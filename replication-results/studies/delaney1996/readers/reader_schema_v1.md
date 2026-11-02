# Reader output schema, version 1 (frozen before either reader runs)

Write every file below into the `output/` folder of your working directory. All files are UTF-8. JSON files must parse. Use `null` for anything not printed or not determinable; never fill a value from memory. Every interpretive entry carries a `locator` object: `{"doc_id": "D1" or "D2", "pdf_page": <int>, "where": "<table/column/row or section/paragraph>"}`. Cite D1 (the primary journal copy) first; cite D2 too when it differs.

Opaque paper identifier for target-free files: `PAPER_K7`. Do not put the article title, authors, journal or year into `manifest.json` or `spec_space.json`.

## 1. output/claim_map.json

```
{"claims": [ {
  "claim_id": "C01", "statement": "...", "hypothesis": "H1|H2|none",
  "tier": "focal|identification_inference_diagnostic|robustness|descriptive|nuisance_control",
  "outcome": "...", "predictor_or_contrast": "...",
  "estimand": "e.g. OLS partial slope of outcome on X holding listed controls",
  "population": "...", "scale": "units of outcome and predictor",
  "direction": "positive|negative|none|two-sided", "tail": "one|two|unstated",
  "supporting_targets": ["T..."], "locator": {...}, "notes": "..." } ],
 "focal_claim_designation": {"claim_ids": [...], "rationale": "...", "aggregation_rule_proposal": "..."} }
```

## 2. output/targets.json (sealed; never seen by implementers)

```
{"targets": [ {
  "target_id": "T001", "claim_id": "C..", "table": "3", "model": "2", "row": "Training",
  "quantity": "coef|se|R2|F|deltaR2|F_deltaR2|N|constant|other",
  "value_printed": "0.125**", "value": 0.125, "se": 0.041,
  "stars": "**", "p_inequality": "p < .01", "alpha": 0.01, "tail": "one", "direction": "positive",
  "N": 590, "locator": {...}, "d1_d2_differ": false, "notes": "..." } ],
 "sealed_n": [ {"sample_id": "...", "N_printed": 590, "locator": {...}} ] }
```

Record every coefficient and SE printed in the regression tables, plus model statistics. Record descriptive-table values (means, SDs, correlations, item means) only as descriptive targets with `quantity: "other"` and a clear `row`/`notes`. No-star entries are not exact p values: use `p_inequality` such as `p >= .10 (one-tailed)`.

## 3. output/manifest.json (target-free; goes to implementers after reconciliation)

```
{"paper_id": "PAPER_K7",
 "data": {"source_id": "icpsr06240_ds0002", "unit": "...", "id_variable": "..."},
 "sample_steps": [ {"step": 1, "rule": "...", "source_variables": [...], "locator": {...}} ],
 "variables": [ {"var_id": "...", "construct": "...", "role": "outcome|hrm_practice|control|interaction|other",
     "source_variables": ["NOS variable names from the dictionary"], "item_coding": "...",
     "missing_value_rule": "...", "transformation": "e.g. log, z-score, mean of items",
     "scale_construction": "...", "locator": {...}, "ambiguities": "..."} ],
 "models": [ {"model_id": "...", "outcome": "var_id", "regressors": ["var_id"...],
     "controls": ["var_id"...], "industry_effects": "...", "interactions": [...],
     "estimator": "OLS|...", "weights": "...", "covariance": "...", "sample": "sample step ref",
     "statistics_to_report": ["coef","se","t","p_one_tailed","R2","F","deltaR2","F_deltaR2","N"],
     "locator": {...}} ],
 "inference": {"tail_rule": "...", "alpha_levels": [...], "joint_tests": "..."},
 "software_defaults": "...", "missingness": "...",
 "unresolved_items": ["..."] }
```

Published coefficient values, SEs, R2, F and N must not appear in the manifest. Design constants (e.g. scale ranges, years such as 1991, item counts) may appear.

## 4. output/spec_space.json

```
{"axes": [ {"axis_id": "A01", "decision": "...", "priority": "sample|coding|fixed_effects_clustering|estimator",
   "origin_level": "L0", "levels": [ {"level_id": "L0", "description": "...",
       "label": "origin|equivalent|non_equivalent|uncertain", "source": "article locator or methodological reference",
       "rationale": "..."} ] } ],
 "compatibility_notes": "...", "explicit_controls_fixed": true }
```

Alternatives need an article or methodological-literature basis. Do not invent alternatives to fill a quota. Distinct reported outcomes or models are not alternatives to each other.

## 5. output/wider_space_and_documentation.json

```
{"choices": [ {"choice": "...", "commonness": "default|common|rare", "justified": true|false, "locator": {...}} ],
 "structural_counts": {"n_models_reported": .., "n_outcomes": .., "n_hrm_measures": .., "n_controls": ..},
 "unusualness_rating": "low|moderate|high", "rationale": "...",
 "documentation_scores": {"specificity": 1-5, "precision": 1-5, "exhaustiveness": 1-5, "rationale": "..."} }
```

## 6. output/inference.json

```
{"observation_unit": "...", "sampling_unit": "...", "assignment_unit": "...",
 "clusters": "...", "native_se_method": "...", "software": "...",
 "first_stage": "not applicable|...", "unavailable_sources": [...], "vintage_fallbacks": [...]}
```

## 7. output/forensic.json

```
{"checks": [ {"check_id": "F01", "type": "coef_se_stars|N_df|table_identity|transformation|text_vs_table|D1_vs_D2",
   "description": "...", "computation": "...", "result": "consistent|inconsistent|undetermined",
   "rounding_interval_used": "...", "locator": {...}} ] }
```

Use whole rounding intervals before calling something inconsistent. These are published-record checks only.

## 8. output/notes.md

Limitations, contradictions between D1 and D2 or between text and tables, missing appendices, items you could not map to a dictionary variable, and questions for the coordinator.
