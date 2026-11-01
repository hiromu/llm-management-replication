# Implementation notes for run.R (manifest P-7Q3, neutral, version 1)

Language: R 4.6.1, `/opt/homebrew/bin/Rscript`. Packages used: data.table (input, data handling, output), lme4 and Matrix (mixed models), sandwich (clustered covariance), lmtest (loaded, not required), jsonlite (constants.json), digest (sample hash). Nothing else is used; nothing was installed.

Command line:

```
Rscript run.R <data_dir> <out_dir> <run_ids>
```

`run_ids` is a comma-separated list of run IDs (`ORIGIN`, `U01` ... `U26`, `N01`), or `all` (ORIGIN plus every deviation in manifest section 8, no influence), or `influence` (influence runs for M3-M8 under origin settings). Extension for testing only: `influence:M4` or `influence:M3+M4` runs influence for the named models. Tokens may be mixed, e.g. `ORIGIN,U20,influence`. Plain runs are executed in manifest order regardless of the order given; influence runs come last.

Every fit is wrapped in `tryCatch`; data preparation for a run is wrapped separately. A failure writes a row with `status = failed` and the error message and the script continues with the next model/run. Outputs are always written at the end.

## 1. Input files

`read_inputs()`: `data.table::fread(..., na.strings = c("", "NA"))`, with `ID_9817_RDM` forced to character. All code columns listed in the manifest are coerced with `as.numeric()`; `iso3` is trimmed and upper-cased; `year = GEM_YR`. `country_year_inputs.csv` is de-duplicated on (iso3, year) (`unique(..., by = c("iso3","year"))`, first row kept). Columns not named in the manifest are ignored.

## 2. Roster

`ROSTER` list in the script reproduces section 2 (143 surveys). Step 1 keeps rows whose (iso3, year) is in the roster. U05 (`roster = "U05"`): rows with iso3 among the 24 countries and 2001 <= year <= 2008. The synthetic file covers 111 of the 143 roster surveys; the script simply uses the surveys present.

## 3. Individual variables (`build_individual()`)

All derived with `data.table::fifelse`; "else missing" is `NA`. `in_set(x, set)` is `!is.na(x) & x %in% set`.

- female, age, postsecondary, employed, not_employed: exactly as section 3.
- Screening items (`code_screen()`): 1 or 100 -> 1, 0 -> 0, 8 and 9 -> NA; any other value -> NA. U06 (`screen8 = "U06"`): 8 -> 0 for BSTART, OWNMGE, SUSKILL, FEARFAIL, KNOWENT only. NBSTATUS always uses 8 -> NA.
- activity (origin): 1 if SUBOANWT = 1 or coded OWNMGE = 1; 0 if SUBOANWT = 0 and coded OWNMGE = 0; else NA. The screening-coded OWNMGE is used here, so U06 changes activity (this is why U06 is listed for M3). U03 and U04 as written; "SUWAGE is not 1" is true when SUWAGE is missing. In each definition the "= 1" condition is tested first, then the "= 0" condition, else NA.
- nascent = SUBOANWT (0/1, else NA); U03 as written with screening-coded BSTART.
- owner: origin coded OWNMGE = 1; U07 OMESTBBT = 1; U08 coded OWNMGE = 1 and OMOWN in {1, 2}. Owner is 1/0 (never NA) because only owner = 1 is used.
- planb, newprod, newtech, sole (origin and U24), size: as written. size requires 0 <= OMNOWJOB <= 999998.
- growth (origin): missing if OMNOWJOB or OMYR5JOB is NA or in {999999, 9999997, 9999999}; else 1 if OMYR5JOB - OMNOWJOB > 5, else 0. U23: 1 if OMYR5JOB > 5, 0 otherwise, missing only when OMYR5JOB is missing by the same code rule (choice: the manifest does not say whether OMNOWJOB missingness still applies under U23; it is not used by the U23 formula, so it is not required).
- bage_years = year - OMWAGEYR when 1990 <= OMWAGEYR <= GEM_YR, else NA. bage = log(bage_years), NA when bage_years = 0; U11: log(bage_years + 1).
- survey id = `paste(iso3, year, sep = "_")`.

## 4. Samples

Flags `step1` (roster, and under N01 also year not in {2001, 2002}), `step2` (origin `age > 18 & age < 55`; U01 `age >= 18 & age < 55`), `step3` (origin `employed == 1`; U02 `GEMWORK %in% c(1, 2, 6)`). `build_sample()` then applies, per model, `complete.cases()` on:

