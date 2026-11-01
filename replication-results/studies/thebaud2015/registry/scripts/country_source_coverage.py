"""Internal coverage check (not for readers): for each newly acquired country-level source, which of the
paper's 24 countries have a non-missing value in each year 2000-2008 for the series that could feed a paper
variable. Writes presence flags only (1 = a value exists, 0 = none). No values are written.
Usage: python -I country_source_coverage.py <study_dir>"""
import sys, os, json, re
import pandas as pd, openpyxl

study = sys.argv[1]
raw = os.path.join(study, "data", "raw")
ISO3 = ["AUS","AUT","BEL","CAN","CZE","DNK","FIN","FRA","DEU","GRC","ISL","IRL","ITA","JPN","NLD","NZL","NOR",
        "POL","PRT","ESP","SWE","CHE","GBR","USA"]
NAMES = {"AUS":"Australia","AUT":"Austria","BEL":"Belgium","CAN":"Canada","CZE":"Czech","DNK":"Denmark",
         "FIN":"Finland","FRA":"France","DEU":"Germany","GRC":"Greece","ISL":"Iceland","IRL":"Ireland","ITA":"Italy",
         "JPN":"Japan","NLD":"Netherlands","NZL":"New Zealand","NOR":"Norway","POL":"Poland","PRT":"Portugal",
         "ESP":"Spain","SWE":"Sweden","CHE":"Switzerland","GBR":"United Kingdom","USA":"United States"}
YEARS = list(range(2000, 2009))
out = {}

def presence_from_long(df, area="REF_AREA", time="TIME_PERIOD", val="OBS_VALUE"):
    df = df[df[val].notna()]
    m = {c: [int(y in set(df.loc[df[area] == c, time].astype(int))) for y in YEARS] for c in ISO3}
    return m

def sdmx(path, **flt):
    d = pd.read_csv(path, low_memory=False)
    for k, v in flt.items():
        d = d[d[k].isin(v if isinstance(v, list) else [v])]
    return d

# OECD part-time incidence, women, employees and total employment, ages 15-64 / total
p = os.path.join(raw, "oecd_ftpt", "OECD.ELS.SAE_DSD_FTPT@DF_FTPT_COMMON_INC_1.0.csv")
for ws, lab in [("ICSE93_1", "employees"), ("_T", "total_employment")]:
    for age in ["Y15T64", "_T"]:
        d = sdmx(p, SEX="F", WORKER_STATUS=ws, WORK_TIME_ARNGMNT="PT", AGE=age)
        out[f"oecd_ftpt common-definition PT incidence, women, {lab}, age {age}"] = presence_from_long(d)
p = os.path.join(raw, "oecd_ftpt", "OECD.ELS.SAE_DSD_FTPT@DF_FTPT_NATIONAL_INC_1.0.csv")
d = sdmx(p, SEX="F", WORK_TIME_ARNGMNT="PT")
out["oecd_ftpt national-definition PT incidence, women (any worker status/age)"] = presence_from_long(d)

# EPL version 1 regular (EPL_OV) and temporary (EPL_T)
p = os.path.join(raw, "oecd_epl", "OECD.ELS.JAI_DSD_EPL@DF_EPL_1.0.csv")
for meas in ["EPL_OV", "EPL_T", "EPL_R", "EPL_CD"]:
    for ver in ["VERSION1", "VERSION2"]:
        out[f"oecd_epl {meas} {ver}"] = presence_from_long(sdmx(p, MEASURE=meas, VERSION=ver))

# Harmonised unemployment rate, annual, total, 15+
p = os.path.join(raw, "oecd_unemployment", "OECD.SDD.TPS_DSD_LFS@DF_IALFS_UNE_M_1.0_annual.csv")
out["oecd_unemployment harmonised rate annual total 15+"] = presence_from_long(sdmx(p, FREQ="A", SEX="_T", AGE="Y_GE15"))

# Union density
p = os.path.join(raw, "oecd_union_density", "OECD.ELS.SAE_DSD_TUD_CBC@DF_TUD_1.0.csv")
out["oecd_union_density TUD"] = presence_from_long(sdmx(p))

# SOCX public ECEC spending % GDP
p = os.path.join(raw, "oecd_socx_family", "OECD.ELS.SPD_DSD_SOCX_AGG@DF_PUB_FAM_1.0.csv")
out["oecd_socx_family public ECEC (TP521) % GDP"] = presence_from_long(sdmx(p, PROGRAMME_TYPE="TP521", UNIT_MEASURE="PT_B1GQ"))
out["oecd_socx_family public maternity/parental leave (TP512) % GDP"] = presence_from_long(sdmx(p, PROGRAMME_TYPE="TP512", UNIT_MEASURE="PT_B1GQ"))

# OECD LFS women's labour force participation 15-64
p = os.path.join(raw, "oecd_lfs_indicators", "OECD.ELS.SAE_DSD_LFS@DF_LFS_INDIC_1.1.csv")
out["oecd_lfs_indicators LF_RATE women 15-64"] = presence_from_long(sdmx(p, MEASURE="LF_RATE", SEX="F", AGE="Y15T64"))

