"""Step 2 of downstream scoring: compare the agreeing implementations with the sealed published
targets under registry/scoring_rules_v1.json. Deterministic; no model judgement."""
import json, sys, math
from pathlib import Path
import numpy as np
import pandas as pd
sys.path.insert(0, str(Path(__file__).parent))

ST = Path(sys.argv[1]); RUN = sys.argv[2]
REF = "impl_B"  # member of the agreeing B|C pair; A agrees with both at origins
RD = ST / "runs" / RUN
OUT = ST / "scoring" / RUN
rules = json.load(open(ST / "registry/scoring_rules_v1.json"))
grid = json.load(open(ST / "reconciliation/grid_v1.json"))
tg = json.load(open(ST / "readers/fable/initial_v1/out/sealed_targets.json"))["targets"]
nb = json.load(open(ST / "readers/fable/initial_v1/out/sealed_n_branch.json"))

res = pd.read_csv(RD / REF / "out/spec_results.csv")
res["term"] = res["term"].replace({"(Intercept)": "intercept", "Intercept": "intercept"})
ftest = pd.read_csv(RD / REF / "out/f_tests.csv")

MODEL = {"Model 1": "M1", "Model 2": "M2", "Model 3": "M3"}
TERM = {"Intercept": "intercept", "Strategic Deviation^2": "SD2", "Strategic Deviation": "SD",
        "Market Share": "MS", "Total Expense Ratio": "TER", "Real Market Growth": "RMG",
        "Relative ROA(t-1)": "lag"}

from rules_lib import band, pub_band, score_term

def fit(spec, model, term):
    r = res[(res.spec_id == spec) & (res.model == model) & (res.term == term)]
    if r.empty or r.iloc[0]["status"] != "ok":
        return None
    r = r.iloc[0]
    return float(r.estimate), float(r.se), float(r.p_two_sided), int(r.n)

rows = []
for x in tg:
    if x["table"] != "Table 2" or x.get("coefficient") is None:
        continue
    m, t = MODEL[x["model"]], TERM[x["row_term"]]
    for o in ["O_A", "O_B"]:
        f = fit(o, m, t)
        rec = score_term(x["coefficient"], x["published_se"], x["stars_or_inequality"],
                         x["printed_precision"]["coefficient"], x["printed_precision"]["se"], *f[:3])
        rows.append({"target_id": x["target_id"], "origin": o, "model": m, "term": t, "n": f[3], **rec})
# Model 3 without first-order term (text): stars absent, 'negative and significant' -> treat as p<.05 claim
x = next(x for x in tg if x["target_id"] == "TX.3noLin.sd2")
for o in ["O_A", "O_B"]:
    f = fit(o, "M3_SQ", "SD2")
    rec = score_term(x["coefficient"], x["published_se"], "*", 3, 4, *f[:3])
    rec["pub_stars"] = "text: negative and significant (mapped to p<.05)"
    rows.append({"target_id": x["target_id"], "origin": o, "model": "M3_SQ", "term": "SD2", "n": f[3], **rec})
terms = pd.DataFrame(rows)
terms.to_csv(OUT / "term_scores.csv", index=False)

# N branch
n_pub = 960
nrec = {o: int(res[(res.spec_id == o) & (res.model == "M3")].iloc[0].n) for o in ["O_A", "O_B"]}
n_eval = {o: {"n_rec": n, "n_pub": n_pub, "rel_diff": (n - n_pub) / n_pub,
              "band": "consistent" if abs(n - n_pub) / n_pub <= .05 else "grey" if abs(n - n_pub) / n_pub <= .15 else "outside"}
          for o, n in nrec.items()}

# F tests (significance only)
fpub = {"M2 vs M1": 30.4, "M3 vs M1": 84.4, "M3 vs M2": 134.1}
fr = []
for o in ["O_A", "O_B"]:
    for c, fv in fpub.items():
        r = ftest[(ftest.spec_id == o) & (ftest.comparison == c)].iloc[0]
        fr.append({"origin": o, "comparison": c, "pub_F": fv, "pub_sig": "p<.001 (text)", "rec_F": r.F,
                   "rec_p": r.p_upper, "sig_agree": bool(r.p_upper < .001)})
fdf = pd.DataFrame(fr); fdf.to_csv(OUT / "f_test_scores.csv", index=False)

