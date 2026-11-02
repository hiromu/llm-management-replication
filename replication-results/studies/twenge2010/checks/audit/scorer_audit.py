"""Audit: independent re-derivation of the scorer arithmetic (does not import checks/scripts).

Focal contrasts (all 15) and five item claims are recomputed from sealed/targets_v2.json, the agreed values in
the comparison CSV and the rule text in sealed/scoring_rules.json, then compared with scoring/scores.json.
Also tabulates the delta-CFI decision across branches and baselines for the adversarial review.
Run from the study root: ~/.venv/bin/python -I checks/audit/scorer_audit.py
"""
import csv, json, math

RUN = "runs/run_20261028T035346Z"
T = json.load(open("sealed/targets_v2.json"))
S = json.load(open(f"{RUN}/scoring/scores.json"))
ag = {(r["spec"], r["key"]): r["agreed"] for r in csv.DictReader(open(f"{RUN}/comparison/implementation_agreement_all.csv"))}
st = {(r["spec"], r["key"]): r["status"] for r in csv.DictReader(open(f"{RUN}/comparison/implementation_agreement_all.csv"))}
g = lambda s, k: float(ag[(s, k)]) if ag.get((s, k)) not in (None, "") else None
N = {k: v["value"] for k, v in T["N"].items()}
PAIRS = {"P1": ("1976", "1991"), "P2": ("1991", "2006"), "P3": ("1976", "2006")}


def iv(v, k):
    h = 0.5 * 10 ** -k
    return v - h, v + h


def dist(x, lo, hi):
    return 0.0 if lo <= x <= hi else (lo - x if x < lo else x - hi)


def band(z):
    return "agree" if z <= 2 else "grey" if z <= 4 else "mismatch"


def sign_rule_text(x, lo, hi, z):
    """Literal rule text: mismatch only if opposite sign and distance beyond the grey bound (4 SE); otherwise agree."""
    if lo <= 0 <= hi:
        return "not_assessable"
    opposite = (x < 0) if lo > 0 else (x > 0)
    return "mismatch" if (opposite and z > 4) else "agree"


out = {"focal": [], "items": [], "deviations": []}
by = {f["claim"]: f for f in S["focal_contrasts"]}
for f in S["focal_contrasts"]:
    K, P = f["factor"], f["pair"]
    t = T["d"][f"{K}_{P}"]
    lo, hi = iv(t["value"], t["decimals"])
    a, b = PAIRS[P]
    n1, n2 = N[f"f4_{a}"], N[f"f4_{b}"]
    se = math.sqrt((n1 + n2) / (n1 * n2) + t["value"] ** 2 / (2 * (n1 + n2)))
    d = g("S00", f"con|{K}|{P}|d_eq")
    z = dist(d, lo, hi) / se
    m = band(z)
    s_txt = sign_rule_text(d, lo, hi, z)
    rec = {"contrast": f"{K}_{P}", "d_rec": d, "interval": [lo, hi], "se_d": se, "z": z, "magnitude_auditor": m, "magnitude_scorer": f["S00_magnitude"],
           "sign_auditor_rule_text": s_txt, "sign_scorer": f["S00_sign"], "se_match": abs(se - f["S00_se_d_derived"]) < 1e-12,
           "z_match": abs(z - f["S00_distance_in_se"]) < 1e-9, "impl_status": st[("S00", f"con|{K}|{P}|d_eq")],
           "outcome_scorer": f["S00_outcome"], "subcode_scorer": f["S00_subcode"]}
    crit = [c for c in (s_txt, m) if c != "not_assessable"]
    oc = "discrepant_provisional" if "mismatch" in crit else "indeterminate" if "grey" in crit else "consistent"
    if f"{K}_{P}" == "K2_P1":  # text value .05 versus table -.05
        lo2, hi2 = iv(0.05, 2)
        se2 = math.sqrt((n1 + n2) / (n1 * n2) + 0.05 ** 2 / (2 * (n1 + n2)))
        z2 = dist(d, lo2, hi2) / se2
        oc2 = "discrepant_provisional" if (band(z2) == "mismatch" or sign_rule_text(d, lo2, hi2, z2) == "mismatch") else "consistent"
        rec["text_value_z"] = z2
        rec["text_value_outcome_auditor"] = oc2
        if oc2 != oc:
            oc = "indeterminate"
    rec["outcome_auditor"] = oc
    rec["outcome_match"] = oc == f["S00_outcome"]
    if s_txt != f["S00_sign"]:
        out["deviations"].append(f"{K}_{P}: scorer sign criterion '{f['S00_sign']}' vs literal rule text '{s_txt}' (outcome unaffected: {rec['outcome_match']})")
    out["focal"].append(rec)

