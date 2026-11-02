# Reconciliation ledger, version 1

Inputs: Reader A (claude-fable-5-1) readers/fable/run_20261027T120905Z/output; Reader B (gpt-6-astra) readers/astra/run_20261027T120905Z/output. Both initial outputs are sealed (read-only, hashed). No clarification round was used. Matching rules: matching_rules_v1.md (written before comparison). Initial agreement statistics: initial_agreement_v1.json (computed before any coordinator decision).

## Initial agreement (before any clarification)

| Comparison | Pairs | Agree | Raw agreement | Gwet's AC1 |
| --- | --- | --- | --- | --- |
| Claim tier (matched claim pairs, one-to-many counted per pair) | 27 | 21 | 0.78 | 0.73 |
| Claim tier (unique Reader A claims) | 26 | 20 | 0.77 | 0.72 |
| Focal versus non-focal | 27 | 26 | 0.96 | 0.95 |
| Specification level labels (matched levels) | 11 | 10 | 0.91 | 0.89 |
| Origin choice on matched axes | 7 | 5 | 0.71 | not computed (categories not exchangeable) |
| Transcription, Tables 4 to 6 (estimates, p values, pseudo R2, ROC p values) | 248 | 248 | 1.00 | not applicable |

Unmatched claims: Reader A C07 (Japan dummy), C08 (group size positive), C23 (20 percent less likely to survive, focal), C29 (camp composition shares); Reader B C15 (trade-impediment interpretation, focal), C20 (theoretical mechanisms, focal). Axes: Reader A 13, Reader B 17, 7 matched pairs; unmatched axes retained as a union below.

## Claim tier decisions

- Agreements retained: Table 4 hierarchy coefficients for Steepness and Sameness, captured and camp cohorts (A C01 to C04; B C01, C02) are focal for both readers. The quartile contrast (A C05, B C03) is focal for both.
- Disagreements become uncertain: Table 6 officer interaction (A robustness, B focal) is uncertain-focal; Table 5 Panel A (A robustness, B diagnostic); steepness-sameness correlation (A descriptive, B diagnostic); Air Force subsample (A robustness, B diagnostic); older POWs in Japan (A robustness, B nuisance); officers' lower survival (A robustness, B descriptive).
- Union: unmatched claims are retained with their single reader's tier. B C15 and C20 are interpretive statements without an estimable quantity and are recorded but not scored. A C23 (20 percent) has no stated model or quantity and is recorded as not scorable.
- D-AGG (coordinator, from the article before results): focal estimable claims are the eight Table 4 hierarchy coefficients. The quartile contrast C05 is a transformation of Table 4 column 2 and is reported descriptively, not as a separate claim in aggregation. Table 6 is label-sensitive (uncertain focal); the paper-level outcome is computed with and without it.

## Specification axes (union) and origin decisions

Rule D-ORIG: when both readers mark the same level as origin it is the origin; when one reader leaves a decision unresolved (missing or adjudication pending) and the other specifies an operational level, the specified level is the origin and the other reader's level is an uncertain branch; labels that differ become uncertain; a level proposed by only one reader keeps that reader's label, except that a single-reader "equivalent" label becomes "uncertain" because equivalence was not independently confirmed. Mathematical re-expressions and numerical-precision variants are checks, not alternatives.

