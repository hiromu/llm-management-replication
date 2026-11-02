#!/bin/zsh
# Launch both independent readers from opaque staging directories with identical inputs.
set -u
STUDY=${0:A:h:h}
ROOT=${STUDY:h:h}
CLAUDE=~/.local/bin/claude
CODEX=~/.local/bin/codex

stage() {
  local d=$1
  mkdir -p $d/packet $d/rules $d/sources $d/output
  cp $ROOT/papers/journal_collection/ASQ/ASQ_2015_Thebaud.pdf $d/packet/MAIN.pdf
  cp $ROOT/papers/supplements/ASQ/ASQ_2015_Thebaud_S1.pdf $d/packet/S1.pdf
  cp $STUDY/sources/text/MAIN.paged.txt $STUDY/sources/text/S1.paged.txt $STUDY/sources/publication_packet.json $d/packet/
  cp $STUDY/readers/schema/reader_rules.md $d/rules/
  cp $STUDY/readers/schema/reader_output_schema.md $d/rules/
  cp $STUDY/readers/schema/reader_assignment.md $d/ASSIGNMENT.md
  cp $STUDY/registry/reader_dictionaries/*.md $d/sources/
  (cd $d && find packet rules sources ASSIGNMENT.md -type f -exec shasum -a 256 {} \; | sort -k2 > input_hashes.txt)
}

A=${TMPDIR}role_$(openssl rand -hex 4)
B=${TMPDIR}role_$(openssl rand -hex 4)
stage $A; stage $B
PROMPT="Read ASSIGNMENT.md in the current directory and carry it out completely. All inputs are in this directory. Write your outputs to output/."

(
  cd $A
  date -u +%FT%TZ > start.txt
  $CLAUDE -p --safe-mode --model claude-fable-5-1 --effort high \
    --settings '{"fastMode":false,"autoMemoryEnabled":false}' --no-session-persistence \
    --tools "Read,Write,Edit,Glob,Grep" --allowed-tools "Read,Write,Edit,Glob,Grep" \
    --permission-mode acceptEdits --output-format json "$PROMPT" < /dev/null > run.json 2> err.txt
  echo $? > exit.txt
  date -u +%FT%TZ > end.txt
) &
(
  cd $B
  date -u +%FT%TZ > start.txt
  $CODEX exec --ephemeral --ignore-user-config --skip-git-repo-check -C $B -m gpt-6-astra \
    -c 'model_reasoning_effort="high"' -c 'service_tier="default"' -c 'features.fast_mode=false' \
    -s workspace-write -o last.txt "$PROMPT" < /dev/null > run.txt 2> err.txt
  echo $? > exit.txt
  date -u +%FT%TZ > end.txt
) &
wait

for pair in "fable:$A" "astra:$B"; do
  name=${pair%%:*}; dir=${pair#*:}
  dest=$STUDY/readers/$name/initial_v1
  mkdir -p $dest
  cp -R $dir/output $dest/
  cp $dir/input_hashes.txt $dir/start.txt $dir/end.txt $dir/exit.txt $dir/err.txt $dest/
  [ -f $dir/run.json ] && cp $dir/run.json $dest/
  [ -f $dir/run.txt ] && cp $dir/run.txt $dest/
  [ -f $dir/last.txt ] && cp $dir/last.txt $dest/
  echo $dir > $dest/staging_path.txt
  (cd $dest && find . -type f ! -name output_hashes.txt -exec shasum -a 256 {} \; | sort -k2 > output_hashes.txt)
done
echo done
