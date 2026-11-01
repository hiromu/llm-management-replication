# Downstream audit and adversarial review, deephouse1999, run_v1

Auditor: Claude Code subagent on claude-opus-5-5 (Anthropic), invoked by the coordinator after scoring. Scope: STUDY = studies/deephouse1999 only. No existing study file was modified; all scripts and outputs are in checks/audit_v1/. Frozen run outputs were re-hashed against runs/run_v1/impl_{A,B,C}_outputs_SHA256SUMS.txt (32/32 files OK). Python: ~/.venv/bin/python -I (3.13.4); R 4.6.1 (/opt/homebrew/bin/Rscript) only to re-run the implementers' own code in a scratch copy for task 6.

Every diagnostic labelled post hoc below is non-scoring. No label, tolerance, grid level, scoring rule or scored specification was changed or added.

## Summary

| Task | Result |
| --- | --- |
| 1 Transcription | 0 mismatches. All 18 Table 2 coefficient/SE/star cells, 3 SSE, 3 delta SSE with F and text significance, the Model 3 without first-order term values and N = 960 match the page image in both readers. |
| 2 Lineage | 3 bank-years traced from raw zip to derived extract to sample: all values identical; TER reproduced to 1e-16; 14 raw zip hashes match the registry. |
| 3 Calculation | Independent WLS and F tests match impl_B and impl_C to 4e-13. An independent rebuild of O_A from the derived extract reproduces all 1260 rows, the sample hash and every variable, including SD in the audit year 1988 (max diff 5e-14). |
| 4 Completeness | Each implementation has all 112 expected spec ids x 4 models (446 ok, 2 not_applicable as amendment C6 requires), plus 52 origin-own-level duplicates. Influence: 8,715 fits per implementation, 0 failures. |
| 5 Scoring | term_scores.csv (38 rows), claim_outcomes.csv and paper_outcome.json reproduced by an independent scorer. One minor code-scope point does not change any outcome. |
| 6 A vs B/C | R03.proforma: impl_A drops one row (Heritage NB, RSSD 724351, 1990) because of an identifier change. B/C follow the rule text. R13.components: the rule text is ambiguous. The B/C literal mapping double-counts loans for purchasing securities, and A's mapping fits the accounting identity. Neither affects any claim outcome. |
| 7 Adversarial | No coding, transcription, unit or scoring error explains any candidate. (a) H3 and (b) Model 3 TER remain unresolved. (c) The Model 3 intercept follows arithmetically from (a) and (b). (d) H2 at O_B is origin-label sensitivity, not a discrepancy. Post hoc evidence points to a market-definition difference that the frozen grid does not contain. |
| 8 Limitation | No model family independent of the implementers is available. This reviewer is Anthropic, the same family as Reader A, implementer A and checkers for B and C. |

No error was found that would change term, claim or paper outcomes. The paper outcome stays indeterminate. The discrepancy candidates cannot become discrepant under the frozen rules in any case: N is outside tolerance (1260 and 1255 vs 960, about +31%), so scoring_rules_v1.json n_tolerance turns them into indeterminate (sample construction).

## 1. Transcription audit

The auditor read Table 2 independently from sources/packet_v1/pages/DOC01_p12.png and from the PDF text layer (pdftotext, PDF pages 12-13; SHA-256 of the article matches STUDY.json). Both sealed target files were then compared with that reading (a1_transcription_audit.py → a1_transcription_audit.csv, a1_transcription_summary.json). The result was 25 checks per reader and 0 mismatches. The text values match as well:
- Model 3 without the first-order term: -0.001, S.E. 0.0001, S.S.E. 2.803 (DOC01 p13).
- F = 30.4 (1,954), 84.4 (2,953) and 134.1 (1,953), each stated as p < 0.001.
- n = 960.

The printed statistics are internally consistent:
- delta SSE: 2.978 - 2.886 = 0.092, 2.978 - 2.530 = 0.448, 2.886 - 2.530 = 0.356.
- F recomputed from the SSEs: 30.41, 84.38 and 134.10.

