# Synthetic checks

Generated 2026-10-27T22:44:11+0900 by code/run_all.R (stage synthetic, or at the start of stage full before any empirical fit).

## 1. Exact conditional likelihood: small case against direct enumeration

Four strata of sizes 6, 9, 11, 7 with 2, 5, 7, 4 events; p = 3; direct enumeration sums over all C(n_g, d_g) subsets (506 terms in total).

| check | value | pass |
|---|---|---|
| log-likelihood at test beta: recursion vs enumeration (abs diff) | 3.553e-15 | TRUE |
| score vs central-difference gradient of enumeration LL (max abs diff) | 6.792e-11 | TRUE |
| observed information vs numerical Hessian of enumeration LL (max abs diff) | 1.852e-05 | TRUE |
| MLE: cl_fit vs optim on enumeration LL (max abs diff) | 1.375e-07 | TRUE |
| MLE: cl_fit vs survival::clogit(method='exact') (max abs diff) | 4.712e-11 | TRUE |
| maximised LL: cl_fit vs survival::clogit (abs diff) | 5.329e-15 | TRUE |
| native SE: cl_fit vs survival::clogit (max abs diff) | 1.403e-11 | TRUE |
| null conditional LL: -sum log C(n,d) vs analytic (abs diff) |     0 | TRUE |
| LL at beta = 0 vs -sum log C(n,d) (abs diff) |     0 | TRUE |

Result: PASS

## 2. Exact conditional likelihood: medium case against survival (exact partial likelihood)

32 strata x 120 observations, p = 6 (survival::coxph(Surv(1, y) ~ X + strata(g), ties = 'exact'), the routine behind survival::clogit(method = 'exact')).

| check | value | pass |
|---|---|---|
| max abs coefficient difference | 2.135e-10 | TRUE |
| abs LL difference | 2.274e-13 | TRUE |
| max relative SE difference | 8.491e-11 | TRUE |

Result: PASS

## 3. Parameter recovery on synthetic data with the structure of the real sample

N = 22080 plays, 32 teams x 6 seasons, M3 regressor list, team effects ~ N(0, 0.50^2), intercept -0.80. Event rate 0.163.

Estimates and native SEs by estimator (U7 = 0 exact conditional logit by team; U7 = 1 logit with team dummies; U7 = 2 exact conditional logit by team x season, no season dummies; N1 random-intercept logit, AGHQ 12 points). z = (estimate - truth)/SE.

| term | truth | est_U7_0 | se_U7_0 | z_U7_0 | est_U7_1 | z_U7_1 | est_U7_2 | z_U7_2 | est_N1 | z_N1 |
|---|---|---|---|---|---|---|---|---|---|---|
| total_points |  0.02 | 0.01861 | 0.005628 | -0.2471 | 0.01864 | -0.2408 | 0.01817 | -0.3236 | 0.01855 | -0.2581 |
| yards_first_down | -0.15 | -0.1556 | 0.005529 | -1.018 | -0.1559 | -1.06 | -0.155 | -0.9078 | -0.1557 | -1.031 |
| yards_touchdown | -0.01 | -0.01017 | 0.000691 | -0.2473 | -0.01019 | -0.2742 | -0.01006 | -0.08631 | -0.01018 | -0.2662 |
| same_division |   0.1 | 0.06709 | 0.0472 | -0.6971 | 0.06723 | -0.6936 | 0.06872 | -0.6585 | 0.06684 | -0.7026 |
| same_conference |  -0.1 | -0.0998 | 0.05069 | 0.003893 |  -0.1 | 5.283e-05 | -0.09437 | 0.1105 | -0.09888 | 0.02203 |
| home_field |  0.15 | 0.1468 | 0.03908 | -0.08248 | 0.147 | -0.07543 | 0.151 | 0.0245 | 0.1469 | -0.07895 |
| week |  0.01 | 0.006747 | 0.003998 | -0.8137 | 0.006759 | -0.8098 | 0.007234 | -0.6886 | 0.006742 | -0.815 |
| minutes | -0.02 | -0.01926 | 0.002353 | 0.3157 | -0.01929 | 0.3025 | -0.01942 | 0.246 | -0.01923 | 0.3272 |
| perf_below | -0.04 | -0.06221 | 0.01699 | -1.308 | -0.06235 | -1.314 | -0.06414 | -1.41 | -0.06231 | -1.314 |
| perf_below_sq | 0.001 | 0.0001945 | 0.0006756 | -1.192 | 0.0001957 | -1.189 | 5.721e-05 | -1.383 | 0.0001907 | -1.198 |
| perf_above |  0.03 | 0.03045 | 0.008046 | 0.05533 | 0.0305 | 0.06222 | 0.02926 | -0.09209 | 0.03058 | 0.07183 |
| below_indicator |   0.3 | 0.2579 | 0.07724 | -0.5446 | 0.2584 | -0.5387 | 0.2597 | -0.519 | 0.2581 | -0.542 |
| perf_below_x_min | 0.0005 | 0.0009308 | 0.0004998 | 0.8619 | 0.0009333 | 0.8661 | 0.0009732 | 0.9424 | 0.0009346 | 0.8696 |
| perf_below_sq_x_min | -2e-05 | -3.26e-06 | 2.07e-05 | 0.8089 | -3.279e-06 | 0.8072 | 6.044e-08 | 0.9634 | -3.118e-06 | 0.8155 |
| perf_above_x_min | -0.0005 | -0.000549 | 0.0002436 | -0.2013 | -0.0005501 | -0.2053 | -0.0005079 | -0.03224 | -0.0005516 | -0.2121 |
| season_2001 |   0.1 | 0.2342 | 0.06726 | 1.996 | 0.2346 |     2 | NA | NA | 0.2346 | 2.002 |
| season_2002 |  -0.1 | -0.03697 | 0.0692 | 0.9109 | -0.03704 | 0.9089 | NA | NA | -0.03736 | 0.9052 |
| season_2003 |   0.2 | 0.2813 | 0.06685 | 1.216 | 0.2818 | 1.223 | NA | NA | 0.2816 | 1.221 |
| season_2004 |  0.05 | 0.1193 | 0.06811 | 1.017 | 0.1195 | 1.019 | NA | NA | 0.1192 | 1.016 |
| season_2005 | -0.15 | -0.07954 |  0.07 | 1.007 | -0.07969 | 1.003 | NA | NA | -0.07945 | 1.008 |

