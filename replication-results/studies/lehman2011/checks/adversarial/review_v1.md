# Adversarial review v1: Lehman et al. (2011), study lehman2011

Role: adversarial reviewer (coordinator subagent, Claude Opus 5.5). This role was allowed to see everything after the potential discrepancies were identified. No existing file was modified. No frozen label, alternative, tolerance or target was changed. Everything below that uses the empirical results is a post-hoc diagnostic and must not be read as a new specification or a relabelled origin.

Inputs read: the article PDF (pp. 10-12, page images plus 3-4x crops), sealed/targets_reconciled_v1.json, reconciliation/scoring_rules_v1.json, reconciliation/decisions_v1.md, implementation/manifest_neutral_v1.md (section 4), runs/scorer/score_v1.py, runs/score_v1/*, runs/exec_v1/C/code/{samples.py, margins.py}, runs/exec_v1/C/results/coefs.csv, registry/team_season_alignment.csv and its check file, and readers/fable/run1/out/forensics.json (F20).

New files, all under checks/adversarial/:
- code/desc.py rebuilds the origin sample with implementation C's own sample code and computes the indicator descriptives. It wrote a temporary parquet to the reviewer scratchpad; that file is not retained.
- code/swap.py rescores the six division and conference cells with the frozen `compare_target`, once as printed and once with the published rows swapped.
- code/me_check.py recomputes ME0 and U9a by hand from coefs.csv and tests the All quarters row.
- Outputs: division_conference_swap_scoring.csv, table1_division_conference_fingerprint.csv, all_quarters_row_m3_at_mean_minutes.csv, table1_crop.png and table5_controls_crop.png.

## Item 1: Table 5 Model 1, same division and same conference

### (a) Transcription
I checked the printed cells on PDF p.11 using a 4x crop (table5_controls_crop.png). They are correct:

| Row | Model 1 | Model 2 | Model 3 |
|---|---|---|---|
| Same division | 0.969 (0.054) | 1.025 (0.059) | 1.046 (0.062) |
| Same conference | 1.008 (0.050) | 0.997 (0.051) | 0.999 (0.052) |

None of these cells has stars. The sealed targets match the print exactly. No transcription error.

### (b) Reconstruction code and variable labels
- samples.py lines 66-67 set `same_division = (off_division == def_division)` and `same_conference = (off_conference == def_conference)`. Here `off_` is the possession team (`posteam`) and `def_` is `defteam`, both merged by season from the season-specific alignment table. The coding direction is correct (1 means same), the defence is used correctly, and the codes are not reversed. Exclusive conference coding is applied only under U5=1.
- The alignment table agrees with nflverse `div_game` for all 1,520 regular-season games (0 mismatches; team_season_alignment_check.json). The executed origin sample also shows 0 division disagreements.
- Origin-sample descriptives (N = 21,540): same_division mean 0.425 (SD 0.494) and same_conference mean 0.758 (SD 0.428). By season, the division share is 0.53 for 2000-2001 and 0.36-0.38 for 2002-2005, which is the expected effect of realignment. The two indicators are correctly nested: P(division = 1, conference = 0) = 0.

### Finding: the published labels look inverted
Printed Table 1 (p.10) lists "Same division" with mean 0.75 and SD 0.434, and "Same conference" with mean 0.42 and SD 0.493. These are our conference and division statistics with the labels exchanged. The correlations with the other variables show the same exchange (table1_division_conference_fingerprint.csv):

| Correlate | Printed row "Same division" | Our same_conference | Printed row "Same conference" | Our same_division |
|---|---|---|---|---|
| Week | -0.04** | -0.038 | 0.05** | 0.061 |
| Performance (<=AL) | 0.02** | 0.022 | -0.01 | -0.007 |
| Performance (>AL) | -0.01+ | -0.014 | 0.01+ | 0.007 |
| Total points | -0.02** | -0.012 | -0.01 | -0.015 |

The only printed statistic that matches neither labelling is the 0.19 correlation between the two indicators. Ours is 0.486, the value that nesting implies. Reader A's F20 already found that 0.19 is inconsistent with nesting. In short, the column in the authors' data that is labelled "same division" behaves like a same-conference indicator.

Table 5 carries a similar fingerprint. Look at how each published row changes from M1 to M2 and M3; these within-sample changes depend less on data vintage than the levels do.

- The published "division" row changes by +0.056 and +0.077 in log-OR. Our conference coefficient changes by +0.065 and +0.085.
- The published "conference" row changes by -0.011 and -0.009. Our division coefficient changes by -0.018 and -0.010.
- The published OR-scale SEs, converted to the log scale, are larger in the "division" row (0.056-0.059) than in the "conference" row (0.050-0.052). In our fits the conference coefficient has the larger SE (0.068-0.072, against 0.059-0.063 for division).

A swap therefore explains the pattern across models better than the printed labelling does.

### Would a swap reconcile the cells? Only partly
I rescored all six cells with the frozen scorer function, keeping our variables fixed and pairing each with the other published row (division_conference_swap_scoring.csv).

| Model, our variable | As printed: delta_se, sign, outcome | Swapped: delta_se, sign, outcome |
|---|---|---|
| M1 division (OR 1.115) | 2.49, mismatch, discrepant_candidate | 2.01, ok, grey |
| M1 conference (OR 0.916) | 1.90, mismatch, discrepant_candidate | 0.99, ok, consistent |
| M2 division (OR 1.095) | 1.14, ok, consistent | 1.81, mismatch, discrepant_candidate |
| M2 conference (OR 0.977) | 0.38, ok, consistent | 0.82, mismatch, discrepant_candidate |
| M3 division (OR 1.105) | 0.91, ok, consistent | 1.90, mismatch, discrepant_candidate |
| M3 conference (OR 0.997) | 0.02, ok, consistent | 0.79, mismatch, discrepant_candidate |

Neither labelling makes all six cells consistent. A swap clears M1 but creates four sign flags in M2 and M3. Under both labellings, every flag comes from the sign criterion alone. No cell has magnitude above 3 SE (the maximum is 2.49) or an inference change of two or more bands. Every published estimate involved is nonsignificant, within about 1 SE of OR = 1 (z of 0.16 to 0.74 on the published scale).

### (c) Scoring arithmetic (hand check)
- M1 same_division: published 0.969 gives the log interval [ln 0.9685, ln 0.9695] = [-0.03201, -0.03098]. The interval excludes 0, so sign is assessable. The reconstruction is +0.10905, so sign mismatch. Distance 0.14003; SE upper bound 0.0545/0.9685 = 0.05627; delta_se = 2.488. p = 0.066 is band 3 against published band 4, so inference is consistent. Outcome: discrepant_candidate, via the sign criterion. This matches the record.
- M1 same_conference: [0.007472, 0.008464] against -0.08776. Distance 0.09523; SE upper bound 0.0505/1.0075 = 0.05012; delta_se = 1.900. This matches.
- The scorer follows the frozen text. "Published interval" in the sign rule is the rounding interval, so a printed OR of 1.008 makes the sign assessable even though the estimate is nowhere near significant. This is a design property of the frozen rule, not an arithmetic error. Both item 1 flags rest only on this property.

### (e) Verdict on item 1: uncertain (not overturned, and not a sound discrepancy)
- It is not overturned by an error on our side. The transcription, the code (validated against nflverse div_game), the alignment table and the arithmetic are all correct.
- Strong documentary evidence suggests the authors' "same division" and "same conference" labels are swapped. This is certain for Table 1, given its means, SDs and correlations, and likely for Table 5, given the cross-model changes and SE pattern. The flags may therefore come from mislabelling in the article, not from a substantive difference. However, a swap does not reconcile every cell under the frozen sign rule.
- Every flag depends on the sign criterion applied to nonsignificant estimates whose ORs are near 1. Magnitude stays in the grey zone or below. The vintage difference is moderate (N -4.7%; 2 of 1,520 games are missing from the source).

A reviewer should:
1. Compare Table 1 rows (8) and (9) with table1_division_conference_fingerprint.csv.
2. Decide whether a published nonsignificant OR of 0.969 against our 1.115 (and 1.008 against 0.916) is a meaningful contradiction.
3. Treat the paper mapping "partially reproduced" as pending, because it rests only on these two cells.

## Item 2: Table 6 marginal effects, ME0 against U9a

### (a) Transcription
I checked all 35 cells, with their SEs and stars, against the PDF p.12 image. All of them match the sealed targets.

### Reconstruction check
I recomputed the MEs independently from coefs.csv and the rebuilt origin sample (code/me_check.py). My values reproduce implementation C: for q4, d = 0, ME0 = -0.016097 (p = 0.0529) and U9a = -0.004902 (p = 0.0155), identical to the record. Hand check of the scoring arithmetic: the q4, d = 0 interval is [-0.00555, -0.00545]; distance 0.010547 divided by 0.00045 gives delta_se = 23.44, which matches. Origin counts: 18 discrepant_candidate, 9 grey, 8 consistent. None has a sign mismatch, and the median ratio of reconstructed to published ME is 2.6. Under U9a the counts are 28 consistent, 2 grey and 5 discrepant_candidate, with a median ratio of 0.89.

### (d) Stata convention, from knowledge
- After `xtlogit, fe`, Stata's default `predict` statistic is `pc1`: the probability of a positive outcome conditional on exactly one positive outcome in the group. The other statistics are `pu0` (probability with the fixed effect set to 0), `xb` and `stdp`. Confidence: high.
- The xtlogit (fe) and clogit postestimation entries say `margins` cannot handle the default `pc1` correctly, and that `margins` should be used with `predict(pu0)` or `predict(xb)`. Confidence: high that this note exists. Running `margins` without `predict()` either errors ("prediction is a function of possibly stochastic quantities other than e(b)") or must be overridden. Confidence: moderate, about 70%.
- The default `margins` result is an average over observations; "controls at means" requires `atmeans`. In Stata 10, `mfx` evaluated at means by default and was used with `predict(pu0)` after the fe estimators.
- Conclusion: the only probability-scale prediction the stated software supports after `xtlogit, fe` is `pu0`, so the probability is invlogit(x-bar b) with no intercept and no group effect. With "control variables held constant at their means" (Figure 2 note), that is ME0, provided the regressors are coded as ours are. ME0 is therefore the closer match to the stated software's behaviour. U9a (averaging over estimated team effects from a dummy-variable logit) is not a Stata default after `xtlogit, fe`. It is closer to what `logit y x i.team i.year` followed by `margins, atmeans` would give.
- A wording correction for decisions_v1.md: it calls `pu0` "the default used by margins". More precisely, `pu0` is not the default prediction (`pc1` is); it is the probability prediction that margins supports. The label and its basis are otherwise sound. No label change.

Caveat on ME0. Under `pu0`, the level of the index is arbitrary: it depends on the zero points of every regressor and on the normalisation of the conditioned-out team effects. In our M3 fit, the average estimated team effect plus intercept is about -1.29 on the logit scale (M2: about -0.17). That shift alone produces the 2-3x gap in the M3 rows. Season base-year choices cannot shift the index this far, because the season effects are at most 0.14, and Table 1's means for the controls match ours. If the authors had used `pu0` with our coding, their M3 numbers should look like ME0. They look like U9a. This suggests the authors did not use `pu0` with the group effect at 0, or that their coding differed in a way not documented. This is a result-informed inference and cannot change the frozen origin.

### Additional publication diagnostic (post hoc, not an alternative)
The "All quarters" row is labelled as Model 2 (Table 6 note), but it is internally inconsistent with Table 5 Model 2. Published M2 perf_above is 0.994 (SE 0.007), nonsignificant with z of about -0.9. Yet the All quarters MEs at d = 14, 28 and 42 carry ** with z of about 3 to 6+. At fixed covariates, a single-term logit ME and its coefficient have nearly the same z; our M2 gives p = 0.33 for the coefficient and 0.31 for the ME. Evaluating our M3 at mean minutes (30.24) under the U9a convention reproduces all seven All-quarters magnitudes within 0.93 published SE (all_quarters_row_m3_at_mean_minutes.csv): for example -0.00255 against -0.0026, -0.00182 against -0.0022, and -0.00050 against -0.0006. Neither M2 convention does this. The All-quarters row was probably computed from Model 3, not Model 2 as the note states. This observation is post hoc and result-informed. It must not enter the scored outcomes, but it bears on the H1A secondary shares, where 3 of 4 are flagged, all from this row.

### (e) Verdict on item 2: uncertain (convention-driven; no reconstruction error)
- It is not overturned by transcription, code or arithmetic. All were verified.
- It survives under the frozen origin ME0, which is also the convention closer to the stated software's `pu0`. But the size of the difference depends almost entirely on the unidentified location of the probability scale. The prespecified uncertain variant U9a makes 28 of 35 cells consistent. Six of the remaining seven are in the All quarters row, which appears to have been computed from a different model than the one stated. All signs match under ME0.
- These targets are secondary and do not change any claim outcome under the frozen rules. They should be reported as label-sensitive, with ME0 and U9a shares side by side and with the All quarters row diagnostic noted. They should not be reported as 18 discrepancies.

A reviewer should:
1. Check the Table 6 and Figure 2 notes against the Stata `pu0` convention.
2. Review me_variant_comparison.csv (ME0 against U9a by cell).
3. Check the All quarters row's significance against Table 5 M2 perf_above.

## Summary
| Item | Verdict | Error found on our side | Main reason |
|---|---|---|---|
| 1. M1 same division and same conference | uncertain | none | The published labels appear swapped (certain in Table 1, likely in Table 5). The flags rest only on the sign rule applied to nonsignificant near-null ORs. A swap clears M1 but flags M2 and M3. |
| 2. Table 6 under ME0 | uncertain (label-sensitive) | none | ME0 matches Stata's `pu0` convention (moderate-high confidence), but the published values match U9a (28/35). The All quarters row appears to come from M3, not M2. |
