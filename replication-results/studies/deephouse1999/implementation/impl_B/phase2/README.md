# Offline R analysis

`analysis.R` implements `manifest.md` and the supplied `grid.json`. It reads only the supplied Parquet inputs and local JSON documentation. No downloads, package installation, or external services are used.

Run from this directory in the later frozen execution:

```sh
/opt/homebrew/bin/Rscript analysis.R
```

This runs both origins, every one-axis deviation, duplicate records, both algebraic checks at each origin, and all registered influence refits. Outputs go to `out/`. The script accepts `--grid=grid.json`, `--data=data`, and `--out=out`; command-line paths must stay inside this directory. The grid supplies parameters, model names/order, and configurations; the model formulas and axis implementations follow the manifest. Sourcing the script defines functions without executing the analysis.

**The real-data fitting stage has not been run in this implementation phase.** All fitted results under `tests/synthetic_out/` use generated observations. Real data were used only for construction validation under `tests/construction_out/`.

## Validation

```sh
/opt/homebrew/bin/Rscript --vanilla tests/test_analysis.R > tests/test_output.txt 2>&1
/opt/homebrew/bin/Rscript --vanilla tests/validate_construction.R > tests/construction_output.txt 2>&1
```

The first command tests direct-matrix WLS coefficients, standard errors, weighted SSE, all four nested F tests, Student t probabilities, condition indices, strategic deviation on a hand-made market, calendar lags across gaps and entries, exact sample hash bytes, and invariance to weight scaling. It additionally tests full covariance back-transformation, HC1, CR1, the AR(1) transformation, externally studentized residuals against deletion refits, missing-item rules, quarter coverage, duplicate selection, merger/continuation lags, outlier timing, leap-year weighting, and stock timing. Finally it runs the entire grid and all influence deletions on synthetic inputs and validates output coverage and statuses. `tests/synthetic_fixture.R` constructs those inputs; `tests/test_construction_edges.R` contains the targeted construction tests.

The second command constructs every distinct real-data specification with `construct_only=TRUE` and replaces `fit_model()` with a function that errors if called. It does not run preliminary outlier fits, algebraic model checks, or influence fits. A direct command-line construction pass is also available:

```sh
/opt/homebrew/bin/Rscript analysis.R --construct-only --out=tests/construction_out
```

Construction-only outputs omit fitted results, F tests, influence, and algebraic-check results; they include origin samples, descriptives, logs, environment, and construction statuses. `R10.max_rstudent` is explicitly marked as awaiting model-dependent deletion in this mode. Duplicate configurations are skipped in construction-only status summaries; the full execution records them in `spec_results.csv`.

## Structure and manifest coverage

| Manifest item | Implementation |
|---|---|
| Section 1, inputs | `load_inputs()` reads the seven manifest Parquet tables and, when present, the optional county crosswalk with `nanoparquet::read_parquet`, adds calendar identifiers and parses date formats; the local candidate JSON supplies the component inventory. |
| S1, records | `filter_records()` applies the active charter/entity/reporting rule, prioritizes reporting level 1 over 2, and logs discarded duplicate bank-quarter records. Remaining exact-priority ties preserve input order. |
| S2, market | Q4 geography is applied by bank and year; positive **RCFD2170** defines the market population as specified. Bank-years without Q4 are logged. 1984–1992 are constructed, with 1983Q4 available for asset endpoints. |
| S3, annual quantities | `construct_annual()` computes quarterly-average assets, Q4 YTD income and expenses, eleven asset categories/shares, deposits, opening dates, and alternative FDIC ROA. Variables for nonmarket banks are retained internally only to support predecessor calculations. |
| S4, benchmarks | `benchmarks()` constructs available-case category means/SDs, mean ROA, separate share and growth deposit totals, and the selected price series. Reference exclusions and zero SDs are logged. |
| S5, derived variables | Strategic deviation is the sum of eleven absolute z-scores; SD2 is its raw square. Relative ROA and real deposit growth are in percentage points/percent, with MS and TER in proportions. Calendar-year matching prevents gap-skipping. |
| S6, sample | `select_sample()` applies 1985–1992, continuity/opening requirements, finite-variable and positive-share restrictions, then outlier deletion. Ordinary specifications share the same rows across all four models. |
| Section 3, models | `make_design()`, `qr_estimate()`, and `fit_model()` implement M1, M2, M3, M3_SQ with the specified term order, intercept, weights, fixed effects, and covariance. Every fit reports N, bank count, K, residual df, SSE, condition index, coefficient, SE, t and two-sided Student p. |
| Section 3, comparisons | `nested_f()` calculates M2 vs M1, M3 vs M1, M3 vs M2, and M3_SQ vs M1 from weighted SSE, parameter-count differences and unrestricted residual df. |
| Section 4, grid | `make_specs()` generates origins, O_A deviations, O_B deviations, and then the checks. Identical-origin levels produce duplicate statuses. A construction cache avoids rebuilding samples when only fitting choices change. |
| Section 4, checks | R24 checks coefficients/SEs, expected SSE scaling, and sample identity; R26 back-transforms coefficients and the entire covariance matrix and checks agreement with raw fits. Tolerance is `all.equal(..., tolerance=1e-7)`; a failed check has failed status. |
| Section 5, influence | `run_influence()` refits M2 and M3 at each origin for every individual row deletion and every bank deletion, without rebuilding variables, benchmarks or lags. Each requested target term is recorded, including failures and error messages. |
| Section 6, outputs | The full run writes all required paths and exact required column names, as listed below. This README documents implementation and limits. |

