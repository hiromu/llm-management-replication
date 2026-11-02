"""Audit recomputations from data/derived/extracts (auditor's own code; no implementation code imported).

Run from the study root: ~/.venv/bin/python -I checks/audit/recompute_audit.py
Writes checks/audit/recompute_audit.json.
"""
import csv, hashlib, json, math, sys, time
import numpy as np, pandas as pd
from scipy import stats

sys.path.insert(0, "checks/audit")
from sem_audit_lib import MGModel, fit_mg, moments, baseline_free, baseline_equal, cfi

RUN = "runs/run_20261028T035346Z"
YEARS = ["1976", "1991", "2006"]
PAIRS = {"P1": ("1976", "1991"), "P2": ("1991", "2006"), "P3": ("1976", "2006")}
EXT = {("f3", "1976"): "1976_DS0003", ("f3", "1991"): "1991_DS0004", ("f3", "2006"): "2006_DS0004",
       ("f4", "1976"): "1976_DS0004", ("f4", "1991"): "1991_DS0005", ("f4", "2006"): "2006_DS0005"}
F4 = [f"V{i}" for i in range(4225, 4248)]
F3 = ["V3222", "V3223", "V3224", "V3225", "V3226", "V3227"]
FACT = {"K1": ["V4236", "V4238", "V4240", "V4246"], "K2": ["V4227", "V4225", "V4231", "V4232", "V4234", "V4242", "V4243"],
        "K3": ["V4235", "V4229"], "K4": ["V4233", "V4245"], "K5": ["V4226", "V4228", "V4230", "V4244"]}
MARK = {k: v[0] for k, v in FACT.items()}
REL = ["V4238", "V4240", "V4231", "V4229", "V4230", "V4228"]
ITEMS19 = [v for f in FACT.values() for v in f]

agreed, rawvals = {}, {}
for r in csv.DictReader(open(f"{RUN}/comparison/implementation_agreement_all.csv")):
    agreed[(r["spec"], r["key"])] = r["agreed"]
    rawvals[(r["spec"], r["key"])] = (r["value_A"], r["value_B"], r["value_C"])
A = lambda spec, key: float(agreed[(spec, key)])

out = {"run": RUN, "inputs": {}, "checks": []}
D = {}
for (form, y), ds in EXT.items():
    p = f"data/derived/extracts/{ds}.csv.gz"
    out["inputs"][f"{form}_{y}"] = {"path": p, "sha256": hashlib.sha256(open(p, "rb").read()).hexdigest()}
    df = pd.read_csv(p, low_memory=False)
    items = F4 if form == "f4" else F3
    X = df[items].astype(float).copy()
    for v in items:
        valid = [1, 2, 3, 4] if form == "f4" else ([1, 2] if v == "V3227" else [1, 2, 3, 4, 5])
        X.loc[~X[v].isin(valid), v] = np.nan
    X["V4"] = df["V4"].values
    X["V5"] = df["V5"].values
    D[(form, y)] = X


def chk(name, mine, theirs, tol, kind="abs"):
    diff = abs(mine - theirs) if kind == "abs" else abs(mine - theirs) / max(abs(theirs), 1e-12)
    rec = {"check": name, "auditor": mine, "agreed": theirs, "diff": diff, "tol": tol, "result": "pass" if diff <= tol else "FAIL"}
    out["checks"].append(rec)
    return rec


# ---- 1. item statistics, 6 items x 3 years
for v in ["V4236", "V4227", "V4235", "V4233", "V4226", "V3223"]:
    form = "f3" if v.startswith("V32") else "f4"
    for y in YEARS:
        x = D[(form, y)][v].dropna()
        top = (x == 4).mean() * 100 if form == "f4" else (x >= 4).mean() * 100
        chk(f"item n {v} {y}", len(x), A("S00", f"item|{v}|{y}|n"), 0)
        chk(f"item mean {v} {y}", x.mean(), A("S00", f"item|{v}|{y}|mean"), 1e-9)
        chk(f"item sd {v} {y}", x.std(ddof=1), A("S00", f"item|{v}|{y}|sd"), 1e-9)
        chk(f"item pct {v} {y}", top, A("S00", f"item|{v}|{y}|pct"), 1e-9)

