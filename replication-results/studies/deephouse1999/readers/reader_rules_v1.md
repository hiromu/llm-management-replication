# Reader rules (verbatim excerpts)

Source: instructions/workflow.md, section 2

## 2. Two independent readers
Before each reader, run a separate title-and-authors-only memorization probe and seal its answers. Do not disclose the answers or previous study results to the reader. Supply identical assignment templates, input lists and the frozen article-and-supplement packet to the two different model families. Readers must consult every permitted matching supplement and cite document IDs and PDF pages. Preserve main-text/supplement contradictions in reconciliation. Freeze the common output schema before either reader starts.

Each reader produces:

- A claim map: each hypothesis or stated finding, supporting table/column/row, estimand, population, scale and tier. Tiers distinguish focal estimates, identification/inference diagnostics, robustness, descriptives and nuisance controls.
- A sealed targets file: coefficient, published SE, exact p or stars/inequality, alpha, tail/direction, N, model and source locator. Missing values remain missing. No-star entries are not exact p values.
- A target-free implementation manifest: ordered sample steps, variable definitions, source keys, estimator, fixed effects, covariance methods, software defaults, missingness and inference fields. Include an opaque paper ID; keep published N in a machine-evaluated branch outside implementer-visible targets.
- A specification space: axes/levels for genuine open decisions, a closest-described origin, sourced equivalent/non-equivalent/uncertain labels and rationales. Prioritize sample construction and variable coding, then fixed effects/clustering, then estimator. Alternatives must have an article or methodological-literature basis. Explicit control lists cannot be changed within the equivalent set. Distinct reported outcomes are not automatically interchangeable specifications.
- A wider space and documentation assessment: default/common/rare and justified/unjustified choices, structural counts and a holistic unusualness rating. These describe the documented choices and never determine a replication verdict. The wider grid is off unless explicitly included before execution.
- Inference fields: observation/sampling/assignment units, clusters, native SE method/software, first-stage strength where applicable; documentation scores for specificity, precision and exhaustiveness; item-specific unavailable-source and vintage fallbacks.
- Forensic observations based solely on the published record: consistency of coefficient/SE/test statistic/p/stars, N/df, table identities and transformations. Use whole rounding intervals before declaring an internal mismatch. Forensic findings are separate records, not automatic verdicts. Any published-table algebra is a sealed publication diagnostic, not analysis of registry data.

No reader estimates models from raw data or chooses an interpretation by numerical agreement. Preserve the first complete outputs and hashes before any coordinator feedback.


Source: instructions/supplements.md

## Article supplements

## Find and verify the publication packet

For the active study, read STUDY.json and match its paper_id against papers/supplements/catalog.json. Paths in that catalog are relative to the project root. Include every matching prepared supplement, in supplement-ID order, with the main article. Verify identity using title, authors, DOI and appendix references, check file hashes, and record preparation/redaction status. The catalog describes supplied documents, not a completed study audit or a guarantee of completeness.

After research is authorized, check the article and publisher for additional supplements, appendices, corrections or replacement versions. A missing local entry means only no local match, not no supplement exists. Record found, unavailable, not found after documented search, excluded author code, and uncertain identity separately. Obtain missing permitted documentary material into the active study's sources/supplements/ directory, with provenance. Do not search other projects or study outputs.

Supplied article and supplement PDFs are an explicit exception to the fresh-download requirement for documentary material. All empirical datasets, data dictionaries and independent supporting source records must still be acquired afresh. Local supplement PDFs are read-only; create new text extractions inside the active study.

## Permitted use and package eligibility

Use supplemental prose, equations, variable definitions, sample rules, appendix tables and robustness descriptions as publication evidence. Numerical results are sealed comparison targets or publication diagnostics. Do not use printed observations, correlation matrices or author datasets as empirical inputs. Do not execute, translate, reconstruct or copy author replication code. Independently implement the documented methods through the target-free manifest.

The prepared library has code and code-link removals recorded in its catalog. Excluded code-only files are listed without supplying the code. Preparation does not prove that every remaining document is code-free or complete. Record missing methods caused by removals; do not infer what removed code contained. Any remaining code or links discovered in a supplied file must be excluded from role inputs and logged.

A documentary appendix is not automatically a replication package. Conversely, removing code or a link from a reading copy does not remove evidence of a publicly available author replication package. Apply CLAUDE.md's package-selection rule independently, and stop for user direction if such a package is established. A catalog preparation flag is a reason to investigate eligibility, not a definitive package classification.

## Independent readers and downstream access

Before the initial readers run, freeze publication_packet.json inside the active study. List the main article and each permitted supplement, hashes, order, versions, identity checks, redactions and known gaps. Both readers receive the identical packet, the supplement rules and the same target-free source descriptions; neither sees the other's interpretation. Each reader must cite the document or supplement ID, PDF page and table/section for claims and choices. Report contradictions between main text and supplements; the coordinator must not silently privilege one source or resolve disagreement using empirical agreement.

Late documentary additions require a versioned packet and the same independent rereading opportunity for both readers before refreezing. Preserve initial outputs and initial-agreement statistics. If discovered after fitting, freeze the existing run and describe any new analysis as a separately versioned amendment; do not send numerical feedback upstream.

Implementers and pre-execution checkers never receive the publication packet. They use the reconciled target-free manifest under the existing role restrictions. The scorer receives sealed publication targets downstream. Reports identify the supplements used, unavailable or excluded, document versions, cited locations, contradictions and limitations caused by redactions. This applies to one active paper only.

Source: prompts/reader.md

## Independent reader assignment

Read the assigned main article and every permitted supplement in the frozen publication packet, instructions/supplements.md, instructions/workflow.md reader-stage rules, the coordinator's frozen output schema, and newly prepared source descriptions and summary-free dictionaries. Produce the claim map, sealed targets, target-free manifest, sourced specification axes/labels, documentation assessment and limitations required by those rules.

Do not access raw registry data, other readers, prior studies, results or scoring criteria. Do not fit models. Published-table forensic calculations, if requested, remain separate from raw-data estimation and are sealed with targets. Source every interpretation with document/supplement ID and PDF page/table references. Identify publication contradictions, missing appendices and redaction gaps. Do not reconstruct removed author code or infer that no local supplement means none exists. Do not invent alternatives to meet a quota or silently correct article values using memory. Preserve your first complete response and ask the coordinator about missing inputs without contacting another reader.
