"""Samples, model fitting, nested tests, influence diagnostic and output rows.

Sections 3, 5, 6, 7 and 8 of the specification, as amended by v1.1
(A1 HC3 leverage-one rows, A5 column dropping and nested-test df, A6 failure
records, A8 validity-based reference sample, A10 influence refits).
"""
from __future__ import annotations

import traceback

import numpy as np
import pandas as pd

from . import coding as C
from .regression import FitError, drop_collinear_dummies, fit_linear, nested_f

INTERACTIONS = {
    "TRAIN_x_STAFF": ("TRAIN", "STAFF"),
    "GRIEV_x_INCENT": ("GRIEV", "INCENT"),
    "ILM_x_DECENT": ("ILM", "DECENT"),
    "VHIER_x_DECENT": ("VHIER", "DECENT"),
}
A_TERMS = ["STAFF", "TRAIN", "INCENT", "GRIEV", "DECENT", "ILM"]
B_TERMS = ["STAFF", "TRAIN", "INCENT", "GRIEV", "DECENT", "VHIER"]
A_INT = ["TRAIN_x_STAFF", "GRIEV_x_INCENT", "ILM_x_DECENT"]
B_INT = ["TRAIN_x_STAFF", "GRIEV_x_INCENT", "VHIER_x_DECENT"]


def model_definitions(family):
    """List of (model_id, hrm_terms, interaction_terms) for a family."""
    if family == "org":
        p, single, a, b, ai, bi = "org", "org_M1_", "org_M2", "org_M3", "org_M4", "org_M5"
    elif family == "mkt":
        p, single, a, b, ai, bi = "mkt", "mkt_M6_", "mkt_M7", "mkt_M8", "mkt_M9", "mkt_M10"
    else:
        raise ValueError(family)
    defs = [(f"{p}_base", [], [])]
    for t in C.HRM_TERMS:
        defs.append((f"{single}{t}", [t], []))
    defs += [(a, A_TERMS, []), (b, B_TERMS, []), (ai, A_TERMS, A_INT), (bi, B_TERMS, B_INT)]
    return defs


NESTED_TESTS = {
    "org": [("org_M2", "org_base"), ("org_M3", "org_base"), ("org_M4", "org_M2"), ("org_M5", "org_M3")],
    "mkt": [("mkt_M7", "mkt_base"), ("mkt_M8", "mkt_base"), ("mkt_M9", "mkt_M7"), ("mkt_M10", "mkt_M8")],
}
INFLUENCE_MODELS = {"org": ["org_M2", "org_M3", "org_M4", "org_M5"],
                    "mkt": ["mkt_M7", "mkt_M8", "mkt_M9", "mkt_M10"]}
FAMILY_OUTCOME = {"org": "POP", "mkt": "PMP"}
FAMILY_CONTROLS = {"org": C.ORG_CONTROLS, "mkt": C.MKT_CONTROLS}


# ----------------------------------------------------------------------------
# samples
# ----------------------------------------------------------------------------
def family_filter(base, family, settings):
    """Row filter for the family (before completeness)."""
    if family == "org":
        return pd.Series(True, index=base.index)
    m = base["V8"] == 1
    if settings["market_sample"] == "L1":
        m &= base["V9"] == 4
    elif settings["market_sample"] != "L0":
        raise ValueError(settings["market_sample"])
    if settings["market_requires_pop"] == "L1":
        m &= base["POP"].notna()
    elif settings["market_requires_pop"] != "L0":
        raise ValueError(settings["market_requires_pop"])
    return m


def required_vars(family, hrm_terms, settings, common=True):
    """Variables that must be valid for a row to enter a sample."""
    req = [FAMILY_OUTCOME[family]]
    req += list(C.HRM_TERMS) if common else list(hrm_terms)
    req += FAMILY_CONTROLS[family] + ["IND_GROUP"]
    if settings["weights"] == "L1":
        req.append("WEIGHT")
    return req