# Uncertain / non-equivalent sets for focal terms
labels = {}
for a in grid["axes"]:
    for l in a["levels"]:
        labels[l["id"]] = (l["label"], l.get("origin_of", []))
FOCAL = [("M2", "SD"), ("M3", "SD"), ("M3", "SD2")]
pub = {(MODEL[x["model"]], TERM[x["row_term"]]): x["coefficient"] for x in tg if x["table"] == "Table 2" and x.get("coefficient") is not None}
dis = json.load(open(OUT / "implementation_agreement.json"))
universe = []
for _, r in res[res.status == "ok"].drop_duplicates(["spec_id", "model", "term"]).iterrows():
    sid = r.spec_id
    if sid in ("O_A", "O_B") or "__" not in sid:
        continue
    o, lvl = sid.split("__", 1)
    lab, oo = labels.get(lvl, ("unknown", []))
    if lab == "origin":
        lab = "uncertain"  # the other reader's origin level, relative to this origin
    universe.append({"spec_id": sid, "origin": o, "level": lvl, "label": lab, "model": r.model, "term": r.term,
                     "estimate": r.estimate, "se": r.se, "p": r.p_two_sided, "n": r.n, "hash": r.sample_hash})
U = pd.DataFrame(universe)
U.to_csv(OUT / "grid_focal_universe.csv", index=False)
summ = []
for lab in ["uncertain", "non_equivalent", "equivalent_algebraic_check"]:
    for m, t in FOCAL:
        g = U[(U.label == lab) & (U.model == m) & (U.term == t)].copy()
        g["key"] = g["hash"] + g["estimate"].round(10).astype(str)
        g = g.drop_duplicates("key")
        if g.empty:
            continue
        hyp = -1  # hypothesised sign: H2 negative for M2 SD; H3 negative SD2; M3 SD positive
        if (m, t) == ("M3", "SD"):
            hyp = 1
        b = pub[(m, t)]
        summ.append({"label": lab, "model": m, "term": t, "n_specs_dedup": len(g),
                     "sign_share_published": float((np.sign(g.estimate) == np.sign(b)).mean()),
                     "sig05_hyp_share": float(((g.p < .05) & (np.sign(g.estimate) == hyp)).mean()),
                     "median": float(g.estimate.median()), "min": float(g.estimate.min()), "max": float(g.estimate.max()),
                     "published": b, "published_rank_pct": float((g.estimate < b).mean()),
                     "any_term_consistent_with_published": None})
S = pd.DataFrame(summ); S.to_csv(OUT / "multiverse_summary.csv", index=False)

# Influence ranges (primary bank-year, secondary bank), from the reference implementation
inf = pd.read_csv(RD / REF / "out/influence.csv")
inf["term"] = inf["term"].replace({"(Intercept)": "intercept"})
ir = []
for o in ["O_A", "O_B"]:
    for m, t in FOCAL:
        for dt in ["bank_year", "bank"]:
            g = inf[(inf.origin == o) & (inf.model == m) & (inf.term == t) & (inf.deletion_type == dt)]
            ok = g[g.status == "ok"]
            ir.append({"origin": o, "model": m, "term": t, "deletion_type": dt, "fits": len(g), "ok": len(ok),
                       "failed": int((g.status != "ok").sum()),
                       "est_min": ok.estimate.min(), "est_max": ok.estimate.max(),
                       "p_min": ok.p_two_sided.min(), "p_max": ok.p_two_sided.max(),
                       "sign_changes": int((np.sign(ok.estimate) != np.sign(fit(o, m, t)[0])).sum()),
                       "p_ge_05": int((ok.p_two_sided >= .05).sum())})
IR = pd.DataFrame(ir); IR.to_csv(OUT / "influence_summary.csv", index=False)

json.dump({"n_eval": n_eval, "reference_impl": REF}, open(OUT / "n_eval.json", "w"), indent=1)
pd.set_option("display.width", 250)
print(terms[["target_id", "origin", "model", "term", "pub_coef", "pub_se", "pub_stars", "rec_coef", "rec_se", "rec_p2",
             "sign", "inference", "d_se_units", "magnitude", "term_outcome"]].to_string())
print(json.dumps(n_eval, indent=1))
print(fdf.to_string())
print(S.to_string())
print(IR.to_string())
