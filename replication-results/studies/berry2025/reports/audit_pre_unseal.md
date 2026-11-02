# Pre-unseal audit, berry2025

Scope: the four checks requested. Nothing under sealed/author_package/ was opened. No existing file was changed. Scratch code ran outside the study folder, including an instrumented copy of score.py.

## Result

| Check | Confirmed errors |
|---|---|
| 1. Transcription and key mapping (22 focal claims, 4 Ns) | 0 |
| 2. Lineage and completeness | 0 |
| 3. Calculation and hand scoring | 0 |
| 4. Scorer against rules | 14 |

No scorer error was found to change a focal, family or paper outcome in this run, as far as tested (see the effect column). Two of them leave required reporting undone. Separately, the rules let all nine H2 claims score consistent although the printed SEs and CIs do not reproduce. That is not a code error, but it is the most important thing a reader of "consistent" needs to know (section 5).

## 1. Transcription

Every field was checked against the text layer of D01_article.pdf, by PDF page: means, t, df, p, d, and B, SE, CI, p for indirect effects.

| Claims | PDF page | Result |
|---|---|---|
| P1 you_grant, prom_voice, proh_voice | 9 | all correct |
| T2 three outcomes | 11 | all correct |
| PM2 you_grant; prom_voice benevolence and value alignment | 11 (value alignment p runs to 12) | all correct |
| PM2 prom_voice relational concerns; proh_voice three | 12 | all correct |
| C3 you_grant and prom_voice cells, H1, H3 | 13 | all correct |
| C3 proh_voice cells, H1, H3 | 14 | all correct |
| L4.M1.LoyalRequestor coef, SE, p, OR | 15, Table 6 on 16 | all correct |
| N1 530 | 7, Table 1 on 8 | correct |
| N2 186 | 10, Table 1 on 8 | correct |
| N3 286 | 12, Table 1 on 8 | correct |
| N4 50 | 15, Table 1 on 8 | correct |

Mapping is also correct. LC, CC and LD match the article's loyal/no-history, colleague/no-history and loyal/divisive descriptions. Data coding confirms it: cond_recode, cond_rel_recode and cond_brokhist_recode all cross-tabulate as the keys assume.

Faithful transcriptions of values the data do not reproduce. These are article-side, not target errors:

| Target | Article prints | Recomputed | Note |
|---|---|---|---|
| P1.proh_voice.t | 16.76 (p.9) | 16.874 | t enters no outcome, so this is invisible at claim level |
| P1 d (three outcomes) | 0.86, 0.71, 0.67 | 0.868, 0.721, 0.677 | print mismatch only |
| C3.cell.proh_voice.LD.mean | 2.12 (p.14) | 2.186 | printed t 1.77 and d 0.262 fit 2.19, not 2.12 |
| C3 d: H3 you_grant, H1 and H3 prom_voice, H3 proh_voice | 0.412, 0.465, 0.283, 0.262 | 0.413, 0.464, 0.284, 0.263 | third decimal only |
| T2.prom_voice.sd_loyal | 1.95 (p.11) | 1.692 | non-focal field |
| D1.mean.prom_voice | 3.88 (Table 2, p.9) | 2.880 | non-focal; makes S1.table.D1 indeterminate |
| C3.cell.proh_voice.LD.sd | "1.1.29" (p.14) | 1.289 | printed garble, stored as printed; unparseable |

The 2.12 is the closest focal call: S3.contrast.proh_voice.H3 sits at 0.21 published SE against the 0.25 limit only because of it.

## 2. Lineage and completeness

| Study | Raw rows, cols | Bundle rows, cols | Removed columns match registry | Kept cells identical to raw |
|---|---|---|---|---|
| 1 | 1060, 58 | 1060, 51 | yes (7) | yes |
| 2 | 186, 52 | 186, 47 | yes (5) | yes |
| 3 | 286, 37 | 286, 32 | yes (5) | yes |
| 4 | 50, 45 | 50, 45 | yes (0) | yes |

