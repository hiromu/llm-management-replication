#!/usr/bin/env python
"""Frozen manifest P-R7M2 v1. Run --help for controlled-run options.

All statistical routines and synthetic validation live in this one script.
No network access or package installation is performed.
"""
from __future__ import annotations

import os
for _key in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
    os.environ.setdefault(_key, "1")

import argparse
import csv
import json
import math
from pathlib import Path
import time
import traceback
from dataclasses import dataclass

import numpy as np
import pandas as pd
import pyarrow.parquet as pq
from scipy import linalg, optimize, special, stats

ROOT = Path(__file__).resolve().parent
POW_COLS = ["record_seq", "SERIAL_NO", "GRADE_ALPHA", "GRADE_CODE", "SERVICE_CODE",
            "ARM_SVC_ALPHA", "ARM_SVC_CODE", "DATE_REPORTED_MONTH", "DATE_REPORTED_YEAR",
            "TYPE_ORG", "PARENT_UNIT_NUM", "PARENT_UNIT_TYPE", "STA", "DET_POWER", "CAMP"]
ENL_FIELDS = ["CARD_NUM", "HEIGHT", "ERC_HEIGHT", "YR_BIRTH", "ERC_YR_BIRTH",
              "EDUCATION", "ERC_EDUCATION", "MARITAL_STATUS", "ERC_MARITAL_STATUS"]
RESULT_COLS = ("spec_id model_id family term coef coef_se me me_se me_p "
               "me_se_campcluster me_p_campcluster n n_clusters dropped_rows_pp "
               "dropped_camps_pp ll ll0 pseudo_r2 converged status error").split()
ROC_COLS = ("spec_id model_id family omitted_term comparator_id auc_full auc_reduced "
            "difference z p n status error").split()
INFLUENCE_COLS = "spec_id model_id deleted_camp me me_p n status error".split()
BINARY = {"japan", "dependents", "officer"}
HIERARCHIES = ["steepness", "sameness"]
GROUP_METRICS = ["n_g", "steepness", "sameness", "ratio_sameness", "absolute_sameness",
                 "distinct_ranks", "sum_ranks", "administrative_intensity"]


def clean(s):
    return s.fillna("").astype(str).str.replace("\x00", "", regex=False).str.strip()


def read_codes(path):
    d = pd.read_csv(path, dtype=str, keep_default_na=False)
    for c in d:
        d[c] = clean(d[c])
    return d


def load_inputs(data, log):
    """Scan only 11 enlistment columns in bounded batches; retain matching serials."""
    start = time.monotonic()
    pow_ = pd.read_parquet(data / "pow.parquet", columns=POW_COLS)
    for c in POW_COLS[1:]:
        pow_[c] = clean(pow_[c])
    # Literal exact matching includes the empty string; duplicate policy still applies.
    serials = set(pow_["SERIAL_NO"])
    kept, scanned = [], 0
    for batch in pq.ParquetFile(data / "enl.parquet").iter_batches(
            batch_size=131072, columns=["record_seq", "SER_NUM"] + ENL_FIELDS):
        d = batch.to_pandas()
        d["SER_NUM"] = clean(d["SER_NUM"].str.replace("#", " ", regex=False))
        d = d.loc[d.SER_NUM.isin(serials)].copy()
        for c in ENL_FIELDS:
            d[c] = clean(d[c])
        kept.append(d)
        scanned += batch.num_rows
    enl = pd.concat(kept, ignore_index=True)
    log(f"Read D0={len(pow_)}; scanned enlistments={scanned}; retained={len(enl)}; "
        f"distinct matching serials={enl.SER_NUM.nunique()}; seconds={time.monotonic()-start:.2f}")
    return pow_, enl


def link_records(pow_, enl, rule):
    if rule == "unmatched":
        e = enl.loc[~enl.SER_NUM.duplicated(keep=False)].set_index("SER_NUM")
    elif rule == "first":
        e = enl.sort_values("record_seq", kind="stable").drop_duplicates("SER_NUM").set_index("SER_NUM")
    elif rule == "combine":
        # Aggregate the raw fields first, then interpret the card layout.
        values = enl[ENL_FIELDS].mask(enl[ENL_FIELDS].eq(""))
        values["SER_NUM"] = enl.SER_NUM
        g = values.groupby("SER_NUM", sort=False)
        e = g.first().where(g.nunique(dropna=True).eq(1)).fillna("")
    else:
        raise ValueError(f"Unknown dup_serial {rule}")
    linked = e[ENL_FIELDS].reindex(pow_.SERIAL_NO).set_axis(pow_.index)
    linked["linked"] = pow_.SERIAL_NO.isin(e.index).to_numpy()
    return linked


def assign_rank(d, data, rule):
    a = read_codes(data / "rank_map_grade_alpha.csv")
    # 'Removing spaces from both sides' means remove spaces in both compared labels.
    a["grade_alpha"] = a.grade_alpha.str.replace(" ", "", regex=False)
    a = a.drop_duplicates("grade_alpha", keep="first").set_index("grade_alpha")
    c = read_codes(data / "rank_map_grade_code.csv").drop_duplicates("grade_code").set_index("grade_code")
    navy = d.SERVICE_CODE.eq("2")
    officer = d.SERIAL_NO.str[:1].isin(["O", "T"])
    label = d.GRADE_ALPHA.str.replace(" ", "", regex=False)
    prefix = "rank_strict_" if rule == "strict" else "rank_origin_"
    ar = label.map(pd.to_numeric(a[prefix + "service_not_navy"], errors="coerce"))
    ar.loc[navy] = label.loc[navy].map(pd.to_numeric(a[prefix + "navy"], errors="coerce"))
    if rule == "strict":
        return ar
    cr = pd.Series(np.nan, index=d.index)
    for nv in (False, True):
        for of in (False, True):
            mask = navy.eq(nv) & officer.eq(of)
            col = "rank_" + ("officer" if of else "enlisted") + ("_navy" if nv else "_not_navy")
            cr.loc[mask] = d.loc[mask, "GRADE_CODE"].map(pd.to_numeric(c[col], errors="coerce"))
    return cr.fillna(ar) if rule == "grade_code" else ar.fillna(cr)


