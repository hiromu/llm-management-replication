"""Audit task 7: post hoc, NON-SCORING adversarial diagnostics for the discrepancy candidates.

Nothing here changes a label, tolerance, grid level, sample or scoring rule; no result below is a scored
specification. Diagnostics:
 D1 published internal consistency (SSE/F arithmetic in a1) and omitted-variable identities linking Models 1-3:
    b_X(M2) = b_X(M3) + b_SD2(M3) * delta_X, b_X(M1) = b_X(M2) + b_SD(M2) * gamma_X, where delta/gamma are the
    weighted auxiliary-regression coefficients. Published delta/gamma are implied from Table 2; reconstructed ones
    are computed exactly from the O_A/O_B samples and checked against the identity.
 D2 joint view of the H3 pair (b_SD, b_SD2): coefficient correlation, turning point, SE of SD2 implied by the
    printed F(M3 vs M2) = 134.1, decomposition of the M3 SD-term gap.
 D3 Table 1 descriptives vs the O_A/O_B samples under the frozen descriptive rule (printed interval widened by
    10% relative), with an N-consistency check on mean market share.
 D4 sample-size anatomy: rows by year and county, and the share of total WLS weight carried by the largest banks.
 D5 outlier check: externally studentized WLS residuals with the named row retained (O_A construction rebuilt
    without R10 deletion; must reproduce the O_A hash once the row is deleted).
 D6 H2 at O_B: which single O_A->O_B axis switch moves M2 SD from p<.001 to p~.09 (frozen grid specs only).
Run: ~/.venv/bin/python -I checks/audit_v1/a7_adversarial_diagnostics.py <STUDY>
"""
import json, sys, hashlib
from pathlib import Path
import numpy as np, pandas as pd
from scipy import stats

ST = Path(sys.argv[1]); OUT = ST / "checks/audit_v1"; RUN = ST / "runs/run_v1"
res = {}
TERMS = {"M1": ["MS", "TER", "RMG", "lag"], "M2": ["SD", "MS", "TER", "RMG", "lag"], "M3": ["SD2", "SD", "MS", "TER", "RMG", "lag"]}

def wls(d, y, X, w):
    Xm = np.column_stack([np.ones(len(d))] + [d[c].values for c in X]); sw = np.sqrt(d[w].values)
    Xw, yw = Xm * sw[:, None], d[y].values * sw
    XtX = Xw.T @ Xw; b = np.linalg.solve(XtX, Xw.T @ yw); e = yw - Xw @ b
    n, k = Xm.shape; s2 = e @ e / (n - k); cov = s2 * np.linalg.inv(XtX)
    H = Xw @ np.linalg.solve(XtX, Xw.T); h = np.diag(H)
    s2_i = ((n - k) * s2 - e ** 2 / (1 - h)) / (n - k - 1)
    rst = e / np.sqrt(s2_i * (1 - h))
    return dict(names=["intercept"] + X, b=b, se=np.sqrt(np.diag(cov)), cov=cov, sse=float(e @ e), rstudent=rst, n=n, k=k)

PUB = {"M1": {"intercept": 0.929, "MS": -0.576, "TER": -9.948, "RMG": 0.014, "lag": 0.369},
       "M2": {"intercept": 1.164, "SD": -0.020, "MS": -0.093, "TER": -10.601, "RMG": 0.016, "lag": 0.361},
       "M3": {"intercept": 0.511, "SD2": -0.006, "SD": 0.170, "MS": -0.457, "TER": -15.387, "RMG": 0.018, "lag": 0.403}}

