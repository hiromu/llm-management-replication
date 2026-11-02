#!/bin/bash
# Frozen execution of one implementation in an isolated directory.
# Usage: bash launch_execution.sh <A|B|C> <code_dir> <influence all|first20|none> [specs]
# Isolation: macOS sandbox-exec profile denying all network access and any read of the project folder;
# the code and data are copied into a fresh $TMPDIR execution directory.
set -euo pipefail
IMPL="$1"; CODE="$2"; INFL="$3"; SPECS="${4:-all}"
STUDY="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$(cd "$STUDY/../.." && pwd)"
F="$STUDY/implementation/frozen_v1"
EXEC=$(mktemp -d "${TMPDIR}exec_XXXXXX")
mkdir -p "$EXEC/data"
cp -R "$CODE"/. "$EXEC/"
rm -rf "$EXEC/results" "$EXEC/construction_check" "$EXEC/construction_checks" "$EXEC/tests/integration_results" 2>/dev/null || true
cp "$F/bundle/manifest.md" "$F/bundle/grid.json" "$EXEC/"
cp -R "$F/bundle/dictionaries" "$F/bundle/code_lists" "$EXEC/"
cp "$F/bundle/data_small/"*.csv "$EXEC/data/"
cp "$STUDY/data/derived/pow_rg389_records.parquet" "$EXEC/data/pow.parquet"
cp "$STUDY/data/derived/asnf_rg64_records.parquet" "$EXEC/data/enl.parquet"
RUNID="${IMPL}_$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$STUDY/runs/$RUNID"; mkdir -p "$OUT"
( cd "$EXEC" && find . -type f | sort | xargs shasum -a 256 > "$OUT/exec_inputs_SHA256SUMS" )
PROFILE="(version 1)(allow default)(deny network*)(deny file-read* (subpath \"$PROJECT\"))"
echo "$PROFILE" > "$OUT/sandbox_profile.sb"
echo "$EXEC" > "$OUT/exec_dir.txt"
cd "$EXEC"
if [ "$IMPL" = C ]; then
  CMD=(~/.venv/bin/python -I run.py --grid grid.json --data data --out results --specs "$SPECS" --influence "$INFL")
  ~/.venv/bin/python -c "import sys,numpy,scipy,pandas,statsmodels,pyarrow;print(sys.version);print('numpy',numpy.__version__,'scipy',scipy.__version__,'pandas',pandas.__version__,'statsmodels',statsmodels.__version__,'pyarrow',pyarrow.__version__)" > "$OUT/environment.txt"
else
  CMD=(/opt/homebrew/bin/Rscript run.R --grid grid.json --data data --out results --specs "$SPECS" --influence "$INFL")
  /opt/homebrew/bin/Rscript -e 'cat(R.version.string,"\n"); for(p in c("data.table","nanoparquet","jsonlite")) cat(p, as.character(packageVersion(p)),"\n")' > "$OUT/environment.txt"
fi
printf '%q ' "${CMD[@]}" > "$OUT/command_line.txt"
START=$(date -u +%FT%TZ)
set +e
sandbox-exec -p "$PROFILE" "${CMD[@]}" > "$OUT/stdout.txt" 2> "$OUT/stderr.txt"
RC=$?
set -e
END=$(date -u +%FT%TZ)
cp -R "$EXEC/results" "$OUT/results" 2>/dev/null || true
( cd "$OUT" && find results -type f -not -path 'results/sample_ids/*' | sort | xargs shasum -a 256 > results_SHA256SUMS ) || true
printf '{"run_id":"%s","implementation":"%s","exit_code":%s,"start_utc":"%s","end_utc":"%s","influence":"%s","specs":"%s","exec_dir":"%s"}\n' "$RUNID" "$IMPL" "$RC" "$START" "$END" "$INFL" "$SPECS" "$EXEC" > "$OUT/run_record.json"
echo "$OUT"
