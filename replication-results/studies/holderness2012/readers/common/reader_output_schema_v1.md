# Reader output schema, version 1

Common to both independent readers. Write every file below into the output/ directory of your working folder. Use UTF-8 JSON (2-space indent) unless a Markdown file is specified. Every interpretation must carry at least one source locator.

## Source locator object

{"doc_id": "D1" (main article) or "S<n>" (supplement), "pdf_page": integer page of the PDF file, "journal_page": printed page number or null, "section": string or null, "table": string or null, "column": string or null, "row": string or null, "quote": verbatim excerpt of at most 25 words or null}

## 1. claim_map.json

{"claims": [ {
  "claim_id": "C01", ...
  "statement": the claim or stated finding in your words,
  "hypothesis_or_direction": stated expected or reported sign/direction, or null,
  "tier": one of "focal", "identification_inference_diagnostic", "robustness", "descriptive", "nuisance_control",
  "reported_status": "reported_with_numbers" | "reported_in_text_only" | "unreported_described",
  "estimand": what quantity is estimated (e.g. scale of coefficient, marginal-effect definition),
  "population": population and sample described,
  "unit_of_analysis": observation unit,
  "scale": units/scaling of outcome and key regressor,
  "model_ids": ids of models in manifest.json supporting the claim,
  "locators": [locator, ...],
  "notes": string } ],
  "focal_claim_rationale": why the focal claims are focal, with locators,
  "paper_level_aggregation_proposal": how claim outcomes should combine into a paper-level outcome, from the article's own emphasis }

## 2. targets_sealed.json

Published numbers only. This file is sealed from implementers.

{"targets": [ {
  "target_id": "T001", "claim_id": "C..", "model_id": "M..",
  "table": , "column": , "row": ,
  "quantity": "coefficient" | "marginal_effect" | "se" | "p_value" | "pseudo_r2" | "n" | "summary_statistic" | "test_statistic" | "other",
  "value_as_printed": string exactly as printed,
  "value_numeric": number or null,
  "printed_decimals": integer or null,
  "published_se": number or null (null if not printed),
  "exact_p": number or null (only if a p value is printed),
  "p_printed_as": string or null,
  "stars_or_inequality": string or null (no-star entries are not exact p values),
  "alpha": number or null, "tail": "two" | "one" | "unknown", "direction": "+" | "-" | null,
  "n": integer or null,
  "locator": locator, "ocr_uncertain": boolean, "notes": string } ],
 "n_branch": [ {"model_id": , "published_n": , "locator": , "notes": } ] }

## 3. manifest.json (target-free)

Must not contain the article's title, authors, journal, publication year, any published estimate, SE, p value, pseudo R2 or published N, or any wording that reveals them. Use the opaque paper ID supplied in the assignment. Genuine design constants stated as part of a method (for example a scaling constant inside a formula) may be included and must be flagged in leakage_flags.

{"paper_id": opaque id,
 "data_sources": [ {"source_key": key from the registry dictionaries, "role": , "fields_used": [ ] } ],
 "unit_of_observation": ,
 "sample_steps": [ {"step": 1, "description": , "rule": precise operational rule in terms of registry fields/codes, "locators": [ ], "ambiguity": string or null } ],
 "variables": [ {"name": , "role": "outcome" | "key_regressor" | "control" | "group_definition" | "fixed_effect" | "cluster" | "other", "definition": , "construction": exact operational recipe from registry fields and codes, "transformation": , "scaling": , "missing_handling": , "locators": [ ], "ambiguity": } ],
 "group_definitions": [ {"name": , "definition": , "locators": [ ] } ],
 "formulas": [ {"name": , "latex_or_text": , "inputs": , "locators": [ ] } ],
 "models": [ {"model_id": "M01", "outcome": , "key_regressors": [ ], "controls": [ ], "fixed_effects": [ ], "estimator": , "reported_quantity": e.g. marginal effects definition and evaluation point, "covariance": , "cluster_variable": , "sample": reference to sample steps, "software_defaults_needed": , "locators": [ ] } ],
 "missingness_rules": ,
 "inference_rules": {"test": , "tail": , "alpha": },
 "leakage_flags": [ {"item": , "reason": } ] }

## 4. specification_space.json

{"origin_description": the closest-described specification for each model family,
 "axes": [ {"axis_id": "A01", "decision": the open analytic decision, "priority": "sample_construction" | "variable_coding" | "fixed_effects_clustering" | "estimator" | "other",
   "levels": [ {"level_id": "A01L0", "description": , "is_origin": boolean, "label": "equivalent" | "non_equivalent" | "uncertain", "rationale": , "basis": "article" | "methodological_literature", "basis_citation_or_locator": } ] } ],
 "incompatible_crossings": [ ],
 "notes": }

Alternatives must have an article or methodological-literature basis. Explicitly reported control lists cannot be changed within the equivalent set. Distinct reported outcomes are not automatically interchangeable specifications. Do not invent alternatives to reach a count.

## 5. wider_space_assessment.json

{"choices": [ {"choice": , "classification": "default" | "common" | "rare", "justification_status": "justified" | "unjustified" | "unclear", "locators": [ ] } ],
 "structural_counts": {"documented_decisions": , "undocumented_decisions": , "axes_with_alternatives": },
 "holistic_unusualness": 1 (very conventional) to 5 (very unusual), "rationale": }

## 6. inference_and_documentation.json

{"observation_unit": , "sampling_unit": , "assignment_unit": , "cluster_units": [ ], "native_se_method": , "native_software": or null if not stated, "first_stage_strength": null or text,
 "documentation_scores": {"specificity": 0-3, "precision": 0-3, "exhaustiveness": 0-3, "rationale": },
 "unavailable_source_fallbacks": [ {"item": , "problem": , "fallback": , "label": "uncertain" | "unavailable" } ],
 "vintage_issues": [ ] }

## 7. forensics_sealed.json

Based solely on the published record. Separate from targets; sealed.

{"observations": [ {"id": , "type": "coef_se_p_consistency" | "n_df" | "table_identity" | "transformation" | "text_table_mismatch" | "other", "description": , "rounding_interval_check": , "severity": "none" | "minor" | "notable", "locators": [ ] } ] }

## 8. limitations.md

Publication contradictions (main text versus tables or supplements), missing appendices, unreported analyses the text relies on, redaction gaps, OCR-uncertain values, and questions for the coordinator about missing inputs.
