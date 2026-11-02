# Adversarial review of potential discrepancies, holderness2012

Reviewer: Claude Opus 5.5 (claude-opus-5-5), running as a coordinator subagent. This is an Anthropic-family model, the same family as implementer A (claude-fable-5-1) and Reader A. The review is therefore not model-family independent. It is also not a human confirmation.

Scope and method. I read the frozen manifest, grid, ledger, scoring rules, sealed targets, scored outputs, the A, B and C code and the article text and page images. The flagged Table 4 and Table 5 cells were checked against the page 9 image; the Table 6 cells were checked against the layout text only. All transcriptions are correct. I changed no existing file, specification, label, tolerance or scoring rule. For diagnostics I used a scratch copy of implementation C's run.py, with the grade-label lookup switched to the A/B edge-trim reading. It reproduces the A/B origin values exactly, for example cap full Steepness -0.10336 (p < 1e-7), camp full Sameness -0.1537 (p 0.0031), camp full men -0.0582 (p 0.794). I ran it on data/derived parquet files whose hashes match the run inputs. The scripts are in the session scratchpad (scratchpad/adv/d1 to d6) and are not part of the study record. All refits labelled post hoc below are diagnostics. They do not replace frozen outputs or change any outcome.

## Summary

| Item | Targets | Conclusion |
| --- | --- | --- |
| 1a Length of captivity sign, captured full | T006, T033, T081, T114 | unresolved (label-sensitive) |
| 1b Men in hierarchy sign, camp full | T018, T045, T096, T129 | unresolved (label-sensitive) |
| 1c Men squared sign, camp full | T019, T046, T130 | overturned (scale artifact; caveat below) |
| 1d Table 5 A captured simple Sameness | T057 | overturned as a formal flag (scoring-rule application); keep as a recorded contradiction of nonsignificance |
| 1e Table 5 A camp simple Sameness sign | T061 | survives (formally; weak evidence) |
| 2a Same-unit hierarchy measures, p around 0.50 | text 5.2 | survives |
| 2b Robustness hierarchy coefficients all negative | text 5.3.4 | survives for administrative intensity (and sum of ranks, not previously listed); distinct ranks survives only as a sign difference with p 0.84 |
| 2c Hierarchy x size interaction | text 6.2 | unresolved (interpretation-sensitive) |
| 2d-i ROC captured simple Steepness row | Table 5 B | unresolved (test-method-sensitive) |
| 2d-ii ROC camp full Steepness row | Table 5 B | survives |
| 3 Focal Table 4 and N | T4 | focal outcomes stand; N gap is a manifest-ordering artifact for camp models (report it) |

## 1. Lower-tier formal flags

### 1a Length of captivity (T006, T033; T6 analogues T081, T114)

Printed 0.01 (p 0.82, 0.79, 0.77, 0.80). Reconstructed -0.0010, -0.0007, -0.0007, -0.0008 (p 0.70 to 0.81). A, B and C agree.

- Construction does not explain the sign. RG 389 has no capture-date field, only DATE_REPORTED (DDMMY) and LATEST_REPORT_DATE, which records release or file closure (registry/data_dictionary_nara_pow_rg389.csv). Because the article's captured cohort ("enter the same camp in the same month") and its length variable both need an entry date, the report month is the only usable field in this file. Post hoc variants all stay negative. Truncating the 335 post-war report dates (0.33 percent, length below zero) at zero gives -0.0011 and -0.0008. Dropping those rows gives -0.0011 and -0.0008. A common September 1945 end month gives -0.0010 and -0.0006. The power-specific end month is not fully absorbed by camp dummies, because 11 camp codes (15,720 rows) mix powers, but excluding those camps gives -0.0024 (p 0.14) and -0.0024 (p 0.16).
- Scale. Printed camp full length MEs are 0.06, 0.02, 0.07 and 0.03, against reconstructed 0.0046, 0.0036, 0.0051 and 0.0037 at similar p values. Implied published SEs (0.04 to 0.06) are about 10 to 20 times ours (0.003 to 0.005). The article's length variable is probably on a smaller numeric scale than months/10, or is defined differently. Scale cannot change a sign.
- Label sensitivity, using frozen uncertain branches from runs/B_20261027T132459Z/results/results.csv. Under S008 (group_members complete), the T4 values are +0.0002 (p 0.95) and +0.0013 (p 0.65). Under S005 (rank_rule strict), T4 Sameness is +0.00003. A post hoc T6 refit under S008 gives +0.0006 and +0.0019. Under each of these the printed sign is matched and the frozen rule scores consistent. The scorer did not compute label sensitivity for control terms (branches_n is empty for these rows in scoring/claim_scores.csv). By scoring_rules_v1.json (label_sensitivity, grey_zone), these flags should carry label_sensitive and lean to indeterminate.
- Conclusion: unresolved (label-sensitive). The sign difference is in a control that is insignificant in both, with |ME| 0.001 against printed 0.01.

