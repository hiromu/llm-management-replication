"""Compare implementations A, B, C on every normalized quantity of every specification (no targets used).

Tolerances: sealed/scoring_rules.json implementation_agreement. Fields not listed there (SEs, p values, variances,
alpha, percentages, df, chi-square differences) use the addendum rule recorded in
checks/implementation_tolerance_addendum.json (relative 1e-3 with absolute floor 1e-6), written before any target comparison.
Run: ~/.venv/bin/python -I checks/scripts/compare_implementations.py <run_dir>
"""
import json, sys, os, itertools, csv
sys.path.insert(0, "checks/scripts")
from adapters import normalize

RUN = sys.argv[1]
SPECS = ["S00", "S01", "S02", "S03", "S04", "S05", "S06", "S07a", "S07b", "S08", "CHK1", "CHK2"]
IMPLS = "ABC"


def tol(key):
    kind = key[0]
    if kind in ("rows", "mgn", "mghash"):
        return ("exact", 0)
    if kind == "item" and key[3] == "n":
        return ("exact", 0)
    if kind == "con" and key[3] in ("d_eq", "d_df", "g", "d_glass", "d_obs"):
        return ("abs", 0.002)
    if kind == "con" and key[3] == "Delta":
        return ("abs", 0.002)
    if kind == "lat" and key[3] == "mean":
        return ("abs", 0.002)
    if kind == "item" and key[3] in ("mean", "sd"):
        return ("abs", 1e-6)
    if kind == "itest" and key[3] in ("t", "welch_t", "z", "diff"):
        return ("abs", 1e-4)
    if kind == "fit" and key[3] == "chisq":
        return ("rel", 1e-3)
    if kind == "fit" and key[3] in ("rmsea", "cfi", "tli", "srmr"):
        return ("abs", 0.001)
    if kind == "fit" and key[3] == "df":
        return ("exact", 0)
    if kind == "mdiff" and key[2] == "ddf":
        return ("exact", 0)
    return ("relfloor", 1e-3)


def agree(a, b, t):
    m, e = t
    if isinstance(a, str) or isinstance(b, str):
        return a == b
    if m == "exact":
        return a == b
    if m == "abs":
        return abs(a - b) <= e
    if m == "rel":
        return abs(a - b) <= e * max(abs(a), abs(b), 1e-12)
    return abs(a - b) <= max(e * max(abs(a), abs(b)), 1e-6)


summary, rows_out = {}, []
for spec in SPECS:
    N, status = {}, {}
    for I in IMPLS:
        p = f"{RUN}/{I}/results/{spec}.json"
        if os.path.exists(p):
            d = json.load(open(p))
            N[I] = normalize(I, d)
            status[I] = d.get("status")
        else:
            status[I] = "missing"
    keys = sorted(set().union(*[set(v) for v in N.values()]), key=str)
    cnt = {"keys": len(keys), "all_three_agree": 0, "pair_agree": 0, "no_pair": 0, "single_impl": 0}
    for k in keys:
        vals = {I: N[I].get(k) for I in N if N[I].get(k) is not None}
        t = tol(k)
        pairs = [(i, j) for i, j in itertools.combinations(sorted(vals), 2) if agree(vals[i], vals[j], t)]
        if len(vals) < 2:
            status_k = "single_impl"; agreed = None
        elif len(vals) == 3 and len(pairs) == 3:
            status_k = "all_three_agree"
        elif pairs:
            status_k = "pair_agree"
        else:
            status_k = "no_pair"
        cnt[status_k] += 1
        if pairs:
            i, j = pairs[0]
            agreed = vals[i] if isinstance(vals[i], str) else (vals[i] + vals[j]) / 2
            odd = "".join(sorted(set(vals) - set(pairs[0]) - (set(pairs[1]) if len(pairs) > 1 else set())))
        else:
            agreed, odd = None, ""
        rows_out.append({"spec": spec, "key": "|".join(map(str, k)), "status": status_k, "agreed": agreed, "outlier": odd if status_k == "pair_agree" else "",
                         **{f"value_{I}": vals.get(I) for I in IMPLS}, "tolerance": f"{t[0]}:{t[1]}"})
    summary[spec] = {"impl_status": status, **cnt}
os.makedirs(f"{RUN}/comparison", exist_ok=True)
json.dump(summary, open(f"{RUN}/comparison/implementation_agreement_summary.json", "w"), indent=1)
with open(f"{RUN}/comparison/implementation_agreement_all.csv", "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows_out[0].keys()))
    w.writeheader(); w.writerows(rows_out)
print(json.dumps(summary, indent=1))
