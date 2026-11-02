# Technical supplement: nagaraj2021

Public distribution copy: omitted data, source documents, row-level outputs and private logs are documented in ../README.md. Original run hashes remain historical evidence; export hashes are in ../export_manifest.json.

Companion to reports/replication_report.md. All paths are relative to the study folder. No human reviewed any step.

## 1. Provenance and inputs

- Deposit: OSF node a47e9, 60 files. All matched the OSF SHA-256 at setup and again before and after unsealing (logs/osf_receipt.json; logs/deposit_validation_pre.json, deposit_validation_pre_unseal.json, deposit_validation_post_unseal.json). License: CC-BY 4.0 per the OSF API. TIGER/Line 2010 county file: logs/tiger_receipt.json.
- Registry: registry/data_registry.json (definitions, formats, coverage; no summary statistics). The implementer copy (manifest/data_registry_impl_v1.json) removes deposit identity and unused files.
- Format facts found during registry building: quarterly.csv repeats its header 3,111 times (once per county block) and has 2 malformed rows with an empty quarter. 2005q1 and 2005q3 never occur. Counties have 3-36 quarter rows. FIPS is stored as text in timing.xlsx. The ACS deposit covers 2005-2011, and its 2011 rows lack median earnings for 671 counties.
- Implementer bundle: data/derived/bundle_v1 (logs/bundle_v1_record.json). h12.csv column 3 (user names) became U<n> codes and osm-events.csv field_3 (free text) became E<n> codes. Both mappings are one-to-one, no mapping was stored, and no rows were filtered. A first build recoded the wrong osm-events column. It was never used and is kept as data/derived/bundle_v0_failed_do_not_use with its record, because deleting it was not permitted. Its content equals data/raw.
- Loader equivalence, R against Python: every file has identical rows, columns and cell text. Two noted differences: R strips the leading space of one header, and the Excel FIPS stored as text loads as text in R and as integers in Python, numerically identical (logs/loader_check_compare.json).
- Run input: data/derived/run_input_v1 (the six used files plus placebo_draws.csv, built from county keys only).

## 2. Publication packet and readers

- Packet: packet/frozen_v1, 20 files (packet/publication_packet.json): D01 article, D02 appendix (deposit copy), D03 deposit data notes, D41-D54 column names and types, D60 TIGER fields. Built by code/build_reader_packet.py, adopted unchanged from setup_drafts.
- Prompts: prompts_frozen/reader_prompt_v1.md (the draft plus explicit null handling, a fixed rule for plot readings, and the workflow reader-stage section verbatim) and prompts_frozen/probe_prompt.txt (unchanged). Hashes: logs/reader_freeze_sha256.txt.
- Runs: reader_opus 323 s; reader_astra 171 s. Both inputs were byte-identical (verified by hash). First complete outputs are in readers/*/initial_v1, hashed in readers/*/initial_v1_sha256.txt, and work files are in staging_extras. No clarification round was used.
- Probes: both ran before the readers and were sealed until after them (checks/memorization_probes.md).

## 3. Reconciliation (reconciliation/)

- Claim ledger: 84 units (each Table 1-2 row, each regression column in Tables 3-7 with Table 6 split into Treat and Distance, and each figure panel or series). Text-summary claims are kept as structural extras. Rule set: code/reconcile_tiers.py.
- Initial tier agreement: 76 of 84, AC1 0.883 (agreement_initial.json). The 8 disagreements, all made uncertain: Table 6 columns 2-3 (robustness vs focal), Figure 1(a) and Figure 2(a)-(b) (descriptive vs diagnostic) and Figure 6 (descriptive vs robustness).
- Specification axes: 21 from Opus and 13 from Astra. 15 matched level pairs, with 8 equal labels (AC1 0.310). Unequal labels became uncertain, and single-reader levels were kept with their label (axis_ledger_v1.json).
- Transcription agreement: 164 of 164 regression fields. Tables 1-2 differ only in where text-stated percentages were filed (transcription_agreement_initial.json).
- Coordinator fallbacks, flagged as such: control transformation (levels or ln(1+x)), cross-section control year (2011, 2008 or the 2005-2011 mean), panel control years (nearest available year, years after 2011 carry 2011), distance unit (km; miles as an algebraic rescale) and event-study reference year (2007). The panel rule handles missing years but not missing values. That is the source of the controlled-model sample loss reported in comparison 3.
- Paper-focal designation (from the abstract): T3 (3)-(6), T4 (3)-(6), T6 (1).

