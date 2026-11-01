"""Adversarial probe (post-discrepancy, diagnostic only; not a scored specification).

The article's printed multigroup df (375, 401, 427, 417, 427) are reproduced by an 18-indicator five-factor model with
5 group-specific intercepts. Two families satisfy this:
  A: drop one footnoted (released) item, release the other 5 (computed in recompute_audit.py).
  B: keep the altruistic item V4229 constrained (both altruistic intercepts invariant), release the other 5 footnoted
     items, and drop one non-footnoted item from a factor with >= 3 indicators.
For family B this script fits M1-M5 (complete cases on the 18 items, Wishart ML) and reports df, delta CFI
(manifest baseline and the article-implied baseline scale), and d_eq for all 15 contrasts from M4.
Run from the study root: ~/.venv/bin/python -I checks/audit/df_consistent_variants_probe.py
"""
import json, math, sys
import numpy as np, pandas as pd

sys.path.insert(0, "checks/audit")
from sem_audit_lib import fit_mg, moments, baseline_free, cfi

FACT = {"K1": ["V4236", "V4238", "V4240", "V4246"], "K2": ["V4227", "V4225", "V4231", "V4232", "V4234", "V4242", "V4243"],
        "K3": ["V4235", "V4229"], "K4": ["V4233", "V4245"], "K5": ["V4226", "V4228", "V4230", "V4244"]}
REL5 = ["V4238", "V4240", "V4231", "V4230", "V4228"]
YEARS = ["1976", "1991", "2006"]
PAIRS = {"P1": (0, 1), "P2": (1, 2), "P3": (0, 2)}
EXT = {"1976": "1976_DS0004", "1991": "1991_DS0005", "2006": "2006_DS0005"}
ALL = [v for f in FACT.values() for v in f]
raw = {y: pd.read_csv(f"data/derived/extracts/{ds}.csv.gz", usecols=ALL)[ALL] for y, ds in EXT.items()}
NC_ARTICLE = 61371.26409593374  # mean article-implied baseline noncentrality, from recompute_audit.json
NPUB = 3296 + 2526 + 2406

res = []
for K, its in FACT.items():
    if len(its) < 3:
        continue
    for drop in its:
        if drop in REL5:
            continue
        fac = {k: [v for v in vv if v != drop] for k, vv in FACT.items()}
        mark = {k: next(v for v in vv if v not in REL5) for k, vv in fac.items()}
        items = [v for f in fac.values() for v in f]
        gs = []
        for y in YEARS:
            d = raw[y][items]
            d = d[d.isin([1, 2, 3, 4]).all(axis=1)].astype(float)
            gs.append(moments(d.to_numpy()))
        cb, db = baseline_free(gs)
        N = sum(g[0] for g in gs)
        r = {"dropped": drop, "markers": mark, "released": REL5, "n": [g[0] for g in gs]}
        for m in ("M1", "M2", "M3", "M4", "M5"):
            mod = fit_mg(items, fac, mark, m, REL5, gs)
            r[m] = {"chisq": mod.chisq, "df": mod.df, "cfi": cfi(mod.chisq, mod.df, cb, db), "maxgrad": mod.maxgrad,
                    "start_gap": mod.alt_chisq - mod.chisq}
            if m == "M4":
                deq = {}
                for P, (a, b) in PAIRS.items():
                    La, _, _, Pa, aa = mod.mats(mod.theta, a)
                    Lb, _, _, Pb, ab = mod.mats(mod.theta, b)
                    for j, f in enumerate(fac):
                        deq[f"{f}_{P}"] = (ab[j] - aa[j]) / math.sqrt((Pa[j, j] + Pb[j, j]) / 2)
                r["d_eq_M4"] = deq
        r["df_pattern"] = [r[m]["df"] for m in ("M1", "M2", "M3", "M4", "M5")]
        r["dcfi_M2_M4_manifest_baseline"] = r["M2"]["cfi"] - r["M4"]["cfi"]
        dnc = (r["M4"]["chisq"] - r["M4"]["df"]) - (r["M2"]["chisq"] - r["M2"]["df"])
        r["dcfi_M2_M4_article_baseline_scale"] = dnc / (NC_ARTICLE * (N - 3) / (NPUB - 3))
        r["M1_chisq_at_published_N"] = r["M1"]["chisq"] * (NPUB - 3) / (N - 3)
        res.append(r)
        print(drop, r["df_pattern"], round(r["dcfi_M2_M4_manifest_baseline"], 5), round(r["dcfi_M2_M4_article_baseline_scale"], 5),
              {k: round(v, 3) for k, v in r["d_eq_M4"].items() if k.startswith("K3")}, flush=True)
json.dump(res, open("checks/audit/df_consistent_variants_probe.json", "w"), indent=1, default=float)
