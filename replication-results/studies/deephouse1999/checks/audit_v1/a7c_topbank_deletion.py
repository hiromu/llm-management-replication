"""Audit task 7 support (post hoc, non-scoring): Model 2/3 coefficients (all terms) after deleting each of the five
banks with the largest total WLS weight, at O_A and O_B (registered deletion unit = bank; the registered influence
file records only the focal terms, so this extends it to TER and the intercept for diagnosis only).
Run: ~/.venv/bin/python -I checks/audit_v1/a7c_topbank_deletion.py <STUDY>
"""
import sys
from pathlib import Path
import numpy as np, pandas as pd
from scipy import stats
ST = Path(sys.argv[1]); OUT = ST / "checks/audit_v1"
TERMS = {"M2": ["SD", "MS", "TER", "RMG", "lag"], "M3": ["SD2", "SD", "MS", "TER", "RMG", "lag"]}
def fit(d, X):
    Xm = np.column_stack([np.ones(len(d))] + [d[c].values for c in X]); sw = np.sqrt(d.MS.values)
    Xw, yw = Xm * sw[:, None], d.y.values * sw; XtX = Xw.T @ Xw; b = np.linalg.solve(XtX, Xw.T @ yw)
    e = yw - Xw @ b; n, k = Xm.shape; se = np.sqrt(np.diag(e @ e / (n - k) * np.linalg.inv(XtX)))
    return dict(zip(["intercept"] + X, b)), dict(zip(["intercept"] + X, 2 * stats.t.sf(np.abs(b / se), n - k)))
rows = []
for o in ["O_A", "O_B"]:
    d = pd.read_csv(ST / "runs/run_v1/impl_B/out/samples" / f"{o}.csv")
    top = d.groupby("RSSD9001").MS.sum().sort_values(ascending=False).head(5).index
    for drop in [None] + list(top):
        dd = d if drop is None else d[d.RSSD9001 != drop]
        for m, X in TERMS.items():
            b, p = fit(dd, X)
            rows.append(dict(origin=o, deleted_bank=drop if drop is not None else "none", model=m, n=len(dd),
                             **{f"b_{k}": v for k, v in b.items()}, **{f"p_{k}": v for k, v in p.items()}))
D = pd.DataFrame(rows); D.to_csv(OUT / "a7c_topbank_deletion.csv", index=False)
pd.set_option("display.width", 250)
print(D[D.model == "M3"][["origin", "deleted_bank", "n", "b_SD", "p_SD", "b_SD2", "p_SD2", "b_TER", "b_intercept", "p_intercept"]].round(4).to_string())
print(D[D.model == "M2"][["origin", "deleted_bank", "n", "b_SD", "p_SD", "b_TER"]].round(4).to_string())