# ---------------- D1/D2 -----------------
d1 = []; d2 = {}
for o in ["O_A", "O_B"]:
    d = pd.read_csv(RUN / "impl_B/out/samples" / f"{o}.csv")
    f = {m: wls(d, "y", TERMS[m], "MS") for m in TERMS}
    est = {m: dict(zip(f[m]["names"], f[m]["b"])) for m in f}
    aux3 = wls(d, "SD2", TERMS["M2"], "MS"); dl = dict(zip(aux3["names"], aux3["b"]))   # SD2 on M2 regressors
    aux2 = wls(d, "SD", TERMS["M1"], "MS"); gm = dict(zip(aux2["names"], aux2["b"]))    # SD on M1 regressors
    for x in ["intercept", "SD", "MS", "TER", "RMG", "lag"]:
        ident = est["M3"][x] + est["M3"]["SD2"] * dl[x]
        pub_delta = (PUB["M2"][x] - PUB["M3"][x]) / PUB["M3"]["SD2"]
        d1.append(dict(origin=o, link="M3->M2 via SD2", term=x, rec_b_M3=est["M3"][x], rec_b_M2=est["M2"][x],
                       identity_check=abs(ident - est["M2"][x]), rec_aux_coef=dl[x], pub_implied_aux_coef=pub_delta))
    for x in ["intercept", "MS", "TER", "RMG", "lag"]:
        ident = est["M2"][x] + est["M2"]["SD"] * gm[x]
        pub_g = (PUB["M1"][x] - PUB["M2"][x]) / PUB["M2"]["SD"]
        d1.append(dict(origin=o, link="M2->M1 via SD", term=x, rec_b_M3=None, rec_b_M2=est["M2"][x], identity_check=abs(ident - est["M1"][x]),
                       rec_aux_coef=gm[x], pub_implied_aux_coef=pub_g))
    m3 = f["M3"]; iS, iQ = m3["names"].index("SD"), m3["names"].index("SD2")
    bS, bQ = m3["b"][iS], m3["b"][iQ]; C = m3["cov"][np.ix_([iS, iQ], [iS, iQ])]
    diff = np.array([0.170 - bS, -0.006 - bQ])
    # published pair as a point vs reconstructed sampling covariance (post hoc; reconstructed-SE units)
    maha = float(np.sqrt(diff @ np.linalg.solve(C, diff)))
    dSD = dl["SD"]
    d2[o] = {"b_SD": bS, "b_SD2": bQ, "corr_bSD_bSD2": C[0, 1] / np.sqrt(C[0, 0] * C[1, 1]),
             "turning_point_rec": -bS / (2 * bQ), "turning_point_pub_point": 0.170 / 0.012,
             "turning_point_pub_rounding_range": [0.1695 / 0.013, 0.1705 / 0.011],
             "aux_delta_SD_rec": dSD, "aux_delta_SD_pub_implied": (0.170 + 0.020) / 0.006,
             "aux_delta_SD_pub_rounding_range": [(0.1695 + 0.0195) / 0.0065, (0.1705 + 0.0205) / 0.0055],
             "SD_gap_pub_minus_rec": 0.170 - bS,
             "gap_part_from_M2_SD": (-0.020) - est["M2"]["SD"],
             "gap_part_from_SD2_magnitude_at_rec_delta": (0.006 - (-bQ)) * dSD,
             "gap_part_from_delta": 0.006 * ((0.190 / 0.006) - dSD),
             "SD2_true_SE_implied_by_F134.1": [0.000475, 0.000561],
             "SD2_gap_in_implied_true_SE_units": [(abs(-0.0055 - bQ)) / 0.000561, (abs(-0.006 - bQ)) / 0.000518],
             "mahalanobis_pub_pair_vs_rec_cov_posthoc": maha,
             "rec_SSE": {m: f[m]["sse"] for m in f}, "pub_SSE": {"M1": 2.978, "M2": 2.886, "M3": 2.530}}
D1 = pd.DataFrame(d1); D1.to_csv(OUT / "a7_D1_ovb_identities.csv", index=False)
res["D2_H3_joint"] = d2

# ---------------- D3 Table 1 -----------------
T1 = {"y": (0.000, 0.007, 100), "lag": (0.000, 0.007, 100), "SD2": (66.956, 66.548, 1), "SD": (7.640, 2.932, 1),
      "MS": (0.008, 0.037, 1), "TER": (0.085, 0.012, 1), "RMG": (-1.094, 5.492, 1)}
COR = {("lag", "y"): 0.62, ("SD2", "y"): -0.12, ("SD2", "lag"): -0.14, ("SD", "y"): -0.14, ("SD", "lag"): -0.17, ("SD", "SD2"): 0.95,
       ("MS", "y"): -0.04, ("MS", "lag"): -0.08, ("MS", "SD2"): 0.49, ("MS", "SD"): 0.41, ("TER", "y"): -0.45, ("TER", "lag"): -0.40,
       ("TER", "SD2"): 0.09, ("TER", "SD"): 0.13, ("TER", "MS"): -0.03, ("RMG", "y"): 0.01, ("RMG", "lag"): -0.01, ("RMG", "SD2"): 0.00,
       ("RMG", "SD"): 0.00, ("RMG", "MS"): -0.02, ("RMG", "TER"): 0.08}
def within(v, pub, dec):
    h = 0.5 * 10 ** -dec; lo, hi = pub - h, pub + h
    w = 0.1 * max(abs(lo), abs(hi))
    return lo - w <= v <= hi + w
d3 = []
for o in ["O_A", "O_B"]:
    d = pd.read_csv(RUN / "impl_B/out/samples" / f"{o}.csv")
    for v, (mu, sd, sc) in T1.items():
        m_, s_ = d[v].mean() / sc, d[v].std(ddof=1) / sc
        d3.append(dict(origin=o, stat="mean", var=v, published=mu, reconstructed=m_, agree=within(m_, mu, 3)))
        d3.append(dict(origin=o, stat="sd", var=v, published=sd, reconstructed=s_, agree=within(s_, sd, 3)))
    for (a, b), r in COR.items():
        rv = d[a].corr(d[b]); d3.append(dict(origin=o, stat="corr", var=f"{a}|{b}", published=r, reconstructed=rv, agree=within(rv, r, 2)))
    sumMS = d.MS.sum()
    res.setdefault("D3_ms_consistency", {})[o] = {"sum_MS": sumMS, "mean_MS_at_rec_N": sumMS / len(d), "mean_MS_if_same_sum_over_960": sumMS / 960,
                                                   "published_mean_MS": 0.008}
