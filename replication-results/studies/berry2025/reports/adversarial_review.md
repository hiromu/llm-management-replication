# Adversarial review, berry2025

Post-unsealing diagnostic. Written after scored results were hashed. Frozen results, labels and scores are unchanged; every fit reported here is a new diagnostic, not a frozen output.

## Limits on this review

- The reviewer is Claude Opus 5.5, an Anthropic-family model and the same model as the coordinator, run as a coordinator subagent. The implementation families are Anthropic (Fable 5.1, implementer A) and OpenAI (GPT-6 Astra, implementers B and C). No model family independent of both was available, so independence is limited and no finding here may be called fully verified (scoring_rules_amendment_1.json; workflow.md).
- The brief named the findings and the files to check, and the reviewer saw the author script from the start. This review was not blind.
- No human reviewed these findings.
- Fits ran under lavaan 0.6-21 (R 4.6.1), the version recorded for the author rerun. The authors' own lavaan version is not recorded. Raw data hashes for Studies 1 to 4 match the copies in runs/author_rerun/data/.

## Dispositions

| Finding | Disposition | Responsible | Traces to |
|---|---|---|---|
| A. S2.serial.relconcerns, 0.149 vs 0.71 | Overturned as a discrepancy. A reporting defect remains. | D03 text and author script; manifest for an unlabelled path choice | Nothing written, plus article text that misdescribes model 2 |
| B. S2.serial.val_align, 0.389 vs 0.47 | Overturned as a potential discrepancy. Frozen grey_zone stands as the score. | Same | Nothing written |
| C1. Study 1 prohibitive t, 16.87 vs 16.76 | Survives as a published-record mismatch. Cause cannot be decided. | Article | Article text |
| C2. Table 2 promotive mean, 2.88 vs 3.88 | Survives as a printed error | Article | Article text |
| C3. Study 2 promotive loyal SD, 1.69 vs 1.95 | Survives as a printed error | Article | Article text |
| C4. Study 3 promotive relationship eta2, .036/.037 vs .048 | Survives as a printed error | Article | Article text |
| C5. Study 3 prohibitive LC SD, 1.93 vs 1.74 | Survives as an internal inconsistency | Article | Article text |
| C6. Study 3 prohibitive LD mean, 2.19 vs 2.12 | Survives as a printed error | Article | Article text |
| C7. Online Appendix Table 1 dishonesty control t, 1.16 vs 1.61 | Survives as a printed error | Online Appendix | Article text |
| C8. Study 1 promotive interaction p, .994 vs .944 | Survives as a printed error | Article | Article text |

Meaning of the words. For A and B, overturned means the gap is explained by a model difference and is not evidence that the published number fails to come from the deposited data. For C, survives means the printed value really does differ from what the data give and no transcription, label, code or model reading of ours caused it. None of the C items is an AI misreading, and none is a reproduction failure of the analysis.

## Findings A and B: serial models

### Source text

D03 PDF p.2-3, checked on the rendered page, not only the text layer. Model 1 is B = 0.47, SE = .11, CI [0.47, 0.14], p < .001. Model 2 is B = 0.71, SE = .23, CI [0.71, 0.21], p = .002. D03 gives only an arrow chain for each model and describes model 2 as "re-ran model 1 replacing" the second mediator.

D12 question 8 gives the same arrow chains and calls them models to "also conduct". It says nothing about direct paths, residual covariances, software or bootstrap for them. Its 5000 bootstrap sentence is under question 5, for H3a-d. D22 concerns only the power typo. The dictionary D32 defines relconcerns_with_broker and the broker_rep items, and is silent on the model. D01 does not report the serial models.

### Readers, targets, manifest, code

- Transcription is correct. Both readers record the same values, and targets_reconciled.json holds 0.47/.11 and 0.71/.23 with status agree.
- Both readers flagged the malformed CIs (fable forensics 8; astra forensics 119, 121). score.py already sets ci_usable=False for these claims, so the printed CIs did not drive the scores.
- Neither reader wrote a path set. Fable wrote "a1*d21*b2" with covariance method unstated. Astra wrote "regression estimator/link unstated" and "covariance_method: unstated", and listed condition, benevolence and the second mediator as predictors of the outcome.
- manifest/implementer_manifest_v1.md then froze a saturated model: m2 on condition and benevolence; you_grant on condition, benevolence and m2. frozen_grid_v1.json lists only inference alternatives for SM2 (ci_perc equivalent, delta/Wald uncertain). No path-set alternative was carried, so "every equivalent reading" in the frozen outcome tested interval methods only, never model structure.
- The code is right for what the manifest asked. A, B and C agree at 0.14914 and 0.38868, and an independent lavaan fit gives the same point estimates. They differ only in bootstrap quantities.

### Author script

Sealed script lines 214-247. The two models are not parallel:

