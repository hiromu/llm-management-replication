# PAPER_K7 v1.1 — R implementation

Implements `implementation_spec.md` as amended by `spec_amendment_v1_1.md`, using the supplied frozen grid and installed R packages. All work uses this directory; no network access or package installation was used. The grid, specifications, crosswalk, metadata and survey inputs are unchanged (verified with `input_checksums.txt`). No synthetic results are interpreted.

## Run

Run from the task directory:

```sh
mkdir -p code/dev_out/v1_1
/opt/homebrew/bin/Rscript code/tests/run_tests.R > code/dev_out/v1_1/tests.log 2>&1
/opt/homebrew/bin/Rscript code/run_grid.R \
  --data data/survey.csv \
  --metadata data/survey_metadata.json \
  --crosswalk data/industry_crosswalk.csv \
  --grid grid_v1.json \
  --out code/dev_out/v1_1 > code/dev_out/v1_1/full_grid.log 2>&1
/opt/homebrew/bin/Rscript code/tests/validate_outputs.R > code/dev_out/v1_1/output_validation.log 2>&1
```

The runner accepts compatible input paths and an output directory, creates that directory, and replaces its six named output files. It does not assume a row count. Specifications run in `compute_order`. Model/test failures are recorded while execution continues. Invalid input files produce a nonzero exit and an input failure in `run_info.json`.

Production dependencies: base R and `jsonlite`. Tests also use the installed `sandwich` package as an independent HC3 reference on designs without leverage-one observations. Leverage-one tests use an independent normal-equation calculation with the amended zero-contribution rule. The run used R 4.6.1 and jsonlite 2.0.0. `run_grid.R` is sourceable without starting a run.

## v1.1 changes

Every amendment item and the sole checker item are covered below. Requirements already satisfied are explicitly identified and retained.

| Item | Implementation and verification |
| --- | --- |
| A1 — leverage-one HC3 | Replaced the NA-for-all-HC3 behavior. Rows with weighted-design leverage `h >= 1 - 1e-8` now contribute exactly zero to HC3 meat; bread, residual df and conventional statistics are unchanged. Added `n_leverage_one` to `model_stats.csv`. The shared fitter applies this to ordinary fits and every deletion refit. Tests compare OLS/WLS HC3 to independent calculations with singleton industry rows, after deletions, and on either side of the threshold. |
| A2 — top codes versus declared missing | `clean_data` now protects V157=99996, V261=96 under hierarchy L0/L2, and STAFF=995 under staff L2 from both discrete and range missing declarations. Subsequent transformations assign 100000, 100 and 995 respectively. Tests cover each protected code and declaration type, plus adjacent excluded codes. |
| A3 — hierarchy log10 | Already correct; retained `ln(recoded count)/ln(10)`, including 96→100. Existing direct recoding and full-grid algebraic invariance tests verify it. |
| A4 — system-missing routing | SUBSID now remains missing for missing V17 at all levels; DECENT already preserved missing V17. Missing V43 now remains missing at both industry levels. UNCL applies only to nonmissing codes with empty/unmatched crosswalk entries. Updated routing/industry expectations and added declaration tests. |
| A5 — column drops and nested df | Existing substantive-term protection and nominal nested df (6 HRM, 3 interaction) were retained. Industry rank resolution still precedes residual-df checking; its bookkeeping now also runs before reporting non-industry rank failure. Tests cover permitted drops that restore positive df, prohibited substantive aliasing, rank-increment mismatch, and nominal df in emitted failed-test records. |
| A6 — failure records | Dropped industry columns survive subsequent df or substantive-rank failure. Failed original influence models now explicitly emit failed rows for every sample record and requested term, with the original reason. Restricted nested-model failures receive separate `restricted` entries with reasons in `run_info.json`, in addition to the failed nested-test entry. Existing CSV `NA` and JSON null serialization are retained. Unit tests and an isolated injected-failure runner fixture verify these branches and their written artifacts. |
| A7 — copy validity | Already correct; retained metadata and item-domain/STAFF-level exclusions before copying. Added tests for CORE=0, every STAFF code 995–999, declared missing values, missing CORE, manager GSS fallback, explicit same-occupation routing, and all staff levels. A2's specified top-code overrides apply before validity is evaluated. |
| A8 — fixed reference sample | Reference rows were already selected before z scoring. Added retained pre-standardization validity data so later estimation-sample selection cannot remove rows merely because standardization yields an undefined score. Reference and family membership are fixed by validity; if a required standardized index remains undefined, fitting fails explicitly on the retained rows. Added zero-SD tests for both families under L1/L2, supplementing existing reference-moment and outside-reference-value tests. |
| A9 — coding precedence | Retained V17=2 overriding V21 under SUBSID L1/L2, exclusion of STAFF 996–999 and of 995 outside L2, and metadata handling of V8/V17/V43/WEIGHT. Added explicit tests for these input declarations, WEIGHT=0 exclusion, and routing precedence; A4 corrects the handling of cleaned missing identifiers. |
| A10 — influence refits | Retained shared fitter rank resolution before df checking and JSON logging for failed deletions. Added small deletion fixtures with more original columns than rows but permitted dummy drops, and injected-failure integration checks verifying each failed deletion appears in both `influence.csv` and `run_info.json`. |
| Checker item 1 — top-code precedence | Confirmed and fixed through A2. Previously metadata removed V157=99996 and V261=96 before replacement, and STAFF=995 was protected only from discrete declarations. The revised protected-row mask covers both declaration forms. No checker item was rejected as mistaken. |

