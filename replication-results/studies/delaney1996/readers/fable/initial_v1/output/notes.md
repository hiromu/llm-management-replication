# Reader notes: PAPER_K7 (study delaney1996), packet v1

Reader: Claude Fable 5.1, independent reader. Inputs: D1 (journal scan, governs locators), D2 (author retypeset copy), rules, reader_schema_v1.md, NOS 1991 source description and dictionary, Census 1980 to SIC 1972 crosswalk. No supplement, appendix or correction exists in the packet (documented search; publisher page returned HTTP 403).

## 1. Limitations of this reading

- The D1 text layer is clipped at the right margin. All table values were read from the D1 page images (150 dpi) and cross-checked against the D2 text layer and images. Image zooming and scripted arithmetic were not available in this session (shell execution of Python and image tools was denied), so every forensic computation in forensic.json was done by hand with whole rounding intervals. The coordinator may wish to re-run the arithmetic mechanically.
- Table 2 row 10 (nonprofit organization) has nine correlation cells, but both text layers show only eight. I recorded nine values by column position from the images (two adjacent .21 entries). Please verify columns 2 and 3 of that row against the PDF at higher magnification (forensic F30; target T409).
- Correlations were recorded as per-row strings (T402-T418) rather than one target per cell, to keep the hand-written targets file reliable. The single correlation cited in the text (.51) has its own target (T401).
- No analyst data were used. No memory of the article or of other analyses was used to fill gaps.

## 2. Contradictions inside the publication record

Text versus tables (D1 pages in parentheses):

1. Firm age: text says years, 1991 minus founding year (p11); every table reports "Log of firm age" with log-scale descriptives (p13). Manifest uses the log; years is a flagged non-equivalent branch (A13).
2. Market competition: text describes a 1-4 scale (p12); Table 2 prints mean 0.44, SD 0.50 (p13), which only a 0/1 variable can produce; Tables 3-4 call the row "Competitive pressure". Manifest origin is the 1-4 scale per text, with the dummy as an uncertain branch (A16).
3. Market performance sample: text says profit-making organizations (p7); Table 1 footnote a says publicly held firms (p10). Origin is profit-making, which matches the NOS routing (A02).
4. Training index: text says the items were "standardized and averaged" (p7); Table 1 footnote b, attached to the training heading, says "standard score of logged value for all" (p10). Origin follows the footnote (A07).
5. "Dummy" controls: Table 2 means of 1.35 (nonprofit) and 1.44 (subsidiary) imply 1/2 coding, not 0/1 (F23). Slopes are unaffected; constants are.
6. "Three (training, incentive compensation, vertical hierarchy) are statistically significant" in "each equation" (p15), but Model 2 contains no vertical hierarchy term.
7. Discussion lists staffing selectivity among the practices positively related to performance (p18); it is insignificant in every Table 3 model and significant only in Table 4.
8. Standardized items have nonzero printed means (Table 1 and Table 2), which cannot happen if standardization used the analysis sample (F24).

Internal table inconsistencies under the stated one-tailed rule (all in forensic.json):

- Overstated stars: Table 3 Model 2 nonprofit (** where * applies, F03); Table 4 Model 8 training (* where dagger applies, F13); Table 4 Model 9 internal labor market (dagger not supported, F15).
- Understated stars: Table 3 Model 4 percent managers (dagger where * applies, F04); Table 3 Model 3 F for Delta R2 (* where ** applies, F08); Table 4 Model 10 staffing selectivity (* where ** applies, F16).
- F for Delta R2 not reproducible: Table 3 Model 5 (0.868 vs admissible 0.55-0.78, F07); Table 4 Model 8 (2.489 vs admissible 2.83-2.92, and identical to the overall F, F12).
- Sign anomaly: Table 3 Model 5 subsidiary -0.107 vs positive values in Models 2-4 (F09, undetermined).
- Table 2 footnote thresholds for the full sample are too low for the stated N (F25).
- Overall F statistics are consistent with 33 industry dummies, 9 (Table 3) or 8 (Table 4) controls and the printed N in every model (F05, F06, F29), which also confirms the nonprofit dummy is absent from Table 4 and that all industry dummies survive in the profit-making subsample.

