# Analysis manifest P-R7M2, version 1 (frozen)

This manifest fully specifies a set of probit analyses on two public archival files. Implement it exactly. Where a step says "parameter", the value comes from the specification grid (grid.json); the origin value is listed first.

## Inputs (all in data/)

- pow.parquet: prisoner-of-war records (one row per card record). All fields are exact fixed-width character slices (untrimmed strings; some contain NUL characters). Dictionary: dictionaries/data_dictionary_pow.csv; code lists in code_lists/.
- enl.parquet: Army enlistment records (one row per card image), fields as exact character slices. Dictionary: dictionaries/data_dictionary_enl.csv. Read only the columns you need.
- camp_location_crosswalk.csv: one or more rows per camp code with latitude/longitude and a confidence flag (exact, approximate, unknown). Schema: dictionaries/camp_location_crosswalk_schema.md.
- rank_map_grade_alpha.csv and rank_map_grade_code.csv: rank tables (see Rank).

String handling: before comparing a field to a code, remove NUL characters and leading/trailing spaces. A field that is empty after this is blank.

## Sample

1. D0: all POW rows.
2. Service exclusion (parameter svc_exclude; origin ["6","7"]; alternatives ["6"], ["4","6","7"]): drop rows whose SERVICE_CODE is in the set. Blank or other SERVICE_CODE values are kept.
3. Keep DET_POWER in {"1","2"}.
4. Keep STA in {"4","5","7","8","9"}. The result is the descriptive sample D.
5. Valid camp (parameter camp_valid; origin "nonblank"): "nonblank" = CAMP is exactly three characters after cleaning, not blank and not "000"; "defined" = additionally the code appears in code_lists/pow_CAMP_cl1277.csv. Valid report month: DATE_REPORTED_YEAR in {"1",...,"6"} and DATE_REPORTED_MONTH in {"01",...,"12"}.
6. Regression sample R (parameter sample_common; origin true): if true, R = rows of D with valid camp and valid report month, and R is used for every model. If false, camp-cohort models use rows of D with valid camp (report month not required) and captured-cohort models use rows with both.

## Outcome

survival = 1 if STA in {"7","8","9"}; 0 if STA in {"4","5"}. executed = 1 if STA = "4", else 0.

## Groups

- camp = cleaned CAMP code.
- captured cohort = camp + report year + report month, with year = 1940 + DATE_REPORTED_YEAR digit.
- Group members (parameter group_members; origin "regression"): "regression" = rows of the model's estimation sample (R, or the column-specific sample) in the group with a non-missing rank; "file" = all rows of D0 (any service, power or status) with a valid camp (and valid report month for captured cohorts) and a non-missing rank, using the same cleaning; "complete" = members as in "regression" restricted to rows with no missing covariate among height, age, education, dependents.
- n_g = number of group members.

## Rank (nine ranks, 1 = private ... 9 = general)

Parameter rank_rule (origin "origin"):
- "origin": look up cleaned GRADE_ALPHA in rank_map_grade_alpha.csv (column grade_alpha, compared after removing spaces from both sides); use rank_origin_navy if SERVICE_CODE = "2", otherwise rank_origin_service_not_navy. If the label is absent from the table or maps to empty, fall back to GRADE_CODE via rank_map_grade_code.csv: officer columns if the first character of cleaned SERIAL_NO is "O" or "T", otherwise enlisted columns; navy columns if SERVICE_CODE = "2". Empty cells are missing.
- "strict": as "origin" but with the rank_strict_* columns and no GRADE_CODE fallback.
- "grade_code": GRADE_CODE table first (as in the fallback); if missing, the "origin" GRADE_ALPHA lookup.
When a label appears more than once in the table with different values, use the first row.

## Hierarchy measures (computed per group over its members)

