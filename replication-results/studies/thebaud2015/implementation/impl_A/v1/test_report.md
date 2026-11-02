# Test report for run.R on the synthetic files

All runs used `/opt/homebrew/bin/Rscript run.R synthetic <out_dir> <run_ids>` on `synthetic/gem_extract.csv` (26,400 rows, 165 surveys, 2000-2008) and `synthetic/country_year_inputs.csv` (264 rows). No raw data rows are printed anywhere. Output directories were kept outside the project directory.

## Runs executed and timing

| Run argument | Models fitted | Wall time |
| --- | --- | --- |
| `ORIGIN` | M1-M8, R1-R3 (11 fits) | 2.9 min |
| `U03,U15,U20,N01` | U03: M3, R1; U15, U20, N01: M3-M8 (20 fits) | 2.2 min |
| `influence:M4+M3` | 24 refits of M4 and 24 of M3 (48 fits) | 5.3 min |
| `U25,U23` | M5 (REML), M6 | < 0.5 min |
| `ORIGIN` (repeat with final script) | 11 fits | 3.4 min |
| `U03,U15,U20,N01` (repeat with final script, concurrently) | 20 fits | 2.6 min |

Total about 17 minutes, under the 25-minute limit. The repeats with the final script reproduce every estimate, standard error, wild-bootstrap p and sample hash of the earlier runs exactly (max absolute difference 0); the only change between versions is the `converged` flag, which no longer counts a boundary (singular) fit as non-convergence. The slow fits are the stage-1 logit models with about 6,500-9,600 rows (M2 31 s, R1 66 s, R2 52 s); stage-2 models take under 5 s each.

All 11 ORIGIN fits, all 20 deviation fits and all 48 influence fits returned `status = ok`; results.csv also contains the `WEIGHTED` not_estimable row. constants.json and session_info.txt were written for every run.

## Sample counts against the manifest rules

An independent recount (separate script, plain data.table, no shared code with run.R) of steps 1-5 gave identical numbers:

| Model | n_obs | countries | surveys | Independent recount |
| --- | --- | --- | --- | --- |
| M1, M2, M3, R1 (S1) | 6,579 | 24 | 111 | 6,579 / 24 / 111 |
| M4 (planb) | 365 | 24 | 107 | 365 / 24 / 107 |
| M5 (size), M6 (growth) | 372 | 24 | 107 | 372 / 24 / 107 |
| M7 (newprod, 2002-2008) | 332 | 24 | 96 | 332 / 24 / 96 |
| M8 (newtech, 2005-2008) | 179 | 22 | 51 | 179 / 22 / 51 |
| R2 (no step 3) | 9,634 | 24 | 111 | |
| R3 (S1 + skill, fear, knows) | 2,197 | 24 | 111 | |

Step-by-step counts (recount): roster rows 17,760 in 111 of the 143 roster surveys (the synthetic coverage is incomplete by design); after 18 < age < 55: 10,114; after employed = 1: 6,786; after complete cases on activity, female, postsecondary (61, 27, 121 rows missing respectively, survey variables complete): 6,579. Status carry-back was verified on a country with no NBSTATUS responses in 2000-2002 (value taken from the earliest later year with responses); no roster survey was left without a status value.

Other checks on the sample rules:

- Deviation samples move as expected: U03 M3 6,512 (activity from BSTART/SUWAGE), U03 R1 6,506 (nascent also complete); N01 M3 4,967 in 84 surveys and 23 countries (2001 and 2002 dropped; one country loses all its surveys); U15 and U20 keep the origin samples and hashes.
- Sample hashes are identical for models sharing a sample (M1/M2/M3/R1; M5/M6) and differ otherwise; the hash is order-independent and sorts integer ids numerically (checked against a hand-built string).
- Year dummies: M1-M6 produce year2002-year2008 (reference 2001); M7 year2003-year2008 (reference 2002); M8 year2005-year2007 (reference 2008); N01 produces year2004-year2008 with 2003 as fallback reference.
- Term names in results.csv are exactly the manifest names; wild_p is non-empty only for the four F x X terms of M5.

## M3 female:childcare against the generating value

Synthetic truth: female:childcare = -0.25, female = -0.5, intercept = -2.0, female:leave = 0.2, childcare = 0.1, female:parttime = 0.

| Term | ORIGIN estimate | SE | truth |
| --- | --- | --- | --- |
| (Intercept) | -1.994 | 0.155 | -2.0 |
| female | -0.646 | 0.119 | -0.5 |
| childcare | 0.091 | 0.061 | 0.1 |
| female:childcare | -0.323 | 0.097 | -0.25 |
| female:leave | 0.111 | 0.085 | 0.2 |
| female:parttime | 0.090 | 0.086 | 0.0 |

female:childcare is within one standard error of its generating value (z-distance 0.75); the other terms are within about 1.3 SE. Under U03, U15, U20 and N01 the estimate stays between -0.26 and -0.33, and across the 24 M3 influence refits it ranges from -0.37 to -0.29.

The random-effect SDs of M3 are estimated at zero (singular fit). A direct fit outside the script with the same formula reproduces this, and a fit with only female and the random effects gives SDs of 0.14-0.23 (generating values 0.1-0.3), so the collapse comes from the year dummies and survey-level covariates absorbing the small simulated variance, not from the extraction code. Under U20 (unstructured covariance) the survey-level SDs are 0.14 and 0.15, which confirms that the covariance branch and the VarCorr extraction for both random-effect structures work.

## Inference checks

- Native SEs and p-values are computed from the lme4 summary; benchmark SEs come from `vcovCL(type = "HC0", cadjust = TRUE)` and are smaller than the mixed-model SEs on the synthetic data, as expected for a pooled fit.
- The CR1 variance used inside the wild bootstrap was compared with `sandwich::vcovCL` on simulated clustered data: identical to machine precision.
- M5 wild-bootstrap p-values (999 Rademacher draws, seed 20261028) are larger than the asymptotic clustered p-values for all four F x X terms, as expected with 24 clusters, and are reproducible across repeated runs (identical values in the ORIGIN and U25 runs, which share the pooled benchmark).
- U25 changes the M5 routine to `lme4::lmer(REML=TRUE)` and the log-likelihood accordingly.

## Error handling

- Failed fit: `fit_one()` was called with an outcome containing values outside {0, 1}; it returned a single `status = failed` row with the glmer and glm error messages and the script continued (checked through a harness that loads the script's functions).
- Data-preparation failure: during development a bug in standardization raised an error inside run preparation; the script wrote one failed row per model with the message and still produced results.csv, constants.json and session_info.txt.
- Not estimable: a data file with a single roster survey makes every standardization SD undefined; the script writes `not_estimable` with the reason "empty estimation sample (standardization SD undefined or zero for: ...)" and continues.
- Convergence warnings are recorded in the `error` column (prefixed "warning:") with `converged = FALSE`; on the synthetic data M1 and M7 give lme4 gradient/iteration warnings and M5 is a boundary (singular) fit. These are left as the software default reports.

## Not covered by these tests

U01, U02, U04-U14, U16-U19, U22, U24, U26 and the influence runs for M5-M8 were not executed in the tests (the code paths are shared with the runs above: the settings switch, the sample builder and `fit_one()`); `all` was not run because of the time limit.
