"""Synthetic rule tests: score a synthetic run against targets derived from it, then plant errors. Touches no real targets' values in output."""
import json, os, subprocess, sys, tempfile, csv
STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUN = os.path.join(STUDY, "runs/synthetic_1"); OUT = os.path.join(STUDY, "scoring/rule_tests"); os.makedirs(OUT, exist_ok=True)
PY = "~/.venv/bin/python"
base = os.path.join(OUT, "pass0"); env = dict(os.environ)
structure = json.load(open(os.path.join(STUDY, "sealed/targets/targets_reconciled.json")))
# First pass: placeholder targets to obtain consensus
rows = list(csv.DictReader(open(os.path.join(RUN, "A/results.csv"))))
ORIG = {"1": "D1_key", "2": "D2_any", "3": "D3_all", "4": "D4_loyal"}; COMP = {"1": "mean", "2": "mean", "3": "mean", "4": "existing"}
A = {}
for r in rows:
    if r["sample_level"] == ORIG[r["dataset"]] and r["composite_level"] == COMP[r["dataset"]]:
        A.setdefault(r["key"], {})[r["method"]] = r["value"]
PREF = ["paired", "welch", "pooled", "type3", "mixed_anova", "ols", "linear_cont", "logit", "descriptive"]
def val(key):
    m = A.get(key)
    if not m: return None
    for p in PREF:
        if p in m: return float(m[p])
    return float(next(iter(m.values())))
def stat_of(key, leaf): return val(key.rsplit(".", 1)[0] + "." + leaf)
syn = {}
for k, t in structure.items():
    pk = k; d = len(t["value"].split(".")[1]) if "." in str(t["value"]) else 0
    if ".cell." in k and "_h3print" in k: pk = k.replace("LC_h3print", "LC")
    if k.endswith(".ind"): pass
    v = val(pk)
    r = dict(t)
    for f in ("se", "ci_low", "ci_high", "p_exact", "p_inequality", "df"): r[f] = None
    if v is None: r["value"] = "NA"; syn[k] = r; continue
    if k.split(".")[0] in ("N1", "N2", "N3", "N4") and k.endswith(".n"): d = 0
    r["value"] = f"{v:.{max(d, 2)}f}" if d else f"{v:.0f}"
    if k.endswith((".t", ".F", ".coef", ".ind")):
        p = stat_of(k, "p") if not k.endswith(".ind") else stat_of(k, "p_delta")
        if p is not None: r["p_exact"] = f"{p:.3f}"
    if k.endswith(".coef"): r["se"] = f"{stat_of(k, 'se'):.2f}"
    if k.endswith(".ind"):
        r["se"] = f"{stat_of(k, 'se_boot'):.2f}"; r["ci_low"] = f"{stat_of(k, 'ci_bc_low'):.2f}"; r["ci_high"] = f"{stat_of(k, 'ci_bc_high'):.2f}"
    syn[k] = r
tf = os.path.join(OUT, "synthetic_targets.json"); json.dump(syn, open(tf, "w"))
env["TARGETS"] = tf
def run(name, targets):
    json.dump(targets, open(tf, "w")); o = os.path.join(OUT, name)
    r = subprocess.run([PY, os.path.join(STUDY, "scoring/score.py"), RUN, o], env=env, capture_output=True, text=True)
    if r.returncode: print(r.stderr[-1500:]); sys.exit(1)
    return {c["claim"]: c for c in json.load(open(o + "/claim_outcomes.json"))}, json.load(open(o + "/paper_summary.json"))
c0, s0 = run("clean", syn)
print("clean", s0["family_outcomes"], s0["paper_outcome"], s0["by_tier"].get("focal"))
print("clean non-consistent", [(k, v["outcome"], v["reason"], v.get("sign"), v.get("inference"), v.get("magnitude")) for k, v in c0.items() if v["outcome"] != "consistent"][:14])
import copy
checks = []
t = copy.deepcopy(syn); t["L4.M1.LoyalRequestor.coef"]["value"] = f"{-float(t['L4.M1.LoyalRequestor.coef']['value']):.2f}"
c, _ = run("plant_sign", t); checks.append(("sign flip gives discrepant_candidate", c["S4.M1.LoyalRequestor"]["outcome"] == "discrepant_candidate"))
t = copy.deepcopy(syn); v = float(t["L4.M1.LoyalRequestor.coef"]["value"]); se = float(t["L4.M1.LoyalRequestor.coef"]["se"]); t["L4.M1.LoyalRequestor.coef"]["value"] = f"{v + 3 * se:.2f}"
c, _ = run("plant_mag3", t); checks.append(("3 SE shift gives discrepant_candidate", c["S4.M1.LoyalRequestor"]["outcome"] == "discrepant_candidate"))
t = copy.deepcopy(syn); t["L4.M1.LoyalRequestor.coef"]["value"] = f"{v + .6 * se:.2f}"
c, _ = run("plant_mag06", t); checks.append(("0.6 SE shift is grey, indeterminate", c["S4.M1.LoyalRequestor"]["outcome"] == "indeterminate"))
t = copy.deepcopy(syn); t["M1.you_grant.F"]["value"] = f"{float(t['M1.you_grant.F']['value']) + 2:.2f}"
c, _ = run("plant_F", t); checks.append(("large F shift is out", c["S1.interaction.you_grant"]["magnitude"] == "out"))
t = copy.deepcopy(syn); p = float(t["C3.H1.you_grant.t"]["p_exact"]); t["C3.H1.you_grant.t"]["p_exact"] = "0.500" if p < .05 else "0.001"
c, _ = run("plant_p", t); checks.append(("two-band p change is out", c["S3.contrast.you_grant.H1"]["inference"] == "out"))
t = copy.deepcopy(syn); t["N2.n"]["value"] = str(int(float(t["N2.n"]["value"])) + 999)
c, s = run("plant_n", t); nb = json.load(open(os.path.join(OUT, "plant_n/n_branch.json"))); checks.append(("unreachable N marked n_unmatched", nb["2"]["code"] == "n_unmatched"))
t = copy.deepcopy(syn)
for lvl, ds in (("D2_none", "2"),):
    n_none = [r for r in rows if r["dataset"] == ds and r["sample_level"] == lvl and r["key"] == "N2.n"][0]["value"]
t["N2.n"]["value"] = f"{float(n_none):.0f}"
c, s = run("plant_n_branch", t); nb = json.load(open(os.path.join(OUT, "plant_n_branch/n_branch.json"))); checks.append(("N equal to alternative selects it by code", nb["2"]["scoring_sample"] == "D2_none" and nb["2"]["code"] == "n_branch_selected"))
for a, b in checks: print(("PASS" if b else "FAIL"), a)
json.dump([{"test": a, "pass": bool(b)} for a, b in checks], open(os.path.join(OUT, "results.json"), "w"), indent=1)
