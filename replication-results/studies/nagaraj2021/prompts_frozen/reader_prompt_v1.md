# Independent reader assignment

You are one of two independent readers. Another reader from a different model family has the same files. You cannot contact them. Your goal is to extract, from the documents alone, what the article claims and exactly how each analysis was done, so that a separate programmer who never sees the article can rebuild it from data.

## Inputs (all in ./input)
- D01_article (PDF and .txt): the article. Scope is the main-text Tables 1-7 and Figures 1-6.
- D02_online_appendix (PDF and .txt): the online appendix. Use it only for the methods of in-scope results, and cite it as D02.
- D03_deposit_data_notes.txt: the author's description of each deposited data file.
- D41-D54: the column names of each deposited data file, with no data rows. One file has no header row; its file gives the column count and each column's type only.
- D60_tiger_fields.txt: field names of the Census TIGER/Line 2010 county file.

Appendix tables and figures are outside scope. Do not extract their claims or targets.

## Rules
- You do not have the data and must not estimate anything. Do not browse or use the network. Do not use memory of this paper; use only these files.
- Do not choose interpretations for numerical fit. Cite every interpretation with document ID and PDF page, plus table or figure where relevant.
- Missing values stay missing. Stars or a printed inequality are not an exact p value. Do not correct printed values.
- Preserve contradictions between article text, tables, figure notes, appendix and data notes rather than resolving them silently.
- Do not invent alternatives to fill a list. An alternative needs a basis in the article, the appendix, the data notes or the methodological literature.

## Output: write these seven JSON files to ./output
Use exactly these file names and field names. Use null for a field that does not apply or is not reported.

1. claim_map.json: list of {claim_id, statement, hypothesis, table_or_figure, panel, column, estimand, population, unit, scale, tier}. Tier is one of focal, identification_or_inference_diagnostic, robustness, descriptive, nuisance. Include every coefficient the text interprets, every column of Tables 1-7, and every claim the text makes from Figures 1-6.

2. targets.json (sealed from implementers): list of {target_id, claim_id, table_or_figure, panel, column, row_term, statistic_type, dependent_variable, value, se, stars, p_inequality, test_statistic, n_obs, n_clusters, r2, fixed_effects, cluster_variable, read_from_plot, reading_interval, locator}. statistic_type examples: coefficient, mean, sd, median, min, max, difference, p, n_obs, n_counties, n_quarters, r2. Record each printed number as printed, with its printed decimal places kept as a string in value. For figures, record values printed in the figure or stated in the text with read_from_plot false. You may also record values read from a plot only if you can see the figure image; then set read_from_plot true and give reading_interval as [low, high] covering your reading uncertainty. Otherwise leave plotted values out. For the two county maps, record only what the text or the figure states, such as legend categories and counts.

3. manifest.json (target-free: must contain no published estimate, test result, p value, effect size, published sample size, hypothesis outcome, title, author or journal). Object with paper_id "PX02" and {data_files, analyses}. data_files: for each file, its unit of observation, key columns and how files merge, using column names from D41-D54. analyses: each with {analysis_id, claim_ids, table_or_figure, sample_steps (ordered; each with the exact columns and values used, or "unstated", and a source_locator), variables (each constructed variable with source columns, transformation such as logs or per-capita scaling, timing, and treatment definition), estimator, dependent_variable, regressors, controls, fixed_effects, weights, cluster_or_se_method, event_time_or_period_definitions, software and routine as stated, alpha, tail and direction where documented, missing-data rule, output_required}. For a map or plot, output_required describes the plotted quantity and grouping, never its values. Where a mapping from document to column is an inference, mark it inferred. Where it cannot be determined, write unstated.

4. specification_space.json: list of {axis, category, analysis_ids, levels:[{level_id, description, label, source_locator, rationale}], origin_level}. Category is one of sample_construction, variable_coding, fixed_effects_or_clustering, estimator, other. Label is equivalent, non_equivalent or uncertain relative to the origin level. Prioritize sample construction and variable coding, then fixed effects and clustering, then estimator. Explicit control lists are not open choices. Leave out an axis with no sourced open decision.

5. documentation_assessment.json: {per_table_or_figure: {specificity, precision, exhaustiveness (each 1-5 with reason)}, choices: [{choice, default_common_or_rare, justified, locator}], wider_space: [{choice, alternatives, default_common_or_rare, justified, locator}], structural_counts: {per_table_or_figure: {n_columns, n_outcomes, n_regressors_of_interest, n_controls, n_fixed_effect_sets, n_sample_rules}}, unusualness_overall, unavailable_or_appendix_only: [...], unavailable_source_fallbacks: [{item, why_unavailable, fallback, label}], inference_fields: {observation_unit, sampling_unit, treatment_assignment_unit, clusters, native_se_method_and_software}}. Structural counts are design elements only, not sample sizes or results.

6. forensics.json: list of {issue, locator, values, check, within_rounding}. Checks from the published record only: coefficient, SE, stars and p consistency; N, counties and quarters; identities across tables, figures and text. Use whole rounding intervals before calling something a mismatch. These are separate records, not verdicts.

7. n_branch.json (sealed from implementers): list of {analysis_id, n_obs, n_counties, n_quarters, n_treated, n_control, locator}, the published sample sizes for each analysis in manifest.json. Missing values stay null.

Focal tier: mark as focal the claims the article itself presents as its main tests, and cite the basis.

## Standing rules for this assignment
Read the assigned main article and every permitted supplement in the frozen publication packet, the workflow reader-stage rules below, the output schema above, and the source descriptions in D03, D41-D54 and D60. Produce the claim map, sealed targets, target-free manifest, sourced specification axes/labels, documentation assessment and limitations required by those rules.

Do not access raw registry data, other readers, prior studies, results or scoring criteria. Do not fit models. Published-table forensic calculations remain separate from raw-data estimation and are sealed with targets. Source every interpretation with document/supplement ID and PDF page/table references. Identify publication contradictions, missing appendices and redaction gaps. Do not reconstruct removed author code or infer that no local supplement means none exists. Do not invent alternatives to meet a quota or silently correct article values using memory. Preserve your first complete response. If an input is missing, record it in documentation_assessment.json under unavailable_or_appendix_only rather than stopping.

Work only inside this directory. Write valid JSON. Before finishing, confirm all seven files parse and that manifest.json contains no published result. Then print only the word DONE.

## Workflow reader-stage rules (verbatim from the project workflow)

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

