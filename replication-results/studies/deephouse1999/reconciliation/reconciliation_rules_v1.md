# Reconciliation rule set v1 (frozen before either reader output was opened)

Frozen: 2026-10-27, while both initial readers were still running. Applies to readers/fable (Reader A) and readers/astra (Reader B) initial outputs.

## Matching rules
1. Claims are matched by (table, model, regressor/row term) for numerical claims, and by hypothesis label (H1, H2, H3) for hypothesis claims. Claims without a table locator are matched by DOC01 page and section plus paraphrase; unmatched claims are retained as reader-specific rows.
2. Tier agreement: exact match of the tier label on matched claims.
3. Sealed targets are matched by (table, model, row term, statistic type). Transcription agreement is exact string agreement of the printed value after removing whitespace and normalising minus signs; it is reported separately from interpretation agreement.
4. Specification axes are matched by decision content (what is open), not by axis id. Two axes match if they concern the same variable or sample step and the same choice dimension. Levels are matched by codeable rule.
5. Labels (origin, equivalent, non_equivalent, uncertain) are compared on matched levels only.

## Decisions
- Agreements are retained.
- Label disagreements on a matched level become `uncertain`.
- Structural differences (an axis, level, sample step or variable mapping present in only one reader) are retained as the union, with each reader's locator and rationale, and labelled `uncertain` unless both readers' text excludes it.
- Contradictory origin choices: the origin is the level both readers mark as origin; if they differ, both are kept as alternative origins (origin_A, origin_B) and the difference is logged; neither is privileged by any numerical information.
- Coordinator does not use any empirical result to resolve a disagreement. Clarification requests are written, logged and sent only for missing or unreadable outputs, never with the other reader's content or any result.
- If treating uncertain options as equivalent would change an eventual verdict, the claim is flagged label-sensitive and both scores are kept.

## Agreement statistics
- For each categorical decision type (tier, origin/equivalent/non_equivalent/uncertain label, direction, tail), report raw agreement counts, denominators and Gwet's AC1 with the category set used. If a denominator is below 2 or only one category is observed by both raters, report AC1 as undefined.
- Initial agreement is computed before any clarification round and is never revised.
- Transcription agreement (sealed targets) is reported as exact-match share with denominator.
