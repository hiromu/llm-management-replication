# Technical supplement: thebaud2015

This supplement gives the detail behind reports/replication_report.md. It is generated from saved outputs; file paths are relative to the study folder.

## 1. Roles, models and containment

| Role | Model and settings | Process | Context and inputs |
| --- | --- | --- | --- |
| Coordinator | Claude Opus 5.5, high effort, fast mode off | Claude Code session | Everything; does no independent reading |
| Source acquisition, package and supplement search | Claude Opus 5.5 subagents | Coordinator subagents | Paper identity allowed |
| Memorization probes | Claude Fable 5.1 high; GPT-6 Astra high | Separate CLI processes in neutral staging, no tools | Title and author only; answers sealed |
| Reader A / Reader B | Claude Fable 5.1 high / GPT-6 Astra high | claude -p --safe-mode / codex exec, neutral staging | Frozen packet, workflow rules, summary-free dictionaries |
| Implementers A, B, C | Fable 5.1 (R) / Astra (R) / Fable 5.1 (Julia) | Separate CLI processes, opaque staging | Neutral manifest and synthetic data only |
| Pre-execution checkers | Separate CLI processes | Opaque staging | Manifest and code only |
| Scorer | Deterministic script checks/score.py | Coordinator-run | Frozen outputs and sealed targets |
| Adversarial reviewers | Claude Opus 5.5 subagent; GPT-6 Astra via codex | After candidates were identified | Everything in the study folder |

