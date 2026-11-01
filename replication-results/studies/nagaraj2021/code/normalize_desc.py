"""Put each implementation's descriptive side files into one long format:
spec_id, block (an01/an02/an09/an10), variable, group, statistic, value.
The manifest fixed the quantities but not the column layout, so each implementation needs its own reader."""
import os
import pandas as pd

AN01_NAMES = {"chg_": "change_", "change_": "change_"}


def _an01(d, impl):
    f = pd.read_csv(os.path.join(d, "an01_groups.csv"))
    if impl == "A":
        f = f.rename(columns={"value": "value"})
        f["statistic"] = f["statistic"].replace({"mean_treated": "treated_mean", "mean_control": "control_mean"})
        long = f[["spec_id", "variable", "statistic", "value"]]
    else:
        long = f.melt(id_vars=["spec_id", "variable"], var_name="statistic", value_name="value")
    long = long.copy()
    long["variable"] = long["variable"].str.replace(r"^(chg_|change_|d_|delta_)", "change_", regex=True)
    long["statistic"] = long["statistic"].replace({"diff": "difference", "diff_treated_minus_control": "difference", "p_equal": "p_equal_variance", "p_equal_var": "p_equal_variance", "n_t": "n_treated", "n_c": "n_control"})
    long["block"], long["group"] = "an01", ""
    return long


def _an02(d, impl):
    f = pd.read_csv(os.path.join(d, "an02_summary.csv"))
    if impl == "A":
        long = f[["spec_id", "variable", "statistic", "value"]].copy()
    else:
        long = f.melt(id_vars=["spec_id", "variable"], var_name="statistic", value_name="value")
    long["statistic"] = long["statistic"].replace({"std": "sd", "n": "n_nonmissing", "count": "n_nonmissing"})
    long["block"], long["group"] = "an02", ""
    return long


def _an09(d, impl):
    f = pd.read_csv(os.path.join(d, "an09_counts.csv"))
    if "group" in f.columns:
        f["treat"] = f["group"].map({"treated": 1, "control": 0, "all": "all", "total": "all"})
    f["variable"] = f["sample"].astype(str)
    f["group"] = f["treat"].astype(str)
    f["statistic"], f["value"], f["block"] = "n_counties", f["n_counties"], "an09"
    return f[["spec_id", "variable", "group", "statistic", "value", "block"]]


def _an10(d, impl):
    f = pd.read_csv(os.path.join(d, "an10_means.csv"))
    if impl == "A":
        f["statistic"] = f["statistic"].replace({"mean_log_y_plus_1": "mean_log", "mean_cumsum": "mean_cumulative", "mean_cumulative_sum": "mean_cumulative"})
        long = f[["spec_id", "outcome", "quarter", "treat", "statistic", "value"]].copy()
    else:
        f = f.rename(columns={"mean_log1p": "mean_log"})
        long = f.melt(id_vars=["spec_id", "outcome", "quarter", "treat"], value_vars=[c for c in ("mean_log", "mean_cumulative") if c in f.columns],
                      var_name="statistic", value_name="value")
    long["variable"] = long["outcome"] + "|" + long["quarter"].astype(str)
    long["group"] = long["treat"].astype(str)
    long["block"] = "an10"
    return long[["spec_id", "variable", "group", "statistic", "value", "block"]]


def load(d, impl):
    parts = [_an01(d, impl), _an02(d, impl), _an09(d, impl), _an10(d, impl)]
    out = pd.concat([p[["spec_id", "block", "variable", "group", "statistic", "value"]] for p in parts], ignore_index=True)
    out["group"] = out["group"].astype(str).replace({"1.0": "1", "0.0": "0", "nan": ""})
    out["value"] = pd.to_numeric(out["value"], errors="coerce")
    return out


if __name__ == "__main__":
    import json, sys
    dirs = dict(zip("ABC", sys.argv[1:4]))
    L = {k: load(v, k).set_index(["spec_id", "block", "variable", "group", "statistic"])["value"] for k, v in dirs.items()}
    keys = sorted(set().union(*[set(s.index) for s in L.values()]), key=str)
    rep = {"keys": len(keys)}
    for p, q in (("A", "B"), ("A", "C"), ("B", "C")):
        miss = [k for k in keys if k not in L[p].index or k not in L[q].index]
        both = [k for k in keys if k in L[p].index and k in L[q].index]
        a, b = L[p].loc[both], L[q].loc[both]
        diff = ((a - b).abs() > (1e-9 + 1e-6 * b.abs())) & ~(a.isna() & b.isna())
        rep[p + q] = {"compared": len(both), "differ": int(diff.sum()), "missing_in_one": len(miss),
                      "examples_differ": [str(k) for k in diff[diff].index[:6]], "examples_missing": [str(k) for k in miss[:6]]}
    print(json.dumps(rep, indent=1))
    if len(sys.argv) > 4:
        json.dump(rep, open(sys.argv[4], "w"), indent=1)
