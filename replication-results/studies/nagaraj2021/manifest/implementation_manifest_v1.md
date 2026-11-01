# Implementation manifest PX02, version 1

You implement a fixed set of analyses on county-level data about contributions to an online collaborative street map in the United States. Write one parameterized script that runs every row of `grid_v1.csv` and writes the outputs described at the end. Do not choose specifications yourself: every choice below is fixed, and every alternative you must run is a row of the grid.

Files you receive: this manifest, `grid_v1.csv`, `data_registry.json` (formats and columns of each data file) and a `data/` folder. During development `data/` holds synthetic files with the same names, columns and formats as the real ones; the real files are run later by someone else with your frozen script. Never hard-code anything learned from the synthetic values. The script must take the data folder and an output folder as command-line arguments.

## 1. Common data preparation

P1. County universe. Read `county_lookup.csv`. Keep rows with `STATE_NAME` not equal to "Massachusetts". The county key is the integer `FIPS`. Treatment `treat` is 0 or 1. This set is the universe U.

P2. Contribution panel. Read `quarterly.csv` as text. Remove lines that repeat the header (where `geoid` equals the literal text `geoid`). Remove rows whose `quarter` is empty or whose count columns cannot all be parsed as numbers; report how many rows were removed for each reason. Convert `geoid` to an integer county key and every other column to a number. `quarter` has the form `YYYYqN`.

P3. Balanced panel. Build every combination of a county in U and each of the 39 quarters from 2005q2 to 2014q4. Attach the rows of P2 by county and quarter. Any county-quarter with no row gets 0 for every count column. Rows of P2 for counties outside U or quarters outside the range are not used; report their number. Define `post` = 1 for quarters from 2008q1 on and 0 before. Define a quarter index `qidx` = (year − 1960) × 4 + quarter − 1.

P4. Outcomes for each county-quarter (column names as in `quarterly.csv`):
- `total` = totalcontrib
- `followon` depends on grid parameter `F`: F1 = totaltaga + totaltagb + totaltagh; F2 = totaltagv2a + totaltagv2b + totaltagv2h; F3 = totalversion2 + totalversion3 + totalversion4plus; F4 = sum of all six totaltag fields.
- `distant` depends on `F` and `D`. D1: F1 → totaltagb; F2 → totaltagv2b; F4 → totaltagb + totaltagv2b; F3 → same as F1. D2 adds the amenity field(s) of the same F level: F1 → + totaltaga; F2 → + totaltagv2a; F4 → + totaltaga + totaltagv2a; F3 → same as F1.
- `incremental` depends on `F`: F1 → totaltagh; F2 → totaltagv2h; F4 → totaltagh + totaltagv2h; F3 → same as F1.
- `contributors` = totalusers; `new` = totalnewusers; `old` = totaloldusers_active; `high_own` = totaloldfocused1
- `low_own` depends on `O`: O1 = totaloldfocused5 − totaloldfocused1; O2 = totaloldfocused5. If O1 gives a negative value, set it to missing and count such cells.
- `owner` = totalowneredit
- `pctP` = totalpctcontribP for P in 10, 25, 50, 75, 90, 99

P5. Log transformation, grid parameter `G`: G1 = ln(Y + 1) for every value; G2 = ln(Y) for Y > 0 and 0 for Y = 0. A missing Y stays missing and its observation is dropped from that regression.

P6. Controls. Read `acs5year.dta`. The ten controls are the columns population, popdensity, popmales, households, unemploymentrate, income_householdmedian, income_medianearnings, income_percapita, popeduc, popyoungmales. The key is `geo_fips` (county) and `acsyear` (year).
- Panel use: attach to each county-quarter the row whose acsyear equals the calendar year; for years after the latest year in the file use the latest year; if a county lacks a needed year, use its nearest available year (earlier year on a tie). A county with no row has missing controls and drops from models with controls; report how many.
- Cross-section use, grid parameter `Y`: Y1 = the county's values for acsyear 2011; Y2 = acsyear 2008; Y3 = the county mean over all its available years. If the needed year is missing, use the nearest available year (earlier on a tie).
- Transformation, grid parameter `L`: L1 = values as stored; L2 = ln(1 + x) for population, popmales, households, popeduc, popyoungmales, income_householdmedian, income_medianearnings, income_percapita, with popdensity and unemploymentrate as stored.

