# Reader notes (independent reader, packet twenge2010_packet_v1)

All locators refer to doc P1 (main article), PDF page numbers (journal page = 1116 + PDF page). Work was done only from the packet, rules and source dictionaries. No raw data, no web, no memory of results were used to fill values.

## 1. Packet completeness and missing inputs

- The packet contains only the main article (P1). The packet states no supplement exists after a documented search, and the article mentions no appendix or online supplement. The article itself refers to Figure 1 (PDF p. 16); the figure's bars are not readable in the text extraction, so Figure 1 was treated as a redundant display of the Table 1 d values. The PDF is authoritative; a coordinator check that the figure shows nothing beyond Table 1 would be useful.
- The article says reliability estimates for the retained scales "are reported in Table 1" (PDF p. 10) but Table 1 (PDF pp. 11-13) contains no reliability column. These values are missing from the published record. No target was created for them. Question for the coordinator: is there any author-provided table of alphas elsewhere (none in the packet)?
- Published Ns are given only per form and year (PDF p. 10). Item-level n and CFA analysis n are not printed. Forensic finding F11 (RMSEA) suggests the 2006 Form 3 CFA n may be smaller than the form n.
- Vintage: the article cites the Johnston, Bachman & O'Malley (2006) 2nd ICPSR edition and says 2006 was the most recent year available. The packet's source files are ICPSR 7927 V4 (2007), 9871 V1 (2006) and 20022 V3 (2008). Whether the authors used per-year files or the cumulative file, and which release, is unknown (inference.json).
- The source description says the public weight is bracketed and differs from the original ISR weights. If the authors weighted (they do not say), exact reproduction of means is not expected.

## 2. Contradictions and errors in the published record

1. Response scale for Form 4 items. The Method (PDF p. 10) says the 23 job-characteristic items use a "5-point Likert-type scale ranging from not important to very important". All three dictionaries show four categories (1 Not important, 2 A little important, 3 Pretty important, 4 Very important), and the printed means with the top-category percentages are only possible on a 1-4 scale (forensics F06, F17). The manifest uses the 4-point source coding. The Form 3 anchors are "Disagree ... Agree", not "strongly disagree ... strongly agree" as the text says.
2. Sign of d for intrinsic 1976 vs 1991: text (PDF p. 16) prints "d = .05", Table 1 (PDF p. 11) prints "-.05" (F14). Targets transcribe the table value and note the text.
3. Metric invariance chi-square difference: 39.58 on 26 df is called "ns" (PDF p. 15) but has p of about .043 (F08). The delta-CFI criterion the authors rely on still supports metric invariance.
4. Partial invariance rule: the text requires at least two constrained indicators per factor (PDF p. 15), yet footnote a (PDF p. 13) frees one of the two altruistic items (F16).
5. Item-level t signs: the three t values for "would you want to work" are negative while the printed 1-2 means increase; the signs follow the percentage wanting to work rather than the mean. For "work you can forget about after the work day", the 1991 vs 2006 t (.54) does not match the printed means in sign or magnitude, and the 1976 vs 2006 t (-1.92) has the opposite sign from the means (F04).
6. One star level: "chance to earn a good deal of money" 1991 vs 2006 t = -2.37 is printed with *** (p < .001) but corresponds to p of about .018 (F05).
7. Multigroup degrees of freedom: the configural df (375) and two of the four delta df (26, 26) could not be reproduced from the described 19-item, five-factor, three-group model (expected 426 and 28, 28); partial scalar (16) and mean invariance (10) do reproduce (F10). The parameterization is undocumented.
8. RMSEA for the 2006 Form 3 model recomputes to .13 with the form n, printed .14 (F11).
9. Delta CFI for the mean-invariance comparison is .0083 from the printed CFIs but printed as .0080 in Table 2 and .008 in text (F07). Treated as 3-decimal rounding.

## 3. Ambiguities handled as open decisions (spec_space.json)

- Missing-data handling and analysis n (AX01); weighting (AX02); d denominator (AX03); what the printed SD for scale rows is (AX04); identification/scaling of latent means (AX05; the latent means closely track the first-listed item per factor, F15, suggesting marker scaling, but this is an observation only); CFA estimator (AX06); t-test variant (AX07); assignment of the four dropped Form 4 items to security/influence (AX08); which five Form 3 items form work centrality (AX09).
- The article does not report pairwise significance tests for latent mean differences; "significant" statements rest on effect sizes and 95% CIs. The claim map records direction as stated; implementers should output CIs and d so either reading can be evaluated.
- The "% v. imp." column for the yes/no item is the share answering "I would want to work" (code 1); this was inferred from the arithmetic (F06), not stated.
- Table 1 prints the 2006 social CI as "3.12- 3.20" (with a space) in the text extraction; transcribed as printed.
- Generational labels (Boomers, GenX, GenMe) are the article's framing; the source documentation treats each year as a cross-section where year, cohort and period coincide. Claims are coded by survey year.

## 4. Things that are fixed, not open

- 19 retained items and their five-factor assignment; the six freed intercepts (footnote a); the three years and two forms; sign convention later minus earlier (established by F01); the .002 delta-CFI criterion; the top-category definitions for percentages (Table 1 note).

## 5. Limitations of this reading

- Text extraction was used for transcription; the PDF was not visually re-checked for every cell. Any cell where the extraction may have shifted columns (notably the Table 2 TLI/CFI columns, which the extraction separates widely) should be verified against the PDF by the coordinator.
- No Figure 1 values were transcribed separately.
- The 2006 Western-region suppression does not affect any work item (checked: suppressed Form 4 items are V4169, V4170, V4264-V4266; Form 3 items V3169, V3170).
