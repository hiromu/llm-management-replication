"""Task 2: country-year inputs (raw, unstandardized), 24 countries x 1998-2008.

Run from the study root:  ~/.venv/bin/python -I registry/construction/scripts/build_country_year.py
Reads only data/raw/<source_id>/ files (read-only). Writes data/derived/country_year_inputs.csv,
data/derived/country_year_lineage.csv and registry/construction/hdr_parsed_rows.csv (audit of parsed PDF lines).
No model fitting, no correlations, no summaries.
"""
import csv, html, json, math, os, re, subprocess, sys, tempfile
import numpy as np, pandas as pd, openpyxl

RAW = 'data/raw'
OUT = 'data/derived'
PDFTOTEXT = '/opt/homebrew/bin/pdftotext'
YEARS = list(range(1998, 2009))
ISO = 'AUS AUT BEL CAN CZE DNK FIN FRA DEU GRC ISL IRL ITA JPN NLD NZL NOR POL PRT ESP SWE CHE GBR USA'.split()
NAMES = {'AUS': ['Australia'], 'AUT': ['Austria'], 'BEL': ['Belgium'], 'CAN': ['Canada'],
         'CZE': ['Czech Republic', 'Czechia'], 'DNK': ['Denmark'], 'FIN': ['Finland'], 'FRA': ['France'],
         'DEU': ['Germany'], 'GRC': ['Greece'], 'ISL': ['Iceland'], 'IRL': ['Ireland'], 'ITA': ['Italy'],
         'JPN': ['Japan'], 'NLD': ['Netherlands'], 'NZL': ['New Zealand'], 'NOR': ['Norway'], 'POL': ['Poland'],
         'PRT': ['Portugal'], 'ESP': ['Spain'], 'SWE': ['Sweden'], 'CHE': ['Switzerland'],
         'GBR': ['United Kingdom'], 'USA': ['United States']}
name2iso = {n: k for k, v in NAMES.items() for n in v}
COLS = ['leave_fte_weeks', 'leave_fre_oecd', 'childcare_pct_gdp_annual', 'childcare_interp',
        'pt_common_employees_women', 'pt_national_women', 'pt_common_total_women', 'gdp_pc_ppp',
        'gdp_index_undp', 'unemployment_rate', 'epl_overall', 'women_managers_pct', 'fertility_rate']

table = {(i, y): {c: None for c in COLS} for i in ISO for y in YEARS}
lineage = []


def put(iso, year, col, value, source_id, file, loc, rule, flags=''):
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return
    table[(iso, year)][col] = float(value)
    lineage.append(dict(iso3=iso, year=year, column=col, value=repr(float(value)), source_id=source_id,
                        file=file, location=loc, rule=rule, flags=flags))


def num(v):
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return float(v)
    s = str(v).strip()
    try:
        return float(s)
    except ValueError:
        return None


def pdftext(path):
    with tempfile.TemporaryDirectory() as td:
        out = os.path.join(td, 'o.txt')
        subprocess.run([PDFTOTEXT, '-layout', path, out], check=True)
        return open(out, encoding='utf-8', errors='replace').read().split('\n')


def html_lines(path):
    t = open(path, encoding='utf-8', errors='replace').read()
    t = re.sub(r'(?is)<(script|style).*?</\1>', '', t)
    t = re.sub(r'(?i)<br\s*/?>|</p>|</tr>|</div>|</h\d>|</li>', '\n', t)
    t = re.sub(r'<[^>]+>', ' ', t)
    t = html.unescape(t)
    ls = [re.sub(r'[ \t\xa0]+', ' ', l).strip() for l in t.split('\n')]
    return [l for l in ls if l]