- S1 (M1, M2, M3, R1): rows with step1 & step2 & step3, complete on activity, female, age, postsecondary and the model's survey-level variables (none for M1; X and C for M2, M3, R1). For R1 the outcome nascent must also be non-missing (choice: the manifest defines S1 via activity; a missing outcome cannot enter the fit, so R1's sample is S1 intersected with non-missing nascent; under origin nascent is never missing so the two coincide).
- R3: S1 (X and C) also complete on skill, fear, knows.
- R2: step1 & step2 only (no step 3), complete on activity, female, age, postsecondary, not_employed and X and C without fert (with fert under U26). Rows with GEMWORK = 9 or empty drop out because not_employed is missing.
- S2 (M4-M8): step1 & step2 & step3 & owner = 1, restricted to the model's year window (M7: 2002-2008, M8: 2005-2008), complete on the outcome, female, age, postsecondary, sole, bage, X and C.

Each model's estimation sample is its own complete-case set. `n_obs`, `n_countries`, `n_surveys` and `sample_hash` are computed on that set.

Sample hash: `digest::digest(paste(ids, collapse = ","), algo = "sha256", serialize = FALSE)` on the sorted `ID_9817_RDM` values. If every id is a non-negative integer string, ids are sorted in numeric order (by length, then lexically); otherwise in byte order (`sort(method = "radix")`).

## 5. Survey-level variables (`build_survey()`)

One row per (iso3, year) present in gem_extract.csv.

- leave: `leave_fte_weeks` from country_year_inputs at year - lag, lag = 1 (origin), 0 (U17), 2 (U18), implemented by shifting the year key of the inputs table before the merge.
- childcare: `childcare_interp` (origin) or `childcare_pct_gdp_annual` (U19); parttime: `pt_common_employees_women` (origin), `pt_national_women` (U12), `pt_common_total_women` (U13); gdp, unemp, epl, wmgr, fert from the survey year.
- status: mean of coded NBSTATUS (0/1 only, 8/9/empty excluded, unweighted) among all gem_extract.csv respondents of that iso3 and year (all ages and work statuses). U22: among respondents passing steps 1-3 only. Carry-back: a survey year with no 0/1 NBSTATUS response takes the value of the earliest later year of the same country that has responses (choice: "later year" means any later survey year present in gem_extract.csv for that country, not only roster years, because the proportion itself is defined on all respondents; under U22 the candidate years are those with step 1-3 respondents). If no later year has responses, status stays missing and the survey drops out of models with C. N01: no carry-back and 2001 and 2002 surveys removed in step 1. The source year of each survey's status is kept internally (`status_source_year`).

Standardization (`compute_constants()`, `apply_constants()`): for every run, the constants are computed on that run's own M3-equivalent stage-1 sample (steps 1-3, complete on activity, female, age, postsecondary and X and C, under the run's settings). For ORIGIN this is the origin M3 stage-1 sample; for branches that change nothing relevant the constants equal the origin ones. Origin: each variable's values over the distinct surveys of that sample (each survey once), `mean()` and `sd()` (n - 1 divisor); z = (x - mean) / sd; leave_sq = z_leave^2, not restandardized. U14: raw leave^2 is added as a variable and standardized over the same set. U15: survey values averaged within country (`lapply(.SD, mean), by = iso3`), then mean and sd over the country means (24 in the real data; the number present in the synthetic data), applied to the survey values. U16: mean and sd over the individual rows of the M3 estimation sample. The same constants are applied to all models in the run. constants.json records the unit, the number of units, and all means and SDs per run_id.

Centering (`center_sample()`): age_c = age - mean(age) over the model's estimation sample; age_c2 = age_c^2; bage_c = bage - mean(bage) over the model's estimation sample (S2 models only). Means are recorded in constants.json under `centering`. Influence runs reuse the full origin sample's constants and centering means (centering is applied before the country is removed).

## 6. Models (`make_formulas()`, `fit_mixed()`)

Year: `factor(year, levels = c(ref, other years present))`, so dummies are named `year2002` ... `year2008` and the reference is 2001 (M1-M6, R1-R3), 2002 (M7), 2008 (M8). If the stated reference year is absent from a model's sample (this happens under N01, where 2001 and 2002 are dropped), the earliest year present becomes the reference (choice; recorded here). Years absent from the sample get no dummy.

Fixed terms by model follow the table in section 6; interactions are written `female:leave` etc. so the coefficient names match the manifest exactly. R2 omits fert (includes it under U26) and adds not_employed; R3 adds skill, fear, knows; M4-M8 add sole and bage_c.

Random effects, origin (independent intercept and female slope at both levels):

```
(1 | iso3) + (0 + female | iso3) + (1 | survey) + (0 + female | survey)
```

U20 (unstructured 2 x 2 at both levels): `(1 + female | iso3) + (1 + female | survey)`. survey is the iso3 x year id, so nesting is implicit in the id.

Calls:

- logit models: `lme4::glmer(formula, data, family = binomial(link = "logit"), nAGQ = 1L)` (Laplace), default `glmerControl()` (optimizer bobyqa for the nAGQ = 0 stage then Nelder_Mead; default tolerances and iteration limits).
- M5: `lme4::lmer(formula, data, REML = FALSE)` (ML), default `lmerControl()` (nloptwrap / bobyqa). U25: `REML = TRUE`.

