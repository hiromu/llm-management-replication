# Technical supplement: delaney1996

This supplement indexes the frozen artifacts and records details omitted from the main report. Every path is relative to the study folder.

## Timeline and freezing order

| Step | Artifact | Frozen before |
|---|---|---|
| Package and supplement search | logs/eligibility/package_and_supplement_search.json | readers |
| Memorization probes (sealed) | sealed/memorization/ | readers |
| Publication packet v1 | readers/publication_packet.json, readers/packet_v1/PACKET_SHA256SUMS.txt | readers |
| Reader schema and assignment | readers/reader_schema_v1.md, readers/reader_assignment_v1.md | readers |
| Source validation and dictionaries | registry/, sources/reader_dictionary/, data/derived/ | readers |
| Initial reader outputs (hashed) | readers/fable/initial_v1/, readers/astra/initial_v1/ | reconciliation |
| Reconciliation rules, ledger, agreement | reconciliation/rules_v1.md, ledger_input_v1.json, initial_agreement.json | manifest |
| Decisions, implementation spec, grid | reconciliation/decisions_v1.md, implementation_spec_v1.md, grid_v1.json, grid_v1_labels_coordinator.json | implementation |
| Sealed targets | sealed/targets_frozen_v1.json (sha256 9cb9db5b...) | implementation |
| Scoring rules and scorer | checks/scoring_rules_v1.json, checks/score.py, checks/test_score.py (hashes in checks/FROZEN_SCORING_SHA256.txt) | execution |
| Spec amendment v1.1 (clarifications A1-A10) | reconciliation/spec_amendment_v1_1.md | execution (issued from synthetic-data questions only) |
| Influence-diagnostic scope | reconciliation/decisions_v1.md, implementation spec section 7 | execution |
| Frozen execution | runs/run_20261028_v1_1/ (inputs, code, sandbox profiles, outputs, hashes) | scoring |

## Grid

`reconciliation/grid_v1_labels_coordinator.json` lists every specification with its axis, level, label and basis.

| Axis | Origin (L0) | Uncertain levels |
|---|---|---|
| records | keep V3 = 0 copies | drop them |
| market_sample | V8 = 1 | publicly held |
| market_requires_pop | no | yes |
| case_scope | common complete cases | model-specific |
| item_rule | available-item mean | all items; copy rule |
| staff_coding | ln(x) | ln(1+x); 995 kept |
| z_reference | all records | organizational sample; family sample; population SD |
| train_log | log all three items | count only; none |
| no_training | missing | zero/lowest; zero count only |
| decision_map | larger org lowest | head lowest |
| union_items | V220 + V233 | + V300; + V300 + V166 |
| subsidiary | V17 | V21 = 2; V21 in {1,2,3} |
| age | ln | ln(1+age); years |
| hierarchy | ln, 100+ = 100 | 100+ missing; raw count |
| employment | full + part time | NEWTOTAL; full time only |
| pct_managers | V114 = 2 missing | V114 = 3 missing; NEWTOTAL denominator |
| competition | 1-4 | = 4 dummy; >= 3 dummy |
| neither | excluded | in omitted group |
| industry | first SIC, UNCL group | exclude ambiguous |
| weights | OLS | WLS with WEIGHT |
| centering | raw products | centered |

Algebraic checks, all confirmed exact:
- hierarchy log10: coefficient ratio 2.302585, t identical;
- percent vs proportion of managers: ratio 100;
- alternative industry reference: non-industry estimates identical to 1e-15.

N by specification (organizational / market):
- 361 / 239 at origin.
- Largest: 372 / 250 (model-specific cases).
- Smallest: 111 / 64 (all items required).
- Publicly held market sample: 69.

See data/model_stats_all_implementations.csv.

## Scoring

The rules are in checks/scoring_rules_v1.json. Cells are scored at the origin and at every fitted deviation. Inference uses one-tailed bands (.01 / .05 / .10). Magnitude is measured in published-SE units (discrepancy above 2 SE, after a ±0.0005 rounding interval). The N tolerance is 5%. The benchmark is HC3, a declared adaptation because no clusters exist. Claim and paper aggregation rules were frozen before execution.

