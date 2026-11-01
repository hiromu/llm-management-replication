# Implementation manifest P01 (neutral, target-free), v1

You are implementing a pre-specified analysis of public NFL play-by-play data. The specification below is complete and frozen. Implement exactly what it says. Where something seems ambiguous, choose the most literal reading, write the choice in `results/implementation_notes.md`, and do not try alternatives that are not in the grid. There are no reference results to match.

Inputs in this directory:
- `manifest.md` (this file) and `grid.json` (the frozen grid of specifications; the axis and level codes used below are defined there).
- `data/pbp/play_by_play_{2000..2005}.parquet`: play-by-play, one file per season. `data/games/games.parquet`: one row per game. `data/alignment/team_season_alignment.csv`: conference and division of each team in each season.
- `data/dictionary/data_dictionary.md`: column definitions.
- `docs/`: software notes.

## 1. Sample construction (origin, U1..U6 = 0)

Apply in this order and record the row count after each step in `results/sample_flow.csv` (step, description, rows), for the origin and for every distinct realised sample.

1. S1. Stack the six season files. Keep `season_type == "REG"`.
2. S2. Keep `down == 4`.
3. S3. Decision rows. Origin: keep `play_type` in {punt, field_goal, run, pass}.
   - S3b (U1 = 1): also keep rows with `play_type == "no_play"`. Classify them as a non-attempt if `punt_attempt == 1` or `field_goal_attempt == 1`, otherwise as an attempt if `pass == 1` or `rush == 1`, and drop them otherwise.
   - S3c (U2 = 1): also keep `play_type` in {qb_kneel, qb_spike}, coded as a non-attempt.
4. S4. Keep regulation: `qtr` in {1, 2, 3, 4}.
5. S5. Terminal-time exclusion. Origin: keep `game_seconds_remaining > 120`. U3 = 1: keep `game_seconds_remaining >= 120`.
6. S6. Drop rows with an empty or missing `posteam` or `defteam`.
7. S7. Merge `games` on `game_id`, many-to-one; every row must match. Merge the alignment table twice: offence on (`season`, `posteam` = `team_abbr_pbp`) and defence on (`season`, `defteam` = `team_abbr_pbp`). Every row must match. Stop with an error if not.
8. S8. Complete cases. Drop rows with a missing value in any variable used by M1, M2 or M3 under the current grid cell, so one common sample is used for all three models of a cell. Record the count dropped. Record separately the rows each model would have used under model-specific complete cases. If that differs from the common sample, flag it.

Each sample row is identified by (`game_id`, `play_id`). For each distinct realised sample, write the sorted ID list to `results/samples/<sha256 of the sorted "game_id|play_id" lines>.csv.gz`, and reference that hash from each specification row.

## 2. Variables

All play-level values are pre-play (state at the snap).

