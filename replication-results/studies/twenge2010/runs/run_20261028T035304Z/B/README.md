# PAPER_X implementation

The R entry point is `code/analysis.R`. It implements all twelve specifications in `MANIFEST.md` and the separate, chunked S00 M4 influence mode. Run commands from this directory. No web access or software installation is needed.

## Running

The installed R executable is `/opt/homebrew/bin/Rscript`. The program uses lavaan, jsonlite, numDeriv for synthetic verification, and base/recommended R packages. Sample hashing uses the installed `shasum -a 256` command. No Python is used.

First run the synthetic estimation tests:

```sh
/opt/homebrew/bin/Rscript code/analysis.R --test
```

The initial synthetic test suite was run successfully and recorded **before any supplied survey CSV was opened**. The suite was later rerun after an MLR normalization correction and again for repair round 1, with regression checks for CHK1 identification, S04 observed-score standardization, and sample hash bytes. `code/TESTS.md` records the tests; `code/test_results.json` contains their numeric results and session information. The analysis command requires a successful test result.

Run one specification, or all specifications:

```sh
/opt/homebrew/bin/Rscript code/analysis.R --spec S00
/opt/homebrew/bin/Rscript code/analysis.R --spec all
```

Available names are `S00`, `S01`, `S02`, `S03`, `S04`, `S05`, `S06`, `S07a`, `S07b`, `S08`, `CHK1`, and `CHK2`. Each writes or replaces `results/<spec_id>.json`.

Run a chunk of influence deletions:

```sh
/opt/homebrew/bin/Rscript code/analysis.R --influence --start 1 --limit 2
```

Indices are one-based and ordered by ascending year, then numeric V4, in the S00 complete-case multigroup sample. This writes `results/influence_1_2.csv` and `results/influence_1_2.metadata.json`. The ending index is truncated at the sample size. Failed deletion fits remain in the CSV with their reason and missing numerical results. Each deletion starts from the full-sample M4 estimates; exact moments are recomputed after deleting the row. The CSV has exactly the columns specified in Section 6. Its metadata sidecar records software/session information, analysis samples and hashes for every deletion, warnings, and timings without changing that CSV schema.

The program supports larger chunks, but **only two supplied-data deletions were run for this assignment**, within the limit of twenty.

After running all specifications and the two-deletion example, verify the saved outputs:

```sh
/opt/homebrew/bin/Rscript code/validate_outputs.R
```

This writes `code/VALIDATION.md`. It checks saved results without fitting additional analyses.

## Implementation and output conventions

- All input records and columns are read; analysis selection uses only the manifest's item validity, completeness, and S01 weight rules. Forms remain separate. V5 declared missing values and ranges are read from each file's dictionary.
- Each model's output includes its explicit lavaan syntax, resolved software options, estimates, convergence information, warnings, fit indices, analysis n, and sample hashes. Item and alpha outputs include their own n and hashes. Item comparisons reuse the corresponding item/year samples; latent contrasts reuse the M4 samples. Model comparisons reuse the indicated constituent model samples.
- SHA-256 hashes use ascending numeric V4 values, canonical numeric IDs separated by LF, with no terminal newline. No header or row numbers enter the hash. An empty list hashes zero bytes.
- S00 uses divisor n-1 and Wishart likelihood. S01 supplies sample-specific normalized weighted moments. S02 supplies divisor-n moments. Raw-data S06 explicitly permits lavaan's n-1-to-n rescaling and uses MLR with observed-information Huber–White covariance. All other requested ML standard errors use expected information.
- Optimizer relative function tolerance is `1e-10`. Other resolved lavaan defaults are retained in each model output. No residual correlations, demographic exclusions, positivity bounds, or model repairs are added.
- Complete-data chi-square, baseline chi-square, CFI, TLI, RMSEA, and covariance-only SRMR are calculated from the manifest's formulas. S04 uses the raw-data likelihood-ratio chi-square and lavaan's unrestricted H1 EM covariance for SRMR; resolved missing-data options are saved. For S04 `d_obs`, the variance of the unit-weighted mean of k factor items is the sum of their H1 covariance block divided by k squared, multiplied by n/(n-1) to use the requested sample-SD divisor. This missing-data convention uses the full multigroup sample and reduces to the empirical score variance when data are complete. S06 additionally reports the scaled Yuan–Bentler Mplus-variant statistic supplied by MLR. Section 4.2 differences remain ordinary unscaled chi-square differences, as specified.
- S05 implements the loading-average and intercept-sum constraints literally, including released intercepts. Those constraints can change the restrictions in a partial-invariance model, so equivalence to S00 is not assumed. CHK1 uses separate numeric fixing and character label modifiers: all five 1976 means are fixed to 0 and variances to 1, with df 470 as in M4. CHK1 and CHK2 standardized contrasts were checked for agreement with S00.
- JSON numbers use 17 digits, rather than jsonlite's shorter `digits=NA` formatting. Influence numeric fields use 17 significant digits. Undefined numeric values serialize as JSON `null` or empty CSV fields, with relevant availability reasons or fit warnings retained. No output estimates are rounded for presentation.
- Every specification JSON and the influence metadata include `sessionInfo()` and package versions. Numerical test results also include session information. Logs are progress transcripts; the JSON files and CSV/metadata pair are the authoritative results.

## Completed runs and limitations

All twelve specifications were run. All **77 model fits converged**. S00 completed all nine single-group models, M1–M5, fit comparisons, latent estimates and contrasts, alpha coefficients, and item statistics and comparisons. The S00 multigroup samples contain 3,097, 2,413, and 2,297 respondents in 1976, 1991, and 2006, respectively.

The synthetic tests passed. Repair round 1 reran all twelve specifications and the existing two-deletion influence chunk because the sample-hash correction affects every output. Saved-output validation passed **480 checks**, including direct agreement between the manifest's chi-square calculation and lavaan, covariance-aware contrast standard errors, identification invariance, robust normalization, sample hashes, influence schema, and double-precision JSON round trips.

The following limitations and warnings are explicitly retained:

- **S04:** status is `ok`; all five FIML fits and all 15 `d_obs` values are provided using the H1 covariance convention above. The convention is also recorded in `results/S04.json`.
- **S07a and S07b:** all three yearly fits in each specification converge, but lavaan reports a non-positive-definite latent covariance matrix. The fits and warnings are retained without changing the model or imposing additional bounds. An `ok` fit status indicates computational convergence, not an admissible latent covariance matrix.
- **CHK1:** the repaired fit has df 470 and no identification warning; its standardized contrasts agree with S00 within the validation tolerance.

There are no other specification substitutions or unavailable items.

## Influence timing

The two supplied-data deletions were indices 1 and 2: year 1976, V4 40002 and 40003. Both converged and returned all 30 requested contrast values.

Repair-round wall times were approximately **0.208 and 0.191 seconds**, averaging **0.1995 seconds per deletion** on this environment. Timing includes moment recomputation, fitting, and contrast extraction; it excludes the initial full-sample fit, sample hashing, and disk output. Full-precision timings and session information are in `results/influence_1_2.metadata.json`. This is a two-deletion timing check, not a full influence run.

## Files

- `code/analysis.R`: parameterized analysis and influence entry point.
- `code/tests.R`, `code/TESTS.md`, `code/test_results.json`: synthetic test implementation and recorded results.
- `code/validate_outputs.R`, `code/VALIDATION.md`: saved-output validation and report.
- `results/S00.json` through the twelve named specification outputs: full requested results.
- `results/influence_1_2.csv` and its `.metadata.json` sidecar: two deletion results and timing/provenance.
- `results/*.log`: run progress transcripts.
