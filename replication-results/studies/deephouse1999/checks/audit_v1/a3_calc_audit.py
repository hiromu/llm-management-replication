"""Audit task 3: independent recomputation.

(a) WLS for M1, M2, M3, M3_SQ and the nested F tests from impl_B's saved O_A and O_B samples, written from the
    manifest formulas (numpy only; not the implementers' code), compared with impl_B/impl_C spec_results.csv and
    f_tests.csv.
(b) Independent rebuild of the O_A construction from data/derived/call_mnwi_core_1983q4_1993q4.parquet following
    the grid_v1.json O_A levels (R01.fixed1983, R02.charter_entity, R03.as_reported, R04.lag_only, R05.min2_fallback,
    R06.rck_mean, R07.net_income, R08.year_end, R09.all_market, R10.delete_named, R11-R14 origin A, R15 zero if not
    collected, R16 consolidated, R17 sample SD, R18 domestic RCON2200, R19/R21 commercial, R20 CPI annual), and
    comparison with out/samples/O_A.csv: strategic deviation for the fixed audit year 1988 (middle of 1985-1992)
    and, additionally, every variable in every year.
Run: ~/.venv/bin/python -I checks/audit_v1/a3_calc_audit.py <STUDY>
"""
import json, sys, hashlib
from pathlib import Path
import numpy as np, pandas as pd
from scipy import stats

ST = Path(sys.argv[1]); OUT = ST / "checks/audit_v1"; RUN = ST / "runs/run_v1"
TERMS = {"M1": ["MS", "TER", "RMG", "lag"], "M2": ["SD", "MS", "TER", "RMG", "lag"],
         "M3": ["SD2", "SD", "MS", "TER", "RMG", "lag"], "M3_SQ": ["SD2", "MS", "TER", "RMG", "lag"]}

def wls(d, model):
    X = np.column_stack([np.ones(len(d))] + [d[t].values for t in TERMS[model]])
    y = d["y"].values; w = d["MS"].values
    sw = np.sqrt(w); Xw = X * sw[:, None]; yw = y * sw
    XtX = Xw.T @ Xw; b = np.linalg.solve(XtX, Xw.T @ yw)
    e = yw - Xw @ b; n, k = X.shape; sse = float(e @ e); s2 = sse / (n - k)
    se = np.sqrt(np.diag(s2 * np.linalg.inv(XtX))); t = b / se; p = 2 * stats.t.sf(np.abs(t), n - k)
    Z = Xw / np.linalg.norm(Xw, axis=0); sv = np.linalg.svd(Z, compute_uv=False)
    cov = s2 * np.linalg.inv(XtX)
    return dict(names=["intercept"] + TERMS[model], b=b, se=se, t=t, p=p, n=n, k=k, sse=sse, cond=sv.max() / sv.min(), cov=cov)

def sample_hash(d):
    lines = sorted(f"{int(a)},{int(b)}" for a, b in zip(d.RSSD9001, d.year))
    return hashlib.sha256("".join(l + "\n" for l in lines).encode()).hexdigest()

rows, frows, covrows = [], [], []
for impl in ["impl_B", "impl_C"]:
    R = pd.read_csv(RUN / impl / "out/spec_results.csv"); R["term"] = R["term"].replace({"(Intercept)": "intercept", "Intercept": "intercept", "const": "intercept"})
    FT = pd.read_csv(RUN / impl / "out/f_tests.csv")
    for o in ["O_A", "O_B"]:
        d = pd.read_csv(RUN / "impl_B/out/samples" / f"{o}.csv")
        assert np.allclose(d.SD2, d.SD ** 2) and np.allclose(d.w, d.MS)
        fits = {m: wls(d, m) for m in TERMS}
        h = sample_hash(d)
        for m, f in fits.items():
            for nm, b, se, p in zip(f["names"], f["b"], f["se"], f["p"]):
                r = R[(R.spec_id == o) & (R.model == m) & (R.term == nm)].iloc[0]
                rows.append(dict(impl_compared=impl, origin=o, model=m, term=nm, n_audit=f["n"], n_impl=int(r.n),
                                 hash_match=(h == r.sample_hash), est_audit=b, est_impl=r.estimate, est_absdiff=abs(b - r.estimate),
                                 se_audit=se, se_impl=r.se, se_absdiff=abs(se - r.se), p_audit=p, p_impl=r.p_two_sided,
                                 sse_audit=f["sse"], sse_impl=r.sse_w, cond_audit=f["cond"], cond_impl=r.cond_max))
        for comp, (r_, u_, q) in {"M2 vs M1": ("M1", "M2", 1), "M3 vs M1": ("M1", "M3", 2), "M3 vs M2": ("M2", "M3", 1), "M3_SQ vs M1": ("M1", "M3_SQ", 1)}.items():
            fu, fr = fits[u_], fits[r_]; df = fu["n"] - fu["k"]
            F = ((fr["sse"] - fu["sse"]) / q) / (fu["sse"] / df); p = stats.f.sf(F, q, df)
            fi = FT[(FT.spec_id == o) & (FT.comparison == comp)].iloc[0]
            frows.append(dict(impl_compared=impl, origin=o, comparison=comp, F_audit=F, F_impl=fi.F, p_audit=p, p_impl=fi.p_upper,
                              dsse_audit=fr["sse"] - fu["sse"], dsse_impl=fi.delta_sse, absdiff_F=abs(F - fi.F)))
        if impl == "impl_B":
            f3 = fits["M3"]; i1, i2 = f3["names"].index("SD"), f3["names"].index("SD2")
            c = f3["cov"]; covrows.append(dict(origin=o, corr_bSD_bSD2=c[i1, i2] / np.sqrt(c[i1, i1] * c[i2, i2]),
                                               b_SD=f3["b"][i1], b_SD2=f3["b"][i2], turning_point=-f3["b"][i1] / (2 * f3["b"][i2])))
