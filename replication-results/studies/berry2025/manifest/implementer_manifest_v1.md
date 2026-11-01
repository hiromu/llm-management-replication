# Analysis manifest PX01

Write one script that reads four CSV files and computes every quantity below. You do not have the real data. You develop against synthetic files with the same columns. Someone else will run your final script on the real files, so it must not depend on anything else in your directory.

## Command line
`<interpreter> script --data DIR --out DIR --seed 20261031 --boot 5000`

Files read: DIR/dataset_1.csv ... dataset_4.csv. Dictionaries for datasets 1-3 are supplied. Dataset 4 has no dictionary; its columns are defined here.

Files written to --out:
- results.csv with columns dataset, sample_level, composite_level, key, method, value, status, message. One row per quantity. value is a number at full precision. status is ok, or failed with the reason in message. A failed quantity still gets a row. Do not stop the run on one failure.
- influence.csv with columns dataset, sample_level, estimand, deleted_unit, estimate, p, status, message.
- samples.csv with columns dataset, sample_level, unit_id: the units retained.
- session_info.txt: software and package versions.

## General rules
- Read every column as text first. Convert analysis columns to numbers; anything that does not parse is missing. Do not filter rows except as stated.
- Missing data: each quantity uses complete cases on the variables it involves. A composite is missing if any of its items is missing.
- All tests are two-sided. p values are exact, never rounded.
- Report SD with the n-1 denominator. Correlations are Pearson on pairwise complete cases. alpha is Cronbach's alpha from complete cases on the items.
- For correlation keys, the two variable names are sorted in byte order and joined with |, for example D1.r.cond_recode|prom_voice.
- Bootstraps resample units (rows in datasets 2 and 4, not used in dataset 1) with replacement, --boot resamples, one seeded stream per model. Bias-corrected interval: z0 = qnorm(share of resamples below the estimate, counting ties as half), lower and upper bounds are the resample quantiles at pnorm(2 z0 - 1.96) and pnorm(2 z0 + 1.96), no acceleration. Percentile interval: quantiles .025 and .975. se_boot is the SD of the resampled estimates. Discard a resample only if the fit fails, and count discards in a key ending .boot_failed.
- Report HC3 p values as p_hc3: an OLS of the outcome on the group contrast with the HC3 covariance, normal reference distribution.
- Run every analysis under every sample level and composite level defined below, except where stated. Bootstraps run only under composite level mean for datasets 1-3, and existing for dataset 4; delta and point estimates run under all levels.

## Sample levels
Dataset 1 has two rows per person, linked by part_uid. Apply filters per person: remove both rows if any row fails.
- D1_key: keep a person only if attn equals wrongdoing_num on every row; a missing attn fails. Then keep persons with exactly one loyal and one control row for paired quantities.
- D1_none: no attention filter. The pairing rule still applies for paired quantities.

Dataset 2:
- D2_any: keep if comp2 == 2 and comp1 matches condition (loyal_colleague needs comp1 == 1, control needs comp1 == 2). A missing check fails.
- D2_both: remove only if both of those checks fail.
- D2_none: no filter.

Dataset 3:
- D3_all: keep if all hold: comp2 == 2; comp1 == 1 for loyal_colleague and comp1 == 2 for control; comp3 == 2 for divisive and comp3 == 1 for control history; attn_afterscen matches cond_num by the map cond_num 1 -> 1, 2 -> 3, 3 -> 2, 4 -> 4. A missing check fails.
- D3_comp: the same without attn_afterscen.
- D3_none: no filter.

Dataset 4:
- D4_loyal: keep rows with non-missing LoyalRequestor.

## Composite levels
- mean: mean of items, computed by you from item columns.
- sum: sum of items, computed by you from item columns.
- existing: the deposited composite column.
Item sets. benev_trust_broker: bentrust_broker1-3. integ_trust_broker: inttrust_broker1-3. val_align_part_broker: me_broker_valal1-2. relconcerns_with_broker: broker_rep1-3. loyal_comb: loyal1-3. Dataset 3 has no dictionary rows for broker_rep1-3; they are the items of relconcerns_with_broker. Dataset 4: LoyaltyHouse from LoyalHouse1-3; for dataset 4 run existing and mean only.
Single-item outcomes (you_grant, prom_voice, proh_voice) are the same under all levels; report them under every level anyway.

## Dataset 1: within-person loyal versus control
Condition: cond (loyal, control). Between-person factor: wrongdoing_num. Outcomes o in you_grant, prom_voice, proh_voice, loyal_comb. Paired quantities use the two rows per person. Difference is loyal minus control.

P1.o, method paired: mean_loyal, sd_loyal, mean_control, sd_control, mean_diff, se_diff, t, df, p, n (persons), d (mean_diff / sqrt((sd_loyal^2 + sd_control^2)/2)), dz (mean_diff / SD of differences), p_hc3 (test of the mean of the differences).

