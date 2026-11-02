# Article supplements

## Find and verify the publication packet

For the active study, read STUDY.json and match its paper_id against papers/supplements/catalog.json. Paths in that catalog are relative to the project root. Include every matching prepared supplement, in supplement-ID order, with the main article. Verify identity using title, authors, DOI and appendix references, check file hashes, and record preparation/redaction status. The catalog describes supplied documents, not a completed study audit or a guarantee of completeness.

After research is authorized, check the article and publisher for additional supplements, appendices, corrections or replacement versions. A missing local entry means only no local match, not no supplement exists. Record found, unavailable, not found after documented search, excluded author code, and uncertain identity separately. Obtain missing permitted documentary material into the active study's sources/supplements/ directory, with provenance. Do not search other projects or study outputs.

Supplied article and supplement PDFs are an explicit exception to the fresh-download requirement for documentary material. Empirical datasets, data dictionaries and independent supporting source records must be acquired afresh except explicitly authorized user-supplied bundles under supplied_sources.md. Supplied bundles still require independent validation. Local supplement PDFs are read-only; create new text extractions inside the active study.

## Permitted use and package eligibility

Use supplemental prose, equations, variable definitions, sample rules, appendix tables and robustness descriptions as publication evidence. Numerical results are sealed comparison targets or publication diagnostics. Do not use printed observations, correlation matrices or author datasets as empirical inputs. Do not execute, translate, reconstruct or copy author replication code. Independently implement the documented methods through the target-free manifest.

The prepared library has code and code-link removals recorded in its catalog. Excluded code-only files are listed without supplying the code. Preparation does not prove that every remaining document is code-free or complete. Record missing methods caused by removals; do not infer what removed code contained. Any remaining code or links discovered in a supplied file must be excluded from role inputs and logged.

A documentary appendix is not automatically a replication package. Conversely, removing code or a link from a reading copy does not remove evidence of a publicly available author replication package. Apply CLAUDE.md's package-selection rule independently, and stop for user direction if such a package is established. A catalog preparation flag is a reason to investigate eligibility, not a definitive package classification.

## Independent readers and downstream access

Before the initial readers run, freeze publication_packet.json inside the active study. List the main article and each permitted supplement, hashes, order, versions, identity checks, redactions and known gaps. Both readers receive the identical packet, the supplement rules and the same target-free source descriptions; neither sees the other's interpretation. Each reader must cite the document or supplement ID, PDF page and table/section for claims and choices. Report contradictions between main text and supplements; the coordinator must not silently privilege one source or resolve disagreement using empirical agreement.

Late documentary additions require a versioned packet and the same independent rereading opportunity for both readers before refreezing. Preserve initial outputs and initial-agreement statistics. If discovered after fitting, freeze the existing run and describe any new analysis as a separately versioned amendment; do not send numerical feedback upstream.

Implementers and pre-execution checkers never receive the publication packet. They use the reconciled target-free manifest under the existing role restrictions. The scorer receives sealed publication targets downstream. Reports identify the supplements used, unavailable or excluded, document versions, cited locations, contradictions and limitations caused by redactions. This applies to one active paper only.
