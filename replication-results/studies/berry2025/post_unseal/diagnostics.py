"""Post-unsealing diagnostics. One difference between frozen AI output and author code at a time. Frozen outputs are not altered."""
import glob, json, math, os, re
import numpy as np, pandas as pd
RUN = sorted(glob.glob("runs/empirical_*"))[-1]
T = json.load(open("sealed/targets/targets_reconciled.json"))
d = pd.read_csv(f"{RUN}/A/results.csv", dtype=str, keep_default_na=False); d["v"] = pd.to_numeric(d.value, errors="coerce")
L = {(r.sample_level, r.composite_level, r.key, r.method): r.v for r in d.itertuples()}
def get(ds, key, method, cl=None):
    s = {1: "D1_key", 2: "D2_any", 3: "D3_all", 4: "D4_loyal"}[ds]; c = cl or ("existing" if ds == 4 else "mean"); return L.get((s, c, key, method))
def dec(s): return len(str(s).split(".")[1]) if "." in str(s) else 0
def mt(v, pub): return abs(abs(v) - abs(float(str(pub).replace("−", "-")))) <= .5 * 10 ** (-dec(pub)) + 1e-9
OUT = {}
# 1 filters
s = pd.read_csv(f"{RUN}/A/samples.csv", dtype=str); sets = {k: set(g.unit_id) for k, g in s.groupby("sample_level")}
OUT["filters"] = {"level_sizes": {k: len(v) for k, v in sets.items()}, "D1_key==D1_none": sets["D1_key"] == sets["D1_none"], "D2_any==D2_none": sets["D2_any"] == sets["D2_none"], "D2_both==D2_none": sets["D2_both"] == sets["D2_none"], "D3_all==D3_none": sets["D3_all"] == sets["D3_none"], "D3_comp==D3_none": sets["D3_comp"] == sets["D3_none"]}
# 2 composites
diff = []
for (sl, cl, k, m), v in L.items():
    if cl == "existing" and sl in ("D1_key", "D2_any", "D3_all"):
        w = L.get((sl, "mean", k, m))
        if w is not None and not math.isnan(v) and not math.isnan(w) and abs(v - w) > 1e-8 and not k.rsplit(".", 1)[-1].startswith(("ci_", "se_boot", "boot")): diff.append((k, v, w))
OUT["composite_existing_vs_mean"] = {"keys_differing": len(diff), "examples": diff[:8]}
hm = [(k, v, L.get(("D4_loyal", "mean", k, "logit"))) for (sl, cl, k, m), v in L.items() if sl == "D4_loyal" and cl == "existing" and k == "L4.M3.LoyalRequestor.coef"]
OUT["house_loyalty_existing_vs_item_mean"] = hm
# 3 pairing and within-file rows
b1 = pd.read_csv("data/derived/implementer_bundle/dataset_1.csv", dtype=str, keep_default_na=False); pos = {}
for o in ("you_grant", "prom_voice", "proh_voice"):
    a = pd.to_numeric(b1.loc[b1.cond == "loyal", o], errors="coerce").values; c = pd.to_numeric(b1.loc[b1.cond == "control", o], errors="coerce").values; x = a - c
    pos[o] = {"positional_t": x.mean() / (x.std(ddof=1) / math.sqrt(len(x))), "ai_uid_t": get(1, f"P1.{o}.t", "paired")}
OUT["positional_pairing"] = pos; OUT["uid_order_identical"] = bool((b1.loc[b1.cond == "loyal", "part_uid"].values == b1.loc[b1.cond == "control", "part_uid"].values).all())
# 4 effect sizes
au = pd.read_csv("post_unseal/author_vs_published.csv"); aud = {r.key: r.value for r in au.itertuples()}
rows = []
for k, t in T.items():
    if re.match(r"^(P1|T2|C3\.H[13])\..*\.d$", k):
        ds = 1 if k.startswith("P1") else 2 if k.startswith("T2") else 3; m = "paired" if ds == 1 else "descriptive"
        ai = get(ds, k, m); alt = get(ds, k + "_pooled", m) if ds == 3 else None
        rows.append({"key": k, "published": t["value"], "ai_frozen_d": ai, "ai_match": mt(ai, t["value"]), "ai_d_pooled": alt, "pooled_match": (mt(alt, t["value"]) if alt is not None else None), "author": aud.get(k), "author_match": (mt(aud[k], t["value"]) if k in aud else None)})
