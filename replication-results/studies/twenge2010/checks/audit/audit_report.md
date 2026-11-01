# Downstream audit and adversarial review, twenge2010, run_20261028T035346Z

Auditor: Claude Opus 5.5 (claude-opus-5-5), run as a coordinator subagent after the discrepancies were identified. This review is not family-independent: implementation A, Reader A and the coordinator are Anthropic models too. No existing file was modified; all audit code and outputs are in checks/audit/. Machine-readable results: checks/audit/audit_findings.json. Calculations used ~/.venv/bin/python -I and the auditor's own code; no implementation or scorer code was imported.

## Summary

No transcription, lineage, implementation or scorer arithmetic error was found. Two code-versus-rule-text deviations in the scorer do not change any outcome. Of the two discrepant_provisional claims, the partial scalar invariance decision is confirmed under the frozen rule but is not supported as a substantive discrepancy: it depends on the CFI baseline scale, and the article's CFIs use a baseline about twice as large per case as the reconstruction's. The security/influence alpha statement survives narrowly and has low materiality. The grey-zone and inconsistent-target focal contrasts are scored correctly. For the altruistic contrasts, the grey zone is fully explained by the V4229 intercept-release label.

## 1. Transcription audit

I re-extracted the article PDF myself (pdftotext -layout; PDF sha256 equals STUDY.json) and parsed Table 1, Table 2 and the Method-text Ns independently of sources/publication. A random sample of 80 keyed cells, drawn with random.Random(2010) from the sorted cell keys, matched 80/80. The required sets also matched in full: 15 d, 60 latent cells (mean, SD, CI, SE for 15 factor-years), 96 Table 2 cells and the 6 form Ns, 177/177 in all. All 525 keyed cells matched on string, value and significance stars. Unkeyed text targets T007-T009 and T529-T534 appear verbatim. Mismatches: none. Evidence: checks/audit/transcription_audit.json.

## 2. Source lineage

- The 18 run data files (A, B, C) have 6 distinct sha256 values, each equal to the extract named in implementation/manifest/data_key_map.txt.
- Every extract sidecar's extract_sha256 and source_sha256 recompute correctly, and registry/registry.json agrees with all 20 sidecars.
- The MD5s of the six analysis source files match the ICPSR manifests, including row counts. Provider dataset labels confirm the forms: 1976 DS0003/DS0004 are Forms 3/4; in 1991 and 2006, DS0004/DS0005 are Forms 3/4.
- Reading the sources with pyreadstat gives values identical to the extracts for V4, V5 and the 29 items. Where pyreadstat applies .por declared missing values, the extracts hold only codes 0 or 9 (checks/audit/extract_content_check.json).
- All 29 manifest variables match the dictionary question wording in all three years.
- Factor membership and the six released items match Table 1's grouping and footnote a.

## 3. Completeness and calculations

- All 36 result files (12 specifications x 3 implementations) exist. A's S04 is marked "unavailable" only for d_obs: 15 cells, where records with a missing item have no composite. B and C agree on those cells.
- My own code reproduces from the extracts: n, mean, SD and percentage for V4236, V4227, V4235, V4233, V4226 and V3223 in all three years; Student t and p for V4236 P3 and V3224 P1, plus Welch p; S00 multigroup n (3097/2413/2297) and V4 hashes; and K6/K7 alpha. That is 122/122 checks within tolerance.
- d_eq recomputed from each implementation's reported latent means and psi matches the reported d_eq (max difference 3e-14).
- My own multigroup ML fit (checks/audit/sem_audit_lib.py) reproduces the agreed M1-M5 chi-square (relative difference < 2e-9), df, CFI, delta CFI (.0029190) and all 15 d_eq (difference < 4e-6).
- The scorer arithmetic is reproduced exactly for all 15 focal contrasts (interval, derived SE, distance, band, outcome), for RQ1-RQ5, and for item claims V4236, V4230, V4239, V4241 and V3227.

Notes, none changing an outcome:

- The scorer's sign criterion returns "grey" for an opposite sign at 2-4 derived SE, whereas the rule text says "otherwise agree". This affects only the K3_P1 subcode.
- score.py does not implement the rounding band [.0015, .0025] around the .002 delta-CFI threshold. No reconstructed value falls inside it.
- S05 (effects coding) is not an equivalent re-expression. Including released intercepts in the per-group sum-to-zero constraint adds 8 constraints (M4 df 478 versus 470), so S05 results should not be read as an identification check.
- Rows read exceed the published Ns in all six files, by 22 to 55. Simple record filters do not reproduce the published Ns.

## 4. Adversarial review

### Partial scalar invariance accepted (delta CFI M2-M4 < .002)

Attempts that do not overturn the result:

- The models compared are the same in the article and the reconstruction: M2 versus M4.
- A (closed-form baseline), B (lavaan baseline), C (own baseline) and my own fit agree.
- Delta CFI exceeds the rounding bound .0025 in every branch: S00 .00292, S01 weighted .00278, S02 .00292, S03 .00296, S04 FIML .00283, S06 .00292 and CHK2 .00292. S05 is .0112, but that model is non-equivalent.
- An independence baseline with item means and variances held equal across groups gives .00281.

