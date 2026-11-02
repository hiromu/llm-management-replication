# Shared-data replication project — version 1

## Scope and authority
This project holds independent replications of papers whose authors deposited data and code. Each paper runs in its own Claude Code coordinator session and its own studies/<study_id>/ folder: berry2025 (complete) and nagaraj2021. It adapts the v4 management replication protocol to deposited data. Results are reported separately from the v4 studies and do not enter their candidate counts or tables. Do not start readers, run models or unseal author code until the user authorizes research in the session. Setup does not authorize research.

These instructions, the files in instructions/ and the study's CLAUDE.md and STUDY.json are the complete working method. Never inspect sibling projects, other studies in this project, archives, prior sessions or other replication outputs. Do not seek a separate protocol document. The article and deposited documents are read-only. as_run/ holds the root files as they stood during berry2025; it is a record, not an instruction.

Use $HOME/.venv/bin/python and $HOME/.venv/bin/python -m pip. Rscript is at /opt/homebrew/opt/r/bin/Rscript. Use relative project paths for artifacts and record runtime versions. Claude Code loads this file and the study's CLAUDE.md automatically. Do not depend on the user's global CLAUDE.md, other inherited instructions or automatic memory. The .claude/settings.json at the project root and in each study folder excludes the global file and turns auto-memory off; check with /memory at session start and disclose anything else that loads. Explicitly provide each role only its assigned instructions and files.

## Required preparation
All paths are relative to the project root unless specified otherwise. Read instructions/shared_data.md first, then instructions/workflow.md, instructions/supplements.md, instructions/scoring.md, instructions/reporting.md, instructions/model_access.md, the study's STUDY.json and CLAUDE.md, and the role configuration that STUDY.json names. Where these files differ, the study's CLAUDE.md takes precedence, then instructions/shared_data.md, then the rest. Record the coordinator session identifier where available.

## Data and author code
The empirical inputs are the deposited data files in the study's data/raw/ folder, plus any other public file the study's CLAUDE.md names. Agents do not acquire other data. Do not use observations, correlation matrices or effect-size tables printed in the article as empirical inputs. Published results may be extracted only as sealed comparison targets or publication diagnostics.

Everything in the study's sealed/author_package/ stays unread until the unsealing point in instructions/shared_data.md. This applies to the coordinator and to every role. Do not look for author results or code elsewhere online.

## Models and independent roles
The coordinator is Claude Code running Claude Opus 5.5 (claude-opus-5-5), High effort, with the speed pinned in the study's .claude/settings.json. Readers, implementers, checkers and memorization probes use the models, efforts and speeds in the study's role configuration. Two readers from different model families are required. Three independent implementers are required: A in R from one family, B in R and C in Python from the other. Pre-execution checkers come from the family other than the implementer's. Different contexts of one family do not meet the reader requirement. Where the coordinator shares a family or a model with a reader, the coordinator does not read independently, so reader independence holds, but record the overlap.

Do not silently change model, version, effort or speed; record requested and actual settings, and report if verification or availability fails. CLI launch notes are in instructions/model_access.md. Connectivity checks are not reader runs.

Use separate fresh contexts for the two readers, implementers, pre-execution checking and downstream audits. Claude Code subagents can inherit this project's CLAUDE.md files, which name the paper and carry coordinator instructions. Readers, memorization probes, implementers and pre-execution checkers must therefore run as separate CLI processes from a neutral staging directory, never as coordinator subagents. Coordinator subagents may only do work that is allowed to know the paper, such as scoring and post-discrepancy audits. No agent grades its own empirical result. Do not invent a missing model-family independence claim.

## Information flow
Readers receive the identical frozen publication packet, these workflow rules and summary-free data descriptions, never data rows or analysis output. They independently prepare initial manifests and targets; no cross-reading or coordinator interpretation before those outputs are sealed. Memorization probes run separately, and their answers are sealed from the readers.

The coordinator reconciles structure and logs every disagreement. Different labels remain uncertain; different structures retain the union. Do not force consensus. Compute and report initial reader agreement before any clarification round. Readers must never receive result-based feedback.

Implementers receive neutral target-free manifests, the implementer data bundle and software requirements. They cannot see article identity, targets, scoring criteria, another implementation or analysis results. Checkers see only the manifest and code before execution. The scorer sees frozen outputs and sealed targets downstream. Adversarial reviewers can see everything after a potential discrepancy is identified. Enforce access and network barriers where available; instruction-only isolation must be disclosed.

## Scientific rules
Freeze data, manifest, sourced alternatives, labels, inference rules, numerical tolerances, budget and scoring before empirical execution. No tuning to reported estimates; no result-driven label change, added alternative or widened tolerance. Preserve failures and all prior versions. Explicitly reported models and controls cannot be changed merely to enlarge the grid. Mathematical re-expressions and repeat implementations are checks, not new scientific alternatives. Distinguish equivalent, uncertain, non-equivalent and influence analyses.

Report six outcomes using instructions/scoring.md, keeping claim and paper levels separate. No substantive alternatives means no assessed specification-fragility verdict. Incomplete data or missing calibration cannot silently become consistency or discrepancy. Final discrepant verdicts require adversarial review. Human confirmation was removed at the user's request, so reports must say that no human reviewed them. No author contact, publication, submission, account creation or paid data purchase is authorized.

## Deliverables
Use concise Markdown without bold emphasis in main prose. Follow instructions/reporting.md. Generate all contents from this study's new outputs. Deliver the report, then stop.
