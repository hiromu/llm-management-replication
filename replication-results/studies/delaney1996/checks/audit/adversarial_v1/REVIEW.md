# Adversarial review v1: discrepant candidates and sample shortfall, study delaney1996

Run reviewed: runs/run_20261028_v1_1, scored with implementation A (A-B agreement pair) by the frozen scorer (checks/score.py) into checks/score_output_run_20261028_v1_1/. Reviewer: Claude Opus 5.5 (Anthropic) coordinator subagent, 2026-10-28. Only files inside this study folder were read. No existing file was modified. All scripts and outputs are in this folder. Software: R 4.6.1, Python 3.13.4.

## Limitations

- Model family. The reviewer is an Anthropic model. Implementations A and C were written by an Anthropic model too. The protocol requires an adversarial reviewer from a family independent of the implementation families, and that requirement is not met. decisions_v1.md already records that no third family is available. This review cannot by itself confirm or retire a discrepancy. Real human confirmation is still required.
- Unblinded. The reviewer saw the sealed targets, Table 2 and all outputs. The exploratory configurations below were constructed after seeing results. X4 in particular was designed after seeing X3 and the Table 2 STAFF correlations. That is a garden of forking paths: 4 refit configurations and 7 sample-count configurations were tried. No exploratory result changes a frozen classification or the frozen protocol. They show only whether a candidate is robust to plausible unexecuted readings.

## 1. Checks common to all candidates

- Transcription. All 23 candidate values, SEs and stars were checked against the D1 page images: Table 3 on p14, Table 4 on p16, Table 4 (continued) on p17. All match sealed/targets_frozen_v1.json. One published inconsistency, outside the scorer's control: mkt_M10 STAFF prints 0.139* (0.058). Its t is 2.40 (p about .0085 one-tailed), which implies **. This does not change the cell's flag. See published_star_consistency.csv.
- Variable construction. The origin construction in code_A/k7_lib.R was checked against implementation_spec_v1.md, spec_amendment_v1_1.md and the reader dictionary for INCENT, STAFF, TRAIN, GRIEV, DECENT, ILM, SUBSID, UNION, COMPET, PCTMGR and the industry group. No departure from the frozen specification was found. Rebuilding the origin with code_A's own functions reproduces out_A to within 4.7e-5, which is rounding of the printed comparison (exploratory_refits.R, configuration X0). B was written independently and agrees with A to 1e-12. The C audit (checks/audit/C_divergence/AUDIT.md) traces C's divergence to C reversing a stored, unlabelled V233 = 0. It does not implicate A or B.
- Source vintage. ICPSR 6240 V1 DS0002 has 727 establishment records, the same number of organizations the article reports. The shortfall is 361 against 590. Even D04, the largest grid sample (372), stays far below 590. Release-level record loss therefore does not explain it, and no vintage issue was found.

## 2. Per-candidate verdicts

Criteria are the frozen scorer's own (criteria() imported from checks/score.py), applied at the origin. Every candidate also met the criteria at all 33 or 34 fitted grid deviations. The counterfactual column sets the reconstructed estimate equal to the published value while keeping the reconstructed SE and df. If the cell is still flagged, the flag comes from the reconstructed SE (sample size), not from a disagreement in the estimate. X4 is exploratory and post hoc, not part of the frozen protocol. Full numbers are in candidate_diagnostics.csv.