- Steepness (ordered Gini): sort members' ranks in nondescending order, index i = 1..n. S = 1 + 1/n - 2 * sum_i (n + 1 - i) * rank_i / (n * sum_i rank_i). One member gives 0.
- Reference fractions p_r, r = 1..9 (parameter pop_fractions; origin "descriptive"): shares of each rank among rows of D with non-missing rank ("descriptive"), or among rows of R with non-missing rank ("regression").
- Sameness: M = 1 - (1/c) * sum_r (f_r - p_r)^2, where f_r is the group's share of rank r. Parameter sameness_constant (origin "fixed"): "fixed" c = 1.319; "recomputed" c = (1 - p_9)^2 + sum_{r=1..8} p_r^2.
- Variables used only in robustness models: alternative ratio sameness A = 1 - (1/10000) * sum_r (f_r / p_r - 1)^2; absolute-deviation sameness = 1 - sum_r |f_r - p_r| / (2 * (1 - p_9)); number of distinct ranks; sum of ranks; administrative intensity = 100 * share of members with rank >= 2.
- A record whose group has n_g = 0 has missing hierarchy and missing group size.

## Regressors

All scaled as stated. Missing values are replaced by 0 and a missing indicator (1 if missing) is added to the model for each variable that has any missing value in the estimation sample; indicators that are constant in the estimation sample are omitted.
- hierarchy: Steepness or Sameness of the model's group type.
- men = ln(n_g) / 10; men_sq = men^2.
- length = months from report month to the end month, divided by 10. End month: May 1945 if DET_POWER = "1", September 1945 if "2". months = (1945 - year) * 12 + (end_month - month).
- japan = 1 if DET_POWER = "2", else 0.
- distance = ln(km) / 10, km = haversine great-circle distance (Earth radius 6371 km) from the camp to Berlin (52.5200, 13.4050) if DET_POWER = "1" or Tokyo (35.6762, 139.6503) if "2". If the camp's identified_place_name is Berlin (power 1) or Tokyo (power 2), km = 1. Parameter coords (origin "crosswalk"): "crosswalk" uses latitude/longitude of the first crosswalk row for the code (lowest entry_id) whose confidence is exact or approximate; "nara_degree" parses nara_degree_coords_text "LAT-LON" as whole degrees north and east (use the crosswalk coordinates when this text is absent). Confidence unknown or no row: missing.
- officer = 1 if rank >= 5, 0 if rank 1..4, missing if rank missing.
- Enlistment covariates come from the linked enlistment record (Linkage). If not linked, they are missing.
  - height: card layout: if CARD_NUM = "3" use ERC_HEIGHT else HEIGHT; integer inches. Parameter height_rule (origin "range"): "range" accepts 48..84 inches, otherwise missing; "none" sets height missing for everyone (the variable and its indicator then drop out as constants). height = inches / 10.
  - age: YR_BIRTH (ERC_YR_BIRTH if CARD_NUM = "3"), two digits, birth year = 1900 + value, age = 1945 - birth year. Parameter age_rule (origin "range"): "range" accepts 15..70, otherwise missing; "none" accepts any value from a two-digit numeric field. age = years / 100.
  - education: EDUCATION (ERC_EDUCATION if CARD_NUM = "3"): code 0 -> 0, 1..4 -> 1..4, 5..8 -> 5..8, 9 -> parameter educ_postgrad (origin 9; alternatives 10, "missing"); other values missing. education = years / 10.
  - dependents: MARITAL_STATUS (ERC_MARITAL_STATUS if CARD_NUM = "3"): codes 1, 3, 4, 5 -> 1; 6, 7, 8, 9 -> 0; code 2 -> parameter married (origin 1; alternatives 0, "missing"); other values missing.

## Linkage

Match cleaned POW SERIAL_NO to cleaned enlistment SER_NUM (replace "#" by space, then clean) as exact strings. Parameter dup_serial (origin "unmatched") for serial numbers with more than one enlistment record: "unmatched" treats the POW row as unlinked; "first" uses the record with the smallest record_seq; "combine" takes, field by field, the common value when all non-blank duplicates agree and missing otherwise. Never expand rows. If several POW rows share a serial number, each is linked independently.

## Models