- No rows dropped and none reordered, by cell-by-cell string comparison. No values of removed or free-text columns were printed.
- Source, bundle and dictionary SHA-256 values all match registry/source_registry.json.
- runs/empirical_20261031T084512Z is the only empirical run. A, B and C each hold 12,710 rows, all status ok, rc 0, and all file hashes match the *_run.json records.
- Raw key tuples differ in labels: dataset is 1 versus D1, some methods are descriptive versus pearson or cronbach_alpha, and intercept case varies. After the normalization at score.py:15-18 the three sets are identical (12,710 shared, 0 duplicates).
- score.py, scoring_rules.json, the targets, manifest and grid match their hashes in logs/freeze_pre_execution.json and logs/pre_unseal_hashes.json.
- Re-running score.py in scratch reproduced claim_outcomes.json, statistic_comparisons.csv, implementer_agreement.csv and n_branch.json byte for byte. paper_summary.json differs only in key order (score.py:278 iterates a set) and is equal as an object.

## 3. Calculation

Own Python from data/derived/implementer_bundle only, compared with the consensus in scoring/outputs_v1/implementer_agreement.csv and with A, B, C in results.csv.

| Quantity | Mine | Run | Status |
|---|---|---|---|
| Study 1 paired you_grant: diff, t, df, p | 1.5000, 22.0582, 529, 6.007e-77 | same | all_agree |
| Study 2 Welch you_grant: t, df, p | 4.0279, 160.67, 8.659e-05 | same | all_agree |
| Study 2 benevolence on you_grant: ind, se_delta, p_delta | 0.59353, 0.18320, 0.001196 | same | all_agree |
| Same, own bootstrap (5,000, BC interval) | [0.168, 1.022], se 0.220 | [0.173, 1.040], se 0.219 | within 0.05 |
| Study 3 pooled LC-CC you_grant: diff, t, df, p | 0.73584, 3.32896, 282, 9.877e-04 | same | all_agree |
| Study 4 Model 1: coef, se, p | 0.93927, 0.36153, 0.009376 | 0.93927, 0.36153, 0.009375 | all_agree |

Non-bootstrap values matched to at most 7e-07 absolute, and that largest gap is the logit SE. I extended the recomputation to all 22 focal claims. The largest bootstrap gap from consensus was 0.018 on a CI bound, inside the 0.05 tolerance.

Hand scoring with scoring_rules.json:

- diff, S3.contrast.prom_voice.H3. Printed 2.29 - 1.87 = 0.42, interval [0.41, 0.43]. Estimate 0.41624 is inside it, so distance 0 and magnitude passes. Sign passes. Printed p 0.057 is band .05-.10 and p 0.05689 is the same band, so inference passes. Native p is not below .05, so fragile_inference cannot apply. No equivalent level, so fragility not assessed. Student 0.0928 and Welch 0.0903 are on the same side of alpha, so not label sensitive. Result: consistent, matching the scorer.
- ind, S2.ind.proh_voice.val_align. Printed 0.18, interval [0.175, 0.185]. Estimate 0.17900, distance 0. Printed CI [-0.01, 0.37] includes zero, and BC [-0.061, 0.475] and percentile [-0.075, 0.465] include zero. Inference passes. Delta p 0.180 is band p>=.10 against printed .066 in band .05-.10: adjacent, same side, reported separately. Result: consistent, matching the scorer.
- coef, S4.M1.LoyalRequestor. Printed 0.94, interval [0.935, 0.945]. Estimate 0.93927, distance 0. Printed p .009 and p .00938 are both band p<.01. HC0 p .0027 on the same side. Result: consistent, matching the scorer.

An independent re-score of all 22 focal claims from my own values, with no scorer functions, gave the same magnitude, sign and inference results for every claim.

## 4. Scorer against rules

Confirmed departures. Rule references are line numbers in scoring/scoring_rules.json.

