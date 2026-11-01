# Implementation manifest PAPER_X, version 1

This manifest specifies a complete analysis of six survey data files. Implement it exactly. Where an operation is not specified, use the stated software default and record what you used. Do not add analyses that are not requested.

## 1. Data

Six gzip-compressed CSV files in data/, one per survey year and questionnaire form, holding every record and every variable of the source file as raw numeric codes (declared missing codes kept as numbers, system-missing as empty fields). Variable dictionaries for the same files are in dictionaries/.

| Key | File | Year group | Form |
| --- | --- | --- | --- |
| y1976_f3 | data/y1976_f3.csv.gz | 1976 | Form 3 |
| y1991_f3 | data/y1991_f3.csv.gz | 1991 | Form 3 |
| y2006_f3 | data/y2006_f3.csv.gz | 2006 | Form 3 |
| y1976_f4 | data/y1976_f4.csv.gz | 1976 | Form 4 |
| y1991_f4 | data/y1991_f4.csv.gz | 1991 | Form 4 |
| y2006_f4 | data/y2006_f4.csv.gz | 2006 | Form 4 |

Identifiers: V4 = respondent serial number (unique within a file). V5 = sampling weight. Form 3 and Form 4 respondents are different people; never pool or merge forms. Year groups are always 1976, 1991, 2006 in this order. Pairwise comparisons are always (earlier, later) in this order: P1 = (1976, 1991), P2 = (1991, 2006), P3 = (1976, 2006). Every difference is later minus earlier.

## 2. Variables and coding

Form 4 items (all three Form 4 files, same variable names): V4225 to V4247 (23 items). Valid codes 1, 2, 3, 4. Every other value (0, 8, 9 or higher, -9, empty) is missing. Keep native coding (higher = more important). "Top category" indicator: code 4.

Form 3 items (all three Form 3 files): V3222, V3223, V3224, V3225, V3226 (valid codes 1-5; top-category indicator: code 4 or 5) and V3227 (valid codes 1, 2; top-category indicator: code 1). Every other value is missing. Item statistics use native coding.

Weight V5: valid if strictly positive and not a declared missing code for that file (see dictionaries); used only in specification S01.

Factors (Form 4). Marker item listed first in brackets; items marked * are "released" items (see 4.4).

| Factor | Items | Marker (S00) |
| --- | --- | --- |
| K1 | V4236, V4238*, V4240*, V4246 | V4236 |
| K2 | V4227, V4225, V4231*, V4232, V4234, V4242, V4243 | V4227 |
| K3 | V4235, V4229* | V4235 |
| K4 | V4233, V4245 | V4233 |
| K5 | V4226, V4228*, V4230*, V4244 | V4226 |
| K6 | V4239, V4241 | V4239 (single-group seven-factor model only) |
| K7 | V4237, V4247 | V4237 (single-group seven-factor model only) |

The 19 items of K1-K5 are the "model items". The 23 items of K1-K7 are "all Form 4 items".

Form 3 factors (single-group model only): C1 = {V3224, V3225, 6 - V3222, 6 - V3223, 3 - V3227} with marker V3224 (reversals orient all indicators in the same direction; they do not change fit); C2 = single indicator V3226 with loading fixed to 1 and residual variance fixed to 0.

## 3. Samples (S00 unless a specification says otherwise)

- Item statistics: per item and year, all records with a valid code on that item.
- Single-group CFA per year: records complete (valid) on all items of that model.
- Multigroup models: within each year, Form 4 records complete on the 19 model items.
- Coefficient alpha: per scale and year, records complete on that scale's items.
- No other exclusions (no age, sex, race, region or other filters). Record the number of rows read per file and every analysis n.
- Record for each analysis sample the SHA-256 of the ascending, newline-separated list of V4 values (per year group).

## 4. Models

All models are confirmatory factor models for continuous indicators: x = nu_g + Lambda_g eta + eps, E[eta] = alpha_g, Cov(eta) = Psi_g (all factor covariances free), Cov(eps) = Theta_g diagonal. Fit with normal-theory maximum likelihood on sample means and covariances:

