# Audit: why implementation C diverges from A and B (run_20261028_v1_1)

Scope: implementation agreement only. sealed/ was not opened and no published values were consulted. No file under runs/ was modified. No implementation was fixed and the grid was not rerun. Diagnostics called the implementations' own functions on runs/run_20261028_v1_1/inputs/survey.csv, for spec O and for two single-spec spot checks.

## Result

The divergence has one cause. One constructed variable, UNION, differs for one establishment in the estimation samples, V1 = 10160. That record has a stored V233 = 0. Code 0 has no value label and is not a declared missing code. V233's labelled codes are 1, 2, 3 (valid) and 7, 8, 9 (declared missing).

| | V233 = 0 treated as | UNION for V1 10160 (V220 = 3) |
|---|---|---|
| A (R) | missing: out of the 1..3 item range | 1.0, the mean of reversed V220 alone |
| B (R) | missing: not in 1:3 | 1.0 |
| C (Python) | valid value 0, reversed to 4 - 0 = 4 | 2.5 = (1 + 4) / 2 |

A second record, V1 10328, also has V233 = 0. Its UNION differs in the same way, but it is not in any estimation sample of any spec, so it has no effect.

## Evidence

1. Variable-by-variable comparison at spec O (dump_A.R, dump_C.py, compare_frames.py; output in variable_diffs_O.csv). Both implementations give 727 frame rows and an identical organizational sample of 361 rows. The following agree to within 5e-14 on every row: POP, the seven HRM indices, all six STAFF/TRAIN pre-standardization items, every control other than UNION, and the industry group. UNION differs on 2 frame rows, of which 1 (V1 10160) is in the org sample, with an absolute difference of 1.5. V1 10160 is also in the market sample (V8 = 1).
2. Counterfactual (counterfactual_O.py, output in counterfactual_O.txt). This ran C's own `pipeline.run_spec` for spec O on the data with V233 = 0 set to system-missing. Results:
   - Unmodified data: reproduces out_C exactly (4e-16).
   - V233 = 0 set to missing: matches out_A to 1.3e-11 on estimates, SEs and HC3 SEs, and to 1.4e-15 on R2, in both families.

   So this one value explains the whole spec-O divergence: the intercept, ILM, GRIEV, VHIER, INCENT, UNION, DECENT, the industry dummies and R2.
3. Grid-wide pattern (grid_scope.py, output in grid_A_vs_C_by_spec_family.csv and grid_scope.txt). out_A and out_C agree only in the spec/family cells whose sample excludes V1 10160: D02 mkt, D05 org/mkt and D27 org/mkt, checked against out_A/out_C samples.csv. Every other cell differs. This matches the single-record cause.
4. Raw-code scan (grid_scope.py). Among the categorical raw variables C reads, V233 is the only one with an undocumented stored code: value 0, n = 2.

## Code responsible

C, `code_C/paperk7/coding.py`:

```python
97  def reverse(series, k):
99      return (k + 1) - series
409     v233 = reverse(apply_missing(raw["V233"], meta, "V233", extra_missing=[7, 8, 9]), 3)
```

Only declared or listed codes become missing. Any other stored value, including 0, is reversed arithmetically.

A, `code_A/k7_lib.R`:

```r
58  reverse_item <- function(x, k) {
60    x[!is.na(x) & (x < 1 | x > k | x != round(x))] <- NA
338   u_items <- cbind(reverse_item(V220, 3), reverse_item(V233, 3))
```

code_A/README.md, item 4, records this as a deliberate interpretation: undocumented codes on 1..k items are missing, noting that the development file has a stored 0 on V233.

B, `code_B/run_grid.R`:

```r
11  valid <- function(x, values) { x[!x %in% values] <- NA_real_; x }
123 union <- sapply(c('V220','V233'),function(v) 4-valid(d[[v]],1:3))
```

## Which implementation follows the specification

Relevant text from implementation_spec_v1.md:
- Section 1: the metadata gives per variable "label, value labels and declared missing values".
- Section 2: "Apply declared missing codes per variable from the metadata unless a rule below says otherwise." Also: "Reverse a 1..k item means k+1-x."
- Section 4.12, UNION: "each item reversed (4-x) and the index taken under item_rule". V220 and V233 are 1..3 items.
- Amendment v1.1 does not address undocumented codes. A2, A7 and A9 concern top codes, copy validity and specific variables only.

Assessment: A and B follow the specification. C's handling is a defect against it.

- Section 2 defines reversal only on a 1..k item. The metadata's value labels make V233 a 1..3 item, and 0 is not one of its codes. Reversing 0 gives 4, outside the 1..3 scale. That makes UNION, a mean of 1..3 items, an impossible value (it could even exceed 3).
- The spec never says that undeclared, unlabelled codes are valid. C's literal reading treats the declared-missing list as an exhaustive list of invalid values. That reading is possible only because the spec has no explicit out-of-domain rule, and it conflicts with the 1..k definition of reversal.
- A and B wrote their implementations independently and both restrict reversed items to their 1..k domain.

Note for the coordinator: the specification text has a gap here. It does not state explicitly that stored codes outside the labelled domain are missing. C's behaviour is therefore an implementation error under the most coherent reading, not a deviation from an explicit sentence. Any repair, or any clarification recorded after execution, should be documented as a correction to an implementation defect found by agreement checking, not as a result-driven change. The issue is invisible on the synthetic development file only if that file lacks the stored 0. A's README states that it has one, so C's tests did not cover it.

## Secondary observation (outside spec O, not caused by V233)

The spot check (counterfactual_spot.py, output in counterfactual_spot.txt) ran C with the V233 fix:
- D33 matches A to 4e-11.
- D04 (case_scope L1) still differs in mkt_M8 and mkt_M10, in the intercept and industry dummies only. The reason is a different omitted industry group, IND_73 in A versus IND_58 in C.
  - A chooses the reference group once per family, from the rows valid on outcome, controls and industry (`base_rows`, code_A/k7_lib.R line 704). It then drops dummies that are all zero in a given model and records those drops.
  - C chooses the reference group per model, from that model's rows (code_C/paperk7/pipeline.py line 315). It never creates all-zero dummies, so its dropped_columns is NA where A lists them.
- HRM and control estimates, SEs and R2 agree to 2e-12. This is a reparameterization: under case_scope L1, section 4.14 ("the family sample") does not define which sample determines the reference group. It does not affect any HRM coefficient, but A and C report the dummy and intercept terms and dropped_columns differently.

## Files in this folder

- dump_A.R and dump_C.py: build spec-O variables with each implementation's own functions and write frame_A_O.csv and frame_C_O.csv.
- compare_frames.py: column-by-column comparison, written to variable_diffs_O.csv.
- counterfactual_O.py: C's run_spec for spec O with and without V233 = 0 set to missing, compared with out_A and out_C, written to counterfactual_O.txt.
- grid_scope.py: per-spec A versus C differences, written to grid_A_vs_C_by_spec_family.csv, plus an undocumented-code scan; the summary is in grid_scope.txt.
- counterfactual_spot.py: D04 and D33 spot check, written to counterfactual_spot.txt.

Frame CSVs contain record-level constructed values. They stay inside this study folder and must not go into any reader or implementer staging directory.
