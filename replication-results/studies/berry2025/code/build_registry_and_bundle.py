"""Validate the deposit, then build the source registry and the neutral implementer bundle.

Removes free-text columns by name. Filters no rows. Never prints values of removed columns.
"""
import csv, datetime, hashlib, json, os
import pandas as pd

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(STUDY, "data/raw/osf_3h6vc")
OUT = os.path.join(STUDY, "data/derived/implementer_bundle")
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.join(STUDY, "registry"), exist_ok=True)

def sha(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()

# Deposit validation against the receipt
receipt = json.load(open(os.path.join(STUDY, "logs/osf_receipt.json")))
local = {}
for dp, _, fs in os.walk(RAW):
    for f in fs:
        local[sha(os.path.join(dp, f))] = os.path.relpath(os.path.join(dp, f), STUDY)
local[sha(os.path.join(STUDY, "sealed/author_package/ltran_analysis_script.Rmd"))] = "sealed/author_package/ltran_analysis_script.Rmd"
unmatched = [e["path"] for e in receipt["files"] if e["sha256"] not in local]

REMOVE = {
    1: ["name_person", "gender_person_text", "gender_3_TEXT", "race_7_TEXT", "race_8_TEXT", "Q10.5", "Q10.6"],
    2: ["gender_3_TEXT", "race_7_TEXT", "race_8_TEXT", "hypothesis", "addtl_thoughts"],
    3: ["gender_3_TEXT", "race_7_TEXT", "race_8_TEXT", "hypothesis", "addtl_thoughts"],
    4: [],
}
DICT = {1: "Study 1/study1_datadict_ltran.xlsx", 2: "Study 2/study2_datadict_ltran.xlsx",
        3: "Study 3/study3_datadict_ltran.xlsx", 4: "Study 4/studyS4_datadict_ltran.xlsx"}

reg = {"study_id": "berry2025", "provider": receipt["provider"], "node": receipt["node"],
       "url": "https://osf.io/3h6vc", "acquired_utc": receipt["acquired_utc"], "license": receipt["license"],
       "validated_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
       "receipt_entries": len(receipt["files"]), "receipt_unmatched": unmatched,
       "author_processed_before_deposit": True, "datasets": []}

for i in (1, 2, 3, 4):
    src = os.path.join(RAW, f"Study {i}/study{i}_data_ltran.csv")
    df = pd.read_csv(src, dtype=str, keep_default_na=False, encoding="utf-8-sig")
    missing = [c for c in REMOVE[i] if c not in df.columns]
    kept = df.drop(columns=[c for c in REMOVE[i] if c in df.columns])
    dest = os.path.join(OUT, f"dataset_{i}.csv")
    kept.to_csv(dest, index=False, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
    d = pd.read_excel(os.path.join(RAW, DICT[i]), dtype=str).fillna("")
    names = set(d["variable"].str.strip())
    undocumented = [c for c in kept.columns if c not in names]
    overlap = len(set(df.columns) & names)
    entry = {"study": i, "dataset": f"dataset_{i}.csv", "source": os.path.relpath(src, STUDY), "source_sha256": sha(src),
             "rows": len(df), "columns_source": df.shape[1], "columns_kept": kept.shape[1],
             "removed_free_text_columns": [c for c in REMOVE[i] if c in df.columns], "removal_names_absent": missing,
             "bundle_sha256": sha(dest), "dictionary_source": DICT[i], "dictionary_variables": len(names),
             "dictionary_overlap_with_columns": overlap, "kept_columns_not_in_dictionary": undocumented}
    if overlap == 0:
        entry["dictionary_status"] = "does not describe this file; not supplied to implementers"
        with open(os.path.join(OUT, f"dictionary_{i}.csv"), "w") as fh:
            w = csv.writer(fh)
            w.writerow(["variable", "note"])
            for c in kept.columns:
                w.writerow([c, "no dictionary in deposit for this file; definitions come from the manifest"])
    else:
        entry["dictionary_status"] = "matches" if not undocumented else "partial"
        d[d["variable"].str.strip().isin(kept.columns)].to_csv(
            os.path.join(OUT, f"dictionary_{i}.csv"), index=False, quoting=csv.QUOTE_ALL)
    entry["dictionary_bundle_sha256"] = sha(os.path.join(OUT, f"dictionary_{i}.csv"))
    reg["datasets"].append(entry)
    print(i, "rows", len(df), "cols", df.shape[1], "->", kept.shape[1], "removed", len(entry["removed_free_text_columns"]),
          "absent", missing, "dict overlap", overlap, "undocumented", undocumented)

json.dump(reg, open(os.path.join(STUDY, "registry/source_registry.json"), "w"), indent=1)
print("receipt unmatched:", unmatched)