def complete_mask(frame, family, settings, hrm_terms=None, common=True):
    req = required_vars(family, hrm_terms or [], settings, common=common)
    return frame[req].notna().all(axis=1)


def build_family_frames(raw, meta, crosswalk, settings, check=None):
    """Return dict family -> dict(frame, sample(common complete-case mask)), plus z_info.

    z_reference L0/L3: items standardized over the record frame; STAFF/TRAIN are
    the averages of those scores.
    z_reference L1/L2 (amendment A8): the reference sample is the family's
    complete-case sample, determined once from *validity* (outcome, controls,
    industry group, and each HRM index, where the STAFF/TRAIN index is valid iff
    the item_rule is satisfied by the valid transformed items). Items are then
    standardized within that sample and membership is not recomputed. Rows
    outside the reference sample keep the L0 scores.
    """
    raw = C.apply_records(raw, settings)
    base, staff_items, train_items = C.build_base_frame(raw, meta, crosswalk, settings, check=check)
    rule = settings["item_rule"]
    zref = settings["z_reference"]
    if zref not in ("L0", "L1", "L2", "L3"):
        raise ValueError(zref)
    ddof0 = 0 if zref == "L3" else 1
    staff0, zs0, info_s0 = C.standardize_and_index(staff_items, rule, None, ddof0)
    train0, zt0, info_t0 = C.standardize_and_index(train_items, rule, None, ddof0)
    base["STAFF"] = staff0
    base["TRAIN"] = train0
    zinfo = {"L0": {"STAFF": info_s0, "TRAIN": info_t0}}
    frames = {}
    samples = {}
    if zref in ("L0", "L3"):
        for fam in ("org", "mkt"):
            fr = base[family_filter(base, fam, settings)].copy()
            frames[fam] = fr
            samples[fam] = complete_mask(fr, fam, settings)
    else:
        # membership from validity only (A8)
        staff_valid = C.index_of(staff_items, rule).notna()
        train_valid = C.index_of(train_items, rule).notna()
        base_v = base.copy()
        base_v["STAFF"] = pd.Series(0.0, index=base.index).where(staff_valid)
        base_v["TRAIN"] = pd.Series(0.0, index=base.index).where(train_valid)
        for fam in ("org", "mkt"):
            filt = family_filter(base, fam, settings)
            frames[fam] = base[filt].copy()
            samples[fam] = complete_mask(base_v[filt], fam, settings)

        def ref_from(fam):
            idx = frames[fam].index[samples[fam]]
            return pd.Series(base.index.isin(idx), index=base.index)

        ref_org = ref_from("org")
        staff_o, _, info_so = C.standardize_and_index(staff_items, rule, ref_org, 1, base_z=zs0)
        train_o, _, info_to = C.standardize_and_index(train_items, rule, ref_org, 1, base_z=zt0)
        zinfo["org"] = {"STAFF": info_so, "TRAIN": info_to}
        frames["org"]["STAFF"] = staff_o.loc[frames["org"].index]
        frames["org"]["TRAIN"] = train_o.loc[frames["org"].index]
        if zref == "L1":
            frames["mkt"]["STAFF"] = staff_o.loc[frames["mkt"].index]
            frames["mkt"]["TRAIN"] = train_o.loc[frames["mkt"].index]
            zinfo["mkt"] = zinfo["org"]
        else:
            ref_mkt = ref_from("mkt")
            staff_m, _, info_sm = C.standardize_and_index(staff_items, rule, ref_mkt, 1, base_z=zs0)
            train_m, _, info_tm = C.standardize_and_index(train_items, rule, ref_mkt, 1, base_z=zt0)
            zinfo["mkt"] = {"STAFF": info_sm, "TRAIN": info_tm}
            frames["mkt"]["STAFF"] = staff_m.loc[frames["mkt"].index]
            frames["mkt"]["TRAIN"] = train_m.loc[frames["mkt"].index]
        # membership is fixed; a standardized value undefined inside the sample
        # (constant item within the reference) is left as missing and makes the
        # affected model fail with "non-finite values", never a changed sample.
    out = {}
    for fam in ("org", "mkt"):
        out[fam] = {"frame": frames[fam], "sample": samples[fam]}
    out["z_info"] = zinfo
    return out