F_g = log|Sigma_g| + tr(S_g Sigma_g^-1) - log|S_g| - p + (m_g - mu_g)' Sigma_g^-1 (m_g - mu_g),
minimize sum_g c_g F_g, chi-square = sum_g c_g F_g at the minimum.

S00: S_g has divisor n_g - 1 and c_g = n_g - 1 (Wishart convention). Standard errors from the expected information matrix at the solution (lavaan information = "expected"). Converge tightly (relative gradient or function tolerance 1e-8 or better); report convergence status.

Fit indices for every model: chi-square, df (number of sample moments p(p+3)/2 per group minus free parameters), p value, RMSEA = sqrt(G) * sqrt(max(chi2 - df, 0) / (df * sum_g c_g)), CFI and TLI against a baseline model with free item means and variances and zero covariances in every group (no cross-group constraints), and SRMR = sum_g (n_g/N) * SRMR_g where SRMR_g is the root mean square over the p(p+1)/2 lower-triangle elements (including the diagonal) of (s_ij - sigma_ij)/sqrt(s_ii s_jj), mean residuals excluded.

4.1 Single-group models, each year separately: (a) Form 3 C1-C2 model; (b) Form 4 seven-factor model on all 23 items (K1-K7); (c) Form 4 five-factor model on the 19 model items (K1-K5). Marker loadings 1; item intercepts free, factor means 0 (saturated mean structure).

4.2 Multigroup sequence (Form 4, 19 items, three year groups):
- M1 configural: same pattern, all loadings (except markers, fixed to 1), intercepts, factor covariances and residual variances free in each group; factor means fixed to 0.
- M2 metric: M1 with each loading equal across groups.
- M3 scalar: M2 with every item intercept equal across groups, marker intercepts fixed to 0 in every group, factor means free in every group.
- M4 partial scalar: M3 except the intercepts of V4238, V4240, V4231, V4229, V4230, V4228 are free in every group (not equal across groups). Marker intercepts stay fixed to 0.
- M5: M4 with each factor mean equal across the three groups.
Report every fit index for M1-M5, and the differences M2-M1, M3-M2, M4-M2, M5-M4 (chi-square difference, df difference, p value, and CFI difference = CFI of the less constrained model minus CFI of the more constrained model).

4.3 Latent outputs from M4, for each factor K1-K5 and group: alpha_gk (latent mean), its SE, 95% CI alpha_gk +/- 1.96 SE, factor variance psi_gk and SD sqrt(psi_gk). For each factor and pair (a, b): Delta = alpha_bk - alpha_ak; SE of Delta from the parameter covariance matrix including the covariance term; z = Delta / SE; two-sided normal p.

4.4 Standardized contrasts for each factor and pair, all from M4:
- d_eq = Delta / sqrt((psi_a + psi_b) / 2)  (primary)
- d_df = Delta / sqrt(((n_a - 1) psi_a + (n_b - 1) psi_b) / (n_a + n_b - 2)), n = multigroup analysis n
- g = d_eq * (1 - 3 / (4 (n_a + n_b) - 9))
- d_glass = Delta / sqrt(psi_a)  (earlier group)
- d_obs = Delta / sqrt((s_a^2 + s_b^2) / 2), where s_g is the SD (divisor n_g - 1) of the unit-weighted mean of the factor's items in group g on the multigroup analysis sample.

4.5 Coefficient alpha (raw covariance version, alpha = k/(k-1) * (1 - sum of item variances / variance of the item sum)) per year for K1-K7 and C1 (C1 with the reversals in Section 2).

4.6 Item statistics, for every Form 4 item and Form 3 item and every year: n, mean, SD (divisor n - 1), percentage in the top category. For every item and pair: mean difference, Student pooled-variance t, df, two-sided p; Welch t, Welch-Satterthwaite df, two-sided p; difference in percentage.

## 5. Specification grid

Run every specification below. Each is a one-at-a-time change to S00 unless stated. Keep everything else as in S00.