Results:
- Outcome counts over 192 cells: 143 indeterminate, 24 descriptive only, 23 discrepant candidates, 2 not attemptable (a scorer lookup issue for the model 1/6 N cells, which should read descriptive only).
- Output: checks/score_output_run_20261028_v1_1/.
- Synthetic rule tests: 12 of 12 pass (checks/test_score.py).

Scorer-application issues found by the adversarial review (checks/audit/adversarial_v1/REVIEW.md, section 5). None changes a claim outcome. The scorer was not modified after execution.
- The N lookup for models 1 and 6.
- For printed non-significant controls, the scorer applied the either-direction rule. For two union-pressure cells this gives d = 2 instead of 0; the sign flag remains.
- The frozen outcome-precedence list and the step rules differ in order; the scorer follows the steps.
- The sign criterion fires on cells within 0.84 SE of zero. Fifteen candidates carry a sign flag of this kind, and for 12 of them it is the only flag.

## Reader reconciliation details

- Claim units: 23 (15 matched, 1 Reader A-only, 7 Reader B-only).
- Tier confusion and level-pair confusion: reconciliation/initial_agreement.json.
- Coordinator working-origin choices: reconciliation/decisions_v1.md.
- Known error: ledger pair P31 matched Reader A's A15.L0, which maps V114 = 2 to the CORE/GSS count. The executed origin instead sets V114 = 2 to missing (Reader A's A15.L1), and A15.L0 was never run. The rule that structural differences retain the union was not followed for this level. Excluding these establishments accounts for 108 records missing on percent managers, 24 of which are lost for this reason alone.

## Implementation, checking and repairs

- Pre-execution checker lists: checks/precheck/<impl>_<version>/check_output.md.
  - B v1: 1 item. A v1: 11 items. C v1: 13 items.
  - After amendment v1.1 and repairs: B v1.1 none; A v1.1 3 items, A v1.2 none; C v1.1 3 items, C v1.2 none.
- Code versions are preserved under implementation/<impl>_<version>/, with hashes.
- Two C v1.2 attempts were rejected for model substitution: implementation/C_v1_2_REJECTED_model_substitution/ and implementation/C_v1_2b_REJECTED_model_substitution/.
- The first launch of C's frozen run failed before execution (interpreter path with a flag). It is preserved as runs/run_20261028_v1_1/out_C_attempt1_launch_error/.

## Audits

- checks/audit/implementation_agreement_note_AB.md: A and B agree; the D02 flag is a formatting artifact.
- checks/audit/C_divergence/AUDIT.md: V1 = 10160 has V233 = 0. A and B follow the spec. A further reference-group difference under model-specific samples (D04) affects the intercept and industry dummies only.
- checks/audit/adversarial_v1/REVIEW.md:
  - Per-candidate verdicts: 16 overturned, 7 uncertain.
  - Missingness diagnosis: staffing 224 missing, percent managers 138, competition 113.
  - Size selection: median employment 120 in the sample against 20 excluded.
  - Exploratory post-hoc configurations, labelled as such, including X4 (N = 584 / 373).
  - Influence agreement between A and B.
  - The reviewer is the same model family as A and C.
- Human confirmation of discrepant candidates: not performed.

## Containment

- ICPSR terms: research use, no redistribution, no attempt to identify respondents.
- The release includes ZIP code and phone-prefix variables; they were not used.
- Record-level derived files are inside data/derived/, runs/ and checks/audit/ only.
- The implementer bundle used column-permuted synthetic data. Implementers never received the real records.
- Reader staging directories received no data and no codebook frequencies (leak scan: checks/leak_scan_review_v1.md).
- Remaining items for the user to delete from the session scratchpad: haven_export/haven_user_na_true.csv, haven_user_na_false.csv, codebook.txt, sec3_clean.txt.

## Calibration and validation status

These items were not performed in this single-paper session:
- planted-error and null-data arms;
- unreachable-target, post-cutoff stratum and human-reproduced comparison sets;
- human double-coding of claim maps and labels;
- human review of candidate discrepancies.

Memorization probes were performed and sealed. Both reader models recalled the data source and sample size, which is a memorization risk for the reader stage.
