#!/bin/zsh
D=${0:A:h}; cd $D
date -u +%FT%TZ > start.txt
~/.local/bin/codex exec --ephemeral --ignore-user-config --skip-git-repo-check -C $D -m gpt-6-astra \
  -c 'model_reasoning_effort="high"' -c 'service_tier="default"' -c 'features.fast_mode=false' \
  -s workspace-write -o last.txt "Read PROMPT.md in the current directory and carry it out completely." < /dev/null > run.txt 2> err.txt
echo $? > exit.txt; date -u +%FT%TZ > end.txt
