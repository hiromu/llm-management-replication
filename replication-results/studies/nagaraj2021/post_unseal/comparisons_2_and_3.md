# Comparisons 2 and 3 (post-unsealing)

The author package was opened at the time in logs/unsealed_utc.txt, after logs/pre_unseal_hashes.json was written (391 files). The 45 sealed files matched logs/osf_receipt.json before and after unsealing (logs/deposit_validation_pre_unseal.json, logs/deposit_validation_post_unseal.json). Nothing frozen was revised. Every rerun below is a labelled post-unsealing diagnostic.

## Comparison 2: author code rerun

Not run. Stata is not installed on this machine (no stata, stata-mp or stata-se binary, nothing in /Applications). The author pipeline needs Stata 16.1 plus the bundled SSC files (estout, coefplot, parmest, ivreg2, vincenty). I read the code before deciding: main.do and the 28 project .ado files read and write only under a user-set path, call no network and shell out to nothing. Figures 1 and 2 are not produced by code (screenshots and QGIS, per main.do). Following the study instructions, the code was not translated into another language as a substitute. Missing software is recorded as a finding.

## Comparison 3: AI code against author code

The AI code is the three frozen implementations, which follow implementation_manifest_v1.md; A and B agree on every regression row. Each difference is classified by its written source. "Changes a result" refers to post_unseal/diagnostics (frozen implementation A changed one difference at a time, origin rows only; table in reports/data/post_unseal_variant_diagnostics.csv).

| # | Item | AI code (manifest) | Author code | Written source | Changes a result |
| --- | --- | --- | --- | --- | --- |
| 1 | Massachusetts | excluded (14 counties) | kept, recoded treat = 0 (merge_covar.ado) | Article says excluded (D01 p.5, Figure 1 note, Table 2 note); code departs | Yes: Table 3 columns without controls move from 0.39-0.46 to 0.08-0.09 published SE (D01); full-sample N reaches 121,251 and Table 6 N reaches 81,007 exactly |
| 2 | County universe | county_lookup.csv | counties in quarterly.csv minus Hawaii, merged to county_lookup | Stated nowhere; deposit only | Small (2 counties without any activity row) |
| 3 | Hawaii | not handled | dropped | Stated nowhere | No (Hawaii is absent from county_lookup.csv) |
| 4 | FIPS 46102 to 46113 | not recoded | recoded | Stated nowhere | Not tested; one county |
| 5 | Panel controls across years | year match, nearest available year for whole missing years, listwise loss when a value is missing | per-county linear interpolation and extrapolation of each control (ipolate, epolate) | Stated nowhere. The AI rule was a coordinator fallback; 671 counties lack 2011 median earnings, so 10,314 county-quarters and 644 cross-section counties dropped | Yes, the largest driver: Table 3 columns with controls move from 0.86-1.23 to 0.27-0.33 SE; Table 4 columns from up to 1.87 to at most 0.42 (D03) |
| 6 | Cross-section control year | ACS 2011 (Y1) | interpolated/extrapolated values of the 2014q4 row | Stated nowhere | Small beyond item 5 (D04) |
| 7 | Quartile cut-points | county-level values, reference set U | xtile over all county-quarter rows (Tables 4, 5B); over address pairs (Table 6) | Stated nowhere ("four equal groups by percentile rank") | Not rerun separately |
| 8 | Quartile variables | density, household income, per-capita income | same | Main text (D01 p.15); appendix note D.4 says population: appendix contradiction | No |
| 9 | Table 6 outcome | ln abs(OSRM - Google) | ln abs(OSRM - Google), sign flipped when OSRM is shorter (signed log error) | Article says absolute value (D01 p.11, p.18); code departs | Yes, decisive: Treat moves from -0.108 to 0.125 (published 0.126) and Distance from 0.052 to 0.035 (published 0.034) (D06) |
| 10 | Timing sample | scheduled delivery in calendar 2005 or 2006 (1,568 counties) | scheduled month within 12 months of June 2005 (abs(mofd - 545) <= 12) | Article says calendar years 2005-2006 (D01 p.9); code departs | Yes: 1,809 counties (1,097 treated, 712 control) (D08); with Massachusetts 1,822 |
| 11 | Sample labels | boundary = opposite-status neighbour (2,214 counties), timing as item 10 | same definitions | Text and Figure 2 give boundary 1,820 (1,096/724) and timing 2,218 (1,228/990); the code's boundary sample is about 2,218 and its timing sample about 1,820. Publication labels swapped; Table 5 Panel B N follows the code | Explains Figure 2 and Table 5 N conflicts |
| 12 | Table 5 Panel A column order | as printed headings | estimates stored in the order boundary follow-on, timing follow-on, boundary contributors, timing contributors, printed under headings Boundary (Follow-on, Contributors), Timing (Follow-on, Contributors) | Publication heading error | Yes for scoring: candidates 6 and 7 align under the code order (adversarial review) |
| 13 | Table 5 Panel A controls | origin with controls; without controls is an uncertain row | no controls in any Panel A column | Stated nowhere ("similar to Table 3") | Modest; the uncertain row exists in the grid |
| 14 | Diff-time-trends FE | Y1 density quartile x quarter | quartile of the county's mean interpolated density x quarter | Stated nowhere | Not rerun |
| 15 | Placebo | permutation from shared uniform draws | Bernoulli via runiformint(0,100) > 40, Stata seed 1234 | Stated nowhere | Draw-specific; both null |
| 16 | Table 1 test | Welch (origin), Student also reported | Student t-test (estpost ttest) | Stated nowhere | p-values change little |
| 17 | Table 1 control changes | 2011 minus 2005 (deposit ends 2011) | extrapolated 2014q4 minus 2005q2 | Article says 2014-2005; deposit vintage stops at 2011 | Explains the six Table 1 control rows (source vintage) |
| 18 | Table 2 ownership rows | high = focused1, low = focused5 - focused1 (Table 7 meaning) | Table 2 lists raw totaloldfocused1 then totaloldfocused5; Table 7 uses focused1 and focused5 - focused1 | Publication labels inconsistent between Tables 2 and 7 | Explains the two Table 2 rows |
| 19 | Follow-on, distant, incremental | a + b + h; b; h | same | Matches the AI origin (an inference from column names) | No |
| 20 | Figure 5 | Table 4 specification per year | controls and quartile FE are locals defined in another program, so empty: no controls; outcome is the yearly mean of quarterly values | Article says controls and FE (D01 Figure 5 note); code departs | Plausibly explains the Figure 5 reading mismatch; not rerun |
| 21 | Figure 6(a) | separate regressions per density decile, with controls (M1) or cross-section (M2) | one pooled DiD with post x treat x decile interactions, no controls, deciles of raw density over panel rows | Stated nowhere | Plausibly explains Figure 6(a); not rerun |
| 22 | Figure 6(b) | DiD with controls | DiD without controls | Stated nowhere | Not rerun |
| 23 | Inference | CR1 county for panels and pairs, HC1 for county cross-sections | xtreg fe cluster(geoid); reg robust; Table 6 cluster(geoid) | Tables 4, 5B stated; Table 3, 5A, 6, 7 unstated | No difference in method |

No difference was classified as an AI misreading of the written record. Item 5 is a shortcoming of the coordinator's fallback rule, not of the implementations. Applying items 1, 2, 3, 5, 6, 9 and 10 together (D10) brings every Table 3, 4, 5B and 7 claim within 0.36 published SE and Table 6 Treat within 1.18 SE.
