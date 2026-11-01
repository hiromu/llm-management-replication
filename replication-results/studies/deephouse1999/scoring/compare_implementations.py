"""Step 1 of downstream scoring (scoring_rules_v1.json, implementation_agreement): compare the
implementations with each other before any published target is opened."""
import json, sys, itertools
from pathlib import Path
import numpy as np
import pandas as pd

ST = Path(sys.argv[1]); RUN = sys.argv[2]; IMPLS = sys.argv[3].split(",")
RD = ST / "runs" / RUN
OUT = ST / "scoring" / RUN
OUT.mkdir(parents=True, exist_ok=True)

TERM_MAP = {"(intercept)": "intercept", "intercept": "intercept", "const": "intercept"}

def load(impl):
    d = pd.read_csv(RD / impl / "out/spec_results.csv")
    d["term"] = d["term"].astype(str).map(lambda t: TERM_MAP.get(t.lower(), t))
    d["impl"] = impl
    return d

res = {i: load(i) for i in IMPLS}
key = ["spec_id", "model", "term"]

def tol(a, b):
    return np.abs(a - b) <= 1e-6 * np.maximum(1.0, np.abs(a))

rows = []
for a, b in itertools.combinations(IMPLS, 2):
    A, B = res[a], res[b]
    sa = A.drop_duplicates(["spec_id", "model"]).set_index(["spec_id", "model"])
    sb = B.drop_duplicates(["spec_id", "model"]).set_index(["spec_id", "model"])
    for idx in sorted(set(sa.index) | set(sb.index)):
        ra = sa.loc[idx] if idx in sa.index else None
        rb = sb.loc[idx] if idx in sb.index else None
        rec = {"pair": f"{a}|{b}", "spec_id": idx[0], "model": idx[1],
               "status_a": None if ra is None else ra["status"], "status_b": None if rb is None else rb["status"]}
        if ra is not None and rb is not None and ra["status"] == "ok" and rb["status"] == "ok":
            rec["n_a"], rec["n_b"] = ra["n"], rb["n"]
            rec["hash_same"] = ra["sample_hash"] == rb["sample_hash"]
            ta = A[(A.spec_id == idx[0]) & (A.model == idx[1])].set_index("term")
            tb = B[(B.spec_id == idx[0]) & (B.model == idx[1])].set_index("term")
            common = ta.index.intersection(tb.index)
            rec["terms_a"], rec["terms_b"], rec["terms_common"] = len(ta), len(tb), len(common)
            est_ok = bool(tol(ta.loc[common, "estimate"].values, tb.loc[common, "estimate"].values).all()) if len(common) else False
            se_ok = bool(tol(ta.loc[common, "se"].values, tb.loc[common, "se"].values).all()) if len(common) else False
            rec["max_abs_est_diff"] = float(np.max(np.abs(ta.loc[common, "estimate"].values - tb.loc[common, "estimate"].values))) if len(common) else None
            # Fixed-effect indicator labels are implementation-specific; agreement is judged on the
            # manifest's named terms, which must all be present in both, plus identical term counts.
            core = {"intercept", "SD", "SD2", "MS", "TER", "RMG", "lag"}
            core_a, core_b = core & set(ta.index), core & set(tb.index)
            rec["fe_label_mismatch"] = len(common) != len(ta)
            rec["agree"] = bool(rec["hash_same"] and est_ok and se_ok and core_a == core_b
                                and core_a <= set(common) and len(ta) == len(tb))
        else:
            rec["agree"] = (ra is not None and rb is not None and ra["status"] == rb["status"])
            rec["agree_kind"] = "status_only"
        rows.append(rec)
cmp = pd.DataFrame(rows)
cmp.to_csv(OUT / "implementation_pairwise.csv", index=False)

# Spec-level agreement (all four models) and origin summary.
spec = cmp.groupby(["pair", "spec_id"]).agg(agree=("agree", "all"), n_models=("model", "size")).reset_index()
summary = {}
for p, g in spec.groupby("pair"):
    summary[p] = {"specs": int(len(g)), "specs_agree": int(g.agree.sum()),
                  "origin_O_A_agree": bool(g[g.spec_id == "O_A"].agree.all()) if (g.spec_id == "O_A").any() else None,
                  "origin_O_B_agree": bool(g[g.spec_id == "O_B"].agree.all()) if (g.spec_id == "O_B").any() else None,
                  "disagreeing_specs": sorted(g[~g.agree].spec_id.tolist())}
origin = cmp[cmp.spec_id.isin(["O_A", "O_B"])][["pair", "spec_id", "model", "n_a", "n_b", "hash_same", "max_abs_est_diff", "agree"]]
json.dump({"pairs": summary, "origin_rows": origin.to_dict("records")}, open(OUT / "implementation_agreement.json", "w"), indent=1, default=str)
print(json.dumps({p: {k: v for k, v in s.items() if k != "disagreeing_specs"} | {"n_disagreeing": len(s["disagreeing_specs"])} for p, s in summary.items()}, indent=1))
print(origin.to_string())