Requested and reported settings are recorded in implementation/role_record.json, sealed/memorization/probe_record.json and logs/*_launch_v1.log. The CLIs do not report the effort level for Claude, or the service tier for codex. Network isolation during execution used sandbox-exec with a deny-network profile (runs/isolation_test/result.md). File-system isolation was instruction-only. The coordinator and Reader A are both Anthropic models; the coordinator did no independent reading.

## 2. Publication packet and supplements

- Packet v1 (sources/publication_packet.json), identical for both readers:
  - MAIN.pdf: the ASQ issue version, 42 pp.
  - S1.pdf: the SAGE online appendix, 3 pp., Tables A1–A3.
  - No redactions; no code, links or data files in either document.
- Supplement search covered Crossref, Google Scholar versions, the SAGE page, web search and the local catalog (sources/supplements/supplement_search.json). S1 is the only supplement; no errata or corrections were found.
- Package eligibility searches (checks/package_eligibility.json) covered:
  - Registries and repositories: Crossref, DataCite, Dataverse, ICPSR and openICPSR, OSF, Zenodo, GitHub.
  - Author pages, Google Scholar and the ASQ policy.
  - No author package was found. OSF 9sxua is a third-party project and was not opened for data.
- Printed data in S1 Table A1 (country means) and Table A2 (descriptives) were never empirical inputs. The adversarial reviewers used them only post hoc as publication diagnostics.
- Packet issues:
  - The article's cross-reference to "Panel B of table A1" should read Table A2.
  - Table 1 Model 2 prints a negative age-squared SE.
  - A3 Model 2 has a blank fertility cell.

## 3. Sources and construction

- Individual data: ICPSR 20320 v6 (user-supplied, read-only).
  - A 34-variable extract with original codes is in data/derived/gem_extract.csv: 713,933 rows for the 24 countries, 1998–2008, SHA-256 805814b1….
  - Validation notes are in registry/validation/README.md.
- Country-year inputs: data/derived/country_year_inputs.csv (SHA-256 10012241…), 24 countries x 1998–2008, unstandardized. Lineage per cell is in data/derived/country_year_lineage.csv; scripts and decisions are in registry/construction/.
- Summary of country-year inputs, flags and gaps:

| Variable | Construction | Main flags and gaps |
| --- | --- | --- |
| leave_fte_weeks | CEPR 2008 FTE weeks for mothers, scaled to each year by OECD PF2.5 paid-week ratios. Iceland and Poland from ILO/PF2.5 rates. | CZE missing all years; FRA 1998–2003 missing; DEU internal CEPR discrepancy; ratio method not the author's construction (see section 8) |
| childcare_interp | OECD PF3.1 total ECEC % GDP. 2005 and 2007 values, 2006 interpolated, carried outward. | Concept is total ECEC, not childcare only |
| pt_common_employees_women | OECD common definition (<30 h), women employees | JPN national definition substitute |
| gdp | UNDP GDP-index formula on WDI GDP per capita PPP (current vintage) | 31 cells capped at 1 |
| unemp | OECD harmonised unemployment, annual | CHE, ISL (early), GRC 1998 fallback to LFS 15–64 |
| epl | OECD EPL_OV version 1 | Regular-contracts index; ISL carried back from 2008 |
| wmgr | UNDP HDR women legislators, senior officials and managers | FRA nearest-edition fallback; JPN ISCO-68 footnotes |
| fert | WDI total fertility rate | none material |
| status | Proportion of NBSTATUS = 1 among all respondents in the country-year | No 2001–2002 responses; carried back from earliest later year |

## 4. Frozen specification and deviation grid

- Frozen files:
  - The manifest: reconciliation/frozen/manifest_neutral.md (SHA-256 bfe7608c…).
  - Scoring rules: scoring_rules.json v1 (5b76afc8…), with addendum v1.1 (written on synthetic output before real results) and addendum v1.2 (influence row matching, written before any influence result).
  - Hash lists: freeze_hashes_v1.txt and freeze_hashes_v1_2.txt. The superseded scorer is kept in checks/versions/score_v1_1.py.
- Origin samples:
  - M1–M3 and A3: respondents aged 19–54 (A3 M2 also includes the non-employed).
  - M4–M8: owner-managers.
  - Complete cases are taken per model.
- Models:
  - M1–M4 and M6–M8: three-level logit. M5: linear on ln(employees + 1).
  - Random intercept and random female slope at survey and country level, independent covariance; Laplace (lme4 nAGQ = 1); ML.
  - Survey-level variables are z-standardized over the surveys of the origin M3 sample; leave² is the square of z(leave); leave lagged one year.
- Deviation branches and the models they run on:

| Branch | Content | Models | Class |
| --- | --- | --- | --- |
| U01 | age 18–54 | M3–M8 | uncertain |
| U02 | include unemployed | M3–M8 | uncertain |
| U03 | activity via BSTART/SUWAGE or OWNMGE | M3, R1 | uncertain |
| U04 | activity via SUBOANWT, OMBABYBT, OMESTBBT | M3 | uncertain |
| U05 | all available surveys of the 24 countries | M3–M8 | uncertain |
| U06 | DK coded as no | M3 | uncertain |
| U07 | owner = OMESTBBT | M4–M8 | uncertain |
| U08 | owner = OWNMGE and OMOWN in {1, 2} | M4–M8 | uncertain; realized duplicate of origin |
| U09 | plan-B = OMREASON 2 or 3 | M4 | uncertain |
| U10 | plan-B via OMWHY | M4 | uncertain |
| U11 | business age ln(years + 1) | M4–M8 | uncertain |
| U12 | part-time, national definitions | M3–M8 | uncertain |
| U13 | part-time, common definition, total employment | M3–M8 | uncertain |
| U14 | standardize raw leave² separately | M3–M8 | algebraic re-expression |
| U15 | standardization over country means | M3–M8 | algebraic re-expression |
| U16 | standardization over individuals | M3–M8 | algebraic re-expression |
| U17 | leave unlagged | M3–M8 | uncertain |
| U18 | leave lagged two years | M3–M8 | uncertain |
| U19 | annual childcare series | M3–M8 | uncertain |
| U20 | unstructured random-effects covariance | M3–M8 | uncertain |
| U21 | survey weights | — | unavailable |
| U22 | status among analytic respondents | M3–M8 | uncertain |
| U23 | growth = expected employees > 5 | M6 | uncertain |
| U24 | sole owner via OMOWNERS | M4–M8 | uncertain |
| U25 | REML | M5 | uncertain |
| U26 | add fertility to A3 M2 | R2 | uncertain |
| N01 | drop 2001–2002 surveys | M3–M8 | non-equivalent (M8: re-expression) |

- Not run, recorded in the coordinator decisions:
  - Nascent-only and TEA outcomes (non-equivalent).
  - New technology code 1 only (non-equivalent).
  - The HDR-printed GDP index (budget).
  - A common owner sample per model family (budget).
- Influence registration (reconciliation/frozen/influence_registration.md, frozen before fitting):
  - Unit: leave-one-country-out, for M3–M8.
  - Constants and centering are held at origin values.
  - Every refit is retained.

## 5. Scoring rules applied

Per term, the scorer evaluates four criteria:
- Magnitude: the distance from the published rounding interval in published-SE units. Up to 1.5 is within, 1.5 to 3 is grey, above 3 is outside.
- Inference: bands of p < .01, < .05, < .10 and ≥ .10 against the published stars. A one-band weakening is consistent, and stronger reconstructed significance is consistent if the sign matches. A nonsignificant published term is outside only if the reconstruction reaches p < .01.
- Sign: compared when the published rounding interval excludes 0.
- N: within 5% is a match, 5–15% grey, above 15% a mismatch.

Precedence (addendum v1.1), highest first:
1. implementation disagreement
2. implementation failure
3. N mismatch (incomplete coverage)
4. any outside criterion (discrepant candidate)
5. grey
6. missing magnitude
7. fragile inference: the benchmark band is at least two bands weaker than published
8. consistent

Claims take their worst term. Hypotheses: H1 = F02; H2 = F05 + F06; H3 = F08–F11. The paper is indeterminate if any hypothesis is indeterminate; a discrepant candidate stays indeterminate:awaiting_confirmation.

Rounding limitation: for printed values with two decimals, the rounding interval is ±.005. Large published SEs therefore dominate the magnitude criterion for the leave terms.

## 6. Execution record

| Run | Implementation | Wall time | Exit | Fits |
| --- | --- | --- | --- | --- |
| ORIGIN_A | A | 7,563 s | 0 | 11 |
| ORIGIN_B | B | 7,416 s | 0 | 11 |
| ORIGIN_C | C | 30,125 s; terminated by the user at 2026-10-28T01:36Z while fitting R1 | 143 | 0 saved (M1–M8 fitted; sample counts identical to A and B in the log) |
| DEV_A_p1–p10 | A, 10 parallel processes | about 1.6 h | 0 | 113 |
| INF_A_M3–M8 | A, 6 parallel processes | up to about 6 h | 0 | 137 |

Inputs, code and environment hashes are in runs/exec_v1/execution_record.json:
- R 4.6.1 with lme4 2.1.0.
- Julia 1.12.6 with MixedModels 5.9.1.
- macOS 26.6.2, 16 CPUs.

Running fits in parallel processes does not change any result. The budget rule allowed up to 30 h of wall-clock time per implementation. The user ended the execution phase before that cap; the unexecuted runs are listed in runs/exec_v1/unexecuted_runs.json.

Implementation agreement (runs/exec_v1/ORIGIN_AB_agreement.csv): A vs B, 276 of 276 terms agree, with identical sample counts for all 11 models. Implementation B hashes string-sorted IDs, so sample identity for pairs with B is established by equal counts (addendum v1.1).

## 7. Claim results and set summaries

- Term outcomes: reports/exports/term_comparisons.csv. Claim outcomes: claim_comparisons.csv (with both adversarial classifications and full-verification status). Paper record: paper_record.json.
- Two versions of the set summaries exist:
  - scoring/final_v1/set_summaries.csv is the frozen scorer's output and pools all uncertain fits, including algebraic re-expressions.
  - reports/exports/uncertain_set_substantive.csv excludes re-expressions (U14–U16) and the realized duplicate (U08), as scoring.md requires. Re-expressed coefficients are on a different basis or scale and should not be pooled.
- Influence summaries per focal term: the same set_summaries.csv (rows with set = influence) and reports/figure/influence_figure.csv.

Influence highlights:
- M3 female x childcare stays between −0.149 and −0.120, with p ≤ .001, under every country deletion.
- M4 female x childcare ranges from −0.105 to −0.015. Its minimum reaches the published value and p = .02.
- M4 female x part-time stays between −0.066 and −0.036.
- M6 female x leave ranges from −0.104 to 0.066. Its published value .31 is outside.
- M7 female x leave² stays between −0.190 and −0.137, with p ≤ .03.

## 8. Adversarial review

Full texts: audits/adversarial_v1/review.md (Claude Opus 5.5; family statement corrected in audits/adversarial_v1/coordinator_note.md) and audits/adversarial_astra_v1/review.md (GPT-6 Astra). Their diagnostics are in each folder's diagnostics/ subfolder. All are post hoc.

Points of agreement between the two reviews:
- No implementation bug was found.
- The leave-series ratio method introduces level changes in countries that footnote 7 says had no relevant policy change.
- The M6 growth outcome prevalence (about 10%, against the published 17%) cannot be reproduced from the supplied file under any documented rule.
- Separately standardizing leave² (U14) is an exact reparameterization with identical likelihood. The published SE pattern resembles it.

Points of disagreement:
- The Claude review treats the plan-B coding (U09), the leave² basis and a common owner sample as pipeline errors.
- The Astra review treats them as plausible but undocumented alternatives.
- The Astra review notes that U18 (two-year lag) brings F06 within the criteria, so it does not accept F06's unconditional survival.

The coordinator did not apply any of these changes. A corrected registration would be a new version, made after results were seen, and needs user authorization. It would have to be reported separately from v1.

## 9. Failures, unavailability and open items

- U21 (weights) is unavailable.
- 6 deviation fits and 6 influence refits did not converge; 34 influence refits are singular. All are retained and flagged.
- Five year dummies are absent from the M7 and M8 samples.
- Implementation C was stopped at user direction before producing output. C's deviations and influence refits, and B's optional deviations, were not executed (runs/exec_v1/unexecuted_runs.json).
- Calibration arms were not performed.
- Memorization: both reader models recognized the article and argument but recalled no numeric results (sealed/memorization/).
