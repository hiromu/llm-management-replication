All manifest analyses are implemented. The script embeds the supplied 1,295-row grid unchanged in content and needs only the data directory at runtime.

Conventions where the manifest leaves details unspecified:

- Blank `R` uses the universe reference (`R1`), including AN13. `R2` ranks distinct counties with complete model variables after the sample and address-outcome restrictions; these groups are recomputed in each influence refit. Universe-based groups and placebo assignments stay fixed.
- `k_slopes` is the rank of estimable slopes after absorption. HC1 counts that rank plus the rank of the entire fixed-effect space, including the intercept. Redundant nuisance terms are handled by a generalized inverse; an unidentified focal coefficient fails the row. Fixed-effect singletons are retained.
- `r2` is the overall, centered R-squared including fixed effects. Confidence intervals use cluster inference except AN12, which uses HC1. `n_dropped_missing` counts incomplete/nonfinite model observations after structural restrictions; explicit address-outcome exclusions are separately logged.
- Quarterly exclusion reasons can overlap. The preparation log gives both overlapping counts and disjoint sequential removals. Sums skip missing values but remain missing when all values are missing.
- Descriptive specifications have status/variable rows in `results.csv`; their requested statistics are in the named auxiliary files. AN10 cumulative means use untransformed cumulative counts.
- Influence results are in `influence.csv`, with the baseline fit in `results.csv`. The focal term is the first reported term: treatment for address regressions, and the 2005 interaction for event studies. The manifest does not specify a focal term for multi-term models. Influence mode requires a regression specification; empty auxiliary files retain headers.

Validation: the full synthetic grid completed successfully in about 14 seconds. S00008 completed all 336 county deletions successfully. Eight numerical checks against explicit dummy-variable OLS verified coefficients, CR1, HC1 and parameter counts, including density-by-quarter effects, event studies and missing observations. Grid identity, output coverage, sample hashes, panel balancing, nearest-year controls and placebo vectors were also checked.
