# Implementation notes

Implemented all specified analysis families, including team, season and game
influence deletions. The synthetic and sample stages do not fit empirical models.
The full stage first reruns the synthetic checks, then constructs all samples,
then runs the prescribed grid and additional analyses. Empirical fitting is
intentionally deferred in this session; empirical convergence is not yet known.

- The frozen grid is embedded in `code/samples.py` so runtime inputs are only
  the files in `data/` (besides the program itself). No downloaded inputs,
  package installations, prior outputs or published results are used.
- The manifest's explicit requirement for variants on individual-deviation
  cells is followed: U9a, U9b and U10a run for steps 1 and 2. The abbreviated
  step-2 text in grid.json only mentions ME0. N3 runs only for the origin.
- Auxiliary U7=1 fits supply origin benchmark results and U9a. They are tagged
  `auxiliary` and have their own `execution_id`. U9a rows retain the target
  cell's spec_id and identify the U7=1 source execution. Its SE is native only.
- Required spec_id strings recur at step 3. An additional execution_id appears
  in every related table to make joins unambiguous; duplicate_of is the first
  occurrence's spec_id and duplicate_of_execution_id points to that execution.
  Every scheduled step-3 fit is optimized again, including duplicates.
- Samples are identified before estimator-specific removal of constant-y
  strata. Estimation N and margin means exclude such strata for U7=0/2.
  The ID hash is SHA256 of lexicographically sorted UTF-8 game_id|integer-play_id
  lines, each with a trailing LF. Gzip CSVs include a header; hashes do not.
  sample_index.csv maps all 604 scheduled fits, including repeated cells, to
  samples without claiming that any empirical fit occurred in sample stage.
- sample_flow.csv reports all eight steps for every scheduled cell, including
  repeated cells, common-case dropped counts, each model's own complete-case
  count, and division disagreements on the common sample. Empty team strings
  are missing. Missing scores propagate to all performance terms. Home status
  follows the stated equality/otherwise-zero rule. Only needed play columns
  are loaded; the unused mixed-type goal_to_go column is never stacked.
- Exact conditional likelihood uses the coefficient of the case-count power
  in the Bernoulli probability polynomial after exponential tilting. A balanced
  product tree uses direct convolution for small polynomials and zero-padded
  FFT convolution for larger ones; reverse differentiation gives the score.
  This computes the exact conditional likelihood up to floating-point error,
  with no Breslow, Efron, saddlepoint, subset or tie approximation. Central
  differences of the analytic score give observed information. Internal QR
  scaling is transformed back to the original log-odds coefficients.
- Fit convergence requires score norm in information/SE units <1e-4. A failed
  covariance or unidentified model is recorded as failed; no pseudoinverse,
  ridge penalty or alternative regressor search is used. Nonconverged fits
  retain their estimates and are labelled. Failure messages propagate.
- N1 uses normal random-intercept ML with 20-point adaptive Gauss-Hermite
  quadrature, recalculating each mode and curvature at every parameter value.
  Scores include derivatives of the adaptive nodes and scale. Observed
  information includes the log standard deviation nuisance parameter. N1's
  fixed intercept is estimated; zero-group-effect margins omit it, as in ME0.
  log_sigma_team is explicitly labelled ancillary and has no odds ratio.
- N2 uses quarters_remaining internally in the minutes slot, including every
  interaction; output coefficient names and time_variable label that change.
- nonequiv.csv is a union of the prescribed spec/coefficient/margin/test
  formats, with run_id and record_type. N4 reports the U7=1 origin estimates
  with team-cluster CR1 SEs in benchmark columns (including marginal effects).
  algebraic_checks.csv similarly includes fitted coefficients and LL/contrast
  checks. Its extra fields give original/reparameterized LLs and coefficients.
- For season deletions only, absent season levels are structural aliases.
  The same season-factor column space is expressed using the earliest retained
  season as reference and only retained levels. This normalization preserves
  every estimable performance coefficient; it is not regressor selection.
- Grid and influence fits warm-start from available earlier fits of the same
  model/estimator, with named coefficient alignment. Influence deletions use
  the origin estimates and covariance when parameterizations agree. Every
  team, season and game is visited, even after previous failures. Influence
  native estimates are U7=0; benchmark SE/p values come from the companion
  U7=1 fit. Additional benchmark_estimate/status/error fields expose this
  distinction. No game deletions are skipped.
- The undocumented spread-reference and field-goal-range analyses listed as
  unavailable in grid.json are not executed, as specified.

Manifest items not implemented: none. Full-stage empirical outputs and their
numerical fit diagnostics have not been generated in this session.
