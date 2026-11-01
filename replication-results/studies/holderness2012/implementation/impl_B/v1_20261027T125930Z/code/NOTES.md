`run.R` implements all 21 specifications and every model family in the supplied grid. It uses only R 4.6.1, base/stats, data.table 1.18.6.1, nanoparquet 0.5.2 and jsonlite 2.0.0. No packages were installed, no internet access was used, and the supplied inputs were not modified. There are no omitted model families. The full empirical grid was **not run**.

The normal invocation is:

```sh
/opt/homebrew/bin/Rscript run.R --grid grid.json --data data --out results_full --specs S000,S001 --influence none
```

Use `--specs all` for the complete grid in the later controlled run. Use `--influence all`, `first20`, or `none`; the default is `none`. Specs run in ID order, families in grid order, and influence last. T5ROC uses the cached T4/T5 predictions and verifies identical estimation IDs and outcomes before comparing them. Influence uses the original T4 estimation sample and preserves its constructed group variables. The lexically smallest camp codes determine `first20`; all valid codes have length three.

Additional switches support the assignment's validation restriction:

```sh
# Synthetic checks only; no empirical loading or fitting.
/opt/homebrew/bin/Rscript run.R --out validation --test-only

# The only empirical fits performed for this assignment.
/opt/homebrew/bin/Rscript run.R --grid grid.json --data data --out results --specs S000 --families T4 --influence none

# Construct all samples and variables, without empirical fitting.
/opt/homebrew/bin/Rscript run.R --grid grid.json --data data --out construction_checks --specs all --construct-only --influence none
```

`--families` accepts a comma-separated intersection with each spec's declared families. Normally omit it. If requesting T5ROC or INFLUENCE with this switch, also include their prerequisite T4/T5 families; missing prerequisites are recorded as failures rather than causing extra fits. Use a separate output directory for each run: CSV files and the run log are overwritten, while previously generated sample-ID files for unselected models are not removed.

All five manifest outputs are written directly under `--out`: `results.csv`, `roc.csv`, `influence.csv`, `sample_ids/`, and `run_log.txt`. Unrequested ROC/influence outputs contain headers only. Test artifacts are written to `tests/` beside the grid, and their summary also appears in the run log. Test definitions are inside the one script, in `synthetic_checks()`. `tests/synthetic_models/` contains synthetic results, ROC comparisons, influence results, and sample IDs; these are not empirical results. `tests/nul_fixture.parquet` is a generated test fixture.

Every invocation validates the estimation machinery before loading empirical records. The saved checks in `tests/test_results.csv` and `tests/test_log.txt` all passed:

| Check | Result |
| --- | --- |
| Known-coefficient probit, 60,000 simulated observations | Maximum coefficient error 0.00914005; maximum standardized error 0.76658, below the prespecified threshold of 4 |
| Continuous/binary/interaction marginal effects and numerical delta method | Maximum effect error 1.62e-12; Jacobian error 2.03e-7; SE error 3.12e-8 |
| Cluster covariance versus independent direct sandwich on nine observations and four clusters | Maximum absolute discrepancy 2.78e-17 |
| Hand-made hierarchy groups | Single rank and singleton Steepness 0; reference-matching Sameness 1; ranks 1 and 9 Steepness 0.4; empty groups missing |
| DeLong | Identical predictors z=0, p=1; tied-predictor z agrees with a brute-force pairwise calculation within 8.88e-16 |
| NUL-safe Parquet decoding | Leading, embedded and trailing NULs removed; spaces, empty strings and null entries preserved |
| Duplicate linkage and missing regressors | Unmatched, first-record and fieldwise-combine rules checked; zero replacement and indicator checked |
| Coordinate selection | Entry ordering, capital override, unknown/missing location, malformed degree text and absent-text fallback checked |
| Synthetic integration | All 104 origin model fits, eight correlated ROC comparisons and 96 leave-camp-out fits succeeded; constant-outcome failures were recorded |