| Cell | Tier | Published (SE) | Origin est (SE) | Flags at origin | Counterfactual flagged | X4 est, flagged | Verdict |
|---|---|---|---|---|---|---|---|
| org_M2 INCENT | H1 primary | 0.120** (0.048) | 0.065 (0.073) | band only (d=3, m=1.14) | yes | 0.120, no | overturned |
| org_M3 INCENT | H1 primary | 0.117** (0.048) | 0.073 (0.073) | band only (d=3, m=0.90) | yes | 0.121, no | overturned |
| mkt_M7 STAFF | H1 primary | 0.145** (0.057) | -0.013 (0.062) | sign, band, m=2.77 | no | 0.122, no | uncertain |
| mkt_M8 STAFF | H1 primary | 0.147** (0.057) | -0.011 (0.062) | sign, band, m=2.77 | no | 0.119, no | uncertain |
| mkt_M6 STAFF | robustness | 0.169** (0.055) | -0.003 (0.063) | sign, band, m=3.12 | no | 0.153, no | uncertain |
| mkt_M9 STAFF | H1 secondary | 0.131* (0.059) | 0.010 (0.065) | band, m=2.04 | no | 0.130, no | uncertain |
| mkt_M10 STAFF | H1 secondary | 0.139* (0.058) | 0.013 (0.065) | band, m=2.17 | no | 0.135, no | uncertain |
| mkt_M9 TRAIN | H1 secondary | 0.071 (0.060) | 0.206 (0.075) | band (d=3), m=2.24 | no | 0.100, no | uncertain |
| org_M4 DECENT | interaction model | -0.087 (0.192) | 0.491 (0.255) | sign, band, m=3.01 | no | 0.145, sign only | uncertain |
| org_M4 GRIEV | interaction model | -0.048 (0.296) | 0.255 (0.490) | sign only (published t=-0.16) | no | sign only | overturned |
| org_M4 GRIEV_x_INCENT | interaction | 0.013 (0.104) | -0.076 (0.173) | sign only (t=0.12) | no | sign only | overturned |
| org_M5 GRIEV | interaction model | -0.012 (0.295) | 0.161 (0.487) | sign only (t=-0.04) | no | sign only | overturned |
| org_M5 GRIEV_x_INCENT | interaction | 0.029 (0.103) | -0.055 (0.171) | sign only (t=0.28) | no | none | overturned |
| mkt_M10 GRIEV_x_INCENT | interaction | -0.029 (0.161) | 0.210 (0.268) | sign only (t=-0.18) | no | sign only | overturned |
| mkt_M9 GRIEV | interaction model | 0.043 (0.459) | -0.777 (0.758) | sign only (t=0.09) | no | sign only | overturned |
| mkt_M6 DECENT | robustness | -0.047 (0.061) | 0.038 (0.074) | sign only (t=-0.77) | no | sign only | overturned |
| mkt_M8 SUBSID | nuisance | -0.063 (0.101) | 0.090 (0.119) | sign only (t=-0.62) | no | none | overturned |
| mkt_M9 SUBSID | nuisance | -0.066 (0.108) | 0.099 (0.121) | sign only (t=-0.61) | no | none | overturned |
| mkt_M10 SUBSID | nuisance | -0.087 (0.104) | 0.120 (0.121) | sign only (t=-0.84) | no | none | overturned |
| mkt_M7 UNION | nuisance | -0.050 (0.094) | 0.127 (0.079) | sign only (t=-0.53) | no | sign only | overturned |
| mkt_M8 UNION | nuisance | -0.049 (0.094) | 0.130 (0.079) | sign only (t=-0.52) | no | sign only | overturned |
| mkt_M9 UNION | nuisance | -0.047 (0.100) | 0.134 (0.080) | sign; band d=2 (p=.048) | no | sign only | overturned |
| mkt_M10 UNION | nuisance | -0.051 (0.099) | 0.143 (0.081) | sign; band d=2 (p=.039) | no | sign only | overturned |

Reasons:

