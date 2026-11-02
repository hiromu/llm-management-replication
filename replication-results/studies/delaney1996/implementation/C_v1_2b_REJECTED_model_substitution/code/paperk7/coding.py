"""Variable construction for PAPER_K7 (sections 2, 3, 4 and 9 of the spec).

All functions work on a pandas DataFrame holding the raw survey codes (floats,
NaN = system missing). Nothing here looks at estimation samples except the
z-score helper, which receives an explicit reference mask.
"""
from __future__ import annotations

import json
import math

import numpy as np
import pandas as pd

HRM_TERMS = ["STAFF", "TRAIN", "INCENT", "GRIEV", "DECENT", "ILM", "VHIER"]
ORG_CONTROLS = ["NONPROF", "SUBSID", "LOGEMP", "LOGAGE", "PCTMGR", "UNION", "PRODUCT", "SERVICE", "COMPET"]
MKT_CONTROLS = [c for c in ORG_CONTROLS if c != "NONPROF"]

POP_ITEMS = [f"V{i}" for i in range(289, 296)]
PMP_ITEMS = [f"V{i}" for i in range(296, 300)]
STAFF_ITEMS = ["V62", "V97", "V131"]
INCENT_ITEMS = ["V209", "V222", "V235"]
ILM_ITEMS = ["V67", "V76", "V102", "V111", "V136"]
DECENT_LARGER = [f"V{i}" for i in range(271, 279)]
DECENT_INDEP = [f"V{i}" for i in range(279, 287)]

# all raw variables the pipeline reads
RAW_VARS = (
    ["V1", "V3", "V8", "V9", "V16", "V17", "V21", "V23", "V32", "V41", "V43", "V79", "V114", "V115",
     "V145", "V157", "V166", "V172", "V220", "V233", "V261", "V270", "V300", "V328", "NEWTOTAL", "WEIGHT"]
    + POP_ITEMS + PMP_ITEMS + STAFF_ITEMS + INCENT_ITEMS + ILM_ITEMS + DECENT_LARGER + DECENT_INDEP
)


# ----------------------------------------------------------------------------
# metadata / missing codes
# ----------------------------------------------------------------------------
def load_metadata(path):
    with open(path) as fh:
        meta = json.load(fh)
    variables = meta["variables"] if isinstance(meta, dict) and "variables" in meta else meta
    if isinstance(variables, list):
        return {v["name"]: v for v in variables}
    return variables


def _range_bound(x, default):
    """Numeric bound of a declared range; None / 'LO' / 'HI' / 'LOWEST' / 'HIGHEST' are open ends."""
    if x is None:
        return default
    if isinstance(x, str):
        u = x.strip().upper()
        if u in ("LO", "LOWEST", "-INF"):
            return -math.inf
        if u in ("HI", "HIGHEST", "INF", "+INF"):
            return math.inf
        return float(u)
    return float(x)


def declared_missing(meta, var):
    """Return (set of missing values, list of (lo, hi) ranges) for a variable."""
    info = meta.get(var, {})
    vals = set(float(x) for x in info.get("declared_missing_values", []) or [])
    ranges = []
    for r in info.get("declared_missing_ranges", []) or []:
        if isinstance(r, dict):
            lo, hi = r.get("lo", r.get("low")), r.get("hi", r.get("high"))
        else:
            lo, hi = r[0], r[1]
        ranges.append((_range_bound(lo, -math.inf), _range_bound(hi, math.inf)))
    return vals, ranges


def apply_missing(series, meta, var, extra_missing=(), keep=()):
    """Set declared missing codes (plus extra_missing, minus keep) to NaN.

    Codes in `keep` are never set to missing, whether the metadata declares
    them as individual values or inside a range (amendment A2: a spec-level
    assignment to a code takes precedence over the metadata declaration).
    """
    s = pd.to_numeric(series, errors="coerce").astype(float)
    vals, ranges = declared_missing(meta, var)
    keep_vals = set(float(x) for x in keep)
    vals = (vals | set(float(x) for x in extra_missing)) - keep_vals
    mask = s.isin(list(vals))
    for lo, hi in ranges:
        mask |= (s >= lo) & (s <= hi)
    if keep_vals:
        mask &= ~s.isin(list(keep_vals))
    return s.mask(mask)


# ----------------------------------------------------------------------------
# generic helpers
# ----------------------------------------------------------------------------
def reverse(series, k):
    """Reverse a 1..k item: k+1-x."""
    return (k + 1) - series


