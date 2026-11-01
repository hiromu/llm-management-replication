#!/bin/bash
# Revision round for one implementer after a check. Usage: bash launch_fix.sh <A|B|C> <code_dir> <check_unmet_md> <round>
set -euo pipefail
IMPL="$1"; CODE="$2"; CHECK="$3"; ROUND="$4"
STUDY="$(cd "$(dirname "$0")/.." && pwd)"
F="$STUDY/implementation/frozen_v1"
STAGE=$(mktemp -d "${TMPDIR}role_im_XXXXXX")
mkdir -p "$STAGE/data"
cp -R "$F/bundle/dictionaries" "$F/bundle/code_lists" "$STAGE/"
cp "$F/bundle/manifest.md" "$F/bundle/grid.json" "$STAGE/"
cp "$F/fix_prompt.md" "$STAGE/ASSIGNMENT.md"
cp "$CHECK" "$STAGE/CHECK.md"
cp -R "$CODE" "$STAGE/code"
cp "$F/bundle/data_small/"*.csv "$STAGE/data/"
cp "$STUDY/data/derived/pow_rg389_records.parquet" "$STAGE/data/pow.parquet"
cp "$STUDY/data/derived/asnf_rg64_records.parquet" "$STAGE/data/enl.parquet"
case "$IMPL" in A|B) cp "$F/software_R.md" "$STAGE/SOFTWARE.md";; C) cp "$F/software_Py.md" "$STAGE/SOFTWARE.md";; esac
OUT="$STUDY/implementation/impl_$IMPL/v${ROUND}_$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p "$OUT"
echo "$STAGE" > "$OUT/staging_path.txt"
PROMPT="Read ASSIGNMENT.md in the current directory and complete it. All inputs are in this directory."
START=$(date -u +%FT%TZ)
cd "$STAGE"
if [ "$IMPL" = A ]; then
  CMD=(~/.local/bin/claude -p --safe-mode --model claude-fable-5-1 --effort high
       --settings '{"fastMode":false,"autoMemoryEnabled":false}' --no-session-persistence
       --tools "Read,Write,Edit,Glob,Grep,Bash" --permission-mode acceptEdits
       --allowed-tools "Bash(Rscript:*)" "Bash(ls:*)" "Bash(head:*)" "Bash(wc:*)" "Bash(mkdir:*)" "Bash(cat:*)" --output-format json)
  "${CMD[@]}" "$PROMPT" > "$OUT/cli_result.json" 2> "$OUT/cli_stderr.txt" || echo "exit=$?" >> "$OUT/cli_stderr.txt"
else
  CMD=(~/.local/bin/codex exec --ephemeral --ignore-user-config --skip-git-repo-check
       -C "$STAGE" -m gpt-6-astra -c 'model_reasoning_effort="high"' -c 'service_tier="default"'
       -c 'features.fast_mode=false' -s workspace-write)
  "${CMD[@]}" -o "$OUT/last_message.txt" "$PROMPT" < /dev/null > "$OUT/cli_transcript.txt" 2>&1 || echo "exit=$?" >> "$OUT/cli_transcript.txt"
fi
END=$(date -u +%FT%TZ)
printf '%q ' "${CMD[@]}" > "$OUT/command_line.txt"
cp -R "$STAGE/code" "$OUT/code"
rm -rf "$OUT/code/results" 2>/dev/null || true
( cd "$OUT" && find code -type f | sort | xargs shasum -a 256 > code_SHA256SUMS )
printf '{"implementer":"%s","round":"%s","start_utc":"%s","end_utc":"%s","staging":"%s"}\n' "$IMPL" "$ROUND" "$START" "$END" "$STAGE" > "$OUT/run_record.json"
echo "$OUT"
