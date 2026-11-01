# Adversarial review v1: Thébaud (2015)

Reviewer role: adversarial review after discrepancy candidates were identified (Claude Opus 5.5, a coordinator subagent). The scoring rules ask for review "by a model family independent of the implementers", and this review does not meet that requirement. Implementers A and B (R lme4) are Anthropic-family contexts, and so is this reviewer. Record this as a limitation of the review, not as independent confirmation.

Date: 2026-10-28. Everything below is post hoc. No frozen rule, target, tolerance, score or code was changed. The diagnostic refits reuse the frozen impl_A/v1 functions unchanged, loaded by `diagnostics/load_impl.R`. Their only changes are (i) combinations of frozen branches (U09, U14), (ii) a common owner sample, and (iii) one alternative leave series built from our own derived inputs. Post-hoc "what-if" scores come from the frozen scorer `checks/score.py`, run unchanged on relabelled rows (`diagnostics/d7_whatif_score.py`). They are diagnostics and do not replace the frozen scores.

Printed article values (Table A1 country means, Table A2 descriptives, footnote 10 correlations) were used only as publication diagnostics, never as model inputs.

Compute used: 16 post-hoc mixed-model fits (15 owner-model fits and 1 M3 fit), at most 2 processes at a time with single-threaded BLAS, about 1 CPU hour of fitting plus data preparation. Influence runs for M4 and M6 were still incomplete and were not used.

## Summary table

| Item | Classification | Confidence | Main evidence |
| --- | --- | --- | --- |
| F05: M4 childcare x female | (a) pipeline error: plan-B outcome coding | moderate | The origin coding gives 18.0% plan-B; the article states 31%. Frozen branch U09 (OMREASON 2 or 3) gives 32.3%. Under U09 the estimate is -.061 (.034), p = .072, an adjacent inference band, so the what-if outcome is no longer discrepant. |
| F06: M4 part-time x female | (c) survives | moderate | Every variant gives -.021 to -.073, never near -.10. The part-time series matches Table A1 (r = .999). The best-fitting M4 specification gives -.021 (.032). |
| F09: M6 leave and leave² x female | (d) unresolved; SE gap explained (a) | low to moderate | Under U14 the SEs match the published ones (.138/.134 vs .14/.14), but the estimates stay near 0 under every variant. The growth outcome cannot be matched: 9.6–10% vs the published 17%. |
| R01: A3 model 1 childcare x female | (b) plausible documented data difference | low | The estimate is within 0.7 published SE. Only the inference band fails. The childcare series is a different concept (total ECEC). |
| M6 female main effect | (d) unresolved | moderate that no pipeline error causes it | -.80 to -.87 in every variant. The raw gender log-odds ratio in growth is about -0.6 to -0.7 under every plausible coding. The published -.29 is not reachable. |
| M8 female main effect | (a) pipeline error: leave² parameterization | high | U14 has an identical log-likelihood. Under U14 female = -.119 (.054) vs -.14 (.06). |
| H3 N mismatch (M4–M8) | (a) pipeline error: per-model complete cases | high (M4–M6), moderate (M7), low (M8) | The published N is identical (28,775) in M4, M5 and M6. A common sample gives 27,289 to 27,333 (-5%), M7 25,899 (-4.5%) and M8 15,451 (-11.7%). |
| M1–M3 N (-3%) | (b) source-file differences | moderate | GBR 2007 has 4,876 rows with missing education in the supplied file. Four surveys (2,836 rows) are lost to leave gaps. |
| Leave x female SEs 2–3x ours | (a) leave² parameterization | high | The published SE structure matches U14 (separately standardized squared leave), not the square of z. Unstandardized leave is ruled out. |
| Random female-slope SD collapse | (b) boundary estimates also present in the published fits | moderate | Published SDs are also near 0: M4 .0044/.0232, M6 survey .0001, M8 country .0000. |

