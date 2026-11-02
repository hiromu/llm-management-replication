"""Audit task 5: independent re-scoring of term_scores.csv and claim_outcomes.csv from registry/scoring_rules_v1.json.

Written from the rule text (not importing scoring/rules_lib.py). Published values are taken from the auditor's own
transcription (a1), estimates from impl_B spec_results.csv (B and C agree exactly at the origins).
Run: ~/.venv/bin/python -I checks/audit_v1/a5_scoring_audit.py <STUDY>
"""
import json, sys, math
from pathlib import Path
import pandas as pd, numpy as np

ST = Path(sys.argv[1]); OUT = ST / "checks/audit_v1"
PUB = {  # (model, term): coef, se, stars, prec_coef, prec_se
    ("M1", "intercept"): (0.929, 0.169, "***", 3, 3), ("M1", "MS"): (-0.576, 0.138, "***", 3, 3),
    ("M1", "TER"): (-9.948, 2.001, "***", 3, 3), ("M1", "RMG"): (0.014, 0.004, "***", 3, 3), ("M1", "lag"): (0.369, 0.028, "***", 3, 3),
    ("M2", "intercept"): (1.164, 0.172, "***", 3, 3), ("M2", "SD"): (-0.020, 0.004, "***", 3, 3), ("M2", "MS"): (-0.093, 0.161, "", 3, 3),
    ("M2", "TER"): (-10.601, 1.974, "***", 3, 3), ("M2", "RMG"): (0.016, 0.004, "***", 3, 3), ("M2", "lag"): (0.361, 0.027, "***", 3, 3),
    ("M3", "intercept"): (0.511, 0.171, "**", 3, 3), ("M3", "SD2"): (-0.006, 0.001, "***", 3, 3), ("M3", "SD"): (0.170, 0.017, "***", 3, 3),
    ("M3", "MS"): (-0.457, 0.155, "**", 3, 3), ("M3", "TER"): (-15.387, 1.895, "***", 3, 3), ("M3", "RMG"): (0.018, 0.003, "***", 3, 3),
    ("M3", "lag"): (0.403, 0.026, "***", 3, 3), ("M3_SQ", "SD2"): (-0.001, 0.0001, "*", 3, 4),  # text 'negative and significant' -> p<.05
}
BANDS = ["p<.01", ".01-.05", ".05-.10", ">=.10"]
def band_idx(p): return 0 if p < .01 else 1 if p < .05 else 2 if p < .10 else 3

def score(key, est, se, p):
    b, s, stars, pb_, ps_ = PUB[key]
    hb, hs = 0.5 * 10 ** -pb_, 0.5 * 10 ** -ps_
    lo, hi = b - hb, b + hb
    sign = "not_assessed" if lo <= 0 <= hi else ("agree" if math.copysign(1, est) == math.copysign(1, b) else "opposite")
    rb = band_idx(p)
    if stars in ("***", "**"): pb = 0
    elif stars == "*": pb = 1
    else: pb = None
    if pb is None:  # published non-significant: newly significant is a contradiction
        inf = "agree" if rb >= 2 else ("contradiction_p<.05_one_band" if rb == 1 else "contradiction_p<.01")
        inf_bad = rb == 0; inf_weaker1 = rb == 1
    else:
        k = rb - pb
        inf = "agree" if k <= 0 else "one_band_weaker" if k == 1 else "two_plus_bands_weaker"
        inf_bad = k >= 2; inf_weaker1 = k == 1
    dist = 0.0 if lo <= est <= hi else min(abs(est - lo), abs(est - hi))
    d = dist / (s + hs)
    mag = "consistent" if d <= 1.5 else "grey" if d <= 3.0 else "outside"
    if sign == "opposite" or inf_bad or mag == "outside": out = "discrepant_candidate"
    elif sign in ("agree", "not_assessed") and inf == "agree" and mag == "consistent": out = "consistent"
    else: out = "grey"
    return dict(sign=sign, rec_band=BANDS[rb], inference=inf, d=d, magnitude=mag, outcome=out)

R = pd.read_csv(ST / "runs/run_v1/impl_B/out/spec_results.csv"); R["term"] = R["term"].replace({"(Intercept)": "intercept"})
T = pd.read_csv(ST / "scoring/run_v1/term_scores.csv")
rows = []
for (m, t) in PUB:
    for o in ["O_A", "O_B"]:
        r = R[(R.spec_id == o) & (R.model == m) & (R.term == t)].iloc[0]
        a = score((m, t), r.estimate, r.se, r.p_two_sided)
        s = T[(T.origin == o) & (T.model == m) & (T.term == t)].iloc[0]
        rows.append(dict(origin=o, model=m, term=t, est=r.estimate, p=r.p_two_sided, audit_d=a["d"], scored_d=s.d_se_units,
                         audit_mag=a["magnitude"], scored_mag=s.magnitude, audit_inf=a["inference"], scored_inf=s.inference,
                         audit_outcome=a["outcome"], scored_outcome=s.term_outcome,
                         match=(a["outcome"] == s.term_outcome and abs(a["d"] - s.d_se_units) < 1e-9 and a["magnitude"] == s.magnitude)))
