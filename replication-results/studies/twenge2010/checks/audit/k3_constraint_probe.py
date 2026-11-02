"""Adversarial probe (diagnostic only): manifest 19-item M2/M4 on the S00 sample with V4229 kept invariant
(5 released intercepts instead of 6). Isolates the effect of the altruistic release label on K3 d_eq and on delta CFI.
Run from the study root: ~/.venv/bin/python -I checks/audit/k3_constraint_probe.py
"""
import json, math, sys
import pandas as pd
sys.path.insert(0, "checks/audit")
from sem_audit_lib import fit_mg, moments, baseline_free, cfi
FACT = {"K1": ["V4236", "V4238", "V4240", "V4246"], "K2": ["V4227", "V4225", "V4231", "V4232", "V4234", "V4242", "V4243"],
        "K3": ["V4235", "V4229"], "K4": ["V4233", "V4245"], "K5": ["V4226", "V4228", "V4230", "V4244"]}
MARK = {k: v[0] for k, v in FACT.items()}
ITEMS = [v for f in FACT.values() for v in f]
EXT = {"1976": "1976_DS0004", "1991": "1991_DS0005", "2006": "2006_DS0005"}
gs = []
for y, ds in EXT.items():
    d = pd.read_csv(f"data/derived/extracts/{ds}.csv.gz", usecols=ITEMS)[ITEMS]
    gs.append(moments(d[d.isin([1, 2, 3, 4]).all(axis=1)].astype(float).to_numpy()))
cb, db = baseline_free(gs)
out = {"n": [g[0] for g in gs]}
for lab, rel in (("manifest_6_released", ["V4238", "V4240", "V4231", "V4229", "V4230", "V4228"]),
                 ("V4229_invariant_5_released", ["V4238", "V4240", "V4231", "V4230", "V4228"])):
    m2 = fit_mg(ITEMS, FACT, MARK, "M2", rel, gs)
    m4 = fit_mg(ITEMS, FACT, MARK, "M4", rel, gs)
    deq = {}
    for P, (a, b) in {"P1": (0, 1), "P2": (1, 2), "P3": (0, 2)}.items():
        _, _, _, Pa, aa = m4.mats(m4.theta, a)
        _, _, _, Pb, ab = m4.mats(m4.theta, b)
        for j, f in enumerate(FACT):
            deq[f"{f}_{P}"] = (ab[j] - aa[j]) / math.sqrt((Pa[j, j] + Pb[j, j]) / 2)
    out[lab] = {"M2": [m2.chisq, m2.df], "M4": [m4.chisq, m4.df], "dcfi_M2_M4": cfi(m2.chisq, m2.df, cb, db) - cfi(m4.chisq, m4.df, cb, db),
                "d_eq_K3": {k: v for k, v in deq.items() if k.startswith("K3")}, "d_eq_all": deq}
    print(lab, out[lab]["M4"], round(out[lab]["dcfi_M2_M4"], 5), {k: round(v, 3) for k, v in out[lab]["d_eq_K3"].items()})
json.dump(out, open("checks/audit/k3_constraint_probe.json", "w"), indent=1, default=float)
