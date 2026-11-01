"""Assemble registry/source_registry.json from source metadata below, file hashes computed now,
and the acquisition log (registry/acquisition_log.jsonl). Usage: python -I build_registry.py <study_dir>"""
import sys, os, json, hashlib, datetime

st = sys.argv[1]
reg_dir = os.path.join(st, "registry")
log = [json.loads(l) for l in open(os.path.join(reg_dir, "acquisition_log.jsonl"))]

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""): h.update(b)
    return h.hexdigest()

def files_in(rel_dir, recurse=True):
    out = []
    base = os.path.join(st, rel_dir)
    for root, dirs, fs in os.walk(base):
        dirs.sort()
        for f in sorted(fs):
            if f.startswith("."): continue
            p = os.path.join(root, f)
            out.append({"path": os.path.relpath(p, st), "bytes": os.path.getsize(p), "sha256": sha(p)})
        if not recurse: break
    return out

def acq(sid):
    recs = [r for r in log if r["source_id"] == sid]
    ok = [r for r in recs if r.get("ok")]
    fail = [r for r in recs if not r.get("ok")]
    return ok, fail

def mk(sid, **kw):
    ok, fail = acq(sid)
    e = {"source_id": sid}
    e.update(kw)
    if "files" not in e:
        e["files"] = files_in(os.path.join("data", "raw", sid))
    if ok:
        e["acquisition"] = {"mode": "agent_download",
                            "utc_first": min(r["utc_time"] for r in ok), "utc_last": max(r["utc_time"] for r in ok),
                            "requests": [{k: r.get(k) for k in ("url", "post_form", "utc_time", "http_status", "final_url", "bytes", "sha256", "file")} for r in ok]}
    fa = e.pop("failed_attempts_extra", [])
    e["failed_attempts"] = [{k: r.get(k) for k in ("url", "post_form", "utc_time", "http_status", "error", "note")} for r in fail] + fa
    return e

paper_countries = ["Australia","Austria","Belgium","Canada","Czech Republic","Denmark","Finland","France","Germany","Greece",
                   "Iceland","Ireland","Italy","Japan","Netherlands","New Zealand","Norway","Poland","Portugal","Spain",
                   "Sweden","Switzerland","United Kingdom","United States"]

