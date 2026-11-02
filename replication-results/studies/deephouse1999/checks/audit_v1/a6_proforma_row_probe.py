"""Audit task 6 support: locate merger-survivor bank-years where R03.proforma readings can differ.
Lists O_A market bank-years (Q4 records passing O_A R01/R02, RCFD2170 > 0) that are merger survivors in year t
(FDIC events, merger/absorption/consolidation codes, survivor = SUR_CERT or ACQ_CERT) and reports whether the
survivor's own RSSD9001 has a t-1 filtered Q4 record, whether its CERT appears at t-1 under another RSSD9001,
and whether any predecessor CERT is missing at t-1.
Run: ~/.venv/bin/python -I checks/audit_v1/a6_proforma_row_probe.py <STUDY>
"""
import sys
from pathlib import Path
import pandas as pd
ST = Path(sys.argv[1])
c = pd.read_parquet(ST / "data/derived/call_mnwi_core_1983q4_1993q4.parquet")
c = c[(c.RSSD9048 == 200) & c.CALL8786.isin([1, 2]) & (c.RSSD9331 == 1) & c.quarter.str.endswith("Q4")]
c = c.sort_values(["RSSD9001", "quarter", "CALL8786"]).drop_duplicates(["RSSD9001", "quarter"])
c["year"] = c.quarter.str[:4].astype(int)
msa = pd.read_parquet(ST / "data/derived/msa_minneapolis_stpaul_counties_by_vintage.parquet")
cn = set(msa[(msa.area_code.astype(str) == "5120") & (msa.omb_definition_date.astype(str).str[:10] == "1983-06-27")].county_fips5.astype(int))
c["fips"] = c.RSSD9210.astype(int) * 1000 + c.RSSD9150.astype(int)
mkt = c[c.fips.isin(cn) & (c.RCFD2170 > 0) & c.year.between(1985, 1992)]
e = pd.read_parquet(ST / "data/derived/fdic_structure_events_mnwi_1983_1994.parquet")
e["year"] = pd.to_datetime(e.EFFDATE.astype(str).str[:10], errors="coerce").dt.year
d = e.CHANGECODE_DESC.fillna("")
e = e[d.str.contains("merg|absorp|absorb|consol", case=False) & ~d.str.contains("branch", case=False)]
e["surv"] = e.SUR_CERT.where(e.SUR_CERT > 0, e.ACQ_CERT)
rows = []
for r in mkt.itertuples():
    ev = e[(e.year == r.year) & ((e.SUR_CERT == r.RSSD9050) | (e.ACQ_CERT == r.RSSD9050))]
    if ev.empty: continue
    prev = c[c.year == r.year - 1]
    outs = set(ev.OUT_CERT.dropna()) - {r.RSSD9050}
    rows.append(dict(RSSD9001=r.RSSD9001, CERT=r.RSSD9050, year=r.year, n_events=len(ev),
                     own_id_prev=bool(((prev.RSSD9001 == r.RSSD9001)).any()),
                     cert_prev_other_id=bool(((prev.RSSD9050 == r.RSSD9050) & (prev.RSSD9001 != r.RSSD9001)).any()),
                     preds=len(outs), preds_missing_prev=len([o for o in outs if not (prev.RSSD9050 == o).any()]),
                     sur_vs_acq_differ=bool((ev.SUR_CERT.fillna(-1) != ev.ACQ_CERT.fillna(-1)).any())))
R = pd.DataFrame(rows)
R.to_csv(ST / "checks/audit_v1/a6_proforma_survivor_rows_O_A.csv", index=False)
print(len(R)); print(R[(~R.own_id_prev) | R.cert_prev_other_id].to_string())
