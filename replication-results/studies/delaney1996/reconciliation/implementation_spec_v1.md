# Implementation specification PAPER_K7, version 1 (frozen)

You are implementing a fixed set of linear regressions on an establishment survey file. Write one parameterized script that runs every specification in `grid_v1.json` and writes the outputs described below. Do not search for or use any other information about the study that produced this specification.

## 1. Inputs

- `data/survey.csv`: one row per establishment interview record, all columns numeric, original variable names, raw stored codes. Declared missing codes have NOT been converted; you must apply them.
- `data/survey_metadata.json`: per variable: label, value labels and declared missing values.
- `data/industry_crosswalk.csv`: Census 1980 industry code to two-digit 1972 SIC major groups (`census1980_code`, `sic2_from_printed`; the latter may hold several groups separated by commas, or be empty).
- `grid_v1.json`: the specifications (an origin plus single-axis deviations and algebraic checks), each a mapping from axis to level.
- The development copy of `survey.csv` you receive is synthetic (each column independently permuted), so routing patterns are broken and results are meaningless. The real file has the same columns and codes. Never assume a particular row count.

Record identifier: `V1` (unique per row).

## 2. General coding rules

- Apply declared missing codes per variable from the metadata unless a rule below says otherwise. Code 7 "Not applicable" is missing wherever declared. System-missing (blank) is missing.
- "Reverse" a 1..k item means k+1-x.
- An index computed under the `item_rule` axis:
  - `L0`: mean of the valid items (at least one valid item required).
  - `L1`: all items must be valid, otherwise missing.
  - `L2`: first apply the copy rule (section 4.9), then as L0.
- Natural logarithms throughout. A log of a value <= 0 is missing unless a level says otherwise.

## 3. Record frame and samples

- Axis `records`: `L0` keep all rows; `L1` drop rows with `V3 == 0`.
- Organizational family (outcome `POP`): all rows of the frame.
- Market family (outcome `PMP`), axis `market_sample`: `L0` rows with `V8 == 1`; `L1` rows with `V8 == 1` and `V9 == 4`.
- Axis `market_requires_pop`: `L0` the market family does not require `POP`; `L1` the market family additionally requires a valid `POP`.
- Axis `case_scope`:
  - `L0` common complete cases within each family. A row enters the family sample if it is valid on the family outcome, all seven HRM indices, all of the family's controls, and the industry group. Every model of that family uses exactly this sample.
  - `L1` model-specific complete cases. Each regression uses the rows valid on its own variables. For a nested F test, both the restricted and the full model are fitted on the full model's rows.
- Exclusions created by coding rules (for example the `neither` rule in 4.12 or industry exclusions in 4.14) make the variable missing, so the row leaves the sample through the complete-case rule.

## 4. Variables

### 4.1 POP (outcome)
Items V289-V295 (codes 1 much better .. 4 worse; 7/8/9 missing). Reverse each item (5-x). POP = index of the seven reversed items under `item_rule`.

### 4.2 PMP (outcome)
Items V296-V299, same coding as POP. PMP = index of the four reversed items.

### 4.3 STAFF (applications per opening)
Items V62 (CORE), V97 (GSS occupation), V131 (managers). Codes 998/999 are missing; 997 "not applicable" is missing. Axis `staff_coding`:
- `L0`: item = ln(x) for numeric counts x >= 1 (excluding codes 995-999); 0 and 995 are missing.
- `L1`: item = ln(1+x) for x >= 0 (excluding 995-999); 995 is missing.
- `L2`: as L0, but 995 is kept as the value 995 (item = ln 995).

Each transformed item is converted to a standard score (section 4.10), and STAFF is the index (`item_rule`) of the three standard scores.

### 4.4 TRAIN (training)
Items:
- V145: any formal job training, 1 yes / 2 no. Recode yes = 2, no = 1.
- V157: number of employees who participated. 99996 means 100,000 or more; use 100000.
- V172: effectiveness, 1 highly / 2 somewhat / 3 not at all; 4 "varies/depends" is missing. Reverse it (4-x), so 3 = highly effective.

Axis `no_training`, for rows with V145 = no (where V157 and V172 are skipped):
- `L0`: V157 and V172 missing.
- `L1`: V157 = 0 and V172 = 1 (the lowest effectiveness, after reversal).
- `L2`: V157 = 0 and V172 missing.

Axis `train_log`:
- `L0`: log each of the three items. Under no_training L0, V157 uses ln(x) with x >= 1 and 0 missing; under no_training L1 or L2, V157 uses ln(1+x) for all rows.
- `L1`: log only the V157 count (same rule as L0); V145 and V172 enter untransformed.
- `L2`: no logarithms.

Each resulting item is converted to a standard score (4.10). TRAIN is the index (`item_rule`) of the three standard scores.

### 4.5 INCENT (incentive compensation)
Items V209 (managers), V222 (CORE), V235 (GSS occupation): importance of job performance for earnings, 1 very .. 3 not. 7/8/9 are missing. Reverse each (4-x). INCENT = index of the three items. Not standardized.

### 4.6 GRIEV (grievance procedure)
V270: 1 yes gives 1, 2 no gives 0. 7/8/9 are missing.

