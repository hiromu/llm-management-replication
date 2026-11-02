# PAPER_K7 grid implementation (specification v1, frozen, with amendment v1.1)

Python implementation of `implementation_spec.md` as amended by `spec_amendment_v1_1.md`, for every
specification in `grid_v1.json`. Pure numpy/pandas/scipy; statsmodels is used only in the tests as
a reference. Where the amendment and the frozen spec differ, the amendment is followed.

## How to run

```
~/.venv/bin/python code/run_grid.py \
    --data data/survey.csv \
    --metadata data/survey_metadata.json \
    --crosswalk data/industry_crosswalk.csv \
    --grid grid_v1.json \
    --out <output_dir>
```

The script runs every spec in `compute_order`, then the influence diagnostic on the origin spec,
and writes `coefficients.csv`, `model_stats.csv`, `nested_tests.csv`, `samples.csv`,
`influence.csv` and `run_info.json` into `<output_dir>`. Failures of a spec, a model, a nested
test or a leave-one-out refit are recorded (status `failed` with the reason), never skipped.
Progress is printed to stdout. The full grid on the 727-row development file takes about 60 s.

Layout:

- `code/run_grid.py`: command line entry point and output writing.
- `code/paperk7/coding.py`: missing codes, items, indices, copy rule, standard scores, controls, industry.
- `code/paperk7/pipeline.py`: samples, designs, models, nested tests, influence diagnostic.
- `code/paperk7/regression.py`: OLS/WLS, conventional and HC3 SE, one-tailed p, nested F, dummy dropping.
- `code/tests/`: unit tests (see below).
- `code/dev_out/v1_2/`: outputs of the v1.2 full grid on the synthetic development file (meaningless
  results); `code/dev_out/v1_2_log.txt` the run log; `code/dev_out/test_log_v1_2.txt` the test log.
  The earlier `code/dev_out/v1_1/` round (if present) is kept for reference.

Tests are plain `unittest` files and must be run as scripts (the directory name `code` shadows the
standard library module `code`, so `python -m unittest code/tests/...` does not resolve):

```
~/.venv/bin/python code/tests/test_regression.py
~/.venv/bin/python code/tests/test_coding.py
~/.venv/bin/python code/tests/test_influence.py
~/.venv/bin/python code/tests/test_pipeline_checks.py
~/.venv/bin/python code/tests/test_v1_1.py
~/.venv/bin/python code/tests/test_v1_2.py
```

## v1.1 changes

Each amendment item (A1-A10) and each checker item (C1-C13) and what changed in the code. Nothing
in the grid, the models, the variables or the axis levels changed.

### Amendment items

- **A1 (HC3 with leverage-one rows).** `regression.fit_linear` now forms the HC3 meat from the rows
  with `1 - h_ii > 1e-8` only; rows at or above the threshold contribute exactly zero. The bread and
  every other statistic are unchanged. HC3 columns are never NA for an estimated model. The count of
  such rows is returned as `n_leverage_one` and written as the new last column of `model_stats.csv`
  (NA for failed models). For WLS the leverage is that of the weighted design `sqrt(w) X`, with the
  same threshold. The `hc3_undefined` and `unimplemented` entries of `run_info.json` are gone;
  `run_info.json` now states the convention (`hc3_convention`) and the number of models with at
  least one such row. Influence refits use the same `fit_linear`, so they follow the same rule.
- **A2 (spec-level codes beat declared-missing).** `apply_missing` has a `keep` argument that now
  also overrides declared-missing *ranges* (previously only individual values). It is used for
  995 under staff_coding L2, for V157 = 99996 (recoded to 100000 before anything else can mask it)
  and for V261 = 96 (recoded to 100 under hierarchy L0/L2 and in CHK_hierarchy_log10; missing
  under L1). Range bounds given as strings (`"LO"`, `"HI"`, as in the metadata file) are parsed as
  open ends.
- **A3 (CHK_hierarchy_log10).** Unchanged: `build_vhier(check="hierarchy_log10")` returns
  log10 of the recoded count (96 as 100), i.e. ln(count)/ln(10). This is what v1 already did; the
  checker's item C13 is resolved by the amendment (see below). A test now asserts the identity with
  the L0 value divided by ln 10.