def index_of(items: pd.DataFrame, item_rule: str) -> pd.Series:
    """Index under item_rule: L0/L2 mean of valid items (>=1 valid); L1 all valid."""
    if item_rule == "L1":
        return items.mean(axis=1, skipna=False)
    if item_rule in ("L0", "L2"):
        n_valid = items.notna().sum(axis=1)
        return items.mean(axis=1, skipna=True).where(n_valid >= 1)
    raise ValueError(f"unknown item_rule {item_rule}")


def safe_log(series, base=math.e):
    """Natural log (or other base); values <= 0 become missing."""
    s = series.astype(float)
    out = pd.Series(np.nan, index=s.index, dtype=float)
    ok = s.notna() & (s > 0)
    out[ok] = np.log(s[ok]) / math.log(base)
    return out


def zscore(series, ref_mask=None, ddof=1):
    """Standard score using mean/SD of the rows in ref_mask (valid values only).

    Rows outside ref_mask also receive (x - mean)/sd of the reference set.
    Returns (z, info) with info = dict(n, mean, sd). SD of 0 or n < 2 gives all-NaN.
    """
    s = series.astype(float)
    if ref_mask is None:
        ref_mask = pd.Series(True, index=s.index)
    ref = s[ref_mask & s.notna()]
    n = int(ref.shape[0])
    if n < 2 or (ddof == 1 and n < 2):
        return pd.Series(np.nan, index=s.index), {"n": n, "mean": np.nan, "sd": np.nan}
    mean = float(ref.mean())
    sd = float(ref.std(ddof=ddof))
    if not np.isfinite(sd) or sd <= 0:
        return pd.Series(np.nan, index=s.index), {"n": n, "mean": mean, "sd": sd}
    return (s - mean) / sd, {"n": n, "mean": mean, "sd": sd}


def binary(cond_true, cond_false):
    """1 where cond_true, 0 where cond_false, NaN otherwise (both are boolean Series)."""
    out = pd.Series(np.nan, index=cond_true.index, dtype=float)
    out[cond_false.fillna(False).astype(bool)] = 0.0
    out[cond_true.fillna(False).astype(bool)] = 1.0
    return out


# ----------------------------------------------------------------------------
# raw items with missing codes applied (before copy rule / transformations)
# ----------------------------------------------------------------------------
STAFF_CODES = [995, 996, 997, 998, 999]


def staff_raw_item(raw, meta, var, staff_coding):
    """Applications-per-opening item as a *valid count* under the staff_coding level.

    Every exclusion of the level is applied here (amendment A7), so that a
    non-missing value is exactly a value that is valid for copying and for the
    GSS fallback, and the transform is a plain logarithm:
    - codes 995-999 are never counts (996-999 always missing; declared codes too);
    - L0 / L2: counts x >= 1 are valid; 0 (and negatives) are missing;
    - L1: counts x >= 0 are valid;
    - L2: 995 is kept as the value 995 whatever the metadata declares (A2).
    """
    if staff_coding in ("L0", "L1"):
        s = apply_missing(raw[var], meta, var, extra_missing=STAFF_CODES)
    elif staff_coding == "L2":
        s = apply_missing(raw[var], meta, var, extra_missing=[c for c in STAFF_CODES if c != 995], keep=[995])
    else:
        raise ValueError(staff_coding)
    if staff_coding == "L1":
        return s.where(s >= 0)
    return s.where(s >= 1)


def staff_transform(item, staff_coding):
    """Transform a valid staff count (all exclusions already applied)."""
    s = item.astype(float)
    if staff_coding in ("L0", "L2"):
        return safe_log(s)  # ln(x), x >= 1 (995 included under L2)
    if staff_coding == "L1":
        return safe_log(1.0 + s)  # ln(1+x), x >= 0
    raise ValueError(staff_coding)


def build_raw_items(raw, meta, settings):
    """Return a DataFrame of the item-level variables with missing codes applied.

    Includes the copy rule when item_rule == L2.
    """
    it = pd.DataFrame(index=raw.index)
    sc = settings["staff_coding"]
    for v in STAFF_ITEMS:
        it[v] = staff_raw_item(raw, meta, v, sc)
    for v in ILM_ITEMS:
        it[v] = apply_missing(raw[v], meta, v, extra_missing=[8, 9])
    for v in INCENT_ITEMS:
        it[v] = apply_missing(raw[v], meta, v, extra_missing=[7, 8, 9])
    for v in POP_ITEMS + PMP_ITEMS:
        it[v] = apply_missing(raw[v], meta, v, extra_missing=[7, 8, 9])
    for v in DECENT_LARGER + DECENT_INDEP:
        it[v] = apply_missing(raw[v], meta, v, extra_missing=[7, 8, 9])
    if settings["item_rule"] == "L2":
        it = apply_copy_rule(it, raw)
    return it


