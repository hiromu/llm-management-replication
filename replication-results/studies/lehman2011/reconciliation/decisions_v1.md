# Coordinator reconciliation decisions v1

These decisions follow reconciliation/rules_v1.md. They were made from the two sealed run1 reader outputs, before any data were analysed. The full row-by-row ledger is in ledger_v1.json, and the initial agreement statistics are in initial_agreement_v1.json. No clarification round was used: neither reader's questions concerned interpretation that only the other reader or new documents could settle. Both readers asked for the same missing data input, a season-specific conference membership table, and the acquisition role was asked to supply it from public records. That is a data input, not reader feedback.

## Agreed structure (retained)

- Population: 2000-2005 regular-season fourth-down plays in regulation, excluding the last two minutes of each game (D01 p.8, endnotes 2-3 on pp.15-16).
- Dependent variable: conversion attempt (run or pass) = 1, punt or field-goal attempt = 0 (D01 p.8).
- Performance: own pre-play score minus (opponent score + 1). It is split into an at-or-below piece, its square, an above piece, and an at-or-below indicator (D01 pp.8-9).
- Deadline proximity: regulation minutes remaining at the snap (D01 p.9).
- Models: M1 has controls only. M2 adds the performance spline. M3 adds three performance × minutes interactions; the indicator is not interacted (D01 p.11, Table 5).
- Explicit controls in every model: own total points, yards to first down, yards to the end zone, same division, same conference, home field and week. Minutes remaining is a regressor in all models (Table 5).
- Estimator: fixed-effects logit named as Stata xtlogit. Both readers read this as a conditional logit grouped by the offensive team with season dummies, which matches the printed df of 13/17/20 (Table 5).
- Covariance: not stated. Both readers take conventional ML standard errors as the origin and note that clustering is not reported.
- Marginal effects (Table 6): evaluated at d = -42, -28, -14, 0, 14, 28, 42. M2 uses all quarters; M3 fixes minutes at 53, 38, 23 and 8. Controls are at sample means.
- Published targets: all 81 focal Table 5 and Table 6 cells agree between the readers on value, SE and stars (sealed/targets_reconciled_v1.json).

## Disagreements and decisions

| Item | Reader A (Fable) | Reader B (Astra) | Decision |
|---|---|---|---|
| Keep a snap at exactly 2:00 | equivalent | uncertain | uncertain branch U3a |
| Unconditional logit with team and season dummies | equivalent | non_equivalent | uncertain branch U7a |
| Unexpected first-quarter finding | robustness tier | focal tier | tier uncertain; reported with the H2 claim record, not scored as a separate focal claim |
| Claim granularity | 17 claims | 19 claims; several separate focal "stated finding" summaries (C1, C12-C14, C16) | union retained; scored focal claims are the four hypotheses, which both readers mark focal; Astra's stated-finding claims are mapped to the hypothesis records as their supporting summaries |
| Certainty labels (risk_taking, yards to first down, same division, home field, decision-row step) | explicit or inferred | inferred or unclear | retained as recorded; manifest marks each as not fully explicit |

## Union items (one reader only), all retained

- Fable: kneel/spike as non-risky (uncertain, U2a); whole minutes (uncertain, U4a); exclusive same-conference coding (uncertain, U5a); neutral-site home coding (uncertain, U6a); team-season conditional logit (uncertain, U7b); random-effects logit (non-equivalent, N1); cluster-robust SEs by game or by team (non-equivalent as native-inference alternatives); finite-difference and team-effect-averaged marginal effects (uncertain, U9a/U9b); average marginal effects (non-equivalent, N3).
- Astra: indicator in M1 (uncertain, U8a); right-hand derivative at d = 0 (uncertain, U10a); common versus model-specific complete cases (uncertain; collapses if no model variable is missing, which the implementation records); elapsed-minutes reparameterisation and complemented binary codings (mathematical re-expressions, run as algebraic checks, not alternatives); spread-based aspiration and field-goal-range sub-models (non-equivalent; not executable because the article does not give their construction, so recorded as unavailable).
- Both: quarters remaining in place of minutes (non-equivalent, N2; it backs the article's narrative robustness claim and has no printed numbers).

## Equivalent set

After reconciliation, no non-origin level carries an `equivalent` label from both readers. The substantive equivalent set is therefore empty. Under scoring.md this means specification fragility is not assessed. Uncertain branches are run and reported separately. Where an uncertain branch could change a verdict, the claim is flagged label-sensitive.

## Origin choices made by the coordinator where the readers were silent or split

- Predicted probabilities for marginal effects after the conditional logit: the origin is the stated software's default prediction after a fixed-effects xtlogit, which is the probability with the group effect set to zero (Stata's `pu0`, the default used by `margins`). Basis: software default for the stated command. Both readers left this open, so it is uncertain; the alternative is U9a.
- Benchmark inference: cluster-robust sandwich covariance clustered by game. Basis: scoring.md says nonlinear logit models use assignment-level clustered sandwich inference. Both readers identify play-level game states nested in games, and both teams' plays in a game share the score path.
- Benchmark adaptation, declared before execution: games cut across the team strata of the conditional likelihood, so the sandwich is computed on the matched unconditional dummy-variable logit (U7=1) fit. With roughly 700 plays per team, incidental-parameter bias is expected to be small, but the paired U7=0 versus U7=1 coefficient difference is reported for every cell so the adaptation can be checked. Benchmark marginal-effect SEs use the delta method with the clustered covariance.

## Influence-deletion registration (frozen before fitting)

- Units: game (primary), team (fixed-effect group, 32) and season (6). Single plays are not used as the deletion unit. Plays within a game share one score and clock path, so deleting single plays understates influence, and the paper's own dependence structure is at the game and team level.
- Models and terms: M2 and M3 at the origin. Recorded terms: perf_below, perf_below_sq, perf_above, below_indicator (M2 and M3), and the three interactions (M3). For each: estimate, native SE and p, and benchmark p.
- Every eligible deletion is retained, including failed or non-converged fits with reasons. Team and season deletion run in all three implementations. Game deletion runs in implementations A and C.
- Influence ranges are diagnostics. They are not confidence intervals and do not enter the equivalent set.
