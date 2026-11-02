"""Assemble checks/audit/audit_findings.json from the audit outputs. Run from the study root with python -I."""
import json
tr = json.load(open("checks/audit/transcription_audit.json"))
rc = json.load(open("checks/audit/recompute_audit.json"))
sc = json.load(open("checks/audit/scorer_audit.json"))
ec = json.load(open("checks/audit/extract_content_check.json"))
pb = json.load(open("checks/audit/polychoric_baseline_probe.json"))
fb = json.load(open("checks/audit/df_consistent_variants_probe.json"))
k3 = json.load(open("checks/audit/k3_constraint_probe.json"))
fa = [v for v in rc["variants_18_indicators"] if "status" not in v]
R = "runs/run_20261028T035346Z"
F = {"auditor": {"model": "claude-opus-5-5 (Claude Code subagent of the coordinator session)", "independence": "not family-independent: same model family as implementation A, Reader A and the coordinator"},
     "rng": "random.Random(2010)", "checks": []}
add = lambda **k: F["checks"].append(k)
add(id="T1", task="transcription", check="random sample of 80 sealed cells (seed 2010) vs independent pdftotext of the article PDF",
    result="pass", detail=f"{sum(x['result']=='match' for x in tr['random_sample'])}/80 match", evidence=["checks/audit/transcription_audit.json", "checks/audit/transcription_audit.py"])
add(id="T2", task="transcription", check="all 15 d, 15 latent groups (mean, SD, CI, SE = 60 cells), all 96 Table 2 cells, 6 form Ns",
    result="pass", detail=f"{sum(x['result']=='match' for x in tr['required_sets'])}/{len(tr['required_sets'])} match", evidence=["checks/audit/transcription_audit.json"])
add(id="T3", task="transcription", check="all keyed cells (525) plus unkeyed text targets T007-T009, T529-T534", result="pass",
    detail=f"{tr['all_cells_summary']}; unkeyed quotes found verbatim in the PDF text", evidence=["checks/audit/transcription_audit.json"])
add(id="L1", task="lineage", check="run data (A, B, C) sha256 = data/derived/extracts sha256 via implementation/manifest/data_key_map.txt", result="pass",
    detail="18 run files, 6 distinct hashes, each equal to its extract", evidence=[f"{R}/A/data", f"{R}/B/data", f"{R}/C/data", "data/derived/extracts"])
add(id="L2", task="lineage", check="extract sidecar extract_sha256 and source_sha256 recomputed; registry/registry.json derived entries equal sidecars (20 extracts)", result="pass",
    evidence=["data/derived/extracts/*.json", "registry/registry.json"])
add(id="L3", task="lineage", check="MD5 of the six analysis source files vs ICPSR manifests; provider dataset labels (1976 DS0003/DS0004, 1991 and 2006 DS0004/DS0005 = Form 3/Form 4)", result="pass",
    evidence=["data/supplied/ICPSR_07927/07927-manifest.txt", "data/supplied/ICPSR_09871/09871-manifest.txt", "data/supplied/ICPSR_20022/20022-manifest.txt", "registry/registry.json"])
add(id="L4", task="lineage", check="extract values equal source values (pyreadstat) for V4, V5 and the 29 items in the six analysis files", result="pass",
    detail="non-missing values identical; where pyreadstat applies .por declared missing values the extract holds codes 0 or 9 only", evidence=["checks/audit/extract_content_check.json"])
add(id="L5", task="lineage", check="item-to-variable mapping: manifest variables vs dictionary question wording, all 29 items, all 3 years", result="pass",
    detail="29/29 wording match; Form 4 four response categories, Form 3 five, V3227 1 = would want to work; factor membership and the six released items match Table 1 grouping and footnote a",
    evidence=["data/derived/dictionaries", "implementation/manifest/manifest_v1.md", "sealed/targets_v2.json"])
add(id="C1", task="completeness", check="every grid specification (S00-S08, CHK1, CHK2) has output from A, B and C", result="pass_with_note",
    detail="36/36 result files; A S04 status 'unavailable' only for d_obs (15 cells, missing-item composites); B and C agree on those cells; all other S04 quantities from all three",
    evidence=[f"{R}/comparison/implementation_agreement_summary.json", f"{R}/A/results/S04.json"])
