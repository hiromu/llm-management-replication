# Offline bank-panel analysis

`analysis.py` implements the supplied manifest and grid using only local Parquet inputs and installed Python packages. The default invocation runs both origins, every one-axis deviation, both algebraic checks, and all registered influence deletions:

```sh
~/.venv/bin/python analysis.py
```

The implementation phase **did not fit models on the supplied real data**. Model fitting, residual-based outlier selection, and the complete output pipeline were exercised on synthetic data only. The real data were used to validate sample construction. There is no network code or package installation.

To reproduce the tests and their saved output:

```sh
~/.venv/bin/python -m unittest discover -s tests -v > tests/test_output.txt 2>&1
```

To validate construction without any model fitting:

```sh
~/.venv/bin/python analysis.py --construct-only --out out/construction_validation > construction_validation.txt 2>&1
```

Run commands from this directory. `--grid`, `--data-dir`, and `--out` accept alternative paths **inside this directory only**. Defaults are `grid.json`, `data`, and `out`. `--construct-only` evaluates all construction variants but defers the residual-based outlier choice; it does not write model results, F tests, or influence fits. A synthetic test replaces the estimator with a function that would raise an error and verifies that construction-only execution never calls it.

## Structure

Everything needed for execution is in one importable script. Importing it performs no input loading or estimation.

- `Inputs` reads the eight supplied Parquet tables and the local candidate-item JSON. The extra county table resolves the names actually stored in FDIC `STCNTY`.
- `Constructor` implements S1–S6, caches samples for configurations that differ only in model options, and records construction decisions. Annual variables are calculated for filtered banks before selecting the market, so identifiable out-of-market merger predecessors can supply income and assets.
- `sample_hash`, `calendar_lag`, and `strategic_deviation` are independently testable construction functions.
- `fit_matrix` solves weighted regressions using a column-scaled SVD, then computes conventional, HC1, or bank-cluster CR1 covariance. `make_design` handles model terms, fixed effects, and polynomial transformations. Rank-deficient designs and insufficient residual degrees of freedom are reported as failures rather than fitted using an arbitrary generalized inverse.
- `specifications` follows the grid order. `run` writes all outputs and retains duplicate, unavailable, and failed specifications. `influence_diagnostics` refits every registered deletion without rebuilding variables, lags, or benchmarks.

## Manifest coverage

| Manifest item | Implementation |
| --- | --- |
| Section 1, inputs | Local Parquet loading; quarter and provider-date parsing; exact CERT matching; candidate concepts from `docs/call_item_candidates.json`. No CSV input substitution. |
| S1 | R02 record filters, then one record per RSSD/quarter, preferring CALL8786 1 to 2. Stable file order breaks ties within the same reporting level. Duplicate records are logged. |
| S2 | Year-specific Q4 membership and positive Q4 RCFD2170; 1984–1992 market populations. 1983Q4 supplies asset-average endpoints. |
| S3 | Annual average assets, Q4 year-to-date income and expenses, ROA, TER, all eleven asset categories, stock-timing variants, and deposits. No summation of quarterly income. Missing component inputs propagate except under an explicit R15 rule. |
| S4 | Available-case category means and SDs, ROA benchmarks, reference-population variants, deposit totals, and all five deflators. Benchmarks precede regression attrition unless a level explicitly changes this. |
| S5 | Sum of eleven absolute z-scores, raw SD squared, percentage-point relative ROA, exact calendar lags, deposit market shares, and percentage real deposit growth. |
| S6 | Estimation years 1985–1992; finite required variables; positive MS; entry and merger restrictions; outlier handling last except for the explicit pre-benchmark variant. |
| Section 3, models | Ordered terms for M1, M2, M3, and M3_SQ, including an intercept. N, number of banks, K, residual df, weighted SSE, coefficients, SEs, t statistics, Student-t two-sided p values, and largest Belsley condition index. |
| Section 3, nested tests | Four specified SSE-based F comparisons, using identical rows; conventional SSE tests remain in place for robust covariance variants. Incompatible model-specific outlier samples are reported as unavailable comparisons, described below. |
| Section 4 | Both origins, all one-axis levels, explicit duplicate records, checks after deviations, then influence diagnostics. Algebraic checks compare raw-basis coefficients, SEs, sample hashes, and expected SSE scaling against the origin. |
| Section 5 | Every leave-one-bank-year-out and leave-one-bank-out refit for M2 and M3 at both origins. Every attempted fit is retained, including failures. |
| Section 6 | All requested runtime output files and this README; exact column order for the three specified results tables. |

