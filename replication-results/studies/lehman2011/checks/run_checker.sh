#!/bin/zsh
# Usage: run_checker.sh <A|B|C> <study_root> <round_label>
# Pre-execution checker: sees only manifest.md, grid.json and the implementer's code/. Returns a bare list of unmet items.
set -u
WHO=$1; ROOT=$2; RND=$3
I=$ROOT/implementation
RID=$(/usr/bin/openssl rand -hex 6)
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/role_${RID}_XXXX")
mkdir -p $STAGE/code $STAGE/out
cp $I/manifest_neutral_v1.md $STAGE/manifest.md
cp $I/grid_v1.json $STAGE/grid.json
cp -R $I/$WHO/$RND/code/. $STAGE/code/
cat > $STAGE/prompt.md <<'P'
You are a pre-execution code checker. In this directory are a specification (manifest.md and grid.json) and code (code/) written to implement it. The code has not yet been run on real data, and you cannot run it.

Read the specification and the code. Write out/unmet.md: a bare list of specification items that the code does not implement, or implements differently from what the specification says. For each item, cite the manifest section or grid key and the code file and line. Do not suggest improvements beyond the specification, do not comment on style, and do not include items that are met. If every item is met, write "No unmet items." Then stop.
P
OUT=$ROOT/checks/$WHO/$RND; mkdir -p $OUT
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cd $STAGE
if [[ $WHO == A ]]; then
  CMD=(~/.local/bin/codex exec --ephemeral --ignore-user-config --skip-git-repo-check -C "$STAGE" -m gpt-6-astra -c 'model_reasoning_effort="high"' -c 'service_tier="default"' -c 'features.fast_mode=false' -s workspace-write --json -o cli_last_message.txt -)
  "${CMD[@]}" < prompt.md > cli_events.jsonl 2> cli_stderr.txt; RC=$?
else
  CMD=(~/.local/bin/claude -p --safe-mode --model claude-fable-5-1 --effort high --settings '{"fastMode":false,"autoMemoryEnabled":false}' --no-session-persistence --tools "Read,Write,Glob,Grep" --allowed-tools "Read,Write,Glob,Grep" --permission-mode acceptEdits --output-format json)
  "${CMD[@]}" < prompt.md > cli_response.json 2> cli_stderr.txt; RC=$?
fi
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
rsync -a --exclude code $STAGE/ $OUT/
printf '%s\n' "${CMD[@]}" > $OUT/command_argv.txt
echo "{\"role\": \"checker_for_$WHO\", \"round\": \"$RND\", \"staging_dir\": \"$STAGE\", \"start_utc\": \"$START\", \"end_utc\": \"$END\", \"exit_code\": $RC}" > $OUT/launch_record.json
(cd $OUT && find . -type f ! -name SHA256SUMS | sort | xargs shasum -a 256 > SHA256SUMS)
echo "checker $WHO $RND rc=$RC"