The review found four concrete pipeline errors (section 2). Correcting all four together removes F05 and the M7/M8 female main-effect gaps, and unblocks the H3 sample sizes. F06 survives. F09 and the M6 female effect stay unresolved because the growth outcome cannot be reproduced. Once its sample is unblocked, F08 (M5) becomes a new discrepancy candidate.

## 1. Evidence by item

### 1.1 Leave² parameterization (leave x female SEs; M7/M8 female main effects)

The manifest (`reconciliation/frozen/manifest_neutral.md` line 95) sets leave_sq = (standardized leave)². Both implementations follow it (impl_A `run.R` line 426, impl_B `run.R` lines 122–129). Branch U14 instead standardizes raw leave² separately. The two are exact reparameterizations of the same model. Every ORIGIN/U14 pair has the same log-likelihood to 0.001: for example, M6 -8538.110 in both runs and M7 -9959.02 in both (`runs/exec_v1`). Only the coefficients of leave, leave_sq, female x leave, female x leave_sq, female and the intercept are re-expressed.

The published SEs fit U14 and not z². At survey level, cor(z, z²) = .23 while cor(z, z(raw²)) = .91 (`diagnostics/d1_data.log`). The two leave columns are therefore nearly collinear under U14, which inflates their SEs about 2.4-fold. The published leave_sq SEs are as large as the leave SEs (M3 .13/.12), which is the U14 pattern; under z² our leave_sq SE is 4–10 times smaller than the leave SE.

| Model | Published female x leave / x leave² SEs | Origin (z²) | U14 |
| --- | --- | --- | --- |
| M3 | .08 / .08 | .032 / .011 | .058 / .045 |
| M4 | .10 / .11 | .036 / .021 | .088 / .085 |
| M5 | .06 / .06 | .024 / .010 | .048 / .042 |
| M6 | .14 / .14 | .061 / .033 | .138 / .134 |
| M7 | .23 / .24 | .058 / .052 | .176 / .210 |
| M8 | .18 / .17 | .067 / .058 | .194 / .233 |

Unstandardized leave would give per-week coefficients about 12 times smaller than the printed ones, which is not what the table shows. The article also says all survey-level variables are standardized (MAIN p.14).

The female main effect is the gender gap where leave_sq = 0. Under z² that point is the mean of leave with the squared term at zero. Under U14 it is the mean of leave and the mean of leave². Because female x leave² is not zero in M7 and M8, the two main effects differ.

| Female main effect | Published | Origin | U14 | U14 + common sample |
| --- | --- | --- | --- | --- |
| M7 | -.15 (.06) | .064 (.060) | -.097 (.051) | -.114 (.053) |
| M8 | -.14 (.06) | -.002 (.055) | -.119 (.054) | -.105 (.057) |

The readers split on this choice. Astra's origin was U14; Fable's was z². Coordinator rule 3 selected z² (`reconciliation/coordinator_decisions.md`). The rule was followed correctly, but the published SE structure contradicts the result.

Fix: report the leave terms and the female main effects on the U14 parameterization. It is a mathematical re-expression, not a new scientific alternative.

### 1.2 F05 and F06 (M4, Plan-B motivation)

Plan-B coding. Manifest line 65 and impl_A `run.R` line 276 (impl_B line 68) code 1 = OMREASON 2 and 0 = OMREASON 1, 3, 4, 6. In the M4 sample this gives a plan-B share of 0.180. The article states that "31 percent of business owners said this was the case" (MAIN p.14), and Table A2 panel B gives 0.31. U09 (2 "no better choices" or 3 "both" = 1) gives 0.323. No other coding comes near (`diagnostics/d2_planb_codings.csv`): 2 vs 1 only gives .218, and OMWHY gives .180.