## Grid implementation details

| Axis | Implemented levels and conventions |
|---|---|
| R01 | Fixed 1983 county list, reported RSSD MSA, Minnesota-only list, and latest supplied vintage no later than year end. `omb_definition_date` is the date field; `definition_vintage` contains prose. Dynamic geography uses available vintages only. |
| R02 | Charter plus entity, charter alone, entity alone, and origin filter plus savings banks, always requiring CALL8786 in {1,2}. The special-bank exclusion is unavailable; see below. |
| R03 | Same-RSSD calendar lags; exclusion of merger-survivor year and following year; uniquely identified same-CERT legal continuation; and pro-forma predecessor NI/AA aggregation. Merger matching accepts the supplied spelling “Absorbtion”, deduplicates institution links, and excludes branch-only transactions. Pro-forma includes the survivor's prior business and recursively absorbed predecessors in the event year. Missing/ambiguous predecessor inputs yield a missing lag with a logged reason, never a substitute. |
| R04 | Existing-lag eligibility; opening before January 1 of t−1; and first-calendar-year annualization. FDIC establishment dates take priority, with first Call appearance as the specified fallback. Months in operation include the opening month (`13 - opening month`); no daily proration. |
| R05 | At least two available quarterly averages, with RCON fallback per quarter and asset-endpoint fallback **only when zero averages are available**; all four; or any one. One available average fails the min-two rule. |
| R06 | Arithmetic and calendar-day weighted quarterly averages; all-five and both-two asset endpoints; and FDIC ROA divided by 100. Endpoint alternatives override RC-K coverage; day weighting applies R05 coverage. FDIC ROA leaves the origin's average-assets expense denominator intact. |
| R07 | Q4 RIAD4340 or RIAD4300, never a sum of YTD quarterly income. |
| R08 | Q4 shares/deposits; means of available quarterly shares and deposit amounts; ratios of quarterly mean amounts to mean assets. Ratio-of-means deposits are also quarterly mean amounts. Quarterly means are available-case by concept. |
| R09 | All market banks; one analytic-sample recomputation; joint complete reference; and AA-weighted mean ROA with other benchmarks unchanged. Analytic recomputation fixes initial final-sample rows; **1984 retains its initial all-market reference as lag/growth support**, because it has no estimation rows. No convergence iteration or additional attrition is performed. If recomputation makes fixed-row regressors nonfinite, fitting fails explicitly. |
| R10 | Named row deletion after construction; external-studentized maximum; named deletion plus lag suppression; deletion before benchmarks; or none. Initial maximum-residual selection uses undeleted M1/M2/M3. If maxima differ, each uses its own deletion; M3_SQ follows M3. This is the grid's explicit exception to the shared-sample rule. Cross-sample F comparisons are NA and the result message explains why. Ties select the first row in RSSD/year order. |
| R11 | 1766 or 1600, with corresponding subtraction in the other-loan residual. |
| R12 | Production agriculture alone, or farmland added to agriculture and removed from real estate. |
| R13 | Gross residual; explicit non-overlapping components 2165, 1505, 1517, 1510, 1545, 2107, 2081, 2080; net of unearned income; or net of unearned income and allowance. The list uses total foreign-bank loans (1510), not its subcomponent 1516, and “all other loans” (2080). The supplied inventory is under `docs/`, despite the grid's obsolete `sources/` path. |
| R14 | Broad five-component sum, literal 2160, or residual after the other ten categories. |
| R15 | Zero only where the quarter-presence table says uncollected/all missing; preserve provider missingness; or fill missing totals using complete documented component identities. Identities implemented: 0010=0081+0071, 1600=1755+1766 after 1984Q1, 1766=1763+1764, 1350=0276+0277, 1975=2008+2011, 2165=2182+2183. Inputs are not recursively imputed. Total assets, average assets, deposits and income/expense flows are not zero-imputed. A bank's missing share remains missing even if the reference SD is zero. |
| R16 | Consolidated RCFD or same-code domestic RCON stocks and averages; RIAD unchanged. Deposit scope is independently selected by R18. The explicit RCON1420 farmland item remains RCON. Market admission still uses the manifest's RCFD2170 test. |
| R17 | Sample SD (n−1), population SD (n), or zero-SD-to-missing. Otherwise a zero-variation observed category contributes zero. Unobserved/undefined SD remains missing. |
| R18 | Domestic or consolidated deposit amounts, independently of R16; timing follows R08. |
| R19 | Commercial-reference deposit denominator or all-insured FDIC DEP. FDIC STCNTY contains county **names** in the supplied financials, so it is resolved using state abbreviation and the optional county crosswalk; five-digit codes are accepted without that crosswalk. If names need mapping and the crosswalk is absent, only the affected all-insured specifications are unavailable. No present-day institution location is substituted. |
| R20 | FRED annual-average national CPI, December national CPI, annual local CPI, current annual GDP deflator, or mean of all four GDPDEF quarters from ALFRED 1999-01-01. Provider/source/vintage filters prevent mixing duplicate series. |
| R21 | Commercial-reference or all-insured deposits for growth, independently of the share denominator. |
| R22 | Pooled, year indicators, or bank indicators, with intercept and first sorted level omitted. Year effects explicitly drop RMG and report that omission. Other rank deficiencies fail rather than silently dropping terms. |
| R23 | Conventional WLS, HC1 on the weighted regression, and bank CR1 with exactly G/(G−1) × (N−1)/(N−K). All coefficient p-values use Student t with N−K as required; SSE-based F tests remain unchanged. |
| R24 | Raw MS or MS divided by its estimation-sample mean. Coefficients and SEs invariant, SSE scales. |
| R25 | WLS, unit-weight OLS, or two-step feasible Prais–Winsten after sqrt(w) transformation. Estimate rho once by no-intercept regression of preliminary weighted residuals on consecutive within-bank residuals; clip to [−0.999,0.999], logging both values. At bank entries and calendar gaps restart with sqrt(1−rho²). The transformed regression determines covariance and condition index; reported SSE_w is always the manifest's sum of original w×e². F values use that reported SSE, including for AR(1); they are the registered arithmetic comparisons, not a separately derived GLS likelihood test. |
| R26 | Centered SD/SD² with full linear covariance back-transformation. For M3_SQ, freely replacing SD² with (SD−c)² would change the model: the centered representation enforces the original zero raw-linear-coefficient restriction through z²+2cz = SD²−c². The message identifies this restriction; the original coefficients and SEs are recovered. |

