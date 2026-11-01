# P-OPAQUE-01 (v1) — R implementation

## How to run

```
Rscript analysis.R                      # full run: all specifications, checks, influence diagnostics -> out/
Rscript tests/run_tests.R > tests/test_output.txt 2>&1   # synthetic-data tests (no real data read)
```

Debug options (not needed for the frozen run): `--out-dir=PATH` redirects outputs;
`--construction-only` builds every specification's sample and writes the origin
samples, logs and descriptives but fits no model.

Software: R 4.6.1 with data.table, jsonlite, digest, nanoparquet (all Parquet read
with `nanoparquet::read_parquet`). No network access, no other packages.

## Script structure (`analysis.R`)

| Section | Functions | Manifest step |
|---|---|---|
| 0 | constants, `sample_hash` | section 6 hash |
| 1 | `load_inputs` | section 1 inputs |
| 2 | `filter_records` (S1), `market_population` (S2), `get_item` / `category_amounts` / `shares_by_timing` / `compute_AA` / `opening_dates` / `build_annual` (S3), `compute_benchmarks` (S4), `compute_SD` / `relative_roa` / `lag_as_reported` / `deflator_series` / `fdic_insured_deposits` / `merger_survivors` / `derive_variables` (S5), `estimation_sample` (S6), `build_sample` (driver, incl. the R09.analytic second pass) | section 2 |
| 3 | `build_design`, `fit_core`, `rstudent_ext`, `back_transform`, `weights_for`, `fit_model`, `run_models` (models, F tests, R10.max_rstudent, R26.centered) | section 3 |
| 4 | `enumerate_specs`, `make_cfg`, `construction_key` (sample construction cached per construction-relevant configuration) | section 4 |
| 5 | `run_influence` | section 5 |
| 6 | `write_descriptives`, `write_environment`, `main` | section 6 |

Every specification is run inside `tryCatch`; failures are written with status
`failed` and the error message. Duplicates (a deviation level equal to the origin's
level) are written with status `duplicate`. The sample construction is reused across
specifications that share the same construction-relevant axes (R01–R21).

## Outputs (`out/`)

`spec_results.csv`, `f_tests.csv`, `samples/O_A.csv`, `samples/O_B.csv`,
`descriptives_O_A.csv`, `descriptives_O_B.csv` (one row per variable: n, mean, sd and
the Pearson correlation columns), `construction_log_O_A.json`,
`construction_log_O_B.json`, `influence.csv`, `environment.txt`.

`sample_hash` = SHA-256 of the concatenation of the lines `RSSD9001,year\n`, lines
sorted as byte strings (C-locale order).

## Implementation of the manifest, item by item

### S1 record filter (R02)
- `R02.charter_entity`, `R02.charter`, `R02.entity`: as specified.
- `R02.no_special`: origin filter and `RSSD9425` not in {1, 2, 3}. The dictionary does
  not enumerate the codes of this item; the file contains only 0, 1 and 3 (names of the
  flagged entities are bankers' banks for 1 and trust companies for 3). All non-zero
  codes are treated as special-purpose.
- `R02.add_savings`: origin filter OR (`RSSD9048 == 300` and `CALL8786` in {1, 2}).
  No savings bank is located in the market counties in 1984–1992, so the level runs
  but yields the origin sample.
- Duplicate records within quarter × RSSD9001: none exist (key is unique), the rule
  "keep CALL8786 == 1 over 2" is implemented and logged anyway.

### S2 market membership (R01)
`county_fips5 = RSSD9210 (2 digits) + RSSD9150 (3 digits)` at the Q4 record.
`R01.fixed1983` uses the 1983-06-27 vintage; `R01.rssdmsa` uses `RSSD9180 == 5120`;
`R01.mnonly` restricts to state 27; `R01.dynamic` uses the latest vintage dated on or
before 31 December of year t (1983 vintage for 1984–1989, 1990 vintage for 1990–1992;
identical county lists). U_t additionally requires total assets > 0 (the R16-scope
item 2170).

### S3 annual variables
- Average assets (R05, R06, R16): quarterly records of year t under the S1 filter.
  `R05.min2_fallback`: mean of RCFD3368 (RCON3368 where RCFD is missing) over ≥ 2
  quarters; if no quarter is available, mean of the available 2170 points from Q4 t−1
  to Q4 t; exactly one available quarter gives missing (literal reading; 2 bank-years
  affected at O_A, logged). `R05.all4` requires all four quarters (no RCON fallback).
  `R05.any` needs ≥ 1. `R06.rck_days` weights the quarters admitted by the R05 rule by
  calendar days (90/91, 91, 92, 92). `R06.five_point`, `R06.two_point` as specified.
  `R06.fdic_roa`: ROA = FDIC `ROA/100` at REPDTE 31 Dec of t matched on CERT =
  RSSD9050; the expense ratio keeps the origin's RC-K average assets.
- Net income (R07): RIAD4340 or RIAD4300 at Q4. Expense ratio = (RIAD4073 +
  RIAD4093)/AA.
- `R04.annualise`: in the bank's opening calendar year (FDIC ESTYMD via CERT, else the
  first quarter in which the RSSD9001 appears in the Call files), NI and expenses are
  multiplied by 12 / (months from the opening month to December inclusive).
  `R04.full_prior_year`: opening date < 1 January of t−1.
