#!/bin/zsh
# Usage: run_reader.sh <fable|astra> <study_root> <run_label>
# Builds a neutral staging directory holding only the frozen reader inputs, runs the reader CLI there,
# then copies everything back to readers/<who>/<run_label>/ with hashes.
set -u
WHO=$1; ROOT=$2; RUN=$3
C=$ROOT/readers/common
RID=$(/usr/bin/openssl rand -hex 6)
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/role_${RID}_XXXX")
mkdir -p $STAGE/packet/docs $STAGE/packet/text/pages $STAGE/rules $STAGE/schema $STAGE/data_description $STAGE/out
cp $ROOT/../../papers/journal_collection/ORSC/ORSC_2011_Lehman.pdf $STAGE/packet/docs/D01_article.pdf
cp $ROOT/sources/text/pages/*.txt $STAGE/packet/text/pages/
cp $C/publication_packet.json $STAGE/packet/
cp $C/reader_rules.md $STAGE/rules/
cp $C/reader_output_schema.md $STAGE/schema/
cp $C/source_descriptions.md $ROOT/registry/data_dictionary.md $STAGE/data_description/
cp $C/reader_prompt.md $STAGE/prompt.md
(cd $STAGE && find . -type f ! -path './out/*' | sort | xargs shasum -a 256 > input_manifest.sha256)
OUT=$ROOT/readers/$WHO/$RUN; mkdir -p $OUT
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cd $STAGE
if [[ $WHO == fable ]]; then
  CMD=(~/.local/bin/claude -p --safe-mode --model claude-fable-5-1 --effort high --settings '{"fastMode":false,"autoMemoryEnabled":false}' --no-session-persistence --tools "Read,Write,Edit,Glob,Grep" --allowed-tools "Read,Write,Edit,Glob,Grep" --permission-mode acceptEdits --output-format json)
  "${CMD[@]}" < prompt.md > cli_response.json 2> cli_stderr.txt; RC=$?
  VER=$(~/.local/bin/claude --version)
else
  CMD=(~/.local/bin/codex exec --ephemeral --ignore-user-config --skip-git-repo-check -C "$STAGE" -m gpt-6-astra -c 'model_reasoning_effort="high"' -c 'service_tier="default"' -c 'features.fast_mode=false' -s workspace-write --json -o cli_last_message.txt -)
  "${CMD[@]}" < prompt.md > cli_events.jsonl 2> cli_stderr.txt; RC=$?
  VER=$(~/.local/bin/codex --version)
fi
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
rsync -a --exclude packet/docs $STAGE/ $OUT/
printf '%s\n' "${CMD[@]}" > $OUT/command_argv.txt
cat > $OUT/launch_record.json <<J
{"role": "reader_$WHO", "run": "$RUN", "staging_dir": "$STAGE", "start_utc": "$START", "end_utc": "$END", "exit_code": $RC, "cli_version": "$VER", "network": "$([[ $WHO == fable ]] && echo 'no network tools granted (Read/Write/Edit/Glob/Grep only)' || echo 'codex workspace-write sandbox (network disabled by default)')"}
J
(cd $OUT && find . -type f ! -name SHA256SUMS | sort | xargs shasum -a 256 > SHA256SUMS)
chmod -R a-w $OUT/out
echo "$WHO $RUN done rc=$RC"