# ----------------------------------------------------------------------------
# design construction
# ----------------------------------------------------------------------------
def build_design(frame, rows, family, hrm_terms, int_terms, settings, reference_group):
    """Design DataFrame on `rows` (index labels): intercept, HRM, interactions, controls, dummies.

    Returns (X_df, y, w, dummy_names, center_means).
    """
    sub = frame.loc[rows]
    X = pd.DataFrame(index=sub.index)
    X["(Intercept)"] = 1.0
    for t in hrm_terms:
        X[t] = sub[t].astype(float)
    center_means = {}
    for it in int_terms:
        a, b = INTERACTIONS[it]
        xa, xb = sub[a].astype(float), sub[b].astype(float)
        if settings["centering"] == "L1":
            ma, mb = float(xa.mean()), float(xb.mean())
            center_means[a] = ma
            center_means[b] = mb
            X[it] = (xa - ma) * (xb - mb)
        elif settings["centering"] == "L0":
            X[it] = xa * xb
        else:
            raise ValueError(settings["centering"])
    for cvar in FAMILY_CONTROLS[family]:
        X[cvar] = sub[cvar].astype(float)
    dummies = C.industry_dummies(sub["IND_GROUP"], reference_group)
    for col in dummies.columns:
        X[col] = dummies[col]
    y = sub[FAMILY_OUTCOME[family]].astype(float)
    w = sub["WEIGHT"].astype(float) if settings["weights"] == "L1" else None
    return X, y, w, list(dummies.columns), center_means


def resolve_dummies(X_df, dummy_names):
    """Drop all-zero/collinear dummies (A5: before any df check). Returns (Xk, names, dropped)."""
    return drop_collinear_dummies(X_df.values, list(X_df.columns), dummy_names)


def fit_design(X_df, y, w, dummy_names):
    """Resolve dummy collinearity, then fit. Returns (fit, names, dropped)."""
    Xk, names, dropped = resolve_dummies(X_df, dummy_names)
    fit = fit_linear(Xk, y.values, names, None if w is None else w.values)
    return fit, names, dropped


def dropped_str(dropped):
    return ";".join(f"{nm}({why})" for nm, why in dropped) if dropped else "NA"


# ----------------------------------------------------------------------------
# a whole specification
# ----------------------------------------------------------------------------
class SpecResult:
    def __init__(self, spec_id):
        self.spec_id = spec_id
        self.coefficients = []
        self.model_stats = []
        self.nested = []
        self.samples = []
        self.failures = []
        self.models = {}  # model_id -> dict with design etc. (for influence); fit is None when failed
        self.notes = []
        self.z_info = {}


def _coef_rows(spec_id, family, model_id, fit):
    rows = []
    for j, nm in enumerate(fit["names"]):
        rows.append({
            "spec_id": spec_id, "family": family, "model_id": model_id, "term": nm,
            "estimate": fit["beta"][j], "se": fit["se"][j], "t": fit["t"][j], "df": fit["df"],
            "p_two": fit["p_two"][j], "p_upper": fit["p_upper"][j], "p_lower": fit["p_lower"][j],
            "se_hc3": fit["se_hc3"][j], "t_hc3": fit["t_hc3"][j], "p_two_hc3": fit["p_two_hc3"][j],
            "p_upper_hc3": fit["p_upper_hc3"][j], "p_lower_hc3": fit["p_lower_hc3"][j],
        })
    return rows


