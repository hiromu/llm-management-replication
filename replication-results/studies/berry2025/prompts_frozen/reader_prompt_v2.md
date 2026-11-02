# Independent reader assignment

You are one of two independent readers. Another reader from a different model family has the same files. You cannot contact them. Your goal is to extract, from the documents alone, what the article claims and exactly how each analysis was done, so that a separate programmer who never sees the article can rebuild it from data.

## Inputs (all in ./input)
- D01_article (PDF and .txt): the article. Scope is the four main-text studies: Studies 1, 2, 3 and 4.
- D02_appendixA_materials: study materials from the authors' deposit.
- D03_online_appendix: the article's Online Appendix. Use it for Studies 1-4.
- D11-D14: preregistrations for Studies 1-4. D22: deviation report for Study 2 (docx and .txt).
- D31-D33: data dictionaries for Studies 1-3. D34 is the dictionary filed in the Study 4 folder. It is byte-identical to a supplemental study's dictionary and shares no variable names with D44, so it does not describe the Study 4 data file. Three Study 3 columns (broker_rep1-3) are absent from D33.
- D41-D44: column names of each study's data file, with no data rows.

Supplemental Studies S1-S7 are outside scope. Do not extract their claims or targets. Record any Study 1-4 detail that appears only in the Online Appendix, and cite it as D03.

## Rules
- You do not have the data and must not estimate anything. Do not browse. Do not use memory of this paper; use only these files.
- Do not choose interpretations for numerical fit. Cite every interpretation with document ID and PDF page, plus table or figure where relevant.
- Missing values stay missing. A printed inequality is not an exact p value. Do not correct printed values.
- Preserve contradictions between article, preregistration and dictionary rather than resolving them silently.
- Do not invent alternatives to fill a list. An alternative needs a basis in the article, preregistration, deviation report or methodological literature.

## Output: write these seven JSON files to ./output

1. claim_map.json: list of {claim_id, study, statement, hypothesis, table_or_locator, estimand, population, scale, tier}. Tier is one of focal, identification_or_inference_diagnostic, robustness, descriptive, nuisance. Include every hypothesis test, ANOVA main effect and interaction, planned contrast, indirect effect, serial mediation path, moderated mediation index and manipulation check reported in the main text for Studies 1-4.

2. targets.json (sealed from implementers): list of {target_id, claim_id, study, statistic_type, condition_or_term, value, se, ci_low, ci_high, test_statistic, df, p_exact, p_inequality, n, alpha, tail, locator}. statistic_type examples: mean, sd, coefficient, indirect_effect, F, t, eta2, d, correlation, alpha_reliability, n_analysed, n_excluded. Record each printed number as printed, with its printed decimal places kept as a string in value. Extract all inferential and descriptive results for Studies 1-4 including means, SDs, reliabilities and sample sizes.

3. manifest.json (target-free: must contain no published estimate, test result, p value, effect size, published sample size, hypothesis outcome, title, author or journal). Object with paper_id "PX01" and, per study, {data_file, unit_of_observation, design (factors, levels, between or within, assignment unit), sample_steps (ordered; each with the exact variables and values used, or "unstated"), variables (each constructed variable with source columns, reverse coding, scoring rule, condition coding), analyses (each with analysis_id, claim_ids, outcome, predictors, estimator, covariates, contrasts, within-subject handling, covariance method, bootstrap settings, software and routine or macro as stated, seed if stated, missing-data rule, output_required)}. Use column names from D41-D44. Where a mapping from document to column is an inference, mark it inferred. Where it cannot be determined, write unstated.

4. specification_space.json: list of {axis, study, analysis_ids, levels:[{level_id, description, label, source_locator, rationale}], origin_level}. Label is equivalent, non_equivalent or uncertain relative to the origin level. Prioritize sample construction and variable coding, then covariance and clustering, then estimator. Explicit control lists are not open choices.

5. documentation_assessment.json: {per_study: {specificity, precision, exhaustiveness (each 1-5 with reason)}, choices: [{choice, default_common_or_rare, justified, locator}], unusualness_overall, unavailable_or_appendix_only: [...], inference_fields: {observation_unit, sampling_unit, assignment_unit, clusters, native_se_method_and_software}, preregistration_vs_article_differences: [...]}.