def distance_values(d, data, rule):
    c = read_codes(data / "camp_location_crosswalk.csv")
    # IDs include suffixes such as 359a/359b; lexical ordering within a camp
    # preserves those identifiers and selects the first eligible entry.
    c["entry_order"] = c.entry_id
    c = c.loc[c.confidence.isin(["exact", "approximate"])].sort_values(
        "entry_order", kind="stable").drop_duplicates("camp_code").set_index("camp_code")
    lat = pd.to_numeric(c.latitude, errors="coerce")
    lon = pd.to_numeric(c.longitude, errors="coerce")
    if rule == "nara_degree":
        degrees = c.nara_degree_coords_text.str.extract(r"^(\d+)\s*-\s*(\d+)$")
        present = c.nara_degree_coords_text.ne("")
        lat.loc[present] = pd.to_numeric(degrees.loc[present, 0], errors="coerce")
        lon.loc[present] = pd.to_numeric(degrees.loc[present, 1], errors="coerce")
    lat1, lon1 = np.deg2rad(d.CAMP.map(lat)), np.deg2rad(d.CAMP.map(lon))
    jp = d.DET_POWER.eq("2")
    lat2 = np.deg2rad(np.where(jp, 35.6762, 52.5200))
    lon2 = np.deg2rad(np.where(jp, 139.6503, 13.4050))
    a = np.sin((lat1-lat2)/2)**2 + np.cos(lat1)*np.cos(lat2)*np.sin((lon1-lon2)/2)**2
    km = 12742 * np.arcsin(np.sqrt(np.clip(a, 0, 1)))
    place = d.CAMP.map(c.identified_place_name)
    km.loc[(~jp & place.eq("Berlin")) | (jp & place.eq("Tokyo"))] = 1
    return np.log(km.where(km.gt(0))) / 10


def construct_records(raw, linked, data, p):
    d = raw.copy()
    d["rank"] = assign_rank(d, data, p["rank_rule"])
    d["camp"] = d.CAMP
    d["valid_camp"] = d.CAMP.str.len().eq(3) & d.CAMP.ne("000")
    if p["camp_valid"] == "defined":
        defined = read_codes(ROOT / "code_lists" / "pow_CAMP_cl1277.csv")["Code"]
        d["valid_camp"] &= d.CAMP.isin(defined)
    d["valid_month"] = (d.DATE_REPORTED_YEAR.isin(list("123456")) &
                        d.DATE_REPORTED_MONTH.isin([f"{i:02}" for i in range(1, 13)]))
    d["cap"] = d.CAMP + "|194" + d.DATE_REPORTED_YEAR + "|" + d.DATE_REPORTED_MONTH
    d["unit"] = d.TYPE_ORG + d.PARENT_UNIT_NUM + d.PARENT_UNIT_TYPE
    d.loc[d.unit.eq(""), "unit"] = None
    d["survival"] = d.STA.isin(["7", "8", "9"]).astype(float)
    d["executed"] = d.STA.eq("4")
    d["japan"] = d.DET_POWER.eq("2").astype(float)
    d["officer"] = d["rank"].ge(5).astype(float).where(d["rank"].notna())
    year = pd.to_numeric(d.DATE_REPORTED_YEAR, errors="coerce") + 1940
    month = pd.to_numeric(d.DATE_REPORTED_MONTH, errors="coerce")
    d["length"] = (((1945-year)*12 + np.where(d.japan.eq(1), 9, 5)-month)/10).where(d.valid_month)
    d["distance"] = distance_values(d, data, p["coords"])
    erc = linked.CARD_NUM.eq("3")
    def field(name):
        return linked[name].where(~erc, linked["ERC_" + name]).fillna("")
    htext = field("HEIGHT")
    h = pd.to_numeric(htext.where(htext.str.fullmatch(r"[0-9]+")), errors="coerce")
    d["height"] = h.where(h.between(48, 84))/10 if p["height_rule"] == "range" else np.nan
    btext = field("YR_BIRTH")
    birth = pd.to_numeric(btext.where(btext.str.fullmatch(r"[0-9]{2}")), errors="coerce")
    age = 45-birth
    d["age"] = (age.where(age.between(15, 70)) if p["age_rule"] == "range" else age)/100
    educ_map = {str(i): i for i in range(9)}
    educ_map["9"] = np.nan if p["educ_postgrad"] == "missing" else p["educ_postgrad"]
    d["education"] = field("EDUCATION").map(educ_map)/10
    marital = {"1": 1, "3": 1, "4": 1, "5": 1, "6": 0, "7": 0, "8": 0, "9": 0,
               "2": np.nan if p["married"] == "missing" else p["married"]}
    d["dependents"] = field("MARITAL_STATUS").map(marital)
    d["linked"] = linked.linked
    d["in_D"] = (~d.SERVICE_CODE.isin(p["svc_exclude"]) & d.DET_POWER.isin(["1", "2"]) &
                 d.STA.isin(["4", "5", "7", "8", "9"]))
    return d


def hierarchy_from_counts(counts, reference, constant):
    """Vectorized ordered Gini, exactly equivalent to sorting all individual ranks."""
    counts = np.asarray(counts, dtype=float)
    n = counts.sum(axis=1)
    ranks = np.arange(1, 10, dtype=float)
    total = counts @ ranks
    before = np.cumsum(counts, axis=1) - counts
    weighted = (counts*(n[:, None]+1-before) - counts*(counts+1)/2) @ ranks
    with np.errstate(divide="ignore", invalid="ignore"):
        f = counts/n[:, None]
        steep = 1 + 1/n - 2*weighted/(n*total)
        c = 1.319 if constant == "fixed" else (1-reference[8])**2 + np.sum(reference[:8]**2)
        same = 1 - np.sum((f-reference)**2, axis=1)/c
        # Undefined ratios (including 0/0) remain missing; no pseudocounts.
        ratio = 1 - np.sum((f/reference-1)**2, axis=1)/10000
        absolute = 1 - np.sum(np.abs(f-reference), axis=1)/(2*(1-reference[8]))
        admin = 100*counts[:, 1:].sum(axis=1)/n
    result = np.column_stack([n, steep, same, ratio, absolute, (counts > 0).sum(axis=1), total, admin])
    result[n == 0] = np.nan
    result[~np.isfinite(result)] = np.nan
    return result


def group_table(members, keys, reference, constant):
    if members.empty:
        # An empty MultiIndex preserves join semantics for friends groups.
        idx = pd.MultiIndex.from_arrays([[] for _ in keys], names=keys) if len(keys) > 1 else pd.Index([], name=keys[0])
        return pd.DataFrame(index=idx, columns=GROUP_METRICS, dtype=float)
    counts = members.groupby(keys + ["rank"], sort=False, dropna=True).size().unstack("rank", fill_value=0)
    counts = counts.reindex(columns=range(1, 10), fill_value=0)
    return pd.DataFrame(hierarchy_from_counts(counts, reference, constant), index=counts.index, columns=GROUP_METRICS)


def construct_groups(d, p, group, friends=False):
    mask = d.in_D & d.valid_camp
    if group == "cap" or p["sample_common"]:
        mask &= d.valid_month
    sample = d.loc[mask].copy()
    reference_rows = d.loc[d.in_D] if p["pop_fractions"] == "descriptive" else sample
    counts = reference_rows["rank"].value_counts().reindex(range(1, 10), fill_value=0).to_numpy(float)
    reference = counts / counts.sum() if counts.sum() else np.full(9, np.nan)
    if p["group_members"] == "file":
        member_mask = d.valid_camp & (d.valid_month if group == "cap" else True)
    else:
        member_mask = mask.copy()
        if p["group_members"] == "complete":
            member_mask &= d[["height", "age", "education", "dependents"]].notna().all(axis=1)
    member_mask &= d["rank"].notna()
    members = d.loc[member_mask]
    table = group_table(members, [group], reference, p["sameness_constant"])
    sample = sample.join(table, on=group)
    sample["men"] = np.log(sample.n_g)/10
    sample["men_sq"] = sample.men**2
    if friends:
        units = group_table(members.loc[members.unit.notna()], [group, "unit"], reference, p["sameness_constant"])
        units = units.rename(columns={c: "unit_" + c for c in units})
        sample = sample.join(units, on=[group, "unit"])
        number = sample.unit_n_g.fillna(0)
        if p["friends_def"] == "others":
            number = number - sample.index.isin(members.index).astype(int)
        sample["friends"] = np.log(number.where(number.gt(0))).where(sample.unit.notna())
    return sample, reference


