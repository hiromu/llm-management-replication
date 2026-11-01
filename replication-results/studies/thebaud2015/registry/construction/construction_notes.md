# Data construction notes (thebaud2015)

Role: fresh data-construction context, 2026-10-28. Inputs were only the registered raw files under `data/raw/<source_id>/`, the user-supplied ICPSR file, the registry and the reader dictionaries. The article, supplement, reader outputs, sealed targets and reconciliation files were not opened. No model was fitted and no correlation or summary statistic was computed. Runtime: ~/.venv/bin/python -I (Python 3.13, pandas, numpy, pyreadstat, openpyxl); pdftotext from /opt/homebrew/bin.

Scripts (run from the study root):
- `registry/construction/scripts/build_gem_extract.py` -> `data/derived/gem_extract.csv`, `data/derived/country_codes.csv`
- `registry/construction/scripts/build_country_year.py` -> `data/derived/country_year_inputs.csv`, `data/derived/country_year_lineage.csv`, plus audit files `registry/construction/hdr_parsed_rows.csv` (every parsed HDR table line) and `registry/construction/leave_inputs_audit.json` (CEPR Table 1 lines, ILO lines, PF2.5 text entries)
- `registry/construction/scripts/hash_derived.py` -> `registry/construction/derived_hashes.json`

## Task 1: GEM extract

- Source: `data/supplied/ICPSR_20320/DS0001/20320-0001-Data.sav` (ICPSR 20320 V6), read with pyreadstat. Read only.
- Filter: COUNTRY in the 24 codes below and 2000 <= GEM_YR <= 2008. Records from subnational samples (codes 4401, 4402, 6401, 620, 755, 8601) are not selected because their codes differ.
- All 34 requested variables exist under the requested names; no name differences. Values are the original codes (no recoding, labelled missing codes such as 8/9/99 retained). System-missing is written as an empty cell. Float columns whose non-missing values are all integers are written as integers; weights keep full precision. Column `iso3` added first. Sorted by iso3, GEM_YR, ID_9817_RDM.
- Country codes (`country_codes.csv`): COUNTRY value labels from the SAV were checked for each code. Note that Switzerland is COUNTRY 41 with CTRYALP "SW" and value label "SW:SWITZERLAND"; the United Kingdom is 44 with CTRYALP "UK".

| iso3 | COUNTRY | CTRYALP | iso3 | COUNTRY | CTRYALP |
|---|---|---|---|---|---|
| AUS | 61 | AU | ISL | 354 | IS |
| AUT | 43 | AT | IRL | 353 | IE |
| BEL | 32 | BE | ITA | 39 | IT |
| CAN | 101 | CA | JPN | 81 | JP |
| CZE | 420 | CZ | NLD | 31 | NL |
| DNK | 45 | DK | NZL | 64 | NZ |
| FIN | 358 | FI | NOR | 47 | NO |
| FRA | 33 | FR | POL | 48 | PL |
| DEU | 49 | DE | PRT | 351 | PT |
| GRC | 30 | GR | ESP | 34 | ES |
| CHE | 41 | SW | SWE | 46 | SE |
| GBR | 44 | UK | USA | 1 | US |

## Task 2: country-year inputs (24 x 1998-2008, unstandardized, no lag)

`country_year_inputs.csv` columns: iso3, year, leave_fte_weeks, leave_fre_oecd, childcare_pct_gdp_annual, childcare_interp, pt_common_employees_women, pt_national_women, pt_common_total_women, gdp_pc_ppp, gdp_index_undp, unemployment_rate, epl_overall, women_managers_pct, fertility_rate. Empty = not constructible under the rule. Every non-empty cell has one lineage row.

### leave_fte_weeks

Rule (a), 21 CEPR countries. CEPR value = Table 1 of Ray, Gornick and Schmitt (2008), "Minimum and Maximum Parental Leave Allotments, in Weeks of FTE Paid Leave", column "Mothers' FTE Paid Leave, Maximum" (the leave available to a mother in a couple who takes all transferable leave; this is the quantity plotted in Figure 4 "Total and FTE Paid Leave for Mothers in Couples"). Table 1 gives one decimal, so it was preferred over the rounded figure labels. Policy reference date: the report states policies "as of June 2008"; the detailed appendix (Ray 2008) states "as of July 2008". Reference year = 2008, W(ref) = PF2.5 Total_paid for 2008. W(y) = PF2.5 sheet Time-Series column Total_paid ("Total weeks of paid maternity, parental and home care payments available to mothers"). FTE(y) = CEPR x W(y)/W(2008). The appendix was used to confirm policy descriptions; it does not print per-country FTE numbers. Exact Table 1 lines are in `leave_inputs_audit.json` and in each lineage row.

