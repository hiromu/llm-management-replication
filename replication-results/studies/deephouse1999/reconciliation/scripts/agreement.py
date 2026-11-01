"""Initial reader agreement (reconciliation_rules_v1.md). Matching pairs were set by the frozen
matching rules and are listed explicitly so every decision is auditable."""
import json, sys, csv
from collections import Counter
from pathlib import Path

ST = Path(sys.argv[1])
R = ST / "readers"

def claims(r):
    d = json.load(open(R / r / "initial_v1/out/claim_map.json"))
    d = d.get("claims", d) if isinstance(d, dict) else d
    return {c["claim_id"]: c for c in d}

def levels(r):
    d = json.load(open(R / r / "initial_v1/out/specification_space.json"))
    return {l["level_id"]: (a["axis_id"], l["label"]) for a in d["axes"] for l in a["levels"]}

# Rule 1: numerical claims matched by table/model/row; hypothesis claims by label.
CLAIM_PAIRS = [("C1", "C1"), ("C2", "C2"), ("C2b", "C4"), ("C3", "C3"), ("C3b", "C5"),
               ("C4", "C6"), ("C5", "C7"), ("C6", "C8"), ("C7", "C9"), ("C8", "C15"),
               ("C9", "C13"), ("C10", "C16"), ("C11", "C11"), ("C12", "C10"), ("C13", "C12"),
               ("C14", "C17"), ("C15", "C18")]
CLAIM_UNMATCHED_A = ["C3c"]
CLAIM_UNMATCHED_B = ["C14", "C19", "C20", "C21", "C22", "C23", "C24"]

# Rule 4/5: axes matched by decision content, levels by codeable rule.
LEVEL_PAIRS = [("S1.a", "A01_O"), ("S1.b", "A01_RSSD"), ("S1.c", "A01_MN"),
               ("S2.a", "A02_O"), ("S3.a", "A03_O"),
               ("V1.a", "A09_O"), ("V1.b", "A09_QUARTERS"),
               ("V2.a", "A04_O"), ("V2.b", "A04_ANALYTIC"),
               ("V3.a", "A08_O"), ("V3.b", "A08_FIVE"), ("V3.c", "A08_ENDPOINT"),
               ("V5.a", "A11_O"), ("V5.b", "A11_ACCEPT"), ("V6.a", "A13_O"),
               ("V7.a", "A14_BROAD"), ("V7.b", "A14_O"), ("V7.c", "A14_RESIDUAL"),
               ("V8.a", "A12_O"), ("V8.b", "A12_FARMLAND"),
               ("V9.a", "A16_O"), ("V9.b", "A16_POP"),
               ("V10.a", "A10_DOMESTIC"), ("V10.b", "A10_O"),
               ("V12.a", "A17_O"), ("V12.b", "A17_DEC"), ("V12.c", "A17_LOCAL"),
               ("F2.a", "A19_O"), ("F2.b", "A19_BANKCLUSTER"),
               ("E1.a", "A18_O"), ("E1.b", "A18_MEAN1")]

def ac1(pairs, cats):
    n = len(pairs)
    if n < 2:
        return None, "undefined: fewer than 2 items"
    pa = sum(a == b for a, b in pairs) / n
    pi = {k: (sum(a == k for a, _ in pairs) + sum(b == k for _, b in pairs)) / (2 * n) for k in cats}
    observed = [k for k in cats if pi[k] > 0]
    if len(observed) < 2:
        return None, "undefined: only one category observed"
    pe = sum(p * (1 - p) for p in pi.values()) / (len(cats) - 1)
    return (pa - pe) / (1 - pe), None

ca, cb = claims("fable"), claims("astra")
la, lb = levels("fable"), levels("astra")

def dirnorm(d):
    d = str(d or "none")
    return d.split(":")[0].strip() if d.startswith("other") else d

rows, out = [], {}
TIERS = ["focal", "identification_inference_diagnostic", "robustness", "descriptive", "nuisance_control"]
tier_pairs = [(ca[a]["tier"], cb[b]["tier"]) for a, b in CLAIM_PAIRS]
dir_pairs = [(dirnorm(ca[a]["direction_claimed"]), dirnorm(cb[b]["direction_claimed"])) for a, b in CLAIM_PAIRS]
for (a, b), t, d in zip(CLAIM_PAIRS, tier_pairs, dir_pairs):
    rows.append({"type": "claim", "id_A": a, "id_B": b, "value_A": t[0], "value_B": t[1], "agree": t[0] == t[1],
                 "direction_A": d[0], "direction_B": d[1], "direction_agree": d[0] == d[1]})
for a in CLAIM_UNMATCHED_A:
    rows.append({"type": "claim", "id_A": a, "id_B": "", "value_A": ca[a]["tier"], "value_B": "", "agree": "unmatched"})
for b in CLAIM_UNMATCHED_B:
    rows.append({"type": "claim", "id_A": "", "id_B": b, "value_A": "", "value_B": cb[b]["tier"], "agree": "unmatched"})

LABELS = ["origin", "equivalent", "non_equivalent", "uncertain"]
lab_pairs = [(la[a][1], lb[b][1]) for a, b in LEVEL_PAIRS]
for (a, b), l in zip(LEVEL_PAIRS, lab_pairs):
    rows.append({"type": "level_label", "id_A": a, "id_B": b, "value_A": l[0], "value_B": l[1], "agree": l[0] == l[1]})
matched_A = {a for a, _ in LEVEL_PAIRS}; matched_B = {b for _, b in LEVEL_PAIRS}
for k, (ax, lab) in la.items():
    if k not in matched_A:
        rows.append({"type": "level_label", "id_A": k, "id_B": "", "value_A": lab, "value_B": "", "agree": "unmatched"})
for k, (ax, lab) in lb.items():
    if k not in matched_B:
        rows.append({"type": "level_label", "id_A": "", "id_B": k, "value_A": "", "value_B": lab, "agree": "unmatched"})

DIRS = sorted({x for p in dir_pairs for x in p})
for name, pairs, cats in [("claim_tier", tier_pairs, TIERS), ("claim_direction", dir_pairs, DIRS),
                          ("level_label", lab_pairs, LABELS)]:
    v, why = ac1(pairs, cats)
    out[name] = {"matched_n": len(pairs), "agree_n": sum(a == b for a, b in pairs),
                 "raw_agreement": round(sum(a == b for a, b in pairs) / len(pairs), 4),
                 "gwet_ac1": None if v is None else round(v, 4), "undefined_reason": why,
                 "categories": cats, "joint_counts": {f"{a}|{b}": n for (a, b), n in Counter(pairs).items()}}
out["unmatched"] = {"claims_A_only": CLAIM_UNMATCHED_A, "claims_B_only": CLAIM_UNMATCHED_B,
                    "levels_A_only": sorted(k for k in la if k not in matched_A),
                    "levels_B_only": sorted(k for k in lb if k not in matched_B),
                    "claims_A_total": len(ca), "claims_B_total": len(cb),
                    "levels_A_total": len(la), "levels_B_total": len(lb)}

with open(ST / "reconciliation/agreement_ledger.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["type", "id_A", "id_B", "value_A", "value_B", "agree",
                                      "direction_A", "direction_B", "direction_agree"])
    w.writeheader(); w.writerows(rows)
json.dump(out, open(ST / "reconciliation/initial_agreement.json", "w"), indent=1)
print(json.dumps({k: {kk: vv for kk, vv in v.items() if kk not in ("joint_counts", "categories")} for k, v in out.items()}, indent=1))
