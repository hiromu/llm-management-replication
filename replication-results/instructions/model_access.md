# Model access and launch records

Requested configurations are pinned in config/roles.json. The coordinator is Claude Code running Claude Opus 5.5 (claude-opus-5-5), High effort, fast mode off. Reader A is Claude Fable 5.1 (claude-fable-5-1); Reader B is GPT-6 Astra (gpt-6-astra). Both readers use High effort and normal (standard) speed. Keep separate fresh contexts and explicitly disable Fast and Ultrafast.

## Coordinator

.claude/settings.json at the project root and in each study folder sets the model, effortLevel high, fastMode false, autoMemoryEnabled false, and claudeMdExcludes for the user's global ~/.claude/CLAUDE.md. Each study folder has a copy, so the settings apply whichever folder is opened. At session start, record the actual model and effort (/status), the loaded instruction files (/memory) and the fast-mode state. Do not toggle /fast during a study. If the session runs another model or effort, or loads other instruction files, stop and report it.

## Isolated roles

Run every reader, memorization probe, implementer and pre-execution checker as a separate CLI process, never as a coordinator subagent. Subagents can inherit this project's CLAUDE.md files, which name the paper and carry coordinator instructions. Launch each process from a staging directory whose path does not reveal the study, for example $TMPDIR/role_<opaque run id>/, holding only that role's frozen inputs and its prompt. Copy the outputs back into the study's role directory with hashes. Record the staging path, the command line without credentials, the CLI version and the reported model. Isolation that rests only on instructions must be disclosed.

Use the standalone claude and codex CLIs and record their paths and versions; do not install, upgrade or change a requested model silently. No credentials belong in this project.

For Claude roles, use claude -p --safe-mode --model claude-fable-5-1 --effort high --settings '{"fastMode":false,"autoMemoryEnabled":false}' --no-session-persistence, with the explicit role prompt and a bounded tool list (--tools or --allowed-tools). --safe-mode disables CLAUDE.md, skills, plugins, hooks, MCP servers and custom agents, so the role sees only what it is given. Do not use --dangerously-skip-permissions or bypassPermissions. Do not enable /fast: it can switch an unsupported model to another model. Reader A writes under readers/fable/. A Claude implementer or checker uses the model frozen in its role record, with the same flags.

For Codex roles, use codex exec --ephemeral --ignore-user-config --skip-git-repo-check -C <staging directory> -m gpt-6-astra -c 'model_reasoning_effort="high"' -c 'service_tier="default"' -c 'features.fast_mode=false', with a sandbox mode fitted to the role. This project has no AGENTS.md, so Codex finds no project instructions. The user's global ~/.codex/AGENTS.md may still load; it holds only Python-path, Markdown-math and Gmail rules. Check whether it loads and record the result. Reader B writes under readers/astra/.

These are requested launch settings, not proof of a successful call. Verify installed CLI support, account access, actual model, effort and speed at launch; record any metadata that is unavailable. If a requested setting cannot be honored, stop and report it without silently substituting a model or speed. Do not treat earlier connectivity checks as verification of this reader pair. No reader or replication run is performed by this configuration.

Use the same settings for a reader's separate memorization probe. Never put login tokens, API keys or private credentials in logs. Preserve existing run records unchanged when updating future launch settings.

References: [Fable 5.1 model ID](https://platform.claude.com/docs/en/models/fable-5-1/overview), [Claude fast-mode controls](https://code.claude.com/docs/en/fast-mode), and [Codex speed controls](https://learn.chatgpt.com/docs/agent-configuration/speed).
