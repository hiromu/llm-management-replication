"""Write the summary-free reader dictionary for ICPSR 20320 (GEM APS 1998-2017).
Uses only metadata (names, labels, value labels) and presence information (which years/countries exist,
which years a variable has any substantive response). No counts, shares, means or distributions are written.
Usage: python -I make_gem_dictionary.py <study_dir>"""
import sys, os, json
import pandas as pd

st = sys.argv[1]
val = os.path.join(st, "registry", "validation")
meta = json.load(open(os.path.join(val, "icpsr20320_metadata.json")))
cy = pd.read_csv(os.path.join(val, "icpsr20320_country_year_records_INTERNAL.csv"), index_col=0)
vs = pd.read_csv(os.path.join(val, "icpsr20320_variable_year_valid_share_INTERNAL.csv"), index_col=0)
gaps = json.load(open(os.path.join(val, "icpsr20320_country_year_variable_gaps_2001_2008_INTERNAL.json")))

def ranges(years):
    years = sorted(int(float(y)) for y in years)
    if not years: return "none"
    out, s, p = [], years[0], years[0]
    for y in years[1:]:
        if y == p + 1: p = y; continue
        out.append(f"{s}" if s == p else f"{s}-{p}"); s = p = y
    out.append(f"{s}" if s == p else f"{s}-{p}")
    return ", ".join(out)

