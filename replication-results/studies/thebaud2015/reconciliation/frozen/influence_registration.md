# Influence diagnostic registration (frozen before fitting)

Deletion unit: one country (all of its surveys and respondents) at a time.

Justification: the focal estimands are cross-level interactions between respondent gender and survey-level institutional measures. Those measures vary only between surveys, and most of their variation is between the 24 countries. Deleting a single respondent out of several hundred thousand cannot move these estimates in an informative way, and an exhaustive single-respondent deletion would require hundreds of thousands of mixed-model refits. Country deletion is the design's natural influence unit for country-level predictors. It is also the assignment-level cluster used by the benchmark inference.

Scope: origin specifications of M3, M4, M5, M6, M7 and M8. Each is refitted once per country present in its own origin estimation sample. Standardization constants and centering means stay fixed at the full-sample origin values, so each refit changes only the data. Every refit is retained, including failures, convergence warnings and singular fits, with its reason. No deletion is selected or dropped based on its effect.

Executed by implementations A (R) and C (Julia) under the frozen compute budget. The figure uses implementation A's ranges if A and C agree on the origin; otherwise it reports both.

Estimand scale in the figure: log-odds coefficient for M3, M4, M6, M7, M8 and linear coefficient on log(employees + 1) for M5. Null value 0. p values are two-sided Wald p values from the native model-based SEs, with the paper's .05 threshold drawn. These ranges are influence ranges, not confidence intervals, and they are not part of any equivalent specification set.

The report's preferred figure is described for correlations. This study adapts it to the actual estimands, which are regression coefficients of the focal interaction terms.