S = []
# ---------------------------------------------------------------- ICPSR (user supplied)
S.append({
 "source_id": "icpsr20320",
 "role_in_paper": "Individual-level data for all models (pp. 679-685; Online Appendix tables A1-A3): entrepreneurial activity (nascent or established owner-manager), female, age and age squared, post-secondary degree, labour-force restriction and employment status, perceptions (skills, fear of failure, knows entrepreneur; supplementary model 3), owner subsample outcomes (no-better-choices motive, business size from current jobs, growth aspiration from expected jobs in five years, product new to all customers, technology less than five years old), ownership share (sole owner), business age (first year of payments to owners); survey-level control 'social status of entrepreneurship' (country-year mean of the status item, p. 683-684). The article does not name the GEM release or distributor.",
 "provider": "Inter-university Consortium for Political and Social Research (ICPSR), distributor; principal investigator Paul D. Reynolds; originating programme Global Entrepreneurship Monitor (GEM)",
 "title": "Global Entrepreneurship Monitor [GEM]: Adult Population Survey Data Set, 1998-2017",
 "doi": "10.3886/ICPSR20320.v6",
 "url_or_query": "https://www.icpsr.umich.edu/web/ICPSR/studies/20320 (downloaded by the user; no agent access)",
 "acquisition": {"mode": "user_supplied_by_hand",
                 "user_download_date": "2026-10-27 (TermsOfUse.html states the user agreed to the terms on 2026-10-27 pursuant to the download); exact time not recorded; file modification times in the bundle are 2026-10-27 09:41-10:03 local time (UTC+9), i.e. about 00:41-01:03 UTC, indicative only",
                 "validated_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")},
 "licence_terms": "ICPSR Terms of Use (TermsOfUse.html, agreed by the user on 2026-10-27): research/statistical use only; no re-identification; no redistribution without ICPSR written agreement except among authorized users at member institutions; cite the dataset; report publications to ICPSR bibliography; restriction on sharing with listed countries of concern. Implication for this study: keep data inside the study folder; never copy to reader staging; implementers may receive derived numeric extracts only within the project.",
 "release_vintage": "ICPSR 20320 V6, 2022-07-12 (data/codebook added 2021-04-12; harmonized file version 4.01 per PI codebook dated 2020-04-01). Paper (published 2015, survey years 2001-2008) used an unnamed GEM release; necessarily an earlier vintage (GEM public annual files and/or ICPSR V1-V3). Harmonization, age imputation and transformed variables in V6 may differ from what the author used.",
 "files": [],  # filled below
 "status": "partially_available",
 "status_reason": "All 143 paper country-years are present and nearly all needed variables exist, but (1) the status item NBSTATUS (input to the social-status control) has no valid responses in survey years 2001 and 2002 for any country; (2) GEMWORK and GEMEDUC have no valid responses for France 2003, a paper survey-year; see registry/validation/README.md.",
 "integrity": "SHA-256 of all 7 files equal the inventory in data/supplied/supplied_sources.json; MD5 of Data.sav, Codebook-ICPSR.pdf and Codebook-PI.pdf equal the ICPSR manifest. Manifest lists other formats (dta, rda, stc, tsv, txt, setup files) and 20320-descriptioncitation.pdf that are not in the bundle; not needed (the .sav suffices; the citation page is present as HTML).",
 "failed_attempts": [],
 "missing_from_bundle_needed_from_user": [],
 "notes": "Read-only; not copied. Loads in pyreadstat 1.3.3 and R haven 2.5.5 with identical shape (2,796,985 x 97) and identical fingerprints on 10 variables (WEIGHT sums differ only at 1e-6 float rounding). Missing values are not declared as SPSS user-missing; they are system-missing plus labelled codes (e.g. 8/9, 9999, 999999...) documented in value labels."
})
S[-1]["files"] = files_in(os.path.join("data", "supplied", "ICPSR_20320"))

# ---------------------------------------------------------------- GEM originals (sourced supplement check)
S.append(mk("gem_aps_original",
 role_in_paper="Checked as a possible original-provider source for the social-status item in survey years 2001-2002 (absent from ICPSR V6). Result: the public GEM 2001 and 2002 APS individual files contain a variable named nbstatus but it has no non-missing values; the 2002 national-level file has no status indicator. Not a substitute for any paper variable; retained as evidence and as an original-vintage cross-check of 2001-2002 individual records.",
 provider="Global Entrepreneurship Monitor consortium / Global Entrepreneurship Research Association (gemconsortium.org)",
 url_or_query="POST https://www.gemconsortium.org/download@file with id=48777 (2001 APS individual), id=48778 (2002 APS individual), id=47183 (2002 APS national level); public download buttons on https://www.gemconsortium.org/data/sets?id=aps; no login or terms dialog",
 licence_terms="Public download; GEM states full APS datasets are made public three years after collection. No explicit licence text was displayed with the download; cite GEM as source. No login, registration or terms acceptance performed.",
 release_vintage="Zip files dated 2014-07/08 (server names 1407424654GEM_2001..., 1407424562GEM_2002..., 1407423885GEM_2002...). Closer to the paper's era than ICPSR V6.",
 status="available",
 sourced_alternative=True,
 sourced_alternative_reason="Attempted to fill the 2001-2002 status-item gap from the original provider; it does not fill it.",
 notes="Zips saved unmodified; extracted copies in unzipped_* subfolders (extraction only). pyreadstat fails on these .sav files ('multi-response set record is invalid'); R foreign::read.spss reads them. The acquisition log rows for these three downloads show mangled file names (header-parsing bug in fetch_post.sh); files were renamed to the server-supplied Content-Disposition names without content change; sha256 below is authoritative."))

