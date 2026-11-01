# Second adversarial review: Thébaud (2015)

2026-10-28. All computations here are post hoc diagnostics. No frozen file, supplied data, implementation, target, or score was changed. Paths below are relative to the study root unless linked. Implementer B was GPT-6 Astra/OpenAI, as `implementation/role_record.json` records. This is a separate review context, not a model family independent of every implementer; the frozen requirement for such independence and human confirmation remains unmet.

The first review’s numerical observations are substantially reproducible, but its four “pipeline errors” are not equally established. In particular, a better match to published means or standard errors does not establish an undocumented coding decision.

| Item | Classification | Confidence | Finding |
| --- | --- | --- | --- |
| F06, M4 female × part-time employment | (d) unresolved | Moderate | The discrepancy persists under the one-year origin and the proposed mixed-motive fix, but a documented two-year lag passes the frozen magnitude and inference criteria. Sample coverage remains grey. |
| F09, M6 female × leave and leave² | (d) unresolved | High that attribution remains unresolved | Reparameterization explains much of the SE difference, not the published curvature. The growth outcome and historical leave series are not recovered. |
| M6 female main effect | (d) unresolved | High that attribution remains unresolved | Neither the polynomial basis nor ordinary weighting of descriptives explains the gap. Raw gender odds do not prove that the published adjusted effect is impossible. |
| Claimed plan-B coding error | (d) unresolved | Moderate | Including mixed motives is plausible and descriptively better, but the article does not specify treatment of that response category. |
| Claimed leave² coding error | (d) unresolved | Moderate | An exact change of basis is established; the published basis is not. Its coefficient comparison requires a matching transformation. |
| Claimed per-model complete-case error | (d) unresolved | Moderate | Equal printed Ns suggest a shared sample, but do not identify its construction. The proposed common sample is not within the 5% match band. |
| Claimed leave-series error | (a) specific construction mismatch | High for the temporal mismatch; low for full recovery | Mechanical paid-duration ratios introduce changes outside the article’s policy-change list. Removing those changes is justified as a diagnostic; it does not recover all historical FTE levels. |

## F06: the survival claim needs qualification

Table 2 gives −.10 (.03), three bullets. Direct inspection of `runs/exec_v1/DEV_A_combined.csv` identifies an overlooked qualification: U18, the two-year lag, gives −.07334 (.03681), p = .04632. Distance from the published rounding interval is only .722 published SE; the inference band is adjacent to the published band. Both pass the frozen numerical criteria. N = 31,494 remains grey. MAIN p.12, footnote 8 explicitly discusses this lag, so it is not an invented numerical rescue, although it does not supersede the stated one-year origin.

I independently rebuilt samples with B’s functions and fitted the following mixed logits. All retain the same random-effects structure. U14 means separately standardized raw leave²; it cannot itself change the part-time interaction.

| Diagnostic M4 specification | N | Female × part-time, estimate (SE) | p |
| --- | ---: | ---: | ---: |
| Common sample, mixed motives included, U14 | 27,289 | −.02106 (.03179) | .508 |
| Same, alternative leave history | 27,333 | −.02459 (.03227) | .446 |
| Same original leave history, omit childcare and its interaction | 27,289 | −.02989 (.03149) | .342 |
| Common sample, original motivation coding, two-year lag, U14 | 27,263 | −.07819 (.03975) | .0492 |
| Same two-year lag, mixed motives included | 27,263 | −.03247 (.03242) | .317 |

The first review’s preferred coding therefore does not rescue F06. However, its assertion that no variant comes near −.10 overlooks U18, and the result depends on an unresolved motivation coding. I classify the overall adjudication as unresolved rather than endorse unconditional survival. None of these post hoc runs changes the frozen discrepancy-candidate score.

An independent comparison over all 24 published country rosters gives r = .99944 between reconstructed and printed part-time country means. That rejects a gross part-time input mismatch, not all possible confounding from other covariates or sample differences. Dropping childcare is a non-equivalent stress test, not a reconstruction of the unavailable childcare-only measure; its small effect cannot rule out measurement-error effects from the correct measure.