- org_M2 and org_M3 INCENT: overturned as evidence of discrepancy. The only criterion that fires is the inference band. The magnitude gap, 0.9 to 1.1 published SEs, is in the frozen "moderate" band. The reconstructed SE is 1.5 times the published SE. The sample is 39% smaller and the sample-size ratio alone would give a factor of 1.28. The counterfactual shows the band criterion would flag these cells even if the reconstructed estimate equalled 0.120 exactly. Under the N mismatch the criterion cannot tell disagreement from lost power. In the exploratory configurations INCENT is 0.091 under X1 (m=0.59), 0.113 (0.049) under X3 and 0.120 (0.049) under X4.
- STAFF in market models 6 to 10: uncertain. This is a real disagreement at the origin. The point estimate is about zero against a published 0.13 to 0.17, the counterfactual does not flag it, and it holds at all 33 or 34 frozen readings and under X1 to X3. It does not hold under X4. X4 treats an establishment that did not hire from outside (V50, V85 or V119 = 2) as having 0 applications, using ln(1+x). It also takes two other unexecuted readings: COMPET N/A as 0, and the PCTMGR mapping. X4 reproduces the market N exactly (373). It reproduces the coefficients within tolerance (m at most 0.49, d at most 1). Independently, it reproduces Table 2's r(PMP, STAFF) = .19: X4 gives .206, while the frozen construction gives about 0 in every frame. Under the frozen construction, every pairwise STAFF correlation with a size-related variable is about half the Table 2 value (staff_subsid_correlations_vs_table2.csv). This points to a construction difference in STAFF, specifically the treatment of the structural skip for establishments with no outside hiring. It does not point to an error in the article. The STAFF candidates survive only as "not reproducible under the frozen readings". Because the explanation is post hoc, they are not overturned outright.
- mkt_M9 TRAIN: uncertain. The reconstructed coefficient is larger and significant, against a printed non-significant 0.071. In mkt_M7 and mkt_M8 the same TRAIN term was already label_sensitive, not a candidate. Under X4 the cell is within tolerance (0.100, m=0.47, d=1). The TRAIN construction carried several uncertain axes, and the cell is sensitive to sample construction.
- org_M4 DECENT: uncertain. In a raw-product interaction model, the main effect is the slope at ILM = 0, which is outside ILM's 1 to 2 range. It is an extrapolation that magnifies small differences in how ILM and DECENT are constructed. The printed value is non-significant (t=-0.45). Under X4 only the sign criterion fires (m=1.21).
- Sign-only cells on estimates indistinguishable from zero (GRIEV and GRIEV_x_INCENT in interaction models; mkt_M6 DECENT): overturned. Each published |t| is at most 0.77. Every magnitude is under 2 published SEs, and d = 0. The frozen sign rule fires whenever the 3-decimal rounding interval excludes zero. The scorer applied it correctly, but it carries no information when the printed estimate is a fraction of an SE from zero. The article itself calls the interactions insignificant, and the reconstruction agrees. Under X4 several of these cells flip sign again, which confirms the instability.
- SUBSID (mkt_M8, M9, M10): overturned. These are sign-only flags with published |t| at most 0.84. In addition, the publication's own Table 2 shows that the printed "Subsidiary" variable has the opposite orientation to the reconstruction's SUBSID (V17 == 1 coded 1):
  - The Table 2 mean of 1.44 equals the raw V17 mean, 1.457, where 1 = part of a larger organization and 2 = independent. Nonprofit's 1.35 likewise equals the raw V8 mean, 1.348.
  - Every Table 2 correlation of Subsidiary with POP, STAFF, TRAIN, INCENT, GRIEV and DECENT has the opposite sign to, and nearly the same size as, the reconstructed pairwise correlation. Example: GRIEV -.43 printed against +.446 reconstructed.
  - Under the exact re-expression (coefficient on 1 - SUBSID = -coefficient), no SUBSID candidate is discrepant at the origin.
  - The frozen origin "subsidiary = V17" therefore misreads the printed orientation. Fable's A12.L0 states "V17 = 1 coded as the high category", the readers agreed it, and decisions_v1.md lists it as an agreed origin. This is a reconciliation finding.
- UNION in market models: overturned. The sign rule fires on printed |t| of about 0.5, with m of 1.8 to 1.96, under 2. For M9 and M10 the d = 2 comes from the scorer using min(p_upper, p_lower) for a printed non-significant control (see section 4) and from p = .048 and .039. Under X4 only the sign criterion fires. The printed union index has sd .59 against .83 reconstructed, so the item set or coding probably differs. The union-item axis was already uncertain.

Overall: none of the 23 discrepant candidates survives adversarial review as evidence of a discrepancy attributable to the published article.

- 16 are overturned: both org INCENT cells, 7 near-zero sign-only cells, 3 SUBSID and 4 UNION.
- 7 are uncertain: 5 STAFF cells in market models 6 to 10, mkt_M9 TRAIN and org_M4 DECENT.
- Of the 4 H1 primary candidates, 2 are overturned (INCENT) and 2 are uncertain (STAFF).
- The frozen records stay "discrepant_candidate_pending_human_review". The reviewer recommends that the human reviewer not confirm any of them, and that the claim-level reading remain indeterminate/sample_reconstruction, as the scorer already reports for H1, H2 and the paper.