# RQ re-derivation
RQ = {"RQ1": "K1", "RQ2": "K5", "RQ3": "K2", "RQ4": "K3", "RQ5": "K4"}
rq = {}
for name, K in RQ.items():
    outs = [r["outcome_auditor"] for r in out["focal"] if r["contrast"].startswith(K)]
    rq[name] = "consistent" if all(o == "consistent" for o in outs) else (
        "discrepant_provisional" if sum(o == "discrepant_provisional" for o in outs) >= 2 else "indeterminate")
out["rq_auditor"] = rq
out["rq_match"] = all(rq[k] == S["research_questions"][k]["outcome"] for k in rq)

# five item claims
for V in ("V4236", "V4230", "V4239", "V4241", "V3227"):
    tv = T["items"][V]
    form = "f3" if V.startswith("V32") else "f4"
    sc = next(i for i in S["item_claims"] if i["item"] == V)
    cells = []
    for P, (a, b) in PAIRS.items():
        ma, mb, sa, sb = tv[f"mean_{a}"], tv[f"mean_{b}"], tv[f"sd_{a}"], tv[f"sd_{b}"]
        la, ha = iv(ma["value"], ma["decimals"])
        lb, hb = iv(mb["value"], mb["decimals"])
        lo, hi = lb - ha, hb - la
        se = math.sqrt(sa["value"] ** 2 / N[f"{form}_{a}"] + sb["value"] ** 2 / N[f"{form}_{b}"])
        d = g("S00", f"itest|{V}|{P}|diff")
        p = g("S00", f"itest|{V}|{P}|p")
        z = dist(d, lo, hi) / se
        stars = tv[f"t_{P}"]["stars"]
        rb = 1 if p < .01 else 2 if p < .05 else 3 if p < .10 else 4
        pub = {1} if stars >= 2 else {2} if stars == 1 else {3, 4}
        bd = 0 if (stars >= 1 and rb < min(pub)) else min(abs(rb - x) for x in pub)
        sccell = next(c for c in sc["pairs"] if c["pair"] == P)
        cells.append({"pair": P, "diff_rec": d, "interval": [lo, hi], "se": se, "z": z, "magnitude": band(z), "p_band": rb, "published_bands": sorted(pub),
                      "band_distance": bd, "inference": "mismatch" if bd >= 2 else "agree",
                      "matches_scorer": (abs(se - sccell["se_derived"]) < 1e-12 and abs(z - sccell["distance_in_se"]) < 1e-9 and band(z) == sccell["magnitude"]
                                         and (("mismatch" if bd >= 2 else "agree") == sccell["inference"]) and bd == sccell["band_distance"]),
                      "printed_t": tv[f"t_{P}"]["printed"], "t_rec": g("S00", f"itest|{V}|{P}|t"), "p_lt_001": (p < .001) if stars >= 3 else None})
    out["items"].append({"item": V, "scorer_outcome": sc["outcome"], "scorer_subcode": sc["subcode"], "cells": cells,
                         "all_cells_match": all(c["matches_scorer"] for c in cells)})

# delta-CFI decision across branches, and the diagnostic thresholds
dc = {}
for s in ("S00", "S01", "S02", "S03", "S04", "S05", "S06", "CHK2"):
    dc[s] = {"dcfi_M2_M4": g(s, "mdiff|M4-M2|dcfi"), "ddf": g(s, "mdiff|M4-M2|ddf"), "dchisq": g(s, "mdiff|M4-M2|dchisq"),
             "cfi_M1": g(s, "fit|M1|MG|cfi")}
    dc[s]["outside_rounding_of_.002_(>.0025)"] = dc[s]["dcfi_M2_M4"] > 0.0025
out["dcfi_branches"] = dc
al = {s: {f"{k}_{y}": g(s, f"alpha|{k}|{y}") for k in ("K6", "K7") for y in ("1976", "1991", "2006")} for s in ("S00", "S01", "S03")}
al.update({s: {f"{k}_{y}": g(s, f"alpha|{k}|{y}") for k in ("K6", "K7") for y in ("1976", "1991", "2006")} for s in ("S07a", "S07b")})
out["alpha_branches"] = al
json.dump(out, open("checks/audit/scorer_audit.json", "w"), indent=1)
print("focal outcome matches", sum(r["outcome_match"] for r in out["focal"]), "/15; se/z match", all(r["se_match"] and r["z_match"] for r in out["focal"]))
print("rq match", out["rq_match"], rq)
print("items", [(i["item"], i["all_cells_match"]) for i in out["items"]])
print("deviations", out["deviations"])
for r in out["focal"]:
    if r["outcome_scorer"] != "consistent":
        print(r["contrast"], round(r["d_rec"], 4), [round(x, 3) for x in r["interval"]], round(r["z"], 3), r["magnitude_auditor"], r["sign_auditor_rule_text"], r["sign_scorer"], r["outcome_auditor"], r.get("text_value_z"))
print(json.dumps(dc, indent=0))