def probit_parts(beta, x, y, hessian=False):
    sign = 2*y-1
    t = sign*(x @ beta)
    logp = special.log_ndtr(t)
    hazard = np.exp(-0.5*t*t - 0.5*np.log(2*np.pi)-logp)
    score_scalar = sign*hazard
    nll, grad = -logp.sum(), -(x.T @ score_scalar)
    if hessian:
        weights = hazard*(hazard+t)
        return nll, grad, x.T @ (weights[:, None]*x), score_scalar
    return nll, grad


def fit_probit(x, y):
    if len(y) <= x.shape[1] or np.unique(y).size != 2:
        raise ValueError("Insufficient observations or constant survival")
    # Internal RMS scaling is an invertible parameter transformation; outputs use original units.
    scale = np.sqrt(np.mean(x*x, axis=0))
    z = x/scale
    start = np.zeros(x.shape[1])
    start[0] = special.ndtri(y.mean()) * scale[0]
    n = len(y)
    def objective(b):
        f, g = probit_parts(b, z, y)
        return f/n, g/n
    opt = optimize.minimize(objective, start, jac=True, method="L-BFGS-B",
                            options={"maxiter": 1500, "ftol": 1e-13, "gtol": 1e-9, "maxcor": 30})
    b = opt.x
    converged = False
    for _ in range(25):
        f, g, h, _ = probit_parts(b, z, y, True)
        step = linalg.solve(h, g, assume_a="pos")
        decrement = float(g @ step)
        if decrement < 1e-9 and np.max(np.abs(g))/n < 1e-7:
            converged = True
            break
        alpha = 1.0
        while alpha > 2**-22:
            candidate = b-alpha*step
            if probit_parts(candidate, z, y)[0] <= f - 1e-4*alpha*max(decrement, 0) + 1e-10:
                b = candidate
                break
            alpha /= 2
        else:
            break
    beta = b/scale
    f, g, h, score_scalar = probit_parts(beta, x, y, True)
    if not np.isfinite(beta).all() or not np.isfinite(f):
        raise FloatingPointError("Non-finite probit fit")
    # A diverging estimate / vanishing information is not a valid finite MLE.
    hz = h/scale[:, None]/scale[None, :]
    if np.linalg.cond(hz) > 1e14:
        raise ValueError("Observed information singular or ill-conditioned; possible separation")
    if np.all((2*y-1)*(x @ beta) > 0):
        raise ValueError("Complete separation: finite maximum-likelihood estimate does not exist")
    bread = linalg.inv(hz)/scale[:, None]/scale[None, :]
    return {"beta": beta, "bread": bread, "score_scalar": score_scalar,
            "ll": -f, "converged": converged, "optimizer_message": str(opt.message),
            "max_scaled_score": float(np.max(np.abs(g/scale))/n)}


def cluster_covariance(x, score_scalar, bread, clusters):
    codes, labels = pd.factorize(np.asarray(clusters), sort=True)
    g = len(labels)
    if g < 2 or (codes < 0).any():
        raise ValueError("Cluster covariance requires at least two non-missing clusters")
    cluster_scores = np.zeros((g, x.shape[1]))
    # Column-wise sums avoid allocating the full observation-by-parameter score matrix.
    for j in range(x.shape[1]):
        cluster_scores[:, j] = np.bincount(codes, weights=score_scalar*x[:, j], minlength=g)
    a = cluster_scores @ bread
    cov = (a.T @ a)*(g/(g-1))
    return (cov+cov.T)/2, g


def marginal_effects(beta, mean, binary_indices):
    k = len(beta)
    eta = mean @ beta
    phi = stats.norm.pdf(eta)
    effects = phi*beta
    jac = phi*np.eye(k) - eta*phi*np.outer(beta, mean)
    for j in binary_indices:
        lo, hi = mean.copy(), mean.copy()
        lo[j], hi[j] = 0, 1
        a, b = lo @ beta, hi @ beta
        effects[j] = special.ndtr(b)-special.ndtr(a)
        jac[j] = stats.norm.pdf(b)*hi - stats.norm.pdf(a)*lo
    return effects, jac


def delta_se(jac, cov):
    var = np.einsum("ij,jk,ik->i", jac, cov, jac)
    if np.min(var) < -1e-9:
        raise FloatingPointError("Negative delta-method variance")
    return np.sqrt(np.maximum(var, 0))


def normal_p(effect, se):
    with np.errstate(divide="ignore", invalid="ignore"):
        z = np.asarray(effect)/np.asarray(se)
    return 2*special.ndtr(-np.abs(z))


def delong(y, predictions):
    """Paired DeLong covariance via tie-aware empirical placement values (O(n log n))."""
    y = np.asarray(y)
    predictions = np.asarray(predictions)
    m, n = int((y == 1).sum()), int((y == 0).sum())
    if m < 2 or n < 2 or predictions.shape != (2, len(y)) or not np.isfinite(predictions).all():
        raise ValueError("DeLong requires two finite paired scores and >=2 observations in each class")
    v10, v01 = [], []
    for scores in predictions:
        pos, neg = scores[y == 1], scores[y == 0]
        sn, sp = np.sort(neg), np.sort(pos)
        v10.append((np.searchsorted(sn, pos, "left") + np.searchsorted(sn, pos, "right"))/(2*n))
        v01.append(1-(np.searchsorted(sp, neg, "left") + np.searchsorted(sp, neg, "right"))/(2*m))
    v10, v01 = np.asarray(v10), np.asarray(v01)
    auc = np.mean(v10, axis=1)
    diff = auc[0]-auc[1]
    # Algebraically [1,-1] Cov [1,-1]', but avoids cancellation for almost
    # identical predictors. Do not round a small positive variance to zero.
    variance = float(np.var(v10[0]-v10[1], ddof=1)/m + np.var(v01[0]-v01[1], ddof=1)/n)
    z = diff/math.sqrt(variance) if variance > 0 else (0. if diff == 0 else math.copysign(math.inf, diff))
    return dict(auc_full=auc[0], auc_reduced=auc[1], difference=diff, z=z, p=2*special.ndtr(-abs(z)))


@dataclass(frozen=True)
class Model:
    family: str
    group: str
    level: str
    hierarchy: tuple[str, ...]
    variant: str = ""

    @property
    def id(self):
        h = "+".join(self.hierarchy) or "friends"
        return "__".join(filter(None, [self.family, self.group, self.level, h, self.variant]))


