# Common rule v1 (post hoc): Holderness and Pontiff (2012)

This file rescores the study's existing estimates under one rule shared by all six studies: [scoring_rules_common_v1.json](../../scoring_rules_common_v1.json), applied by [score_common.py](../../score_common.py). The rule was written on 28 October 2026, after every study's results were known. No estimate was refitted. The study's frozen rules (sealed/scoring/scoring_rules_v1.json) and its [replication report](replication_report.md) remain the protocol outcome.

## Outcome

| Level | Study rule (frozen) | Common rule | Lenient variant |
|---|---|---|---|
| Paper | partially reproduced | consistent | consistent |

A candidate is unverified: no study had an adversarial review from a model family independent of every implementer. "Not reproduced (unverified)" is therefore formally indeterminate.

| Claim | Common rule | Lenient |
|---|---|---|
| steepness, cap | consistent | consistent |
| steepness, camp | consistent | consistent |
| sameness, cap | consistent | consistent |
| sameness, camp | consistent | consistent |

## Estimates by table

| Table | Consistent | Indeterminate | Candidate | Total | Lenient (C / I / Cand) |
|---|---|---|---|---|---|
| Table 4 | 44 | 2 | 0 | 46 | 44 / 2 / 0 |
| Table 5 | 7 | 1 | 0 | 8 | 7 / 1 / 0 |
| Table 6 | 54 | 4 | 0 | 58 | 54 / 4 / 0 |

## Focal estimates

Distance is from the published rounding interval in published-SE units.

| Claim | Term | Published | Reconstructed | Distance (SE) | Study rule | Common rule | Lenient |
|---|---|---|---|---|---|---|---|
| steepness, cap | T001 simple steepness | -0.06 | -0.0635 |  | consistent | consistent | consistent |
| steepness, cap | T003 full steepness | -0.11 | -0.103 |  | consistent | consistent | consistent |
| steepness, camp | T013 simple steepness | -0.33 | -0.369 |  | consistent | consistent | consistent |
| steepness, camp | T016 full steepness | -0.18 | -0.169 |  | consistent | consistent | consistent |
| sameness, cap | T028 simple sameness | -0.03 | -0.0221 |  | consistent | consistent | consistent |
| sameness, cap | T030 full sameness | -0.07 | -0.0691 |  | consistent | consistent | consistent |
| sameness, camp | T040 simple sameness | -0.23 | -0.242 |  | consistent | consistent | consistent |
| sameness, camp | T043 full sameness | -0.18 | -0.154 |  | consistent | consistent | consistent |

## Not rescored

Text-only robustness statements; three were not reproduced and human-confirmed under the study rule, which would make the paper partially reproduced. ROC comparisons and pseudo R2. Their study-rule outcomes stand.

Every rescored term: [scoring/common_v1/terms.csv](../scoring/common_v1/terms.csv).
