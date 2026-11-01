# Replication protocol

## One study per session, inside its own folder

Each replication runs on its own. Open studies/<study_id>/ as the workspace of a new Claude Code session; Claude Code then loads this file and the study's CLAUDE.md. The session works on that one study and stops once its report is delivered. Record the study ID and the coordinator session ID.

The session writes only inside its study folder. Outside it, the session may read only this file, instructions/, prompts/, config/ and its own article and supplements, located through STUDY.json in papers/ or in the study's packet/. It never reads another study's folder, earlier sessions, archives or other projects, and never reuses a role context from another study. A new paper needs a new session opened in that paper's folder.

Start no readers, downloads or model runs until the user authorizes research in the session.

## Where the rules are

Read these before research. Paths are relative to the project root (../.. from a study folder).

- instructions/shared_data.md: rules for a study built on the authors' own data deposit (berry2025). For that study they take precedence over every other file listed here.
- instructions/workflow.md: the steps from source acquisition to audit.
- instructions/supplements.md: the article-and-supplement packet both readers receive.
- instructions/supplied_sources.md: data files the user downloaded by hand into data/supplied/.
- instructions/scoring.md: frozen scoring rules and the six outcomes.
- instructions/reporting.md: the report and the influence figure.
- instructions/model_access.md and config/roles.json: models, settings and how each role is launched.
- prompts/coordinator_start.md and prompts/reader.md: the coordinator's start prompt and the reader prompt.

## Rules stated only here

Eligibility. The paper must have no publicly available author replication data or code. Check this afresh after research is authorized and record the evidence. If a package exists, report that the paper fails the selection rule and stop for user direction; do not use the package or substitute another paper. Removing author code from a reading copy does not make a paper eligible. The exception is a study under instructions/shared_data.md, which uses the authors' deposit by design and keeps their code sealed until scoring is done.

Empirical inputs. Use public source data acquired afresh in this session, plus any bundle in the study's data/supplied/ folder. A study under instructions/shared_data.md uses the authors' deposited files instead. Numbers printed in the article or its supplements are sealed comparison targets, never data. If core sources cannot be obtained, the affected scope is not attemptable.

Roles. Reader A (Claude Fable 5.1) and Reader B (GPT-6 Astra) must come from different model families; two contexts of one family do not count. Record that the coordinator (Claude Opus 5.5) shares Reader A's family. Readers, memorization probes, implementers and pre-execution checkers run as separate CLI processes, never as coordinator subagents, because subagents inherit these instructions and the paper's identity. Coordinator subagents may only do work that is allowed to know the paper: source acquisition, scoring and post-discrepancy audits. No agent grades its own result.

Freezing. Freeze data, manifest, labels, tolerances and scoring rules before any model is fitted. Never tune toward published estimates, change a label after seeing results, or widen a tolerance. Keep every failure and every earlier version.

Environment. Use one existing Python virtual environment for every role and record its path and runtime versions. Use study-relative paths. The .claude/settings.json at the project root and in each study folder pins the coordinator model and turns off the user's global CLAUDE.md and automatic memory; confirm with /memory at session start and disclose anything else that loads.

Not authorized: contacting authors, publishing, submitting, creating accounts or buying data.

## Cross-study rescoring

studies/scoring_rules_common_v1.json and studies/score_common.py rescore the six public-data studies under one shared rule, after all results were known. They change no study's frozen rules or outcomes. A study session does not read, run or adopt them.