For o in you_grant, prom_voice, proh_voice:
- M1.o, method mixed_anova: F, df1, df2, p for the condition by wrongdoing interaction. Compute as the one-way ANOVA of the per-person differences on wrongdoing_num.
- ME1.o, method mixed_anova: F, df1, df2, p for the condition main effect: intercept test of the regression of differences on sum-coded wrongdoing_num.
- LMM1.o, method ri_person: coef, se, p (Wald, normal reference) for condition (cond_recode), linear mixed model by REML with a random intercept for part_uid. Method ri_person_wrongdoing adds a random intercept for wrongdoing_num with persons nested in it.

D1 on all retained rows, stacked: D1.mean.v and D1.sd.v and pairwise D1.r for cond_recode, you_grant, prom_voice, proh_voice.

R1 on all retained rows, stacked: R1.loyal_comb.alpha from loyal1-3; R1.perceived_ethic_import.alpha from pie1, pie2, pie3, pie4_rev. Inter-item correlations: R1.magnitude.r (magnitude1_rev, magnitude2), R1.prob_of_effect.r (prob_effect1, prob_effect2_rev), R1.temp_immediacy.r (temp_imm1, temp_imm2_rev), R1.proximity_effect.r (proxim_eff1_rev, proxim_eff2), R1.social_consensus.r (social_cons1, social_cons2_rev), R1.concentration_of_effect.r (concen_eff1_rev, concen_eff2).

N1: N1.rows, N1.n (persons in paired quantities), N1.age.mean and N1.age.sd (one row per person).

Subgroups use you_grant, gender 1 = female and 2 = male, others excluded. g is male or female.
- G1W.s.g: loyal versus control within gender g, where s is sexual_harassment (wrongdoing_num == 1) or all. Quantities t, df, p under each of method paired, student and welch. Student and welch treat rows as independent.
- G1C.w.c: male versus female, male minus female, within condition c (loyal, control) and scenario w, where w is sexual_harassment, theft, false_advertising, fraud, bribery, plagiarism, dishonesty (wrongdoing_num 1-7) or average (all scenarios). Quantities mean_male, sd_male, mean_female, sd_female (method descriptive), t, df, p under method student and welch.

## Dataset 2: two independent groups
Condition: cond_recode (1 = loyal_colleague, 0 = control). Outcomes o in you_grant, prom_voice, proh_voice. Mediators m in benev_trust_broker, integ_trust_broker, val_align_part_broker, relconcerns_with_broker.

T2.o: mean_loyal, sd_loyal, mean_control, sd_control, mean_diff, d (mean_diff / pooled SD), p_hc3 (method descriptive); t, df, p under method welch and method student.

Path models are OLS. a is the coefficient of condition in m on condition. In the parallel model, b is the coefficient of m in o on condition and all four mediators.

PM2.o.m (parallel), method ols: ind (a times b), a, b, c_prime, total, se_delta (sqrt(a^2 se_b^2 + b^2 se_a^2) with classical OLS SEs), p_delta (ind / se_delta, normal reference), ci_norm_low, ci_norm_high (ind +/- 1.96 se_delta), se_boot, ci_bc_low, ci_bc_high, ci_perc_low, ci_perc_high.

SI2.o.m (m alone as the only mediator), method ols: the same quantities.

SM2.m2 (serial), for m2 in val_align_part_broker, relconcerns_with_broker, outcome you_grant: condition -> benev_trust_broker -> m2 -> you_grant. Models: benev on condition; m2 on condition and benev; you_grant on condition, benev and m2. ind is the product of the three paths a1, d21, b2. Report ind, a1, d21, b2, se_delta (sqrt((d21 b2)^2 var_a1 + (a1 b2)^2 var_d21 + (a1 d21)^2 var_b2)), p_delta, se_boot, ci_bc_low, ci_bc_high, ci_perc_low, ci_perc_high.

D2: D2.mean.v, D2.sd.v and pairwise D2.r for cond_recode, the three outcomes and the four mediators.

R2: R2.benev_trust_broker.alpha, R2.integ_trust_broker.alpha, R2.relconcerns_with_broker.alpha, R2.val_align_part_broker.r, R2.benev_trust_accused.alpha (bentrust_accused1-3), R2.integ_trust_accused.alpha (inttrust_accused1-3), R2.integ_trust_accused_rev3.alpha (the same with inttrust_accused3 reversed as 8 minus the item), R2.group_cohesion_pre.alpha, R2.group_cohesion_post.alpha (their three items each).

N2: N2.n (rows), N2.n_loyal, N2.n_control, N2.age.mean, N2.age.sd.

Subgroups on you_grant, gender coded as dataset 1.
- G2W.all.g: loyal versus control within gender g: t, df, p under method student and welch.
- G2C.c: male minus female within condition c (loyal, control): mean_male, sd_male, mean_female, sd_female (method descriptive), t, df, p under method student and welch.

