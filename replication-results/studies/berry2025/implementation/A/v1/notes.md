# Notes on analysis.R (manifest PX01)

Run: `Rscript analysis.R --data DIR --out DIR --seed 20261031 --boot 5000`
(R 4.6.1; packages used: sandwich, lme4; everything else is base R.)

The synthetic run (`--boot 200`) finished in about 14 s with 12,710 result rows,
7,362 influence rows and 1,052 sample rows, zero failed quantities, and every key
family in the manifest present. All point estimates were cross-checked against
reference implementations (car::Anova types 1-3, psych::alpha, lm/glm/lmer,
t.test, chisq.test, sandwich HC0/HC3) and matched to machine precision; one
bootstrap was reproduced independently with the same seed and matched exactly.

## Decisions the manifest left open

### Keys and method labels
- Key = family, then the substituted names, then the quantity, joined by `.`:
  `P1.you_grant.mean_diff`, `PM2.you_grant.benev_trust_broker.ind`,
  `G1C.theft.loyal.mean_male`, `C3.cell.you_grant.LC.n`,
  `A3.you_grant.relationship.F`, `L4.M2.KnowRequestor.p_hc0`, `L4.M1.fit.ll`,
  `MED4.sim.SignedTrust.ind`, `N1.age.mean`, `D1.r.cond_recode|you_grant`.
- The intercept of the L4 models is reported as term `intercept`
  (e.g. `L4.M1.intercept.coef`). `L4.ALT.*` reports only the predictor term.
- Families with no stated method (D*, R*, N*, C3.cell, the descriptive part of
  T2/G*C/C3 contrasts) carry method `descriptive`. CHI4 carries method `chisq`.
  Boot counts use the model's method (`ols` or the MED4 method name).
- `boot_failed` is written once per key family that was bootstrapped
  (`PM2.o.m.boot_failed`, `SI2.o.m.boot_failed`, `SM2.m2.boot_failed`,
  `MED4.sim.m.boot_failed`, `MED4.ind.m.boot_failed`). Mediators that share one
  outcome model share one resampling run and therefore the same count.
- Bootstrap keys are only written under the composite levels where bootstraps
  run (mean for datasets 1-3, existing for dataset 4). They are omitted, not
  marked failed, under the other levels, as the manifest says bootstraps do not
  run there.
- Values are written with 17 significant digits (`%.17g`).

### Units, samples and influence
- Dataset 1: the unit is the person, identified by `part_uid`; `unit_id` and
  `deleted_unit` are the `part_uid` value. Datasets 2-4: the unit is the row,
  numbered from 1 in file order (header excluded).
- `samples.csv` for dataset 1 lists persons passing the attention filter of the
  sample level (the pairing rule applies only to paired quantities and is not a
  sample filter). Leave-one-out deletes each of these persons in turn; deleting
  an unpaired person leaves the paired estimate unchanged, which is reported as
  such rather than skipped.
- Person-level covariates in dataset 1 (wrongdoing_num, gender, age) come from
  the person's first row in file order. `N1.age.*` uses that one row per person.
- Dataset 1 condition text is trimmed and lower-cased before matching `loyal` /
  `control`. Rows with any other condition value still count toward `N1.rows`
  and the stacked D1/R1 quantities but cannot form a pair.
- Datasets 2 and 3 use the numeric recode columns (`cond_recode`,
  `cond_rel_recode`, `cond_brokhist_recode`) to define groups and to decide the
  expected comprehension answers. A missing recode fails the check.
- `D2_both` keeps a row if at least one of the two checks passes; a missing
  check counts as failing that check.
- Dataset 3 cells: LC = relationship 1 / history 0, CC = 0/0, LD = 1/1, CD = 0/1.

### Statistical details
- Missing columns do not abort the run: the column is treated as all missing
  (with a console warning) and the quantities that need it fail with a reason.
- A quantity whose value is NA, NaN or infinite is written as `failed` with the
  reason `value is missing or not finite` (for example a zero-variance item set).
- 1.96 is used literally wherever the manifest writes it, not `qnorm(.975)`.
- P1 `p_hc3`: intercept-only OLS of the differences with HC3, normal reference.
- ME1: the intercept t test of the sum-coded regression is reported as
  F = t^2, df1 = 1, df2 = residual df; p is the two-sided t p value.
- LMM1: `lme4::lmer` with REML on all retained rows (complete cases on outcome
  and condition), random intercept `(1 | part_uid)`; the nested variant uses
  `(1 | wrongdoing_num/part_uid)`. p is Wald with a normal reference.
  Singular-fit messages, if any, are suppressed; the estimates are still reported.
- G1W `student`/`welch` use all retained rows of the chosen gender and scenario
  as independent observations; `paired` uses the paired persons whose
  person-level gender matches. G1C uses the row's own gender.
- Path models (PM2, SI2, SM2, MED4) use one complete-case sample over every
  variable in that model, so that `total = c_prime + sum(ind)` holds within PM2.
  `total` is the coefficient of condition in the outcome-on-condition regression
  on that same sample. Classical OLS standard errors feed `se_delta`.
- MED4 logit methods take `b` on the log-odds scale; mediator models are OLS.
  MED4 does not involve LoyaltyHouse, so its point estimates are identical under
  the `existing` and `mean` levels; they are reported under both as instructed.
- Bootstrap: `set.seed(seed)` is called immediately before each model's
  resampling loop (one seeded stream per model). A "model" is one outcome
  model: PM2 per outcome (all four indirect effects come from the same
  resamples), SI2 per outcome and mediator, SM2 per m2, MED4.sim per method,
  MED4.ind per method and mediator. Resamples draw rows of the model's
  complete-case data with replacement. A resample is discarded only when the
  fit fails: rank-deficient design, non-finite coefficients, or a logistic fit
  that does not converge. Quantiles use R's default type 7. If every resample
  falls on one side of the estimate, z0 is infinite and the BC bounds are
  written as failed with that reason; the percentile bounds are still written.
  With rare binary outcomes, logistic resamples may show quasi-separation with a
  converged fit; those resamples are kept, as the manifest discards only on
  fit failure, so `se_boot` can be large for the `logit_*` MED4 methods.
- A3: sums of squares are computed from nested OLS fits on the sum-to-zero
  design (type 3 drops each term's columns from the full model; type 2 respects
  marginality; type 1 is sequential in the order relationship, history,
  interaction). F uses the full-model error. `eta2_classic` divides by the
  corrected total SS. Verified equal to `car::Anova` types 2/3 and `anova()`.
- C3 pooled contrast: df is the residual df of the four-cell model (N - 4 when
  all cells are present). `p_hc3` tests the +1/-1 contrast on the cell-indicator
  OLS with HC3, normal reference.
- Cronbach's alpha: k/(k-1) * (1 - sum(item variances)/variance of the item
  sum) on complete cases; correlations are Pearson on pairwise complete cases
  and need at least 3 pairs; t tests need at least 2 observations per group.
- The chi-square test suppresses R's "approximation may be incorrect" warning;
  the statistic is reported regardless of expected counts.
- If a whole dataset cannot be read or an entire dataset block throws, a single
  extra row `DATASETk.read` / `DATASETk.analysis` / `DATASETk.influence` with
  status failed records it, so that nothing fails silently.