def apply_copy_rule(items, raw):
    """Section 4.9. Uses the *raw* V79 / V114 for the system-missing checks.

    `items` holds each source item after every exclusion of the current axis
    level (amendment A7), so "valid" == not NaN here: a STAFF count of 0 or a
    code 995 under staff_coding L0 is NaN and is neither copied to the GSS item
    nor used for the manager item (the GSS fallback is used instead); declared
    missing codes are NaN and never valid.
    """
    it = items.copy()
    v79 = raw["V79"]
    v114 = raw["V114"]
    gss_pairs = [("V97", "V62"), ("V102", "V67"), ("V111", "V76"), ("V235", "V222")]
    for gss, core in gss_pairs:
        core_valid = it[core].notna()
        mark = (v79 == 2) | (v79.isna() & core_valid)
        it.loc[mark, gss] = it.loc[mark, core]
    mgr_pairs = [("V131", "V62", "V97"), ("V136", "V67", "V102"), ("V209", "V222", "V235")]
    mark_mgr = (v114 == 2) | v114.isna()
    for mgr, core, gss in mgr_pairs:
        src = it[core].where(it[core].notna(), it[gss])
        it.loc[mark_mgr, mgr] = src[mark_mgr]
    return it


# ----------------------------------------------------------------------------
# HRM variables (non-standardized) and pre-z items for STAFF and TRAIN
# ----------------------------------------------------------------------------
def build_pop_pmp(items, item_rule):
    pop = index_of(pd.DataFrame({v: reverse(items[v], 4) for v in POP_ITEMS}), item_rule)
    pmp = index_of(pd.DataFrame({v: reverse(items[v], 4) for v in PMP_ITEMS}), item_rule)
    return pop, pmp


def build_staff_items(items, staff_coding):
    """Transformed (pre-standardization) staff items."""
    return pd.DataFrame({v: staff_transform(items[v], staff_coding) for v in STAFF_ITEMS})


def build_train_items(raw, meta, settings):
    """Transformed (pre-standardization) training items V145, V157, V172."""
    no_training = settings["no_training"]
    train_log = settings["train_log"]
    v145 = apply_missing(raw["V145"], meta, "V145", extra_missing=[8, 9])
    v145r = pd.Series(np.nan, index=raw.index, dtype=float)
    v145r[v145 == 1] = 2.0
    v145r[v145 == 2] = 1.0
    # 99996 -> 100000 takes precedence over any metadata declaration (A2)
    v157 = apply_missing(raw["V157"], meta, "V157", extra_missing=[99998, 99999], keep=[99996])
    v157 = v157.mask(v157 == 99996, 100000.0)
    v172 = apply_missing(raw["V172"], meta, "V172", extra_missing=[4, 8, 9])
    v172r = reverse(v172, 3)
    no = v145 == 2
    if no_training == "L0":
        v157 = v157.mask(no)
        v172r = v172r.mask(no)
    elif no_training == "L1":
        v157 = v157.mask(no, 0.0)
        v172r = v172r.mask(no, 1.0)
    elif no_training == "L2":
        v157 = v157.mask(no, 0.0)
        v172r = v172r.mask(no)
    else:
        raise ValueError(no_training)
    # count log rule
    if no_training == "L0":
        v157_log = safe_log(v157.where(v157 >= 1))
    else:
        v157_log = safe_log(1.0 + v157.where(v157 >= 0))
    if train_log == "L0":
        out = pd.DataFrame({"V145": safe_log(v145r), "V157": v157_log, "V172": safe_log(v172r)})
    elif train_log == "L1":
        out = pd.DataFrame({"V145": v145r, "V157": v157_log, "V172": v172r})
    elif train_log == "L2":
        out = pd.DataFrame({"V145": v145r, "V157": v157, "V172": v172r})
    else:
        raise ValueError(train_log)
    return out


def build_incent(items, item_rule):
    return index_of(pd.DataFrame({v: reverse(items[v], 3) for v in INCENT_ITEMS}), item_rule)