# ---------------------------------------------------------------- Paid leave sources
S.append(mk("cepr_parental_leave",
 role_in_paper="Paid leave for mothers in FTE weeks (p. 681-682, footnote 6): 'Ray, 2008' and 'Ray, Gornick, and Schmitt, 2010' cited for weeks of full-time-equivalent paid leave (duration x wage replacement rate), 21 countries.",
 provider="Center for Economic and Policy Research (CEPR), Washington DC; archived copies from the Internet Archive Wayback Machine",
 url_or_query="Original URLs http://www.cepr.net/documents/publications/parental-app_2008_09.pdf (Ray 2008, 'A Detailed Look at Parental Leave Policies in 21 OECD Countries', Sept 2008), .../parental_2008_09.pdf (Ray, Gornick & Schmitt 2008, 'Parental Leave Policies in 21 Countries: Assessing Generosity and Gender Equality', CEPR report), .../parental-summary-2008-09.pdf (one-page summary); retrieved as raw archived bytes via https://web.archive.org/web/<timestamp>id_/<original URL> (captures 2008-10-23 and 2010-10-17)",
 licence_terms="Publicly released CEPR reports; no licence statement found; documentary use. The 2010 Journal of European Social Policy article (Ray, Gornick & Schmitt 2010) is paywalled and was not acquired; the 2008 CEPR report is its public working-paper version.",
 release_vintage="Ray (2008) and the 2008 CEPR report match the paper's cited Ray (2008); the JESP 2010 article version (cited) not acquired - possible minor revisions between versions.",
 status="partially_available",
 status_reason="Ray 2008 obtained; JESP 2010 article version not obtained (paywalled). Direct cepr.net download blocked by a Cloudflare browser challenge (not bypassed); archived originals used. Covers 21 of the paper's 24 countries; Czech Republic, Iceland and Poland do not appear in either report (text check); for these the ILO and OECD sources are the only acquired leave sources.",
 notes="These are source publications containing printed policy parameters; they are permitted public primary records (not the focal article). The paper says it 'used multiple sources to create an FTE paid-leave database' with policy changes for 8 countries lagged one year; this construction is not reproducible from a single file."))

S.append(mk("ilo_travail_maternity",
 role_in_paper="Paid leave for mothers (p. 681-682): 'ILO, 2012, Maternity protection database' (ILO Conditions of Work and Employment Programme, TRAVAIL), used as one of multiple sources for the FTE paid-leave database.",
 provider="International Labour Organization (ILO) TRAVAIL legal databases, Maternity protection; archived copies from the Internet Archive Wayback Machine",
 url_or_query="Cited URL http://www.ilo.org/travaildatabase/servlet/maternityprotection now 404; database discontinued at ilo.org/dyn/travail (404). Retrieved archived country reports: https://web.archive.org/web/<ts>id_/http://www.ilo.org:80/dyn/travail/travmain.sectionReport1?p_lang=en&p_countries=<ISO2>&p_sc_id=2000&p_year=<2009|2011>&p_structure=3 (fallback for 2011: ...&p_print=Y capture of 2016-03-12)",
 licence_terms="ILO web content; documentary use; no login.",
 release_vintage="Database editions labelled 2009 (captures 2010-01 and 2012-08) and 2011 (captures 2012-08-25; Belgium, Ireland, Netherlands from 2016-03-12 print captures). The paper cites ILO 2012 (consistent with the 2011 edition as online in 2012).",
 status="partially_available",
 status_reason="Substantive 2011-edition reports for 21/24 countries (missing Canada, France, Poland: no archived capture). 2009-edition reports substantive for 20/24 (Czech Republic, Greece, Poland captures are empty shells; Portugal not captured). Poland has no substantive report in either edition.",
 notes="Archived HTML pages saved unmodified. Each page includes ILO site navigation text; country content follows the country list."))