The empirical check used only S000/T4. All eight fits converged. D0 has 143,374 rows, D has 124,387, and the common R has 101,993. Captured-cohort models drop 1,321 rows in 178 constant-outcome camps, leaving 100,672 observations, 163 camps and 1,674 captured-cohort clusters. Camp-cohort models use 101,993 observations and 341 camp clusters. The eight sample-ID files have the reported counts, strictly increasing IDs and no duplicates. Result keys `(spec_id, model_id, term)` are unique. Exact duplicate missing-indicator columns are reported as aliased, as explained below.

Sample and variable construction was also run successfully for S000 through S020, with no empirical fits in that run. Counts, reference fractions and missingness appear in `construction_checks/run_log.txt`; its result CSVs have headers only. This checks that every grid option can be constructed, without claiming empirical convergence for the unrun models.

Measured timing on this machine:

| Operation | Elapsed time |
| --- | --- |
| Entire synthetic suite | About 2.3 seconds |
| Read necessary columns and retain enlistment matches | About 17 seconds |
| Construct all 21 specs after loading | About 12 seconds |
| One captured-cohort simple T4 fit | 16.1–16.2 seconds |
| One captured-cohort full T4 fit | 18.8–20.3 seconds |
| One camp-cohort simple T4 fit | About 0.16 seconds |
| One camp-cohort full T4 fit | 0.49–0.51 seconds |
| S000/T4 validation, including loading and synthetic checks | About 93 seconds |

These are wall-clock observations, not guarantees. Similar full-sample captured-cohort fits are expected to take roughly 15–25 seconds and camp-cohort fits 0.2–1 second; subset fits can be faster. The grid contains 266 ordinary model fits and eight ROC comparisons before influence. Extrapolating, allow roughly 35–60 minutes without influence. `first20` adds 160 fits, likely around 20–35 minutes. Origin `all` would add 2,016 fits (four models over 163 camps and four over 341 camps), plausibly another 3–5 hours. These totals are estimates only; none of those larger empirical runs was performed.

Implementation choices and manifest ambiguities are recorded here by the line numbers in the supplied `manifest.md`:

| Manifest line(s) | Interpretation or limitation |
| --- | --- |
| 7–12 | The installed nanoparquet string reader raises `embedded nul in string` on seven selected POW columns before R can clean them. The script first tries `read_parquet(col_select=...)`, then uses nanoparquet's internal decompressed-page and RLE readers for the affected BYTE_ARRAY column. It removes NUL bytes before creating strings. The fallback supports flat optional/required fields, PLAIN and dictionary encoding, and data pages V1/V2; it fails explicitly on unsupported encodings. Internal functions make this fallback specific to the supplied nanoparquet version. Input bytes are never rewritten. |
| 8, 67 | Only needed columns are read. Enlistment serials are matched first; each subsequent full-length column is immediately reduced to matching rows and released. Only 74,210 candidate enlistment rows remain for duplicate resolution. Several POW rows can point to one enlistment record, without expanding POW rows. |
| 12, 21 | The camp code CSV has an improperly escaped quote in its meaning text. data.table reports and repairs it; this warning is recorded. Only its cleaned `Code` column is used. |
| 31, 45, 73, 87–96 | Group members and reference fractions are constructed from the applicable R (or the stated file/complete alternative) before robustness restrictions and camp-outcome screening. This follows the named R in line 31 and the explicit instructions to preserve group variables. Screening removes whole camps, so it cannot alter groups of retained camps. With column-specific R and regression reference fractions, each group type uses its own R. Influence never recomputes group variables. |
| 37–40 | Trim outside spaces on both lookup keys; preserve internal spaces. First-row precedence is applied before rank lookup. Tables are read as character data to preserve codes. |
| 47 | If a reference fraction is zero, ratio sameness is mathematically undefined; it is missing, without adding a pseudocount. Absolute-deviation sameness is missing if p9=1; recomputed Sameness is missing if its constant is zero. The ordinary missing-value rules then apply. These cases do not occur in the observed origin fractions. |
| 52, 71 | Constant regressors are omitted along with constant missing indicators. Exact linear dependencies are resolved by a deterministic rank-revealing QR in model-column order. Dependent terms have explicit `aliased` rows and NA estimates, and their names appear in the error/detail column. In S000 full models, `men_missing` and `men_sq_missing` duplicate the hierarchy missing indicator. Separate effects of identical columns are not identified; the remaining columns span the requested model. |
| 52, 85, 95 | Interaction and square columns are constructed from original variables before missing values are replaced. A product with a missing component is missing and receives its own nonconstant missing indicator. Effects treat product columns as continuous independent regressors, as specified. |
| 57 | `entry_id` includes suffixes such as `359a` and `359b`, so lowest means lexical order within camp. Among eligible exact/approximate rows, the first is used. The unknown-confidence restriction also applies to the whole-degree option. Capital-name overrides use exact cleaned Berlin/Tokyo names. Nonpositive computed distances outside that override are missing because their logarithms are undefined. |
| 57 | Six nonempty NARA coordinate strings contain multiple candidate pairs: camps 803, 737, 054, 013, 802 and 801. The manifest only specifies a single `LAT-LON` string and permits crosswalk fallback when text is absent. Accordingly these nonempty, unparsable strings produce missing distance in S019; no candidate is silently selected and absent-text fallback is not extended to malformed text. This raises R's distance missing count from 625 to 8,912. |
| 67 | Duplicate `combine` operates on each cleaned raw field, then applies the CARD_NUM layout rule. A conflicting field becomes blank. A conflicting CARD_NUM therefore follows the literal “else HEIGHT/YR_BIRTH/etc.” rule. Blank serial strings are compared literally, with the same duplicate rule; the manifest supplies no additional blank-serial exclusion. |
| 71 | The sandwich uses inverse observed negative likelihood Hessian as bread, summed individual likelihood scores within clusters as meat, and exactly G/(G−1), without an extra (N−1)/(N−K) factor. The manifest does not choose observed versus expected information; observed information is the MLE Hessian interpretation. Log probabilities and Mills ratios are computed stably. |
| 71 | The null model is intercept-only, on precisely the final estimation rows, even when the fitted model contains camp effects. Covariate means are treated as fixed for the delta method. Coefficients and SEs include the intercept, whose marginal effect fields are NA. The manifest's explicit binary list excludes camp dummies; their reported effects use its continuous-column formula, while their means enter every effect calculation. A discrete-change interpretation for camp-dummy effects would differ. |
| 73, 100 | The lowest retained camp code is the omitted fixed-effect category. No further sample exclusions are made for general separation. Numerical failures and insufficient clusters produce `failed`; nonconvergence produces `nonconverged`; caught fitting warnings are retained. All subsequent fits continue. |
| 86, 94 and grid S020 | Robustness uses origin parameters in S000. S020 explicitly changes friends_def, so that grid deviation is honored for its ten R_friends fits despite the generic “origin parameters” wording in line 86. |
| 93 | The last clause says “two full models of each group type” but explicitly gives two fits per measure and six total. Implemented cap full and camp full once for each of distinct-rank count, rank sum and administrative intensity. Thus R_alt has 14 fits, not duplicated fits with identical regressors. |
| 94 | Unit is a tuple of the three cleaned fields, encoded with separators to prevent concatenation collisions. The line's “including the row itself” conflicts with line 31 for rows excluded from group membership, such as missing-rank rows. Counts follow the explicit group-member set: include the row only if it is a member; `others` subtracts one only for an actual member. No missing-rank person is silently added to the rank-defined member set. Unit-restricted hierarchy uses that same member set and the original population fractions; men and men_sq remain whole-group measures. |
| 96, 100 | Named model sample-ID files describe the corresponding ordinary fit after screening. Influence output has the original model ID plus deleted_camp; no separate influence sample-ID filename is specified, so influence rows are recorded only in influence.csv. Failed named fits also write their retained/candidate IDs, with status explaining the failure. |

After the empirical validation, CSV warnings were made explicit in logs, internal captured-cohort identifiers were changed to contain the full year (an equivalent relabeling), and error handling was widened. The complete synthetic suite and all-spec construction check passed after those changes. A final coordinate check also verified that an eligible capital gets km=1 even without numeric coordinates; this edge-case correction leaves the supplied capital rows unchanged because their coordinates are present. All nine final synthetic checks passed, and no additional empirical fits were needed.
