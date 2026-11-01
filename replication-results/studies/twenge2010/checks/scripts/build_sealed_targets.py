"""Build sealed/targets_v1.json with structured keys from the reconciled reader transcriptions.

Both readers' Table 1 and Table 2 transcriptions agree on every printed number (reconciliation/agreement_initial.json),
so Reader A's records are used as the base and each is keyed for scoring. Run from the study root with
~/.venv/bin/python -I checks/scripts/build_sealed_targets.py
"""
import json, re

ts = json.load(open("readers/fable/initial/targets.json"))["targets"]

ITEM_KEYS = [  # (substring of printed row text, source variable)
    ("establish roots", "V4239"), ("make friends", "V4233"), ("directly helpful", "V4229"), ("high status", "V4226"),
    ("interesting to do", "V4227"), ("worthwhile to society", "V4235"), ("time for other things", "V4238"),
    ("free of supervision", "V4240"), ("look up to", "V4244"), ("secure future", "V4241"), ("contact with a lot", "V4245"),
    ("earn a good deal", "V4230"), ("uses your skills", "V4234"), ("difficult and challenging", "V4247"),
    ("advancement and promotion", "V4228"), ("not go out of date", "V4232"), ("learn new things", "V4242"),
    ("see the results", "V4225"), ("pretend to be", "V4243"), ("decision making", "V4237"), ("vacation", "V4236"),
    ("be creative", "V4231"), ("easy pace", "V4246"), ("very central part", "V3224"), ("forget about after", "V3222"),
    ("do my best", "V3225"), ("same job for most", "V3226"), ("enough money", "V3227"), ("nothing more than making", "V3223"),
]
FACTORS = {"Leisure": "K1", "Intrinsic": "K2", "Altruistic": "K3", "Social": "K4", "Extrinsic": "K5"}
PAIRS = {"1976 vs 1991": "P1", "1991 vs 2006": "P2", "1976 vs 2006": "P3"}


def item_key(text):
    hits = [v for s, v in ITEM_KEYS if s.lower() in text.lower()]
    assert len(hits) == 1, (text, hits)
    return hits[0]


def num(s):
    s = str(s).replace("−", "-").replace("–", "-").replace(",", "")
    m = re.match(r"\s*\(?\s*(-?\d*\.?\d+)", s)
    return float(m.group(1)) if m else None


def decimals(s):
    m = re.search(r"-?\d*\.(\d+)", str(s))
    return len(m.group(1)) if m else 0


def stars(s):
    return len(re.findall(r"\*", str(s)))


out = {"sealed": True, "source": "readers/fable/initial/targets.json (identical printed values in readers/astra/initial/targets.json)",
       "d": {}, "latent": {}, "items": {}, "fit": [], "N": {}, "unkeyed": []}
for t in ts:
    q, g, txt = t["quantity"], t["group_or_comparison"], t["printed_text"]
    rec = {"target_id": t["target_id"], "printed": txt, "value": num(txt), "decimals": decimals(txt), "locator": t["locator"]}
    if q.startswith("d ("):
        k = [v for n, v in FACTORS.items() if n.lower() in t["construct_or_item"].lower()][0]
        out["d"][f"{k}_{PAIRS[g]}"] = rec
    elif q in ("latent mean", "SD (printed in parentheses under latent mean)", "standard error of latent mean", "95% confidence interval of latent mean"):
        k = [v for n, v in FACTORS.items() if n.lower() in t["construct_or_item"].lower()][0]
        yr = re.search(r"(1976|1991|2006)", g).group(1)
        field = {"latent mean": "mean", "SD (printed in parentheses under latent mean)": "sd", "standard error of latent mean": "se", "95% confidence interval of latent mean": "ci"}[q]
        out["latent"].setdefault(f"{k}_{yr}", {})[field] = rec
    elif t["locator"].get("table") == "Table 1" and (q.startswith("item") or q.startswith("t stat") or q.startswith("percentage")):
        v = item_key(t["construct_or_item"])
        if q.startswith("t stat"):
            rec["stars"] = stars(txt)
            out["items"].setdefault(v, {})[f"t_{PAIRS[g]}"] = rec
        else:
            yr = re.search(r"(1976|1991|2006)", g).group(1)
            field = "mean" if q == "item mean" else "sd" if q == "item SD" else "pct"
            out["items"].setdefault(v, {})[f"{field}_{yr}"] = rec
    elif t["locator"].get("table") == "Table 2":
        out["fit"].append({"quantity": q, "model": t["construct_or_item"], "group": g, **rec})
    elif q == "N (respondents)":
        form = "f3" if "Form 3" in t["construct_or_item"] else "f4"
        out["N"][f"{form}_{g}"] = rec
    else:
        out["unkeyed"].append({"quantity": q, "item": t["construct_or_item"], "group": g, **rec})
assert len(out["d"]) == 15 and len(out["latent"]) == 15 and len(out["items"]) == 29 and len(out["N"]) == 6
out["version"] = "v2: item keys verified against source dictionary wording (V4239 = establish roots, V4241 = secure future); v1 had these two keys swapped"
json.dump(out, open("sealed/targets_v2.json", "w"), indent=1)
print({k: len(v) for k, v in out.items() if isinstance(v, (dict, list))})
