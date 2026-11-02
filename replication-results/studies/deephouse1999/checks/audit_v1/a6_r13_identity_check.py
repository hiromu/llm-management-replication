"""Audit task 6 support: which explicit component list reproduces the gross other-loans residual?

For filtered commercial-bank Q4 records 1984-1992 in MN/WI (RSSD9048 == 200, CALL8786 in {1,2}), compare
gross residual = RCFD1400 - RCFD1766 - RCFD1410 - RCFD1975 - RCFD1590 with
  impl_A list: 2165 + 1505 + 1510 + 1517 + 2107 + 2081 + 1563
  impl_B/C list: 2165 + 1505 + 1517 + 1510 + 1545 + 2107 + 2081 + 2080
on records where every item of the list is non-missing; also report how often items are missing.
Run: ~/.venv/bin/python -I checks/audit_v1/a6_r13_identity_check.py <STUDY>
"""
import sys, json
from pathlib import Path
import numpy as np, pandas as pd
ST = Path(sys.argv[1]); OUT = ST / "checks/audit_v1"
c = pd.read_parquet(ST / "data/derived/call_mnwi_core_1983q4_1993q4.parquet")
c = c[(c.RSSD9048 == 200) & c.CALL8786.isin([1, 2]) & c.quarter.str.endswith("Q4") & (c.quarter >= "1984") & (c.quarter <= "1992Q4")]
res = c.RCFD1400 - c.RCFD1766 - c.RCFD1410 - c.RCFD1975 - c.RCFD1590
L = {"impl_A": ["2165", "1505", "1510", "1517", "2107", "2081", "1563"],
     "impl_B_C": ["2165", "1505", "1517", "1510", "1545", "2107", "2081", "2080"]}
out = {"n_records": int(len(c))}
for k, codes in L.items():
    cols = ["RCFD" + x for x in codes]
    complete = c[cols].notna().all(axis=1)
    s = c.loc[complete, cols].sum(axis=1)
    diff = (res[complete] - s)
    out[k] = {"records_all_items_present": int(complete.sum()),
              "share_present": round(float(complete.mean()), 4),
              "exact_identity_share(|diff|<=1)": round(float((diff.abs() <= 1).mean()), 4) if complete.any() else None,
              "median_abs_diff_thousand_usd": float(diff.abs().median()) if complete.any() else None}
# relation of 2080 to 1563 / 1545 where all present
m = c[["RCFD2080", "RCFD1563", "RCFD1545"]].notna().all(axis=1)
out["RCFD2080_eq_RCFD1563_share"] = round(float((c.loc[m, "RCFD2080"] == c.loc[m, "RCFD1563"]).mean()), 4)
out["RCFD2080_eq_RCFD1563_minus_1545_share"] = round(float((c.loc[m, "RCFD2080"] == c.loc[m, "RCFD1563"] - c.loc[m, "RCFD1545"]).mean()), 4)
# small filers: is 2080 the only reported other-loans line?
sm = c.RCFD1563.isna()
out["records_without_1563"] = int(sm.sum())
out["records_without_1563_identity_res_eq_2165+2107+2080_share"] = round(float(((res[sm] - (c.RCFD2165 + c.RCFD2107 + c.RCFD2080)[sm]).abs() <= 1).mean()), 4)
json.dump(out, open(OUT / "a6_r13_identity_check.json", "w"), indent=1)
print(json.dumps(out, indent=1))
