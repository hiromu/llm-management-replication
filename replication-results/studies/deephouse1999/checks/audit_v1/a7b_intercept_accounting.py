"""Audit task 7(c) support (post hoc, non-scoring): is the Model 3 intercept difference a by-product of the slope
differences? WLS with an intercept satisfies ybar_w = b0 + sum_j b_j xbar_wj (weighted means, weights = MS).
Plug the PUBLISHED slopes into the reconstructed weighted means and compare the implied intercept with the
published one; also report the share of the intercept gap due to each slope.
Run: ~/.venv/bin/python -I checks/audit_v1/a7b_intercept_accounting.py <STUDY>
"""
import sys, json
from pathlib import Path
import numpy as np, pandas as pd
ST = Path(sys.argv[1]); OUT = ST / "checks/audit_v1"
PUB = {"M1": {"intercept": 0.929, "MS": -0.576, "TER": -9.948, "RMG": 0.014, "lag": 0.369},
       "M2": {"intercept": 1.164, "SD": -0.020, "MS": -0.093, "TER": -10.601, "RMG": 0.016, "lag": 0.361},
       "M3": {"intercept": 0.511, "SD2": -0.006, "SD": 0.170, "MS": -0.457, "TER": -15.387, "RMG": 0.018, "lag": 0.403}}
R = pd.read_csv(ST / "runs/run_v1/impl_B/out/spec_results.csv"); R["term"] = R.term.replace({"(Intercept)": "intercept"})
rows = []
for o in ["O_A", "O_B"]:
    d = pd.read_csv(ST / "runs/run_v1/impl_B/out/samples" / f"{o}.csv"); w = d.MS / d.MS.sum()
    xbar = {c: float((w * d[c]).sum()) for c in ["y", "SD", "SD2", "MS", "TER", "RMG", "lag"]}
    for m, p in PUB.items():
        rec = R[(R.spec_id == o) & (R.model == m)].set_index("term").estimate
        implied = xbar["y"] - sum(p[t] * xbar[t] for t in p if t != "intercept")
        contrib = {t: -(p[t] - rec[t]) * xbar[t] for t in p if t != "intercept"}
        rows.append(dict(origin=o, model=m, pub_intercept=p["intercept"], rec_intercept=float(rec["intercept"]),
                         implied_intercept_pub_slopes_rec_means=implied,
                         **{f"gap_contrib_{t}": v for t, v in contrib.items()}, **{f"wmean_{k}": v for k, v in xbar.items()}))
D = pd.DataFrame(rows); D.to_csv(OUT / "a7b_intercept_accounting.csv", index=False)
pd.set_option("display.width", 250); print(D.round(4).T.to_string())