# ---------------------------------------------------------------- PF2.5 weeks of paid leave W(y)
PF25 = f'{RAW}/oecd_family_database/PF2_5_Trends_in_leave_entitlements_around_childbirth.xlsx'
wb = openpyxl.load_workbook(PF25, read_only=True, data_only=True)
ws = wb['Time-Series']
hdr = None
W, Wraw, Wrow = {}, {}, {}
for rn, r in enumerate(ws.iter_rows(values_only=True), start=1):
    if rn == 1:
        hdr = list(r)
        tp = hdr.index('Total_paid')
        continue
    if r[0] in name2iso and isinstance(r[1], int):
        iso = name2iso[r[0]]
        Wraw[(iso, r[1])] = r[tp]
        Wrow[(iso, r[1])] = rn
        v = r[tp]
        W[(iso, r[1])] = float(v) if isinstance(v, (int, float)) else None


def W_at(iso, y):
    """W(y); if missing (non-numeric), carry nearest year with numeric W (ties -> earlier)."""
    if W.get((iso, y)) is not None:
        return W[(iso, y)], y, ''
    cands = sorted([yy for (ii, yy), v in W.items() if ii == iso and v is not None], key=lambda yy: (abs(yy - y), yy))
    if not cands:
        return None, None, 'no_numeric_W'
    return W[(iso, cands[0])], cands[0], f'W_carried_from_{cands[0]}'


# ---------------------------------------------------------------- CEPR Table 1 (mothers' FTE paid leave, maximum)
CEPR = f'{RAW}/cepr_parental_leave/parental_2008_09.pdf'
cl = pdftext(CEPR)
i0 = next(i for i, l in enumerate(cl) if 'Minimum and Maximum Parental Leave Allotments, in Weeks of FTE Paid Leave' in l)
cepr = {}
for l in cl[i0:i0 + 40]:
    m = re.match(r'^\s*([A-Z][A-Za-z ]+?)\s{2,}([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*$', l)
    if m and m.group(1).strip() in name2iso:
        cepr[name2iso[m.group(1).strip()]] = (float(m.group(4)), l.strip())
assert len(cepr) == 21, cepr.keys()
REF_YEAR = 2008  # report: "as of June 2008"; detailed appendix: "as of July 2008"
cepr_text_check = {  # mothers' FTE values stated in report text (rounded weeks) for cross-check
    'DEU': 42, 'SWE': 40, 'NOR': 38, 'GRC': 34, 'CAN': 29, 'FIN': 29, 'JPN': 26}
cepr_flags = {}
for iso, t in cepr_text_check.items():
    if abs(round(cepr[iso][0]) - t) > 0.5:
        cepr_flags[iso] = (f'CEPR_internal_discrepancy: Table 1 mothers maximum {cepr[iso][0]} vs report text/Figure 4 '
                           f'{t} weeks; Table 1 used')

for iso in cepr:
    fte_ref = cepr[iso][0]
    wref, wref_y, wref_note = W_at(iso, REF_YEAR)
    for y in YEARS:
        wy, wy_y, wy_note = W_at(iso, y)
        flags = [f for f in [wy_note, cepr_flags.get(iso, '')] if f]
        raw_y, raw_ref = Wraw.get((iso, y)), Wraw.get((iso, REF_YEAR))
        if iso == 'FRA':
            # PF2.5 Total_paid is text 'a / b' (two entitlements, varies with birth order); no single numeric W.
            if raw_y == raw_ref:
                put(iso, y, 'leave_fte_weeks', fte_ref, 'cepr_parental_leave; oecd_family_database',
                    'parental_2008_09.pdf; PF2_5_Trends_in_leave_entitlements_around_childbirth.xlsx',
                    f'CEPR Table 1 line: "{cepr[iso][1]}"; PF2.5 Time-Series row {Wrow[(iso, y)]} Total_paid="{raw_y}" (ref row {Wrow[(iso, REF_YEAR)]} "{raw_ref}")',
                    'rule (a): FTE = CEPR_FTE x W(y)/W(2008); both PF2.5 text components identical to 2008 so ratio = 1',
                    'FRA_PF25_text_entry_ratio_1_by_identity')
            continue
        if wy is None or wref is None:
            continue
        if wref == 0:
            if wy == 0 and fte_ref == 0:
                put(iso, y, 'leave_fte_weeks', 0.0, 'cepr_parental_leave; oecd_family_database',
                    'parental_2008_09.pdf; PF2_5_Trends_in_leave_entitlements_around_childbirth.xlsx',
                    f'CEPR Table 1 line: "{cepr[iso][1]}"; PF2.5 Time-Series row {Wrow[(iso, wy_y)]} Total_paid={wy}',
                    'rule (a) ratio undefined (W(ref)=0); W(y)=0 paid weeks and CEPR FTE=0 imply FTE=0',
                    ';'.join(flags + ['zero_paid_weeks_ratio_undefined']))
            continue
        val = fte_ref * wy / wref
        put(iso, y, 'leave_fte_weeks', val, 'cepr_parental_leave; oecd_family_database',
            'parental_2008_09.pdf; PF2_5_Trends_in_leave_entitlements_around_childbirth.xlsx',
            f'CEPR Table 1 line: "{cepr[iso][1]}"; PF2.5 Time-Series row {Wrow[(iso, wy_y)]} Total_paid={wy}; ref row {Wrow[(iso, wref_y)]} Total_paid={wref}',
            f'rule (a): FTE = {fte_ref} x W({y})/W({REF_YEAR})', ';'.join(flags))

