"""POST HOC, NON-SCORING: apply the frozen term rule (auditor's independent scorer, a5) to the seven-county
diagnostic estimates of a7d, for description only. Does not enter claim or paper outcomes.
Run: ~/.venv/bin/python -I checks/audit_v1/a7e_posthoc_7county_score.py <STUDY>
"""
import sys
from pathlib import Path
import pandas as pd
ST = Path(sys.argv[1]); OUT = ST / "checks/audit_v1"
src = open(OUT / "a5_scoring_audit.py").read().split("R = pd.read_csv")[0]
ns = {"__name__": "a5lib"}; exec(src, ns); score, PUB = ns["score"], ns["PUB"]
D = pd.read_csv(OUT / "a7d_posthoc_7county_estimates.csv")
rows = []
for (m, t) in PUB:
    r = D[(D.model == m) & (D.term == t)].iloc[0]
    rows.append(dict(model=m, term=t, pub=PUB[(m, t)][0], est=r.estimate, p=r.p, **score((m, t), r.estimate, r.se, r.p)))
S = pd.DataFrame(rows); S.to_csv(OUT / "a7e_posthoc_7county_termscores.csv", index=False)
pd.set_option("display.width", 200); print(S.round(4).to_string())
