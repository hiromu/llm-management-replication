# PAPER_K7 v1 grid implementation (R)

Implements `implementation_spec.md` (frozen, version 1) for every specification in
`grid_v1.json`. Base R and `stats` only, plus `jsonlite` for JSON I/O. The tests additionally use
`sandwich` and `lmtest` as reference implementations.

## Files

| Path | Purpose |
|---|---|
| `code/run_grid.R` | Main script (CLI). Runs all specs in `compute_order`, writes the section 8 outputs. |
| `code/k7_lib.R` | All coding, sampling, estimation and influence functions. Sourced by the main script and the tests. |
| `code/tests/run_tests.R` | Runs every test file; writes `code/dev_out/test_results.txt`. |
| `code/tests/test_ols.R` | OLS, WLS, conventional SE, HC3, one-tailed p, nested F, overall F against `lm`, `anova`, `sandwich::vcovHC`, `lmtest::coeftest`; column-drop and failure recording. |
| `code/tests/test_coding.R` | Hand-built rows for every coding rule and axis level (missing codes, reversals, logs, top codes, routing, copy rule, decision maps, industry mapping and UNCL, neither, no-training, z-scores, family filters, centering). |
| `code/tests/test_loo.R` | Leave-one-out refits on a small case against explicit `lm` refits, including the all-zero-dummy flag, failure retention and WLS. |
| `code/tests/test_spec_invariances.R` | `run_spec()` end to end on the synthetic file: output structure, CHK_ invariances, centering, case_scope L1, weights, z_reference. |
| `code/dev_out/full_run/` | Outputs of the full grid on the synthetic `data/survey.csv` (meaningless numbers; structural check only). |
| `code/dev_out/full_run_log.txt` | Console log of that run. |
| `code/dev_out/test_results.txt` | Test log. |

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
and `run_info.json` to `<output_dir>` (created if needed). Missing values are written as `NA`.
Progress goes to stderr. The run on the 727-row synthetic file takes about 15 seconds, most of it
the leave-one-out refits of the origin spec.

Tests:

```
/opt/homebrew/bin/Rscript code/tests/run_tests.R
```

## Processing order per specification

1. Record frame (`records`), declared missing codes from the metadata, item recodes.
2. Copy rule (only `item_rule` L2), then STAFF/TRAIN item transformations.
3. All other indices and controls, industry group, weight.
4. L0 standard scores (all frame rows, sample SD; population SD for L3), STAFF and TRAIN indices.
5. Family common complete-case samples (the case_scope L0 definition) found with those values.
6. `z_reference` L1/L2: re-standardize within the reference sample(s); rows outside keep L0 values;
   indices recomputed.
7. Industry dummy set and reference group per family; 12 models per family; nested tests;
   influence diagnostic (origin spec only).

Failures are recorded, never skipped: a model that cannot be fitted gets `status = failed` and the
reason in `model_stats.csv`; its nested tests are written with `NA`; a whole-spec failure writes
all 24 model rows as failed; `run_info.json` lists every failure.

## Interpretations where the specification was not explicit

Inputs and codes

1. **Crosswalk separator.** The spec says several SIC groups are comma-separated; the supplied
   file uses `;` (for example `11;12`). The field is split on either `;` or `,`.
2. **Census code matching.** Crosswalk codes are zero-padded strings (`010`), V43 is numeric (10).
   Codes are matched as integers.
3. **V43 missing.** A blank V43 gives a missing industry group under both industry levels (it is
   not treated as "not in the crosswalk", so it does not become UNCL).
4. **Undocumented codes on 1..k items.** Values outside 1..k on a reversed item are missing
   (the dev file has a stored 0 on V233). Likewise COMPET outside 1..4 and decision codes outside
   1..5 are missing.
5. **Staff code 997.** The metadata does not declare 997 as missing for V62/V97/V131; the spec
   says it is missing, so it is applied explicitly in all staff_coding levels.
6. **WEIGHT = 0** is a declared missing code in the metadata; it is applied (and is excluded under
   weights L1 anyway).
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
12. When a row is flagged, the GSS item is overwritten by the CORE item even if the CORE item is
    missing (the GSS item becomes missing). Same for the manager copy when both sources are missing.
13. The manager copy is applied after the GSS copy and uses the post-copy GSS value as the
    fallback source.
14. Under item_rule L2 the copy affects STAFF (V97, V131), ILM (V102, V111, V136) and INCENT
    (V235, V209). POP, PMP, TRAIN, DECENT and UNION have no copied items, so L2 equals L0 for them.
15. "Valid" for the copy test means non-missing after the level-specific missing codes, so under
    staff_coding L2 a CORE value of 995 counts as valid.

Indices and standard scores

16. **UNION L2, V166.** "Yes gives 3, no gives 1" is taken as the final value on the reversed
    scale (3 = the "very important" end, matching the other reversed items); it is not reversed a
    second time.
17. **Standard scores** need at least two valid values and a positive SD; otherwise the item z is
    missing. (On the real file this cannot happen for the frame-wide L0 reference.)
18. **z_reference L1/L2 reference sample** is the family's common complete-case sample as defined
    for case_scope L0, found with the L0 z-scores. The same definition is used when case_scope is L1
    (the grid never combines these, but the code handles it). Under L2 the market family's reference
    is the market common sample; under L1 both families use the organizational one.
