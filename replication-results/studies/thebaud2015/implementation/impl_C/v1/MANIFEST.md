# Implementation manifest P-7Q3 (neutral, version 1)

You will write one parameterized analysis script that fits a set of multilevel regression models to two input files. You will not receive the real data. You receive synthetic files with the same columns and codes to test your code. Your script will later be run unchanged on the real files by someone else. Write results exactly in the output format in section 8.

## 1. Input files

Both are CSV, UTF-8, header row, empty cell = missing.

gem_extract.csv: one row per survey respondent. Repeated national cross-sections. Columns (original codes, unchanged):

| Column | Meaning | Codes |
| --- | --- | --- |
| ID_9817_RDM | unique respondent id | |
| GEM_YR | survey year | 2000-2008 |
| iso3 | country | 24 ISO3 codes, see section 2 |
| COUNTRY, CTRYALP | other country codes | not needed |
| GEMSEX | gender | 1 male, 2 female, 9 missing |
| GEMAGE | age in years | 99, 999 missing |
| GEMEDUC | education | 0 none, 111 some secondary, 1212 secondary degree, 1316 post-secondary, 1720 graduate, 9999 cannot code |
| GEMWORK | work status | 1 full or full/part time, 2 part time only, 3 retired/disabled, 4 homemaker, 5 student, 6 not working: other, 9 missing |
| GEMWORK3 | work status, 3 categories | 10 working, 20 not working, 30 retired/student, 99 missing |
| BSTART | currently trying to start a business | 0 no, 1 yes, 8 don't know, 9 refused/missing |
| SUWAGE | start-up has paid wages or payments for more than three months | 1 yes, 2 no, 3 or 8 don't know, 4 or 9 refused |
| SUBOANWT | nascent entrepreneur flag (active in start-up, will own, no wages over three months) | 0 no, 1 yes |
| OWNMGE | currently owns and helps manage a business | 0 no, 1 yes, 8 don't know, 9 refused/missing |
| OMBABYBT | new-business owner flag | 0 no, 1 yes |
| OMESTBBT | established-business owner flag (owners paid for more than 42 months) | 0 no, 1 yes |
| OMOWN | owns all or part of the business | 1 all, 2 part, 3 none, 7 n/a, 8 don't know, 9 refused, 999999 missing |
| OMOWNERS | number of owner-managers | 999, 9997, 9999 missing |
| OMWAGEYR | first calendar year owners received payments | calendar year; the value 1990 means "1990 or earlier"; 9997 none yet, 9998 n/a, 9999 no answer |
| OMREASON | reason involved | 1 opportunity, 2 no better choices for work, 3 both, 4 other, 6 family business, 7 n/a, 8 don't know, 9 refused, 999999 missing |
| OMWHY | recode of OMREASON | -1 no better choice, 0 opportunity and other, 1 opportunity primary, 9 other/missing |
| OMNOWJOB | number of people working for the business now | 999999, 9999997, 9999999 missing |
| OMYR5JOB | number expected in five years | 999999, 9999997, 9999999 missing |
| OMNEWCST | product new to customers | 1 new to all, 2 new to some, 3 new to none, 7, 8, 9 missing |
| OMNEWT_5 | age of the technology used | 1 under one year, 2 one to five years, 3 over five years, 7, 8, 9, 99 missing |
| SUSKILL, FEARFAIL, KNOWENT, NBSTATUS | yes/no items | 0 no, 1 or 100 yes, 8 don't know, 9 refused |
| WEIGHT, WEIGHT_L, WEIGHT_A | survey weights | not used (see section 7) |
| TEA, SUACTS, SUOWN | not used | |

country_year_inputs.csv: one row per iso3 x year (1998-2008). Columns used: iso3, year, leave_fte_weeks, childcare_interp, childcare_pct_gdp_annual, pt_common_employees_women, pt_national_women, pt_common_total_women, gdp_index_undp, unemployment_rate, epl_overall, women_managers_pct, fertility_rate. Other columns may be present; ignore them.

## 2. Country-year roster (origin)

Keep only these surveys (iso3: years). This is 143 surveys in 24 countries.

AUS: 2002-2006. AUT: 2005, 2007. BEL: 2001-2008. CAN: 2001, 2002, 2003, 2006. CZE: 2006. DNK: 2001-2008. FIN: 2001-2008. FRA: 2002-2008. DEU: 2001-2006, 2008. GRC: 2003-2008. ISL: 2002-2008. IRL: 2001-2008. ITA: 2001-2003, 2005-2008. JPN: 2001-2008. NLD: 2002-2008. NZL: 2001, 2003, 2004, 2005. NOR: 2002-2006, 2008. POL: 2001, 2002, 2004. PRT: 2001, 2004, 2007. ESP: 2002-2008. SWE: 2001-2007. CHE: 2002, 2003, 2005, 2007. GBR: 2001-2008. USA: 2001-2008.

Branch U05 replaces the roster with every survey of the 24 countries present in gem_extract.csv for 2001-2008.

## 3. Individual variables (origin)

