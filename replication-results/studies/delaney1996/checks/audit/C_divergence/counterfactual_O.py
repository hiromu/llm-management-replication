"""Run C's own run_spec for spec O (diagnostic only, not the grid) on
(a) the unmodified data and (b) a copy where the undocumented V233 code 0 is set
to system-missing (A/B's out-of-range rule). Compare both with out_A and out_C."""
import json, os, sys
import numpy as np, pandas as pd
HERE = os.path.dirname(os.path.abspath(__file__))
RUN = os.path.join(HERE, "../../../runs/run_20261028_v1_1")
sys.path.insert(0, os.path.join(RUN, "code_C"))
import run_grid as R  # noqa
from paperk7 import coding as C, pipeline as P  # noqa
raw = R.load_raw(os.path.join(RUN, "inputs/survey.csv"))
meta = C.load_metadata(os.path.join(RUN, "inputs/survey_metadata.json"))
cw = C.load_crosswalk(os.path.join(RUN, "inputs/industry_crosswalk.csv"))
spec = [s for s in json.load(open(os.path.join(RUN, "inputs/grid_v1.json")))["specs"] if s["spec_id"] == "O"][0]

def coefs(res):
    return pd.DataFrame(res.coefficients).set_index(["family", "model_id", "term"])
def stats(res):
    return pd.DataFrame(res.model_stats).set_index(["family", "model_id"])
def load(out):
    c = pd.read_csv(os.path.join(RUN, out, "coefficients.csv")); c = c[c.spec_id == "O"].set_index(["family", "model_id", "term"])
    s = pd.read_csv(os.path.join(RUN, out, "model_stats.csv")); s = s[s.spec_id == "O"].set_index(["family", "model_id"])
    return c, s
cA, sA = load("out_A"); cC, sC = load("out_C")

res_a = P.run_spec(spec, raw, meta, cw)
raw_b = raw.copy()
bad = raw_b["V233"].notna() & ~raw_b["V233"].isin([1, 2, 3, 7, 8, 9])
print("V233 undocumented codes:", raw_b.loc[bad, ["V1", "V233"]].to_dict("records"))
raw_b.loc[bad, "V233"] = np.nan
res_b = P.run_spec(spec, raw_b, meta, cw)

lines = []
for label, res in [("C as run (unmodified data)", res_a), ("C with V233==0 set missing", res_b)]:
    ce, st = coefs(res), stats(res)
    for ref_label, rc, rs in [("out_C", cC, sC), ("out_A", cA, sA)]:
        j = ce.join(rc[["estimate", "se", "se_hc3"]], rsuffix="_ref", how="outer")
        dmax = np.nanmax(np.abs(j[["estimate", "se", "se_hc3"]].values - j[["estimate_ref", "se_ref", "se_hc3_ref"]].values))
        js = st.join(rs[["r2", "n"]], rsuffix="_ref", how="outer")
        r2max = np.nanmax(np.abs(js["r2"].astype(float) - js["r2_ref"].astype(float)))
        nmis = int(j[["estimate", "estimate_ref"]].isna().any(axis=1).sum())
        lines.append(f"{label:30s} vs {ref_label}: max|d est/se/hc3| = {dmax:.3e}, max|d R2| = {r2max:.3e}, unmatched coef rows = {nmis}")
print("\n".join(lines))
with open(os.path.join(HERE, "counterfactual_O.txt"), "w") as fh:
    fh.write("\n".join(lines) + "\n")