The full M4 column agrees better with U09 combined with U14 and the common sample (`diagnostics/d8_M4_full_column.txt`). Postsecondary is -.319 (.028) against the published -.33 (.03); the origin gives -.445 (3.7 published SE away). The intercept is -.757 against -1.00; the origin gives -1.539 (4.5 SE away). Sole is .140 against .17, and the origin .223. The female main effect is .069 (.029) against .06 (.03). The SEs of the country-level terms also come close to the published ones. The median distance over all M4 terms falls from 0.86 to 0.73 published SE. These checks use published descriptives and the coefficient structure, not the target estimate itself.

| M4 specification | female x childcare | female x parttime | what-if outcome for F05 / F06 |
| --- | --- | --- | --- |
| Published | -.10 (.04) ** | -.10 (.03) *** | |
| Origin (frozen) | -.066 (.043), p .12 | -.047 (.036), p .19 | discrepant / discrepant |
| Common sample | -.068 (.047), p .15 | -.055 (.039), p .16 | discrepant / discrepant |
| U09 (frozen branch) | -.061 (.034), p .072 | -.021 (.030), p .48 | grey (N only) / discrepant |
| U09 + common | -.066 (.037), p .074 | -.021 (.032), p .51 | grey / discrepant |
| U09 + U14 + common | -.066 (.037), p .074 | -.021 (.032), p .51 | grey / discrepant |
| Same + footnote-7 leave series | -.064 (.037), p .084 | -.025 (.032), p .45 | grey / discrepant |

F05 is classified (a). The specific error is the plan-B coding (manifest line 65; impl_A `run.R` line 276). The fix is planb = 1 if OMREASON is 2 or 3. With the fix, the estimate is within 0.8 published SE and p falls in the adjacent band (.05 to .10), which the frozen inference rule counts as consistent. Confidence is moderate: the corrected p is still above .05, and the evidence for U09 is descriptive.

F06 is classified (c). The part-time series is not the cause: its country means correlate .999 with Table A1. The other variants (U12, U13, U17, U18, U07, U08, U11, U24, U20, common sample) give -.021 to -.073, and the corrected plan-B coding moves the estimate further from the published value. Two possibilities remain and cannot be tested. One is the childcare concept (see 1.5): footnote 10 gives r(childcare, parttime) = -.25, ours is -.13 (`diagnostics/d6_wf_correlations.csv`). The other is unreported survey weighting. Neither has a documented mechanism large enough to move -.02 to -.10.

### 1.3 F09 and the M6 female main effect (growth aspirations)

The growth outcome does not match the published descriptive (`diagnostics/d2_growth_codings.csv`, `d9_growth_subsets.csv`). The manifest rule (expected minus current employees > 5) follows the article's wording and gives a prevalence of 0.096 (0.0995 in the common sample). The published value is 0.17. The source file already stores missing codes as empty cells, so treating them as counts changes nothing.

Alternative codings either miss the prevalence or keep a raw gender log-odds ratio near -0.6. Total > 5 gives .266 (log-OR -.41). Additional ≥ 5 gives .125 (-.60). Additional > 2 gives .194 (-.51). Employers with 2 or more workers give .167 (-.58). New businesses only give .148 (-.68). Only "any expected growth" reaches a log-OR of -.32, and its prevalence is .37.

The female effect is stable at -.79 to -.87 across origin, U14, common sample, U07, U08, U11, U24, U20, N01 and the footnote-7 leave series. U23 gives -.62. The published -.29 is not reachable in this file. Three anomalies are visible in the published M6 column: the intercept -1.12 (.09) has no stars despite z ≈ 12, both survey-level SDs are about 0, and the 17% prevalence does not follow from the stated rule.

| M6 | female | female x leave | female x leave² |
| --- | --- | --- | --- |
| Published | -.29 (.04) | .31 (.14) ** | -.29 (.14) ** |
| Origin | -.825 (.073) | .023 (.061) | .013 (.033) |
| U14 | -.812 (.062) | -.020 (.138) | .053 (.134) |
| Common sample + U14 | -.796 (.063) | .019 (.141) | .021 (.137) |
| Same + footnote-7 leave series | -.795 (.064) | .036 (.141) | .030 (.136) |

