# Independent reader notes

I used only the files supplied in this working directory. P1 is the sole publication document in the frozen packet. I read the article and checked Tables 1–2 and Figure 1 against rendered PDF pages; the PDF and convenience text hashes match the packet. No web access, contacts, other reader work, raw observations, model fitting or outside result memory was used. Calculations in forensics.json use only printed quantities and are sealed comparison-record checks, not replication estimates.

The claim map covers the five exploratory research questions, all fifteen latent pairwise findings, every individually reported item, the psychometric/invariance diagnostics, and current-study descriptive and interpretive conclusions. Background numbers about other studies or workplace anecdotes are not targets for this study. No separately reported robustness model or covariate-adjusted nuisance-control specification was found; none was invented. The discussion’s policy/entitlement explanations are labeled unestimated implications, not causal estimates (P1 pp.18–22).

## Packet and missing-input limitations

The packet contains no supplement. That is not evidence that no supplement exists. publication_packet.json records an unsuccessful automated visit to the publisher supplementary tab and indirect searches; it also says the Retraction Watch database was not directly queried. Its referenced sources/supplement_search.json is not supplied here. I did not attempt to obtain it externally. The article does not announce an appendix or online supplement, but original syntax, additional tables and corrections cannot be ruled out from this packet. The packet reports no corrections found; this is the packet’s search status rather than an independent reader verification.

The source descriptions and dictionaries have no publication doc_id or PDF page in the frozen packet. Their citations therefore use exact relative source-file names and variable keys, alongside the P1 page that motivates each mapping. I did not invent document IDs for them. File paths mentioned inside source metadata were not followed outside the directory. The raw data, original codebooks, full cross-time question index and annual design guidance are absent.

## Fixed mapping and coding

Forms 3 and 4 are explicit in P1 p.10. The correct supplied mapping is 1976 DS0003/DS0004 and 1991/2006 DS0004/DS0005. DS numbers must not be treated as invariant form numbers. The six Form 3 items are V3222–V3227; the twenty-three Form 4 items are V4225–V4247. Dictionary wording and response labels were checked for every mapped item in each selected year/form. The identically worded binary item also occurs elsewhere, but its Form 3 version is used because the article specifies that form; it is not pooled with Form 4 respondents.

The article calls Form 4 a five-point scale (P1 p.10), whereas all three supplied dictionaries give four substantive categories, 1 through 4. Form 3 agreement items are 1 through 5 and the work-if-rich item is 1=want to work, 2=not want to work. Native descriptive coding is preserved; higher native binary scores mean less willingness to work. Endorsement uses Form 4 code 4, agreement codes 4 or 5, and binary code 1. No fifth response category is manufactured. AX02 keeps the article/source conflict visible.

All documented missing codes are removed before scoring: in the selected 1976 files zero or nine through highest; selected 1991 items declare zero/nine and the codebook says zero or greater/equal nine; selected 2006 items use minus nine. Only labeled substantive codes are allowed. Metadata-level missing codes do not resolve analysis-level deletion or imputation. No exact age, employment, race or other demographic exclusion is justified by P1; “most” are 17 or 18 is descriptive (P1 p.9), not a filter.

## Model and inference ambiguities

Table 1 scale rows are latent means (P1 p.13), not averages of the listed items. The fixed final memberships contain 19 Form 4 items, grouped into five factors. A summed or averaged score would change the estimand and was not inserted as an equivalent branch. The rejected centrality, security and influence scales are kept out of final total-score analyses as stated (P1 p.10), while their individual items remain descriptive outputs. Seven-factor security/influence membership is inferable from wording but not explicitly tabulated and remains AX12.

P1 names LISREL 8.7 but supplies no fitting function, native syntax, covariance normalization, marker indicators, intercept origin, residual correlations, optimizer options, model-specific eligibility counts, weight handling or design-based covariance rule (P1 pp.10,14–15). The manifest gives explicit provisional formulas and marks them as choices; these are not recovered software defaults. Any equivalent marker or likelihood parameterization must map back to common units and use identical data and constraints. The exact published d formula is null because no denominator definition is supplied (P1 pp.13,15–16). AX09 distinguishes explicit plausible denominators without selecting by target agreement. The provenance of the SDs printed with latent means is also not specified.

Table 1 flags six items for partial scalar release: time for other things, freedom from supervision, creativity, helping others, earnings and advancement (P1 pp.11–13). A literal all-group intercept release would remove twelve constraints, whereas Table 2’s scalar-to-partial df difference is ten (P1 p.14). The text’s “at least two” invariant indicators per factor rule also sits uneasily with the two-indicator altruistic factor and one flagged altruistic item (P1 p.15). Group-specific syntax is needed; I did not silently drop an item or search constraint subsets.

