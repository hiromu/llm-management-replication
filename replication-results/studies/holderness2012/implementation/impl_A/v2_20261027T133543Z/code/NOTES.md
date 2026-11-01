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

What was run on the real data: sample/variable construction for S000, S003, S007, S018 (`--dry`) in the first
round, and after check round 1 again for S000, S018, S019, S020 (`--dry`), plus the S000 T4 family
(`--families T4`, `--influence none`), whose outputs are in `results/`. Nothing else was fitted on the real data.

## 2. Implementation choices (with the manifest line they concern)

**Reading the parquet files (manifest lines 7–8, 12).** The POW string columns contain NUL bytes and nanoparquet
cannot build R strings from them (R forbids embedded NULs). run.R first tries a direct read; on the "embedded nul"
error it copies the file to a temporary file and patches the parquet footer so that the BYTE_ARRAY leaves lose
their STRING annotation (the Thrift `converted_type` field is relabelled as `scale` with value 0 and the following
`logicalType` field then has an unknown id and is skipped). nanoparquet then returns raw bytes, from which only the
NUL bytes are removed before strings are built; every other byte is kept (a byte above 0x7f would be kept as a
latin1 character; none occurs in the fifteen POW columns read). Every string field is then cleaned exactly as the
manifest says (NUL removed, leading/trailing spaces trimmed). The enlistment columns needed
(SER_NUM, CARD_NUM, HEIGHT, ERC_HEIGHT, YR_BIRTH, ERC_YR_BIRTH, EDUCATION, ERC_EDUCATION, MARITAL_STATUS,
ERC_MARITAL_STATUS, record_seq) contain no NULs and are read directly, one column at a time; the serial column is
read first and only rows whose serial occurs among the POW serials are kept (74,210 rows of 9.2 million).

**Crosswalk codes (line 57, schema).** `camp_code` is "as it appears in the raw field" and contains literal
`\x00` escape text for NUL bytes; it is cleaned with the same rule (escape text removed, trimmed) before matching
to the cleaned CAMP; `confidence`, `identified_place_name` and `nara_degree_coords_text` are cleaned the same way
before they are compared or parsed. Duplicate codes are ordered by `entry_id` as a string (e.g. 359a before 359b)
and the first row with confidence exact/approximate is used; confidence unknown or no such row gives a missing
distance.

**nara_degree coordinates (line 57).** The text is parsed as `LAT-LON` whole degrees north and east, literally
(no sign for western longitudes, e.g. Caen "49-0" becomes 0°E). Seven crosswalk rows carry several pairs separated
by ";" (e.g. "40-116;44-26"); the first pair is used. The row selected is the same as for "crosswalk" (first
exact/approximate row). That row's latitude/longitude are used only when its text is absent (blank after
cleaning); text that is present but cannot be parsed as LAT-LON gives missing coordinates (no such text exists in
the supplied crosswalk).

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
column is parsed from the first quoted field of each line and cleaned). With `sample_common = false` the camp-cohort models use
rows with a valid camp only; their `length` is missing when the report month is invalid (missing indicator added).

**Reference fractions (line 45).** "regression" with `sample_common = false` is not in the grid; if it occurred,
the rows of R as defined in step 6 (valid camp and valid report month) would be used.

**Group members (line 31).** "regression": members come from the base sample of the group type (R, or the
column-specific sample), i.e. before any family-specific row filter, camp drop or leave-one-camp-out deletion, so
"group variables unchanged / computed before subsetting" holds for the robustness families that state it and for
the influence loop. The one exception is R_aaf (line 91 gives no such statement): its group members are the AAF
rows of R with a non-missing rank, and hierarchy and n_g are computed over them (see section 8, item 9).
"complete" restricts to members with non-missing height, age, education and dependents. "file" uses all D0
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
pivoted Cholesky factorisation of the correlation-scaled cross-product matrix (tolerance 1e-9, i.e. numerically
exact linear dependence) and omitted from the design; among duplicated columns the earliest is kept. In practice
this only removes duplicated missing indicators: in S000 steepness_miss, men_miss and men_sq_miss are identical (all
come from n_g missing), so men_miss and men_sq_miss are omitted and the hierarchy's indicator is kept. Every omitted
column is still reported in results.csv as a term row with NA estimates, and is named in the `error` column of the
model's rows (with `status = "ok"`) and in the log. A camp dummy that were exactly collinear with the dense columns
would be merged into the reference camp and likewise reported as `camp_<code>` with NA estimates (does not occur in
S000 T4). See section 8, item 6, for why this omission is unavoidable.