# Family database wide sheets: find rows by country name and year columns
def wide_sheet(path, sheet, year_row_hint="Country"):
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    rows = list(wb[sheet].iter_rows(values_only=True))
    hdr_i = next(i for i, r in enumerate(rows) if r and any(isinstance(c, (int, float)) and 1960 <= c <= 2030 for c in r if c is not None) and sum(1 for c in r if isinstance(c,(int,float)) and 1960<=c<=2030) > 5)
    hdr = rows[hdr_i]
    ycol = {int(c): j for j, c in enumerate(hdr) if isinstance(c, (int, float)) and 1960 <= c <= 2030}
    res = {}
    for c3, nm in NAMES.items():
        r = next((r for r in rows[hdr_i + 1:] if r and any(isinstance(x, str) and x.strip().startswith(nm) for x in r[:3])), None)
        res[c3] = [int(r is not None and y in ycol and isinstance(r[ycol[y]], (int, float))) for y in YEARS]
    return res

fd = os.path.join(raw, "oecd_family_database")
out["oecd_family_database PF3.1 Time-series total public ECEC % GDP"] = wide_sheet(os.path.join(fd, "PF3_1_Public_spending_on_childcare_and_early_education.xlsx"), "Time-series")
out["oecd_family_database SF2.1 total fertility rate"] = wide_sheet(os.path.join(fd, "SF_2_1_Fertility_rates.xlsx"), "Total Fertility Rates")
out["oecd_family_database LMF1.6 PT_Women"] = wide_sheet(os.path.join(fd, "LMF_1_6_Gender_differences_in_employment_outcomes.xlsx"), "PT_Women")
out["oecd_family_database LMF1.6 Managers_Women"] = wide_sheet(os.path.join(fd, "LMF_1_6_Gender_differences_in_employment_outcomes.xlsx"), "Managers_Women")

# PF2.5 long time series: country label rows followed by year rows
wb = openpyxl.load_workbook(os.path.join(fd, "PF2_5_Trends_in_leave_entitlements_around_childbirth.xlsx"), read_only=True, data_only=True)
rows = list(wb["Time-Series"].iter_rows(values_only=True))
col_total_paid = rows[0].index("Total_paid")
res = {c: [0]*len(YEARS) for c in ISO3}
cur = None
for r in rows[2:]:
    if r[0] and isinstance(r[0], str):
        cur = next((c for c, nm in NAMES.items() if r[0].strip().startswith(nm)), None)
    y = r[1]
    if cur and isinstance(y, (int, float)) and int(y) in YEARS and isinstance(r[col_total_paid], (int, float)):
        res[cur][YEARS.index(int(y))] = 1
out["oecd_family_database PF2.5 Total_paid weeks (mothers)"] = res

# World Bank WDI GDP per capita PPP current
j = json.load(open(os.path.join(raw, "worldbank_wdi_gdppc", "NY.GDP.PCAP.PP.CD_24countries_1995-2012.json")))
recs = [x for x in j[1] if x["value"] is not None]
out["worldbank_wdi_gdppc NY.GDP.PCAP.PP.CD"] = {c: [int(any(x["countryiso3code"] == c and int(x["date"]) == y for x in recs)) for y in YEARS] for c in ISO3}

# ILO TRAVAIL archived country reports (2009 and 2011 database editions): file present and substantive
ilo = os.path.join(raw, "ilo_travail_maternity")
ISO2 = dict(zip(ISO3, "AU AT BE CA CZ DK FI FR DE GR IS IE IT JP NL NZ NO PL PT ES SE CH GB US".split()))
def substantive(fp):
    if not os.path.exists(fp): return 0
    s = open(fp, encoding="latin-1").read()
    s = re.sub(r"<script.*?</script>", " ", s, flags=re.S); s = re.sub(r"<[^>]+>", " ", s); s = re.sub(r"\s+", " ", s)
    i = s.find("Zimbabwe"); body = s[i:] if i > 0 else s
    return int(len(body) > 5000)
out["ilo_travail_maternity database edition 2009 / 2011 (presence of substantive country report)"] = {
    c: {"2009": substantive(os.path.join(ilo, f"travail_maternity_2009_{ISO2[c]}.html")),
        "2011": substantive(os.path.join(ilo, f"travail_maternity_2011_{ISO2[c]}.html"))} for c in ISO3}

json.dump({"years": YEARS, "countries": ISO3, "presence": out}, open(os.path.join(study, "registry", "validation", "country_source_coverage_INTERNAL.json"), "w"), indent=1)
for k, v in out.items():
    if "ilo" in k:
        miss = {c: x for c, x in v.items() if not all(x.values())}
        print(k, "-> not substantive:", miss); continue
    full = [c for c in ISO3 if all(v[c])]
    gaps = {c: [y for y, f in zip(YEARS, v[c]) if not f and y >= 2001] for c in ISO3 if not all(v[c][1:])}
    print(f"{k}: complete 2001-2008 for {sum(1 for c in ISO3 if all(v[c][1:]))}/24; gaps(2001-08): {gaps}")
