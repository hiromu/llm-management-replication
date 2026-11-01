# PAPER_K7 v1 grid implementation (R) — code version v1.1

Implements `implementation_spec.md` (frozen, version 1) **as amended by `spec_amendment_v1_1.md`**
for every specification in `grid_v1.json`. Base R and `stats` only, plus `jsonlite` for JSON I/O.
The tests additionally use `sandwich` and `lmtest` as reference implementations.

The section "v1.1 changes" at the end lists, for every amendment item (A1–A10) and every checker
item (1–11), what changed in this round.

## Files

| Path | Purpose |
|---|---|
| `code/run_grid.R` | Main script (CLI). Runs all specs in `compute_order`, writes the section 8 outputs. |
| `code/k7_lib.R` | All coding, sampling, estimation and influence functions. Sourced by the main script and the tests. |
| `code/tests/run_tests.R` | Runs every test file; writes `code/dev_out/test_results.txt`. |
| `code/tests/test_ols.R` | OLS, WLS, conventional SE, HC3 (including leverage-one rows), one-tailed p, nested F, overall F against `lm`, `anova`, `sandwich::vcovHC`, `lmtest::coeftest`; industry-only column drops, failure reasons, drop information on failure. |
| `code/tests/test_coding.R` | Hand-built rows for every coding rule and axis level (missing codes, reversals, logs, top codes, routing, copy rule and its validity rule, decision maps, industry mapping and UNCL, neither, no-training, z-scores, validity-based samples, family filters, centering). |
| `code/tests/test_loo.R` | Leave-one-out refits on a small case against explicit `lm` refits, including the all-zero-dummy flag, dummy drops before the df check, refit failures with reasons, failed original model, WLS. |
| `code/tests/test_spec_invariances.R` | `run_spec()` end to end on the synthetic file: output structure, CHK_ invariances, centering, case_scope L1, weights, z_reference, validity-based samples. |
| `code/dev_out/v1_1/` | Outputs of the full grid (v1.1 code) on the synthetic `data/survey.csv` (meaningless numbers; structural check only). |
| `code/dev_out/v1_1_run_log.txt` | Console log of that run. |
| `code/dev_out/test_results.txt` | Test log (v1.1). |
| `code/DONE.txt`, `code/DONE_v1_1.txt` | Completion markers of the two rounds. |

## How to run

```
/opt/homebrew/bin/Rscript code/run_grid.R \
  --data data/survey.csv \
  --metadata data/survey_metadata.json \
  --crosswalk data/industry_crosswalk.csv \
  --grid grid_v1.json \
  --out <output_dir>
```

Writes `coefficients.csv`, `model_stats.csv`, `nested_tests.csv`, `samples.csv`, `influence.csv`
and `run_info.json` to `<output_dir>` (created if needed). Missing values are written as `NA` in
the CSV files and as `null` in the JSON file (amendment A6). Progress goes to stderr. The run on
the 727-row synthetic file takes about 12 seconds, most of it the leave-one-out refits of the
origin spec.

Tests:

```
/opt/homebrew/bin/Rscript code/tests/run_tests.R
```

## Output columns beyond the section 8 tables

- `model_stats.csv` has the additional last column `n_leverage_one` (amendment A1): the number
  of rows of the estimation sample with hat value `h_ii >= 1 - 1e-8` (on the weighted design under
  weights L1). `NA` for failed models.
- `nested_tests.csv` has the additional last columns `status` (`ok` / `failed`) and `error`
  (the reason), because amendment A5/A6 require nested tests to be recorded as failed with a
  reason (full model failed, restricted model failed, or rank increase different from the number
  of added terms). The original eleven columns are unchanged; a failed test has `NA` statistics.

## Processing order per specification

1. Record frame (`records`), declared missing codes from the metadata, item recodes. Every
   level-specific exclusion is applied to the raw items at this point (A7).
2. Copy rule (only `item_rule` L2), then STAFF/TRAIN item transformations and the item-validity
   flags of the STAFF and TRAIN indices (A8).
