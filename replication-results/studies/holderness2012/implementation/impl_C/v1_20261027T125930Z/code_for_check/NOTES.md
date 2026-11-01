`run.py` implements manifest P-R7M2 v1 and all 21 specifications in `grid.json`. It uses only the supplied files and installed Python packages. No internet access or package installation was used. No manifest model family is left unimplemented.

Use the specified interpreter. A controlled full run can be started with:

```sh
~/.venv/bin/python -I run.py --grid grid.json --data data --out controlled_results --specs all --influence all
```

This command is provided for the later controlled run; it was **not executed** during implementation. `--specs S000,S003` selects any subset. Specs are processed with S000 first, then in ID order, with families in grid order and influence last. `--influence first20` selects the 20 smallest camp codes separately within each T4 estimation sample; `none` skips influence. The default influence scope is `none`.

The authorized empirical smoke run was:

```sh
~/.venv/bin/python -I run.py --grid grid.json --data data --out results --specs S000 --families T4 --influence none
```

Only S000 T4 was fitted on real data. Its eight models all converged. Other specifications were checked only through sample and variable construction, using `--construct-only`. All model families were additionally exercised on generated synthetic data. The final empirical CSV files contain only the eight authorized models, and `roc.csv` and `influence.csv` have headers but no empirical rows.

`--families` is an optional restriction within each spec's grid-listed families, added to make the authorized T4 smoke run possible. Selecting T5ROC also includes its T4/T5 prerequisites; selecting influence also includes T4. Without this flag, all families listed for the selected specs are executed. `--construct-only` retains sample construction, hierarchy construction, and missingness diagnostics but performs no fits.

Outputs are written directly under `--out`: `results.csv`, `roc.csv`, `influence.csv`, `sample_ids/`, and `run_log.txt`. Use a fresh output directory for a new controlled run: CSVs and the log are overwritten, while unrelated existing sample-ID files are not deleted. Model IDs encode family, group, model level, hierarchy, and any friends variant. Influence refit sample-ID files append `__delete_<camp>`. IDs are numeric `record_seq` values sorted in ascending order. CSV missing numeric values are empty or `nan`. Intercepts have coefficient estimates and standard errors but no marginal effect. Omitted regressors retain a row identifying why they were omitted. Failed fits receive `status=failed`, `converged=False`, an error, and an attempted-sample ID file; subsequent fits continue.

The implementation reads 16 POW columns and 11 enlistment columns. Enlistment data are scanned in batches of 131,072, matching serial numbers before retaining and cleaning the other fields. The input has 143,374 POW records and 9,200,232 enlistment records; only 74,210 matching enlistment records were retained. Duplicate handling never expands POW rows. The supplied origin sample has D=124,387 and R=101,993. Of R, 57,659 records link under the origin duplicate rule. Captured-cohort models remove 1,321 rows in 178 camps with constant survival, leaving 100,672 observations, 163 camps, and 1,674 captured cohorts. Camp-cohort models use 101,993 observations in 341 camps.

The estimator maximizes the unpenalized probit likelihood using stable log-normal probabilities, analytic scores, RMS column scaling, L-BFGS initialization, and Newton refinement. Coefficients and covariance are returned to the original regressor units. The sandwich uses the inverse observed information, cluster sums of individual scores, and exactly G/(G−1); there is no additional N/K correction. Delta-method gradients are analytic. Binary changes hold every other regressor, including interaction columns, at its estimation-sample mean. Continuous derivatives likewise treat interaction products as separate regressors. Null log likelihood is from an intercept-only model on the actual estimation rows. Ill-conditioned information, detected complete separation, nonconvergence, or insufficient clusters produce recorded fit failures, without regularization or a substitute estimator.

Implementation choices and manifest ambiguities, with line references:

