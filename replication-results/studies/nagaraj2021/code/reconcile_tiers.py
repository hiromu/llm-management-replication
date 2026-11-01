"""Initial reader agreement on claim tiers, before any clarification round.

Matching rule set (fixed before comparing labels): one ledger unit per Table 1 row, Table 2 row,
regression column in Tables 3-7 (Table 6 split into the Treat and Distance terms) and figure panel or series.
Each unit maps to the reader claim that covers it; a reader claim covering several units is reused.
Text-summary claims that span several tables are kept as structural extras, outside the unit ledger.
"""
import csv, json, os
from collections import Counter

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
O = {x["claim_id"]: x for x in json.load(open(os.path.join(STUDY, "readers/opus/initial_v1/claim_map.json")))}
A = {x["claim_id"]: x for x in json.load(open(os.path.join(STUDY, "readers/astra/initial_v1/claim_map.json")))}

T1 = ["Contributions", "Follow-on Contributions", "Contributors", "Error-Score", "Owner-Contributions",
      "D Population", "D Households", "D Unemployed Pop.", "D Educ. Population", "D Male Population (18-45)", "D Income per Capita"]
T1_O = ["C_T1_contrib", "C_T1_followon", "C_T1_contributors", "C_T1_error", "C_T1_owner"] + ["C_T1_balance"] * 5 + ["C_T1_income"]
T2 = ["Total Contributions", "Total Follow-on Contributions", "Contributors", "Distant Follow-on", "Incremental Follow-On",
      "New Contributors", "Old Contributors", "Low Ownership Contributions", "High Ownership Contributions", "Owner-Contributions",
      "Treat", "Post", "Year", "Quarter", "Population", "Households", "Population Density", "Per-Capita Income"]
T2_O = ["C_T2_median"] * 3 + ["C_T2_other"] * 6 + ["C_T2_owner"] + ["C_T2_other"] * 8

units = []
units += [(f"T1|{r}", T1_O[i], f"T1R{i + 1}") for i, r in enumerate(T1)]
units += [(f"T2|{r}", T2_O[i], f"T2R{i + 1}") for i, r in enumerate(T2)]
units += [(f"T3|({c})", f"C_T3_{c}", f"T3C{c}") for c in range(1, 7)]
units += [(f"T4|({c})", f"C_T4_{c}", f"T4C{c}") for c in range(1, 7)]
units += [(f"T5A|({c})", f"C_T5A_{c}", f"T5AC{c}") for c in range(1, 9)]
units += [(f"T5B|({c})", f"C_T5B_{c}", f"T5BC{c}") for c in range(1, 9)]
units += [(f"T6|({c}) Treat", f"C_T6_{c}", f"T6C{c}") for c in range(1, 4)]
units += [(f"T6|({c}) Distance", f"C_T6_dist_{c}", f"T6C{c}D") for c in range(1, 4)]
units += [(f"T7|({c})", f"C_T7_{c}", f"T7C{c}") for c in range(1, 8)]
units += [("F1|a", "C_F1_a", "F1A"), ("F1|b", "C_F1_b", "F1B"), ("F2|a", "C_F2_a", "F2A"), ("F2|b", "C_F2_b", "F2B"),
          ("F3|a(i)", "C_F3_a", "F3AI"), ("F3|a(ii)", "C_F3_a", "F3AII"), ("F3|b(i)", "C_F3_b", "F3BI"), ("F3|b(ii)", "C_F3_b", "F3BII"),
          ("F4|follow-on", "C_F4_fo", "F4F"), ("F4|contributors", "C_F4_users", "F4U"), ("F5|follow-on", "C_F5", "F5"),
          ("F6|a follow-on", "C_F6_a", "F6AF"), ("F6|a contributors", "C_F6_a", "F6AU"), ("F6|b", "C_F6_b", "F6B")]

rows = []
for u, oc, ac in units:
    to, ta = O[oc]["tier"], A[ac]["tier"]
    rows.append({"unit": u, "opus_claim": oc, "astra_claim": ac, "opus_tier": to, "astra_tier": ta, "agree": to == ta,
                 "reconciled_tier": to if to == ta else "uncertain:" + "|".join(sorted({to, ta}))})


def ac1(pairs, cats):
    n = len(pairs)
    pa = sum(a == b for a, b in pairs) / n
    pi = {k: (sum(a == k for a, _ in pairs) + sum(b == k for _, b in pairs)) / (2 * n) for k in cats}
    pe = sum(p * (1 - p) for p in pi.values()) / (len(cats) - 1)
    return {"n": n, "observed_agreement": round(pa, 4), "chance_pe": round(pe, 4),
            "ac1": None if pe == 1 else round((pa - pe) / (1 - pe), 4)}


CATS = ["focal", "identification_or_inference_diagnostic", "robustness", "descriptive", "nuisance"]
pairs = [(r["opus_tier"], r["astra_tier"]) for r in rows]
focal = [(a == "focal", b == "focal") for a, b in pairs]
out = {"rule_set": __doc__.strip(), "units": len(rows),
       "tier_5cat": ac1(pairs, CATS), "focal_vs_other": ac1(focal, [True, False]),
       "by_block": {b: ac1([(r["opus_tier"], r["astra_tier"]) for r in rows if r["unit"].split("|")[0] == b], CATS)
                    for b in sorted({r["unit"].split("|")[0] for r in rows})},
       "disagreements": [r for r in rows if not r["agree"]],
       "structural_extras": {"opus_text_claims": ["C_TXT_intro", "C_TXT_abstract", "C_TXT_333"],
                             "astra_text_claims": ["INTRO_ACTIVITY", "INTRO_QUALITY"],
                             "opus_extra_units": ["C_T2_sample (panel dimensions note)"],
                             "granularity": "Opus grouped Table 1 balance rows, Table 2 rows, Figure 3 sub-panels and Figure 6(a) series; Astra listed them separately"},
       "counts": {"opus_claims": len(O), "astra_claims": len(A)}}
os.makedirs(os.path.join(STUDY, "reconciliation"), exist_ok=True)
with open(os.path.join(STUDY, "reconciliation/claim_ledger_initial.csv"), "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0]))
    w.writeheader()
    w.writerows(rows)
json.dump(out, open(os.path.join(STUDY, "reconciliation/agreement_initial.json"), "w"), indent=1)
print(json.dumps({k: out[k] for k in ("units", "tier_5cat", "focal_vs_other")}, indent=1))
for b, v in out["by_block"].items():
    print(b, v["n"], v["observed_agreement"], v["ac1"])
for r in out["disagreements"]:
    print("DISAGREE", r["unit"], r["opus_tier"], r["astra_tier"])
