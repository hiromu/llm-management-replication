# Implementation notes — manifest P-7Q3

The deliverable is `run.R`, using only the permitted R packages. No packages were installed, no network access was used, and no input files were changed.

## Running

```sh
/opt/homebrew/bin/Rscript run.R synthetic output ORIGIN
/opt/homebrew/bin/Rscript run.R synthetic output U03,U09,U25
/opt/homebrew/bin/Rscript run.R synthetic output all
/opt/homebrew/bin/Rscript run.R synthetic output influence
```

There are exactly three command-line arguments. `all` means ORIGIN and every listed deviation/check, excluding influence. Runs are ordered as the groups and IDs appear in manifest section 8, regardless of argument order. Duplicate requested IDs are collapsed. U21 is not a listed run and is rejected, as are other unknown IDs. `influence` runs all six specified models. A comma-separated selection may include `influence`.

The file is also sourceable. The callable `run_analysis()` exposes `influence_models` solely to allow the required smaller influence test; its default, and the CLI, include M3–M8. Sourceable preparation and fitting functions support independent validation without changing the production CLI.

Each output directory contains `results.csv`, `constants.json`, and `session_info.txt`. Results and constants are checkpointed after each fit. An existing output directory's three output files are replaced; other files are not removed.

## 1. Inputs and identity

`read_inputs()` calls `utils::read.csv()` with UTF-8, `na.strings=''`, unchanged column names, and character respondent/country identifiers. Other column types use `read.csv` inference. It checks required columns, unique/nonmissing respondent IDs, nonmissing country/year keys, and unique country-year input keys. Extra columns are ignored. Duplicate or structurally invalid inputs raise an input error before estimation, rather than silently multiplying records in a join.

Joins use `match()` on `iso3:year` keys and preserve respondent order. Missing country-year matches become missing covariates. Hashing preserves IDs as strings (including leading zeros), sorts with `sort(method='radix')`, joins with literal commas and no newline, then uses `digest::digest(algo='sha256', serialize=FALSE)`. Thus identifier sorting is lexical, not numeric; IDs are identifiers rather than measurements. No respondent rows or identifiers are printed in logs or results.

## 2–4. Roster, individual recodes and samples

`ROSTER` explicitly transcribes all 143 surveys across 24 countries; no balanced panel is imposed and unavailable surveys are not fabricated. `recode_individuals()` implements the roster, recodes, and sample eligibility flags. `binary()` maps listed yes/no values and makes all other values missing; `screen()` implements 0/1/100/8/9 screening rules. Logical ORs retain an affirmative activity value when another constituent is missing. Explicit zeros require the manifest's stated zero conditions.

Individual construction follows the manifest:

- Gender, education and work use the exact code lists. Age codes 99/999 are missing; origin uses strictly `age > 18 & age < 55`. `not_employed` always derives from the original employed definition.
- Origin activity uses SUBOANWT and recoded OWNMGE. Nascent uses SUBOANWT 0/1. Skill, fear and knows use screening coding. Owner eligibility uses recoded OWNMGE.
- Plan B uses OMREASON; size uses `log1p()` only for 0–999998 inclusive. Growth removes the three specified count sentinels and empty counts, then tests a difference strictly greater than five. Unlike size, growth has no additional count bounds not stated in the manifest.
- New product, technology and sole ownership use their listed code sets.
- Business age allows OMWAGEYR from 1990 through survey year, treating 1990 literally as directed. Origin uses `log()` of positive age only; zero is missing. It does not impute a date for the “1990 or earlier” category.

`model_sample()` applies roster, age, work (except R2), outcome-specific owner/year restrictions, then `complete.cases()`. S2 does not require complete activity. R1 is an S1 sample, so it requires complete activity as well as its own nascent outcome. R3 additionally requires skill, fear and knows. M1 has no survey-covariate deletion. R2 excludes fertility from its own completeness check except in U26, and requires observed work status to construct `not_employed`.