- **Lines 20–21:** Camp validity follows the literal three-character rule, without an added numeric-only requirement. Invalid dates give missing length even when the camp sample is permitted to retain them. Negative valid lengths are retained. Captured-cohort keys distinguish camp, year, and month.
- **Lines 31, 45, 73, 86–96:** Group members and reference fractions are computed from the specified prefit R (or column-specific R when `sample_common=false`). Whole-camp perfect-prediction removal occurs immediately before each fit. Removing an entire camp does not change hierarchy in retained camps. Robustness and influence restrictions retain their precomputed group variables, as specified. When regression reference fractions and column-specific samples are combined, each group type uses its own R. This combination is supported even though the supplied one-at-a-time grid does not combine those deviations.
- **Lines 37–40:** “Removing spaces from both sides” is interpreted as removing space characters from both compared GRADE_ALPHA labels, including internal spaces. NULs and outside whitespace are removed first. Duplicate normalized labels use the first table row, including when that row maps to missing. GRADE_CODE is otherwise compared exactly; leading zeros are not stripped.
- **Lines 46–48:** Undefined ratio sameness when a reference share is zero, or undefined normalizations when a denominator is zero, are missing. No pseudocount, clipping, or alternate denominator is introduced. Zero-member groups have all hierarchy measures and group size missing. The rank-count implementation of Steepness is algebraically equivalent to the specified sorted-member formula.
- **Lines 52, 60, 71:** Constants cannot be estimated separately from the intercept, so all constant columns are omitted and identified in the output. The manifest does not specify handling of exact collinearity: columns are retained in the stated model order, with later aliases dropped using a normalized QR/reorthogonalization tolerance of 1e-10. In the origin full models, hierarchy, men, and men-squared missing indicators coincide, so the latter two indicators are marked `omitted_collinear`. Products are formed before zero imputation and receive their own missing indicators where needed.
- **Line 57:** Crosswalk `entry_id` is not purely numeric: it includes `359a`, `359b`, `510a`, and `510b`. “Lowest entry_id” is implemented by stable lexicographic order among eligible rows for the same camp. Unknown-confidence rows are ineligible. Degree-text parsing accepts whole nonnegative degrees separated by a hyphen; a nonblank but unparsable string is missing, while absent text uses crosswalk coordinates. The capital-name override is applied after coordinate selection.
- **Line 67:** Duplicate `combine` operates field by field on cleaned raw enlistment fields, before interpreting CARD_NUM; it does not combine already-derived covariates. If duplicate CARD_NUM values conflict, the combined value is missing and the literal “else HEIGHT”/ordinary-layout rule applies. Exact matching includes blank serial strings, with the same duplicate rule, because the manifest specifies no exclusion for blank identifiers. The supplied enlistment matches contain no blank serials, so this last choice does not affect the delivered empirical results. Only enlistment SER_NUM receives the specified `#` replacement.
- **Lines 71, 73, 75:** The lowest camp code is the omitted fixed-effect category. Camp dummies are binary regressors, so their reported marginal effects use discrete changes, holding all other dummies at their sample means. The explicitly named binary terms (japan, dependents, officer, and missing indicators) also use discrete changes. The requested secondary camp-cluster results occupy the two marginal-effect columns in the prescribed output schema; no extra coefficient covariance columns are added.
- **Line 84:** ROC rows identify the omitted term and reduced-model ID. Comparisons require identical ordered record IDs and converged paired fits. DeLong uses tie-aware placement values with sample covariance denominators n−1. Identical predictors have z=0 and p=1. A zero-variance nonzero AUC contrast has signed infinite z and p=0; fewer than two observations in either outcome class produces a failed comparison.
- **Lines 86, 94 and grid S020:** The grid explicitly requests R_friends with the changed friends definition in S020; this takes precedence over the general phrase “origin parameters” for robustness families. Unit is the literal concatenation of the three cleaned component strings, missing only when all three are blank. Friend counts use the rank-eligible group-member definition in line 31. “Others” subtracts the row only if it belongs to that member set; a row with missing rank was not counted in the first place. Zero eligible same-unit members give missing log count. Unit-specific hierarchies use the original reference fractions, and the other group covariates retain their original group values.
- **Line 100:** Failure rows use term `__model__` when no fitted coefficient table is available. Output schemas otherwise match the manifest. No significance cutoff or post-fit model selection is applied.

Synthetic validation is built into `run.py` and runs before any empirical fitting. To repeat just these checks:

```sh
~/.venv/bin/python -I run.py --self-test
~/.venv/bin/python -I run.py --integration-test
```

The first command saves `tests/synthetic_results.json` and `tests/synthetic_results.log`. The reproducible seed is 742019. All five mandatory statistical checks passed:

| Check | Result |
| --- | --- |
| Known-coefficient probit, N=60,000 | Truth (−0.25, 0.70, −0.45); estimates (−0.253643, 0.699402, −0.455805); maximum absolute error 0.005805, below tolerance 0.035 |
| Marginal effects and delta-method finite differences | Maximum effect error 4.16e−12; Jacobian error 2.02e−7; standard-error error 5.33e−10 |
| Cluster sandwich, 12 observations / 4 clusters | Maximum absolute difference from direct sandwich 1.11e−16, using correction 4/3 |
| Handmade rank groups | One-rank Steepness 0; reference-matched Sameness 1; ranks {1,9} Steepness 0.4; empty group missing |
| DeLong identical predictors | z=0 and p=1; a second tied-score comparison matches a direct pairwise-kernel calculation |

Additional checks cover family fit counts, string cleaning, duplicate linkage, repeated POW serials, and blank-string matching. The integration command uses seed 92741 and 15,949 generated POW records with synthetic covariates and locations. It exercises all 104 origin fits, 10 friends-others fits, 8 correlated ROC comparisons, and 96 camp-deletion refits. All expected fits and comparisons passed. An intentional empty-sample failure is recorded, and the following fit succeeds; constant-survival camp removal, friends-member subtraction, and sorted unique sample-ID files are checked. See `tests/integration_summary.json`, `tests/integration_console.log`, and `tests/integration_results/`. These are synthetic outputs and are separate from `results/`.

`construction_check/run_log.txt` records successful sample and variable construction for every supplied spec, with no fitting. `tests/s000_t4_console.log` and `results/run_log.txt` record the authorized empirical smoke run. No empirical T5, T6, robustness, ROC, or influence models were run.

Observed elapsed times on this machine, including design construction, covariance, marginal effects, and writing each fit, were approximately:

| Fit type | Seconds per fit |
| --- | ---: |
| Captured cohort, simple | 1.4 |
| Captured cohort, full | 9.1 |
| Camp cohort, simple | 0.09–0.10 |
| Camp cohort, full | 0.35–0.39 |

The eight T4 fits took about 22 seconds together, plus about 5–6 seconds to scan and link the inputs and about a second for sample construction and validation. These are measured smoke-run timings, not full-grid measurements. The grid contains 266 regular fits before influence. A rough planning estimate is 10–20 minutes without influence on similar hardware; family-specific collinearity and convergence may change this substantially. Origin influence comprises 4×163 + 4×341 = 2,016 refits for `all`, or 160 for `first20`. Extrapolating the observed T4 costs gives roughly one additional hour for all influence refits or about 7–8 minutes for first20. Every fit logs its actual runtime for the later controlled run.