Note for later tasks: F(M3 vs M2) = 134.1 implies |t(SD2)| = 11.58. With |b| in [0.0055, 0.0065], the actual SE of SD2 is 0.000475 to 0.000561, about half the printed 0.001.

## 2. Source lineage spot check

Rule fixed before looking: sort impl_B out/samples/O_A.csv by (RSSD9001, year) and take positions 0, 629 and 1259 (first, lower median, last). Script: a2_lineage_spotcheck.py, outputs a2_lineage_spotcheck.csv and a2_raw_hash_check.csv. XPT members were unpacked to the session scratchpad, not into the study.

| Bank-year | Name | RC-K 3368 quarters | AA (O_A rule) | TER raw vs sample | RCON2200 Q4 | Implied market deposits |
| --- | --- | --- | --- | --- | --- | --- |
| 8855, 1985 | Resource B&TC | 4 | 28,298.75 | 0.159760 = 0.159760 | 41,177 | 22.23 bn |
| 687652, 1986 | Norwest Bk Univ-Midway | 4 | 63,678.75 | 0.080749 = 0.080749 | 65,884 | 23.73 bn |
| 1857377, 1992 | Valley Bk MN | 4 | 30,623.25 | 0.069816 = 0.069816 | 27,281 | 27.18 bn |

For each bank-year, RCFD2170, RIAD4340, RIAD4073, RIAD4093, RCFD/RCON3368 (Q1-Q4) and RCON2200 are identical in the raw XPT and in data/derived/call_mnwi_core_1983q4_1993q4.parquet. All 14 raw zips touched match registry/source_registry.json. The derived parquet hashes match registry/registry_freeze_v1_SHA256SUMS.txt and the run input sums. The implied market totals equal the year sums of RCON2200 in the auditor's rebuild (task 3).

## 3. Calculation audit

Recomputation from impl_B's saved O_A and O_B samples used numpy WLS with weights = MS and conventional covariance (a3_calc_audit.py → a3_wls_recompute.csv, a3_ftest_recompute.csv). Agreement with impl_B and impl_C spec_results.csv:
- Coefficients: max abs diff 4.4e-13.
- SEs: 1.6e-14.
- F statistics: 3.7e-12.
- Sample hashes: identical.

For the independent rebuild, the auditor wrote a separate construction from the grid_v1.json O_A rule texts and the manifest (a3_calc_audit.py part b; same logic in a_rebuild_lib.py). The result:
- 1260 rows with 0 unmatched rows, the identical sample hash da728ebd…77c1 and 195 banks.
- Max abs diff on any variable: 5.5e-14 for SD and 1.4e-12 for SD2.
- Audit year 1988 SD: 154 rows, max diff 4.8e-14 (a3_rebuild_O_A_SD_1988.csv).
- The zero-if-not-collected rule fills only 1983Q4 items (RCFD1766, 0390, 2146), so it has no effect on 1984-1992 shares.

In Model 3, the estimates of the SD and SD2 coefficients have correlation -0.979 at O_A and -0.980 at O_B (a3_m3_coef_correlation.csv).

## 4. Completeness audit

a4_completeness_audit.py → a4_completeness_status.csv, a4_completeness_summary.json:
- Expected spec ids from the grid: O_A, O_B and 55 deviations per origin, 112 in total.
- Every implementation has every spec id x {M1, M2, M3, M3_SQ}: 446 ok, and 2 not_applicable for R26.centered x M3_SQ at both origins (amendment C6).
- Each implementation also records 52 origin-own-level specs as duplicate (164 spec ids in total, matching implementation_agreement.json).
- There are no failed or unavailable specs.

Influence (each implementation): every registered cell has one fit per row or bank, unique ids and 0 failures.
- O_A: M2 SD has 1260 bank-year and 195 bank fits; M3 SD and SD2 have the same counts per term.
- O_B: 1255 bank-year and 195 bank fits.
- Total: 8,715 rows.