def _stat_row(spec_id, family, model_id, status, error="NA", fit=None, n_ind=None, dropped=None, n=None, k=None):
    """One model_stats row. dropped_columns is recorded even when the fit failed (A6).

    Checker item 3 / spec §6: when dummy resolution has succeeded the number of
    parameters k and the number of industry dummies are known even if the
    subsequent fit fails (for example because no positive residual df remains
    after the permitted drops). Pass them via `k` and `n_ind` so the failure row
    reports them instead of NA.
    """
    row = {"spec_id": spec_id, "family": family, "model_id": model_id, "status": status, "error": error,
           "n": np.nan, "k": np.nan, "n_industry_dummies": np.nan, "dropped_columns": dropped_str(dropped),
           "r2": np.nan, "adj_r2": np.nan, "f": np.nan, "f_df1": np.nan, "f_df2": np.nan, "f_p": np.nan,
           "n_leverage_one": np.nan}
    if n is not None:
        row["n"] = n
    if k is not None:
        row["k"] = k
    if n_ind is not None:
        row["n_industry_dummies"] = n_ind
    if fit is not None:
        row.update({"n": fit["n"], "k": fit["k"], "n_industry_dummies": n_ind,
                    "r2": fit["r2"], "adj_r2": fit["adj_r2"], "f": fit["f"], "f_df1": fit["f_df1"],
                    "f_df2": fit["f_df2"], "f_p": fit["f_p"], "n_leverage_one": fit["n_leverage_one"]})
    return row


def _empty_nested_row(spec_id, fam, full, restricted):
    return {"spec_id": spec_id, "family": fam, "test_id": f"{full}_vs_{restricted}", "full_model": full,
            "restricted_model": restricted, "n": np.nan, "delta_r2": np.nan, "f": np.nan,
            "df1": np.nan, "df2": np.nan, "p": np.nan}


def run_spec(spec, raw, meta, crosswalk):
    spec_id = spec["spec_id"]
    settings = spec["settings"]
    check = spec.get("check")
    res = SpecResult(spec_id)
    try:
        fams = build_family_frames(raw, meta, crosswalk, settings, check=check)
    except Exception as exc:  # noqa: BLE001
        msg = f"frame construction failed: {exc!r}"
        res.failures.append({"spec_id": spec_id, "stage": "frame", "error": msg, "traceback": traceback.format_exc()})
        for fam in ("org", "mkt"):
            for model_id, _, _ in model_definitions(fam):
                res.model_stats.append(_stat_row(spec_id, fam, model_id, "failed", msg))
                res.models[model_id] = None
            for full, restricted in NESTED_TESTS[fam]:
                res.nested.append(_empty_nested_row(spec_id, fam, full, restricted))
                res.failures.append({"spec_id": spec_id, "stage": f"{full}_vs_{restricted}", "error": msg})
        return res
    res.notes.extend(fams["z_info"].get("notes", []))
    res.z_info = fams["z_info"]
    scope = settings["case_scope"]
    if scope not in ("L0", "L1"):
        raise ValueError(scope)
    for fam in ("org", "mkt"):
        frame = fams[fam]["frame"]
        common = fams[fam]["sample"]
        common_rows = frame.index[common]
        if scope == "L0":
            ref_group = C.choose_reference_group(frame.loc[common_rows, "IND_GROUP"], check=check)
            for v1 in frame.loc[common_rows, "V1"]:
                res.samples.append({"spec_id": spec_id, "family": fam, "model_id": "ALL", "V1": v1})
        for model_id, hrm, ints in model_definitions(fam):
            if scope == "L0":
                rows = common_rows
                rg = ref_group
            else:
                mask = complete_mask(frame, fam, settings, hrm_terms=hrm, common=False)
                rows = frame.index[mask]
                rg = C.choose_reference_group(frame.loc[rows, "IND_GROUP"], check=check)
                for v1 in frame.loc[rows, "V1"]:
                    res.samples.append({"spec_id": spec_id, "family": fam, "model_id": model_id, "V1": v1})
            dropped = []
            names = None  # set once dummy resolution succeeds; used to report k on failure
            model = {"family": fam, "fit": None, "hrm": hrm, "ints": ints, "rows": rows,
                     "V1": frame.loc[rows, "V1"], "reference_group": rg, "error": None}
            try:
                if len(rows) == 0:
                    raise FitError("empty estimation sample")
                X, y, w, dnames, cmeans = build_design(frame, rows, fam, hrm, ints, settings, rg)
                model.update({"X": X, "y": y, "w": w, "dummies": dnames, "center_means": cmeans})
                Xk, names, dropped = resolve_dummies(X, dnames)
                model["dropped"] = dropped
                fit = fit_linear(Xk, y.values, names, None if w is None else w.values)
                n_ind = sum(1 for nm in names if nm.startswith("IND_"))
                res.coefficients.extend(_coef_rows(spec_id, fam, model_id, fit))
                res.model_stats.append(_stat_row(spec_id, fam, model_id, "ok", fit=fit, n_ind=n_ind, dropped=dropped))
                model.update({"fit": fit, "names": names})
            except Exception as exc:  # noqa: BLE001
                msg = f"{type(exc).__name__}: {exc}"
                model["error"] = msg
                res.failures.append({"spec_id": spec_id, "stage": model_id, "error": msg,
                                     "dropped_columns": dropped_str(dropped)})
                # Spec §6 / checker item 3: if dummy resolution succeeded the final
                # column set is known, so report k and the number of industry
                # dummies even though the fit itself failed.
                k_fail = None if names is None else len(names)
                n_ind_fail = None if names is None else sum(1 for nm in names if nm.startswith("IND_"))
                res.model_stats.append(_stat_row(spec_id, fam, model_id, "failed", msg, dropped=dropped,
                                                 n=len(rows), k=k_fail, n_ind=n_ind_fail))
            res.models[model_id] = model
        for full, restricted in NESTED_TESTS[fam]:
            res.nested.append(_nested_row(res, spec_id, fam, full, restricted))
    return res


