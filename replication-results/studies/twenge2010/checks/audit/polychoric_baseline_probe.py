"""Audit probe: does a polychoric-correlation input (PRELIS default for variables with few categories) reproduce the
scale of the article's single-group Form 4 five-factor fit (chi-square and CFI/TLI)? Diagnostic only; nothing here
changes any rule, target or scored value.

Run from the study root: ~/.venv/bin/python -I checks/audit/polychoric_baseline_probe.py
"""
import json, sys
import numpy as np, pandas as pd
from scipy import stats, optimize

sys.path.insert(0, "checks/audit")
from sem_audit_lib import MGModel, fit_mg, cfi

FACT = {"K1": ["V4236", "V4238", "V4240", "V4246"], "K2": ["V4227", "V4225", "V4231", "V4232", "V4234", "V4242", "V4243"],
        "K3": ["V4235", "V4229"], "K4": ["V4233", "V4245"], "K5": ["V4226", "V4228", "V4230", "V4244"]}
MARK = {k: v[0] for k, v in FACT.items()}
ITEMS = [v for f in FACT.values() for v in f]
EXT = {"1976": "1976_DS0004", "1991": "1991_DS0005", "2006": "2006_DS0005"}
PUB = {"1976": dict(chisq=1655.87, tli=.92, cfi=.93, N=3296), "1991": dict(chisq=1419.08, tli=.92, cfi=.93, N=2526),
       "2006": dict(chisq=1451.73, tli=.94, cfi=.95, N=2406)}


def thresholds(x):
    cats = np.arange(1, 5)
    cum = np.cumsum([np.mean(x == c) for c in cats])[:-1]
    return np.concatenate([[-8.0], stats.norm.ppf(np.clip(cum, 1e-9, 1 - 1e-9)), [8.0]])


def bvn_rect(t1, t2, rho):
    mvn = stats.multivariate_normal(mean=[0, 0], cov=[[1, rho], [rho, 1]])
    G = np.array([[mvn.cdf([a, b]) for b in t2] for a in t1])
    G[0, :] = 0
    G[:, 0] = 0
    G[-1, :] = stats.norm.cdf(t2)
    G[:, -1] = stats.norm.cdf(t1)
    G[-1, -1] = 1.0
    return np.diff(np.diff(G, axis=0), axis=1)


def polychoric(x, y):
    t1, t2 = thresholds(x), thresholds(y)
    tab = np.array([[np.sum((x == i) & (y == j)) for j in range(1, 5)] for i in range(1, 5)])
    nll = lambda r: -np.sum(tab * np.log(np.clip(bvn_rect(t1, t2, r), 1e-300, None)))
    return optimize.minimize_scalar(nll, bounds=(-0.99, 0.99), method="bounded", options=dict(xatol=1e-6)).x


out = {}
for y, ds in EXT.items():
    df = pd.read_csv(f"data/derived/extracts/{ds}.csv.gz", usecols=ITEMS)[ITEMS]  # usecols keeps file order; reorder
    df = df[df.isin([1, 2, 3, 4]).all(axis=1)].astype(int)
    X = df.to_numpy()
    n, p = X.shape
    R = np.eye(p)
    for i in range(p):
        for j in range(i):
            R[i, j] = R[j, i] = polychoric(X[:, i], X[:, j])
    Rp = np.corrcoef(X, rowvar=False)
    res = {"n": n}
    for lab, M in (("pearson", Rp), ("polychoric", R)):
        mod = fit_mg(ITEMS, FACT, MARK, "M1", [], [(n, np.zeros(p), M)])
        chib = -(n - 1) * np.linalg.slogdet(M)[1]
        dfb = p * (p - 1) // 2
        tli = ((chib / dfb) - (mod.chisq / mod.df)) / ((chib / dfb) - 1)
        res[lab] = {"chisq": mod.chisq, "df": mod.df, "baseline_chisq": chib, "cfi": cfi(mod.chisq, mod.df, chib, dfb), "tli": tli,
                    "chisq_scaled_to_published_N": mod.chisq * (PUB[y]["N"] - 1) / (n - 1), "maxgrad": mod.maxgrad,
                    "mean_abs_offdiag_r": float(np.abs(M[np.tril_indices(p, -1)]).mean())}
    res["published"] = PUB[y]
    out[y] = res
    print(y, json.dumps(res, default=float), flush=True)
json.dump(out, open("checks/audit/polychoric_baseline_probe.json", "w"), indent=1, default=float)