| # | Code | Rule | Departure | Effect in this run |
|---|---|---|---|---|
| 1 | score.py:30 | line 6 | Relative tolerances are multiplied by max(1, abs a, abs b), so they are absolute below 1. se_boot at "10 percent relative" allows 0.10 absolute on values near 0.14 | Tested by re-run with a true relative rule: 28 rows move from all_agree to a pair (L4 p and p_hc0, LMM1 p, MED4 p_delta). No claim outcome, inference, label flag or impl status changes |
| 2 | score.py:116, 120, 19 | lines 14, 16 | A missing estimate always has status absent, all_missing or no_pair, so line 116 returns implementer_disagreement and line 120 (incomplete_coverage) is unreachable. Row status is also read and never used | Latent: all rows ok |
| 3 | absent | line 14 | not_attemptable has no code path | Latent |
| 4 | score.py:55-59 | line 5 | n_branch_selected and n_unmatched go to n_branch.json only; claims are not marked | Latent: all four studies code origin |
| 5 | score.py:189, 218 | line 16 | magnitude_not_audited is never emitted. A missing L4 SE would raise TypeError at line 218 | Latent |
| 6 | score.py:147, 203 | line 15 | all_equiv_out is hard-coded True for indirect effects, ignoring the percentile reading. For diffs it tests only p band membership, not sign, magnitude or two-or-more bands | No effect: the one candidate (S2.serial.relconcerns) fails on magnitude, and percentile shares its point estimate |
| 7 | score.py:146, 149 | line 12 | Stability tests the side of alpha only; the rule also requires the same sign | No effect found; Student and Welch share the mean difference |
| 8 | score.py:11, 62, 184, 207-212 | lines 12, 17; frozen_grid_v1.json | Only method alternatives are scored. Sample and composite levels are never used: equiv_comp and cl are declared and never passed. The grid labels existing as equivalent_one_reader and the sample alternatives, sum and Study 4 mean as uncertain | Tested on values: sample levels identical on every non-bootstrap row (0 differences); existing equals mean; sum only rescales; Study 4 mean moves only M3, with no side-of-alpha change |
| 9 | score.py:199 | frozen_grid_v1.json, SM2 | For dataset 2 it reads ci_norm, which the manifest does not define for SM2, so the lookup is absent and uok is vacuously True. The grid names delta/Wald p | Tested: p_delta .0003 and .0077 agree with the BC reading, so no change |
| 10 | score.py:116, 138, 185, 201 | line 7 | Disagreement is judged on the point estimate only, not p, SE or CI. A no_pair CI gives NaN, which line 201 reads as instability rather than disagreement | One live path: S4.med.ind.SignedTrust, logit_strong upper bound is no_pair. The flag stands anyway, because each implementer's interval includes zero there |
| 11 | score.py:39 | line 7 | "Send the third to code audit" is not implemented and no audit record exists in scoring/, logs/ or checks/ | 21 pair rows await audit, plus 3 partial rows: L4.M3.LoyaltyHouse and intercept se and z, and MED4 boot quantities. All non-focal |
| 12 | absent | line 18 | The required sensitivity for the one-reader focal mark on the Study 4 overview table (S4.overview_table_mediation_mark, reconciled focal in claims_ledger.csv) is not computed | Required reporting missing. Not estimated here |
| 13 | score.py:274; absent | line 19 | comparability_map is not implemented, and the "pending adversarial review" note at line 274 is assigned and never written | Latent for the note, since no family is discrepant. The map is not produced |
| 14 | score.py:247-256 | none stated | Target families with no claim-level outcome; see below | Required coverage gap |

Target families with no claim-level outcome:

- G1C (80 keys), G1W (4), G2C (10), G2W (2): 96 of 484 targets, 20 percent. These receive print comparison only, and ledger claims S1.gender_cells, S1.gender_within and S2.gender have no outcome.
- All four G1W t targets fail under the origin paired method (for example 10.33 printed, 15.29 recomputed, printed df 470) and match the Student and Welch rows. No claim records this.
- Print comparison only, within scored families: L4 fit (9 keys, also ledger claim S4.fit), L4 odds ratios (10), eta2 (21), d (21), and all means and SDs.

