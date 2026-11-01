#!/bin/bash
# Launch one independent reader from a neutral staging directory.
# Usage: launch_reader.sh fable|astra <frozen_input_dir>
# <frozen_input_dir> holds packet/, rules/, sources/ and ASSIGNMENT.md, identical for both readers.
set -euo pipefail
READER="$1"; INPUT="$2"
STUDY="$(cd "$(dirname "$0")/../.." && pwd)"
STAGE=$(mktemp -d "${TMPDIR}role_rd_XXXXXX")
cp -R "$INPUT"/. "$STAGE"/
mkdir -p "$STAGE/output"
PROMPT="Read ASSIGNMENT.md in the current directory and carry out the assignment completely. All inputs are in this directory; write outputs only to ./output/."
OUT="$STUDY/readers/$READER/run_$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"
echo "$STAGE" > "$OUT/staging_path.txt"
cd "$STAGE"
START=$(date -u +%FT%TZ)
if [ "$READER" = fable ]; then
  CMD=(~/.local/bin/claude -p --safe-mode --model claude-fable-5-1 --effort high
       --settings '{"fastMode":false,"autoMemoryEnabled":false}' --no-session-persistence
       --tools "Read,Write,Edit,Glob,Grep" --permission-mode acceptEdits --output-format json)
  ~/.local/bin/claude --version > "$OUT/cli_version.txt"
  "${CMD[@]}" "$PROMPT" > "$OUT/cli_result.json" 2> "$OUT/cli_stderr.txt" || echo "exit=$?" >> "$OUT/cli_stderr.txt"
else
  CMD=(~/.local/bin/codex exec --ephemeral --ignore-user-config --skip-git-repo-check
       -C "$STAGE" -m gpt-6-astra -c 'model_reasoning_effort="high"' -c 'service_tier="default"'
       -c 'features.fast_mode=false' -s workspace-write)
  ~/.local/bin/codex --version > "$OUT/cli_version.txt"
  "${CMD[@]}" -o "$OUT/last_message.txt" "$PROMPT" < /dev/null > "$OUT/cli_transcript.txt" 2>&1 || echo "exit=$?" >> "$OUT/cli_transcript.txt"
fi
END=$(date -u +%FT%TZ)
printf '%q ' "${CMD[@]}" > "$OUT/command_line.txt"
cp -R "$STAGE/output" "$OUT/output"
chmod -R a-w "$OUT/output"
( cd "$OUT" && find output -type f -exec shasum -a 256 {} \; > output_SHA256SUMS )
printf '{"reader":"%s","start_utc":"%s","end_utc":"%s","staging":"%s","input_dir":"%s"}\n' "$READER" "$START" "$END" "$STAGE" "$INPUT" > "$OUT/run_record.json"
echo "$OUT"
