# Source validation notes (internal, not for readers)

Study: thebaud2015. Role: source acquisition, fresh context. Prepared 2026-10-27/28 (UTC). Files ending in `_INTERNAL` contain coverage checks (record counts, valid-response shares) and must not be given to readers or implementers as summaries.

## 1. ICPSR 20320 bundle (user supplied)

Scripts: `registry/scripts/icpsr_metadata.py`, `icpsr_coverage.py`, `pyreadstat_check.py`, `haven_check.R`.

Integrity and identity
- SHA-256 of all 7 files match `data/supplied/supplied_sources.json`. MD5 of Data.sav (df0faa55...), Codebook-ICPSR.pdf (eaab4d2c...) and Codebook-PI.pdf (a1d65cbb...) match `20320-manifest.txt`.
- Identity: Reynolds, Paul D. GEM Adult Population Survey Data Set, 1998-2017, ICPSR20320-v6, 2022-07-12, doi 10.3886/ICPSR20320.v6. PI codebook version 4.01 (2020-04-01).
- Manifest lists formats not in the bundle (dta, rda, stc, tsv, txt, setup files, descriptioncitation.pdf). Not needed; nothing requested from the user.
- Terms (TermsOfUse.html): the user agreed on 2026-10-27 at download. Research/statistical use only, no re-identification, no redistribution outside authorized users, cite, notify ICPSR bibliography, countries-of-concern restriction. No conflict with in-project analysis; data must not be copied to reader staging.

Reading
- pyreadstat 1.3.3 / pandas 2.2.3 and R 4.6.1 haven 2.5.5 both read 2,796,985 rows x 97 columns. Fingerprints (non-missing counts and column sums) on GEM_YR, COUNTRY, CTRYALP, GEMSEX, GEMAGE, GEMEDUC, GEMWORK, OWNMGE, WEIGHT, OMNOWJOB are identical (WEIGHT sum differs at the 6th decimal, float rounding). Files: `haven_fingerprint_INTERNAL.csv`, `pyreadstat_fingerprint_INTERNAL.csv`.
- No SPSS user-missing declarations. Missing = system-missing plus labelled codes (e.g. 8 "DON'T KNOW", 9 "REFUSED"/"DK/NR/MISS", 7 "Not Applicable", 99/999/9999/999999/9999997/9999999 variants). Codes inferred from labels are in `icpsr20320_missing_codes_from_labels.json`; full metadata in `icpsr20320_metadata.json`.
- Some screening items carry a value 100 labelled "YES" in addition to 1 "YES" (BUSANG, OPPORT, KNOWENT, SUSKILL, FEARFAIL, NBGOODC, NBSTATUS, NBMEDIA); transformed activity flags (SUBOANWT, OMBABYBT, OMESTBBT, TEA) use 0 / 1 "QUALIFIES" / 100 "ACTIVE".

Country and year coverage (`icpsr20320_country_year_records_INTERNAL.csv`)
- All 24 paper countries are present. Every one of the 143 survey-years listed in the paper's Online Appendix Table A1 exists in the bundle. The bundle also has additional years for several countries (e.g. Canada 2004-2005, Italy 2004, Netherlands 2001, Australia 2000-2001) that the paper did not use; reasons are not stated in the paper.
- Subnational samples (Scotland, Wales, NZ Maori, Azores, Shenzhen) are excluded from this version per the PI codebook; none appear under the paper's country codes.