nf = sum(c.get("result") == "FAIL" for c in rc["checks"])
add(id="C2", task="recomputation", check="own code from extracts: n/mean/SD/% for V4236, V4227, V4235, V4233, V4226, V3223 x 3 years; Student t and p (V4236 P3, V3224 P1) and Welch p; S00 multigroup n and V4 hashes; K6/K7 alpha",
    result="pass" if nf == 0 else "fail", detail=f"{len(rc['checks'])} checks, {nf} failures", evidence=["checks/audit/recompute_audit.json", "checks/audit/recompute_audit.py"])
add(id="C3", task="recomputation", check="d_eq for 15 contrasts from each implementation's reported latent means and factor variances", result="pass",
    detail=f"max abs difference {max(r[I]['absdiff'] for r in rc['d_eq_from_latent'] for I in 'ABC'):.1e}", evidence=["checks/audit/recompute_audit.json"])
add(id="C4", task="recomputation", check="auditor's own multigroup ML fit (M1-M5, 19 items) vs agreed chi-square, df, CFI, delta CFI and 15 d_eq", result="pass",
    detail="chi-square relative differences < 2e-9; CFI < 3e-10; d_eq < 4e-6", evidence=["checks/audit/sem_audit_lib.py", "checks/audit/recompute_audit.json"])
add(id="C5", task="scorer", check="scorer arithmetic for 15 focal contrasts (interval, derived SE, distance, bands, outcome) and RQ outcomes", result="pass",
    detail="15/15 outcomes, SEs and distances reproduced; RQ1-RQ5 reproduced", evidence=["checks/audit/scorer_audit.json", "checks/audit/scorer_audit.py"])
add(id="C6", task="scorer", check="scorer arithmetic for item claims V4236, V4230, V4239, V4241, V3227", result="pass", evidence=["checks/audit/scorer_audit.json"])
add(id="C7", task="scorer", check="code vs rule text: sign criterion", result="note",
    detail="scoring_lib.sign_check returns 'grey' for an opposite sign at 2-4 derived SE; rule text says 'otherwise agree'. Affects only K3_P1 subcode (grey_zone:sign,magnitude vs grey_zone:magnitude); outcome unchanged.",
    evidence=["checks/scripts/scoring_lib.py", "sealed/scoring_rules.json"])
add(id="C8", task="scorer", check="code vs rule text: diagnostic delta-CFI rounding band", result="note",
    detail="score.py compares delta CFI with .002 directly and does not implement the 'within rounding of the threshold -> indeterminate' band [.0015, .0025]; no reconstructed delta CFI lies in that band (S00 values .00109, .01275, .00292), so no outcome changes.",
    evidence=["checks/scripts/score.py"])
add(id="C9", task="manifest", check="S05 effects coding equivalence", result="note",
    detail="S05 M4 has df 478 vs 470 (released intercepts inside the per-group sum-to-zero constraint add 8 constraints); S05 is a more constrained, non-equivalent model, not an identification re-expression",
    evidence=[f"{R}/comparison/implementation_agreement_all.csv"])
add(id="C10", task="N branch", check="rows read vs published form N", result="note",
    detail="rows exceed published N in all six files (by 22 to 55); simple record filters (any valid item, all items valid) do not reproduce the published N; consistent with the different-vintage regime",
    evidence=["checks/audit/recompute_audit.json", f"{R}/scoring/n_branch.json"])