3. All other indices and controls, industry group, weight.
4. Family common complete-case samples (the case_scope L0 definition, also the z_reference L1/L2
   reference samples), determined from validity alone (A8).
5. L0 standard scores (all frame rows, sample SD; population SD for L3), STAFF and TRAIN indices.
6. `z_reference` L1/L2: re-standardize within the reference sample(s) found in step 4; rows outside
   keep L0 values; indices recomputed; membership is not recomputed.
7. Industry dummy set and reference group per family; 12 models per family; nested tests;
   influence diagnostic (origin spec only).

Failures are recorded, never skipped: a model that cannot be fitted gets `status = failed` and the
reason in `model_stats.csv` (with any industry dummies dropped before the failure in
`dropped_columns`); its nested tests are written with `status = failed` and the reason; a
whole-spec failure writes all 24 model rows, 8 nested rows and (for the origin) 8 influence rows as
failed; `run_info.json` lists every failure (models, nested tests, influence deletions).

## Interpretations where the specification was not explicit

Inputs and codes

1. **Crosswalk separator.** The spec says several SIC groups are comma-separated; the supplied
   file uses `;` (for example `11;12`). The field is split on either `;` or `,`.
2. **Census code matching.** Crosswalk codes are zero-padded strings (`010`), V43 is numeric (10).
   Codes are matched as integers.
3. **V43 missing.** A blank or declared-missing V43 gives a missing industry group under both
   industry levels (A4); UNCL applies only to non-missing codes with an empty field or no entry.
4. **Undocumented codes on 1..k items.** Values outside 1..k on a reversed item are missing
   (the dev file has a stored 0 on V233). Likewise COMPET outside 1..4 and decision codes outside
   1..5 are missing. For the copy-rule items this exclusion is applied before the copy (A7).
5. **Staff codes 996 and 997.** The metadata does not declare 996/997 as missing for V62/V97/V131;
   the spec and A9 say they are missing, so they are applied explicitly in all staff_coding levels.
6. **WEIGHT = 0** is a declared missing code in the metadata; it is applied (and is excluded under
   weights L1 anyway, A9).
7. **Declared missing ranges** in the metadata are honoured generically; none of the variables used
   declares a range.
8. **Non-numeric columns** in the dev CSV (V18, V19, V42, V334, V343) are not used; every used
   column is coerced to numeric.
9. **Records L1** drops only rows with V3 == 0; rows with a blank V3 are kept.
10. **Age** is 1991 - V16, as stated; L2 keeps negative ages (V16 = 1992 gives -1).

Copy rule (item_rule L2)

11. "GSS = CORE when V79 == 2 or V79 is system-missing while the CORE item is valid" is read
    per item as: `V79 == 2`, OR (`V79` blank AND the CORE item for that pair is valid).
    System-missing means a blank cell only; the declared codes 8/9 on V79 and V114 are ordinary
    missing values and do not trigger the copy.
12. When a row is flagged by `V79 == 2`, the GSS item is overwritten by the CORE item even if the
    CORE item is not valid (the GSS item becomes missing). Same for the manager copy when both
    sources are invalid.
13. The manager copy is applied after the GSS copy and uses the post-copy GSS value as the
    fallback source.
14. Under item_rule L2 the copy affects STAFF (V97, V131), ILM (V102, V111, V136) and INCENT
    (V235, V209). POP, PMP, TRAIN, DECENT and UNION have no copied items, so L2 equals L0 for them.
15. "Valid" for the copy test and for the GSS fallback means: passed every exclusion that applies
    at the current axis level (A7). For STAFF: declared missing codes, 996–999, and 995 unless
    staff_coding is L2; 0 under L0/L2 (counts must be >= 1); negative counts under every level.
    For ILM items: in 1..2 after declared codes; for INCENT items: in 1..3 after declared codes.

Indices and standard scores

16. **UNION L2, V166.** "Yes gives 3, no gives 1" is taken as the final value on the reversed
    scale (3 = the "very important" end, matching the other reversed items); it is not reversed a
    second time.
