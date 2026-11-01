# Implementation notes for manifest P-7Q3 (run.jl)

Language: Julia 1.12.6. Packages used: MixedModels 5.9.1, GLM 1.9.5, StatsModels 0.7.10,
DataFrames 1.8.2, CSV 0.10.17, JSON3 1.14.3, CategoricalArrays 1.1.1 (loaded only; year
indicators are built by hand), Distributions 0.25.132, and the standard libraries
LinearAlgebra, Statistics, Random, SHA, Printf, Dates. SparseArrays is reached through the
binding `MixedModels.SparseArrays` (needed only for the work-around in section 0 below).

Command line: `julia run.jl <data_dir> <out_dir> <run_ids>` where run_ids is a
comma-separated list of run IDs, `all` (ORIGIN plus every deviation of manifest section 8,
no influence), or `influence`. `influence` may also be listed together with other IDs.
As a testing aid, `influence:M5` (or `influence:M3+M5`) restricts the influence refits to
the named models; plain `influence` does all of M3-M8 as the manifest requires.
Runs are always executed in manifest order (ORIGIN, U01 ... U26, N01, influence) whatever
the order on the command line. results.csv and constants.json are rewritten after every
completed run so partial output survives an interruption. Every fit is wrapped in
try/catch: a failed fit yields one row with status `failed` and the error text, and the
script continues. `main` only runs when the file is executed as a script, so a test
harness can `include("run.jl")` and call the functions directly.

Run time. The manifest's estimator (`fast = false`: the fixed effects are optimised jointly
with the covariance parameters by the derivative-free NLopt optimiser, each objective
evaluation being a full PIRLS solve) is slow for the stage-1 models. On the synthetic data
(6,579 stage-1 rows, 25-28 fixed effects) one stage-1 logit fit takes 1-6 minutes and
about 17,000 objective evaluations; the full ORIGIN run takes about 15 minutes, while the
stage-2 models and the linear model take seconds. Cost grows roughly linearly in the
number of rows, so on the real data a stage-1 fit may take tens of minutes and `all`
(113 fits, about 50 of them stage-1 size) many hours. `fast = true` would be about 100
times faster but is a different approximation (fixed effects profiled inside PIRLS) and
the manifest forbids substituting it; no starting-value or tolerance tricks were applied
either (software defaults, section 9). To spread the work, run IDs can be split across
separate invocations writing to separate output directories (e.g. one process per
deviation), because every run recomputes its own constants from the data.

## 0. Defect in MixedModels 5.9.1 and the work-around used

Every logit model in the manifest has two grouping factors (country and survey) each
carrying two random-effects columns (intercept and female). When MixedModels fits a GLMM it
re-weights the working design in every PIRLS step and recomputes the cross-product blocks
`Z_i' W Z_j` with `updateA!`. The off-diagonal country-by-survey block is stored as a
`SparseMatrixCSC`, and MixedModels 5.9.1 only defines the specialised in-place product
`mul!(::SparseMatrixCSC, ::Adjoint{ReMat{T,1}}, ::ReMat{T,1})` for single-column terms.
For two multi-column terms the call falls through to the generic LinearAlgebra method,
which writes wrong values into the sparse block. The consequence, reproduced on the
synthetic data, is `PosDefException` at the first objective evaluation with
`fast = false` (every manifest model), and a silently wrong objective with `fast = true`.
Models with only one grouping factor, or with intercept-only random effects, do not touch
this code path and fit normally. The linear mixed model (M5) is unaffected because its
cross-products are formed once at construction by a different (correct) method.

