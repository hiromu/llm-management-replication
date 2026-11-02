# Common rule v1 (post hoc): Thébaud (2015)

This file rescores the study's existing estimates under one rule shared by all six studies: [scoring_rules_common_v1.json](../../scoring_rules_common_v1.json), applied by [score_common.py](../../score_common.py). The rule was written on 28 October 2026, after every study's results were known. No estimate was refitted. The study's frozen rules (reconciliation/frozen/scoring_rules.json and addenda v1_1, v1_2) and its [replication report](replication_report.md) remain the protocol outcome.

## Outcome

| Level | Study rule (frozen) | Common rule | Lenient variant |
|---|---|---|---|
| Paper | indeterminate | not reproduced (unverified) | not reproduced (unverified) |

A candidate is unverified: no study had an adversarial review from a model family independent of every implementer. "Not reproduced (unverified)" is therefore formally indeterminate.

| Claim | Common rule | Lenient |
|---|---|---|
| H1 | consistent | consistent |
| H2 | candidate | candidate |
| H3 | candidate | candidate |

## Estimates by table

| Table | Consistent | Indeterminate | Candidate | Total | Lenient (C / I / Cand) |
|---|---|---|---|---|---|
| Table 1 | 43 | 6 | 10 | 59 | 43 / 7 / 9 |
| Table 2 | 40 | 73 | 27 | 140 | 92 / 27 / 21 |
| Table A3 | 58 | 11 | 12 | 81 | 61 / 11 / 9 |

## Focal estimates

Distance is from the published rounding interval in published-SE units.

| Claim | Term | Published | Reconstructed | Distance (SE) | Study rule | Common rule | Lenient |
|---|---|---|---|---|---|---|---|
| H1 | M3 female:childcare | -0.1 | -0.131 | 0.644 | consistent | consistent | consistent |
| H2 | M4 female:childcare | -0.1 | -0.0665 | 0.713 | discrepant_candidate | candidate | candidate |
| H2 | M4 female:parttime | -0.1 | -0.0472 | 1.59 | discrepant_candidate | candidate | candidate |
| H3 | M5 female:leave_sq | -0.11 | -0.00863 | 1.61 | indeterminate:incomplete_coverage | indeterminate | indeterminate |
| H3 | M5 female:leave | 0.12 | 0.0173 | 1.63 | indeterminate:incomplete_coverage | indeterminate | indeterminate |
| H3 | M6 female:leave_sq | -0.29 | 0.0131 | 2.13 | discrepant_candidate | candidate | candidate |
| H3 | M6 female:leave | 0.31 | 0.0234 | 2.01 | discrepant_candidate | candidate | candidate |
| H3 | M7 female:leave_sq | -0.58 | -0.162 | 1.72 | indeterminate:incomplete_coverage | indeterminate | consistent |
| H3 | M7 female:leave | 0.56 | -0.00627 | 2.44 | indeterminate:incomplete_coverage | indeterminate | indeterminate |
| H3 | M8 female:childcare | 0.13 | 0.0219 | 1.47 | indeterminate:grey_zone | indeterminate | indeterminate |

## Not rescored

Descriptive claims (Figures 1 to 3, Tables A1 and A2). Their study-rule outcomes stand.

Every rescored term: [scoring/common_v1/terms.csv](../scoring/common_v1/terms.csv).
