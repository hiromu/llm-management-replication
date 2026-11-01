# Source dictionary: OECD country-level sources

Summary-free descriptions for independent readers. Only definitions, codes, units and coverage (which countries and years are present) are given; no observed values.

Country codes (ISO3) used by all OECD files: AUS Australia, AUT Austria, BEL Belgium, CAN Canada, CZE Czechia (Czech Republic), DNK Denmark, FIN Finland, FRA France, DEU Germany, GRC Greece, ISL Iceland, IRL Ireland, ITA Italy, JPN Japan, NLD Netherlands, NZL New Zealand, NOR Norway, POL Poland, PRT Portugal, ESP Spain, SWE Sweden, CHE Switzerland, GBR United Kingdom, USA United States.

All OECD Data Explorer extracts are SDMX "CSV with labels" files: one row per observation; each dimension appears as a code column followed by a label column; value in OBS_VALUE; TIME_PERIOD = calendar year (annual) or period; OBS_STATUS flags (A normal value, B time-series break, P provisional, U low reliability; SOCX also K included in another category, L not collected, M cannot exist). Requests were limited to the 24 countries above. All files are current releases (downloaded October 2026), not the 2012 releases cited in the article; series may have been revised.

## oecd_ftpt - Incidence of part-time employment (OECD Labour Force Statistics)

Files: `OECD.ELS.SAE_DSD_FTPT@DF_FTPT_COMMON_INC_1.0.csv` (OECD-harmonized definition), `OECD.ELS.SAE_DSD_FTPT@DF_FTPT_NATIONAL_INC_1.0.csv` (national definitions), structure XML.
- What it measures: share of employed persons whose main job is part-time (or full-time), in percent of employment in the same subgroup. Common definition: usual weekly hours in the main job under 30. National definitions vary by country (self-assessment or national hour thresholds).
- Dimensions (code = label): MEASURE EMP = Employment, EMP_PT = Part-time employment; UNIT_MEASURE PT_POP_SUB = percentage of population in the same subgroup; SEX F/M/_T (Female/Male/Total); AGE e.g. Y15T64, Y25T54, Y15T24, Y_GE65, _T (total) and five-year bands; LABOUR_FORCE_STATUS EMP; JOB_COVERAGE MAIN (main job); WORKER_STATUS _T Total, ICSE93_1 Employees, ICSE93_2T5 Self-employed; WORK_TIME_ARNGMNT FT/PT; METHODOLOGY OECD_DEF; FREQ A.
- Coverage 2001-2008: national-definition women's part-time incidence present for all 24 countries in every year. Common definition, women employees: all countries except Japan. Common definition, women in total employment ages 15-64: all except United States (and Japan lacks 2001). Years requested 1990-2015.

## oecd_epl - Strictness of employment protection legislation

Files: `OECD.ELS.JAI_DSD_EPL@DF_EPL_1.0.csv`, structure XML.
- What it measures: synthetic indicators of the strictness of regulation on dismissals and on the use of temporary contracts, scale 0 (least restrictive) to 6 (most restrictive).
- Dimensions: MEASURE EPL_R = Individual dismissals (regular contracts); EPL_OV = Individual and collective dismissals (regular contracts); EPL_CD = Collective dismissals (additional provisions); EPL_T = Temporary contracts. VERSION: VERSION1 (1985-2019), VERSION2 (1998-2019), VERSION3 (2008-2019), VERSION4 (2013-2019) - versions differ in the number of items included. UNIT_MEASURE 0_TO_6. FREQ A.
- No single "overall EPL (regular and temporary)" series is published in this file; an overall index would have to be constructed from components.
- Coverage 2001-2008: version 1 EPL_R, EPL_OV and EPL_T present for 23 countries in all years; Iceland only from 2008. Version 2 EPL_OV and EPL_CD present for 23 countries (not Iceland). Version 2 EPL_R and EPL_T and version 1 EPL_CD are not populated for 2001-2008.

## oecd_unemployment - Harmonised unemployment rates (Infra-annual labour statistics; the series formerly published in Main Economic Indicators)

Files: `OECD.SDD.TPS_DSD_LFS@DF_IALFS_UNE_M_1.0_annual.csv` (contains monthly, quarterly and annual frequencies), structure XML.
- What it measures: unemployed persons as a percentage of the labour force (ILO definitions), harmonised across countries.
- Dimensions: MEASURE UNE_LF_M = Monthly unemployment rate; UNIT_MEASURE PT_LF_SUB = percentage of labour force in the same subgroup; ADJUSTMENT Y = calendar and seasonally adjusted, N = neither; SEX _T/M/F; AGE Y_GE15 (15+), Y_GE25, Y15T24; FREQ M/Q/A.
- Coverage 2001-2008 (annual, total, 15+): present for 22 countries in all years; Switzerland absent in all of 2001-2008; Iceland absent 2001-2002.

## oecd_lfs_indicators - Labour force participation and unemployment rates by sex and age (annual LFS)