run.jl therefore defines, in its own session, the missing method
`LinearAlgebra.mul!(C::SparseMatrixCSC{T}, adjA::Adjoint{T,<:ReMat{T,S}}, B::ReMat{T,P})`
for general S and P. It fills the existing sparsity pattern of C with exactly
`sum_k A.wtz[:,k] * B.wtz[:,k]'` placed at the block positions of observation k's two
group levels, and throws if an entry falls outside the pattern (the pattern is fixed
because the grouping factors never change). It was checked against the explicit product
`Z2' * Diagonal(w) * Z1` (maximum absolute difference 4e-15) and against the
single-column method already in the package. The installed package is not modified. With
this method in place the specified estimator (Laplace, `fast = false`, `nAGQ = 1`) runs
and the synthetic fits recover the generating values (see test_report.md). This is the
only place where the script goes beyond calling the documented API; it is necessary to
run the manifest's estimator at all with the permitted software.

## 1. Input files

Both files are read with `CSV.read(path, DataFrame; missingstring = ["", "NA"])`. Empty
cells are missing. `iso3` is converted to `String`; `GEM_YR` to `Int`. Columns not named in
the manifest are ignored. Rows of gem_extract.csv are never printed.

## 2. Roster

Origin roster: the 143 (iso3, year) pairs of manifest section 2, hard-coded in
`ORIGIN_ROSTER`. Branch U05: every (iso3, year) pair present in gem_extract.csv with iso3
among the 24 roster countries and 2001 <= year <= 2008. Check N01: the roster (origin or
U05) minus every 2001 and 2002 survey, and no status carry-back (section 5).

## 3. Individual variables

Implemented in `derive_individual` with element-wise comprehensions; all derived variables
are `Union{Missing, Float64}`.

- female: GEMSEX 2 -> 1, 1 -> 0, anything else (incl. 9, empty) -> missing.
- age: GEMAGE; 99, 999 and empty -> missing.
- postsecondary: {1316, 1720} -> 1; {0, 111, 1212} -> 0; else missing.
- employed: GEMWORK {1, 2} -> 1; {3, 4, 5, 6} -> 0; else missing. not_employed = 1 - employed.
- Screening items (function `scr`): 1 or 100 -> 1; 0 -> 0; 8, 9, any other code, empty ->
  missing. U06 (`dk_zero`): 8 -> 0 for BSTART, OWNMGE, SUSKILL, FEARFAIL, KNOWENT only.
  NBSTATUS is always coded with 8 missing (U06 does not list it).
- activity (origin): SUBOANWT = 1 or OWNMGE(screening-coded) = 1 -> 1; both 0 -> 0; else
  missing. Because OWNMGE enters through its screening coding, U06 (run for M3 only) also
  turns OWNMGE = 8 into 0 inside activity. U03: (BSTART = 1 and SUWAGE not 1) or OWNMGE = 1
  -> 1; BSTART = 0 and OWNMGE = 0 -> 0; else missing. "SUWAGE is not 1" is true when SUWAGE
  is empty. U04: any of SUBOANWT, OMBABYBT, OMESTBBT = 1 -> 1; all three 0 -> 0; else missing.
- nascent: SUBOANWT (1 -> 1, 0 -> 0, else missing). U03: BSTART = 1 and SUWAGE not 1 -> 1;
  BSTART = 0 -> 0; else missing.
- skill, fear, knows: screening coding of SUSKILL, FEARFAIL, KNOWENT.
- owner: screening-coded OWNMGE (1/0/missing). U07: OMESTBBT (1/0). U08: 1 if OWNMGE = 1 and
  OMOWN in {1, 2}, 0 if OWNMGE is non-missing otherwise, missing if OWNMGE is missing. Only
  owner = 1 matters for the stage-2 sample.
- planb: OMREASON 2 -> 1; {1, 3, 4, 6} -> 0; else missing. U09: {2, 3} -> 1; {1, 4, 6} -> 0.
  U10: OMWHY -1 -> 1; {0, 1} -> 0; else (9, empty) missing.
- size: ln(OMNOWJOB + 1) for 0 <= OMNOWJOB <= 999998; else missing.
- growth: both OMNOWJOB and OMYR5JOB in 0..999998 required; 1 if OMYR5JOB - OMNOWJOB > 5
  else 0. U23: 1 if OMYR5JOB > 5 else 0, missing only when OMYR5JOB is missing/coded
  (OMNOWJOB is not used by the U23 rule; my reading of the branch text).
