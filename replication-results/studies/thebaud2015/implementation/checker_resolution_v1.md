# Checker findings and resolution (code v1)

Checkers: A and C checked by GPT-6 Astra (codex, separate process); B checked by Claude Fable 5.1 (separate process). Each saw MANIFEST.md and one script only. Findings are in check_A/v1, check_B/v1, check_C/v1 (CHECK.md).

Resolution by manifest clarification v1.1 (written before any empirical run; it changes no specification):

1. "all" excludes influence (A5, B1, C5). The implementer assignment defines "all" as every run in section 8 except influence; the checkers did not see the assignment. Influence is run as a separate invocation. Not a defect.
2. Run order (A4, C4). The executor passes run IDs explicitly in the manifest's listed order. No code change.
3. U23 growth (A1, C2). Clarification: under U23 growth depends only on OMYR5JOB and is missing only when OMYR5JOB is missing. A, B and C all implement this.
4. Absent reference year (A2, C3). This affects only N01, where 2001 (and 2002) are removed. Clarification: when the stated reference year is absent, any full-rank year coding is acceptable; the focal interaction terms are invariant to it. A and C use the earliest present year; B marks the aliased intercept and year terms not_estimable. Year and intercept terms are not scored.
5. Failed-model rows (A6, C7) and empty-sample fields (A7). Clarification: one row per failed model with an empty term is acceptable. No change.
6. Weighting report only with ORIGIN (A3). Accepted; weighting is recorded as unavailable in the run ledger by the coordinator.
7. C1 (counts above 999998 discarded for growth): no valid counts in that range exist other than the listed missing codes (999999, 9999997, 9999999). No change.
8. C6 (preparation error stops later runs). Accepted as a robustness limitation; the executor runs each run ID as its own invocation, so one failure cannot stop the others.

No code was modified. Code v1 is frozen for execution.