- **A4 (system-missing routing).** SUBSID is missing at every level when V17 is system-missing
  (previously under L1/L2 a valid V21 produced a value). DECENT with V17 missing was already
  missing; `build_decent` now reads V17 through the metadata like every other variable. A
  system-missing V43 is now missing on industry at both levels (previously it was `UNCL` under
  L0); `UNCL` applies only to a non-missing V43 with an empty crosswalk field or no entry.
- **A5 (column dropping and nested tests).** `drop_collinear_dummies` runs before any
  degrees-of-freedom check, for the reported models, the restricted models of nested tests and
  every influence refit. It fails with a specific reason when a non-dummy column is all zero
  (`non-dummy column(s) all zero: NAME`) or collinear (`non-dummy column(s) collinear: NAME`). (In
  v1.1 a non-dummy design with no more rows than non-dummy columns was reported as
  `no residual degrees of freedom` at the drop stage; **v1.2** reports it as all-zero / collinear and
  leaves the residual-df failure to `fit_linear` after the drops, per checker item 1.)
  A model fails only if no positive residual df remains after the permitted dummy drops. `nested_f`
  now checks that the effective rank increase (k_full - k_restricted, after dummy resolution in
  both) equals the number of added terms (6 or 3) and raises otherwise; the test row then holds NA
  and the reason is listed in `run_info.json`.
- **A6 (failure records).** `model_stats.csv` records `dropped_columns` for failed models too
  (the drops are computed before the fit). The `failures` entries of a failed model also carry
  `dropped_columns`. If an influence-diagnostic original model failed, `influence.csv` holds one
  failed row per record of that model's estimation sample and per HRM/interaction term, with the
  reason (`original model failed: ...`); a single failures entry is added for the model. Failures of
  restricted models (and of full models that are unavailable) are listed in `run_info.json` under
  the stage `<full>_vs_<restricted>` with the reason and the restricted model's dropped columns.
  `NA` is used in the CSV files; `run_info.json` uses JSON `null` (stated in the file under
  `missing_value_convention`).
- **A7 (validity for the copy rule).** `staff_raw_item` now returns the item as a *valid count
  under the current staff_coding level*: 996-999 always missing, 995 missing except under L2, 0 and
  negatives missing under L0/L2, negatives missing under L1, declared codes missing. The copy rule
  (`apply_copy_rule`) therefore sees NaN for every value that is not valid at that level, so an
  invalid CORE item is never copied to the GSS item under the V79-system-missing rule and never
  chosen over a valid GSS item for the manager fallback. `staff_transform` is now a plain log
  (ln x, or ln(1+x) under L1) of the valid count. Results for rows without copies are identical to
  v1.
- **A8 (reference sample under z_reference L1/L2).** `build_family_frames` determines the family's
  complete-case sample once from validity: outcome, controls, industry group, and each HRM index,
  where the STAFF/TRAIN index is valid iff the item_rule is met by the valid *transformed* items.
  Standardization is then done within that sample and membership is **not** recomputed; the
  "membership changed" note of v1 no longer exists. If a standardized value is undefined inside the
  reference (an item constant within it), the index stays missing for that row, the row stays in
  the sample and the affected models fail with `non-finite values in design columns: ...`; no sample
  is silently changed. Under L0/L3 the standardization is frame-wide as before.