# ---------------------------------------------------------------- ILO-based FTE for CZE, ISL, POL
ILO = f'{RAW}/ilo_travail_maternity'
ilo_inputs = {}
# Iceland: 2009 edition (LAST UPDATE 22 February 2009). Maternity benefit and parental-leave benefit both 80 percent.
isl = html_lines(f'{ILO}/travail_maternity_2009_IS.html')
isl_lines = [l for l in isl if l.startswith('80 percent of the average wage (employed persons).')]
assert len(isl_lines) >= 2, isl_lines
isl_hist = [l for l in isl if re.match(r'^(2004 : Eighty percent|1998 : Flat rate|1994 : One hundred percent)$', l)]
assert len(isl_hist) == 3
ilo_inputs['ISL'] = dict(rate=0.80, file='travail_maternity_2009_IS.html',
                         text='Maternity leave benefits Amount: "80 percent of the average wage (employed persons)."; '
                              'Parental leave benefits (3 months) Amount: "80 percent of the average wage (employed persons)."',
                         hist='; '.join(isl_hist))
# Poland: 2009 edition (LAST UPDATE 10 December 2009; capture generated 26 Aug 2012). Maternity benefit 100%.
pl = html_lines(f'{ILO}/travail_maternity_2009_PL.html')
i = max(k for k, l in enumerate(pl) if l == 'Maternity leave benefits')  # report body (last occurrence; earlier ones are search-form labels)
assert pl[i + 1] == 'Duration' and pl[i + 3] == 'Amount' and pl[i + 4].startswith('100%'), pl[i:i + 6]
ilo_inputs['POL'] = dict(rate=1.00, file='travail_maternity_2009_PL.html', text=f'Maternity leave benefits Amount: "{pl[i + 4]}"',
                         hist='; '.join(l for l in pl if re.match(r'^(2004|1998|1994) : One hundred percent$', l)))
# Czech Republic: 2011 edition. Maternity benefit percentage; parental allowance flat monthly CZK amounts.
cz = html_lines(f'{ILO}/travail_maternity_2011_CZ.html')
cz_par = [l for l in cz if l.startswith('Parental allowance is provided at four rates that are set at fixed monthly amounts')]
cz_mat = [l for l in cz if l.startswith('From the first calendar day, the maternity benefit amount is 60%')]
assert cz_par and cz_mat