QTEXT = {
 "GEMSEX": "Respondent gender (interviewer/respondent report).",
 "GEMAGE": "Respondent exact age in years. Where a survey collected only age categories, the harmonizer assigned an approximate category midpoint (18-24 -> 21, 25-34 -> 29, 35-44 -> 39, 45-54 -> 49, 55-64 -> 59, 65+ -> 71). Respondents under 18 or with unknown age are not in the harmonized file.",
 "GEMWORK": "Harmonized work force status (6 categories) recoded from national survey-vendor items; definitions vary across national surveys.",
 "GEMWORK3": "Harmonized work force status (3 categories): working full or part time / not working / retired or student.",
 "GEMEDUC": "Harmonized educational attainment using a North American frame (12 years = secondary degree; post-secondary may include academic, vocational or technical training; 'GRAD EXP' = more than 16 years / graduate training).",
 "GEMHHINC": "Household or personal income, reclassified within each national sample and year into thirds (no PPP or inflation adjustment).",
 "BSTART": "'You are, alone or with others, currently trying to start a new business, including any self-employment or selling any goods or services to others?' (wording varies slightly by year).",
 "BJOBST": "'You are, alone or with others, currently trying to start a new business or a new venture for your employer, as part of your normal work?'",
 "OWNMGE": "'You are, alone or with others, currently the owner of a company you help manage, self-employed, or selling any goods or services to others?'",
 "KNOWENT": "'Do you know someone personally who started a business in the past 2 years?'",
 "SUSKILL": "'Do you have / You have the knowledge, skill and experience required to start a new business?'",
 "FEARFAIL": "'Would fear of failure prevent you from starting a business?'",
 "NBSTATUS": "'In your country, those successful at starting a new business have a high level of status and respect.'",
 "NBGOODC": "'In your country, most people consider starting a new business a desirable career choice.'",
 "SUACTS": "Start-up module: over the past twelve months, has the respondent done anything to help start this new business (e.g. looking for equipment or location, organizing a team, working on a business plan, saving money)?",
 "SUOWN": "Start-up module: will the respondent personally own all, part, or none of this business?",
 "SUWAGE": "Start-up module: has the new business paid any salaries, wages or payments in kind, including to the owners, for more than three months?",
 "OMOWN": "Owner-manager module: 'Do you personally own all, part, or none of this business?'",
 "OMOWNERS": "Owner-manager module: 'How many people both own and manage this business?' (from 2010 'including yourself').",
 "OMWAGEYR": "Owner-manager module: 'What was the first year the owners [founders] received wages, profits, or payments in kind?' Value labels include both a 1-15 code scheme (codes for 2000 back to before 1990, no profits yet, don't know, refused) and calendar-year codes with special codes; which scheme applies in which survey year must be checked in the data documentation.",
 "OMNEWCST": "Owner-manager module: 'Do all, some, or none of your potential customers consider this product or service new and unfamiliar?'",
 "OMNEWTEC": "Owner-manager module: were the technologies or procedures required for this product or service available more than a year ago?",
 "OMNEWT_5": "Owner-manager module (2005 on): how long have the technologies or procedures required for this product or service been available: less than a year, between one and five years, or longer than five years?",
 "OMNOWJOB": "Owner-manager module: number of people currently working for the business (not counting owners in most years' wording).",
 "OMYR5JOB": "Owner-manager module: number of people expected to be working for the business five years from now (not counting owners in most years' wording).",
 "OMREASON": "Owner-manager module: 'Are you involved in this firm to take advantage of a business opportunity or because you have no better choices for work?' (2010 on: 'Did you become involved ...').",
 "SUREASON": "Start-up module: same opportunity versus no-better-choices question for start-up efforts.",
 "SUBOANWT": "Transformed: nascent entrepreneur = active in start-up behaviour in the past 12 months, expects to own all or part, and has not paid owners' salaries/wages for more than three months. After 2001 respondents are reclassified across start-up and owner categories using reported first-payment year.",
 "OMBABYBT": "Transformed: new-firm owner-manager = manages, owns all or part, owners paid for more than 3 but less than 42 months.",
 "OMESTBBT": "Transformed: established-firm owner-manager = manages, owns all or part, owners paid for more than 42 months.",
 "TEA": "Transformed: total early-stage entrepreneurial activity = nascent entrepreneur or new-firm owner-manager (counted once if both).",
 "OMWHY": "Transformed recode of owner-manager motivation (OMREASON).",
 "OMEB_MOT": "Transformed: established-business owner motive (opportunity / best choice / mixed-other).",
 "OMBB_MOT": "Transformed: new (baby) business owner motive (opportunity / best choice / mixed-other).",
 "WEIGHT": "Survey-vendor post-stratification weight, re-centred so its mean is 1 within each year.",
 "WEIGHT_L": "Weight defined only for ages 18-64, adjusted to US Census Bureau International Data Base age-sex distributions after 2000 and re-centred within each country-year.",
 "WEIGHT_A": "Weight for ages 18 and older, adjusted and re-centred within each country-year.",
}
SKIP_LABELS = {"SUTYPE", "OMTYPE", "BATYPE", "COUNTRY", "CTRYALP"}

L = []
w = L.append
w("# Source dictionary: GEM Adult Population Survey, harmonized file (ICPSR 20320, V6)\n")
w("Summary-free description for independent readers. It lists variable names, labels, value codes and coverage expressed only as which years and countries are present. It contains no counts, means, frequencies or other observed values.\n")
w("## What the source is\n")
w("- Title: Global Entrepreneurship Monitor [GEM]: Adult Population Survey Data Set, 1998-2017. Principal investigator Paul D. Reynolds. Distributor ICPSR, study 20320, version V6 (2022-07-12), doi 10.3886/ICPSR20320.v6. Harmonized-file version 4.01 (2020).")
w("- Unit: individual adult respondent (18 and older), cross-sectional national samples by year (country-year surveys). One SPSS file with 97 variables.")
w("- Design: national random samples of adults, mostly telephone (landline, later mobile) or face-to-face; some surveys used gender quotas. Vendors post-stratified weights to national population characteristics.")
w("- Harmonization: core items harmonized across all surveys; standardized transforms identify nascent entrepreneurs, new-firm owner-managers (owners paid for up to 42 months) and established owner-managers (more than 42 months). From 2003 the screening module asked eight attitude/perception items of everyone who qualified for a special module but only of a random half of the remaining respondents (two random item sets A and B).")
w("- Before 2002 a 'don't know' to the first screening items was treated as 'no'; from 2002 a re-ask skip pattern was used. Screening wording broadened over time (self-employment, selling goods or services).")
w("- Missing values are not declared as SPSS user-missing: missing information is system-missing or a labelled code (don't know, refused, not applicable, cannot code). Codes are listed per variable below.")
w("- The file was supplied by the user from ICPSR. The article does not name the GEM release it used.\n")
w("## Countries and survey years present (the article's 24 countries)\n")
w("| Country | Survey years present in the file |\n|---|---|")
for c in cy.index:
    yrs = [y for y in cy.columns if cy.loc[c, y] > 0]
    w(f"| {c} | {ranges(yrs)} |")
