#!/bin/zsh
# Frozen execution of one implementer's final code.
# Usage: execute_frozen.sh <impl_label> <code_dir> <run_id>
# Copies the implementer bundle (data, grid, manifest, amendment, docs) and final code into
# runs/<run_id>/<impl_label>/, hashes everything, then runs the script with network denied and
# file writes restricted to the run directory and the system temp area.
set -euo pipefail
ST=<project>/studies/deephouse1999
IMPL=$1; CODE=$2; RUN=$3
RD=$ST/runs/$RUN/$IMPL
[[ -e $RD ]] && { echo "run dir exists; runs are immutable"; exit 1; }
mkdir -p $RD
cp -R $ST/implementation/bundle_v1/. $RD/
cp $ST/implementation/manifest_v1_1_amendment.md $RD/manifest_amendment_v1_1.md
cp $ST/implementation/rssd9425_codes.txt $RD/docs/rssd9425_codes.txt
cp -R $CODE/. $RD/
(cd $RD && find . -type f | sort | xargs shasum -a 256) > $RD/../${IMPL}_inputs_SHA256SUMS.txt
if [[ -f $RD/analysis.R ]]; then CMD=(/opt/homebrew/bin/Rscript analysis.R); else CMD=(~/.venv/bin/python -I analysis.py); fi
PROFILE="(version 1)(allow default)(deny network*)(deny file-write*)(allow file-write* (subpath \"$RD\") (subpath \"/private/var/folders\") (subpath \"/private/tmp\") (literal \"/dev/null\"))"
date -u +%FT%TZ > $RD/../${IMPL}_start_utc.txt
cd $RD
set +e
sandbox-exec -p "$PROFILE" "${CMD[@]}" > $RD/../${IMPL}_stdout.txt 2> $RD/../${IMPL}_stderr.txt
echo $? > $RD/../${IMPL}_exit_code.txt
date -u +%FT%TZ > $RD/../${IMPL}_done_utc.txt
(cd $RD/out && find . -type f | sort | xargs shasum -a 256) > $RD/../${IMPL}_outputs_SHA256SUMS.txt
echo "exit=$(cat $RD/../${IMPL}_exit_code.txt)"
