"""Score agreed implementation results against sealed targets under sealed/scoring_rules.json v1.

Run: ~/.venv/bin/python -I checks/scripts/score.py <run_dir>
Outputs in <run_dir>/scoring/.
"""
import json, sys, os, csv, math
sys.path.insert(0, "checks/scripts")
from scoring_lib import *

RUN = sys.argv[1]
T = json.load(open("sealed/targets_v2.json"))
OUT = f"{RUN}/scoring"
os.makedirs(OUT, exist_ok=True)

# ---- agreed values from the implementation comparison
agreed = {}
status = {}
for r in csv.DictReader(open(f"{RUN}/comparison/implementation_agreement_all.csv")):
    agreed[(r["spec"], r["key"])] = r["agreed"]
    status[(r["spec"], r["key"])] = r["status"]


def val(spec, *key):
    k = "|".join(map(str, key))
    v = agreed.get((spec, k))
    if v in (None, ""):
        return None
    try:
        return float(v)
    except ValueError:
        return v


def impl_ok(spec, *key):
    return status.get((spec, "|".join(map(str, key)))) in ("all_three_agree", "pair_agree")


YEARS = ["1976", "1991", "2006"]
PAIRS = {"P1": ("1976", "1991"), "P2": ("1991", "2006"), "P3": ("1976", "2006")}
FACT = {"K1": "leisure", "K2": "intrinsic", "K3": "altruistic", "K4": "social", "K5": "extrinsic"}
RQ = {"RQ1": "K1", "RQ2": "K5", "RQ3": "K2", "RQ4": "K3", "RQ5": "K4"}
NPUB = {k: v["value"] for k, v in T["N"].items()}

# ---- N branch
nbranch = []
for form, ds in (("f3", "f3"), ("f4", "f4")):
    for y in YEARS:
        rows = val("S00", "rows", f"y{y}_{form}")
        mg = val("S00", "mgn", y) if form == "f4" else None
        nbranch.append({"cell": f"{form}_{y}", "published_N": NPUB[f"{form}_{y}"], "rows_read": rows,
                        "match_rows": rows == NPUB[f"{form}_{y}"], "multigroup_n": mg})
json.dump(nbranch, open(f"{OUT}/n_branch.json", "w"), indent=1)

# ---- focal latent contrasts
TEXT_ALT = {"K2_P1": 0.05}  # intrinsic 1976-1991: table -.05, text .05 (both readers, forensics)


def score_contrast(spec, K, P, dpub_override=None):
    t = T["d"][f"{K}_{P}"]
    dpub = t["value"] if dpub_override is None else dpub_override
    iv = interval(dpub, t["decimals"])
    a, b = PAIRS[P]
    se = se_d(dpub, NPUB[f"f4_{a}"], NPUB[f"f4_{b}"])
    d = val(spec, "con", K, P, "d_eq")
    ok = impl_ok(spec, "con", K, P, "d_eq")
    if d is None:
        return {"outcome": "not_attemptable", "subcode": "no_estimate"}
    s = sign_check(d, iv, se)
    m, z = magnitude_band(d, iv, se)
    out, sub = claim_outcome(ok, {"sign": s, "magnitude": m})
    return {"d_rec": d, "d_pub": dpub, "pub_interval": iv, "se_d_derived": se, "distance_in_se": z, "sign": s, "magnitude": m,
            "outcome": out, "subcode": sub, "sign_mismatch": s == MISMATCH,
            "relative_effect": (d - dpub) / abs(dpub) if abs(dpub) >= 0.10 else None}