The SE gap in F09 is explained by the U14 parameterization (1.1). The estimates remain about 2 published SE from the targets, with p > .79 under every variant. The leave data are not the obvious cause: with the same leave series and parameterization, M7 reproduces the published curvilinear pattern, .459 (.182) and -.587 (.219) against .56 (.23) and -.58 (.24). That result is a check, not a rescue.

Because the M6 outcome demonstrably differs from the published one and cannot be rebuilt from the supplied file, F09 and the M6 female effect are classified (d) unresolved rather than (c). No error in our pipeline was found for either.

### 1.4 H3 sample sizes (N mismatch)

Manifest lines 81 and 83 require complete cases per model, implemented in impl_A `run.R` lines 473–476. The article prints the same N = 28,775 for M4, M5 and M6, and Table A2 panel B uses that one N, with footnotes only for new product (27,107) and new technology (17,498). That pattern implies a common owner sample. The coordinator log lists the common-sample branch as "uncertain, not run: budget".

| Sample | Ours per model | Common sample | Published |
| --- | --- | --- | --- |
| M4 / M5 / M6 | 31,520 / 33,626 / 29,961 | 27,289 (27,333 with the footnote-7 leave series) | 28,775 |
| M7 | 32,890 | 25,899 | 27,107 |
| M8 | 19,944 | 15,451 | 17,498 |

The common sample's year shares match Table A2 panel B to two decimals (`diagnostics/d1_data.log`). Its female share (.363), age (40.9) and postsecondary share (.458) also match the published .37, 41.31 and .44. The remaining -5% gap comes partly from CZE 2006 and FRA 2002–2004, which are lost to leave gaps (116 common-sample owners), and partly from source-file differences.

For M8, the published N is larger than the 2005–2008 share of the 28,775 sample. The M8 sample rule therefore remains unresolved.

What-if outcomes under the common sample and U14 (`diagnostics/d7_whatif_term_scores.csv`):

- F10 (M7) becomes consistent.
- F08 (M5) becomes a discrepancy candidate. Female x leave is .036 (.054), p = .51, against .12 (.06) **.
- F11 (M8 childcare) is grey: -.044 vs .13.
- The M8 female x leave term (part of F12) shows a sign mismatch: .362 vs -.04.

Unblocking H3 therefore does not make H3 consistent.

Stage 1 is within the N match band. GBR 2007 has 4,876 rows with missing education in the supplied file. CZE 2006 and FRA 2002–2004 (2,836 rows) are lost to missing leave (`diagnostics/d5_ngap.log`).

### 1.5 R01 (A3 model 1, nascent; childcare x female)

The reconstruction is -.058 (.047) against -.09 (.04) **: a distance of 0.69 published SE, with only the inference band outside. The nascent share is .037 against the published 3%, and the definition is not the issue (TEA would be .074).

The childcare input measures a different concept. It is total public ECEC spending, including pre-primary (flag concept_total_ECEC in `registry/construction/construction_notes.md`). Its mean is .61 against .31 in Table A1, and its country-mean correlation with Table A1 is .79 (Spearman .72). Large divergences: FRA 1.14 vs .36, NZL .65 vs .08, PRT .36 vs .003, BEL .61 vs .23, NLD .53 vs .14, ITA .51 vs .15. No annual childcare-only series exists in the acquired sources.

A shift of 0.03 on this term is within what a covariate of a different concept can produce. Yet the M3 childcare result, which uses the same series, reproduces. Classification is (b) with low confidence.

The R1 female main effect (-.72 vs -.56) also falls outside the band. U03 (BSTART-based nascent) gives -.59, so the nascent definition may be part of it.

### 1.6 Random female-slope SDs

Our near-zero SDs (M4 country .0005 and survey .0001; M5 survey 0; M7 country .003; M8 country .001) match boundary estimates in the published fits: M4 .0044 and .0232, M6 survey .0001 and intercept .000, M8 country .0000 and .0000.

