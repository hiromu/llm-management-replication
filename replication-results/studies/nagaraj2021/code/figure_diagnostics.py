"""Post-unsealing figure diagnostics: author figure specifications on the AI-constructed panel.

The panel is rebuilt exactly as implementation_manifest_v1 (P1-P4, origin F1, G1). Before any specification change,
the script checks that it reproduces implementation A's frozen AN10 means and AN11 event-study coefficients.
Author specifications (from the unsealed .ado files):
  Fig 3  make_meanline.ado: county-quarter means collapsed by calendar year and treat (annual points).
  Fig 5  ddchart_cross.ado: outcome = yearly MEAN of quarterly follow-on per county, ln(+1); reg on treat only
         (the control and quartile locals are empty inside run_regs), robust SE.
  Fig 6a plot_urban.ado: one regression of ln(y+1) on post x treat x decile dummies with county and quarter FE,
         county-clustered; decile = Stata xtile (nq 10) of raw ACS popdensity over county-quarter rows; rows without
         an ACS value (2012-2014) drop.
  Fig 6b plot_users.ado: AN14 without controls.
Labelled diagnostics; no frozen result changes.
usage: figure_diagnostics.py   (network denied by the caller)
"""
import json, os
import numpy as np
import pandas as pd
import pyfixest as pf

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(STUDY, "data/derived/run_input_v1")
A = os.path.join(STUDY, "runs/run_20261101_v1/out/A")
OUT = os.path.join(STUDY, "post_unseal/figure_diagnostics")
os.makedirs(OUT, exist_ok=True)

cl = pd.read_csv(os.path.join(D, "county_lookup.csv"))
U = cl[cl.STATE_NAME != "Massachusetts"][["FIPS", "treat"]].rename(columns={"FIPS": "fips"})
q = pd.read_csv(os.path.join(D, "quarterly.csv"), sep="\t", dtype=str)
q = q[(q.geoid != "geoid") & q.quarter.notna() & (q.quarter != "")]
for c in q.columns[2:]:
    q[c] = pd.to_numeric(q[c], errors="coerce")
q = q.dropna(subset=list(q.columns[2:]))
q["fips"] = q.geoid.astype(int)
quarters = [f"{y}q{k}" for y in range(2005, 2015) for k in range(1, 5) if not (y == 2005 and k == 1)]
grid = pd.MultiIndex.from_product([U.fips, quarters], names=["fips", "quarter"]).to_frame(index=False)
pan = grid.merge(q.drop(columns="geoid"), on=["fips", "quarter"], how="left").fillna(0).merge(U, on="fips")
pan["year"] = pan.quarter.str[:4].astype(int)
pan["qn"] = pan.quarter.str[-1].astype(int)
pan["t"] = (pan.year - 1960) * 4 + pan.qn - 1
pan["post"] = (pan.quarter >= "2008q1").astype(int)
pan["followon"] = pan.totaltaga + pan.totaltagb + pan.totaltagh
pan["total"] = pan.totalcontrib
pan["contributors"] = pan.totalusers
checks = {}

# --- check 1: AN10 quarterly means (G1) against frozen A
a10 = pd.read_csv(os.path.join(A, "an10_means.csv"))
a10 = a10[(a10.statistic == "mean_log_y_plus_1") & (a10.followon_def.isna() | (a10.followon_def == "followon_F1"))]
mine = []
for o in ("total", "followon"):
    m = pan.assign(v=np.log1p(pan[o])).groupby(["quarter", "treat"]).v.mean().reset_index()
    m["outcome"] = o
    mine.append(m)
mine = pd.concat(mine)
cmp = a10.merge(mine, on=["outcome", "quarter", "treat"])
checks["AN10_max_abs_diff"] = float((cmp.value - cmp.v).abs().max())
checks["AN10_rows_compared"] = int(len(cmp))

# --- check 2: AN11 event study against frozen A
aR = pd.read_csv(os.path.join(A, "results.csv"), dtype={"spec_id": str})
cy = pan.groupby(["fips", "year", "treat"])[["followon", "contributors"]].sum().reset_index()
ev = {}
for o, spec in (("followon", "S00055"), ("contributors", "S00056")):
    d = cy.assign(y=np.log1p(cy[o]))
    for yr in range(2005, 2015):
        if yr != 2007:
            d[f"tx{yr}"] = (d.treat * (d.year == yr)).astype(float)
    f = pf.feols("y ~ " + " + ".join(f"tx{yr}" for yr in range(2005, 2015) if yr != 2007) + " | fips + year", d, vcov={"CRV1": "fips"})
    co = f.coef()
    ref = aR[aR.spec_id == spec].set_index("term").estimate
    checks[f"AN11_{o}_max_abs_diff"] = float(max(abs(co[f"tx{yr}"] - ref[f"treat_x_{yr}"]) for yr in range(2005, 2015) if yr != 2007))
    ev[o] = co