17. **Standard scores** need at least two valid values and a positive SD; otherwise the item z is
    missing. (On the real file this cannot happen for the frame-wide L0 reference.) Sample
    membership never depends on this (A8), so a degenerate item would surface as a fit failure
    "missing values in design", not as a changed sample.
18. **z_reference L1/L2 reference sample** is the family's common complete-case sample as defined
    for case_scope L0, determined from validity before any standardization (A8). The same
    definition is used when case_scope is L1 (the grid never combines these, but the code handles
    it). Under L2 the market family's reference is the market common sample; under L1 both
    families use the organizational one.
19. **z_reference L3** divides each item by the population SD over all frame rows; the index is
    then the mean of these z-scores. Because the three items have different valid counts, this is
    not a pure rescaling of the L0 index (so t statistics are not expected to be invariant).
20. **no_training** overrides V157/V172 for every V145 == 2 row, even if a value is stored. The
    top code 99996 -> 100000 is applied before that override and takes precedence over any
    declared missing code (A2).
21. **train_log L0** logs the recoded V145 (2/1 -> ln 2 / 0) and the reversed V172 (3/2/1 ->
    ln 3 / ln 2 / 0), as the spec says "log each of the three items".

Controls

22. **SUBSID:** a missing V17 gives missing SUBSID at every level (A4). **L0:** V17 == 1 gives 1,
    any other valid V17 gives 0. **L1/L2:** V17 == 2 gives 0 whatever V21 says (A9); V17 == 1 with
    a blank or 8/9 V21 gives missing.
23. **LOGEMP L0:** missing when either V23 or V32 is missing, or when the sum is 0 (log rule).
24. **PCTMGR:** a declared-missing V115 (99998/99999) with V114 == 1 gives a missing numerator;
    the denominator is missing when V23 or V32 (L0/L1) or NEWTOTAL (L2) is missing or 0.
25. **CHK_hierarchy_log10** is log10 of the recoded hierarchy count (with 96 taken as 100), i.e.
    ln(count)/ln(10) (A3); it is not log10 of ln(V261).
26. **Weights L1:** rows with WEIGHT missing or <= 0 are removed from the family sample (and from
    model-specific samples under case_scope L1), so they are absent from `samples.csv` and from N.

Samples, dummies and estimation

27. **Industry reference group ties** use lexical order of the group codes; two-digit codes sort
    numerically and "UNCL" sorts after them. "Lowest code" is the lexically first, "highest" the
    lexically last.
28. **case_scope L1 dummy set.** The groups entering as dummies, and the reference group, are
    determined from the family's base sample (rows valid on the outcome, the controls and the
    industry group, after the family filters). Each model then drops dummies that are all zero in
    its own rows and records them.
29. **Column drops (A5).** Only `IND_<group>` columns may be dropped: all-zero dummies are removed
    first (`(all zero)`), then aliased dummies found by the pivoted QR of `lm.wfit`
    (`(collinear)`). Because the dummies are the last design columns, the QR aliases them in
    preference to earlier columns. Any other term that is all zero or aliased fails the model with
    the reason `term all zero in the estimation sample: <term>` or
    `term collinear in the estimation sample: <term>`; a reduced model is never reported as ok.
30. **Number of parameters k** is the rank after drops, intercept included. The overall F uses
    df1 = k - 1 and df2 = N - k. The residual-df check comes after the industry drops; the model
    fails with `no positive residual df: ...` only if N <= k after them (an early exit with the same
    wording happens when N is not larger than the number of non-industry parameters, since no
    permitted drop can help then).
31. **Nested F (A5):** df1 must equal the number of added terms (6 for an HRM block, 3 for an
    interaction block). If the effective rank increase differs (possible only through a dummy that
    is collinear in one of the two fits but not the other), the test is written with
    `status = failed` and the reason, and listed in `run_info.json`. df2 is the residual df of the
    full model. Under case_scope L0 both fits use the family sample; under L1 the restricted model
    is refitted on the full model's rows, and `n` in `nested_tests.csv` is that row count. For WLS
    the weighted SSR and weighted R2 are used.
32. **Centering L1** uses unweighted means of the components over the model's estimation sample,
    also under weights L1.