- newprod: OMNEWCST 1 -> 1; {2, 3} -> 0; else missing. newtech: OMNEWT_5 {1, 2} -> 1; 3 ->
  0; else missing.
- sole: OMOWN 1 -> 1; 2 -> 0; else missing. U24: OMOWNERS 1 -> 1; 2..998 -> 0; else missing.
- bage_years = GEM_YR - OMWAGEYR when 1990 <= OMWAGEYR <= GEM_YR, else missing. bage =
  ln(bage_years), missing when bage_years = 0. U11: ln(bage_years + 1).

## 4. Samples

`step_masks` builds step 1 (roster membership), step 2 (18 < age < 55; U01: 18 <= age < 55;
missing age fails the step) and step 3 (employed = 1; U02: GEMWORK in {1, 2, 6}).

`model_sample` applies, per model, complete-case deletion on exactly the variables listed:

- S1 (M1, M2, M3, R1): steps 1-3, complete on activity, the model's outcome (nascent for
  R1), female, age, postsecondary and the model's survey-level variables (none for M1; X
  and C for the others; leave_sq is complete whenever leave is).
- R3: S1 and complete on skill, fear, knows.
- R2: steps 1-2 (no employment step), complete on activity, female, age, postsecondary,
  not_employed and the survey-level variables of the model (fert excluded; U26 includes it).
- S2 (M4-M8): steps 1-3, owner = 1, complete on the model's outcome, female, age,
  postsecondary, sole, bage and the survey-level variables. M7 additionally keeps years
  2002-2008, M8 years 2005-2008.

n_obs, n_countries, n_surveys are counted on the estimation sample. sample_hash is the
SHA-256 hex digest of the ID_9817_RDM values of the estimation sample, sorted numerically
and joined by commas without spaces (`bytes2hex(sha256(join(string.(sort(ids)), ",")))`).

## 5. Survey-level variables

`survey_table` builds one row per roster survey:

- leave = leave_fte_weeks of (iso3, year - 1); U17: year; U18: year - 2. Missing if that
  (iso3, year) row does not exist in country_year_inputs.csv.
- childcare = childcare_interp (U19: childcare_pct_gdp_annual); parttime =
  pt_common_employees_women (U12: pt_national_women; U13: pt_common_total_women); gdp,
  unemp, epl, wmgr, fert from the survey year.
- status (`compute_status`): per (iso3, year), the unweighted share of NBSTATUS = yes (1 or
  100) among respondents with NBSTATUS yes or no, over all gem_extract.csv rows of that
  survey (U22: only rows passing steps 1-3). If a roster survey has no such respondents,
  the value of the earliest later survey year of the same country with responses (searched
  over all years in gem_extract.csv) is carried back; if none exists, status is missing and
  the survey drops out of every model that uses C. N01: no carry-back at all and 2001/2002
  surveys removed from the roster. The surveys that received carried-back values are listed
  in constants.json (`status_carry_back`).

Standardization (`std_constants`): the M3-equivalent stage-1 sample of the run (steps 1-3,
complete on activity, female, age, postsecondary and all nine raw survey-level variables)
defines the set of surveys. Origin: mean and SD (`Statistics.mean`, `Statistics.std`, n - 1
divisor) over those surveys, each counted once. U15: average each variable within country
over the set's surveys, then mean and SD over the country means (n - 1 with n = number of
countries in the set, 24 when all are present). U16: mean and SD over the individual rows
of that sample. The same constants are used for every model of the run, including R2 (whose
own sample differs). For every run the constants are recomputed from that run's own
M3-equivalent sample under the run's data; for runs that do not change samples or
variables this reproduces the origin constants exactly. leave_sq = (standardized leave)^2
(not restandardized); U14: raw leave^2 is added to the set, standardized with its own
mean/SD and used as leave_sq. The female x leave_sq interaction uses whichever leave_sq is
in force. Constants are written to constants.json per run_id (means, sds, rule, size of
the basis set, carried-back surveys); the influence entry repeats the origin constants.

