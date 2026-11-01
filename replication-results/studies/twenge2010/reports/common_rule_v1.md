# Common rule v1 (post hoc): Twenge, Campbell, Hoffman and Lance (2010)

This file rescores the study's existing estimates under one rule shared by all six studies: [scoring_rules_common_v1.json](../../scoring_rules_common_v1.json), applied by [score_common.py](../../score_common.py). The rule was written on 28 October 2026, after every study's results were known. No estimate was refitted. The study's frozen rules (sealed/scoring_rules.json) and its [replication report](replication_report.md) remain the protocol outcome.

## Outcome

| Level | Study rule (frozen) | Common rule | Lenient variant |
|---|---|---|---|
| Paper | indeterminate | not reproduced (unverified) | indeterminate |

A candidate is unverified: no study had an adversarial review from a model family independent of every implementer. "Not reproduced (unverified)" is therefore formally indeterminate.

| Claim | Common rule | Lenient |
|---|---|---|
| leisure | consistent | consistent |
| intrinsic | candidate | indeterminate |
| altruistic | indeterminate | indeterminate |
| social | consistent | consistent |
| extrinsic | consistent | consistent |

## Estimates by table

| Table | Consistent | Indeterminate | Candidate | Total | Lenient (C / I / Cand) |
|---|---|---|---|---|---|
| Table 1 | 91 | 10 | 1 | 102 | 91 / 11 / 0 |

## Focal estimates

Distance is from the published rounding interval in published-SE units.

| Claim | Term | Published | Reconstructed | Distance (SE) | Study rule | Common rule | Lenient |
|---|---|---|---|---|---|---|---|
| leisure | latent d leisure P1 | 0.35 | 0.35214257371054936 | 0 | consistent | consistent | consistent |
| leisure | latent d leisure P2 | 0.22 | 0.21537000022787423 | 0 | consistent | consistent | consistent |
| leisure | latent d leisure P3 | 0.57 | 0.570820521175637 | 0 | consistent | consistent | consistent |
| intrinsic | latent d intrinsic P1 | -0.05 | -0.06790596563430726 | 0.488 | indeterminate | indeterminate | indeterminate |
| intrinsic | latent d intrinsic P2 | -0.16 | -0.22230644340304867 | 2.01 | indeterminate | indeterminate | indeterminate |
| intrinsic | latent d intrinsic P3 | -0.2 | -0.2860704951282965 | 3.02 | indeterminate | candidate | indeterminate |
| altruistic | latent d altruistic P1 | -0.04 | 0.024600859884126056 | 2.25 | indeterminate | indeterminate | indeterminate |
| altruistic | latent d altruistic P2 | -0.06 | -0.042311519933352214 | 0.445 | consistent | consistent | consistent |
| altruistic | latent d altruistic P3 | -0.1 | -0.01876521668876733 | 2.84 | indeterminate | indeterminate | indeterminate |
| social | latent d social P1 | -0.1 | -0.11666977031720216 | 0.441 | consistent | consistent | consistent |
| social | latent d social P2 | -0.18 | -0.19973991666754337 | 0.516 | consistent | consistent | consistent |
| social | latent d social P3 | -0.28 | -0.3197298349200064 | 1.29 | consistent | consistent | consistent |
| extrinsic | latent d extrinsic P1 | 0.39 | 0.4203631293246124 | 0.95 | consistent | consistent | consistent |
| extrinsic | latent d extrinsic P2 | -0.13 | -0.1353830057881817 | 0.0134 | consistent | consistent | consistent |
| extrinsic | latent d extrinsic P3 | 0.26 | 0.28089824989892076 | 0.59 | consistent | consistent | consistent |

## Not rescored

Fit, invariance and reliability diagnostics (10 claims): 3 consistent, 5 indeterminate, 2 discrepant_provisional under the study rule. Their study-rule outcomes stand.

Every rescored term: [scoring/common_v1/terms.csv](../scoring/common_v1/terms.csv).
