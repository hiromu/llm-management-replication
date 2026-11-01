# Technical supplement: Holderness and Pontiff (2012), study holderness2012

All paths are relative to studies/holderness2012/. Every number below is generated from files in this study; nothing is copied from an earlier exercise.

## 1. Session, models and isolation

- Coordinator: Claude Code, claude-opus-5-5, High effort, fast mode off (user-confirmed; not directly observable by the coordinator). Session fd5c105f-e59a-44db-b474-6f14aa01b1e0. Loaded instruction files: project-root CLAUDE.md and the study CLAUDE.md. User-level hooks (conversation logger, status hooks) ran in the coordinator session; they do not reach role processes. Record: logs/session_readiness.json.
- Reader A: claude-fable-5-1, High, normal speed, claude CLI 2.1.270 with --safe-mode, tools Read/Write/Edit/Glob/Grep, neutral $TMPDIR staging. Reader B: gpt-6-astra, reasoning effort high, service tier default, codex-cli 0.164.0, workspace-write sandbox (no network); the user's global ~/.codex/AGENTS.md loads (non-study rules). Run records: readers/*/run_*/.
- Memorization probes (title and authors only), sealed before reading: sealed/memorization/. Fable 5.1 recalled the journal, volume, issue and pages correctly but stated the findings with the opposite sign (hierarchy aiding survival) and recalled no numbers (self-rated confidence 30/100). GPT-6 Astra recalled nothing substantive (0/100). Neither probe shows memorized results.
- Implementers: A claude-fable-5-1 in R; B gpt-6-astra in R; C gpt-6-astra in Python (implementation/role_record_v1.json). Two model families only, so the adversarial review cannot use an independent family.
- Checkers: A checked by gpt-6-astra; B and C by claude-fable-5-1 (checks/). Rounds: A two rounds (one genuine error fixed: complete-case captured-cohort filter); B accepted after review of two no-effect items; C one runtime repair (camp code containing "/" broke the influence file path) and recheck.
- Execution isolation: macOS sandbox-exec profile denying all network access and all reads of the project folder; code and data copied to a fresh $TMPDIR directory (runs/isolation_test.json, runs/*/sandbox_profile.sb). Reader and implementer isolation beyond CLI sandboxing is instruction-based.

## 2. Publication packet and eligibility

- D1: published article, JSTOR scan (stable 41686887), sha256 57d70148...0fdbb4, 15 PDF pages, DOI 10.1287/mnsc.1120.1532. Text extraction and page images in sources/. Packet: publication_packet.json.
- No e-companion, appendix, supplement, correction or author replication package found after a documented 25-search check on 2026-10-27 (logs/eligibility_supplement_search.md). Working-paper versions (AEA 2009, SSRN 1345420, accepted manuscript) were identified and excluded as not part of the published record (logs/packet_decisions.json). The article reports several analyses only as "reported in previous versions"; those analyses are documentation gaps.

## 3. Public sources (registry/acquisition_log.json)

- nara_pow_rg389: World War II Prisoners of War Data File, NAID 1263907, RG 389, unrestricted; POW.MERGED2.txt, 143,374 records, sha256 37cf6778...bffef4 (matches NARA's published hash).
- nara_asnf_rg64: Electronic Army Serial Number Merged File, NAID 1263923, RG 64, unrestricted; ASNEF.FIN.DAT, 9,200,232 records, sha256 db10dbf9...07e5b.
- Code lists (31, from NARA AAD), technical documentation, GeoNames gazetteer (CC-BY 4.0) for the independently constructed camp crosswalk (registry/camp_location_crosswalk.csv: 393 exact, 78 approximate, 15 unknown NARA-listed entries; 99 data-only codes unknown).
- Python and R loaders return identical data (registry/loader_equivalence.json). Raw files could not be write-protected (chmod denied); immutability rests on recorded hashes.

## 4. Reader agreement (before any clarification; reconciliation/initial_agreement_v1.json)

| Comparison | Pairs | Agree | AC1 |
| --- | --- | --- | --- |
| Claim tier | 27 | 21 | 0.73 |
| Focal versus non-focal | 27 | 26 | 0.95 |
| Specification labels (matched levels) | 11 | 10 | 0.89 |
| Origin choice (matched axes) | 7 | 5 | not computed |
| Transcription, Tables 4 to 6 | 248 | 248 | n/a |

Decisions and the union of 23 specification axes are in reconciliation/ledger_v1.md. No alternative was labelled equivalent by both readers, so the equivalent set is the origin alone.

## 5. Frozen grid, scoring and budget

- Manifest and grid: implementation/frozen_v1/ (21 specifications: S000 origin with all families; S001 to S019 one-at-a-time uncertain deviations on the eight Table 4 models; S020 friends definition). Hashes in FROZEN_SHA256SUMS. Leakage scan: one reviewed false positive (the constant 1.319 in the Sameness formula).
- Scoring rules: sealed/scoring/scoring_rules_v1.json, provisional and uncalibrated. Magnitude in published-SE units is not audited because the article prints no standard errors. Benchmark inference equals native clustering (the hierarchy is assigned at the clustering level).
- Influence: leave-one-camp-out on the eight Table 4 origin models; implementation A ran all 2,016 deletions (341 camps for camp-cohort models, 163 camps remaining after perfect-prediction drops for captured-cohort models), B and C the first 20 camps per model as cross-check.
- Unavailable: pay-grade Steepness and pay interactions (no pay table), Hanley-McNeil correlation table (DeLong test used as uncertain fallback), camp-entry date (report month used).

## 6. Sample construction (implementation A log; B identical)

POW records 143,374; after excluding service codes 6 and 7, powers other than Germany and Japan, and unknown status: 124,387 (article Table 1 total 122,765). Regression sample with valid camp and report month: 101,993. Captured-cohort models drop 178 camps (1,321 rows) whose outcome does not vary: N = 100,672. Published N for all Table 4 columns: 100,464 (difference +0.2 percent captured, +1.5 percent camp). Enlistment records linked to regression-sample prisoners: 57,659 (56.5 percent; article about 55 percent).

## 7. Implementation agreement (scoring/implementation_agreement.json)

A and B agree within tolerance on all 32 core terms (Tables 4 to 6 hierarchy and interaction effects) and on the estimation rows of all 266 comparable models. C agrees on 22 of 32 core terms; the audit (checks/code_audit_C_post_execution.json) traced the difference to an ambiguity in the manifest's wording on spaces in grade labels (708 records), not a code error. Scoring uses the A-B pair. Influence deletions: B matches A on all 160 shared deletions (maximum difference 4.6e-6); C on 120 of 160.

## 8. Uncertain branches (scoring/branch_summary.csv)

All 19 one-at-a-time branches keep every focal coefficient negative. Branches that change a focal outcome: S005 (strict rank labels) for Sameness captured simple (p 0.13); S008 (group composition from complete-covariate members only) for Sameness camp simple (p 0.49) and camp full (p 0.15). S008 also weakens both camp Steepness models (p 0.50 and 0.88) but those already sat at or near the 0.10 boundary in print. S019 (NARA whole-degree coordinates) produced no agreeing pair for camp full Steepness (A -0.172, B -0.222, C -0.221), recorded as implementation disagreement for that branch only.

## 9. Lower tiers

See scoring/claim_scores.csv, scoring/robustness_terms.csv, runs/B_20261027T132459Z/results/roc.csv and reports/adversarial_review.md. Pseudo R2 of the eight Table 4 models are within 0.01 of the printed values.

## 10. Process limitations

logs/limitations_log.md lists every limitation: write-protection unavailable, instruction-based isolation, the scorer correction of the paper mapping before reporting, missing independent model family for adversarial review, no human double-coding or human confirmation, and uncalibrated scoring constants.
