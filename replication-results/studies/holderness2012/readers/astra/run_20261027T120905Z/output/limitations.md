# Independent reader limitations — P-R7M2

Only the frozen D1 publication and the supplied summary-free source descriptions, dictionaries and code lists were used. D1 has a repository cover at PDF page 1; article pages are PDF pages 2–15. The PDF SHA-256 matches the packet. No internet, registry observations, author code, other reader output, or recalled results were used. All published tables and equations were checked against the supplied page images. No unresolved table glyph remained; OCR scrambling was corrected only by reading those images, not by changing printed values.

## Contradictions and publication-only diagnostics

- Table 4 reports 100,464 observations, while Table 6 reports 102,334. The latter adds officer interactions without explaining an expanded sample. Table 1 reports 122,765 prisoners; the reductions to either regression sample are not reconciled. Table 5 has no printed N. Do not target-match sample construction. [D1, PDF pp.6, 9, 13; Tables 1, 4–6.]
- The introduction's 20% reduction for the most versus least hierarchical groups is not traceable to a specified model or contrast. The identified top/bottom captured-steepness quartile comparison is 81% versus 87%, or six percentage points. Ordinary rounding cannot make these the same 20% relative comparison, but the introduction could refer to different endpoints. It is an unresolved contrast, not a proved contradiction between identical estimands. [D1, PDF p.3, §1; p.8, §4.4 and footnote 11.]
- Table 3 Group D sameness is printed 0.95. The printed equation and hypothetical counts give approximately 0.95666. Even generously allowing rounding of the reference fractions and scale leaves the result outside the 0.95 rounding bin. Group E's value is also close to a rounding boundary, but reference-share uncertainty can reconcile it. Both printed values are retained. Full rounding checks are sealed in `forensics_sealed.json`; no hypothetical rank counts or reference fractions are copied into the manifest. [D1, PDF p.7, §4.1.2 and Table 3.]
- The text refers to Panel C of Table 5, although only Panels A and B exist; the described ROC results appear in Panel B. The same passage calls this a probit-appropriate F-test but supplies only a paired ROC-area description, without statistics or degrees of freedom. [D1, PDF p.9, §4.5 and Table 5.]
- Enlistment coverage is described as both 1938–1946 and 1938–1945. This is not enough to infer a date-based exclusion. [D1, PDF p.5, §3.]
- The article says it measures hierarchy in ten ways, but does not unambiguously map that count to ten enumerated constructs. Do not invent variants to reach ten. [D1, PDF pp.10–11, §§5.2–5.4.]
- Table 1's note says all data items are defined in Table 2, but weight and the outside-home-country indicator do not receive full definitions there. Group summary weighting and item-specific denominators are also unclear. [D1, PDF pp.6–7, Tables 1–2.]

## Missing tables, appendices and described analyses

The frozen packet lists no supplement, e-companion or correction and records excluded earlier working-paper/accepted-manuscript versions. This is a limitation of the supplied publication record, not proof that no further documentation exists. There is no supplied documentary appendix to read and no author replication package established by the supplied files. D1's bibliographic, archive and historical-source links are not replication-code links; none was accessed. The rule files reference additional workflow documents and a package-selection rule in CLAUDE.md, but those files are not supplied. Their absence does not justify inventing their contents or stopping this otherwise authorized reading assignment.

The following results lack complete published tables:

- Separate Germany/Japan repeats, said to appear in earlier versions. [D1, PDF p.10, §5.1.]
- Social-network additions/removals and friends-only hierarchy measures; only the largest friends p-value and approximate p-values are given. [D1, PDF p.10, §5.2.]
- Alternative pay-based steepness, ratio/absolute-deviation sameness, rank count, rank sum, administrative intensity, complete cases, minimum cohort sizes and exclusion of executions. [D1, PDF pp.10–11, §5.3.]
- German Army Air Force results, also attributed to earlier versions, with only selected p-values and significance counts. [D1, PDF p.12, §5.4.]
- Greater age vulnerability in Japanese camps. [D1, PDF p.8, §4.4.]
- Pay-by-hierarchy and separate-regime officer checks. [D1, PDF p.12, §6.1 and footnote 13.]
- Size models dropping the squared term, and hierarchy-by-size interactions. [D1, PDF p.14, §6.2.]

Red Cross camp food-shipment data were sought unsuccessfully, so the proposed direct market-mechanism test is not reported and cannot be reconstructed. Anecdotes and group-size patterns do not identify a causal trade mechanism. [D1, PDF pp.12–15, §6.2 and §7.]

## Source-to-construction gaps

