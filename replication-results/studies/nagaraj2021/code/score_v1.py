"""Deterministic scorer for scoring_rules_v1.json.
usage: score.py <run_dir>   (expects <run_dir>/out/{A,B,C}; writes <run_dir>/scoring/)
Step 1 compares implementations without targets (written first); step 2 scores claims against sealed targets.
"""
import json, math, os, re, sys
import numpy as np
import pandas as pd

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(STUDY, "code"))
import normalize_desc  # noqa: E402

RUN = sys.argv[1]
OUT = os.path.join(RUN, "scoring")
os.makedirs(OUT, exist_ok=True)
GRID = pd.read_csv(os.path.join(STUDY, "manifest/grid_v1.csv"), dtype=str).fillna("")
GI = GRID.set_index("spec_id")
XS = {"AN04", "AN06", "AN12"}


def norm_term(t):
    t = str(t)
    m = re.fullmatch(r"treat_(?:x_|year_)(\d{4})", t)
    if m:
        return f"treat_{m.group(1)}"
    return {"post_placebo_treat": "post_treat", "nan": ""}.get(t, t)


RES = {}
for k in "ABC":
    r = pd.read_csv(os.path.join(RUN, "out", k, "results.csv"), dtype={"spec_id": str, "term": str, "sample_hash": str})
    r["term"] = r["term"].fillna("").map(norm_term)
    RES[k] = r.drop_duplicates(["spec_id", "term"]).set_index(["spec_id", "term"])


def agree(a, b):
    if a["status"] != "ok" or b["status"] != "ok":
        return False
    if a["n_obs"] != b["n_obs"] or str(a["sample_hash"]) != str(b["sample_hash"]):
        return False
    se = np.nanmean([a["se_cluster"], b["se_cluster"]]) if not (pd.isna(a["se_cluster"]) and pd.isna(b["se_cluster"])) else 0.0
    if not abs(a["estimate"] - b["estimate"]) <= max(1e-8, 1e-3 * se):
        return False
    for c in ("se_cluster", "se_hc1"):
        x, y = a[c], b[c]
        if pd.isna(x) and pd.isna(y):
            continue
        if pd.isna(x) or pd.isna(y) or abs(x - y) > 0.005 * max(abs(x), abs(y)):
            return False
    return True


def pair_value(spec, term):
    """Return (row, pair, agreement dict) using the first agreeing pair in order AB, AC, BC."""
    key = (spec, term)
    rows = {k: RES[k].loc[key] for k in "ABC" if key in RES[k].index}
    ag = {}
    for p, q in (("A", "B"), ("A", "C"), ("B", "C")):
        ag[p + q] = (p in rows and q in rows and agree(rows[p], rows[q]))
    for pq in ("AB", "AC", "BC"):
        if ag[pq]:
            return rows[pq[0]], pq, ag
    fails = [k for k, r in rows.items() if r["status"] != "ok"]
    return None, ("all_failed" if len(fails) == len(rows) and rows else "none"), ag


# ---------- Step 1: implementation agreement over the full grid (no targets) ----------
keys = sorted(set().union(*[set(RES[k].index) for k in "ABC"]))
reg_specs = set(GRID.loc[GRID.analysis.isin(["AN03", "AN04", "AN05", "AN06", "AN07", "AN08", "AN11", "AN12", "AN13", "AN14"]), "spec_id"])
agr = []
for key in keys:
    if key[0] not in reg_specs:
        continue
    _, pq, ag = pair_value(*key)
    agr.append({"spec_id": key[0], "term": key[1], **ag, "pair_used": pq})
AG = pd.DataFrame(agr)
AG.to_csv(os.path.join(OUT, "impl_agreement_rows.csv"), index=False)
desc = {k: normalize_desc.load(os.path.join(RUN, "out", k), k).set_index(["spec_id", "block", "variable", "group", "statistic"])["value"] for k in "ABC"}
dcmp = {}
for p, q in (("A", "B"), ("A", "C"), ("B", "C")):
    both = desc[p].index.intersection(desc[q].index)
    a, b = desc[p].loc[both], desc[q].loc[both]
    dcmp[p + q] = {"compared": int(len(both)), "differ": int((((a - b).abs() > (1e-9 + 1e-6 * b.abs())) & ~(a.isna() & b.isna())).sum())}