# ---------------------------------------------------------------- OECD family database
S.append(mk("oecd_family_database",
 role_in_paper="OECD (2012a) Family Database: (a) paid leave for mothers (cited with Ray and ILO; p. 681-682); (b) state childcare spending, % of GDP spent on childcare services for children under five, 'published in 2005 and again in 2007; information for missing years was imputed' (p. 682, footnote 9); (c) fertility rate (p. 684). Also alternative-control candidates: women's part-time share (LMF1.6), women's share of managers (LMF1.6, 2010+ only), enrolment (PF3.2; footnote 9 alternative).",
 provider="OECD, Directorate for Employment, Labour and Social Affairs, OECD Family Database",
 url_or_query="https://webfs.oecd.org/els-com/Family_Database/<file>.xlsx for PF2_1_Parental_leave_systems, PF2_5_Trends_in_leave_entitlements_around_childbirth, PF3_1_Public_spending_on_childcare_and_early_education, PF3_2_Enrolment_childcare_preschool, PF1_1_Public_spending_on_family_benefits, SF_2_1_Fertility_rates, LMF_1_6_Gender_differences_in_employment_outcomes",
 licence_terms="OECD terms and conditions (oecd.org/termsandconditions): OECD data may be used and reproduced with attribution (CC BY 4.0 for OECD data since 2024); no login.",
 release_vintage="Current vintage (files cover up to 2021-2025). Paper used the 2012 vintage. Differences: PF3.1 time series is total public spending on early childhood education and care (childcare plus pre-primary), not 'childcare services' alone, and is a revised series rather than the 2005/2007 publication points; PF2.5 time series gives weeks of paid leave by year but no historical payment rate, so FTE weeks cannot be computed from it alone; PF2.1 gives current (2025) payment rates/FRE only; SF2.1 fertility series revised.",
 status="available",
 notes="Old cited URLs (www.oecd.org/els/family/...) return 404 and the OECD landing page returned 403; webfs.oecd.org files downloaded without login. France's PF2.5 Total_paid entries are text (parity-dependent), not numeric."))

S.append(mk("oecd_socx_family",
 role_in_paper="Sourced alternative/complement for state childcare spending (p. 682): SOCX public expenditure on family, early childhood education and care (TP521) and maternity/parental leave (TP512), % GDP, annual. The 2012 Family Database childcare indicator was derived from SOCX plus education spending data.",
 provider="OECD Social Expenditure Database (SOCX), OECD Data Explorer SDMX API",
 url_or_query="https://sdmx.oecd.org/public/rest/data/OECD.ELS.SPD,DSD_SOCX_AGG@DF_PUB_FAM,1.0/<24 ISO3>.......?startPeriod=1990&endPeriod=2015&format=csvfilewithlabels",
 licence_terms="OECD terms (attribution; CC BY 4.0); no login.",
 release_vintage="Current SOCX (2025/26 vintage). Paper used 2012-vintage Family Database figures; series revised since.",
 status="available", sourced_alternative=True,
 sourced_alternative_reason="Annual public ECEC spending series to examine the paper's imputation of missing years; not the paper's exact indicator."))

# ---------------------------------------------------------------- OECD labour force / EPL / unemployment
S.append(mk("oecd_ftpt",
 role_in_paper="Women's part-time employment (p. 682): 'percentage of women in paid employment who work part time (OECD, 2012b)' (Table A1 footnote: percent of female employees in part-time work).",
 provider="OECD Labour Force Statistics, OECD Data Explorer SDMX API",
 url_or_query="https://sdmx.oecd.org/public/rest/data/OECD.ELS.SAE,DSD_FTPT@DF_FTPT_COMMON_INC,1.0/<24 ISO3>..........?startPeriod=1990&endPeriod=2015&format=csvfilewithlabels ; same for DSD_FTPT@DF_FTPT_NATIONAL_INC; structure: https://sdmx.oecd.org/public/rest/dataflow/OECD.ELS.SAE/DSD_FTPT@DF_FTPT_COMMON_INC/latest?references=all&detail=referencepartial",
 licence_terms="OECD terms (attribution; CC BY 4.0); no login.",
 release_vintage="Current vintage (2025/26). Paper: OECD Labour Force Statistics as of 2012 (stats.oecd.org). Revisions likely.",
 status="available",
 notes="Common (30-hour) definition: women employees series lacks Japan; women total-employment 15-64 lacks USA. National-definition series covers all 24. Choice of definition/worker status/age band is an implementer decision to be frozen in the manifest."))

