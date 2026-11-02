# Independent reader assignment

You are one of two independent readers for a replication study of a single published article. Another reader from a different model family receives the identical inputs; you will not see each other's work. Work only with the files in this directory. Do not use the web or any other files on this computer.

Inputs in this directory:
- `packet/DOC01_main_article.pdf`: the main article (the only document in the frozen publication packet; no supplement exists after a documented search).
- `packet/DOC01_main_article_text_layout.txt`: text extraction of DOC01 (equation glyphs are partly garbled; check the page images).
- `packet/pages/DOC01_pNN.png`: page images of DOC01 at 150 dpi. PDF page k is printed journal page 146+k.
- `packet/publication_packet.json`: packet record, identity checks and known gaps.
- `rules/reader_rules.md`: reader-stage rules (workflow excerpt, supplement rules, reader assignment).
- `rules/reader_output_schema_v1.md`: the required output files and fields.
- `sources/source_descriptions.md` and `sources/data_dictionary.md`: descriptions and a summary-free data dictionary of newly acquired public source data. You do not get the data itself. The dictionary is large; search it rather than reading it end to end.
- `sources/call_item_candidates.json`: a non-binding list, prepared during data acquisition, of report items that could plausibly map to each balance-sheet or income concept. Choosing and justifying the mapping is your job; list alternatives where more than one mapping is defensible.

Task. Read DOC01 completely and produce every file in `rules/reader_output_schema_v1.md` inside `out/`. In particular:
1. Map every hypothesis and stated finding to tables, models and rows, with tiers.
2. Transcribe published numbers as sealed targets exactly as printed (including stars, table notes, N, F tests, test statistics). Missing values stay null. No-star entries are not exact p values.
3. Write a target-free implementation manifest that an implementer who has never seen the article could code from, referring to variables by the names in `sources/data_dictionary.md`. Record each ambiguity rather than resolving it silently. Map the article's variable definitions to specific data-dictionary columns where possible, and say when the mapping is uncertain or the item is unavailable.
4. Write the specification space: the origin (closest-described specification) and genuine open decisions, prioritizing sample construction and variable coding, then fixed effects/clustering, then estimator. Label each alternative `equivalent`, `non_equivalent` or `uncertain`, with an article locator or a methodological-literature basis and rationale. Do not change explicitly reported models or control lists within the equivalent set. Do not invent alternatives to fill a quota.
5. Assess documentation and unusualness, inference fields, and forensic consistency of the published record.

Rules. Do not estimate any model from data. Do not choose an interpretation because of any numerical agreement. Do not correct article values from memory. Cite DOC01 and the PDF page (and table/section) for every interpretation. Report contradictions, missing information and questions in `out/notes.md`. When all files are written, finish with a short message listing the files you wrote.