- **A9 (other coding precedence).** SUBSID L1/L2: V17 == 2 gives 0 whatever V21 holds (the
  previous mask order let V21 == 2 win). STAFF: 995-999 are never counts except 995 under L2;
  996 is now explicitly missing (it is not in the metadata's declared list). V8, V17, V43 and
  WEIGHT are read through their metadata declarations: NONPROF, the market filter, SUBSID, DECENT
  routing, the industry lookup and WLS weights all use the masked values; a WEIGHT equal to a
  declared missing value (0) is missing and the row is excluded under weights L1, and a positive
  declared-missing WEIGHT would be excluded as well.
- **A10 (influence refits).** Each deletion refit starts from the columns kept in the original fit
  and resolves industry-dummy collinearity (`drop_collinear_dummies`: all-zero first, then rank)
  *before* the df check; the note says `dropped all-zero dummies: ...` and/or
  `dropped collinear dummies: ...`. Failed deletions are retained in `influence.csv` and are also
  added to `failures` in `run_info.json` (stage `influence:<model_id>`, with `deleted_V1`).

### Checker items

- **C1 (raw V8/V17/V43/WEIGHT).** Fixed (A4, A9): all four are read through `apply_missing` with
  their metadata declarations. WEIGHT 0 (declared) is missing; any declared-missing WEIGHT value
  is excluded from WLS.
- **C2 (STAFF 996).** Fixed (A9): 996 is in the always-missing list for V62/V97/V131.
- **C3 (995 under L2, V157 99996, V261 96 masked by metadata).** Fixed (A2): `keep` overrides
  ranges; the top-code recodes are protected from masking by `keep` and applied before the log.
- **C4 (CORE 0 copied under item_rule L2).** Fixed (A7): the level's exclusions are applied before
  the copy rule, so a CORE 0 (L0/L2) or 995 (L0/L1) is not valid, is not copied to the GSS item
  under the V79-system-missing rule and does not pre-empt the manager's GSS fallback. Under
  staff_coding L1 a count of 0 is valid and is copied.
- **C5 (reference sample determined from standardized L0 indices and recomputed).** Fixed (A8):
  membership from validity only, determined once, never recomputed.
- **C6 (SUBSID = 1 when V17 == 2 and V21 == 2).** Fixed (A9): V17 == 2 is applied last and gives 0.
- **C7 (all HC3 statistics NA when any row has leverage one).** Fixed (A1): zero contribution for
  those rows, HC3 reported for every coefficient, `n_leverage_one` column added.
- **C8 (influence refits fit before dropping collinear dummies; df check before rank).** Fixed
  (A5, A10): collinearity is resolved first in every refit, starting from the kept columns.
- **C9 (failed origin model: one row per term with missing deleted_V1).** Fixed (A6): the failed
  model keeps its rows and V1 list; `influence.csv` has one failed row per record and term with
  the reason. (Only when the estimation sample is empty is there no record to list; then one row
  per term with `deleted_V1 = NA` is written so the failure remains visible.) **Superseded in v1.2
  (checker item 2):** A6 means one row per *record*, not per term, so a failed origin model now gives
  exactly one row per record with `term = NA`, and an empty sample gives no influence row at all. See
  "v1.2 changes".
- **C10 (dropped columns lost when the fit fails after dropping).** Fixed (A6): drops are computed
  before the fit and written for failed models and in the failures list.
- **C11 (influence refit failures missing from run_info.json).** Fixed (A6, A10).
- **C12 (JSON null instead of NA).** Not changed; resolved by amendment A6, which states that `NA`
  applies to the CSV files and JSON may use null. `run_info.json` says so explicitly.
- **C13 (hierarchy_log10 should be log10 of ln(count)).** Not changed; resolved by amendment A3,
  which defines CHK_hierarchy_log10 as log10 of the recoded count (the base-10 re-expression of the
  L0 variable), which is what the code computes.

Other small changes in v1.1: integer-valued count columns (`n`, `k`, `n_industry_dummies`,
`f_df1`, `f_df2`, `df`, `df1`, `df2`, `V1`, `deleted_V1`, `n_leverage_one`) are written as integers
(not `14.0`) in the CSV files; `drop_collinear_dummies` reports non-finite design columns by name
instead of letting the rank computation fail.

## v1.2 changes

Second repair round against the same amendment (`spec_amendment_v1_1.md`) and a second checker pass
(`checker_items.md`, three items). Nothing in the grid, the models, the variables or the axis levels
changed. The three checker items all refine the amended reading of A5/A10, A6 and specification
section 6; the code change is confined to `paperk7/regression.py` and `paperk7/pipeline.py`.

### Amendment items

All of A1-A10 remain satisfied as described under "v1.1 changes". v1.2 sharpens three of them in
line with the new checker items; the rest (A1 HC3 leverage-one, A2 top codes, A3 log10 hierarchy,
A4 system-missing routing, A7 copy-rule validity, A8 reference sample, A9 coding precedence) are
unchanged.

- **A5 / A10 (industry collinearity before the df check).** The residual-degrees-of-freedom check is
  now performed only in `fit_linear`, after the permitted industry-dummy drops.
  `regression._check_non_dummy_columns` no longer raises a residual-df error at the dummy-resolution
  stage: a rank-deficient non-dummy design is always reported with the all-zero or collinear reason
  that applies to it (A5), even when there are no more rows than non-dummy columns. A model fails for
  lack of df only when none remains after the drops, and then the failure comes from `fit_linear`
  with the `n`/`k` in the message. This holds for reported models, restricted models of nested tests
  and every influence refit.
- **A6 (one influence row per record for a failed origin model).** When an influence-diagnostic
  original model fails, `influence.csv` now holds exactly one row per estimation-sample record, with
  `term = NA`, `status = failed` and the reason in `note` (previously one row per record *per* HRM /
  interaction term). An empty estimation sample yields no influence rows at all (previously a single
  row per term with `deleted_V1 = NA`); the failure is still recorded in `run_info.json` under the
  stage `influence:<model_id>`. A deletion that fails inside an otherwise successful model is
  unchanged: it still records one row per term (section 7).

### Checker items

- **Checker item 1 (A5/A10: resolve dummy collinearity before the df check).**
  `regression._check_non_dummy_columns` (regression.py:39-62) dropped its premature
  `n <= len(keep_idx)` residual-df branch. It now returns when the non-dummy base is full rank and
  otherwise raises `non-dummy column(s) all zero: ...` or `non-dummy column(s) collinear: ...`; it
  never raises a residual-df error, so dummy resolution (regression.py:84) and the influence refits
  (pipeline.py:401) defer every df decision to `fit_linear`, after the permitted drops. A rank-
  deficient non-industry design with no more rows than non-industry columns is now reported as
  all-zero / collinear with the offending term named, as A5 requires.
- **Checker item 2 (A6: one influence row per estimation-sample record).** `pipeline.influence_rows`
  now emits, for a failed original model, one row per record via the new `_orig_failed_row`
  (term `NA`), instead of one row per record per term through `_failed_rows`; and it emits no row
  when the estimation sample is empty (the stray `deleted_V1 = NA` row is gone). `_failed_rows` is
  kept only for per-deletion failures inside a successful model, which still list every term.
- **Checker item 3 (section 6: report k and the industry-dummy count on a failed fit).** When dummy
  resolution succeeds but the subsequent `fit_linear` fails (for example no residual df after the
  permitted drops), `run_spec` now reads the parameter count `k` and the number of industry dummies
  from the resolved column names and passes them to `_stat_row`, which records them even without a
  successful fit. Both stay `NA` only when resolution itself failed or the sample was empty, so no
  design survived. On the synthetic file every failure is an empty-sample D05 model, so this path is
  covered by the unit tests rather than the grid output.

## Interpretations where the spec was not explicit

Inputs and codes

1. The metadata file is a list of variable records; `declared_missing_values` and
   `declared_missing_ranges` (dicts with `low`/`high`, where `"LO"`/`"HI"` are open ends; none occur
   on the variables used) are applied to every variable read, except where a spec level assigns a
   value to a code (A2: 995 under staff_coding L2, V157 99996, V261 96).
2. The crosswalk lists several groups separated by semicolons (e.g. `11;12`), not commas as the spec
   says. Both separators are accepted. `census1980_code` is matched to V43 as an integer (leading
   zeros ignored). Group labels keep the two-digit string of the crosswalk (`07`, dummy `IND_07`);
   the unclassified group is `UNCL` with dummy `IND_UNCL`.
3. Non-missing V43 values absent from the crosswalk (two codes in the development file) are `UNCL`
   under industry L0 and missing under L1, as for an empty field. A system-missing V43 is missing
   at both levels (A4).
4. Ordering of group codes for tie breaks is numeric; `UNCL` sorts after every numeric code, so
   "lowest code" never picks UNCL over a numeric code and "highest code" (CHK_industry_ref_alt)
   prefers UNCL in a tie.
5. "System-missing" (copy rule) means a blank cell in the raw file. User-missing codes 8/9 on V79 or
   V114 are not system-missing and do not trigger the copy.
6. STAFF items: 996, 997, 998, 999 are always missing; 995 is missing under staff_coding L0/L1 and
   kept as 995 under L2 whatever the metadata declares. Under L0 and L2 a count of 0 is missing
   (x >= 1 rule); under L1 it gives ln(1) = 0. These exclusions are applied before the copy rule (A7).
7. V157 = 99996 is set to 100000 before the log; V261 = 96 is set to 100 (hierarchy L0/L2) or
   missing (L1). Both recodes take precedence over the metadata (A2).

Indices and the copy rule

8. "Valid" in the copy rule means not missing after every exclusion of the current axis level (A7):
   STAFF items as in item 6; 8/9 for ILM items; 7/8/9 for V222/V235. V79 == 2 copies
   unconditionally, so a missing CORE item makes the GSS item missing. For V79 blank the copy
   happens only when the CORE item is valid, per item.
9. The manager copy is applied after the GSS copy and uses the post-copy GSS values as fallback.
   For V114 == 2 or V114 blank it is applied with no further condition, as written; the CORE item
   is used when valid, otherwise the GSS item, otherwise the manager item is missing.
10. The copy rule only runs under item_rule L2. Under L2 all indices use the L0 averaging rule.
11. The no_training rule applies to every row with V145 == 2, whatever V157/V172 contain (in the
    real file they are skipped). Rows with V145 8/9 or blank keep their own V157/V172 coding and
    have a missing V145 item.
12. train_log L0 logs the recoded V145 (2 -> ln 2, 1 -> 0) and the reversed V172 (1..3). Under
    train_log L1 and L2 the V157 rule still follows the no_training level (ln x with 0 missing under
    no_training L0; ln(1+x) under L1/L2), and L2 uses the raw count.
13. DECENT: rows with V17 missing (A4) or V17 neither 1 nor 2 have all eight decision items missing.
    Codes 6, 7, 8, 9 are missing under both maps.
14. CHK_hierarchy_log10 is log10 of the hierarchy count (V261 with 96 as 100), i.e. the base-10
    version of the L0 variable, not log10 of ln(V261) (A3). CHK_pct_proportion divides PCTMGR by 100.

Standard scores

15. The reference set for z_reference L0/L3 is the record frame after the `records` axis. L0 uses
    the sample SD (n-1), L3 the population SD (n). A reference set with fewer than two valid values
    or zero SD makes the item's score missing.
16. Under L1 and L2 the reference sample is the family's common complete-case sample (outcome, all
    seven HRM indices, controls, industry, and WEIGHT under weights L1), determined once from
    validity (A8): the STAFF/TRAIN index counts as valid when the item_rule is met by the valid
    transformed items. Items are standardized within that sample; rows outside it keep the L0
    scores; membership is never recomputed. The grid never combines z_reference L1/L2 with
    case_scope L1; if it did, the same common sample would be used as reference.