### 4.7 DECENT (decentralization)
Eight decisions. Use V271-V278 when V17 == 1 (part of a larger organization) and V279-V286 when V17 == 2. Codes: 1 head of organization, 2 someone below, 3 someone at larger organization / above, 4 head and below, 5 head and larger organization / above, 6 depends; 7/8/9 missing.

Axis `decision_map`:
- `L0`: 3 -> 1, 5 -> 2, 1 -> 3, 4 -> 4, 2 -> 5.
- `L1`: 1 -> 1, 5 -> 2, 3 -> 3, 4 -> 4, 2 -> 5.

Code 6 is missing under both levels. DECENT = index of the eight mapped items.

### 4.8 ILM (internal labor market)
Items V67, V76, V102, V111, V136: 1 yes / 2 no, 8/9 missing. Reverse (3-x) so yes = 2. ILM = index of the five items.

### 4.9 Copy rule (item_rule L2 only)
GSS-occupation items are skipped when the GSS occupation equals the CORE occupation. Mark a row as "GSS = CORE" when V79 == 2 or V79 is system-missing while the CORE item is valid. For such rows, set the GSS item to the corresponding CORE item:
- V97 <- V62
- V102 <- V67
- V111 <- V76
- V235 <- V222

Manager items are skipped when managers are the CORE or GSS occupation. Mark a row as "manager same" when V114 == 2 or V114 is system-missing. For such rows, set each manager item to the CORE item, or to the GSS item when the CORE item is missing:
- V131 <- V62 / V97
- V136 <- V67 / V102
- V209 <- V222 / V235

Apply the copy before transformations and standardization.

### 4.10 Standard scores (STAFF and TRAIN items)
Axis `z_reference`:
- `L0`: standardize each transformed item over all rows of the record frame with a valid value, using that set's mean and sample SD (n-1). The same values serve both families.
- `L1`: standardize each item within the organizational-family analysis sample. Find that sample first; it does not depend on the standardization. The market family uses the same standardized values.
- `L2`: standardize within each family's own analysis sample separately.
- `L3`: as L0, but with the population SD (n).

Averaging into the index happens after standardization. Under L1 and L2, rows outside the reference sample keep the L0 values, which are irrelevant to that family.

### 4.11 VHIER (vertical hierarchy)
V261: number of levels. 98/99 missing; 96 means 100 or more. Axis `hierarchy`:
- `L0`: ln(V261), with 96 taken as 100.
- `L1`: ln(V261), with 96 missing.
- `L2`: raw count, with 96 taken as 100.

### 4.12 Controls
- NONPROF: V8 == 2 gives 1, V8 == 1 gives 0. Organizational family only; omitted from the market family.
- SUBSID, axis `subsidiary`:
  - `L0`: V17 == 1 gives 1, else 0.
  - `L1`: V21 == 2 gives 1. Other V21 values give 0, and V17 == 2 gives 0. V21 8/9 are missing.
  - `L2`: V21 in {1, 2, 3} gives 1, otherwise as L1.
- LOGEMP, axis `employment`:
  - `L0`: ln(V23 + V32), with 99998/99999 missing in either component.
  - `L1`: ln(NEWTOTAL).
  - `L2`: ln(V23).
- LOGAGE (age = 1991 - V16; 9998/9999 missing), axis `age`:
  - `L0`: ln(age), with age <= 0 missing.
  - `L1`: ln(1 + age), with age < 0 missing.
  - `L2`: age in years.
- PCTMGR, axis `pct_managers`. The numerator is V115 when V114 == 1, 0 when V114 == 3, and missing otherwise:
  - `L0`: 100 x numerator / (V23 + V32).
  - `L1`: as L0, but the numerator is missing when V114 == 3.
  - `L2`: as L0, but the denominator is NEWTOTAL.
  - Missing whenever the denominator is missing or 0.
- UNION, axis `union_items`, with each item reversed (4-x) and the index taken under `item_rule`:
  - `L0`: V220 and V233.
  - `L1`: V220, V233 and V300.
  - `L2`: V220, V233, V300 and V166 (V166 yes gives 3, no gives 1).
- PRODUCT and SERVICE: V41 == 1 gives PRODUCT = 1, V41 == 2 gives SERVICE = 1, and V41 == 3 (both) is the omitted category. 8/9 are missing. Axis `neither` for V41 == 4:
  - `L0`: missing.
  - `L1`: PRODUCT = 0 and SERVICE = 0.
- COMPET, axis `competition`, on V328 (1 none .. 4 a great deal; 7/8/9 missing):
  - `L0`: V328 as is.
  - `L1`: V328 == 4 gives 1, else 0.
  - `L2`: V328 >= 3 gives 1, else 0.

### 4.13 Control lists
- Organizational family: NONPROF, SUBSID, LOGEMP, LOGAGE, PCTMGR, UNION, PRODUCT, SERVICE, COMPET, plus industry dummies.
- Market family: the same list without NONPROF.