focal = []
for K in FACT:
    for P in PAIRS:
        r0 = score_contrast("S00", K, P)
        rw = score_contrast("S01", K, P)
        rec = {"claim": f"{FACT[K]} {P}", "factor": K, "pair": P, "years": PAIRS[P], **{f"S00_{k}": v for k, v in r0.items()},
               "S01_d": rw.get("d_rec"), "S01_outcome": rw["outcome"], "S01_subcode": rw["subcode"],
               "label_sensitive": rw["outcome"] != r0["outcome"]}
        if f"{K}_{P}" in TEXT_ALT:
            ra = score_contrast("S00", K, P, TEXT_ALT[f"{K}_{P}"])
            rec["text_value_outcome"] = ra["outcome"]
            if ra["outcome"] != r0["outcome"]:
                rec["S00_outcome"], rec["S00_subcode"] = "indeterminate", "inconsistent_targets (table -.05 vs text .05)"
            rwa = score_contrast("S01", K, P, TEXT_ALT[f"{K}_{P}"])
            if rwa["outcome"] != rw["outcome"]:
                rec["S01_outcome"], rec["S01_subcode"] = "indeterminate", "inconsistent_targets (table -.05 vs text .05)"
            rec["label_sensitive"] = rec["S01_outcome"] != rec["S00_outcome"]
        # native inference (descriptive, not audited)
        rec["native_wald_p_two_sided"] = val("S00", "con", K, P, "p")
        rec["native_wald_z"] = val("S00", "con", K, P, "z")
        rec["Delta"] = val("S00", "con", K, P, "Delta")
        # uncertain branches and post-estimation variants (reported, never change the outcome)
        rec["uncertain"] = {s: val(s, "con", K, P, "d_eq") for s in ("S01", "S02", "S03", "S04", "S05", "S06")}
        rec["uncertain"].update({f"S00_{f}": val("S00", "con", K, P, f) for f in ("d_df", "g", "d_glass", "d_obs")})
        rec["checks"] = {"CHK1_d_eq": val("CHK1", "con", K, P, "d_eq"), "CHK2_d_eq": val("CHK2", "con", K, P, "d_eq")}
        rec["S06_robust_p"] = val("S06", "con", K, P, "p")
        focal.append(rec)

# ---- RQ and item-level claims
rq = {}
for name, K in RQ.items():
    cs = [f for f in focal if f["factor"] == K]
    rq[name] = rq_outcome([(c["S00_outcome"], c["S00_subcode"]) for c in cs], [c.get("S00_sign_mismatch", False) for c in cs])
    rqw = rq_outcome([(c["S01_outcome"], c["S01_subcode"]) for c in cs], [False] * 3)
    rq[name] = {"factor": K, "outcome": rq[name][0], "subcode": rq[name][1], "S01_outcome": rqw[0]}

items = []
FORM3 = {"V3222", "V3223", "V3224", "V3225", "V3226", "V3227"}
for V, tv in T["items"].items():
    form = "f3" if V in FORM3 else "f4"
    crit, cells, inconsistent = {}, [], False
    for P, (a, b) in PAIRS.items():
        ma, mb = tv[f"mean_{a}"], tv[f"mean_{b}"]
        sa, sb = tv[f"sd_{a}"], tv[f"sd_{b}"]
        div = diff_interval(interval(ma["value"], ma["decimals"]), interval(mb["value"], mb["decimals"]))
        se = math.sqrt(sa["value"] ** 2 / NPUB[f"{form}_{a}"] + sb["value"] ** 2 / NPUB[f"{form}_{b}"])
        drec = val("S00", "itest", V, P, "diff")
        prec = val("S00", "itest", V, P, "p")
        trec = val("S00", "itest", V, P, "t")
        tp = tv[f"t_{P}"]
        sg = sign_check(drec, div, se)
        mg, z = magnitude_band(drec, div, se)
        inf, bd = inference_check(prec, tp["stars"])
        # target consistency: sign of printed t vs printed mean-difference interval
        t_sign_conflict = (div[0] > 0 and tp["value"] < 0) or (div[1] < 0 and tp["value"] > 0)
        alt_sign = None
        if t_sign_conflict:
            alt_sign = AGREE if (trec is not None and (trec > 0) == (tp["value"] > 0)) else MISMATCH
            if alt_sign != sg:
                inconsistent = True
        star3 = None
        if tp["stars"] >= 3:
            star3 = prec is not None and prec < 0.001
        crit[f"{P}_sign"], crit[f"{P}_magnitude"], crit[f"{P}_inference"] = sg, mg, inf
        cells.append({"pair": P, "diff_rec": drec, "diff_pub_interval": div, "se_derived": se, "distance_in_se": z, "sign": sg, "magnitude": mg,
                      "t_rec": trec, "p_rec": prec, "t_pub": tp["printed"], "stars_pub": tp["stars"], "inference": inf, "band_distance": bd,
                      "printed_t_sign_conflicts_with_means": t_sign_conflict, "p_lt_001_check": star3,
                      "welch_p": val("S00", "itest", V, P, "welch_p"), "S01_weighted_z_p": val("S01", "itest", V, P, "zp")})
    ok = all(impl_ok("S00", "itest", V, P, "diff") and impl_ok("S00", "itest", V, P, "t") for P in PAIRS)
    out, sub = claim_outcome(ok, crit, inconsistent_targets=inconsistent)
    if inconsistent and out == "discrepant_provisional":
        out, sub = "indeterminate", "inconsistent_targets (printed t sign vs printed means): " + sub
    desc = {y: {"mean_rec": val("S00", "item", V, y, "mean"), "mean_pub": tv[f"mean_{y}"]["printed"], "sd_rec": val("S00", "item", V, y, "sd"),
                "sd_pub": tv[f"sd_{y}"]["printed"], "pct_rec": val("S00", "item", V, y, "pct"), "pct_pub": tv[f"pct_{y}"]["printed"],
                "n_rec": val("S00", "item", V, y, "n")} for y in YEARS}
    items.append({"item": V, "form": form, "tier": "descriptive (work-centrality set: tier uncertain)" if V in FORM3 else "descriptive",
                  "outcome": out, "subcode": sub, "pairs": cells, "by_year": desc})

