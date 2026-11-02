"""Dump implementation C's constructed analysis variables at spec O (org family sample)."""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
RUN = os.path.join(HERE, "../../../runs/run_20261028_v1_1")
sys.path.insert(0, os.path.join(RUN, "code_C"))
import run_grid as R  # noqa
from paperk7 import coding as C, pipeline as P  # noqa
raw = R.load_raw(os.path.join(RUN, "inputs/survey.csv"))
meta = C.load_metadata(os.path.join(RUN, "inputs/survey_metadata.json"))
cw = C.load_crosswalk(os.path.join(RUN, "inputs/industry_crosswalk.csv"))
spec = [s for s in json.load(open(os.path.join(RUN, "inputs/grid_v1.json")))["specs"] if s["spec_id"] == "O"][0]
st = spec["settings"]
fam = P.build_family_frames(raw, meta, cw, st)
fr = fam["org"]["frame"].copy(); fr["in_org"] = fam["org"]["sample"]
base, staff_items, train_items = C.build_base_frame(C.apply_records(raw, st), meta, cw, st)
for i, c in enumerate(staff_items.columns, 1): fr[f"staff_i{i}"] = staff_items[c]
for i, c in enumerate(train_items.columns, 1): fr[f"train_i{i}"] = train_items[c]
fr = fr.rename(columns={"IND_GROUP": "IND"})
cols = ["V1", "POP"] + C.HRM_TERMS + C.ORG_CONTROLS + ["IND"] + [f"staff_i{i}" for i in (1,2,3)] + [f"train_i{i}" for i in (1,2,3)] + ["in_org"]
fr[cols].to_csv(os.path.join(HERE, "frame_C_O.csv"), index=False, na_rep="NA")
print("rows", len(fr), "org sample", int(fr["in_org"].sum()))
