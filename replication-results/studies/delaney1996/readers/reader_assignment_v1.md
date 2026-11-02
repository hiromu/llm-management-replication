# Independent reader assignment

You are one of two independent readers in a replication project. Another reader, from a different model family, receives exactly the same inputs. You will never see the other reader's work, and nobody will tell you about any analysis results.

## Inputs in this working directory

- `packet/`: the frozen publication packet. `publication_packet.json` describes it. D1 is the primary copy of the article (journal print scan; its text layer is clipped at the right margin, so read tables from the page images `D1_article_library_pNN.png` or the PDF). D2 is an author-hosted retypeset copy of the same article. No supplement, appendix or correction was found after a documented search.
- `source/`: a source description and a summary-free data dictionary for the public survey file that will be used (variable names, labels, question wording, value codes, missing codes). It contains no data values or statistics.
- `rules/`: `supplements.md`, `workflow_reader_stage.md` and `reader.md` (the general rules for readers).
- `reader_schema_v1.md`: the frozen output schema. Follow it exactly.

## Task

Read the whole article (both copies; D1 governs locators) and the rules, then write the eight output files defined in `reader_schema_v1.md` into `output/`.

1. Claim map: every hypothesis and stated finding, with tier and estimand. Propose the focal claim designation and an aggregation rule from the article itself.
2. Sealed targets: every printed coefficient, SE, star level, R2, F, delta-R2, joint F and N in the regression tables, with exact printed text. Descriptive table values only as descriptive targets.
3. Target-free implementation manifest: ordered sample steps, variable construction mapped to dictionary variable names, models, estimator, inference and missingness, so that an analyst who has never seen the article could implement every reported model from the survey file. Where the article is silent or ambiguous, say so in `ambiguities` / `unresolved_items` and add a specification axis, rather than guessing.
4. Specification space with sourced labels (origin, equivalent, non_equivalent, uncertain). Prioritise sample construction and variable coding, then industry effects/clustering, then estimator.
5. Wider space and documentation assessment.
6. Inference fields.
7. Forensic checks of the published record (coefficient/SE/star consistency under the stated one-tailed rule, N and df, D1 versus D2 transcription, text versus tables). Use whole rounding intervals.
8. Notes and questions.

## Rules

- Use only the files in this directory. No web access. Do not use memory of this article or of other analyses of it to fill gaps or correct values; if something is not in the packet, mark it missing.
- Do not estimate anything from data (you have none). Do not choose an interpretation because it would make numbers agree.
- Cite `doc_id` and PDF page for every interpretation.
- Keep published numbers out of `manifest.json` and `spec_space.json`.
- Your first complete set of outputs is final for the initial round; it will be hashed and preserved.
- When finished, write `output/DONE.txt` containing a list of the files you wrote.
