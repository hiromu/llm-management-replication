# Common reader output schema (v1)

Both readers produce the same seven files in their output directory `out/`. All files are UTF-8. JSON files must parse. Every interpretive item carries a `source` locator of the form `{"doc": "<document ID from publication_packet.json>", "pdf_page": <int>, "where": "<table/column/row, section, footnote or equation>"}`. Use `null` for anything the publication does not state; never fill a missing value from memory or by calculation. Use IDs exactly as specified so the coordinator can match rows by rule.

## 1. out/claim_map.json

```json
{"paper_id": "P01",
 "claims": [
   {"claim_id": "C1",              // C1, C2, ... in the order the paper states them
    "type": "hypothesis | stated_finding | robustness_claim | descriptive_claim",
    "statement": "verbatim or close paraphrase (<= 40 words)",
    "hypothesis_label": "H1 | H2 | ... | null",
    "predicted_direction": "positive | negative | nonzero | specific pattern (describe) | null",
    "estimand": "the parameter or contrast the claim concerns, e.g. coefficient on X in model M; marginal effect; predicted probability difference",
    "population": "units, period and sample the claim concerns",
    "scale": "log-odds coefficient | odds ratio | probability | other (describe)",
    "tier": "focal | identification_inference_diagnostic | robustness | descriptive | nuisance_control",
    "supporting_results": ["T1", "T2"],   // target_ids from targets file
    "paper_reports_supported": "yes | no | partial | not stated",
    "source": [ {"doc": "...", "pdf_page": 0, "where": "..."} ] }
 ],
 "focal_claims_rationale": "why the focal claims are focal, with sources"}
```

## 2. out/targets_sealed.json (sealed; never shown to implementers)

One row per published number used to judge a claim (coefficients and their published uncertainty, model N, fit statistics, and any reported predicted probabilities or marginal effects that a claim relies on). Descriptive statistics may be included with `tier: "descriptive"`.

```json
{"targets": [
  {"target_id": "T1",
   "table_or_figure": "Table k / Figure k / text",
   "model_label": "as printed, e.g. Model 3",
   "row_label": "as printed",
   "quantity": "coefficient | standard_error | z | p | odds_ratio | N | log_likelihood | chi2 | pseudo_R2 | predicted_probability | marginal_effect | mean | sd | other",
   "value_as_printed": "string exactly as printed, including sign and decimals",
   "value": 0.0,                    // numeric parse or null
   "decimals_printed": 3,
   "published_se": null,            // numeric if the paper prints an SE for this estimate
   "se_type_as_described": "e.g. robust clustered by game | not stated",
   "exact_p": null,                 // only if the paper prints an exact p
   "stars_or_inequality": "e.g. ** / p < 0.01 / none printed",
   "alpha_convention": "the paper's significance key, verbatim",
   "tail": "one-tailed | two-tailed | not stated",
   "hypothesized_direction": "positive | negative | none",
   "N": null,
   "claim_ids": ["C1"],
   "source": {"doc": "...", "pdf_page": 0, "where": "..."} }
 ],
 "notes": "anything about printing, rounding or legibility"}
```

No-star entries are not exact p-values. Do not convert stars into p-values.

## 3. out/manifest.json (target-free implementation manifest)

This file goes to implementers who never see the paper. It must contain no published estimates, standard errors, p-values, sample sizes, counts or percentages from the paper, and no paper title, author names, journal, year of publication or verbatim distinctive sentences. Refer to the paper only as `P01`. Published sample sizes and counts go only in `sealed_N_branch` (point 3b), which is held back from implementers.

