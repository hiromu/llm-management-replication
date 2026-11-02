# PAPER_K7 v1 — R implementation

Implements the frozen grid using only the supplied files and installed R packages. No network access or package installation was used. The input grid and data were not modified.

## Run

Run from the task directory:

```sh
/opt/homebrew/bin/Rscript code/run_grid.R \
  --data data/survey.csv \
  --metadata data/survey_metadata.json \
  --crosswalk data/industry_crosswalk.csv \
  --grid grid_v1.json \
  --out code/dev_out/full_grid
```

The script accepts paths to other compatible input files and an arbitrary output directory; it never assumes the development row count. The output directory is created if needed. Running again replaces the six named output files. Specifications run sequentially in `compute_order`. Statistical/model failures are recorded while execution continues; invalid input files produce a nonzero exit and an input failure in `run_info.json`.

Production dependencies: R base/stats/utils/tools and `jsonlite`. Tests additionally use the already installed `sandwich` package as an independent HC3 reference. The development run used R 4.6.1 and jsonlite 2.0.0. `run_grid.R` can also be sourced without starting a run.

## Outputs

All six required outputs are in `code/dev_out/full_grid/`: `coefficients.csv`, `model_stats.csv`, `nested_tests.csv`, `samples.csv`, `influence.csv`, and `run_info.json`. The CSV column names and ordering match section 8. The JSON additionally records interpretations, warnings, industry references and output row counts. Nested test IDs are `HRM_<full_model>` or `interaction_<full_model>`.

For `case_scope=L0`, samples are stored once per family with `model_id=ALL`; for L1, every model has its own rows. A zero-row family has no rows to emit in `samples.csv`; its model statistics explicitly record N=0 and the failure reason. Conventional nested tests always refit the restricted specification on the full specification’s exact rows. No influence values are recomputed upstream: deletion refits use the original design matrix.

## Interpretations and edge cases

The following resolves every identified ambiguity or unspecified computational edge case. The same list is embedded in `run_info.json`:

1. Crosswalk accepts comma and semicolon delimiters, preserving printed order and zero-padding SIC to two digits.
2. System-missing or declared-missing V43 maps to UNCL under industry L0 and missing under L1.
3. SUBSID L0 preserves missing V17; L1/L2 independent establishments (V17=2) override missing V21 to zero. Otherwise missing V21 remains missing.
4. Training routing overrides inconsistent stored V157/V172 whenever V145=2; no other unstated routing is imposed.
5. Copy validity is evaluated per source item after metadata and domain/STAFF-level exclusions, before transformation; declared-missing routing codes are not system-missing.
6. CHK_hierarchy_log10 uses log10 of the top-code-adjusted hierarchy count (ln(count)/ln(10)), consistent with the stipulated algebraic invariance.
7. CHK_industry_ref_alt omits the least frequent group (highest code breaks ties); ordinary reference omits the most frequent (lowest code breaks ties). UNCL sorts after numeric codes.
8. With case_scope L1, family industry schema/reference is selected on base-model complete cases and reused for every model and nested refit.
9. Z reference membership uses pre-standardization item validity and all seven HRM indices, outcome, controls, industry, family restrictions and positive weights. L1/L2 retain L0 scores outside reference rows exactly as specified.
10. If combining case_scope L1 and z_reference L1/L2 (not present in the frozen grid), the reference is the family common complete-case sample.
11. Zero/undefined reference SD makes that standardized item missing; reference membership is not iteratively recomputed. Partial indices may use the remaining items.
12. Centering uses unweighted arithmetic means in each model sample, including WLS; standard-score moments are also unweighted.
13. Categorical items outside specified valid domains are missing; numeric raw counts/age follow the stated restrictions only. Record filtering drops raw V3=0 and retains missing V3.
14. Only industry columns may be dropped for collinearity; non-industry rank deficiency fails the model. Industry columns are considered in increasing code order after all substantive terms; QR tolerance is 1e-9.
15. Parameter count is estimable columns including intercept; adjusted R2 uses 1-(1-R2)*(n-1)/(n-k). WLS HC3 uses sqrt(weight) times design and residuals.
16. HC3 is NA when leverage reaches one (within 1e-12); this is recorded as a diagnostic warning without invalidating conventional statistics.
17. Nested tests use nominal added-term df (6 or 3); if effective rank increment differs they fail explicitly in run_info, with NA statistics in nested_tests.
18. Failed models have explicit model_stats entries and NA coefficient rows for intended columns. Failed nested tests have NA rows and run_info reasons. Samples include complete-case rows even if the fit fails.
19. Influence uses explicit refits and fixed original design columns (including original industry reference); newly empty/aliased industry columns are dropped. Every deletion/HRM term is retained, even on failure. An empty sample has no possible deletions.
20. Missing numeric CSV values are NA; empty strings mean no error/drop/note. JSON missing values are null. No scientific interpretation of development results is made.