33. **HC3 with weights** uses the weighted design (sqrt(w) X, sqrt(w) e, hat values of the weighted
    design), as in the software notes; it matches `sandwich::vcovHC(type = "HC3")` on a weighted
    `lm` when no row has leverage one (tested).
34. **One-tailed p values** are t-distribution tails with the residual df, for both the
    conventional and HC3 t.
35. **HC3 with leverage-one rows (A1).** Rows with `h_ii >= 1 - 1e-8` contribute exactly zero to the
    HC3 meat; the bread and all other statistics are unchanged; the count is `n_leverage_one`. The
    same threshold is applied in the influence refits and under WLS (hat values of the weighted
    design). Tested against the explicit formula restricted to the other rows.

Influence diagnostic

36. Runs only for the spec of type `origin`. The design matrix is the one actually estimated for
    the original model (after its own industry drops). Each row is deleted once; a dummy that
    becomes all zero or collinear is dropped before the df check (A10) and noted as
    `dropped: IND_xx (all zero)`. A failed refit is written as one row with `term = NA`,
    `status = failed` and the reason (plus any drop information in brackets); every failed deletion
    is also listed in `run_info.json` with its `deleted_V1` (A10). If the original model failed,
    one failed row per estimation-sample record is written with the reason (A6).
37. `samples.csv` has one set per family with `model_id = "ALL"` under case_scope L0 and one set
    per model under L1.
38. `run_info.json` lists specs run in order and every failure: per-model (`model_id`), whole-spec
    (`model_id = null`), nested tests (`model_id = "nested:<test_id>"`) and influence deletions
    (`model_id = "influence:<model>"`, with `deleted_V1`). Missing identifiers are `null` (A6).

## Nothing left unimplemented

Every rule of the specification and of the amendment is implemented. No specification was added,
removed or tuned; the grid is unchanged.

## Test results

`code/dev_out/test_results.txt`, R 4.6.1 (v1.1 code):

| File | Passed | Failed |
|---|---|---|
| test_ols.R | 59 | 0 |
| test_coding.R | 141 | 0 |
| test_loo.R | 18 | 0 |
| test_spec_invariances.R | 45 | 0 |
| **Total** | **263** | **0** |

Highlights: estimates, SE, t, p, R2, adjusted R2, overall F match `lm`; HC3 matches
`sandwich::vcovHC` and the explicit formula, and with a leverage-one row it matches the explicit
formula with that row's contribution zeroed (OLS and WLS) while sandwich is not finite; nested F
matches `anova`; all of these also under WLS; leave-one-out estimates, SE and p match explicit
`lm` refits for every deletion; refits that would need a non-industry drop fail with the reason
and are retained; a failed original model yields one failed row per record; the copy rule copies
only level-valid sources and falls back to the GSS item when the CORE item is invalid at the level;
the CHK_ specs reproduce the expected invariances (HRM estimates invariant to the omitted industry
group, VHIER estimate scaled by ln 10 with invariant t, PCTMGR estimate scaled by 100 with
invariant t); centering L1 leaves the interaction estimates, R2 and nested F unchanged.

## Full grid on the synthetic data (v1.1)

`code/dev_out/v1_1/` was produced from `data/survey.csv` (727 rows, every column independently
permuted). Results are meaningless and were not interpreted. Structure:

- 38 specs run in `compute_order`; 912 model rows (24 per spec); 304 nested-test rows (8 per spec);
  63,271 coefficient rows, all with finite HC3 statistics; influence rows for all 8 origin models
  with every record deleted once (358 deletions per organizational model, 243 per market model), no
  refit failures.
- 888 models ok, 24 failed: all of spec D05 (`item_rule` L1). On the permuted file the routing
  between V17 and the decision items is broken, so DECENT is valid on only 7 rows when all eight
  items are required, and the common complete-case samples are empty. Each model is recorded as
  `failed` with reason `no positive residual df: empty estimation sample, n (0)`; its 8 nested
  tests are `failed` with `full model failed: ...`; all 32 failures are listed in `run_info.json`.
  This is a property of the synthetic file, not of the code (the same rule passes the hand-built
  tests).
