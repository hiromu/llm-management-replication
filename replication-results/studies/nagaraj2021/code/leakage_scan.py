"""Scan implementer and checker inputs for article identity and published target values.
Identity terms are fixed below. Target strings are every printed value, SE and N in both readers' sealed targets that has
at least three significant digits; they are searched as whole tokens in text inputs and, for the synthetic data, as
exact cell strings. Hits are written for review; reviewed false positives are recorded by the coordinator."""
import json, os, re, sys
STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IDENT = ["nagaraj", "information seeding", "seeding", "a47e9", "management science", "berkeley", "mnsc", "openstreetmap",
         "osm", "tiger experiment", "hansen", "harris", "mtaip", "fusaro", "knowledge production", "online communit", "doi"]
tv = set()
for r in ("opus", "astra"):
    for x in json.load(open(os.path.join(STUDY, f"readers/{r}/initial_v1/targets.json"))):
        for f in ("value", "se", "n_obs"):
            v = str(x.get(f) or "").replace("−", "-").strip("() ")
            if re.fullmatch(r"-?[\d,]*\.?\d+", v) and len(re.sub(r"[^1-9]", "", v.lstrip("-0.").replace(",", ""))) >= 2 and len(v.replace(",", "").lstrip("-0.").replace(".", "")) >= 3:
                tv.add(v.lstrip("-")); tv.add(v.replace(",", "").lstrip("-"))
hits = {"identity": [], "targets": []}
for path in sys.argv[1:]:
    for root, _, files in os.walk(path) if os.path.isdir(path) else [(os.path.dirname(path), None, [os.path.basename(path)])]:
        for fn in files:
            p = os.path.join(root, fn)
            if fn.endswith((".dta", ".xlsx")):
                continue
            txt = open(p, encoding="utf-8", errors="replace").read()
            low = txt.lower()
            for t in IDENT:
                for m in re.finditer(r"(?<![a-z])" + re.escape(t), low):
                    hits["identity"].append((os.path.relpath(p, STUDY), t, low[max(0, m.start() - 40):m.end() + 40].replace("\n", " ")))
            is_data = "synthetic" in p or fn == "grid_v1.csv"
            for v in tv:
                pat = (r'(?<![\d.])"?' + re.escape(v) + r'"?(?![\d])') if not is_data else (r'(?:^|[\t,"])' + re.escape(v) + r'(?:$|[\t,"\n])')
                for m in re.finditer(pat, txt, flags=re.M):
                    hits["targets"].append((os.path.relpath(p, STUDY), v, txt[max(0, m.start() - 30):m.end() + 30].replace("\n", " ")))
json.dump(hits, open(os.path.join(STUDY, "logs/leakage_scan_v1.json"), "w"), indent=1)
print("target strings scanned:", len(tv))
print("identity hits:", len(hits["identity"]))
for h in hits["identity"][:40]: print("  ID", h)
from collections import Counter
print("target hits:", len(hits["targets"]), Counter(h[0] for h in hits["targets"]))
for h in [h for h in hits["targets"] if "synthetic" not in h[0]][:40]: print("  TV", h)