- Eleven categories (R11–R16) with the item codes of the manifest; all divided by
  item 2170 at the same timing. `R13.components` = 2165 + 1505 + 1510 + 1517 + 2107 +
  2081 + 1563 (+ 1755 when R11 = excl_accept). Here 1563 "other loans" covers both
  "loans to purchase securities" (1545) and "all other loans" (1564) on the 1984+
  forms (1563 = 1545 + 1564 on the file); 1510 covers 1516. With acceptances included
  this sum reproduces the gross residual exactly for every bank that reports the
  components. Banks filing the short forms (FFIEC 033/034, about 85 % of the market)
  do not report 1505/1510/1517/2081/1563 although the items are collected in the
  quarter, so under both R15 rules their category is missing and they leave the
  sample (≈ 206 rows remain). This is the designed consequence, not a failure.
- R15: `zero_if_not_collected` uses `call_item_presence_by_quarter` (`in_file == 0`
  or `any_nonmissing_mnwi == 0`); `missing`; `identity_fill` fills totals 0010 =
  0081+0071, 1600 = 1755+1766, 1766 = 1763+1764, 1975 = 2008+2011, 1350 = 0276+0277
  from complete components. All substitutions are counted in the construction log.
- R16.domestic: the foreign-office banks (FFIEC 031 filers) do not report several
  RCON other-asset items, so their category 11 is missing and they drop out (25
  bank-years at O_A). Logged.
- R08: `year_end` (Q4 record); `mean_of_quarter_shares` (mean over available
  quarterly shares and quarterly deposit amounts); `ratio_of_means` (mean of item
  amounts over mean of 2170 across the quarters where both are present; deposits =
  mean of quarterly amounts).
- Deposits (R18): RCON2200 or RCFD2200 (not subject to R16).

### S4 benchmarks (R09, R17)
Means, SDs, mean ROA and deposit totals by year over: all U_t banks (available-case);
the joint-complete subset; or the estimation-sample rows of the year (`R09.analytic`,
two passes: build with all_market, then recompute benchmarks on the final rows of each
year 1985–1992, rebuild SD, y, lag, MS, RMG and keep the same rows; 1984 keeps the
all-market benchmarks because no estimation rows exist for it). `R09.weighted_roa`
weights ROA by average assets. R17: n−1 or n denominator; zero-SD category
contributes 0 or makes SD missing.

### S5 derived variables
- SD, SD2, y = 100·(ROA − mean ROA_t).
- Lag (R03): `as_reported` = y of the same RSSD9001 in U_{t−1} (no gap-skipping).
  `drop_merger_years`: bank-years t and t+1 are dropped when the bank's CERT is the
  acquirer or survivor (ACQ_CERT / SUR_CERT) of an FDIC event with CHANGECODE in
  {213, 221, 222, 223, 810, 812} effective in year t (branch-level codes 713/722 are
  not used). `continuity`: a bank without a t−1 row whose CERT reported at t−1 under
  another RSSD9001, with an FDIC event in {420, 440, 510, 820} in t−1 or t and no
  absorption of that CERT, takes the predecessor's y_{t−1}; no such case exists in
  the data, so the level equals as_reported. `proforma`: for acquirers/survivors in
  year t, lag = 100·(ΣNI_{t−1}/ΣAA_{t−1} − mean ROA_{t−1}) summed over the bank itself
  and the OUT_CERT institutions found in the filtered Call records at t−1 (inside or
  outside the market); other banks as_reported.
