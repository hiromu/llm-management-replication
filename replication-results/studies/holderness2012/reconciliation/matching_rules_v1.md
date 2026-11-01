# Reconciliation matching rules, version 1

Written before either reader's outputs were opened for comparison (2026-10-27).

1. Claims. A Reader A claim and a Reader B claim match when they refer to the same published result: same table and same column(s)/model family, or, for text-only claims, the same section and the same substantive assertion (same variable, same direction, same subsample). One-to-many matches are allowed when one reader split a claim the other combined; each split claim is matched to the combined claim and recorded as a structural difference. Unmatched claims are retained (union).
2. Tier agreement. For matched claims, compare tier labels (focal, identification_inference_diagnostic, robustness, descriptive, nuisance_control). Agreement is exact label equality.
3. Focal designation. Separately compare the binary focal versus non-focal label on matched claims.
4. Specification axes. Axes match when they address the same analytic decision (same variable or sample step and same kind of choice). Levels match when they describe the same operational alternative. Label agreement is exact equality of equivalent / non_equivalent / uncertain on matched levels. Origin agreement is whether both mark the same level as origin.
5. Transcription. Targets are matched by (table, column position, row variable, quantity). Agreement is exact equality of value_as_printed after whitespace and minus-sign normalisation. Transcription agreement is reported separately from interpretive agreement.
6. Statistics. Report raw agreement counts with denominators and Gwet's AC1 for each categorical comparison (tier, focal, label, origin). If a denominator is zero, or only one category is observed so AC1 is undefined, report "undefined" rather than a value.
7. Resolution. Agreements are retained. Label disagreements become "uncertain". Structural differences retain the union with source locators. The coordinator does not use empirical results to resolve any disagreement.