## 3. Sample-shortfall diagnosis (origin, organizational frame of 727 records)

Per-variable missingness within the record frame and its effect on the common complete-case sample of 361 is in missingness_org_origin.csv and missingness_mkt_origin.csv. "Only cause" counts the rows for which this variable is the only missing one.

| Variable | Missing (org) | Only cause (org) | N if not required (org) | Missing (mkt, frame 474) | Only cause (mkt) |
|---|---|---|---|---|---|
| STAFF | 224 | 85 | 446 | 179 | 77 |
| PCTMGR | 138 | 24 | 385 | 105 | 19 |
| COMPET | 113 | 53 | 414 | 14 | 3 |
| POP / PMP | 45 | 5 | 366 | 36 | 4 |
| VHIER | 44 | 11 | 372 | 25 | 11 |
| LOGAGE | 38 | 7 | 368 | 21 | 4 |
| LOGEMP | 15 | 0 | 361 | 7 | 0 |
| GRIEV | 13 | 0 | 361 | 13 | 0 |
| DECENT | 11 | 0 | 361 | 11 | 0 |
| UNION | 6 | 1 | 362 | 5 | 1 |
| INCENT | 4 | 0 | 361 | 4 | 0 |
| ILM | 1 | 0 | 361 | 1 | 0 |
| TRAIN, NONPROF, SUBSID, PRODUCT, SERVICE, industry | 0 | 0 | 361 | 0 | 0 |

Sources of the three largest losses:

- STAFF (224 rows): 177 rows have all three application-count items system-missing. 176 of the 224 report no outside hiring of COREs (V50 = 2), and the items are skipped by routing. The other 47 are code 995 "large number" (18 rows), 998/999, or 0.
- PCTMGR (138 rows): 108 rows have V114 = 2, meaning the managers are the same occupation as CORE or GSS. The frozen origin sets them to missing. 17 have the manager count V115 missing.
- COMPET (113 rows): 107 rows have V328 = 7 "not applicable", 98 of them nonprofits, plus 6 with code 9.

The loss is strongly selective on size (size_selection.csv). The median employment of the 361 retained establishments is 120, against 20 for the 366 excluded and 7 for the STAFF-missing rows. Mean log employment is 5.00 in the origin sample. Table 2 prints 4.15 (sd 2.36), and the full record frame gives 4.17 (sd 2.36). The published sample therefore resembles the full frame in size, and the reconstruction's complete-case sample does not. Using all available pairs in the full frame, the reconstruction's HRM correlations with POP and PMP match Table 2 closely, except for STAFF and the orientation of SUBSID (pairwise_correlations_vs_table2.csv).

Relaxing requirements one at a time in a greedy order: dropping the STAFF requirement gives 446, then COMPET 518, then PCTMGR 597 for the org family. For the market family, dropping STAFF gives 316, then PCTMGR 375.

The following counts are exploratory, post hoc and not part of the frozen protocol (n_exploratory_EXPLORATORY_POSTHOC.csv):

| Configuration | org N | mkt N |
|---|---|---|
| Origin (as frozen) | 361 | 239 |
| E1: PCTMGR for V114 = 2 from the CORE/GSS count (Fable A15.L0) | 381 | 256 |
| E2: COMPET N/A as 0 | 413 | 242 |
| E1 + E2 | 439 | 259 |
| E1 + E2 + STAFF not required | 590 | 377 |
| X4: E1 + E2 + non-hiring = 0 applications, ln(1+x) | 584 | 373 |

Assessment, a diagnostic only, which neither claims to be the authors' procedure nor selects a reading:

- No rule stated in the article's text yields about 590. The article gives no missing-data rule.
- Three handling choices the article leaves unspecified account for almost the whole shortfall: establishments that did not hire from outside (STAFF), managers who are the same occupation as CORE or GSS (PCTMGR), and competition "not applicable" (COMPET).
- Two of them have documentary support. Fable's A15.L0 origin maps V114 = 2. Table 2 prints competition with mean .44 and sd .50, which indicates a dummy. The share of records with V328 = 4 among all 727 is .435, which fits N/A coded 0. Table 2 also prints percent managers as a proportion with mean .24, against .13 under the frozen construction. That is consistent with V114 = 2 establishments being retained with large manager shares.
- None of these three readings was executed in grid_v1. That explains why no grid specification exceeds 372 or 250.