for iso in ['ISL', 'POL']:
    d = ilo_inputs[iso]
    for y in YEARS:
        wy, wy_y, wy_note = W_at(iso, y)
        if wy is None:
            continue
        flags = [wy_note] if wy_note else []
        comp = ''
        if iso == 'POL':
            mp = None
            for rn2, r in enumerate(openpyxl.load_workbook(PF25, read_only=True, data_only=True)['Time-Series'].iter_rows(values_only=True), start=1):
                if rn2 == Wrow[(iso, wy_y)]:
                    mp, pp = r[hdr.index('Maternity_paid')], r[hdr.index('Parental_paid')]
                    break
            assert float(mp) == wy and float(pp) == 0, (mp, pp, wy)
            comp = f'PF2.5 W consists only of paid maternity weeks (Maternity_paid={mp}, Parental_paid={pp}); rate 100% applies to all of W'
        else:
            comp = 'PF2.5 W = paid maternity + paid parental weeks; both components 80% -> duration-weighted rate 80%'
            if y < 2004:
                flags.append('ISL_rate_pre2004_uncertain: ILO historical data list 1998 maternity benefit as flat rate, 2004 as 80%; switch date not stated; single 2009-edition rate applied')
        put(iso, y, 'leave_fte_weeks', wy * d['rate'], 'oecd_family_database; ilo_travail_maternity',
            f'PF2_5_Trends_in_leave_entitlements_around_childbirth.xlsx; {d["file"]}',
            f'PF2.5 Time-Series row {Wrow[(iso, wy_y)]} Total_paid={wy}; ILO {d["text"]}; ILO historical: {d["hist"]}',
            f'rule (b): FTE = W(y) x {d["rate"]}; {comp}', ';'.join(flags))

# ---------------------------------------------------------------- PF3.1 childcare spending
PF31 = f'{RAW}/oecd_family_database/PF3_1_Public_spending_on_childcare_and_early_education.xlsx'
ws = openpyxl.load_workbook(PF31, read_only=True, data_only=True)['Time-series']
rows = list(ws.iter_rows(values_only=True))
pf31_title = ' | '.join(str(x) for x in (rows[0][0], rows[1][0]))
yh = [str(x) if x is not None else None for x in rows[3]]
cc = {}
for rn, r in enumerate(rows, start=1):
    if r[0] in name2iso:
        iso = name2iso[r[0]]
        for y in YEARS:
            v = num(r[yh.index(str(y))])
            cc[(iso, y)] = v
            note = r[1] if r[1] else ''
            put(iso, y, 'childcare_pct_gdp_annual', v, 'oecd_family_database', 'PF3_1_Public_spending_on_childcare_and_early_education.xlsx',
                f'sheet Time-series row {rn} col {y}', 'total public ECEC spending, % GDP (childcare + pre-primary; no annual childcare-only component in file)',
                f'concept_total_ECEC{";note=" + str(note) if note else ""}')
for iso in ISO:
    def pick(target):
        if cc.get((iso, target)) is not None:
            return cc[(iso, target)], target, ''
        cands = sorted([y for y in range(1990, 2015) if cc.get((iso, y)) is not None], key=lambda y: (abs(y - target), y))
        return (cc[(iso, cands[0])], cands[0], f'{target}_missing_used_{cands[0]}') if cands else (None, None, 'none')
    v05, y05, f05 = pick(2005)
    v07, y07, f07 = pick(2007)
    for y in YEARS:
        if y <= 2005:
            v, src, fl = v05, f'{y05}', f05
            rule = 'childcare_interp: 1998-2005 = 2005 value'
        elif y == 2006:
            v = (v05 + v07) / 2 if (v05 is not None and v07 is not None) else None
            src, fl = f'mean({y05},{y07})', ';'.join(x for x in [f05, f07] if x)
            rule = 'childcare_interp: 2006 = mean(2005, 2007)'
        else:
            v, src, fl = v07, f'{y07}', f07
            rule = 'childcare_interp: 2007-2008 = 2007 value'
        put(iso, y, 'childcare_interp', v, 'oecd_family_database', 'PF3_1_Public_spending_on_childcare_and_early_education.xlsx',
            f'sheet Time-series, source year(s) {src}', rule, ';'.join(x for x in ['concept_total_ECEC', fl] if x))

