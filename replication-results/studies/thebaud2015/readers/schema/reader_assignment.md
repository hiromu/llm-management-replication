# Independent reader assignment

You are one of two independent readers in a replication study. Another reader, from a different model family, receives exactly the same files and instructions. You will not see their work and they will not see yours. Work only with the files in this folder. Do not use the web, other folders, or memory of the article's results. Do not fit models or compute anything from data. You have no data, only documents.

## Inputs in this folder

- packet/MAIN.pdf: the main article (document ID MAIN).
- packet/S1.pdf: the article's online supplement (document ID S1).
- packet/MAIN.paged.txt and packet/S1.paged.txt: text extractions of the same PDFs with markers "===== MAIN PDF page N =====". Use them for searching, and check tables against the PDFs where the layout text is ambiguous. Cite the PDF page number.
- packet/publication_packet.json: identity, hashes and known gaps of the packet.
- rules/reader_rules.md: the reader-stage rules (from the study workflow and supplement rules).
- rules/reader_output_schema.md: the exact output files and fields you must write.
- sources/: source descriptions and summary-free dictionaries for the data that are available to the implementers, including variable names and codes. Use the source keys and variable names from these files in your manifest wherever possible. They contain no observed values.

## Task

1. Read MAIN and S1 completely, including tables, table notes, footnotes and appendix tables.
2. Write the seven files defined in rules/reader_output_schema.md into output/. Follow the schema exactly.
3. The manifest must be target-free: no article identity, no published numbers of any kind except in its sealed_n_branch field.
4. Where the article is silent or ambiguous, say so and mark the item as unclear. Label alternative readings as equivalent, uncertain or non_equivalent only with a stated article or methodological basis.
5. When a variable the article uses cannot be built from the listed sources, record it in the manifest's unavailable_or_unclear list and propose a sourced fallback in documentation_assessment.json. Do not invent data.
6. Report contradictions between MAIN and S1 and any gaps in reader_notes.md.

Your first complete output is preserved as written. Write all seven files before finishing. End with a one-paragraph summary of what you wrote.