## Dataset 3: two by two between persons
Factors: relationship, cond_rel_recode (1 = loyal_colleague); history, cond_brokhist_recode (1 = divisive). Outcomes o: you_grant, prom_voice, proh_voice, benev_trust_broker, integ_trust_broker, val_align_part_broker, relconcerns_with_broker. Cells: LC (loyal, control history), CC (control, control history), LD (loyal, divisive), CD (control, divisive).

A3.o.term, for term in relationship, history, interaction: F, df1, df2, p, eta2 (SS_term / (SS_term + SS_error)), eta2_classic (SS_term / SS_total) under method type3 (sum-to-zero coding), type2 and type1 (order relationship, history, interaction).

C3.cell.o.cell: mean, sd, n (method descriptive).

Contrasts: C3.H1.o is LC minus CC. C3.H3.o is LC minus LD. Quantities under method pooled (the full four-cell model MSE, df = N - 4), student (the two cells only) and welch (the two cells only): mean_diff, t, df, p. Under method descriptive: d (mean_diff / sqrt((sd_a^2 + sd_b^2)/2)), d_pooled (mean_diff / two-cell pooled SD), p_hc3 (HC3 from an OLS on the four cell indicators, testing the contrast).

D3: D3.mean.v, D3.sd.v and pairwise D3.r for cond_rel_recode, cond_brokhist_recode and the seven outcomes.

R3: R3.benev_trust_broker.alpha, R3.integ_trust_broker.alpha, R3.relconcerns_with_broker.alpha, R3.val_align_part_broker.r.

N3: N3.n, N3.age.mean, N3.age.sd.

## Dataset 4: binary outcome, measured predictor
Columns: Signed (1 = signed, 0 = did not sign). LoyalRequestor (1-7 loyalty to the requester). KnowRequestor, LikeRequestor (1-7). SemestersRequestor (semesters known). LoyaltyHouse (three-item house loyalty, LoyalHouse1-3). SignedTrust, SignedRisk (reasons for the decision). StrongLoyaltyRequestor, ExpLoyaltyRequestor: transformed LoyalRequestor. Age.

Logistic regression by maximum likelihood.
- L4.M1: Signed on LoyalRequestor.
- L4.M2: adds KnowRequestor, LikeRequestor, SemestersRequestor.
- L4.M3: adds LoyaltyHouse to M2.
For each term: L4.Mk.term.coef, se (model-based), z, p, or (exp coef), p_hc0 (sandwich HC0, normal reference); method logit. Fit: L4.Mk.fit.ll, mcf (1 - ll/ll_null), cs (1 - exp(2 (ll_null - ll) / n)), n.

Alternatives, method logit, one predictor each in place of LoyalRequestor in M1: L4.ALT.strong (StrongLoyaltyRequestor), L4.ALT.exp (ExpLoyaltyRequestor), L4.ALT.house (LoyaltyHouse): coef, se, z, p, or. CHI4.strong: chi2, df, p (Pearson, no continuity correction) for Signed by StrongLoyaltyRequestor.

Mediation with mediators SignedTrust and SignedRisk. MED4.sim.m has both mediators in the outcome model. MED4.ind.m has m alone. Run under four methods. linear_cont and logit_cont use X = LoyalRequestor. linear_strong and logit_strong use X = StrongLoyaltyRequestor. linear uses OLS for the outcome model; logit uses logistic regression for the outcome model and reads b on the log-odds scale. The mediator models are always OLS. Report ind, a, b, se_delta, p_delta, se_boot, ci_bc_low, ci_bc_high, ci_perc_low, ci_perc_high.

D4: D4.mean.v, D4.sd.v and pairwise D4.r for Signed, LoyalRequestor, KnowRequestor, LikeRequestor, SemestersRequestor, LoyaltyHouse.

N4: N4.n, N4.signed_count, N4.signed_share, N4.age.mean, N4.age.sd.

## Leave-one-out influence
Under every sample level, with composite level mean (dataset 4: existing), refit after deleting one unit at a time, for every unit retained. The unit is a person (part_uid) in dataset 1 and a row in the others; number rows from 1 in file order and use that number as unit_id everywhere. Keep failures as rows. No bootstrap. estimate and p are:
- P1.o for you_grant, prom_voice, proh_voice: mean_diff and p of the paired t.
- T2.o for the three outcomes: mean_diff and p of the welch t.
- PM2.o.m for all o and for m in benev_trust_broker, val_align_part_broker, relconcerns_with_broker: ind and p_delta.
- C3.H1.o and C3.H3.o for you_grant, prom_voice, proh_voice: mean_diff and p of the pooled contrast.
- L4.Mk.LoyalRequestor for k in 1, 2, 3: coef and p.

## Quality
Write clear code with no hard-coded numeric results. Never tailor anything to any expected value: you have none. If an item cannot be met, record it as failed with the reason. Output keys must be exactly as written, with variable names substituted.