def build_griev(raw, meta):
    v = apply_missing(raw["V270"], meta, "V270", extra_missing=[7, 8, 9])
    return binary(v == 1, v == 2)


DECISION_MAPS = {
    "L0": {3: 1, 5: 2, 1: 3, 4: 4, 2: 5},
    "L1": {1: 1, 5: 2, 3: 3, 4: 4, 2: 5},
}


def build_decent(items, raw, settings, meta=None):
    """DECENT index. V17 system-missing (or any value other than 1/2) gives all items missing (A4)."""
    mapping = DECISION_MAPS[settings["decision_map"]]
    v17 = apply_missing(raw["V17"], meta, "V17") if meta is not None else raw["V17"].astype(float)
    cols = {}
    for j in range(8):
        larger = items[DECENT_LARGER[j]]
        indep = items[DECENT_INDEP[j]]
        src = pd.Series(np.nan, index=raw.index, dtype=float)
        src[v17 == 1] = larger[v17 == 1]
        src[v17 == 2] = indep[v17 == 2]
        mapped = src.map(lambda x: mapping.get(int(x), np.nan) if pd.notna(x) and float(x).is_integer() else np.nan)
        cols[f"DEC{j + 1}"] = mapped.astype(float)
    return index_of(pd.DataFrame(cols), settings["item_rule"])


def build_ilm(items, item_rule):
    return index_of(pd.DataFrame({v: reverse(items[v], 2) for v in ILM_ITEMS}), item_rule)


def build_vhier(raw, meta, settings, check=None):
    """VHIER. 96 -> 100 (L0, L2, and the log10 check) takes precedence over the metadata (A2);
    under L1, 96 is missing. CHK_hierarchy_log10 is log10 of the recoded count (A3)."""
    level = settings["hierarchy"]
    if level not in ("L0", "L1", "L2"):
        raise ValueError(level)
    if level == "L1" and check != "hierarchy_log10":
        v = apply_missing(raw["V261"], meta, "V261", extra_missing=[96, 98, 99])
        return safe_log(v)
    v = apply_missing(raw["V261"], meta, "V261", extra_missing=[98, 99], keep=[96])
    count = v.mask(v == 96, 100.0)
    if check == "hierarchy_log10":
        return safe_log(count, base=10)
    if level == "L0":
        return safe_log(count)
    return count  # L2: raw count