def models_for(family):
    if family in {"T5ROC", "INFLUENCE"}:
        return []
    models = []
    for group in ("cap", "camp"):
        if family == "R_friends":
            models.append(Model(family, group, "full", (), "friends_only"))
            for h in HIERARCHIES:
                models.extend([Model(family, group, "full", (h,), "plus_friends"),
                               Model(family, group, "full", (h,), "unit_hierarchy")])
            continue
        if family == "R_alt":
            for h in ("ratio_sameness", "absolute_sameness"):
                for level in ("simple", "full"):
                    models.append(Model(family, group, level, (h,)))
            for h in ("distinct_ranks", "sum_ranks", "administrative_intensity"):
                models.append(Model(family, group, "full", (h,)))
            continue
        allowed = {"T4", "T5", "T6", "R_cc", "R_n50", "R_n100", "R_noexec", "R_ger", "R_jap", "R_aaf", "R_nosq", "R_int"}
        if family not in allowed:
            raise ValueError(f"Unknown family {family}")
        for level in (("full",) if family in {"R_cc", "R_nosq", "R_int"} else ("simple", "full")):
            for hs in ([tuple(HIERARCHIES)] if family == "T5" else [(h,) for h in HIERARCHIES]):
                models.append(Model(family, group, level, hs))
    return models


def model_sample(base, model):
    d = base.copy()
    family = model.family
    if family == "R_cc":
        cols = ["height", "age", "education", "dependents", "officer"]
        if model.group == "camp":
            cols += ["distance"]
        d = d.loc[d[cols].notna().all(axis=1)].copy()
    elif family in {"R_n50", "R_n100"}:
        d = d.loc[d.n_g.ge(50 if family == "R_n50" else 100)].copy()
    elif family == "R_noexec":
        d = d.loc[~d.executed].copy()
    elif family in {"R_ger", "R_jap", "R_aaf"}:
        d = d.loc[d.DET_POWER.eq("2" if family == "R_jap" else "1")].copy()
        if family == "R_aaf":
            d = d.loc[d.SERVICE_CODE.eq("1") & (d.ARM_SVC_CODE.eq("20") | d.ARM_SVC_ALPHA.eq("AC"))].copy()
    if model.variant == "unit_hierarchy":
        for h in model.hierarchy:
            d[h] = d["unit_" + h]
    return d


def regressor_names(model):
    names = list(model.hierarchy)
    if model.group == "camp" and model.family not in {"R_ger", "R_jap", "R_aaf"}:
        names += ["japan"]
    if model.level == "full":
        names += ["men"]
        if model.family != "R_nosq":
            names += ["men_sq"]
        if model.group == "camp":
            names += ["distance"]
        names += ["length", "height", "age", "education", "dependents", "officer"]
    if model.family == "T6":
        if "officer" not in names:
            names += ["officer"]
        names += ["officer_x_" + h for h in model.hierarchy]
    if model.family == "R_int":
        names += [h + "_x_men" for h in model.hierarchy]
    if model.family == "R_friends":
        names += ["friends"]
    return names


def make_design(d, model):
    names = regressor_names(model)
    raw = {}
    for name in names:
        if name.startswith("officer_x_"):
            raw[name] = d.officer*d[name[len("officer_x_"):]]
        elif name.endswith("_x_men"):
            raw[name] = d[name[:-len("_x_men")]]*d.men
        else:
            raw[name] = d[name]
    columns = {"intercept": np.ones(len(d))}
    binary, omitted = set(), {}
    for name, series in raw.items():
        series = series.replace([np.inf, -np.inf], np.nan)
        columns[name] = series.fillna(0).to_numpy(float)
        if name in BINARY:
            binary.add(name)
        if series.isna().any():
            columns[name + "_missing"] = series.isna().to_numpy(float)
            binary.add(name + "_missing")
    if model.group == "cap":
        camps = sorted(d.camp.unique())
        for camp in camps[1:]:
            columns["camp["+camp+"]"] = d.camp.eq(camp).to_numpy(float)
            binary.add("camp["+camp+"]")
    for name in list(columns):
        if name != "intercept" and (len(d) == 0 or np.ptp(columns[name]) == 0):
            omitted[name] = "omitted_constant"
            del columns[name]
    names = list(columns)
    x = np.column_stack(list(columns.values()))
    if len(d):
        # Exact aliases can arise from missing indicators or country/camp coding.
        # Preserve the stated regressor order, dropping later redundant columns.
        scale = np.linalg.norm(x, axis=0)
        _, r = linalg.qr(x/scale, mode="economic", check_finite=False)
        if r.shape[0] < r.shape[1] or np.any(np.abs(np.diag(r)) < 1e-10):
            chosen, q = [], []
            for j in range(x.shape[1]):
                v = x[:, j]/scale[j]
                for _ in range(2):
                    if q:
                        basis = np.column_stack(q)
                        v = v-basis @ (basis.T @ v)
                norm = np.linalg.norm(v)
                if norm > 1e-10:
                    chosen.append(j)
                    q.append(v/norm)
                else:
                    omitted[names[j]] = "omitted_collinear"
            x, names = x[:, chosen], [names[j] for j in chosen]
    return x, names, [j for j, name in enumerate(names) if name in binary], omitted


class Outputs:
    def __init__(self, out):
        self.out = Path(out)
        self.out.mkdir(parents=True, exist_ok=True)
        (self.out / "sample_ids").mkdir(exist_ok=True)
        self.handles = []
        self.writers = {}
        for name, fields in [("results", RESULT_COLS), ("roc", ROC_COLS), ("influence", INFLUENCE_COLS)]:
            handle = (self.out / (name + ".csv")).open("w", newline="")
            self.handles.append(handle)
            self.writers[name] = csv.DictWriter(handle, fields, extrasaction="raise")
            self.writers[name].writeheader()
        self.logfile = (self.out / "run_log.txt").open("w", buffering=1)

    def log(self, text):
        line = time.strftime("%Y-%m-%d %H:%M:%S") + " " + str(text)
        print(line, flush=True)
        self.logfile.write(line + "\n")

    def write(self, kind, row):
        self.writers[kind].writerow(row)
        for h in self.handles:
            h.flush()

    def ids(self, spec, model_id, ids):
        path = self.out / "sample_ids" / f"{spec}__{model_id}.txt"
        np.savetxt(path, np.sort(np.asarray(ids, dtype=np.int64)), fmt="%d")

    def close(self):
        for h in self.handles:
            h.close()
        self.logfile.close()


