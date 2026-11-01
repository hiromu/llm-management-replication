"""Apply the adversarial review (audit/adversarial_v1/review.json) to the frozen v1.1 claim scores.
Overturned candidates become indeterminate with the review's reason code; surviving candidates become
discrepant_not_fully_verified, because the only available reviewer is the same model family as implementation A
(workflow: withhold the fully verified discrepancy claim). The paper-level rule of scoring_rules_v1 is then applied."""
import json, os, sys
STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUN = sys.argv[1]
scores = json.load(open(os.path.join(RUN, "scoring/claim_scores.json")))
rev = json.load(open(os.path.join(STUDY, "audit/adversarial_v1/review.json")))
units = {u["unit"]: u for u in rev["units"]}
final = []
for r in scores:
    f = {"unit": r["unit"], "kind": r["kind"], "tier": r["tier"], "paper_focal": r["paper_focal"], "pre_review_outcome": r["outcome"],
         "pre_review_reason": r.get("reason"), "outcome": r["outcome"], "reason": r.get("reason")}
    if r["outcome"] == "discrepant_candidate":
        v = units.get(r["unit"])
        if v is None:
            f["outcome"], f["reason"] = "indeterminate", "not_reviewed"
        elif v["verdict"] == "overturned":
            f["outcome"], f["reason"] = "indeterminate", v["reason_code"] + " (adversarial review)"
        else:
            f["outcome"], f["reason"] = "discrepant_not_fully_verified", r.get("reason") + "; survived adversarial review by a same-family reviewer"
    final.append(f)
foc = [f for f in final if f["paper_focal"]]
oc = [f["outcome"] for f in foc]
disc = lambda o: o.startswith("discrepant")
if any(o in ("indeterminate", "not_attemptable") for o in oc):
    paper = "indeterminate"
elif sum(disc(o) for o in oc) >= len(oc) / 2:
    paper = "not reproduced"
elif any(disc(o) or o == "fragile" for o in oc) or any(disc(f["outcome"]) for f in final):
    paper = "partially reproduced"
elif all(o == "consistent" for o in oc):
    paper = "fully reproduced"
else:
    paper = "unmapped"
from collections import Counter
summ = {"outcomes": dict(Counter(f["outcome"] for f in final)), "paper_focal": {f["unit"]: f"{f['outcome']} ({f['reason']})" for f in foc},
        "paper_level": paper, "review_limitation": "Adversarial review used Claude Opus 5.5, the family of implementation A; no third model family was available. Discrepancies are reported as not fully verified. No human review was performed."}
json.dump(final, open(os.path.join(RUN, "scoring/final_outcomes.json"), "w"), indent=1)
json.dump(summ, open(os.path.join(RUN, "scoring/final_summary.json"), "w"), indent=1)
print(json.dumps(summ, indent=1))
