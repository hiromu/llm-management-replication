"""Audit task 4: completeness of the frozen run.

Expected spec set from reconciliation/grid_v1.json: base O_A and O_B, plus for each origin every level of every
axis that differs from that origin's own level (spec_id '<origin>__<level>'). Every expected spec x model
(M1, M2, M3, M3_SQ) must have at least one row with a status in each implementation's spec_results.csv.
Influence: for O_A/O_B x M2/M3, one bank_year fit per estimation row and one bank fit per bank, each recorded
for the registered focal terms.
Run: ~/.venv/bin/python -I checks/audit_v1/a4_completeness_audit.py <STUDY>
"""
import json, sys
from pathlib import Path
import pandas as pd

ST = Path(sys.argv[1]); OUT = ST / "checks/audit_v1"; RUN = ST / "runs/run_v1"
grid = json.load(open(ST / "reconciliation/grid_v1.json"))
own = {"O_A": {}, "O_B": {}}
for a in grid["axes"]:
    for l in a["levels"]:
        for o in l.get("origin_of", []):
            own[o][a["axis"]] = l["id"]
expected = ["O_A", "O_B"]
for o in ["O_A", "O_B"]:
    for a in grid["axes"]:
        for l in a["levels"]:
            if l["id"] != own[o][a["axis"]]:
                expected.append(f"{o}__{l['id']}")
models = ["M1", "M2", "M3", "M3_SQ"]
rows, summ = [], {}
for impl in ["impl_A", "impl_B", "impl_C"]:
    R = pd.read_csv(RUN / impl / "out/spec_results.csv")
    st = R.groupby(["spec_id", "model"]).status.agg(lambda s: "|".join(sorted(set(s)))).to_dict()
    missing = [(s, m) for s in expected for m in models if (s, m) not in st]
    extra = sorted(set(R.spec_id) - set(expected))
    cnt = pd.Series([st[(s, m)] for s in expected for m in models if (s, m) in st]).value_counts().to_dict()
    for s in expected:
        for m in models:
            rows.append(dict(impl=impl, spec_id=s, model=m, status=st.get((s, m), "MISSING")))
    # influence
    I = pd.read_csv(RUN / impl / "out/influence.csv")
    inf = {}
    for o in ["O_A", "O_B"]:
        smp = pd.read_csv(RUN / impl / "out/samples" / f"{o}.csv")
        nrow, nbank = len(smp), smp.RSSD9001.nunique()
        for m, terms in {"M2": ["SD"], "M3": ["SD2", "SD"]}.items():
            for dt, nexp in [("bank_year", nrow), ("bank", nbank)]:
                g = I[(I.origin == o) & (I.model == m) & (I.deletion_type == dt)]
                for t in terms:
                    gt = g[g.term == t]
                    inf[f"{o}|{m}|{dt}|{t}"] = dict(expected=nexp, fits=len(gt), unique_ids=int(gt.deleted_id.nunique()),
                                                     ok=int((gt.status == "ok").sum()), not_ok=int((gt.status != "ok").sum()))
    summ[impl] = dict(expected_specs=len(expected), expected_spec_models=len(expected) * 4, missing=missing,
                      extra_spec_ids=extra, status_counts=cnt, influence=inf,
                      influence_terms_present=sorted(I.term.unique().tolist()))
pd.DataFrame(rows).to_csv(OUT / "a4_completeness_status.csv", index=False)
json.dump(summ, open(OUT / "a4_completeness_summary.json", "w"), indent=1)
for k, v in summ.items():
    print(k, v["expected_specs"], "missing", len(v["missing"]), "extra", v["extra_spec_ids"], v["status_counts"])
    for kk, vv in v["influence"].items():
        flag = "" if vv["fits"] == vv["expected"] == vv["unique_ids"] and vv["not_ok"] == 0 else "  <-- CHECK"
        print("   ", kk, vv, flag)
# non-ok statuses
D = pd.DataFrame(rows)
print(D[D.status != "ok"].groupby(["spec_id", "model"]).status.agg(lambda s: dict(zip(D.loc[s.index, "impl"], s))).to_string())