- Model 1: benev ~ cond; val_align ~ benev; you_grant ~ val_align; benev ~~ you_grant.
- Model 2: benev ~ cond; relconcerns ~ benev; you_grant ~ relconcerns; benev ~~ you_grant; relconcerns ~~ you_grant.

Neither has a direct path from condition or benevolence to the outcome, and neither has a direct path from condition to the second mediator. Each adds residual covariances that no document mentions. Model 2 adds one more than model 1, so "re-ran model 1 replacing" in D03 does not describe what was run.

The rerun, with the recorded rename of reputation_with_broker to relconcerns_with_broker, reproduces all printed values: 0.469, SE .110, p < .001 and 0.712, SE .233, p = .0023. The rename is well supported: the original column is absent from the deposit, the dictionary labels the broker_rep items "reputation with broker", and the digits match under it.

### One difference at a time

New diagnostic fits, ML, N = 186, no missing values. SE units are the absolute gap over the printed SE, with no rounding adjustment.

| Specification | val_align ind (SE) | SE units vs .47 | relconcerns ind (SE) | SE units vs .71 |
|---|---|---|---|---|
| V0 saturated (frozen manifest) | 0.389 (.106) | 0.74 | 0.149 (.055) | 2.44 |
| V1 literal chain, no direct paths, no residual covariances | 0.688 (.120) | 1.98 | 0.421 (.093) | 1.26 |
| V2 chain + benev~~y (author model 1 form) | 0.469 (.110) | 0.01 | 0.289 (.077) | 1.83 |
| V3 chain + benev~~y + m2~~y (author model 2 form) | 0.881 (.227) | 3.73 | 0.712 (.233) | 0.01 |
| V4 chain + m2~~y only | 1.039 (.159) | 5.17 | 1.039 (.159) | 1.43 |

What this shows:

- Each printed estimate is reached only by its own undisclosed covariance set.
- The two written readings do not reach 0.71: the literal chain gives 0.421, and taking D03 at its word, model 1 with the mediator replaced, gives 0.289. Both fall outside the scorer's 1.0 grey limit by plain SE units. So finding A is not a misreading that a better reader of the text would have avoided. No reading of the written record reaches 0.71.
- The sign is positive and the indirect effect is significant in every row. Under the frozen delta p, the frozen and printed relconcerns values sit in the same band (.0077 and .002). The substantive sentence in D03, a significant positive serial path, survives every specification. Only the size changes.

Why the size moves so much. With no direct path, the model has to route the condition effect through the chain. The total effect of condition on you_grant is 0.943, and 0.712 is 75 percent of it, against 16 percent in the saturated model. In model 2 the fit is poor, chi-square(1) = 26.15, p < .001, RMSEA .368, with a negative residual covariance of -1.13 (p = .037), and the mediator-to-outcome path rises to 0.673 from an OLS slope of 0.398. Model 1 fits better, chi-square(2) = 5.62, p = .060, RMSEA .099. Neither D03 nor D12 reports fit.

### Other defects in the printed record

- The printed CIs are not intervals. They are the Std.lv and Std.all columns of the lavaan summary: model 1 prints ind2 at 0.469 and Std.all 0.142, model 2 at 0.712 and Std.all 0.214, matching [0.47, 0.14] and [0.71, 0.21]. The Wald CIs would be [0.254, 0.684] and [0.254, 1.169].
- The printed SEs and p values are normal-theory. The call sem(..., bootstrap = 5000) without se = "bootstrap" does not bootstrap; the rerun output reports "Standard errors: Standard". D03 does not claim a bootstrap for these models, though Fable inferred one from D12 question 5 and Astra marked it unstated for these models.
- A true bootstrap of the author models (2000 draws, BCa, one seed, Monte Carlo error not assessed) gives SE .144, CI [0.247, 0.798] for model 1 and SE .254, CI [0.204, 1.195] for model 2. Both exclude zero, with SEs above the printed ones.

### Finding A decision

Overturned as a discrepancy. Attacks that failed: transcription is correct, the label and composite are correct (composite_existing_vs_mean shows zero differences), the code is correct for the manifest, and source vintage is not at issue, since the deposit reproduces the printed digits. The attack that succeeded is the model reading. The frozen origin was not the model that produced the published number, and no document says what that model is.

Attribution. The path set and residual covariances are stated nowhere. The saturated choice is an AI choice, made by the coordinator's manifest on top of readers who wrote "unstated"; it is not a misreading, since it is a standard form of a serial mediation and the authors' own parallel models include a direct path. It is a process weakness that the grid carried it as the only structure, with no uncertain alternative, despite a reader saying the estimator was unstated. "Re-ran model 1" is article text contradicted by the script.

What survives is a reporting defect: D03 describes a model other than the one run, and prints misplaced standardized estimates as CIs. That defect should be reported as such, not as a failure to reproduce. Suggested wording: indeterminate, underdocumentation, with claim_outcomes.json left as frozen. The claim has family null and robustness tier, so overturning it does not rescore a family under the amendment rule.