The individual five-factor CFA df of 142 matches a conventional 19-indicator correlated-factor model. The reported multigroup configural df of 375 and metric increment of 26 fit a conventional 18-indicator calculation instead, although other unreported parameters could also explain them (P1 pp.10,14). This is conditional parameter-count algebra, not proof that 18 items were used and not permission to change the explicit list.

Item t tests lack df, tail, variance assumptions and software details. The narrative’s latent pairwise significance claims lack contrast SEs, exact p values and the cross-group mean covariance (P1 pp.11–17). Individual confidence intervals are not a substitute for the missing contrast test. Multiple-comparison adjustment is not stated. No-star cells never become exact p values. Different levels of significance wording, such as p<.05 in the text and ** meaning p<.01 in Table 2 for mean invariance, are logically compatible, not contradictions.

The article refers to reliability estimates for retained scales in Table 1, but the table note identifies parentheses as SDs or SEs and no alpha estimates can be identified (P1 pp.10–13). Exact reliabilities stay null; rejected-scale alpha values have only the collective upper bound given in the text. Raw versus standardized alpha is open.

The public sources lack school/PSU/stratum identifiers, and public V5 weights are confidentiality-modified. Source documentation recommends weighting and warns about clustered inference, whereas P1 does not report implementation of either. Region is not a valid replacement cluster identifier. Public-file vintage matches are not proven: the three supplied releases are documented, but exact original author vintages are not (P1 p.10; data citation p.24; sources/source_description.md).

## Printed-record checks

All fifteen reported d values are compatible, over complete rounding intervals, with the conditional equal-group root-mean-square SD reference calculation. This checks arithmetic compatibility only and does not identify or authorize the original denominator. Reported sample counts add to the stated overall count (P1 pp.1,10); they are not treated as item or model Ns.

The metric-invariance chi-square difference of 39.58 on 26 df implies p about .0429 throughout the rounding interval, although the narrative calls it ns (P1 pp.14–15). This conflicts at a conventional .05 threshold; a stricter unstated threshold could differ. The small CFI change is a separate criterion and still supports the article’s CFI-based interpretation.

The printed CFI difference for the final latent-mean invariance comparison is .0080, whereas the two printed parent CFIs imply a difference in [.0082,.0084], which cannot round to .0080 at four decimals (P1 p.14). The narrative .008 uses coarser precision and can be compatible (P1 p.15).

The earnings item’s 1991–2006 t is −2.37*** (P1 p.12). Across the full rounded t interval, even a one-tailed normal p exceeds .001; conventional finite-df t tails cannot meet the printed *** threshold. This is retained verbatim, with no correction. Other nested-test stars need not be the maximum possible star level under the one-way inequality legend.

For 2006 altruistic and extrinsic latent means, the printed CI endpoints and SE cannot simultaneously arise from a normal-Wald 95% construction over their complete rounding intervals (P1 p.12). The precise CI algorithm is unreported, so those findings are expressly conditional on that construction.

The intrinsic 1976–1991 d is −.05 in Table 1 but .05 in the narrative (P1 pp.11,16). Both are preserved; the prose may be quoting magnitude. In the “forget work after the day” row, two t signs disagree with the native mean changes, and a uniform row reversal does not fix all three comparisons (P1 p.13). In the work-if-rich row, the signs can instead reflect a consistently reversed binary orientation while means stay native; this remains a coding question. No numerical match was used to resolve either issue.

Figure 1 was visually checked but not digitized: points have no exact numeric labels. The baseline is explicitly zero for 1976 (P1 p.16). Table values supply the exact effect targets. Descriptions such as “almost twice,” “nearly half” and “three fourths” remain approximate narrative quantities, separate from the finer Table 1 percentages.

## Questions for the coordinator (recorded only; no contact made)

1. Can the missing supplement-search log and any permitted original syntax or supplementary files be added to a future frozen packet, particularly the original model/item list and group-specific intercept releases?
2. Which exact data vintages and weighting/missingness settings were used? Are item/model eligible counts, original survey weights, and actual design identifiers available through an authorized source?
3. What were the latent factor markers/origins, scale SD definition, precise d denominator and 95% CI formula? Were any correlated residuals, cross-loadings or unreported item changes present?
4. What were the exact individual and pairwise latent test procedures, orientation, df, tail and multiplicity rules? Can original output clarify the suspect signs and stars without replacing the frozen publication targets?
5. Where are the retained-scale reliability estimates that P1 says Table 1 reports, and is there a documented correction for the Form 4 category count or Table 2 CFI difference?

The specification space has only identified unresolved decisions; some levels cannot run without missing inputs and say so. Broader exploratory specifications remain off. Methodological reparameterizations are labeled equivalent only with explicit transformation constraints. No choice is selected by numerical agreement. Manifest numbers are limited to source years/codes, method constants, structural definitions and locators; all published estimates and counts are excluded from that file. Targets and forensic results are sealed, and published counts have their separate machine-readable branch. These files are the first complete outputs and will not be revised after writing except if invalid JSON is discovered.
