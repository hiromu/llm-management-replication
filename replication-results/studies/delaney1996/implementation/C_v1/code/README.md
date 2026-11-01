# PAPER_K7 grid implementation (specification v1, frozen)

Python implementation of `implementation_spec.md` for every specification in `grid_v1.json`.
Pure numpy/pandas/scipy; statsmodels is used only in the tests as a reference.

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
Progress is printed to stdout. The full grid on the 727-row development file takes about 30 s.

Layout:

- `code/run_grid.py`: command line entry point and output writing.
- `code/paperk7/coding.py`: missing codes, items, indices, copy rule, standard scores, controls, industry.
- `code/paperk7/pipeline.py`: samples, designs, models, nested tests, influence diagnostic.
- `code/paperk7/regression.py`: OLS/WLS, conventional and HC3 SE, one-tailed p, nested F, dummy dropping.
- `code/tests/`: unit tests (see below).
- `code/dev_out/full_grid/`: outputs of the full grid on the synthetic development file (meaningless results).

Tests are plain `unittest` files and must be run as scripts (the directory name `code` shadows the
standard library module `code`, so `python -m unittest code/tests/...` does not resolve):

```
~/.venv/bin/python code/tests/test_regression.py
~/.venv/bin/python code/tests/test_coding.py
~/.venv/bin/python code/tests/test_influence.py
~/.venv/bin/python code/tests/test_pipeline_checks.py
```

## What could not be implemented as written

**HC3 standard errors when an observation has leverage 1.** An industry group with a single
member in the estimation sample gives that row leverage exactly 1 and residual exactly 0, so the
HC3 term e^2/(1-h)^2 is 0/0 and the HC3 covariance is undefined. R (`lm.influence` snaps such hat
values to 1; `sandwich::vcovHC(type="HC3")` then returns NaN) reports NaN; statsmodels returns
numerical noise because it does not snap. This implementation follows R: leverage within 1e-8 of 1
is treated as 1 and all HC3 columns of that model are `NA`. Conventional SEs are unaffected.
Affected models are listed in `run_info.json` under `hc3_undefined` (spec, model, number of
leverage-1 rows). On the synthetic file every model is affected because the permuted V43 scatters
rows over many single-member groups; on the real file this will happen for any model whose sample
contains a single-member group. No alternative convention (e.g. dropping those rows' contributions)
was invented; that is a decision for the spec owner.

Everything else in the specification is implemented.

## Interpretations where the spec was not explicit

Inputs and codes

1. The metadata file is a list of variable records; `declared_missing_values` (and
   `declared_missing_ranges`, none of which occur on the variables used) are applied to every
   variable read, except where the spec overrides them (STAFF items, see 6).
2. The crosswalk lists several groups separated by semicolons (e.g. `11;12`), not commas as the spec
   says. Both separators are accepted. `census1980_code` is matched to V43 as an integer (leading
   zeros ignored). Group labels keep the two-digit string of the crosswalk (`07`, dummy `IND_07`);
   the unclassified group is `UNCL` with dummy `IND_UNCL`.
3. V43 values absent from the crosswalk (two codes in the development file) are `UNCL` under
   industry L0 and missing under L1, as for an empty field.
4. Ordering of group codes for tie breaks is numeric; `UNCL` sorts after every numeric code, so
   "lowest code" never picks UNCL over a numeric code and "highest code" (CHK_industry_ref_alt)
   prefers UNCL in a tie.
5. "System-missing" (copy rule) means a blank cell in the raw file. User-missing codes 8/9 on V79 or
   V114 are not system-missing and do not trigger the copy.
6. STAFF items: 997, 998, 999 are always missing; 995 is missing under staff_coding L0/L1 and kept
   as 995 under L2 even though the metadata declares it missing. Under L0 and L2 a count of 0 is
   missing through the x >= 1 rule; under L1 it gives ln(1) = 0.
7. V157 = 99996 is set to 100000 before the log; V261 = 96 is set to 100 (hierarchy L0/L2) or
   missing (L1).

Indices and the copy rule

8. "Valid" in the copy rule means not missing after applying the item's missing codes (item 6 for
   STAFF items; 8/9 for ILM items; 7/8/9 for V222). V79 == 2 copies unconditionally, so a missing
   CORE item makes the GSS item missing. For V79 blank the copy happens only when the CORE item is
   valid, per item.
9. The manager copy is applied after the GSS copy and uses the post-copy GSS values as fallback.
   For V114 == 2 or V114 blank it is applied with no further condition, as written.