# ---------------------------------------------------------------- FTPT part-time incidence
def ftpt(path):
    d = pd.read_csv(path, dtype=str)
    d = d[(d.MEASURE == 'EMP') & (d.WORK_TIME_ARNGMNT == 'PT') & (d.UNIT_MEASURE == 'PT_POP_SUB')]
    d = d.assign(TIME_PERIOD=d.TIME_PERIOD.astype(int), OBS_VALUE=d.OBS_VALUE.astype(float))
    return d
FC = f'{RAW}/oecd_ftpt/OECD.ELS.SAE_DSD_FTPT@DF_FTPT_COMMON_INC_1.0.csv'
FN = f'{RAW}/oecd_ftpt/OECD.ELS.SAE_DSD_FTPT@DF_FTPT_NATIONAL_INC_1.0.csv'
dc, dn = ftpt(FC), ftpt(FN)
# sanity: MEASURE EMP_PT (gender composition) for SEX=_T equals 100 -> EMP/PT is the incidence
chk = pd.read_csv(FC, dtype=str)
chk = chk[(chk.MEASURE == 'EMP_PT') & (chk.SEX == '_T')].OBS_VALUE.astype(float)
assert ((chk - 100).abs() < 1e-6).all()

def ft_get(d, iso, y, ws_, age='_T'):
    s = d[(d.REF_AREA == iso) & (d.TIME_PERIOD == y) & (d.SEX == 'F') & (d.WORKER_STATUS == ws_) & (d.AGE == age)]
    assert len(s) <= 1
    return (s.OBS_VALUE.iloc[0], s.OBS_STATUS.iloc[0]) if len(s) else (None, None)

for iso in ISO:
    for y in YEARS:
        v, st = ft_get(dc, iso, y, 'ICSE93_1')
        if v is not None:
            put(iso, y, 'pt_common_employees_women', v, 'oecd_ftpt', os.path.basename(FC),
                'MEASURE=EMP;WORK_TIME_ARNGMNT=PT;SEX=F;WORKER_STATUS=ICSE93_1;AGE=_T;FREQ=A', 'common definition (<30 usual hours), women employees, all ages (15+)', f'OBS_STATUS={st}')
        elif iso == 'JPN':
            v2, st2 = ft_get(dn, iso, y, '_T')
            put(iso, y, 'pt_common_employees_women', v2, 'oecd_ftpt', os.path.basename(FN),
                'MEASURE=EMP;WORK_TIME_ARNGMNT=PT;SEX=F;WORKER_STATUS=_T;AGE=_T;FREQ=A',
                'JPN substitute: national-definition women part-time incidence (total employment; employee series not available for JPN)',
                f'JPN_national_definition_substitute;employment_basis_total;OBS_STATUS={st2}')
        v, st = ft_get(dn, iso, y, '_T')
        put(iso, y, 'pt_national_women', v, 'oecd_ftpt', os.path.basename(FN),
            'MEASURE=EMP;WORK_TIME_ARNGMNT=PT;SEX=F;WORKER_STATUS=_T;AGE=_T;FREQ=A', 'national definition, women, total employment, all ages', f'OBS_STATUS={st}')
        v, st = ft_get(dc, iso, y, '_T')
        put(iso, y, 'pt_common_total_women', v, 'oecd_ftpt', os.path.basename(FC),
            'MEASURE=EMP;WORK_TIME_ARNGMNT=PT;SEX=F;WORKER_STATUS=_T;AGE=_T;FREQ=A', 'common definition, women, total employment, all ages (15+)', f'OBS_STATUS={st}')

# ---------------------------------------------------------------- WDI GDP per capita PPP and UNDP-style GDP index
WDI = f'{RAW}/worldbank_wdi_gdppc/NY.GDP.PCAP.PP.CD_24countries_1995-2012.json'
wdi = json.load(open(WDI))
for rec in wdi[1]:
    iso, y, v = rec['countryiso3code'], int(rec['date']), rec['value']
    if iso in ISO and y in YEARS and v is not None:
        put(iso, y, 'gdp_pc_ppp', v, 'worldbank_wdi_gdppc', os.path.basename(WDI), f'indicator NY.GDP.PCAP.PP.CD date={y}',
            'WDI GDP per capita PPP current international $ (lastupdated ' + wdi[0].get('lastupdated', '') + ')')
        gi = (math.log(v) - math.log(100)) / (math.log(40000) - math.log(100))
        put(iso, y, 'gdp_index_undp', min(gi, 1.0), 'worldbank_wdi_gdppc', os.path.basename(WDI), f'indicator NY.GDP.PCAP.PP.CD date={y}',
            '(ln(gdp_pc_ppp)-ln(100))/(ln(40000)-ln(100)), capped at 1', 'capped_at_1' if gi > 1 else '')

