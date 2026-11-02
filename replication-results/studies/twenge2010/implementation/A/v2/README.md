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
| `code/TESTS.md` | test design and the recorded results (58 of 58 checks passed) |
| `code/probe.R` | optional helper that prints a compact summary of `results/*.json` |
| `results/<spec>.json` | one JSON per specification |
| `results/influence_<start>_<end>.csv` | influence-mode output (+ `.meta.json` with timing, the full-sample values, the full-sample n and V4 hash per group, and for every deletion the analysis n and V4 hash per group) |

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
(1976, 1991, 2006) then ascending V4 over the S00 multigroup analysis sample (total 7,807 respondents: 3,097 + 2,413 + 2,297).

## What each JSON contains

`spec_id`, `status` (ok / failed / unavailable) and `reason` (rules below); `problems` (every model failure or unavailable
quantity found in the output, with its location); `software` (R, package versions, full `sessionInfo()`);
`rows_read` per file; `estimation_options` and `conventions`; for every analysis sample its `n` and the SHA-256 of the
ascending newline-separated V4 list; `item_statistics` (4.6), `coefficient_alpha` (4.5), `single_group` (4.1) and
`multigroup` (4.2 fit indices and differences, 4.3 `latent`, 4.4 `contrasts`) as required by the grid; the lavaan syntax,
convergence record (status, iterations, objective, warnings, npar) and full parameter table (est, se, z, p) of every model;
and `deviations` (notes on choices the manifest leaves open). Numbers are written with full double precision (no rounding).
Factor, model, pair and variable names follow the manifest (K1-K7, C1, C2, M1-M5, P1-P3, V-names): CHK1 reports its
re-identified model under the ID `M4`, and S08 reports its one-factor model and alpha under the factor ID `C1`. Reversed
Form 3 indicators are named `V3222_r = 6 - V3222`, `V3223_r = 6 - V3223`, `V3227_r = 3 - V3227`.

Status rules (applied after every run by scanning the whole output, not only escaping exceptions):

- `failed`: an exception escaped, or any model errored or did not converge, or the fit indices of a fitted model could not
  be computed (and any block skipped for that reason). `reason` lists each problem with its location.
- `unavailable`: no failure, but at least one requested quantity could not be computed as specified and is recorded as
  unavailable with its reason; all other requested quantities are present. `reason` names the quantities.
- `ok`: every model converged and every requested quantity was computed.

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
- S04 (FIML) and S06 (MLR) use raw data; chi-square, baseline and (for S06) the scaled model chi-square come from lavaan.
  For S04 the SRMR uses the saturated-model (EM) moments as s_ij. For S06 lavaan's MLR defaults are used as the manifest
  states (`se = "robust.huber.white"`, `information = "observed"`, n normalization); robust z and p for the latent contrasts
  come from the sandwich covariance, and `fit_scaled` holds the scaled chi-square (value, df, p, scaling factor) of each
  model. The chi-square differences of 4.2 are the ordinary ML differences for every specification; no scaled difference
  tests are computed. All other specifications use expected-information standard errors.
- d_obs (4.4) is the SD (divisor n_g - 1) of the unit-weighted mean of the factor's items over every record of the
  multigroup analysis sample. Under S04 that sample contains records missing some of a factor's items, for which that mean
  is undefined, so d_obs is reported as unavailable (null, with the per-cell counts of such records in
  `observed_scale_n_incomplete` and the reason in `d_obs_availability`); no available-item means or complete-case subsets
  are substituted. The other 4.4 contrasts of S04 are unaffected.
- S05 implements the effects-coding constraints literally (loadings average 1 per factor; intercepts, including released
  ones, sum to 0 per factor and group), which changes the df of M4 and M5 relative to S00; this is reported, not altered.
- S01: records with invalid V5 are dropped (counts per file in `invalid_weights`); weights are normalized within each
  analysis sample to sum to its n; weighted covariances use divisor n - 1 with the normalized weights.
- Influence mode: the full-sample S00 M4 is fitted once; for each deletion the deleted group's moments are downdated exactly
  and M4 is refitted warm-started from the full-sample estimates. Failed fits are kept as rows with status and message.
  The CSV has exactly the 35 columns of Section 6; the companion `.meta.json` records the full-sample n and V4 hash per
  group (`full_sample`, identical to the S00 multigroup sample) and, per deletion (`deletions`), the deleted group and V4,
  status, the analysis n per group and the SHA-256 of the remaining V4 list per group.

## Runs performed on the supplied data

All twelve specifications completed and every model converged (`Rscript code/run.R all`, about 25 s). Eleven have status
"ok"; S04 has status "unavailable" because d_obs cannot be computed as specified on the FIML sample (see above); every
other S04 quantity (4.2, 4.3, the remaining 4.4 contrasts) is present.
lavaan post-check warnings are kept verbatim in each model's `convergence.warnings`; on the supplied data the only ones are
"covariance matrix of latent variables is not positive definite" for the S07a and S07b seven-factor models (the
re-assigned K6/K7 pairs have coefficient alphas between 0.02 and 0.39), which does not affect convergence or the fit indices.
Influence mode was run for deletions 1-20 (`results/influence_1_20.csv`): all 20 refits converged;
**mean time per deletion 0.17 s** (range 0.15-0.21 s) on this machine, so the full 7,807 deletions would take about 22 minutes.

## Deviations / unavailable items

One item is unavailable: d_obs under S04 (reason in `results/S04.json`, fields `multigroup.contrasts.d_obs_availability`
and `deviations`). Nothing was substituted. Choices that the manifest leaves open are recorded in the `conventions` and
`deviations` fields of each JSON (hash format, FIML SRMR moments, lavaan MLR defaults, S01 normalization details).

## Repair round 1 (changes to the previous version)

1. d_obs: unit-weighted mean of all of the factor's items over every record of the multigroup analysis sample, SD with
   divisor n_g - 1; no available-item means and no record exclusion. Under S04 it is reported as unavailable with the reason.
2. S06: `information = "observed"` (lavaan's MLR default, as the recorded explanation states) instead of the previously
   passed `"expected"`; the S06 robust standard errors, z and p changed slightly as a result.
3. Influence mode: the meta file records the full-sample n and V4 hash per group and, per deletion, the analysis n and
   V4 hash per group.
4. Specification status: model errors, nonconvergence, fit-index errors and unavailable quantities found anywhere in the
   output now set `status` and `reason` (rules above); the located problems are listed in `problems`.
5. Identifiers: CHK1 uses model ID `M4` (was `M4_CHK1`); S08 alpha and model use factor ID `C1` (was `S08_one_factor`).
6. S06: the Satorra-Bentler scaled difference tests were removed, and the scaled record of each model is reduced to the
   scaled chi-square (value, df, p, scaling factor); the ordinary differences of 4.2 are unchanged.