## 5. Scoring audit

An independent scorer was written from the scoring_rules_v1.json text, not by importing rules_lib.py (a5_scoring_audit.py → a5_term_rescore.csv, a5_claim_rederive.csv). It applies:
- Rounding interval of half a unit in the last printed digit.
- d = distance to the interval divided by the upper SE bound.
- Bands: 1.5 and 3.0.
- Star mapping: *** and ** to p<.01, * to .01-.05, none to p>=.05.
- Inference rule with two or more bands weaker as the discrepancy criterion.
- Text claim for Model 3 without the first-order term treated as *, with SE printed to 4 decimals.

Results:
- All 38 term outcomes, d values and magnitude bands match term_scores.csv.
- All 18 coefficient claims and their per-origin combinations match claim_outcomes.csv. The 3 F-test rows follow the p<.001 rule.
- paper_outcome.json follows paper_rule: an indeterminate primary focal claim gives an indeterminate paper outcome. The N tolerance is applied, and the label-sensitivity search for H3 finds 0 uncertain specs where both H3 terms are consistent.

Observations, none of which changes an outcome:
- claim_outcomes.py line 76 runs the uncertain-reading label-sensitivity check only for focal and robustness tiers. The rule text (discrepancy_across_readings) is not tier-restricted.
  - Applying it to the two nuisance claims that are discrepant_candidate at both origins: control_TER_M3 has 0 of 84 uncertain specs consistent. control_intercept_M3 has 3 consistent specs (O_A__R03.drop_merger_years, O_B__R03.drop_merger_years, O_B__R07.before_extraordinary).
  - The latter would add a label_sensitive reason code; the outcome stays indeterminate (a5b_control_label_sensitivity.json).
- rules_lib.py maps a published non-significant term with reconstructed p<.01 to two_band_contradiction, which is discrepancy-level. The rule text says only "a contradiction". This is a reasonable reading, but it is an interpretation; it affects control_MS_M2 at O_B, which is indeterminate anyway.
- The frozen rule's Table 1 descriptive comparison was not produced in scoring/run_v1. It is informational, and the auditor computed it in a7_D3_table1_compare.csv:
  - O_A agrees on 5/7 means, 2/7 SDs and 10/21 correlations.
  - O_B agrees on 6/7 means, 4/7 SDs and 7/21 correlations.

## 6. Implementer disagreement (R03.proforma, R13.components)

R03.proforma. The rule text: "For survivors of a merger in year t, build t-1 lag from summed predecessor income and average assets."

The auditor re-ran the unmodified impl_A and impl_B code for this level in a scratch copy (a6_proforma_rebuild_driver.R, a6_proforma_A_vs_B_rows.csv). The two differ on exactly one bank-year at each origin: RSSD 724351 (Heritage NB), 1990.
- Under FDIC events, CERT 13810 absorbed CERT 8201 on 1990-02-09. The Fed RSSD 724351 carried CERT 8201 in 1989Q4 and CERT 13810 in 1990Q4.
- impl_B and impl_C identify the merging institutions by CERT and sum the t-1 income and assets of both CERTs. This follows the rule text.
- impl_A treats the survivor as its RSSD9001. It excludes the predecessor CERT 8201 because that record has the same RSSD9001, finds no other predecessor record, and sets the lag to missing ("predecessor_no_t-1_record").
- This is the unresolved checker item 3 ("R03.proforma identifier change") in checks/open_checker_items_at_freeze.md.
- Verdict: B/C follow the rule; A's handling is an implementation limitation for identifier changes.

Other code differences have no effect in this data:
- Event identification: A uses CHANGECODE {213, 221, 222, 223, 810, 812}; B and C use a description regex. The two select the identical 989 events.
- Same-year chain closure: B and C close chains; A does not.

