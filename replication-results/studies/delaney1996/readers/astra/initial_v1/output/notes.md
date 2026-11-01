# Independent reader notes — initial round

This reading uses only the supplied frozen packet, source descriptions, dictionary and historical industry crosswalk. Both copies were read, with all D1 pages inspected as images and the numerical tables compared visually to D2. D1 governs article locators: its PDF page 2 is journal page 949; D2 PDF page 1 is journal page 949. No web access, raw survey records, fitted regressions, other-reader output, author code or prior analysis was used. Calculations in `forensic.json` use printed publication values only.

The eight schema files are accompanied by `DONE.txt`. This is the first complete initial-round set. Published numerical results and sample counts are excluded from `manifest.json` and `spec_space.json`; source variable codes, scale endpoints, design dimensions and inference alpha levels remain because they are implementation instructions. Null weights, covariance, software and missing methods mean **unknown**, not “none used.” Unresolved branches are not authorization to search for a specification that matches the publication.

## Packet identity and availability

D1 and D2 match title, authors and journal identity (D1 PDF pp1–2; D2 p1). D2 is an alternate retypesetting, not a supplement. Both PDF hashes match `publication_packet.json`. All 47 PDF/image/text entries in `PACKET_SHA256SUMS.txt` pass. Its additional self-referential checksum for `PACKET_SHA256SUMS.txt` fails; the inputs were not changed. A checksum listing its own digest is a manifest issue, not evidence that either article copy changed.

The packet supplies no supplement, appendix, correction or author code. Its metadata reports a documented supplement search with none found and a publisher HTTP 403; the underlying search log and project-level STUDY/catalog/CLAUDE files referenced by generic rules are not supplied. I have not independently repeated that search because this assignment expressly forbids outside access. No appendix follows the discussion: D1 pp20–22 / D2 pp19–21 are references and biographies. Unshown complementarity regressions (D1 p17; D2 p16) and subgroup analyses “available upon request” (D1 p18; D2 p17) remain unavailable, rather than assumed absent. No author code or code links were encountered.

## Primary numerical and transcription findings

`targets.json` contains all printed regression coefficients, SEs, constants, model R2/F/delta-R2/joint-F/N, all Table 1 item means/ranges/reliabilities, and all printed Table 2 means, SDs and correlations. There is no invented zero for the blank market-performance/nonprofit correlation, nor an invented set of model statistics for columns 1 and 6. Each of those columns reports seven regressions; the ten labeled columns represent 22 tabled equations (D1 pp15,17 / D2 pp14,16).

The following D1/D2 differences are retained as separate sealed targets, not corrections:

| Location | D1 | D2 |
|---|---|---|
| Table 3, model 2, training SE | `(0.041)` | `[0.041)` (typography only) |
| Table 3, model 3, joint F | `3.953**` | `3.953*` |
| Table 4, model 7, incentive-compensation SE | `(0.081)` | `(0.061)` |
| Table 4, model 10, percent-managers coefficient suffix | `−0.604**` | `−0.604”` (quotation-like glyph; significance indeterminate) |
| Table 2, nonprofit SD | `0.48` | `0.46` |
| Table 2, manager-share SD | `0.28` | `0.26` |
| Table 2, grievance / incentive correlation | `−.08` | `−.06` |
| Table 2, decentralization / incentive correlation | `.18` | `.16` |
| Table 2, log-age / training correlation | `.28` | `.26` |
| Table 2, service / manager-share correlation | `.08` | `.06` |

Locators: Table 2 D1 p13/D2 p12; Table 3 D1 pp14–15/D2 pp13–14; Table 4 D1 pp16–17/D2 pp15–16. Other numerical table cells agree in this transcription. D2 has minor reference-list and prose typographical defects; for example D1 p20 prints Arthur pages 670–687 and D2 p19 prints 670–667; D1 p21 prints Lado while D2 p20 prints Lade. These do not justify altering any result.

Under conventional full-rank OLS t inference, three printed significance assertions cannot hold anywhere in the coefficient/SE rounding rectangles: model 2 nonprofit `−.209** (.092)`, model 8 training `.076* (.058)`, and model 9 internal labor market `.588† (.566)`. Model 2 internal labor market has no star although its magnitude-tail p is below .10; its negative sign is consistent with nonsignificance for a prespecified positive alternative, so that case is **undetermined**, not an unconditional error. Some marks are weaker than the strongest available threshold; this is distinguished from violating the asserted inequality. Borderline entries are never rejected solely from their displayed point ratios (D1 pp14,16).

Conditional on the stated model dimensions, full-model F/R2/N triples are compatible after rounding. Model 5 delta-R2 versus joint F and model 8 delta-R2 versus joint F are incompatible over whole rounding intervals. The stricter simultaneous constraint involving both models’ overall F and R2 and their nested partial F also flags model 4 versus model 2. All such findings are conditional on full-rank conventional OLS and common nested observations; df and covariance were not printed. See the individual formula-based records in `forensic.json` (D1 pp15–17).

The Table 2 footnote’s full-sample correlation significance cutoffs are too small under the standard one-tailed Pearson test, even allowing their complete two-decimal rounding intervals; the smaller market-sample cutoffs are compatible/conservative (D1 p13 / D2 p12). These publication diagnostics do not establish which target should be changed and are not replication verdicts.