| check | value |
|---|---|
| max |z| U7=0 | 1.996 |
| max |z| U7=1 |     2 |
| max |z| U7=2 |  1.41 |
| max |z| N1 | 2.002 |
| N1 sigma_u: estimate | 0.4134 |
| N1 sigma_u: truth |   0.5 |
| N1 sigma_u z | -1.555 |
| U7=0 converged |     1 |
| U7=1 converged |     1 |
| U7=2 converged |     1 |
| N1 converged |     1 |
| N1 max |analytic gradient| at optimum | 2.682e-12 |
| N1 max |numerical gradient| at optimum | 2.728e-06 |
| corr(U7=1 team effects, true team effects) | 0.9708 |
| U7=0 iterations |     5 |
| N1 LL | -8541 |
| U7=1 LL (for reference) | -8482 |

Criterion: every |z| < 3.5, all fits converged, team-effect correlation > 0.9. Result: PASS

## 4. Marginal effects: delta-method SE against numerical derivatives

For every marginal-effect row (variants ME0, U9b, U10a, N3 on the U7 = 0 fit; U9a and benchmark-covariance ME0 on the U7 = 1 fit; d grid x minutes in {53, 8}), the gradient of the effect with respect to the coefficients was recomputed by central differences and the delta-method SE compared with the analytic one.

| check | value | pass |
|---|---|---|
| max relative SE difference, ME0/U9b/U10a/N3 (native covariance, U7=0 fit) | 1.82e-08 | TRUE |
| max relative SE difference, U9a (native covariance, U7=1 fit) | 1.113e-09 | TRUE |
| max relative SE difference, ME0 with benchmark (cluster-robust) covariance (U7=1 fit) | 1.452e-09 | TRUE |
| number of marginal-effect rows checked |    72 | TRUE |

Result: PASS

## 5. Cluster-robust sandwich (CR1) against numerical derivatives

On the U7 = 1 synthetic fit: per-observation scores vs central-difference gradients of the observation log-likelihood; bread vs the inverse of the numerically differentiated Hessian; the full CR1 sandwich (clustered by game_id) vs an explicit-loop computation using the numerical bread.

| check | value | pass |
|---|---|---|
| max relative score difference (4 observations) | 3.146e-09 | TRUE |
| relative Frobenius difference, numerical Hessian vs X'WX | 3.202e-10 | TRUE |
| max relative SE difference, CR1 sandwich (explicit loops, numerical bread) vs cluster_vcov | 1.896e-08 | TRUE |
| clusters (G) |  3264 | TRUE |
| parameters K (incl. intercept and team dummies) |    52 | TRUE |

Result: PASS

## 6. Random-intercept logit: quadrature sensitivity

| check | value | pass |
|---|---|---|
| abs LL difference, 12 vs 20 adaptive points | 1.037e-10 | TRUE |
| max abs parameter difference, 12 vs 20 points | 2.334e-11 | TRUE |

Result: PASS

## 7. SHA-256 (tools::sha256sum) known test vector

sha256('abc') = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad; expected ba7816bf...15ad. Result: PASS

## 8. Algebraic invariance (K1 analogue) on synthetic data

M3 with elapsed = 60 - minutes: LL difference from the minutes fit = 1.091e-11 (expected 0). Result: PASS

## Summary

| check | pass |
|---|---|
| enum | TRUE |
| surv | TRUE |
| recover | TRUE |
| me | TRUE |
| sw | TRUE |
| re | TRUE |
| hash | TRUE |
| k1 | TRUE |

Overall: ALL PASS
