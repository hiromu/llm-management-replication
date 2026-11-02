"""Synthetic data in the formats of the real bundle, for implementer development and pre-execution checks.
No real value is used: county keys, outcomes, controls, dates and coordinates are drawn at random. The files reproduce
the real formats, including quoted repeated header lines, two malformed rows with an empty quarter, absent
county-quarters, a never-observed quarter (2005q3), FIPS stored as text in the Excel file and a leading space in the
boundary-file header. Planted effects (log scale): post x treat on follow-on fields -0.20, on users -0.05.

usage: make_synthetic.py <out_dir> <seed>
Also writes placebo_draws.csv for the out_dir's county keys (see code/make_placebo_draws.py).
"""
import csv, datetime, math, os, sys
import numpy as np
import pandas as pd
import pyreadstat

out, seed = sys.argv[1], int(sys.argv[2])
os.makedirs(out, exist_ok=False)
rng = np.random.default_rng(seed)

states = {1: "Alabama", 6: "California", 12: "Florida", 25: "Massachusetts", 36: "New York", 48: "Texas", 53: "Washington"}
counties = []
for st, name in states.items():
    for c in range(1, 2 * int(rng.integers(20, 70)), 2):
        counties.append((st, name, c, st * 1000 + c))
lookup = pd.DataFrame(counties, columns=["STATE_FIPS", "STATE_NAME", "CNTY_FIPS", "FIPS"])
lookup["NAME"] = [f"County {i}" for i in range(len(lookup))]
lookup["area"] = rng.lognormal(6.5, 0.8, len(lookup)).round(2)
lookup["population"] = rng.lognormal(10, 1.2, len(lookup)).round(0)
lookup["treat"] = (rng.random(len(lookup)) < 0.6).astype(int)
lookup = lookup[["NAME", "STATE_NAME", "STATE_FIPS", "CNTY_FIPS", "FIPS", "area", "population", "treat"]]
lookup.iloc[:-3].to_csv(os.path.join(out, "county_lookup.csv"), index=False)   # last 3 counties absent from lookup
fips = lookup["FIPS"].to_numpy()
treat = dict(zip(lookup.FIPS, lookup.treat))

# quarterly.csv
cols = ["geoid", "quarter", "totaltigerall", "totalowneredit", "totaltaga", "totaltagv2a", "totaltagb", "totaltagv2b",
        "totaltagh", "totaltagv2h", "totalversion2", "totalversion3", "totalversion4plus", "totalchange", "totalcontrib",
        "totalusers", "totalnewusers", "totalpctcontrib25", "totalpctcontrib50", "totalpctcontrib75", "totalpctcontrib99",
        "totaloldusers_active", "totaloldfocused1", "totaloldfocused5", "totalpctcontrib10", "totalpctcontrib90"]
quarters = [f"{y}q{q}" for y in range(2005, 2015) for q in range(1, 5) if (y, q) not in ((2005, 1), (2005, 3))] + ["2015q1"]
lines = ["\t".join(cols)]
size = dict(zip(fips, rng.normal(0, 1, len(fips))))
for f in fips:
    if rng.random() < 0.02:
        continue                                   # county never observed
    lines.append("\t".join(f'"{c}"' for c in cols))
    for qi, q in enumerate(quarters):
        if rng.random() < 0.25:
            continue                               # absent county-quarter
        y = int(q[:4])
        post = q >= "2008q1"
        base = math.exp(1.5 + size[f] + 0.25 * (y - 2005))
        eff = math.exp(-0.20) if (post and treat[f]) else 1.0
        effu = math.exp(-0.05) if (post and treat[f]) else 1.0
        tag = {k: int(rng.poisson(base * w * eff)) for k, w in
               dict(a=0.2, v2a=0.1, b=0.4, v2b=0.2, h=0.6, v2h=0.3).items()}
        users = int(rng.poisson(max(base, 1) ** 0.5 * 2 * effu))
        new = int(rng.binomial(users, 0.6)) if users else 0
        old = users - new
        f1 = int(rng.binomial(old, 0.5)) if old else 0
        f5 = f1 + (int(rng.binomial(old - f1, 0.5)) if old - f1 else 0)
        if rng.random() < 0.01:
            f5 = max(f1 - 1, 0)                     # occasional focused5 < focused1
        pct = sorted(int(rng.binomial(new, p)) if new else 0 for p in (0.9, 0.75, 0.5, 0.25, 0.1, 0.01))[::-1]
        contrib = sum(tag.values()) + int(rng.poisson(base * 2 * eff))
        vals = {"geoid": str(f), "quarter": q, "totaltigerall": int(rng.poisson(base)), "totalowneredit": int(rng.poisson(base * 0.3 * eff)),
                "totaltaga": tag["a"], "totaltagv2a": tag["v2a"], "totaltagb": tag["b"], "totaltagv2b": tag["v2b"],
                "totaltagh": tag["h"], "totaltagv2h": tag["v2h"], "totalversion2": int(rng.poisson(base * 0.5)),
                "totalversion3": int(rng.poisson(base * 0.2)), "totalversion4plus": int(rng.poisson(base * 0.1)),
                "totalchange": int(rng.poisson(base)), "totalcontrib": contrib, "totalusers": users, "totalnewusers": new,
                "totalpctcontrib10": pct[0], "totalpctcontrib25": pct[1], "totalpctcontrib50": pct[2], "totalpctcontrib75": pct[3],
                "totalpctcontrib90": pct[4], "totalpctcontrib99": pct[5], "totaloldusers_active": old,
                "totaloldfocused1": f1, "totaloldfocused5": f5}
        lines.append("\t".join(f'"{vals[c]}"' for c in cols))