Sample counts and hashes describe the exact rows passed to the fit, including for failed, singular, or partially aliased fits. Missing standardization constants do not silently change the model's raw-variable complete-case sample; affected models are reported as `not_estimable`.

Each branch changes only its stated setting:

| Branch | Implementation |
|---|---|
| U01 | Age lower bound becomes `>= 18`. |
| U02 | Work eligibility includes GEMWORK 6; it does not redefine employed. |
| U03 | BSTART/SUWAGE activity and nascent alternatives. “SUWAGE is not 1” is implemented literally as `!(SUWAGE %in% 1)`, including empty, don't-know and refusal values. BSTART remains subject to screening missingness. |
| U04 | Three-flag activity definition with affirmative OR and explicit all-zero rule. |
| U05 | Every available 2001–2008 survey in the 24 countries. |
| U06 | Screening code 8 becomes zero for the five listed items; NBSTATUS stays unchanged. |
| U07, U08 | Established-owner restriction, or OWNMGE plus OMOWN 1/2 restriction. |
| U09, U10 | Alternative OMREASON grouping, or OMWHY coding. |
| U11 | Business age uses `log1p()`, admitting zero-age businesses. |
| U12, U13 | National-women or common-total-women part-time series. |
| U14 | Raw leave squared is separately standardized. |
| U15 | Equal weighting of observed country means for standardization. |
| U16 | Individual-row rather than survey weighting for standardization. |
| U17, U18 | Same-year or two-year-lagged leave, matched by calendar year. |
| U19 | Annual childcare GDP series. |
| U20 | Correlated intercept/female random effects at both levels. |
| U22 | Status respondents must pass that branch's roster, age and work filters. |
| U23 | Growth tests future jobs > 5; only the future count is required by this alternative definition. |
| U24 | Sole ownership uses valid OMOWNERS counts 1 versus 2–998. |
| U25 | M5 changes to REML, with all other settings including the pooled benchmark unchanged. |
| U26 | R2 includes fertility in fixed effects and completeness. |
| N01 | Drops 2001/2002 and disables status carryback; explicitly a non-equivalent check. |

`RUN_MODELS` limits each branch to exactly the models listed in section 8. Unlisted interactions between branches are never run.

## 5. Survey variables, scaling and centering

`survey_variables()` matches leave to year minus one (or the branch lag); other variables match survey year and their specified source columns. It computes status with `tapply(..., mean)` from all source respondents with valid recoded NBSTATUS, before analytical eligibility filters. U22 alone limits those respondents to steps 1–3. This means U22's carryback sources must also pass its roster eligibility.

For a survey without valid status responses, it finds the earliest strictly later observed year of the same country with responses. It uses the original observed proportions, not an average of later years. Origin source years may lie outside the analysis roster. There is no backward-year fallback and no interpolation. If no later response year exists, status remains missing. N01 disables fallback entirely.

`prepare_run()` constructs the branch's M3-equivalent S1 sample from raw complete survey covariates and individual variables. The origin scale unit is one distinct survey; `mean()` and `sd()` supply the mean and sample SD with divisor n−1. All models in a run use the same constants. Every branch recomputes its own constants, including branches whose M3-equivalent sample happens to be unchanged.

Origin `leave_sq = leave^2` after scaling leave. In U14, raw leave squared obtains its own mean/SD over the same anchor surveys. U15 uses `aggregate(..., FUN=mean)` within country, then the mean/SD across observed country means. It uses the actual countries represented in the anchor, not fictitious observations for absent countries; `n_countries` records coverage. U16 computes constants over the anchor's individual rows. Zero, missing or nonfinite scale SDs are disclosed and cause affected models to be non-estimable.

`constants.json` is keyed by run ID and includes all variable means/SDs, scaling method, anchor counts/hash, leave-square construction, invalid variables, and per-model centering means. `mean()` centers age within each model's final sample; age squared is computed afterward. S2 business age is centered in that same model's sample. Unused business-age centers are JSON null.

