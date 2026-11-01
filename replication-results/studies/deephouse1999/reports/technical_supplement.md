# Technical supplement: deephouse1999

Every value here is generated from saved files in this study folder. Paths are relative to studies/deephouse1999/.

## Timeline and versions

| Stage | Artifact | Version / hash file |
| --- | --- | --- |
| Session start, settings | logs/session_start.json, logs/authorization.json | coordinator claude-opus-5-5, high, fast mode off |
| Supplement and package search | logs/supplement_and_package_search.json | none found |
| Publication packet | sources/publication_packet.json, sources/packet_v1/ | sources/packet_v1_SHA256SUMS.txt |
| Data acquisition and registry | registry/source_registry.json, data_dictionary.md, source_descriptions.md, loader_check.md | registry/registry_freeze_v1_SHA256SUMS.txt (188 files) |
| Memorization probes | sealed/memorization/ | per-folder SHA256SUMS.txt |
| Reader schema, prompt, rules | readers/reader_output_schema_v1.md, reader_prompt_v1.md, reader_rules_v1.md | readers/input_bundle_v1_SHA256SUMS.txt |
| Initial reader outputs | readers/fable/initial_v1, readers/astra/initial_v1 | initial_v1_SHA256SUMS.txt in each |
| Reconciliation | reconciliation/reconciliation_rules_v1.md (frozen while readers ran), agreement.py, agreement_ledger.csv, initial_agreement.json, decisions_v1.md, grid_v1.json | |
| Scoring and influence rules | registry/scoring_rules_v1.json, registry/influence_registration_v1.json | frozen before fitting |
| Implementer bundle | implementation/bundle_v1, manifest_v1.md, manifest_v1_1_amendment.md, leakage_scan_v1.json, leakage_review_v1.md | implementation/bundle_v1_SHA256SUMS.txt |
| Implementations | implementation/impl_{A,B,C}/phase1..phase3 | phaseN_SHA256SUMS.txt |
| Pre-execution checks | checks/checker_{A,B,C}_v1..v3, checks/open_checker_items_at_freeze.md | |
| Frozen execution | runs/run_v1/, runs/execute_frozen.sh, runs/sandbox_test_v1.json | runs/run_v1/impl_*_{inputs,outputs}_SHA256SUMS.txt |
| Scoring | scoring/*.py, scoring/run_v1/ | claim_outcomes v1.1 (v1 preserved as *_v1_superseded) |
| Audit | checks/audit_v1/audit_report.md and scripts | |
| Reports | reports/ | |

## Frozen grid (reconciliation/grid_v1.json)

26 axes. Origins O_A (Reader A) and O_B (Reader B) differ on R02, R05, R14, R15 and R18. Labels: origin; uncertain (both readers uncertain, label disagreements, single-reader levels, or the other reader's origin level); non_equivalent (sensitivity only); equivalent_algebraic_check (R24 weight scaling, R26 centred polynomial). The substantive equivalent set is empty.

| Axis | Decision | O_A | O_B | Other levels (label) |
| --- | --- | --- | --- | --- |
| R01 | Market geography | 1983 MSA 5120 counties | same | RSSD9180 code, Minnesota only, dynamic vintage (uncertain) |
| R02 | Bank records | charter 200 + entity type 1 | charter 200 | entity only, no special-purpose (uncertain); add savings banks (non-eq) |
| R03 | Mergers | as reported | same | drop merger years, continuation links (uncertain); pro forma (non-eq) |
| R04 | Entrants | lag only | same | full prior year, annualise (uncertain) |
| R05 | Average-asset quarters | at least 2, fallbacks | all 4 | any quarter (uncertain) |
| R06 | Average-asset formula | RC-K mean | same | day-weighted, five-point, two-point, FDIC ROA (uncertain) |
| R07 | Income | net income | same | before extraordinary items (uncertain) |
| R08 | Stock timing | year end | same | mean of quarterly shares, ratio of means (uncertain) |
| R09 | Benchmark population | all market banks | same | analytic sample, joint complete (uncertain); asset-weighted ROA (non-eq) |
| R10 | Outlier | delete RSSD 995151 1987 | same | max rstudent, suppress lag, before benchmarks (uncertain); none (non-eq) |
| R11 | C&I loans | excl. acceptances | same | incl. acceptances (uncertain) |
| R12 | Agricultural loans | production | same | plus farmland (uncertain) |
| R13 | Other loans | gross residual | same | components, net unearned, net allowance (uncertain) |
| R14 | Other assets | broad sum | literal 2160 | residual (uncertain) |
| R15 | Missing items | zero if not collected | missing | identity fill (uncertain) |
| R16 | Stock scope | RCFD | same | RCON (uncertain) |
| R17 | SD | n-1 | same | n, zero-SD missing (uncertain) |
| R18 | Deposits | RCON2200 | RCFD2200 | |
| R19 | Share denominator | commercial banks | same | all insured (non-eq) |
| R20 | Deflator | CPI-U annual | same | December, local CPI, GDP current, GDP 1999 vintage (uncertain) |
| R21 | Growth aggregate | commercial banks | same | all insured (uncertain) |
| R22 | Fixed effects | none | same | year, bank (non-eq) |
| R23 | Covariance | conventional | same | bank cluster CR1, HC1 (non-eq) |
| R24 | Weight scale | raw | same | mean one (check) |
| R25 | Estimator | WLS | same | OLS, WLS-AR(1) (non-eq) |
| R26 | Polynomial basis | raw | same | centred (check) |

## Inference and scoring rules (registry/scoring_rules_v1.json)

Provisional, uncalibrated constants. Rounding: printed precision half-unit intervals with benefit of rounding. Magnitude: distance to the published rounding interval divided by the upper published SE bound; consistent at most 1.5, grey up to 3.0, outside beyond 3.0 (different-vintage public reconstruction regime). Inference bands p < .01, .01-.05, .05-.10, >= .10; stars *** and ** map to p < .01; a two-band weakening meets the discrepancy criterion, one band never does. Reconstructed p is two-sided from conventional WLS (article tails unstated). Benchmark inference is not audited (no assignment-level clustering; no declared adaptation). N tolerance 5 percent (consistent) and 15 percent (outside beyond); N outside tolerance converts a discrepancy candidate to indeterminate. Two origins: differing claim outcomes give indeterminate (origin_label_sensitive). Discrepant requires adversarial review and human confirmation; none was requested because no claim reached that stage.

Focal structure (frozen before results): H3 Model 3 SD^2 with the first-order term scored jointly is the primary focal claim; H2 Model 2 SD is secondary; paper outcome follows the primary claim and is qualified by lower tiers.

## Reader agreement detail

reconciliation/agreement_ledger.csv lists every matched and unmatched claim and level. Unmatched: Reader A 1 of 18 claims and 26 of 57 levels; Reader B 7 of 24 claims and 27 of 58 levels. Tier disagreements: F tests (A focal, B diagnostic) and the Table 1 SD/SD^2 correlation (A diagnostic, B descriptive). Forensic records: no arithmetic inconsistency in the published table; Reader B flags that the prose definition of zero strategic deviation conflicts with the formula (wording issue).

## Implementation and checking record

| Role | Model | Language | Check rounds | Final check |
| --- | --- | --- | --- | --- |
| Implementer A | claude-fable-5-1 high | R 4.6.1 | 2 (Astra checker) | 7 open items, non-origin levels only |
| Implementer B | gpt-6-astra high | R 4.6.1 | 3 (Fable checker) | no unmet items |
| Implementer C | gpt-6-astra high | Python 3.13.4 | 3 (Fable checker) | no unmet items |

Manifest amendment v1.1 (implementation/manifest_v1_1_amendment.md) clarified eight points for all implementers before any fit, including the RSSD9425 code list from the Federal Reserve MDRM. Leakage scan: one reviewed false positive (159 counties in Minnesota and Wisconsin). Execution: sandbox-exec denying network and writes outside the run folder (tested, runs/sandbox_test_v1.json); A, B and C each ran in about one minute.

Implementation agreement (scoring/run_v1/implementation_agreement.json): identical sample hashes and coefficients within 2.2e-13 at both origins for all pairs. B-C agree on 164/164 settings; A-B and A-C on 160/164. The four disagreements are R03.proforma (one bank-year, Heritage NB 1990, certificate change; B and C follow the rule text) and R13.components (ambiguous item mapping; audit finds B and C double count RCFD2080 and A's mapping is closer to the gross residual; N = 206, degenerate). Both were scored on the B-C pair.

## Additional reconstructed results

Selected non-equivalent sensitivities at the origins (impl_B, identical in A and C):

| Setting | M2 SD (p) | M3 SD (p) | M3 SD^2 (p) |
| --- | --- | --- | --- |
| O_A bank-cluster SE | -0.0140 (2e-5) | 0.112 (0.126) | -0.0043 (0.075) |
| O_B bank-cluster SE | -0.0061 (0.375) | 0.100 (0.227) | -0.0039 (0.155) |
| O_A unweighted OLS | -0.0020 (0.718) | -0.033 (0.047) | 0.0014 (0.048) |
| O_B unweighted OLS | 0.0039 (0.477) | -0.035 (0.031) | 0.0017 (0.011) |
| O_A no outlier deletion | -0.0277 (4e-12) | 0.059 (0.002) | -0.0030 (4e-6) |
| O_B no outlier deletion | -0.0199 (6e-6) | 0.040 (0.069) | -0.0022 (0.005) |

Table 1 descriptives (informational, from checks/audit_v1/a7_D3_table1_compare.csv; the scorer did not produce this comparison, an omission noted by the audit): O_A agrees within printed precision on 5/7 means, 2/7 SDs and 10/21 correlations; O_B on 6/7, 4/7 and 7/21.

Influence (scoring/run_v1/influence_summary.csv): bank-year deletions produce no sign change and no p >= .05 for M3 SD and SD^2 at either origin, nor for M2 SD at O_A; at O_B 1,250 of 1,255 M2 deletions have p >= .05. Bank deletions: one deletion changes the sign of M3 SD at O_A and one takes M3 SD^2 to p = 0.47.

## Failures and unavailability

No specification failed or was unavailable in the final run. Failed acquisition attempts (FFIEC NIC, BLS flat files, first Python download attempt) are logged in registry/download_log*.jsonl. Reader B, implementers B and C and Astra checkers do not expose the realized model or effort in codex output. Corpus calibration, human double-coding and human review were not performed in this session.

## Containment

Readers, probes, implementers and checkers ran as separate claude or codex CLI processes from neutral $TMPDIR/role_<hex> folders (IDs in readers/staging_ids.txt and implementation/staging_ids.txt). Readers received no data; implementers and checkers received no article, targets or scoring rules. Coordinator subagents (data acquisition, audit) knew the paper, as permitted.