## F09 and the M6 female effect

The explicit operational definition is more than five additional employees (MAIN p.14, lines 757–759), and the source labels distinguish jobs now from jobs in five years. A’s `run.R:284–291` and B’s `run.R:73–75` implement the difference with missing-value guards. The extract contains 713,933 records; comparison against the supplied SAV finds no unexplained differences in country, year, gender, motivation, or either employee count. SPSS-declared missing codes become blanks. The construction note’s claim that all labelled codes were retained is inaccurate, but this conversion does not turn valid growth responses into missing values.

The origin growth share is .09633; the common sample gives .09953. Weighting that common sample by WEIGHT, WEIGHT_L, or WEIGHT_A gives .10660, .10794, or .10836, respectively, versus the published .17. These are weighted descriptive checks, not weighted mixed models. Unreported hierarchical weighting is not thereby exhaustively excluded.

The existing U14 fit has female −.81168 (.06204), female × leave −.02007 (.13833), and female × leave² .05282 (.13406). The corresponding published values are −.29 (.04), .31 (.14), and −.29 (.14). I independently verified the algebraic mapping from the origin coefficients: it reproduces these U14 coefficients to .00033 or better without refitting. Thus the near-matching SEs are not evidence that the substantive growth discrepancy has disappeared.

My independent common-sample U14 refit gives female −.79568 (.06330), female × leave .01762 (.14135), and female × leave² .02234 (.13685). The joint two-interaction Wald test gives χ² = .4474, p = .7995. Transforming the complete coefficient covariance verifies the same joint test and fixed linear predictors to numerical precision (maximum predictor difference 1.8 × 10⁻¹⁵).

With the alternative leave history, these three estimates are −.79483 (.06385), .03670 (.14086), and .02914 (.13604). This independently confirms that the first review’s four changes together do not explain either M6 gap; plan-B recoding changes no membership in the common sample.

As an explicitly invalid fault-injection check, I coded missing growth as 1. This moves female to −.37717 (.05315), but produces prevalence .22323 and N = 34,856; the leave interactions, .11914 (.10757) and −.04140 (.09331), still do not reproduce F09. This is not a proposed fix or evidence that the author made such an error. Our actual implementations preserve missing growth.

The first review’s raw gender log-odds argument is too strong: an unadjusted contrast does not bound a conditional main effect in an interacted multilevel logit. Existing M6 rows for U20, U24, U22 and N01 flag nonconvergence; they cannot count as successful robustness confirmations. Nor does reproducing M7 with the same leave series establish that its measurement errors are harmless in M6. The unresolved outcome prevalence, missing Czech leave, historical policy reconstruction, and undocumented estimation details prevent attributing either M6 result to the article or to a specific error in our pipeline.

## Are the four proposed fixes warranted by the text?

1. Plan B. MAIN p.14, lines 744–748 describes respondents reporting no better work choices, but does not state whether the mixed “work choice and opportunity” response counts. `manifest_neutral.md:65`, A `run.R:276`, and B `run.R:68` deliberately use code 2 alone. Code 3 includes the stated motivation, making U09 a defensible alternative, not a demonstrated correction. It moves prevalence from .17982 to .32294, close to .31; weights alone leave the code-2 share around .173–.174. This supports U09 but cannot identify the original coding from prose. If subsequently documented, the concrete change is code 1 for OMREASON in {2,3}, code 0 for {1,4,6}, preserving missing values. Both readers originally selected code 2 alone; the coordinator did not introduce a transcription error.

2. Leave². MAIN p.14, lines 731–733 says survey-level variables are standardized; p.12 introduces a square. The order is unstated. `manifest_neutral.md:95` and A `run.R:426` use z(L)²; B `run.R:122–129` implements both bases. For μ = mean(L), s = SD(L), m₂ = mean(L²), and s₂ = SD(L²),

