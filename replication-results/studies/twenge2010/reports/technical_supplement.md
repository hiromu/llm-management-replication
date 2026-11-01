# Technical supplement: twenge2010

All paths are relative to the study folder. Times are UTC on 2026-10-28.

## 1. Session, configuration and authorization

The user started the session with "Start the replication project" (logs/session_record.json). Configuration and checks:

- Coordinator: claude-opus-5-5 in the Claude Code desktop app, with effort high, fast mode off and auto-memory off pinned in .claude/settings.json.
  - Effort and fast mode could not be observed directly, because /status and /memory are unavailable in the desktop app.
  - The loaded instruction files were the root and study CLAUDE.md only.
- Runtimes: Python 3.13.4 (~/.venv), R 4.6.1, claude CLI 2.1.270, codex CLI 0.164.0.
- lavaan 0.7.3 was installed from CRAN before any implementer ran; this is software only (logs/session_record_addenda.md).
- Connectivity checks of both reader models were run separately from the reader runs.

## 2. Sources and provenance

Supplied bundles. The user downloaded these by hand from ICPSR; the download time was not recorded, and the setup copy was made at 01:48:50Z:

| Study | Year | Version | Release date |
| --- | --- | --- | --- |
| ICPSR 7927 | 1976 | V4 | 2007-05-25 |
| ICPSR 9871 | 1991 | V1 | 2006-03-30 |
| ICPSR 20022 | 2006 | V3 | 2008-09-12 |

Validation by the fresh source role (registry/registry.json, registry/validation_report.md):

- Hashes: 42/42 files match the setup inventory, and 20/20 data-file MD5s match the ICPSR manifests.
- Terms: research and statistical use only, no re-identification, data citation required.
- Not supplied: alternative formats and setup files, which are not needed.
- Documentation discrepancies:
  - The 1991 codebook gives a different Form 6 count from the data file.
  - The 1991 weight's missing rule differs between the codebook and the SPSS file.
  - In 1976, V3319-V3332 were removed.
  None of these affects the analysis.

Derived data:

- data/derived/extracts/ holds all 20 files as raw codes, with sha256 sidecars. Loader equivalence was checked between R haven and pyreadstat (registry/loader_check.json).
- data/derived/dictionaries/ holds summary-free dictionaries (registry/summary_free_check.json).
- Readers received a version of the source description with the source role's item-specific pointers removed (readers/packet_inputs/).

Eligibility (sources/eligibility_check.json): 27 logged checks found no author replication package. Supplements (sources/supplement_search.json): none found, and no corrections. Packet: sources/publication/publication_packet.json (P1 only).

## 3. Memorization probes

Title-and-authors-only probes were run on both reader models from neutral directories before the reader runs. The answers were sealed (sealed/memorization/) and opened only for this report.

- Both models recognised the article and its journal, year and data source.
- Both recalled the combined N of 16,507, and d = .57 for leisure 1976-2006.
- Reader A's model also recalled d = .26 for extrinsic 1976-2006, and approximate social and intrinsic magnitudes, which it marked as guesses.

Readers transcribed targets from the packet; the transcriptions agree with an independent audit re-extraction, 525/525 keyed cells. Implementers never saw the paper or any target.

## 4. Readers and reconciliation

Frozen before the runs: readers/schema/ (schema, prompt, rules; FROZEN.sha256). The identical input manifest is readers/reader_input_manifest.sha256 (48 files). Launch records are in logs/launches/. Initial outputs and their hashes are in readers/fable/initial, readers/astra/initial and initial_outputs.sha256. No clarification round was used.

Reader output sizes:

| Reader | Claims | Targets | Specification axes | Forensic checks |
| --- | --- | --- | --- | --- |
| A | 59 | 534 | 9 | 18 |
| B | 70 | 604 | 14 | 56 |

Reconciliation materials: reconciliation/scripts/reconcile.py (matching rules R1-R5), ledger.json, agreement_initial.json and decisions.md (D1-D11).

Gwet AC1 uses two raters with nominal categories. The tier categories are focal, diagnostic, robustness, descriptive and nuisance. The label categories are origin, equivalent, uncertain and non_equivalent.

- Tier: 53/54 agree, pa .981, pe .148, AC1 .978. The one disagreement is the work-centrality summary (Reader B focal, Reader A descriptive).
- Labels: 13/18 agree, pa .722, pe .162, AC1 .669. The five disagreements:
  - unweighted: origin vs uncertain;
  - weighted: uncertain vs origin;
  - df-weighted d: equivalent vs uncertain;
  - reference-group identification: uncertain vs equivalent;
  - Welch t: equivalent vs uncertain.
- Structural agreement: 77/77. The altruistic marker differs.
- Single-reader levels (9 from Reader A, 11 from Reader B) are retained in the union with the dispositions recorded in ledger.json.

Leakage review of the manifest (implementation/roles/leakage_review_manifest_v1.json): there are no identity terms. The numeric tokens 19, 23 and 95 overlap with target strings; all three are reviewed design constants (item counts and the confidence level).

## 5. Frozen grid, inference and scoring

Manifest: implementation/manifest/manifest_v1.md. Grid S00-S08, CHK1-CHK2 (see the main report). The frozen files and their hashes are listed in sealed/FROZEN_pre_execution.sha256.

Scoring rules: sealed/scoring_rules.json v1. They are provisional and uncalibrated:

- Implementation agreement:
  - d and latent means within .002;
  - item means and SDs within 1e-6;
  - t within 1e-4;
  - chi-square within 1e-3 relative;
  - fit indices within .001;
  - n exact.