- `y` (dependent): 1 if `play_type` in {run, pass} (S3b: the attempt class), 0 if `play_type` in {punt, field_goal} (S3b: the non-attempt class; S3c: kneel/spike).
- `d` = `posteam_score` − `defteam_score` − 1, using the pre-play score columns. Do not use the `_post` columns or the total home/away columns.
- `perf_below` = min(d, 0). `perf_below_sq` = perf_below². `perf_above` = max(d, 0). `below_indicator` = 1 if d ≤ 0, else 0.
- `minutes` = `game_seconds_remaining` / 60 (U4 = 1: floor of that).
- `perf_below_x_min` = perf_below × minutes; `perf_below_sq_x_min` = perf_below_sq × minutes; `perf_above_x_min` = perf_above × minutes.
- `total_points` = `posteam_score` (the offence's own pre-play points).
- `yards_first_down` = `ydstogo`. `yards_touchdown` = `yardline_100`.
- `same_division` = 1 if the offence and defence have the same `division` in that season (alignment table), else 0. Cross-check against `games.div_game` and report the number of disagreeing rows.
- `same_conference`: origin (U5 = 0) is 1 if they have the same `conference` in that season, else 0. U5 = 1 is 1 if same conference and not same division, else 0.
- `home_field`: origin (U6 = 0) is 1 if `posteam_type == "home"`, else 0. U6 = 1 is the same, except 0 for every row whose game has `games.location == "Neutral"`.
- `week` = `week` (integer, regular-season week, linear).
- `team` (grouping) = `posteam`. The play-by-play uses one abbreviation per franchise across all seasons, so use it as is.
- Season dummies: indicators for 2001-2005, with 2000 as the reference.

## 3. Models

The regressor lists are fixed and must not be changed:

- M1: total_points, yards_first_down, yards_touchdown, same_division, same_conference, home_field, week, minutes, plus the season dummies (U8 = 1 adds below_indicator).
- M2: M1 regressors + perf_below, perf_below_sq, perf_above, below_indicator.
- M3: M2 regressors + perf_below_x_min, perf_below_sq_x_min, perf_above_x_min.

Estimator by U7:
- U7 = 0 (origin): conditional (fixed-effects) logit with the exact conditional likelihood, grouped (stratified) by `team`, with the season dummies as regressors. This is the likelihood Stata's `xtlogit, fe` and `clogit` maximise. An approximate or Breslow/Efron tie method is not acceptable as the origin; if your routine offers several methods, use the exact one and confirm it on a small case against a direct computation. Groups whose y never varies contribute nothing and are dropped by the method; report how many.
- U7 = 1: ordinary logit by maximum likelihood with an intercept, `team` dummies (one omitted) and the season dummies.
- U7 = 2: conditional logit as U7 = 0 but grouped by `team` × `season`, with no season dummies.

Native covariance: the inverse of the observed (or expected) information matrix at the MLE; no clustering and no small-sample correction. For each coefficient report the estimate (log-odds scale), native SE, z and two-sided p. Also report the odds ratio exp(b) and its delta-method SE, exp(b) × SE.

Benchmark covariance (grid.json, benchmark_inference): on U7 = 1 fits only, a cluster-robust sandwich clustered by `game_id`, with the CR1 factor G/(G−1) × (N−1)/(N−K), where K counts all estimated parameters including the intercept and team dummies. Report the SE and two-sided normal p for each coefficient, and the number of clusters G.

Fit statistics for each fit: N, number of groups used, log-likelihood (LL), LL of the null model with the same groups and no regressors (for U7 = 0/2 the null conditional LL; for U7 = 1 the intercept-and-team-dummies-only model; label which), the LR χ² against that null, df, convergence status and iterations.

Tests:
- LR test of M2 against M1, and of M3 against M2, on the same sample: statistic, df, p.
- Wald test (native covariance) of perf_below = perf_above in M2 (1 df).
- Wald test that perf_below, perf_below_sq, perf_above and below_indicator are jointly zero in M2 (4 df).

## 4. Marginal effects (M2 and M3)

Evaluation grid: d ∈ {−42, −28, −14, 0, 14, 28, 42}. M2 uses one setting with minutes at its estimation-sample mean. M3 is evaluated separately at minutes ∈ {53, 38, 23, 8}; in M3 the interaction regressors are formed from these minutes values.

ME0 (origin). Build the covariate vector. Every regressor other than the performance terms, minutes and the interactions is set to its estimation-sample mean, and that includes the season dummies. For U7 = 1 fits, leave out the intercept and team dummies (the group effect is set to zero), so all estimators use the same index without group effects. Set the performance terms from d. At d ≤ 0 set below_indicator = 1, perf_below = d, perf_below_sq = d², perf_above = 0. At d > 0 set below_indicator = 0, perf_below = 0, perf_below_sq = 0, perf_above = d. Let p = 1/(1 + exp(−xb)). The marginal effect is dp/dd = p(1 − p) × ∂xb/∂d, where ∂xb/∂d = b_below + b_below_x_min·m + 2·d·(b_below_sq + b_below_sq_x_min·m) for d ≤ 0, and b_above + b_above_x_min·m for d > 0 (for M2, drop the interaction terms). At d = 0 use the d ≤ 0 branch. Report p, the effect, its delta-method SE using the native covariance, the z, and the two-sided p. For U7 = 1 fits, also report the delta-method SE and p using the benchmark covariance.

Variants, run for the origin cell and the individual-deviation cells only:
- U9a. Use the U7 = 1 fit of the same cell. For each team j compute the ME0 derivative with the intercept plus team j's effect added to xb; the reference team's effect is 0. Report the unweighted mean over teams, with a delta-method SE (native covariance).
- U9b. As ME0, but report p(d + 1) − p(d) instead of the derivative.
- U10a. At d = 0 only, use the d > 0 branch (below_indicator = 0, slope b_above (+ b_above_x_min·m)).
- N3 (origin cell only). Average marginal effect: for each sample observation, set d (and, for M3, minutes) to the evaluation value, keep that observation's other regressors, set the group effect to 0, compute the derivative, and average over observations.

## 5. Non-equivalent runs (origin cell only)

- N1: random-intercept logit by `team` (normal random effect, ML with adaptive Gauss-Hermite quadrature of at least 12 points, or a documented equivalent), season dummies, M1-M3.
- N2: replace minutes with `quarters_remaining` = 5 − `qtr` everywhere (main effect and the three interactions), M1-M3, U7 = 0. For M3 marginal effects use quarters_remaining ∈ {4, 3, 2, 1} in place of the minutes values.
- N4: on the origin U7 = 1 fits, a cluster-robust sandwich clustered by `team`, with the same CR1 factor.

## 6. Algebraic checks

- K1: M3 (origin, U7 = 0) with `elapsed` = 60 − minutes replacing minutes in the main effect and all three interactions. Report the LL difference from the origin M3.
- K2: M2 (origin, U7 = 0) with home_field replaced by 1 − home_field. Report the LL difference and both coefficients.

## 7. Execution order

Follow grid.json compute_order. In step 3, a combination that equals an earlier cell is still fitted, and flagged `duplicate_of`. Do not skip, prune or reorder cells according to their results. A failed fit is recorded with status and error message, and execution continues.

## 8. Output files (all in `results/`)

- `specs.csv`: spec_id, step, model, U1..U8, me_variant_set, sample_hash, status (ok/failed/not_converged), error, n_obs, n_groups_used, n_groups_dropped, loglik, null_loglik, null_label, lr_chi2, df, converged, iterations, routine (exact function and options), duplicate_of.
- `coefs.csv`: spec_id, model, term, estimate, se_native, z_native, p_native, or, or_se, se_bench, p_bench, n_clusters_bench.
- `margins.csv`: spec_id, model, variant (ME0, U9a, U9b, U10a, N3), minutes_eval, d, prob, effect, se_native, p_native, se_bench, p_bench.
- `tests.csv`: spec_id, test, statistic, df, p.
- `nonequiv.csv` and `algebraic_checks.csv`, in the same column formats with an added run_id.
- `influence.csv`: unit_type, unit_id, model, term, estimate, se_native, p_native, se_bench, p_bench, n_obs, status, error (section 9).
- `sample_flow.csv`, `samples/`, `implementation_notes.md`, and `environment.txt` (language and package versions, OS, start and end times).

spec_id format: `<model>|U1=a|U2=b|U3=c|U4=d|U5=e|U6=f|U7=g|U8=h`.

## 9. Influence deletions (origin cell, M2 and M3)

For each deletion unit, refit the origin M2 and M3 (U7 = 0), plus the U7 = 1 fit for the benchmark columns, on the origin sample minus that unit. Record perf_below, perf_below_sq, perf_above and below_indicator (both models), plus the three interactions (M3). Every unit is run; none is skipped because of its result.

- `team`: each of the offensive teams in the sample, deleting all plays where it is `posteam`.
- `season`: each season.
- `game`: each `game_id` in the origin sample, deleting all plays in that game. Your role assignment says whether you run the game unit.

Record failures with reasons. If you warm-start from the full-sample estimates, say so in the notes.

## 10. Rules

Use only the files given. No network access. Write one parameterised script (plus small helpers if needed) that produces every output from the raw files. Before the empirical run, check the estimators on synthetic data you generate, with known parameters, and on a small case where the exact conditional likelihood can be computed directly. Save that check as `results/synthetic_checks.md`. If something cannot be done, record why in `implementation_notes.md` and continue with the rest.