A = pd.DataFrame(rows); A.to_csv(OUT / "a3_wls_recompute.csv", index=False)
Fd = pd.DataFrame(frows); Fd.to_csv(OUT / "a3_ftest_recompute.csv", index=False)
pd.DataFrame(covrows).to_csv(OUT / "a3_m3_coef_correlation.csv", index=False)
print("max |est diff|", A.est_absdiff.max(), "max |se diff|", A.se_absdiff.max(), "max rel est diff",
      (A.est_absdiff / np.maximum(1, A.est_impl.abs())).max(), "all hash match", A.hash_match.all(), "max |F diff|", Fd.absdiff_F.max())
print(pd.DataFrame(covrows))

# ---------------- (b) independent O_A rebuild ----------------
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

notcoll = {}
for it in ["RCFD1766", "RCFD1410", "RCFD1975", "RCFD1590", "RCFD1400", "RCFD0010", "RCFD1350", "RCFD0390", "RCFD2146",
           "RCFD2145", "RCFD2150", "RCFD2130", "RCFD2155", "RCFD2143", "RCFD2160"]:
    p = pres[pres.item == it].set_index("quarter")
    nc = ((p.in_file == 0) | (p.any_nonmissing_mnwi == 0))
    v = c[it].copy() if it in c else pd.Series(np.nan, index=c.index)
    fill = v.isna() & c.quarter.map(nc).fillna(False).astype(bool)
    v[fill] = 0.0; c[it + "_z"] = v; notcoll[it] = int(fill.sum())
c["AAq"] = c.RCFD3368.where(c.RCFD3368.notna(), c.RCON3368)
yr = c[c.year.between(1984, 1992)]
aa = yr.groupby(["RSSD9001", "year"]).AAq.agg(lambda s: s.dropna().mean() if s.notna().sum() >= 2 else np.nan).rename("AA")
nav = yr.groupby(["RSSD9001", "year"]).AAq.agg(lambda s: int(s.notna().sum())).rename("nav")
q4all = c[c.q == 4].set_index(["RSSD9001", "year"])
q4 = c[(c.q == 4) & c.year.between(1984, 1992)].copy().set_index(["RSSD9001", "year"])
q4 = q4.join(aa).join(nav)
# fallback when no quarter of 3368 is available: mean of RCFD2170 from Q4 t-1 through Q4 t (available points)
fb = q4.nav == 0
for (b, t) in q4.index[fb]:
    pts = list(yr[(yr.RSSD9001 == b) & (yr.year == t)].RCFD2170.dropna())
    if (b, t - 1) in q4all.index and pd.notna(q4all.loc[(b, t - 1), "RCFD2170"]): pts.append(q4all.loc[(b, t - 1), "RCFD2170"])
    q4.loc[(b, t), "AA"] = np.mean(pts) if pts else np.nan