### 1b Men in hierarchy, camp full (T018, T045; T6 T096, T129)

Printed +0.11, +0.15, +0.09, +0.13 (p 0.41 to 0.64). Reconstructed -0.058, -0.010, -0.053, -0.010 (p 0.79 to 0.96).

- The term is the linear coefficient of an uncentred quadratic in men = ln(n)/10. Its ME is the slope at n = 1, far outside the data (mean men 0.79 in the camp sample). It is collinear with men_sq, and its sign is not a meaningful quantity on its own. The implied total size derivative at the mean, ME_men + 2 * mean(men) * ME_men_sq, is positive in all four reconstructed full models: cap 0.019 and 0.017, camp 0.108 and 0.088. That matches the article's positive size narrative.
- Label sensitivity from frozen branches. S004 (camp_valid defined) gives +0.031 and +0.069. S019 (NARA degree coordinates) gives +0.018 and +0.060. Post hoc T6 refits under the same branches give +0.036, +0.071, +0.022 and +0.060. Each of these matches the printed sign and scores consistent.
- A further reading reverses the sign: camp models estimated on the captured-model estimation rows (see item 3) give +0.038 and +0.066 (T4) and +0.044 and +0.070 (T6).
- Conclusion: unresolved (label-sensitive). These four flags should be recoded indeterminate:label_sensitive, not potential discrepancy.

### 1c Men squared, camp full (T019, T046, T130)

Printed -0.00 (p 0.96, 0.76, 0.84). Reconstructed +0.105, +0.062, +0.063 (p 0.57 to 0.71). The T6 camp Steepness cell T097 is printed "0.00" and scored consistent at +0.101.

- The printed and reconstructed quantities are not on the same scale. All eight printed men_sq MEs in Tables 4 and 6 have magnitude below 0.005. Our cap full MEs, which are scored consistent, are -0.0455 (p 0.29) and -0.0648 (p 0.14), and would print as -0.05 and -0.06. The printed values are -0.00 (p 0.18) and -0.00 (p 0.16).
- With the squared term entered as (ln n)^2, a factor of 100 that is a pure re-expression of the same fit (ledger: Squared size scaling, B A11L1 is a re-expression check), the reconstructed MEs become -0.00046 and -0.00065 for cap full. Those print exactly as -0.00 with unchanged p values. For the flagged camp cells they become +0.0010, +0.0006 and +0.0006 (verified by refit; the men ME is unchanged).
- scoring/score.py (score_target) uses the interval [v - 0.005, v + 0.005] = [-0.005, 0.005] for "-0.00". On the comparable scale all three values fall inside it, so no sign failure is triggered.
- Caveat: the article's squared-term scaling is not documented. Table 2 says only that men is divided by 10. The scale reading is inferred from printed magnitudes, so it is target-informed and should be accepted or rejected by the coordinator or a human. Under a strict signed reading of "-0.00", (-0.005, 0], the coefficient sign is still opposite. Both are insignificant (p >= 0.57), and under S004 the T046 value is +0.0033 even at our scale, which is inside the scorer's interval.
- Conclusion: overturned as an artifact of comparing different scales, with the caveat stated.

### 1d Table 5 Panel A captured simple Sameness (T057)