# ---------------------------------------------------------------- Unemployment
UF = f'{RAW}/oecd_unemployment/OECD.SDD.TPS_DSD_LFS@DF_IALFS_UNE_M_1.0_annual.csv'
du = pd.read_csv(UF, dtype=str)
du = du[(du.FREQ == 'A') & (du.SEX == '_T') & (du.AGE == 'Y_GE15') & (du.MEASURE == 'UNE_LF_M')]
LF = f'{RAW}/oecd_lfs_indicators/OECD.ELS.SAE_DSD_LFS@DF_LFS_INDIC_1.1.csv'
dl = pd.read_csv(LF, dtype=str)
dl = dl[(dl.MEASURE == 'UNE_RATE') & (dl.SEX == '_T') & (dl.AGE == 'Y15T64')]
for iso in ISO:
    for y in YEARS:
        got = False
        for adj in ['N', 'Y']:
            s = du[(du.REF_AREA == iso) & (du.TIME_PERIOD == str(y)) & (du.ADJUSTMENT == adj)]
            if len(s):
                assert len(s) == 1
                put(iso, y, 'unemployment_rate', float(s.OBS_VALUE.iloc[0]), 'oecd_unemployment', os.path.basename(UF),
                    f'FREQ=A;MEASURE=UNE_LF_M;SEX=_T;AGE=Y_GE15;ADJUSTMENT={adj};TIME_PERIOD={y}',
                    'OECD harmonised unemployment rate, annual, total, 15+',
                    ';'.join(x for x in [f'OBS_STATUS={s.OBS_STATUS.iloc[0]}', 'adjusted_series_used_no_unadjusted' if adj == 'Y' else ''] if x))
                got = True
                break
        if not got:
            s = dl[(dl.REF_AREA == iso) & (dl.TIME_PERIOD == str(y))]
            if len(s):
                assert len(s) == 1
                put(iso, y, 'unemployment_rate', float(s.OBS_VALUE.iloc[0]), 'oecd_lfs_indicators', os.path.basename(LF),
                    f'MEASURE=UNE_RATE;SEX=_T;AGE=Y15T64;TIME_PERIOD={y}',
                    'fallback: OECD LFS indicators unemployment rate, total, closest age group 15-64 (no 15+ series in file)',
                    f'fallback_LFS_UNE_RATE_15_64;OBS_STATUS={s.OBS_STATUS.iloc[0]}')

# ---------------------------------------------------------------- EPL
EF = f'{RAW}/oecd_epl/OECD.ELS.JAI_DSD_EPL@DF_EPL_1.0.csv'
de = pd.read_csv(EF, dtype=str)
de = de[de.VERSION == 'VERSION1']
def epl(iso, y, m):
    s = de[(de.REF_AREA == iso) & (de.TIME_PERIOD == str(y)) & (de.MEASURE == m)]
    assert len(s) <= 1
    return float(s.OBS_VALUE.iloc[0]) if len(s) else None
