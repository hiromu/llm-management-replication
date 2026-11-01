# Reconciliation rule set, version 1

Written by the coordinator after both initial reader outputs were sealed (hashes in readers/*/initial_v1/OUTPUT_SHA256SUMS.txt) and before any empirical fitting. No data have been analysed. Reader outputs are never edited.

## Matching

- Claims are matched by content unit: the same hypothesis, outcome(s) and evidential cells (table and model columns). When one reader splits a unit that the other states once, the unit takes the tier the splitting reader gave all its parts (they were identical in every case here). Content stated by only one reader is unmatched and retained.
- Specification levels are matched when they describe the same operational choice on the same variable or sample step. Levels that differ in substance (for example, 995 as a top-coded high value versus 995 and 997 as literal counts) are not matched and are each retained.
- Transcription is compared cell by cell on Tables 3 and 4 (coefficient, SE, stars, model statistics), using D1-located entries only. D1/D2 differences are recorded separately.

## Labels

- Agreement is retained.
- A label disagreement between equivalent, non_equivalent and uncertain becomes uncertain.
- When the readers name different origins, or one names a non-executable origin ("unresolved", "unknown"), the coordinator sets a working origin by the first applicable rule: (a) the more specific documentary statement in D1; (b) if the article is silent, the reading that imposes no unobserved values (no imputation of skipped answers); (c) the reading that can be computed without depending on a later step. Every other level proposed by either reader stays an uncertain branch. These rules use no target values and no data.
- A level that is an exact algebraic re-expression (logarithm base, reference category of a full dummy set, sum versus mean of complete items, percentage versus proportion, solver choice, polarity of a dummy) is a check, not a specification alternative. It is run or derived as an algebraic check and never counted as an alternative.
- Single-reader levels keep the proposer's label unless covered by the previous rule.
- Non-equivalent levels are recorded and not executed in the grid.
- Levels that cannot be executed (no validated identifier, unshown models without printed targets) are recorded as unavailable.

## Agreement statistics

- Raw agreement and Gwet's AC1 are reported over matched units only, with denominators. Unmatched units are counted separately.
- Claim tiers use five categories (focal, identification_inference_diagnostic, robustness, descriptive, nuisance_control).
- Specification labels use four categories (origin, equivalent, non_equivalent, uncertain), where origin means the reader designated that level as origin.
- These initial-agreement figures are computed once and never revised after any clarification.