for f in fips[:2]:                                  # two malformed rows
    lines.append("\t".join([f'"{f}"', '""'] + ['"7"'] * (len(cols) - 4) + ['"totalpctcontrib10"', '"totalpctcontrib90"']))
open(os.path.join(out, "quarterly.csv"), "w").write("\n".join(lines) + "\n")

# acs5year.dta
acs = []
for f in fips:
    if rng.random() < 0.01:
        continue                                   # county with no ACS rows
    pop = float(rng.lognormal(10, 1.2))
    for y in range(2005, 2012):
        if rng.random() < 0.03:
            continue                               # missing year
        g = 1 + 0.01 * (y - 2005)
        acs.append(dict(geo_fips=int(f), geo_state=int(f // 1000), population=int(pop * g), popdensity=float(pop / rng.uniform(200, 3000)),
                        area=float(rng.uniform(200, 3000)), popmales=int(pop * g * 0.49), households=int(pop * g * 0.38),
                        unemploymentrate=int(rng.integers(2, 15)), income_householdmedian=float(rng.normal(45000, 9000)),
                        income_medianearnings=float(rng.normal(30000, 5000)), income_percapita=float(rng.normal(23000, 5000)),
                        popeduc=float(pop * g * rng.uniform(0.1, 0.4)), popyoungmales=float(pop * g * 0.18), acsyear=float(y)))
acs = pd.DataFrame(acs).astype({"geo_fips": "int32", "geo_state": "int8", "population": "int32", "popdensity": "float32",
                                "area": "float32", "popmales": "int32", "households": "int32", "unemploymentrate": "int32",
                                "popeduc": "float32", "popyoungmales": "float32", "acsyear": "float32"})
pyreadstat.write_dta(acs, os.path.join(out, "acs5year.dta"))

# boundary-counties.csv: random symmetric neighbours within state
nb = {int(f): set() for f in fips}
for st in states:
    fs = [int(f) for f in fips if f // 1000 == st]
    for i, f in enumerate(fs):
        for g in fs[i + 1:i + 1 + int(rng.integers(1, 5))]:
            nb[f].add(g); nb[g].add(f)
with open(os.path.join(out, "boundary-counties.csv"), "w", newline="") as fh:
    fh.write("source county, border counties\n")
    for f in fips[:-1]:
        lst = sorted(nb[int(f)] | ({int(f)} if rng.random() < 0.05 else set()))
        fh.write(f'{int(f)},{";".join(map(str, lst))}\n')

# timing.xlsx
t = pd.DataFrame({"ID": range(1, len(fips) + 1), "FIPS": [f"{int(f):05d}" for f in fips], "County": lookup.NAME.tolist(),
                  "SB Selected": ["S"] * len(fips), "Thread": rng.integers(1, 11, len(fips)).astype(float),
                  "Sch SB Delivery": [datetime.datetime(2002, 6, 1) + datetime.timedelta(days=int(d)) for d in rng.integers(0, 1900, len(fips))]})
t.loc[rng.random(len(t)) < 0.02, "Sch SB Delivery"] = pd.NaT
t.to_excel(os.path.join(out, "timing.xlsx"), sheet_name="MTAIP_Upload_Dates", index=False)

# distance.csv
drows = []
for f in fips:
    if rng.random() < 0.25:
        continue
    for _ in range(int(rng.integers(5, 21))):
        lat, lon = rng.uniform(26, 48), rng.uniform(-123, -70)
        dlat, dlon = lat + rng.normal(0, 0.1), lon + rng.normal(0, 0.1)
        g = int(rng.uniform(1000, 40000))
        eff = 1.15 if treat[int(f)] else 1.0
        o = g if rng.random() < 0.03 else g + rng.normal(0, 1) * 300 * eff
        drows.append(dict(origin_lat=lat, origin_lon=lon, dest_lat=dlat, dest_lon=dlon, fips=int(f), ggl_distance=g, osrm_distance=round(o, 1)))
pd.DataFrame(drows).to_csv(os.path.join(out, "distance.csv"), sep="\t", index=False)
print(len(lookup), "counties;", len(lines), "quarterly lines;", len(acs), "acs rows;", len(drows), "pairs")
