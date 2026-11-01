"""Compare implementations on keys and influence. usage: compare_impl.py <run_dir>. Uses no targets."""
import math, os, sys, collections
import pandas as pd
RUN = sys.argv[1]; IM = "ABC"; DATA = sys.argv[2]
_d1 = pd.read_csv(os.path.join(DATA, "dataset_1.csv"), dtype=str, keep_default_na=False)
FIRST = {u: str(i + 1) for i, u in reversed(list(enumerate(_d1["part_uid"])))}
def load(i):
    d = pd.read_csv(os.path.join(RUN, i, "results.csv"), dtype=str, keep_default_na=False)
    d["ds"] = d["dataset"].str.extract(r"(\d)")[0]
    d.loc[d["key"].str.match(r"^(D[1-4]|R[1-3]|N[1-4]|CHI4)\."), "method"] = "descriptive"
    d["k"] = d.ds + "|" + d.sample_level + "|" + d.composite_level + "|" + d.key.str.replace(r"\.\(?[Ii]ntercept\)?\.", ".intercept.", regex=True) + "|" + d.method
    d["v"] = pd.to_numeric(d.value, errors="coerce")
    return d.set_index("k")["v"]
R = {i: load(i) for i in IM}
idx = sorted(set().union(*[set(r.index) for r in R.values()]))
print("keys", len(idx), {i: len(set(idx) - set(R[i].index)) for i in IM}, "dups", {i: int(R[i].index.duplicated().sum()) for i in IM})
print("only in some", [k for k in idx if not all(k in R[i].index for i in IM)][:12])
fam = collections.defaultdict(lambda: [0, 0])
bad = []; boot_nonun = [0]
def tol(k):
    q = k.split("|")[3]; last = q.rsplit(".", 1)[-1]
    if last == "se_boot": return "rel", .10
    if last.startswith(("ci_bc", "ci_perc")): return "abs", .05 if not q.startswith("MED4") else .5
    if last == "boot_failed": return "abs", 1e9
    if q.startswith("LMM1"): return "rel", 1e-3
    if q.startswith(("L4", "CHI4")) or "logit" in k: return "rel", 1e-4
    return "rel", 1e-5
for k in idx:
    v = {i: float(R[i].get(k, float("nan"))) for i in IM}; f = k.split("|")[3].split(".")[0]
    t, e = tol(k); ok = 0
    def c(a, b):
        if math.isnan(a) and math.isnan(b): return True
        if math.isnan(a) or math.isnan(b): return False
        return abs(a - b) <= (e if t == "abs" else e * max(1, abs(a), abs(b)))
    n = sum([c(v["A"], v["B"]), c(v["A"], v["C"]), c(v["B"], v["C"])])
    fam[f][0] += 1; fam[f][1] += int(n == 3)
    if n < 3 and not k.split("|")[3].rsplit(".", 1)[-1].startswith(("ci_", "se_boot")): bad.append((k, v))
    if n < 3: boot_nonun[0] += int(k.split("|")[3].rsplit(".", 1)[-1].startswith(("ci_", "se_boot")))
print({f: tuple(x) for f, x in sorted(fam.items())}); print("non-unanimous, non-bootstrap", len(bad), "bootstrap beyond tolerance", boot_nonun[0])
for k, v in bad[:40]: print(k, {i: round(x, 6) for i, x in v.items()})
I = {}
for i in IM:
    d = pd.read_csv(os.path.join(RUN, i, "influence.csv"), dtype=str, keep_default_na=False); d["ds"] = d["dataset"].str.extract(r"(\d)")[0]
    if i == "A": d.loc[d.ds == "1", "deleted_unit"] = d.loc[d.ds == "1", "deleted_unit"].map(lambda u: FIRST.get(u, u))
    I[i] = d
print("influence rows", {i: len(x) for i, x in I.items()}, {i: x.status.value_counts().to_dict() for i, x in I.items()})
key = lambda d: d.ds + "|" + d.sample_level + "|" + d.estimand + "|" + d.deleted_unit
for i in IM: I[i]["k"] = key(I[i]); I[i]["e"] = pd.to_numeric(I[i].estimate, errors="coerce"); I[i]["pp"] = pd.to_numeric(I[i].p, errors="coerce")
m = I["A"].merge(I["B"], on="k", suffixes=("A", "B"), how="outer").merge(I["C"], on="k", how="outer")
print("influence merged", len(m), "unit id mismatch rows", int(m[["eA", "eB", "e"]].isna().any(axis=1).sum()))
for a, b in (("eA", "eB"), ("eA", "e"), ("pp" + "A", "pp" + "B"), ("ppA", "pp")):
    print(a, b, "max abs diff", float((m[a] - m[b]).abs().max()))