File: `OECD.ELS.SAE_DSD_LFS@DF_LFS_INDIC_1.1.csv`.
- Dimensions: MEASURE LF_RATE = Labour force participation rate (unit PT_POP_SUB, % of population in subgroup), UNE_RATE = Unemployment rate (unit PT_LF_SUB, % of labour force); SEX F/M/_T; AGE Y15T64, Y25T54; LABOUR_FORCE_STATUS LF, UNE; FREQ A. Years 1995-2012.
- Coverage 2001-2008: women's participation rate 15-64 present for all 24 countries in all years.
- Relevance: candidate alternative indicator (women's labour force participation) mentioned among the article's alternative measures; also an alternative unemployment series.

## oecd_union_density - Trade union density

File: `OECD.ELS.SAE_DSD_TUD_CBC@DF_TUD_1.0.csv`.
- What it measures: union members as a percentage of employees (MEASURE TUD; UNIT_MEASURE PT_SAL = percentage of employees). Annual, 1990-2015 requested.
- Coverage 2001-2008: present for 21 countries in all years; missing years for France (2006-2007), Greece (2002-2003, 2005-2006, 2008) and Portugal (2001, 2005, 2007).

## oecd_socx_family - Public social expenditure on family (SOCX)

File: `OECD.ELS.SPD_DSD_SOCX_AGG@DF_PUB_FAM_1.0.csv`.
- What it measures: public spending on family benefits by programme. EXPEND_SOURCE ES10 = Public. SPENDING_TYPE C = in cash, K = in kind, _T = total. PROGRAMME_TYPE TP51 Family (total), TP511 Family allowances, TP512 Maternity and parental leave, TP513 Other cash benefits, TP521 Early childhood education and care (ECEC), TP522 Home help / accommodation, TP523 Other benefits in kind. UNIT_MEASURE PT_B1GQ = % of GDP, PT_OTE_S13 = % of general government expenditure, USD_PPP_PS = US dollars per person PPP, XDC = national currency (with CURRENCY and PRICE_BASE V current / Q constant). Annual.
- Coverage 2001-2008: ECEC (TP521) as % of GDP present for all 24 countries in all years; maternity and parental leave (TP512) present for 23 (not United States).
- Note: this is a sourced alternative; the article's childcare indicator is from the OECD Family Database (below).

## oecd_family_database - OECD Family Database spreadsheets

Files (Excel workbooks, each with chart sheets, data tables and notes/sources text):
- `PF2_1_Parental_leave_systems.xlsx`: current (2025) paid leave entitlements for mothers and fathers: weeks of paid maternity leave, paid parental and home-care leave available to mothers, average payment rate across the leave (% of earnings), and the full-rate equivalent (FRE = weeks x average payment rate). Current reference year only; no historical series.
- `PF2_5_Trends_in_leave_entitlements_around_childbirth.xlsx`: sheet "Time-Series", one block of rows per country, one row per year 1970-2025. Columns: Maternity_paid (weeks of paid maternity leave), Maternity_weeks (weeks of maternity leave), Maternity_prebirth, Maternity_postbirth, Parental_protected (weeks of job-protected parental leave available to mothers), Parental_paid (weeks of payments associated with parental leave available to mothers), Parental_paid_long (weeks under a 'long option'), Homecare_protected, Homecare_paid, Total_Protected (maximum weeks of job-protected maternity, parental and home-care leave available to mothers), Total_paid (total weeks of paid maternity, parental and home-care payments available to mothers), Total_paid_long, Patleave, Patleave_paid, Father_specific_Parleave, Father_specific_Parleave_paid, Total_Father_specific, Total_Father_specific_paid. Units: weeks. No historical payment rates. Coverage 2001-2008: Total_paid numeric for 23 countries; for France the entries are text (entitlement varies with birth order) rather than a single number.
- `PF3_1_Public_spending_on_childcare_and_early_education.xlsx`: sheet "Time-series" = total public expenditure on early childhood education and care (childcare and pre-primary education), % of GDP, 1980-2021/22, one row per country with a 'Note' column; chart sheets give the latest split between childcare and pre-primary and per-child spending. Coverage 2001-2008: all 24 countries.
- `PF3_2_Enrolment_childcare_preschool.xlsx`: enrolment rates in ECEC, 0-2 and 3-5 year-olds (percent), by year (alternative measure mentioned in the article's footnote on childcare).
- `PF1_1_Public_spending_on_family_benefits.xlsx`: "Time-series" sheet of public spending on family benefits in cash, services and tax measures, % of GDP, 1980-2021.
- `SF_2_1_Fertility_rates.xlsx`: sheet "Total Fertility Rates" = average number of children born per woman over a lifetime given current age-specific fertility rates, 1960 onward, countries in columns or rows by year. Coverage 2001-2008: all 24 countries.
- `LMF_1_6_Gender_differences_in_employment_outcomes.xlsx`: sheets PT_Women / PT_Men (part-time employment as a proportion of employment, by sex, 1990 onward; coverage 2001-2008 all 24 countries), EPR and FTE employment rates by sex, TempEmp by sex, Managers_Women (women's share of managerial employment, 2010-2021 only; no 2001-2008 coverage).
- Definitions, notes and sources are printed in each sheet. All files are the current vintage; the article cites the 2012 Family Database (its childcare series referred to 'childcare services' for children under five and was published for 2005 and 2007).
