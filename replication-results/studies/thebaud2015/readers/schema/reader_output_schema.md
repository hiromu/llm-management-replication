# Common reader output schema (version 1)

Both readers write the same seven files, all UTF-8, into the output/ folder of their working directory. JSON files must parse. Give every interpretation a locator: document ID (MAIN or S1), PDF page number (the physical page in the PDF, starting at 1), and table/column/row or section. Missing values are null, never guessed.

## 1. claim_map.json

A list of claim objects:

- claim_id: C01, C02, ...
- statement: the hypothesis or stated finding, paraphrased
- hypothesis_label: e.g. "H1" if the article numbers it, else null
- direction: positive / negative / null-effect / interaction-sign description / none
- tier: focal / identification_or_inference_diagnostic / robustness / descriptive / nuisance_control
- estimand: the quantity that tests the claim (e.g. coefficient of X in model M, interaction term, marginal effect)
- scale: log-odds / odds ratio / probability / linear coefficient / other, as printed
- population: who the claim is about (sample, subgroup)
- support: list of {doc, page, table, column_or_model, row}
- notes

## 2. sealed_targets.json

A list of published values, one per row of a table cell:

- target_id: T001, ...
- claim_ids: list of linked claims, or [] if none
- doc, page, table, model_or_column, row_label
- quantity: coefficient / odds_ratio / se / z / t / p / n_individuals / n_countries / variance_component / icc / fit_statistic / other
- printed_value: exactly as printed (string)
- value: numeric or null
- published_se: numeric or null (for coefficient rows)
- stars_or_p: as printed (string or null). A missing star is not an exact p value.
- alpha_levels_in_legend: as printed in the table note
- tail: one-tailed / two-tailed / unstated, with locator
- n: as printed for that model, or null
- scale_note

Include every coefficient row of every regression table you consider part of the focal or robustness claims, and the N rows. Transcribe exactly; do not round, correct or recompute.

## 3. manifest.json (target-free implementation manifest)

It must contain no article title, author, journal, DOI, country-level published values, published coefficients, SEs, p values, stars or Ns. Use opaque paper_id "P-7Q3".

- paper_id
- data_sources: list of {source_key (use the keys in the source descriptions), role, years, notes}
- sample_steps: ordered list of {step, rule, source_locator}
- variables: list of {name, role (outcome/predictor/control/country_level/interaction/weight/cluster id), definition, construction from source variables and codes, coding of missing/refused/don't know, transformations (centering, standardizing, logs), level (individual/country/country-year), locator}
- models: list of {model_id, outcome, sample (which steps/subgroup), terms (exact list including interactions), estimator (e.g. multilevel logit with random country intercepts), random effects / fixed effects, weights, covariance method, software and defaults if stated, integration method if stated, locator}
- inference: {observation_unit, sampling_unit, assignment_unit_for_country_variables, clusters, native_se_method, software, tail_and_alpha_policy, locator}
- missing_data: rules as described, or "unstated"
- sealed_n_branch: put published sample sizes here only (it is kept away from implementers by the coordinator): list of {model_id, n_individuals, n_countries, locator}
- unavailable_or_unclear: items the article does not specify

## 4. spec_space.json

- origin: the closest-described specification, as references to manifest model_ids and variable definitions
- axes: list of {axis_id, decision (what is open), priority (1 sample construction, 2 variable coding, 3 fixed/random effects or clustering, 4 estimator), levels: list of {level_id, description, is_origin, label (equivalent / uncertain / non_equivalent), rationale, basis (article locator or methodological-literature citation)}}
- compatibility: crossings that are incompatible, with reason
- notes: alternatives must have an article or methodological-literature basis. Do not change explicitly listed controls within the equivalent set. Distinct reported outcomes are not interchangeable specifications. Add no alternatives just to reach a count.

## 5. documentation_assessment.json

- choices: list of {choice, assessment (default / common / rare), justified (yes / no / partly), locator}
- structural_counts: {n_models, n_outcomes, n_country_level_predictors, n_interactions, n_controls}
- unusualness_rating: low / moderate / high with a sentence of reasoning
- documentation_scores (1 to 5 with reasons): specificity, precision, exhaustiveness
- wider_space: optional list of further plausible choices outside the equivalent set, default/common/rare. These are descriptive only and are off unless the coordinator includes them before execution.
- unavailable_source_fallbacks: item-specific fallbacks if a source or vintage is unavailable, with basis

## 6. forensic_observations.json

Based only on the published record. Each: {obs_id, locator, check (e.g. coefficient/SE vs stars; N consistency across tables; df; text vs table), finding, uses_rounding_intervals (true/false), severity (none / minor / potential_inconsistency)}. Use whole rounding intervals before declaring a mismatch. These are separate records, not verdicts.

## 7. reader_notes.md

Contradictions between MAIN and S1, missing appendices or redaction gaps, questions for the coordinator (written; you will not get numerical feedback), and limitations of your reading.