- female = 1 if GEMSEX = 2, 0 if GEMSEX = 1, else missing.
- age = GEMAGE; missing if 99 or 999.
- postsecondary = 1 if GEMEDUC in {1316, 1720}; 0 if in {0, 111, 1212}; missing if 9999 or empty.
- employed = 1 if GEMWORK in {1, 2}; 0 if in {3, 4, 5, 6}; missing if 9 or empty.
- not_employed = 1 - employed.
- Screening items BSTART, OWNMGE, SUSKILL, FEARFAIL, KNOWENT, NBSTATUS: 1 or 100 = yes (1), 0 = no (0), 8 and 9 = missing. Branch U06 codes 8 as 0 instead (9 stays missing) for BSTART, OWNMGE, SUSKILL, FEARFAIL, KNOWENT.
- activity (total entrepreneurial activity) = 1 if SUBOANWT = 1 or OWNMGE = 1; 0 if SUBOANWT = 0 and OWNMGE = 0; else missing.
  - Branch U03: activity = 1 if (BSTART = 1 and SUWAGE is not 1) or OWNMGE = 1; 0 if BSTART = 0 and OWNMGE = 0; else missing.
  - Branch U04: activity = 1 if SUBOANWT = 1 or OMBABYBT = 1 or OMESTBBT = 1; 0 if all three are 0; else missing.
- nascent = SUBOANWT (0/1). Under branch U03, nascent = 1 if BSTART = 1 and SUWAGE is not 1; 0 if BSTART = 0; else missing.
- skill, fear, knows = SUSKILL, FEARFAIL, KNOWENT coded as screening items.
- owner = 1 if OWNMGE = 1 (screening coding). Branch U07: owner = 1 if OMESTBBT = 1. Branch U08: owner = 1 if OWNMGE = 1 and OMOWN in {1, 2}.
- planb = 1 if OMREASON = 2; 0 if OMREASON in {1, 3, 4, 6}; missing otherwise. Branch U09: 1 if OMREASON in {2, 3}; 0 if in {1, 4, 6}. Branch U10: 1 if OMWHY = -1; 0 if OMWHY in {0, 1}; missing if 9 or empty.
- size = ln(OMNOWJOB + 1) for OMNOWJOB between 0 and 999998 inclusive; missing otherwise.
- growth = 1 if (OMYR5JOB - OMNOWJOB) > 5; 0 otherwise; missing if either count is missing (codes above or empty). Branch U23: growth = 1 if OMYR5JOB > 5, 0 otherwise.
- newprod = 1 if OMNEWCST = 1; 0 if in {2, 3}; missing otherwise.
- newtech = 1 if OMNEWT_5 in {1, 2}; 0 if 3; missing otherwise.
- sole = 1 if OMOWN = 1; 0 if OMOWN = 2; missing otherwise. Branch U24: sole = 1 if OMOWNERS = 1; 0 if OMOWNERS between 2 and 998; missing otherwise.
- bage_years = GEM_YR - OMWAGEYR, for OMWAGEYR between 1990 and GEM_YR; missing otherwise (including 9997-9999). bage = ln(bage_years), missing when bage_years = 0. Branch U11: bage = ln(bage_years + 1).

## 4. Samples (origin)

Apply in order:

1. Roster surveys only (section 2).
2. Age: 18 < age < 55 (that is, 19-54). Branch U01: 18 <= age < 55.
3. Employed = 1. Branch U02: GEMWORK in {1, 2, 6}.
4. Stage-1 sample S1: complete cases on activity, female, age, postsecondary, and every survey-level variable of the model.
5. Stage-2 sample S2: rows of steps 1-3 with owner = 1, complete on the model's outcome, female, age, postsecondary, sole, bage and every survey-level variable of the model.

Complete-case deletion is applied per model. Each model's estimation sample is its own complete-case set.

## 5. Survey-level variables (origin)

For each survey (iso3, year):

- leave = leave_fte_weeks of iso3 in year - 1 (one-year lag). Branch U17: same year. Branch U18: year - 2.
- childcare = childcare_interp in year. Branch U19: childcare_pct_gdp_annual in year.
- parttime = pt_common_employees_women in year. Branch U12: pt_national_women. Branch U13: pt_common_total_women.
- gdp = gdp_index_undp; unemp = unemployment_rate; epl = epl_overall; wmgr = women_managers_pct; fert = fertility_rate, all in the survey year.
- status = among all gem_extract.csv respondents of that iso3 and year with NBSTATUS coded 0 or 1 (all ages and work statuses, unweighted), the proportion coded 1. If a survey year has no NBSTATUS responses, use the value from the earliest later year of the same country that has responses. Branch U22: compute the proportion only among respondents who pass sample steps 1-3. Check N01 (non-equivalent, disclosed check): drop all 2001 and 2002 surveys instead of carrying status back.

Standardization (origin): compute each survey-level variable for the set of surveys present in the origin stage-1 sample of model M3 (each survey counted once). Standardize each to mean 0 and standard deviation 1 over that set, using the n - 1 divisor. Use the same constants in every model. leave_sq = (standardized leave)^2, not restandardized.

