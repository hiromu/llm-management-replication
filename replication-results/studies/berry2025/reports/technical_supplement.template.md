# Technical supplement: berry2025

## Frozen artifacts
Grid: manifest/frozen_grid_v1.json. Manifest: manifest/implementer_manifest_v1.md. Scoring: scoring/scoring_rules.json, scoring/score.py, scoring/scoring_rules_amendment_1.json. Hashes: logs/freeze_reader_stage.json, logs/freeze_implementation_stage.json, logs/freeze_pre_execution.json, logs/pre_unseal_hashes.json, logs/unseal_record.json. The author script hash before and after unsealing equals the OSF receipt. Empirical run: {RUN}.

## Setup-draft decisions and code versions
build_reader_packet.py, run_role.py and the reader prompt were adopted with changes (code/, prompts_frozen/). The probe prompt was adopted unchanged. Executed scripts: implementation/A/v3, B/v1, C/v2; every earlier version and checker list is kept. Implementer A's last recheck still lists one item: whether path a uses complete cases on its own variables or on the whole model. An earlier recheck asked the reverse. It was recorded, not iterated, and had no effect on the real data: all three implementations agree on these paths.

## Containment
| Role | Enforced | Instruction-only |
| --- | --- | --- |
| Fable readers and implementer | Outer seatbelt denies the Dropbox tree and past transcripts; scrubbed environment; bounded tools; implementer Bash limited to Rscript | Network from R scripts was not separately denied |
| Astra readers, implementers, checker | Native workspace-write: tool network off, writes confined; scrubbed environment | Reads: nesting Codex in an outer seatbelt fails with sandbox_apply: Operation not permitted. Neutral paths and a command-log audit instead |
| Empirical runs | sandbox-exec deny network*, tested (curl failed) | None |
| Global hooks in the coordinator session | None: they logged this conversation to chat_log.md | Disclosed; --safe-mode disabled hooks for Fable roles and no chat_log appeared in staging |

Setup exposure is in STUDY.json. Coordinator exposure: read targets, readers' outputs and deposit row counts before writing the manifest; never opened empirical rows beyond column types and free-text-safe metadata.

## Scorer departures found by audit
The frozen scorer stays as run. Details with line references are in audit_pre_unseal.md. Main items: relative tolerance floored at 1, which moves 28 rows if corrected, no claim change; incomplete_coverage unreachable; the discrepant test ignores equivalents for indirect effects; sample and composite levels unused in stability and label sensitivity; a vacuous SM2 label check; the overview-table sensitivity and comparability map not computed by code (given in the main report); no claim outcome for G1C, G1W, G2C, G2W.

## Failures and unavailability
No empirical quantity failed in any implementation. Unavailable: Study 4 duration in months; signing share among non-completers (no such rows are known to exist in the file); author software settings beyond the script. Author rerun: runs/author_rerun/asis_summary.json lists 31 failures; changed_summary.json lists 0; changes are in that file and the script run_author.R. The study-local package library first attempted inside Dropbox was corrupted by sync and abandoned at runs/author_rerun/rlib; the working library sat outside Dropbox for the session, and versions are in runs/author_rerun/changed_versions.csv. R 4.6.1, lavaan 0.6-21, emmeans 2.0.4, effsize 0.8.1, heplots 1.8.6, rstatix 1.1.0, DescTools 0.99.60. The authors' own package versions are not recorded, so the lavaan syntax failure may be a version effect.

## Provisional rule tests
scoring/rule_tests/results.json: planted sign flip, 3 SE shift, 0.6 SE shift, F shift, two-band p change, unreachable N and N-branch selection, all as expected. Synthetic only.

## Corpus-level items
Reader validation by human double-coding, a human-reproduced set, cross-paper calibration and a post-cutoff sample are outside this session and not performed. Human review of candidate discrepancies was removed at the user's request and not performed.
