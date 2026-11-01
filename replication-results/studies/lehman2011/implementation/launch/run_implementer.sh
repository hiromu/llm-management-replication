#!/bin/zsh
# Usage: run_implementer.sh <A|B|C> <study_root> <round_label> [prev_round_label] [extra_prompt_file]
# Builds a neutral staging directory with the frozen manifest, grid, data and docs (plus previous code for repair
# rounds), runs the implementer CLI there, and copies code and results back to implementation/<WHO>/<round>/.
set -u
WHO=$1; ROOT=$2; RND=$3; PREV=${4:-}; EXTRA=${5:-}
I=$ROOT/implementation
RID=$(/usr/bin/openssl rand -hex 6)
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/role_${RID}_XXXX")
mkdir -p $STAGE/data/pbp $STAGE/data/games $STAGE/data/alignment $STAGE/data/dictionary $STAGE/docs $STAGE/code $STAGE/results
cp $ROOT/data/raw/nflverse/pbp_release_20261027T113315Z/play_by_play_20{00,01,02,03,04,05}.parquet $STAGE/data/pbp/
cp $ROOT/data/raw/nflverse/schedules_release_20261027T113315Z/games.parquet $STAGE/data/games/
cp $ROOT/registry/team_season_alignment.csv $STAGE/data/alignment/
cp $ROOT/registry/data_dictionary.md $STAGE/data/dictionary/
cp $I/docs/* $STAGE/docs/
cp $I/manifest_neutral_v1.md $STAGE/manifest.md
cp $I/grid_v1.json $STAGE/grid.json
chmod -R u+w $STAGE
case $WHO in
  A) LANG_=R; EXT=R; GAME="will";;
  B) LANG_=R; EXT=R; GAME="will not";;
  C) LANG_=Python; EXT=py; GAME="will";;
esac
sed -e "s/{LANGUAGE}/$LANG_/" -e "s/{EXT}/$EXT/" -e "s/{GAME_UNIT}/$GAME/" $I/implementer_prompt_template.md > $STAGE/prompt.md
if [[ -n $PREV ]]; then
  cp -R $I/$WHO/$PREV/code/. $STAGE/code/
  [[ -f $I/$WHO/$PREV/results/synthetic_checks.md ]] && cp $I/$WHO/$PREV/results/synthetic_checks.md $STAGE/results/
  [[ -f $I/$WHO/$PREV/results/implementation_notes.md ]] && cp $I/$WHO/$PREV/results/implementation_notes.md $STAGE/results/
fi
[[ -n $EXTRA ]] && { printf '\n\n' >> $STAGE/prompt.md; cat $EXTRA >> $STAGE/prompt.md; }
(cd $STAGE && find . -type f ! -path './results/*' ! -path './code/*' | sort | xargs shasum -a 256 > input_manifest.sha256)
OUT=$I/$WHO/$RND; mkdir -p $OUT
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cd $STAGE
if [[ $WHO == A ]]; then
  CMD=(~/.local/bin/claude -p --safe-mode --model claude-fable-5-1 --effort high --settings '{"fastMode":false,"autoMemoryEnabled":false}' --no-session-persistence --tools "Read,Write,Edit,Glob,Grep,Bash" --allowed-tools "Read,Write,Edit,Glob,Grep,Bash(Rscript:*),Bash(~/.venv/bin/python:*),Bash(ls:*),Bash(head:*),Bash(wc:*),Bash(cat:*),Bash(mkdir:*)" --permission-mode acceptEdits --output-format json)
  "${CMD[@]}" < prompt.md > cli_response.json 2> cli_stderr.txt; RC=$?
  VER=$(~/.local/bin/claude --version)
else
  CMD=(~/.local/bin/codex exec --ephemeral --ignore-user-config --skip-git-repo-check -C "$STAGE" -m gpt-6-astra -c 'model_reasoning_effort="high"' -c 'service_tier="default"' -c 'features.fast_mode=false' -s workspace-write --json -o cli_last_message.txt -)
  "${CMD[@]}" < prompt.md > cli_events.jsonl 2> cli_stderr.txt; RC=$?
  VER=$(~/.local/bin/codex --version)
fi
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
rsync -a --exclude data --exclude docs $STAGE/ $OUT/
printf '%s\n' "${CMD[@]}" > $OUT/command_argv.txt
cat > $OUT/launch_record.json <<J
{"role": "implementer_$WHO", "round": "$RND", "prev_round": "$PREV", "staging_dir": "$STAGE", "start_utc": "$START", "end_utc": "$END", "exit_code": $RC, "cli_version": "$VER"}
J
(cd $OUT && find . -type f ! -name SHA256SUMS | sort | xargs shasum -a 256 > SHA256SUMS)
echo "$WHO $RND done rc=$RC"
