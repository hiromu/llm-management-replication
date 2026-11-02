# Reader notes (paper P-7Q3)

## Contradictions and mismatches between MAIN and S1

1. **Cross-reference error.** MAIN p.14 cites "Panel B of Online Appendix table A1" for the established-owner descriptives. In S1 that panel is Table A2 Panel B; Table A1 is the country-level table (packet known gap; forensic F16).
2. **Childcare spending ranking.** MAIN p.12 says Finland, Denmark and Sweden spend more than 0.6 percent of GDP. S1 p.1 Table A1 prints Sweden's mean as 0.58 and Iceland's as 0.60 (F10). The text statement is about levels, the table about survey-year means, so this is a minor wording mismatch rather than a data contradiction.
3. **Germany paid leave.** MAIN p.12 gives about 42 weeks; S1 Table A1 prints a mean of 36. Germany is listed among the eight countries with a policy change (fn 7), so the mean can legitimately differ (F11). Not treated as a contradiction.
4. **S1 Table A1 S.D. row.** The S.D. for women's part-time employment is printed as 0.23, identical to the childcare S.D. and impossible for a variable spanning 5 to 60 (F09). Comparison material only; does not affect implementation.
5. **S1 Table A3 Model 2 fertility rate.** The cell is blank. The AIC-implied parameter count suggests the variable was in the model (F08). Model 2 also uses a 'Not employed' control not present in MAIN.
6. **S1 Table A3 Model 3 AIC.** Printed "19950", inconsistent with the log likelihood (F07); probably truncated.

## Gaps and redactions

- No code, data appendix or replication file exists in the packet; S1 is a three-page table supplement with no redactions.
- The unconditional means models and LR test of MAIN p.18 fn 17, the per-country logits behind Figures 1-3, and every robustness check in footnotes 8, 11, 12, 13, 21, 22, 23, 24 and 25 are not tabulated and cannot be sealed as targets.
- MAIN Table 1 Model 2 prints a negative standard error for Age squared (F01). I left the SE null in the sealed targets rather than correcting it.
- MAIN Table 2 Model 6 intercept has no significance marker despite a very large z (F03). Transcribed as printed.
- S1 Table A3 lost its significance bullets in the text extraction. I read them from the PDF image at the available resolution. Cells where I am least sure of the bullet count: Model 1 Childcare × Female (read as two bullets), Model 1 GDP and Social status (one bullet each), Model 1 Fertility rate (two bullets), Model 2 2007 (one bullet). The coordinator may wish to verify these against a higher-resolution render.

## Source availability problems affecting implementation

1. **Social status of entrepreneurship, 2001-2002.** The harmonized ICPSR file and the original GEM 2001-2002 files contain no responses to the status item. The article uses this survey-level control for every survey-year, including 2001-2002 for Belgium, Canada, Denmark, Finland, Germany, Ireland, Italy, Japan, New Zealand, Poland, Sweden, the UK, the US and others. The article does not say how it obtained values for those years (perhaps an older GEM release carried them). Proposed fallback in documentation_assessment.json: impute from each country's earliest available survey year. **Question for the coordinator:** should the implementers use that imputation, drop the 2001-2002 surveys, or omit the control for those years?
2. **France 2003.** Listed in S1 Table A1 as part of the sample, but the harmonized file has no work-status or education responses for that country-year, so the employed-only and education filters cannot be applied. **Question:** retain France 2003 unfiltered, or drop it?
3. **Country-year list.** Several fielded country-years in the harmonized file (for example Canada 2004 and 2005, Italy 2004, Netherlands 2001) are absent from the article's list without a stated rule, while others absent from the list coincide with country-years lacking work-status or education responses (Australia 2001, France 2001, New Zealand 2002, Norway 2001 and 2007, Spain 2001). The origin follows the printed list; implementers should report how many surveys they can reproduce.
4. **Paid leave.** No annual FTE series exists in the registered sources. The CEPR 2008 reports cover 21 countries at one cross-section; ILO pages are incomplete (no 2011 page for Canada, France, Poland; no 2009 page for Portugal; empty 2009 templates for Czech Republic, Greece, Poland). A reconstructed series will differ from the author's. This variable is central to the H3 results (Models 5-7), so divergence here is the largest implementation risk.
5. **Childcare spending.** The article's 2012 Family Database measure (childcare services, children under five, published for 2005 and 2007, other years imputed) is not available; the registered PF3.1 series is a later vintage covering childcare plus pre-primary. This is the key H1 and H2 variable (Childcare × Female), so vintage differences matter.
6. **GDP index and women managers.** Printed only in HDR 2004-2009; the HDR 2010 cited by the article does not carry them. The article does not state the report-to-survey-year mapping.
7. **Unemployment** (Switzerland all years, Iceland 2001-2002) and **EPL** (no overall series; Iceland only from 2008) require the fallbacks listed in documentation_assessment.json.
8. **Vintage.** All non-GEM country-level files are October 2026 releases; the article used 2012-2013 releases. Revisions are expected for part-time rates, unemployment and SOCX/family-database spending.

## Interpretive choices I made and their basis

- The main-sample labour-force restriction is read as "employed" (full- or part-time) because footnote 2 and the S1 Model 2 note contrast the sample with "individuals who are not employed".
- "Established business owner" is read from the screening item (currently owns and manages), not the GEM 42-month transform, because the article defines it that way on p.11; the alternative is an axis in spec_space.json.
- "Over 18 and under 55" is read as 18-54 inclusive; 19-54 is an alternative level.
- New technology is coded from OMNEWT_5 codes 1 and 2 because the article says "less than five years old".
- Random-effects covariance is set to unstructured at the origin only because the AIC-implied parameter counts (forensic F06) fit six variance-covariance parameters; the article itself is silent.
- The manifest lists the 24 country names as a sample definition; it contains no published estimates, and all per-model Ns are confined to sealed_n_branch.

## Limitations of this reading

- I did not have access to raw data and computed nothing from data; all forensic arithmetic uses printed values only.
- I could not confirm which GEM release the author used; variable names in the manifest are those of the harmonized ICPSR file, which may differ from the author's working file.
- Bullet counts in S1 Table A3 were read from a rendered image and may contain errors for the cells listed above.
- Figures 1-7 were read only from axis labels and text descriptions; no values were extracted from plotted points.