Variables the paper uses and their presence (variable names in the bundle)
| Paper concept | Bundle variable(s) | Present | Year coverage note (paper countries) |
|---|---|---|---|
| Nascent entrepreneur | SUBOANWT (transform), BSTART, BJOBST, SUACTS, SUOWN, SUWAGE | yes | all years |
| Established/new business owner-manager | OWNMGE, OMOWN, OMWAGEYR, OMBABYBT, OMESTBBT | yes | all years |
| Female | GEMSEX | yes | all years |
| Age | GEMAGE (exact; category midpoints imputed where only categories collected), GEMAGE7C | yes | all years |
| Post-secondary degree | GEMEDUC (1316 POST SECONDARY, 1720 GRAD EXP) | yes | no valid responses: France 2003 (paper year); also Australia 2001, Spain 2001, NZ 2002, Norway 2007 (not paper years) |
| Labour-force restriction / not employed | GEMWORK, GEMWORK3 | yes | no valid responses: France 2003 (paper year); also France 2001, Norway 2001 and 2007, Spain 2001, NZ 2002 (not paper years) |
| Skills / fear of failure / knows entrepreneur | SUSKILL, FEARFAIL, KNOWENT | yes | valid share drops from 2003 on, consistent with the half-sample skip pattern the paper describes |
| Social status of entrepreneurship (survey-level mean) | NBSTATUS | yes | no valid responses in 2001 and 2002 for any country |
| No better choices for work (owners) | OMREASON (2 BEST WORK CHOICE), OMWHY, OMEB_MOT, OMBB_MOT | yes | all years |
| Business size (full-time employees) | OMNOWJOB (jobs now; wording counts people working, not full-time employees specifically) | yes | all years |
| High-growth aspiration (>5 additional employees in 5 years) | OMYR5JOB with OMNOWJOB | yes | all years |
| New to all customers | OMNEWCST | yes | 2002-2008 (none 2001), matches paper footnote 14 |
| Technology less than five years old | OMNEWT_5 (2005 on); OMNEWTEC (1-year item 2002-2008) | yes | OMNEWT_5 2005-2008 only, matches footnote 14 |
| Sole owner | OMOWNERS (number of owners), OMOWN | yes | all years |
| Business age | OMWAGEYR (first year of payments to owners) | yes | all years |
| Weights | WEIGHT (vendor, recentered by year), WEIGHT_L (18-64), WEIGHT_A (18+) | yes | WEIGHT_L missing outside 18-64 by design; the paper does not mention weighting |
| Household income | GEMHHINC (country-year terciles) | yes | not used by the paper |

Per country-year list of key variables with no valid responses (2001-2008): `icpsr20320_country_year_variable_gaps_2001_2008_INTERNAL.json`; per variable by year valid shares: `icpsr20320_variable_year_valid_share_INTERNAL.csv`.

Gaps relative to the paper
1. NBSTATUS absent 2001-2002 in ICPSR V6. Checked the original public GEM 2001 and 2002 APS individual files and the 2002 national-level file from gemconsortium.org (`data/raw/gem_aps_original`): `nbstatus` exists but is entirely missing in 2001 and 2002, and the national file has no status indicator (`gem_original_2001_2002_nbstatus_coverage_INTERNAL.csv`). The PI codebook's 2003 schedule shows the status item among the items added after 2002. The paper's social-status control for its 2001-2002 surveys therefore cannot be constructed from acquired public individual-level data; the paper does not describe how those values were obtained (imputation is possible but unstated).
2. France 2003 lacks GEMWORK and GEMEDUC in V6 although the paper includes France 2003.
3. Vintage: the paper's GEM release is unnamed; V6 (2022) harmonization (including exact-age imputation from categories, reclassification of nascent/owner status by first-payment year, recoded motives) may differ from the author's file.
4. Nothing needs to be requested from the user for ICPSR.

## 2. Country-level sources

Script: `registry/scripts/country_source_coverage.py` -> `country_source_coverage_INTERNAL.json` (presence flags 2000-2008 by ISO3); `hdr_db_oghist_check.py` -> `hdr_doingbusiness_oghist_check_INTERNAL.json`.