def _nested_row(res, spec_id, fam, full, restricted):
    """Nested F test row. Failures (full model failed, restricted refit failed, rank increase
    different from the number of added terms) leave NA in the row and are listed in failures (A5, A6)."""
    row = _empty_nested_row(spec_id, fam, full, restricted)
    mf = res.models.get(full)
    if mf is None or mf.get("fit") is None:
        reason = "full model not available" + (f" ({mf['error']})" if mf and mf.get("error") else "")
        res.failures.append({"spec_id": spec_id, "stage": row["test_id"], "error": reason})
        return row
    r_def = {m: (h, i) for m, h, i in model_definitions(fam)}[restricted]
    f_def = (mf["hrm"], mf["ints"])
    added = [t for t in f_def[0] + f_def[1] if t not in r_def[0] + r_def[1]]
    row["n"] = mf["fit"]["n"]
    dropped_r = []
    try:
        Xr = mf["X"].drop(columns=added)
        Xk, names_r, dropped_r = resolve_dummies(Xr, mf["dummies"])
        fit_r = fit_linear(Xk, mf["y"].values, names_r, None if mf["w"] is None else mf["w"].values)
        d_r2, f, df1, df2, p = nested_f(mf["fit"], fit_r, len(added))
        row.update({"delta_r2": d_r2, "f": f, "df1": df1, "df2": df2, "p": p})
    except Exception as exc:  # noqa: BLE001
        res.failures.append({"spec_id": spec_id, "stage": row["test_id"],
                             "error": f"restricted model {restricted} on the rows of {full}: {type(exc).__name__}: {exc}",
                             "restricted_dropped_columns": dropped_str(dropped_r)})
    return row


# ----------------------------------------------------------------------------
# influence (leave-one-out) for the origin specification
# ----------------------------------------------------------------------------
def _failed_rows(model_id, v1, terms, msg):
    return [{"model_id": model_id, "deleted_V1": v1, "term": t, "estimate": np.nan, "se": np.nan,
             "p_upper": np.nan, "p_two": np.nan, "status": "failed", "note": msg} for t in terms]