17. Under L1 the market family receives exactly the org-sample scores; under L2 each family is
    standardized within its own common sample.

Controls

18. Binary recodes written as "X gives 1, else 0" give missing when the source is missing (SUBSID
    with V17 blank at every level; COMPET L1/L2 with V328 missing; NONPROF with V8 blank).
19. SUBSID L1/L2: V17 == 2 gives 0 whatever V21 holds (A9); V17 == 1 with V21 8/9 or blank is
    missing; V21 = 7 "something else" gives 0; L2 additionally gives 1 for V21 in {1, 2, 3}.
20. LOGEMP L0: either component 99998/99999 makes the sum missing; a sum of 0 is missing by the log
    rule. NEWTOTAL has no declared missing codes; values <= 0 are missing after the log.
21. PCTMGR: the numerator is missing for V114 in {2, 8, 9, blank} and for V115 99998/99999; the
    denominator (V23+V32, or NEWTOTAL under L2) missing or 0 gives missing.
22. UNION: V166 "yes gives 3, no gives 1" is taken as the final item value (not reversed again);
    V220/V233/V300 are reversed 4-x; code 7 on V233/V300 is missing (declared). The index obeys
    item_rule (L1 requires every listed item).
23. PRODUCT/SERVICE: V41 8/9 or blank gives missing on both; V41 = 4 follows the `neither` axis.