S.append(mk("oecd_epl",
 role_in_paper="Employment protection index (p. 683): overall protection of regular and temporary employees from dismissal (OECD, 2012b).",
 provider="OECD Employment Protection Legislation database, OECD Data Explorer SDMX API",
 url_or_query="https://sdmx.oecd.org/public/rest/data/OECD.ELS.JAI,DSD_EPL@DF_EPL,1.0/.<24 ISO3>...?startPeriod=1985&endPeriod=2015&format=csvfilewithlabels ; structure .../dataflow/OECD.ELS.JAI/DSD_EPL@DF_EPL/latest?references=all",
 licence_terms="OECD terms (attribution; CC BY 4.0); no login.",
 release_vintage="Current EPL database (versions 1-4, through 2019). Paper used 2012 vintage; the 2012-era 'overall EPL' summary (version 1/2 average of regular and temporary) is not published as a single series here; components EPL_R/EPL_OV/EPL_T/EPL_CD by version are.",
 status="available",
 notes="Iceland has no EPL values 2001-2007 in version 1 and none in version 2 (2001-2008)."))

S.append(mk("oecd_unemployment",
 role_in_paper="Unemployment rate (p. 683): 'OECD, 2012c, Main Economic Indicators'.",
 provider="OECD Infra-annual Labour Statistics (harmonised unemployment rates; source of MEI unemployment), OECD Data Explorer SDMX API",
 url_or_query="https://sdmx.oecd.org/public/rest/data/OECD.SDD.TPS,DSD_LFS@DF_IALFS_UNE_M,1.0/<24 ISO3>.........A?startPeriod=1990&endPeriod=2015&format=csvfilewithlabels (server returned monthly, quarterly and annual series)",
 licence_terms="OECD terms (attribution; CC BY 4.0); no login.",
 release_vintage="Current vintage; paper used MEI 2012. Harmonised series revised since.",
 status="available",
 notes="Annual total 15+: Switzerland no values 2001-2008 and Iceland none for 2001-2002 in this dataflow; OECD LFS indicators (oecd_lfs_indicators) provide UNE_RATE as an alternative."))

S.append(mk("oecd_lfs_indicators",
 role_in_paper="Alternative-control candidates (footnote 12): women's labour force participation rate; also unemployment rate (UNE_RATE) as alternative to oecd_unemployment.",
 provider="OECD Labour Force Statistics (annual), OECD Data Explorer SDMX API",
 url_or_query="https://sdmx.oecd.org/public/rest/data/OECD.ELS.SAE,DSD_LFS@DF_LFS_INDIC,1.1/<24 ISO3>.LF_RATE+EMP_RATE+UNE_RATE..F+M+_T.Y15T64+Y25T54+Y_GE15....A?startPeriod=1995&endPeriod=2012&format=csvfilewithlabels",
 licence_terms="OECD terms (attribution; CC BY 4.0); no login.",
 release_vintage="Current vintage; paper vintage 2012.", status="available",
 notes="Returned measures UNE_RATE and LF_RATE; ages Y15T64 and Y25T54 (EMP_RATE and Y_GE15 not returned for this key)."))

S.append(mk("oecd_union_density",
 role_in_paper="Alternative control (footnote 11): union density.",
 provider="OECD/AIAS ICTWSS trade union density, OECD Data Explorer SDMX API",
 url_or_query="https://sdmx.oecd.org/public/rest/data/OECD.ELS.SAE,DSD_TUD_CBC@DF_TUD,1.0/<24 ISO3>..?startPeriod=1990&endPeriod=2015&format=csvfilewithlabels",
 licence_terms="OECD terms (attribution; CC BY 4.0); no login.", release_vintage="Current vintage; paper vintage 2012.",
 status="available", notes="Gaps: France 2006-2007, Greece 2002-03/2005-06/2008, Portugal 2001/2005/2007."))

