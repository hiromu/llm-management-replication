# Reconciliation decisions v1

Inputs: readers/fable/initial_v1 (Reader A, claude-fable-5-1) and readers/astra/initial_v1 (Reader B, gpt-6-astra), both sealed and hashed before this file was written. Rules: reconciliation_rules_v1.md (frozen while both readers were still running). No empirical data were inspected except to confirm that RSSD9001 995151 carries the name of the bank both readers named as the deleted outlier (an identifier lookup, not a result). No clarification round was used.

## Initial agreement (computed before any decision; never revised)

From initial_agreement.json and agreement_ledger.csv:

| Decision type | Matched | Agree | Raw agreement | Gwet AC1 |
| --- | --- | --- | --- | --- |
| Claim tier (5 categories) | 17 | 14 | 0.824 | 0.781 |
| Claim direction | 17 | 12 | 0.706 | 0.640 |
| Specification level label (4 categories) | 31 | 25 | 0.806 | 0.760 |

Unmatched: claims A-only 1 of 18, B-only 7 of 24; levels A-only 26 of 57, B-only 27 of 58.

Transcription agreement (separate measure): all 21 printed Table 2 coefficient cells agree exactly on coefficient, SE and stars (21/21); SSE (3/3), delta SSE and F values (3/3), the text-reported Model 3 without first-order term coefficient and SSE, condition number 35, studentized deleted residual 21.8, Durbin h bound 1.28, condition numbers > 234, N = 960 and 159 banks agree. Differences were only in field placement (stars for F tests stored under different keys).

## Claim map

- Agreed tiers: H1, H2, H3 focal; four controls nuisance; collinearity robustness model; Durbin h, heteroscedasticity and outlier diagnostics; Table 1 and sample description descriptive.
- Tier disagreements (retained, both recorded): the M2-vs-M1 and M3-vs-M1/M2 F tests (A focal, B identification diagnostic); Table 1 SD/SD^2 correlation (A diagnostic, B descriptive). Coordinator use: the F tests are scored as identification/inference diagnostics attached to H2 and H3 (the focal targets are the coefficients); both tier readings are reported.
- Union: A's turning-point claim (C3c) and B's collinearity-judgement claim (C14), theory-interpretation claim (C19), future-research conjectures (C20-C23, no empirical target) and measurement-validity claim (C24) are retained as claim records; C20-C24 have no testable target.

## Specification space

Retained agreements and the union of structures in grid_v1.json (26 axes). Decisions:

1. Origin disagreements (rules: keep both origins). O_A and O_B differ on: R02 record filter (A charter + entity type; B charter only), R05 average-asset quarter coverage (A at least two quarters with fallbacks; B all four), R14 other assets (A broad sum of remaining Schedule RC lines; B the literal other-assets line), R15 missing components (A zero when the item is not collected in the quarter; B missing stays missing), R18 deposit item (A domestic RCON2200; B consolidated RCFD2200).
2. Label disagreements became uncertain: R12 farmland (A non_equivalent, B uncertain); R17 population SD (A equivalent, B uncertain); R15 zero-if-not-collected vs B's A06_ZERO matched as the same level (A origin, B uncertain).
3. Coordinator relabelling of re-expressions: weight normalisation (R24) and centred polynomial (R26), which both or one reader called equivalent, are mathematical re-expressions and run as algebraic checks, not alternatives (project rule). B's identity-fill level (A06_IDENTITY, labelled equivalent by B) is absent in A, so under the union rule it is uncertain.
4. Single-reader non_equivalent levels are retained as non_equivalent sensitivity runs (savings banks, weighted mean ROA, no outlier deletion, all-insured deposit denominator, year/bank fixed effects, HC1, OLS, AR(1)); B's synthetic pro-forma merger level likewise.
5. Coefficient-test tail (B axis A20) is an inference rule, not a specification; moved to scoring_rules_v1.json (two-sided native p with directional p reported alongside).
6. Consequence: the substantive equivalent set is empty. Specification fragility will be reported as not assessed; uncertain-set dispersion is reported separately.

## Forensic records (sealed publication diagnostics)

A: 15 consistent, 3 not checkable (turning point in range; counts; Table 1 relative-ROA means). B: 49 consistent, 7 not checkable, 1 inconsistent beyond rounding (F_ZERO: the prose statement that strategic deviation is zero if and only if all firms have the same strategy conflicts with the printed formula, which is undefined when all firms are identical; a wording/formula issue, not a numerical mismatch). No reader found an arithmetic inconsistency among coefficients, SEs, stars, SSE and F statistics.

## Leakage controls for implementers

Implementers receive manifest_v1.md, a label-free copy of grid_v1.json, the data dictionary, source descriptions, item candidates and the derived Parquet files. Scan rules in implementation/leakage_scan.py.