## Grid coverage and conventions

| Axis | Implemented levels and details |
| --- | --- |
| R01 | Fixed 1983 counties, RSSD9180 MSA code, Minnesota-only counties, and the latest available delineation on or before year-end. The date is read from `omb_definition_date`, because `definition_vintage` contains a descriptive label. |
| R02 | Charter plus entity, charter only, entity only, and additional savings-bank admission. The savings-bank admission overrides the commercial entity restriction for charter 300. `no_special` is unavailable because the dictionary omits its numeric code mapping. |
| R03 | As reported; remove acquirer/survivor event year and following year; event-confirmed same-CERT legal continuity; pro forma merger lags from predecessor income and assets. Institution-level merger/absorption/consolidation descriptions are used, including the source spelling “Absorbtion”; branch-only events are excluded. |
| R04 | Lag only; opening before January 1 of the prior year; annualized first-year NI and expenses. Opening date uses FDIC ESTYMD, otherwise the date of the first available Call report. Months in operation include the opening calendar month, giving `12 / (13 - opening_month)` in the opening year. |
| R05 | At least two quarterly averages with RCON fallback, and endpoint fallback **only if zero** quarterly averages exist; all four; or any available quarter. A single quarterly average does not trigger endpoint fallback. |
| R06 | Arithmetic RC-K mean, calendar-day weighted RC-K mean with R05 coverage, complete five-point assets, complete two-point assets, and FDIC Q4 ROA divided by 100. FDIC ROA leaves the origin's RC-K expense denominator in place. |
| R07 | Q4 RIAD4340 or RIAD4300. |
| R08 | Q4 stocks; mean of available quarterly shares with mean deposits; ratio of quarterly mean amounts to mean assets, also with mean deposits. Ratio-of-means uses available cases separately for each amount and the denominator, as specified. Quarterly shares require positive assets. |
| R09 | All-market available cases, one-pass analytic reference, common complete cases, and AA-weighted ROA. For the analytic reference, the final pilot rows for 1985–1992 are frozen; the presample 1984 all-market benchmark is retained to initialize 1985 lags and growth. See the explicit convention below. |
| R10 | Named deletion; maximum absolute externally studentized residual; named deletion plus 1988 lag suppression; deletion before benchmarks; no deletion. Ordinary named deletion leaves the observation available in benchmarks and as a lag. |
| R11 | Commercial loans 1766 or 1600, including the corresponding residual subtraction. |
| R12 | Agricultural production only or production plus RCON1420 farmland, with the same farmland amount removed from real estate. |
| R13 | Gross residual; explicit components; residual net of unearned income; residual net of unearned income and allowance. The component sum uses 2165, 1505, 1517, 1510, 1545, 2107, 2081, and 2080, each in the active stock scope. Nested subcomponents 1516, 1563, 2182, and 2183 are not double counted. 1520 is documented as a pre-1984 item. |
| R14 | Broad sum 2150 + 2130 + 2155 + 2143 + 2160; literal 2160; or total assets less the other ten categories. |
| R15 | Missing remains missing; zero only if the supplied presence table explicitly establishes noncollection; or complete-component identity filling. Supported documented identities are 0010 = 0081 + 0071, 1766 = 1763 + 1764, 1600 = 1755 + 1766, 1975 = 2008 + 2011, 1400 = 2122 + 2123, and 2165 = 2182 + 2183, within the same mnemonic, from 1984 onward (the 1600 identity applies strictly after 1984Q1, as its concept notes specify). Reported totals are never replaced. Missing presence metadata does not authorize zero filling. |
| R16 | RCFD or same-code RCON for asset denominators, RC-K averages, and category items. Explicit RCON1420 and the separate R18 deposit item remain as specified. RCFD2170 still determines S2 membership, as required there. |
| R17 | Sample SD, population SD, and zero-SD-means-missing. Otherwise a zero-SD category contributes exactly zero. Undefined SDs, including a singleton with sample SD, remain missing. Missing nonconstant-category target shares make the sum missing. |
| R18 | Domestic or consolidated deposits, independently of the asset-category scope. |
| R19 | Reference-population Call deposits or all-insured FDIC Q4 DEP as the share denominator; bank numerator remains the R18/R08 quantity. |
| R20 | FRED annual CPIAUCNS, December CPIAUCNS, annual CUUSA211SA0, annual A191RD3A086NBEA, and four-quarter annual means of ALFRED GDPDEF vintage 1999-01-01. Source, series, vintage, and frequency are selected explicitly. No current/historical vintage splicing. |
| R21 | Reference-population Call deposits or all-insured FDIC deposits for growth, independently of the share denominator. |
| R22 | None, year indicators with RMG explicitly removed and reported, or bank indicators. The first sorted category is omitted. All included indicators count in K. |
| R23 | Conventional covariance, HC1 of the weighted regression, and CR1 bank-cluster covariance with `G/(G-1) * (N-1)/(N-K)`. All term p values use Student t with N-K df, as the manifest prescribes. |
| R24 | Raw weights or weights divided by their sample mean, with an explicit coefficient/SE/SSE invariance check. |
| R25 | WLS, unweighted OLS, and two-step feasible Prais–Winsten on the square-root-weighted panel. See below for the AR(1) convention. |
| R26 | Raw and centered polynomial coordinates, with the full covariance back-transformed by the linear Jacobian. The square-only model retains its raw linear-coefficient-zero constraint rather than changing its fitted space. |

