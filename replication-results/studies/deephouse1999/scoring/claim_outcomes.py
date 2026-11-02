"""Step 3: claim-level and paper-level outcomes under scoring_rules_v1.json (mechanical)."""
import json, sys
from pathlib import Path
import numpy as np
import pandas as pd
sys.path.insert(0, str(Path(__file__).parent))

ST = Path(sys.argv[1]); RUN = sys.argv[2]
OUT = ST / "scoring" / RUN
T = pd.read_csv(OUT / "term_scores.csv")
U = pd.read_csv(OUT / "grid_focal_universe.csv")
F = pd.read_csv(OUT / "f_test_scores.csv")
N = json.load(open(OUT / "n_eval.json"))["n_eval"]
tg = json.load(open(ST / "readers/fable/initial_v1/out/sealed_targets.json"))["targets"]

from rules_lib import score_term

CLAIMS = {
    "H3_strategic_balance": {"tier": "focal_primary", "terms": [("M3", "SD2"), ("M3", "SD")]},
    "H2_conformity_vs_H1": {"tier": "focal_secondary", "terms": [("M2", "SD")]},
    "M3_without_first_order": {"tier": "robustness", "terms": [("M3_SQ", "SD2")]},
}
for m in ["M1", "M2", "M3"]:
    for t in ["MS", "TER", "RMG", "lag", "intercept"]:
        CLAIMS[f"control_{t}_{m}"] = {"tier": "nuisance_control", "terms": [(m, t)]}

def combine(outs):
    if any(o == "discrepant_candidate" for o in outs): return "discrepant_candidate"
    if all(o == "consistent" for o in outs): return "consistent"
    return "grey"

pubrow = {}
for x in tg:
    if x["table"] == "Table 2" and x.get("coefficient") is not None:
        pubrow[({"Model 1": "M1", "Model 2": "M2", "Model 3": "M3"}[x["model"]],
                {"Intercept": "intercept", "Strategic Deviation^2": "SD2", "Strategic Deviation": "SD", "Market Share": "MS",
                 "Total Expense Ratio": "TER", "Real Market Growth": "RMG", "Relative ROA(t-1)": "lag"}[x["row_term"]])] = x
xs = next(x for x in tg if x["target_id"] == "TX.3noLin.sd2")
pubrow[("M3_SQ", "SD2")] = {**xs, "stars_or_inequality": "*", "printed_precision": {"coefficient": 3, "se": 4}}

def uncertain_consistent(terms):
    """Is there any uncertain-set specification in which every term of the claim scores consistent?"""
    specs = set(U[U.label == "uncertain"].spec_id)
    hits = []
    for s in sorted(specs):
        outs = []
        for m, t in terms:
            r = U[(U.spec_id == s) & (U.model == m) & (U.term == t)]
            if r.empty: outs = None; break
            x = pubrow[(m, t)]
            outs.append(score_term(x["coefficient"], x["published_se"], x["stars_or_inequality"],
                                   x["printed_precision"]["coefficient"], x["printed_precision"]["se"],
                                   float(r.estimate.iloc[0]), float(r.se.iloc[0]), float(r.p.iloc[0]))["term_outcome"])
        if outs and all(o == "consistent" for o in outs):
            hits.append(s)
    return hits

n_outside = all(v["band"] == "outside" for v in N.values())
records = []
for cid, c in CLAIMS.items():
    per = {}
    for o in ["O_A", "O_B"]:
        outs = [T[(T.origin == o) & (T.model == m) & (T.term == t)].term_outcome.iloc[0] for m, t in c["terms"]]
        per[o] = combine(outs)
    reasons = []
    if per["O_A"] != per["O_B"]:
        outcome = "indeterminate"; reasons.append("origin_label_sensitive")
    elif per["O_A"] == "consistent":
        outcome = "consistent"
        if n_outside: reasons.append("coverage_qualification_N_outside_tolerance")
    elif per["O_A"] == "grey":
        outcome = "indeterminate"; reasons.append("grey_zone")
    else:
        outcome = "indeterminate"
        if n_outside: reasons.append("sample_construction_N_outside_tolerance")
        uc = uncertain_consistent(c["terms"])  # v1.1: applies to every claim, per scoring_rules_v1.json (audit task 5)
        if uc: reasons.append(f"label_sensitive({len(uc)} uncertain readings consistent)")
        reasons.append("discrepancy_not_confirmed: adversarial review and human confirmation required")
    records.append({"claim": cid, "tier": c["tier"], "terms": ";".join(f"{m}:{t}" for m, t in c["terms"]),
                    "outcome_O_A": per["O_A"], "outcome_O_B": per["O_B"], "claim_outcome": outcome,
                    "reason_codes": "|".join(reasons)})
C = pd.DataFrame(records)
# F-test diagnostics
for comp in ["M2 vs M1", "M3 vs M1", "M3 vs M2"]:
    g = F[F.comparison == comp]
    sa, sb = bool(g[g.origin == "O_A"].sig_agree.iloc[0]), bool(g[g.origin == "O_B"].sig_agree.iloc[0])
    C.loc[len(C)] = {"claim": f"F_{comp.replace(' ', '_')}", "tier": "identification_inference_diagnostic", "terms": comp,
                     "outcome_O_A": "consistent" if sa else "differs", "outcome_O_B": "consistent" if sb else "differs",
                     "claim_outcome": "consistent" if sa and sb else "indeterminate",
                     "reason_codes": "significance only; magnitude not audited" + ("" if sa and sb else "|origin_label_sensitive")}
C.to_csv(OUT / "claim_outcomes.csv", index=False)

primary = C[C.claim == "H3_strategic_balance"].iloc[0]
lower_disc = C[(C.claim != "H3_strategic_balance") & (C.outcome_O_A == "discrepant_candidate") & (C.outcome_O_B == "discrepant_candidate")].claim.tolist()
paper = {"primary_claim_outcome": primary.claim_outcome, "primary_reasons": primary.reason_codes,
         "paper_outcome": primary.claim_outcome if primary.claim_outcome != "consistent" else ("fully reproduced" if not lower_disc else "partially reproduced"),
         "rule": "scoring_rules_v1.json focal_structure.paper_rule; indeterminate primary focal -> paper indeterminate",
         "secondary_claim_outcome": C[C.claim == "H2_conformity_vs_H1"].iloc[0].claim_outcome,
         "lower_tier_discrepant_candidates_both_origins": lower_disc,
         "fragility": "not assessed (no substantive equivalent set)",
         "fragile_inference": "not assessable (benchmark inference not audited)",
         "n": N}
json.dump(paper, open(OUT / "paper_outcome.json", "w"), indent=1)
pd.set_option("display.width", 250)
print(C.to_string()); print(json.dumps(paper, indent=1))