q4["market"] = q4.fips5.isin(counties) & (q4.RCFD2170 > 0)
q4 = q4[q4.market].copy()
q4["ROA"] = np.where(q4.AA > 0, q4.RIAD4340 / q4.AA, np.nan)
q4["TER"] = np.where(q4.AA > 0, (q4.RIAD4073 + q4.RIAD4093) / q4.AA, np.nan)
amt = {1: q4.RCFD1766_z, 2: q4.RCFD1410_z, 3: q4.RCFD1975_z, 4: q4.RCFD1590_z,
       5: q4.RCFD1400_z - q4.RCFD1766_z - q4.RCFD1410_z - q4.RCFD1975_z - q4.RCFD1590_z,
       6: q4.RCFD0010_z, 7: q4.RCFD1350_z, 8: q4.RCFD0390_z, 9: q4.RCFD2146_z, 10: q4.RCFD2145_z,
       11: q4.RCFD2150_z + q4.RCFD2130_z + q4.RCFD2155_z + q4.RCFD2143_z + q4.RCFD2160_z}
for a, v in amt.items(): q4[f"s{a}"] = v / q4.RCFD2170
q4["DEP"] = q4.RCON2200
q4 = q4.reset_index()
bench = []
for t, g in q4.groupby("year"):
    z = np.zeros(len(g))
    for a in range(1, 12):
        x = g[f"s{a}"]; m, s = x.mean(), x.std(ddof=1)
        z = z + (np.where(x.notna(), 0.0, np.nan) if s == 0 else ((x - m) / s).abs().values)
    q4.loc[g.index, "SD"] = z
    q4.loc[g.index, "mROA"] = g.ROA.mean(); q4.loc[g.index, "Dt"] = g.DEP.sum(min_count=1)
    bench.append(dict(year=t, n_market=len(g), D_t=g.DEP.sum(min_count=1), mean_ROA=g.ROA.mean()))
P = defl[(defl.series_id == "CPIAUCNS") & defl.source_file.str.contains("annual_avg")].copy()
P["year"] = P.date.astype(str).str[:4].astype(int); P = P.set_index("year").value
B = pd.DataFrame(bench).set_index("year"); B["real"] = B.D_t / P.reindex(B.index); B["RMG"] = 100 * (B.real / B.real.shift(1) - 1)
q4["y"] = 100 * (q4.ROA - q4.mROA); q4["MS"] = q4.DEP / q4.Dt; q4["RMG"] = q4.year.map(B.RMG); q4["SD2"] = q4.SD ** 2
lagmap = q4.set_index(["RSSD9001", "year"]).y
q4["lag"] = [lagmap.get((b, t - 1), np.nan) for b, t in zip(q4.RSSD9001, q4.year)]
s = q4[q4.year.between(1985, 1992)].dropna(subset=["y", "lag", "SD", "MS", "TER", "RMG"])
s = s[s.MS > 0]; s = s[~((s.RSSD9001 == 995151) & (s.year == 1987))]
mine = s[["RSSD9001", "year", "y", "lag", "SD", "SD2", "MS", "TER", "RMG"]].sort_values(["RSSD9001", "year"]).reset_index(drop=True)
theirs = pd.read_csv(RUN / "impl_B/out/samples/O_A.csv").sort_values(["RSSD9001", "year"]).reset_index(drop=True)
M = mine.merge(theirs, on=["RSSD9001", "year"], how="outer", suffixes=("_audit", "_impl"), indicator=True)
res = {"n_audit": len(mine), "n_impl": len(theirs), "rows_only_audit": int((M._merge == "left_only").sum()),
       "rows_only_impl": int((M._merge == "right_only").sum()), "hash_audit": sample_hash(mine), "hash_impl": sample_hash(theirs),
       "zero_filled_not_collected_counts": notcoll}
both = M[M._merge == "both"]
for v in ["y", "lag", "SD", "SD2", "MS", "TER", "RMG"]:
    res[f"max_absdiff_{v}"] = float((both[f"{v}_audit"] - both[f"{v}_impl"]).abs().max())
y88 = both[both.year == 1988]
res["audit_year_1988_rows"] = int(len(y88))
res["audit_year_1988_SD_max_absdiff"] = float((y88.SD_audit - y88.SD_impl).abs().max())
res["n_by_year_audit"] = mine.groupby("year").size().to_dict()
res["n_market_by_year_audit"] = {int(k): int(v) for k, v in B.n_market.items()}
res["banks_audit"] = int(mine.RSSD9001.nunique())
json.dump(res, open(OUT / "a3_rebuild_O_A_summary.json", "w"), indent=1, default=str)
y88[["RSSD9001", "year", "SD_audit", "SD_impl"]].to_csv(OUT / "a3_rebuild_O_A_SD_1988.csv", index=False)
B.to_csv(OUT / "a3_rebuild_O_A_market_by_year.csv")
print(json.dumps(res, indent=1, default=str))