Decisions and flags:
- DEU (flag CEPR_internal_discrepancy): Table 1 mothers' maximum is 36.6, while the report text and the Figure 4 label give Germany 42 weeks for mothers (42.0 is the couples' value in Table 1). The other six countries named in that text agree with Table 1 after rounding. Table 1 was used. The appendix (14 weeks maternity at 100%, 12 months Elterngeld at 67% per family, 2 further months reserved for the father) does not settle the difference.
- AUS, USA (flag zero_paid_weeks_ratio_undefined): CEPR FTE = 0 and W(2008) = 0, so the ratio is 0/0. W(y) = 0 in every year 1998-2008, and FTE cannot be more than the number of paid weeks, so 0 was entered. For CHE 1998-2004 and NZL 1998-2002, W(y) = 0 with W(2008) > 0, which gives 0 under the rule as written (no flag needed).
- FRA: PF2.5 Total_paid is text ("16.0 / 162.0" for 1998-2003, "42.0 / 162.0" for 2004-2008; two entitlements that depend on birth order). There is no single numeric W, and no year has a numeric value to carry. For 2004-2008 both components equal the 2008 entry, so W(y)/W(2008) = 1 under either reading, and FTE = 21.4 (flag FRA_PF25_text_entry_ratio_1_by_identity). For 1998-2003 the ratio is either 16/42 (first component) or 1 (second component). This cannot be resolved under the rule, so these cells are EMPTY.
- The PF2.5 series is used mechanically, including large one-year steps. Examples: AUT 2008 = 73 against 138 in 2002-2007, which scales earlier years above the CEPR value; NOR 1998 = 38 against 142 in 1999-2005 and 137.67 in 2006-2008; POL 2001 = 26; CZE 2008 = 110. The rate is held at its 2008 level in every year, so changes in payment rates over time are not captured.
- "Carry nearest W" was implemented but never needed: every country other than FRA has numeric W for every year.

Rule (b), CZE, ISL, POL (ILO TRAVAIL archived pages; W(y) from PF2.5 as above):
- ISL: 2009 edition (`travail_maternity_2009_IS.html`, LAST UPDATE 22 February 2009). Maternity leave benefit is "80 percent of the average wage (employed persons)" for 3 months, and the parental leave benefit for the 3 shared months has the same rate. PF2.5 W = Maternity_paid + Parental_paid. The duration-weighted rate is therefore 0.80, and FTE = 0.80 x W(y). Flag ISL_rate_pre2004_uncertain on 1998-2003: the page's historical data give "1998 : Flat rate", "2004 : Eighty percent" (years of data collection). The date of the switch is not on the page. The single edition rate was applied, as in rule (a), which holds rates fixed.
- POL: 2009 edition (`travail_maternity_2009_PL.html`, LAST UPDATE 10 December 2009, capture generated 26 August 2012). Maternity leave benefits Amount "100%" (historical 1994/1998/2004 also 100 percent). The source dictionary describes this page as an empty template, but the archived file does contain this content. PF2.5 W for Poland consists only of paid maternity weeks (Parental_paid = 0 in every year; asserted in the script). So rate = 1.00 and FTE = W(y).
- CZE: EMPTY in every year. PF2.5 W = 28 weeks of paid maternity leave + 186 weeks of parental payments (2008: 28 + 82, long option 188). Maternity benefit is a percentage (2011 edition: 60% of the daily assessment base; 2009 edition and historical data: 69%, up to a ceiling). The parental allowance is a set of fixed monthly CZK amounts (11,400 / 7,600 / 3,800 / 3,000 CZK; 2011 edition line in the audit file). It is flat-rate and the page gives no percentage equivalent. The duration-weighted rate therefore cannot be computed, and the rule says to leave the cell empty. For the record only (not entered), maternity-only components are 28 weeks at 69% (2009 edition) or 60% (2011 edition).

### leave_fre_oecd

EMPTY for all cells. PF2.5 has durations only (no payment rates or FRE). PF2.1 (Table PF2.1.A) reports a full-rate equivalent for the current reference year only, with no historical series.

### childcare_pct_gdp_annual and childcare_interp

PF3.1 sheet "Time-series": "Total public expenditure on early childhood education and care, in per cent of GDP, 1980-2021/22". This covers childcare plus pre-primary education. The annual file has no separate childcare component; the childcare/pre-primary split appears only in Chart PF3.1.A for the latest year. All cells are flagged concept_total_ECEC. The sheet's Note column is empty for all 24 countries. childcare_interp: 1998-2005 = 2005 value; 2006 = mean(2005, 2007); 2007-2008 = 2007 value. 2005 and 2007 are present for all 24 countries, so no nearest-year fallback was used.

### Part-time incidence (oecd_ftpt)

