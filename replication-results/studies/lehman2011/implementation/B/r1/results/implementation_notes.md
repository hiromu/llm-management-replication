# Implementation notes

All manifest items requested for this role are implemented. This session executes synthetic and sample only; real-data estimates are deliberately absent. The full stage runs synthetic validation before accessing real inputs, then the frozen grid and auxiliary runs.

## Explicit interpretations and implementation details

- The frozen grid is encoded in code/samples.R: origin, individual U1..U8 deviations (U8 only M1), then all 192 U1..U7 crossings with U8=0. U1 is the slowest varying axis. There are 604 grid fits. Duplicate cells are actually refitted. The mandated spec_id is unchanged; execution_id disambiguates repeated rows across tables. duplicate_of contains the earlier spec_id.
- Section 4 explicitly requests ME variants for origin and individual deviations, whereas the shorter compute_order text says ME0 for individual deviations. The detailed section 4 governs: ME0/U9a/U9b/U10a are run for both, and N3 only for origin. Full-crossing cells use ME0 only.
- U9a uses a U7=1 fit on the same common sample. Auxiliary source fits are documented in nonequiv.csv with run_id=U9a_source. Benchmark columns for conditional fits remain empty. U9a reports native inference only, as requested.
- nonequiv.csv and algebraic_checks.csv use a union of the specified table schemas, with record_type and run_id. N4 replaces benchmark columns with the team-cluster CR1 covariance. Its coefficients remain the U7=1 coefficients.
- Exact conditional likelihood uses an exponentially tilted Bernoulli dynamic program in code/exact.c, called from R, with a reverse pass for the exact score. This is algebraically the exact conditional subset likelihood, with no tie approximation. A C compiler shipped with the frozen R environment is used by R CMD SHLIB; source, binary and compiler log are placed under results/native/.
- Conditional optimization uses scaled, within-group-centered regressors and nlminb, followed by up to eight Newton refinements with backtracking. Positive-definite observed information and maximum absolute scaled score below 1e-4 certify convergence independently of the nlminb relative-step return code. Covariance is the inverse observed information from central differences of the analytic score (step 1e-5 on scaled coefficients), with no correction. Groups with invariant y are removed before fitting and estimation-sample means. Unconditional logit retains all groups.
- N1 uses 16-point adaptive Gauss-Hermite quadrature centered/scaled at each group posterior mode, normal-density normalization included, ML via nlminb, and observed numerical Hessian including the log-SD nuisance parameter. log_sigma is reported separately as a parameter; odds-ratio fields for it are empty.
- Rank-deficient regressors (especially absent-season dummies in influence runs) are retained in coefficient output as NA. A full-rank basis is fitted, and df/K count identified parameters. No substantive regressors are pruned. Conditional means and marginal effects use the identified parameterization.
- Sample hashes are SHA-256 of lexicographically sorted UTF-8 game_id|play_id lines, each terminated by LF, including the last. play_id is formatted without scientific notation. Compressed CSV rows use that order. Hashing uses the local sha256sum or shasum utility.
- sample_flow.csv has all S1-S8 counts for every grid cell (including repeated realised samples), S8_dropped, separate S8_M1/M2/M3 counts, CC discrepancy flags and alignment/div_game disagreement counts before CC. sample_cells.csv provides a compact cell-to-hash map. One common complete-case sample is used even for the U8-only M1 cell.
- Home field follows the literal home/else-zero definition; missing posteam_type is else zero. Missing flag values are not affirmative flags, and kick flags take priority on no_play. Complete cases use the derived variables required by the three models.
- N2 retains standard output term names, with minutes and its interactions interpreted as quarters remaining; minutes_eval contains quarters for this run. N1/N2/N4 also receive fit statistics, coefficient tables, ME0 and model tests.
- Influence deletions run every team and season, never game, per assignment. No influence warm starts are used. Additional benchmark_estimate/status/error/N columns identify the separate unconditional fit behind benchmark inference.
- Input-integrity audit in this session: all supplied data, docs, grid, manifest and prompt match input_manifest.sha256. Only the checksum index self-entry fails its own check; that supplied file was not modified.
- The unavailable spread-based reference and field-goal-range submodels are not run, as explicitly excluded by grid.json.
- Synthetic checks include an end-to-end miniature pipeline using generated data, written under results/synthetic_smoke/; these are clearly separate from empirical outputs. They do not invoke the full stage on real data.

## Run-specific notes

- Sample stage: 202 cells; 8 distinct realised samples; origin common sample 21540 rows. No real-data models are fitted by the sample stage.
