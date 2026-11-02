#!/bin/bash
# Pre-execution checker: manifest + code only. Usage: bash launch_checker.sh <impl A|B|C> <code_dir> <round>
set -euo pipefail
IMPL="$1"; CODE="$2"; ROUND="$3"
STUDY="$(cd "$(dirname "$0")/.." && pwd)"
F="$STUDY/implementation/frozen_v1"
STAGE=$(mktemp -d "${TMPDIR}role_ck_XXXXXX")
mkdir -p "$STAGE/output"
cp "$F/manifest.md" "$F/grid.json" "$STAGE/"
cp "$F/checker_prompt.md" "$STAGE/ASSIGNMENT.md"
cp -R "$CODE" "$STAGE/code"
rm -rf "$STAGE/code/tests/__pycache__" 2>/dev/null || true
OUT="$STUDY/checks/impl_${IMPL}_round${ROUND}_$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p "$OUT"
echo "$STAGE" > "$OUT/staging_path.txt"
PROMPT="Read ASSIGNMENT.md in the current directory and complete it."
cd "$STAGE"
if [ "$IMPL" = A ]; then
  CMD=(~/.local/bin/codex exec --ephemeral --ignore-user-config --skip-git-repo-check
       -C "$STAGE" -m gpt-6-astra -c 'model_reasoning_effort="high"' -c 'service_tier="default"'
       -c 'features.fast_mode=false' -s workspace-write)
  "${CMD[@]}" -o "$OUT/last_message.txt" "$PROMPT" < /dev/null > "$OUT/cli_transcript.txt" 2>&1 || echo "exit=$?" >> "$OUT/cli_transcript.txt"
else
  CMD=(~/.local/bin/claude -p --safe-mode --model claude-fable-5-1 --effort high
       --settings '{"fastMode":false,"autoMemoryEnabled":false}' --no-session-persistence
       --tools "Read,Write,Glob,Grep" --permission-mode acceptEdits --output-format json)
  "${CMD[@]}" "$PROMPT" > "$OUT/cli_result.json" 2> "$OUT/cli_stderr.txt" || echo "exit=$?" >> "$OUT/cli_stderr.txt"
fi
printf '%q ' "${CMD[@]}" > "$OUT/command_line.txt"
cp -R "$STAGE/output" "$OUT/output"
echo "$OUT"