R13.components. The rule text enumerates categories without item codes. "Loans to purchase securities" and "all other loans" are listed separately.
- impl_A uses 2165 + 1505 + 1510 + 1517 + 2107 + 2081 + 1563, where RCFD1563 "other loans" = 1545 + 1564.
- impl_B and impl_C use 2165 + 1505 + 1517 + 1510 + 1545 + 2107 + 2081 + 2080, where RCFD2080 is named "ALL OTHER LOANS".
- In the MN/WI commercial-bank Q4 records where all items exist (1,145 of 10,684), RCFD2080 = RCFD1563 in 94% of records (a6_r13_identity_check.json). So the B/C list counts 1545 twice.
- A's list reproduces the gross residual (1400 - 1766 - 1410 - 1975 - 1590) exactly in 86% of records, against 47% for B/C.
- Verdict: the rule is ambiguous. The B/C reading follows the MDRM item name literally, and A's follows the accounting identity.
- The level is degenerate in practice. The component items are reported only by about 7-17% of filers, so N = 206 for all three implementations.
- Scoring used the agreeing B/C pair, as frozen. H3 at this level is grey under either reading (SD 0.1246 vs 0.1238), so no claim outcome changes.

## 7. Adversarial review of the discrepancy candidates

### Checks that rule out simple errors

- Transcription: verified (task 1).
- Implementation: three independent implementations, plus the auditor's own rebuild, agree exactly at both origins (task 3).
- Units:
  - y and lag are x100, and the weighted SSE is of the published magnitude (M1: 3.011 at O_A and 2.966 at O_B, vs 2.978 published). Without the x100 scaling the SSE would be 10^4 times smaller.
  - TER and MS are proportions (mean TER 0.088 vs 0.085).
  - SD units match (mean 7.36 vs 7.64).
  - RMG is in percent.
  - Weights are raw MS, consistent with "error variance inversely proportional to market share".
- Variable definitions match the article text: ROA on average assets; relative to the unweighted market mean; 11 asset categories in absolute z-units; total interest plus noninterest expense over average assets; deposit share; percent change in real market deposits.
- Outlier structure is reproduced (O_A rebuilt with the named row kept; a7_adversarial_diagnostics.json D5):
  - Norwest Bank Minneapolis 1987 has the largest externally studentized WLS residual in M1, M2 and M3.
  - Its minimum value is in M2: 24.7, vs the published 21.8.
  - It is 1.61 times the second largest, vs "about 50 percent higher" in the article.
- Source vintage: the Chicago Fed archive files (zip members dated 2000) may differ from the author's 1990s Call Report extracts. This cannot be checked further from public data.

### Sample construction: specific evidence on 1255-1260 vs 960 (post hoc, non-scoring)

The N gap is located geographically (a7 D4):
- The four outer counties of the 1983 MSA used by every frozen R01 level contribute 286 of the 1260 O_A rows (285 of 1255 at O_B): Chisago, Isanti, Wright and St. Croix (WI).
- The seven-county Twin Cities area (Anoka, Carver, Dakota, Hennepin, Ramsey, Scott, Washington) accounts for 974 and 970 rows.

The auditor rebuilt O_A once with the market restricted to those seven counties, rebuilding benchmarks, totals and lags (a7d_posthoc_7county.py → a7d_posthoc_7county_summary.json):
- N = 974. Banks = 159, exactly the article's "159 independent banks"; this statistic was not used to choose the restriction.
- Mean MS = 0.00804 and SD = 0.0365, vs Table 1's 0.008 and 0.037. The frozen origins give 0.0062 and 0.031, which cannot match a 960-row sample because sum(MS) is about 7.84.

This is documentary evidence that the author's market was probably the seven-county area. No frozen R01 level contains that reading, so the frozen grid probably omits the author's construction.

The restriction was found by looking at N. Its estimates are therefore descriptive only and must not replace the origins or enter scoring. Under that diagnostic, the frozen term rule would give (a7e_posthoc_7county_termscores.csv):
- M2 SD = -0.0186 (consistent).
- M3 SD2 = -0.0053 (consistent).
- M3 SD = 0.1275 (d = 2.40, grey; it is outside at the origins).
- M3 TER = -4.75 (still outside).
- M3 intercept = -0.114 (still discrepant).
- Model 3 without the first-order term: SD2 = -0.0009 (consistent).