```json
{"paper_id": "P01",
 "data_sources": [ {"source_key": "registry file key or description", "role": "what it supplies", "fallback_if_unavailable": "..."} ],
 "unit_of_observation": "...",
 "sample_steps": [ {"step": 1, "rule": "precise, executable rule", "variables_used": ["registry column names where identifiable"], "source": {...}, "certainty": "explicit | inferred | unclear"} ],
 "variables": [ {"name": "short_snake_case", "role": "dependent | focal | moderator | interaction | control | fixed_effect | weight | cluster", "definition": "precise construction, including timing, sign convention, units and transformations", "registry_columns": ["..."], "coding": "...", "source": {...}, "certainty": "explicit | inferred | unclear"} ],
 "models": [ {"model_id": "M1", "label_in_paper": "e.g. Model 3 of Table k (label only; no numbers)", "dependent": "...", "regressors": ["ordered list including interactions"], "fixed_effects": ["..."], "estimator": "e.g. logit (ML)", "link": "...", "covariance": "e.g. cluster-robust by X | conventional | not stated", "cluster_variable": null, "software_as_stated": "... | not stated", "software_defaults_relevant": "...", "missing_data_rule": "...", "post_estimation": "any predicted probabilities, marginal effects, or tests to compute, with the evaluation points defined in words", "source": {...}} ],
 "inference": {"observation_unit": "...", "sampling_unit": "...", "assignment_unit_of_focal_variables": "...", "clusters": "...", "native_se_method": "...", "test_tail_and_direction": "...", "alpha": "..."},
 "estimation_order": ["M1", "M2"],
 "open_questions": ["items the paper leaves undetermined that an implementer must not guess silently"]}
```

### 3b. out/sealed_N_branch.json (sealed; machine-evaluated, never shown to implementers)

```json
{"N_targets": [ {"what": "e.g. original fourth-down plays, analysis sample, games, model N", "value": 0, "source": {...}} ],
 "count_targets": [ {"what": "counts or percentages of sample-construction steps", "value": 0, "source": {...}} ]}
```

## 4. out/spec_space.json

```json
{"origin": {"description": "the closest-described specification, by model_id and choices", "source": [...]},
 "axes": [
   {"axis_id": "A1",
    "decision": "the open analytic decision",
    "priority_class": "sample_construction | variable_coding | fixed_effects_clustering | estimator | other",
    "levels": [
      {"level_id": "A1.0", "description": "origin level", "is_origin": true, "source": {...}},
      {"level_id": "A1.1", "description": "...", "is_origin": false,
       "label": "equivalent | non_equivalent | uncertain",
       "rationale": "why; cite the article page or a named methodological source (author, year, title)",
       "basis": "article | methodological_literature | both"}
    ],
    "compatible_with": ["axes it can be crossed with; or 'all'"],
    "notes": "..."}
 ],
 "fixed_not_varied": ["explicitly reported choices that must not vary (e.g. explicit control lists)"],
 "excluded_alternatives": [ {"description": "...", "why_excluded": "..."} ]}
```

Alternatives need an article or methodological-literature basis. Do not invent alternatives to reach a count. Explicit control lists cannot change within the equivalent set. Distinct reported outcomes are not interchangeable specifications.

## 5. out/documentation_assessment.json

```json
{"wider_space": [ {"choice": "...", "frequency_in_field": "default | common | rare", "justified_in_paper": "justified | unjustified | not discussed", "source": {...}} ],
 "structural_counts": {"n_models_reported": 0, "n_axes_identified": 0, "n_levels_total": 0},
 "unusualness_rating": "1 (very standard) to 5 (very unusual), with rationale",
 "documentation_scores": {"specificity": "1-5 + rationale", "precision": "1-5 + rationale", "exhaustiveness": "1-5 + rationale"},
 "unavailable_source_fallbacks": [ {"item": "...", "fallback": "...", "vintage_issue": "..."} ]}
```

These describe documented choices; they never decide a replication verdict.

## 6. out/forensics.json (sealed; publication record only)

```json
{"checks": [ {"check_id": "F1", "what": "e.g. coefficient/SE consistent with printed stars; N consistent across tables; table identities", "inputs": ["target_ids"], "calculation": "...", "rounding_interval_used": "...", "result": "consistent | inconsistent | cannot_assess", "note": "..."} ]}
```

Use whole rounding intervals before calling anything inconsistent.

## 7. out/reader_notes.md

Contradictions within the publication or between article and supplements, missing appendices or redaction gaps, questions for the coordinator about missing inputs, and limitations. List any data or code embedded in the publication.
