All AN01–AN14 analyses are implemented; the unchanged 1,295-row grid is embedded in `run_analysis.R`.

Interpretations where the manifest is not explicit:

- P2's quarter remains `YYYYqN` text; the count columns are numeric. Empty-quarter and unparseable-count reason counts overlap, so the preparation log also gives their intersection and sequential removal counts.
- Blank reference-set parameters in the supplied cross-section rows use R1. R2 means the designated boundary, timing, or decile sample before regression-specific missing-value exclusions. Group assignments and placebo vectors stay fixed during county-deletion refits.
- A period sum with any missing outcome stays missing. `n_dropped_missing` counts incomplete/nonfinite model observations; W1/W4's explicit exclusions are counted separately in `prep_log.json`.
- `r2` is overall centered R-squared. Parameter counts use matrix rank, including disconnected or redundant fixed effects. Confidence intervals use county-cluster inference except AN12, which uses HC1 as specified. Descriptive rows have no regression inference; their detailed statistics are in the named analysis files.
- Influence results are in `influence.csv`; `results.csv` contains the original fit. For specifications with multiple reported coefficients, influence results have one row per removed county **and term**, since the manifest does not select a single focal term for those rows. S00008 has exactly one row per removed county. Unused descriptive files are written with headers in influence mode.

SHA-256 uses the host's `shasum`, `sha256sum`, or `openssl` utility on the comma-joined county keys with no trailing newline; no extra R packages or network access are needed. Validation checks compare the panel estimates and covariance matrices with independent two-way demeaning, and cross-section estimates and covariance matrices with explicit-dummy OLS. The fixed-effect rank calculation is also checked against an explicit design matrix.
