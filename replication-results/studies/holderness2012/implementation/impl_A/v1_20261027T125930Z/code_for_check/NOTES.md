# NOTES — implementation of manifest P-R7M2 v1 (run.R)

## 1. How to run

```
Rscript run.R --grid grid.json --data data --out results --specs S000[,S001,...|all] --influence all|first20|none
```

Development-only flags (not needed for the grid run): `--families T4,T5` restricts the families of the selected
specs; `--dry` runs sample and variable construction only (row counts and missingness go to the log) and fits nothing.

Outputs under `--out`: `results.csv`, `roc.csv`, `influence.csv`, `sample_ids/<spec>__<model>.txt`, `run_log.txt`
(the log is appended to, so separate invocations into the same folder keep their history). The CSVs are rewritten
after every family (and after every T4 model in the influence loop), so a crash loses at most the current family.
A failed fit is recorded with `status = "failed"` and the error text; the run continues.

Tests: `Rscript tests/synthetic_tests.R` (estimation machinery) and `Rscript tests/synthetic_pipeline.R`
(every family end to end on synthetic data). Both write `tests/test_log.txt`; see section 4.

What was run on the real data: sample/variable construction for S000, S003, S007, S018 (`--dry`) and the
S000 T4 family (`--families T4`, `--influence none`), whose outputs are in `results/`. Nothing else was fitted on
the real data.

## 2. Implementation choices (with the manifest line they concern)

**Reading the parquet files (manifest lines 7–8, 12).** The POW string columns contain NUL bytes and nanoparquet
cannot build R strings from them (R forbids embedded NULs). run.R first tries a direct read; on the "embedded nul"
error it copies the file to a temporary file and patches the parquet footer so that the BYTE_ARRAY leaves lose
their STRING annotation (the Thrift `converted_type` field is relabelled as `scale` with value 0 and the following
`logicalType` field then has an unknown id and is skipped). nanoparquet then returns raw bytes, from which NUL bytes
are removed and strings are built; non-ASCII bytes (none expected) would become `?`. Every string field is then
cleaned exactly as the manifest says (NUL removed, leading/trailing spaces trimmed). The enlistment columns needed
(SER_NUM, CARD_NUM, HEIGHT, ERC_HEIGHT, YR_BIRTH, ERC_YR_BIRTH, EDUCATION, ERC_EDUCATION, MARITAL_STATUS,
ERC_MARITAL_STATUS, record_seq) contain no NULs and are read directly, one column at a time; the serial column is
read first and only rows whose serial occurs among the POW serials are kept (74,210 rows of 9.2 million).

**Crosswalk codes (line 57, schema).** `camp_code` is "as it appears in the raw field" and contains literal
`\x00` escape text for NUL bytes; it is cleaned with the same rule (escape text removed, trimmed) before matching
to the cleaned CAMP. Duplicate codes are ordered by `entry_id` as a string (e.g. 359a before 359b) and the first row
with confidence exact/approximate is used; confidence unknown or no such row gives a missing distance.

**nara_degree coordinates (line 57).** The text is parsed as `LAT-LON` whole degrees north and east, literally
(no sign for western longitudes, e.g. Caen "49-0" becomes 0°E). Seven crosswalk rows carry several pairs separated
by ";" (e.g. "40-116;44-26"); the first pair is used. The row selected is the same as for "crosswalk" (first
exact/approximate row), and that row's latitude/longitude are used when its text is absent or unparsable.

**Distance (line 57).** Haversine with radius 6371 km to Berlin (52.5200, 13.4050) for DET_POWER 1 and Tokyo
(35.6762, 139.6503) for DET_POWER 2; km = 1 when the selected row's `identified_place_name` is Berlin (power 1) or
Tokyo (power 2). A computed distance of exactly 0 km would give ln(0); it is treated as missing (does not occur).

**Rank (lines 36–40).** GRADE_ALPHA is matched to `grade_alpha` after trimming both; the first row per label is used
(duplicates exist for CIV, LT COL, M SG, TEC3/4/5). The GRADE_CODE fallback compares the cleaned 3-character
GRADE_CODE with `grade_code` as exact strings, so values such as "02" do not match "2" and stay missing (literal
reading). Officer columns when the first character of the cleaned SERIAL_NO is O or T; navy columns when
SERVICE_CODE = "2". "strict" uses only the strict columns, no fallback. "grade_code" = code table first, then the
origin alpha lookup.

