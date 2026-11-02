#!/bin/zsh
# Usage: execute_frozen.sh <A|B|C> <study_root> <code_round> <run_id>
# Frozen execution: copies the cleared code and the frozen inputs into runs/<run_id>/<WHO>/, hashes them, and runs the
# full stage under a network-deny sandbox. Results stay in that immutable run directory.
set -u
WHO=$1; ROOT=$2; RND=$3; RUN=$4; PROFILE=${5:-$ROOT/checks/nonet.sb}
I=$ROOT/implementation
D=$ROOT/runs/$RUN/$WHO
[[ -e $D ]] && { echo "run dir exists: $D"; exit 1; }
mkdir -p $D/data/pbp $D/data/games $D/data/alignment $D/data/dictionary $D/docs $D/code $D/results
cp $ROOT/data/raw/nflverse/pbp_release_20261027T113315Z/play_by_play_20{00,01,02,03,04,05}.parquet $D/data/pbp/
cp $ROOT/data/raw/nflverse/schedules_release_20261027T113315Z/games.parquet $D/data/games/
cp $ROOT/registry/team_season_alignment.csv $D/data/alignment/
cp $ROOT/registry/data_dictionary.md $D/data/dictionary/
cp $I/docs/* $D/docs/
cp $I/manifest_neutral_v1.md $D/manifest.md
cp $I/grid_v1.json $D/grid.json
rsync -a --exclude __pycache__ --exclude '*.o' --exclude '*.so' $I/$WHO/$RND/code/ $D/code/
chmod -R u+w $D
(cd $D && find . -type f ! -path './results/*' | sort | xargs shasum -a 256 > INPUT_SHA256SUMS)
case $WHO in
  A|B) CMD=(Rscript code/run_all.R --stage full);;
  C) CMD=(~/.venv/bin/python -I code/run_all.py --stage full);;
esac
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cd $D && sandbox-exec -f $PROFILE "${CMD[@]}" > run_stdout.txt 2> run_stderr.txt; RC=$?
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > $D/execution_record.json <<J
{"implementation": "$WHO", "code_round": "$RND", "run_id": "$RUN", "command": "${CMD[*]}", "sandbox": "sandbox-exec $(basename $PROFILE)", "start_utc": "$START", "end_utc": "$END", "exit_code": $RC, "host": "$(uname -srm)"}
J
(cd $D && find results -type f | sort | xargs shasum -a 256 > RESULTS_SHA256SUMS)
echo "$WHO $RUN rc=$RC"