| Axis | Levels (origin first) | Sources | Label |
| --- | --- | --- | --- |
| SVC civilian exclusion | exclude service 6 and 7; exclude 6 only; exclude 4, 6, 7 | A A01; B step 2 (adjudication) | origin from A; alternatives uncertain |
| SAMP common sample | one sample requiring camp and report month for all columns; column-specific (camp models do not require report month) | A A02; B step 8 implies column-specific | uncertain (A non_equivalent, B implied) |
| CAMPDEF valid camp | any three-character non-blank code other than 000; only codes defined in the NARA camp list | A step 6; B variable camp_id | uncertain |
| COHORT date | report year-month (DATE_REPORTED) | B A01 (entry date unavailable); A manifest | only feasible level; entry date unavailable |
| RANK mapping | collapse detailed grades (rank_map origin columns, GRADE_CODE fallback); strict labels only; GRADE_CODE primary | A A03; B A08 | origin A L0 = B L1; others uncertain |
| GRP group members | regression-sample members with valid rank; all POW-file records with valid camp/date; complete-covariate members | A A04; B A02 | origin agreed; alternatives uncertain |
| POP reference fractions | descriptive sample (pooled powers); regression sample | A A05; B A03 | origin agreed; alternative uncertain |
| CONST Sameness constant | fixed 1.319; recomputed so all-generals equals 0 | A A05L1 only | uncertain (single-reader equivalent downgraded) |
| EDU post-graduate code | 9 years; 10 years; missing | A A06; B A09 | origin from A (B unresolved); uncertain |
| DEP married code | married = 1; married = 0; married = missing | A A08; B A10 | origin agreed; alternatives uncertain |
| HT height | 48 to 84 inches accepted; height treated as missing | A height; B height | uncertain |
| AGE age | 1900 century, ages 15 to 70; 1900 century, no range | A age; B age | uncertain |
| DUP duplicate enlistment serials | unmatched; first record; combine agreeing fields | A A10; B step 3 | uncertain |
| COORD camp coordinates | geocoded crosswalk; NARA whole-degree points | A A07; B A15 | origin agreed; alternative uncertain |
| CLUSTER captured models | captured cohort; camp | A A11; B A14 | origin agreed equivalent; alternative uncertain (A non_equivalent, B uncertain) |
| PP perfect prediction | drop camps without outcome variation; penalized probit | A A09 | origin; alternative non_equivalent (not run) |
| ME marginal effects | at means; average marginal effects; index coefficients | A A12 | origin; alternatives non_equivalent (not run) |
| ROC test | Hanley and McNeil (1983); DeLong et al. (1988) | A A13 | H&M correlation table not available to implementers; DeLong run as uncertain fallback |
| INT interaction effect | product regressor slope at means; difference in derivatives | B A17 | origin agreed with A manifest; alternative non_equivalent (not run) |
| FRIENDS definition | ln(same-unit members including self); ln(others) with zero missing | A friends; B A16 | uncertain |
| RESTRICT group recomputation in subsets | keep parent-sample group variables; recompute within subset | B A04 | uncertain; origin B L0 |
| Distance formula | haversine, R = 6371 km | A A07L2 | geodesic variant is a numerical check, not an alternative |
| Squared size scaling | (ln n / 10)^2 | B A11 | B A11L1 is a re-expression check, not an alternative |

Non-equivalent reported robustness families (A models M26 to M36; B models M21 to M30; B axes A05, A06, A07, A12, A13) are run as separate claims, never as equivalent specifications: complete cases, cohorts of at least 50 and 100, executions excluded, Germany only, Japan only, Army Air Force in Germany, no squared size term, alternative hierarchy measures, friends, hierarchy by size interaction. The pay-grade Steepness and pay interactions are unavailable (no pay table in the registry; neither reader supplied one).

## Coordinator decisions on operational details (target-free)

- D-RANK: rank tables registry/manifest_tables/rank_map_grade_alpha.csv and rank_map_grade_code.csv built mechanically by reconciliation/scripts/build_rank_maps.py from the readers' rules and the NARA code-list meanings. Service-dependent labels (Captain, Lieutenant, Lieutenant Colonel or Commander) are resolved by SERVICE_CODE.
- D-CAPITAL: Berlin 52.5200 N 13.4050 E; Tokyo 35.6762 N 139.6503 E (Reader A values; B required explicit points).
- D-DUPCAMP: codes 359 and 510 use crosswalk entry a; entry b is within the same region.
- D-N: published regression N values stay in the sealed n_branch and are evaluated by code; they are never used to choose a sample.

## Data contradictions and gaps preserved

- Table 4 reports one N for all eight columns; Table 6 reports a larger N under the same described sample (both readers).
- The article's sample-construction counts do not identify the regression sample (both readers).
- No entry-date field exists; captured cohorts use report month (B A01).
