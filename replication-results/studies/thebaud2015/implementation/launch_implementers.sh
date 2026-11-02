#!/bin/zsh
# Launch implementers A (Fable, R), B (Astra, R) and C (Fable, Julia) from opaque staging directories.
set -u
IMPL=${0:A:h}
CLAUDE=~/.local/bin/claude
CODEX=~/.local/bin/codex
VERSION=${1:-v1}

stage() {
  local d=$1 lang=$2
  mkdir -p $d/synthetic
  cp $IMPL/role_prompts/MANIFEST.md $d/MANIFEST.md
  cp $IMPL/role_prompts/implementer_assignment.md $d/ASSIGNMENT.md
  cp $IMPL/role_prompts/LANGUAGE_$lang.txt $d/LANGUAGE.txt
  cp $IMPL/synthetic/data/* $d/synthetic/
  (cd $d && find . -type f -exec shasum -a 256 {} \; | sort -k2 > input_hashes.txt)
}

A=${TMPDIR}role_$(openssl rand -hex 4); stage $A R
B=${TMPDIR}role_$(openssl rand -hex 4); stage $B R
C=${TMPDIR}role_$(openssl rand -hex 4); stage $C Julia
PROMPT="Read ASSIGNMENT.md in the current directory and carry it out completely. All inputs are in this directory."

run_claude() {
  local d=$1 interp=$2
  cd $d
  date -u +%FT%TZ > start.txt
  $CLAUDE -p --safe-mode --model claude-fable-5-1 --effort high \
    --settings '{"fastMode":false,"autoMemoryEnabled":false}' --no-session-persistence \
    --tools "Read,Write,Edit,Glob,Grep,Bash" \
    --allowed-tools "Read,Write,Edit,Glob,Grep,Bash($interp:*)" \
    --permission-mode acceptEdits --output-format json "$PROMPT" < /dev/null > run.json 2> err.txt
  echo $? > exit.txt
  date -u +%FT%TZ > end.txt
}

( run_claude $A /opt/homebrew/bin/Rscript ) &
( cd $B; date -u +%FT%TZ > start.txt
  $CODEX exec --ephemeral --ignore-user-config --skip-git-repo-check -C $B -m gpt-6-astra \
    -c 'model_reasoning_effort="high"' -c 'service_tier="default"' -c 'features.fast_mode=false' \
    -s workspace-write -o last.txt "$PROMPT" < /dev/null > run.txt 2> err.txt
  echo $? > exit.txt; date -u +%FT%TZ > end.txt ) &
( run_claude $C ~/.juliaup/bin/julia ) &
wait

for pair in "A:$A" "B:$B" "C:$C"; do
  name=${pair%%:*}; dir=${pair#*:}
  dest=$IMPL/impl_$name/$VERSION
  mkdir -p $dest
  rsync -a --exclude synthetic $dir/ $dest/
  echo $dir > $dest/staging_path.txt
  (cd $dest && find . -type f ! -name output_hashes.txt -exec shasum -a 256 {} \; | sort -k2 > output_hashes.txt)
done
echo done
