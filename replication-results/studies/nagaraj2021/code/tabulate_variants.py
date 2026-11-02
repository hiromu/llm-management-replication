"""Tabulate post-unsealing variant results against published targets (diagnostic only)."""
import json, os, re, sys
import pandas as pd
STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DG = os.path.join(STUDY, "post_unseal/diagnostics")
claims = [c for c in json.load(open(os.path.join(STUDY, "scoring/claims_v1.json"))) if c["kind"] in ("regression", "regression_nuisance_unit", "placebo")]
def z(est, s, se):
    s = str(s); d = len(s.split(".")[1]) if "." in s else 0; v = float(s); h = 0.5 * 10 ** -d
    dist = 0 if v - h <= est <= v + h else min(abs(est - v + h), abs(est - v - h)); return dist / float(se)
runs = {"origin": os.path.join(STUDY, "runs/run_20261101_v1/out/A/results.csv")}
for v in sorted(os.listdir(DG)):
    if os.path.isdir(os.path.join(DG, v)):
        runs[v] = os.path.join(DG, v, "out/results.csv")
R = {k: pd.read_csv(p, dtype={"spec_id": str}).set_index(["spec_id", "term"]) for k, p in runs.items()}
rows = []
for c in claims:
    term = c["term"]; spec = c["origin_spec"]; pub = c["published"]
    r = {"unit": c["unit"], "published": pub["value"], "pub_se": pub["se"], "pub_N": pub["n_obs"]}
    for k, df in R.items():
        if (spec, term) in df.index:
            x = df.loc[(spec, term)]
            r[f"{k}|est"] = round(float(x.estimate), 4); r[f"{k}|z"] = round(z(float(x.estimate), pub["value"], pub["se"]), 2); r[f"{k}|N"] = int(x.n_obs)
    rows.append(r)
T = pd.DataFrame(rows)
T.to_csv(os.path.join(DG, "variant_table.csv"), index=False)
short = {"origin": "orig", "D01_MA_as_controls": "D01", "D02_drop_Hawaii": "D02", "D03_interpolated_controls": "D03",
         "D04_interpolated_controls_xs2014": "D04", "D06_signed_log_error": "D06", "D08_timing_window": "D08", "D10_cumulative": "D10"}
cols = ["unit", "published"] + [f"{k}|est" for k in short] 
print(T[cols].rename(columns=lambda c: short.get(c.split("|")[0], c)).to_string(index=False))
print()
print(T[["unit", "pub_N"] + [f"{k}|N" for k in short]].rename(columns=lambda c: short.get(c.split("|")[0], c)).to_string(index=False))
print()
print(T[["unit"] + [f"{k}|z" for k in short]].rename(columns=lambda c: short.get(c.split("|")[0], c)).to_string(index=False))
for v in ["origin"] + [k for k in runs if k != "origin"]:
    p = os.path.join(os.path.dirname(runs[v]), "an09_counts.csv")
    if os.path.exists(p):
        a = pd.read_csv(p); print(v, a[a.columns[1:]].to_dict("records"))