**Interactions (lines 71, 85, 95).** Products are formed from the zero-filled component variables (a missing
component gives 0). A product is missing where either component is missing, so it gets its own indicator
(`officer_x_steepness_miss`, `steepness_x_men_miss`, ...) when that indicator is not constant in the estimation
sample. Products are treated as continuous for the marginal effect.

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
"incl_self" the count is the number of group members with the same unit (the row itself is one of them when it is a
member; a non-member row, i.e. one with a missing rank, is not counted, and a count of zero gives missing); with
"others" it is the member count minus one when the row is a member, and zero gives missing. friends is missing when
unit is missing. In S000 friends is missing for 33.6% of R, in S020 ("others") for 42.9% (cohorts) / 39.8% (camps).
The unit-level hierarchy is Steepness/Sameness computed over
the group members that share the row's unit (missing when there are none); `men` stays the group size.

**R_cc (line 87).** Rows with non-missing height, age, education, dependents, officer (and distance for camp
models); group variables unchanged.

**R_aaf (line 91).** SERVICE_CODE = "1" and (ARM_SVC_CODE = "20" or cleaned ARM_SVC_ALPHA = "AC") and DET_POWER = "1".
Group members, hierarchy and n_g are computed over these rows (the family's estimation sample) under the
"regression" and "complete" membership rules; under "file" the members do not depend on the estimation sample.

**Influence (line 96).** For each T4 model, every camp in its estimation sample (or the 20 smallest camp codes
with `first20`) is deleted and the model refitted with all group variables unchanged; this is done whether or not
the base fit succeeded (the estimation rows are determined before fitting). An estimation sample without any camp
gives one row with status "failed". For captured-cohort models the constant-survival camp drop is the one already
applied to the base estimation sample. influence.csv: spec_id, model_id, deleted_camp, me, me_p, n, status, error
(the p value uses the model's own clustering).

**Sample id files and family order (line 100; grid lines 3 and 29-45).** `sample_ids/<spec>__<model>.txt` is written
for every model before it is fitted, so failed fits also have their estimation rows on file. Families run in the
order listed in grid.json for the spec, T5ROC in its place right after T5 and before T6, INFLUENCE last.

**Enlistment covariates (lines 59–67).** Linkage: cleaned POW SERIAL_NO = cleaned enlistment SER_NUM ("#" replaced
by a space first); blank serials are never linked. The dup_serial rule is applied to the enlistment records first
and the card layout (CARD_NUM = "3" → ERC fields) to the resulting single record per serial. "unmatched": serials
with more than one enlistment record are unlinked; "first": the record with the smallest record_seq; "combine":
field by field over the nine record fields (CARD_NUM, HEIGHT, ERC_HEIGHT, YR_BIRTH, ERC_YR_BIRTH, EDUCATION,
ERC_EDUCATION, MARITAL_STATUS, ERC_MARITAL_STATUS), the common value when all non-blank duplicates agree, blank
(missing) otherwise; a combined CARD_NUM that is blank is not "3", so the standard fields are used. height: integer inches
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
6. Design builder: missing → 0 plus indicator, all-missing and constant columns dropped, interactions on imputed
   values, a product with a missing component gets its own indicator (none when no component is missing).
8. Raw-to-string conversion: NUL bytes removed, lengths preserved, a byte above 0x7f kept unchanged, cleaning works.
9. Code-list codes and crosswalk fields are cleaned before comparison (padded confidence accepted); nara_degree:
   absent text → crosswalk coordinates, "40-116; 44-26" → (40, 116), "49- 0" → (49, 0), unparsable text → missing.
10. dup_serial "combine" on hand-made duplicates: CARD_NUM disagreement → standard layout, agreeing/disagreeing
    fields, blank-versus-value, single records, and the "first"/"unmatched" rules.
11. The R_cc filter of a captured-cohort model does not require distance; the camp-model filter does.
12. Camp dummies are in the binary set and their marginal effect equals the discrete change.

tests/synthetic_pipeline.R: a synthetic POW-like data set (20,000 rows, 45 camps, duplicated serials with
different card layouts, invalid codes, unknown-confidence camps, a Berlin camp) is pushed through run_spec() with
all S000 families and `--influence first20`: all 104 models are produced, the family counts match the manifest,
every fit is "ok" except the four R_n100 captured-cohort fits whose synthetic sample is empty (they are recorded as
"failed" with an error and the run continues, which exercises that path), the ROC and influence files have the
expected rows, the T4 camp-full and cap-full coefficients equal glm on the same design, omitted collinear columns
appear as NA term rows, T5ROC runs between T5 and T6, the R_cc cap sample keeps rows with missing distance, R_aaf
n_g equals the number of AAF members per camp, friends equals ln(members with the same unit), and a deliberately
failed T4 base fit (fit_model patched to error once) still writes its sample-id file and gets its 20
leave-one-camp-out rows.

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
`tests/synthetic_data.R`, `tests/test_log.txt`, and `results/` (after check round 1: the `--dry` run for S000,
S018, S019, S020 followed by the S000 T4 family on the real data; `run_log.txt` there holds both runs).
`tests/_synthetic_out/` is the output of the last synthetic pipeline run and is regenerated by that test.

## 7. Manifest items not implemented or deviating

None of the listed analyses were dropped. Points where the manifest left room for interpretation are documented in
section 2 (nara_degree multi-pair text, exactly collinear required columns, pop_fractions "regression" with
sample_common false, GRADE_CODE exact-string matching) and in section 8. Only the S000 T4 family was fitted on the
real data, as instructed.

## 8. Check round 1 responses

Each item of CHECK.md, what was changed in run.R (or why not), and the effect on the real data where it was
observable within the permitted runs (variable construction; S000 T4).

1. **Non-ASCII bytes (manifest lines 7-8, 12).** Fixed. `raw_to_chr()` no longer replaces bytes above 0x7f by `?`;
   only NUL bytes are removed and the string is declared latin1 if such a byte occurs, so every distinct byte value
   stays a distinct character. The fifteen POW columns read contain no byte above 0x7f (checked: 0 of 5.7 million
   bytes) and the enlistment SER_NUM column contains none either, so results are unchanged on these data.
   Test 8.

2. **Cleaning before code comparisons (lines 12, 20, 57).** Fixed. Codes from pow_CAMP_cl1277.csv are cleaned in
   `read_code_list_codes()`; the crosswalk fields `confidence`, `identified_place_name` and
   `nara_degree_coords_text` are cleaned in `load_inputs()` before `camp_coordinates()` compares or parses them. In
   the supplied files no code-list code and no confidence value carries padding or NUL text, so the S000 and S004
   samples and S000 distances are unchanged. Test 9a-9c.

3. **nara_degree fallback (line 57; S019).** Fixed. The crosswalk latitude/longitude are used only when the cleaned
   text is blank; text that is present but not of the form LAT-LON gives missing coordinates. The first pair of a
   multi-pair text is still parsed (documented interpretation; the checker did not object to it). In the supplied
   crosswalk every present text parses (six multi-pair texts, one "49- 0" with an internal space), so S019's
   distance missingness is unchanged at 0.6% of R. Test 9d-9f.

4. **dup_serial "combine" (lines 59-63, 67; S018).** Fixed. `enl_covariates()` now applies the dup_serial rule to
   the nine original record fields, CARD_NUM included, taking per field the common value of the non-blank
   duplicates (blank otherwise), and applies the card layout to the combined record. A combined CARD_NUM that is
   blank because the duplicates disagree is not "3", so the standard fields are used (literal reading of line 60).
   The per-record derivation was removed from `load_inputs()`. 590 serials have more than one record; S018 links
   58,151 rows of R (57,659 under "unmatched"). Test 10; the synthetic duplicates now have the other card layout.

5. **Missing indicators for interaction products (lines 52, 85, 95).** Fixed. `build_design()` marks a product as
   missing where either component is missing and adds `<product>_miss` when that indicator varies in the estimation
   sample (the product itself is 0 there, as before). Note that under the "regression" membership rule a missing
   hierarchy implies a missing rank (a ranked row would be a member of its own group), so in S000 the indicator of
   officer x hierarchy duplicates `officer_miss` and that of hierarchy x men duplicates the hierarchy's own
   indicator; both are then exactly collinear and are reported with NA (item 6). The fix therefore changes numbers
   only under other membership rules, which the grid does not combine with T6 or R_int. Tests 6a, 6b, 6d, 6e.

6. **Omission of exactly collinear required columns (lines 52, 71, 73, 100).** Not changed in substance, output
   extended. Line 52 requires one indicator per variable with missing values; in S000 `steepness_miss`, `men_miss`
   and `men_sq_miss` are identical columns (all three variables are missing exactly when n_g is missing). A probit
   "by maximum likelihood" (line 71) with exactly collinear columns has no unique maximiser and a singular Hessian,
   so the design cannot contain all of them and at least one must be omitted; the manifest gives no rule for this
   case. The implementation omits only numerically exact dependence (pivoted Cholesky of the correlation-scaled
   cross-product matrix, tolerance 1e-9), keeps the earliest column (the hierarchy's indicator), and does not
   remove anything else: in S000 T4 the only omitted columns are `men_miss` and `men_sq_miss` in the four full
   models, and no camp dummy is merged. What changed: every omitted column is now reported in results.csv as a
   term row with NA coef/me/SE/p (so the output has a row for each required term), and the `error` column of the
   model names them ("omitted exactly collinear (reported with NA): ..."). Pipeline check 7s.

7. **Marginal effects of camp dummies (line 71).** Fixed. The camp dummies are added to the binary set in
   `fit_model()`, so their marginal effect is the discrete change Phi(xbar with the dummy = 1) - Phi(xbar with the
   dummy = 0) and the delta-method gradient is the corresponding one; the code now matches what section 2 already
   stated. Only the `camp_<code>` rows of the captured-cohort models change. Test 12.

8. **Complete-case filter (line 87).** Fixed. `cc_filter()` forces its `gtype` argument, so the captured-cohort
   R_cc models no longer require a non-missing distance (0.6% of R has missing distance). Test 11; pipeline check 7u.

9. **R_aaf group membership (lines 31-32, 91).** Fixed. Line 31 defines "regression" members as rows of the
   model's estimation sample; lines 87, 89, 90 and 96 state explicitly when group variables are to be kept from
   the unrestricted sample, and line 91 does not. `build_spec_data()` therefore also builds an "aaf" member set
   (members restricted to AAF rows under "regression" and "complete"; identical under "file", whose members do not
   depend on the estimation sample), and the R_aaf models use model frames with hierarchy and n_g from that set.
   Pipeline check 7v.

10. **friends with "incl_self" (lines 31, 94).** Fixed. The count is the number of group members with the row's
    unit; a row that is not a member (missing rank) is not added, and a count of zero gives missing (ln 0). In
    S000 friends is missing for 33.6% of R (missing unit, or no ranked member with the same unit). Pipeline check 7w.

11. **Influence after a failed base fit (lines 96, 100).** Fixed. The estimation frame of each T4 model is kept
    before the fit is attempted, so the leave-one-camp-out loop runs and records every camp's refit even when the
    base fit failed; only an estimation sample with no camp at all gives a single "failed" row. Pipeline check 7y.

12. **Sample-id files for failed fits (line 100).** Fixed. The file is written from the estimation frame before
    the fit, for every model. Pipeline check 7x.

13. **Family order (line 84; grid lines 3, 29-45).** Fixed. `run_spec()` iterates over the families in the order
    listed for the spec, running T5ROC when it is reached (right after T5, before T6) and INFLUENCE last. Pipeline
    check 7t.

Synthetic tests after the changes: `tests/synthetic_tests.R` 50 checks and `tests/synthetic_pipeline.R` 25 checks,
all PASS (tests/test_log.txt). Real data: the S000 T4 fits all converge (6-8 iterations) with the same N, clusters
and dropped camps as before (section 3); the hierarchy, men and covariate estimates are unaffected by items 1-13
in these eight models, whose only changes are the camp-dummy marginal effects (item 7) and the two NA rows per full
model (item 6).
