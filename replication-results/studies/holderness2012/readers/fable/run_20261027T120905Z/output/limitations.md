# Limitations and documentation gaps (paper P-R7M2, reader output)

All page references are PDF pages of D1 (journal page = PDF page + 1871).

## 1. Contradictions and mismatches within the published record

- **Observation counts.** Table 4 (pdf 9) states 100,464 observations for all eight columns, including four with camp dummies and four without. Table 6 (pdf 13), described as the same specifications with an added interaction, states 102,334. Both are far below the Table 1 total of 122,765 (pdf 6). Nothing in the text explains the drop from the descriptive to the regression sample or the difference between the two regression tables. The manifest reconstructs the drop as the need for a usable camp code and report month (sample step 6); this is the reader's inference.
- **"Panel C" of Table 5.** Section 4.5 (pdf 9) cites Panel C for the ROC results; Table 5 has only Panels A and B.
- **"20% less likely to survive".** The introduction (pdf 3) gives a 20% survival gap between the most and least hierarchical groups. The only magnitude computation in the paper (pdf 8) gives six percentage points (81% vs 87%) between Steepness quartiles. The 20% figure cannot be traced to a table or a stated calculation.
- **Table 1 internal identities.** Mean POWs per camp times number of camps for Japan (about 29,256) exceeds the Japanese total (29,099) beyond rounding; for all POWs and Germany the products imply roughly 17,000 POWs without camp codes, which the table note ("number of observations varies with the data item") permits but does not quantify. See forensics F05-F06.
- **Table 3 Sameness values** for Groups D and E differ from values recomputed with Group C's printed fractions by 0.007 and 0.005 (forensics F02); explainable by rounding of the population fractions, but it means Table 3 cannot pin the fractions exactly.
- **Date of capture vs date reported.** The text (pdf 5) lists "date of capture" among the data items and defines cohorts by month of camp entry (Table 2, pdf 7), but the NARA file carries only a "date reported" field. Which field the authors used is unstated.

## 2. Missing appendices and supplements

- The packet contains no e-companion, online appendix or supplement (publication_packet.json: supplement search found none). The article refers to "previous versions of the paper" and "earlier versions of the paper" for several results; those versions are excluded by rule and were not consulted.
- No standard errors, confidence intervals, means of regression variables or correlation matrix are printed; p-values are rounded to two decimals, so "(0.00)" means only p < 0.005.

## 3. Unreported analyses the text relies on

The following are described but have no numbers in the published record (claim map C14-C22, C26):

1. Germany and Japan separately (pdf 10, section 5.1): "significant in all eight German specifications and in the four Japanese captured-cohort specifications".
2. Social-network ("friends") regressions and friends-based hierarchy measures (pdf 10, section 5.2): only the largest p-value (0.02) and "around 0.50" are given.
3. Alternative hierarchy calculations: pay-grade Steepness, Alternative Sameness, absolute-deviation Sameness (pdf 10-11, section 5.3.1).
4. Three further measures: number of ranks, sum of ranks, administrative intensity (pdf 11, section 5.3.2).
5. Four subsets: complete data, cohorts of at least 50, at least 100, excluding executions (pdf 11, section 5.3.3).
6. Air Force POWs in Germany (pdf 12, section 5.4): only two p-values (0.56, 0.07) in text.
7. Hierarchy x group-size interaction and the no-squared-term variant (pdf 14, section 6.2).
8. Pay x hierarchy interaction and Table 6 by detaining power (pdf 12, footnote 13).
9. Older POWs less likely to survive in Japanese camps (pdf 8, section 4.4).

The summary (pdf 14) says the findings hold "when we measure hierarchy in 10 different ways"; only two are tabulated.

## 4. Construction details not documented in the article

- Mapping of the many grade abbreviations (Army, Navy, Marine, nurses, technicians) into nine ranks; handling of Navy/Marine equivalents; handling of records with blank or unmapped grade.
- Serial-number merge: duplicates in the enlistment file, officer identity letters in POW serial numbers, E.R.C. card layout, NARA's '#' blanks.
- Which population defines the Sameness "population fraction" and the exact constant (1.319 printed; its stated rationale implies a data-derived value).
- Whether cohort size and rank shares include records later excluded from the regression sample.
- Coordinates and distance formula for the distance-to-capital variable; what "in Berlin or Tokyo" means operationally; treatment of camps with unknown location.
- Years assigned to the post-graduate education code; treatment of "Married" (no dependency qualifier) in the dependents dummy.
- Treatment of report dates after the war-end month in length of captivity; of the camp code's dual meanings (359, 510); and of NARA's undefined code values.
- Whether civilians exclude Merchant Marine and war correspondents.
- Software and version are not stated anywhere; handling of perfectly predicted camps in the fixed-effect probits is not discussed.
- "Camp located outside of Germany or Japan proper" (Table 1) requires pre-1939 borders that no registry field encodes.
- The tail of the reported p-values is never stated (two-sided assumed in the sealed targets).

## 5. Source and vintage gaps

- No pay-grade or pay data in the registry (needed for Alternative Steepness and footnote 13); recorded as unavailable.
- Height/weight columns of the enlistment card are undated by NARA and may contain other content for some card vintages.
- Camp coordinates come from a 2026 GeoNames-based crosswalk, not from the authors' source.
- The Army-wide rank distribution the authors wanted was never available; the POW distribution is the stated substitute.

## 6. OCR-uncertain values

- All table values were checked against the page images. OCR scrambled Table 4 pseudo R2 entries ("040", "053", "054", "030", "0-41"); the images show 0.40, 0.53, 0.54, 0.30, 0.41. OCR placed a stray dot before the Table 5 value -0.24; the image confirms -0.24. Table 6 "Men in hierarchy squared" in the Steepness/camp/complex column prints 0.00 without a minus sign (image confirmed). No value remains OCR-uncertain.
- Equations: the Steepness and Sameness formulas were transcribed from the page images (pdf 6, 7, 10), not from the scrambled OCR.

## 7. Questions for the coordinator

1. Is any earlier version of the paper to be admitted as a versioned supplement for the unreported robustness tables, or do those claims remain qualitative?
2. Should the regression-sample restriction (manifest step 6) and perfect-prediction handling (step 8) be fixed as stated, given that the published counts cannot be reproduced by any rule described in the article?
3. Should the wider specification grid remain off (default), and should axis A03 (grade mapping) be treated as the highest-impact uncertain axis for pre-registration of the implementer's mapping table?
4. Confirm that Table 3 (hypothetical groups) values are to be used only as formula checks and not as empirical inputs (its Group C fractions must not be used to set the population fractions).
