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

Every specification is run inside `tryCatch`. A level that cannot be implemented from
the supplied inputs raises a condition of class `unavailable` (helper `unavailable()`,
used by `need_input` / `need_cols` and by the level-specific checks) and is written with
status `unavailable` and the reason; any other error is written with status `failed`
and the error message. Duplicates (a deviation level equal to the origin's level) are
written with status `duplicate`, and M3_SQ under `R26.centered` with status
`not_applicable` (amendment v1.1 C6). All inputs other than the main Call file are loaded
under a guard in `load_inputs`: a missing file or column is recorded in
`inp$load_errors`, and only the specifications that need it become `unavailable`. The
sample construction is reused across specifications that share the same
construction-relevant axes (R01–R21).

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
- `R02.no_special`: origin filter and RSSD9425 not in {1, 2, 4, 9} (bankers' banks
  subject / not subject to reserve requirements, primarily credit card activities,
  depository trust company), the code table of `docs/rssd9425_codes.txt` as fixed by
  manifest amendment v1.1 C2; a missing RSSD9425 counts as 0. The S1 log lists the
  codes excluded and the records excluded by code. (If the RSSD9425 column were absent
  the level would be `unavailable`.)
- `R02.add_savings`: origin filter OR (`RSSD9048 == 300` and `CALL8786` in {1, 2}).
  No savings bank is located in the market counties in 1984–1992, so the level runs
  but yields the origin sample.
- Duplicate records within quarter × RSSD9001: none exist (key is unique), the rule
  "keep CALL8786 == 1 over 2" is implemented anyway. The S1 log reports, by year, the
  records before and after duplicate removal and the number removed.

### S2 market membership (R01)
`county_fips5 = RSSD9210 (2 digits) + RSSD9150 (3 digits)` at the Q4 record.
`R01.fixed1983` uses the 1983-06-27 vintage; `R01.rssdmsa` uses `RSSD9180 == 5120`;
`R01.mnonly` restricts to state 27; `R01.dynamic` uses the latest vintage dated on or
before 31 December of year t (1983 vintage for 1984–1989, 1990 vintage for 1990–1992;
identical county lists). U_t additionally requires total assets > 0 (the R16-scope
item 2170). The S2 log reports, by year, the bank-years (RSSD9001 × year) with at
least one filtered record, those with a Q4 record, and those dropped for lacking a Q4
record, before the market and total-assets counts.

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
  item 2170 at the same timing. `R13.components` is the explicit sum over the six
  component categories enumerated in grid.json, each mapped in the constant
  `COMPONENT_ITEMS` to item codes of the `other_loans_and_leases_and_loan_totals`
  group of `docs/call_item_candidates.json` (the script loads that file and records
  the level as `unavailable` if a code is not in the group): lease financing
  receivables 2165; loans to depository institutions 1505 + 1510 + 1517 (1516 is a
  sub-item of 1510); obligations of states and political subdivisions 2107; loans to
  foreign governments 2081; loans to purchase securities and all other loans together
  as "other loans" 1563 (= 1545 + 1564 on the file; 1564 has no RCFD column). Each item
  enters once; nothing else (in particular no acceptances item) is added, so the sum
  differs from the gross residual by the acceptances of other banks. Banks filing the
  short forms (FFIEC 033/034, most of the market) do not report 1505/1510/1517/2081/1563
  although the items are collected in the quarter, so under both R15 rules their
  category is missing and they leave the sample. This is the designed consequence of
  the level, not a failure.
- R15: `zero_if_not_collected` zero-fills a missing value only when
  `call_item_presence_by_quarter` shows `in_file == 0` or `any_nonmissing_mnwi == 0`
  for that item and quarter; an item with no row in the presence file has no such
  evidence and stays missing (counted in the S3 log), and the level is `unavailable`
  if the presence file cannot be loaded. `missing`; `identity_fill` fills totals 0010 =
  0081+0071, 1600 = 1755+1766, 1766 = 1763+1764, 1975 = 2008+2011, 1350 = 0276+0277
  from complete components. All substitutions are counted in the construction log.
- R16.domestic: the foreign-office banks (FFIEC 031 filers) do not report several
  RCON other-asset items, so their category 11 is missing and they drop out (25
  bank-years at O_A). Logged.
- R08: `year_end` (Q4 record); `mean_of_quarter_shares` (mean over available
  quarterly shares and quarterly deposit amounts); `ratio_of_means` (mean of the
  available quarterly item amounts divided by the mean of the available quarterly 2170
  values, each mean over its own available quarters; deposits = mean of quarterly
  amounts).
- Deposits (R18): RCON2200 or RCFD2200 (not subject to R16).

### S4 benchmarks (R09, R17)
Means, SDs, mean ROA and deposit totals by year over: all U_t banks (available-case);
the joint-complete subset; or the estimation-sample rows of the year (`R09.analytic`,
two passes per amendment v1.1 C5: build with all_market, then recompute benchmarks for
each year 1985–1992 on the first-pass estimation rows of that year and for 1984 on the
1984 bank-years whose relative ROA is the lag of a first-pass 1985 row; rebuild SD, y,
lag, MS, RMG and refit on the first-pass rows; a row whose rebuilt variables are
undefined is dropped and counted in the log, not treated as a failure). The log also
lists the reference rows by year. `R09.weighted_roa` weights ROA by average assets. R17:
n−1 or n denominator (a category with a single observation has population SD 0 and
sample SD missing); zero-SD category contributes 0 or makes SD missing.

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
  and every OUT_CERT institution in the filtered Call records at t−1 (inside or
  outside the market). The pro forma lag replaces the as-reported lag for every
  survivor-year; it is missing (and the row leaves the sample) when a predecessor is
  unidentified (OUT_CERT missing), when the survivor or a predecessor has no t−1
  record, or when any of their NI or AA is missing; the reason is in `lag_source`.
  Other banks as_reported.
- MS = DEP / D_t with D_t = sum over the R09 population (`R19.commercial`) or the sum
  of FDIC `DEP` at 31 Dec over all insured institutions whose county (FDIC `STCNTY`
  carries the county name; mapped to FIPS with the county table and `STALP`) is in the
  market county list (`R19.all_insured`).
- RMG_t = 100·((D_t/P_t)/(D_{t−1}/P_{t−1}) − 1) with D per R21 (same two sources) and
  P per R20: FRED CPIAUCNS annual average; CPIAUCNS December; CUUSA211SA0 annual;
  A191RD3A086NBEA; ALFRED GDPDEF vintage 1999-01-01 annual mean of the quarters. The
  t−1 value is matched on calendar year t−1 exactly; if that year is absent RMG_t is
  missing (no gap-spanning). A deflator series absent from the inputs makes the level
  `unavailable`.
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
(`R24.raw`), MS/mean(MS) (`R24.mean1`), 1 (`R25.ols`). A fit requires df_resid = N − K
≥ 1 (N = K + 1 is accepted); missing values in y, X or w raise an explicit error.
`R25.wls_ar1`: Prais–Winsten on the sqrt(w)-transformed panel; rho = Σ e_t e_{t−1} /
Σ e_{t−1}^2 over within-bank consecutive-year pairs of the WLS residuals; first
observations of a bank (and observations after a gap) are scaled by sqrt(1−rho²); each
model estimates its own rho (reported in `message`). The reported `sse_w` is always
Σ w·e² with e = y − Xβ from the original regression (manifest section 3), and the
nested F tests use these SSEs; under AR(1) the covariance s²(X_s'X_s)⁻¹ uses the
transformed regression's residual sum of squares (also reported in `message`), which
coincides with `sse_w` whenever rho is not estimated. Covariance (R23): conventional
s²(X'WX)⁻¹; HC1 and CR1 on the transformed regression as specified. Fixed effects
(R22): year indicators (RMG dropped and reported) or bank indicators; every fitted
coefficient, including each `year_<t>` and `bank_<RSSD9001>` indicator, is listed in
`spec_results.csv` with SE, t and p. The condition index is computed on the
transformed design matrix with unit-length columns. Nested F tests use the weighted
SSEs; p upper tail. `R26.centered`: M3 (and M2) are fitted with SD − mean SD and
(SD − mean SD)² and back-transformed to the raw basis with the exact linear map (delta
method), reproducing the raw coefficients and SEs; M3_SQ has no first-order term, so
the centred re-expression is not defined and it is written with status
`not_applicable` (amendment v1.1 C6; its F test row is empty). M1 has nothing to
centre and equals the raw fit.

### Influence diagnostics
At O_A and O_B, M2 and M3: leave-one-bank-year-out and leave-one-bank-out refits with
the origin estimator; variables, benchmarks and lags are not rebuilt. Rows for SD (M2)
and SD2, SD (M3); failures retained with status `failed`.

## Items not implemented or implemented under stated assumptions
No level is `unavailable` with the supplied inputs; all 110 deviations, the 4 checks
and the 2 origins construct successfully on the real data (construction stage only was
run; no model was fitted on the real data in this phase). M3_SQ under `R26.centered`
is `not_applicable` by amendment v1.1 C6. Assumptions worth knowing:
- `R05.min2_fallback` with exactly one available quarter of item 3368: missing.
- `R06.rck_days`: coverage follows the R05 rule of the active origin.
- `R13.components`: item mapping as described above (1563 carries the two "other
  loans" concepts; no acceptances added).
- `R19/R21.all_insured`: county from the FDIC county name + state.
- `R09.analytic`: 1984 benchmarks stay all-market (no estimation rows in 1984).
- `R03.proforma`: predecessors need not be in the market; incomplete predecessor
  information makes the lag missing.
- Lag requires the t−1 row to be in U_{t−1} (annual variables are defined for U_t).
- `sample_hash` sorts lines as byte strings.

## Checker items
Resolution of the 15 items raised by the independent checker (fixed / no change /
unavailable). `manifest_amendment_v1_1.md` (with `docs/rssd9425_codes.txt`) appeared
in the directory during this revision; its clarifications were applied where they bear
on a checker item (C1 → item 1, C2 → item 2, C5 → item 5, C6 → item 9, C7 → item 10,
C8 → items 1 and 12). Two clarifications fall outside the checker list and were **not**
applied, because this revision was restricted to the listed items: C3 (`R02.add_savings`
should also require RSSD9331 == 1 at O_A; the code admits RSSD9048 == 300 with
CALL8786 in {1, 2} only) and C4 (`R06.rck_days` should require all four quarterly
3368 values with RCON fallback and no 2170 fallback regardless of R05; the code
follows the origin's R05 coverage rule). Both need a follow-up change.
1. **Fixed** – `unavailable` is now a distinct condition class. Inputs other than the
   main Call file are loaded under a guard (`load_inputs`, `inp$load_errors`), steps
   check what they need (`need_input`, `need_cols`, level-specific checks such as a
   deflator series or candidate item codes absent from the inputs), and `main` /
   `run_models` write status `unavailable` with the reason for such conditions and
   `failed` for any other error.
2. **Fixed** – `R02.no_special` no longer infers codes: it excludes RSSD9425 in
   {1, 2, 4, 9} per the code table supplied with amendment v1.1 C2
   (`docs/rssd9425_codes.txt`), treats a missing code as 0, and logs the codes and the
   records excluded by code. (Before the amendment arrived the level had been made
   `unavailable`, since the data dictionary gave no code table; with the table it is
   implementable.)
3. **Fixed** – `R03.proforma`: the pro forma lag replaces the as-reported lag for every
   merger survivor-year; if a predecessor is unidentified, has no t−1 record, or has
   missing NI or AA (or the survivor does), the lag is missing with the reason in
   `lag_source` instead of silently summing the available part or keeping the
   as-reported lag.
4. **Fixed** – `R08.ratio_of_means`: numerator and denominator are now separate means
   over their own available quarters (mean of item amounts / mean of 2170).
5. **Fixed per amendment C5** – `R09.analytic`: the checker asked that rows with
   undefined rebuilt variables be retained, but amendment v1.1 C5 states that such rows
   are dropped and counted in the log (not a failure), so the deletion stays and is
   now logged with the cases. What changed: the 1984 reference population is now the
   1984 bank-years whose relative ROA is the lag of a first-pass 1985 row (previously
   all-market), the reference rows are logged by year, and `fit_core` raises an
   explicit error if a row with missing values ever reaches a model. On the real data
   no row is dropped at either origin.
6. **Fixed** – `R13.components`: the acceptances addition under `R11.excl_accept` was
   removed; the sum is over the six enumerated categories through the explicit
   `COMPONENT_ITEMS` mapping, every code validated at run time against the
   `other_loans_and_leases_and_loan_totals` group of `docs/call_item_candidates.json`
   (the level is `unavailable` if the file or a code is missing).
7. **Fixed** – `R15.zero_if_not_collected`: zero-filling now requires a presence row
   with `in_file == 0` or `any_nonmissing_mnwi == 0` for the item-quarter; an item
   absent from the presence metadata stays missing and is counted in the S3 log; the
   level is `unavailable` without the presence file.
8. **Fixed** – `R17.population_sd`: a category with one observation gets SD 0 (then
   handled by the zero-SD rule); the sample SD still needs n ≥ 2.
9. **Fixed per amendment C6** – `R26.centered` for M3_SQ no longer replaces SD² by
   (SD − m)² or adds an implied SD term; the model is not fitted and is written with
   status `not_applicable` and an explanatory message (its F-test row is empty), as the
   amendment prescribes. M2 and M3 keep the centred fit back-transformed to the raw
   basis (tested to reproduce the raw coefficients and SEs).
10. **Fixed** – RMG_t divides by the real deposit aggregate of calendar year t−1
    matched explicitly; a missing t−1 benchmark year gives a missing RMG_t.
11. **Fixed** – `fit_core` accepts N = K + 1 (df_resid = 1) and rejects only N ≤ K;
    externally studentized residuals (R10.max_rstudent) still need df_resid ≥ 2 and say
    so.
12. **Fixed** – bank-indicator coefficients (`bank_<RSSD9001>`) are reported in
    `spec_results.csv` with SE, t and p like every other term.
13. **Fixed** – `R25.wls_ar1`: `sse_w` and the nested F tests use Σ w·e² of the
    original regression (e = y − Xβ); the Prais–Winsten residual sum of squares is used
    only for s² in the covariance and is reported in `message`.
14. **Fixed** – t and p vectors are named in `fit_core` and `back_transform`, so
    influence rows carry the two-sided p of successful fits (tested against a direct
    refit).
15. **Fixed** – the S1 log adds, by year, records before/after duplicate removal and
    the number removed; the S2 log adds, by year, bank-years with any filtered record,
    with a Q4 record, and dropped for lacking a Q4 record.

## Tests (`tests/run_tests.R`, output in `tests/test_output.txt`)
(a) WLS coefficients, SEs, SSE, condition index, studentized residuals, nested F and
HC1/CR1 covariances against direct matrix computation and `lm`; (b) strategic
deviation on a hand-made three-bank market, including zero-SD and population-SD
rules and the reference-population variants; (c) lag construction across gaps,
entries, out-of-market and missing t−1; (d) sample-hash format; (e) weight rescaling
leaves coefficients and SEs unchanged and scales SSE; (f) the estimation layer
(models, centred-basis check for all four models, fixed effects with listed bank
indicators, covariances, OLS, AR(1) with the Σ w·e² SSE definition, max-rstudent,
influence including p-values, failure handling, the `unavailable` condition); (g)
record-level helpers (R15 rules including items without presence metadata, R08
timing with separate means, back-transformation maps, RMG year matching, the
R02.no_special code filter). 96 tests.
