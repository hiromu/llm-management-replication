# PAPER_X implementation

`code/analyze.py` implements the manifest in Python with NumPy/SciPy, including all twelve named specifications and the separate deletion-influence mode. It accesses inputs and writes outputs only within this assignment directory. No software installation, web access, R, or assistance from another model was used.

Run these commands from this directory with the specified interpreter:

```sh
~/.venv/bin/python -I code/analyze.py test
~/.venv/bin/python -I code/analyze.py run S00
~/.venv/bin/python -I code/analyze.py run all
~/.venv/bin/python -I code/analyze.py influence --start 0 --limit 3
```

`run` accepts `S00`, `S01`, `S02`, `S03`, `S04`, `S05`, `S06`, `S07a`, `S07b`, `S08`, `CHK1`, `CHK2`, or `all`. It writes `results/<spec_id>.json`, replacing an existing result for that specification. `test` writes `code/TESTS.md` and `code/synthetic_tests.json`; it does not read supplied data. The first synthetic test run completed before the first supplied-data run. Tests were rerun after numerical refinements.

Influence indices are **zero-based**. Rows are ordered by ascending year and numeric V4. The filename uses inclusive endpoints: `--start 0 --limit 3` writes `results/influence_0_2.csv` plus a JSON metadata file containing timing, versions, full-fit convergence, and sample hashes for every deletion. A limit extending beyond the sample is clipped at its end; a start outside the sample is rejected. The program supports arbitrary chunk sizes; only five deletions were executed for this assignment, below the allowed maximum of twenty. Each refit starts from the full-sample S00 M4 estimate. Sample moments are recomputed exactly from the remaining raw records. Failed fits retain their CSV row and error message.

## Estimation and recorded conventions

The program uses an affine parameterization of all loading, intercept, mean, and covariance restrictions. It minimizes the exact manifest likelihood with analytic first derivatives. L-BFGS-B uses `ftol=1e-13`, `gtol=1e-8`, and at most 12,000 iterations; up to 200 Fisher-scoring refinements check stationarity after optimizer stopping. The outputs report the final gradient, optimizer message, iteration counts, elapsed time, convergence, and model admissibility separately. Final supplied-data fits all have maximum normalized absolute gradient below `1e-8`.

Expected normal-theory information includes derivatives of both implied means and covariances and the specified group coefficients. Singular information is an error; it is not silently replaced by a pseudoinverse. Latent contrast SEs use the complete parameter covariance, including cross-group covariance terms. Fit indices, differences, alpha, item statistics, and all five effect-size variants follow the manifest formulas. Internal and serialized numerical values are not rounded. JSON uses `null` for nonfinite quantities; associated model errors or inadmissibility warnings identify failures.

All factor covariances and residual variances are unconstrained, as in ordinary unbounded ML CFA; the implied observed covariance must be positive definite for likelihood evaluation. Negative residual variances and non-positive-definite factor covariance matrices are explicitly flagged. A top-level `ok` means computation completed, not that the model fits well or has admissible parameter estimates.

S01 validates V5 against each file's dictionary, including declared missing ranges, and reports dropped counts. It renormalizes weights separately for each analysis sample. The weighted model and alpha covariance uses normalized weights and divisor `n-1`; weighted item SD uses the separately specified unbiased weighted denominator. Weighted item comparisons report the requested approximate normal test in place of Student/Welch tests.

S04 evaluates the observed-data normal likelihood by missingness-pattern sufficient statistics, which is algebraically identical to evaluating each raw record. The unrestricted saturated normal model is fitted by EM for the likelihood-ratio statistic. Baseline means and variances use all available observations on each item. Where the manifest does not specify missing-data descriptive conventions, SRMR uses the unrestricted saturated ML covariance, and an observed factor composite is defined only when all its items are present. Its SD uses the defined scores and divisor `n-1`; `d_obs_samples` supplies those additional sample counts and hashes. No missing values are imputed for observed composites. FIML expected information sums the observed-variable information over missingness patterns.

S05 enforces the loading average and intercept sum constraints exactly, including released intercepts. A null-space parameterization removes redundant intercept-sum equations. Consequently partial-scalar effects coding has additional constraints compared with marker-identified M4; the program preserves them as written, rather than forcing numerical equivalence between S05 and S00.

S06 uses `n`-normalized ML point estimates and a Huber-White sandwich: the bread is the observed normal-likelihood Hessian and the meat is the sum of individual score outer products. The Hessian is obtained by central differences of the analytic gradient, with step `1e-4 * max(1, abs(parameter))`. It reports the Yuan-Bentler Mplus-style T2* scaled statistic using the difference of saturated and restricted information-score traces divided by df. The formula, traces, scale, scaled p value, and raw statistic are saved. The other requested fit indices and likelihood differences use the unscaled manifest formulas; no unrequested scaled difference test is substituted. This is a custom implementation; no comparison against an R/lavaan executable was available or performed.

CHK1 uses zero 1976 means and unit 1976 factor variances with all loadings free and shared. CHK2 uses the specified alternate markers. The alternate seven-factor groupings use the first listed item as marker. The single-indicator C2 loading is 1 and its residual variance is 0. Form 3 reversals affect only factor and alpha analyses; item statistics retain native coding.

Sample hashes use numerically ascending V4, integer values without a `.0` suffix, UTF-8 newline separators, and **no terminal newline**. Every model and descriptive analysis includes its sample n and hash. Every result includes all six input row counts, software versions, conventions, and a deviations field. Forms are never combined.

## Validation and completed runs

The synthetic tests in `code/TESTS.md` cover known-parameter recovery, analytic likelihood and moment derivatives, expected-information SEs, alternate identification and markers, effects-coding constraints, complete-data FIML equivalence, missing-data FIML recovery, weighted moments, robust covariance, and exact deletion moments. All twelve tests passed. They use a seeded three-group, five-factor model with known loadings, intercepts, means, covariances, and group-varying released intercepts.

All twelve specifications were run successfully. Results are in `results/S00.json` through the named grid outputs; `results/grid_run.log` records execution. The initial S00 attempt exposed a numerical initialization issue in two-indicator factors; it was resolved by nonzero starting factor covariances and safeguarded refinement without changing any model restrictions. Final S00 results supersede that initial attempt.

S00 multigroup sample sizes are 3,097 (1976), 2,413 (1991), and 2,297 (2006). All requested computations are available, with no omitted specifications. S07a and S07b converge but have non-positive-definite factor covariance estimates in all three years; their JSON files retain and flag those estimates. The missing-data descriptive choices above are recorded defaults for operations not fully specified in the manifest.

Influence smoke test: five successful deletions, covering all three groups (indices 0–2, 3097, and 5510). Mean time per deletion was **0.084837 seconds**, excluding full-sample fitting and file loading. Individual timings in seconds were `[0.024741207977058366, 0.16875670800800435, 0.09957541699986905, 0.10696079200715758, 0.024150208017090335]`. Each chunk’s JSON records full-precision timing and total runtime, including setup. Timing depends on hardware and deleted record.