# ---------------------------------------------------------------- UNDP
S.append(mk("undp_hdr",
 role_in_paper="GDP per capita control, measured as the HDR 'GDP index' (Table A1 column 'GDP index'; text p. 683 'GDP per capita (UNDP, 2004, 2005, 2006, 2007, 2009, 2010)'); percentage of legislators, senior officials and managers who are women (p. 684); 'High Human Development' sample criterion (p. 680); alternative indicators in footnote 12 (women in parliament, etc.).",
 provider="United Nations Development Programme, Human Development Report Office",
 url_or_query="https://hdr.undp.org/system/files/documents/human-development-report-2004-english.human-development-report-2004-english (and 2005, 2006; 2007/2008: .../2008-english.2008-english; 2009: .../human-development-report-2009-english...; 2010: .../human-development-report-2010-complete-english...), linked from https://hdr.undp.org/content/human-development-report-<year>",
 licence_terms="UNDP publications, freely downloadable; documentary use with attribution; no login.",
 release_vintage="Exactly the six cited reports (HDR 2004, 2005, 2006, 2007/2008, 2009, 2010). Statistical tables in each report generally refer to data about two years before the report year (per HDR conventions); mapping report to survey year is an implementer decision.",
 status="partially_available",
 status_reason="PDFs obtained for all six cited reports and all 24 countries appear in each. Text layer: 'GDP index' and 'legislators, senior officials and managers' labels present in 2004, 2005, 2006, 2007/8 and 2009 reports; absent from HDR 2010 (which replaced the GDP index by a GNI-based income index and the GEM by the Gender Inequality Index). Values are printed tables in PDFs requiring extraction.",
 notes="Machine-readable historical HDR tables (e.g. Excel annex tables for 2004-2009) were not located; HDRO's current time series do not include the old GDP index or the female-managers share."))

# ---------------------------------------------------------------- World Bank
S.append(mk("worldbank_income_class",
 role_in_paper="Sample criterion (p. 680): 'a sample of 24 high-income countries (World Bank Group, 2013)'.",
 provider="World Bank, historical country income classifications (OGHIST)",
 url_or_query="https://datacatalogfiles.worldbank.org/ddh-published/0037712/DR0090754/OGHIST.xlsx",
 licence_terms="World Bank Data Catalog, CC BY 4.0; no login.",
 release_vintage="Current OGHIST (classification history FY1989 onward); includes the 2013 classifications cited.",
 status="available",
 failed_attempts_extra=[{"url": "https://ddh-openapi.worldbank.org/resources/DR0090754/download/", "utc_time": "2026-10-27T14:50Z (probe)", "http_status": "404", "note": "probe only, not logged by fetch script"}]))

S.append(mk("worldbank_doing_business",
 role_in_paper="Alternative control (footnote 11): index of start-up procedures, time and cost (World Bank Group, 2013, Doing Business database).",
 provider="World Bank Doing Business (discontinued 2021), archive site",
 url_or_query="https://archive.doingbusiness.org/content/dam/doingBusiness/excel/db2020/Historical-data---COMPLETE-dataset-with-scores.xlsx",
 licence_terms="World Bank terms of use (CC BY 4.0 for datasets); no login.",
 release_vintage="DB2020 historical file covering DB2004-DB2020 (data years 2003-2019) with later methodology back-revisions; paper accessed in 2013. Survey years 2001-2002 not covered by any DB edition.",
 status="available"))