for iso in ISO:
    yrs_ov = sorted(int(t) for t in de[(de.REF_AREA == iso) & (de.MEASURE == 'EPL_OV')].TIME_PERIOD)
    for y in YEARS:
        v = epl(iso, y, 'EPL_OV')
        if v is not None:
            put(iso, y, 'epl_overall', v, 'oecd_epl', os.path.basename(EF), f'MEASURE=EPL_OV;VERSION=VERSION1;TIME_PERIOD={y}', 'EPL_OV version 1')
            continue
        r_, t_ = epl(iso, y, 'EPL_R'), epl(iso, y, 'EPL_T')
        if r_ is not None and t_ is not None:
            put(iso, y, 'epl_overall', (r_ + t_) / 2, 'oecd_epl', os.path.basename(EF), f'MEASURE=EPL_R,EPL_T;VERSION=VERSION1;TIME_PERIOD={y}',
                'mean of EPL_R and EPL_T version 1 (EPL_OV v1 missing)', 'mean_R_T_fallback')
            continue
        if iso == 'ISL' and yrs_ov and y < yrs_ov[0]:
            v0 = epl(iso, yrs_ov[0], 'EPL_OV')
            put(iso, y, 'epl_overall', v0, 'oecd_epl', os.path.basename(EF), f'MEASURE=EPL_OV;VERSION=VERSION1;TIME_PERIOD={yrs_ov[0]}',
                f'Iceland: first available EPL_OV v1 value ({yrs_ov[0]}) carried back', f'ISL_carried_back_from_{yrs_ov[0]}')

# ---------------------------------------------------------------- Fertility SF2.1
SF = f'{RAW}/oecd_family_database/SF_2_1_Fertility_rates.xlsx'
rows = list(openpyxl.load_workbook(SF, read_only=True, data_only=True)['Total Fertility Rates'].iter_rows(values_only=True))
yh = [str(x).strip() if x is not None else None for x in rows[3]]
for rn, r in enumerate(rows, start=1):
    if r[0] in name2iso:
        iso = name2iso[r[0]]
        for y in YEARS:
            if str(y) in yh:
                put(iso, y, 'fertility_rate', num(r[yh.index(str(y))]), 'oecd_family_database', os.path.basename(SF),
                    f'sheet Total Fertility Rates row {rn} col {y}', 'total fertility rate')

# ---------------------------------------------------------------- UNDP HDR female legislators, senior officials and managers
HDR = {2004: 'human-development-report-2004-english.pdf', 2005: 'human-development-report-2005-english.pdf',
       2006: 'human-development-report-2006-english.pdf', 2007: '2008-english.pdf', 2009: 'human-development-report-2009-english.pdf'}
ANCHOR = {2004: r'Seats in parliament\s+senior officials\s+professional and', 2005: r'Gender empowerment measure\s+Seats in parliament',
          2006: r'Gender empowerment measure\s+Seats in parliament', 2007: r'Gender empowerment measure\s+Seats in parliament',
          2009: r'TABLE\s+Gender empowerment measure and its components'}
TOK = re.compile(r'^(\.\.|—|–|\(\.\)|\d[\d,]*(?:\.\d+)?)([a-z](?:,\s?[a-z])*)?$')
hdr_vals, parsed_rows = {}, []
for ed, fn in HDR.items():
    L = pdftext(f'{RAW}/undp_hdr/{fn}')
    a = next(i for i, l in enumerate(L) if re.search(ANCHOR[ed], l))
    found = {}
    for li in range(a, min(a + 1500, len(L))):
        l = L[li]
        for nm, iso in name2iso.items():
            if iso in found:
                continue
            m = re.match(r'^\s*\d+\s+' + re.escape(nm) + r'\s{2,}(.*)$', l)
            if not m:
                continue
            raw = m.group(1).split()
            toks = []
            for t in raw:
                if re.fullmatch(r'[a-z](,[a-z])*,?', t) and toks:
                    toks[-1] += t
                else:
                    toks.append(t)
            vals = []
            for t in toks:
                mm = TOK.match(t.replace(',', '') if re.fullmatch(r'\d[\d,]*(\.\d+)?[a-z,]*', t) else t)
                if not mm:
                    mm2 = re.match(r'^(\.\.|—|–)([a-z](?:,[a-z])*)$', t)
                    vals.append((t, None, None)); continue
                core, fnote = mm.group(1), mm.group(2)
                vals.append((t, None if core in ('..', '—', '–', '(.)') else float(core), fnote))
            # columns: GEM rank, GEM value, seats, managers, professional, ratio
            if len(vals) < 6:
                raise SystemExit(f'HDR {ed} {iso}: unexpected token count: {l}')
            gem_val = vals[1]
            assert gem_val[0] == '..' or re.fullmatch(r'0\.\d{3}', gem_val[0]), (ed, iso, l)
            found[iso] = (li + 1, l.strip(), vals[3])
    missing = [i for i in ISO if i not in found]
    assert not missing, (ed, missing)
    for iso, (ln, line, (tok, v, fnote)) in found.items():
        hdr_vals[(ed, iso)] = (v, tok, fnote, ln, line)
        parsed_rows.append(dict(edition=ed, file=fn, iso3=iso, text_line_no=ln, managers_token=tok, managers_value=v,
                                footnote=fnote or '', raw_line=line))
