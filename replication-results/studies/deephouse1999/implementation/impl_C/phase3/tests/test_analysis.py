"""Synthetic tests only. No supplied empirical Parquet file is opened here."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
import pandas as pd
from numpy.testing import assert_allclose
from scipy import stats

import analysis as a

ROOT = Path(__file__).resolve().parents[1]
GRID = json.loads((ROOT / 'grid.json').read_text())


def panel(n_banks=12, n_years=8):
    rng = np.random.default_rng(198510)
    n = n_banks * n_years
    d = pd.DataFrame({a.ID: np.repeat(np.arange(1, n_banks + 1), n_years),
                      'year': np.tile(np.arange(1985, 1985 + n_years), n_banks)})
    d['SD'] = rng.uniform(1, 12, n)
    d['SD2'] = d.SD ** 2
    d['MS'] = rng.uniform(.001, .2, n)
    d['TER'] = rng.uniform(.03, .2, n)
    d['RMG'] = d.year.map(dict(zip(sorted(d.year.unique()), rng.normal(size=n_years))))
    d['lag'] = rng.normal(size=n)
    d['y'] = .2 + .3 * d.SD - .01 * d.SD2 + .4 * d.lag + rng.normal(size=n) / np.sqrt(d.MS)
    return d


def synthetic_inputs():
    rng = np.random.default_rng(6113)
    codes = ['2170', '3368', '1766', '1600', '1410', '1975', '1590', '1400',
             '0010', '1350', '0390', '2146', '2145', '2150', '2130', '2155',
             '2143', '2160', '2200', '1420', '2123', '3123', '2165', '1505',
             '1517', '1510', '1545', '2107', '2081', '2080', '0081', '0071', '1755', '1763', '1764']
    rows, financials = [], []
    quarters = pd.period_range('1983Q4', '1992Q4', freq='Q')
    banks = list(range(100001, 100014)) + [995151]
    for year in range(1983, 1993):
        for i, bank in enumerate(banks):
            assets = 800 + i * 120 + (year - 1983) * 29 + rng.uniform(-50, 50)
            ratio = rng.uniform(.007, .025)
            for q in range(1, 5):
                quarter = f'{year}Q{q}'
                if quarter not in quarters.astype(str):
                    continue
                r = {a.ID: bank, 'quarter': quarter, 'CALL8786': 1, 'RSSD9048': 200,
                     'RSSD9331': 1, 'RSSD9050': i + 1, 'RSSD9210': 27,
                     'RSSD9150': 53, 'RSSD9180': 5120, 'RSSD9425': 0,
                     'RIAD4340': assets * (ratio + rng.normal(0, .003)) * q / 4,
                     'RIAD4300': assets * ratio * q / 4,
                     'RIAD4073': assets * rng.uniform(.01, .04) * q / 4,
                     'RIAD4093': assets * rng.uniform(.01, .04) * q / 4}
                values = {code: assets * rng.uniform(.001, .035) for code in codes}
                values.update({'2170': assets, '3368': assets * (.92 + .01 * q),
                               '2200': assets * rng.uniform(.5, .85),
                               '1400': assets * .5, '1410': assets * .12,
                               '1766': assets * rng.uniform(.1, .2), '1975': assets * .08})
                for prefix in ['RCFD', 'RCON']:
                    r.update({prefix + code: value for code, value in values.items()})
                rows.append(r)
            if year >= 1984:
                financials.append({'CERT': i + 1, 'REPDTE': year * 10000 + 1231,
                                   'STALP': 'MN', 'STCNTY': 'Hennepin', 'DEP': assets * .7, 'ROA': ratio * 100})
    call = pd.DataFrame(rows)
    presence = pd.DataFrame([{'item': prefix + code, 'quarter': str(q), 'in_file': 1,
                              'any_nonmissing_mnwi': 1, 'any_nonzero_mnwi': 1}
                             for prefix in ['RCFD', 'RCON'] for code in codes for q in quarters])
    geography = pd.DataFrame([{'area_code': '5120', 'omb_definition_date': date,
                               'definition_vintage': date, 'state_fips': '27', 'county_fips5': '27053'}
                              for date in ['1983-06-27', '1990-06-30']])
    prices = []
    for year in range(1984, 1993):
        for series in ['CPIAUCNS', 'CUUSA211SA0', 'A191RD3A086NBEA']:
            prices.append({'provider': 'FRED', 'series_id': series, 'date': f'{year}-01-01',
                           'frequency': 'annual average' if series == 'CPIAUCNS' else 'as provided',
                           'vintage': 'current', 'value': 100 + (year - 1984) * 3})
        prices.append({'provider': 'FRED', 'series_id': 'CPIAUCNS', 'date': f'{year}-12-01',
                       'frequency': 'as provided', 'vintage': 'current', 'value': 102 + (year - 1984) * 3})
        for month in [1, 4, 7, 10]:
            prices.append({'provider': 'ALFRED', 'series_id': 'GDPDEF', 'date': f'{year}-{month:02}-01',
                           'frequency': 'as provided', 'vintage': '1999-01-01', 'value': 100 + year - 1984 + month / 12})
    frames = dict(call=call, presence=presence, geography=geography,
                  institutions=pd.DataFrame({'CERT': range(1, 15), 'ESTYMD': ['01/01/1980'] * 14}),
                  financials=pd.DataFrame(financials), prices=pd.DataFrame(prices),
                  counties=pd.DataFrame([{'state_abbr': 'MN', 'county_name': 'Hennepin', 'county_fips5': '27053'}]),
                  events=pd.DataFrame(columns=['EFFDATE', 'CHANGECODE_DESC', 'CERT', 'ACQ_CERT', 'SUR_CERT', 'OUT_CERT', 'FRM_CERT']))
    return a.Inputs(frames=frames)


class MatrixTests(unittest.TestCase):
    def setUp(self):
        self.d = panel()
        self.c = GRID['origins']['O_A'].copy()

    def direct(self, model):
        x = np.column_stack([np.ones(len(self.d))] + [self.d[t] for t in a.MODEL_TERMS[model]])
        y, w = self.d.y.to_numpy(), self.d.MS.to_numpy()
        inverse = np.linalg.inv(x.T @ np.diag(w) @ x)
        beta = inverse @ x.T @ np.diag(w) @ y
        sse = (y - x @ beta).T @ np.diag(w) @ (y - x @ beta)
        se = np.sqrt(np.diag(inverse * sse / (len(y) - x.shape[1])))
        return beta, se, sse, x

    def test_wls_and_all_nested_f_against_direct_matrix(self):
        fits = {}
        for model in a.MODEL_TERMS:
            fit = fits[model] = a.fit_model(self.d, model, self.c)
            beta, se, sse, x = self.direct(model)
            assert_allclose(fit.beta, beta, rtol=1e-10, atol=1e-10)
            assert_allclose(fit.se, se, rtol=1e-10)
            self.assertAlmostEqual(fit.sse_w, sse, places=10)
            assert_allclose(fit.p, 2 * stats.t.sf(np.abs(beta / se), len(self.d) - x.shape[1]))
            xw = x * np.sqrt(self.d.MS.to_numpy())[:, None]
            self.assertAlmostEqual(fit.cond_max, np.linalg.cond(xw / np.linalg.norm(xw, axis=0)), places=10)
        for u, r in a.COMPARISONS:
            _, _, su, xu = self.direct(u)
            _, _, sr, xr = self.direct(r)
            q = xu.shape[1] - xr.shape[1]
            df = len(self.d) - xu.shape[1]
            expected = ((sr - su) / q) / (su / df)
            actual = a.nested_f(fits[r], fits[u])
            assert_allclose(actual['F'], expected, rtol=1e-10)
            assert_allclose(actual['p_upper'], stats.f.sf(expected, q, df), rtol=1e-10)

    def test_weight_rescaling_invariance_all_covariances(self):
        for covariance in ['R23.conventional', 'R23.hc1', 'R23.cluster_bank']:
            config = dict(self.c, R23=covariance)
            raw = a.fit_model(self.d, 'M3', config)
            scaled = a.fit_model(self.d, 'M3', dict(config, R24='R24.mean1'))
            assert_allclose(raw.beta, scaled.beta, rtol=1e-10, atol=1e-10)
            assert_allclose(raw.se, scaled.se, rtol=1e-10)
            assert_allclose(scaled.sse_w, raw.sse_w / self.d.MS.mean(), rtol=1e-12)

    def test_centered_basis_backtransform_and_square_only_not_applicable(self):
        with patch('analysis.fit_matrix') as estimator:
            with self.assertRaises(a.NotApplicable):
                a.fit_model(self.d, 'M3_SQ', dict(self.c, R26='R26.centered'))
            estimator.assert_not_called()
        for model in ['M1', 'M2', 'M3']:
            raw = a.fit_model(self.d, model, self.c)
            centered = a.fit_model(self.d, model, dict(self.c, R26='R26.centered'))
            assert_allclose(raw.beta, centered.beta, rtol=1e-10, atol=1e-10)
            assert_allclose(raw.covariance, centered.covariance, rtol=1e-10, atol=1e-10)
            a.check_algebra(raw, centered, 'R26', self.d)

    def test_robust_covariance_direct_sandwich(self):
        for covariance in ['R23.hc1', 'R23.cluster_bank']:
            fit = a.fit_model(self.d, 'M2', dict(self.c, R23=covariance))
            beta, _, _, x = self.direct('M2')
            w = self.d.MS.to_numpy()
            bread = np.linalg.inv(x.T @ (w[:, None] * x))
            scores = x * (w * (self.d.y.to_numpy() - x @ beta))[:, None]
            n, k = x.shape
            if covariance.endswith('hc1'):
                meat = scores.T @ scores * n / (n - k)
            else:
                summed = pd.DataFrame(scores).groupby(self.d[a.ID]).sum().to_numpy()
                g = len(summed)
                meat = summed.T @ summed * g / (g - 1) * (n - 1) / (n - k)
            assert_allclose(fit.covariance, bread @ meat @ bread, rtol=1e-10, atol=1e-10)

    def test_external_studentization_matches_actual_deletions(self):
        fit = a.fit_model(self.d, 'M2', self.c)
        calculated = a.externally_studentized(fit)
        for idx in [0, 11, 44]:
            deleted = a.fit_model(self.d.drop(idx), 'M2', self.c)
            expected = fit.weighted_residual[idx] / np.sqrt(
                deleted.sse_w / deleted.df_resid * (1 - fit.leverage[idx]))
            assert_allclose(calculated[idx], expected)

    def test_ar1_transform_and_matrix_solution_across_gaps(self):
        d = self.d.drop([2, 7, 16]).reset_index(drop=True)
        x, _, _, _ = a.make_design(d, 'M2', self.c)
        w = d.MS.to_numpy()
        xw, yw = x * np.sqrt(w)[:, None], d.y.to_numpy() * np.sqrt(w)
        beta0 = np.linalg.solve(xw.T @ xw, xw.T @ yw)
        residual = yw - xw @ beta0
        prev = a.consecutive_predecessors(d[a.ID], d.year)
        pairs = [(j, p) for j, p in enumerate(prev) if p >= 0]
        rho = sum(residual[j] * residual[p] for j, p in pairs) / sum(residual[p] ** 2 for _, p in pairs)
        rho = np.clip(rho, -1 + 1e-8, 1 - 1e-8)
        transformation = np.zeros((len(d), len(d)))
        for j, p in enumerate(prev):
            if p < 0:
                transformation[j, j] = np.sqrt(1 - rho ** 2)
            else:
                transformation[j, j], transformation[j, p] = 1, -rho
        xt, yt = transformation @ xw, transformation @ yw
        beta = np.linalg.solve(xt.T @ xt, xt.T @ yt)
        cov = np.linalg.inv(xt.T @ xt) * np.sum((yt - xt @ beta) ** 2) / (len(d) - x.shape[1])
        actual = a.fit_model(d, 'M2', dict(self.c, R25='R25.wls_ar1'))
        assert_allclose(actual.beta, beta, rtol=1e-10, atol=1e-10)
        assert_allclose(actual.covariance, cov, rtol=1e-10, atol=1e-10)
        assert_allclose(actual.sse_w, np.sum(w * (d.y - x @ beta) ** 2))

    def test_year_effects_drop_rmg_and_bank_effects_count_k(self):
        year = a.fit_model(self.d, 'M3', dict(self.c, R22='R22.year'))
        self.assertNotIn('RMG', year.terms)
        self.assertEqual(year.k, 7 - 1 + self.d.year.nunique() - 1)
        bank = a.fit_model(self.d, 'M3', dict(self.c, R22='R22.bank'))
        self.assertEqual(bank.k, 7 + self.d[a.ID].nunique() - 1)

    def test_rank_failure_and_different_sample_f_rejected(self):
        with self.assertRaises(a.FitError):
            a.fit_matrix(np.ones((10, 2)), np.arange(10), np.ones(10))
        with self.assertRaises(a.FitError):
            a.nested_f(a.fit_model(self.d, 'M1', self.c), a.fit_model(self.d.drop(0), 'M2', self.c))


class ConstructionTests(unittest.TestCase):
    def test_optional_county_file_only_needed_for_name_lookups(self):
        data = synthetic_inputs()
        with tempfile.TemporaryDirectory(dir=ROOT / 'tests') as directory:
            for key, name in a.FILES.items():
                if key != 'counties':
                    data[key].to_parquet(Path(directory) / (name + '.parquet'))
            loaded = a.Inputs(Path(directory))
            self.assertNotIn('counties', loaded.frames)
            builder = a.Constructor(loaded, GRID)
            for origin, base in GRID['origins'].items():
                sample, _ = builder.construct(base, origin)
                self.assertGreater(len(sample), 0)
                for axis in ['R19', 'R21']:
                    with self.assertRaisesRegex(a.Unavailable, 'county-name lookups'):
                        builder.construct(dict(base, **{axis: axis + '.all_insured'}), origin)
            loaded.frames['financials']['STCNTY'] = '27053'
            for origin, base in GRID['origins'].items():
                for axis in ['R19', 'R21']:
                    sample, _ = builder.construct(dict(base, **{axis: axis + '.all_insured'}), origin)
                    self.assertGreater(len(sample), 0)

    def test_special_codes_and_savings_keep_other_origin_filters(self):
        data = synthetic_inputs()
        template = data['call'].iloc[0].to_dict()
        rows = []
        for charter in [200, 300]:
            for entity in [1, 2]:
                for reporter in [1, 2, 3]:
                    for code in list(range(19)) + [np.nan]:
                        rows.append(dict(template, RSSD9001=len(rows) + 1, RSSD9048=charter,
                                         RSSD9331=entity, CALL8786=reporter, RSSD9425=code))
        data.frames['call'] = pd.DataFrame(rows)
        builder = a.Constructor(data, GRID)
        raw = data['call']
        for origin, base in GRID['origins'].items():
            other = raw.CALL8786.isin([1, 2])
            if origin == 'O_A':
                other &= raw.RSSD9331.eq(1)
            for level in ['R02.no_special', 'R02.add_savings']:
                expected = other.copy()
                if level == 'R02.no_special':
                    expected &= raw.RSSD9048.eq(200) & ~raw.RSSD9425.fillna(0).isin([1, 2, 4, 9])
                audit = a.Audit()
                filtered = builder.filter_records(dict(base, R02=level), origin, audit)
                self.assertEqual(set(filtered[a.ID]), set(raw.loc[expected, a.ID]))
                if level == 'R02.add_savings':
                    note = next(n for n in audit.special if n['kind'] == 'savings_admission')
                    self.assertEqual(note['records'], int((expected & raw.RSSD9048.eq(300)).sum()))
        builder = a.Constructor(synthetic_inputs(), GRID)
        for origin, base in GRID['origins'].items():
            sample, log = builder.construct(dict(base, R02='R02.add_savings'), origin)
            self.assertGreater(len(sample), 0)
            note = next(n for n in log['special_handling'] if n['kind'] == 'savings_admission')
            self.assertEqual(note['records'], 0)
            self.assertIn('No savings records qualify', note['message'])

    def test_market_growth_uses_calendar_predecessor_across_missing_years(self):
        builder = a.Constructor(synthetic_inputs(), GRID)
        c = GRID['origins']['O_A']
        records = builder.filter_records(c, 'O_A', a.Audit())
        annual = builder.annual(records, c, a.Audit())
        for insured in [False, True]:
            reference = annual.loc[annual.year.ne(1986)]
            totals = reference.groupby('year').DEP.sum()
            config = dict(c, R21='R21.all_insured') if insured else c
            with patch.object(builder, 'insured_totals', return_value=totals):
                d = builder.benchmarks(annual, reference, config, a.Audit())
            self.assertTrue(d.loc[d.year.eq(1987), 'RMG'].isna().all())
            prices = builder.deflator(config)
            expected = 100 * ((totals[1988] / prices[1988]) / (totals[1987] / prices[1987]) - 1)
            assert_allclose(d.loc[d.year.eq(1988), 'RMG'], expected)

    def test_strategic_deviation_hand_market(self):
        d = pd.DataFrame({a.ID: [1, 2, 3, 4], 'year': [1984] * 3 + [1985]})
        for col in a.SHARES:
            d[col] = [0., 1., 2., 99.]
        d[a.SHARES[-1]] = [7., 7., 7., 7.]
        sd, zero = a.strategic_deviation(d, d)
        assert_allclose(sd.iloc[:3], [10, 0, 10])
        self.assertTrue(np.isnan(sd.iloc[3]))
        self.assertEqual(zero['1984'], [a.SHARES[-1]])
        pop, _ = a.strategic_deviation(d, d, 'R17.population_sd')
        assert_allclose(pop.iloc[:3], np.array([10, 0, 10]) * np.sqrt(3 / 2))
        missing, _ = a.strategic_deviation(d, d, 'R17.zero_sd_missing')
        self.assertTrue(missing.isna().all())
        d.loc[0, a.SHARES[0]] = np.nan
        sd, _ = a.strategic_deviation(d, d)
        self.assertTrue(np.isnan(sd.iloc[0]))

    def test_lags_do_not_skip_gaps_or_cross_entries(self):
        d = pd.DataFrame({a.ID: [1, 1, 1, 1, 2, 2], 'year': [1984, 1985, 1987, 1988, 1987, 1988],
                          'y': [2, 3, 7, 8, 20, 21]}, index=[10, 4, 18, 2, 0, 1])
        lag = a.calendar_lag(d)
        assert_allclose(lag.to_numpy(), [np.nan, 2, np.nan, 7, np.nan, 20], equal_nan=True)
        self.assertEqual(list(lag.index), list(d.index))
        after = d[~(d[a.ID].eq(1) & d.year.eq(1987))].copy()
        self.assertTrue(np.isnan(a.calendar_lag(after).loc[2]))

    def test_sample_hash_bytes_format_sort_and_empty(self):
        d = pd.DataFrame({a.ID: [20., 3., 100.], 'year': [1985., 1986., 1984.]})
        text = b'100,1984\n20,1985\n3,1986\n'
        self.assertEqual(a.sample_hash(d), hashlib.sha256(text).hexdigest())
        self.assertRegex(a.sample_hash(d), r'^[0-9a-f]{64}$')
        self.assertEqual(a.sample_hash(d.iloc[::-1]), a.sample_hash(d))
        self.assertEqual(a.sample_hash(d.iloc[:0]), hashlib.sha256(b'').hexdigest())
        with self.assertRaises(ValueError):
            a.sample_hash(pd.DataFrame({a.ID: [1.5], 'year': [1984]}))

    def test_quarter_coverage_income_and_named_outlier_lag(self):
        data = synthetic_inputs()
        builder = a.Constructor(data, GRID)
        config = GRID['origins']['O_A'].copy()
        log = a.Audit()
        records = builder.filter_records(config, 'O_A', log)
        annual = builder.annual(records, config, log)
        bank = 100001
        row = annual[(annual[a.ID] == bank) & (annual.year == 1985)].iloc[0]
        records85 = records[(records[a.ID] == bank) & records.year.eq(1985)]
        self.assertAlmostEqual(row.AA, records85.RCFD3368.mean())
        self.assertEqual(row.NI, records85.loc[records85.q.eq(4), 'RIAD4340'].iloc[0])
        sample, _ = builder.construct(config, 'O_A')
        none, _ = builder.construct(dict(config, R10='R10.none'), 'O_A')
        self.assertFalse(((sample[a.ID] == 995151) & (sample.year == 1987)).any())
        for d in [sample, none]:
            lag = d.loc[d[a.ID].eq(995151) & d.year.eq(1988), 'lag'].iloc[0]
            prior_y = none.loc[none[a.ID].eq(995151) & none.year.eq(1987), 'y'].iloc[0]
            self.assertAlmostEqual(lag, prior_y)
        modified = records.copy()
        target = modified[a.ID].eq(bank) & modified.year.eq(1985)
        modified.loc[target & modified.q.ne(4), ['RCFD3368', 'RCON3368']] = np.nan
        one = builder.annual(modified, config, a.Audit())
        self.assertTrue(np.isnan(one.loc[one[a.ID].eq(bank) & one.year.eq(1985), 'AA'].iloc[0]))
        modified.loc[target, ['RCFD3368', 'RCON3368']] = np.nan
        zero = builder.annual(modified, config, a.Audit())
        expected = records.loc[records[a.ID].eq(bank) & (records.year.eq(1985) | (records.year.eq(1984) & records.q.eq(4))), 'RCFD2170'].mean()
        self.assertAlmostEqual(zero.loc[zero[a.ID].eq(bank) & zero.year.eq(1985), 'AA'].iloc[0], expected)
        all4 = builder.annual(modified, dict(config, R05='R05.all4'), a.Audit())
        self.assertTrue(np.isnan(all4.loc[all4[a.ID].eq(bank) & all4.year.eq(1985), 'AA'].iloc[0]))

    def test_day_weighted_assets_require_four_quarters_at_both_origins(self):
        builder = a.Constructor(synthetic_inputs(), GRID)
        for origin, base in GRID['origins'].items():
            config = dict(base, R06='R06.rck_days')
            records = builder.filter_records(config, origin, a.Audit())
            for year, days in [(1984, [91, 91, 92, 92]), (1985, [90, 91, 92, 92])]:
                target = records[a.ID].eq(100001) & records.year.eq(year)
                for count in range(5):
                    with self.subTest(origin=origin, year=year, available_quarters=count):
                        modified = records.copy()
                        for quarter in range(1, 5):
                            modified.loc[target & modified.q.eq(quarter), ['RCFD3368', 'RCON3368']] = (
                                10. * quarter if quarter <= count else np.nan)
                        annual = builder.annual(modified, config, a.Audit())
                        row = annual.loc[annual[a.ID].eq(100001) & annual.year.eq(year)].iloc[0]
                        if count == 4:
                            self.assertAlmostEqual(row.AA, np.dot(days, [10, 20, 30, 40]) / sum(days))
                        else:
                            self.assertTrue(np.isnan(row.AA))
                # An absent record must also prevent a four-quarter mean.
                annual = builder.annual(records.loc[~(target & records.q.eq(2))], config, a.Audit())
                self.assertTrue(annual.loc[annual[a.ID].eq(100001) & annual.year.eq(year), 'AA'].isna().all())
                # C4 requires RCFD, else RCON, independently for each quarter and R05.
                modified = records.copy()
                for quarter in range(1, 5):
                    mask = target & modified.q.eq(quarter)
                    modified.loc[mask, 'RCFD3368'] = 10. * quarter if quarter % 2 else np.nan
                    modified.loc[mask, 'RCON3368'] = 10. * quarter if quarter % 2 == 0 else 999.
                for coverage in ['R05.min2_fallback', 'R05.all4', 'R05.any']:
                    annual = builder.annual(modified, dict(config, R05=coverage), a.Audit())
                    row = annual.loc[annual[a.ID].eq(100001) & annual.year.eq(year)].iloc[0]
                    self.assertAlmostEqual(row.AA, np.dot(days, [10, 20, 30, 40]) / sum(days))

    def test_analytic_reference_includes_exact_1984_lag_sources_and_fits(self):
        for origin, base in GRID['origins'].items():
            data = synthetic_inputs()
            # This bank remains in U_1984 but supplies no first-pass 1985 lag.
            data.frames['call'].loc[data['call'][a.ID].eq(100001)
                                    & data['call'].quarter.eq('1985Q4'), 'RIAD4073'] = np.nan
            builder = a.Constructor(data, GRID)
            pilot, _ = builder.construct(base, origin)
            with patch.object(builder, 'benchmarks', wraps=builder.benchmarks) as benchmarks:
                sample, _ = builder.construct(dict(base, R09='R09.analytic'), origin)
            self.assertEqual(benchmarks.call_count, 2)
            population, reference, config, _ = benchmarks.call_args.args
            expected = set(map(tuple, pilot[a.KEY].to_numpy()))
            expected |= {(bank, 1984) for bank in pilot.loc[pilot.year.eq(1985), a.ID]}
            self.assertEqual(set(map(tuple, reference[a.KEY].to_numpy())), expected)
            self.assertNotIn((100001, 1984), expected)
            self.assertNotIn((995151, 1987), expected)
            self.assertEqual(set(map(tuple, sample[a.KEY].to_numpy())),
                             set(map(tuple, pilot[a.KEY].to_numpy())))
            rebuilt = builder.benchmarks(population, reference, config, a.Audit())
            rebuilt = builder.lags(rebuilt, population, config, a.Audit())
            totals = reference.groupby('year').DEP.sum()
            prices = builder.deflator(config)
            for year in [1985, 1988]:
                growth = 100 * ((totals[year] / prices[year]) / (totals[year - 1] / prices[year - 1]) - 1)
                assert_allclose(sample.loc[sample.year.eq(year), 'RMG'], growth)
            mean84 = reference.loc[reference.year.eq(1984), 'ROA'].mean()
            roa84 = population.loc[population.year.eq(1984)].set_index(a.ID).ROA
            rows85 = sample.loc[sample.year.eq(1985)]
            assert_allclose(rows85.lag, 100 * (rows85[a.ID].map(roa84) - mean84))
            mean87 = reference.loc[reference.year.eq(1987), 'ROA'].mean()
            assert_allclose(rebuilt.loc[rebuilt.year.eq(1987), 'market_roa'], mean87)
            for model in a.MODEL_TERMS:
                fit = a.fit_model(sample, model, config)
                self.assertEqual(fit.n, len(pilot))

    def test_analytic_rebuild_drops_and_logs_undefined_rows_without_reiteration(self):
        for origin, base in GRID['origins'].items():
            data = synthetic_inputs()
            # One first-pass row in 1985 yields undefined sample SD in the rebuild.
            data.frames['call'].loc[data['call'][a.ID].ne(100001)
                                    & data['call'].quarter.eq('1985Q4'), 'RIAD4073'] = np.nan
            builder = a.Constructor(data, GRID)
            pilot, _ = builder.construct(base, origin)
            self.assertEqual(int(pilot.year.eq(1985).sum()), 1)
            sample, log = builder.construct(dict(base, R09='R09.analytic'), origin)
            self.assertFalse(sample.year.eq(1985).any())
            self.assertEqual(len(sample), len(pilot) - 1)
            drop = next(x for x in log['steps'] if x['reason'] == 'analytic rebuild missing/nonfinite SD')
            self.assertEqual(drop['dropped'], 1)
            self.assertEqual(drop['by_year']['1985']['dropped'], 1)
            for model in a.MODEL_TERMS:
                self.assertEqual(a.fit_model(sample, model, base).n, len(sample))

    def test_missingness_zero_rule_and_identity(self):
        data = synthetic_inputs()
        c = GRID['origins']['O_A'].copy()
        builder = a.Constructor(data, GRID)
        records = builder.filter_records(c, 'O_A', a.Audit())
        records.loc[:, 'RCFD0010'] = np.nan
        p = data['presence']
        p.loc[p.item.eq('RCFD0010') & p.quarter.eq('1984Q1'), 'in_file'] = 0
        get = builder.item_getter(records, c, a.Audit())
        result = get('0010')
        self.assertTrue(result[records.quarter.eq('1984Q1')].eq(0).all())
        self.assertTrue(result[records.quarter.eq('1984Q2')].isna().all())
        get = builder.item_getter(records, dict(c, R15='R15.identity_fill'), a.Audit())
        filled = get('0010')
        selected = records.year.ge(1984)
        assert_allclose(filled[selected], records.loc[selected, 'RCFD0081'] + records.loc[selected, 'RCFD0071'])
        records['RCFD1600'] = np.nan
        acceptance = builder.item_getter(records, dict(c, R15='R15.identity_fill'), a.Audit())('1600')
        self.assertTrue(acceptance[records.quarter.eq('1984Q1')].isna().all())
        after_revision = records.quarter.gt('1984Q1')
        assert_allclose(acceptance[after_revision], records.loc[after_revision, 'RCFD1755']
                        + records.loc[after_revision, 'RCFD1766'])

    def test_construct_only_cannot_fit_even_residual_outlier(self):
        data = synthetic_inputs()
        with tempfile.TemporaryDirectory(dir=ROOT / 'tests') as directory:
            with patch('analysis.fit_matrix', side_effect=AssertionError('fitting forbidden')) as fit:
                with contextlib.redirect_stdout(io.StringIO()):
                    a.run(GRID, data, Path(directory), construct_only=True)
                fit.assert_not_called()
            status = pd.read_csv(Path(directory) / 'construction_status.csv')
            self.assertFalse(status.status.eq('failed').any(), status[status.status.eq('failed')].to_dict('records'))
            self.assertFalse((Path(directory) / 'spec_results.csv').exists())

    def test_merger_proforma_and_event_confirmed_continuity(self):
        data = synthetic_inputs()
        data.frames['events'] = pd.DataFrame([
            {'EFFDATE': '1985-06-01', 'CHANGECODE_DESC': 'Merger -Without Assistance',
             'CERT': 2, 'ACQ_CERT': 1, 'SUR_CERT': 1, 'OUT_CERT': 2, 'FRM_CERT': np.nan},
            {'EFFDATE': '1985-03-01', 'CHANGECODE_DESC': 'Change in Chartering Agency',
             'CERT': 9, 'ACQ_CERT': np.nan, 'SUR_CERT': np.nan, 'OUT_CERT': np.nan, 'FRM_CERT': 9}])
        builder = a.Constructor(data, GRID)
        config = GRID['origins']['O_A'].copy()
        d = pd.DataFrame({a.ID: [1, 2, 1, 10, 11], 'RSSD9050': [1, 2, 1, 9, 9],
                          'year': [1984, 1984, 1985, 1984, 1985], 'y': [3., 4., 5., 6., 7.],
                          'market_roa': [.02, .02, .03, .02, .03],
                          'NI': [10., 30., 40., 5., 6.], 'AA': [100., 300., 400., 50., 60.]})
        proforma = builder.lags(d, d, dict(config, R03='R03.proforma'), a.Audit())
        self.assertAlmostEqual(proforma.loc[2, 'lag'], 100 * ((10 + 30) / (100 + 300) - .02))
        continuity = builder.lags(d, d, dict(config, R03='R03.continuity'), a.Audit())
        self.assertEqual(continuity.loc[4, 'lag'], 6.)
        as_reported = builder.lags(d, d, config, a.Audit())
        self.assertTrue(np.isnan(as_reported.loc[4, 'lag']))
        incomplete = d.copy()
        incomplete.loc[1, 'NI'] = np.nan
        missing = builder.lags(d, incomplete, dict(config, R03='R03.proforma'), a.Audit())
        self.assertTrue(np.isnan(missing.loc[2, 'lag']))
        s = panel(3, 4)
        s['RSSD9050'] = s[a.ID]
        selected = builder.select(s, dict(config, R03='R03.drop_merger_years', R10='R10.none'), a.Audit())
        self.assertFalse((selected[a.ID].eq(1) & selected.year.isin([1985, 1986])).any())
        self.assertTrue((selected[a.ID].eq(1) & selected.year.eq(1987)).any())

    def test_stock_timing_day_weights_annualisation_and_record_priority(self):
        data = synthetic_inputs()
        builder = a.Constructor(data, GRID)
        config = GRID['origins']['O_A'].copy()
        record = data['call'].iloc[[0]].copy()
        record['CALL8786'] = 2
        data.frames['call'] = pd.concat([record, data['call']], ignore_index=True)
        audit = a.Audit()
        records = builder.filter_records(config, 'O_A', audit)
        self.assertEqual(len(records), len(data['call']) - 1)
        self.assertTrue(records.CALL8786.eq(1).all())
        self.assertTrue(any(x['kind'] == 'duplicate_records' for x in audit.special))
        target = records[a.ID].eq(100001) & records.year.eq(1985)
        for q in range(1, 5):
            records.loc[target & records.q.eq(q), 'RCFD2170'] = 100. * q
            records.loc[target & records.q.eq(q), 'RCFD1766'] = 5. * q ** 2
            records.loc[target & records.q.eq(q), 'RCFD3368'] = 10. * q
        def target_row(conf):
            frame = builder.annual(records, conf, a.Audit())
            return frame.loc[frame[a.ID].eq(100001) & frame.year.eq(1985)].iloc[0]
        means = target_row(dict(config, R08='R08.mean_of_quarter_shares'))
        ratio = target_row(dict(config, R08='R08.ratio_of_means'))
        self.assertAlmostEqual(means.share_01, np.mean([.05, .10, .15, .20]))
        self.assertAlmostEqual(ratio.share_01, (5 + 20 + 45 + 80) / (100 + 200 + 300 + 400))
        days = target_row(dict(config, R06='R06.rck_days'))
        self.assertAlmostEqual(days.AA, np.dot([90, 91, 92, 92], [10, 20, 30, 40]) / 365)
        unadjusted = target_row(config)
        data.frames['institutions'].loc[data['institutions'].CERT.eq(1), 'ESTYMD'] = '04/10/1985'
        adjusted = target_row(dict(config, R04='R04.annualise'))
        self.assertAlmostEqual(adjusted.NI, unadjusted.NI * 12 / 9)
        self.assertAlmostEqual(adjusted.expenses, unadjusted.expenses * 12 / 9)


class PipelineTests(unittest.TestCase):
    def test_unavailable_inputs_and_runtime_errors_have_distinct_statuses(self):
        specs = list(a.specifications(GRID))[:1]
        for stage in ['construction', 'fit']:
            for exc, expected in [(a.Unavailable('missing input'), 'unavailable'),
                                  (RuntimeError('synthetic runtime error'), 'failed')]:
                target = 'analysis.Constructor.construct' if stage == 'construction' else 'analysis.fit_model'
                with self.subTest(stage=stage, status=expected):
                    with tempfile.TemporaryDirectory(dir=ROOT / 'tests') as directory:
                        with patch('analysis.specifications', return_value=iter(specs)), \
                             patch(target, side_effect=exc), \
                             patch('analysis.influence_diagnostics', return_value=iter([])), \
                             contextlib.redirect_stdout(io.StringIO()):
                            a.run(GRID, synthetic_inputs(), Path(directory))
                        results = pd.read_csv(Path(directory) / 'spec_results.csv')
                        self.assertTrue(results.status.eq(expected).all())

    def test_entire_grid_outputs_checks_and_all_influence_deletions(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'tests') as directory:
            out = Path(directory)
            with contextlib.redirect_stdout(io.StringIO()):
                a.run(GRID, synthetic_inputs(), out)
            results = pd.read_csv(out / 'spec_results.csv')
            expected = {spec[0] for spec in a.specifications(GRID)}
            self.assertEqual(set(results.spec_id), expected)
            self.assertFalse(results.status.eq('failed').any(), results.loc[
                results.status.eq('failed'), ['spec_id', 'model', 'message']].drop_duplicates().to_dict('records'))
            self.assertFalse(results.status.eq('unavailable').any())
            na = results[results.status.eq('not_applicable')]
            self.assertEqual(set(na.spec_id), {'O_A__R26.centered', 'O_B__R26.centered'})
            self.assertEqual(set(na.model), {'M3_SQ'})
            self.assertTrue(na[['estimate', 'se']].isna().all().all())
            for spec in ['O_A', 'O_B', 'O_A__R24.mean1', 'O_B__R24.mean1', 'O_A__R26.centered', 'O_B__R26.centered']:
                self.assertTrue(results.loc[results.spec_id.eq(spec) & ~results.index.isin(na.index), 'status'].eq('ok').all(),
                                results.loc[results.spec_id.eq(spec), ['status', 'message']].to_dict('records'))
            for origin in GRID['origins']:
                no_special = results[results.spec_id.eq(origin + '__R02.no_special')]
                self.assertTrue(no_special.status.eq('ok').all())
                analytic = results[results.spec_id.eq(origin + '__R09.analytic')]
                self.assertTrue(analytic.status.eq('ok').all())
                for effect, variable in [('year', 'year'), ('bank', a.ID)]:
                    rows = results[results.spec_id.eq(origin + '__R22.' + effect)]
                    self.assertTrue(rows.status.eq('ok').all())
                    for model, part in rows.groupby('model'):
                        self.assertEqual(len(part), int(part.k.iloc[0]))
                        self.assertTrue(part.term.str.startswith(variable + '[').any())
                        self.assertTrue(np.isfinite(part[['estimate', 'se', 't', 'p_two_sided']]).all().all())
                self.assertTrue((out / f'construction_log_{origin}.json').is_file())
                descriptive = pd.read_csv(out / f'descriptives_{origin}.csv')
                self.assertEqual(len(descriptive), 14 + 49)
            influence = pd.read_csv(out / 'influence.csv')
            for origin in GRID['origins']:
                sample = pd.read_csv(out / 'samples' / f'{origin}.csv')
                expected_rows = (len(sample) + sample[a.ID].nunique()) * 3
                self.assertEqual(len(influence[influence.origin.eq(origin)]), expected_rows)
                self.assertTrue(influence[influence.origin.eq(origin)].status.eq('ok').all())
                self.assertTrue(results.loc[results.spec_id.eq(origin), 'sample_hash'].eq(a.sample_hash(sample)).all())
            f = pd.read_csv(out / 'f_tests.csv')
            self.assertEqual(len(f[f.spec_id.isin(['O_A', 'O_B'])]), 8)
            self.assertTrue((out / 'environment.txt').is_file())
            centered_f = f[f.spec_id.str.endswith('R26.centered')]
            self.assertTrue(centered_f.loc[centered_f.comparison.eq('M3_SQ vs M1'), 'F'].isna().all())
            self.assertTrue(centered_f.loc[centered_f.comparison.ne('M3_SQ vs M1'), 'F'].notna().all())

    def test_influence_failures_are_retained(self):
        d = panel(2, 3)
        rows = list(a.influence_diagnostics({'O_A': d}, GRID))
        self.assertEqual(len(rows), (6 + 2) * 3)
        self.assertTrue(all(row['status'] == 'failed' for row in rows))


if __name__ == '__main__':
    unittest.main(verbosity=2)
