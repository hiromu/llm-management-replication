# Responses to the unmet items (manifest PX01)

All eleven listed items were accepted as genuine departures from the manifest and fixed in `output/analysis.R`. None was judged wrong. Line numbers below refer to the original script in `input/code/analysis.R`.

On the synthetic data with `--boot 200` the repaired script writes the same 12,710 result rows, 7,362 influence rows and 1,052 sample rows as before, with zero failures. The only value changes are last-digit floating-point differences in a few `d` effect sizes (sd squared instead of var). The synthetic files have no blanks on any model variable, so the complete-case and bootstrap-pool changes cannot show up there; they were verified on perturbed copies of the data instead.

## 1. Each quantity uses complete cases on its own variables (lines 608-609, 620-621, 629-631, 963-975)

Accepted. The path models used one listwise sample over every variable in the model, so `a` (mediator on condition) and `total` (outcome on condition) were estimated on fewer rows than their own variables allow. Now every regression in PM2, SI2, SM2 and MED4 is fit on complete cases of its own variables: `m` on `cond` for `a`; `o` on `cond` and the mediators for `b` and `c_prime`; `o` on `cond` alone for `total`; the three serial-model regressions each on their own variables; and in dataset 4 each mediator on X, and `Signed` on X and the mediators. Products and delta standard errors combine the resulting coefficients. The leave-one-out PM2 refits use the same rule. Consequence: `total` no longer equals `c_prime` plus the sum of the indirect effects when the outcome and mediators have different missingness. Bootstraps now resample the retained rows of the sample level, and each resample applies the same per-regression complete-case rule, so the resampled statistic is the same estimator as the point estimate.

## 2. A composite is missing if any item is missing, also under `existing` (lines 123-124)

Accepted. The manifest's rule is stated for composites in general, not only for the ones the script computes. `composite()` now sets the composite to missing wherever any item is missing under all three levels, including the deposited column under `existing` (and `LoyaltyHouse` in dataset 4).

## 3. Pearson correlation rejected two complete pairs (lines 139-142)

Accepted. The minimum is now two pairwise complete cases. The correlation fails only when it is undefined, that is when a variable has zero variance on the complete pairs, with that reason.

## 4. Cronbach's alpha rejected two complete rows (lines 145-151)

Accepted. The minimum is now two complete rows on the items. Alpha fails only when it is undefined (fewer than two items, fewer than two complete rows, or an item sum with zero variance), with that reason.

## 5. Bias-corrected interval with infinite z0 (lines 245-249)

Accepted. The bounds are now always the resample quantiles at `pnorm(2 z0 - 1.96)` and `pnorm(2 z0 + 1.96)` exactly as written. When every resample falls on one side of the estimate, z0 is infinite, the probabilities are 0 or 1, and both bounds are the minimum or maximum resample. Verified in isolation.

## 6. Bootstrap discard count lost with fewer than two successes (lines 244, 265-273)

Accepted. `run_boot` now returns the discard count separately from the interval quantities. `boot_failed` is reported whenever the resampling loop ran, including when no resample succeeded (all interval quantities fail with "no successful resamples"), when exactly one succeeded (only `se_boot` fails), and when the point estimate itself failed (the interval quantities carry that reason, the count is still written).

## 7. One row per quantity; do not stop on one failure (lines 93-97, 1014-1022; empty samples at 415-416, 593-594, 807-808, 933-934)

Accepted. Two changes. First, the required set of result rows is registered before any data is touched: each dataset's analysis routine is run once in a dry mode on an empty table, which enumerates every (dataset, sample level, composite level, key, method) combination without computing anything; the key set is fixed by the manifest and does not depend on the data. After the real run, any registered row that is absent is written as failed with the reason (an unreadable file, or the error that stopped the block), and the output is ordered by the registry. The single `DATASETk.read` / `DATASETk.analysis` / `DATASETk.influence` rows are gone, since they were not quantities. Influence rows are registered the same way per sample level once the retained units are known. Second, the sample registration no longer throws on an empty retained sample (`data.frame` with a zero-length unit vector was the error), so an empty sample level produces its full set of rows: counts such as `N2.n` are 0 with status ok and everything else fails with a reason. Verified by removing `dataset_1.csv` (all 1,896 dataset-1 rows present and failed with the read error) and by making every `comp2` check fail (empty `D2_any`).

## 8. Quantities computed independently of failures in neighbouring quantities (lines 364-375, 540-547, 780-798, 819-822)

Accepted. `paired_stats`, `group_stats`, `contrast3`, the cell descriptives, the gender descriptives and the age descriptives now compute each quantity inside its own guard. A quantity that cannot be computed is carried as an error object with its reason and derived quantities inherit that reason; the rest are written normally. Examples now handled: a paired count `n` of 0 or 1 is reported while the test fails; group means are reported when a group has one observation or when the HC3 test fails; `C3.cell.o.cell.n` is 0 for an empty cell while its mean and sd fail; `mean_diff`, Student, Welch and the two-cell effect sizes are reported when the four-cell model is not estimable.

## 9. A3 did not reject rank-deficient four-cell designs (lines 750-774)

Accepted. `anova3` now requires exactly two observed levels per factor and all four cells non-empty, and checks the rank of the sum-to-zero design. Otherwise every A3 quantity for that outcome fails with "four-cell design is rank deficient: at least one cell is empty" (or the level-count reason). With the full design every term has one degree of freedom and the error df is N minus 4, as before.

## 10. C3 pooled contrasts must use the full four-cell MSE with df = N - 4 (lines 786-794, and 857 for influence)

Accepted. The pooled method and `p_hc3` now fit the four-cell indicator model on all four cells. If any cell is empty the four-cell model is not estimable and these quantities fail with "four-cell model not estimable; empty cell(s): ..." instead of silently fitting fewer cells with a larger df. The leave-one-out contrasts use the same function, so an influence refit that empties a cell is written as failed with that reason.

## 11. Leave-one-out failures must carry status failed and a reason (lines 57-62, 503-504, 700-701, 858-859, 1000-1001)

Accepted. `add_infl` now receives the estimate and p as values or error objects. A row is failed when either is an error (with its message) or when either is missing or not finite ("estimate or p is missing or not finite"). Whatever part is finite is still written. Verified on an eight-row copy of dataset 4 and on dataset 3 with a cell removed: no influence row has status ok with a blank estimate or p.