OUT["effect_size"] = {"n": len(rows), "ai_match": sum(r["ai_match"] for r in rows), "author_match": sum(bool(r["author_match"]) for r in rows), "ai_d_pooled_match_study3": sum(bool(r["pooled_match"]) for r in rows if r["pooled_match"] is not None), "study3_n": sum(1 for r in rows if r["pooled_match"] is not None), "study1_note": [r for r in rows if r["key"].startswith("P1")]}
# 5 eta
rows = []
for k, t in T.items():
    if k.startswith("A3.") and k.endswith(".eta2"):
        rows.append({"key": k, "published": t["value"], "type3": get(3, k, "type3"), "type2": get(3, k, "type2"), "m3": mt(get(3, k, "type3"), t["value"]), "m2": mt(get(3, k, "type2"), t["value"])})
OUT["eta2"] = {"n": len(rows), "type3_match": sum(r["m3"] for r in rows), "type2_match": sum(r["m2"] for r in rows), "both_miss": [r for r in rows if not r["m2"]]}
# 6 indirect inference: frozen bootstrap versus author's Wald output
rows = []
for k, t in T.items():
    if k.startswith(("PM2.", "MED4.")) and k.endswith(".ind"):
        ds = 2 if k.startswith("PM2") else 4; meth = "ols" if ds == 2 else "linear_cont"; r0 = k[:-4]
        lo, hi = get(ds, r0 + ".ci_bc_low", meth), get(ds, r0 + ".ci_bc_high", meth); pub_ex = float(str(t["ci_low"]).replace("−", "-")) > 0 or float(str(t["ci_high"]).replace("−", "-")) < 0
        rows.append({"key": k, "published": t["value"], "published_se": t["se"], "published_ci": [t["ci_low"], t["ci_high"]], "published_p": t["p_exact"] or t["p_inequality"], "ai_ind": get(ds, r0 + ".ind", meth), "ai_se_boot": get(ds, r0 + ".se_boot", meth), "ai_se_delta": get(ds, r0 + ".se_delta", meth), "ai_ci_bc": [lo, hi], "ai_p_delta": get(ds, r0 + ".p_delta", meth), "author_se": aud.get(k + "#se"), "author_p": aud.get(k + "#p"), "author_ci": [aud.get(k + "#ci_low"), aud.get(k + "#ci_high")], "zero_exclusion_same": (lo > 0 or hi < 0) == pub_ex})
OUT["indirect"] = {"n": len(rows), "zero_exclusion_same": sum(r["zero_exclusion_same"] for r in rows), "rows": rows}
# 7 gender: which uncertain method matches printed
g = {}
for k, t in T.items():
    if k.startswith(("G1W", "G2W", "G1C", "G2C")) and k.endswith(".t"):
        ds = 1 if k[1] == "1" else 2; c = {m: (lambda v: None if v is None else mt(v, t["value"]))(get(ds, k, m)) for m in ("paired", "student", "welch")}
        for m, x in c.items():
            if x is not None: g.setdefault(k[:3], {}).setdefault(m, [0, 0]); g[k[:3]][m][0] += int(x); g[k[:3]][m][1] += 1
OUT["gender_print_match_by_method"] = g
json.dump(OUT, open("post_unseal/diagnostics.json", "w"), indent=1, default=str)
for k in ("filters", "composite_existing_vs_mean", "house_loyalty_existing_vs_item_mean", "positional_pairing", "uid_order_identical", "gender_print_match_by_method"): print(k, json.dumps(OUT[k], default=str)[:700])
print("eff", {k: v for k, v in OUT["effect_size"].items() if k != "study1_note"}); print(json.dumps(OUT["effect_size"]["study1_note"], default=str)[:600]); print("eta", OUT["eta2"]["n"], OUT["eta2"]["type3_match"], OUT["eta2"]["type2_match"], OUT["eta2"]["both_miss"])
print("ind", OUT["indirect"]["n"], OUT["indirect"]["zero_exclusion_same"])
for r in OUT["indirect"]["rows"]: print(r["key"][:42], r["published"], r["published_se"], r["published_p"], "| ai", round(r["ai_ind"], 3), round(r["ai_se_boot"], 3), round(r["ai_se_delta"], 3), round(r["ai_p_delta"], 3), [round(x, 2) for x in r["ai_ci_bc"]], r["published_ci"], r["zero_exclusion_same"])
