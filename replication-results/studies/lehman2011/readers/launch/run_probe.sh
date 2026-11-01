#!/bin/zsh
# Usage: run_probe.sh <fable|astra> <study_root>
# Runs a title-and-authors-only memorization probe in a neutral staging directory.
set -u
WHO=$1; ROOT=$2
RID=$(/usr/bin/openssl rand -hex 6)
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/role_${RID}_XXXX")
cp "$ROOT/readers/common/memorization_probe_prompt.md" "$STAGE/prompt.md"
OUT="$ROOT/sealed/memorization/$WHO"; mkdir -p "$OUT"
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cd "$STAGE"
if [[ $WHO == fable ]]; then
  CMD=(~/.local/bin/claude -p --safe-mode --model claude-fable-5-1 --effort high --settings '{"fastMode":false,"autoMemoryEnabled":false}' --no-session-persistence --tools "" --output-format json)
  "${CMD[@]}" < prompt.md > response.json 2> stderr.txt; RC=$?
  VER=$(~/.local/bin/claude --version)
else
  CMD=(~/.local/bin/codex exec --ephemeral --ignore-user-config --skip-git-repo-check -C "$STAGE" -m gpt-6-astra -c 'model_reasoning_effort="high"' -c 'service_tier="default"' -c 'features.fast_mode=false' -s read-only --json -o last_message.txt -)
  "${CMD[@]}" < prompt.md > events.jsonl 2> stderr.txt; RC=$?
  VER=$(~/.local/bin/codex --version)
fi
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cp -R "$STAGE"/. "$OUT/"
printf '%s\n' "${CMD[@]}" > "$OUT/command_argv.txt"
cat > "$OUT/launch_record.json" <<J
{"role": "memorization_probe_$WHO", "staging_dir": "$STAGE", "start_utc": "$START", "end_utc": "$END", "exit_code": $RC, "cli_version": "$VER"}
J
(cd "$OUT" && shasum -a 256 * > SHA256SUMS)
echo "$WHO done rc=$RC"
