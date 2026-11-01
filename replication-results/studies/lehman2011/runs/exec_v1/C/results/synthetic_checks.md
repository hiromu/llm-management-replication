# Synthetic checks

Generated inputs only; no empirical model was fitted.

Seed: 20261027 (fixture seed: 816). Recovery uses a pre-set four-standard-error tolerance.

Result: 107/107 checks passed.
Elapsed seconds: 8.005.

| Check | Result | Error | Tolerance |
|---|---|---:|---:|
| exact enumeration LL n=8,m=3 | PASS | 0 | 1e-10 |
| exact enumeration score n=8,m=3 | PASS | 2.6090241e-15 | 1e-09 |
| exact enumeration information n=8,m=3 | PASS | 2.9930836e-10 | 2e-07 |
| statsmodels exact LL n=8,m=3 | PASS | 8.8817842e-16 | 1e-10 |
| exact enumeration LL n=9,m=7 | PASS | 0 | 1e-10 |
| exact enumeration score n=9,m=7 | PASS | 4.4408921e-16 | 1e-09 |
| exact enumeration information n=9,m=7 | PASS | 7.0564221e-11 | 2e-07 |
| statsmodels exact LL n=9,m=7 | PASS | 0 | 1e-10 |
| exact enumeration LL n=12,m=4 | PASS | 0 | 1e-10 |
| exact enumeration score n=12,m=4 | PASS | 1.7763568e-15 | 1e-09 |
| exact enumeration information n=12,m=4 | PASS | 6.3358963e-10 | 2e-07 |
| statsmodels exact LL n=12,m=4 | PASS | 1.7763568e-15 | 1e-10 |
| exact enumeration LL n=10,m=1 | PASS | 4.4408921e-16 | 1e-10 |
| exact enumeration score n=10,m=1 | PASS | 4.4408921e-16 | 1e-09 |
| exact enumeration information n=10,m=1 | PASS | 8.7232443e-11 | 2e-07 |
| statsmodels exact LL n=10,m=1 | PASS | 4.4408921e-16 | 1e-10 |
| large-stratum exact LL versus log-DP n=100 | PASS | 0 | 1e-08 |
| conditional intercept invariance n=100 | PASS | 1.4210855e-14 | 1e-08 |
| large-stratum directional score n=100 | PASS | 2.5310332e-10 | 1e-06 |
| large-stratum exact LL versus log-DP n=1100 | PASS | 5.6843419e-14 | 1e-08 |
| conditional intercept invariance n=1100 | PASS | 1.7053026e-13 | 1e-08 |
| large-stratum directional score n=1100 | PASS | 3.3260648e-09 | 1e-06 |
| U7=0 converged | PASS | 0 | 0 |
| U7=0 recovery x1 | PASS | 0.59947428 | 4 |
| U7=0 recovery x2 | PASS | 1.7447835 | 4 |
| U7=0 recovery season | PASS | 0.5952652 | 4 |
| U7=1 converged | PASS | 0 | 0 |
| U7=1 recovery x1 | PASS | 0.35971517 | 4 |
| U7=1 recovery x2 | PASS | 1.9258754 | 4 |
| U7=1 recovery season | PASS | 0.64912141 | 4 |
| U7=2 converged | PASS | 0 | 0 |
| U7=2 recovery x1 | PASS | 0.67788391 | 4 |
| U7=2 recovery x2 | PASS | 1.7559132 | 4 |
| N1 converged | PASS | 0 | 0 |
| N1 recovery x1 | PASS | 0.60674677 | 4 |
| N1 recovery x2 | PASS | 1.7090809 | 4 |
| N1 recovery season | PASS | 0.59433313 | 4 |
| N1 recovery intercept | PASS | 1.0061836 | 4 |
| N1 recovery log_sigma_team | PASS | 1.412397 | 4 |
| dummy logit versus statsmodels coefficients | PASS | 1.4855297e-08 | 2e-05 |
| dummy logit versus statsmodels native covariance | PASS | 1.1533155e-09 | 2e-06 |
| homogeneous conditional groups dropped | PASS | 0 | 0 |
| homogeneous groups leave coefficients unchanged | PASS | 1.110223e-16 | 2e-05 |
| N1 moving-node analytic score versus numeric | PASS | 1.2122214e-10 | 2e-06 |
| N1 20-point adaptive GH versus direct integration | PASS | 1.5454305e-13 | 2e-08 |
| CR1 sandwich versus numerical scores and information | PASS | 1.1442194e-11 | 2e-08 |
| CR1 sandwich versus statsmodels cov_cluster | PASS | 1.6496556e-10 | 2e-07 |
| synthetic pipeline M2 dummy convergence | PASS | 0 | 0 |
| M2 ME0 analytic gradient and delta SE | PASS | 2.724508e-11 | 2e-06 |
| M2 U9a analytic gradient and delta SE | PASS | 1.0636619e-11 | 2e-06 |
| M2 U9b analytic gradient and delta SE | PASS | 6.3795847e-10 | 2e-06 |
| M2 U10a analytic gradient and delta SE | PASS | 4.046919e-13 | 2e-06 |
| M2 N3 analytic gradient and delta SE | PASS | 2.7549219e-11 | 2e-06 |
| M2 dp/dd d=-14 ME0 | PASS | 3.6009459e-12 | 2e-06 |
| M2 dp/dd d=14 ME0 | PASS | 1.1987911e-12 | 2e-06 |
| M2 dp/dd d=0 ME0 | PASS | 4.2579524e-09 | 2e-06 |
| M2 dp/dd d=0 U10a | PASS | 1.5904967e-11 | 2e-06 |
| synthetic pipeline M3 dummy convergence | PASS | 0 | 0 |
| M3 ME0 analytic gradient and delta SE | PASS | 2.2721623e-11 | 2e-06 |
| M3 U9a analytic gradient and delta SE | PASS | 1.266605e-11 | 2e-06 |
| M3 U9b analytic gradient and delta SE | PASS | 1.4339938e-09 | 2e-06 |
| M3 U10a analytic gradient and delta SE | PASS | 3.2128328e-12 | 2e-06 |
| M3 N3 analytic gradient and delta SE | PASS | 2.2036279e-11 | 2e-06 |
| M3 dp/dd d=-14 ME0 | PASS | 9.2448098e-12 | 2e-06 |
| M3 dp/dd d=14 ME0 | PASS | 1.1108328e-12 | 2e-06 |
| M3 dp/dd d=0 ME0 | PASS | 2.6561925e-09 | 2e-06 |
| M3 dp/dd d=0 U10a | PASS | 1.718423e-10 | 2e-06 |
| synthetic pipeline M1 exact convergence | PASS | 0 | 0 |
| synthetic pipeline M2 exact convergence | PASS | 0 | 0 |
| synthetic pipeline M3 exact convergence | PASS | 0 | 0 |
| K1 exact likelihood invariance | PASS | 1.1368684e-13 | 2e-06 |
| K2 exact likelihood invariance | PASS | 0 | 2e-06 |
| K2 home coefficient sign | PASS | 5.8980598e-17 | 2e-05 |
| nested LR and Wald tests emitted | PASS | 0 | 0 |
| full-stage synthetic output smoke fits | PASS | 0 | 0 |
| duplicate grid cells refitted and flagged | PASS | 0 | 0 |
| execution schedule preserves all 604 fits in order | PASS | 0 | 0 |
| auxiliary fits have separate step and no duplicate flags | PASS | 0 | 0 |
| step 2 contains only single-axis deviations | PASS | 0 | 0 |
| duplicate flags reference only scheduled step-1/2 executions | PASS | 0 | 0 |
| only 27 step-3 fits duplicate earlier scheduled cells | PASS | 0 | 0 |
| influence writer emits all requested rows | PASS | 0 | 0 |
| team deletion M2 U7=0 synthetic fit | PASS | 0 | 0 |
| team deletion M2 U7=1 synthetic fit | PASS | 0 | 0 |
| team deletion M3 U7=0 synthetic fit | PASS | 0 | 0 |
| team deletion M3 U7=1 synthetic fit | PASS | 0 | 0 |
| season deletion M2 U7=0 synthetic fit | PASS | 0 | 0 |
| season deletion M2 U7=1 synthetic fit | PASS | 0 | 0 |
| season deletion M3 U7=0 synthetic fit | PASS | 0 | 0 |
| season deletion M3 U7=1 synthetic fit | PASS | 0 | 0 |
| game deletion M2 U7=0 synthetic fit | PASS | 0 | 0 |
| game deletion M2 U7=1 synthetic fit | PASS | 0 | 0 |
| game deletion M3 U7=0 synthetic fit | PASS | 0 | 0 |
| game deletion M3 U7=1 synthetic fit | PASS | 0 | 0 |
| grid 604 scheduled fits | PASS | 0 | 0 |
| grid 192 crossed cells | PASS | 0 | 0 |
| ID hash invariant to row ordering | PASS | 0 | 0 |
| sample origin edge-case ID selection | PASS | 0 | 0 |
| model-specific versus common complete cases | PASS | 0 | 0 |
| expanded decision/boundary sample IDs | PASS | 0 | 0 |
| no_play non-attempt flag priority and classifications | PASS | 0 | 0 |
| kneel and spike are non-attempts | PASS | 0 | 0 |
| minutes floor and terminal inclusive boundary | PASS | 0 | 0 |
| exclusive conference and neutral home coding | PASS | 0 | 0 |
| pre-play score reference and own total_points | PASS | 0 | 0 |
| team-season estimator has no season regressors | PASS | 0 | 0 |
| unmatched games join stops sample construction | PASS | 0 | 0 |