Printed 0.02 (p 0.27). Reconstructed +0.035 (p 0.040; C 0.044). Sign agrees and the value is outside rounding. The flag comes from inference: printed band p >= 0.10, reconstructed band 0.01 to 0.05, distance 2.

- Scoring-rule application. scoring_rules_v1.json defines potential_discrepancy as failing "sign or inference (>= 2 bands weaker)". Its inference rule says "a weaker band by 2 or more is an inference failure" and "a reconstructed result significant at 0.10 where the article reports p >= 0.10 is recorded as contradicting nonsignificance". score.py turns a stronger reconstructed band under a nonsignificance claim into an inference failure (dist = min(pb) - rb). The frozen text does not say that. It records this case as a contradiction, not as a weaker band.
- Robustness: under captured-cohort clustering p is 0.040, just inside the band. Under camp clustering (the uncertain alternative, me_p_campcluster) it is 0.088, a band distance of 1. The coefficient is positive in both article and reconstruction, so it is not in the hypothesized direction.
- Conclusion: overturned as a formal potential discrepancy (rule misapplication). Retain it as a recorded contradiction of nonsignificance.

### 1e Table 5 Panel A camp simple Sameness (T061)

Printed -0.01 (p 0.95). Reconstructed +0.039 (p 0.84). A, B and C agree. It stays positive on the common-row sample (+0.029, p 0.88). T5 was not run on uncertain branches, so label sensitivity cannot be assessed. Steepness and Sameness correlate at about 0.92 in this model and both p values are above 0.8, so the sign carries almost no information. Conclusion: survives as a formal sign flag, with weak evidential value.

## 2. Text-only robustness claims

### 2a Same-unit hierarchy measures (section 5.2)

Reconstructed: cap Steepness -0.102 (p 0.0005), cap Sameness -0.066 (p 0.0003), camp Steepness -0.213 (p 2e-7), camp Sameness -0.139 (p 3e-9). A, B and C agree under different term names (scoring/implementation_comparison_terms.csv), so this is not a code error. S020 (friends excluding self) gives the same picture (p <= 0.0002). Rank-1 share in D is 46.2 percent, matching the article's "forty-six percent ... are privates".

Post hoc readings, all strongly negative:
- Restricting to rows with a known unit: cap -0.015 (p 0.009) and -0.014 (p 0.0001); camp Steepness -0.032 (p 0.010); camp Sameness fails with separation.
- Setting singleton units to missing: p <= 0.0012.
- Computing the unit hierarchy over unit-mates excluding the POW himself, which removes the own-rank component: p <= 0.0015.

Nothing found makes these "around 0.50". Conclusion: survives.

### 2b "All robustness coefficients remain negative" (section 5.3.4)

- Administrative intensity (100 x share above private) in camp full: +0.00085 (p 0.0031). A, B and C agree; scoring/robustness_terms.csv shows pair NaN only because the term names differ. It is also positive in a post hoc camp simple model (+0.0010, p 0.034), in a no-squared-term model (p 0.006), and on the common-row sample (p 0.003). It is negative in captured models (simple -0.00027, p 0.005; full p 0.58). The definition matches the article.
- Sum of ranks, not in the coordinator's list, is also positive in camp full: ME +6.7e-6 per rank unit (p 0.023; A, B and C agree), and +7.2e-6 (p 0.002) on common rows. It appears as 0.0000 in robustness_terms.csv because of rounding.
- Number of distinct ranks in camp full: +0.0016 (p 0.84). Without men_sq it is -1e-5 (p 0.999), so this is essentially zero.
- Conclusion: survives for administrative intensity and sum of ranks. Distinct ranks is only a nonsignificant sign difference.

### 2c Hierarchy x size interaction (section 6.2)

Frozen reading (R_int, product with men in the full model): all four coefficients are negative, matching "always negative". The captured Sameness term is the most significant of the four (p 0.129; camp clustering 0.084; others 0.19 to 0.80), but it is not "highly significant". A, B and C agree.