def run_fit(base, model, spec, out, *, write_results=True, suffix=""):
    start = time.monotonic()
    model_id = model.id + suffix
    meta = dict(spec_id=spec, model_id=model_id, family=model.family, n=len(base),
                dropped_rows_pp=0, dropped_camps_pp=0, converged=False)
    d = base
    try:
        d = model_sample(base, model)
        if model.group == "cap":
            variation = d.groupby("camp").survival.nunique()
            drop = variation.index[variation.le(1)]
            mask = d.camp.isin(drop)
            meta.update(dropped_rows_pp=int(mask.sum()), dropped_camps_pp=len(drop))
            d = d.loc[~mask].copy()
        meta["n"] = len(d)
        meta["n_clusters"] = d[model.group].nunique()
        out.ids(spec, model_id, d.record_seq)
        x, names, binary, omitted = make_design(d, model)
        y = d.survival.to_numpy(float)
        fit = fit_probit(x, y)
        if not fit["converged"]:
            raise RuntimeError("Maximum likelihood did not converge: " + fit["optimizer_message"])
        cov, g = cluster_covariance(x, fit["score_scalar"], fit["bread"], d[model.group])
        beta = fit["beta"]
        me, jac = marginal_effects(beta, x.mean(axis=0), binary)
        se = delta_se(jac, cov)
        p = normal_p(me, se)
        if model.group == "cap":
            cov_camp, _ = cluster_covariance(x, fit["score_scalar"], fit["bread"], d.camp)
            camp_se = delta_se(jac, cov_camp)
            camp_p = normal_p(me, camp_se)
        else:
            camp_se = camp_p = np.full(len(names), np.nan)
        prevalence = y.mean()
        ll0 = float(np.sum(special.xlogy(y, prevalence) + special.xlogy(1-y, 1-prevalence)))
        status, error = "ok", ""
        meta.update(n_clusters=g, ll=fit["ll"], ll0=ll0, pseudo_r2=1-fit["ll"]/ll0,
                    converged=fit["converged"], status=status, error=error)
        rows = []
        for j, name in enumerate(names):
            row = dict(meta, term=name, coef=beta[j], coef_se=np.sqrt(max(cov[j, j], 0)))
            if name != "intercept":
                row.update(me=me[j], me_se=se[j], me_p=p[j], me_se_campcluster=camp_se[j], me_p_campcluster=camp_p[j])
            rows.append(row)
        for name, reason in omitted.items():
            rows.append(dict(meta, term=name, status=reason, error="Regressor dropped: " + reason))
        if write_results:
            for row in rows:
                out.write("results", row)
        out.log(f"{spec} {model_id}: {status}; N={len(d)} K={len(names)} clusters={g}; "
                f"PP={meta['dropped_rows_pp']}/{meta['dropped_camps_pp']}; "
                f"omitted={omitted}; scaled_score={fit['max_scaled_score']:.3g}; seconds={time.monotonic()-start:.3f}")
        return dict(meta=meta, rows={row["term"]: row for row in rows}, ids=d.record_seq.to_numpy(),
                    camp=d.camp.to_numpy(), y=y, predictions=special.ndtr(x @ beta), model=model)
    except Exception as exc:
        error = f"{type(exc).__name__}: {exc}"
        meta.update(status="failed", error=error, n=len(d))
        out.ids(spec, model_id, d.record_seq)
        if write_results:
            out.write("results", dict(meta, term="__model__"))
        out.log(f"{spec} {model_id}: failed; {error}; seconds={time.monotonic()-start:.3f}\n{traceback.format_exc()}")
        return dict(meta=meta, rows={}, ids=d.record_seq.to_numpy(), camp=d.camp.to_numpy(), model=model)


def run_roc(cache, spec, out):
    for model in models_for("T5"):
        for omitted in HIERARCHIES:
            remaining = tuple(h for h in HIERARCHIES if h != omitted)
            comparator = Model("T4", model.group, model.level, remaining)
            row = dict(spec_id=spec, model_id=model.id, family="T5ROC", omitted_term=omitted,
                       comparator_id=comparator.id, status="failed", error="")
            try:
                full, reduced = cache[model.id], cache[comparator.id]
                if full["meta"]["status"] != "ok" or reduced["meta"]["status"] != "ok":
                    raise ValueError("A paired fit failed or did not converge")
                if not np.array_equal(full["ids"], reduced["ids"]):
                    raise ValueError("Paired model estimation rows differ")
                row.update(delong(full["y"], [full["predictions"], reduced["predictions"]]),
                           n=len(full["y"]), status="ok")
            except Exception as exc:
                row["error"] = f"{type(exc).__name__}: {exc}"
            out.write("roc", row)
            out.log(f"{spec} T5ROC {model.id} omit {omitted}: {row['status']} {row['error']}")


def run_influence(cache, bases, spec, out, scope):
    if scope == "none":
        out.log(f"{spec}: INFLUENCE skipped by --influence none")
        return
    for model in models_for("T4"):
        original = cache.get(model.id)
        if original is None:
            out.write("influence", dict(spec_id=spec, model_id=model.id, status="failed", error="T4 fit unavailable"))
            continue
        camps = sorted(set(original["camp"]))
        if scope == "first20":
            camps = camps[:20]
        # Start from the actual T4 estimation sample; all precomputed group variables stay fixed.
        base = bases[model.group].loc[bases[model.group].record_seq.isin(original["ids"])]
        for camp in camps:
            fit = run_fit(base.loc[base.camp.ne(camp)], model, spec, out, write_results=False,
                          suffix="__delete_" + camp)
            term = fit["rows"].get(model.hierarchy[0], {})
            status = fit["meta"]["status"]
            error = fit["meta"]["error"]
            if term.get("status", "").startswith("omitted"):
                status, error = term["status"], term["error"]
            out.write("influence", dict(spec_id=spec, model_id=model.id, deleted_camp=camp,
                      me=term.get("me", np.nan), me_p=term.get("me_p", np.nan), n=fit["meta"]["n"],
                      status=status, error=error))


def run_spec(raw, linked, data, spec, families, out, influence, construct_only=False):
    sid, p = spec["spec_id"], spec["params"]
    out.log(f"BEGIN {sid}; params={json.dumps(p, sort_keys=True)}; families={families}")
    d = construct_records(raw, linked, data, p)
    mask = pd.Series(True, index=d.index)
    for label, step in [("service", ~d.SERVICE_CODE.isin(p["svc_exclude"])),
                        ("power", d.DET_POWER.isin(["1", "2"])),
                        ("D_status", d.STA.isin(["4", "5", "7", "8", "9"]))]:
        mask &= step
        out.log(f"{sid} sample {label}={int(mask.sum())}")
    bases = {}
    for group in ("cap", "camp"):
        bases[group], reference = construct_groups(d, p, group, "R_friends" in families)
        b = bases[group]
        cols = ["rank", "height", "age", "education", "dependents", "officer", "length", "distance"] + GROUP_METRICS
        out.log(f"{sid} {group}: R={len(b)}; linked={int(b.linked.sum())}; "
                f"rank_reference={reference.tolist()}; missing={b[cols].isna().sum().to_dict()}")
        if "R_friends" in families:
            out.log(f"{sid} {group}: friends_missing={int(b.friends.isna().sum())}; "
                    f"unit_steepness_missing={int(b.unit_steepness.isna().sum())}")
    if construct_only:
        out.log(f"END {sid} (construction only; no empirical fits)")
        return
    cache = {}
    for family in families:
        if family == "T5ROC":
            run_roc(cache, sid, out)
        elif family == "INFLUENCE":
            if spec.get("role") != "origin":
                raise ValueError("Influence is restricted to the origin spec")
            run_influence(cache, bases, sid, out, influence)
        else:
            for model in models_for(family):
                result = run_fit(bases[model.group], model, sid, out)
                if family in {"T4", "T5"}:
                    cache[model.id] = result
    out.log(f"END {sid}")