| ID | Change from S00 | Outputs required |
| --- | --- | --- |
| S00 | none | everything in Section 4 |
| S01 | Weighted: within each file, drop records with invalid V5 (count them), normalize weights to sum to the record count of the sample in question (w* = w n / sum w). Weighted means and covariances (divisor n - 1) are the sample moments for every model (c_g = n_g - 1, nominal n). Item statistics: weighted mean, weighted percentage, weighted SD with s_w^2 = sum w (x - m)^2 / (W - sum w^2 / W); approximate test z = diff / sqrt(v_a + v_b) with v = s_w^2 * sum w^2 / W^2, two-sided normal p (report in place of Student and Welch). Alpha from the weighted covariance. | everything in Section 4 |
| S02 | ML normalization: S_g divisor n_g, c_g = n_g; RMSEA uses sum_g n_g | 4.2, 4.3, 4.4 |
| S03 | Form 4 samples (item statistics, all Form 4 models, alpha) restricted to records complete on all 23 Form 4 items; Form 3 samples to records complete on all 6 Form 3 items | everything in Section 4 |
| S04 | Multigroup models by full-information ML on raw data, using Form 4 records with at least one valid value among the 19 model items (missing at random; c_g = n_g) | 4.2, 4.3, 4.4 |
| S05 | Effects-coding identification in M3-M5: no marker constraints; for each factor and group the loadings average 1 and the item intercepts sum to 0 (released intercepts included in the sum); factor means free in every group. M1-M2 unchanged. | 4.2, 4.3, 4.4 |
| S06 | Robust standard errors: ML point estimates with sandwich (Huber-White, observed-score) covariance using the raw complete-case data, n_g normalization (lavaan estimator = "MLR"); report robust z and p for latent contrasts and the scaled chi-square | 4.2, 4.3, 4.4 |
| S07a | Seven-factor single-group model with K6 = {V4239, V4237}, K7 = {V4241, V4247} | 4.1(b) and alpha for K6, K7 |
| S07b | Seven-factor single-group model with K6 = {V4239, V4247}, K7 = {V4241, V4237} | 4.1(b) and alpha for K6, K7 |
| S08 | Form 3 single-group model with one factor on V3222-V3226 (V3222 and V3223 reversed as 6 - x, marker V3224), V3227 excluded | 4.1(a) and alpha |
| CHK1 | M4 identified by fixing the 1976 factor means to 0 and 1976 factor variances to 1, all loadings free (equal across groups), all non-released intercepts equal across groups; then compute Delta and the d variants from the estimated means and variances | 4.3, 4.4 |
| CHK2 | M1-M5 with markers K1 V4246, K2 V4225, K3 V4235, K4 V4245, K5 V4244 | 4.2, 4.3, 4.4 |

## 6. Influence mode

Implement a separate mode that, for the S00 M4 model, deletes one respondent at a time from the multigroup analysis sample (in ascending order of year group then V4), refits M4 on the remaining records (warm-start from the full-sample estimates; sample moments may be recomputed by exact downdating), and records for every deletion: deleted year group, deleted V4, convergence status, any error message, and d_eq and the two-sided p (from 4.3) for all 15 factor-by-pair contrasts. Keep failed fits as rows with their reason. The mode takes a start index and a maximum number of deletions so it can run in chunks. Output CSV columns: idx, del_group, del_V4, status, message, d_eq_K1_P1 ... d_eq_K5_P3, p_K1_P1 ... p_K5_P3.

## 7. Outputs

One script (or one entry-point script plus modules) with a command-line interface: run a named specification (or all) and write results/<spec_id>.json; run the influence mode with start and limit and write results/influence_<start>_<end>.csv. Each JSON must contain: spec_id; status (ok, failed or unavailable) with reason; software and package versions; rows read per file; every analysis n and sample V4 hash; all requested quantities with full numeric precision; convergence status of every model; and any deviation from this manifest with a reason. Use the variable names, factor IDs (K1-K7, C1, C2), model IDs (M1-M5) and pair IDs (P1-P3) of this manifest. Do not round.

Include a README.md describing how to run the script, and test the code on synthetic data with known structure before running it on the supplied files.