P7. Group fixed effects, used in cross-sections. Grid parameter `Q`: Q1 = three separate sets of quartile groups of popdensity, income_householdmedian and income_percapita; Q2 = the same with population in place of popdensity. Values are those of the cross-section year rule `Y`, untransformed. Quartile rule (also used for deciles with 10 in place of 4): among the counties in the reference set with a non-missing value, rank values ascending, giving tied values the smallest rank r (1-based); group = 1 + floor(k × (r − 1) / n), with k = 4 (or 10) and n the number of counties ranked. Grid parameter `R` sets the reference set: R1 = all counties in U; R2 = the counties of the sample being estimated. Each set enters as its own categorical fixed effect.

P8. Boundary sample, grid parameter `B`. Read `boundary-counties.csv`: `source county` is a county key; the second column (its header has a leading space) is a semicolon-separated list of bordering county keys. Ignore a county listed as its own neighbour and neighbours outside U.
- B1: keep a county of U if at least one of its neighbours has the opposite `treat`.
- B2: keep every control county of U, and keep a treated county if at least one neighbour is a control county.

P9. Timing sample. Read the first sheet of `timing.xlsx`; `FIPS` is a county key stored as text; `Sch SB Delivery` is a date. Keep counties of U whose `Sch SB Delivery` falls in calendar year 2005 or 2006. Counties with a missing date or not in the file are excluded.

P10. Address-pair file. Read `distance.csv`. Keep rows whose `fips` is in the sample being estimated and whose `ggl_distance` and `osrm_distance` are both non-missing. Use both distance columns as stored, without unit conversion. `dist_km` = great-circle distance between (origin_lat, origin_lon) and (dest_lat, dest_lon) by the haversine formula with Earth radius 6371.0088 km.

## 2. Analyses

Unless a row says otherwise, linear models are ordinary least squares with an intercept, and fixed effects are absorbed.

Inference to report on every regression:
- `se_cluster`: cluster-robust by county, CR1: V = c (X'X)⁻¹ (Σ_g X_g' u_g u_g' X_g) (X'X)⁻¹ with c = G/(G−1) × (N−1)/(N−K), where G is the number of counties, N the number of observations and K the number of slope coefficients excluding absorbed fixed effects. p-value from a t distribution with G − 1 degrees of freedom.
- `se_hc1`: heteroskedasticity-robust HC1 with c = N/(N−K), where K counts all estimated parameters including fixed-effect levels; p-value from t with N − K degrees of freedom.
For a county-level cross-section, G = N and both are reported.

AN01 County comparison by treatment group (counties in U). For each county: mean over its 39 panel quarters of total, followon (grid F), contributors and owner; `err_mean` = mean over its address pairs of |osrm_distance − ggl_distance|, missing if it has no pairs; changes in controls equal to the panel-rule value for 2014 minus the value for 2005, for population, households, unemploymentrate, popeduc, popmales, popyoungmales, income_percapita. For each variable report the treated mean, the control mean, the difference (treated − control), the number of counties in each group with non-missing values, the Welch two-sample t-test p-value and the equal-variance t-test p-value.

AN02 Panel summary statistics over the balanced county-quarter panel of P3, with panel controls attached by P6: for total, followon, contributors, distant, incremental, new, old, low_own, high_own, owner, treat, post, year, qidx, population, households, popdensity, income_percapita, report the mean, the standard deviation (denominator n − 1), the median, the minimum, the maximum and the count of non-missing values. Also report the number of rows, counties and quarters.

AN03 Panel difference-in-differences. Outcome ln-transform (G) of one county-quarter outcome; regressor `post × treat`; county and quarter fixed effects; with controls (grid `ctrl` = 1, the ten panel controls of P6 under `L`) or without (`ctrl` = 0). Report the coefficient on post × treat.

AN04 County cross-section. For each county in the sample, sum an outcome over the quarters of the period (grid `period`: P0814 = 2008q1–2014q4; P14 = 2014q1–2014q4; Pyyyy = the quarters of calendar year yyyy within the panel). Contributor counts are summed across quarters. Regress the G-transform of the sum on `treat`, the ten controls (P6 cross-section rule with `Y` and `L`) and the quartile fixed effects (P7 with `Q` and `R`). Report the coefficient on treat.