Centering: age_c = age - mean(age) and bage_c = bage - mean(bage) over the model's own
estimation sample; age_c2 = age_c^2. Influence refits reuse the full-sample means.

## 6. Models and estimation

Fixed terms are explicit numeric columns so that output names are exact:

- M1: female, age_c, age_c2, postsecondary, year indicators.
- M2: M1 + leave, leave_sq, childcare, parttime, gdp, unemp, epl, status, wmgr, fert.
- M3: M2 + female:leave, female:leave_sq, female:childcare, female:parttime (products of
  the female column with the standardized survey-level columns).
- M4-M8: M3 + sole + bage_c. R1: M3 terms. R2: M3 terms + not_employed, without fert (U26:
  with fert). R3: M3 terms + skill + fear + knows.

Year indicators: one 0/1 column `year<y>` for every survey year present in the estimation
sample other than the reference (2001 for M1-M6, R1-R3; 2002 for M7; 2008 for M8). If the
reference year is absent from the sample (this happens for N01, where 2001 and 2002 are
dropped), the smallest year present becomes the reference; this is recorded in the `error`
column of the affected rows (status stays `ok`). Years with no rows get no indicator.

Random effects: `zerocorr(1 + female | iso3) + zerocorr(1 + female | survey)` (independent
intercept and slope at both levels); U20: `(1 + female | iso3) + (1 + female | survey)`
(unstructured 2 x 2). survey is the string `iso3_year`, so it is nested in country by
construction.

Estimation calls:

- Logit models: `fit(GeneralizedLinearMixedModel, formula, frame, Bernoulli(), LogitLink();
  fast = false, nAGQ = 1, progress = false)` - Laplace approximation, maximum likelihood,
  MixedModels' default optimiser (NLopt LN_NEWUOA with package default tolerances and
  starting values: GLM coefficients for beta, 1 for the relative covariance parameters).
  Nothing else is substituted.
- M5: `fit(MixedModel, formula, frame; REML = false, progress = false)` (ML). U25:
  `REML = true`.

Reported per term: estimate = `coef`, se = `stderror` (model-based, from the fitted
model's information matrix), z = estimate / se, p = 2 * (1 - Phi(|z|)) with
`Distributions.Normal()`. loglik = `loglikelihood(m)`, aic = `aic(m)`. For the REML fit
(U25) MixedModels refuses `loglikelihood`; loglik is then -objective/2 (the restricted
log-likelihood) and aic = -2 loglik + 2 dof(m) with MixedModels' `dof` (fixed effects +
covariance parameters + residual SD); this is flagged in the routine column. converged =
optimiser return value in {SUCCESS, STOPVAL_REACHED, FTOL_REACHED, XTOL_REACHED} (the
return value itself is appended to the routine column). singular = `issingular(m)`.
sd_country_intercept, sd_country_female, sd_survey_intercept, sd_survey_female = |sigma|
from `VarCorr(m)` (MixedModels can report a negative sign on an independent-covariance
diagonal; the standard deviation is the absolute value).

Benchmark inference (`fit_benchmark`): the same fixed columns in a pooled
`GLM.glm(formula, frame, Binomial(), LogitLink())` (logit) or `GLM.lm` (M5). The
country-clustered sandwich is computed by hand: bread = (X' W X)^-1 with W = mu(1 - mu)
(logit) or I (OLS); meat = sum over countries of s_g s_g' with s_g = sum of x_i (y_i -
mu_i) (logit) or x_i e_i (OLS) within the country; V = G/(G-1) * bread * meat * bread, G =
number of countries in the estimation sample. No (N-1)/(N-K) factor is applied, as the
manifest specifies only G/(G-1). bench_se = sqrt(diag V); bench_p = two-sided normal p of
(pooled coefficient / bench_se). The pooled point estimates are not written (the manifest
has no column for them).

