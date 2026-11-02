# Specification amendment v1.1 (pre-execution clarification)

Issued before any fit to the real data. Prompted by implementation questions raised on synthetic data, not by any result. Models, variables, axis levels and the grid are unchanged.

## A1. HC3 when some rows have leverage one

A row whose hat value is h_ii >= 1 - 1e-8 is fitted exactly, so its residual is zero by construction. Typical cause: the only member of an industry group. Its HC3 term e_i^2/(1-h_ii)^2 is then 0/0.

For every fit, conventional and influence refits alike:
- Compute HC3 with the contribution of such rows set to exactly zero. Equivalently, form the HC3 "meat" from the rows with h_ii < 1 - 1e-8 only. The bread (X'X)^-1 and every other statistic are unchanged.
- Do not report NA because such rows exist.
- Add a column `n_leverage_one` to `model_stats.csv` with the number of such rows. Use the same threshold for weighted fits, computed on the weighted design.

## A2. Declared-missing handling and spec-level top codes

When a level of the specification assigns a value to a code (V157 99996 -> 100000; V261 96 -> 100; V62/V97/V131 995 under staff_coding L2), that assignment takes precedence over any declared-missing value or range in the metadata.

## A3. CHK_hierarchy_log10

VHIER = log10 of the recoded count, i.e. ln(count)/ln(10) with 96 taken as 100. This is the log-base re-expression of the L0 variable, not a log of the logged value.

## A4. System-missing routing and identifier inputs

If V17 is system-missing:
- SUBSID is missing at every level.
- DECENT is missing.

If V43 is system-missing, the industry group is missing at every level. UNCL applies only to non-missing V43 codes with an empty crosswalk field or no crosswalk entry.

## A5. Column dropping and nested tests

Only industry dummies may be dropped, when all-zero or collinear in the estimation sample. If any other term is all-zero or collinear, the model fails with that reason; never report a reduced model as successful.

Industry collinearity is resolved before checking residual degrees of freedom. The model fails only if no positive residual df remains after the permitted drops.

Nested-test numerator df is the number of added terms: 6 for an HRM block, 3 for an interaction block. If the effective rank increase differs, record the test as failed, with the reason.

## A6. Failure records

- Record dropped-column information even when a fit later fails.
- If an influence-diagnostic original model fails, still write one influence row per estimation-sample record, with status failed and the reason.
- Failures of restricted models in nested tests are listed in run_info.json with their reasons.
- `NA` applies to CSV files; JSON may use null.

## A7. Validity used by the copy rule

A source item is "valid" for copying and for the GSS fallback only after it has passed every exclusion that applies to it at the current axis level. Examples:
- A STAFF count of 0, or a code 995-999, under staff_coding L0 is not valid. 995 is valid only under L2.
- Declared missing codes are never valid.

## A8. Reference sample under z_reference L1/L2

The reference sample is the family's complete-case sample. It is defined by the non-missingness of the outcome, the controls, the industry group and each HRM index. Non-missingness of an index depends only on which items are valid, never on standardized values, so determine the sample once from validity. Then standardize within it and do not recompute membership.

## A9. Other coding precedence

- SUBSID L1/L2: V17 == 2 gives 0, whatever V21 says.
- STAFF: codes 995 through 999 are never counts, except 995 under L2. Code 996 is missing.
- V8, V17, V43 and WEIGHT follow their metadata declarations. WEIGHT's declared missing value 0 means the row is excluded under weights L1.

## A10. Influence refits

In each deletion refit:
- Resolve industry-dummy collinearity (A5) before checking degrees of freedom.
- Add failed deletions to the failures list in run_info.json as well as to influence.csv.
