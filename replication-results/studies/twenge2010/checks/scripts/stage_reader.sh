#!/bin/zsh
# Stage one reader's frozen inputs in a neutral directory.
# usage (from the study root): checks/scripts/stage_reader.sh <tag>; prints the staging dir
set -e
d=$(mktemp -d "${TMPDIR:-/tmp}/role_$1_XXXXXX")
mkdir -p $d/packet $d/rules $d/sources/dictionaries $d/out
cp ../../papers/journal_collection/JOM/JOM_2010_Twenge.pdf $d/packet/P1_main_article.pdf
cp sources/publication/P1_main_article_text_layout.txt sources/publication/publication_packet.json $d/packet/
cp readers/schema/reader_rules.md readers/schema/reader_output_schema.json $d/rules/
cp readers/packet_inputs/source_description_reader.md $d/sources/source_description.md
cp data/derived/dictionaries/*.dictionary.json data/derived/dictionaries/*.dictionary.md $d/sources/dictionaries/
cp readers/packet_inputs/dictionaries_README_reader.md $d/sources/dictionaries/README.md
cp readers/schema/reader_prompt.md $d/PROMPT.md
echo $d