# ----------------------------------------------------------------------------
# controls
# ----------------------------------------------------------------------------
def build_controls(raw, meta, settings, check=None):
    c = pd.DataFrame(index=raw.index)
    v8 = apply_missing(raw["V8"], meta, "V8")  # metadata declarations only (A9)
    c["NONPROF"] = binary(v8 == 2, v8 == 1)

    # SUBSID (A4, A9): V17 system-missing -> missing at every level; V17 == 2 -> 0 whatever V21 says.
    v17 = apply_missing(raw["V17"], meta, "V17")
    v21 = apply_missing(raw["V21"], meta, "V21", extra_missing=[8, 9])
    lvl = settings["subsidiary"]
    if lvl == "L0":
        subsid = binary(v17 == 1, v17.notna() & (v17 != 1))
    elif lvl in ("L1", "L2"):
        ones = v21 == 2
        if lvl == "L2":
            ones = v21.isin([1, 2, 3])
        zeros = v21.notna() & ~ones
        subsid = binary(ones, zeros)
        subsid[v17 == 2] = 0.0
    else:
        raise ValueError(lvl)
    subsid[v17.isna()] = np.nan
    c["SUBSID"] = subsid

    v23 = apply_missing(raw["V23"], meta, "V23", extra_missing=[99998, 99999])
    v32 = apply_missing(raw["V32"], meta, "V32", extra_missing=[99998, 99999])
    newtotal = apply_missing(raw["NEWTOTAL"], meta, "NEWTOTAL")
    total = v23 + v32  # NaN if either missing
    lvl = settings["employment"]
    if lvl == "L0":
        c["LOGEMP"] = safe_log(total)
    elif lvl == "L1":
        c["LOGEMP"] = safe_log(newtotal)
    elif lvl == "L2":
        c["LOGEMP"] = safe_log(v23)
    else:
        raise ValueError(lvl)

    v16 = apply_missing(raw["V16"], meta, "V16", extra_missing=[9998, 9999])
    age = 1991.0 - v16
    lvl = settings["age"]
    if lvl == "L0":
        c["LOGAGE"] = safe_log(age.where(age > 0))
    elif lvl == "L1":
        c["LOGAGE"] = safe_log(1.0 + age.where(age >= 0))
    elif lvl == "L2":
        c["LOGAGE"] = age
    else:
        raise ValueError(lvl)

    v114 = apply_missing(raw["V114"], meta, "V114", extra_missing=[8, 9])
    v115 = apply_missing(raw["V115"], meta, "V115", extra_missing=[99998, 99999])
    lvl = settings["pct_managers"]
    num = pd.Series(np.nan, index=raw.index, dtype=float)
    num[v114 == 1] = v115[v114 == 1]
    if lvl != "L1":
        num[v114 == 3] = 0.0
    den = newtotal if lvl == "L2" else total
    den = den.where(den.notna() & (den != 0))
    pct = 100.0 * num / den
    if check == "pct_proportion":
        pct = pct / 100.0
    c["PCTMGR"] = pct

    v220 = reverse(apply_missing(raw["V220"], meta, "V220", extra_missing=[7, 8, 9]), 3)
    v233 = reverse(apply_missing(raw["V233"], meta, "V233", extra_missing=[7, 8, 9]), 3)
    union_items = {"V220": v220, "V233": v233}
    lvl = settings["union_items"]
    if lvl in ("L1", "L2"):
        union_items["V300"] = reverse(apply_missing(raw["V300"], meta, "V300", extra_missing=[7, 8, 9]), 3)
    if lvl == "L2":
        v166 = apply_missing(raw["V166"], meta, "V166", extra_missing=[8, 9])
        u = pd.Series(np.nan, index=raw.index, dtype=float)
        u[v166 == 1] = 3.0
        u[v166 == 2] = 1.0
        union_items["V166"] = u
    if lvl not in ("L0", "L1", "L2"):
        raise ValueError(lvl)
    c["UNION"] = index_of(pd.DataFrame(union_items), settings["item_rule"])

    v41 = apply_missing(raw["V41"], meta, "V41", extra_missing=[8, 9])
    prod = pd.Series(np.nan, index=raw.index, dtype=float)
    serv = pd.Series(np.nan, index=raw.index, dtype=float)
    prod[v41 == 1] = 1.0; serv[v41 == 1] = 0.0
    prod[v41 == 2] = 0.0; serv[v41 == 2] = 1.0
    prod[v41 == 3] = 0.0; serv[v41 == 3] = 0.0
    if settings["neither"] == "L1":
        prod[v41 == 4] = 0.0; serv[v41 == 4] = 0.0
    elif settings["neither"] != "L0":
        raise ValueError(settings["neither"])
    c["PRODUCT"] = prod
    c["SERVICE"] = serv

    v328 = apply_missing(raw["V328"], meta, "V328", extra_missing=[7, 8, 9])
    lvl = settings["competition"]
    if lvl == "L0":
        c["COMPET"] = v328
    elif lvl == "L1":
        c["COMPET"] = binary(v328 == 4, v328.notna() & (v328 != 4))
    elif lvl == "L2":
        c["COMPET"] = binary(v328 >= 3, v328.notna() & (v328 < 3))
    else:
        raise ValueError(lvl)
    return c


# ----------------------------------------------------------------------------
# industry
# ----------------------------------------------------------------------------
def load_crosswalk(path):
    cw = pd.read_csv(path, dtype=str, keep_default_na=False)
    out = {}
    for _, row in cw.iterrows():
        code = str(row["census1980_code"]).strip()
        try:
            code_int = int(float(code))
        except ValueError:
            continue
        field = str(row.get("sic2_from_printed", "")).strip()
        groups = [g.strip() for g in field.replace(";", ",").split(",") if g.strip()] if field else []
        out[code_int] = groups
    return out


def build_industry(raw, crosswalk, settings, meta=None):
    """Industry group per row: string code, 'UNCL', or NaN.

    A4: a system-missing (or metadata-declared missing) V43 is missing at every
    level. UNCL (L0) applies only to non-missing V43 codes with an empty
    crosswalk field or no crosswalk entry.
    """
    v43 = apply_missing(raw["V43"], meta, "V43") if meta is not None else pd.to_numeric(raw["V43"], errors="coerce")
    lvl = settings["industry"]
    if lvl not in ("L0", "L1"):
        raise ValueError(lvl)
    out = []
    for x in v43:
        if pd.isna(x):
            out.append(np.nan)
            continue
        groups = crosswalk.get(int(x)) if float(x).is_integer() else None
        if lvl == "L0":
            if groups is None or len(groups) == 0:
                out.append("UNCL")
            else:
                out.append(groups[0])
        else:
            if groups is None or len(groups) != 1:
                out.append(np.nan)
            else:
                out.append(groups[0])
    return pd.Series(out, index=raw.index, dtype=object)


