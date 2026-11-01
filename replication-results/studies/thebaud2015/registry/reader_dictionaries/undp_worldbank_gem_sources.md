# Source dictionary: UNDP Human Development Reports, World Bank sources, and original GEM annual files

Summary-free descriptions for independent readers. Definitions, structure and coverage only; no observed values.

## undp_hdr - UNDP Human Development Reports 2004, 2005, 2006, 2007/2008, 2009, 2010

Files (PDF, full English reports from hdr.undp.org): `human-development-report-2004-english.pdf`, `human-development-report-2005-english.pdf`, `human-development-report-2006-english.pdf`, `2008-english.pdf` (HDR 2007/2008), `human-development-report-2009-english.pdf`, `human-development-report-2010-complete-english.pdf`.
- Relevant statistical-annex content (printed tables):
  - Human development index table with its components, including the GDP index (2004-2009 reports). The GDP index is computed from GDP per capita in PPP US$ as (log(GDPpc) - log(100)) / (log(40,000) - log(100)), bounded 0-1 (definition from the reports' technical notes). The HDR 2010 replaced the GDP index with an income index based on GNI per capita (different goalposts) and does not print a GDP index.
  - Gender empowerment measure table including "female legislators, senior officials and managers (% of total)" (2004-2009 reports). HDR 2010 replaced the GEM with the Gender Inequality Index and does not print this indicator.
  - Other gender indicators mentioned among the article's alternatives (e.g. seats in parliament held by women, female labour-force participation, estimated earned income ratios).
  - HDI groups ("high human development"), used as a sample criterion in the article.
- Reference years: indicators in each report's annex generally refer to a year about two years earlier than the report year; each table states its reference year in the header.
- Coverage: all 24 countries of the article appear in every report.
- Form: printed tables in PDF; values must be read from the tables.

## worldbank_income_class - World Bank historical income classifications (OGHIST.xlsx)

- Sheets: Parameters, Thresholds (GNI per capita thresholds by fiscal year), Country Analytical History (classification of each economy by fiscal year: L low, LM lower-middle, UM upper-middle, H high income; some special codes), Operational Category Change, Country Indebtedness History.
- Coverage: all economies, classification years from FY1989 to the current fiscal year, including the 2013 classification cited in the article.

## worldbank_doing_business - Doing Business historical data (DB2004-DB2020)

- File `Historical-data---COMPLETE-dataset-with-scores.xlsx`, sheets "All Data", "Methodology", "Metadata". One row per economy and DB year.
- Relevant columns for the article's alternative control (starting a business): "Procedures - Men (number)", "Time - Men (days)", "Cost - Men (% of income per capita)" and the corresponding Women columns, "Paid-in Minimum capital (% of income per capita)", "Rank-Starting a business", "Score-Starting a business", plus score columns under different methodology vintages (DB10-14, DB15, DB17-20).
- DB year = publication year; data refer to conditions about one year earlier (DB2004 refers to 2003). DB years present: 2004-2020. No coverage of 2001-2002.
- Coverage: all 24 countries present.
- The Doing Business project was discontinued in 2021; this archived file is the final historical release.

## worldbank_wdi_gdppc - World Development Indicators, GDP per capita PPP (current international $)

- File `NY.GDP.PCAP.PP.CD_24countries_1995-2012.json`: World Bank API JSON; element [0] = paging metadata including 'lastupdated'; element [1] = list of records with fields indicator (id NY.GDP.PCAP.PP.CD, 'GDP per capita, PPP (current international $)'), country (id, value), countryiso3code, date (year), value, unit, obs_status, decimal.
- Coverage: all 24 countries, 1995-2012.
- Sourced alternative to the HDR GDP index, not the article's measure.

## gem_aps_original - GEM annual APS public files, 2001 and 2002 (gemconsortium.org)

- Files: `1407424654GEM_2001_APS_Global_Individual_Level_Data.zip` (contains `GEM 2001 APS Global Individual Level Data.sav`), `1407424562GEM_2002_APS_Global_Individual_Level_Data.zip` (`GEM 2002 APS Global Individual Level Data.sav`), `1407423885GEM_2002_APS_Global_National_Level_Data.zip` (`GEM 2002 APS Global National Level Data.sav`); extracted copies in `unzipped_*` folders.
- Individual files: one record per respondent, original GEM variable names in lower case (e.g. setid, yrsurv, country [telephone code], weight, weight_l, weight_a, gender, age, bstart, bjobst, ownmge, knowent, suskill, fearfail, nbgoodc, nbstatus, nbmedia, omown, omowners, omwageyr, omnowjob, omyr5job, omreason, gemwork, gemwork3, gemeduc, gemhhinc, suboanw, babybuso, estbbuso, teayy and many derived indicators). Codes: Yes = 1, No = 0, Don't know = 8, Refused = 9 for screening items; gender Male = 1, Female = 2.
- The status item (nbstatus, "In my country, those successful at starting a new business have a high level of status and respect") is present as a variable name but has no responses in either 2001 or 2002. The 2002 national-level file (one row per country; prevalence and count indicators for 2002) has no status indicator.
- Reading note: these SPSS files contain multiple-response set records that some readers (pyreadstat/readstat) reject; R foreign::read.spss reads them.
- Role: checked as an original-provider source for the status item in 2001-2002; it does not supply it.

## Not acquired

- ISSP 2002 "Family and Changing Gender Roles III" (GESIS ZA3880), cited for an alternative gender-ideology indicator: requires a GESIS login; not acquired.
- Charles and Bradley (2009) gender segregation by academic field: no public dataset identified; not acquired.
- Service-sector size and gender wage gap (OECD): optional alternatives, not fetched.