### 4.14 Industry groups
Use V43 (1980 Census industry code). Look it up in the crosswalk. Axis `industry`:
- `L0`:
  - The group is the first two-digit SIC listed in `sic2_from_printed`.
  - When the field is empty, or V43 is not in the crosswalk, the group is "UNCL".
  - Enter one dummy per group present in the family sample, omitting the group with the most rows in that sample (ties: the lowest code).
- `L1`: rows whose V43 has more than one listed group, an empty field, or no crosswalk entry are missing on industry. Other rows are as L0.

If a dummy column is all zero, or collinear in a given estimation sample, drop it and record the drop.

## 5. Models

Each family runs the following, with an intercept, the controls of 4.13 and industry dummies:

| Model | Organizational / Market | HRM terms | Interactions |
|---|---|---|---|
| base | org_base / mkt_base | none | none |
| single | org_M1_<p> / mkt_M6_<p> for each p in STAFF, TRAIN, INCENT, GRIEV, DECENT, ILM, VHIER | p alone | none |
| A | org_M2 / mkt_M7 | STAFF, TRAIN, INCENT, GRIEV, DECENT, ILM | none |
| B | org_M3 / mkt_M8 | STAFF, TRAIN, INCENT, GRIEV, DECENT, VHIER | none |
| A+int | org_M4 / mkt_M9 | as A | TRAIN x STAFF, GRIEV x INCENT, ILM x DECENT |
| B+int | org_M5 / mkt_M10 | as B | TRAIN x STAFF, GRIEV x INCENT, VHIER x DECENT |

Axis `centering`: `L0` interactions are raw products. `L1` interactions are products of components centered at their means in that model's estimation sample; the main effects stay uncentered.

Axis `weights`: `L0` OLS. `L1` WLS with weight `WEIGHT`; rows with WEIGHT <= 0 or missing are excluded under L1.

Nested tests (F, numerator df = number of added terms, denominator df = residual df of the larger model):
- HRM block: org_M2 vs org_base, org_M3 vs org_base, mkt_M7 vs mkt_base, mkt_M8 vs mkt_base.
- Interaction block: org_M4 vs org_M2, org_M5 vs org_M3, mkt_M9 vs mkt_M7, mkt_M10 vs mkt_M8.

Both models of a nested pair use identical rows. Report delta R2 and F. For WLS, use the weighted R2 and the corresponding F.

## 6. Statistics to report for every coefficient

- estimate
- conventional OLS/WLS SE
- t
- residual df
- two-sided p
- upper-tail p (H: beta > 0)
- lower-tail p
- HC3 SE, with HC3 t and HC3 upper/lower/two-sided p (t distribution, residual df)

For every model, report:
- N
- number of parameters
- number of industry dummies used, and any dropped columns
- R2 and adjusted R2
- overall F with its df (all slopes, including industry dummies, against intercept-only) and p
- status (ok / failed with reason)

## 7. Influence diagnostic (origin specification only)

For each of org_M2, org_M3, org_M4, org_M5, mkt_M7, mkt_M8, mkt_M9 and mkt_M10:
- Refit the model once per row of its estimation sample, deleting that one row (the deletion unit is the establishment interview record).
- Keep all variable values fixed, including standard scores, centering means (centering L0 has none) and industry groups.
- Record, for every HRM and interaction term: the deleted V1, estimate, conventional SE, upper-tail p and two-sided p.
- If a deletion makes a dummy column all zero, drop that column and flag it. If a refit fails, record the failure with its reason.
- Retain every deletion, including failures.

## 8. Outputs (write to the output directory given on the command line)

| File | Contents |
|---|---|
| `coefficients.csv` | spec_id, family, model_id, term, estimate, se, t, df, p_two, p_upper, p_lower, se_hc3, t_hc3, p_two_hc3, p_upper_hc3, p_lower_hc3 |
| `model_stats.csv` | spec_id, family, model_id, status, error, n, k, n_industry_dummies, dropped_columns, r2, adj_r2, f, f_df1, f_df2, f_p |
| `nested_tests.csv` | spec_id, family, test_id, full_model, restricted_model, n, delta_r2, f, df1, df2, p |
| `samples.csv` | spec_id, family, model_id, V1 (one row per record used; for case_scope L0 one set per family is enough with model_id = "ALL") |
| `influence.csv` | model_id, deleted_V1, term, estimate, se, p_upper, p_two, status, note |
| `run_info.json` | software, versions, start/end time, list of specs run, failures |

Use `NA` for missing values. Terms are named exactly: STAFF, TRAIN, INCENT, GRIEV, DECENT, ILM, VHIER, TRAIN_x_STAFF, GRIEV_x_INCENT, ILM_x_DECENT, VHIER_x_DECENT, NONPROF, SUBSID, LOGEMP, LOGAGE, PCTMGR, UNION, PRODUCT, SERVICE, COMPET, (Intercept), and IND_<group>.

## 9. Algebraic checks in the grid

Specs whose id starts with `CHK_` change one representation:
- `hierarchy_log10`: VHIER = log10 of the L0 value.
- `pct_proportion`: PCTMGR / 100.
- `industry_ref_alt`: omit the smallest group instead of the largest; ties use the highest code.

Run them like any other spec. They exist to confirm invariances.