### Finding B decision

Overturned as a potential discrepancy, for the same reason. Author model 1 gives 0.469 and SE .110. The frozen grey_zone score remains the score and is a fair result for a model the record does not specify. Note that V0 and V1 bracket 0.47 and neither matches.

## Finding C: printed values

For all eight, both readers transcribed the same value, targets status is agree, and A, B and C agree. Each printed value was confirmed on the rendered PDF page (D01 p.9, 11, 13, 14; D03 p.6), so none is a text-extraction or transcription error.

Correction to the brief. The author script does not compute three of these: the Table 2 mean, the Study 2 SD and the gender table. The script has no descriptive statistics for Studies 1 or 2 and no gender analysis. For those three the evidence is the deposited data and the printed record, not the author rerun. The script's output does cover C1, C4, C5, C6 and C8; C8 is at line 209 of changed_output.txt, not in author_vs_published.csv, which compares F only.

| Item | Printed | Data | Evidence | Likely nature |
|---|---|---|---|---|
| C1 | t(529) = 16.76 | 16.874 | Script gives 16.874. Printed means, SDs, df and d = .67 all match the data. | Unexplained |
| C2 | Table 2 M = 3.88 | 2.880 | Exceeds both printed condition means, 3.47 and 2.29, which is impossible. Their average is 2.88. Both readers flagged it. | Digit typo |
| C3 | loyal SD = 1.95 | 1.692 | With 1.69 the printed summary gives t 2.92, df 169.6, d .43; with 1.95 it gives t 2.66, df 156.6, d .39. Printed t 2.95, df 169, d .44. Printed Table 3 SD 1.54 fits 1.69 and falls outside the range astra forensics 141 computed for 1.95. | Typo, perhaps carried from the adjacent 1.95 control mean |
| C4 | eta2 = .048 | .0360 type 3, .0368 type 2, .0366 type 1 | Script etasq gives .0368. F = 10.53 gives .036. No sums-of-squares type reaches .048. Same value as the granting-request line. Fable flagged it. | Probably copied; .036 vs .037 is a type label difference |
| C5 | SD = 1.74 and SD = 1.93, same cell | 1.927 | Script 1.927. d = .552 fits 1.93, not 1.74 (.594). 1.74 equals the promotive SD for that cell (1.744). Both readers flagged it. | Internal inconsistency; 1.74 is wrong |
| C6 | M = 2.12 | 2.186 | Script 2.186. With 2.19, t = 1.76 (1.766 from the data) and d = .262; with 2.12, t = 2.05 and d = .305. Printed t 1.77, d .262. The same clause prints SD as 1.1.29 (data 1.289). | Typo. Resolves fable forensics 16, where d matched neither printed reading. |
| C7 | t = 1.61 | Welch 1.161, Student 1.170 | Printed p = .250 fits Welch 1.161 (p .2497), and means and SDs in that cell match. Astra left it unassessed without df. | Transposed digits |
| C8 | F(6,523) = 0.12, p = .944 | F .122, p .9937 | Script prints 9.94e-01. F in [.115, .125] implies p in [.9933, .9947]. Astra flagged it. | Transposed digits |

C1 alternatives tried, none giving 16.76: positional pairing and part_uid pairing are identical (16.874); the condition main effect in the mixed ANOVA, sqrt(F), gives 16.88 or 16.90 by SS type; the rounded difference 1.12 over the data SE gives 16.83; any single-person deletion ranges from 16.81 to 17.17; independent-samples gives 11.03. It would need an SD of differences of 1.542 against 1.532. A typo or an earlier run of the analysis are both possible and the record does not distinguish them.

Effect on scores. None changes a substantive conclusion.

- S1.table.D1 is indeterminate at 13 of 14 because of C2 alone. This traces to the article, not to reconstruction.
- S1.paired.proh_voice is consistent. Its magnitude check uses the mean difference, so C1 does not bear on it.
- S1.interaction.prom_voice is consistent on F, and .944 and .994 share an inference band.
- S3.contrast.proh_voice.H3 is consistent, but its published estimate of 0.50 comes from the C6 typo. Its 0.21 SE units passes the 0.25 limit with little room. The value implied by the correct mean is 0.43.
- C3, C4, C5 and C7 appear as print-match failures only.

## Summary

- A overturned as a discrepancy. The author script reproduces 0.71 and its SE and p, from a restricted model with undisclosed residual covariances that D03 misdescribes. Reporting defect remains. Stated nowhere; not an AI misreading, but an unlabelled AI model choice.
- B overturned as a potential discrepancy, same cause. Author model reproduces 0.47. Frozen grey_zone stands.
- C1 to C8 survive as published-record errors or inconsistencies, none from our transcription, label, code or reading. C1's cause cannot be decided; the others are shown wrong by the record's own statistics.
- Independence is limited and no human reviewed this.
