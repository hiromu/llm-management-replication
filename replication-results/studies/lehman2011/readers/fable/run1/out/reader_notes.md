# Reader notes (Reader A, independent reading of packet v1)

Documents read: D01 (main article, 19 PDF pages; page 19 is a database copyright notice). No supplements are included in the packet (publication_packet.json: `supplements_included` empty; supplement search recorded as not found after documented search). All table numbers were read from the PDF page images because the pdftotext extraction drops decimal points and renders parentheses as digits in Tables 1 to 6.

## 1. Contradictions and inconsistencies within the publication

1. **Delta LR chi-square values do not match the printed log-likelihoods.** Twice the log-likelihood improvement from Model 1 to Model 2 is about 709, but the printed delta LR chi-square is 168.87; from Model 2 to Model 3 the implied value is about 527, but 544.05 is printed (D01 PDF page 11, Table 5; forensics F10, F11). The LL and LR chi-square rows are themselves coherent with a common null log-likelihood (F9), so the delta rows are the odd ones out.
2. **The same statistic is reported for two different tests.** The text gives chi-square = 168.87 both for the LR improvement of Model 2 over Model 1 and for the test that the below- and above-aspiration terms differ (D01 PDF page 10, right column; F12).
3. **Table 4 quarter-2 above-aspiration N.** The printed 2,231 is 100 short of both the column total (7,714) and the Table 3 quarter-2 total (6,532); the weighted means of Table 4 and the Table 1 spline means are consistent only with 2,331 (D01 PDF pages 10 and 11; F4, F6, F7). I have recorded the printed value and not corrected it.
4. **Same-division and same-conference descriptives.** Table 1 gives means of 0.75 for 'Same division' and 0.42 for 'Same conference' with a correlation of 0.19 (D01 PDF page 10). These cannot arise from the natural nested definitions under either labelling, and the magnitudes suggest the two row labels may be swapped (F20). Whether the Table 5 rows are also swapped cannot be determined. The manifest uses natural definitions and records the ambiguity; spec_space axis A4 covers the nested-versus-exclusive coding.
5. **H3 support is described inconsistently.** PDF page 13 says 'Hypothesis 3 is thus also supported' and, a few sentences later, 'weak support for Hypothesis 3'; the abstract (PDF page 1) says the hypotheses were supported, whereas H1B is reported as not supported on PDF page 12. Recorded as `partial` for C4 and `no` for C2 in the claim map.
6. **'32 teams' across six seasons.** The paper repeatedly refers to the 32 teams (PDF pages 1, 3, 9, 13), but the printed game count (1,520) equals the full schedule only if the first two seasons had 31 teams, which matches the data description (expansion franchise from 2002; F19). This affects the number of fixed-effect groups per season, not the sample rule.
7. **Order of exclusions.** The number of plays removed for the last two minutes (1,362) equals the whole gap between the original and final counts, so the overtime exclusion removed nothing from the stated original set (F18). The paper does not explain this; implementers should report counts at each step.
8. **Marginal effects not reproducible from the printed coefficients under simple conventions.** A derivative-times-p(1-p) reconstruction of the Table 6 'All quarters' row from Table 5 Model 2 does not reproduce the relative magnitudes across evaluation points (F21). The computation conventions are not published, so this is recorded as cannot-assess rather than as an inconsistency.

## 2. Missing appendices, supplements and redaction gaps

- The only appendix is a reprint of the basic rules of American football from Romer (2006) (D01 PDF pages 15 to 16). It contains no data, code, or additional results.
- Endnote 4 (PDF page 16) says additional robustness analyses (alternative aspiration level; separate conversion-versus-kick and conversion-versus-punt models within and outside field-goal range) are 'available by request from the authors'. They are not in the packet and no supplement exists; the field-goal-range threshold and the alternative aspiration are undefined. Recorded as robustness claim C12 with no targets.
- The quarters-remaining robustness check (PDF page 9) is reported without numbers (C11).
- Known packet gaps (publication_packet.json): the live publisher supplemental-material tab could not be checked, and a different 18-page copy on a university server was excluded. Nothing in the article refers to an online appendix or e-companion.
- No redactions were recorded for D01, and I found no author code, code links, or embedded datasets in the article.

## 3. Data or code embedded in the publication

None. The article contains descriptive tables (Tables 1 to 4), regression and marginal-effect tables (Tables 5 and 6), and figures; no play-level data, no code, and no URLs other than general references (nfl.com and news articles in the reference list). These printed tables are sealed targets or diagnostics only and must not be used as empirical inputs.

## 4. Questions for the coordinator

1. The manifest needs seasons (2000 to 2005), the two-minute cutoff, the 60-minute game length and the marginal-effect evaluation grid to be executable. I treated these as design parameters rather than published estimates or counts. If the coordinator considers any of them target-identifying, please advise and I will move them to the sealed branch.
2. The schedules file provides `div_game` but no conference field; the manifest instructs the implementer to derive conference membership from league alignment by season. If the coordinator prefers a prepared membership table to be supplied as a source file, that would reduce implementer discretion.
3. No action is required on the by-request robustness analyses unless the coordinator wishes to attempt to obtain them; they are not needed for the focal claims.

## 5. Limitations of this reading and of the planned replication

- **Provider and vintage.** The authors do not name their play-by-play source. The public nflverse parse may classify penalty-nullified plays, fakes, aborted plays and kneel-downs differently from the authors' source, so exact sample counts are unlikely to match (spec_space A1).
- **Coverage gap.** Two 2000 regular-season games have no play-by-play rows in the public source, so the replication sample will be smaller than the published one by those games' fourth-down plays.
- **Estimator reading.** The paper names Stata's panel logit command and 'fixed-effect estimations' for teams and years. The degrees of freedom in Table 5 support a conditional logit grouped by team with season dummies (F13, F14). This is an inference, labelled as such in the manifest, with alternatives in spec_space A5.
- **Marginal effects.** Table 6 depends on conventions that are not stated (derivative versus discrete change, treatment of the unestimated team effect, covariate values, standard-error method). The implementer should expect larger discrepancies in Table 6 than in Table 5 and should document the conventions used (spec_space A7).
- **Significance key and tails.** No exact p-values are printed, several standard errors round to zero, and the paper does not state whether tests are one- or two-tailed. Forensic z-checks assumed two-tailed tests.
- **Team abbreviation mapping.** Play-by-play team columns use current franchise codes while game identifiers and the schedules file use historical codes; the manifest flags the need to map them before any team comparison.
- **No fitting or raw-data access** was performed for this reading; all forensic calculations use printed values only and are sealed with the targets.