## 4. Frozen grid and labels

manifest/grid_v1.csv was built by code/make_grid.py and frozen before execution (logs/freeze_impl_inputs_v1.json).

| Stage | Rows | Content |
| --- | --- | --- |
| 1 origin | 112 | every analysis at origin levels F1 D1 O1 G1 L1 Y1 Q1 R1 B1 W1 |
| 2 deviation | 530 | one axis changed at a time |
| 3 crossing | 253 | full crossing of applicable uncertain axes for the nine paper-focal models |
| 4 placebo distribution | 400 | permutation seeds 1-200 for follow-on and contributors |

Axes:
- F (follow-on construction: a+b+h, v2 fields, version fields, all six)
- D (distant: buildings, or plus amenities)
- O (low ownership: focused5 - focused1, or focused5)
- G (log transform: ln(Y+1), or add one only to zeros)
- L (control transformation)
- Y (cross-section control year)
- Q (quartile variables: density, or population)
- R (quartile reference set: universe, or subsample)
- B (boundary rule: symmetric, or treated-only)
- W (Table 6 outcome: ln|d|, ln(|d|+1), or |ln OSRM - ln Google|)
- Table 5 Panel A controls (with, or without)
- Figure 6(a) estimator (panel DiD, or cross-section)

Every non-origin level is uncertain; there are no equivalent alternatives.

Not run, with reasons:
- Non-equivalent: smaller universe (U2), unfilled panel (Z2), Post from 2007q4 (P2), group linear trends (T2), county-mean error (W2), density-only quartile effects (Q3).
- Unavailable: period-distinct contributors (C2) and 2009-2014 ACS (V2), because the deposit cannot support them.
- Not implementable in all three languages: geometric adjacency (B3), because sf is missing in R.
- Infeasible: SB Selected date (S2), because the column is a one-letter code.
- Needs contributor-level data: disjoint percentile groups.

## 5. Implementations, checks and execution