The article's printed multigroup df differ from the reconstruction (375/401/427/417/427 versus 426/454/482/470/480). An 18-indicator five-factor model with 5 group-specific intercepts reproduces all five printed df exactly. The single-group df of 142 implies 19 items, so the article's multigroup model differs from manifest M4. I fitted 15 such variants:

- Family A: one released item dropped, the other five released.
- Family B: V4229 kept invariant, one non-footnoted item dropped.

Under the manifest baseline, delta CFI ranges from .0029 to .0037 in all 15 variants, so the different model does not reverse the decision.

What does change the decision is the CFI baseline. The article's printed CFIs for M1-M5 all imply one baseline noncentrality of about 61,370 (61,345-61,394). The reconstruction's is 31,889; scaled to the reconstruction's N, the article's would be 58,230. The same factor appears in the single-group five-factor models. There, the article's baseline is 1.85 to 2.28 times the reconstruction's per case. Yet the article's model chi-squares are reproduced at the published N with Pearson-covariance ML (1686 vs 1656, 1481 vs 1419, 1453 vs 1452). Polychoric input does not explain the gap: its model chi-squares are about 1.9 times the article's.

Delta CFI is inversely proportional to the baseline noncentrality. The partial-scalar misfit relative to configural misfit is similar in both: .0235 in the reconstruction, .0202 in the article. On the article's baseline scale, the reconstructed delta CFI would be:

| Model | Delta CFI on the article's baseline scale |
| --- | --- |
| S00 | .0016 (.0014 by the CFI-ratio method) |
| Family A | .0015-.0018 |
| Family B | .0015-.0019 |

All of these are below .002. The article's M2-M3 and M4-M5 delta CFIs are likewise about half the reconstructed ones (.0060 vs .0128; .0080 vs .0184).

Verdict: the claim stays discrepant_provisional under the frozen rule, with no error found. As a substantive discrepancy it does not survive. The decision reverses because of an undocumented and unreproduced baseline scale, not because the partial-scalar constraints fit worse. A human reviewer should treat this claim as baseline-dependent before any confirmation. I did not change any rule.

### Security and influence alphas do not exceed .50

Attempts that do not overturn the result:

- The only cell above .50 is K6 2006 (V4239 establish roots + V4241 secure future): S00 .5185, S01 weighted .5091 and S03 listwise .5203. All exceed the .505 rounding bound.
- Standardized alpha is higher still (.530).
- All other K6/K7 cells are below .495.

Points that limit the result:

- The exceedance is small: .004 to .015 above the bound, against a bootstrap SE of .022, and 26% of bootstrap replicates are at or below .505.
- The article does not list which items form these scales. Both alternative partitions (S07a, S07b) keep every alpha below .39, though K6 = {V4239, V4241} is the natural reading and both readers agree on it.
- The published 2006 Form 4 N (2406) is close to the 2394 records complete on K6. Sampling differences therefore explain little; only a data-vintage difference could.

Verdict: survives narrowly, with low materiality. An alpha of .52 is still poor reliability, and the article's decision to drop the scales is unaffected. Human confirmation is required.

### Grey-zone and inconsistent-target contrasts

There is no scoring error. Distances in derived SE:

| Contrast | Distance (derived SE) | Note |
| --- | --- | --- |
| K2_P1 | 0.49 | 4.27 against the text value .05, hence inconsistent_targets |
| K2_P2 | 2.008 | Robust across implementations and my own fit |
| K2_P3 | 3.02 | |
| K3_P1 | 2.25 | |
| K3_P3 | 2.84 | |

For altruistic (K3), keeping V4229 invariant gives d_eq of -.041, -.060 and -.101, against the printed -.04, -.06 and -.10. This holds both in the 19-item model and across family B. Footnote a says V4229 was released, but the article's own text requires at least two constrained indicators per factor. D4 followed the footnote. This is a documentary label conflict; labels are frozen, so it is reported, not rescored.

No principled alternative explains intrinsic (K2). One post hoc family-B variant (dropping V4225) puts all three intrinsic contrasts within 2 SE. This is a search result, not evidence.

The article's latent-row SDs for intrinsic and altruistic (.41/.42/.48; .71/.72/.74) match observed composite SDs (.40/.41/.48; .71/.71/.74) more closely than sqrt(psi). Even so, d_obs (-.032, -.109, -.139) leaves K2_P3 at 2.08 SE.

## Files

- checks/audit/transcription_audit.py and .json
- checks/audit/extract_content_check.py and .json
- checks/audit/sem_audit_lib.py
- checks/audit/recompute_audit.py and .json
- checks/audit/scorer_audit.py and .json
- checks/audit/polychoric_baseline_probe.py and .json
- checks/audit/df_consistent_variants_probe.py and .json
- checks/audit/k3_constraint_probe.py and .json
- checks/audit/build_findings.py
- checks/audit/audit_findings.json