- Rounding: whole printed rounding intervals.
- Focal magnitude: distance from the reconstructed value to the printed interval, in a derived SE of d (based on the published Form 4 Ns). Agree up to 2, grey over 2 and up to 4, mismatch over 4. This band suits a reconstruction from a different data vintage.
- Focal sign: assessable when the printed interval excludes 0; mismatch only beyond the grey bound.
- Focal inference: not audited (SEM).
- Item claims: the same rules, using a derived SE from the printed SDs and published form Ns, plus inference bands (p < .01, .01-.05, .05-.10, ≥ .10) checked against the stars. A difference of two or more bands is a mismatch.
- Diagnostics: the article's stated decision rules. Where no numeric rule is stated, the claim is indeterminate.
- Precedence: not attemptable > implementation disagreement > discrepant_provisional > grey > inconsistent targets > consistent.
- Paper rule: any indeterminate research question makes the paper indeterminate.

Synthetic rule tests: 34/34 pass (checks/scoring_rule_tests.json). An implementation-tolerance addendum covers unscored descriptive fields (checks/implementation_tolerance_addendum.json). It was written before any target comparison.

Benchmark inference adaptations, declared before execution:

- No cluster identifiers exist in the public files, so no clusters were invented.
- Item tests use native independent-sample inference.
- SEM inference is native and not audited.

## 6. Implementations, checks and execution

Role record: implementation/roles/role_record_v1.json. Code versions: implementation/{A,B,C}/v1, v2 with code.sha256. Checker reports: checks/checker_*.

| Implementation | Check outcome | Disposition |
| --- | --- | --- |
| A | Astra checker: 6 items, then repair; 2 residual items | residuals recorded in checks/checker_A_v2/residual_disposition.md |
| B | first check invalid (coordinator staged incomplete code; note kept); rerun found 3 items, then repair; 1 residual item | residual recorded in checks/checker_B_v2/residual_disposition.md |
| C | no unmet items | none |

Execution:

- Network isolation test: checks/network_isolation_test.json.
- Failed run: run_20261028T035304Z failed because the harness omitted dictionaries/ (runs/run_20261028T035304Z/RUN_STATUS.json). It is preserved.
- Executed run: run_20261028T035346Z. Input hashes are in runs/run_20261028T035346Z_inputs.sha256 (79 files). All grids ran under sandbox-exec with network denied.
- Influence:
  - Implementation A ran all 7,807 deletions between 03:54 and 04:16; all converged, at 0.17 s each.
  - Implementation C ran 200 deletions; the maximum difference in d from A is 1.0e-5, and the maximum relative difference in p is 0.3%.
- Implementation comparison: runs/run_20261028T035346Z/comparison/. Every scored key agrees across all three implementations.

## 7. Scoring versions and corrections

All versions are preserved:

- scoring_v1_superseded_keying_error: targets v1 had V4239 and V4241 swapped by the coordinator (checks/audit_target_keying_correction.md). These are corrected in targets v2, verified against the source wording (27/29 keys matched before the fix, 29/29 after).
- scoring_v2_before_rule_alignment: the scorer code deviated from the rule text in two places (sign grey vs agree; missing rounding band around .002). The code was aligned to the frozen text, and no outcome changed.
- scoring_v3_before_S01_textcheck: the weighted co-origin lacked the text-versus-table check. It was added; no research-question or paper outcome changed, and one contrast (altruistic 1976-2006) remains label-sensitive.
- The final scoring is runs/run_20261028T035346Z/scoring/scores.json, also copied to reports/scores.json.

## 8. Audit and adversarial review

The audit is in checks/audit/audit_report.md and audit_findings.json. It was run by a Claude Opus 5.5 subagent and is not family-independent.

- Transcription: 80/80 random cells (seed 2010) and 177/177 required cells match.
- Lineage: verified from the run files back to the ICPSR manifests.
- Recomputation: 122/122 independent checks pass.
- Independent ML fit: reproduces M1-M5 and all 15 d values.
- Scorer arithmetic: reproduced.

Adversarial dispositions (checks/adversarial_disposition.json):

- Partial scalar invariance: did not survive as a substantive discrepancy, because of the CFI baseline scale. It is recorded as indeterminate (underdocumentation).
- Security alpha: survives narrowly, at low materiality. It remains discrepant_provisional and unconfirmed.

Human confirmation of discrepant findings: not obtained.

## 9. Outputs

| File | Contents |
| --- | --- |
| reports/claim_comparisons.csv | 112 rows |
| reports/all_specification_results.csv | every normalized quantity, all specifications, A/B/C values, agreement status, tolerance |
| reports/influence_results_loo_implA.csv | all deletions |
| reports/influence_crosscheck_implC_first200.csv | C cross-check |
| reports/figure_reconstruction_influence.{png,svg,csv} | figure and plotted values |
| reports/scripts/make_figure.py | figure script |

## 10. Unavailable or not performed

- Design-based standard errors (no school or PSU identifiers in the public files).
- The original LISREL syntax, CFI baseline and intercept-release pattern.
- Reliability targets (absent from the article).
- Family-independent adversarial review (no third model family available).
- Human confirmation.
- Corpus-level calibration, human double-coding and a human-reproduced comparison set (outside this session).
- Published SEs for d (a derived SE was used and labelled).

## 11. Approximate compute record

| Role | Duration and cost |
| --- | --- |
| Reader A | 15 min, $8.37 |
| Reader B | 26 min, about 152k tokens |
| Implementer A | 34 min, $8.85; repair 13 min, $4.72 |
| Implementers B and C | about 18 and 13 min, codex token counts in their transcripts |
| Checkers | $1.2-2.5 each (Claude), plus two Codex checks |
| Full influence run | 22 min |