# ---- diagnostic claims
def fit(spec, m, g, f):
    return val(spec, "fit", m, g, f)


md = lambda n, f: val("S00", "mdiff", n, f)
diag = []
diag.append({"claim": "Configural invariance model fits adequately", "outcome": "indeterminate", "subcode": "decision_rule_not_stated (no numeric adequacy cutoff in article)",
             "reconstructed": {f: fit("S00", "M1", "MG", f) for f in ("chisq", "df", "rmsea", "srmr", "tli", "cfi")}})
dcfi = md("M2-M1", "dcfi"); pchi = md("M2-M1", "p")
diag.append({"claim": "Metric invariance supported (delta CFI < .002; chi-square difference ns)",
             "criteria": {"delta_cfi_decision": AGREE if dcfi < 0.002 else MISMATCH,
                          "chi_square_ns": "not_assessable: published 'ns' conflicts with printed 39.58 on 26 df (p ~ .043); outcome depends on which is used"},
             "outcome": "consistent" if dcfi < 0.002 else "discrepant_provisional",
             "subcode": "delta CFI decision agrees; chi-square criterion not assessable (inconsistent targets)",
             "reconstructed": {"delta_chisq": md("M2-M1", "dchisq"), "delta_df": md("M2-M1", "ddf"), "p": pchi, "delta_cfi": dcfi}})
dcfi = md("M3-M2", "dcfi")
diag.append({"claim": "Full scalar invariance not supported (delta CFI > .002; significant chi-square difference)",
             "outcome": "consistent" if (dcfi > 0.002 and md("M3-M2", "p") < 0.01) else "discrepant_provisional", "subcode": "decision rule .002 and p < .01",
             "reconstructed": {"delta_chisq": md("M3-M2", "dchisq"), "delta_df": md("M3-M2", "ddf"), "p": md("M3-M2", "p"), "delta_cfi": dcfi}})
dcfi = md("M4-M2", "dcfi")
# scoring_rules.json diagnostic rule: within the rounding interval of the .002 threshold ([.0015, .0025]) -> indeterminate
diag.append({"claim": "Partial scalar invariance accepted (delta CFI vs metric model < .002, despite significant chi-square difference)",
             "outcome": "consistent" if dcfi < 0.0015 else "indeterminate" if dcfi <= 0.0025 else "discrepant_provisional",
             "subcode": "delta CFI decision agrees" if dcfi < 0.002 else "delta CFI exceeds the article's .002 cutoff (decision reverses)",
             "reconstructed": {"delta_chisq": md("M4-M2", "dchisq"), "delta_df": md("M4-M2", "ddf"), "p": md("M4-M2", "p"), "delta_cfi": dcfi}})
