"""Build the implementer-visible bundle (target-free) and scan it for identity/target leakage."""
import json, re, shutil, sys, hashlib
from pathlib import Path

ST = Path(sys.argv[1])
OUT = ST / "implementation/bundle_v1"
if OUT.exists():
    sys.exit("bundle_v1 already exists; versions are immutable")
(OUT / "data").mkdir(parents=True)
(OUT / "docs").mkdir()

grid = json.load(open(ST / "reconciliation/grid_v1.json"))
igrid = {"origins": {}, "axes": [], "models": grid["models"],
         "run_order": [s for s in grid["run_order"] if "equivalent set" not in s],
         "compatibility": grid["compatibility"]}
for o in grid["origins"]:
    igrid["origins"][o] = {a["axis"]: next(l["id"] for l in a["levels"] if o in l.get("origin_of", []))
                           for a in grid["axes"]}
for a in grid["axes"]:
    igrid["axes"].append({"axis": a["axis"], "decision": a["decision"],
                          "levels": [{"id": l["id"], "rule": l["rule"],
                                      **({"check": True} if l["label"] == "equivalent_algebraic_check" else {})}
                                     for l in a["levels"]]})
igrid["run_order"] = [
    "1. O_A and O_B, all four models.",
    "2. One-at-a-time deviations from O_A for every level of every axis that differs from O_A's level (levels marked check=true excluded); then the same from O_B. Record a level identical to the origin's level as duplicate.",
    "3. Checks (levels with check=true) at both origins.",
    "4. Influence diagnostics per manifest section 5."]
json.dump(igrid, open(OUT / "grid.json", "w"), indent=1)

shutil.copy(ST / "implementation/manifest_v1.md", OUT / "manifest.md")
for f in ["data_dictionary.md", "source_descriptions.md", "call_item_candidates.json"]:
    shutil.copy(ST / "registry" / f, OUT / "docs" / f)
for f in ["call_mnwi_core_1983q4_1993q4", "call_item_presence_by_quarter", "fdic_institutions_mnwi_and_linked",
          "fdic_structure_events_mnwi_1983_1994", "fdic_financials_core_mnwi_1984q1_1994q4", "deflators_long",
          "msa_minneapolis_stpaul_counties_by_vintage", "county_fips_mn_wi"]:
    shutil.copy(ST / "data/derived" / f"{f}.parquet", OUT / "data" / f"{f}.parquet")

# Leakage scan: identity strings, and published target numbers in text files.
IDENT = [r"deephouse", r"strategic balance", r"to be different", r"strategic management journal", r"\bSMJ\b",
         r"norwest", r"isomorphism", r"legitima", r"differentiation", r"conformity", r"hypothes"]
targets = []
for r in ["fable", "astra"]:
    d = json.load(open(ST / f"readers/{r}/initial_v1/out/sealed_targets.json"))
    d = d["targets"] if isinstance(d, dict) else d
    for x in d:
        for k in ("coefficient", "published_se"):
            v = x.get(k)
            if isinstance(v, (int, float)) and v is not None:
                targets.append(f"{v:g}")
targets += ["960", "159", "2.978", "2.886", "2.53", "30.4", "84.4", "134.1", "21.8", "1.28", "234"]
targets = sorted(set(t for t in targets if len(t.replace("-", "").replace(".", "")) >= 3))
hits = []
for p in sorted(OUT.rglob("*")):
    if p.suffix not in (".md", ".json"):
        continue
    txt = p.read_text(errors="ignore")
    for pat in IDENT:
        for m in re.finditer(pat, txt, re.I):
            hits.append({"file": str(p.relative_to(OUT)), "kind": "identity", "pattern": pat,
                         "context": txt[max(0, m.start() - 60): m.end() + 60].replace("\n", " ")})
    for t in targets:
        for m in re.finditer(r"(?<![\d.])" + re.escape(t) + r"(?![\d])", txt):
            hits.append({"file": str(p.relative_to(OUT)), "kind": "target_number", "pattern": t,
                         "context": txt[max(0, m.start() - 60): m.end() + 60].replace("\n", " ")})
json.dump(hits, open(ST / "implementation/leakage_scan_v1.json", "w"), indent=1)
sums = "".join(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(OUT)}\n"
               for p in sorted(OUT.rglob("*")) if p.is_file())
(ST / "implementation/bundle_v1_SHA256SUMS.txt").write_text(sums)
from collections import Counter
print(len(hits), Counter((h["kind"], h["pattern"], h["file"]) for h in hits).most_common(40))