- Branch U14: compute raw leave^2, then standardize it over the same set like the other variables.
- Branch U15: first average each variable within country over the set's surveys, then compute mean and SD over the 24 country means, and standardize the survey values with those constants.
- Branch U16: compute mean and SD over the individual rows of the origin M3 estimation sample.
- Under any branch that changes samples, recompute constants on that branch's own M3-equivalent stage-1 sample (same rule, branch data).

Individual centering: age_c = age minus the mean age of the model's estimation sample; age_c2 = age_c^2. bage_c = bage minus its mean in the model's estimation sample.

## 6. Models

Groups: country = iso3; survey = iso3 x year (nested in country). Every model has a random intercept and a random coefficient on female at the country level and at the survey level. Origin covariance: independent (no intercept-slope correlation) at both levels. Branch U20: unstructured 2 x 2 covariance at both levels.

Year: categorical survey-year indicators with the reference stated per model.

Let X = [leave, leave_sq, childcare, parttime]. Let C = [gdp, unemp, epl, status, wmgr, fert]. Let F x X = [female x leave, female x leave_sq, female x childcare, female x parttime].

| Model | Outcome | Sample | Fixed terms | Family | Year reference |
| --- | --- | --- | --- | --- | --- |
| M1 | activity | S1 | female, age_c, age_c2, postsecondary, year | logit | 2001 |
| M2 | activity | S1 | M1 + X + C | logit | 2001 |
| M3 | activity | S1 | M2 + F x X | logit | 2001 |
| M4 | planb | S2 | M3 terms + sole + bage_c | logit | 2001 |
| M5 | size | S2 | as M4 | linear (Gaussian) | 2001 |
| M6 | growth | S2 | as M4 | logit | 2001 |
| M7 | newprod | S2, years 2002-2008 | as M4 | logit | 2002 |
| M8 | newtech | S2, years 2005-2008 | as M4 | logit | 2008 |
| R1 | nascent | S1 | M3 terms | logit | 2001 |
| R2 | activity | steps 1, 2 and complete cases, without step 3 | M3 terms + not_employed, without fert (branch U26: with fert) | logit | 2001 |
| R3 | activity | S1 complete also on skill, fear, knows | M3 terms + skill + fear + knows | logit | 2001 |

Estimation: maximum likelihood. Logit models: Laplace approximation (adaptive quadrature is not available for this random-effects structure in the specified software; do not substitute another approximation). Linear model: ML, not REML. Branch U25 (M5 only): REML.

Native inference: model-based standard errors from the fitted model, Wald z, two-sided p.

Benchmark inference (for the same fixed terms, no random effects): for logit models, a pooled logistic regression with country-clustered sandwich standard errors (CR1 with G/(G-1) correction, G = number of countries), two-sided p from the normal distribution. For M5, pooled OLS with country clusters; because G < 30, also compute a wild cluster bootstrap p for each F x X term using Rademacher weights, the null imposed (restricted residuals), 999 replications, seed 20261028.

## 7. Weights

Origin: unweighted. A weighted branch is not executable with the specified mixed-model routines (their weights are not sampling weights). Do not implement weighting. Report it as unavailable.

## 8. Specifications to run and outputs

Run IDs, in this order:

1. ORIGIN: M1-M8, R1-R3 with origin settings.
2. Deviations, each changing exactly one setting from origin, fitted only for the listed models:
   - U01, U02, U05, U12, U13, U14, U15, U16, U17, U18, U19, U20, U22: M3, M4, M5, M6, M7, M8.
   - U03, U04, U06: M3 (U03 also R1).
   - U07, U08, U11, U24: M4, M5, M6, M7, M8.
   - U09, U10: M4. U23: M6. U25: M5. U26: R2.
   - N01: M3, M4, M5, M6, M7, M8.
3. Influence: for each of M3, M4, M5, M6, M7, M8 under origin settings, refit once for each country in its estimation sample with that country's rows removed. Keep standardization constants and centering means from the full origin sample. Record failed fits.

The script must take: data directory, output directory, and a list of run IDs (or "all", or "influence"). It must not stop when one fit fails: record the error and continue.

Write results.csv with one row per (run_id, model, term):
run_id, model, deleted_country (empty unless influence), status (ok / failed / not_estimable), error, n_obs, n_countries, n_surveys, sample_hash (SHA-256 of the sorted ID_9817_RDM values joined by commas), term, estimate, se, z, p, bench_se, bench_p, wild_p (M5 F x X only), loglik, aic, converged, singular, routine, sd_country_intercept, sd_country_female, sd_survey_intercept, sd_survey_female.

Also write constants.json (standardization means and SDs per run_id) and session_info.txt (software and package versions). Use term names exactly: (Intercept), female, age_c, age_c2, postsecondary, year2002 ... year2008, leave, leave_sq, childcare, parttime, gdp, unemp, epl, status, wmgr, fert, female:leave, female:leave_sq, female:childcare, female:parttime, sole, bage_c, not_employed, skill, fear, knows.
