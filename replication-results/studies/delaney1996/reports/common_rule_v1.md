# Common rule v1 (post hoc): Delaney and Huselid (1996)

This file rescores the study's existing estimates under one rule shared by all six studies: [scoring_rules_common_v1.json](../../scoring_rules_common_v1.json), applied by [score_common.py](../../score_common.py). The rule was written on 28 October 2026, after every study's results were known. No estimate was refitted. The study's frozen rules (checks/scoring_rules_v1.json) and its [replication report](replication_report.md) remain the protocol outcome.

## Outcome

| Level | Study rule (frozen) | Common rule | Lenient variant |
|---|---|---|---|
| Paper | indeterminate (sample reconstruction; label-sensitive) | indeterminate | indeterminate |

A candidate is unverified: no study had an adversarial review from a model family independent of every implementer. "Not reproduced (unverified)" is therefore formally indeterminate.

| Claim | Common rule | Lenient |
|---|---|---|
| H1 | indeterminate | indeterminate |

## Estimates by table

| Table | Consistent | Indeterminate | Candidate | Total | Lenient (C / I / Cand) |
|---|---|---|---|---|---|
| Table 3 | 0 | 77 | 0 | 77 | 46 / 31 / 0 |
| Table 4 | 0 | 73 | 0 | 73 | 47 / 26 / 0 |

## Focal estimates

Distance is from the published rounding interval in published-SE units.

| Claim | Term | Published | Reconstructed | Distance (SE) | Study rule | Common rule | Lenient |
|---|---|---|---|---|---|---|---|
| H1 | org_M2 INCENT | 0.12 | 0.0649 | 1.14 | discrepant_candidate_pending_human_review | indeterminate | indeterminate |
| H1 | org_M2 TRAIN | 0.125 | 0.239 | 2.77 | indeterminate | indeterminate | indeterminate |
| H1 | org_M3 INCENT | 0.117 | 0.0732 | 0.902 | discrepant_candidate_pending_human_review | indeterminate | indeterminate |
| H1 | org_M3 TRAIN | 0.111 | 0.234 | 3.06 | indeterminate | indeterminate | indeterminate |
| H1 | org_M3 VHIER | 0.103 | 0.107 | 0.0669 | indeterminate | indeterminate | consistent |
| H1 | mkt_M7 INCENT | 0.125 | 0.239 | 1.4 | indeterminate | indeterminate | consistent |
| H1 | mkt_M7 STAFF | 0.145 | -0.0132 | 2.77 | discrepant_candidate_pending_human_review | indeterminate | indeterminate |
| H1 | mkt_M8 INCENT | 0.134 | 0.253 | 1.47 | indeterminate | indeterminate | consistent |
| H1 | mkt_M8 STAFF | 0.147 | -0.0114 | 2.77 | discrepant_candidate_pending_human_review | indeterminate | indeterminate |
| H1 | mkt_M8 TRAIN | 0.076 | 0.211 | 2.31 | indeterminate | indeterminate | indeterminate |

## Not rescored

H2's four interaction-block F tests, which decide H2 under the study rule (all indeterminate on sample size); HRM-block F tests, R2 and N cells; descriptive Tables 1 and 2. H2 therefore has no rescored claim. Their study-rule outcomes stand.

Every rescored term: [scoring/common_v1/terms.csv](../scoring/common_v1/terms.csv).
