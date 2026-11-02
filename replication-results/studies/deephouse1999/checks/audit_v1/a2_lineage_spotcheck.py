"""Audit task 2: source-lineage spot check for 3 bank-years of the O_A estimation sample (impl_B).

Rule (fixed before looking at values): sort out/samples/O_A.csv by (RSSD9001, year); take the first row,
the lower-median row (0-based position (n-1)//2) and the last row. For each bank-year, read the raw
Chicago Fed zip(s) for the four quarters of year t (and Q4 of t-1), extract RCFD2170, RIAD4340, RIAD4073,
RIAD4093, RCFD3368/RCON3368, RCON2200 for the bank, compare with the derived core extract, and recompute
TER = (RIAD4073+RIAD4093)/AA with the O_A average-assets rule (mean of available quarterly 3368, RCFD else
RCON, at least two quarters) and compare with the sample TER. Raw file SHA-256 values are checked against
registry/source_registry.json. Zips are unpacked into a fresh temporary directory outside the study.
Run: ~/.venv/bin/python -I checks/audit_v1/a2_lineage_spotcheck.py <STUDY> <TMPDIR>
"""
import hashlib, json, sys, zipfile, os
from pathlib import Path
import numpy as np, pandas as pd, pyreadstat

ST = Path(sys.argv[1]); TMP = Path(sys.argv[2]); TMP.mkdir(parents=True, exist_ok=True)
OUT = ST / "checks/audit_v1"
S = pd.read_csv(ST / "runs/run_v1/impl_B/out/samples/O_A.csv").sort_values(["RSSD9001", "year"]).reset_index(drop=True)
n = len(S); pick = [0, (n - 1) // 2, n - 1]
reg = {f["path"]: f["sha256"] for f in json.load(open(ST / "registry/source_registry.json"))["files"]}
core = pd.read_parquet(ST / "data/derived/call_mnwi_core_1983q4_1993q4.parquet")
ITEMS = ["RSSD9001", "RSSD9048", "RSSD9331", "CALL8786", "RSSD9210", "RSSD9150", "RCFD2170", "RIAD4340", "RIAD4073",
         "RIAD4093", "RCFD3368", "RCON3368", "RCON2200", "RCFD2200"]

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for b in iter(lambda: fh.read(1 << 20), b""): h.update(b)
    return h.hexdigest()

cache, hashes = {}, []
def raw_quarter(year, q):
    yymm = f"{year % 100:02d}{q * 3:02d}"
    rel = f"data/raw/chicagofed_call_reports/call{yymm}-zip.zip"
    if rel in cache: return cache[rel]
    p = ST / rel
    h = sha(p); hashes.append({"path": rel, "sha256_disk": h, "sha256_registry": reg.get(rel), "match": h == reg.get(rel)})
    with zipfile.ZipFile(p) as zf:
        mem = [m for m in zf.namelist() if m.lower().endswith(".xpt")]
        assert len(mem) == 1
        d = TMP / yymm; d.mkdir(exist_ok=True)
        zf.extract(mem[0], d)
    df, _ = pyreadstat.read_xport(str(d / mem[0]))
    os.remove(d / mem[0])
    df = df[[c for c in ITEMS if c in df.columns]]
    cache[rel] = df
    return df

rows = []
for pos in pick:
    s = S.iloc[pos]; bank, yr = int(s.RSSD9001), int(s.year)
    rec = {"position": pos, "RSSD9001": bank, "year": yr}
    q3368 = []
    for (yy, q) in [(yr - 1, 4), (yr, 1), (yr, 2), (yr, 3), (yr, 4)]:
        raw = raw_quarter(yy, q)
        r = raw[raw.RSSD9001 == bank]
        r = r[r.CALL8786.isin([1, 2])].sort_values("CALL8786").head(1)
        dq = core[(core.RSSD9001 == bank) & (core.quarter == f"{yy}Q{q}")]
        dq = dq[dq.CALL8786.isin([1, 2])].sort_values("CALL8786").head(1)
        tag = f"{yy}Q{q}"
        for it in ["RCFD2170", "RCFD3368", "RCON3368", "RCON2200", "RIAD4340", "RIAD4073", "RIAD4093"]:
            rv = float(r[it].iloc[0]) if (len(r) and it in r) else np.nan
            dv = float(dq[it].iloc[0]) if (len(dq) and it in dq) else np.nan
            rec[f"{tag}_{it}_raw"] = rv; rec[f"{tag}_{it}_derived"] = dv
            rec.setdefault("raw_vs_derived_all_equal", True)
            if not ((np.isnan(rv) and np.isnan(dv)) or rv == dv): rec["raw_vs_derived_all_equal"] = False
        if yy == yr:
            v = rec[f"{tag}_RCFD3368_raw"]
            if np.isnan(v): v = rec[f"{tag}_RCON3368_raw"]
            q3368.append(v)
    q = np.array(q3368, float); avail = q[~np.isnan(q)]
    AA = avail.mean() if len(avail) >= 2 else np.nan
    t4 = f"{yr}Q4"
    rec["AA_O_A_rule"] = AA; rec["n_quarters_3368"] = int(len(avail))
    rec["ROA_raw"] = rec[f"{t4}_RIAD4340_raw"] / AA
    rec["TER_raw"] = (rec[f"{t4}_RIAD4073_raw"] + rec[f"{t4}_RIAD4093_raw"]) / AA
    rec["TER_sample"] = float(s.TER); rec["TER_absdiff"] = abs(rec["TER_raw"] - float(s.TER))
    rec["DEP_raw_RCON2200_Q4"] = rec[f"{t4}_RCON2200_raw"]
    rec["MS_sample"] = float(s.MS); rec["implied_market_deposits_D_t"] = rec["DEP_raw_RCON2200_Q4"] / float(s.MS)
    rec["y_sample"] = float(s.y); rec["SD_sample"] = float(s.SD)
    rows.append(rec)

R = pd.DataFrame(rows)
# the implied market total must equal the year's sum of RCON2200 over the O_A market population; checked in a3
R.T.to_csv(OUT / "a2_lineage_spotcheck.csv", header=[f"row{p}" for p in pick])
pd.DataFrame(hashes).to_csv(OUT / "a2_raw_hash_check.csv", index=False)
print(R[["position", "RSSD9001", "year", "n_quarters_3368", "AA_O_A_rule", "ROA_raw", "TER_raw", "TER_sample", "TER_absdiff",
         "DEP_raw_RCON2200_Q4", "MS_sample", "implied_market_deposits_D_t", "raw_vs_derived_all_equal"]].to_string())
print(pd.DataFrame(hashes).to_string())