Wild cluster bootstrap (M5, the four F x X terms, `wild_cluster_bootstrap`): for each term
the OLS model without that term is fitted (null imposed), giving restricted fitted values
and residuals; for each of 999 replications a Rademacher weight (+1/-1) is drawn per
country and y* = restricted fitted + weight * restricted residual; the full model is
refitted to y* and the CR1 cluster-robust t statistic of the term computed with the same
G/(G-1) factor; wild_p = share of replications with |t*| >= |t_observed| where
t_observed uses the CR1 standard error of the unrestricted pooled OLS. Random numbers come
from `Random.Xoshiro(20261028)`, one generator seeded once per M5 fit; the G x 999 weight
matrix is drawn once and shared by the four terms (so results are reproducible and
independent of term order). The benchmark is computed for every run including influence
refits; a benchmark failure is reported in the error column while the mixed-model row
keeps status ok.

## 7. Weights

All fits are unweighted. A weighted branch is not implemented: the weights accepted by
MixedModels' `fit` are precision/frequency weights, not sampling weights, so the manifest
marks it unavailable. No run ID exists for it, so no results rows are written for it.

## 8. Runs, influence and outputs

- `ORIGIN`: M1-M8, R1-R3. Deviations: exactly the model lists of section 8 (table
  `DEVIATIONS` in run.jl); each changes a single entry of the settings dictionary.
- `influence`: for M3-M8 under origin settings, the full origin estimation sample is built
  once (origin constants, centering means from the full sample), then refitted once per
  country with that country's rows removed (deleted_country column). Year indicators that
  become all-zero after a deletion are dropped and noted in the error column. The
  benchmark and (for M5) the wild bootstrap are recomputed on the reduced sample.
- results.csv: one row per (run_id, model, term) with exactly the columns of section 8;
  failed fits produce one row with term empty, status failed and the error message; the
  sample counts and hash are still filled when the sample could be built. Missing values
  are written as empty cells. Booleans are written as true/false.
- constants.json: per run_id as described in section 5.
- session_info.txt: Julia version, OS, BLAS, package versions (`pkgversion`), the routines
  used and the work-around notice.

## 9. Defaults relied upon (not fixed by the manifest)

- MixedModels optimiser and tolerances (NLopt LN_NEWUOA, package defaults), starting
  values (GLM beta, theta = 1), `progress = false`; no `init_from_lmm`.
- GLM pooled fits use GLM's default pivoted-Cholesky handling of collinear columns
  (`dropcollinear = true`); a dropped column would show bench_se = 0 or missing.
- The sample hash sorts respondent IDs numerically (they are integers) before joining.
- Mean and SD functions use the n - 1 divisor (`Statistics.std` default).
- Surveys with missing survey-level values drop out through complete-case deletion; no
  imputation beyond the status carry-back of section 5.
- Status "has responses": at least one respondent with NBSTATUS coded 0, 1 or 100 in the
  relevant pool.
- Reference-year fallback when the reference year is absent (N01): smallest year present.
- Rademacher weights drawn with `rand(rng, (-1.0, 1.0), G, 999)`.
- U08 owner = 0 for non-missing OWNMGE that fails the rule; U23 growth needs only OMYR5JOB.

## 10. Files delivered

- run.jl: the script. IMPLEMENTATION_NOTES.md: this file. test_report.md: what was run on
  the synthetic files and what was checked.
- tests/: the check scripts referred to in test_report.md (independent sample recount,
  branch harness, optimiser cross-check, result summariser). They are not needed to run
  run.jl.
- test_output/: results.csv, constants.json and session_info.txt from the timed synthetic
  run, plus the harness and cross-check logs. They contain estimates, counts and hashes
  only, no respondent rows.

## 11. Items not implemented

- Weighted estimation (manifest section 7): unavailable by design of the specified
  software; no run rows.
- Nothing else is omitted. Every run ID, model and output column of the manifest is
  produced. The MixedModels defect of section 0 is worked around, not left as
  not_estimable, because the work-around reproduces exactly the specified estimator.