w("\nThe file contains many other countries (109 in total across 1998-2017); subnational samples (Scotland, Wales, NZ Maori, Azores, Shenzhen) are excluded from this version.\n")
w("## Years in which selected items have any substantive response (article's 24 countries combined)\n")
w("| Variable | Years with responses (2001-2008 window) |\n|---|---|")
for v in ["GEMSEX","GEMAGE","GEMWORK","GEMEDUC","GEMHHINC","BSTART","OWNMGE","KNOWENT","SUSKILL","FEARFAIL","NBSTATUS","OMOWN","OMOWNERS","OMWAGEYR","OMNEWCST","OMNEWTEC","OMNEWT_5","OMNOWJOB","OMYR5JOB","OMREASON","WEIGHT","WEIGHT_L","WEIGHT_A"]:
    yrs = [y for y in vs.columns if 2001 <= float(y) <= 2008 and vs.loc[v, y] > 0]
    w(f"| {v} | {ranges(yrs)} |")
w("\nCountry-years within 2001-2008 in which an item has no substantive response at all (presence check only):\n")
for g in gaps:
    m = [x for x in g["vars_without_any_valid_response"] if x not in ("OMNEWT_5", "OMNEWCST", "NBSTATUS")]
    if m: w(f"- {g['country']} {g['year']}: {', '.join(m)}")
w("- NBSTATUS: no responses in any country in 2001 and 2002. OMNEWCST: none in 2001. OMNEWT_5: none before 2005.\n")
w("## Variables\n")
w("Type: numeric unless the SPSS format starts with A (string). Codes are listed as code = label. ISIC industry code lists and the full country code list are omitted for length (4-digit ISIC Rev. 3.1 codes to 2009, ISIC Rev. 4 from 2010; country code = international telephone access code, e.g. 1 United States, 44 United Kingdom, 49 Germany).\n")
for v in meta["variables"]:
    nm = v["name"]
    w(f"### {nm}\n")
    w(f"- Label: {v['label']}")
    w(f"- SPSS format: {v['spss_format']}")
    if nm in QTEXT: w(f"- Definition / question: {QTEXT[nm]}")
    if nm not in SKIP_LABELS and v["value_labels"]:
        codes = "; ".join(f"{k.rstrip('0').rstrip('.') if '.' in k else k.strip()} = {lab}" for k, lab in v["value_labels"].items())
        w(f"- Value labels: {codes}")
    elif nm in SKIP_LABELS:
        w("- Value labels: long code list (industry or country codes); see ICPSR documentation.")
    w("")
w("## Notes for use\n")
w("- Weighting: three weights are provided (WEIGHT, WEIGHT_L, WEIGHT_A); the documentation recommends weights in any analysis, and dividing venture-level weights by team size when describing ventures rather than people.")
w("- 'Best choice' / 'no better choices for work' motive: the harmonizer cautions that it is not equivalent to being unable to find any job.")
w("- Case identifiers: ID_9817_RDM is a unique random record identifier; SETID / SETID_NE are original GEM case IDs (duplicates possible across years/countries).")
out = os.path.join(st, "registry", "reader_dictionaries", "icpsr20320_gem_aps.md")
open(out, "w").write("\n".join(L) + "\n")
print(out, len(L))
