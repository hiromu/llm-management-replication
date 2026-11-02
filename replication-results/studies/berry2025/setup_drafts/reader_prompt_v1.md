# Independent reader assignment

You are one of two independent readers. Another reader from a different model family has the same files. You cannot contact them. Your goal is to extract, from the documents alone, what the article claims and exactly how each analysis was done, so that a separate programmer who never sees the article can rebuild it from data.

## Inputs (all in ./input)
- D01_article (PDF and .txt): the article. Scope is the four main-text studies: Studies 1, 2, 3 and 4.
- D02_appendixA_materials: study materials from the authors' deposit.
- D03_online_appendix: the article's Online Appendix. Use it for Studies 1-4.
- D11-D14: preregistrations for Studies 1-4. D22: deviation report for Study 2.
- D31-D33: data dictionaries for Studies 1-3. D34 is the dictionary filed in the Study 4 folder; it may not describe Study 4.
- D41-D44: column names of each study's data file, with no data rows.

Supplemental Studies S1-S7 are outside scope. Do not extract their claims or targets. Record any Study 1-4 detail that appears only in the Online Appendix, and cite it as D03.

## Rules
- You do not have the data and must not estimate anything. Do not browse. Do not use memory of this paper; use only these files.
- Do not choose interpretations for numerical fit. Cite every interpretation with document ID and PDF page, plus table or figure where relevant.
- Missing values stay missing. A printed inequality is not an exact p value. Do not correct printed values.
- Preserve contradictions between article, preregistration and dictionary rather than resolving them silently.
- Do not invent alternatives to fill a list. An alternative needs a basis in the article, preregistration, deviation report or methodological literature.

## Output: write these six JSON files to ./output

1. claim_map.json: list of {claim_id, study, statement, hypothesis, table_or_locator, estimand, population, scale, tier}. Tier is one of focal, identification_or_inference_diagnostic, robustness, descriptive, nuisance. Include every hypothesis test, ANOVA main effect and interaction, planned contrast, indirect effect, serial mediation path, moderated mediation index and manipulation check reported in the main text for Studies 1-4.

2. targets.json (sealed from implementers): list of {target_id, claim_id, study, statistic_type, condition_or_term, value, se, ci_low, ci_high, test_statistic, df, p_exact, p_inequality, n, alpha, tail, locator}. statistic_type examples: mean, sd, coefficient, indirect_effect, F, t, eta2, d, correlation, alpha_reliability, n_analysed, n_excluded. Record each printed number as printed, with its printed decimal places kept as a string in value. Extract all inferential and descriptive results for Studies 1-4 including means, SDs, reliabilities and sample sizes.

3. manifest.json (target-free: must contain no published estimate, test result, p value, effect size, published sample size, hypothesis outcome, title, author or journal). Object with paper_id "PX01" and, per study, {data_file, unit_of_observation, design (factors, levels, between or within, assignment unit), sample_steps (ordered; each with the exact variables and values used, or "unstated"), variables (each constructed variable with source columns, reverse coding, scoring rule, condition coding), analyses (each with analysis_id, claim_ids, outcome, predictors, estimator, covariates, contrasts, within-subject handling, covariance method, bootstrap settings, software and routine or macro as stated, seed if stated, missing-data rule, output_required)}. Use column names from D41-D44. Where a mapping from document to column is an inference, mark it inferred. Where it cannot be determined, write unstated.

4. specification_space.json: list of {axis, study, analysis_ids, levels:[{level_id, description, label, source_locator, rationale}], origin_level}. Label is equivalent, non_equivalent or uncertain relative to the origin level. Prioritize sample construction and variable coding, then covariance and clustering, then estimator. Explicit control lists are not open choices.

5. documentation_assessment.json: {per_study: {specificity, precision, exhaustiveness (each 1-5 with reason)}, choices: [{choice, default_common_or_rare, justified, locator}], unusualness_overall, unavailable_or_appendix_only: [...], inference_fields: {observation_unit, sampling_unit, assignment_unit, clusters, native_se_method_and_software}, preregistration_vs_article_differences: [...]}.

6. forensics.json: list of {issue, locator, values, check, within_rounding}. Checks from the published record only: coefficient/SE/test/p consistency, N and df, identities across tables and text. Use whole rounding intervals before calling something a mismatch. These are separate records, not verdicts.

Write valid JSON. Before finishing, confirm all six files parse and that manifest.json contains no published result. Then print only the word DONE.
