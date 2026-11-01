# Technical supplement: study lehman2011

This supplement gives the detail behind replication_report.md. Every value comes from files in this study folder; the paths are given in each section.

## 1. Eligibility, sources and provenance

- Author package: none found after a documented search covering Dataverse, Zenodo, figshare, OSF via SHARE, GitHub, DataCite (which indexes ICPSR, openICPSR and Mendeley Data), Crossref, the journal page and the four authors' pages (logs/package_availability.json). openICPSR returned HTTP 500 and the ICPSR and Mendeley web pages needed JavaScript, so DataCite is the evidence for those three.
- Supplements: none found (logs/supplement_search.json). The live INFORMS page returned HTTP 403, so the archived copy of 2023-11-18 was used instead.
- Data: registry/source_registry.json lists every file with its provider, URL, release, asset date, licence, size and sha256. Python and R loaders agree on every season (registry/loader_check.json). Raw files are read-only. data/raw/download_log*.tsv could not be made read-only (permission refusal).
- Team alignment: registry/team_season_alignment.csv has 190 team-seasons. It agrees with nflverse div_game on all 1,520 games, and Wikipedia agrees with nfldata on all 128 team-seasons for 2002-2005.
- Environment changes made by the acquisition role: pyarrow 26.0.0 was installed into the venv from a sha256-verified wheel, and the R package nanoparquet 0.5.2 was installed. The venv Python cannot use SSL (missing Homebrew openssl@3), so HTTPS went through curl (logs/acquisition_log.md).

## 2. Publication packet and readers

- Packet v1 (readers/common/publication_packet.json): D01, the article (PDF pages 1-18 = journal pages 1613-1630), with a page-level pdftotext extraction. Reader inputs were frozen and hashed in readers/common/FROZEN_SHA256SUMS.txt before launch.
- Memorization probes (title and authors only), sealed in sealed/memorization/: Fable recalled the setting and gave a wrong dependent variable (pass versus run); Astra recalled fourth-down decisions. Neither gave any number.
- Reader runs: readers/fable/run1 (claude-fable-5-1; modelUsage confirms the model; usage.speed standard; fast_mode_state off) and readers/astra/run1 (gpt-6-astra requested; not echoed by codex). Both launched from neutral staging directories role_<hex>; the launch records give the paths and command lines. The first outputs are read-only and hashed.
- Reconciliation: rules frozen before outputs were read (reconciliation/rules_v1.md and rules_v1.sha256). Results are in the ledger (ledger_v1.json), the initial agreement file (initial_agreement_v1.json) and the decisions file (decisions_v1.md). Targets were merged by canonical key (sealed/targets_reconciled_v1.json): 81 focal Table 5 and Table 6 cells, all agreeing.

## 3. Frozen grid and labels

Source: implementation/grid_v1.json. Labels follow reconciliation/decisions_v1.md.

