#!/bin/zsh
set -u
IMPL=${0:A:h}; VERSION=${1:-v1}
CLAUDE=~/.local/bin/claude; CODEX=~/.local/bin/codex
PROMPT="Read ASSIGNMENT.md in the current directory and carry it out."
mk() { local d=${TMPDIR}role_$(openssl rand -hex 4); mkdir -p $d; cp $IMPL/role_prompts/MANIFEST.md $d/; cp $IMPL/role_prompts/checker_assignment.md $d/ASSIGNMENT.md; cp $IMPL/impl_$1/$VERSION/$2 $d/; echo $d; }
DA=$(mk A run.R); DB=$(mk B run.R); DC=$(mk C run.jl)
codex_check() { cd $1; date -u +%FT%TZ > start.txt; $CODEX exec --ephemeral --ignore-user-config --skip-git-repo-check -C $1 -m gpt-6-astra -c 'model_reasoning_effort="high"' -c 'service_tier="default"' -c 'features.fast_mode=false' -s workspace-write -o last.txt "$PROMPT" < /dev/null > run.txt 2> err.txt; echo $? > exit.txt; date -u +%FT%TZ > end.txt; }
( codex_check $DA ) & ( codex_check $DC ) &
( cd $DB; date -u +%FT%TZ > start.txt; $CLAUDE -p --safe-mode --model claude-fable-5-1 --effort high --settings '{"fastMode":false,"autoMemoryEnabled":false}' --no-session-persistence --tools "Read,Write,Glob,Grep" --allowed-tools "Read,Write,Glob,Grep" --permission-mode acceptEdits --output-format json "$PROMPT" < /dev/null > run.json 2> err.txt; echo $? > exit.txt; date -u +%FT%TZ > end.txt ) &
wait
for p in "A:$DA" "B:$DB" "C:$DC"; do n=${p%%:*}; d=${p#*:}; dest=$IMPL/check_$n/$VERSION; mkdir -p $dest; cp -R $d/ $dest/; echo $d > $dest/staging_path.txt; done
echo done
