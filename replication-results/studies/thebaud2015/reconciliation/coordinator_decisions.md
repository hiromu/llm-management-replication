# Coordinator reconciliation decisions (v1)

Inputs: readers/fable/initial_v1 and readers/astra/initial_v1 (first complete outputs, hashed). No clarification round was held. Initial agreement is in initial_agreement.json and was computed before any decision below. Ledgers: claim_ledger.csv, spec_level_ledger.csv, target_transcription_ledger.csv.

## Rules applied

1. Matched levels with the same label keep that label. Matched levels with different labels become uncertain.
2. A level proposed by only one reader is kept (union). It keeps a non_equivalent label. An equivalent label from one reader becomes uncertain, because no second reading confirms it.
3. The executed origin for each decision is the level both readers chose as origin. When they chose different origins, the origin is the level that both readers labelled origin or equivalent. If no level meets that, the origin is the level closest to explicit article or supplement wording. If the wording does not settle it, the default of the software the article cites (Stata, via the Rabe-Hesketh and Skrondal citation on MAIN p.36 and Fable's manifest) decides. The other level becomes an uncertain branch.
4. The coordinator does not use empirical agreement for any decision. No results exist at this point.

## Decisions by axis

| Decision | Executed origin | Basis | Branches retained |
| --- | --- | --- | --- |
| Labour force | Employed only (GEMWORK 1, 2) | both origin | plus unemployed (uncertain); full sample with control (non_equivalent; this is A3 M2) |
| Age | 19-54 (GEMAGE > 18 and < 55) | origins differ; literal wording "over 18 and under 55" (MAIN p.10) | 18-54 (uncertain) |
| Country-years | S1 Table A1 roster (143 surveys) | Fable origin; Astra fixed roster | all 2001-2008 available (uncertain) |
| Screening DK/refused | missing | Fable origin; Astra codes as missing | DK as no (uncertain) |
| Activity outcome | SUBOANWT in {1,100} or OWNMGE = 1 | origins differ; SUBOANWT implements the article's nascent wording (actively trying, owner, no wages over three months) more completely | BSTART/SUWAGE screening or OWNMGE (uncertain); transforms only (uncertain); nascent only and TEA (non_equivalent, not run) |
| Owner subsample | OWNMGE = 1 with owner-module data | both origin | OMOWN corroborated (uncertain); OMESTBBT (uncertain after label disagreement) |
| Plan-B coding | OMREASON = 2 vs 1, 3, 4, 6 | both origin | OMREASON 2 or 3 (uncertain); OMWHY (uncertain, single reader) |
| New technology | OMNEWT_5 in {1, 2} | Fable origin; Astra same rule in variables | code 1 only (non_equivalent, not run) |
| Business age | log(years), zero years missing | origins differ; literal "log of years" (MAIN p.15) | log(years + 1) (uncertain) |
| Part-time | OECD common definition, women employees; Japan from national definition | origins differ; S1 Table A1 note says female employees | national definitions (uncertain); common definition total employment (uncertain after label disagreement) |
| Standardization | z-score of each survey-level variable over the analytic country-years, each counted once; squared leave = square of standardized leave | Fable origin, Astra labels it equivalent; population: Astra origin, Fable's rule says across analytic country-years | standardize raw square separately (uncertain); z over country means (uncertain); pooled-individual population (uncertain, single reader) |
| Leave lag | one year | both origin | no lag, two years (uncertain after label disagreement) |
| Childcare | 2005 and 2007 values with linear interpolation for 2006 and nearest endpoint carried to 2001-2004 and 2008 | Fable origin; Astra lists it as uncertain | current annual series (uncertain); nearest year (uncertain) |
| Random effects | independent intercept and female slope at both levels | both uncertain; Stata melogit default covariance is independent | unstructured (uncertain) |
| Weights | none | both origin | WEIGHT_L (uncertain) |
| Likelihood | adaptive quadrature requested; not executable for three-level random-slope models in the available software, so Laplace is executed and recorded as a deviation | software limitation | Laplace is the executed origin; REML for M5 (uncertain) |
| Status 2001-2002 | carry back each country's earliest available survey-level status | Fable origin; Astra keeps the control but leaves values unresolved | drop 2001-2002 (non_equivalent, run as a disclosed influence-type check only) |
| Status population | all valid respondents in the country-year, unweighted | Astra origin; consistent with Fable | analytic respondents only (uncertain) |
| Growth threshold | additional employees > 5 | both origin | total > 5 (uncertain) |
| Missing values | complete cases per model | both | common sample per family (uncertain, not run: budget) |
| GDP | UNDP GDP index formula applied to GDP per capita PPP | Astra origin GDP index; HDR printed tables cover only some years | not run: HDR-printed index (budget) |
| Sole owner | OMOWN = 1 vs 2 | both | OMOWNERS = 1 (uncertain) |
| A3 M2 fertility | omitted, as the printed table shows | Astra origin, literal table | included (uncertain) |
| Native covariance | model-based | Astra origin; Fable model-based | country-cluster sandwich is the benchmark, not a specification |

## Other decisions

- France 2003 lacks work status and education in the supplied file. Under complete-case processing it contributes no cases. No imputation. This is recorded as a data limitation.
- Table 1 Model 2 age-squared SE is printed as "–.001", a negative SE. Fable recorded it as missing; Astra recorded -0.001. Both readers flag it in forensic observations. It is a nuisance control and is not scored.
- Fable recorded a blank fertility cell for A3 M2; Astra omitted the row. They agree it is blank.
- Equivalent set: no non-origin level is labelled equivalent by both readers. The equivalent set is therefore empty, and specification fragility is not assessed. Uncertain branches are run and reported separately.
- Not-shown robustness checks in footnotes (lags, alternative controls, women-only models) are recorded as claims but are not scored, because no published values exist.
- Descriptive figures, the per-country regressions and variance-decomposition diagnostics are outside the scored scope for this session. Their published values remain sealed.
