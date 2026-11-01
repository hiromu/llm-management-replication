# Reconciliation rule set v1 (frozen before reading either reader's output)

Written 2026-10-27, while both readers were running and before the coordinator had opened any reader output.

## Matching rules

1. Claims. Claims are matched by hypothesis label (H1, H2, ...) where both readers give one. Other claims are matched on the cited table/figure and model, and are matched only when they make the same directional assertion about the same estimand. A claim present in only one map is retained as unmatched (union).
2. Targets. Targets are matched on the key (table_or_figure, model label, row label, quantity), after normalising whitespace, case and dash characters. Transcription agreement compares `value_as_printed` strings exactly after the same normalisation and is reported separately from interpretive agreement.
3. Manifest items. Sample steps, variables and models are matched by role and meaning, not by name, and are recorded in a row-by-row ledger with each reader's text and source locator. A structural difference (a step, variable, model or covariance choice present in one and absent or different in the other) keeps the union and is marked as a structural disagreement, with both sources.
4. Specification axes. Axes are matched when they concern the same analytic decision. Levels are matched when they describe the same operational alternative. Unmatched axes and levels are kept (union).

## Agreement statistics (computed before any clarification round)

- Interpretive label agreement on matched items, by category: claim tier (5 categories); claim type (4); manifest certainty (3); equivalence label for matched non-origin levels (3).
- For each category: number of matched items (the denominator), raw percent agreement, and Gwet's AC1 = (pa - pe) / (1 - pe), where pe = (1/(q-1)) * sum_k pi_k (1 - pi_k), q = the number of categories, and pi_k = the mean of the two readers' marginal proportions in category k. When there are fewer than 2 matched items, or when pe = 1, AC1 is reported as undefined.
- Structural coverage: counts of items each reader has that the other lacks.
- Transcription agreement: exact-match rate on matched targets.

## Decision rules

- Agreements are retained.
- Label disagreements become `uncertain`.
- Structural differences keep the union. If the readers' origin specifications differ, both are retained as candidate origins: one is designated the primary origin by the rule below, and the other becomes an `uncertain` branch.
- Primary origin rule: where readers differ on an origin choice, the primary origin is the reading with the more explicit article basis (certainty explicit over inferred over unclear). If that ties, the coordinator records the choice and the reason, and the alternative is run as an uncertain branch. Never choose by numerical agreement; no numbers exist at this stage.
- No result-based feedback goes to readers. Clarification requests are written, sent to both readers identically, and versioned; initial agreement statistics are not changed by them.
- If treating uncertain options as equivalent could change a verdict, the item is flagged label-sensitive and both scorings are kept.