# ---- 2. Student t tests (pooled variance), two cells, plus Welch for one
for v, P in (("V4236", "P3"), ("V3224", "P1")):
    form = "f3" if v.startswith("V32") else "f4"
    a, b = PAIRS[P]
    xa, xb = D[(form, a)][v].dropna(), D[(form, b)][v].dropna()
    t, p = stats.ttest_ind(xb, xa, equal_var=True)
    chk(f"Student t {v} {P}", t, A("S00", f"itest|{v}|{P}|t"), 1e-8)
    chk(f"Student p {v} {P}", p, A("S00", f"itest|{v}|{P}|p"), 1e-12)
    tw, pw = stats.ttest_ind(xb, xa, equal_var=False)
    chk(f"Welch p {v} {P}", pw, A("S00", f"itest|{v}|{P}|welch_p"), 1e-12)

# ---- 3. multigroup analysis samples
mg = {}
for y in YEARS:
    X = D[("f4", y)]
    cc = X.dropna(subset=ITEMS19)
    mg[y] = cc
    h = hashlib.sha256("\n".join(str(int(v)) for v in sorted(cc["V4"])).encode()).hexdigest()
    chk(f"S00 multigroup n {y}", len(cc), A("S00", f"mgn|{y}"), 0)
    out["checks"].append({"check": f"S00 multigroup V4 sha256 {y}", "auditor": h, "agreed": agreed[("S00", f"mghash|{y}")],
                          "result": "pass" if h == agreed[("S00", f"mghash|{y}")] else "FAIL"})

# ---- 4. d_eq recomputed from reported latent means and factor variances (each implementation and agreed)
deq = []
for K in FACT:
    for P, (a, b) in PAIRS.items():
        row = {"contrast": f"{K}_{P}"}
        for j, I in enumerate("ABC"):
            ma = float(rawvals[("S00", f"lat|{K}|{a}|mean")][j]); mb = float(rawvals[("S00", f"lat|{K}|{b}|mean")][j])
            pa = float(rawvals[("S00", f"lat|{K}|{a}|psi")][j]); pb = float(rawvals[("S00", f"lat|{K}|{b}|psi")][j])
            mine = (mb - ma) / math.sqrt((pa + pb) / 2)
            rep = float(rawvals[("S00", f"con|{K}|{P}|d_eq")][j])
            row[I] = {"recomputed": mine, "reported": rep, "absdiff": abs(mine - rep)}
        row["agreed_d_eq"] = A("S00", f"con|{K}|{P}|d_eq")
        deq.append(row)
out["d_eq_from_latent"] = deq
out["checks"].append({"check": "d_eq recomputed from each implementation's latent means and psi (45 values)",
                      "max_absdiff": max(r[I]["absdiff"] for r in deq for I in "ABC"),
                      "result": "pass" if max(r[I]["absdiff"] for r in deq for I in "ABC") < 1e-9 else "FAIL"})

# ---- 5. coefficient alpha K6/K7 (complete on scale), bootstrap SE, standardized version, and composite SDs
def alpha(M):
    k = M.shape[1]
    C = np.cov(M, rowvar=False, ddof=1)
    return k / (k - 1) * (1 - np.trace(C) / C.sum())


rng = np.random.default_rng(2010)
alph = {}
for sc, its in (("K6", ["V4239", "V4241"]), ("K7", ["V4237", "V4247"])):
    for y in YEARS:
        M = D[("f4", y)][its].dropna().to_numpy()
        a = alpha(M)
        r = np.corrcoef(M, rowvar=False)[0, 1]
        bs = [alpha(M[rng.integers(0, len(M), len(M))]) for _ in range(2000)]
        alph[f"{sc}_{y}"] = {"n": len(M), "alpha_raw": a, "alpha_standardized": 2 * r / (1 + r), "bootstrap_se": float(np.std(bs, ddof=1)),
                             "bootstrap_95": [float(np.quantile(bs, .025)), float(np.quantile(bs, .975))],
                             "share_bootstrap_le_0505": float(np.mean(np.array(bs) <= 0.505))}
        chk(f"alpha {sc} {y}", a, A("S00", f"alpha|{sc}|{y}"), 1e-9)
out["alpha_security_influence"] = alph

comp_sd = {}
for K, its in FACT.items():
    for y in YEARS:
        comp_sd[f"{K}_{y}"] = float(mg[y][its].mean(axis=1).std(ddof=1))