### Concentration of the WLS weight

With weights = MS, the regression is dominated by a few banks (a7 D4, a7c_topbank_deletion.csv):
- First Bank NA (66855) carries 30% of total weight at O_A, Norwest (995151) 21% and Marquette (37855) 6%.
- 357 bank-years with MS < 0.001 carry 3% of the weight.
- Deleting single large banks moves the Model 3 TER from -0.74 to -15.0 at O_A and from -0.68 to -16.4 at O_B. Deleting Marquette alone gives -15.0 and -16.4.
- Deleting First Bank removes H3 at O_A (SD -0.005, SD2 -0.0003, p = 0.47). The registered bank-deletion influence summary shows the same result.

These figures are influence diagnostics, not confidence intervals and not specifications.

### (a) H3: Model 3 first-order SD term outside the 3-SE band at both origins (published 0.170 vs 0.112 / 0.100); SD2 consistent

- Internal consistency of the published table. By the omitted-variable identity b_SD(M2) = b_SD(M3) + b_SD2 x delta (a7_D1_ovb_identities.csv):
  - The published Models 2 and 3 imply delta = 31.7 (rounding range 29.1-34.7).
  - The reconstructed exact delta is 29.3 at O_A and 27.1 at O_B. The published Models 1-3 are therefore mutually consistent and close to the reconstructed collinearity structure.
- The SD-term gap is mostly the curvature gap (a7 D2):
  - The two coefficients are about -0.98 correlated.
  - At O_A, 0.050 of the 0.058 SD-term gap comes from the smaller |SD2| (0.0043 vs 0.006). The rest comes from delta (0.014) and the M2 term (-0.006).
  - The SD2 term scores consistent only because its SE is printed coarsely. Under the SE implied by F = 134.1 (about 0.0005), the SD2 gap is 2.2-3.3 (O_A) or 2.8-4.0 (O_B) of those units (post hoc).
  - The fair description is that the reconstructed concave curve is about 30% flatter: turning point 13.0 / 12.8 vs 14.2 (published rounding range 13.04-15.5). Sign, significance and concavity agree.
- Verdict: survives adversarial review in the sense that no error explains it, and remains unresolved.
  - It is not a confirmed discrepancy. The formal outcome is indeterminate (N outside tolerance) under the frozen rules.
  - The post hoc market-definition evidence and the dependence on single large banks make sample construction a plausible cause.

### (b) Model 3 total expense ratio (published -15.387 vs -5.93 / -7.12)

- The TER term agrees in M1 (-9.00 / -9.03 vs -9.948) and is consistent in M2 (-8.62 / -8.80 vs -10.601). The gap appears only when SD2 enters.
- The published Models 2 and 3 imply an auxiliary coefficient of SD2 on TER, given the M2 regressors, of -798. The reconstruction gives +626 (O_A) and +428 (O_B); the sign is reversed.
- The M1 to M2 link is similar: the published table implies -32.7 vs a reconstructed +27.6 / +36.2.
- Unweighted Table 1 points the same way: corr(TER, SD) and corr(TER, SD2) are 0.13 and 0.09 published vs 0.23 and 0.25 reconstructed.
- So, among the heavily weighted banks, the reconstruction has highly deviant strategies with high expense ratios, and the published data imply the opposite.
- No uncertain spec (0/84) is consistent.
- Single-bank deletion spans the published value, as described above.
- No unit, item or code error was found: TER = (RIAD4073 + RIAD4093)/AA matches the article's definition.
- Verdict: survives as unresolved, attributable to data composition among a few large banks (sample construction or vintage), not to an identified error. It is a nuisance-tier claim and formally indeterminate (N outside tolerance).

### (c) Model 3 intercept (published 0.511** vs 0.025 / 0.229)