6. forensics.json: list of {issue, locator, values, check, within_rounding}. Checks from the published record only: coefficient/SE/test/p consistency, N and df, identities across tables and text. Use whole rounding intervals before calling something a mismatch. These are separate records, not verdicts.

7. n_branch.json (sealed from implementers): list of {analysis_id, study, n_total, n_by_condition, n_excluded, locator}, the published sample sizes for each analysis in manifest.json. Missing values stay null.

Additions to the files above:
- specification_space.json: each axis also has category, one of sample_construction, variable_coding, covariance_or_clustering, estimator, other. Mark a study with no sourced open decision on an axis by leaving the axis out.
- documentation_assessment.json also has: wider_space: list of {choice, alternatives, default_common_or_rare, justified, locator}; structural_counts: {per_study: {n_conditions, n_outcomes, n_mediators, n_covariates, n_exclusion_rules, n_analyses}}, counting design elements only, not sample sizes or results; unavailable_source_fallbacks: list of {item, study, why_unavailable, fallback, label}.
- Each manifest analysis also states alpha, tail and direction where documented, and each manifest sample step has a source_locator.
- Focal tier: mark as focal the claims the article itself presents as tests of its hypotheses, and cite the basis.

## Standing rules for this assignment
Read the assigned main article and every permitted supplement in the frozen publication packet, the workflow reader-stage rules, the coordinator's frozen output schema, and newly prepared source descriptions and summary-free dictionaries. Produce the claim map, sealed targets, target-free manifest, sourced specification axes/labels, documentation assessment and limitations required by those rules.

Do not access raw registry data, other readers, prior studies, results or scoring criteria. Do not fit models. Published-table forensic calculations, if requested, remain separate from raw-data estimation and are sealed with targets. Source every interpretation with document/supplement ID and PDF page/table references. Identify publication contradictions, missing appendices and redaction gaps. Do not reconstruct removed author code or infer that no local supplement means none exists. Do not invent alternatives to meet a quota or silently correct article values using memory. Preserve your first complete response and ask the coordinator about missing inputs without contacting another reader.

## 2. Two independent readers
Supply identical assignment templates, input lists and the frozen article-and-supplement packet to the two different model families. Readers must consult every permitted matching supplement and cite document IDs and PDF pages. Preserve main-text/supplement contradictions in reconciliation. Freeze the common output schema before either reader starts.

Each reader produces:

- A claim map: each hypothesis or stated finding, supporting table/column/row, estimand, population, scale and tier. Tiers distinguish focal estimates, identification/inference diagnostics, robustness, descriptives and nuisance controls.
- A sealed targets file: coefficient, published SE, exact p or stars/inequality, alpha, tail/direction, N, model and source locator. Missing values remain missing. No-star entries are not exact p values.
- A target-free implementation manifest: ordered sample steps, variable definitions, source keys, estimator, fixed effects, covariance methods, software defaults, missingness and inference fields. Include an opaque paper ID; keep published N in a machine-evaluated branch outside implementer-visible targets.
- A specification space: axes/levels for genuine open decisions, a closest-described origin, sourced equivalent/non-equivalent/uncertain labels and rationales. Prioritize sample construction and variable coding, then fixed effects/clustering, then estimator. Alternatives must have an article or methodological-literature basis. Explicit control lists cannot be changed within the equivalent set. Distinct reported outcomes are not automatically interchangeable specifications.
- A wider space and documentation assessment: default/common/rare and justified/unjustified choices, structural counts and a holistic unusualness rating. These describe the documented choices and never determine a replication verdict. The wider grid is off unless explicitly included before execution.
- Inference fields: observation/sampling/assignment units, clusters, native SE method/software, first-stage strength where applicable; documentation scores for specificity, precision and exhaustiveness; item-specific unavailable-source and vintage fallbacks.
- Forensic observations based solely on the published record: consistency of coefficient/SE/test statistic/p/stars, N/df, table identities and transformations. Use whole rounding intervals before declaring an internal mismatch. Forensic findings are separate records, not automatic verdicts. Any published-table algebra is a sealed publication diagnostic, not analysis of registry data.

No reader estimates models from raw data or chooses an interpretation by numerical agreement. Preserve the first complete outputs and hashes before any coordinator feedback.

Write valid JSON. Before finishing, confirm all seven files parse and that manifest.json contains no published result. Then print only the word DONE.