Probit by maximum likelihood with an intercept. For every model, fit on the estimation sample and report the marginal effect of each regressor at the sample means of all regressors (including fixed-effect dummies and missing indicators): for continuous regressors the derivative phi(xbar'b) * b_k; for binary regressors (japan, dependents, officer, missing indicators) the discrete change Phi(xbar with x_k = 1) - Phi(xbar with x_k = 0). Interaction products are treated as continuous regressors. Standard errors of marginal effects by the delta method from the cluster-robust covariance of the coefficients (sandwich with G/(G-1) small-sample factor, G = number of clusters); two-sided p values from the normal distribution. Report also the coefficients with their cluster-robust standard errors, N, number of clusters, log likelihood, null log likelihood, McFadden pseudo R2 = 1 - LL/LL0, convergence status.

Fixed effects: captured-cohort models include one dummy per camp (one omitted). Before fitting, drop camps whose survival is constant within the estimation sample and record the number of dropped rows and camps. Camp-cohort models have no camp dummies.

Clustering: captured-cohort models cluster by captured cohort; camp-cohort models cluster by camp. For captured-cohort models also report standard errors and p values clustered by camp (parameter-free secondary output).

Model families (G = group type; "cap" captured cohort, "camp" camp):
- T4 (8 models): hierarchy in {steepness, sameness} x G in {cap, camp} x {simple, full}.
  - cap simple: hierarchy + camp dummies (+ hierarchy missing indicator if needed).
  - cap full: hierarchy, men, men_sq, length, height, age, education, dependents, officer, missing indicators + camp dummies.
  - camp simple: hierarchy, japan.
  - camp full: hierarchy, japan, men, men_sq, distance, length, height, age, education, dependents, officer, missing indicators.
- T5 (4 models): as T4 but with both steepness and sameness of G, for {cap, camp} x {simple, full}.
- T5ROC: for each of the four T5 models, compare in-sample areas under the ROC curve (fitted probabilities versus survival) of the T5 model with the T4 model of the same column that omits steepness (row "steepness") or omits sameness (row "sameness"), using the DeLong, DeLong and Clarke-Pearson (1988) test for correlated areas; report both AUCs, difference, z and two-sided p. The rows of the two models must be the same.
- T6 (8 models): T4 models plus officer and officer x hierarchy (the officer main effect is added to simple models).
- Robustness families (each fitted for the listed T4 models with origin parameters):
  - R_cc: full models, rows with no missing covariate (height, age, education, dependents, officer, distance for camp models); group variables unchanged.
  - R_n50, R_n100: all T4 models, rows whose group has n_g >= 50 (>= 100).
  - R_noexec: all T4 models, drop rows with executed = 1 (group variables computed before dropping).
  - R_ger, R_jap: all T4 models on DET_POWER = "1" (resp. "2") rows; camp models omit japan. Group variables computed before subsetting.
  - R_aaf: all T4 models on rows with SERVICE_CODE = "1", ARM_SVC_CODE = "20" (or cleaned ARM_SVC_ALPHA = "AC") and DET_POWER = "1"; camp models omit japan.
  - R_nosq: full models without men_sq.
  - R_alt: the four Sameness T4 models with Sameness replaced by alternative ratio sameness (4 fits) and by absolute-deviation sameness (4 fits); the two full models of each group type (cap full, camp full) with the hierarchy replaced by number of distinct ranks, by sum of ranks, and by administrative intensity (2 fits each, 6 in total).
  - R_friends: unit = TYPE_ORG + PARENT_UNIT_NUM + PARENT_UNIT_TYPE (cleaned; missing if all three are blank). friends (parameter friends_def; origin "incl_self") = ln(number of group members with the same unit, including the row itself), or "others" = ln(number of such members excluding the row; zero gives missing). friends is missing when unit is missing. Fits: cap full and camp full with friends in place of the hierarchy (2 fits); the four full models with hierarchy and friends (4 fits); the four full models with the hierarchy recomputed over the group members sharing the row's unit, with friends (4 fits).
  - R_int: full models plus hierarchy x men (4 fits).
- Influence (only T4 origin): leave-one-camp-out. For each camp in the estimation sample, drop all rows of that camp and refit with all group variables unchanged; record the hierarchy marginal effect, its p value, N and status (including failures). Parameter influence_scope from grid.json says whether all camps or a subset are run.

## Outputs

Write results/results.csv with one row per (spec_id, model_id, term) and columns: spec_id, model_id, family, term, coef, coef_se, me, me_se, me_p, me_se_campcluster, me_p_campcluster, n, n_clusters, dropped_rows_pp, dropped_camps_pp, ll, ll0, pseudo_r2, converged, status, error. Write results/roc.csv, results/influence.csv (spec_id, model_id, deleted_camp, me, me_p, n, status, error), results/sample_ids/<spec_id>__<model_id>.txt (record_seq of the estimation rows, one per line, sorted) and results/run_log.txt. Never stop the whole run on one failed fit: record status "failed" with the error and continue.
