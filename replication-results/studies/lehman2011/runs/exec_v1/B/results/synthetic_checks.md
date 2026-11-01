# Synthetic checks

Seed: 27102026. All fits in this stage use generated data.

- Exact conditional LL versus direct enumeration: **PASS**; error/statistic 4.4408921e-16, limit 1e-11.
- Exact analytic score versus numerical derivative: **PASS**; error/statistic 3.63376e-11, limit 1e-07.
- Invariant group contributes zero likelihood: **PASS**; error/statistic 0, limit 1e-11.
- Exact conditional LL versus survival::clogit(method=exact): **PASS**; error/statistic 0, limit 1e-10.
- U7=0 known slope recovery (maximum absolute z): **PASS**; error/statistic 1.0842071, limit 4.
- U7=0 convergence: **PASS**; error/statistic 0, limit 0.
  Estimates: x1 = 0.523193 (truth 0.55); x2 = -0.411411 (truth -0.40).
- U7=1 known slope recovery (maximum absolute z): **PASS**; error/statistic 0.84581037, limit 4.
- U7=1 convergence: **PASS**; error/statistic 0, limit 0.
  Estimates: x1 = 0.528965 (truth 0.55); x2 = -0.415968 (truth -0.40).
- U7=2 known slope recovery (maximum absolute z): **PASS**; error/statistic 0.47387459, limit 4.
- U7=2 convergence: **PASS**; error/statistic 0, limit 0.
  Estimates: x1 = 0.537837 (truth 0.55); x2 = -0.408730 (truth -0.40).
- N1 known slope recovery (maximum absolute z): **PASS**; error/statistic 1.1050092, limit 4.
- N1 convergence: **PASS**; error/statistic 0, limit 0.
  Estimates: x1 = 0.522692 (truth 0.55); x2 = -0.409461 (truth -0.40).
- N1 population intercept recovery (absolute z): **PASS**; error/statistic 0.32116744, limit 4.
- N1 random-effect SD recovery (log-scale absolute z): **PASS**; error/statistic 2.4922176, limit 4.
  N1 sigma estimate = 0.523091; truth = 0.65; 16 adaptive GH nodes.
- N1 16 versus 32 adaptive GH nodes at MLE: **PASS**; error/statistic 9.094947e-12, limit 1e-05.
- Exact MLE versus survival::clogit: **PASS**; error/statistic 2.3038551e-08, limit 1e-05.
- Exact observed covariance versus survival::clogit: **PASS**; error/statistic 6.9121634e-11, limit 1e-06.
- Logit information versus numerical Hessian: **PASS**; error/statistic 4.6608051e-10, limit 1e-07.
- CR1 sandwich versus numerical scores and Hessian: **PASS**; error/statistic 7.970638e-13, limit 1e-08.
- All marginal-effect gradients versus numerical coefficient derivatives: **PASS**; error/statistic 3.2608009e-05, limit 0.0002.
- Marginal effects versus numerical d derivatives (left branch at zero): **PASS**; error/statistic 1.0424815e-08, limit 1e-07.
- Exact likelihood/score timing: 0.010 seconds for five evaluations on 9600 generated rows.
- S3 flag priority and unclassified no-play exclusion: **PASS**; error/statistic 0, limit 0.
- S5 strict boundary: **PASS**; error/statistic 0, limit 0.
- Floor minutes, exclusive conference, neutral-site override: **PASS**; error/statistic 0, limit 0.

## Synthetic pipeline smoke test

- Synthetic end-to-end orchestration and output schemas: **PASS**; error/statistic 0, limit 0.

All synthetic checks passed.