AN05 Panel variants (grid `variant`):
- `dtt`: AN03 with the quarter fixed effects replaced by fixed effects for each combination of popdensity quartile and quarter (popdensity under Y1, reference set U, quartile rule of P7).
- `placebo_perm`: AN03 with `treat` replaced by a permutation built from `data/placebo_draws.csv` (columns seed, fips, u): take the rows with the grid `seed` and the counties of U, sort them by u ascending (ties by county key), and set placebo treat = 1 for the first n counties, where n is the number of treated counties in U, and 0 otherwise. Also write the vector you used.
- `placebo_bern`: as `placebo_perm`, but placebo treat = 1 when u is below the treated share of U (n divided by the number of counties in U).
Do not use any random number generator.
- `boundary`, `timing`: AN03 restricted to the counties of the boundary sample (B) or the timing sample.

AN06 Cross-sections on subsamples: AN04 restricted to the boundary sample (B) or the timing sample, with `R` deciding the quartile reference set.

AN07 Address-pair regression on the pairs of P10 for the sample (full U, boundary or timing). Outcome by grid `W`: W1 = ln|osrm − ggl|, with pairs where the difference is 0 excluded and counted; W3 = ln(|osrm − ggl| + 1); W4 = |ln(osrm) − ln(ggl)|, with pairs where either distance is ≤ 0 excluded and counted. Regressors: treat, dist_km, the ten controls of the pair's county (cross-section rule, `Y`, `L`) and the quartile fixed effects (`Q`, `R`). Report the coefficients on treat and dist_km. Clustering is by county.

AN08 Panel models for the component outcomes: AN03 with controls for distant, incremental, old, new, high_own, low_own and owner.

AN09 Sample membership. One row per county in U with treat, membership in the boundary sample under B1 and under B2, and membership in the timing sample. Report counts of treated and control counties in each.

AN10 Group means over time. For each quarter and treatment group: the mean across counties of the G1-transformed outcome, and the mean across counties of the outcome's cumulative sum from 2005q2 through that quarter, for total and followon (F).

AN11 Event study. Aggregate the balanced panel to county-years 2005–2014 by summing the quarters of each year. Regress the G-transform of the yearly sum (followon or contributors) on treat × 1(year = z) for every year except 2007, with county and year fixed effects. Report each coefficient, `se_cluster`, its p-value and the 95% interval coefficient ± t(0.975, G − 1) × se_cluster.

AN12 Year-by-year cross-sections: AN04 with `period` = each calendar year 2005–2014, outcome followon. Report coefficient, `se_hc1` and the 95% interval with t(0.975, N − K).

AN13 Effects by density decile. Deciles of popdensity (cross-section rule Y1, reference set U, rule of P7 with k = 10). Within each decile: estimator M1 = AN03 with controls; M2 = AN04 for period P0814. Outcomes followon and contributors.

AN14 Panel models with controls (AN03) for each pctP outcome.

## 3. Influence mode

The script must also accept `--influence <spec_id>`. For that grid row it refits the model once for every county in the estimation sample, each time removing all observations of that county, and writes one row per removed county: county key, status, error message if any, n_obs, coefficient of the focal term, se_cluster and its p-value, se_hc1 and its p-value. A failed fit is kept as a row with its error.

## 4. Outputs (write to the output folder)

- `results.csv`: one row per grid row and reported term, with columns spec_id, analysis, term, status ("ok" or "failed"), error, n_obs, n_counties, n_dropped_missing, estimate, se_cluster, p_cluster, df_cluster, se_hc1, p_hc1, df_hc1, ci_low, ci_high, r2, k_slopes, sample_hash. `sample_hash` is the hex SHA-256 of the sorted county keys used, joined by commas. A failed row keeps its spec_id and error.
- `an01_groups.csv`, `an02_summary.csv`, `an09_membership.csv` (the per-county rows) and `an09_counts.csv`, `an10_means.csv`, with self-explanatory long-format columns that include spec_id.
- `prep_log.json`: every count the preparation steps above ask you to report.
- `placebo_vectors.csv`: spec_id, county key and the assigned placebo treat.
- `session_info.txt`: language version and package versions.

Never stop the whole run because one grid row fails; record the failure and continue.