Samples and models

24. WEIGHT is read through its metadata declaration (0 is missing) and must be > 0 under weights
    L1 (A9); under case_scope L0 this is part of the family's common sample so that all models of
    the family share one sample. Under weights L0 WEIGHT is ignored.
25. market_sample L1 uses V9 == 4 after V9's missing codes (8/9 excluded); V8 is read through its
    (empty) metadata declaration.
26. Industry reference group: under case_scope L0 it is chosen once from the family sample; under
    L1 from each model's own rows. Dummies are created for the groups present in those rows.
27. Dummy dropping (A5): all-zero dummy columns are dropped first, then dummies that do not
    increase the rank are dropped in column (code) order, before the residual-df check. Only
    industry dummies are ever dropped; an all-zero or collinear non-dummy column fails the model
    with that column named in the reason. Drops are listed in `dropped_columns` as
    `IND_xx(all_zero)` / `IND_xx(collinear)`, for failed models too.
28. Nested tests: the restricted model is the full model's design without the added columns, on the
    full model's rows (identical to the reported restricted model under case_scope L0), re-checked
    for dummy collinearity. df1 is the number of added terms (6 or 3), df2 the full model's residual
    df; F is computed from the (weighted) SSRs, which equals the delta-R2 form because both models
    share the same (weighted) total sum of squares. If the effective rank increase differs from df1
    the test is failed with that reason (A5).