- Actual initial camp, capture date and camp-entry month are not directly observed in the available fields. The article treats the camp as initial and describes capture/entry dates, whereas NARA says CAMP may be first or last and DATE_REPORTED is a report date. Subsequent movement cannot be reconstructed. The article's assertion of attenuation toward zero is not established by these facts alone. [D1, PDF p.5, §3 and footnote 7; pp.7–8, Table 2 and §4.2; supplied POW dictionary/source description.]
- Nine published rank categories do not supply a crosswalk for service-specific ranks, technicians, warrant/flight officers, cadets, nursing designations or malformed codes. Raw GRADE_CODE is not a nine-point ordinal scale. Merchant mariners, correspondents, unknown service and contradictory civilian labels also need explicit treatment. [D1, PDF pp.5–7, §3 and §4.1; supplied POW grade/service lists.]
- Serial-number linking is named but prefix normalization, blanks/NULs, repeated POW records and multiple enlistment cards are not resolved. Name matching is not described. Unmatched covariates should not cause silent wholesale sample loss or many-to-many row expansion. [D1, PDF p.5, §3; source descriptions and dictionaries.]
- Enlistment records have an ERC layout. Height/weight fields had other uses on some card versions; NARA could not date their meanings reliably. A numeric-looking value is not sufficient to establish height or weight. Two-digit birth-year centuries, postgraduate years and dependency for married code 2 are unresolved. [D1, PDF pp.5 and 7, §3 and Table 2; supplied enlistment dictionary and education/marital lists.]
- The exact population used to form reference rank shares, timing of group counting relative to exclusions, missing-rank denominators and recomputation within robustness subsets are unspecified. Table 3 must not serve as a source-data substitute. [D1, PDF pp.6–7, §4.1, footnote 9 and Table 3; p.11, §5.3.3.]
- Camp locations are an independent reconstruction. Duplicate code meanings (359 and 510), approximate geocodes and unknown sites need review. Capital coordinates, distance formula, city-membership rule and historical country boundaries are not supplied. Modern country labels do not automatically recover Germany or Japan proper. [D1, PDF p.4, §2.1; p.7, Table 2; supplied crosswalk schema.]
- Missing-variable zero filling and indicators are explicit, but their scope and ordering relative to logarithms, squares and products are unclear. Missing camp identities must not be pooled into a fictitious observed cohort. Size-square scaling, inclusive month counting and zero-friend logarithms need frozen rules. [D1, PDF pp.5, 7–8, §3, Table 2 and §4.3; p.10, §5.2.]
- Historical pay schedules, injuries at capture, death times, Red Cross shipments and card-component identifiers are unavailable. Death/report-close dates cannot be substituted. [D1, PDF p.5, §3; p.8, footnote 10; p.10, §5.3.1; p.14, §6.2; supplied source descriptions.]

## Inference and interpretation limits

The paper prints rounded p-values, not standard errors. Printed 0.00 is not an exact zero; 0.05 and 0.10 straddle common thresholds. Alpha, test tail, software, covariance small-sample correction, reference distribution, fitted cluster counts, degrees of freedom, convergence treatment and perfect-prediction exclusions are unstated. ROC dependence handling beyond a paired-curve citation is unspecified. No IV or first-stage result exists. [D1, PDF pp.8–9, §§4.4–4.5 and Tables 4–5; p.13, Table 6.]

The product-regressor slope in a probit is not generally the probability-scale officer interaction. The exact reported convention is unresolved and the two quantities must not be substituted. Quartile cutoffs, weighting, and prediction averaging for the survival contrast are also missing. [D1, PDF p.8, §4.4 and footnote 11; pp.12–13, §6.1 and Table 6.]

This is observational administrative evidence with incomplete coverage and no measured capture injury. Air-service restriction is an argued endogeneity diagnostic rather than verified random assignment. No specification alternatives are selected by numerical agreement. Explicit control lists stay fixed within equivalent implementations; distinct hierarchy definitions, cohort levels and restricted samples are not interchangeable claims. The wider grid remains off. [D1, PDF pp.5, 8, 10–12, §§3, 4.3, 5.1–5.4.]

## Questions for the coordinator before implementation

1. Can missing permitted documentary methods (not author code or excluded earlier results) be added through a versioned packet and the same independent rereading opportunity? In particular, seek sample-flow details, full rank crosswalk, software/effect conventions and complete robustness specifications. [D1, PDF pp.9–14, Tables 4–6 and §§5–6.]
2. Which source-only conventions should be frozen for ambiguous ranks/services, serial linkage, duplicate records, card layouts, height/weight vintages, postgraduate education, married dependents and birth centuries? The candidate rules are explicitly marked uncertain in the manifest. [D1, PDF pp.5–7, §3, §4.1 and Table 2.]
3. Can independent camp/capital coordinates, historical boundary conventions and historical pay schedules be supplied without exposing publication targets? Which initial-camp/report-month proxies and group-construction population are approved? [D1, PDF pp.6–8, §§4.1–4.3; p.10, §5.3.1.]
4. Was the separate title-and-authors memorization probe performed upstream? No probe record was supplied to this reader. Running it after reading would not reproduce the requested pre-reader procedure; none was fabricated. [Workflow provenance: rules/reader_rules.md, §2; no D1 page applies.]

These questions do not prevent completing the reader-stage outputs. They identify unresolved inputs for later implementation. This first complete output set is final for the round; no feedback-based revision was made.