## Text, coding and sample conflicts

- Market performance is for profit-making organizations in the prose (D1 p7 / D2 p6), but publicly held firms only in Table 1 footnote a (D1 p10 / D2 p9). Dictionary Box F supports the broader profit-making survey universe. Both branches remain visible.
- Training is standardized and averaged in prose (D1 p7 / D2 p6); Table 1 footnote b says standard scores of logged values for all staffing and training items (D1 pp9–10 / D2 pp8–9). Applying log to a zero-coded binary item is undefined. The article does not say how binary coding, no-training skips, zeros or effectiveness “varies/depends” were handled.
- Age is described in years (D1 p11 / D2 p10), while all tables label log age. Hierarchy is described as a count (D1 p8 / D2 p7) but explicitly logged in Table 1 footnote c (D1 p10 / D2 p9). Log bases and zero handling are missing.
- Competition is explicitly 1–4 (D1 p12 / D2 p11), but Table 2 reports mean .44. This cannot be an average of valid 1–4 values. The record does not establish a binary cutoff. Nonprofit and subsidiary are called dummies (D1 p11) but have Table 2 means above one; a 1/2 source coding is a possible offset representation, not a recovered author choice.
- The nonprofit SD differs across versions. Neither copy is preferred because a number appears closer to a binary-variable identity. The primary copy governs transcription only.
- The “five of six” positive HRM slopes statement holds in each simultaneous organizational model (D1 p15 / D2 p14). Model 2 has two significant HRM practices, while model 3 has three; vertical hierarchy is not included in model 2. Thus the prose’s three named significant practices must be read across the pair of specifications rather than as three in each.
- The general statement that isolated-practice coefficients are larger (D1 p19 / D2 p18) holds for signed slopes in the main-effect comparisons; it need not hold for absolute magnitudes of negative slopes or for reference-dependent main effects in interaction models.
- D1 p5 / D2 p4 correctly describes size-proportional establishment inclusion; D1 p18 / D2 p17 later calls the organizational sample equiprobable. The public source distinguishes GSS person sampling from establishment sampling and supplies design weights, but the article never reports whether weights were used.

## Implementation gaps and questions for the coordinator

Resolve these from permitted documentation or freeze explicit uncertainty branches **before** execution; do not use sample size, coefficients, reliabilities or descriptive values to select a branch.

1. Were copied nominations retained or were V3=0 records removed? What exactly links source interviews to the analysis sample? D1 pp5–6 gives no exclusion sequence; pp15,17 only print final N. V1 is a record identifier, not a documented establishment cluster key. DUP/NUMOBS semantics are insufficient to invent a grouping rule.
2. Which market-eligibility statement governs? How were scale item nonresponse and occupational same-as-CORE/GSS routes treated: copy, available-item mean, or complete-item exclusion? Which minimum counts apply? Were regression samples common within outcomes or model-specific? D1 pp7–10 and table footnotes do not answer.
3. What is the raw-code map to the five-level decision-authority scale? Dictionary Q.72 uses nominal single/mixed authority codes whose numerical ordering does not match the article’s decentralization ordering. The two routed blocks must be merged; no unique 1–5 recode is available (D1 p8 and Table 1 p10).
4. Which questions form union pressure? Candidate V220/V233 concern union negotiations, and V300 concerns anticipated union-relations problems. The article prints neither item names nor item count (D1 p12); their inclusion is uncertain, not a confirmed map.
5. Were employment counts raw V23+V32 or release-assigned NEWTOTAL? How were no-manager and same-occupation manager routes incorporated into numerator/denominator? Which units represent percent managers? Were top-coded application, participation and hierarchy categories retained, recoded or excluded? D1 pp7–12 omits these decisions.
6. What SIC vintage, Census-to-SIC mapping, ambiguous-code handling, reference category and effective industry rank were used? The source contains Census industry codes, not SIC. The supplied 1972-SIC crosswalk does not identify the authors’ grouping and contains multi-valued/unspecified entries. Do not truncate Census codes or force a desired number of groups (D1 p12).
7. Which estimator, weights, covariance correction, degrees-of-freedom convention, software/version and significance direction were used? The article says multiple regression and unstandardized coefficients/SEs but supplies no native formula. Negative nuisance slopes do not establish prespecified lower-tail hypotheses (D1 pp11,15,17).
8. What were the full median-count, threshold, spline, interaction-search and profit-status subgroup models? Median reference population, spline knots, exact regressors, sample sizes and subgroup comparisons are absent (D1 pp11,17–18). The manifest identifies these as non-executable without additional decisions; it does not invent a search grid.

H1 is the primary headline claim, with H2 a separately focal exploratory hypothesis. The article gives no scalar success criterion across outcomes/practices. The proposed aggregation keeps all simultaneous-model slopes and joint tests visible, treats isolated-practice regressions as the stated comparison, and does not convert absent H2 significance into proof of no complementarity (D1 pp5,15,17–19). Cross-sectional associations do not identify causal HRM effects; the authors explicitly acknowledge unavailable instruments (D1 p19 / D2 p18).
