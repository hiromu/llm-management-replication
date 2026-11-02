"""Column-by-column comparison of A's and C's spec-O variables (all rows and org sample)."""
import os, numpy as np, pandas as pd
HERE = os.path.dirname(os.path.abspath(__file__))
A = pd.read_csv(os.path.join(HERE, "frame_A_O.csv")).set_index("V1")
Cc = pd.read_csv(os.path.join(HERE, "frame_C_O.csv")).set_index("V1")
A = A.loc[Cc.index]
assert (A["in_org"].astype(bool) == Cc["in_org"].astype(bool)).all(), "samples differ"
org = A["in_org"].astype(bool)
cols = [c for c in Cc.columns if c != "in_org"]
rows = []
for c in cols:
    a, b = A[c], Cc[c]
    if c == "IND":
        a = a.astype(str); b = b.astype(str)
        diff = a != b
    else:
        a = pd.to_numeric(a, errors="coerce"); b = pd.to_numeric(b, errors="coerce")
        na_mis = a.isna() != b.isna()
        val = (~a.isna() & ~b.isna()) & (np.abs(a - b) > 1e-9)
        diff = na_mis | val
    rows.append(dict(var=c, rows_differ_all=int(diff.sum()), rows_differ_org=int((diff & org).sum()),
                     max_abs_org=(float(np.nanmax(np.abs(a[org] - b[org]))) if c != "IND" else np.nan)))
res = pd.DataFrame(rows)
res.to_csv(os.path.join(HERE, "variable_diffs_O.csv"), index=False)
print(res.to_string(index=False))
