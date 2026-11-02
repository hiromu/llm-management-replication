# Synthetic validation

This mode uses synthetic data only. The initial suite passed before the first supplied-data run; it was rerun after numerical refinements. The results below describe the latest run.

Command: `~/.venv/bin/python -I code/analyze.py test`

Seed: 20261028. Three groups, five correlated factors, 19 indicators; 18,000 generated observations per group.
Marker loadings are 1, marker intercepts are 0, other loadings/intercepts are known; six intercepts vary by group.
Latent means and covariances are known. Missing-data tests use the first 1,800 records per group with independent 8% missingness.

Overall result: **ok**.

- **known_parameter_recovery: PASS**. `{"max_mean_error": 0.01775157595344934, "max_loading_error": 0.006809569131467574, "max_covariance_error": 0.02598584478605115, "chi2": 479.5617431885912, "df": 470}`
- **analytic_likelihood_gradient: PASS**. `{"maximum_absolute_error": 3.3390127097162985e-10}`
- **moment_derivatives: PASS**. `{"maximum_absolute_error": 2.6324720181492012e-11}`
- **expected_information_SE: PASS**. `{"maximum_SE_ratio_error": 0.003969473727613249}`
- **reference_mean_variance_identification: PASS**. `{"maximum_d_eq_difference": 5.803355171418723e-09, "chi2_difference": 1.7456613932154141e-10}`
- **alternate_markers: PASS**. `{"maximum_d_eq_difference": 8.564232448216025e-09}`
- **effects_coding_equalities: PASS**. `{"maximum_constraint_residual": 2.220446049250313e-16, "df": 478}`
- **FIML_complete_data_equivalence: PASS**. `{"chi2_difference": 1.0857093002414331e-11, "max_parameter_difference": 0.0}`
- **FIML_missing_data_recovery: PASS**. `{"maximum_mean_error": 0.03445499683338804, "chi2": 479.7877626301488}`
- **weighted_moments: PASS**. `{"mean": [2.9000000000000004, 2.5], "covariance": [[1.1866666666666668, -0.8666666666666667], [-0.8666666666666667, 1.6666666666666667]]}`
- **robust_covariance: PASS**. `{"minimum_covariance_eigenvalue": 4.181356561037471e-05, "method": "Huber-White observed-information sandwich; Yuan-Bentler Mplus T2* correction", "scaling_factor": 1.0015485666047297, "scaled_chi_square": 496.5743958153991, "scaled_p": 0.1914433988297807, "h1_trace": 627.4803821996102, "h0_trace": 156.75255589538722, "observed_hessian_central_difference_relative_step": 0.0001, "scaling_formula": "(trace(H1_inverse J1) - trace(H0_inverse J0)) / df; H0 observed, H1 saturated normal information", "score_meat": "sum of individual score outer products; no degrees-of-freedom adjustment"}`
- **deletion_moments: PASS**. `{"deleted_index": 5}`

Full-precision machine-readable results and package versions: `synthetic_tests.json`.
These checks validate numerical implementation and identification; they do not establish that survey data satisfy normality or the factor model.
