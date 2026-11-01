# Responses to the unmet items (manifest PX01)

One item was listed. It was accepted as a genuine departure from the manifest and fixed in `output/analysis.R`. Line numbers below refer to the original script in `input/code/analysis.R`.

## 1. Each quantity uses complete cases on the variables it involves (lines 633-647, 658-669, 1018-1028)

Accepted. The indirect effect `ind` is `a` times `b`, and `se_delta`, `p_delta` and the normal interval are functions of `a`, `b` and their variances. Those quantities therefore involve every variable in the path model: the outcome, the condition and every mediator in the outcome equation (for the serial model, `you_grant`, the condition, `benev_trust_broker` and `m2`). The original script fit each regression on the complete cases of its own variables, so `a` could come from one set of rows and `b` from another, and the product and delta standard error mixed samples. The same functions fed the bootstrap statistic and the PM2 leave-one-out refits.

Fix. `pm_core` (PM2 and SI2), `sm_core` (SM2) and `med4_core` (MED4) now first take the complete cases on every variable the model set involves, and fit all of their regressions on that one table:

- PM2.o.m: complete cases on `o`, `cond` and all four mediators; `m` on `cond`, `o` on `cond` and the four mediators, and `o` on `cond` (total) are fit on those rows.
- SI2.o.m: complete cases on `o`, `cond` and `m`.
- SM2.m2: complete cases on `you_grant`, `cond`, `benev_trust_broker` and `m2`; the three serial regressions are fit on those rows.
- MED4.sim.m: complete cases on `Signed`, X and both mediators. MED4.ind.m: complete cases on `Signed`, X and `m`. The OLS mediator models and the OLS or logistic outcome model share those rows.

Every quantity reported under a key (`ind`, `a`, `b`, `c_prime`, `total`, `se_delta`, `p_delta`, the normal interval) comes from that one sample, so `ind` equals the reported `a` times the reported `b`, and in the parallel model `total` equals `c_prime` plus the sum of the four indirect effects, as it must when all paths share one sample. Bootstraps still resample the retained rows of the sample level, and each resample applies the same common complete-case rule, so the resampled statistic is the same estimator as the point estimate. The PM2 leave-one-out refits call the same function.

Verification. The synthetic files have no blanks on any model variable, so the repaired script writes output on them that is byte-identical to the original script with `--boot 200`: 12,710 result rows, 7,362 influence rows, 1,052 sample rows, zero failures. The change was verified on a perturbed copy with blanks injected into the outcomes, mediator items, `Signed`, `SignedTrust` and `SignedRisk`. On that copy only PM2, SI2, SM2 and MED4 result rows and PM2 influence rows changed. The new values for PM2, SM2 and the logistic MED4 model equal independent `lm` and `glm` fits on the common complete cases to floating-point precision, and `total - (c_prime + sum of ind)` moved from a non-zero value under the original script to zero.