The following details resolve places where the grid does not fully specify an algorithm:

- **Analytic-reference initialization:** 1984 is explicitly a presample year and has no final estimation rows. Replacing its population with the empty regression sample would destroy every fixed 1985 row's lag and growth. The implementation retains the pilot 1984 benchmarks, recomputes 1985–1992 benchmarks on the fixed pilot regression rows, and rebuilds all variables once. It does not perform iterative fixed-point sample selection. This initialization convention is recorded in the construction log. If the rebuild makes any fixed row undefined, the specification is marked unavailable rather than silently changing its rows.
- **Residual outliers and F tests:** the grid explicitly permits different deletion rows for different models, while the general manifest requires common rows for nested tests. If M1/M2/M3 agree, all four models delete that row. Otherwise every model, including M3_SQ, deletes its own maximum absolute external residual. Ties use the first numerically sorted RSSD/year. Model-specific sample hashes make this visible. A comparison whose samples differ has blank numerical F-test fields and an explanation in the origin's construction log; it is not calculated from incompatible SSEs. No extra selection or common-row refits are invented.
- **Square-only centering:** if `c = mean(SD)` and `z = SD - c`, the square-only design uses `z² + 2cz = SD² - c²`. This preserves the required omission of the raw linear term. Its intercept transforms as `b0_raw = b0_centered - c²*b2`. In the full quadratic, the usual transformations are `b1_raw = b1_centered - 2c*b2` and `b0_raw = b0_centered - c*b1_centered + c²*b2`.
- **AR(1):** first fit ordinary WLS; regress its square-root-weighted residuals on the immediately preceding residual within the same bank without an intercept; pool those consecutive pairs to estimate one rho; clip rho into `[-1+1e-8, 1-1e-8]`; apply one Prais–Winsten fit. Every entry or gap starts a new spell and gets the initial factor `sqrt(1-rho²)`. The covariance uses innovation SSE and N-K df, conditioning on estimated rho. The reported `sse_w` remains the manifest's original `sum(w*e²)` and the condition index describes the actual transformed design. SSE-based comparisons are reported as prescribed; with separately estimated rho they need not have the usual exact nested-F interpretation. Rho and clipping are reported in result messages.
- **Merger information:** continuity requires a qualifying event, an unchanged CERT, a unique previous RSSD in the previous year's market, and no own prior annual record. Pro forma construction includes the survivor's predecessor and all identified outgoing CERTs, closes within-year merger chains, and uses the preceding market ROA benchmark. It does not use FDIC income as a substitute for missing Call income. Unidentified, missing, or ambiguous predecessor information makes that bank-year's pro forma lag missing and is logged; ordinary sample attrition then applies.
- **FDIC geography:** the supplied financial table uses county names in STCNTY. These are matched exactly by state and county name to `county_fips_mn_wi.parquet` (case-insensitive, optional “ County” suffix removed). Unresolved names make the relevant level unavailable. No current institution location is used as a historical substitute. All-insured variants use financial-report dates and county geography, including savings institutions; they do not apply the Call commercial-bank filter.

