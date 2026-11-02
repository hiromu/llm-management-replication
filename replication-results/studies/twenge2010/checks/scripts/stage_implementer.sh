#!/bin/zsh
# Stage one implementer's frozen inputs in a neutral directory.
# usage (from the study root): zsh checks/scripts/stage_implementer.sh <tag> <R|PY>; prints the staging dir
set -e
d=$(mktemp -d "${TMPDIR:-/tmp}/role_$1_XXXXXX")
mkdir -p $d/data $d/dictionaries $d/code $d/results
cp implementation/manifest/manifest_v1.md $d/MANIFEST.md
cp implementation/manifest/implementer_prompt_template.md $d/PROMPT.md
if [[ $2 == R ]]; then cp implementation/manifest/software/SOFTWARE_R.md $d/SOFTWARE.md; else cp implementation/manifest/software/SOFTWARE_PY.md $d/SOFTWARE.md; fi
while IFS=: read key src; do
  cp data/derived/extracts/$src.csv.gz $d/data/$key.csv.gz
  cp data/derived/dictionaries/$src.dictionary.md $d/dictionaries/$key.dictionary.md
  cp data/derived/dictionaries/$src.dictionary.json $d/dictionaries/$key.dictionary.json
done < implementation/manifest/data_key_map.txt
echo $d