- In WLS with an intercept, the intercept equals the weighted mean of y minus the sum of slopes times the weighted means of the regressors.
- Inserting the published slopes into the reconstructed weighted means gives implied intercepts of 0.442 (O_A) and 0.420 (O_B). Both are within 0.5 published SE of 0.511 (a7b_intercept_accounting.csv).
- The gap decomposes into TER (+0.82 / +0.71), SD (-0.75 / -0.86) and SD2 (+0.36 / +0.38).
- Verdict: explained as an arithmetic by-product of (a) and (b). It is not an independent discrepancy and not an error. The formal outcome remains indeterminate.

### (d) H2 at O_B (Model 2 SD p = 0.088 vs published p < .001; O_A agrees)

- O_A is consistent on sign, inference (p = 2e-5) and magnitude (d = 1.22). O_B has the same sign, p = 0.088 and d = 2.97.
- No single one of the five origin-defining axes accounts for the difference (a7 D6). Switching O_B to O_A's other-assets definition (R14.broad) gives p = 0.0013, deposits (R18.domestic) p = 0.020, and quarter coverage (R05.min2_fallback) p = 0.044.
- The scoring correctly records origin_label_sensitive, so the outcome is indeterminate rather than discrepant.
- The F test of M2 vs M1 at O_B (p = 0.088) is the same phenomenon.
- Post hoc, the seven-county diagnostic gives -0.0186 at p < .001.
- Verdict: does not survive as a discrepancy. It is a reader-origin label sensitivity, driven mainly by the other-assets definition.

## 8. Limitations

- No model family independent of both implementer families is available. This review was performed by an Anthropic model (claude-opus-5-5), the same family as:
  - Reader A (claude-fable-5-1)
  - implementer A
  - the pre-execution checkers for B and C
- Any discrepant verdict therefore cannot be fully verified, as registry/scoring_rules_v1.json and implementation/role_record_v1.json anticipated.
- The auditor saw the published targets while running diagnostics. The seven-county diagnostic was selected after seeing N and is subject to forking-path bias. It is reported as evidence about the grid, not as a result.
- A seven-county market level could be added only through a new, pre-registered grid version on the user's direction, never as a change to run_v1 scoring. Human confirmation is still required before any final discrepant verdict.

## Files (checks/audit_v1/)

- audit_report.md
- Scripts:
  - a1_transcription_audit.py, a2_lineage_spotcheck.py, a3_calc_audit.py, a_rebuild_lib.py, a4_completeness_audit.py
  - a5_scoring_audit.py, a5b_control_label_sensitivity.py
  - a6_r13_identity_check.py, a6_proforma_row_probe.py, a6_proforma_rebuild_driver.R
  - a7_adversarial_diagnostics.py, a7b_intercept_accounting.py, a7c_topbank_deletion.py, a7d_posthoc_7county.py, a7e_posthoc_7county_score.py
- Outputs:
  - a1: a1_transcription_audit.csv, a1_transcription_summary.json
  - a2: a2_lineage_spotcheck.csv, a2_raw_hash_check.csv
  - a3: a3_wls_recompute.csv, a3_ftest_recompute.csv, a3_m3_coef_correlation.csv, a3_rebuild_O_A_summary.json, a3_rebuild_O_A_SD_1988.csv, a3_rebuild_O_A_market_by_year.csv
  - a4: a4_completeness_status.csv, a4_completeness_summary.json
  - a5: a5_term_rescore.csv, a5_claim_rederive.csv, a5_uncertain_set_term_context.csv, a5b_control_label_sensitivity.json
  - a6: a6_r13_identity_check.json, a6_proforma_survivor_rows_O_A.csv, a6_proforma_A_vs_B_rows.csv
  - a7: a7_D1_ovb_identities.csv, a7_D3_table1_compare.csv, a7_adversarial_diagnostics.json, a7b_intercept_accounting.csv, a7c_topbank_deletion.csv, a7d_posthoc_7county_estimates.csv, a7d_posthoc_7county_summary.json, a7e_posthoc_7county_termscores.csv