- `n_leverage_one` is positive in every fitted model (single-member industry groups exist in the
  permuted file), which is exactly the situation A1 addresses; no HC3 statistic is `NA` or `Inf`.
- Column drops occur only under case_scope L1 (D04), where industry groups absent from a
  model-specific sample are dropped and recorded; every dropped column is an `IND_` dummy.

## v1.1 changes

For each amendment item and checker item: what changed in the code (`code/k7_lib.R` unless stated),
and the test that covers it.

Amendment items

- **A1 (HC3 with leverage-one rows).** `fit_model()` now sets the HC3 contribution of rows with
  `h_ii >= 1 - 1e-8` to exactly zero (meat formed from the other rows; bread unchanged) and returns
  `n_leverage_one`; `run_grid.R` writes it as a new last column of `model_stats.csv`. Applies to
  conventional fits, restricted refits and influence refits alike; under WLS the hat values are
  those of the weighted design. Previously a leverage-one row produced 0/0 in the meat. Tests:
  `test_ols.R` (OLS and WLS against the explicit zeroed formula; conventional SE, R2 and F
  unchanged; count 0 / 1), `test_loo.R`, `test_spec_invariances.R` (finite HC3 everywhere).
- **A2 (spec-level assignments precede declared missing codes).** V157 is read with 99996 kept,
  V261 with 96 kept, and V62/V97/V131 with 995 kept under staff_coding L2, before any declared
  missing code is applied. On the supplied metadata only the 995 case is affected (995 is
  declared missing); the other two are made robust to metadata changes. Tests: `test_coding.R`
  (A2 block, with a metadata copy that declares 99996 and 96 missing).
- **A3 (CHK_hierarchy_log10).** No change: the code already computed log10 of the recoded count
  (96 taken as 100). Comment and tests added (`test_coding.R` A3 block: equals ln(count)/ln(10)).
- **A4 (system-missing routing).** SUBSID L1/L2 now give missing when V17 is system-missing (L0
  and DECENT already did). V43 now passes through the metadata missing codes before the crosswalk
  lookup, so a missing V43 is missing at both industry levels and UNCL applies only to non-missing
  codes. Tests: `test_coding.R` (A4/A9 block).
- **A5 (column dropping and nested tests).** `fit_model()` drops only `IND_` columns (all zero,
  then collinear); any other all-zero or collinear term fails the model with that reason. The
  order is now: all-zero drops, early exit if N is not larger than the number of non-industry
  parameters, QR collinearity with industry drops, then the residual-df check; a model fails only
  if no positive residual df remains after the permitted drops. `nested_f()` takes the required
  numerator df (6 or 3, computed from the model definitions) and fails the test with a reason if
  the effective rank increase differs; `nested_tests.csv` gained `status` and `error` columns.
  Tests: `test_ols.R` (A5 block), `test_loo.R`, `test_spec_invariances.R` (only `IND_` drops).
- **A6 (failure records).** `fit_model()` returns `dropped` on failure too, and `model_stats.csv`
  shows it for failed models; failed influence refits carry drop information in the note.
  `influence_loo()` writes one failed row per estimation-sample record (with `deleted_V1`) when the
  original model failed; the estimation-sample identifiers are now attached to failed fits.
  Nested-test failures (full model failed, restricted model failed, rank mismatch) are written with
  their reason and listed in `run_info.json` as `nested:<test_id>`. CSV files use `NA`, the JSON
  file uses `null` (unchanged). Tests: `test_ols.R` (drop info on failure), `test_loo.R` (per-record
  failed rows, refit failures with reasons).
- **A7 (validity used by the copy rule).** All level-specific exclusions are applied to the raw
  copy-rule items before the copy: `staff_valid()` implements the STAFF rule per staff_coding
  level (0 invalid under L0/L2, 995 valid only under L2, 996–999 never, negatives never); ILM and
  INCENT items are restricted to their 1..k ranges after the declared codes. Hence a CORE item
  that is invalid at the level neither triggers the V79-system-missing copy nor overwrites a valid
  GSS item, and the manager fallback uses the GSS item when the CORE item is invalid. The
  transformation step no longer re-applies exclusions. Tests: `test_coding.R` (A7 block, three
  staff levels, manager fallback, ILM/INCENT sources).