| Paper variable | Source(s) acquired | Coverage of 24 countries, 2001-2008 | Vintage issue |
|---|---|---|---|
| Paid leave, FTE weeks for mothers | cepr_parental_leave (Ray 2008; Ray, Gornick & Schmitt 2008 CEPR report), ilo_travail_maternity (archived 2009 and 2011 editions), oecd_family_database PF2.1/PF2.5 | CEPR: 21 countries, no Czech Republic, Iceland, Poland, single reference period (about 2008). ILO 2011: 21 countries substantive (missing Canada, France, Poland); ILO 2009: 20 substantive (Czech Republic, Greece, Poland empty; Portugal missing). PF2.5: weeks of paid leave by year for 23 countries (France entered as text); no historical payment rates. Poland: no ILO report; only OECD PF2.5 weeks | JESP 2010 version of Ray et al. not acquired (paywalled); the paper's own year-specific FTE database with 1-year lag is not published |
| State childcare spending, % GDP | oecd_family_database PF3.1 time series; oecd_socx_family TP521 (sourced alternative) | 24/24 all years in both | Current series are total ECEC (childcare + pre-primary), revised; paper used 2005 and 2007 published childcare figures with imputation |
| Women's part-time share | oecd_ftpt (common and national definitions); LMF1.6 PT_Women | National def.: 24/24. Common def. women employees: Japan missing; women total employment 15-64: USA missing. LMF1.6: 24/24 | 2012 vs current revisions; definition choice open |
| GDP control (GDP index) | undp_hdr (HDR 2004, 2005, 2006, 2007/8, 2009, 2010 PDFs); worldbank_wdi_gdppc (sourced alternative) | HDR 2004-2009: all 24 countries in text, GDP index label present; HDR 2010: no GDP index. WDI: 24/24 | HDR values only as printed PDF tables |
| Unemployment rate | oecd_unemployment (harmonised; annual) ; oecd_lfs_indicators UNE_RATE (alternative) | Harmonised annual: Switzerland none 2001-2008, Iceland none 2001-2002 | MEI 2012 vs current |
| Employment protection index | oecd_epl | Version 1 EPL_OV/EPL_R/EPL_T: 23/24, Iceland none 2001-2007 (2008 only); version 2 EPL_OV and EPL_CD: 23/24, Iceland none; version 2 EPL_R and EPL_T not populated in 2001-2008; version 1 EPL_CD not populated | 2012 'overall' summary indicator not published as a single series |
| % women among legislators, senior officials, managers | undp_hdr (2004-2009 reports) | label present in 2004-2009 reports; absent in HDR 2010. OECD LMF1.6 managers series starts 2010 | printed PDF tables only |
| Fertility rate | oecd_family_database SF2.1 | 24/24 | revised series |
| High-income sample criterion | worldbank_income_class (OGHIST) | all countries | none |
| Alternatives (footnotes 11-12) | worldbank_doing_business (DB2004-DB2020; no 2001-2002 coverage), oecd_union_density (gaps France 2006-07, Greece 2002-03/05-06/08, Portugal 2001/05/07), oecd_lfs_indicators LF_RATE (24/24) | as noted | ISSP 2002 needs GESIS login; Charles & Bradley 2009 not available as a dataset; service-sector size and gender wage gap not fetched |

## 3. Failed or blocked attempts (all logged in `registry/acquisition_log.jsonl`)
- First 7 log rows: local tooling failure (python urllib under `-I` reported "unknown url type: https"); retried successfully with curl. Not provider failures.
- cepr.net direct PDF: HTTP 403 Cloudflare browser challenge (not bypassed). Archived originals from web.archive.org used instead. Failure body saved as `failed_response_cepr_parental_leave_parental_app_2008_09_direct.pdf.txt`.
- ILO TRAVAIL cited servlet and current travail URLs: 404 (database discontinued). Wayback rate-limited the first batch (HTTP 000); paced retries succeeded except Canada/France/Poland 2011 and Portugal 2009 (no captures).
- OECD old Family Database URLs: 404; OECD dataset landing page: 403.
- World Bank WDI NY.GDP.PCAP.PP.KD: HTTP 400. ddh-openapi OGHIST link: 404 (probe).
- ILOSTAT (female share of managers, un-cited alternative): bulk/API endpoints returned 400/404/empty; not pursued.
- `fetch_post.sh` mis-parsed Content-Disposition for the three GEM downloads; files renamed to the server-supplied names (content unchanged; hashes in the registry are authoritative). Response headers kept as `response_headers_gem_*.txt`.