Post hoc readings:
- Interaction added to the no-squared-term model described in the preceding paragraph of 6.2: captured Sameness p 0.0074, captured Steepness p 0.18, camp Sameness p 0.35. This reproduces "highly significant only for captured Sameness", but camp Steepness turns positive (+0.067, p 0.81).
- Simple model with men: captured Sameness p 0.0002, captured Steepness p 0.042.
- Raw count n instead of ln n: all signs positive.

No single reading reproduces both parts of the statement. The model is unreported. Conclusion: unresolved (interpretation-sensitive).

### 2d ROC p values (Table 5 Panel B)

A, B and C agree on the row definition (row = measure added; base model omits it). Swapping the row labels fits worse: both captured complex cells fail. The direct labelling matches captured complex (0.047 vs printed 0.04; 0.29 vs 0.50) and camp simple.

I approximated the Hanley-McNeil test post hoc: SEs from Hanley-McNeil 1982, and r taken as the mean Kendall tau of the two scores in survivors and in non-survivors, either uncapped or capped at 0.90 (the table maximum). The correlation table itself is unavailable.

- Captured simple Steepness row: DeLong p 0.0001; the HM approximation gives 0.056 to 0.21, bracketing the printed 0.13. The same approximation breaks three other cells: captured simple Sameness 0.06 to 0.40 (printed 0.00), captured complex Steepness 0.51 to 0.80 (printed 0.04), camp simple Sameness 0.23 to 0.61 (printed 0.00). Neither method reproduces all eight cells. Conclusion: unresolved (test-method-sensitive).
- Camp full Steepness row: the AUC increment is 1.1e-5. DeLong p 0.58 (C's rank-label reading gives 0.13); HM approximation 0.92 to 0.98. No reading reaches 0.00. The article's own Panel A (camp full Steepness 0.09, p 0.69) is also hard to square with 0.00. Conclusion: survives, as a fragile lower-tier statistic.

## 3. Focal Table 4 and sample size

- The eight focal hierarchy coefficients are consistent. I found no transcription, code or rule error affecting them. Label sensitivity is already flagged for T028 (S005) and T040 and T043 (S008).
- N. Table 4 prints 100,464 for all eight columns. Reconstructed N is 100,672 for captured models (+0.21 percent, within the 0.5 percent n_branch) and 101,993 for camp models (+1.52 percent, outside it). The article's Table 6 prints 102,334 under the same described sample, so the article's own N values are inconsistent.
- Cause of the camp gap. The manifest applies the drop of camps with constant survival (1,321 rows) only to captured models with camp dummies. Camp models keep those rows, even though sample_common = true aimed at one sample for all columns. Post hoc camp models on the captured estimation rows (N 100,672) move closer to the printed values:

| Camp model | Common-row value (p) | Printed (p) | Origin (p) |
| --- | --- | --- | --- |
| Steepness simple | -0.311 (0.056) | -0.33 (0.06) | -0.369 (0.035) |
| Sameness simple | -0.205 (0.015) | -0.23 (0.01) | -0.242 (0.009) |
| Steepness full | -0.137 (0.24) | -0.18 (0.10) | -0.169 (0.14) |
| Sameness full | -0.135 (0.010) | -0.18 (0.00) | -0.154 (0.003) |

  Every focal outcome stays consistent under this reading. Report the camp N mismatch as a manifest-ordering artifact and coverage note, not as a discrepancy.
- Side finding outside the listed items: A and B do not agree on several R_aaf (Air Force) fits. Samples are identical but values differ, for example camp full Steepness -0.029 vs -0.017 and captured simple Steepness +0.0017 vs -0.0012, with quasi-separation in the missing indicators (scoring/implementation_comparison_terms.csv). robustness_terms.csv falls back to A for these. R_aaf statements should be treated as implementation_disagreement, not as evidence.

## Net effect

No potential discrepancy among the 13 lower-tier flags survives as a clean, label-robust discrepancy except T061, a sign difference with p > 0.8 on both sides. The text-only contradictions that survive are 2a (same-unit hierarchy strongly significant rather than near 0.50), 2b (positive camp-level administrative intensity and sum of ranks), and the camp full ROC Steepness cell. All of these are lower-tier and descriptive. The focal paper-level mapping is unaffected. Any confirmation still requires a human, and this review is not family-independent.