## Outputs

A full run writes:

| Path | Contents |
| --- | --- |
| `out/spec_results.csv` | One row per specification/model/term, with the exact manifest columns. Failed/unavailable/duplicate fits also have rows for their terms and explanatory messages. Unknown numerical quantities are blank. |
| `out/f_tests.csv` | The four comparisons for each nonduplicate specification, with the exact manifest columns. Unavailable comparisons retain a row with blank numerical fields. |
| `out/samples/O_A.csv`, `out/samples/O_B.csv` | Exact requested bank/year, constructed variables, and actual estimation weights. |
| `out/descriptives_O_A.csv`, `out/descriptives_O_B.csv` | Tidy columns `statistic,variable,other_variable,value`: seven means, seven sample SDs, and all 49 entries of the Pearson correlation matrix. |
| `out/construction_log_O_A.json`, `out/construction_log_O_B.json` | S1–S6 counts and sequential losses by reason/year, marginal missingness, quarterly coverage, duplicates, zero SDs, missing items, identity/zero fills, special handling, and hashes. The `deviations` object retains construction logs and unavailable reasons for variants, plus outlier choices and F-test errors. |
| `out/influence.csv` | Exact manifest columns; all row/bank deletions and requested SD/SD2 terms, including failures. Variables and benchmarks are frozen from the origin. |
| `out/environment.txt` | Python executable/version, platform, and pandas/numpy/pyarrow/scipy/statsmodels versions. |

Sample hashes use UTF-8, lowercase SHA-256 hex, integer RSSD and year without spaces, a comma delimiter, and a trailing LF for **every** line. The textual lines are sorted lexicographically before hashing, following the manifest's “sorted lines” wording; the output samples themselves are sorted numerically by RSSD and year. Duplicate sample identifiers are rejected by the lag/annual construction checks.

The saved `out/construction_validation/` artifacts are construction-only validation outputs, not frozen full-run estimation results. `construction_validation.txt` records that validation run. The validation status table includes `duplicate` entries for all 52 origin-identical levels. `R10.max_rstudent` samples in this validation directory are the pre-deletion samples, with selection explicitly deferred.

## Tests and limitations

`tests/test_analysis.py` contains synthetic checks for the five required test categories: WLS coefficients/SEs/SSE and all F comparisons against direct matrix algebra; a hand-made strategic-deviation market; exact lags across gaps and entries; exact hash serialization; and weight-rescaling invariance. Additional tests cover robust sandwich covariance, centered and square-only coordinates, actual deleted-fit studentization, AR(1) against an explicit transformation matrix, fixed effects and rank failures, quarterly coverage, timing, day weights, annualization, missingness/identity filling, record priority, merger/continuity lags, outlier lag preservation, the full grid/output pipeline, and complete influence-failure retention. `tests/test_output.txt` is the saved test run.

The only supplied-data level that cannot be implemented is **R02.no_special**, at both origins: the dictionary describes RSSD9425 but does not provide the requested bankers'-bank, credit-card-bank, and trust-only numeric codes. These specifications receive `status=unavailable`; values are not guessed. Conditional limitations are missing merger-predecessor lags and F comparisons across different residual-outlier samples, as detailed above. All other grid levels, output writers, checks, and influence diagnostics are implemented. Real-data fit success, empirical estimates, and real-data residual-outlier choices remain untested in this phase by instruction.