Counts with top codes explicitly specified in the task use the required replacements. Metadata missing declarations are applied first, with the stated STAFF 995 exception. Zero training counts are retained under `train_log=L2`; negative age remains numeric under `age=L2`, following the raw-value levels literally. Product/service, grievance, union, decision and index item domains are validated before averaging. Missing V17 still permits a V21-based subsidiary value at L1/L2 unless V21 is itself missing. No additional reconciliation of independently permuted synthetic columns is performed.

Numerical fitting uses pivoted QR through `lm.wfit`; the QR covariance is restored to coefficient order. HC3 uses transformed weighted residuals and design, and all robust p-values use the model residual t degrees of freedom. F statistics with a negative numerator only from floating-point error are clamped to zero. A constant outcome has undefined R2 and overall F, reported as NA. Insufficient residual degrees of freedom and non-industry aliasing are model failures, not successful fits with silently removed substantive terms. Rank-deficient nested additions are explicitly recorded as failed tests.

If a specification cannot be coded, its failure propagates to explicit model and nested-test records instead of silently disappearing. All specified features are implemented; the run’s `unimplemented` list is empty. Undefined statistics caused by the data remain NA and are explained in model errors or diagnostic warnings.

## Tests run

```sh
/opt/homebrew/bin/Rscript code/tests/run_tests.R > code/dev_out/tests.log 2>&1
/opt/homebrew/bin/Rscript code/tests/validate_outputs.R > code/dev_out/output_validation.log 2>&1
```

The output validator requires the full-grid run shown above. Both test scripts use deterministic fixtures/seeds and stop with a nonzero exit at the first failed assertion.

- **239 unit/numerical checks passed.** OLS/WLS coefficients, conventional SEs, t statistics, all p-value tails, R2/adjusted R2, overall F and nested F match base R; HC3 matches both a hand calculation and `sandwich::vcovHC`. The OLS fixture has deliberately orthogonal residuals and known exact coefficients.
- Hand-built rows cover every axis level, metadata values/ranges and system missingness, all index reversals, log and top-code rules, training routing, every copy pair and fallback, both decision maps/routing branches, union variants, control recodes, ambiguous/empty/unknown industries and UNCL, reference ties, sample rules, and STAFF/TRAIN standardization reference sets.
- Explicit small-case weighted deletion refits match base R for every deletion’s coefficients, conventional SEs and p-values. Tests also retain failed deletions and verify zero/collinear dummy drops and undefined HC3 flags.
- **5,642 output checks passed.** These verify exact schemas, compute order, every model and nested-test record, sample counts/IDs, coefficient counts/df, recorded failures, all influence deletion/term combinations, centering invariance, and all three algebraic checks.

Logs and concise test result files are in `code/dev_out/`.

## Full synthetic development run

The full frozen grid ran once on the supplied synthetic CSV: 38 specifications, 912 model records, 63,573 coefficient rows, 304 nested-test records, 29,499 sample rows and 18,030 influence rows.

888 models completed. D05 (`item_rule=L1`) has no common complete cases in either family, so all 24 D05 models and its eight nested tests are explicitly recorded as failures (32 failure entries total). No influence deletion failed. Every successful model has at least one leverage-one observation under the stated numerical threshold; HC3 is consequently undefined and recorded as NA with 888 diagnostic warnings in `run_info.json`. The standalone numerical tests verify HC3 on nonsingular designs without leverage-one observations.

These are execution and validation results only. The independently permuted synthetic data are meaningless for substantive inference; no study results are interpreted.