The R09 lag-support convention, M3_SQ outlier inheritance, annualization month convention, and two-step AR(1) details resolve aspects not fully specified in the grid and are explicit above. No expected empirical result was used to choose them.

## Output files

The full execution writes:

- `out/spec_results.csv`: the required spec/model/term schema, including status, fit diagnostics and sample hash. Failed/unavailable/duplicate models retain term rows with NA estimates and explanatory messages. Fixed-effect coefficients are included for successful fits.
- `out/f_tests.csv`: four rows per spec with the required schema. Values are NA for absent fits, duplicates, unavailable configurations, or incompatible model samples; detailed status/reasons reside in `spec_results.csv`.
- `out/samples/O_A.csv` and `out/samples/O_B.csv`: exactly the eleven specified sample columns.
- `out/descriptives_O_A.csv` and `out/descriptives_O_B.csv`: long format `statistic, variable, variable2, value`. Rows contain unweighted mean, sample SD, and all 49 Pearson correlation cells. `variable2` is NA for moments.
- `out/construction_log_O_A.json` and `out/construction_log_O_B.json`: year/step/reason counts and special handling. S6 attrition reasons are sequential and disjoint; missing-variable diagnostics in S3/S5 overlap intentionally. S4 records benchmark statistics and reference population counts. Special records include duplicates, zero fills, identity fills, asset fallbacks and opening-date fallback.
- `out/influence.csv`: the specified schema for all row/bank deletions and target terms, including every failed refit.
- `out/environment.txt`: R, base/stats and used package versions plus session information.

