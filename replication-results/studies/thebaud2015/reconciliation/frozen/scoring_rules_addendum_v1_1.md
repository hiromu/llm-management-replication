# Scoring rules addendum v1.1

Written after the scorer code was exercised on synthetic results and before any real-data result was read. Synthetic results carry no information about real outcomes.

1. Order of the per-term rule. An N mismatch (relative difference above 0.15) takes precedence over an out-of-tolerance criterion. The term is then indeterminate:incomplete_coverage, not discrepant_candidate, because a sample that was not reconstructed cannot support a discrepancy. The claim precedence becomes: not_attemptable, indeterminate:implementation_disagreement, indeterminate:implementation_failure, indeterminate:incomplete_coverage, discrepant_candidate, other indeterminate sub-codes, fragile_inference, consistent.
2. Sample identity for implementation pairs that include B uses equal n_obs, n_countries and n_surveys, because B hashes string-sorted IDs. This was decided on synthetic output.
3. For M5, benchmark inference uses the wild cluster bootstrap p for the F x X terms and the CR1 p otherwise.