D3 = pd.DataFrame(d3); D3.to_csv(OUT / "a7_D3_table1_compare.csv", index=False)
res["D3_table1_agree_counts"] = D3.groupby(["origin", "stat"]).agree.agg(["sum", "count"]).reset_index().to_dict("records")

# ---------------- D4 sample anatomy -----------------
core = pd.read_parquet(ST / "data/derived/call_mnwi_core_1983q4_1993q4.parquet", columns=["RSSD9001", "quarter", "RSSD9210", "RSSD9150", "RSSD9010"])
q4 = core[core.quarter.str.endswith("Q4")].copy(); q4["year"] = q4.quarter.str[:4].astype(int)
q4 = q4.drop_duplicates(["RSSD9001", "year"])
cty = pd.read_parquet(ST / "data/derived/msa_minneapolis_stpaul_counties_by_vintage.parquet")
cty = cty[(cty.area_code.astype(str) == "5120") & (cty.omb_definition_date.astype(str).str[:10] == "1983-06-27")][["county_fips5", "county_name"]]
cty["county_fips5"] = cty.county_fips5.astype(int)
d4 = {}
for o in ["O_A", "O_B"]:
    d = pd.read_csv(RUN / "impl_B/out/samples" / f"{o}.csv").merge(q4, on=["RSSD9001", "year"], how="left")
    d["fips"] = d.RSSD9210.astype(int) * 1000 + d.RSSD9150.astype(int)
    d = d.merge(cty, left_on="fips", right_on="county_fips5", how="left")
    wb = d.groupby(["RSSD9001"]).MS.sum().sort_values(ascending=False)
    names = d.drop_duplicates("RSSD9001").set_index("RSSD9001").RSSD9010
    d4[o] = {"rows_by_year": d.groupby("year").size().to_dict(), "rows_by_county": d.groupby("county_name").size().to_dict(),
             "banks": int(d.RSSD9001.nunique()),
             "weight_share_top_banks": {f"{int(k)} {names.get(k, '')}": round(float(v / wb.sum()), 4) for k, v in wb.head(5).items()},
             "rows_small_MS_lt_0.001": int((d.MS < 0.001).sum()),
             "weight_share_rows_MS_lt_0.001": float(d.MS[d.MS < 0.001].sum() / d.MS.sum())}
res["D4_sample_anatomy"] = d4

# ---------------- D5 outlier check (rebuild O_A without deletion) -----------------
sys.path.insert(0, str(OUT))
from a_rebuild_lib import build_O_A
full, _ = build_O_A(ST, delete_named=False)
ded = full[~((full.RSSD9001 == 995151) & (full.year == 1987))]
lines = sorted(f"{int(a)},{int(b)}" for a, b in zip(ded.RSSD9001, ded.year))
hsh = hashlib.sha256("".join(l + "\n" for l in lines).encode()).hexdigest()
d5 = {"rebuild_hash_after_deletion_matches_O_A": hsh == pd.read_csv(RUN / "impl_B/out/spec_results.csv").query("spec_id=='O_A'").sample_hash.iloc[0],
      "n_with_named_row": len(full)}
for m in TERMS:
    f = wls(full, "y", TERMS[m], "MS"); r = np.abs(f["rstudent"]); order = np.argsort(-r)
    top = full.iloc[order[:3]][["RSSD9001", "year"]].astype(int).values.tolist()
    d5[m] = {"top3_rows": top, "top3_abs_rstudent": r[order[:3]].round(2).tolist(), "ratio_first_to_second": float(r[order[0]] / r[order[1]])}
res["D5_outlier"] = d5

# ---------------- D6 H2 at O_B -----------------
R = pd.read_csv(RUN / "impl_B/out/spec_results.csv")
g = R[(R.model == "M2") & (R.term == "SD") & (R.status == "ok")]
keys = ["O_A", "O_B", "O_A__R02.charter", "O_A__R05.all4", "O_A__R14.literal", "O_A__R15.missing", "O_A__R18.consolidated",
        "O_B__R02.charter_entity", "O_B__R05.min2_fallback", "O_B__R14.broad", "O_B__R15.zero_if_not_collected", "O_B__R18.domestic"]
res["D6_H2_M2_SD"] = g[g.spec_id.isin(keys)][["spec_id", "n", "estimate", "se", "p_two_sided"]].set_index("spec_id").loc[keys].reset_index().to_dict("records")
json.dump(res, open(OUT / "a7_adversarial_diagnostics.json", "w"), indent=1, default=float)
pd.set_option("display.width", 250)
print(D1.to_string()); print(json.dumps(res, indent=1, default=float))
print(D3.to_string())
