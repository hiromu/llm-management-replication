"""Audit task 7 support. POST HOC, NON-SCORING, NOT A REPLACEMENT SPECIFICATION.

Motivation (documented before fitting): the N anatomy (a7 D4) shows that the four outer counties of the 1983
Minneapolis-St. Paul MSA (Chisago 27025, Isanti 27059, Wright 27171, St. Croix 55109) contribute 286 of the 1260
O_A rows, about the size of the 1260-960 gap. The article names the 'Minneapolis-St. Paul ... metropolitan area
(Twin Cities)'; the seven-county Twin Cities area (Anoka, Carver, Dakota, Hennepin, Ramsey, Scott, Washington) is
a common narrower reading that is NOT in the frozen grid. This script rebuilds O_A with the market restricted to
those seven counties (benchmarks, market totals and lags rebuilt) and reports N, banks, Table 1 moments and M1-M3
estimates once. Because the restriction was chosen after seeing that it approximately matches the published N,
its estimates carry no evidential weight for scoring and must not be substituted for the frozen origins.
Run: ~/.venv/bin/python -I checks/audit_v1/a7d_posthoc_7county.py <STUDY>
"""
import sys, json
from pathlib import Path
import numpy as np, pandas as pd
from scipy import stats
ST = Path(sys.argv[1]); OUT = ST / "checks/audit_v1"
sys.path.insert(0, str(OUT))
from a_rebuild_lib import build_O_A
SEVEN = {"27003", "27019", "27037", "27053", "27123", "27139", "27163"}
s, B = build_O_A(ST, delete_named=True, county_subset=SEVEN)
TERMS = {"M1": ["MS", "TER", "RMG", "lag"], "M2": ["SD", "MS", "TER", "RMG", "lag"], "M3": ["SD2", "SD", "MS", "TER", "RMG", "lag"],
         "M3_SQ": ["SD2", "MS", "TER", "RMG", "lag"]}
rows, sse = [], {}
for m, X in TERMS.items():
    Xm = np.column_stack([np.ones(len(s))] + [s[c].values for c in X]); sw = np.sqrt(s.MS.values)
    Xw, yw = Xm * sw[:, None], s.y.values * sw; XtX = Xw.T @ Xw; b = np.linalg.solve(XtX, Xw.T @ yw)
    e = yw - Xw @ b; n, k = Xm.shape; se = np.sqrt(np.diag(e @ e / (n - k) * np.linalg.inv(XtX)))
    sse[m] = float(e @ e)
    for nm, bb, ss in zip(["intercept"] + X, b, se):
        rows.append(dict(model=m, term=nm, estimate=bb, se=ss, p=2 * stats.t.sf(abs(bb / ss), n - k), n=n))
D = pd.DataFrame(rows); D.to_csv(OUT / "a7d_posthoc_7county_estimates.csv", index=False)
desc = {v: {"mean": float(s[v].mean() / (100 if v in ("y", "lag") else 1)), "sd": float(s[v].std(ddof=1) / (100 if v in ("y", "lag") else 1))}
        for v in ["y", "lag", "SD2", "SD", "MS", "TER", "RMG"]}
out = {"label": "POST HOC NON-SCORING diagnostic", "n": len(s), "banks": int(s.RSSD9001.nunique()),
       "rows_by_year": s.groupby("year").size().to_dict(), "sse": sse, "table1_moments": desc,
       "corr_TER_SD": float(s.TER.corr(s.SD)), "corr_TER_SD2": float(s.TER.corr(s.SD2)), "corr_MS_SD": float(s.MS.corr(s.SD))}
json.dump(out, open(OUT / "a7d_posthoc_7county_summary.json", "w"), indent=1, default=float)
pd.set_option("display.width", 200); print(json.dumps(out, indent=1, default=float)); print(D.round(4).to_string())