29. Overall F tests all slopes including dummies against the intercept-only model; adjusted R2 is
    the usual 1-(1-R2)(n-1)/(n-k). For WLS, R2 uses the weighted centred total sum of squares
    (statsmodels/R convention).
30. Centering L1 uses the means of each interaction component over the model's own estimation
    sample; main effects stay uncentered. Centering means are stored per model and held fixed in
    the influence diagnostic (none exist for the origin spec, which has centering L0).
31. Design column order: (Intercept), HRM terms, interactions, controls, industry dummies.
32. HC3 (A1): leverage within 1e-8 of 1 (weighted design under WLS) marks a row whose contribution
    to the HC3 meat is set to zero; `n_leverage_one` counts those rows per model. HC3 t and p use
    the t distribution with the residual df.

Influence diagnostic

33. One row per deletion and per HRM/interaction term for a successful model. Each refit starts from
    the columns kept in the original fit; all-zero and collinear dummies are dropped first and noted;
    a failed deletion gives `status = failed` rows (one per term) with the reason in `note` and a
    failures entry in `run_info.json`. If the original model itself failed, every record of its
    estimation sample gets a single failed row with `term = NA` and the reason (v1.2, checker item 2);
    an empty estimation sample yields no influence row, only the `run_info.json` failure. All variable
    values, standard scores and dummy sets are those of the origin fit; nothing is recomputed from the
    data. Refits are explicit (no closed-form update).

Outputs