def _failed_record_row(model_id, v1, msg):
    """A single failed influence row for one estimation-sample record (A6).

    Used when the original model itself failed: the spec asks for one row per
    record (not one per term), with status failed and the reason. term is NA.
    """
    return {"model_id": model_id, "deleted_V1": v1, "term": "NA", "estimate": np.nan, "se": np.nan,
            "p_upper": np.nan, "p_two": np.nan, "status": "failed", "note": msg}


def influence_rows(model_id, model, spec_id="O"):
    """Leave-one-out refits. All variable values (X, y, w) are held fixed.

    Each deletion starts from the columns kept in the original fit; all-zero and
    collinear industry dummies are resolved before the residual-df check (A10)
    and noted. Returns (rows, failures): one row per deletion and term, and one
    failures entry per failed deletion (A6/A10). If the original model failed,
    every record of its estimation sample gets failed rows with the reason.
    """
    rows = []
    failures = []
    terms = list(model["hrm"]) + list(model["ints"])
    v1s = list(model["V1"].values)
    if model.get("fit") is None:
        msg = "original model failed: " + str(model.get("error") or "not estimated")
        failures.append({"spec_id": spec_id, "stage": f"influence:{model_id}", "error": msg})
        # Amendment A6 / checker item 2: one influence row per estimation-sample
        # record (not one per term), status failed, with the reason. When the
        # estimation sample is empty there are no records, so emit no rows.
        for v1 in v1s:
            rows.append(_failed_record_row(model_id, v1, msg))
        return rows, failures
    cols = list(model.get("names") or model["X"].columns)
    X = model["X"][cols]
    dnames = [d for d in model["dummies"] if d in cols]
    Xv = X.values
    yv = model["y"].values
    wv = None if model["w"] is None else model["w"].values
    n = Xv.shape[0]
    for i in range(n):
        keep = np.ones(n, dtype=bool)
        keep[i] = False
        Xi = Xv[keep]
        note_parts = []
        try:
            Xk, names_k, dropped_k = drop_collinear_dummies(Xi, cols, dnames)
            zero_d = [nm for nm, why in dropped_k if why == "all_zero"]
            col_d = [nm for nm, why in dropped_k if why == "collinear"]
            if zero_d:
                note_parts.append("dropped all-zero dummies: " + ",".join(zero_d))
            if col_d:
                note_parts.append("dropped collinear dummies: " + ",".join(col_d))
            fit = fit_linear(Xk, yv[keep], names_k, None if wv is None else wv[keep])
            note = "; ".join(note_parts) if note_parts else "NA"
            for t in terms:
                j = fit["names"].index(t)
                rows.append({"model_id": model_id, "deleted_V1": v1s[i], "term": t, "estimate": fit["beta"][j],
                             "se": fit["se"][j], "p_upper": fit["p_upper"][j], "p_two": fit["p_two"][j],
                             "status": "ok", "note": note})
        except Exception as exc:  # noqa: BLE001
            msg = f"{type(exc).__name__}: {exc}"
            if note_parts:
                msg = "; ".join(note_parts) + "; " + msg
            rows.extend(_failed_rows(model_id, v1s[i], terms, msg))
            failures.append({"spec_id": spec_id, "stage": f"influence:{model_id}", "deleted_V1": v1s[i], "error": msg})
    return rows, failures


def run_influence(origin_result):
    rows = []
    failures = []
    for fam in ("org", "mkt"):
        for model_id in INFLUENCE_MODELS[fam]:
            model = origin_result.models.get(model_id)
            if model is None:
                hrm, ints = {m: (h, i) for m, h, i in model_definitions(fam)}[model_id]
                model = {"family": fam, "fit": None, "hrm": hrm, "ints": ints, "V1": pd.Series([], dtype=float),
                         "error": "model not estimated in the origin specification"}
            r, f = influence_rows(model_id, model, spec_id=origin_result.spec_id)
            rows.extend(r)
            failures.extend(f)
    return rows, failures