| Axis | Origin | Alternative | Label | Basis |
|---|---|---|---|---|
| U1 decision rows | punt, field_goal, run, pass | + no_play rows classified by provider flags | uncertain | both readers (article silent on penalties) |
| U2 kneel/spike | excluded | included as non-attempts | uncertain | Reader A |
| U3 two-minute boundary | > 120 s | ≥ 120 s | uncertain (A: equivalent; B: uncertain) | both readers |
| U4 minutes | seconds/60 | floor(seconds/60) | uncertain | Reader A |
| U5 same conference | nested | exclusive of division | uncertain | Reader A (Table 1 inconsistency) |
| U6 home field | provider home team | 0 for neutral sites | uncertain | Reader A |
| U7 estimator | conditional logit by team + season dummies | dummy-variable logit; conditional logit by team-season | uncertain (A: equivalent, B: non-equivalent); uncertain | both readers; Reader A |
| U8 indicator in M1 | no (Table 5) | yes (methods prose) | uncertain | Reader B |
| Marginal-effect conventions | ME0 (group effect 0, means) | U9a team-averaged; U9b finite difference; U10a right branch at d = 0 | uncertain | Reader A; Reader B |
| N1 random-effects logit | – | – | non-equivalent | Reader A |
| N2 quarters remaining | – | – | non-equivalent | both readers (article's narrative robustness) |
| N3 average marginal effects | – | – | non-equivalent | Reader A |
| N4 team-clustered SE | – | – | non-equivalent | Reader A |
| Elapsed minutes; complemented binaries | – | – | algebraic checks K1, K2 | Reader B |
| Spread-based reference point; field-goal-range submodels | – | – | unavailable (undocumented) | Reader B |

Fixed and never varied: the dependent variable, the performance definition and spline structure, the explicit control list, the seasons, the regular-season and regulation restrictions, and the marginal-effect evaluation grid.

## 4. Scoring rules and their application

- Rules: reconciliation/scoring_rules_v1.json, frozen before fitting. Different-vintage magnitude bands: consistent ≤ 1.5 published SEs, grey ≤ 3, discrepancy candidate above 3. Distances are measured from the published rounding interval, using the upper SE bound.
- Inference: star bands, two-sided. A change of two or more bands is a discrepancy candidate. Fragile inference means the benchmark is two or more bands weaker.
- N bands: close (≤ 2%), moderate (2-5%), large (> 5%).
- Aggregation rule: claims follow their primary Table 5 coefficients; Table 6 effects are secondary shares. The paper outcome uses all four focal claims, with H2 and H3 central.
- Scorer: runs/scorer/score_v1.py. It passed 8 synthetic rule tests (runs/scorer/synthetic_test_results_v1.json): exact match, a planted error, a planted error rescued by a branch, null data, an unreachable target, implementation disagreement, and a large N gap.
- Patches, logged in reconciliation/FROZEN_v1.sha256:
  - v1.1, before any comparison: duplicate rows and season-dummy names.
  - v1.2, after the first pass: the "minutes remaining" label mapped to the term `minutes`. The first-pass output is kept in runs/score_v1_pass1_namebug/.
- Implementation agreement: checks/implementation_agreement/ABC_v1.json. Every pair agrees on 577 shared specifications, 8 sample hashes, and all coefficients, SEs, marginal effects and shared influence rows within tolerance; the maximum coefficient difference is 4.5e-8. Scored on A, per the rule's lowest-letter convention.

### Claim records (runs/score_v1/score_record.json)

| Claim | Outcome | Secondary Table 6 shares (ME0 origin) | Secondary shares under U9a |
|---|---|---|---|
| H1A | consistent | 1 consistent, 3 discrepancy candidates of 4 | 1 consistent, 1 grey, 2 discrepancy candidates |
| H1B | consistent | 0 of 3 consistent | 0 of 3 consistent |
| H2 | consistent | 7 consistent, 2 grey, 7 discrepancy candidates of 16 | 15 consistent, 1 grey |
| H3 | consistent | 0 consistent, 7 grey, 5 discrepancy candidates of 12 | 12 of 12 consistent |

The adversarial review found that the published "All quarters" row behaves like Model 3 at mean minutes, not Model 2: under U9a, Model 3 reproduces all seven cells within 0.93 SE (checks/adversarial/all_quarters_row_m3_at_mean_minutes.csv). That explains the H1 secondary shares. This is a post-hoc diagnostic, not a relabelled origin.

### Uncertain set (runs/score_v1/uncertain_set_summary.csv)

For every primary focal coefficient, all 191 non-origin cells are consistent, the sign agrees with the published sign in 100%, and the significance status at 0.05 matches the published status in 100%. The published value sits between the 15th and 75th percentile of the cell distribution for every term except perf² × minutes, whose published OR rounds to 1.000 and so carries no sign on the log scale. Ranges on the log-odds scale:
- M2 perf ≤ aspiration: −0.1250 to −0.1167 (published −0.1244)
- M3 perf ≤ asp. × minutes: 0.01085 to 0.01103 (published 0.01094)
- M3 perf > asp. × minutes: −0.00230 to −0.00178 (published −0.00200)

### Nonfocal controls (origin)

- Consistent: total points, yards to touchdown, week, home field, minutes remaining (all models), and same division and same conference in Models 2 and 3.
- Grey: yards to first down in Models 1-3 (1.7-1.9 SEs; the reconstruction is slightly more negative).
- Discrepancy candidates: same division and same conference in Model 1. Both are nonsignificant and flagged by the sign rule. The adversarial verdict is uncertain, and a published label swap is likely (checks/adversarial/review_v1.md).

### Paper aggregation

- Under the frozen rule, all four focal claims are consistent, so the paper outcome is consistent. Because two lower-tier cells are discrepancy candidates, the comparability mapping is "partially reproduced".

### Publication diagnostics

- The reconstructed LR χ² values (3,052, 3,680 and 4,158 on 13, 17 and 20 df) are close to the printed ones (3,045.63, 3,755.00 and 4,281.62).
- The reconstructed incremental LR tests are 627.8 (M2 vs M1) and 478.7 (M3 vs M2). The printed increments, 168.87 and 544.05, match neither the printed log-likelihoods (implied 709.37 and 526.62) nor our values; both readers flagged this independently.
- Wald test of perf ≤ aspiration = perf > aspiration in M2: χ² = 84.5 (1 df).

## 5. Inference and influence

- Benchmark (game-clustered CR1 on the paired dummy-variable logit): no fragile-inference flag for any focal target.
- N4 (team-clustered): every significant focal term stays at p < 0.001.
- Influence (runs/score_v1/influence_summary.csv):
  - No sign change and no crossing of p = 0.05 for any focal term, under game (1,518), team (32) or season (6) deletion.
  - Largest relative moves: the M3 indicator term under season deletion (−0.239 to −0.037; nonsignificant throughout) and M2 perf² under season deletion.
  - Failures: in A, the season-2000 deletion lost its benchmark fit (the reference dummy was absent and the design singular); native estimates are unaffected and match C. C had none.

## 6. Containment and isolation

- Implementers and checkers never received the article, the targets, the scoring rules or other implementations.
  - The leakage scan (checks/leakage_scan_v1.md) found no target values or identity terms in their inputs.
  - Isolation was enforced by the codex workspace-write sandbox for B and C.
  - For A it rested on a tool allowlist (Rscript, python, basic file tools) and instructions; A's 10 denied tool calls were local scratchpad commands, with no network attempts.
- Frozen execution: sandbox-exec. B and C ran with all network denied; A ran with localhost-only access for its R cluster. The tests are in checks/sandbox_tests.md. Input and result hashes are in runs/exec_v1/*/INPUT_SHA256SUMS and RESULTS_SHA256SUMS.
- Every code version is preserved under implementation/{A,B,C}/r*/, with checker outputs under checks/{A,B,C}/r*/.

## 7. Calibration and validation status

| Arm | Status |
|---|---|
| Synthetic scorer tests (planted errors, null data, unreachable targets) | done (8 of 8) |
| Title-only memorization probes | done |
| Implementer synthetic checks | done (A 8 groups, B 25, C 107) |
| Post-cutoff paper stratum, cross-paper calibration | not performed (outside this single-paper session) |
| Independent-family adversarial review | unavailable; done by an Anthropic model in a fresh context |
