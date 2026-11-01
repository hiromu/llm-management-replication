# Implementation manifest P-OPAQUE-01 (v1)

You are implementing a fixed, pre-specified empirical analysis from public U.S. bank regulatory data. Everything you need is in this directory. Work offline. Do not look for the study this design came from and do not try to guess expected results; there is no target to match. Write one parameterised script that runs every specification in `grid.json` and writes the outputs listed in section 6. If a level cannot be implemented with the supplied data, record status `unavailable` with the reason; do not invent substitutes.

## 1. Inputs

- `data/`: Parquet files (read Parquet, not CSV) described in `docs/data_dictionary.md` and `docs/source_descriptions.md`. Main file: `call_mnwi_core_1983q4_1993q4.parquet` (one row per reporting record per quarter; `quarter` is a string like `1987Q4`; dollar items in thousands). Also `call_item_presence_by_quarter.parquet`, `fdic_institutions_mnwi_and_linked.parquet`, `fdic_structure_events_mnwi_1983_1994.parquet`, `fdic_financials_core_mnwi_1984q1_1994q4.parquet`, `deflators_long.parquet`, `msa_minneapolis_stpaul_counties_by_vintage.parquet`.
- `docs/call_item_candidates.json`: report items by concept.
- `grid.json`: axes, levels, the two base configurations `O_A` and `O_B`, model list and run order.

## 2. Base construction (shared by all specifications; axis levels in grid.json override the marked parts)

Notation: bank i = RSSD9001; year t = calendar year; "Q4 record" = the record with quarter `tQ4`.

S1. Record filter [axis R02]. Keep records passing the active R02 rule. If a bank has more than one record in a quarter after filtering, keep CALL8786 == 1 over 2 and log it.

S2. Market membership [axis R01]. A bank is in the market in year t if its Q4 record of year t passes the R01 rule. Market population U_t = market banks in year t with a Q4 record and RCFD2170 > 0. Years needed: 1984-1992 (1984 supplies lags and t-1 market totals).

S3. Annual bank variables for every bank in U_t, t = 1984..1992:
- Average assets AA_it [axes R05, R06, R16].
- Net income NI_it [axis R07]; income items are calendar-year-to-date, so the Q4 record gives the full year. Do not sum quarters.
- ROA_it = NI_it / AA_it [axis R06 option fdic_roa replaces this].
- Total expense ratio TER_it = (RIAD4073 + RIAD4093 at Q4) / AA_it (proportion).
- Eleven asset amounts at the timing of axis R08, each divided by RCFD2170 at the same timing (proportions):
  1 commercial loans [R11]; 2 real estate loans RCFD1410 [R12]; 3 loans to individuals RCFD1975; 4 agricultural loans [R12]; 5 other loans and leases [R13]; 6 cash and balances due RCFD0010; 7 federal funds sold and resale agreements RCFD1350; 8 investment securities RCFD0390; 9 trading account assets RCFD2146; 10 premises and fixed assets RCFD2145; 11 other assets [R14].
  Missing components [R15]. Stock scope RCFD vs RCON [R16].
- Deposits DEP_it [axes R18, R08].

S4. Market benchmarks for each year t over the reference population of axis R09:
- For each category a: mean m_at and standard deviation s_at [R17] of the share.
- Market mean ROA: unweighted mean of ROA_it [R09 option weighted_roa].
- Market deposits D_t = sum of DEP_it [axes R19, R21].

S5. Derived variables:
- Strategic deviation SD_it = sum over the 11 categories of |(share_ait - m_at) / s_at| [R17 zero-SD rule].
- SD2_it = SD_it squared (raw, not centred) [R26 check].
- Relative ROA y_it = 100 * (ROA_it - market mean ROA_t).
- Lag: y_i,t-1 for the same unit [axis R03], computed with year t-1 benchmarks. No gap-skipping: the lag must be from calendar year t-1.
- Market share MS_it = DEP_it / (market deposits of year t used for shares) [R19]; proportion 0-1.
- Real market growth RMG_t = 100 * ((D_t / P_t) / (D_t-1 / P_t-1) - 1), deflator P [R20], deposit aggregate D [R21]; same value for all banks in year t.