D1 versus D2 (D1 governs; full list in F26): Table 2 cells row 6 col 5 (-.08 vs -.06), row 7 col 5 (.18 vs .16), row 10 SD (0.48 vs 0.46), row 14 SD (0.28 vs 0.26); Table 4 Model 7 incentive compensation SE (0.081 vs 0.061; the D1 value is the one consistent with the printed dagger); Table 4 Model 10 percent managers star glyph; several typographic glitches and reference-list typos in D2. D2 p11 confirms the "33 dummy variables" sentence that is clipped in the D1 text layer; the D1 page image also shows 33.

## 3. Items that could not be mapped to a dictionary variable

- Union pressure index: the article never lists its items. NOS establishment-level union items are V220, V233 (importance of union negotiations for CORE/GSS earnings), V300 (relations with unions as a future problem) and V166 (training because of union contracts). Which were used, and how they were oriented, is unknown (A11). Industry-level PCTUNION does not fit the description "respondents' perception".
- Decentralized decision making: NOS codes distinguish head of org, someone below, someone at the larger organization, combinations and "depends"; the article's 1-5 scale with "lowest = CEO" cannot be derived uniquely (A10). The two item sets (Q.72a for parts of larger organizations, Q.72b for independents) must be merged by V17.
- Two-digit SIC: the public NOS has only 1980 Census industry codes. The crosswalk gives 1972 SIC equivalents, but some Census categories span several SIC major groups and not-specified categories carry none; a tie rule is needed (A17). The article's 33 dummies need not equal the implementer's count.
- Subsidiary: V17 (part of a larger organization) vs V21 category 2 (wholly owned subsidiary); orientation unknown (A12).
- Percent managers: the manager count V115 is skipped when managers are the CORE or GSS occupation or absent; the article does not say what was done (A15).
- Staffing selectivity and training: skip patterns (no outside hiring; no formal training; GSS block skipped when GSS = CORE; manager block skipped when CORE/GSS managerial) make complete items impossible for many establishments; the averaging rule is unstated (A04, A05, A08).
- Duplicate establishment records (V3 = 0) are never mentioned (A01).

## 4. Missing or unpublished material

- No appendix, supplement or erratum exists (packet search). The authors reference unpublished results: complementarity count-variable models and their dummy/spline transformations ("results not shown"), subgroup analyses by sector ("available upon request"), and the extensive set of interaction subsets they experimented with. None can be targeted.
- Degrees of freedom, software and missing-data rules are not reported.
- Data vintage: the authors cite the 1993 release; the available file is the November 1994 second ICPSR release, which re-designated six cases as duplicates late in processing. Record counts may therefore differ slightly from the authors' copy.

## 5. Questions for the coordinator

1. Should the Table 2 row 10 reading (two adjacent .21 values) be verified by zooming the D1 PDF before targets are sealed?
2. Should the scorer treat the five star-level inconsistencies (F03, F04, F08, F13, F15, F16) by comparing implementer t-ratios to the printed coefficient/SE rather than to the printed stars? My aggregation proposal in claim_map.json assumes the stars, but the coefficient/SE pair is the more reliable published quantity.
3. For axes with no article-described level (A10 decentralization recode, A11 union items), origin_level is a placeholder labelled "uncertain". Please confirm whether the implementer should run all listed levels or whether the coordinator will pick one after reconciliation.
4. Are published N values (which appear in targets.json and in the sealed_n block) acceptable in forensic.json computations? They were needed for the F-statistic degrees-of-freedom checks and are kept out of manifest.json and spec_space.json as required.
5. The A02 L1 branch (publicly held only) would change the Table 4 population entirely; I recommend it be run only as a flagged diagnostic, not within the equivalent set.
