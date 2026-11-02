# Synthetic estimation tests

Result: PASS

The initial synthetic suite passed and was recorded before opening any supplied survey CSV. The suite was subsequently rerun after correcting raw-data MLR normalization and adding its regression check. No data/ or dictionaries/ input is used by the test suite.

Three groups of 900, 1100, 1300 observations; five correlated factors, 19 indicators; known unequal latent means/variances, invariant loadings, six noninvariant intercepts. Gaussian draws whitened to exact known means/covariances.

Run with `/opt/homebrew/bin/Rscript code/analysis.R --test`.

- PASS: Synthetic moments equal known population moments
- PASS: M1 converges with expected df
- PASS: M2 converges with expected df
- PASS: M3 converges with expected df
- PASS: M4 converges with expected df
- PASS: M5 converges with expected df
- PASS: M4 recovers known loadings intercepts latent means and variances
- PASS: M4 zero population discrepancy and custom Wishart chi-square
- PASS: All 15 standardized contrasts recover truth
- PASS: Contrast SE includes parameter covariance
- PASS: CHK1 M4 converges
- PASS: CHK1 identification invariant d_eq
- PASS: CHK2 M4 converges
- PASS: CHK2 identification invariant d_eq
- PASS: S05 M4 converges
- PASS: S05 exact loading averages and intercept sums
- PASS: Warm-start deletion agrees with cold refit
- PASS: S01 normalized weighted covariance divisor n-1
- PASS: S02 covariance divisor n
- PASS: Weight validity includes dictionary missing codes
- PASS: S02 M4 supported and converges
- PASS: S06 M4 supported and converges
- PASS: S06 reports finite sandwich SE and scaled statistic
- PASS: S06 raw-data normalization agrees with explicit divisor-n discrepancy
- PASS: S04 M4 supported and converges

Exact numerical test details and software versions are in `code/test_results.json`.

S05 is tested against its literal sum constraints; those constraints can change partial-invariance restrictions, so equivalence to marker identification is not assumed.

## Session information

```
R version 4.6.1 (2026-06-24)
Platform: aarch64-apple-darwin25.6.0
Running under: macOS Tahoe 26.6.2

Matrix products: default
BLAS:   /opt/homebrew/Cellar/openblas/0.3.34/lib/libopenblasp-r0.3.34.dylib 
LAPACK: /opt/homebrew/Cellar/r/4.6.1_1/lib/R/lib/libRlapack.dylib;  LAPACK version 3.12.1

locale:
[1] C.UTF-8/C.UTF-8/C.UTF-8/C/C.UTF-8/C.UTF-8

time zone: Asia/Tokyo
tzcode source: internal

attached base packages:
[1] stats     graphics  grDevices utils     datasets  methods   base     

other attached packages:
[1] jsonlite_2.0.0 lavaan_0.7-3  

loaded via a namespace (and not attached):
[1] MASS_7.3-66         compiler_4.6.1      parallel_4.6.1     
[4] mnormt_2.1.2        pbivnorm_0.6.0      numDeriv_2016.8-1.1
[7] stats4_4.6.1        quadprog_1.5-8     
```