EDMAP = {1998: 2004, 1999: 2004, 2000: 2004, 2001: 2004, 2002: 2004, 2003: 2005, 2004: 2006, 2005: 2007, 2006: 2007, 2007: 2009, 2008: 2009}
EDS = sorted(HDR)
for iso in ISO:
    for y in YEARS:
        ed = EDMAP[y]
        v = hdr_vals[(ed, iso)][0]
        used, fl = ed, ''
        if v is None:
            cands = sorted([e for e in EDS if hdr_vals[(e, iso)][0] is not None], key=lambda e: (abs(e - ed), e))
            if not cands:
                continue
            used = cands[0]
            fl = f'nearest_edition_fallback: HDR {ed if ed != 2007 else "2007/2008"} has "{hdr_vals[(ed, iso)][1]}"; used HDR {used if used != 2007 else "2007/2008"}'
        v, tok, fnote, ln, line = hdr_vals[(used, iso)]
        k = EDS.index(used)
        adj = [hdr_vals[(EDS[j], iso)][0] for j in (k - 1, k + 1) if 0 <= j < len(EDS)]
        jump = ''
        if len(adj) == 2 and all(a is not None and abs(v - a) > 10 for a in adj):
            jump = 'printed_value_rechecked_in_layout_text: departs by >10 points from both adjacent editions'
        flags = ';'.join(x for x in [fl, f'footnote={fnote}' if fnote else '', jump] if x)
        put(iso, y, 'women_managers_pct', v, 'undp_hdr', HDR[used], f'pdftotext -layout line {ln}: "{line}"',
            f'GEM table, column "Female legislators, senior officials and managers (% of total)"; edition map year {y} -> HDR {ed if ed != 2007 else "2007/2008"}', flags)

# ---------------------------------------------------------------- write
out = pd.DataFrame([dict(iso3=i, year=y, **table[(i, y)]) for i in ISO for y in YEARS])
out.to_csv(f'{OUT}/country_year_inputs.csv', index=False, na_rep='', float_format='%.10g')
pd.DataFrame(lineage).to_csv(f'{OUT}/country_year_lineage.csv', index=False, quoting=csv.QUOTE_MINIMAL)
pd.DataFrame(parsed_rows).sort_values(['edition', 'iso3']).to_csv('registry/construction/hdr_parsed_rows.csv', index=False)
json.dump({'cepr_table1_lines': {k: v[1] for k, v in cepr.items()}, 'cepr_flags': cepr_flags, 'pf31_title': pf31_title,
           'cz_ilo_parental_line': cz_par[0], 'cz_ilo_maternity_line': cz_mat[0],
           'W_raw_FRA': {str(y): Wraw[('FRA', y)] for y in YEARS},
           'W_raw_CZE': {str(y): Wraw[('CZE', y)] for y in YEARS}},
          open('registry/construction/leave_inputs_audit.json', 'w'), indent=1, ensure_ascii=False)
# coverage report (emptiness only, no values)
for c in COLS:
    e = out[out[c].isna()]
    print(c, 'empty:', len(e), dict(e.groupby('iso3').year.apply(lambda s: f'{s.min()}-{s.max()}' if len(s) == s.max() - s.min() + 1 else ','.join(map(str, s)))))