10. The copy rule only runs under item_rule L2. Under L2 all indices use the L0 averaging rule.
11. The no_training rule applies to every row with V145 == 2, whatever V157/V172 contain (in the
    real file they are skipped). Rows with V145 8/9 or blank keep their own V157/V172 coding and
    have a missing V145 item.
12. train_log L0 logs the recoded V145 (2 -> ln 2, 1 -> 0) and the reversed V172 (1..3). Under
    train_log L1 and L2 the V157 rule still follows the no_training level (ln x with 0 missing under
    no_training L0; ln(1+x) under L1/L2), and L2 uses the raw count.
13. DECENT: rows with V17 missing have all eight decision items missing. Codes 6, 7, 8, 9 are
    missing under both maps.
14. CHK_hierarchy_log10 is log10 of the hierarchy count (V261 with 96 as 100), i.e. the base-10
    version of the L0 variable, not log10 of ln(V261). CHK_pct_proportion divides PCTMGR by 100.

Standard scores

15. The reference set for z_reference L0/L3 is the record frame after the `records` axis. L0 uses
    the sample SD (n-1), L3 the population SD (n). A reference set with fewer than two valid values
    or zero SD makes the item missing.
16. Under L1 and L2 the reference sample is the family's common complete-case sample as defined for
    case_scope L0 (outcome, all seven HRM indices, controls, industry, and WEIGHT under weights L1),
    found with the L0 scores. Rows outside the reference keep the L0 scores. The sample is
    re-derived after re-standardization; a note is written to `run_info.json` if membership changes
    (it does not on the development file). The grid never combines z_reference L1/L2 with
    case_scope L1; if it did, the same common sample would be used as reference.
17. Under L1 the market family receives exactly the org-sample scores; under L2 each family is
    standardized within its own common sample.

Controls

18. Binary recodes written as "X gives 1, else 0" give missing when the source is missing (SUBSID
    L0 with V17 blank; COMPET L1/L2 with V328 missing; NONPROF with V8 blank).
19. SUBSID L1/L2: V17 == 2 gives 0 whatever V21 holds; V17 == 1 with V21 8/9 or blank is missing;
    V21 = 7 "something else" gives 0; L2 additionally gives 1 for V21 in {1, 2, 3}.
20. LOGEMP L0: either component 99998/99999 makes the sum missing; a sum of 0 is missing by the log
    rule. NEWTOTAL has no declared missing codes; values <= 0 are missing after the log.
21. PCTMGR: the numerator is missing for V114 in {2, 8, 9, blank} and for V115 99998/99999; the
    denominator (V23+V32, or NEWTOTAL under L2) missing or 0 gives missing.
22. UNION: V166 "yes gives 3, no gives 1" is taken as the final item value (not reversed again);
    V220/V233/V300 are reversed 4-x; code 7 on V233/V300 is missing (declared). The index obeys
    item_rule (L1 requires every listed item).
23. PRODUCT/SERVICE: V41 8/9 or blank gives missing on both; V41 = 4 follows the `neither` axis.

Samples and models

24. WEIGHT (declared missing 0) is required to be valid and > 0 under weights L1; under case_scope
    L0 this is part of the family's common sample so that all models of the family share one
    sample. Under weights L0 WEIGHT is ignored.
25. market_sample L1 uses V9 == 4 after V9's missing codes (8/9 excluded).
26. Industry reference group: under case_scope L0 it is chosen once from the family sample; under
    L1 from each model's own rows. Dummies are created for the groups present in those rows.
27. Dummy dropping: all-zero dummy columns are dropped first, then dummies that do not increase the
    rank are dropped in column (code) order. Only industry dummies are ever dropped; collinearity
    among the other columns fails the model with a reason. Drops are listed in `dropped_columns`
    as `IND_xx(all_zero)` / `IND_xx(collinear)`.
28. Nested tests: the restricted model is the full model's design without the added columns, on the
    full model's rows (identical to the reported restricted model under case_scope L0), re-checked
    for dummy collinearity. df1 is the number of added terms, df2 the full model's residual df; F
    is computed from the (weighted) SSRs, which equals the delta-R2 form because both models share
    the same (weighted) total sum of squares.
29. Overall F tests all slopes including dummies against the intercept-only model; adjusted R2 is
    the usual 1-(1-R2)(n-1)/(n-k). For WLS, R2 uses the weighted centred total sum of squares
    (statsmodels/R convention).
30. Centering L1 uses the means of each interaction component over the model's own estimation
    sample; main effects stay uncentered. Centering means are stored per model and held fixed in
    the influence diagnostic (none exist for the origin spec, which has centering L0).