With about 23 countries and about 30,000 owners, the female-slope variances are weakly identified. Our Laplace approximation differs from the article's routine, a disclosed deviation. A and B agree to tolerance, so this is not an implementation bug.

Classification is (b), moderate confidence. M7 differs: published country female SD .078 against our .003. That difference sits inside the same boundary-instability class.

## 2. Pipeline errors found

1. Plan-B coding (manifest line 65; impl_A `run.R` line 276; impl_B `run.R` line 68). It contradicts the article's stated 31%. Fix: OMREASON in {2, 3} = 1, which is frozen branch U09. Effect: F05 leaves the discrepant range; F06 moves further away.
2. Leave² parameterization (manifest line 95; impl_A `run.R` line 426; impl_B `run.R` line 128). The published SE structure shows separate standardization of raw leave². Fix: U14, an exact reparameterization. Effect: the leave-term SEs and the M7/M8 female main effects come into line with the article.
3. Per-model complete cases for the owner models (manifest lines 81 and 83; impl_A `run.R` lines 473–476). The published N is identical across M4–M6. Fix: one common owner sample complete on planb, size and growth, with M7 and M8 restricted by year. Effect: N within 5% for M4–M7.
4. Leave construction (`registry/construction/scripts/build_country_year.py` lines 116–147). Rule (a) scales the 2008 CEPR value by PF2.5 paid-week ratios in every year for every country. This creates level shifts in countries that, by the article's footnote 7, had no relevant policy change: AUT 30.2 vs 16, GRC 13.2 vs 33.5, NOR, CAN and POL. It also leaves FRA 1998–2003 empty. Fix: hold each country's 2008 value constant except for DNK, DEU, IRL, NZL, PRT, SWE, CHE and GBR. Post hoc this raises the country-mean correlation with Table A1 from .82 to .91 (`diagnostics/d10_leave_alt_vs_A1.txt`) and recovers FRA 2002 and 2004. The effect on every candidate is ≤ .03, so it resolves none of them. With this series and U14, M3 is unchanged in substance: female x childcare -.125 (.033) and female x leave -.005 (.059).

No implementation bug was found. The lag merge (year + lag), the standardization base (139 M3 surveys, n - 1 divisor), centering, the female coding (male reference) and the interaction construction all follow the manifest, and A and B agree.

## 3. Unresolved observations outside the candidate list

- Stage-1 activity prevalence is .171 against the published 13%. The published M1 log-likelihood of -132,749 for 354,143 rows implies a prevalence of about 13%. U04 gives .146. The H1 childcare result reproduces regardless.
- Business-age mean is 1.82 against the published 2.01. In the harmonized file, OMWAGEYR is top-coded at "1990 or earlier" for 27% of owners. This is (b), a source-file limitation.
- Other documented country-level differences: EPL_OV is the regular-contracts index (country-mean r = .85 with Table A1), and the GDP index is from current WDI (r = .96). CZE has no leave value; it has the longest leave in Table A1 (62.8 weeks).

## 4. Files

- `diagnostics/load_impl.R`: loads the frozen impl_A functions without running them.
- `d1_data.R`, `d2_coding.R`, `d3_stage1.R`, `d5_ngap.R`, `d6_wf_correlations.R`, `d9_growth_subsets.R`: data diagnostics with no fitting. Logs and CSVs sit alongside them.
- `d4_refits.R` → `d4_refits_p1.csv` and `d4_refits_p2.csv`: 10 post-hoc fits.
- `d10_leave_alt.R` → `d10_leave_alt_series.csv`, `d10_leave_alt_p1.csv` and `d10_leave_alt_p2.csv`: footnote-7 leave series.
- `d7_whatif_score.py` → `d7_whatif_term_scores.csv` and `whatif/<set>/`: the frozen scorer applied to post-hoc rows, diagnostic only.
- `d8_M4_full_column.txt`: the full M4 column, origin vs U09 + U14 + common sample.