diag.append({"claim": "Equality of latent means rejected", "outcome": "consistent" if md("M5-M4", "p") < 0.01 else "discrepant_provisional",
             "subcode": "chi-square difference p < .01", "reconstructed": {"delta_chisq": md("M5-M4", "dchisq"), "delta_df": md("M5-M4", "ddf"), "p": md("M5-M4", "p"), "delta_cfi": md("M5-M4", "dcfi")}})
for m, lab in (("form3", "Form 3 two-factor model fits inadequately in every year"), ("form4_7", "Seven-factor Form 4 model fits adequately in every year"), ("form4_5", "Five-factor Form 4 model fits adequately in every year")):
    diag.append({"claim": lab, "outcome": "indeterminate", "subcode": "decision_rule_not_stated (no numeric adequacy cutoff in article)",
                 "reconstructed": {y: {f: fit("S00", m, y, f) for f in ("chisq", "df", "rmsea", "srmr", "tli", "cfi")} for y in YEARS}})
al = {sc: {y: val("S00", "alpha", sc, y) for y in YEARS} for sc in ("K6", "K7")}
mx = max(v for d in al.values() for v in d.values())
diag.append({"claim": "Security and influence scales: no coefficient alpha exceeds .50", "outcome": "consistent" if mx <= 0.505 else "discrepant_provisional",
             "subcode": "max reconstructed alpha vs .50 (rounding .505)", "reconstructed": al})
diag.append({"claim": "Five-factor alphas (said to be in Table 1, absent)", "outcome": "indeterminate", "subcode": "target_missing",
             "reconstructed": {sc: {y: val("S00", "alpha", sc, y) for y in YEARS} for sc in ("K1", "K2", "K3", "K4", "K5", "C1")}})

# descriptive fit comparison against Table 2
fitcmp = []
MAPM = {"Form 3: 2 factor": "form3", "Form 4: 7 factor": "form4_7", "Form 4: 5 factor": "form4_5"}
QF = {"chi-square": "chisq", "df": "df", "RMSEA": "rmsea", "SRMSR": "srmr", "TLI": "tli", "CFI": "cfi"}
for f in T["fit"]:
    q = QF.get(f["quantity"])
    model = f["model"]
    y = next((yy for yy in YEARS if yy in str(f["group"])), None)
    if q and model in MAPM and y:
        rec = fit("S00", MAPM[model], y, q)
    elif q and model.startswith("Model "):
        rec = fit("S00", "M" + model.split()[1].rstrip(":"), "MG", q)
    else:
        rec = None
    fitcmp.append({"model": model, "group": f["group"], "quantity": f["quantity"], "published": f["printed"], "reconstructed": rec})

lower = [i["outcome"] for i in items if i["form"] == "f4"] + [d["outcome"] for d in diag]
paper = paper_outcome([(v["outcome"], v["subcode"]) for v in rq.values()], lower)
lower_with_f3 = lower + [i["outcome"] for i in items if i["form"] == "f3"]
paper_f3 = paper_outcome([(v["outcome"], v["subcode"]) for v in rq.values()], lower_with_f3)
paper_w = paper_outcome([(v["S01_outcome"], "") for v in rq.values()], lower)

res = {"run": RUN, "scoring_rules": "sealed/scoring_rules.json v1", "n_branch": nbranch, "focal_contrasts": focal, "research_questions": rq,
       "item_claims": items, "diagnostic_claims": diag, "fit_descriptive": fitcmp,
       "paper": {"S00": paper, "S01_weighted_co_origin": paper_w, "with_form3_items_as_lower_tier": paper_f3},
       "notes": ["Focal inference not audited (SEM).", "Magnitude uses derived SE (adaptation), not a published SE.",
                 "Specification fragility not assessed (empty equivalent set).", "discrepant_provisional requires adversarial review and human confirmation."]}
json.dump(res, open(f"{OUT}/scores.json", "w"), indent=1, default=str)
print(json.dumps({"rq": rq, "paper": res["paper"]}, indent=1))
from collections import Counter
print("focal", Counter((f["S00_outcome"], f["S00_subcode"]) for f in focal))
print("items", Counter((i["outcome"], i["subcode"].split(":")[0]) for i in items))
print("diag", [(d["claim"][:40], d["outcome"]) for d in diag])
print("N", nbranch)