out["composite_sd_multigroup_sample"] = comp_sd

# ---- 6. N-branch diagnostics (not used for tuning): counts under simple record filters
nb = {}
for (form, y), X in D.items():
    its = F4 if form == "f4" else F3
    nb[f"{form}_{y}"] = {"rows": len(X), "any_valid_item": int(X[its].notna().any(axis=1).sum()),
                         "all_items_valid": int(X[its].notna().all(axis=1).sum())}
out["n_filters"] = nb

# ---- 7. own multigroup fits, 19 items (S00), compare with agreed
groups19 = [moments(mg[y][ITEMS19].to_numpy()) for y in YEARS]
chib, dfb = baseline_free(groups19)
chibe, dfbe = baseline_equal(groups19)
own = {}
for m in ("M1", "M2", "M3", "M4", "M5"):
    t0 = time.time()
    mod = fit_mg(ITEMS19, FACT, MARK, m, REL, groups19)
    own[m] = {"chisq": mod.chisq, "df": mod.df, "cfi": cfi(mod.chisq, mod.df, chib, dfb), "cfi_equal_baseline": cfi(mod.chisq, mod.df, chibe, dfbe),
              "maxgrad": mod.maxgrad, "other_start_chisq": mod.alt_chisq, "seconds": time.time() - t0}
    chk(f"own {m} chi-square (relative)", mod.chisq, A("S00", f"fit|{m}|MG|chisq"), 1e-4, "rel")
    chk(f"own {m} df", mod.df, A("S00", f"fit|{m}|MG|df"), 0)
    chk(f"own {m} CFI", own[m]["cfi"], A("S00", f"fit|{m}|MG|cfi"), 1e-4)
    if m == "M4":
        m4 = mod
out["own_multigroup_19"] = {"baseline_free": [chib, dfb], "baseline_equal_means_variances": [chibe, dfbe], "models": own}
dcfi = own["M2"]["cfi"] - own["M4"]["cfi"]
chk("own delta CFI M2-M4", dcfi, A("S00", "mdiff|M4-M2|dcfi"), 1e-4)
out["own_multigroup_19"]["dcfi_M2_M4_equal_baseline"] = own["M2"]["cfi_equal_baseline"] - own["M4"]["cfi_equal_baseline"]

# own d_eq from own M4
K = list(FACT)
own_d = {}
for P, (a, b) in PAIRS.items():
    ga, gb = YEARS.index(a), YEARS.index(b)
    La, nua, Tha, Psa, ala = m4.mats(m4.theta, ga)
    Lb, nub, Thb, Psb, alb = m4.mats(m4.theta, gb)
    for j, f in enumerate(K):
        d = (alb[j] - ala[j]) / math.sqrt((Psa[j, j] + Psb[j, j]) / 2)
        own_d[f"{f}_{P}"] = d
        chk(f"own M4 d_eq {f} {P}", d, A("S00", f"con|{f}|{P}|d_eq"), 0.002)
out["own_d_eq"] = own_d

# ---- 8. article-implied baseline and rescaled delta CFI
pub = {"M1": (4110.93, 375, .9391), "M2": (4150.52, 401, .9389), "M3": (4539.10, 427, .9330), "M4": (4241.86, 417, .9377), "M5": (4760.09, 427, .9294)}
impl_base = {m: (c - d) / (1 - f) for m, (c, d, f) in pub.items()}
out["article_implied_baseline_noncentrality"] = impl_base
nc_pub = np.mean(list(impl_base.values()))
rec_dnc = A("S00", "fit|M4|MG|chisq") - 470 - (A("S00", "fit|M2|MG|chisq") - 454)
out["rescaled_delta_cfi"] = {
    "reconstructed_noncentrality_increment_M2_to_M4": rec_dnc,
    "reconstructed_baseline_noncentrality": chib - dfb,
    "article_baseline_noncentrality_mean_M1_M5": nc_pub,
    "article_baseline_scaled_to_reconstruction_N": nc_pub * (sum(n - 1 for n, _, _ in groups19) / (3296 + 2526 + 2406 - 3)),
    "dcfi_using_article_baseline_scaled": rec_dnc / (nc_pub * (sum(n - 1 for n, _, _ in groups19) / (3296 + 2526 + 2406 - 3))),
    "dcfi_ratio_method": A("S00", "mdiff|M4-M2|dcfi") * (1 - .9391) / (1 - A("S00", "fit|M1|MG|cfi")),
    "article_dnc_over_configural_nc": (91.34 - 16) / (4110.93 - 375),
    "reconstructed_dnc_over_configural_nc": rec_dnc / (A("S00", "fit|M1|MG|chisq") - 426),
    "baseline_noncentrality_needed_for_dcfi_below_0.002": rec_dnc / 0.002,
}