S6. Estimation sample: bank-years with t in 1985..1992, in U_t, with non-missing y_it, lag, SD_it, MS_it, TER_it, RMG_t, MS_it > 0 [axes R03, R04]. Apply the outlier rule [R10] last. The same rows are used for M1, M2, M3 and M3_SQ within a specification.

## 3. Models

All models: outcome y_it, intercept, regressors in this order:
- M1: MS, TER, RMG, lag
- M2: SD, MS, TER, RMG, lag
- M3: SD2, SD, MS, TER, RMG, lag
- M3_SQ: SD2, MS, TER, RMG, lag

Estimator [R25]: weighted least squares minimising sum w_it * e_it^2 with w_it = MS_it [R24]. Equivalent to OLS of sqrt(w)*y on sqrt(w)*X including sqrt(w) as the intercept column. Fixed effects [R22]. Covariance [R23]: conventional WLS covariance s^2 (X'WX)^-1 with s^2 = SSE_w / (N - K).

Report for each fitted model: N, number of banks, K, df_resid = N - K, weighted SSE_w = sum w e^2, each coefficient with SE, t, two-sided p from Student t(df_resid), and the largest condition index of the weighted design matrix with columns scaled to unit length (Belsley-Kuh-Welsch convention, intercept included).

Nested F tests within a specification (same rows): M2 vs M1, M3 vs M1, M3 vs M2, M3_SQ vs M1, F = ((SSE_r - SSE_u)/q) / (SSE_u/(N - K_u)), with the upper-tail p value. For R23 non-conventional covariance, still report the SSE-based F.

## 4. Specifications

Build each specification from `grid.json`: start from base configuration `O_A` or `O_B` (each lists one level per axis), then replace exactly one axis level (run order step 2). spec_id = `<origin>__<level_id>` for deviations and `<origin>` for the base configurations. Skip a deviation whose level equals the origin's level and record it as `duplicate`. Run the algebraic checks R24.mean1 and R26.centered at both origins; for R26.centered report the back-transformed raw-basis coefficients and SEs (delta method). Keep sample construction reusable across specifications.

## 5. Influence diagnostics (registered before fitting)

At O_A and O_B, for models M2 and M3:
- Leave-one-bank-year-out: for every row r of the estimation sample, refit after deleting row r only (variables, benchmarks and lags are not rebuilt). Record row id, estimates, SEs, two-sided p for SD (M2) and SD2 and SD (M3), N, status and any error.
- Leave-one-bank-out: for every bank, refit after deleting all its rows; record the same fields.
Retain every fit, including failures.

## 6. Outputs (write under `out/`)

- `out/spec_results.csv`: one row per spec x model x term: spec_id, origin, axis, level_id, model, status (ok/failed/unavailable/duplicate), message, n, n_banks, k, df_resid, sse_w, cond_max, term, estimate, se, t, p_two_sided, sample_hash.
  sample_hash = SHA-256 hex of the sorted lines `RSSD9001,year` (integers, no spaces, newline-terminated) of the estimation sample.
- `out/f_tests.csv`: spec_id, comparison, delta_sse, q, df_resid_u, F, p_upper.
- `out/samples/O_A.csv`, `out/samples/O_B.csv`: RSSD9001, year, y, lag, SD, SD2, MS, TER, RMG, w for the estimation sample.
- `out/descriptives_O_A.csv`, `out/descriptives_O_B.csv`: unweighted mean and SD of y, lag, SD, SD2, MS, TER, RMG and their Pearson correlation matrix in the estimation sample.
- `out/construction_log_<origin>.json`: counts of records/bank-years kept and dropped at each step S1-S6 and by reason, by year; any special handling (duplicate records, zero SDs, unavailable items).
- `out/influence.csv`: origin, model, deletion_type (bank_year/bank), deleted_id, term, estimate, se, p_two_sided, n, status, message.
- `out/environment.txt`: language and package versions.
- `README.md`: how to run, and any manifest item you could not implement with the reason.

Language and software defaults are given in your task prompt. Use only installed packages; no network access.