**Samples (lines 16–21).** Blank or other SERVICE_CODE values are kept. Valid camp: cleaned CAMP has exactly three
characters and is not "000" (internal spaces count, e.g. "0 0" is a valid code under "nonblank"); "defined"
additionally requires the code in pow_CAMP_cl1277.csv (that file has unescaped quotes inside fields, so the code
column is parsed from the first quoted field of each line). With `sample_common = false` the camp-cohort models use
rows with a valid camp only; their `length` is missing when the report month is invalid (missing indicator added).

**Reference fractions (line 45).** "regression" with `sample_common = false` is not in the grid; if it occurred,
the rows of R as defined in step 6 (valid camp and valid report month) would be used.

**Group members (line 31).** "regression": members come from the base sample of the group type (R, or the
column-specific sample), i.e. before any family-specific row filter, camp drop or leave-one-camp-out deletion, so
"group variables unchanged / computed before subsetting" holds for every robustness family and for the influence
loop. "complete" restricts to members with non-missing height, age, education and dependents. "file" uses all D0
rows with a valid camp (and valid report month for cohorts) and a non-missing rank. A row whose group has no member
has missing hierarchy, n_g, men and men_sq (0.2% of R in S000).

**Hierarchy measures (lines 44–47).** Implemented as written. Ratio sameness divides by p_r; in the real data all
nine reference shares are positive (p_9 = 0.0002), so no division by zero occurs. Should a share be zero in some
spec, the resulting non-finite values are treated as missing by the design builder (missing indicator; the variable
drops out if it is missing for everyone).

**Missing-value treatment (line 52).** Missing values are set to 0 and an indicator `<var>_miss` is added when the
variable has any missing value in the estimation sample; indicators that are constant are omitted. In addition any
regressor that is constant in the estimation sample is dropped (this is how `height_rule = "none"` makes height and
its indicator drop out, and how `japan` drops in R_ger/R_jap/R_aaf). Exactly collinear columns are detected with a
pivoted Cholesky factorisation of the correlation-scaled cross-product matrix (tolerance 1e-9) and dropped; among
duplicated columns the earliest is kept. In practice this only removes duplicated missing indicators: in S000
steepness_miss, men_miss and men_sq_miss are identical (all come from n_g missing), so men_miss and men_sq_miss are
dropped and the hierarchy's indicator is kept. Dropped columns are listed in the `error` column of results.csv (with
`status = "ok"`) and in the log. A camp dummy that were collinear would be merged into the reference camp.

**Interactions (lines 71, 85, 95).** Products are formed from the zero-filled component variables (so a missing
component gives 0, which the component indicators already flag); no additional indicator is created for the product.
Products are treated as continuous for the marginal effect.

