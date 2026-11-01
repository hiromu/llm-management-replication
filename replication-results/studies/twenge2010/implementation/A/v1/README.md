# PAPER_X (manifest version 1) implementation

One parameterized R program (entry point `code/run.R` plus modules) that implements MANIFEST.md Sections 1-7
with R 4.6.1 and lavaan 0.7.3 (plus data.table and jsonlite). Nothing is installed; all documentation used was offline.

## Layout

| Path | Content |
| --- | --- |
| `code/run.R` | command-line entry point (spec / all / influence / test) |
| `code/lib_data.R` | constants (items, factors, markers, released items, pairs), data loading and coding, declared-missing weights, analysis samples, V4 hashes, (weighted) sample moments |
| `code/lib_models.R` | lavaan syntax generation for every model/identification, fitting wrapper, manifest fit indices, latent outputs (4.3), standardized contrasts (4.4) |
| `code/lib_stats.R` | item statistics (4.6), coefficient alpha (4.5), weighted variants (S01) |
| `code/lib_specs.R` | the specification grid S00-S08, CHK1, CHK2 and the JSON writer |
| `code/lib_influence.R` | influence mode (Section 6) |
| `code/test_synthetic.R` | synthetic-data tests with known parameters; writes `code/TESTS.md` |
| `code/TESTS.md` | test design and the recorded results (50 of 50 checks passed) |
| `code/probe.R` | optional helper that prints a compact summary of `results/*.json` |
| `results/<spec>.json` | one JSON per specification |
| `results/influence_<start>_<end>.csv` | influence-mode output (+ `.meta.json` with timing and the full-sample values) |

## How to run

Run from the project root (the directory that contains `code/`, `data/`, `dictionaries/`, `results/`).
`Rscript` is `/opt/homebrew/bin/Rscript`; `R --vanilla -q -f code/run.R --args ...` is equivalent.

```sh
Rscript code/run.R test                    # synthetic-data tests -> code/TESTS.md (about 2 minutes)
Rscript code/run.R spec S00                # one specification -> results/S00.json
Rscript code/run.R spec S02 S06 CHK1       # several specifications
Rscript code/run.R all                     # the whole grid (about 30 s in total)
Rscript code/run.R influence 1 20          # delete respondents idx 1..20 one at a time -> results/influence_1_20.csv
Rscript code/run.R influence 21 500        # next chunk -> results/influence_21_520.csv
Rscript code/probe.R S00                   # print a compact summary of a result file
```

Optional `--root=<dir>` points to a project directory other than the working directory.

Specification IDs: S00, S01, S02, S03, S04, S05, S06, S07a, S07b, S08, CHK1, CHK2.
The influence mode takes a 1-based start index and a maximum number of deletions; the deletion order is year group
(1976, 1991, 2006) then ascending V4 over the S00 multigroup analysis sample (total 8,004 respondents).

## What each JSON contains

`spec_id`, `status` (ok / failed / unavailable) and `reason`; `software` (R, package versions, full `sessionInfo()`);
`rows_read` per file; `estimation_options` and `conventions`; for every analysis sample its `n` and the SHA-256 of the
ascending newline-separated V4 list; `item_statistics` (4.6), `coefficient_alpha` (4.5), `single_group` (4.1) and
`multigroup` (4.2 fit indices and differences, 4.3 `latent`, 4.4 `contrasts`) as required by the grid; the lavaan syntax,
convergence record (status, iterations, objective, warnings, npar) and full parameter table (est, se, z, p) of every model;
and `deviations` (notes on choices the manifest leaves open). Numbers are written with full double precision (no rounding).
Factor, model, pair and variable names follow the manifest (K1-K7, C1, C2, M1-M5, P1-P3, V-names). Reversed Form 3 indicators
are named `V3222_r = 6 - V3222`, `V3223_r = 6 - V3223`, `V3227_r = 3 - V3227`.

## Implementation notes

- Estimation is normal-theory ML in lavaan on sample means and covariances (`likelihood = "wishart"`, unbiased S, c_g = n_g - 1
  for S00; `likelihood = "normal"`, S with divisor n_g, c_g = n_g for S02), expected-information standard errors,
  nlminb with `rel.tol = 1e-10`. The chi-square reported is sum_g c_g F_g evaluated with the manifest formula from lavaan's
  implied moments; it agrees with lavaan's chi-square to 1e-6 (checked in the tests and recorded alongside in `lavaan_fitmeasures`).
  df = G p(p+3)/2 - free parameters (after equality constraints). The baseline model (free means and variances, zero
  covariances, no cross-group constraints) has the closed-form F_g = sum log s_ii - log|S_g|; it equals lavaan's baseline.
  RMSEA, CFI, TLI and SRMR follow the manifest formulas exactly; the manifest SRMR coincides with lavaan's `srmr_bentler_nomean`.
- Models are generated as explicit lavaan syntax with labels for every parameter (`L_item`, `N_item`, `A_K`, `P_K`, `C_Ka_Kb`,
  `E_item`, with `_g1.._g3` suffixes for group-specific parameters); the syntax of every model is stored in the JSON.
  lavaan 0.7.3 parses a group vector that mixes numbers and labels as labels only, so for CHK1 the group-1 factor means and
  variances are fixed through the parameter table instead (recorded as `fixed_via_partable`).
- S04 (FIML) and S06 (MLR) use raw data; chi-square, baseline and (for S06) scaled statistics come from lavaan. For S04 the
  SRMR uses the saturated-model (EM) moments as s_ij. For S06 the scaled chi-square difference tests use `lavTestLRT`
  (Satorra-Bentler 2001) in addition to the plain differences.
- S05 implements the effects-coding constraints literally (loadings average 1 per factor; intercepts, including released
  ones, sum to 0 per factor and group), which changes the df of M4 and M5 relative to S00; this is reported, not altered.
- S01: records with invalid V5 are dropped (counts per file in `invalid_weights`); weights are normalized within each
  analysis sample to sum to its n; weighted covariances use divisor n - 1 with the normalized weights.
- Influence mode: the full-sample S00 M4 is fitted once; for each deletion the deleted group's moments are downdated exactly
  and M4 is refitted warm-started from the full-sample estimates. Failed fits are kept as rows with status and message.

## Runs performed on the supplied data

All twelve specifications completed with status "ok" and every model converged (`Rscript code/run.R all`, about 30 s).
lavaan post-check warnings are kept verbatim in each model's `convergence.warnings`; on the supplied data the only ones are
"covariance matrix of latent variables is not positive definite" for the S07a and S07b seven-factor models (the
re-assigned K6/K7 pairs have coefficient alphas between 0.02 and 0.39), which does not affect convergence or the fit indices.
Influence mode was run for deletions 1-20 (`results/influence_1_20.csv`): all 20 refits converged;
**mean time per deletion 0.17 s** (range 0.16-0.21 s) on this machine, so the full 8,004 deletions would take about 25 minutes.

## Deviations / unavailable items

No specification was unavailable and nothing was substituted. Choices that the manifest leaves open are recorded in the
`conventions` and `deviations` fields of each JSON (hash format, FIML SRMR moments, FIML d_obs over available items,
lavaan MLR defaults, S01 normalization details).