Reconciliation finding: the ledger pairs Fable A15.L0 (V114 = 2 mapped to V45/V80, a reader origin) with Astra A12.L0 as one origin choice (ledger_input_v1.json, P31). The executed origin instead sets V114 = 2 to missing, which is Fable's A15.L1 "uncertain" level. Fable's origin level appears nowhere in the grid. The rule "different structures retain the union" was not followed for this level.

## 4. Influence diagnostics

out_A/influence.csv and out_B/influence.csv agree (influence_agreement_AB.json):

- Both have 18,000 rows, all with status ok. Keyed on model, deleted V1 and term, every row matches.
- Maximum absolute differences: 2.0e-14 for the estimate, 3.7e-12 for the SE, 8.1e-13 for p_upper and 1.6e-12 for p_two.
- The dropped-dummy flags are identical on all 330 flagged rows. The notes differ only in format.

No deletion moves a candidate term near the published value (influence_ranges_candidate_terms_A.csv):

- org_M2 INCENT ranges from 0.044 to 0.086.
- mkt_M7 STAFF ranges from -0.029 to 0.006.

Influence ranges are not confidence intervals.

## 5. Scorer-application issues

1. The N cells for org_M1 and mkt_M6 are marked not_attemptable. recon_value() looks up model_stats for model_id 'org_M1' or 'mkt_M6', but the implementations write per-practice ids such as org_M1_STAFF. The value is available: 361 and 239 under case_scope L0. These cells should read descriptive_only. No claim outcome changes.
2. Printed non-significant controls. For pb = 3 the code computes the band from min(p_upper, p_lower) for every term. The frozen direction_by_tier rule says controls use "one-tailed p in the direction of the printed estimate". The rule's general "either direction" sentence for claims of non-significance makes this ambiguous. Under the control rule, mkt_M9 and mkt_M10 UNION get d = 0 instead of d = 2. They stay flagged through the sign criterion, so no outcome changes. The ambiguity should be recorded.
3. The frozen rules are internally inconsistent on precedence. outcome_precedence lists indeterminate before discrepant, but cell_outcome steps 5 to 7 and the n_tolerance consequence place discrepant before indeterminate/sample_reconstruction. The scorer follows the steps. With a 39% N shortfall, this precedence lets significance-band flags become discrepant candidates when they would fire even at an exact point match (org INCENT). This is a rule-design issue, not a coding error.
4. The sign criterion requires only that the printed rounding interval exclude zero. As applied, 15 of the 23 candidates carry a sign flag on a printed estimate within 0.84 printed SEs of zero. For 12 of them, sign is the only criterion that fires. The application is correct as written, but the result is not scientifically informative. A future protocol version could require the printed interval to exclude zero at some multiple of the SE. Any such change must not be applied retroactively to this run.
5. "Every fitted deviation" is satisfied without testing the sample. No grid deviation reaches a sample near the published N, so the requirement that a discrepancy hold at every reading never tests the dominant source of uncertainty.

## Files in this folder

- Scripts: n_diagnosis.R, descriptives.R, size_selection.R, staff_subsid_corr.R, n_exploratory.R, exploratory_refits.R, exploratory_staff_X4.R, exploratory_X4_allmodels.R, candidate_table.py, influence_compare.py.
- Outputs:
  - Missingness and sample size: missingness_org_origin.csv, missingness_mkt_origin.csv, greedy_requirement_relaxation.csv, size_selection.csv.
  - Comparisons with Table 2: descriptives_vs_table2.csv, origin_correlations.csv, pairwise_correlations_vs_table2.csv, staff_subsid_correlations_vs_table2.csv.
  - Candidates: candidate_diagnostics.csv, published_star_consistency.csv.
  - Influence: influence_agreement_AB.json, influence_ranges_candidate_terms_A.csv.
  - Exploratory, post hoc: files with the suffix _EXPLORATORY_POSTHOC.
  - frame_origin_A.rds is the origin frame rebuilt with code_A functions.
