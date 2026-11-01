# Independent reader assignment

You are an independent reader in a replication study. Work only from the files in this directory. Do not use the web, do not consult memory of results to correct or fill values, and do not contact anyone. Another reader works separately; you will not see their work and they will not see yours.

Inputs in this directory
- packet/publication_packet.json: the frozen publication packet (document IDs, hashes, gaps).
- packet/P1_main_article.pdf and packet/P1_main_article_text_layout.txt: the main article (PDF is authoritative; the text file has page markers "PDF page N of 26" for convenience). Cite doc_id and PDF page for everything.
- rules/reader_rules.md: the reader-stage workflow rules and supplement rules you must follow.
- rules/reader_output_schema.json: the required output files and fields.
- sources/source_description.md and sources/dictionaries/: newly prepared, summary-free descriptions and dictionaries of the original public source data that will be used (variable names, labels, value labels, missing codes, question wording). They contain no data values or summaries. Use them to map article measures to source variables in manifest.json.

Task
Produce, in the directory out/, every file defined in rules/reader_output_schema.json: claim_map.json, targets.json, manifest.json, published_N_branch.json, spec_space.json, documentation_assessment.json, inference.json, forensics.json and reader_notes.md.

Requirements
1. Claim map: every hypothesis and stated finding, with tier (focal, identification/inference diagnostic, robustness, descriptive, nuisance control), estimand, effect scale and null value, population and supporting table/column/row.
2. Targets: transcribe every published number needed to evaluate the claims (including means, SDs, effect sizes, test results, Ns), exactly as printed, with locators. Missing values stay null. Absence of stars is not an exact p value.
3. Manifest: target-free and identity-free (use opaque id PAPER_X; no title, authors, journal, published numbers, published Ns or result directions). Give ordered sample steps, exact source variable names per year and questionnaire form from the dictionaries, coding and reverse-coding, construct scoring, missing-data rules, weights, estimator formulas (including the exact effect-size formula and sign convention), inference and outputs. Where the article does not determine a choice, mark it as an open decision and reference its spec_space axis. Put published Ns only in published_N_branch.json.
4. Specification space: axes and levels only for genuine open decisions, with a closest-described origin. Label each level equivalent, non_equivalent or uncertain, with a rationale and an article or methodological-literature source. Prioritize sample construction and variable coding, then weighting/clustering, then estimator. Do not invent alternatives to reach a count. Explicitly reported items cannot be swapped within the equivalent set.
5. Documentation assessment, inference fields and forensic checks on the published record only (for example whether printed effect sizes are consistent with printed means and SDs, using whole rounding intervals before calling anything inconsistent). Do not estimate anything from raw data; you have none.
6. reader_notes.md: contradictions, missing appendices or supplements, ambiguities, and questions for the coordinator about missing inputs.

Write valid JSON. Preserve your first complete output; do not revise after writing unless a file is invalid JSON. When finished, print a one-paragraph summary of what you produced.
