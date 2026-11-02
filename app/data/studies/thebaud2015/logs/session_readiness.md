# Coordinator session readiness check

- Study: thebaud2015 (paper_id ASQ_2015_Thebaud), selected by opening this study folder.
- Date: 2026-10-27. Coordinator CCD session: local_05c24e8e-e5c7-460b-9141-bbcfdfd2a454; transcript ID 70a385e9-abe5-4440-ac25-10dd29d6dc33.
- Research authorized: no (readiness check only).

## Coordinator configuration (actual)

- Model claude-opus-5-5, effort high, fast mode off, from the app's session metadata (get_session "self"). Permission mode auto.
- Instruction files loaded: project-root CLAUDE.md and studies/thebaud2015/CLAUDE.md only. ~/.claude/CLAUDE.md exists but is excluded by .claude/settings.json and did not load. Auto-memory is off.
- Disclosure: the desktop app adds its own system context (tools, task-list rules). A user-level logging hook writes studies/thebaud2015/chat_log.md, which was not created by this project setup.

## Inputs verified by hash

- Article papers/journal_collection/ASQ/ASQ_2015_Thebaud.pdf: SHA-256 matches STUDY.json.
- Supplement ASQ_2015_Thebaud_S1: SHA-256 matches STUDY.json and papers/supplements/catalog.json (preparation copied_without_code_removal; identity and completeness still to verify).
- ICPSR 20320 bundle: all 7 files match the SHA-256 values in data/supplied/supplied_sources.json. Coverage, weights, missing-value coding and terms still need source-role validation.

## Reader tooling (connectivity checks, not reader runs)

- claude CLI 2.1.270 supports --safe-mode, --effort, --settings, --no-session-persistence and --tools. A one-line check with claude-fable-5-1, effort high, fastMode false returned OK. modelUsage reported claude-fable-5-1.
- codex-cli 0.164.0 supports the flags required by instructions/model_access.md. A one-line check with gpt-6-astra, reasoning effort high and sandbox read-only returned OK. The header reported model gpt-6-astra and reasoning effort high. service_tier is not shown in the CLI output, so speed was not verified from output.
- ~/.codex/AGENTS.md exists. Whether --ignore-user-config suppresses it is unverified and is to be checked at reader launch.
- Python: ~/.venv/bin/python 3.13.4.

## Notes for execution

- These connectivity checks ran in the session scratchpad, whose path contains the study name. Real role runs must use opaque staging directories such as $TMPDIR/role_<id>/.
- Codex reads stdin when stdin is not closed. Launch role runs with </dev/null.