step1 = {"regression_rows": int(len(AG)), "all_three_agree": int((AG.AB & AG.AC & AG.BC).sum()),
         "pair_agree": {pq: int(AG[pq].sum()) for pq in ("AB", "AC", "BC")}, "no_agreeing_pair": int((AG.pair_used.isin(["none", "all_failed"])).sum()),
         "failed_rows": {k: int((RES[k].status != "ok").sum()) for k in "ABC"}, "descriptive": dcmp}
json.dump(step1, open(os.path.join(OUT, "step1_implementation_agreement.json"), "w"), indent=1)
print("STEP1", json.dumps(step1))

# ---------- Step 2: claims against sealed targets ----------
CLAIMS = json.load(open(os.path.join(STUDY, "scoring/claims_v1.json")))
BANDS = [0.01, 0.05, 0.10]


def band(p):
    if p is None or (isinstance(p, float) and math.isnan(p)):
        return None
    return sum(p >= b for b in BANDS)  # 0: <.01, 1: <.05, 2: <.10, 3: >=.10


STARBAND = {"***": 0, "**": 1, "*": 2, "": 3}


def interval(s):
    s = str(s)
    d = len(s.split(".")[1]) if "." in s else 0
    v = float(s)
    h = 0.5 * 10 ** (-d)
    return v - h, v + h, v


def zdist(est, s, se):
    lo, hi, _ = interval(s)
    dist = 0.0 if lo <= est <= hi else min(abs(est - lo), abs(est - hi))
    return dist / float(se)


def bench_p(spec, row):
    a = GI.loc[spec, "analysis"]
    xs = a in XS or (a == "AN13" and GI.loc[spec, "est"] == "M2")
    return (row["p_hc1"], row["se_hc1"], "HC1") if xs else (row["p_cluster"], row["se_cluster"], "CR1")


def passes(spec, term, pubv, se, pubband, sign_assess):
    row, pq, _ = pair_value(spec, term)
    if row is None:
        return None, None
    p, _, _ = bench_p(spec, row)
    est = row["estimate"]
    s_ok = (not sign_assess) or (est != 0 and math.copysign(1, est) == math.copysign(1, float(pubv)))
    b = band(p)
    ok = s_ok and (b is not None and b - pubband <= 1) and zdist(est, pubv, se) <= 2.0
    return ok, row


