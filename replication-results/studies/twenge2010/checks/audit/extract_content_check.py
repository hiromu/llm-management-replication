"""Audit: extract content equals source content for the analysis variables (V4, V5, 29 items) of the six analysis files.
Run from the study root: ~/.venv/bin/python -I checks/audit/extract_content_check.py
"""
import json
import numpy as np, pandas as pd, pyreadstat
EXT = {"y1976_f3": "1976_DS0003", "y1991_f3": "1991_DS0004", "y2006_f3": "2006_DS0004",
       "y1976_f4": "1976_DS0004", "y1991_f4": "1991_DS0005", "y2006_f4": "2006_DS0005"}
F4 = [f"V{i}" for i in range(4225, 4248)]
F3 = ["V3222", "V3223", "V3224", "V3225", "V3226", "V3227"]
out = {}
for key, ds in EXT.items():
    side = json.load(open(f"data/derived/extracts/{ds}.json"))
    cols = ["V4", "V5"] + (F4 if key.endswith("f4") else F3)
    src = side["source_file"]
    if src.endswith(".sav"):
        s, _ = pyreadstat.read_sav(src, usecols=cols, user_missing=True)
    else:
        s, _ = pyreadstat.read_por(src, usecols=cols)
    e = pd.read_csv(side["extract"], usecols=cols)[cols]
    s = s[cols]
    same = {c: bool(np.allclose(s[c].to_numpy(float), e[c].to_numpy(float), equal_nan=True, rtol=0, atol=1e-9)) for c in cols}
    # where the reader returns NaN (declared missing applied by pyreadstat for .por), the extract must hold a declared
    # missing code; all non-missing source values must be equal
    diffinfo = {}
    for c in [c for c, v in same.items() if not v]:
        sv, ev = s[c].to_numpy(float), e[c].to_numpy(float)
        nan_src = np.isnan(sv)
        eq_nonmiss = bool(np.allclose(sv[~nan_src], ev[~nan_src], rtol=0, atol=1e-9))
        codes = sorted(set(np.unique(ev[nan_src & ~np.isnan(ev)]).tolist()))
        diffinfo[c] = {"equal_where_source_nonmissing": eq_nonmiss, "extract_codes_where_source_missing": codes}
    valid = {1, 2, 3, 4, 5}
    out[key] = {"source": src, "rows_source": len(s), "rows_extract": len(e), "all_columns_equal_including_missing": all(same.values()),
                "nonmissing_values_equal_all_columns": all(d["equal_where_source_nonmissing"] for d in diffinfo.values()),
                "extract_codes_where_source_missing": sorted(set(x for d in diffinfo.values() for x in d["extract_codes_where_source_missing"])),
                "any_valid_code_hidden_as_missing": any(set(d["extract_codes_where_source_missing"]) & valid for d in diffinfo.values())}
    print(key, out[key])
json.dump(out, open("checks/audit/extract_content_check.json", "w"), indent=1)
