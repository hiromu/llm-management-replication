"""Compare implementations' results.csv row by row under the frozen agreement rule (scoring_rules_v1.json).
usage: compare_impls.py <out_json> <A_results.csv> <B_results.csv> <C_results.csv>
"""
import json, sys
from collections import Counter
import numpy as np
import pandas as pd

out, paths = sys.argv[1], dict(zip("ABC", sys.argv[2:5]))
import os, re
GRID = pd.read_csv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "manifest/grid_v1.csv"), dtype=str)
REG = set(GRID.loc[GRID.analysis.isin(["AN03", "AN04", "AN05", "AN06", "AN07", "AN08", "AN11", "AN12", "AN13", "AN14"]), "spec_id"])


def norm_term(t):
    """Term labels were not fixed by the manifest; map equivalent labels to one name."""
    t = str(t)
    m = re.fullmatch(r"treat_(?:x_|year_)(\d{4})", t)
    if m:
        return f"treat_{m.group(1)}"
    return {"post_placebo_treat": "post_treat"}.get(t, t)


R = {k: pd.read_csv(p, dtype={"spec_id": str, "term": str, "sample_hash": str}) for k, p in paths.items()}
for k in R:
    R[k]["term"] = R[k]["term"].fillna("").map(norm_term)
    R[k] = R[k][R[k].spec_id.isin(REG)].drop_duplicates(["spec_id", "term"]).set_index(["spec_id", "term"])


def agree(a, b):
    if a["status"] != "ok" or b["status"] != "ok":
        return a["status"] == b["status"], "status"
    if pd.isna(a["estimate"]) and pd.isna(b["estimate"]):
        return True, "no_estimate"
    if a["n_obs"] != b["n_obs"]:
        return False, "n_obs"
    if str(a["sample_hash"]) != str(b["sample_hash"]):
        return False, "sample_hash"
    se = np.nanmean([a["se_cluster"], b["se_cluster"]])
    if not abs(a["estimate"] - b["estimate"]) <= max(1e-8, 1e-3 * (se if np.isfinite(se) else 0)):
        return False, "estimate"
    for col in ("se_cluster", "se_hc1"):
        x, y = a[col], b[col]
        if pd.isna(x) and pd.isna(y):
            continue
        if pd.isna(x) or pd.isna(y) or abs(x - y) > 0.005 * max(abs(x), abs(y)):
            return False, col
    return True, "ok"


keys = sorted(set().union(*[set(r.index) for r in R.values()]))
rows, summary = [], Counter()
for key in keys:
    rec = {"spec_id": key[0], "term": key[1]}
    for p, q in (("A", "B"), ("A", "C"), ("B", "C")):
        if key in R[p].index and key in R[q].index:
            ok, why = agree(R[p].loc[key], R[q].loc[key])
        else:
            ok, why = False, "missing_row"
        rec[f"{p}{q}"] = ok
        rec[f"{p}{q}_why"] = why
        summary[f"{p}{q}_{'agree' if ok else why}"] += 1
    rec["any_pair"] = rec["AB"] or rec["AC"] or rec["BC"]
    rec["all_three"] = rec["AB"] and rec["AC"]
    rows.append(rec)
df = pd.DataFrame(rows)
res = {"rows": len(df), "all_three": int(df.all_three.sum()), "any_pair": int(df.any_pair.sum()), "no_pair": int((~df.any_pair).sum()),
       "pair_summary": dict(summary), "rows_detail_file": out.replace(".json", ".csv")}
df.to_csv(out.replace(".json", ".csv"), index=False)
json.dump(res, open(out, "w"), indent=1)
print(json.dumps(res, indent=1))