records = []
for c in CLAIMS:
    kind, unit = c["kind"], c["unit"]
    rec = {"unit": unit, "kind": kind, "tier": c["tier"], "paper_focal": c["paper_focal"], "origin_spec": c["origin_spec"]}
    if kind == "not_audited":
        rec.update(outcome="not_audited", reason=c["reason"])
        records.append(rec)
        continue
    if kind in ("regression", "regression_nuisance_unit", "placebo"):
        pub = c["published"]
        term = c["term"]
        row, pq, ag = pair_value(c["origin_spec"], term)
        rec.update(pair=pq, impl_agreement=ag, published=pub)
        if row is None:
            rec.update(outcome="not_attemptable" if pq == "all_failed" else "indeterminate", reason="failed_fit" if pq == "all_failed" else "implementation_disagreement")
            records.append(rec)
            continue
        est = float(row["estimate"])
        p_b, se_b, method = bench_p(c["origin_spec"], row)
        pubband = STARBAND[pub["stars"]]
        lo, hi, pv = interval(pub["value"])
        sign_assess = not (lo <= 0 <= hi) and kind != "placebo"
        sign_ok = (not sign_assess) or (est != 0 and math.copysign(1, est) == math.copysign(1, pv))
        scales = c.get("unit_readings", {"as_fitted": 1.0})
        zs = {u: zdist(est * f, pub["value"], pub["se"]) for u, f in scales.items()}
        z = min(zs.values())
        bb = band(p_b)
        hb = band(row["p_hc1"])
        nrec, npub = int(row["n_obs"]), int(pub["n_obs"]) if pub.get("n_obs") else None
        nrel = None if not npub else abs(nrec - npub) / npub
        ncat = None if npub is None else ("match" if nrel == 0 else "near" if nrel <= 0.005 else "mismatch")
        rec.update(estimate=est, se_benchmark=se_b, p_benchmark=p_b, benchmark=method, se_cluster=row["se_cluster"], p_cluster=row["p_cluster"],
                   se_hc1=row["se_hc1"], p_hc1=row["p_hc1"], n_obs=nrec, n_published=npub, n_check=ncat, z_by_unit=zs, z=z,
                   rel_diff=(est / pv - 1) if pv != 0 else None, band_benchmark=bb, band_hc1=hb, band_published=pubband,
                   band_change=None if bb is None else bb - pubband, sign_assessed=sign_assess, sign_ok=sign_ok)
        # uncertain branches
        unc = [s for s in (c.get("uncertain_specs", []) + [x for x in c.get("uncertain_specs_extra", []) if x])]
        ures = []
        for s in unc:
            ok, r2 = passes(s, term, pub["value"], pub["se"], pubband, sign_assess)
            if r2 is None:
                ures.append({"spec": s, "status": "no_agreeing_pair_or_failed"})
                continue
            p2, _, _ = bench_p(s, r2)
            ures.append({"spec": s, "estimate": float(r2["estimate"]), "p_benchmark": p2, "passes_all": bool(ok),
                         "keeps_sign_p05": bool((not sign_assess or math.copysign(1, r2["estimate"]) == math.copysign(1, pv)) and p2 < 0.05)})
        okr = [u for u in ures if "estimate" in u]
        rec["uncertain"] = {"n": len(unc), "n_scored": len(okr), "n_pass_all": sum(u["passes_all"] for u in okr),
                            "share_keep_sign_p05": (sum(u["keeps_sign_p05"] for u in okr) / len(okr)) if okr else None,
                            "median": float(np.median([u["estimate"] for u in okr])) if okr else None,
                            "min": min((u["estimate"] for u in okr), default=None), "max": max((u["estimate"] for u in okr), default=None),
                            "rows": ures}
        if kind == "placebo":
            fail2 = bb is not None and pubband == 3 and bb <= 1
            rec["outcome"], rec["reason"] = ("discrepant_candidate", "placebo significant at .05") if fail2 else \
                (("consistent", "placebo p >= .10") if bb == 3 else ("indeterminate", "placebo_adjacent_band"))
            dist = [pair_value(s, term)[0] for s in GRID.loc[(GRID.stage == "4_placebo_dist") & (GRID.outcome == GI.loc[c["origin_spec"], "outcome"]), "spec_id"]]
            ps = [bench_p("S", r)[0] if False else r["p_cluster"] for r in dist if r is not None]
            rec["placebo_distribution"] = {"n": len(ps), "share_p_lt_05": float(np.mean([p < 0.05 for p in ps])) if ps else None,
                                           "estimates_q05_q50_q95": [float(np.quantile([r["estimate"] for r in dist if r is not None], q)) for q in (0.05, 0.5, 0.95)] if ps else None}
            records.append(rec)
            continue
        fail_sign = sign_assess and not sign_ok
        fail_inf = (bb is not None) and ((bb - pubband >= 2) or (pubband == 3 and bb <= 1))
        fail_mag = z > 2.0
        if fail_sign or fail_inf or fail_mag:
            if rec["uncertain"]["n_pass_all"] > 0:
                rec["outcome"], rec["reason"] = "indeterminate", "label_sensitive"
            else:
                rec["outcome"], rec["reason"] = "discrepant_candidate", ";".join(x for x, f in (("sign", fail_sign), ("inference_2band", fail_inf), ("magnitude", fail_mag)) if f)
        elif z > 0.5:
            rec["outcome"], rec["reason"] = "indeterminate", "magnitude_grey_zone"
        elif ncat == "mismatch":
            rec["outcome"], rec["reason"] = "indeterminate", "sample_reconstruction"
        elif bb is not None and bb > pubband and (hb is not None and hb <= pubband):
            rec["outcome"], rec["reason"] = "fragile_inference", f"benchmark band weaker by {bb - pubband}; HC1 band not weaker"
        elif bb is not None and bb > pubband:
            rec["outcome"], rec["reason"] = "indeterminate", f"inference_one_band_weaker under both HC1 and benchmark ({bb - pubband})"
        else:
            rec["outcome"], rec["reason"] = "consistent", "origin sign, magnitude, inference and N criteria met"
        if rec["outcome"] in ("consistent", "fragile_inference") and pubband <= 1 and rec["uncertain"]["share_keep_sign_p05"] is not None \
                and rec["uncertain"]["share_keep_sign_p05"] < 0.8:
            rec["label_sensitive_flag"] = "treating uncertain rows as equivalent would give fragile (share keeping sign and p<.05 below 0.8)"
        records.append(rec)
        continue
    if kind in ("descriptive_group", "descriptive_summary", "count"):
        pub = c["published"]
        specs = [c["origin_spec"]] + c.get("uncertain_specs", [])
        D = {k: desc[k] for k in "ABC"}

        def dval(spec, block, var, group, stat):
            vals = {}
            for k in "ABC":
                try:
                    vals[k] = float(D[k].loc[(spec, block, var, group, stat)])
                except KeyError:
                    pass
            for p, q in (("A", "B"), ("A", "C"), ("B", "C")):
                if p in vals and q in vals and (abs(vals[p] - vals[q]) <= 1e-9 + 1e-6 * abs(vals[q]) or (math.isnan(vals[p]) and math.isnan(vals[q]))):
                    return vals[p], p + q
            return None, "none:" + ",".join(f"{k}={v}" for k, v in vals.items())

        def rdev(x, s):
            lo, hi, v = interval(s)
            if x is None:
                return None
            d = 0.0 if lo <= x <= hi else min(abs(x - lo), abs(x - hi))
            return d / abs(v) if v != 0 else (0.0 if d == 0 else float("inf"))

        def cat(r):
            return None if r is None else "match" if r == 0 else "near" if r <= 0.01 else "moderate" if r <= 0.10 else "mismatch"

        if kind == "descriptive_group":
            vars_ = c["term"].split("|")
            readings = []
            for spec in specs:
                for vv in vars_:
                    v = vv.replace("d_", "change_") if vv.startswith("d_") else vv
                    got = {s: dval(spec, "an01", v, "", s) for s in ("treated_mean", "control_mean", "difference", "p_welch", "p_equal_variance", "n_treated", "n_control")}
                    vals = {k: g[0] for k, g in got.items()}
                    devs = {"treated_mean": rdev(vals["treated_mean"], pub["mean_treated"]), "control_mean": rdev(vals["control_mean"], pub["mean_control"]),
                            "difference": rdev(vals["difference"], pub["difference"])}
                    plo, phi, _ = interval(pub["p"])
                    pw = vals["p_welch"]
                    p_ok = pw is not None and (plo <= pw <= phi or band(pw) in (band(max(plo, 0)), band(phi)))
                    readings.append({"spec": spec, "variable": v, "values": vals, "rel_dev": devs, "cats": {k: cat(x) for k, x in devs.items()}, "p_ok": p_ok,
                                     "pairs": {k: g[1] for k, g in got.items()}})
            o = readings[0]
            okrow = lambda r: all(x in ("match", "near") for x in r["cats"].values()) and r["p_ok"]
            mism = lambda r: any(r["cats"][k] == "mismatch" for k in ("treated_mean", "control_mean"))
            if None in o["cats"].values():
                outcome, reason = "indeterminate", "unavailable_criterion"
            elif okrow(o):
                outcome, reason = "consistent", "means, difference and p band reproduced"
            elif mism(o) and all(mism(r) for r in readings):
                outcome, reason = "discrepant_candidate", "group mean mismatch at origin and every reading"
            else:
                outcome, reason = "indeterminate", "measurement" + ("; label_sensitive" if any(okrow(r) for r in readings[1:]) else "")
            rec.update(outcome=outcome, reason=reason, readings=readings, published=pub)
        elif kind == "descriptive_summary":
            v = c["term"]
            readings = []
            for spec in specs:
                vals = {s: dval(spec, "an02", v, "", s)[0] for s in ("mean", "sd", "median", "min", "max")}
                devs = {s: rdev(vals[s], pub[s]) if s in pub and pub[s] is not None else None for s in vals}
                readings.append({"spec": spec, "values": vals, "rel_dev": devs, "cats": {k: cat(x) for k, x in devs.items()}})
            o = readings[0]
            okrow = lambda r: r["cats"]["mean"] in ("match", "near") and r["cats"]["median"] in ("match", "near")
            if o["cats"]["mean"] is None:
                outcome, reason = "indeterminate", "unavailable_criterion"
            elif okrow(o):
                outcome, reason = "consistent", "mean and median reproduced"
            elif o["cats"]["mean"] == "mismatch" and all(r["cats"]["mean"] == "mismatch" for r in readings):
                outcome, reason = "discrepant_candidate", "mean mismatch at origin and every reading"
            else:
                outcome, reason = "indeterminate", "measurement" + ("; label_sensitive" if any(okrow(r) for r in readings[1:]) else "")
            rec.update(outcome=outcome, reason=reason, readings=readings, published=pub)
        else:
            smp = {"full": "full", "boundary_B1": "boundary_B1", "timing": "timing"}[c["term"]]
            got = {}
            for g, key in (("treated", "1"), ("control", "0")):
                val = None
                for vname in {"full": ["full", "U", "universe"], "boundary_B1": ["boundary_B1", "B1", "boundary"], "timing": ["timing"]}[smp]:
                    x, _ = dval(c["origin_spec"], "an09", vname, key, "n_counties")
                    if x is not None:
                        val = x
                        break
                got[g] = val
            got["all"] = None if None in got.values() else got["treated"] + got["control"]
            devs = {g: (None if got[g] is None else abs(got[g] - float(pub[g])) / float(pub[g])) for g in ("treated", "control", "all")}
            if None in devs.values():
                outcome, reason = "indeterminate", "unavailable_criterion"
            elif all(d == 0 for d in devs.values()):
                outcome, reason = "consistent", "counts exact"
            elif all(d <= 0.01 for d in devs.values()):
                outcome, reason = "indeterminate", "near"
            else:
                outcome, reason = "discrepant_candidate", "county counts differ by more than 1%"
            rec.update(outcome=outcome, reason=reason, values=got, rel_dev=devs, published=pub)
        records.append(rec)
        continue
    if kind == "plot_points":
        pts = c["published"]
        by = c.get("origin_specs_by_point")
        res = []
        for key, readings in pts.items():
            if by:
                spec = by[key]
                term = {"AN12": "treat", "AN13": "post_treat", "AN14": "post_treat"}[GI.loc[spec, "analysis"]]
            else:
                spec, term = c["origin_spec"], f"treat_{key}"
            if not by and key == "2007":
                val, pq = 0.0, "reference_year"
            else:
                row, pq, _ = pair_value(spec, term)
                val = None if row is None else float(row["estimate"])
            ivs = []
            for r in readings:
                lo, hi = r["interval"]
                w = hi - lo
                ivs.append((lo - 0.5 * w, hi + 0.5 * w))
            m = None if val is None else any(a <= val <= b for a, b in ivs)
            res.append({"point": key, "spec": spec, "estimate": val, "pair": pq, "widened_intervals": ivs, "match": m,
                        "readings": [(r["reader"], r["value"]) for r in readings]})
        scored = [r for r in res if r["match"] is not None]
        share = sum(r["match"] for r in scored) / len(scored) if scored else None
        outcome = "consistent" if share is not None and share >= 0.8 else "indeterminate"
        rec.update(outcome=outcome, reason=f"share of read points matched = {share:.2f}" if share is not None else "no scorable points",
                   reason_code=None if outcome == "consistent" else "plot_reading", points=res)
        if "alt_estimator_specs_by_point" in c:
            alt = []
            for key in pts:
                row, pq, _ = pair_value(c["alt_estimator_specs_by_point"][key], "treat")
                alt.append({"point": key, "estimate": None if row is None else float(row["estimate"])})
            rec["alt_estimator_M2"] = alt
        records.append(rec)
        continue

