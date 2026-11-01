"""Auditor's independent O_A construction (same logic as a3_calc_audit.py part b, which reproduced the frozen
O_A sample exactly). Used only for post hoc diagnostics; delete_named=False keeps the named 1987 row."""
from pathlib import Path
import numpy as np, pandas as pd

ITEMS = ["RCFD1766", "RCFD1410", "RCFD1975", "RCFD1590", "RCFD1400", "RCFD0010", "RCFD1350", "RCFD0390", "RCFD2146",
         "RCFD2145", "RCFD2150", "RCFD2130", "RCFD2155", "RCFD2143", "RCFD2160"]

def build_O_A(ST, delete_named=True, county_subset=None):
    """county_subset: optional set of 5-digit FIPS strings restricting the market (post hoc diagnostics only)."""
    ST = Path(ST)
    core = pd.read_parquet(ST / "data/derived/call_mnwi_core_1983q4_1993q4.parquet")
    pres = pd.read_parquet(ST / "data/derived/call_item_presence_by_quarter.parquet")
    msa = pd.read_parquet(ST / "data/derived/msa_minneapolis_stpaul_counties_by_vintage.parquet")
    defl = pd.read_parquet(ST / "data/derived/deflators_long.parquet")
    c = core[(core.RSSD9048 == 200) & core.CALL8786.isin([1, 2]) & (core.RSSD9331 == 1)].copy()
    c = c.sort_values(["RSSD9001", "quarter", "CALL8786"]).drop_duplicates(["RSSD9001", "quarter"])
    c["year"] = c.quarter.str[:4].astype(int); c["q"] = c.quarter.str[-1].astype(int)
    c["fips5"] = c.RSSD9210.astype(int).map("{:02d}".format) + c.RSSD9150.astype(int).map("{:03d}".format)
    mk = msa[(msa.area_code.astype(str) == "5120") & (msa.omb_definition_date.astype(str).str[:10] == "1983-06-27")]
    counties = set(mk.county_fips5.astype(int).map("{:05d}".format))
    if county_subset is not None: counties = counties & set(county_subset)
    for it in ITEMS:
        p = pres[pres.item == it].set_index("quarter"); nc = ((p.in_file == 0) | (p.any_nonmissing_mnwi == 0))
        v = c[it].copy(); fill = v.isna() & c.quarter.map(nc).fillna(False).astype(bool); v[fill] = 0.0; c[it + "_z"] = v
    c["AAq"] = c.RCFD3368.where(c.RCFD3368.notna(), c.RCON3368)
    yr = c[c.year.between(1984, 1992)]
    aa = yr.groupby(["RSSD9001", "year"]).AAq.agg(lambda s: s.dropna().mean() if s.notna().sum() >= 2 else np.nan).rename("AA")
    nav = yr.groupby(["RSSD9001", "year"]).AAq.agg(lambda s: int(s.notna().sum())).rename("nav")
    q4all = c[c.q == 4].set_index(["RSSD9001", "year"])
    q4 = c[(c.q == 4) & c.year.between(1984, 1992)].copy().set_index(["RSSD9001", "year"]).join(aa).join(nav)
    for (b, t) in q4.index[q4.nav == 0]:
        pts = list(yr[(yr.RSSD9001 == b) & (yr.year == t)].RCFD2170.dropna())
        if (b, t - 1) in q4all.index and pd.notna(q4all.loc[(b, t - 1), "RCFD2170"]): pts.append(q4all.loc[(b, t - 1), "RCFD2170"])
        q4.loc[(b, t), "AA"] = np.mean(pts) if pts else np.nan
    q4 = q4[q4.fips5.isin(counties) & (q4.RCFD2170 > 0)].copy()
    q4["ROA"] = np.where(q4.AA > 0, q4.RIAD4340 / q4.AA, np.nan)
    q4["TER"] = np.where(q4.AA > 0, (q4.RIAD4073 + q4.RIAD4093) / q4.AA, np.nan)
    amt = {1: q4.RCFD1766_z, 2: q4.RCFD1410_z, 3: q4.RCFD1975_z, 4: q4.RCFD1590_z,
           5: q4.RCFD1400_z - q4.RCFD1766_z - q4.RCFD1410_z - q4.RCFD1975_z - q4.RCFD1590_z,
           6: q4.RCFD0010_z, 7: q4.RCFD1350_z, 8: q4.RCFD0390_z, 9: q4.RCFD2146_z, 10: q4.RCFD2145_z,
           11: q4.RCFD2150_z + q4.RCFD2130_z + q4.RCFD2155_z + q4.RCFD2143_z + q4.RCFD2160_z}
    for a, v in amt.items(): q4[f"s{a}"] = v / q4.RCFD2170
    q4["DEP"] = q4.RCON2200; q4 = q4.reset_index()
    bench = []
    for t, g in q4.groupby("year"):
        z = np.zeros(len(g))
        for a in range(1, 12):
            x = g[f"s{a}"]; m, s = x.mean(), x.std(ddof=1)
            z = z + (np.where(x.notna(), 0.0, np.nan) if s == 0 else ((x - m) / s).abs().values)
        q4.loc[g.index, "SD"] = z; q4.loc[g.index, "mROA"] = g.ROA.mean(); q4.loc[g.index, "Dt"] = g.DEP.sum(min_count=1)
        bench.append(dict(year=t, n_market=len(g), D_t=g.DEP.sum(min_count=1), mean_ROA=g.ROA.mean()))
    P = defl[(defl.series_id == "CPIAUCNS") & defl.source_file.str.contains("annual_avg")].copy()
    P["year"] = P.date.astype(str).str[:4].astype(int); P = P.set_index("year").value
    B = pd.DataFrame(bench).set_index("year"); B["real"] = B.D_t / P.reindex(B.index); B["RMG"] = 100 * (B.real / B.real.shift(1) - 1)
    q4["y"] = 100 * (q4.ROA - q4.mROA); q4["MS"] = q4.DEP / q4.Dt; q4["RMG"] = q4.year.map(B.RMG); q4["SD2"] = q4.SD ** 2
    lagmap = q4.set_index(["RSSD9001", "year"]).y
    q4["lag"] = [lagmap.get((b, t - 1), np.nan) for b, t in zip(q4.RSSD9001, q4.year)]
    s = q4[q4.year.between(1985, 1992)].dropna(subset=["y", "lag", "SD", "MS", "TER", "RMG"])
    s = s[s.MS > 0]
    if delete_named: s = s[~((s.RSSD9001 == 995151) & (s.year == 1987))]
    s = s[["RSSD9001", "year", "y", "lag", "SD", "SD2", "MS", "TER", "RMG", "AA"]].sort_values(["RSSD9001", "year"]).reset_index(drop=True)
    return s, B