def group_sort_key(g):
    """Numeric order of SIC codes; UNCL sorts after every numeric code."""
    try:
        return (0, int(g))
    except (TypeError, ValueError):
        return (1, str(g))


def choose_reference_group(groups: pd.Series, check=None):
    """Reference (omitted) group: largest, ties lowest code; CHK alt: smallest, ties highest."""
    counts = groups.dropna().value_counts()
    if counts.empty:
        return None
    if check == "industry_ref_alt":
        m = counts.min()
        cands = [g for g, c in counts.items() if c == m]
        return sorted(cands, key=group_sort_key)[-1]
    m = counts.max()
    cands = [g for g, c in counts.items() if c == m]
    return sorted(cands, key=group_sort_key)[0]


def industry_dummies(groups: pd.Series, reference):
    """One 0/1 column per group present (excluding reference), named IND_<group>."""
    present = sorted(set(groups.dropna().unique()) - {reference}, key=group_sort_key)
    d = pd.DataFrame(index=groups.index)
    for g in present:
        d[f"IND_{g}"] = (groups == g).astype(float)
    d[groups.isna()] = np.nan
    return d


# ----------------------------------------------------------------------------
# full variable frame
# ----------------------------------------------------------------------------
def apply_records(raw, settings):
    if settings["records"] == "L0":
        return raw
    if settings["records"] == "L1":
        return raw[raw["V3"] != 0]
    raise ValueError(settings["records"])


def build_base_frame(raw, meta, crosswalk, settings, check=None):
    """Everything that does not depend on the standardization reference.

    Returns (frame, staff_items, train_items):
      frame has POP, PMP, INCENT, GRIEV, DECENT, ILM, VHIER, controls, IND_GROUP,
      V1, V8, V9, WEIGHT_OK/WEIGHT.
      staff_items / train_items are the transformed, un-standardized items.
    """
    items = build_raw_items(raw, meta, settings)
    rule = settings["item_rule"]
    f = pd.DataFrame(index=raw.index)
    f["V1"] = raw["V1"]
    f["V8"] = apply_missing(raw["V8"], meta, "V8")
    f["V9"] = apply_missing(raw["V9"], meta, "V9", extra_missing=[8, 9])
    f["POP"], f["PMP"] = build_pop_pmp(items, rule)
    f["INCENT"] = build_incent(items, rule)
    f["GRIEV"] = build_griev(raw, meta)
    f["DECENT"] = build_decent(items, raw, settings, meta=meta)
    f["ILM"] = build_ilm(items, rule)
    f["VHIER"] = build_vhier(raw, meta, settings, check=check)
    controls = build_controls(raw, meta, settings, check=check)
    for col in controls.columns:
        f[col] = controls[col]
    f["IND_GROUP"] = build_industry(raw, crosswalk, settings, meta=meta)
    # WEIGHT follows its metadata declarations (declared missing 0), then must be > 0 (A9)
    w = apply_missing(raw["WEIGHT"], meta, "WEIGHT")
    f["WEIGHT"] = w.where(w.notna() & (w > 0))
    staff_items = build_staff_items(items, settings["staff_coding"])
    train_items = build_train_items(raw, meta, settings)
    return f, staff_items, train_items


def standardize_and_index(items: pd.DataFrame, item_rule, ref_mask=None, ddof=1, base_z=None):
    """Standardize each item (reference rows = ref_mask) and average.

    If base_z is given (frame-wide L0 z-scores), rows outside ref_mask keep
    those values. Returns (index_series, z_items, info_per_item).
    """
    z = pd.DataFrame(index=items.index)
    info = {}
    for col in items.columns:
        zc, inf = zscore(items[col], ref_mask=ref_mask, ddof=ddof)
        if base_z is not None and ref_mask is not None:
            zc = zc.where(ref_mask, base_z[col])
        z[col] = zc
        info[col] = inf
    return index_of(z, item_rule), z, info
