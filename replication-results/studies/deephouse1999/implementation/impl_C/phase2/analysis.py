#!/usr/bin/env python3
"""Offline, parameterised implementation of manifest.md and grid.json.

Importing this module never loads data or fits a model. --construct-only never
calls the estimator, including the residual-based outlier selector.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.metadata
import json
import platform
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats

ROOT = Path(__file__).resolve().parent
ID = 'RSSD9001'
KEY = [ID, 'year']
SHARES = [f'share_{i:02}' for i in range(1, 12)]
VARIABLES = ['y', 'lag', 'SD', 'SD2', 'MS', 'TER', 'RMG']
MODEL_TERMS = {
    'M1': ['MS', 'TER', 'RMG', 'lag'],
    'M2': ['SD', 'MS', 'TER', 'RMG', 'lag'],
    'M3': ['SD2', 'SD', 'MS', 'TER', 'RMG', 'lag'],
    'M3_SQ': ['SD2', 'MS', 'TER', 'RMG', 'lag'],
}
COMPARISONS = [('M2', 'M1'), ('M3', 'M1'), ('M3', 'M2'), ('M3_SQ', 'M1')]
RESULT_COLUMNS = ('spec_id origin axis level_id model status message n n_banks k '
                  'df_resid sse_w cond_max term estimate se t p_two_sided sample_hash').split()
F_COLUMNS = 'spec_id comparison delta_sse q df_resid_u F p_upper'.split()
INFLUENCE_COLUMNS = ('origin model deletion_type deleted_id term estimate se '
                     'p_two_sided n status message').split()
FILES = {
    'call': 'call_mnwi_core_1983q4_1993q4',
    'presence': 'call_item_presence_by_quarter',
    'institutions': 'fdic_institutions_mnwi_and_linked',
    'events': 'fdic_structure_events_mnwi_1983_1994',
    'financials': 'fdic_financials_core_mnwi_1984q1_1994q4',
    'prices': 'deflators_long',
    'geography': 'msa_minneapolis_stpaul_counties_by_vintage',
    'counties': 'county_fips_mn_wi',
}


class Unavailable(RuntimeError):
    """A specified input or defensible mapping is not supplied."""


class FitError(RuntimeError):
    """A model cannot be estimated on its specified sample."""


def local_path(path: str | Path) -> Path:
    p = Path(path).resolve()
    if not p.is_relative_to(ROOT):
        raise ValueError(f'Path must be inside the task directory: {path}')
    return p


def dates(s: pd.Series) -> pd.Series:
    """Accept ISO, MM/DD/YYYY, or numeric YYYYMMDD provider dates."""
    text = s.astype('string').str.replace(r'\.0$', '', regex=True)
    compact = text.str.fullmatch(r'\d{8}', na=False)
    out = pd.to_datetime(text.where(~compact), format='mixed', errors='coerce')
    out.loc[compact] = pd.to_datetime(text.loc[compact], format='%Y%m%d', errors='coerce')
    return out


def sample_hash(sample: pd.DataFrame) -> str:
    """SHA-256 of lexicographically sorted, newline-terminated integer lines."""
    values = sample[KEY].to_numpy(dtype=float)
    if not np.isfinite(values).all() or not np.equal(values, np.floor(values)).all():
        raise ValueError('Sample identifiers and years must be finite integers')
    lines = sorted(f'{int(i)},{int(t)}\n' for i, t in values)
    return hashlib.sha256(''.join(lines).encode('utf-8')).hexdigest()


def calendar_lag(frame: pd.DataFrame, value: str = 'y') -> pd.Series:
    """Exact same-unit, previous-calendar-year join; never skip a gap."""
    if frame.duplicated(KEY).any():
        raise ValueError('Duplicate bank-years in lag construction')
    lookup = frame.set_index(KEY)[value]
    keys = pd.MultiIndex.from_arrays([frame[ID], frame.year - 1], names=KEY)
    return pd.Series(lookup.reindex(keys).to_numpy(), index=frame.index, name='lag')


def strategic_deviation(frame: pd.DataFrame, reference: pd.DataFrame,
                        level: str = 'R17.sample_sd') -> tuple[pd.Series, dict]:
    ddof = 0 if level == 'R17.population_sd' else 1
    means = reference.groupby('year')[SHARES].mean()
    sds = reference.groupby('year')[SHARES].std(ddof=ddof)
    mu = means.reindex(frame.year).set_axis(frame.index)
    sd = sds.reindex(frame.year).set_axis(frame.index)
    z = (frame[SHARES] - mu).abs() / sd.replace(0, np.nan)
    if level != 'R17.zero_sd_missing':
        # A zero-SD category contributes zero, even when the target share is absent.
        z = z.mask(sd.eq(0), 0.0)
    result = z.sum(axis=1, min_count=len(SHARES))
    special = {str(int(year)): list(sds.columns[row.eq(0)])
               for year, row in sds.iterrows() if row.eq(0).any()}
    return result, special


class Audit:
    def __init__(self):
        self.steps = []
        self.special = []

    def record(self, step, reason, before, after):
        b = before.groupby('year').size() if len(before) else pd.Series(dtype=int)
        a = after.groupby('year').size() if len(after) else pd.Series(dtype=int)
        years = sorted(set(b.index) | set(a.index))
        self.steps.append({'step': step, 'reason': reason,
                           'input': len(before), 'kept': len(after),
                           'dropped': len(before) - len(after),
                           'by_year': {str(int(y)): {'input': int(b.get(y, 0)),
                               'kept': int(a.get(y, 0)),
                               'dropped': int(b.get(y, 0) - a.get(y, 0))} for y in years}})

    def note(self, kind, **details):
        self.special.append({'kind': kind, **details})

    def as_dict(self):
        return {'steps': self.steps, 'special_handling': self.special}


class Inputs:
    def __init__(self, directory: Path | None = None, frames: dict | None = None):
        self.frames = frames if frames is not None else {
            k: pd.read_parquet(local_path(directory / (v + '.parquet')))
            for k, v in FILES.items()}
        self.candidates = json.loads((ROOT / 'docs/call_item_candidates.json').read_text())

    def __getitem__(self, name):
        return self.frames[name]


class Constructor:
    """Reusable S1--S6 pipeline. It contains no model-fitting operations."""
    def __init__(self, inputs: Inputs, grid: dict):
        self.data = inputs
        self.grid = grid
        self.cache = {}

    def construct(self, config: dict, origin: str):
        # Model-only axes do not change constructed variables or sample membership.
        key = (origin, tuple((k, v) for k, v in sorted(config.items()) if int(k[1:]) <= 21))
        if key not in self.cache:
            self.cache[key] = self._construct(config, origin)
        sample, log = self.cache[key]
        return sample.copy(), copy.deepcopy(log)

    def counties(self, year, level):
        g = self.data['geography']
        g = g[pd.to_numeric(g.area_code, errors='coerce').eq(5120)].copy()
        g['date'] = dates(g.omb_definition_date)
        target = pd.Timestamp('1983-06-27')
        if level == 'R01.dynamic':
            target = g.loc[g.date <= pd.Timestamp(year=int(year), month=12, day=31), 'date'].max()
        g = g[g.date.eq(target)]
        if level == 'R01.mnonly':
            g = g[pd.to_numeric(g.state_fips, errors='coerce').eq(27)]
        if g.empty:
            raise Unavailable(f'No county delineation for {year}, {level}')
        return set(g.county_fips5.astype(str).str.zfill(5))

    def filter_records(self, c, origin, log):
        raw = self.data['call'].copy()
        raw['year'] = raw.quarter.str[:4].astype(int)
        raw['q'] = raw.quarter.str[-1].astype(int)
        eligible = raw[raw.year.between(1983, 1992)].copy()
        log.record('S1', 'quarters needed (1983Q4 through 1992Q4)', raw, eligible)
        raw = eligible
        level = c['R02']
        if level == 'R02.no_special':
            raise Unavailable('RSSD9425 special-purpose numeric code mapping is absent from '
                              'the supplied data dictionary; codes cannot be inferred from values.')
        base = self.grid['origins'][origin]['R02'] if level == 'R02.add_savings' else level
        charter = raw.RSSD9048.eq(200)
        if level == 'R02.add_savings':
            charter |= raw.RSSD9048.eq(300)
        keep = raw.CALL8786.isin([1, 2])
        if base in ['R02.charter_entity', 'R02.charter']:
            keep &= charter
        if base in ['R02.charter_entity', 'R02.entity']:
            # Additional admission of savings filers overrides the commercial entity test.
            keep &= raw.RSSD9331.eq(1) | (raw.RSSD9048.eq(300) if level == 'R02.add_savings' else False)
        filtered = raw.loc[keep].copy()
        log.record('S1', level, raw, filtered)
        if filtered[ID].isna().any():
            raise Unavailable('Filtered record lacks RSSD9001')
        ordered = filtered.sort_values(['quarter', ID, 'CALL8786'], kind='stable')
        dup = ordered.duplicated(['quarter', ID], keep='first')
        if dup.any():
            log.note('duplicate_records', dropped=ordered.loc[dup, ['quarter', ID, 'CALL8786']].to_dict('records'),
                     rule='prefer CALL8786 1 over 2, stable file order for ties')
        unique = ordered.loc[~dup].copy()
        unique[ID] = unique[ID].astype('int64')
        log.record('S1', 'deduplicate bank-quarter', filtered, unique)
        return unique

    def market(self, q4, c, log):
        if c['R01'] == 'R01.rssdmsa':
            mask = q4.RSSD9180.eq(5120)
        else:
            county = (pd.to_numeric(q4.RSSD9210).astype('Int64').astype('string').str.zfill(2)
                      + pd.to_numeric(q4.RSSD9150).astype('Int64').astype('string').str.zfill(3))
            mask = pd.Series(False, index=q4.index)
            for year, g in q4.groupby('year'):
                mask.loc[g.index] = county.loc[g.index].isin(self.counties(year, c['R01']))
        m = q4.loc[mask].copy()
        log.record('S2', c['R01'], q4, m)
        # Membership uses the explicitly specified RCFD2170, also under R16.domestic.
        positive = m[m.RCFD2170.gt(0)].copy()
        log.record('S2', 'positive Q4 RCFD2170', m, positive)
        return positive

    def item_getter(self, records, c, log):
        presence = self.data['presence'].set_index(['item', 'quarter'])
        if presence.index.has_duplicates:
            raise Unavailable('Item-presence table has duplicate item-quarter keys')
        memo = {}
        prefix = 'RCON' if c['R16'] == 'R16.domestic' else 'RCFD'
        # Only explicit, complete identities documented in supplied concept notes.
        identities = {'0010': ['0081', '0071'], '1766': ['1763', '1764'],
                      '1600': ['1755', '1766'], '1975': ['2008', '2011'],
                      '1400': ['2122', '2123'], '2165': ['2182', '2183']}

        def get(code, explicit=None, component=True):
            item = explicit or prefix + code
            token = (item, component)
            if token in memo:
                return memo[token].copy()
            if item not in records:
                log.note('unavailable_item', item=item, handling='missing unless documented R15 rule applies')
                s = pd.Series(np.nan, index=records.index)
            else:
                s = pd.to_numeric(records[item], errors='coerce').copy()
            if component and c['R15'] == 'R15.zero_if_not_collected':
                try:
                    p = presence.xs(item, level='item')
                    absent = records.quarter.map(p.in_file.eq(0) | p.any_nonmissing_mnwi.eq(0)).fillna(False)
                except KeyError:
                    absent = pd.Series(False, index=records.index)
                filled = s.isna() & absent
                if filled.any():
                    log.note('not_collected_zero', item=item, count=int(filled.sum()),
                             by_year=records.loc[filled].groupby('year').size().to_dict())
                s = s.mask(filled, 0.0)
            elif component and c['R15'] == 'R15.identity_fill' and code in identities:
                values = [get(x, explicit=item[:4] + x) for x in identities[code]]
                total = sum(values)
                # Apply only during the documented post-revision periods.
                total = total.where(records.year.ge(1984))
                if code == '1600':
                    total = total.where(records.quarter.gt('1984Q1'))
                filled = s.isna() & total.notna()
                if filled.any():
                    log.note('identity_fill', item=item, count=int(filled.sum()),
                             components=[item[:4] + x for x in identities[code]])
                s = s.fillna(total)
            memo[token] = s
            return s.copy()
        return get

    def opening_dates(self, records):
        inst = self.data['institutions'][['CERT', 'ESTYMD']].copy()
        inst['opened'] = dates(inst.ESTYMD)
        if inst.groupby('CERT').opened.nunique().gt(1).any():
            raise Unavailable('Conflicting FDIC opening dates for a CERT')
        lookup = inst.groupby('CERT').opened.first()
        result = records.RSSD9050.map(lookup)
        raw = self.data['call']
        first = raw.groupby(ID).quarter.min().map(lambda x: pd.Period(x, freq='Q').end_time.normalize())
        return result.fillna(records[ID].map(first))

    def annual(self, records, c, log):
        get = self.item_getter(records, c, log)
        a = records[[ID, 'year', 'q', 'quarter', 'RSSD9050']].copy()
        a['assets'] = get('2170', component=False)
        a['rck'] = get('3368', component=False)
        if c['R05'] == 'R05.min2_fallback' and c['R16'] == 'R16.consolidated':
            a['rck'] = a.rck.fillna(get('3368', explicit='RCON3368', component=False))
        periods = pd.PeriodIndex(a.quarter, freq='Q')
        a['days'] = (periods.end_time.normalize() - periods.start_time).days + 1
        groups = a.groupby(KEY)
        avg = groups.rck.mean()
        count = groups.rck.count()
        if c['R06'] == 'R06.rck_days':
            weighted = (a.rck * a.days).groupby([a[ID], a.year]).sum(min_count=1)
            denom = a.days.where(a.rck.notna()).groupby([a[ID], a.year]).sum(min_count=1)
            avg = (weighted / denom).where(count.eq(4))
        else:
            required = {'R05.min2_fallback': 2, 'R05.all4': 4, 'R05.any': 1}[c['R05']]
            avg = avg.where(count.ge(required))
        points = a.pivot(index=KEY, columns='q', values='assets').reindex(columns=[1, 2, 3, 4])
        prior = points[4].reset_index()
        prior['year'] += 1
        points[0] = prior.set_index(KEY)[4].reindex(points.index)
        if c['R06'] == 'R06.five_point':
            avg = points.mean(axis=1).where(points.notna().all(axis=1))
        elif c['R06'] == 'R06.two_point':
            avg = points[[0, 4]].mean(axis=1).where(points[[0, 4]].notna().all(axis=1))
        elif c['R05'] == 'R05.min2_fallback' and c['R06'] in ['R06.rck_mean', 'R06.fdic_roa']:
            fallback = count.eq(0)
            avg = avg.mask(fallback, points.mean(axis=1))
            log.note('average_assets_fallback', bank_years=int((fallback & avg.notna()).sum()),
                     rule='zero available RC-K quarters only; one quarter remains missing')
        coverage = count.reset_index(name='available_quarters')
        log.note('average_assets_coverage', counts=coverage.groupby(
            ['year', 'available_quarters']).size().reset_index(name='bank_years').to_dict('records'),
            formula=c['R06'], coverage_rule='four quarterly 3368 values required'
            if c['R06'] == 'R06.rck_days' else c['R05'])
        annual = records[records.q.eq(4) & records.year.between(1984, 1992)].copy()
        annual = annual.set_index(KEY)
        annual['AA'] = avg.reindex(annual.index).where(lambda s: s.gt(0))
        income = 'RIAD4340' if c['R07'] == 'R07.net_income' else 'RIAD4300'
        annual['NI'] = annual[income]
        annual['expenses'] = annual.RIAD4073 + annual.RIAD4093
        annual = annual.reset_index()
        annual['opened'] = self.opening_dates(annual)
        if c['R04'] == 'R04.annualise':
            first = annual.opened.dt.year.eq(annual.year)
            # Calendar months, inclusive of opening month; no fractional-month convention supplied.
            factor = 12 / (13 - annual.opened.dt.month)
            annual.loc[first, ['NI', 'expenses']] = annual.loc[first, ['NI', 'expenses']].mul(factor[first], axis=0)
            log.note('annualisation', count=int(first.sum()), months='inclusive calendar months of opening year')
        annual['ROA'] = annual.NI / annual.AA
        annual['TER'] = annual.expenses / annual.AA
        if c['R06'] == 'R06.fdic_roa':
            fin = self.fdic_q4()
            lookup = fin.set_index(['CERT', 'year']).ROA
            keys = pd.MultiIndex.from_arrays([annual.RSSD9050, annual.year])
            annual['ROA'] = lookup.reindex(keys).to_numpy() / 100
        amounts = pd.DataFrame(index=records.index)
        amounts[SHARES[0]] = get('1766' if c['R11'] == 'R11.excl_accept' else '1600')
        amounts[SHARES[1]] = get('1410')
        amounts[SHARES[2]] = get('1975')
        amounts[SHARES[3]] = get('1590')
        if c['R12'] == 'R12.plus_farmland':
            farmland = get('1420', explicit='RCON1420')
            amounts[SHARES[1]] -= farmland
            amounts[SHARES[3]] += farmland
        residual = get('1400') - amounts[SHARES[:4]].sum(axis=1, min_count=4)
        other = c['R13']
        if other == 'R13.components':
            # Disjoint totals: do not double count 1516 within 1510, 1563 within
            # 2080, or 2182/2183 within 2165. 1520 is a pre-1984 concept.
            codes = ['2165', '1505', '1517', '1510', '1545', '2107', '2081', '2080']
            inventory = self.data.candidates['other_loans_and_leases_and_loan_totals']['codes']
            if not set(codes).issubset(inventory):
                raise Unavailable('Explicit other-loan components absent from candidate inventory')
            residual = sum(get(code) for code in codes)
            log.note('other_loan_components', codes=codes)
        elif other in ['R13.net_unearned', 'R13.net_allowance']:
            residual -= get('2123')
            if other == 'R13.net_allowance':
                residual -= get('3123')
        amounts[SHARES[4]] = residual
        for name, code in zip(SHARES[5:10], ['0010', '1350', '0390', '2146', '2145']):
            amounts[name] = get(code)
        if c['R14'] == 'R14.broad':
            amounts[SHARES[10]] = sum(get(x) for x in ['2150', '2130', '2155', '2143', '2160'])
        elif c['R14'] == 'R14.literal':
            amounts[SHARES[10]] = get('2160')
        else:
            amounts[SHARES[10]] = a.assets - amounts[SHARES[:10]].sum(axis=1, min_count=10)
        dep_item = 'RCON2200' if c['R18'] == 'R18.domestic' else 'RCFD2200'
        # R18 explicitly controls deposits independently of the category/AA scope axis.
        amounts['DEP'] = get('2200', explicit=dep_item, component=False)
        shares = amounts[SHARES].div(a.assets.where(a.assets.gt(0)), axis=0)
        annual = annual.set_index(KEY)
        if c['R08'] == 'R08.year_end':
            stocks = shares.copy()
            stocks['DEP'] = amounts.DEP
            stocks[ID], stocks['year'] = a[ID], a.year
            stocks = stocks[a.q.eq(4)].set_index(KEY)
        else:
            if c['R08'] == 'R08.mean_of_quarter_shares':
                stocks = shares.groupby([a[ID], a.year]).mean()
            else:
                stocks = amounts[SHARES].groupby([a[ID], a.year]).mean().div(groups.assets.mean(), axis=0)
            stocks['DEP'] = amounts.DEP.groupby([a[ID], a.year]).mean()
        annual[SHARES + ['DEP']] = stocks.reindex(annual.index)[SHARES + ['DEP']]
        annual = annual.reset_index()
        log.note('annual_variable_missingness', by_year={str(int(year)): {
            v: int(part[v].isna().sum()) for v in ['AA', 'NI', 'expenses', 'ROA', 'TER', 'DEP'] + SHARES}
            for year, part in annual.groupby('year')})
        log.record('S3', 'annual variables (missing values retained until S6)', annual, annual)
        return annual

    def fdic_q4(self):
        fin = self.data['financials'].copy()
        date = dates(fin.REPDTE)
        fin['year'] = date.dt.year
        fin = fin[date.dt.month.eq(12) & date.dt.day.eq(31) & fin.year.between(1984, 1992)].copy()
        if fin.duplicated(['CERT', 'year']).any():
            raise Unavailable('FDIC financials duplicate CERT-year keys')
        return fin

    def insured_totals(self, c, log):
        f = self.fdic_q4()
        county = f.STCNTY.astype('string').str.replace(r'\.0$', '', regex=True).str.zfill(5)
        # Some supplied STCNTY values are county names, despite the field description.
        numeric = county.str.fullmatch(r'\d{5}', na=False)
        if (~numeric).any():
            table = self.data['counties']
            lookup = {(str(r.state_abbr).upper(), str(r.county_name).casefold().removesuffix(' county')):
                      str(r.county_fips5).zfill(5) for r in table.itertuples()}
            mapped = [lookup.get((str(s).upper(), str(v).casefold().removesuffix(' county')))
                      for s, v in zip(f.STALP, f.STCNTY)]
            county = county.where(numeric, pd.Series(mapped, index=f.index))
            log.note('fdic_county_name_mapping', mapped=int((~numeric & county.notna()).sum()),
                     source='county_fips_mn_wi.parquet; exact state/county name match')
        if county.isna().any():
            raise Unavailable('FDIC STCNTY cannot be mapped exactly to supplied county FIPS table')
        mask = pd.Series(False, index=f.index)
        for year, part in f.groupby('year'):
            mask.loc[part.index] = county.loc[part.index].isin(self.counties(year, c['R01']))
        return f.loc[mask].groupby('year').DEP.sum(min_count=1)

    def deflator(self, c):
        p = self.data['prices'].copy()
        date = dates(p.date)
        p['year'] = date.dt.year
        level = c['R20']
        if level == 'R20.gdp_historical':
            p = p[p.provider.eq('ALFRED') & p.series_id.eq('GDPDEF') & p.vintage.str.contains('1999-01-01', na=False)]
            if p.duplicated('date').any():
                raise Unavailable('Duplicate historical GDPDEF dates')
            count = p.groupby('year').value.count()
            result = p.groupby('year').value.mean().where(count.eq(4))
        else:
            series = {'R20.cpi_annual': 'CPIAUCNS', 'R20.cpi_december': 'CPIAUCNS',
                      'R20.local_cpi': 'CUUSA211SA0', 'R20.gdp_current': 'A191RD3A086NBEA'}[level]
            mask = p.provider.eq('FRED') & p.series_id.eq(series)
            if level == 'R20.cpi_annual':
                mask &= p.frequency.str.contains('annual average', case=False, na=False)
            elif level == 'R20.cpi_december':
                mask &= date.dt.month.eq(12) & ~p.frequency.str.contains('annual', case=False, na=False)
            p = p.loc[mask]
            if p.duplicated('year').any():
                raise Unavailable(f'Multiple observations per year for {level}')
            result = p.set_index('year').value
        result = result.reindex(range(1984, 1993))
        if result.isna().any() or result.le(0).any():
            raise Unavailable(f'Missing/nonpositive 1984--1992 price observations for {level}')
        return result

    def benchmarks(self, population, reference, c, log):
        d = population.copy()
        d['SD'], zeros = strategic_deviation(d, reference, c['R17'])
        log.note('zero_standard_deviations', by_year=zeros)
        if c['R09'] == 'R09.weighted_roa':
            valid = reference.ROA.notna() & reference.AA.gt(0)
            r = reference.loc[valid]
            mean_roa = (r.ROA * r.AA).groupby(r.year).sum(min_count=1) / r.groupby('year').AA.sum(min_count=1)
        else:
            mean_roa = reference.groupby('year').ROA.mean()
        d['market_roa'] = d.year.map(mean_roa)
        d['y'] = 100 * (d.ROA - d.market_roa)
        d['SD2'] = d.SD ** 2
        totals = reference.groupby('year').DEP.sum(min_count=1)
        insured = None
        if c['R19'] == 'R19.all_insured' or c['R21'] == 'R21.all_insured':
            insured = self.insured_totals(c, log)
        share_totals = insured if c['R19'] == 'R19.all_insured' else totals
        growth_totals = insured if c['R21'] == 'R21.all_insured' else totals
        d['MS'] = d.DEP / d.year.map(share_totals.where(share_totals.gt(0)))
        real = growth_totals.reindex(range(1984, 1993)) / self.deflator(c)
        growth = 100 * (real / real.shift(1) - 1)
        d['RMG'] = d.year.map(growth)
        log.record('S4', 'reference population for benchmarks', population, reference)
        log.note('benchmark_available_counts', counts=reference.groupby('year')[SHARES + ['ROA', 'DEP']].count().to_dict('index'))
        return d

    def merger_events(self):
        e = self.data['events'].copy()
        e['year'] = dates(e.EFFDATE).dt.year
        desc = e.CHANGECODE_DESC.fillna('')
        mask = desc.str.contains(r'merg|absorp|absorb|consolidat', case=False, regex=True)
        mask &= ~desc.str.contains(r'branch', case=False)
        e = e.loc[mask].copy()
        e['survivor'] = e.SUR_CERT.where(e.SUR_CERT.gt(0), e.ACQ_CERT.where(e.ACQ_CERT.gt(0)))
        return e

    def lags(self, d, all_annual, c, log):
        d = d.copy()
        d['lag'] = calendar_lag(d)
        level = c['R03']
        if level == 'R03.continuity':
            e = self.data['events'].copy()
            e['year'] = dates(e.EFFDATE).dt.year
            desc = e.CHANGECODE_DESC.fillna('')
            pure = desc.str.contains(r'charter|legal name|reorgani', case=False)
            pure &= ~desc.str.contains(r'merg|absorp|absorb|consolidat|branch', case=False)
            e = e.loc[pure]
            allowed = set()
            for row in e.itertuples():
                certs = {getattr(row, col) for col in ['CERT', 'FRM_CERT', 'SUR_CERT', 'ACQ_CERT', 'OUT_CERT']
                         if pd.notna(getattr(row, col)) and getattr(row, col) > 0}
                if len(certs) == 1:
                    allowed.add((next(iter(certs)), row.year))
            existing = set(map(tuple, all_annual[KEY].to_numpy()))
            count = 0
            for idx, row in d[d.lag.isna()].iterrows():
                if (row[ID], row.year - 1) in existing or (row.RSSD9050, row.year) not in allowed:
                    continue
                prev = d[(d.RSSD9050.eq(row.RSSD9050)) & d.year.eq(row.year - 1) & d[ID].ne(row[ID])]
                if len(prev) == 1:
                    d.loc[idx, 'lag'] = prev.y.iloc[0]
                    count += int(pd.notna(prev.y.iloc[0]))
            log.note('continuity_lags', filled=count, rule='event-confirmed same CERT, unique prior RSSD')
        elif level == 'R03.proforma':
            events = self.merger_events()
            missing, filled = [], 0
            for idx, row in d.iterrows():
                match = events[events.survivor.eq(row.RSSD9050) & events.year.eq(row.year)]
                if match.empty:
                    continue
                certs = set(match.OUT_CERT.dropna().loc[lambda s: s.gt(0)]) | {row.RSSD9050}
                if len(certs) < 2:
                    d.loc[idx, 'lag'] = np.nan
                    missing.append([int(row[ID]), int(row.year), 'no outgoing CERT'])
                    continue
                # Close same-year merger chains so every prior-year predecessor is included.
                changed = True
                while changed:
                    links = events[events.year.eq(row.year) & events.survivor.isin(certs)]
                    extra = set(links.OUT_CERT.dropna().loc[lambda s: s.gt(0)])
                    changed = not extra.issubset(certs)
                    certs |= extra
                prev = all_annual[all_annual.year.eq(row.year - 1) & all_annual.RSSD9050.isin(certs)]
                if (set(prev.RSSD9050) != certs or prev.RSSD9050.duplicated().any()
                        or prev[['NI', 'AA']].isna().any().any() or not prev.AA.gt(0).all()):
                    d.loc[idx, 'lag'] = np.nan
                    missing.append([int(row[ID]), int(row.year), 'incomplete/unidentifiable predecessor income or assets'])
                    continue
                prior_market = d.loc[d.year.eq(row.year - 1), 'market_roa']
                mean = prior_market.iloc[0] if len(prior_market) else np.nan
                d.loc[idx, 'lag'] = 100 * (prev.NI.sum() / prev.AA.sum() - mean)
                filled += int(pd.notna(d.loc[idx, 'lag']))
            log.note('proforma_lags', filled=filled, missing=missing,
                     rule='all predecessor CERTs including survivor; no partial aggregation')
        log.record('S5', 'derived variables and exact calendar lags', d, d)
        return d

    def select(self, d, c, log):
        s = d[d.year.between(1985, 1992)].copy()
        log.record('S6', '1985--1992 estimation years', d, s)
        def keep(mask, reason):
            nonlocal s
            after = s.loc[mask].copy()
            log.record('S6', reason, s, after)
            s = after
        if c['R03'] == 'R03.drop_merger_years':
            e = self.merger_events()
            excluded = {(cert, int(year) + offset) for role in ['SUR_CERT', 'ACQ_CERT']
                        for cert, year in zip(e[role], e.year)
                        if pd.notna(cert) and cert > 0 and pd.notna(year) for offset in [0, 1]}
            keep(pd.Series([(cert, year) not in excluded for cert, year in zip(s.RSSD9050, s.year)], index=s.index),
                 'merger survivor event year and following year')
        if c['R04'] == 'R04.full_prior_year':
            cutoff = pd.to_datetime((s.year - 1).astype(str) + '-01-01')
            keep(s.opened.lt(cutoff), 'opening date before January 1 of t-1')
        if c['R10'] == 'R10.suppress_lag':
            mask = s[ID].eq(995151) & s.year.eq(1988)
            s.loc[mask, 'lag'] = np.nan
            log.note('named_lag_suppression', count=int(mask.sum()))
        # Report marginal missingness as well as mutually exclusive sequential losses.
        log.note('pre_complete_case_missing', by_year={str(int(y)): {
            v: int((~np.isfinite(g[v])).sum()) for v in VARIABLES} for y, g in s.groupby('year')})
        for v in VARIABLES:
            keep(np.isfinite(s[v]), f'missing/nonfinite {v}')
        keep(s.MS.gt(0), 'nonpositive market share')
        if c['R10'] in ['R10.delete_named', 'R10.suppress_lag']:
            keep(~(s[ID].eq(995151) & s.year.eq(1987)), 'named 1987 outlier (last)')
        if c['R10'] == 'R10.max_rstudent':
            log.note('deferred_outlier_selection', rule='requires fitting; performed only in full run')
        s = s.sort_values(KEY).reset_index(drop=True)
        s['w'] = s.MS
        return s

    def _construct(self, c, origin):
        log = Audit()
        records = self.filter_records(c, origin, log)
        q4 = records[records.q.eq(4) & records.year.between(1984, 1992)].copy()
        log.record('S2', 'Q4 bank-years 1984--1992', records, q4)
        market = self.market(q4, c, log)
        annual = self.annual(records, c, log)
        population = annual.merge(market[KEY], on=KEY, how='inner', validate='one_to_one')
        log.record('S3', 'annual market bank-years', annual, population)
        if c['R10'] == 'R10.before_benchmarks':
            kept = population[~(population[ID].eq(995151) & population.year.eq(1987))].copy()
            log.record('S4', 'named outlier removed before benchmarks and lags', population, kept)
            population = kept
        reference = population
        if c['R09'] == 'R09.joint_complete':
            reference = population.dropna(subset=SHARES + ['ROA', 'DEP'])
        d = self.benchmarks(population, reference, c, log)
        d = self.lags(d, annual, c, log)
        sample = self.select(d, c, log)
        if c['R09'] == 'R09.analytic':
            fixed = sample[KEY]
            reference = population.merge(fixed, on=KEY, validate='one_to_one')
            log.note('analytic_reference', rule='one pilot pass; only fixed final estimation bank-years')
            rebuilt = self.benchmarks(population, reference, c, log)
            rebuilt = self.lags(rebuilt, annual, c, log)
            sample = rebuilt.merge(fixed, on=KEY, validate='one_to_one').sort_values(KEY).reset_index(drop=True)
            if not np.isfinite(sample[VARIABLES]).all().all() or not sample.MS.gt(0).all():
                raise Unavailable('Analytic reference rebuild makes fixed pilot rows undefined; '
                                  'only final estimation bank-years may supply benchmarks, so no '
                                  '1984 reference exists for 1985 lags and real market growth. '
                                  'Rows cannot be silently changed or all-market benchmarks substituted.')
            sample['w'] = sample.MS
        log.note('final_sample', n=len(sample), n_banks=int(sample[ID].nunique()), sample_hash=sample_hash(sample))
        return sample[KEY + VARIABLES + ['w']], log.as_dict()


@dataclass
class Fit:
    terms: list[str]
    beta: np.ndarray
    covariance: np.ndarray
    se: np.ndarray
    t: np.ndarray
    p: np.ndarray
    n: int
    k: int
    df_resid: int
    sse_w: float
    cond_max: float
    residual: np.ndarray
    weighted_residual: np.ndarray
    leverage: np.ndarray
    n_banks: int = 0
    sample_hash: str = ''
    message: str = ''
    rho: float | None = None


def _solve(x, y):
    """Column-normalized SVD, including intercept; reject non-identification."""
    n, k = x.shape
    if n <= k:
        raise FitError(f'Insufficient residual degrees of freedom: N={n}, K={k}')
    scale = np.linalg.norm(x, axis=0)
    if np.any(scale == 0):
        raise FitError('Design contains a zero column')
    z = x / scale
    u, singular, vt = np.linalg.svd(z, full_matrices=False)
    tolerance = np.finfo(float).eps * max(z.shape) * singular[0]
    if singular[-1] <= tolerance:
        raise FitError(f'Rank deficient design: rank={int((singular > tolerance).sum())}, K={k}')
    inverse = (vt.T / singular) @ u.T
    beta = (inverse @ y) / scale
    bread = ((vt.T / singular ** 2) @ vt) / np.outer(scale, scale)
    leverage = (u ** 2).sum(axis=1)
    return beta, bread, leverage, float(singular[0] / singular[-1])


def consecutive_predecessors(groups, years):
    keys = {(int(i), int(t)): r for r, (i, t) in enumerate(zip(groups, years))}
    if len(keys) != len(groups):
        raise FitError('Duplicate bank-year keys in AR(1) estimation')
    return np.array([keys.get((int(i), int(t) - 1), -1) for i, t in zip(groups, years)])


def prais_winsten(x, y, predecessors, rho):
    """Apply PW separately to each contiguous bank spell, preserving row order."""
    x_new, y_new = x.copy(), y.copy()
    paired = predecessors >= 0
    x_new[paired] -= rho * x[predecessors[paired]]
    y_new[paired] -= rho * y[predecessors[paired]]
    first_factor = np.sqrt(1 - rho ** 2)
    x_new[~paired] *= first_factor
    y_new[~paired] *= first_factor
    return x_new, y_new


def fit_matrix(x, y, weights, terms=None, covariance='R23.conventional',
               groups=None, years=None, ar1=False):
    """WLS/OLS and sandwich covariances; no dependency on real data files.

    AR(1) is a specified two-step feasible PW fit: preliminary WLS residuals,
    pooled no-intercept consecutive residual regression, then one PW fit.
    """
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    weights = np.asarray(weights, dtype=float)
    if x.ndim != 2 or y.shape != (len(x),) or weights.shape != y.shape:
        raise FitError('Invalid design/outcome/weight dimensions')
    if not (np.isfinite(x).all() and np.isfinite(y).all() and np.isfinite(weights).all()):
        raise FitError('Nonfinite model input')
    if np.any(weights <= 0):
        raise FitError('Weights must be strictly positive')
    n, k = x.shape
    root_w = np.sqrt(weights)
    xw, yw = x * root_w[:, None], y * root_w
    beta, bread, leverage, cond = _solve(xw, yw)
    rho, message = None, ''
    if ar1:
        if groups is None or years is None:
            raise FitError('AR(1) requires bank and year identifiers')
        prev = consecutive_predecessors(groups, years)
        paired = prev >= 0
        if not paired.any():
            raise FitError('AR(1) has no consecutive within-bank residual pairs')
        initial = yw - xw @ beta
        denom = initial[prev[paired]] @ initial[prev[paired]]
        if denom <= 0:
            raise FitError('AR(1) residual lag regression has zero denominator')
        rho_unclipped = float(initial[prev[paired]] @ initial[paired] / denom)
        rho = float(np.clip(rho_unclipped, -1 + 1e-8, 1 - 1e-8))
        xw, yw = prais_winsten(xw, yw, prev, rho)
        beta, bread, leverage, cond = _solve(xw, yw)
        message = (f'two-step Prais-Winsten rho={rho:.17g}; raw rho={rho_unclipped:.17g}; '
                   'new spell at each gap; covariance uses innovation SSE; sse_w uses original WLS metric')
    residual = y - x @ beta
    innovations = yw - xw @ beta
    df = n - k
    if covariance == 'R23.conventional':
        cov = bread * float(innovations @ innovations) / df
    elif covariance == 'R23.hc1':
        score = xw * innovations[:, None]
        cov = bread @ (score.T @ score) @ bread * n / df
    elif covariance == 'R23.cluster_bank':
        if groups is None:
            raise FitError('Cluster covariance requires bank identifiers')
        _, codes = np.unique(groups, return_inverse=True)
        g = int(codes.max()) + 1
        if g < 2:
            raise FitError('Cluster covariance requires at least two banks')
        sums = np.zeros((g, k))
        np.add.at(sums, codes, xw * innovations[:, None])
        cov = bread @ (sums.T @ sums) @ bread * g / (g - 1) * (n - 1) / df
    else:
        raise ValueError(f'Unknown covariance level {covariance}')
    cov = (cov + cov.T) / 2
    diag = np.diag(cov)
    if np.any(diag < -1e-12):
        raise FitError('Negative covariance diagonal')
    se = np.sqrt(np.maximum(diag, 0))
    with np.errstate(divide='ignore', invalid='ignore'):
        t = beta / se
    p = 2 * stats.t.sf(np.abs(t), df)
    return Fit(terms or [f'x{i}' for i in range(k)], beta, cov, se, t, p, n, k, df,
               float(weights @ residual ** 2), cond, residual, innovations, leverage,
               message=message, rho=rho)


def make_design(sample, model, c):
    terms = ['intercept'] + MODEL_TERMS[model].copy()
    messages = []
    if c['R22'] == 'R22.year':
        terms.remove('RMG')
        messages.append('RMG dropped: collinear with year indicators')
    design = pd.DataFrame({'intercept': np.ones(len(sample))}, index=sample.index)
    for term in terms[1:]:
        design[term] = sample[term]
    if c['R22'] != 'R22.none':
        variable = 'year' if c['R22'] == 'R22.year' else ID
        levels = sorted(sample[variable].unique())
        for level in levels[1:]:
            name = f'{variable}[{int(level)}]'
            design[name] = sample[variable].eq(level).astype(float)
            terms.append(name)
    transform = np.eye(len(terms))
    if c['R26'] == 'R26.centered':
        mean = float(sample.SD.mean())
        if 'SD' in terms:
            index = terms.index('SD')
            design['SD'] = sample.SD - mean
            transform[0, index] = -mean
        if 'SD2' in terms:
            index = terms.index('SD2')
            if 'SD' in terms:
                design['SD2'] = (sample.SD - mean) ** 2
                transform[0, index] = mean ** 2
                transform[terms.index('SD'), index] = -2 * mean
            else:
                # Preserve the raw square-only model's constraint. A freely omitted
                # centered linear term would change the model and fail the check.
                design['SD2'] = (sample.SD - mean) ** 2 + 2 * mean * (sample.SD - mean)
                transform[0, index] = -mean ** 2
                messages.append('M3_SQ centered basis retains raw linear-coefficient-zero constraint')
    return design.to_numpy(float), terms, transform, '; '.join(messages)


def model_weights(sample, c):
    if c['R25'] == 'R25.ols':
        return np.ones(len(sample))
    weights = sample.MS.to_numpy(float).copy()
    if c['R24'] == 'R24.mean1':
        weights /= weights.mean()
    return weights


def fit_model(sample, model, c):
    x, terms, transform, message = make_design(sample, model, c)
    fit = fit_matrix(x, sample.y, model_weights(sample, c), terms, c['R23'],
                     sample[ID].to_numpy(), sample.year.to_numpy(), c['R25'] == 'R25.wls_ar1')
    fit.beta = transform @ fit.beta
    fit.covariance = transform @ fit.covariance @ transform.T
    fit.se = np.sqrt(np.maximum(np.diag(fit.covariance), 0))
    with np.errstate(divide='ignore', invalid='ignore'):
        fit.t = fit.beta / fit.se
    fit.p = 2 * stats.t.sf(np.abs(fit.t), fit.df_resid)
    fit.n_banks = int(sample[ID].nunique())
    fit.sample_hash = sample_hash(sample)
    fit.message = '; '.join(x for x in [message, fit.message] if x)
    return fit


def nested_f(restricted: Fit, unrestricted: Fit):
    if restricted.n != unrestricted.n or restricted.sample_hash != unrestricted.sample_hash:
        raise FitError('Nested F requires identical estimation rows')
    q = unrestricted.k - restricted.k
    if q <= 0:
        raise FitError('Nested F requires positive restriction count')
    delta = restricted.sse_w - unrestricted.sse_w
    tolerance = 1e-10 * max(1.0, restricted.sse_w, unrestricted.sse_w)
    if delta < 0 and delta >= -tolerance:
        delta = 0.0
    if unrestricted.sse_w == 0:
        f = np.inf if delta > 0 else np.nan
    else:
        f = (delta / q) / (unrestricted.sse_w / unrestricted.df_resid)
    return {'delta_sse': delta, 'q': q, 'df_resid_u': unrestricted.df_resid,
            'F': f, 'p_upper': float(stats.f.sf(f, q, unrestricted.df_resid))}


def externally_studentized(fit):
    if fit.df_resid <= 1:
        raise FitError('External studentization needs at least two residual degrees of freedom')
    h = fit.leverage
    if np.any(h >= 1 - 1e-12):
        raise FitError('External studentization undefined at unit leverage')
    e = fit.weighted_residual
    deleted_variance = ((e @ e) - e ** 2 / (1 - h)) / (fit.df_resid - 1)
    if np.any(deleted_variance <= 0):
        raise FitError('External studentization has nonpositive deleted variance')
    return e / np.sqrt(deleted_variance * (1 - h))


def outlier_samples(sample, c):
    samples = {model: sample for model in MODEL_TERMS}
    messages = {model: '' for model in MODEL_TERMS}
    if c['R10'] != 'R10.max_rstudent':
        return samples, messages
    maxima = {}
    for model in ['M1', 'M2', 'M3']:
        fit = fit_model(sample, model, c)
        maxima[model] = int(np.argmax(np.abs(externally_studentized(fit))))
    if len(set(maxima.values())) == 1:
        maxima['M3_SQ'] = maxima['M3']
    else:
        maxima['M3_SQ'] = int(np.argmax(np.abs(externally_studentized(fit_model(sample, 'M3_SQ', c)))))
    for model, pos in maxima.items():
        row = sample.iloc[pos]
        samples[model] = sample.drop(sample.index[pos]).copy()
        messages[model] = f'largest absolute external residual deleted: {int(row[ID])},{int(row.year)}'
    return samples, messages


def specifications(grid):
    for origin, config in grid['origins'].items():
        yield origin, origin, '', '', config.copy(), False
    for check in [False, True]:
        for origin, base in grid['origins'].items():
            for axis in grid['axes']:
                for level in axis['levels']:
                    if bool(level.get('check', False)) != check:
                        continue
                    lid, aid = level['id'], axis['axis']
                    config = dict(base, **{aid: lid})
                    yield f'{origin}__{lid}', origin, aid, lid, config, base[aid] == lid


def failure_rows(meta, model, status, message, sample=None, c=None):
    terms = ['intercept'] + MODEL_TERMS[model]
    n, n_banks, digest = np.nan, np.nan, ''
    if sample is not None:
        n, n_banks, digest = len(sample), sample[ID].nunique(), sample_hash(sample)
        if c is not None:
            _, terms, _, _ = make_design(sample, model, c)
    for term in terms:
        yield dict(meta, model=model, status=status, message=message, n=n, n_banks=n_banks,
                   term=term, sample_hash=digest)


def fit_rows(meta, model, fit, status='ok', extra_message=''):
    message = '; '.join(x for x in [extra_message, fit.message] if x)
    for i, term in enumerate(fit.terms):
        yield dict(meta, model=model, status=status, message=message, n=fit.n,
                   n_banks=fit.n_banks, k=fit.k, df_resid=fit.df_resid, sse_w=fit.sse_w,
                   cond_max=fit.cond_max, term=term, estimate=fit.beta[i], se=fit.se[i],
                   t=fit.t[i], p_two_sided=fit.p[i], sample_hash=fit.sample_hash)


def check_algebra(base, candidate, axis, sample):
    if base.sample_hash != candidate.sample_hash or base.terms != candidate.terms:
        raise FitError('Algebraic check changed sample or reported terms')
    if not np.allclose(base.beta, candidate.beta, rtol=1e-7, atol=1e-9):
        raise FitError('Algebraic check failed: coefficients differ')
    if not np.allclose(base.se, candidate.se, rtol=1e-7, atol=1e-9):
        raise FitError('Algebraic check failed: standard errors differ')
    expected = base.sse_w / sample.MS.mean() if axis == 'R24' else base.sse_w
    if not np.isclose(candidate.sse_w, expected, rtol=1e-8, atol=1e-11):
        raise FitError('Algebraic check failed: SSE does not have expected scaling')


def write_descriptives(sample, path):
    rows = []
    for variable in VARIABLES:
        rows.append({'statistic': 'mean', 'variable': variable, 'other_variable': '', 'value': sample[variable].mean()})
        rows.append({'statistic': 'sd', 'variable': variable, 'other_variable': '', 'value': sample[variable].std(ddof=1)})
    corr = sample[VARIABLES].corr(method='pearson')
    for variable in VARIABLES:
        for other in VARIABLES:
            rows.append({'statistic': 'correlation', 'variable': variable, 'other_variable': other, 'value': corr.loc[variable, other]})
    pd.DataFrame(rows).to_csv(path, index=False)


def influence_diagnostics(base_samples, grid):
    for origin, sample in base_samples.items():
        config = grid['origins'][origin]
        deletions = [('bank_year', f'{int(row[ID])},{int(row.year)}', [idx])
                     for idx, row in sample.iterrows()]
        deletions += [('bank', str(int(bank)), list(part.index)) for bank, part in sample.groupby(ID)]
        for model in ['M2', 'M3']:
            target_terms = ['SD'] if model == 'M2' else ['SD2', 'SD']
            for deletion_type, deleted_id, indices in deletions:
                sub = sample.drop(indices)
                meta = dict(origin=origin, model=model, deletion_type=deletion_type,
                            deleted_id=deleted_id, n=len(sub))
                try:
                    fit = fit_model(sub, model, config)
                    for term in target_terms:
                        i = fit.terms.index(term)
                        yield dict(meta, term=term, estimate=fit.beta[i], se=fit.se[i],
                                   p_two_sided=fit.p[i], status='ok', message=fit.message)
                except Exception as exc:
                    for term in target_terms:
                        yield dict(meta, term=term, status='failed', message=f'{type(exc).__name__}: {exc}')


def environment_text():
    packages = ['pandas', 'numpy', 'pyarrow', 'scipy', 'statsmodels']
    return ('Python: ' + sys.version.replace('\n', ' ') + '\nExecutable: ' + sys.executable
            + '\nPlatform: ' + platform.platform() + '\n'
            + ''.join(f'{p}: {importlib.metadata.version(p)}\n' for p in packages))


def run(grid, inputs, output, construct_only=False):
    output.mkdir(parents=True, exist_ok=True)
    (output / 'samples').mkdir(exist_ok=True)
    (output / 'environment.txt').write_text(environment_text())
    constructor = Constructor(inputs, grid)
    results, f_tests, construction_status = [], [], []
    base_samples, base_fits, origin_logs = {}, {}, {}
    for spec_id, origin, axis, level, config, duplicate in specifications(grid):
        meta = dict(spec_id=spec_id, origin=origin, axis=axis, level_id=level)
        sample = None
        if duplicate:
            for model in MODEL_TERMS:
                results.extend(failure_rows(meta, model, 'duplicate', f'Level equals {origin} configuration'))
            construction_status.append(dict(meta, status='duplicate', message='Level equals origin'))
            continue
        print(f'{spec_id}: constructing', flush=True)
        try:
            sample, log = constructor.construct(config, origin)
            construction_status.append(dict(meta, status='ok', n=len(sample), sample_hash=sample_hash(sample),
                                            message='outlier fitting deferred' if config['R10'] == 'R10.max_rstudent' else ''))
            if spec_id == origin:
                base_samples[origin] = sample
                origin_logs[origin] = dict(spec_id=origin, configuration=config, **log, deviations={})
                exported = sample.copy()
                exported['w'] = model_weights(sample, config)
                exported[KEY + VARIABLES + ['w']].to_csv(output / 'samples' / f'{origin}.csv', index=False)
                write_descriptives(sample, output / f'descriptives_{origin}.csv')
            else:
                origin_logs.setdefault(origin, {'deviations': {}})['deviations'][spec_id] = log
            if construct_only:
                continue
            samples, messages = outlier_samples(sample, config)
            fits = {}
            for model in MODEL_TERMS:
                model_sample = samples[model]
                try:
                    fit = fit_model(model_sample, model, config)
                    check = axis in ['R24', 'R26'] and level.endswith(('mean1', 'centered'))
                    if check:
                        if (origin, model) not in base_fits:
                            raise FitError('Origin fit unavailable for algebraic comparison')
                        check_algebra(base_fits[origin, model], fit, axis, model_sample)
                        messages[model] += '; algebraic check passed'
                    fits[model] = fit
                    if spec_id == origin:
                        base_fits[origin, model] = fit
                    results.extend(fit_rows(meta, model, fit, extra_message=messages[model]))
                except Exception as exc:
                    results.extend(failure_rows(meta, model, 'failed', f'{type(exc).__name__}: {exc}', model_sample, config))
            for unrestricted, restricted in COMPARISONS:
                record = dict(spec_id=spec_id, comparison=f'{unrestricted} vs {restricted}')
                try:
                    if unrestricted not in fits or restricted not in fits:
                        raise FitError('One or both model fits failed')
                    record.update(nested_f(fits[restricted], fits[unrestricted]))
                except FitError as exc:
                    # Never present an SSE difference between different samples as an F test.
                    origin_logs[origin]['deviations'].setdefault(spec_id, {}).setdefault('f_test_errors', []).append(
                        {'comparison': record['comparison'], 'message': str(exc)})
                f_tests.append(record)
            if config['R10'] == 'R10.max_rstudent':
                origin_logs[origin]['deviations'][spec_id]['outlier_deletions'] = messages
        except Exception as exc:
            status = 'unavailable' if isinstance(exc, Unavailable) else 'failed'
            message = f'{type(exc).__name__}: {exc}'
            construction_status.append(dict(meta, status=status, message=message))
            origin_logs.setdefault(origin, {'deviations': {}})['deviations'][spec_id] = {'status': status, 'message': message}
            if spec_id == origin and origin not in base_samples:
                empty = pd.DataFrame(columns=KEY + VARIABLES + ['w'])
                empty.to_csv(output / 'samples' / f'{origin}.csv', index=False)
                write_descriptives(empty.astype({v: float for v in VARIABLES}), output / f'descriptives_{origin}.csv')
            for model in MODEL_TERMS:
                results.extend(failure_rows(meta, model, status, message, sample, config))
            if not construct_only:
                f_tests.extend(dict(spec_id=spec_id, comparison=f'{u} vs {r}') for u, r in COMPARISONS)
    for origin, log in origin_logs.items():
        (output / f'construction_log_{origin}.json').write_text(json.dumps(log, indent=2, default=str) + '\n')
    if construct_only:
        pd.DataFrame(construction_status).to_csv(output / 'construction_status.csv', index=False)
        print('Construction only completed. No estimator or residual selector was called.', flush=True)
        return
    pd.DataFrame(results, columns=RESULT_COLUMNS).to_csv(output / 'spec_results.csv', index=False)
    pd.DataFrame(f_tests, columns=F_COLUMNS).to_csv(output / 'f_tests.csv', index=False)
    # Stream diagnostics so failures are retained and memory remains bounded.
    import csv
    with (output / 'influence.csv').open('w', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=INFLUENCE_COLUMNS)
        writer.writeheader()
        for row in influence_diagnostics(base_samples, grid):
            writer.writerow(row)
    print('All specifications, algebraic checks and influence deletions completed.', flush=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--grid', default='grid.json')
    parser.add_argument('--data-dir', default='data')
    parser.add_argument('--out', default='out')
    parser.add_argument('--construct-only', action='store_true',
                        help='Build every sample; never fit models or select residual outliers')
    args = parser.parse_args(argv)
    grid = json.loads(local_path(args.grid).read_text())
    if set(grid['models']) != set(MODEL_TERMS):
        raise ValueError('Grid model names differ from implemented manifest models')
    inputs = Inputs(local_path(args.data_dir))
    run(grid, inputs, local_path(args.out), args.construct_only)


if __name__ == '__main__':
    main()