dc = sc["dcfi_branches"]
add(id="A1", task="adversarial", claim="Partial scalar invariance accepted (delta CFI M2-M4 < .002)", result="rule-level discrepancy confirmed; substantive discrepancy not supported",
    detail={"manifest_baseline_dcfi": {k: v["dcfi_M2_M4"] for k, v in dc.items()},
            "models_compared": "M2 vs M4 in both article and reconstruction; arithmetic, implementations (A closed-form, B lavaan, C own) and auditor fit agree",
            "article_df_pattern_reproduced_by": "18 indicators with 5 group-specific intercepts (375/401/427/417/427); 15 such variants fitted",
            "variant_dcfi_manifest_baseline_range": [min(min(v["complete_on_18"]["dcfi_M2_M4"] for v in fa), min(x["dcfi_M2_M4_manifest_baseline"] for x in fb)),
                                                     max(max(v["complete_on_18"]["dcfi_M2_M4"] for v in fa), max(x["dcfi_M2_M4_manifest_baseline"] for x in fb))],
            "equal_means_variances_baseline_dcfi": rc["own_multigroup_19"]["dcfi_M2_M4_equal_baseline"],
            "article_implied_baseline_noncentrality": rc["article_implied_baseline_noncentrality"],
            "reconstructed_baseline_noncentrality": rc["rescaled_delta_cfi"]["reconstructed_baseline_noncentrality"],
            "dcfi_on_article_baseline_scale_S00": rc["rescaled_delta_cfi"]["dcfi_using_article_baseline_scaled"],
            "dcfi_on_article_baseline_scale_family_B_range": [min(x["dcfi_M2_M4_article_baseline_scale"] for x in fb), max(x["dcfi_M2_M4_article_baseline_scale"] for x in fb)],
            "relative_misfit_dnc_over_configural_nc": {"article": rc["rescaled_delta_cfi"]["article_dnc_over_configural_nc"], "reconstruction": rc["rescaled_delta_cfi"]["reconstructed_dnc_over_configural_nc"]},
            "single_group_baseline_ratio_per_case_article_over_reconstruction": {y: v["ratio_per_case"] for y, v in rc["single_group_baseline_comparison"].items()},
            "single_group_model_chisq_at_published_N_pearson_vs_article": {y: [v["pearson"]["chisq_scaled_to_published_N"], v["published"]["chisq"]] for y, v in pb.items()},
            "polychoric_input": "ruled out as explanation: polychoric model chi-square about 1.9x the article's"},
    evidence=["checks/audit/recompute_audit.json", "checks/audit/df_consistent_variants_probe.json", "checks/audit/polychoric_baseline_probe.json", "checks/audit/scorer_audit.json"])
al = sc["alpha_branches"]
add(id="A2", task="adversarial", claim="Security and influence scales: no alpha exceeds .50", result="survives narrowly; low materiality",
    detail={"K6_2006": {"S00": al["S00"]["K6_2006"], "S01_weighted": al["S01"]["K6_2006"], "S03_listwise23": al["S03"]["K6_2006"],
                        "standardized": rc["alpha_security_influence"]["K6_2006"]["alpha_standardized"],
                        "bootstrap_se": rc["alpha_security_influence"]["K6_2006"]["bootstrap_se"],
                        "share_bootstrap_le_0.505": rc["alpha_security_influence"]["K6_2006"]["share_bootstrap_le_0505"],
                        "n_complete": rc["alpha_security_influence"]["K6_2006"]["n"], "published_form4_N_2006": 2406},
            "all_other_K6_K7_cells_below_0.495": True,
            "alternative_partitions_S07a_S07b_max_alpha": max(max(al["S07a"].values()), max(al["S07b"].values())),
            "item_assignment": "K6 = V4239 (establish roots) + V4241 (secure future); not listed in the article; both readers agree"},
    evidence=["checks/audit/recompute_audit.json", "checks/audit/scorer_audit.json"])
add(id="A3", task="adversarial", claim="Grey-zone and inconsistent-target focal contrasts (K2_P1, K2_P2, K2_P3, K3_P1, K3_P3)", result="no scoring error",
    detail={"distances_in_se": {r["contrast"]: r["z"] for r in sc["focal"] if r["outcome_scorer"] != "consistent"},
            "K2_P1_text_value_distance_in_se": next(r["text_value_z"] for r in sc["focal"] if r["contrast"] == "K2_P1"),
            "K3_with_V4229_invariant_19_items": k3["V4229_invariant_5_released"]["d_eq_K3"],
            "K3_with_V4229_invariant_family_B_range": {k: [min(x["d_eq_M4"][k] for x in fb), max(x["d_eq_M4"][k] for x in fb)] for k in ("K3_P1", "K3_P2", "K3_P3")},
            "note": "printed altruistic d = -.04, -.06, -.10; the K3 grey zone is explained by the V4229 release label (footnote a vs the article's own two-constrained-indicators rule); labels are frozen, so this is reported, not rescored"},
    evidence=["checks/audit/scorer_audit.json", "checks/audit/k3_constraint_probe.json", "checks/audit/df_consistent_variants_probe.json"])
json.dump(F, open("checks/audit/audit_findings.json", "w"), indent=1, default=float)
print(json.dumps(F["checks"][-3]["detail"], indent=1, default=float)[:2500])
print(json.dumps(F["checks"][-2]["detail"], default=float)); print(json.dumps(F["checks"][-1]["detail"], default=float))