$$
z(L^2)=\frac{s^2}{s_2}z(L)^2+\frac{2\mu s}{s_2}z(L)+\frac{\mu^2-m_2}{s_2}.
$$

With the intercept, female main effect, lower-order terms and interactions retained, this is an invertible transformation. Coefficients and their full covariance must be mapped together; fitted probabilities and a joint test of the two leave interactions are unchanged. Individual coefficient tests and the female main effect refer to different contrasts. U14’s better agreement with printed SEs is suggestive, not proof of the author’s basis. The appropriate fix to comparison practice is explicit basis metadata and transformation, not silently replacing one coefficient by another. Astra’s original `spec_space.json`, axis S12, already states this caveat.

3. Complete cases. `manifest_neutral.md:81–83`, A `run.R:473–476`, and B `run.R:158–163` intentionally delete missing values per outcome. The equal N = 28,775 for M4–M6 and Table A2’s single owner panel favor a common sample, but do not specify the intersection of planb, size and growth. That intersection gives 27,289, a 5.164% shortfall; the alternative leave series gives 27,333, a 5.011% shortfall. Both remain grey, not within 5%. It improves M5 coverage but actually worsens M6’s N match. A stronger contradiction limits extension to M8: the printed 2005–2008 shares sum to .58. Even their rounding upper bound, .60 × 28,775 = 17,265, is below M8’s 17,498. A single parent sample restricted by year cannot explain all these printed quantities, assuming the descriptives are unweighted. A documented shared-sample rule would justify intersecting the relevant outcomes before centering; the exact rule is presently unresolved.

4. Leave construction. `registry/construction/scripts/build_country_year.py:116–146`, especially line 142, multiplies CEPR’s 2008 FTE level by PF2.5 paid-duration ratios; lines 173–196 separately construct Iceland and Poland. The ratio method assumes a stable effective replacement rate despite changing duration and benefit composition. It is a disclosed proxy, not the article’s documented historical construction. More concretely, it produces temporal changes outside the eight-country list in MAIN p.12, footnote 7, and leaves early France empty. The specific diagnostic fix is to retain each non-listed country’s source-based 2008 level throughout the period, then apply the lag and rebuild samples and constants; the existing eight-country series is retained only as a provisional proxy. No printed outcome or country mean is used as input.

This fixes that temporal inconsistency, not the whole FTE measure. Constancy does not establish the 2008 anchor as the correct historical level, especially for pre-2001 lag years. The independent country-mean correlation rises from .823 to .907, but CZE stays missing and Poland remains 20 weeks against Table A1’s 39.1; France is 21.4 against 19.8, Portugal 23.8 against 15. The source itself disagrees internally on German leave. Historical rates, eligibility and the eight changing-country trajectories still require documentary resolution. Calling the complete proposed series “corrected” overstates what footnote 7 establishes.

## Evidence and limits

Scripts, CSVs, saved fits and logs are in [diagnostics](diagnostics/). `prepare.R` independently reconstructs B’s samples and descriptive checks; `raw_audit.py` compares the original SAV and extract and checks existing A/B results; `source_documents.py` checks local source documents and country means; `prepare_lag.R` and the refit drivers implement the new stress tests. Printed values enter comparison files only, never regressions. No downloading, login or contact was performed; all writes stayed within this audit directory.

Eight completed mixed-model fits converged; three M4 fits were singular, recorded separately. They used 16.5 CPU minutes; including one interrupted optimizer attempt, a conservative refitting bound is 32 CPU minutes, with at most two single-threaded numerical processes. [Validation](diagnostics/validation.csv), [reproduction notes](diagnostics/README.txt), and [final checks](diagnostics/final_checks.log) retain convergence, interruptions, script checks and verification against the registered data and frozen-file hashes.

Summary: no specific pipeline error has explained F06 or the M6 results. F06 is less robust than the first review claimed; F09 and the M6 female effect remain unresolved. Of the four alleged errors, the leave history has a concrete mismatch with the stated construction, while the other three remain plausible but incompletely documented alternatives. Frozen scores remain unchanged.
