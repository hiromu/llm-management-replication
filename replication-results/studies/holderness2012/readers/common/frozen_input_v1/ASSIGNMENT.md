# Independent reader assignment

You are one of two independent readers of a published empirical article. Another reader, using a different model, receives exactly the same inputs; you will never see each other's work. Work only from the files in this folder. Do not use the internet. Do not fit models or look at any data values (you have none). Do not rely on memory of this article or of its reported numbers; if you recall something, do not use it, and do not silently correct printed values from memory.

Opaque paper ID for the manifest: P-R7M2

## Inputs in this folder

- packet/publication_packet.json: the frozen publication packet (document IDs, hashes, gaps).
- packet/D1_main_article.pdf: the main article (doc_id D1). PDF page 1 is a repository cover page; the article starts on PDF page 2.
- packet/D1_pages/page-NN.png: page images of D1 (NN = PDF page). Tables in the OCR text are scrambled; use the page images as authoritative for tables and equations.
- packet/D1_text_layout.txt: OCR text extraction of D1 (imperfect).
- packet/S*: any supplements listed in the packet (none if the packet lists none).
- rules/reader_rules.md: the reader-stage workflow rules and supplement rules.
- rules/reader_output_schema_v1.md: the required output files and fields.
- sources/source_descriptions.md and sources/data_dictionary_*.csv (and code-list CSVs): descriptions of the publicly available source data newly acquired for this study. They contain definitions and codes only, no data values or statistics. Write the manifest's construction rules in terms of these fields and codes. Where the article's description cannot be mapped to available fields, record that as an ambiguity or unavailable item rather than guessing silently.

## Task

Produce all eight outputs defined in rules/reader_output_schema_v1.md in the output/ folder: claim_map.json, targets_sealed.json, manifest.json, specification_space.json, wider_space_assessment.json, inference_and_documentation.json, forensics_sealed.json, limitations.md.

Requirements:
- Cite doc_id and PDF page (and table/section) for every claim, target, manifest item and specification choice.
- Transcribe every published number in the article's results tables and the numeric results stated in the text into targets_sealed.json, as printed. Missing values stay missing. Mark OCR-uncertain values and check them against the page images.
- The manifest must be target-free and identity-free as the schema states.
- Identify genuine open analytic decisions and label alternatives as equivalent, non-equivalent or uncertain, each with an article or methodological-literature basis. Do not invent alternatives to reach a count.
- Record contradictions between text and tables, missing appendices, unreported analyses and documentation gaps in limitations.md.
- Validate that every JSON file parses before finishing. Your first complete set of outputs is final for this round.
