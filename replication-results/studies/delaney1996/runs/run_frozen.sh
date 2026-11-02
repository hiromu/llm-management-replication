#!/bin/zsh
# Frozen execution of one implementation under sandbox-exec (network denied; writes limited to the output dir and temp).
# Usage: zsh runs/run_frozen.sh <run_dir> <impl_label> <interpreter> <script_relpath>
set -e
RUN=$1; L=$2; INTERP=$3; SCRIPT=$4
ABS=$(cd $RUN && pwd -P)
PROFILE=$ABS/sandbox_$L.sb
cat > $PROFILE <<SB
(version 1)
(allow default)
(deny network*)
(deny file-write*)
(allow file-write* (subpath "$ABS/out_$L") (subpath "/private/var/folders") (subpath "/private/tmp") (literal "/dev/null") (literal "/dev/stdout") (literal "/dev/stderr"))
SB
mkdir -p $ABS/out_$L
date -u +%Y-%m-%dT%H:%M:%SZ > $ABS/out_$L/_start_utc.txt
set +e
sandbox-exec -f $PROFILE $INTERP $ABS/code_$L/$SCRIPT --data $ABS/inputs/survey.csv --metadata $ABS/inputs/survey_metadata.json --crosswalk $ABS/inputs/industry_crosswalk.csv --grid $ABS/inputs/grid_v1.json --out $ABS/out_$L > $ABS/out_$L/_stdout.txt 2> $ABS/out_$L/_stderr.txt
echo $? > $ABS/out_$L/_exit_code.txt
date -u +%Y-%m-%dT%H:%M:%SZ > $ABS/out_$L/_end_utc.txt
