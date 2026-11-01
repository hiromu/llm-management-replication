"""Spot check (not a grid rerun): C's run_spec with V233 == 0 set missing, for D04 and D33, vs out_A."""
import json, os, sys
import numpy as np, pandas as pd
HERE = os.path.dirname(os.path.abspath(__file__))
RUN = os.path.join(HERE, "../../../runs/run_20261028_v1_1")
sys.path.insert(0, os.path.join(RUN, "code_C"))
import run_grid as R  # noqa
from paperk7 import coding as C, pipeline as P  # noqa
raw = R.load_raw(os.path.join(RUN, "inputs/survey.csv"))
raw.loc[raw["V233"] == 0, "V233"] = np.nan
meta = C.load_metadata(os.path.join(RUN, "inputs/survey_metadata.json"))
cw = C.load_crosswalk(os.path.join(RUN, "inputs/industry_crosswalk.csv"))
specs = {s["spec_id"]: s for s in json.load(open(os.path.join(RUN, "inputs/grid_v1.json")))["specs"]}
cA = pd.read_csv(os.path.join(RUN, "out_A/coefficients.csv"))
sA = pd.read_csv(os.path.join(RUN, "out_A/model_stats.csv"))
lines = []
for sid in ["D04", "D33"]:
    res = P.run_spec(specs[sid], raw, meta, cw)
    ce = pd.DataFrame(res.coefficients).set_index(["family", "model_id", "term"])
    ra = cA[cA.spec_id == sid].set_index(["family", "model_id", "term"])
    j = ce[["estimate"]].join(ra[["estimate"]], rsuffix="_A", how="outer")
    st = pd.DataFrame(res.model_stats).set_index(["family", "model_id"])
    rs = sA[sA.spec_id == sid].set_index(["family", "model_id"])
    js = st[["r2"]].join(rs[["r2"]], rsuffix="_A")
    um = j[j.isna().any(axis=1)]
    matched = j.dropna()
    lines.append(f"{sid}: max|d est| on matched terms = {np.abs(matched.estimate - matched.estimate_A).max():.3e}; "
                 f"max|d R2| = {np.abs(js.r2 - js.r2_A).max():.3e}; unmatched terms = {list(um.index)}")
    if len(um):
        bad_models = sorted(set(m for _, m, _ in um.index))
        sub = matched.loc[[i for i in matched.index if i[1] not in bad_models]]
        lines.append(f"   excluding models {bad_models}: max|d est| = {np.abs(sub.estimate - sub.estimate_A).max():.3e}")
        hrm = matched.loc[[i for i in matched.index if i[1] in bad_models and not i[2].startswith("IND_") and i[2] != "(Intercept)"]]
        lines.append(f"   in {bad_models}, non-intercept non-dummy terms: max|d est| = {np.abs(hrm.estimate - hrm.estimate_A).max():.3e}")
txt = "\n".join(lines); print(txt)
open(os.path.join(HERE, "counterfactual_spot.txt"), "w").write(txt + "\n")