- MS = DEP / D_t with D_t = sum over the R09 population (`R19.commercial`) or the sum
  of FDIC `DEP` at 31 Dec over all insured institutions whose county (FDIC `STCNTY`
  carries the county name; mapped to FIPS with the county table and `STALP`) is in the
  market county list (`R19.all_insured`).
- RMG_t = 100·((D_t/P_t)/(D_{t−1}/P_{t−1}) − 1) with D per R21 (same two sources) and
  P per R20: FRED CPIAUCNS annual average; CPIAUCNS December; CUUSA211SA0 annual;
  A191RD3A086NBEA; ALFRED GDPDEF vintage 1999-01-01 annual mean of the quarters.
- R10: `delete_named` (row 995151/1987 deleted last; it keeps serving as lag and in
  benchmarks); `suppress_lag` (also sets its 1988 lag to missing); `before_benchmarks`
  (removed from U_1987 before benchmarks, 1988 lag missing); `none`;
  `max_rstudent` (fit M1–M3 on the undeleted sample, delete the row with the largest
  externally studentized residual if common to all three, else each model's own
  maximum; M3_SQ uses its own maximum in that case; F tests are only computed when the
  compared models share the same rows).

### S6 estimation sample
Years 1985–1992, in U_t, non-missing y, lag, SD, MS, TER, RMG, MS > 0, then R03/R04
restrictions, then R10. Sequential counts by year are in the construction log.

### Models and estimator
WLS by the sqrt(w) transformation with sqrt(w) as intercept column; w = MS
(`R24.raw`), MS/mean(MS) (`R24.mean1`), 1 (`R25.ols`). `R25.wls_ar1`: Prais–Winsten on
the sqrt(w)-transformed panel; rho = Σ e_t e_{t−1} / Σ e_{t−1}^2 over within-bank
consecutive-year pairs of the WLS residuals; first observations of a bank (and
observations after a gap) are scaled by sqrt(1−rho²); each model estimates its own rho
(reported in `message`). Covariance (R23): conventional s²(X'WX)⁻¹; HC1 and CR1 on the
transformed regression as specified. Fixed effects (R22): year indicators (RMG dropped
and reported) or bank indicators (counted in K, coefficients not listed). The
condition index is computed on the transformed design matrix with unit-length columns.
Nested F tests use the weighted SSEs; p upper tail. `R26.centered` fits with SD − mean
SD and back-transforms coefficients and covariance with the exact linear map (delta
method); for M3_SQ the centred square implies a raw first-order term, which is listed.

### Influence diagnostics
At O_A and O_B, M2 and M3: leave-one-bank-year-out and leave-one-bank-out refits with
the origin estimator; variables, benchmarks and lags are not rebuilt. Rows for SD (M2)
and SD2, SD (M3); failures retained with status `failed`.

## Items not implemented or implemented under stated assumptions
No manifest level is marked `unavailable`; all 110 deviations, 4 checks and 2 origins
construct successfully on the real data (construction stage only was run; no model was
fitted on the real data in this phase). Assumptions worth knowing:
- `R02.no_special`: codes of RSSD9425 taken as all non-zero values (see above).
- `R05.min2_fallback` with exactly one available quarter of item 3368: missing.
- `R06.rck_days`: coverage follows the R05 rule of the active origin.
- `R13.components`: item mapping as described above (1563 for the two "other loans"
  concepts; acceptances added under excl_accept).
- `R19/R21.all_insured`: county from the FDIC county name + state.
- `R09.analytic`: 1984 benchmarks stay all-market (no estimation rows in 1984).
- `R03.proforma`: predecessors need not be in the market.
- Lag requires the t−1 row to be in U_{t−1} (annual variables are defined for U_t).
- `sample_hash` sorts lines as byte strings.

## Tests (`tests/run_tests.R`, output in `tests/test_output.txt`)
(a) WLS coefficients, SEs, SSE, condition index, studentized residuals, nested F and
HC1/CR1 covariances against direct matrix computation and `lm`; (b) strategic
deviation on a hand-made three-bank market, including zero-SD and population-SD
rules and the reference-population variants; (c) lag construction across gaps,
entries, out-of-market and missing t−1; (d) sample-hash format; (e) weight rescaling
leaves coefficients and SEs unchanged and scales SSE; (f) the estimation layer
(models, centred-basis check, fixed effects, covariances, OLS, AR(1), max-rstudent,
influence, failure handling); (g) record-level helpers (R15 rules, R08 timing,
back-transformation map).