# single-group 5-factor: article-implied baseline vs reconstructed baseline (per year, from printed CFI/TLI)
sg = {}
pubsg = {"1976": (1655.87, .92), "1991": (1419.08, .92), "2006": (1451.73, .94)}
for y in YEARS:
    c, tli = pubsg[y]
    r_chi = c / 142
    x = (r_chi - tli) / (1 - tli)  # chi_B/df_B implied by printed TLI (df_B = 171)
    S = groups19[YEARS.index(y)][2]
    n = groups19[YEARS.index(y)][0]
    _, ld = np.linalg.slogdet(S)
    rb = (n - 1) * (np.log(np.diag(S)).sum() - ld)
    sg[y] = {"article_baseline_chisq_implied_by_TLI": x * 171, "reconstructed_baseline_chisq": rb, "reconstructed_n": n,
             "ratio_per_case": (x * 171 / {"1976": 3296, "1991": 2526, "2006": 2406}[y]) / (rb / n)}
out["single_group_baseline_comparison"] = sg

# ---- 9. 18-indicator variants consistent with the article's printed df (375/401/427/417/427)
variants = []
for drop in REL:
    fac = {k: [v for v in its if v != drop] for k, its in FACT.items()}
    if min(len(v) for v in fac.values()) < 2:
        variants.append({"dropped": drop, "status": "not fitted: leaves a single-indicator factor (df would not match)"})
        continue
    items = [v for f in fac.values() for v in f]
    rel = [v for v in REL if v != drop]
    res = {"dropped": drop, "released": rel}
    for sample_rule in ("complete_on_18", "complete_on_19"):
        gs = [moments((mg[y] if sample_rule == "complete_on_19" else D[("f4", y)].dropna(subset=items))[items].to_numpy()) for y in YEARS]
        cb, db = baseline_free(gs)
        r = {"n": [g[0] for g in gs]}
        for m in ("M1", "M2", "M3", "M4", "M5"):
            mod = fit_mg(items, fac, MARK, m, rel, gs)
            r[m] = {"chisq": mod.chisq, "df": mod.df, "cfi": cfi(mod.chisq, mod.df, cb, db), "maxgrad": mod.maxgrad, "other_start_chisq": mod.alt_chisq}
        r["dcfi_M2_M4"] = r["M2"]["cfi"] - r["M4"]["cfi"]
        r["dchisq_M2_M4"] = r["M4"]["chisq"] - r["M2"]["chisq"]
        r["dcfi_M2_M3"] = r["M2"]["cfi"] - r["M3"]["cfi"]
        r["dcfi_M1_M2"] = r["M1"]["cfi"] - r["M2"]["cfi"]
        r["df_pattern"] = [r[m]["df"] for m in ("M1", "M2", "M3", "M4", "M5")]
        res[sample_rule] = r
    variants.append(res)
    print("variant", drop, res["complete_on_18"]["df_pattern"], res["complete_on_18"]["dcfi_M2_M4"], res["complete_on_19"]["dcfi_M2_M4"], flush=True)
out["variants_18_indicators"] = variants

json.dump(out, open("checks/audit/recompute_audit.json", "w"), indent=1, default=float)
fails = [c for c in out["checks"] if c.get("result") == "FAIL"]
print("checks", len(out["checks"]), "fails", len(fails))
for c in fails:
    print(c)
print(json.dumps(out["own_multigroup_19"], indent=1, default=float))
print(json.dumps(out["rescaled_delta_cfi"], indent=1))
print(json.dumps(out["single_group_baseline_comparison"], indent=1))
print(json.dumps(out["alpha_security_influence"], indent=1))
print(json.dumps(out["n_filters"]))
print(json.dumps(comp_sd))