Incidence = MEASURE EMP with WORK_TIME_ARNGMNT PT ("percentage of population in the same subgroup", i.e. part-timers as a share of women's employment). MEASURE EMP_PT is the gender composition of part-time employment; the script asserts that EMP_PT equals 100 for SEX = _T. AGE = _T (total, all ages 15+), which is the broadest group in both files. Y15T64 also exists.
- pt_common_employees_women: common definition (<30 usual hours), WORKER_STATUS ICSE93_1 (employees). JPN has no common-definition employee series. It was substituted with the national-definition women's value for total employment, because there is no national employee series for JPN (flag JPN_national_definition_substitute; employment_basis_total), available 2000-2008. Empty: AUS 1998-2000 (series starts 2001); JPN 1998-1999.
- pt_national_women: national definition, WORKER_STATUS _T (total employment; the employee series lacks JPN and USA). Empty: JPN 1998-1999.
- pt_common_total_women: common definition, WORKER_STATUS _T, AGE _T. Empty: USA all years (not in file); AUS 1998-2000.

### gdp_pc_ppp and gdp_index_undp

WDI NY.GDP.PCAP.PP.CD (current international $, API lastupdated 2026-10-08) for year y. gdp_index_undp = (ln(gdp) - ln 100)/(ln 40000 - ln 100), capped at 1. Flag capped_at_1 on 31 cells (AUT, CAN, CHE, DNK, FIN, IRL, ISL, NLD, NOR, SWE, USA; 2004-2008). This is a current-vintage WDI series, not the GDP index printed in the HDRs.

### unemployment_rate

Primary: oecd_unemployment, FREQ = A, MEASURE UNE_LF_M, SEX _T, AGE Y_GE15, ADJUSTMENT N (unadjusted) preferred and Y used only if N is absent. N was available in every primary cell. One primary cell has OBS_STATUS B (FRA 2002, series break), recorded in the flags. Fallback (flag fallback_LFS_UNE_RATE_15_64): oecd_lfs_indicators UNE_RATE, SEX _T, AGE Y15T64 (the file only has 15-64 and 25-54, so 15-64 is the closest group) for CHE 1998-2008, ISL 1998-2002 and GRC 1998.

### epl_overall

OECD EPL VERSION1 EPL_OV for all 23 non-Iceland countries in every year. The EPL_R/EPL_T mean fallback was not needed. Iceland's first EPL_OV v1 year is 2008, so the 2008 value was carried back to 1998-2007 (flag ISL_carried_back_from_2008). Note: EPL_OV in the current OECD file is labelled "Individual and collective dismissals (regular contracts)". It is not an overall regular-plus-temporary index.

### women_managers_pct

Extracted with `pdftotext -layout` from the GEM table of each HDR. The column is "Female legislators, senior officials and managers (% of total)", the 4th field after the country name: GEM rank, GEM value, seats in parliament, managers, professional, ratio. Footnote letters attached to a number are separated from it. Every parsed line, token and value is in `registry/construction/hdr_parsed_rows.csv`. The full raw line and its text line number are kept in each lineage row. All 120 parsed lines (24 countries x 5 editions) were inspected against the layout text. Edition map: 1998-2002 -> HDR 2004; 2003 -> HDR 2005; 2004 -> HDR 2006; 2005-2006 -> HDR 2007/2008 (`2008-english.pdf`); 2007-2008 -> HDR 2009. Reference periods printed in the table notes: 2007/2008 note b, "most recent year available between 1994 and 2005"; 2009 note b, "between 1999 and 2007"; 2004, "most recent year available during the period specified".
- FRA: ".." in HDR 2004, 2005 and 2006, so the nearest edition with a value (HDR 2007/2008) was used for 1998-2004 (flag nearest_edition_fallback, 7 cells). Ties would go to the earlier edition, but none occurred.
- JPN: HDR 2007/2008 value carries footnote d and HDR 2009 carries footnote h (both "Data follow the ISCO-68 classification"). Flagged footnote=d / footnote=h for 2005-2008.
- CHE 2005-2006 (HDR 2007/2008): the printed value is far from both adjacent editions. It was rechecked in the layout text: "7 Switzerland 27 0.660 24.8 8 22 0.63". Entered as printed and flagged printed_value_rechecked_in_layout_text.
- HDR 2010 was not used (it does not print this indicator).

### fertility_rate

SF2.1 sheet "Total Fertility Rates", by year. Complete.

## Completeness summary (empty cells)

- leave_fte_weeks: CZE 1998-2008 (flat-rate parental allowance, no percentage); FRA 1998-2003 (ambiguous PF2.5 text entry).
- leave_fre_oecd: all cells (no historical FRE series).
- pt_common_employees_women: AUS 1998-2000; JPN 1998-1999.
- pt_national_women: JPN 1998-1999.
- pt_common_total_women: USA 1998-2008; AUS 1998-2000.
- All other columns are complete for 24 x 1998-2008.

All country-level sources are current (October 2026) releases, not the vintages available to the original study.
