# Synthetic test report

All required tests completed using `/opt/homebrew/bin/Rscript` (R 4.6.1) and the permitted installed packages. Inputs were only the supplied synthetic files, plus small in-memory edge cases derived from their schema. No raw data rows were printed. The synthetic generator parameters were used only to assess the fitted result, never by the production script.

## Executed analyses

| Test | Invocation / harness | Saved results |
|---|---|---|
| Full origin, M1–M8 and R1–R3 | `/opt/homebrew/bin/Rscript run.R synthetic test_origin ORIGIN` | `test_origin/` |
| Three deviations: U03 M3/R1, U09 M4, U25 M5 | `/opt/homebrew/bin/Rscript test_deviations.R` calls `run_analysis('synthetic','test_deviations','U03,U09,U25')` | `test_deviations/` |
| M3 influence, all 24 represented countries | `/opt/homebrew/bin/Rscript test_influence.R` calls `run_analysis(..., 'influence', influence_models='M3')` | `test_influence/` |
| N01 M3 with absent reference year | `/opt/homebrew/bin/Rscript test_rank.R` | `test_rank_results.csv` |
| U20 M5 correlated random effects | Run inside `verify_outputs.R` | `test_u20_m5_results.csv` |
| Injected M1 fit failure followed by a real M5 fit | `/opt/homebrew/bin/Rscript test_continuation.R` | `test_continuation/` (explicit test output, not a full origin run) |
| Recoding, samples, constants, bootstrap, failure edge case | `/opt/homebrew/bin/Rscript validate.R` | `validation_results.txt`, `validated_sample_counts.csv` |
| Saved schema, inference, hashes, influence, empty/constant inputs | `/opt/homebrew/bin/Rscript verify_outputs.R` | `output_verification.txt` |

The normal CLI `influence` still runs M3–M8. Only the test harness limits influence to M3, as allowed by the assignment's minimum test requirement. `all` and all six full influence-model sets were not fitted end to end; every listed branch's preparation and designated model samples were constructed and checked. The tests did not change production model definitions or optimizer settings.

## Runtime

Testing ran approximately 00:54:50–01:04:08 JST on 2026-10-28, about 9 minutes 18 seconds of wall time, below 25 minutes. Independent processes overlapped. The origin log creation to completed results spans at most 194 seconds. Timed harnesses recorded 80.028 seconds for the three deviations, 285.634 seconds for M3 influence, 7.280 seconds for N01 M3, and 0.443 seconds for the continuation test. These principal runtimes sum to about 9.5 minutes; the additional validation and U20 M5 checks took only a few seconds. Timing records and logs are retained.

## Sample verification

An independent implementation of the origin eligibility and complete-case rules matched the **exact respondent membership**, not just the counts, of all 11 models. The literal roster has 143 surveys in 24 countries. The source synthetic file has 26,400 respondents and 165 observed surveys, including surveys outside the origin roster. The origin M3 anchor represents 111 roster surveys and all 24 countries; missing roster coverage is preserved rather than filled.

| Model | Observations | Countries | Surveys |
|---|---:|---:|---:|
| M1 | 6,579 | 24 | 111 |
| M2 | 6,579 | 24 | 111 |
| M3 | 6,579 | 24 | 111 |
| M4 | 365 | 24 | 107 |
| M5 | 372 | 24 | 107 |
| M6 | 372 | 24 | 107 |
| M7 | 332 | 24 | 96 |
| M8 | 179 | 22 | 51 |
| R1 | 6,579 | 24 | 111 |
| R2 | 9,634 | 24 | 111 |
| R3 | 2,197 | 24 | 111 |

U03 M3 had 6,512 observations and U03 R1 had 6,506; the difference follows R1's additional nascent-outcome completeness rule. U09 M4 had 365 and U25 M5 had 372. Their result counts and hashes matched separately prepared model samples. M7/M8 restrictions, S2's outcome-specific completeness, R2's work-filter exception, and R3's additional screening items were checked.

`validate.R` passed 201 assertions, including:

- All origin sample memberships and within-model age/business-age centering.
- Every run's designated model sample construction; U01/U02/U05 sample expansion.
- Origin unique-survey means of zero and sample SDs of one, and squared standardized leave.
- U14 raw leave-square scaling; U15 country-mean SDs; U16 individual-row SDs; U17/U18 exact calendar-year lag joins.
- Screening code 100, codes 8/9, U03's literal SUWAGE exclusion including an empty value, size bounds and count sentinels, strict growth threshold, zero business age and the 1990 value.
- Status computed from all respondents, earliest-later-year carryback, U22's restricted contributors, and N01's disabled carryback.
- Each wild-bootstrap interaction's p-value against a separate 19-replicate implementation using direct `lm()` and `sandwich::vcovCL()` refits with identical Rademacher draws. Production output uses all 999 replicates.
- Constant-response mixed fitting records an actual failure.

The separate output verifier also passed: exact 26-column schema and term lists, native z/p arithmetic, counts and hashes, nonempty wild p-values only for the four M5 interactions, explicit U25 REML routine, correlated-effects SD extraction, fractional-age strict bounds, no-status empty samples, and zero-variance scaling without silent sample loss.

## Parameter recovery and diagnostics

The origin M3 `female:childcare` estimate was **−0.322694261**, with model-based SE **0.096695077**. Its generating value in `synthetic_truth.json` is **−0.25**. The discrepancy is **0.752 standard errors**, and the approximate 95% Wald interval is [−0.512, −0.133], which contains the generating value. This is an appropriate stochastic recovery check, not a demand for exact equality. The recovery assertion required the estimate to lie within one fitted SE of the generating value and passed.

All 11 origin fits returned estimates. M1 reported a convergence/identifiability warning and has `converged=FALSE`; the remaining ten have `converged=TRUE`. Six origin fits (M3, M4, M5, M6, M8 and R3) are singular. These diagnostics are retained in the CSV, and defaults were not retuned to eliminate warnings. The three required deviation runs returned all four fits, all converged; U03 M3, U09 M4 and U25 M5 were singular.

Origin M5's 999-replicate wild p-values were:

| Interaction | Wild p |
|---|---:|
| female:leave | 0.013013013 |
| female:leave_sq | 0.100100100 |
| female:childcare | 0.476476476 |
| female:parttime | 0.422422422 |

These benchmark p-values concern pooled OLS coefficients, not the mixed-model coefficients.

## Influence and failure handling

All 24 M3 country deletions returned estimates and converged; 19 were singular. Each deletion had 23 countries, and its observation count, survey count and sample hash matched the full origin M3 sample minus precisely that country. Saved scaling constants and M3 centering means matched origin exactly. For every deletion, a separate pooled refit on the frozen origin covariates reproduced all saved benchmark SEs within 1e−10. The female:childcare estimates ranged from **−0.370231169 to −0.285187970**.

The N01 fit confirmed that absent reference-year intercept and year comparisons are `not_estimable`, while the female:childcare effect remains estimable. The production script does not silently substitute another reference year.

An injected exception at M1 produced failed rows and a recorded explanation, then the same invocation completed the actual M5 fit. Empty M3 samples and constant childcare scaling were separately reported as `not_estimable` with correct sample counts. Each invocation also reports the manifest's unavailable sampling-weight capability in its clearly labeled sentinel row.

The saved tests establish implementation behavior on the supplied synthetic coverage. They do not guarantee convergence, identification, or parameter recovery on different real data; those outcomes are explicitly reported per fit.
