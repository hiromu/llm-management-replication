# Reconciliation decisions (coordinator), twenge2010

Inputs: initial reader outputs in readers/fable/initial (Reader A, claude-fable-5-1) and readers/astra/initial (Reader B, gpt-6-astra), hashes in each initial_outputs.sha256. No clarification round was requested; initial agreement is final agreement. Matching rules are in reconciliation/scripts/reconcile.py; raw decisions are in reconciliation/ledger.json and agreement statistics in reconciliation/agreement_initial.json. No empirical result existed when these decisions were made.

## Initial agreement (before any clarification)

| Measure | Units | Agree | Gwet AC1 |
| --- | --- | --- | --- |
| Claim tier (matched analytic units) | 54 | 53 | 0.978 |
| Specification level labels (matched levels) | 18 | 13 | 0.669 |
| Item-to-source mapping | 29 | 29 | not computed (single category) |
| Factor membership | 29 | 29 | not computed |
| Freed-intercept flags | 19 | 19 | not computed |
| Altruistic marker item | 1 | 0 | structural |
| Transcription, Tables 1 and 2 (printed numbers) | 519 Reader A cells | 519 matched in Reader B | separate measure |

Reader B transcribed 12 additional null cells (fit-index deltas not printed). No printed value differs between readers.

## Decisions

D1 Focal claims. Both readers label the 15 latent-mean contrasts (five factors by three survey-year pairs, Table 1, P1 pp. 11-12; text pp. 15-17) as focal. These are the focal claims. They are grouped into five research-question claims (RQ1 leisure, RQ2 extrinsic, RQ3 intrinsic, RQ4 altruistic, RQ5 social), each defined by its three contrasts.

D2 Work-centrality summary (Reader B C64 focal; Reader A records the same Form 3 item findings as descriptive). Tier label disagreement, so the tier is uncertain. It is scored as an item-level claim set and excluded from the primary paper aggregation; the report states whether including it as focal would change the paper outcome.

D3 Origin rule where readers disagree and the article is silent: use the default behaviour of the software the article names (LISREL 8.7, P1 p. 10). This rule was fixed before any estimation and applies to:
- Weighting: Reader A origin unweighted, Reader B origin public weight V5. Origin S00 is unweighted (LISREL fits the supplied moments without weights unless weights are specified). The weighted reading is retained as co-origin S01, scored separately; if the claim outcome differs between S00 and S01 the claim is flagged label-sensitive and both scores are preserved.
- Covariance normalization: Reader A cites the LISREL default (N-1, Wishart likelihood); Reader B records an ML (N) normalization as provisional. Origin uses N-1; the N normalization is branch S02 (uncertain).

D4 Altruistic marker. Both readers use marker identification (loading 1, intercept 0 in every group, latent means free). Reader A's rule (first-listed item) selects V4229, whose intercept both readers free across groups per Table 1 footnote a; a marker with intercept fixed at 0 in every group cannot also have its intercept freed. Reader A's own rationale requires a non-freed marker. The explicit article constraint takes precedence, so the altruistic marker is V4235 (Reader B's choice). Markers for the other four factors are identical across readers. Under partial scalar invariance, any invariant marker gives the same model fit and the same standardized contrasts; this is run as check CHK2, not as an alternative.

D5 Equivalent set. After reconciliation no substantive alternative is labelled equivalent by both readers. The df-weighted denominator and Welch t (A equivalent, B uncertain) become uncertain. Single-reader levels cannot enter the equivalent set. Mathematical re-expressions (reference-group normalization, alternative invariant marker, raw-data likelihood, native-coded centrality orientation) are checks. Specification fragility is therefore not assessed.

D6 Uncertain branches retained, one-at-a-time deviations from S00: S01 weighted (co-origin), S02 N normalization, S03 listwise on all form items, S04 FIML, S05 effects-coding identification, S06 robust (MLR-type sandwich) standard errors, plus post-estimation standardizer variants (df-weighted pooled SD, Hedges g, Glass delta with earlier-year SD, observed composite SD) and the item-level Welch test. Diagnostic-tier branches: S07a/S07b alternative security/influence partitions and S08 single-factor centrality on V3222-V3226.

D7 Non-equivalent or unavailable, not run: ordinal WLS/DWLS (non-equivalent, wider space off); a five-category Form 4 instrument (the source files have four categories in every year); the original group-specific intercept release syntax; design-based variance with school/PSU identifiers (absent from the public files).

D8 Inference. The focal contrasts come from a multigroup SEM. Under the scoring rules, SEM keeps native inference and inference is not audited. Native Wald tests of each latent contrast (two-sided, .05) are reported descriptively, since the article reports no contrast test statistics. Item-level t tests are linear comparisons; no assignment-level cluster identifier exists, so native independent-sample inference is the benchmark and no clusters are invented.

D9 Item scoring follows the agreed source coding: Form 4 items native 1-4 (no fifth category), Form 3 agreement items 1-5, V3227 1 = would want to work, 2 = would not; percentage columns use Form 4 code 4, Form 3 codes 4-5, V3227 code 1.

D10 Contradictions in the published record, preserved and not resolved by the coordinator: Form 4 scale described as 5-point (P1 p. 10) versus 4 categories in the source; intrinsic 1976-1991 d printed -.05 (Table 1) and .05 (text p. 16); metric-invariance chi-square difference called ns although p is about .043; delta CFI .0080 versus .0082-.0084 implied; the 'earn money' 1991-2006 t = -2.37 with ***; t signs for two Form 3 rows; multigroup df not reproducible from the described model; reliability estimates said to be in Table 1 but absent. Both readers report these independently (forensics.json).

D11 Influence diagnostic (reporting requirement). Registered before fitting: leave-one-respondent-out over the S00 Form 4 three-group partial-scalar model sample (respondents complete on the 19 model items). The respondent is the observation unit; school and PSU identifiers are not in the public files, and survey year defines the contrasts, so neither can be the deletion unit. Every eligible deletion is retained, including failures. Influence ranges are not confidence intervals and do not enter the equivalent set.
