# Model access and launch records

Requested configurations are pinned per study. STUDY.json names the role configuration: config/roles.json for berry2025 and config/roles_nagaraj2021.json for nagaraj2021. Keep separate fresh contexts. Set speed explicitly on every launch rather than inheriting a global preference.

## Coordinator

.claude/settings.json at the project root and in each study folder sets the model, effortLevel high, fastMode, autoMemoryEnabled false, and claudeMdExcludes for the user's global CLAUDE.md on either machine. Each study folder has its own copy, so the settings apply whichever folder is opened. At session start, record the actual model and effort (/status), the loaded instruction files (/memory) and the fast-mode state. Do not toggle /fast during a study. If the session runs another model or effort, or loads other instruction files, stop and report it.

## Isolated roles

Run every reader, memorization probe, implementer and pre-execution checker as a separate CLI process, never as a coordinator subagent. Subagents can inherit this project's CLAUDE.md files, which name the paper and carry coordinator instructions. Launch each process from a staging directory whose path does not reveal the study, for example $TMPDIR/role_<opaque run id>/, holding only that role's frozen inputs and its prompt. Copy the outputs back into the study's role directory with hashes. Record the staging path, the command line without credentials, the CLI version and the reported model. Isolation that rests only on instructions must be disclosed.

The standalone CLIs are $HOME/.local/bin/claude and $HOME/.local/bin/codex. On the machine used for berry2025, claude CLI authentication used CLAUDE_CONFIG_DIR=$HOME/.claude-personal. Resolve them afresh if unavailable; do not install, upgrade or change a requested model silently. No credentials belong in this project.

For Claude roles, use claude -p --safe-mode --model <model> --effort high --settings '{"fastMode":<true|false>,"autoMemoryEnabled":false}' --no-session-persistence, with the explicit role prompt and a bounded tool list (--tools or --allowed-tools). --safe-mode disables CLAUDE.md, skills, plugins, hooks, MCP servers and custom agents, so the role sees only what it is given. Do not use --dangerously-skip-permissions or bypassPermissions. Fast mode works only on Opus 5.5, Opus 5 and Opus 4.8; turning it on for another model switches the model, so set fastMode true only where the role configuration pins an Opus model with fast mode. In claude -p, fast mode must be set in --settings (Claude Code v2.1.205 or later) and draws on usage credits. Under a fast-mode rate limit Claude Code falls back to standard speed with the same model; record any fallback.

For Codex roles, use codex exec --ephemeral --ignore-user-config --skip-git-repo-check -C <staging directory> -m gpt-6-astra -c 'model_reasoning_effort="high"' -c 'service_tier="<tier>"', with a sandbox mode fitted to the role. The tier comes from the role configuration: "default" (add -c 'features.fast_mode=false'), "fast" or "ultrafast". Ultrafast needs an eligible plan, and GPT-6 Astra Ultrafast is served from the United States only. Record the service_tier that the event log reports. This project has no AGENTS.md, so Codex finds no project instructions. The user's global ~/.codex/AGENTS.md may still load; check whether it loads and record the result.

These are requested launch settings, not proof of a successful call. Verify installed CLI support, account access, actual model, effort and speed at launch; record any metadata that is unavailable. Never change a requested model or effort. A speed fallback follows the role configuration's policy and is recorded. Do not treat earlier connectivity checks as verification of a reader pair. No reader or replication run is performed by this configuration.

Use the same settings for a reader's separate memorization probe. Never put login tokens, API keys or private credentials in logs. Preserve existing run records unchanged when updating future launch settings.

References: [Claude fast mode](https://code.claude.com/docs/en/fast-mode) and [Codex speed controls](https://learn.chatgpt.com/docs/agent-configuration/speed).