A = pd.DataFrame(rows); A.to_csv(OUT / "a5_term_rescore.csv", index=False)
print(A.to_string()); print("all match:", A.match.all())

# claim-level logic re-derivation
N = {"O_A": 1260, "O_B": 1255}; n_out = all(abs(n - 960) / 960 > .15 for n in N.values())
def comb(xs):
    return "discrepant_candidate" if "discrepant_candidate" in xs else "consistent" if all(x == "consistent" for x in xs) else "grey"
claims = {"H3_strategic_balance": [("M3", "SD2"), ("M3", "SD")], "H2_conformity_vs_H1": [("M2", "SD")], "M3_without_first_order": [("M3_SQ", "SD2")]}
for m in ["M1", "M2", "M3"]:
    for t in ["MS", "TER", "RMG", "lag", "intercept"]: claims[f"control_{t}_{m}"] = [(m, t)]
U = pd.read_csv(ST / "scoring/run_v1/grid_focal_universe.csv")
def unc_consistent(terms):
    hits = []
    for sid, g in U[U.label == "uncertain"].groupby("spec_id"):
        outs = []
        for (m, t) in terms:
            r = g[(g.model == m) & (g.term == t)]
            if r.empty: outs = None; break
            outs.append(score((m, t), r.estimate.iloc[0], r.se.iloc[0], r.p.iloc[0])["outcome"])
        if outs and all(o == "consistent" for o in outs): hits.append(sid)
    return hits
C = pd.read_csv(ST / "scoring/run_v1/claim_outcomes.csv").set_index("claim")
cl = []
for c, terms in claims.items():
    per = {o: comb([A[(A.origin == o) & (A.model == m) & (A.term == t)].audit_outcome.iloc[0] for m, t in terms]) for o in ["O_A", "O_B"]}
    if per["O_A"] != per["O_B"]: out = "indeterminate(origin_label_sensitive)"
    elif per["O_A"] == "consistent": out = "consistent"
    elif per["O_A"] == "grey": out = "indeterminate(grey_zone)"
    else: out = "indeterminate(" + ("N_outside;" if n_out else "") + "pending_review)"
    hits = unc_consistent(terms) if c in ("H3_strategic_balance", "H2_conformity_vs_H1", "M3_without_first_order") else []
    cl.append(dict(claim=c, audit_O_A=per["O_A"], audit_O_B=per["O_B"], audit_outcome=out, scored_outcome=C.loc[c, "claim_outcome"],
                   scored_reasons=C.loc[c, "reason_codes"], uncertain_specs_all_terms_consistent=";".join(hits),
                   match=(per["O_A"] == C.loc[c, "outcome_O_A"] and per["O_B"] == C.loc[c, "outcome_O_B"] and out.split("(")[0] == C.loc[c, "claim_outcome"])))
CL = pd.DataFrame(cl); CL.to_csv(OUT / "a5_claim_rederive.csv", index=False)
print(CL.to_string()); print("claims all match:", CL.match.all())

# How many uncertain specs make each H3 term consistent separately (context)
ctx = []
for (m, t) in [("M3", "SD"), ("M3", "SD2"), ("M2", "SD"), ("M3", "TER"), ("M3", "intercept")]:
    g = U[(U.label == "uncertain") & (U.model == m) & (U.term == t)] if t in ("SD", "SD2") else None
    if g is None:
        g = pd.read_csv(ST / "runs/run_v1/impl_B/out/spec_results.csv"); g["term"] = g["term"].replace({"(Intercept)": "intercept"})
        g = g[(g.model == m) & (g.term == t) & (g.status == "ok") & g.spec_id.str.contains("__")]
        g = g.rename(columns={"p_two_sided": "p"})
        labs = {l["id"]: l["label"] for a in json.load(open(ST / "reconciliation/grid_v1.json"))["axes"] for l in a["levels"]}
        g = g[g.level_id.map(labs).isin(["uncertain", "origin"])]
    outs = [score((m, t), r.estimate, r.se, r.p)["outcome"] for r in g.itertuples()]
    ctx.append(dict(model=m, term=t, n_uncertain_specs=len(outs), consistent=outs.count("consistent"), grey=outs.count("grey"),
                    discrepant_candidate=outs.count("discrepant_candidate"), est_min=g.estimate.min(), est_max=g.estimate.max()))
pd.DataFrame(ctx).to_csv(OUT / "a5_uncertain_set_term_context.csv", index=False)
print(pd.DataFrame(ctx).to_string())
