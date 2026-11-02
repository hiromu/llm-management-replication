"""Audit task 5 support: apply the frozen 'discrepancy_across_readings' label-sensitivity check (any uncertain
reading consistent -> label_sensitive) to the two nuisance claims that are discrepant_candidate at both origins
(control_TER_M3, control_intercept_M3); scoring/claim_outcomes.py applies it only to focal/robustness tiers.
Uses impl_B estimates (agreeing B|C pair) and the auditor's independent scorer from a5_scoring_audit.py.
Run: ~/.venv/bin/python -I checks/audit_v1/a5b_control_label_sensitivity.py <STUDY>
"""
import sys, json, importlib.util
from pathlib import Path
import pandas as pd
ST = Path(sys.argv[1]); OUT = ST / "checks/audit_v1"
src = open(OUT / "a5_scoring_audit.py").read().split("R = pd.read_csv")[0]   # reuse PUB and score() definitions only
ns = {"__name__": "a5lib"}; exec(src, ns); score = ns["score"]
grid = json.load(open(ST / "reconciliation/grid_v1.json"))
lab = {l["id"]: l["label"] for a in grid["axes"] for l in a["levels"]}
R = pd.read_csv(ST / "runs/run_v1/impl_B/out/spec_results.csv"); R["term"] = R.term.replace({"(Intercept)": "intercept"})
R = R[(R.status == "ok") & R.spec_id.str.contains("__")]
R = R[R.level_id.map(lab).isin(["uncertain", "origin"])]
out = {}
for m, t in [("M3", "TER"), ("M3", "intercept")]:
    g = R[(R.model == m) & (R.term == t)]
    hits = [r.spec_id for r in g.itertuples() if score((m, t), r.estimate, r.se, r.p_two_sided)["outcome"] == "consistent"]
    out[f"{m}:{t}"] = {"uncertain_specs": len(g), "consistent_specs": hits}
json.dump(out, open(OUT / "a5b_control_label_sensitivity.json", "w"), indent=1); print(json.dumps(out, indent=1))