31. Design column order: (Intercept), HRM terms, interactions, controls, industry dummies.

Influence diagnostic

32. One row per deletion and per HRM/interaction term. If a deletion makes a dummy all zero the
    column is dropped and the note says which; if the reduced design is still rank deficient,
    collinear dummies are dropped and noted; any other failure gives `status = failed` rows (one per
    term) with the reason in `note`. All variable values, standard scores and dummy sets are those of
    the origin fit; nothing is recomputed from the data. Refits are explicit (no closed-form update).

Outputs

33. `samples.csv` lists one set per family with `model_id = ALL` under case_scope L0 and one set
    per model under L1 (nested-test rows are the full model's rows and are not listed separately).
34. `NA` is written for every missing value, including `error` for ok models and `dropped_columns`
    when nothing was dropped. `run_info.json` also stores the z-score reference moments per spec
    and family.
35. A model fails (status `failed`, reason in `error`, no coefficient rows) when its sample is empty,
    has no residual df, or has non-dummy collinearity. On the synthetic file spec D05 (item_rule L1)
    has empty samples in both families because the independently permuted columns break the skip
    patterns (for example DECENT needs all eight decision items valid, which only 7 rows satisfy).
    This is a data artefact, recorded in `run_info.json` as 32 failures (24 models + 8 nested tests).

## Test results

All tests pass (run on 2026-10-28 with Python 3.13.4, numpy 2.4.2, pandas 2.2.3, scipy 1.16.3,
statsmodels 0.14.6 as reference).

| File | Tests | Covers |
|---|---|---|
| `test_regression.py` | 11 | OLS exact recovery of a known structure; OLS and WLS estimates, conventional SE, t, p, df, R2, adjusted R2, overall F against statsmodels; HC3 against statsmodels and against the explicit formula (unweighted and weighted design); one-tailed p (upper + lower = 1, two-sided = 2 min, direction); nested F and delta R2 against `compare_f_test` (OLS and WLS); leverage-1 gives NA HC3; rank deficiency and no-df errors; all-zero / collinear dummy dropping. |
| `test_coding.py` | 26 | Declared missing values and ranges; reversal; index rules L0/L1/L2; log of non-positive values; z-scores (n-1, n, reference subset, rows outside keep L0 values, constant reference); POP/PMP; STAFF coding L0/L1/L2 with 0/995/997/998/999; TRAIN under every no_training and train_log level incl. 99996 and V172 = 4; INCENT, GRIEV, ILM; DECENT routing by V17, both decision maps, code 6; VHIER L0/L1/L2 and the log10 check; GSS and manager copy rules incl. system-missing vs user-missing and copy order; NONPROF, SUBSID L0/L1/L2, LOGEMP L0/L1/L2, LOGAGE L0/L1/L2, PCTMGR L0/L1/L2 and the proportion check, UNION L0/L1/L2 incl. V166 and code 7, PRODUCT/SERVICE with neither L0/L1, COMPET L0/L1/L2; crosswalk parsing (comma, semicolon, empty), industry L0/L1, UNCL, reference group selection (largest/lowest, smallest/highest, UNCL ordering), dummies; records L1; market sample and requires_pop filters; required variable lists; standardization inside the frame builder (L0 vs L3). |
| `test_influence.py` | 4 | Leave-one-out estimates, SE, two-sided and upper-tail p equal explicit statsmodels refits for every deletion (OLS and WLS); deletion of a single-member group drops and flags the dummy; refit failures are retained with the reason; the design is not modified and the OLS result equals the closed-form DFBETA update. |
| `test_pipeline_checks.py` | 6 | On the synthetic file: common sample equals the complete-case rows and every model of a family uses it; nested F for the origin equals statsmodels on the actual designs; CHK specs are invariant (log10: identical t and R2, VHIER slopes scaled by ln 10; proportion: PCTMGR slope x100, same t; alternative reference group: identical non-industry slopes and SEs, different dummy set); case_scope L1 model-specific rows and WLS against statsmodels; centering changes only interaction columns and leaves R2 unchanged; z_reference L1/L2/L3 behaviour. |

Full grid on `data/survey.csv` (`code/dev_out/full_grid/`, log in `code/dev_out/full_grid_log.txt`):
38 specs run, 24 models per spec, all six output files written, 32 recorded failures (all from D05,
see item 35), influence rows for all eight models of the origin spec (one per deletion and term).
Results on the synthetic file are meaningless and were not interpreted.
