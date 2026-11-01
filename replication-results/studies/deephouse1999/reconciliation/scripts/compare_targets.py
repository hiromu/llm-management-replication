"""Transcription comparison of the two readers' sealed targets (rule 3 of reconciliation_rules_v1.md)."""
import json, re, sys, csv
from pathlib import Path

ST = Path(sys.argv[1])

def load(r):
    d = json.load(open(ST / f"readers/{r}/initial_v1/out/sealed_targets.json"))
    return d["targets"] if isinstance(d, dict) else d

def norm_model(m):
    m = str(m or "")
    g = re.search(r"(\d)", m)
    s = "M%s" % g.group(1) if g else m
    if re.search(r"sq|without|no first|only", m, re.I):
        s += "_SQONLY"
    return s

def norm_term(t):
    t = str(t or "").lower().replace("²", "^2").replace("squared", "^2")
    t = re.sub(r"[^a-z0-9^]+", " ", t).strip()
    t = t.replace("strategic deviation 2", "strategic deviation^2").replace("strategic deviation ^2", "strategic deviation^2")
    if "lag" in t or "t 1" in t or "t1" in t:
        return "lag_relative_roa"
    for k, v in [("intercept", "intercept"), ("constant", "intercept"), ("market share", "market_share"),
                 ("expense", "total_expense_ratio"), ("growth", "real_market_growth")]:
        if k in t:
            return v
    if "deviation^2" in t or "deviation 2" in t:
        return "sd_sq"
    if "deviation" in t:
        return "sd"
    return t

def num(x):
    if x is None:
        return None
    s = str(x).replace("−", "-").replace(" ", "")
    return s

rows = {}
for r in ["fable", "astra"]:
    for x in load(r):
        tab = str(x.get("table") or "")
        if "2" not in tab or "Table 2" not in tab:
            continue
        key = (norm_model(x.get("model")), norm_term(x.get("row_term")))
        rows.setdefault(key, {})[r] = x

out = []
for key in sorted(rows):
    f = rows[key].get("fable"); a = rows[key].get("astra")
    def g(x, k): return None if x is None else num(x.get(k))
    rec = {"model": key[0], "term": key[1],
           "coef_A": g(f, "coefficient"), "coef_B": g(a, "coefficient"),
           "se_A": g(f, "published_se"), "se_B": g(a, "published_se"),
           "stars_A": g(f, "stars_or_inequality"), "stars_B": g(a, "stars_or_inequality")}
    rec["match"] = all(rec[f"{k}_A"] == rec[f"{k}_B"] for k in ("coef", "se", "stars"))
    out.append(rec)

w = csv.DictWriter(open(ST / "reconciliation/table2_transcription_comparison.csv", "w", newline=""), fieldnames=list(out[0]))
w.writeheader(); w.writerows(out)
for r in out:
    print(r)
