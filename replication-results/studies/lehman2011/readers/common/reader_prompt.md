# Independent reader assignment

You are one of two independent readers for a single-paper replication study. Another reader from a different model family receives these same inputs. You will not see their work, and they will not see yours. Work only from the files in this directory. Do not use the internet, do not look outside this directory, and do not fit any model or open any raw data (none is provided).

## Inputs (all in this directory)

- packet/publication_packet.json: the frozen publication packet. It lists the documents, their IDs, hashes and known gaps.
- packet/docs/: the article PDF. packet/text/pages/: a page-by-page plain-text extraction (file suffix _pNN = PDF page NN). Tables can be garbled in the text extraction, so check numbers against the PDF page itself.
- rules/reader_rules.md: the rules for the reader stage and for using supplements.
- schema/reader_output_schema.md: the required output files and fields. Follow it exactly.
- data_description/: descriptions of the public source datasets that will be acquired for the replication, and a summary-free data dictionary. Use these to map the paper's variables to source columns in the manifest. They describe public sources acquired independently of the paper; the paper's authors may have used a different vintage or provider.

## Task

Read the article and every document in the packet. Then produce the seven output files described in the schema in out/: claim_map.json, targets_sealed.json, manifest.json, sealed_N_branch.json, spec_space.json, documentation_assessment.json, forensics.json and reader_notes.md.

- Source every interpretation with the document ID, PDF page and table, section or footnote.
- Keep the manifest target-free. It must contain no published estimates, standard errors, p-values, sample sizes, counts or percentages, and must not identify the paper (no title, authors, journal or year). Published sample sizes and counts belong only in sealed_N_branch.json.
- Write the manifest so that an analyst who has never seen the paper could build the sample and fit every reported model from the public data described in data_description/. Where the paper is silent or ambiguous, say so in `certainty` and `open_questions`; do not guess silently.
- Specification alternatives need a basis in the article or the methodological literature. Label each as equivalent, non_equivalent or uncertain, with a rationale. Do not invent alternatives to reach a quota. Explicit control lists may not change within the equivalent set.
- Missing values stay missing. Do not correct or fill article values from memory.
- Forensic checks use only the published record. Use whole rounding intervals before declaring an inconsistency.
- If an input you need is missing, record the question in out/reader_notes.md and carry on with what you have.

Your first complete set of outputs is preserved as your submission. When all eight files are written and valid, stop and reply with a one-paragraph summary of what you produced.