- **A8 (reference sample).** `build_frame()` now computes `STAFF_valid` and `TRAIN_valid` from
  item validity (`index_valid()`), and `family_sample_L0()` uses these flags (not the indices), so
  the family samples, which are also the z_reference L1/L2 reference samples, are determined once
  from validity before any standardization and are never recomputed. Model-specific samples under
  case_scope L1 use the same flags. Tests: `test_coding.R` (A8 block, including a degenerate
  constant-item fixture where the sample still includes the rows), `test_spec_invariances.R`
  (samples equal across z_reference levels; mean 0 / SD 1 within the reference sample).
- **A9 (other coding precedence).** SUBSID L1/L2 with V17 == 2 already gave 0 regardless of V21;
  test added. STAFF code 996 is now explicitly missing at every level (previously covered by the
  995–999 band; now also applied as an extra code before the copy). V8 and V17 now pass through
  the metadata missing codes (previously read raw; the supplied metadata declares none, so values
  are unchanged on this file); V43 as in A4; WEIGHT unchanged. Tests: `test_coding.R` (A9 blocks).
- **A10 (influence refits).** Refits use the same `fit_model()`, so industry-dummy collinearity is
  resolved before the df check (previously only all-zero drops preceded it; a collinear dummy was
  found only after the N > k test, so a deletion that left N = k with a collinear dummy failed
  instead of being fitted on the reduced dummy set). `run_grid.R` adds every failed deletion to
  the `run_info.json` failures list (`influence:<model>`, `deleted_V1`, reason) instead of an
  aggregate count. Tests: `test_loo.R` (dummy drop before df check; failed refits retained).

Checker items

1. **V43 missing codes bypassed.** Changed: V43 is read through `apply_missing()` (see A4).
2. **Copy validity checked only with `is.na()`.** Changed: exclusions applied before the copy
   (see A7). Under item_rule L2 with staff_coding L0, CORE V62 = 0 no longer overwrites a valid V97
   on a V79-system-missing row, and the manager item falls back to V97.
3. **SUBSID L0 with system-missing V17.** Not changed. Amendment A4 states that SUBSID is missing
   at every level when V17 is system-missing, which is what the code did; the checker's reading of
   section 4.12 ("else 0") is superseded by A4. Test added.
4. **N <= column count rejected before collinearity.** Changed: industry collinearity is resolved
   before the residual-df check (see A5); the only early exit is when N is not larger than the
   number of non-industry parameters, a case no permitted drop can repair.
5. **Non-industry columns dropped and reduced model reported ok.** Changed: only `IND_` dummies
   are dropped; any other all-zero or collinear term fails the model with that reason (see A5).
6. **Nested df from parameter counts after drops.** Changed: the required df (6 / 3) is enforced
   and a mismatch is a recorded failure (see A5).
7. **Drop information lost on failure.** Changed: `dropped` is returned on failure and written to
   `model_stats.csv`; failed influence rows carry it in the note (see A6).
8. **Influence skipped when the original model fails.** Changed: one failed row per
   estimation-sample record with `deleted_V1` and the reason (see A6).
9. **Restricted-model failures not retained.** Changed: reason written in `nested_tests.csv`
   (`status`, `error`) and listed in `run_info.json` (see A6).
10. **`null` in JSON.** Not changed. Amendment A6 states that `NA` applies to the CSV files and
    that JSON may use `null`; the writer keeps `null` for missing values and identifiers.
11. **CHK_hierarchy_log10 as log10 of ln(count).** Not changed. Amendment A3 defines the check as
    log10 of the recoded count, i.e. ln(count)/ln(10), which is what the code computes; the
    alternative reading would also break the invariance (VHIER estimate scaled by ln 10, t
    unchanged) that the check exists to confirm. Test added.