S.append(mk("worldbank_wdi_gdppc",
 role_in_paper="Sourced alternative for the GDP control (p. 683) where HDR GDP index is unavailable (e.g. HDR 2010): GDP per capita, PPP (current international $).",
 provider="World Bank World Development Indicators API",
 url_or_query="https://api.worldbank.org/v2/country/<24 ISO3 ;-separated>/indicator/NY.GDP.PCAP.PP.CD?format=json&date=1995:2012&per_page=1000",
 licence_terms="CC BY 4.0; no login.", release_vintage="Current WDI vintage.",
 status="available", sourced_alternative=True,
 sourced_alternative_reason="HDR 2010 lacks the GDP index; WDI is the original source series underlying HDR income measures. Not the paper's measure (the GDP index is a log-transformed, bounded transformation of GDP per capita PPP).",
 notes="Constant-price request NY.GDP.PCAP.PP.KD returned HTTP 400 (logged)."))

# ---------------------------------------------------------------- Not acquired
S.append({"source_id": "issp_2002_family_gender_roles_iii",
 "role_in_paper": "Alternative indicator (footnote 12): national-level gender ideology from ISSP 2002 'Family and Changing Gender Roles III'.",
 "provider": "GESIS - Leibniz Institute for the Social Sciences (ISSP data archive)",
 "url_or_query": "https://doi.org/10.4232/1.11564 (ZA3880, ISSP 2002 Family and Changing Gender Roles III)",
 "acquisition": {"mode": "not_attempted_login_required"},
 "licence_terms": "GESIS download requires a registered account and acceptance of terms; agents may not log in or accept terms.",
 "release_vintage": "Paper cites ISSP 2002.", "files": [],
 "status": "unavailable_login_required",
 "needed_from_user": "If this robustness indicator is to be reproduced: the user should download ZA3880_v1-1-0.sav (or the current .sav/.dta version of ZA3880) and its codebook from GESIS by hand into data/supplied/ and inventory it in supplied_sources.json.",
 "failed_attempts": [], "notes": "Only used in an unreported alternative specification (footnote 12)."})
S.append({"source_id": "charles_bradley_2009_field_segregation",
 "role_in_paper": "Alternative indicator (footnote 12): gender segregation by academic field (Charles and Bradley, 2009, American Journal of Sociology).",
 "provider": "Published journal article (secondary compilation); underlying UNESCO data not identified",
 "url_or_query": "none", "acquisition": {"mode": "not_acquired"}, "files": [],
 "licence_terms": "Paywalled article", "release_vintage": "2009",
 "status": "not_found", "failed_attempts": [],
 "notes": "No public original dataset identified; values exist only as printed results in a third-party article. Not acquired; unreported alternative only."})
S.append({"source_id": "oecd_service_sector_and_gender_wage_gap",
 "role_in_paper": "Alternative controls (footnotes 11-12): size of the service sector (OECD 2012b) and gender wage gap.",
 "provider": "OECD (Labour Force Statistics; Earnings database)", "url_or_query": "not requested",
 "acquisition": {"mode": "not_acquired"}, "files": [], "licence_terms": "OECD terms", "release_vintage": "n/a",
 "status": "not_acquired_optional", "failed_attempts": [],
 "notes": "Unreported robustness alternatives; can be fetched later from OECD Data Explorer (e.g. DSD_EARNINGS gender wage gap; ALFS employment by sector) if the manifest includes them."})

reg = {"schema_version": 1, "study_id": "thebaud2015",
       "generated_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
       "generated_by": "source-acquisition role (fresh context), registry/scripts/build_registry.py",
       "paper_countries": paper_countries, "paper_survey_years": "2001-2008 (143 country-years per Online Appendix Table A1)",
       "acquisition_log": "registry/acquisition_log.jsonl (every request incl. failures; first 7 rows are a local tooling failure of python urllib under -I, not provider failures)",
       "sources": S}
json.dump(reg, open(os.path.join(reg_dir, "source_registry.json"), "w"), indent=1, ensure_ascii=False)
for s in S: print(s["source_id"], s["status"], len(s.get("files", [])), "files", len(s.get("failed_attempts", [])), "failed")
