# Shared-data replication — version 1

Independent replications that test the two-reader, three-implementer workflow on papers whose authors deposited data and code. Agents rebuild the results from the deposited data and the written methods, with the author code sealed, and then compare their code with the authors'.

| Journal | Paper | Design | Status | Folder |
| --- | --- | --- | --- | --- |
| Organization Science | Berry & Hildreth (2025) | experiments | complete | [studies/berry2025/](studies/berry2025/README.md) |
| Management Science | Nagaraj (2021) | county panel, natural experiment | fresh start | [studies/nagaraj2021/](studies/nagaraj2021/README.md) |

## Contents
- CLAUDE.md and instructions/: the working method. [instructions/shared_data.md](instructions/shared_data.md) holds the shared-data rules; each study's CLAUDE.md adds its own rules and takes precedence.
- config/: role configuration per study. config/roles.json is berry2025's; config/roles_nagaraj2021.json is nagaraj2021's.
- prompts/: coordinator start prompt and reader rules.
- .claude/settings.json: pins the coordinator to Claude Opus 5.5, High effort, fast mode off, with auto-memory off and the global CLAUDE.md excluded.
- as_run/berry2025/: the root files as they stood when berry2025 ran, with hashes. The root files were generalized on 2026-11-01 to hold a second study.

workflow.md, scoring.md, reporting.md and reader.md are copies of the v4 files. No v4 file was changed.

## Start
Open one study folder in a new Claude Code session and use the first message in its README. Setup does not authorize research.
