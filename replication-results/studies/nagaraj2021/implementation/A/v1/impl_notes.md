# Implementation notes (run_analysis.R, manifest PX02 v1)

## Running
- The grid file is not passed as an argument. The script looks for `grid_v1.csv` in this order: env var `PX02_GRID`, `<data_dir>/`, `<data_dir>/../`, the script's own folder, `<script_dir>/../input/`, `./`, `./input/`.
- Influence mode writes `influence_<spec_id>.csv`, plus `prep_log.json` and `session_info.txt`, to the output folder.

## Estimation conventions
- Every regression in the manifest absorbs fixed effects. Panels use county plus quarter/year/dtt FE; cross-sections and AN07 use the quartile FE sets. So there is never a separate intercept. Slopes are estimated by FWL: panels are demeaned with `fixest::demean` (tol 1e-12), and cross-sections are residualised on explicit dummies by QR. I checked the coefficients, CR1 SEs and HC1 SEs against `feols` and `lm` + `sandwich`, and they match.
- CR1: K = number of estimated slope coefficients (`k_slopes`), with FE and intercept excluded. HC1: K = k_slopes + the exact rank of the FE design. For two-way FE that rank is levels1 + levels2 − number of connected components; for cross-sections it is the QR rank of the intercept plus the dummies. In the `dtt` variant, county is nested in the popdensity-quartile×quarter cells, which gives 4 components. My K is therefore 3 smaller than fixest's `fixef.K="full"`, which only removes 1.
- A slope collinear with the FE or with other regressors is dropped and not counted in K. If the dropped slope is a focal term, that results row gets `status=failed` with an explanatory error. This does not happen on the synthetic data.
- `r2` is the R² of the full model, including the fixed effects.
- `ci_low`/`ci_high`: AN12 uses se_hc1 and t(N−K). All other analyses use se_cluster and t(G−1). The manifest specifies CIs only for AN11 and AN12; the cluster-based CI elsewhere is my choice.
- `n_counties` = number of clusters (G) in the estimation sample. `sample_hash` = SHA-256 of the sorted, comma-joined county keys in the estimation sample after missing-value drops.
- `n_dropped_missing` counts observations dropped for missing outcome, regressors or FE. Exclusions from the AN07 W rules (zero difference for W1, non-positive distance for W4) are not counted there. They are logged per spec in `prep_log.json` under `per_spec`.
- AN01, AN02, AN09 and AN10 each produce one `results.csv` row with a blank term and `status=ok`. Their numbers are in the side files.

## Choices where the manifest is silent or ambiguous
- P2: rows are classified in this order: repeated header, empty quarter, unparseable count columns. The two irregular lines have an empty quarter and also non-numeric counts; they are counted as "empty quarter", and the overlap is reported separately. Empty strings and "NA" count as unparseable. Malformed geoid/quarter values and duplicate county-quarters would also be removed and counted (keeping the first duplicate); there are none in the synthetic data.
- P3: unused rows are reported both as a total and split into "county outside U" and "quarter outside range (county in U)".
- P4: the count of negative O1 `low_own` cells covers the whole balanced panel and is computed once.
- P6: Y3 averages each variable over the county's available years, ignoring missing values. AN01 and AN02 use controls as stored (no L transform).
- P7 with R2: the reference set is the counties of the estimated county sample (boundary, timing or decile) before missing-value drops. For AN07 this means the counties of the sample, not only those with address pairs. A blank R is treated as R1. Blank Y/L/Q/B/F/D/O would default to Y1/L1/Q1/B1/F1/D1/O1, but every grid row that uses these parameters supplies them.
- AN13 M2: R is blank in the grid, so quartile FE use reference set U. Deciles exclude counties with missing Y1 popdensity.
- P8: neighbours are taken as listed in each source county's row, not symmetrised. Source counties outside U are ignored.
- P9: a duplicate FIPS keeps its first row. Dates are read as Excel dates; text or serial values are parsed as a fallback.
- AN05 placebo: a county of U with no draw for the seed gets a missing placebo treat and is dropped. The number is logged per spec. For the permutation version, n is the number of treated counties in U.
- AN01: `err_mean` uses all of the county's pairs with both distances present. A t-test with too few observations gives NA. The "change in controls" variables are named `chg_<var>`.
- AN10: counties with missing treat are excluded. The cumulative mean is of the raw outcome, not logged.
- AN11: terms are `treat_x_<year>`. In influence mode all 9 terms are written for each removed county; for AN07 the focal term is `treat`.
- Influence mode: the design is built once from the full grid row, so quartile/decile groups, placebo vectors and samples stay fixed. Each refit only removes the rows of one county. Counties iterated over are those in the full-sample estimation sample.