Non-issues I checked:

- Rounding intervals, band construction, adjacency and pass_stronger logic (score.py:63-100) match the rules.
- Derived SE, the difference interval, sqrt(F) in t units and the multi-df F limits match the rules.
- Family and paper aggregation (264-277) match. Amendment 1 explicitly leaves score.py unchanged.
- The instrumented run shows the only absent lookups are the four SM2 ci_norm keys in item 9. p_hc3 and d method labels resolve correctly.
- The focal set in code equals the rules' 22, and tiers match the ledger where claim names coincide. 26 ledger keys use different names and have no explicit crosswalk.
- The H1 family of 10 claims (3+3+3+1) and H3 family of 3 are correct.
- No focal claim is label sensitive. The six label-sensitive claims are real flags.
- Two-pair "partial" status (score.py:39), the sign exemption at 188 and the CI-mismatch grey rule at 197 are undeclared elaborations where the rules are silent, none triggered in a scored outcome. Rule gaps rather than errors.
- Table outcomes require an exact print match, which is stricter than the rule's "share reported" and leaves the share reported.
- Dead code at score.py:225-227 and 233 is harmless.

## 5. What "consistent" does and does not cover

The H2 rule tests the point estimate and zero exclusion only. Printed SEs and CI bounds enter no pass or fail. All nine are consistent by rule, and the estimates do match, but no printed SE reproduces.

| Claim | Printed SE | se_boot | se_delta | Printed CI | BC CI (consensus) |
|---|---|---|---|---|---|
| you_grant benevolence | 0.14 | 0.219 | 0.183 | [0.32, 0.86] | [0.173, 1.040] |
| you_grant value alignment | 0.11 | 0.143 | 0.137 | [0.20, 0.63] | [0.180, 0.741] |
| you_grant relational | 0.13 | 0.143 | 0.137 | [0.15, 0.65] | [0.147, 0.726] |
| prom_voice benevolence | 0.13 | 0.200 | 0.177 | [0.32, 0.84] | [0.210, 0.986] |
| prom_voice value alignment | 0.10 | 0.134 | 0.130 | [0.18, 0.57] | [0.158, 0.679] |
| prom_voice relational | 0.12 | 0.144 | 0.130 | [0.10, 0.57] | [0.080, 0.642] |
| proh_voice benevolence | 0.15 | 0.207 | 0.197 | [0.31, 0.89] | [0.213, 1.022] |
| proh_voice value alignment | 0.10 | 0.136 | 0.134 | [-0.01, 0.37] | [-0.061, 0.475] |
| proh_voice relational | 0.13 | 0.160 | 0.146 | [0.07, 0.59] | [0.045, 0.681] |

- se_boot exceeds the printed SE by a factor of 1.10 to 1.56 in all nine. My own bootstrap agrees with the run, so this is not implementation noise.
- Each printed CI equals estimate +/- 1.96 printed SE to rounding, although the article calls them bias-corrected.
- Delta p differs from printed p, for example .180 against .066 on proh_voice value alignment.
- I did not establish the cause. It is a natural question for the author script at unsealing.

Also rule-permitted and unseen at claim level: P1.proh_voice t (16.87 against 16.76), since t enters no outcome, and df, which is recorded but never tested. Recomputed df do round to the printed values for every focal t test.

The one discrepant_candidate is non-focal: S2.serial.relconcerns, printed 0.71 against 0.149 (2.42 SE), a1 1.909, d21 0.329, b2 0.238. Key mapping fits D03 PDF p.3. The printed CI there is [0.71, 0.21], evidently not an interval, so it remains open. S2.serial.val_align (0.47 against 0.389) is grey.

## Limits of this audit

- Effects marked latent rest on reading the code path, not on a corrected re-run. Only item 1 was re-run with a fix.
- Transcription used the PDF text layer, not page images.
- The audit does not establish why any article value differs from the data.