34. `samples.csv` lists one set per family with `model_id = ALL` under case_scope L0 and one set
    per model under L1 (nested-test rows are the full model's rows and are not listed separately).
35. `NA` is written for every missing value in the CSV files, including `error` for ok models and
    `dropped_columns` when nothing was dropped; `run_info.json` uses null (A6). `run_info.json`
    also stores the z-score reference moments per spec and family.
36. A model fails (status `failed`, reason in `error`, no coefficient rows) when its sample is empty,
    has no residual df after the permitted dummy drops, has an all-zero or collinear non-dummy
    column, or has non-finite values in the design. On the synthetic file spec D05 (item_rule L1)
    has empty samples in both families because the independently permuted columns break the skip
    patterns (for example DECENT needs all eight decision items valid, which only 7 rows satisfy).
    This is a data artefact, recorded in `run_info.json` as 32 failures (24 models + 8 nested tests).

## Test results

All tests pass (run on 2026-10-28 with Python 3.13.4, numpy 2.4.2, pandas 2.2.3, scipy 1.16.3,
statsmodels 0.14.6 as reference; v1.2 log in `code/dev_out/test_log_v1_2.txt`, 91 tests across the
six files). The v1.1 reading of two assertions (the "too few rows" reason in `test_v1_1.py` and the
failed-origin influence row count) was updated in place to the amended behaviour; see "v1.2 changes".

| File | Tests | Covers |
|---|---|---|
| `test_regression.py` | 11 | OLS exact recovery of a known structure; OLS and WLS estimates, conventional SE, t, p, df, R2, adjusted R2, overall F against statsmodels; HC3 against statsmodels and against the explicit formula (unweighted and weighted design); one-tailed p (upper + lower = 1, two-sided = 2 min, direction); nested F and delta R2 against `compare_f_test` (OLS and WLS); leverage-1 row gives zero HC3 contribution and finite HC3 (A1); rank deficiency and no-df errors; all-zero / collinear dummy dropping. |
| `test_coding.py` | 26 | Declared missing values and ranges; reversal; index rules L0/L1/L2; log of non-positive values; z-scores (n-1, n, reference subset, rows outside keep L0 values, constant reference); POP/PMP; STAFF coding L0/L1/L2 with 0/995/997/998/999; TRAIN under every no_training and train_log level incl. 99996 and V172 = 4; INCENT, GRIEV, ILM; DECENT routing by V17, both decision maps, code 6; VHIER L0/L1/L2 and the log10 check; GSS and manager copy rules incl. system-missing vs user-missing and copy order; NONPROF, SUBSID L0/L1/L2, LOGEMP L0/L1/L2, LOGAGE L0/L1/L2, PCTMGR L0/L1/L2 and the proportion check, UNION L0/L1/L2 incl. V166 and code 7, PRODUCT/SERVICE with neither L0/L1, COMPET L0/L1/L2; crosswalk parsing (comma, semicolon, empty), industry L0/L1, UNCL vs blank V43, reference group selection (largest/lowest, smallest/highest, UNCL ordering), dummies; records L1; market sample and requires_pop filters; required variable lists; standardization inside the frame builder (L0 vs L3). |
| `test_influence.py` | 4 | Leave-one-out estimates, SE, two-sided and upper-tail p equal explicit statsmodels refits for every deletion (OLS and WLS); deletion of a single-member group drops and flags the dummy; refit failures are retained with the reason and listed as failures; the design is not modified and the OLS result equals the closed-form DFBETA update. |
| `test_pipeline_checks.py` | 6 | On the synthetic file: common sample equals the complete-case rows and every model of a family uses it; nested F for the origin equals statsmodels on the actual designs; CHK specs are invariant (log10: identical t and R2, VHIER slopes scaled by ln 10; proportion: PCTMGR slope x100, same t; alternative reference group: identical non-industry slopes and SEs, different dummy set); case_scope L1 model-specific rows and WLS against statsmodels; centering changes only interaction columns and leaves R2 unchanged; z_reference L1/L2/L3 behaviour. |
| `test_v1_1.py` | 28 | A1: HC3 with a leverage-one row (OLS and WLS, explicit formula, bread unchanged, equality with HC3 on the reduced design), `n_leverage_one` in model stats, no NA HC3. A2/A9: 995 kept under L2 despite a declared range, 996-999 missing at every level, V157 99996 and V261 96 recoded despite declarations, A3 identity, string range bounds. A4/A9: V17 blank gives missing SUBSID (all levels) and DECENT, V17 == 2 beats V21 == 2, blank V43 missing vs UNCL, WEIGHT and V8 through metadata. A7: copy-rule validity for CORE 0 / 995 / 996 / declared codes under staff_coding L0/L1/L2, manager fallback by validity, other items. A8: reference sample from validity, moments within the sample, rows outside keep L0 scores, membership fixed when a score is undefined (model fails explicitly). A5: non-dummy all-zero / collinear reasons (never a residual-df error at the drop stage, v1.2), collinear dummies dropped before the df check in `run_spec`, `k` and the industry-dummy count reported on a failed fit (v1.2), nested-test rank-increase mismatch recorded as failed, df1 = 6 / 3. A6/A10: dropped columns on failed fits and in failures, one influence row per record for a failed origin model (v1.2), collinear dummy resolved before the df check in a refit (OLS and WLS, against statsmodels), failed deletions listed, refits start from the kept columns. Development file: HC3 present for every coefficient, blank V43 never UNCL. |
| `test_v1_2.py` | 16 | Checker item 1: `drop_collinear_dummies` reports all-zero / collinear (never a residual-df error) for a rank-deficient non-dummy design, including fewer rows than non-dummy columns, and defers the df check to `fit_linear` when the base is full rank. Checker item 2: a failed origin model gives one influence row per record with `term = NA`, no row for an empty sample (direct and through `run_spec`/`run_influence`), while a per-deletion failure inside a successful model still lists every term. Checker item 3: `k` and `n_industry_dummies` reported when a fit fails after successful dummy resolution, and `NA` when resolution fails or the sample is empty. HC3 with a leverage-one row (OLS and WLS, explicit formula, zero contribution, finite SE). Copy-rule validity (GSS copy and manager fallback follow level exclusions under staff_coding L0/L1/L2). |

Full grid on `data/survey.csv` (`code/dev_out/v1_2/`, log in `code/dev_out/v1_2_log.txt`):
38 specs run, 24 models per spec, all six output files written, 32 recorded failures (all from D05,
see item 36), HC3 statistics present for every coefficient of every estimated model, influence rows
for all eight models of the origin spec (one per deletion and term; the origin spec itself does not
fail, so no failed-origin rows arise on this file). Every D05 failure is an empty estimation sample,
so `k` and `n_industry_dummies` are `NA` there (the checker-item-3 path is exercised by the unit
tests). Results on the synthetic file are meaningless and were not interpreted.