def synthetic_tests(directory):
    """Mandatory gate before all empirical fits. Failures abort before reading real data."""
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    reports = []
    started = time.monotonic()
    def check(name, metrics):
        reports.append(dict(test=name, status="passed", **metrics))
        print(f"SYNTHETIC PASS {name}: {metrics}", flush=True)
    try:
        rng = np.random.default_rng(742019)
        n = 60000
        x = np.column_stack([np.ones(n), rng.normal(size=n), rng.binomial(1, .4, n)])
        truth = np.array([-.25, .7, -.45])
        y = (rng.random(n) < special.ndtr(x @ truth)).astype(float)
        fit = fit_probit(x, y)
        error = float(np.max(np.abs(fit["beta"]-truth)))
        assert fit["converged"] and error < .035, (fit["beta"], error)
        check("known_probit_coefficients", dict(n=n, truth=truth.tolist(), recovered=fit["beta"].tolist(), max_abs_error=error, tolerance=.035))

        cov, _ = cluster_covariance(x, fit["score_scalar"], fit["bread"], np.arange(n)//20)
        mean, beta, eps = x.mean(axis=0), fit["beta"], 1e-5
        effects, jac = marginal_effects(beta, mean, [2])
        numerical_effects = np.empty(3)
        def numeric_me(b):
            result = np.empty(3)
            for j in range(3):
                lo, hi = mean.copy(), mean.copy()
                if j == 2:
                    lo[j], hi[j] = 0, 1
                    result[j] = special.ndtr(hi @ b)-special.ndtr(lo @ b)
                else:
                    lo[j] -= eps
                    hi[j] += eps
                    result[j] = (special.ndtr(hi @ b)-special.ndtr(lo @ b))/(2*eps)
            return result
        numerical_effects[:] = numeric_me(beta)
        nj = np.column_stack([(numeric_me(beta+eps*np.eye(3)[k])-numeric_me(beta-eps*np.eye(3)[k]))/(2*eps) for k in range(3)])
        np.testing.assert_allclose(effects, numerical_effects, atol=1e-9, rtol=1e-7)
        np.testing.assert_allclose(jac, nj, atol=2e-6, rtol=2e-5)
        np.testing.assert_allclose(delta_se(jac, cov), delta_se(nj, cov), atol=2e-8, rtol=2e-5)
        check("marginal_effects_and_delta_finite_differences", dict(max_me_error=float(np.max(abs(effects-numerical_effects))), max_jacobian_error=float(np.max(abs(jac-nj))), max_se_error=float(np.max(abs(delta_se(jac, cov)-delta_se(nj, cov))))))

        tx = np.column_stack([np.ones(12), np.linspace(-1, 1, 12)])
        ty = np.array([0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1.])
        tb = np.array([.2, -.4])
        t = (2*ty-1)*(tx @ tb)
        lam = stats.norm.pdf(t)/stats.norm.cdf(t)
        scores = ((2*ty-1)*lam)[:, None]*tx
        hess = sum(lam[i]*(lam[i]+t[i])*np.outer(tx[i], tx[i]) for i in range(12))
        bread = np.linalg.inv(hess)
        tc = np.repeat(np.arange(4), 3)
        meat = sum(np.outer(scores[tc == g].sum(axis=0), scores[tc == g].sum(axis=0)) for g in range(4))
        direct = (4/3)*bread @ meat @ bread
        _, _, actual_hess, scalar = probit_parts(tb, tx, ty, True)
        np.testing.assert_allclose(hess, actual_hess, atol=1e-12)
        actual, _ = cluster_covariance(tx, scalar, np.linalg.inv(actual_hess), tc)
        np.testing.assert_allclose(actual, direct, atol=1e-12)
        check("cluster_sandwich_direct_tiny_example", dict(max_abs_error=float(np.max(abs(actual-direct))), clusters=4, correction=4/3))

        counts = np.array([[0, 0, 7, 0, 0, 0, 0, 0, 0], [1, 2, 3, 4, 5, 6, 7, 8, 9], [1, 0, 0, 0, 0, 0, 0, 0, 1], [0]*9])
        ref = np.arange(1, 10)/45
        metrics = hierarchy_from_counts(counts, ref, "fixed")
        np.testing.assert_allclose(metrics[0, 1], 0, atol=1e-14)
        np.testing.assert_allclose(metrics[1, 2], 1, atol=1e-14)
        np.testing.assert_allclose(metrics[2, 1], .4, atol=1e-14)
        assert np.isnan(metrics[3]).all()
        ranks = np.repeat(np.arange(1, 10), counts[1])
        ordered = 1+1/len(ranks)-2*np.sum((len(ranks)+1-np.arange(1, len(ranks)+1))*ranks)/(len(ranks)*ranks.sum())
        np.testing.assert_allclose(metrics[1, 1], ordered, atol=1e-14)
        check("handmade_hierarchy_groups", dict(single_rank_steepness=float(metrics[0, 1]), matching_reference_sameness=float(metrics[1, 2]), ranks_1_9_steepness=float(metrics[2, 1]), empty_group_missing=True))

        yy = np.array([1, 1, 1, 1, 0, 0, 0, 0])
        pred = np.array([.3, .5, .5, .9, .1, .3, .5, .7])
        identical = delong(yy, [pred, pred])
        assert identical["z"] == 0 and identical["p"] == 1
        other = np.array([.1, .5, .8, .7, .2, .4, .5, .9])
        paired = delong(yy, [pred, other])
        placements = []
        for s in [pred, other]:
            a, b = s[yy == 1], s[yy == 0]
            kernel = (a[:, None] > b).astype(float) + .5*(a[:, None] == b)
            placements.append(kernel)
        aucs = np.array([k.mean() for k in placements])
        dcov = np.cov([k.mean(axis=1) for k in placements])/4 + np.cov([k.mean(axis=0) for k in placements])/4
        dz = (aucs[0]-aucs[1])/np.sqrt(np.array([1, -1]) @ dcov @ np.array([1, -1]))
        np.testing.assert_allclose([paired["auc_full"], paired["auc_reduced"], paired["z"]], [*aucs, dz], atol=1e-12)
        near_y = np.tile([0, 1], 100000)
        near_a = np.arange(200000, dtype=float)
        near_b = near_a.copy()
        near_b[2], near_b[3] = near_b[3], near_b[2]
        near = delong(near_y, [near_a, near_b])
        np.testing.assert_allclose(near["z"], 1/np.sqrt(2), rtol=2e-6)
        assert 0 < near["p"] < 1
        check("delong_identical_and_direct_paired_with_ties", dict(identical_z=identical["z"], identical_p=identical["p"], paired_z=paired["z"], nearly_identical_z=near["z"]))

        expected = {"T4": 8, "T5": 4, "T6": 8, "R_cc": 4, "R_n50": 8, "R_n100": 8,
                    "R_noexec": 8, "R_ger": 8, "R_jap": 8, "R_aaf": 8, "R_nosq": 4,
                    "R_alt": 14, "R_friends": 10, "R_int": 4}
        for family, number in expected.items():
            models = models_for(family)
            assert len(models) == number and len({m.id for m in models}) == number
        check("model_family_inventory", expected)

        raw = pd.DataFrame({"SERIAL_NO": ["A", "A", "B", "C", "D", ""]})
        enl = pd.DataFrame({"record_seq": [3, 1, 2, 4], "SER_NUM": ["A", "A", "B", "C"]})
        for name in ENL_FIELDS:
            enl[name] = ""
        enl["CARD_NUM"] = "1"
        enl["HEIGHT"] = ["70", "70", "65", ""]
        enl["YR_BIRTH"] = ["20", "21", "22", "23"]
        unique = link_records(raw, enl, "unmatched")
        first = link_records(raw, enl, "first")
        combined = link_records(raw, enl, "combine")
        assert len(unique) == len(first) == len(combined) == len(raw)
        assert not unique.loc[0, "linked"] and not unique.loc[1, "linked"]
        assert first.loc[0, "YR_BIRTH"] == "21" and first.loc[1, "YR_BIRTH"] == "21"
        assert combined.loc[0, "HEIGHT"] == "70" and combined.loc[0, "YR_BIRTH"] == ""
        assert combined.loc[3, "HEIGHT"] == "" and not combined.loc[5, "linked"]
        blank_duplicates = enl.iloc[[0, 1]].copy()
        blank_duplicates["SER_NUM"] = ""
        with_blank = pd.concat([enl, blank_duplicates], ignore_index=True)
        assert not link_records(raw, with_blank, "unmatched").loc[5, "linked"]
        assert link_records(raw, with_blank, "first").loc[5, "YR_BIRTH"] == "21"
        assert link_records(raw, with_blank, "combine").loc[5, "HEIGHT"] == "70"
        assert clean(pd.Series([" \x00 A ", " \x00 ", None])).tolist() == ["A", "", ""]
        check("cleaning_and_duplicate_linkage", dict(pow_rows_preserved=len(raw), duplicate_rules=3,
                                                     blank_serial_exact_matching=True))
    except Exception as exc:
        reports.append(dict(test="validation_failure", status="failed", error=repr(exc), traceback=traceback.format_exc()))
        raise
    finally:
        report = dict(seed=742019, elapsed_seconds=time.monotonic()-started, checks=reports)
        (directory / "synthetic_results.json").write_text(json.dumps(report, indent=2) + "\n")
        (directory / "synthetic_results.log").write_text("\n".join(json.dumps(r) for r in reports) + "\n")
    return report


def synthetic_integration(directory):
    """Exercise every family, paired ROC and deletion refits on generated records only."""
    directory = Path(directory)
    fixture = directory / "synthetic_inputs"
    fixture.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(92741)
    # Unequal group sizes and rank distributions avoid artificial collinearity.
    camps, months, rank = [], [], []
    for camp in range(12):
        for month in range(1, 9):
            n = int(rng.integers(90, 240))
            probabilities = rng.dirichlet(np.linspace(4, 1, 9))
            camps.extend([f"{camp+101}"]*n)
            months.extend([f"{month:02}"]*n)
            rank.extend(rng.choice(np.arange(1, 10), n, p=probabilities))
    n = len(rank)
    raw = pd.DataFrame("", index=range(n), columns=POW_COLS)
    raw["record_seq"] = np.arange(1, n+1)
    raw["SERIAL_NO"] = [f"{i:08}" for i in range(1, n+1)]
    raw["CAMP"], raw["DATE_REPORTED_MONTH"] = camps, months
    raw["DATE_REPORTED_YEAR"] = "3"
    raw["GRADE_ALPHA"] = [f"R{r}" for r in rank]
    raw.loc[rng.random(n) < .015, "GRADE_ALPHA"] = "unknown"
    raw["GRADE_CODE"] = ""
    raw["SERVICE_CODE"] = "1"
    raw["ARM_SVC_CODE"] = "20"
    raw["ARM_SVC_ALPHA"] = "AC"
    raw["DET_POWER"] = np.where(raw.CAMP.astype(int).gt(106), "2", "1")
    raw["TYPE_ORG"] = "U"
    raw["PARENT_UNIT_NUM"] = rng.integers(1, 8, n).astype(str)
    raw.loc[rng.random(n) < .02, ["TYPE_ORG", "PARENT_UNIT_NUM"]] = ""
    latent = .45 + .15*(np.array(rank) >= 5) - .2*raw.DET_POWER.eq("2").to_numpy()
    survival = rng.random(n) < special.ndtr(latent)
    raw["STA"] = np.where(survival, "7", np.where(rng.random(n) < .07, "4", "5"))
    linked = pd.DataFrame("", index=raw.index, columns=ENL_FIELDS)
    linked["CARD_NUM"] = np.where(rng.random(n) < .15, "3", "1")
    for prefix in ("", "ERC_"):
        linked[prefix+"HEIGHT"] = rng.integers(60, 79, n).astype(str)
        linked[prefix+"YR_BIRTH"] = rng.integers(5, 28, n).astype(str).tolist()
        linked[prefix+"YR_BIRTH"] = linked[prefix+"YR_BIRTH"].str.zfill(2)
        linked[prefix+"EDUCATION"] = rng.integers(0, 10, n).astype(str)
        linked[prefix+"MARITAL_STATUS"] = rng.integers(1, 10, n).astype(str)
        for field in ("HEIGHT", "YR_BIRTH", "EDUCATION", "MARITAL_STATUS"):
            linked.loc[rng.random(n) < .035, prefix+field] = ""
    linked["linked"] = True
    alpha = pd.DataFrame({"grade_alpha": [f"R{r}" for r in range(1, 10)]})
    for col in ("rank_origin_service_not_navy", "rank_origin_navy", "rank_strict_service_not_navy", "rank_strict_navy"):
        alpha[col] = np.arange(1, 10)
    alpha.to_csv(fixture / "rank_map_grade_alpha.csv", index=False)
    codes = pd.DataFrame({"grade_code": ["1"]})
    for col in ("rank_officer_not_navy", "rank_enlisted_not_navy", "rank_officer_navy", "rank_enlisted_navy"):
        codes[col] = 1
    codes.to_csv(fixture / "rank_map_grade_code.csv", index=False)
    crosswalk = pd.DataFrame({"camp_code": [str(i) for i in range(101, 113)],
                              "entry_id": [str(i) for i in range(101, 113)],
                              "confidence": "exact", "latitude": rng.uniform(30, 60, 12),
                              "longitude": rng.uniform(0, 150, 12),
                              "identified_place_name": "synthetic", "nara_degree_coords_text": ""})
    crosswalk.to_csv(fixture / "camp_location_crosswalk.csv", index=False)
    origin = json.loads((ROOT / "grid.json").read_text())["specs"][0]
    out = Outputs(directory / "integration_results")
    try:
        out.log("SYNTHETIC ONLY: all records and locations generated with seed 92741")
        run_spec(raw, linked, fixture, origin, origin["families"], out, "first20")
        friends_spec = dict(origin, spec_id="SYNTH_FRIENDS_OTHERS", role="synthetic",
                            params=dict(origin["params"], friends_def="others"))
        run_spec(raw, linked, fixture, friends_spec, ["R_friends"], out, "none")
        # Empty/single-class failures must be persisted without terminating the next fit.
        prepared = construct_records(raw, linked, fixture, origin["params"])
        base, _ = construct_groups(prepared, origin["params"], "camp")
        model = Model("T4", "camp", "simple", ("steepness",))
        failure = run_fit(base.iloc[:0], model, "SYNTH_EXPECTED_FAILURE", out)
        assert failure["meta"]["status"] == "failed"
        success = run_fit(base, model, "SYNTH_AFTER_FAILURE", out)
        assert success["meta"]["status"] == "ok"
        # The required prefit constant-outcome camp exclusion gets a direct assertion.
        base_cap, _ = construct_groups(prepared, origin["params"], "cap")
        first_camp = sorted(base_cap.camp.unique())[0]
        base_cap.loc[base_cap.camp.eq(first_camp), "survival"] = 1
        pp = run_fit(base_cap, Model("T4", "cap", "simple", ("steepness",)), "SYNTH_PP", out)
        assert pp["meta"]["dropped_camps_pp"] == 1 and first_camp not in pp["camp"]
        # Friends 'others' removes the row only when it is in the member set.
        incl, _ = construct_groups(prepared, origin["params"], "cap", True)
        others, _ = construct_groups(prepared, dict(origin["params"], friends_def="others"), "cap", True)
        eligible = incl["rank"].notna().to_numpy()
        expected_count = incl.unit_n_g.to_numpy()-eligible
        expected_friends = np.log(np.where(expected_count > 0, expected_count, np.nan))
        np.testing.assert_allclose(others.friends.to_numpy(), expected_friends, equal_nan=True)
    finally:
        out.close()
    result = pd.read_csv(directory / "integration_results" / "results.csv")
    actual = result.loc[result.spec_id.eq("S000")]
    unexpected = result.loc[~result.spec_id.eq("SYNTH_EXPECTED_FAILURE")]
    assert not unexpected.status.isin(["failed", "nonconverged"]).any()
    expected_fits = sum(len(models_for(f)) for f in origin["families"])
    assert actual.model_id.nunique() == expected_fits
    assert not actual.status.isin(["failed", "nonconverged"]).any(), actual.loc[actual.status.isin(["failed", "nonconverged"]), ["model_id", "status", "error"]].to_dict("records")
    roc = pd.read_csv(directory / "integration_results" / "roc.csv")
    influence = pd.read_csv(directory / "integration_results" / "influence.csv")
    assert len(roc) == 8 and roc.status.eq("ok").all()
    assert len(influence) == 12*8 and influence.status.eq("ok").all()
    for path in (directory / "integration_results" / "sample_ids").glob("*.txt"):
        ids = [int(s) for s in path.read_text().splitlines()]
        assert ids == sorted(ids) and len(ids) == len(set(ids))
    report = dict(status="passed", seed=92741, synthetic_rows=n, origin_fits=expected_fits,
                  roc_comparisons=len(roc), influence_refits=len(influence), friends_others_fits=10,
                  expected_failure_continuation=True, perfect_prediction_camp_drop=True,
                  friends_membership_subtraction=True, sorted_sample_ids=True)
    (directory / "integration_summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print("SYNTHETIC INTEGRATION PASS " + json.dumps(report), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--grid", type=Path, default=ROOT / "grid.json")
    parser.add_argument("--data", type=Path, default=ROOT / "data")
    parser.add_argument("--out", type=Path, default=ROOT / "results")
    parser.add_argument("--specs", default="S000", help="Comma-separated IDs or all")
    parser.add_argument("--influence", choices=["all", "first20", "none"], default="none")
    parser.add_argument("--families", help="Optional comma-separated restriction, e.g. T4 for the authorized smoke run")
    parser.add_argument("--self-test", action="store_true", help="Run synthetic checks only, without reading empirical data")
    parser.add_argument("--integration-test", action="store_true", help="Exercise all families using generated data only")
    parser.add_argument("--construct-only", action="store_true", help="Construct samples and variables, without empirical fits")
    args = parser.parse_args()
    report = synthetic_tests(ROOT / "tests")
    if args.integration_test:
        synthetic_integration(ROOT / "tests")
        return
    if args.self_test:
        return
    grid = json.loads(args.grid.read_text())
    specs = sorted(grid["specs"], key=lambda s: (s["spec_id"] != "S000", s["spec_id"]))
    if args.specs != "all":
        selected = set(args.specs.split(","))
        unknown = selected - {s["spec_id"] for s in specs}
        if unknown:
            parser.error(f"Unknown specs: {sorted(unknown)}")
        specs = [s for s in specs if s["spec_id"] in selected]
    restriction = set(args.families.split(",")) if args.families else None
    if restriction:
        unknown = restriction - {f for s in grid["specs"] for f in s["families"]}
        if unknown:
            parser.error(f"Unknown families: {sorted(unknown)}")
        if "T5ROC" in restriction:
            restriction |= {"T4", "T5"}
        if "INFLUENCE" in restriction:
            restriction.add("T4")
    out = Outputs(args.out)
    try:
        out.log(f"Invocation={vars(args)}; synthetic checks passed={len(report['checks'])}; "
                f"numpy={np.__version__}; pandas={pd.__version__}")
        raw, enl = load_inputs(args.data, out.log)
        linked_cache = {}
        for spec in specs:
            rule = spec["params"]["dup_serial"]
            if rule not in linked_cache:
                linked_cache[rule] = link_records(raw, enl, rule)
            families = [f for f in spec["families"] if restriction is None or f in restriction]
            families = [f for f in families if f != "INFLUENCE"] + (["INFLUENCE"] if "INFLUENCE" in families else [])
            try:
                run_spec(raw, linked_cache[rule], args.data, spec, families, out, args.influence, args.construct_only)
            except Exception as exc:
                out.log(f"SPEC FAILURE {spec['spec_id']}: {traceback.format_exc()}")
                for family in families:
                    for model in models_for(family):
                        out.write("results", dict(spec_id=spec["spec_id"], model_id=model.id, family=family,
                                                  term="__model__", status="failed", error=f"Sample construction: {exc}"))
                        out.ids(spec["spec_id"], model.id, [])
    finally:
        out.close()


if __name__ == "__main__":
    main()
