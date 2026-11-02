# Common rule v1 (post hoc): Lehman, Hahn, Ramanujam and Alge (2011)

This file rescores the study's existing estimates under one rule shared by all six studies: [scoring_rules_common_v1.json](../../scoring_rules_common_v1.json), applied by [score_common.py](../../score_common.py). The rule was written on 28 October 2026, after every study's results were known. No estimate was refitted. The study's frozen rules (reconciliation/scoring_rules_v1.json) and its [replication report](replication_report.md) remain the protocol outcome.

## Outcome

| Level | Study rule (frozen) | Common rule | Lenient variant |
|---|---|---|---|
| Paper | consistent (comparability mapping: partially reproduced) | partially reproduced | partially reproduced |

A candidate is unverified: no study had an adversarial review from a model family independent of every implementer. "Not reproduced (unverified)" is therefore formally indeterminate.

| Claim | Common rule | Lenient |
|---|---|---|
| H1B | consistent | consistent |
| H1A | consistent | consistent |
| H3 | consistent | consistent |
| H2 | consistent | consistent |

## Estimates by table

| Table | Consistent | Indeterminate | Candidate | Total | Lenient (C / I / Cand) |
|---|---|---|---|---|---|
| Table 5 | 28 | 7 | 0 | 35 | 32 / 3 / 0 |
| Table 6 | 6 | 12 | 17 | 35 | 7 / 14 / 14 |

## Focal estimates

Distance is from the published rounding interval in published-SE units.

| Claim | Term | Published | Reconstructed | Distance (SE) | Study rule | Common rule | Lenient |
|---|---|---|---|---|---|---|---|
| H1B | T5|M2|perf_above | 0.994 | -0.0076 | 0.143 | consistent | consistent | consistent |
| H1A | T5|M2|perf_below | 0.883 | -0.122 | 0.199 | consistent | consistent | consistent |
| H1A | T5|M2|perf_below_sq | 0.999 | -0.00116 | 0 | consistent | consistent | consistent |
| H3 | T5|M3|perf_above_x_min | 0.998 | -0.00213 | 0 | consistent | consistent | consistent |
| H2 | T5|M3|perf_below_sq_x_min | 1 | 0.000232 | 0 | consistent | consistent | consistent |
| H2 | T5|M3|perf_below_x_min | 1.01 | 0.0109 | 0 | consistent | consistent | consistent |

## Not rescored

Publication diagnostics. Their study-rule outcomes stand.

Every rescored term: [scoring/common_v1/terms.csv](../scoring/common_v1/terms.csv).
