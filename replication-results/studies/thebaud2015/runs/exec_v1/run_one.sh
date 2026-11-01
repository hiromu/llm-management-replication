#!/bin/zsh
# Usage: run_one.sh <impl A|B|C> <run_ids> <out_subdir>
set -u
STUDY=${0:A:h:h:h}
cd $STUDY
impl=$1; ids=$2; out=runs/exec_v1/$3
mkdir -p $out
case $impl in
  A|B) cmd=(/opt/homebrew/bin/Rscript implementation/impl_$impl/v1/run.R) ;;
  C) cmd=(~/.juliaup/bin/julia implementation/impl_C/v1/run.jl) ;;
esac
date -u +%FT%TZ > $out/start.txt
/usr/bin/time -p sandbox-exec -f runs/isolation_test/nonet.sb $cmd data/derived $out $ids > $out/log.txt 2>&1
echo $? > $out/exit.txt
date -u +%FT%TZ > $out/end.txt
shasum -a 256 $out/* > $out/hashes.txt 2>/dev/null