Native inference: `summary(fit)$coefficients` Estimate and Std. Error; z = estimate / se; p = 2 * pnorm(-|z|) for both glmer and lmer. loglik = `logLik(fit)` (REML criterion under U25), aic = `AIC(fit)`.

`converged` = TRUE when the optimizer return code is 0 and lme4 recorded no convergence message other than the boundary/singular message. `singular` = `lme4::isSingular(fit)` (default tolerance 1e-4). Random-effect SDs come from `as.data.frame(VarCorr(fit))` matched on grouping factor (iso3 / survey) and term name; the U20 correlations are not written (no column in the spec).

Warnings from the fit (convergence, singularity, rank deficiency) are stored in the `error` column prefixed `warning:` even when status is ok; newlines are collapsed to spaces. `routine` names the function and settings used.

Benchmark inference (`fit_bench()`): logit models `glm(fixed formula, family = binomial)`; M5 `lm(fixed formula)`. Covariance `sandwich::vcovCL(fit, cluster = x$iso3, type = "HC0", cadjust = TRUE)`, which is the CR1 estimator with the G/(G-1) factor only (no (N-1)/(N-K) factor). bench_se = sqrt(diag), bench_p = 2 * pnorm(-|estimate_pooled / bench_se|). Note that bench_p uses the pooled estimate, not the mixed-model estimate (the pooled estimate itself is not written because the spec has no column for it).

Wild cluster bootstrap (`wild_cluster_p()`, M5 only, the four F x X terms): for each term, the restricted OLS model without that term gives fitted values and residuals; `set.seed(20261028)` is called before each term's loop, so all four terms use the same Rademacher draws; 999 replications of y* = fitted_r + w_g * e_r with w_g in {-1, +1} per country; the full model is refitted on y* by closed-form OLS and the term's t-statistic uses the same CR1 (G/(G-1)) cluster variance as the benchmark; wild_p = proportion of replicates with |t*| >= |t_observed| (no +1 adjustment). The CR1 variance inside the bootstrap was checked against `vcovCL(type = "HC0")` on simulated data (identical). wild_p is written only for M5 rows with those four terms.

## 7. Weights

Not implemented, as instructed. results.csv contains one row `run_id = WEIGHTED`, `status = not_estimable` with the reason whenever ORIGIN is run.

## 8. Runs and outputs

Run lists are hard-coded from section 8 (`DEV_MODELS`). Influence rows have `run_id = INFLUENCE`, `model`, and `deleted_country`; one refit per country in the model's full origin estimation sample; constants and centering means from the full origin sample; n_countries is therefore G - 1.

results.csv: one row per (run_id, model, term); columns exactly as section 8 in that order, empty for NA, written with `data.table::fwrite`. For a fit that fails: one row per term if the benchmark design could be built (status failed, bench columns filled, mixed columns empty), else one row with term empty. A model whose sample is empty, whose outcome has no variation, or which has fewer than two countries is written as `not_estimable` with the reason.

constants.json: per run_id, the settings used, the standardization unit and size, the means and SDs per variable (including `leave_sq_raw` under U14), the leave_sq rule, and the per-model centering means and n_obs. The INFLUENCE entry notes that the origin constants are reused.

session_info.txt: `sessionInfo()` output plus package versions, the command-line arguments and the elapsed time.

## Defaults relied on (summary)

- `glmerControl()` and `lmerControl()` defaults (optimizers, tolerances, max evaluations, convergence checks).
- `isSingular()` default tolerance 1e-4.
- `vcovCL()` with `type = "HC0"` and `cadjust = TRUE` for CR1 as defined in the manifest.
- `sd()` uses the n - 1 divisor.
- `fread` type detection, with explicit coercion of all code columns to numeric and the id to character.
- R's `factor()` ordering for year levels after the reference.

## Choices where the manifest is silent (all listed above, collected)

1. R1 sample additionally requires non-missing nascent.
2. Status carry-back uses any later survey year present in gem_extract.csv (U22: among step 1-3 respondents).
3. Absent reference year: earliest year present becomes the reference (N01).
4. U23 growth is missing only when OMYR5JOB is missing.
5. Sample hash sorts integer ids numerically, other ids in byte order.
6. One seed per term in the wild bootstrap; p = proportion of |t*| >= |t|.
7. bench_p is based on the pooled estimate.
8. Singular fits count as converged when the optimizer reports success; singularity is reported in its own column.
9. Influence run id is `INFLUENCE`; the weighted branch is reported as a `WEIGHTED` not_estimable row.

## Not implemented

- Weighted branch (manifest section 7): reported as unavailable.
- Adaptive quadrature: not used, per the manifest (Laplace only).