Two extra audit outputs are `out/construction_status.csv` (construction status by evaluated spec) and `out/algebraic_checks.json` (per-model comparison flags). Construction logs are required for origins; deviations receive status rows, while row-level construction diagnostics are held with their cached construction internally.

`sample_hash` is SHA-256 of the UTF-8/ASCII text obtained by lexically sorting the complete `RSSD9001,year` lines, formatting both fields as integers without spaces, and terminating **every** line with LF, including the last. There is no header and no R serialization. The empty sample hashes the empty byte string. Sorting is lexical because the manifest specifies sorted lines, not numeric sorting of the two columns.

## Unavailable item and execution limits

**R02.no_special, at both origins, is unavailable.** The supplied dictionary describes RSSD9425 as the bank-type analysis code but does not give the actual values identifying bankers' banks, credit-card banks and trust-only banks. Neither candidate JSON nor source descriptions supplies that mapping. The code records `unavailable` with this reason rather than guessing or using another field.

All other levels have executable implementations. Data-dependent missing inputs are handled by the registered missingness/sample rules and logged, including absent or ambiguous merger predecessors. No real-data coefficient estimates, fit success claims, F results, influence results, or empirical algebraic-check outcomes are asserted in this phase; those are deferred to the full frozen execution.

## Checker items

1. **Fixed — Section 1 inputs.** `load_inputs()` now requires only the seven manifest Parquet files. It reads `county_fips_mn_wi.parquet` only when present. Without it, ordinary specifications still construct; R19/R21 all-insured levels report `unavailable` only when FDIC county names require that mapping. Numeric county codes still work without it. Synthetic tests exercise the actual loader with exactly seven Parquet inputs and verify both origins and the affected levels.
2. **Fixed — R02.add_savings.** Savings admission expands the allowed charter codes to 200 and 300 while preserving the origin's other predicates. At O_A, savings banks must still have RSSD9331 == 1; at both origins, CALL8786 must be 1 or 2. Synthetic cases cover accepted, rejected, and missing entity codes at both origins.
3. **Fixed — R16.domestic / deposits.** R18 alone selects RCON2200 versus RCFD2200, and R08 controls deposit timing. R16 changes asset scope without overriding deposits. Synthetic tests use unequal domestic and consolidated deposits across all three timing levels, including the O_B domestic-asset deviation.
4. **No change — R26.centered / M3_SQ.** The grid explicitly requires the back-transformed fit to reproduce raw coefficients, and M3_SQ explicitly omits the raw first-order term. With c = mean(SD) and z = SD − c, a raw squared-only term expands as b(SD²) = b z² + 2cb z + bc². Thus the centered linear coefficient must be constrained to 2c times the quadratic coefficient. The existing regressor z² + 2cz = SD² − c² implements exactly that restriction; its intercept and full covariance back-transformation recover the raw fit. Using z² alone instead imposes a raw linear coefficient of −2cb and generally changes fitted values, SSE, and coefficients, violating the grid's required algebraic equivalence. This is a specification conflict, not a missing-data issue. The existing representation is retained to satisfy that explicit equivalence requirement. Synthetic tests verify the constrained centered polynomial, raw coefficient/covariance recovery, and the failure of pure z² to preserve the raw fit.