## Outputs and failure handling

All six outputs are in `code/dev_out/v1_1/`: `coefficients.csv`, `model_stats.csv`, `nested_tests.csv`, `samples.csv`, `influence.csv`, and `run_info.json`. CSV schemas follow section 8 with the A1 addition `n_leverage_one` appended to model statistics. JSON also records interpretations, warnings, industry references and output row counts. Nested-test IDs are `HRM_<full_model>` or `interaction_<full_model>`.

For case_scope L0, samples appear once per family with `model_id=ALL`; for L1, each model has its own sample. Empty families have no sample rows, but explicit N=0 failed model records. Failed models retain NA coefficient rows and reasons. Failed nested tests retain nominal numerator df and NA statistics, with reasons in JSON. Failed deletions retain one row per HRM/interaction term and one JSON failure entry per deletion.

Only industry columns may be dropped. The fitter checks substantive rank and considers industry columns in their existing order using QR tolerance 1e-9. Drops are retained when subsequent rank or df checks fail. Conventional covariance uses the pivot-corrected QR inverse; WLS HC3 uses the weighted design and residuals. All coefficient p-values, including HC3, use residual t degrees of freedom. Constant outcomes have undefined R2/F. Missing statistics are CSV `NA`; JSON uses null. Leverage count is NA when no valid full-rank design can be formed.

Nested restricted models use exactly the full model's rows and original family industry coding. Influence refits keep the original variable values, standard scores, industry coding and interaction construction fixed.

## Retained implementation details

- Copy validity is evaluated per source item before transformation. Declared-missing routing codes are distinct from system-missing routing codes.
- Training routing overrides stored V157/V172 when V145=2 according to `no_training`. Zero training counts remain numeric under `train_log=L2`; raw age is used under `age=L2`.
- Standardization uses item-specific valid values and unweighted moments. Under z_reference L1/L2, outside-reference rows retain L0 scores. Undefined SD makes the item score missing; partial indices may still use other valid items, without recomputing sample membership.
- Crosswalk parsing accepts commas and semicolons, preserves printed order and zero-pads groups. UNCL sorts after numeric groups. Ordinary reference uses the largest group and lowest-code tie break; the alternative uses the smallest group and highest-code tie break.
- With model-specific cases, the family industry schema/reference is selected on base-model complete cases and reused across models and nested fits.
- Centering uses arithmetic means of the model's sample; main effects remain uncentered. Record filtering drops raw V3=0 and retains missing V3. No additional reconciliation of independently permuted columns is performed.

## Validation completed

- **339 unit/numerical/integration checks passed**, including all original tests with amended expectations and the additional tests in `tests/amendment_tests.R`.
- **8,306 full-grid output checks passed**, covering schemas, compute order, model/test coverage, samples, failures, finite HC3 SEs and tail identities, influence coverage, centering invariance, and all three algebraic checks.
- The full frozen grid completed: **38 specifications, 912 model rows, 63,573 coefficient rows, 304 nested-test rows, 29,499 sample rows, and 18,030 influence rows**.
- **888 models succeeded; 24 D05 models failed because both common complete-case family samples are empty.** Together with eight failed nested tests, these produce 32 failure entries. No deletion failed in the supplied synthetic-data run. No HC3 warnings remain.

Logs and result summaries are in `code/dev_out/v1_1/`. The `failure_fixture/` subdirectory contains separate test artifacts generated with injected fit failures to exercise otherwise unvisited logging branches; these are not the supplied-data grid results. It uses the same unchanged grid and adds no specifications.

These counts describe execution and validation only. No substantive interpretation of synthetic results is made.
