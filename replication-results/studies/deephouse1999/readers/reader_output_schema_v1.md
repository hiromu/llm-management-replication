# Reader output schema v1 (frozen before either reader runs)

Each reader writes the files below into its output folder `out/`. All files are UTF-8. JSON files must parse. Every interpretive field carries a `source` locator of the form `DOC01 p<PDF page> <section/table/column/row>`; PDF page k = printed page 146+k. Missing values are JSON null, never guessed. Use the identifiers you create consistently across files.

## 1. out/claim_map.json
A list of claim records:
- `claim_id` (string, e.g. "C1")
- `statement` (the hypothesis or stated finding, paraphrased)
- `hypothesis_label` (e.g. "H1", or null)
- `tier`: one of `focal`, `identification_inference_diagnostic`, `robustness`, `descriptive`, `nuisance_control`
- `supporting_locations` (list of locators: table/model/row)
- `estimand` (what parameter or quantity; include scale, e.g. "WLS coefficient on X in model M, outcome scaled x100")
- `population` (units, place, period)
- `direction_claimed` (`positive`, `negative`, `concave_down`, `none`, `other` with text)
- `source`

## 2. out/sealed_targets.json
A list of published numerical values (comparison targets only):
- `target_id`, `claim_id` (or null), `table`, `model`, `row_term`
- `coefficient`, `published_se`, `test_statistic` (value and type), `exact_p` (only if printed), `stars_or_inequality` (verbatim, e.g. "p<0.01", "**"), `alpha_convention` (as printed in table note), `tail` (`one`, `two`, `unstated`), `direction_hypothesized`
- `n` (as printed for that model, or null), `other_stats` (object: e.g. F, df, SSE, R2, Durbin h, as printed)
- `printed_precision` (decimal places of coefficient and SE)
- `source`
Include Table 1 descriptives as tier `descriptive` targets (means, SDs, correlations) if present.

## 3. out/manifest.json (target-free; given to implementers)
Must not contain the article title, author, journal, any published estimate, SE, p value, N, or descriptive value. Use paper id `P-OPAQUE-01`. Fields:
- `paper_id`
- `data_sources`: which registry files/items are used (by the file and column names in the supplied data dictionary)
- `sample_steps`: ordered list; each step has `step_id`, `description`, `rule` (precise, codeable), `source` (locator in DOC01, kept for reconciliation; the coordinator strips locators before implementers see them), `ambiguity` (null or text)
- `variables`: each with `name`, `role` (outcome/focal/control/lag/weight/id), `definition` (codeable formula referencing data-dictionary columns), `timing` (which quarter/date items), `transformations` (e.g. scaling x100), `ambiguity`, `source`
- `estimator` (e.g. OLS/WLS/GLS; weights definition), `models` (list: model id, outcome, regressors in order), `fixed_effects`, `covariance_method`, `autocorrelation_handling`, `outlier_rule`, `missingness_rule`, `software_defaults`, `model_comparison_tests` (e.g. F-test definition), each with `source`
- `inference`: `observation_unit`, `sampling_unit`, `assignment_unit`, `clusters` (or "not applicable" with reason), `native_se_method`, `software_if_stated`, `tail_and_direction_by_hypothesis`, `alpha`
- `documentation_scores`: `specificity`, `precision`, `exhaustiveness` each 1-5 with a one-line justification
- `unavailable_or_vintage_fallbacks`: item-specific fallbacks if a needed source item is unavailable or differs by vintage, each with rationale

## 4. out/sealed_n_branch.json
Published N values and any printed counts of units (banks, years, deleted observations), each with locator. Kept outside implementer-visible files; evaluated by code.

## 5. out/specification_space.json
- `origin`: the closest-described specification, as a set of axis levels
- `axes`: list; each axis has `axis_id`, `decision` (what is open), `priority_group` (`sample_construction`, `variable_coding`, `fixed_effects_clustering`, `estimator`), `levels` (each: `level_id`, `description`, `codeable_rule`, `label` one of `origin`, `equivalent`, `non_equivalent`, `uncertain`, `basis` (article locator or methodological reference), `rationale`)
- `compatible_crossings`: rules for which levels may be combined, and exclusions
- Explicitly listed controls may not be altered within the equivalent set. Do not add alternatives without an article or methodological-literature basis. Distinct reported outcomes are not interchangeable specifications.

## 6. out/wider_space_assessment.json
For each axis and the overall design: `default_common_rare`, `justified_unjustified`, structural counts (number of axes, levels), and a holistic `unusualness_rating` 1-5 with rationale. Descriptive only; never a verdict.

## 7. out/forensic_observations.json
Checks based only on the published record: coefficient/SE/test-statistic/stars consistency (use whole rounding intervals), N and df consistency, F-test arithmetic from printed SSE if available, table identities. Each record: `check_id`, `description`, `inputs` (printed values with locators), `calculation`, `result` (`consistent`, `inconsistent_beyond_rounding`, `not_checkable`), `notes`. These are sealed publication diagnostics.

## 8. out/notes.md
Limitations, publication contradictions, missing information, questions for the coordinator, and a list of every DOC01 page you consulted.
