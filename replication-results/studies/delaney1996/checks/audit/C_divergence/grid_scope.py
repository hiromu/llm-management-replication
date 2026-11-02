"""Which specs differ between out_A and out_C (read-only), and a scan of undocumented
stored codes (no value label, not declared missing) on the raw variables C reads."""
import json, os, sys
import numpy as np, pandas as pd
HERE = os.path.dirname(os.path.abspath(__file__))
RUN = os.path.join(HERE, "../../../runs/run_20261028_v1_1")
sys.path.insert(0, os.path.join(RUN, "code_C"))
from paperk7 import coding as C  # noqa
out = []
cA = pd.read_csv(os.path.join(RUN, "out_A/coefficients.csv")).set_index(["spec_id", "family", "model_id", "term"])
cC = pd.read_csv(os.path.join(RUN, "out_C/coefficients.csv")).set_index(["spec_id", "family", "model_id", "term"])
j = cA[["estimate"]].join(cC[["estimate"]], lsuffix="_A", rsuffix="_C", how="outer")
j["d"] = (j.estimate_A - j.estimate_C).abs()
per = j.groupby(level=["spec_id", "family"]).agg(max_d=("d", "max"), unmatched=("d", lambda s: int(s.isna().sum())))
per.to_csv(os.path.join(HERE, "grid_A_vs_C_by_spec_family.csv"))
out.append("spec/family cells with max|dA-C| > 1e-8 or unmatched coefficients:")
out.append(per[(per.max_d > 1e-8) | (per.unmatched > 0)].to_string())
out.append(f"total spec/family cells: {len(per)}")
raw = pd.read_csv(os.path.join(RUN, "inputs/survey.csv"))
meta = json.load(open(os.path.join(RUN, "inputs/survey_metadata.json")))["variables"]
meta = {v["name"]: v for v in meta}
out.append("\nUndocumented stored codes (categorical variables with value labels only):")
for v in C.RAW_VARS:
    m = meta.get(v, {})
    labs = set(float(k) for k in (m.get("value_labels") or {}).keys())
    if not labs or v in ("V1",):
        continue
    dm = set(float(x) for x in m.get("declared_missing_values") or [])
    vals = raw[v].dropna().unique()
    # only flag variables whose labelled codes cover a small categorical domain
    if len(labs) > 12 or len(vals) > 15:
        continue
    und = sorted(x for x in vals if float(x) not in labs | dm)
    if und:
        out.append(f"  {v}: undocumented {und} (n={int(raw[v].isin(und).sum())})")
txt = "\n".join(out)
print(txt)
open(os.path.join(HERE, "grid_scope.txt"), "w").write(txt + "\n")