json.dump(checks, open(os.path.join(OUT, "reproduction_checks.json"), "w"), indent=1)
print("checks", checks)
assert checks["AN10_max_abs_diff"] < 1e-9 and checks["AN11_followon_max_abs_diff"] < 1e-8 and checks["AN11_contributors_max_abs_diff"] < 1e-8

# --- Fig 3 author: annual means by year and treat
pan = pan.sort_values(["fips", "t"])
rows = []
for o in ("total", "followon"):
    pan[f"cum_{o}"] = pan.groupby("fips")[o].cumsum()
    g = pan.assign(lnv=np.log1p(pan[o])).groupby(["year", "treat"]).agg(lnmean=("lnv", "mean"), cummean=(f"cum_{o}", "mean")).reset_index()
    g["outcome"] = o
    rows.append(g)
pd.concat(rows).to_csv(os.path.join(OUT, "fig3_author_annual.csv"), index=False)

# --- Fig 5 author: yearly mean, ln(+1), treat only, HC1
ym = pan.groupby(["fips", "year", "treat"]).followon.mean().reset_index()
r5 = []
for yr in range(2005, 2015):
    d = ym[ym.year == yr].assign(y=lambda x: np.log1p(x.followon))
    f = pf.feols("y ~ treat", d, vcov="HC1")
    b, se = f.coef()["treat"], f.se()["treat"]
    r5.append({"year": yr, "estimate": b, "se": se, "ci_low": b - 1.96 * se, "ci_high": b + 1.96 * se, "n": len(d)})
pd.DataFrame(r5).to_csv(os.path.join(OUT, "fig5_author_spec.csv"), index=False)


# --- Fig 6a author: pooled interaction, xtile deciles of raw popdensity over county-quarter rows
def stata_xtile(x, nq):
    v = np.sort(x[~np.isnan(x)])
    n = len(v)
    cuts = []
    for k in range(1, nq):
        p = n * k / nq
        i = int(np.floor(p))
        h = p - i
        cuts.append(v[i] if h > 0 else (v[i - 1] + v[i]) / 2)
    out = np.full(len(x), np.nan)
    ok = ~np.isnan(x)
    out[ok] = np.searchsorted(np.array(cuts), x[ok], side="left") + 1
    return out


acs = pd.read_stata(os.path.join(D, "acs5year.dta"))[["geo_fips", "acsyear", "popdensity"]]
acs = acs.rename(columns={"geo_fips": "fips", "acsyear": "year"}).astype({"fips": int, "year": int})
p6 = pan.merge(acs, on=["fips", "year"], how="left")
p6["dec"] = stata_xtile(p6.popdensity.to_numpy(dtype=float), 10)
r6 = []
for o in ("followon", "contributors"):
    d = p6.dropna(subset=["dec"]).assign(y=lambda x: np.log1p(x[o]))
    for k in range(1, 11):
        d[f"ptd{k}"] = (d.post * d.treat * (d.dec == k)).astype(float)
    f = pf.feols("y ~ " + " + ".join(f"ptd{k}" for k in range(1, 11)) + " | fips + t", d, vcov={"CRV1": "fips"})
    for k in range(1, 11):
        b, se = f.coef()[f"ptd{k}"], f.se()[f"ptd{k}"]
        r6.append({"outcome": o, "decile": k, "estimate": b, "se": se, "ci_low": b - 1.96 * se, "ci_high": b + 1.96 * se, "n": len(d)})
pd.DataFrame(r6).to_csv(os.path.join(OUT, "fig6a_author_spec.csv"), index=False)

# --- Fig 6b author: no controls
r6b = []
for p in (10, 25, 50, 75, 90, 99):
    d = pan.assign(y=np.log1p(pan[f"totalpctcontrib{p}"]), pt=(pan.post * pan.treat).astype(float))
    f = pf.feols("y ~ pt | fips + t", d, vcov={"CRV1": "fips"})
    b, se = f.coef()["pt"], f.se()["pt"]
    r6b.append({"pct": p, "estimate": b, "se": se, "ci_low": b - 1.96 * se, "ci_high": b + 1.96 * se, "n": len(d)})
pd.DataFrame(r6b).to_csv(os.path.join(OUT, "fig6b_author_spec.csv"), index=False)
print("written", os.listdir(OUT))