## 6. Models and estimation

`model_spec()` supplies each outcome, family, fixed-term list, year range and reference. Fixed terms match the manifest, including the four female interactions and model-specific extra covariates. Survey is a globally unique country-year factor nested within country.

Origin random effects are `(1 + female || country) + (1 + female || survey)`, which `lme4` expands into independent intercept and numeric-female terms. U20 uses `(1 + female | country) + (1 + female | survey)`.

Binomial fits call `lme4::glmer(..., family=binomial(link='logit'), nAGQ=1, na.action=na.fail)`. Gaussian fits call `lme4::lmer(..., REML=FALSE, na.action=na.fail)`, except U25 sets `REML=TRUE`. No weights are supplied. No approximation changes, optimizer retries, or silent model simplifications are made.

Year categories are represented by explicit 0/1 columns, algebraically equivalent to treatment coding with the specified reference: 2001 ordinarily, 2002 for M7, and 2008 for M8. All declared non-reference columns are retained in the requested term roster, even for an unobserved year. This preserves exact output names and avoids silently switching the reference year when coverage is incomplete.

`lme4`'s default rank check may drop columns. Dropped terms are marked `not_estimable`. A QR relation between dropped and retained columns also identifies retained coefficients that cannot be individually identified without an arbitrary constraint. Their estimates and inference are suppressed as well. In particular N01 lacks reference year 2001, so its intercept and year coefficients cannot represent comparisons with 2001; these are non-estimable, while identifiable policy coefficients can still be reported. This is a data identification issue, not a substituted reference category.

Native inference uses `fixef()`, `vcov()`, and `2 * pnorm(-abs(estimate/se))` for every family. M5 therefore also has normal/Wald z inference, not lmerTest t degrees of freedom. `logLik()` and `AIC()` use the fitted object's default definitions; U25 reports the REML-based values returned by those functions, without pretending they are ML-comparable. `VarCorr()` supplies all four requested SDs. `isSingular()` uses its default tolerance (1e−4). Native convergence combines optimizer return codes and lme4 convergence diagnostics; a singular-boundary message alone does not imply nonconvergence. Optimizer warnings, rank messages and diagnostic messages are retained in `error` even when coefficients are available.

### Pooled benchmark

`glm(..., family=binomial('logit'))` or `lm()` uses exactly the same fixed formula and rows as the corresponding mixed fit. `sandwich::vcovCL(cluster=iso3, type='HC0', cadjust=TRUE)` implements the explicitly requested G/(G−1) cluster correction. HC0 is deliberate: it avoids adding an unrequested HC1 observation/parameter multiplier. The default `fix=FALSE` is retained. Two-sided p-values use the pooled coefficient and the clustered SE with `pnorm()`, not the mixed-model coefficient and not a t distribution. The output does not add a pooled coefficient column because the prescribed schema has none.

Benchmark failure is disclosed with missing benchmark fields and does not prevent mixed fitting. A wild-bootstrap failure similarly leaves valid benchmark SE/p fields intact. Pooled nonconvergence is treated as a benchmark failure. Benchmark separation warnings are retained.

### M5 wild cluster bootstrap

There is no permitted package providing this exact bootstrap as a one-call default. `wild_cluster()` implements a restricted wild cluster bootstrap-t with `stats` linear algebra:

1. Test each female interaction's coefficient against zero separately. Fit the restricted OLS model with that term omitted, keeping every other fixed term.
2. Draw 999 independent country-level Rademacher signs using `set.seed(20261028)` and `sample(c(-1,1), ..., replace=TRUE)`. A sign is shared by all respondents in a country. The same sign matrix is used across the four nulls in that fit; the seed is reset for each M5 fit.
3. Form each bootstrap response from the restricted fitted values plus restricted residuals multiplied by those signs. Fit the unrestricted OLS design with `qr.coef()`/`qr.resid()`.
4. Studentize with the same HC0, G/(G−1) clustered variance. Report the empirical fraction of `abs(t_boot) >= abs(t_observed)` over all 999 replicates, without a plus-one adjustment.

