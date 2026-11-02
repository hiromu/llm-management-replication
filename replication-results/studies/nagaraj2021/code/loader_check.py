"""Python half of the loader-equivalence check on data/derived/bundle_v1.
Each file is read as text, and every column is reduced to an md5 of its values joined by newlines.
code/loader_check.R does the same in R; compare_loaders below compares the two outputs.
Only shapes, names and checksums are written, never values.
"""
import hashlib, json, os, sys
import pandas as pd

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B = os.path.join(STUDY, "data/derived/bundle_v1")
TAB = {"amenitycheck.csv", "distance.csv", "land_area.csv", "maptimes.csv", "osm-events.csv", "quarterly.csv", "h12.csv"}


def num(x):
    return "NA" if pd.isna(x) else f"{float(x):.10g}"


out = {}
for f in sorted(os.listdir(B)):
    p = os.path.join(B, f)
    if f.endswith(".csv"):
        df = pd.read_csv(p, sep="\t" if f in TAB else ",", dtype=str, keep_default_na=False,
                         header=None if f == "h12.csv" else 0, encoding="utf-8")
        cols = {str(c): df[c].tolist() for c in df.columns}
    elif f.endswith(".dta"):
        df = pd.read_stata(p, convert_categoricals=False)
        cols = {c: [num(v) for v in df[c]] for c in df.columns}
    elif f.endswith(".xlsx"):
        df = pd.read_excel(p)
        cols = {}
        for c in df.columns:
            if str(df[c].dtype).startswith("datetime"):
                cols[str(c)] = ["NA" if pd.isna(v) else v.strftime("%Y-%m-%d") for v in df[c]]
            elif df[c].dtype.kind in "if":
                cols[str(c)] = [num(v) for v in df[c]]
            else:
                cols[str(c)] = ["NA" if pd.isna(v) else str(v) for v in df[c]]
    else:
        continue
    out[f] = {"nrow": len(df), "ncol": df.shape[1],
              "columns": {c: hashlib.md5(("\n".join(v) + "\n").encode()).hexdigest() for c, v in cols.items()}}
json.dump(out, open(sys.argv[1], "w"), indent=1)