19. **z_reference L3** divides each item by the population SD over all frame rows; the index is
    then the mean of these z-scores. Because the three items have different valid counts, this is
    not a pure rescaling of the L0 index (so t statistics are not expected to be invariant).
20. **no_training** overrides V157/V172 for every V145 == 2 row, even if a value is stored. The
    top code 99996 -> 100000 is applied before that override.
21. **train_log L0** logs the recoded V145 (2/1 -> ln 2 / 0) and the reversed V172 (3/2/1 ->
    ln 3 / ln 2 / 0), as the spec says "log each of the three items".

Controls

22. **SUBSID L0:** V17 == 1 gives 1, any other valid V17 gives 0, a missing V17 gives missing
    (rather than 0). **L1/L2:** V17 == 1 with a blank V21 gives missing.
23. **LOGEMP L0:** missing when either V23 or V32 is missing, or when the sum is 0 (log rule).
24. **PCTMGR:** a declared-missing V115 (99998/99999) with V114 == 1 gives a missing numerator;
    the denominator is missing when V23 or V32 (L0/L1) or NEWTOTAL (L2) is missing or 0.
25. **CHK_hierarchy_log10** is log10 of the hierarchy count (with 96 taken as 100), i.e. the L0
    quantity before its natural log; it is not log10 of ln(V261).
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
29. **Collinear columns.** Aliased columns (as detected by the QR decomposition in `lm.wfit`) are
    dropped and recorded in `dropped_columns` with the tag `(collinear)`; all-zero columns with
    `(all zero)`. This is applied to any column, not only dummies; the model status stays `ok` and
    the dropped term has no coefficient row.
30. **Number of parameters k** is the rank after drops, intercept included. The overall F uses
    df1 = k - 1 and df2 = N - k.
31. **Nested F:** df1 is the difference in parameter counts between the two fits (equal to the
    number of added terms unless an added term was dropped as collinear); df2 is the residual df of
    the full model. Under case_scope L0 both fits use the family sample; under L1 the restricted
    model is refitted on the full model's rows, and `n` in `nested_tests.csv` is that row count.
    For WLS the weighted SSR and weighted R2 are used.
32. **Centering L1** uses unweighted means of the components over the model's estimation sample,
    also under weights L1.
33. **HC3 with weights** uses the weighted design (sqrt(w) X, sqrt(w) e, hat values of the weighted
    design), as in the software notes; it matches `sandwich::vcovHC(type = "HC3")` on a weighted
    `lm` (tested).
34. **One-tailed p values** are t-distribution tails with the residual df, for both the
    conventional and HC3 t.

Influence diagnostic

35. Runs only for the spec of type `origin`. The design matrix is the one actually estimated for
    the base model (after its own column drops). Each row is deleted once; a dummy that becomes all
    zero is dropped and noted as `dropped: IND_xx (all zero)`. If a refit drops one of the reported
    terms, that term is written with `NA` values and the note `term dropped in refit`. A failed refit
    is written as one row with `term = NA`, `status = failed` and the reason. If the base model itself
    failed, one failed row is written for the model.

Outputs

36. `samples.csv` has one set per family with `model_id = "ALL"` under case_scope L0 and one set
    per model under L1.
37. `run_info.json` lists specs run in order, per-model failures (`model_id`), whole-spec failures
    (`model_id = null`), and influence refit failures aggregated per model.

## Nothing left unimplemented

Every rule of the specification is implemented. No specification was added, removed or tuned.

## Test results

`code/dev_out/test_results.txt`, R 4.6.1:

| File | Passed | Failed |
|---|---|---|
| test_ols.R | 41 | 0 |
| test_coding.R | 105 | 0 |
| test_loo.R | 10 | 0 |
| test_spec_invariances.R | 37 | 0 |
| **Total** | **193** | **0** |

Highlights: estimates, SE, t, p, R2, adjusted R2, overall F match `lm`; HC3 matches
`sandwich::vcovHC` and the explicit formula; nested F matches `anova`; all of these also under
WLS; leave-one-out estimates, SE and p match explicit `lm` refits for every deletion; the CHK_
specs reproduce the expected invariances (HRM estimates invariant to the omitted industry group,
VHIER estimate scaled by ln 10 with invariant t, PCTMGR estimate scaled by 100 with invariant t);
centering L1 leaves the interaction estimates, R2 and nested F unchanged.

## Full grid on the synthetic data

`code/dev_out/full_run/` was produced from `data/survey.csv` (727 rows, every column independently
permuted). Results are meaningless and were not interpreted. Structure:

- 38 specs run in `compute_order`; 912 model rows (24 per spec); 304 nested-test rows (8 per spec);
  63,271 coefficient rows; influence rows for all 8 origin models with every record deleted once
  (358 deletions per organizational model, 243 per market model), no refit failures.
- 888 models ok, 24 failed: all of spec D05 (`item_rule` L1). On the permuted file the routing
  between V17 and the decision items is broken, so DECENT is valid on only 7 rows when all eight
  items are required, and the common complete-case samples are empty. Each model is recorded as
  `failed` with reason `n (0) <= number of parameters (1)`; the failure is listed in
  `run_info.json`. This is a property of the synthetic file, not of the code (the same rule passes
  the hand-built tests).
- Column drops occur only under case_scope L1 (D04), where industry groups absent from a
  model-specific sample are dropped and recorded.