# paper level
foc = [r for r in records if r["paper_focal"]]
oc = [r["outcome"] for r in foc]
if any(o in ("indeterminate", "not_attemptable") for o in oc):
    paper = "indeterminate"
elif sum(o == "discrepant" for o in oc) >= len(oc) / 2:
    paper = "not reproduced"
elif any(o in ("discrepant", "fragile") for o in oc) or any(r["outcome"] == "discrepant" for r in records):
    paper = "partially reproduced"
elif all(o == "consistent" for o in oc):
    paper = "fully reproduced"
elif all(o in ("consistent", "fragile_inference") for o in oc):
    paper = "consistent with fragile inference (not mapped)"
else:
    paper = "unmapped: " + ",".join(sorted(set(oc)))
summary = {"claims": len(records), "outcomes": pd.Series([r["outcome"] for r in records]).value_counts().to_dict(),
           "paper_focal_outcomes": {r["unit"]: r["outcome"] + " (" + str(r.get("reason")) + ")" for r in foc},
           "paper_level_pre_review": paper,
           "note": "discrepant_candidate outcomes require adversarial review before becoming discrepant; paper level is recomputed after review"}
json.dump(records, open(os.path.join(OUT, "claim_scores.json"), "w"), indent=1, default=lambda x: None if (isinstance(x, float) and math.isnan(x)) else (x.item() if hasattr(x, "item") else str(x)))
json.dump(summary, open(os.path.join(OUT, "summary.json"), "w"), indent=1)
print(json.dumps(summary, indent=1))