- Manifest: manifest/implementation_manifest_v1.md, target-free and identity-free.
- Leakage scan: logs/leakage_scan_v1.json. Final scan found 0 identity hits; the first pass found 11 in registry notes, which were rewritten. 428 numeric hits were reviewed as false positives: random synthetic numbers and placebo seed 171.
- Prompt: prompts_frozen/implementer_prompt_v1_{A,B,C}.md.
- Development data: data/synthetic_v1 (code/make_synthetic.py; planted effects; real formats including the irregular lines).
- Implementer runs (logs/roles/impl_*.json):

  | Implementation | Model | Language | Time | Cost |
  | --- | --- | --- | --- | --- |
  | A | Opus 5.5 fast, reported "fast" | R | 337 s | $4.16 |
  | B | Astra, tier not reported | R | 216 s | not reported |
  | C | Astra, tier not reported | Python | 94 s | not reported |

  Code and synthetic outputs are in implementation/*/v1.
- Synthetic agreement: 1,385 of 1,389 regression rows agreed across all three, with A-B agreement on all 1,389. The 4 exceptions are the R2 reference set, where C restricts to complete cases. Descriptive outputs had 0 numeric differences (checks/synthetic_v1).
- Pre-execution checkers (cross-family; checks/pre_execution): 6 items on A, 2 on B, 0 on C. None affected the frozen run (disposition_v1.md). No code was changed after checking.
- Execution: runs/run_20261101_v1 (code, grid, input hashes, outputs_sha256.txt). The three implementations ran concurrently under sandbox-exec with network denied: 148 s, 211 s and 211 s, and 0 failed rows. Outputs could not be set read-only (the command was denied), so immutability rests on hashes.
- Influence: runs/run_20261101_v1/influence. A ran every deletion and C repeated every deletion: 22,409 refits each, 0 failures, 22,409 of 22,409 in agreement (A_vs_C_agreement.csv). The plan specified C on a 50-county subset per model; C ran all of them, and agreement is reported for both the declared subset (450 of 450) and the full set.

## 6. Scoring

- Rules: scoring/scoring_rules_v1.json; claims: scoring/claims_v1.json; sealed targets: sealed/targets/targets_v1.json. All were frozen and hashed before execution (logs/freeze_scoring_v1.json).
- Scorer: code/score.py. Step 1 compares implementations without targets; step 2 scores claims.
- Constants (provisional, uncalibrated):

  | Criterion | Rule |
  | --- | --- |
  | Implementation agreement | equal N and sample hash, estimate difference <= 0.001 SE, SEs within 0.5% |
  | Magnitude, in published-SE units from the rounding interval | match <= 0.5, grey <= 2, mismatch > 2 |
  | Inference bands | < .01, < .05, < .10, >= .10 |
  | Discrepancy | fails at origin and at every uncertain row |
  | Descriptive rows | relative deviation 1% (near) and 10% (mismatch) |
  | Plot readings | point within the reading interval widened by half its width; series consistent at >= 80% of points; never discrepant |
  | Paper level | any indeterminate focal claim makes the paper indeterminate |

- Revision: scorer v1.1 was produced before unsealing. It implements the frozen inconsistent-targets sub-code and the Table 5 label-swap diagnostic, both of which v1 had omitted; the omission was noticed after the first scoring run. v1 and its output are kept (code/score_v1.py; runs/run_20261101_v1/scoring_v1). No outcome category changed.
- Review application: code/apply_review.py writes scoring/final_outcomes.json and final_summary.json.

Label sensitivity of the paper-focal claims (uncertain rows; share keeping the published sign with benchmark p < .05):

| Claim | Uncertain rows | Pass all criteria | Share sign and p < .05 | Median | Range |
| --- | --- | --- | --- | --- | --- |
| T3 (3) | 7 | 5 | 1.00 | -0.118 | -0.407 to -0.111 |
| T3 (4) | 15 | 5 | 0.60 | -0.093 | -0.374 to -0.073 |
| T3 (5) | 1 | 1 | 1.00 | -0.046 | single row |
| T3 (6) | 3 | 2 | 0.67 | -0.036 | -0.039 to -0.031 |
| T4 (3) | 95 | 56 | 0.84 | -0.200 | -0.743 to -0.046 |
| T4 (4) | 95 | 68 | 1.00 | -0.393 | -1.016 to -0.258 |
| T4 (5) | 23 | 17 | 1.00 | -0.097 | -0.131 to -0.078 |
| T4 (6) | 23 | 7 | 1.00 | -0.237 | -0.292 to -0.221 |
| T6 (1) Treat | 35 | 0 | 0.00 (sign never positive) | -0.071 | -0.109 to -0.001 |

The wide ranges for T3 (3)-(4) and T4 (3)-(4) come from the F3 reading (version-count fields as follow-on).

## 7. Adversarial review (audit/adversarial_v1)

A coordinator subagent (Claude Opus 5.5, the same family as implementation A and Reader A) reviewed the 20 discrepancy candidates before unsealing, without reading the author package, with network denied and with independent reruns. Verdicts:

| Candidates | Verdict | Reason |
| --- | --- | --- |
| The six Table 1 control-change rows | overturned | source vintage (deposit ends in 2011) |
| Table 2 low and high ownership | overturned | inconsistent targets (labels opposite to Table 7; Massachusetts included) |
| Figure 1(a) and Figure 2(a) counts | overturned | inconsistent targets |
| Table 5 Panel A columns 6-7 | overturned | inconsistent targets (heading order contradicts the N row) |
| Table 5 Panel A column 8, Figure 2(b), all six Table 6 terms | survives | |

The coordinator independently checked three pieces of evidence: Massachusetts carries treat = 1 in the deposit, the Table 2 high-ownership maximum lies in a Massachusetts county, and the raw Table 6 contrast is negative with or without Massachusetts. Unsealing later confirmed the review's reading of the Table 5 column order and the label swap. Limitation: no family-independent reviewer, so the discrepancies are reported as not fully verified.

## 8. Unsealing and post-unsealing work

- Unsealed at the time in logs/unsealed_utc.txt, after logs/pre_unseal_hashes.json (391 files).
- Comparisons 2 and 3: post_unseal/comparisons_2_and_3.md.
- One-at-a-time diagnostics: code/post_unseal_variants.py and post_unseal/diagnostics/* (variants D01, D02, D03, D04, D06, D08 and cumulative D10 of frozen implementation A, run with network denied); tables in post_unseal/diagnostics/variant_table.csv. These are labelled diagnostics and revise nothing.
- Setup exposure note: opened with the package. It records that an earlier session believed follow-on = taga + tagb + tagh in merge_covar.ado; the code confirms this. The note was not passed to any role, and the AI origin F1 had already been chosen by Reader A.

- Figure comparisons, added after delivery at the user's request; the requirement was then written into instructions/reporting.md and instructions/shared_data.md, with the earlier versions kept in as_run/nagaraj2021/.
  - Published crops: 150-dpi renders of D01 pages 7, 9, 13, 15, 16 and 20, with boxes in reports/figures/comparison/provenance.json.
  - Author-specification figure diagnostics: code/figure_diagnostics.py, outputs in post_unseal/figure_diagnostics. Its reproduction checks against frozen A passed before any specification change (reproduction_checks.json).
  - Map panels use the D01 and D08 variant outputs.
  - Version 2 of the comparison images restyles every reconstructed and author panel to the published figure's visual form, and draws reader readings as orange open triangles. It was made at the user's request after Figure 4's intervals appeared as a shaded area in version 1. Version 1 is kept in reports/figures/comparison_v1/ and code/make_figure_comparisons_v1.py. The plotted values are identical in both versions.

## 9. Containment and model records

- Coordinator: Claude Opus 5.5, High effort, fast mode off (pinned, not observable in the desktop app). Loaded instructions were the two project CLAUDE.md files only. The user's global hooks were active, and a chat-log hook wrote chat_log.md into the working directory at prompt times, including once into sealed/probes. Desktop connectors were present and unused (logs/session_record.json).
- Roles: separate claude -p --safe-mode or codex exec processes from neutral $TMPDIR staging folders, launched by code/run_role.py (adopted from setup_drafts at the user's instruction).
  - Both families ran inside a sandbox-exec profile denying reads and writes to ~/Library/CloudStorage, the project root, Claude and Codex session stores and the coordinator scratch folder, plus reads of ~/.codex/AGENTS.md. Codex's own sandbox was off because it cannot nest (checks/astra_barrier_test/RESULTS.md).
  - Network access from role commands was open. No-browsing was instruction-only. A scan of all four Astra event logs (reader, two implementers, one checker; 95 commands) found no network command; the one pattern match was the text "nc in" inside a Python loop. Opus roles do not log their commands in the JSON output, so they were not scanned.
  - Opus roles reported "fast" with no fallback. Astra Ultrafast and its model name are not reported by codex-cli 0.164.0 and are unverified.
- Empirical runs, loader checks and diagnostics: sandbox-exec deny network*, tested first (logs/session_record.json).

## 10. Deviations, failures and unavailable items

- Research ran in the Dropbox folder; the coordinator had recommended moving it first. Inputs were materialized and hashed.
- Failed bundle v0 is kept (section 1). Making outputs read-only was not permitted; hashes are used instead.
- Influence: C ran all deletions instead of the declared subset (section 5).
- Scorer v1.1 (section 6).
- Comparison 2 was not run (Stata missing).
- Figure 3 and Figure 1(b) were not audited.
- Corpus-level reader validation, human double-coding, planted-error and null-data calibration arms and a post-cutoff stratum were not performed; they are outside this single-paper session.