## Parameter recovery

| Estimator | Term | Truth | Estimate | Native SE | Absolute error / SE |
|---|---|---:|---:|---:|---:|
| U7=0 | x1 | 0.65 | 0.631905 | 0.030185 | 0.599474 |
| U7=0 | x2 | -0.45 | -0.501749 | 0.029659 | 1.74478 |
| U7=0 | season | 0.25 | 0.283534 | 0.0563353 | 0.595265 |
| U7=1 | x1 | 0.65 | 0.639075 | 0.0303711 | 0.359715 |
| U7=1 | x2 | -0.45 | -0.507465 | 0.0298384 | 1.92588 |
| U7=1 | season | 0.25 | 0.286777 | 0.0566573 | 0.649121 |
| U7=2 | x1 | 0.65 | 0.629404 | 0.030383 | 0.677884 |
| U7=2 | x2 | -0.45 | -0.502343 | 0.0298097 | 1.75591 |
| N1 | x1 | 0.65 | 0.631698 | 0.0301645 | 0.606747 |
| N1 | x2 | -0.45 | -0.500667 | 0.0296456 | 1.70908 |
| N1 | season | 0.25 | 0.283479 | 0.0563301 | 0.594333 |
| N1 | intercept | -0.8 | -0.903587 | 0.10295 | 1.00618 |
| N1 | log_sigma_team | -0.356675 | -0.225086 | 0.0931669 | 1.4124 |

The synthetic_smoke/ tables exercise full-stage output formats using generated
data; they are not empirical results. Covariance and margin checks use independent
numerical derivatives. Exact-likelihood checks include exhaustive enumeration,
statsmodels comparisons, and independent log-domain dynamic programming.