**Estimation (line 71).** Probit by Newton–Raphson with analytic gradient and the observed Hessian, step halving,
convergence when the Newton decrement is below 1e-10(1+|LL|). Camp dummies are handled in block form (the dense
part of X'WX is K×K, the dummy block is diagonal), which makes a fit with ~160 camp dummies and 100k rows take
0.3 s. The cluster-robust covariance is the sandwich with the observed-information bread and the factor G/(G−1),
G = number of clusters. Marginal effects at the means of all design columns (including camp dummies and indicators):
phi(x̄'b)·b_k for continuous regressors; Phi(x̄ with x_k=1) − Phi(x̄ with x_k=0) for japan, dependents, officer,
missing indicators and camp dummies. Delta-method SEs use the analytic Jacobian. p values are two-sided normal.
Null log likelihood is the intercept-only likelihood on the estimation sample. `converged` is TRUE/FALSE; `status`
is "ok", "not_converged" or "failed".

**Clustering (line 75).** Captured-cohort models cluster by cohort (camp + report year + month); camp-cohort models
by camp. For captured-cohort models the camp-clustered SEs and p values are in `me_se_campcluster`,
`me_p_campcluster`; for camp-cohort models these columns are NA. Note that camp-clustered SEs of the camp dummies
themselves are (correctly) near zero: a dummy's score sums to zero within its own camp at the MLE, so its sandwich
variance degenerates. The hierarchy and the other regressors are unaffected.

**Fixed effects (line 73).** Camps whose survival is constant in the estimation sample are dropped before fitting
(S000 T4 cap models: 178 camps, 1,321 rows). The omitted camp is the smallest camp code in the estimation sample.
Camp dummies appear in results.csv as terms `camp_<code>`.

**Model ids and terms.** `T4_<hier>_<cap|camp>_<simple|full>`, `T5_<g>_<s>`, `T6_<hier>_<g>_<s>`,
`Rcc_…_full`, `Rn50_…`, `Rn100_…`, `Rnoexec_…`, `Rger_…`, `Rjap_…`, `Raaf_…`, `Rnosq_…_full`,
`Ralt_ratio_<g>_<s>`, `Ralt_absdev_<g>_<s>`, `Ralt_n_distinct_ranks_<g>_full`, `Ralt_sum_ranks_<g>_full`,
`Ralt_admin_intensity_<g>_full`, `Rfriends_only_<g>_full`, `Rfriends_<hier>_<g>_full`,
`Rfriends_unit_<hier>_<g>_full`, `Rint_<hier>_<g>_full`. Term names are the variable names (steepness, sameness,
ratio_sameness, absdev_sameness, n_distinct_ranks, sum_ranks, admin_intensity, friends, steepness_unit,
sameness_unit, men, men_sq, length, japan, distance, height, age, education, dependents, officer), `<var>_miss`,
interactions `officer_x_steepness`, `steepness_x_men`, etc., and `camp_<code>`. S000 has 104 models plus 8 ROC rows.

**T5ROC (line 84).** In-sample AUCs of fitted probabilities vs survival; DeLong et al. (1988) with placement values
(ties count one half). Row "steepness" compares the T5 model with the T4 sameness model of the same column (which
omits steepness), row "sameness" with the T4 steepness model. Equality of the two estimation-row sets is verified
by record_seq (rows are aligned by record_seq if the order differs; a mismatch is a failed comparison).
roc.csv columns: spec_id, model_id, family, row, compare_model_id, auc_t5, auc_t4, diff, z, p, n, status, error.

**R_friends (line 94).** unit = TYPE_ORG|PARENT_UNIT_NUM|PARENT_UNIT_TYPE (cleaned; missing if all blank). With
"incl_self" the count is the number of group members with the same unit, plus one when the row itself is not a
member (it has a missing rank); with "others" it is the member count minus one when the row is a member, and zero
gives missing. friends is missing when unit is missing. The unit-level hierarchy is Steepness/Sameness computed over
the group members that share the row's unit (missing when there are none); `men` stays the group size.

**R_cc (line 87).** Rows with non-missing height, age, education, dependents, officer (and distance for camp
models); group variables unchanged.

**R_aaf (line 91).** SERVICE_CODE = "1" and (ARM_SVC_CODE = "20" or cleaned ARM_SVC_ALPHA = "AC") and DET_POWER = "1".

**Influence (line 96).** For each T4 model that fitted, every camp in its estimation sample (or the 20 smallest camp
codes with `first20`) is deleted and the model refitted with all group variables unchanged. For captured-cohort
models the constant-survival camp drop is the one already applied to the base estimation sample. influence.csv:
spec_id, model_id, deleted_camp, me, me_p, n, status, error (the p value uses the model's own clustering).

**Enlistment covariates (lines 59–67).** Card layout chosen per enlistment record (CARD_NUM = "3" → ERC fields).
Linkage: cleaned POW SERIAL_NO = cleaned enlistment SER_NUM ("#" replaced by a space first); blank serials are never
linked. "unmatched": serials with more than one enlistment record are unlinked; "first": smallest record_seq;
"combine": per field, the common non-blank value of the duplicates, otherwise missing. height: integer inches
(digits only), 48..84 under "range"; age: two-digit numeric year of birth, age = 1945 − (1900 + yy), 15..70 under
"range" (under "none" any two-digit numeric value is accepted); education: single digit 0..9 with 9 → parameter;
dependents as listed (code "0" and other values missing).

## 3. Sample sizes on the real data (S000)

| quantity | value |
|---|---|
| D0 rows | 143,374 |
| D (after service, power, status filters) | 124,387 |
| R (valid camp and report month) | 101,993 |
| camps in R / captured cohorts in R | 341 / 2,118 |
| rows of R with a linked enlistment record | 57,659 |
| share of R missing: height / age / education / dependents / officer | 0.596 / 0.436 / 0.435 / 0.436 / 0.008 |
| T4 cap models: camps dropped for constant survival (rows) | 178 (1,321) → n = 100,672, 1,674 clusters |
| reference shares p_1..p_9 | 0.462 0.088 0.281 0.007 0.137 0.016 0.005 0.004 0.0002 |

Height is missing for 60% of R mainly because the enlistment HEIGHT field is often "00" or blank.
The S000 T4 fits all converged (6–8 Newton iterations).

## 4. Synthetic test results (tests/test_log.txt)

tests/synthetic_tests.R (all PASS):
1. Probit with known coefficients (N = 20,000): estimates within sampling error of the truth and equal to
   glm(binomial(probit)) to 1e-6, same log likelihood; the camp-dummy version equals glm with factor dummies.
2. Marginal effects at means equal finite-difference derivatives/discrete changes (1e-11); the analytic
   delta-method Jacobian equals a numerical Jacobian (1e-11) and the SEs agree to 1e-13.
3. Cluster-robust covariance on a 60-row, 12-cluster, 4-camp example equals a direct sandwich built from numerical
   per-observation scores and a numerical Hessian (relative difference 7e-8); the analytic observed Hessian equals the
   numerical one.
4. Steepness is 0 for a one-rank group and for a single member; Sameness (and the ratio and absolute-deviation
   variants) is 1 for a group whose shares equal the reference shares; hand-computed values for ranks (1,1,9,9)
   (Steepness 0.4) and ranks 1..4 (0.25) are reproduced, as are n_g, distinct ranks, sum of ranks and administrative
   intensity.
5. DeLong: identical predictors give z = 0, p = 1; AUC equals the Mann–Whitney statistic; a constant predictor has
   AUC 0.5; the variance equals a double-loop implementation of the DeLong components.
6. Design builder: missing → 0 plus indicator, all-missing and constant columns dropped, interactions on imputed values.

tests/synthetic_pipeline.R: a synthetic POW-like data set (20,000 rows, 45 camps, duplicated serials, invalid
codes, unknown-confidence camps, a Berlin camp) is pushed through run_spec() with all S000 families and
`--influence first20`: all 104 models are produced, the family counts match the manifest, every fit is "ok"
except the four R_n100 captured-cohort fits whose synthetic sample is empty (they are recorded as "failed" with an
error and the run continues, which exercises that path), the ROC and influence files have the expected rows, and the
T4 camp-full and cap-full coefficients equal glm on the same design.

## 5. Runtime (Apple Silicon, R 4.6.1, single thread)

| step | time |
|---|---|
| read POW parquet (NUL-safe path) | 1.5 s |
| read and link enlistment file | 15–17 s (once per run) |
| variable construction per spec | 0.6–1.3 s |
| captured-cohort fit (100k rows, ~160 camp dummies) | 0.25–0.4 s |
| camp-cohort fit | 0.1–0.25 s |
| S000, all families except INFLUENCE (~96 fits + 8 ROC) | ≈ 30 s |
| INFLUENCE all: ~341 camps × 8 T4 models | ≈ 12 min (first20: ≈ 40 s) |
| S001–S020 (T4 or R_friends only) | ≈ 5 s each |

The whole grid with `--influence all` should take about 15 minutes; peak memory is about 2 GB during the
enlistment read.

## 6. Files

Deliverables: `run.R`, `NOTES.md`, `tests/synthetic_tests.R`, `tests/synthetic_pipeline.R`,
`tests/synthetic_data.R`, `tests/test_log.txt`, and `results/` (S000 T4 family on the real data; `run_log.txt`
there contains the successive development runs, the last one being final). `tests/_synthetic_out/` is the output
of the last synthetic pipeline run and is regenerated by that test. The files `_explore*.R`, `_patchlib.R`,
`_inspect.R`, `_debug*.R` and the folder `_dryrun/` are exploration scratch work kept only because deleting them
was not permitted in this session; they are not part of the implementation.

## 7. Manifest items not implemented or deviating

None of the listed analyses were dropped. Points where the manifest left room for interpretation are documented in
section 2 (nara_degree multi-pair text, friends for non-member rows, interaction indicators, duplicate missing
indicators, pop_fractions "regression" with sample_common false, GRADE_CODE exact-string matching). Only the S000
T4 family was fitted on the real data, as instructed.
