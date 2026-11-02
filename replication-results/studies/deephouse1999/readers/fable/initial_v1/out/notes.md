# Reader notes (DOC01, packet v1)

Reader: independent reader, model family Claude. Inputs: DOC01 PDF text extraction and page images, publication_packet.json, reader rules, output schema, source descriptions, data dictionary (searched, not read end to end), call_item_candidates.json. No data were accessed and no model was estimated.

## 1. Pages consulted

All 20 PDF pages were read in the text extraction (DOC01_main_article_text_layout.txt, PDF p1-p20 = printed pp.147-166). Page images were checked for the pages carrying equations, hypotheses, analysis description and tables: DOC01_p09.png (p.155), DOC01_p10.png (p.156), DOC01_p11.png (p.157), DOC01_p12.png (p.158), DOC01_p13.png (p.159). The strategic deviation equation on p10 and the Model 3 equation on p11 were transcribed from the images because the text extraction garbles the summation and multiplication glyphs. Tables 1 and 2 on p12 were transcribed from the image and agree with the text extraction cell by cell.

Section map used for locators: p1-p3 introduction and theory (pp.147-149); p4-p9 theory and context (pp.150-155); p9 Research design, Sample and data, Dependent variable, Independent variable (p.155); p10 equation, Hypotheses, Control variables (p.156); p11 collinearity note, Analysis, Results start (p.157); p12 Tables 1 and 2, Results (p.158); p13 Results continued, discussion start (p.159); p14-p16 discussion (pp.160-162); p17-p20 references (pp.163-166).

## 2. Limitations of the published record

- No supplement, appendix, codebook or author data exists in the packet, and the packet search found none. Estimates with the 11 asset-strategy controls are described as available from the author only (p10-p11); they cannot be targeted.
- Call Report item mappings for the 11 asset categories are not given. The article names categories only (p9). My mappings (manifest `asset_share_a`) are reader choices with alternatives listed in specification_space.json axes V5-V8.
- The market boundary is described only as the Minneapolis-St. Paul metropolitan area (p9). The county composition and whether Wisconsin counties were included are not stated.
- Average assets (p9), the deflator for real market deposits (p10), and the deposit item for market share (p10) are not defined at item level.
- Sample attrition is summarized in one sentence (p9): foundings, mergers, failures, the lag requirement and one deletion. No counts by year or by cause are printed. The treatment of acquirers in merger years is inferred from the statement that acquisition effects are incorporated in strategic position.
- The statistical software is not named. Durbin h, studentized deleted residuals and condition numbers are standard outputs of several packages; I did not infer the package.
- Tails of the significance tests are not stated; stars follow a conventional 0.05/0.01/0.001 scheme (p12 table notes). No exact p values appear anywhere.
- Table 1 reports relative ROA in raw ratio units (SD 0.007) while Table 2 uses the x100 scale (p11). This is documented in the text and is not a contradiction, but implementers must reproduce both scales.
- The descriptive statistics and correlations in Table 1 are printed data and are sealed targets only.

## 3. Publication contradictions and tensions

- "Minneapolis-St. Paul, Minnesota, United States, metropolitan area" (p9) versus the metropolitan area's MN-WI composition (source descriptions section 5). Recorded as axis S1; the full area is the origin because the article says the market was defined by regulators as the metropolitan area (p4).
- "159 independent banks" (p9) versus 960 bank-years over 8 years (120 per year). Not a contradiction, but the word "independent" is ambiguous; it must mean separately chartered banks because the deleted outlier (Norwest Bank Minneapolis, N.A.) is a holding-company affiliate (p11).
- The article says OLS estimators were "consistent" after the Durbin h test (p11) but reports WLS (p11-p12). Not a contradiction: WLS was chosen for heteroscedasticity and the autocorrelation test only ruled out an AR correction.
- Market share is n.s. in the bivariate correlation with relative ROA (Table 1, -0.04) but strongly negative in the weighted Model 1 (-0.576***). Not an inconsistency, but it shows that the market-share result depends on the market-share weighting and the controls (forensic FX17).
- The two correlations printed as 0.08 carry different stars (** and *). Both are consistent within rounding (forensic FX11).
- Hypotheses 1 and 2 are stated as competing directional hypotheses on one coefficient (p10). The article reports two-sided-looking stars; direction is assessed from the sign.

## 4. Open questions for the coordinator

1. Is naming the outlier bank (Norwest Bank Minneapolis, N.A., 1987) in the implementer manifest acceptable? It is a sample-construction fact from the article, not a result, but it is an identifying detail. If not, sample step S9 should be replaced by level S5.b (delete the common maximum studentized deleted residual) with the name held back.
2. Branch-level FDIC Summary of Deposits data (the usual source for local deposit market shares in the cited banking literature) are not among the acquired sources. Bank-level Call Report deposits are used instead. Should the coordinator consider acquiring Summary of Deposits for 1984-1992 as a vintage fallback?
3. The data dictionary caveat for RSSD9180 (MSA code vintage unknown) means the county-list rule (S1.a) and the provider-code rule (S1.b) may disagree for a few banks. I recommend the implementer report both counts.
4. The small-form missingness rule (treat a non-collected component as zero) is my construction and is not in the article. The coordinator may prefer to make it a labelled axis.
5. The weight-scale observation (forensic FX14) is a plausibility check only. I did not use it to select the weight definition; the origin follows the text ("error variance was inversely proportional to market share", p11).

## 5. Items deliberately not treated as specification alternatives

- Changing the control list in any model (explicit in the Model 3 equation, p11, and Table 2).
- Replacing the quadratic with another functional form (the article's discussion mentions alternatives only as future research, p13-p14).
- Using the 11 asset-strategy proportions as controls (described but unreported, p10-p11); listed as claim C10 with no targets.
- Pairwise-distance or Euclidean similarity measures (discussed as future research, p15), which would be a different construct.

## 6. Forensic summary

All recomputable published quantities are internally consistent within rounding: delta SSE values, the three F statistics and their degrees of freedom, n and df, coefficient/SE ratios versus stars in Tables 1 and 2, the Table 1 identity between the mean of the squared index and the mean and SD of the index, the Durbin h statement, and the SSE ordering of the robustness model. Not checkable from the record: the turning point relative to the sample maximum, the year-by-year attrition, and whether the relative ROA mean is exactly zero (see forensic_observations.json).

## 7. Files written

out/claim_map.json, out/sealed_targets.json, out/manifest.json, out/sealed_n_branch.json, out/specification_space.json, out/wider_space_assessment.json, out/forensic_observations.json, out/notes.md.