The null, studentization, shared draws, unadjusted restricted residuals and empirical-tail convention are explicit algorithm choices where the manifest does not further specify a variant; they are not claimed to be a package default. The fixed-design matrix implementation was checked against independent `lm()` and `vcovCL()` refits. Non-estimable interactions have missing wild p-values. All eligible countries are in a 24-country roster, so the specified G < 30 condition always holds. Fewer than two countries makes clustered inference unavailable.

## 7. Unavailable sampling weights

No weighted model is implemented: lme4 weights are not the requested survey sampling weights. Because the manifest supplies no weighted run ID, each completed invocation appends one clearly labeled `WEIGHTED_UNAVAILABLE` row, with blank model/term, `status=not_estimable`, and an explicit reason. It has no sample or estimates and is not an extra fitted specification. This is the only intentionally unavailable software capability.

## 8. Influence, output and failure handling

For each requested influence model, `model_sample()` first builds the full origin sample and centers it. The country-deletion loop then removes each represented country with `droplevels()`, without repeating completeness selection, standardization, or centering. Both native and benchmark fits use the frozen covariates. The run ID is `influence`, and `deleted_country` disambiguates country-specific rows. Influence constants record the full origin anchor and full-model centers.

`result_template()` fixes the exact column order and requested term names. `write.csv(row.names=FALSE, na='')` represents unavailable numeric values with empty cells and logical diagnostics with TRUE/FALSE. `jsonlite::write_json(pretty=TRUE, auto_unbox=TRUE, na='null', null='null', digits=16)` serializes constants. `session_info.txt` includes `sessionInfo()`, every permitted package's version, complete default mixed-model control objects, `glm.control()` and RNG kind.

`capture_conditions()` uses `withCallingHandlers()` to collect warnings/messages and `tryCatch()` for errors. Each fitting/extraction failure becomes rows for the requested terms with `status=failed`; successful subsequent fits continue. Empty samples, invalid scaling and unidentified terms use `not_estimable`. `status=ok` means an estimate/inference was returned, not a promise of convergence; consumers must also inspect `converged`, `singular`, and `error`. Fit counts/hash survive failures. Errors during initial file validation are fatal input errors rather than fit errors.

## Defaults and reproducibility

Unspecified statistical controls use the installed software defaults. In this environment glmer uses the bobyqa/Nelder_Mead optimizer sequence and lmer uses nloptwrap; optimizer tolerances, starts, boundary handling, derivative calculation and convergence checks are unchanged. The complete control lists are saved to session information instead of selectively reconstructing them. Rank checking uses the default `message+drop.cols`. The glmer initial nAGQ0 optimization step is left at its default, but the fitted likelihood requested and reported is nAGQ=1 Laplace.

`glm()` uses its default IRLS initialization and `glm.control()` (epsilon 1e−8, maxit 25, trace FALSE); `lm()` uses default QR fitting, intercept and singular handling. Both explicitly use `na.fail` after sample construction. No offsets, frequency weights, sampling weights or custom contrasts are added. The explicit dummy variables make factor contrast options irrelevant to year coding. `qr()` retains its default tolerance 1e−7; alias dependence is screened at 1e−7. `pnorm()`, `mean()`, `sd()`, `log()`, `log1p()`, `logLik()`, `AIC()` and `vcov()` use their defaults unless stated above. The bootstrap uses R's default RNG kinds (recorded in session information), with the mandated explicit seed. CSV quoting/type inference and `write.csv()` numeric formatting retain base defaults. JSON precision is explicitly set to 16 digits for reusable scaling constants. Locale and platform are recorded by `sessionInfo()`; identifier sorting explicitly uses radix order.
