# Open checker items at code freeze (run_v1)

impl_A (phase3 code) was frozen with the seven items of checks/checker_A_v2/unmet_items.md unresolved. Coordinator assessment of scope, made before any result was seen:
- Item 1 (missing main Call file handling): input is present; no effect on this run.
- Item 2 (R03.continuity acquirer/survivor exclusion), Item 3 (R03.proforma identifier change), Item 5 (R09.analytic drop counts not logged for non-origin specs), Item 6 (R25.wls_ar1 condition index basis): affect only uncertain or non-equivalent levels, not the origins O_A/O_B, the focal rules or influence diagnostics.
- Item 4 (R09.analytic years without first-pass rows): every year 1985-1992 has first-pass estimation rows and 1984 is handled by amendment C5, so the case does not arise.
- Item 7 (run command location): artifact of the checker staging layout; the run directory places analysis.R beside grid.json.
Consequence: specifications on which impl_A disagrees with impl_B/impl_C are scored on the agreeing pair and sent to code audit, per scoring_rules_v1.json.

impl_B and impl_C: final checks (checker_B_v3, checker_C_v3) returned NO UNMET ITEMS.
