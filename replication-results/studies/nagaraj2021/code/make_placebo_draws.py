"""Write placebo_draws.csv (seed, fips, u) for every county key in a data folder's county_lookup.csv.
u is uniform on [0,1) from numpy's PCG64 with seed 20211101 + seed; seeds 0..200. Uses only county keys.

usage: make_placebo_draws.py <data_dir>
"""
import os, sys
import numpy as np
import pandas as pd

d = sys.argv[1]
keys = sorted(pd.read_csv(os.path.join(d, "county_lookup.csv"))["FIPS"].astype(int).unique())
rows = []
for s in range(0, 201):
    u = np.random.default_rng(20211101 + s).random(len(keys))
    rows.append(pd.DataFrame({"seed": s, "fips": keys, "u": np.round(u, 12)}))
pd.concat(rows).to_csv(os.path.join(d, "placebo_draws.csv"), index=False)
print(len(keys), "keys x 201 seeds")
