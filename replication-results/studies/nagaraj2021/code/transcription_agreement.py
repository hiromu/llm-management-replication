"""Transcription agreement between the two readers' sealed targets (initial outputs).
Regression entries in Tables 3-7 are matched by table, panel and column position; value, SE, stars and N are compared
after normalizing minus signs, parentheses and thousands separators. Tables 1 and 2 are compared as multisets of
normalized printed numbers per table, because the readers keyed rows differently."""
import json, os, re
from collections import Counter
STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def load(r): return json.load(open(os.path.join(STUDY, f"readers/{r}/initial_v1/targets.json")))
def norm(v):
    if v is None: return None
    s = str(v).replace("−", "-").replace(",", "").strip("() ")
    return s or None
def regs(t):
    out = {}
    for x in t:
        if x["table_or_figure"] in ("Table 3", "Table 4", "Table 5", "Table 6", "Table 7") and x["statistic_type"] == "coefficient":
            key = (x["table_or_figure"], (x["panel"] or "")[-1:] if x["panel"] else "", x["row_term"].split()[0])
            out.setdefault(key, []).append(x)
    return out
O, A = regs(load("opus")), regs(load("astra"))
fields, agree, mism = 0, 0, []
for k in sorted(set(O) | set(A)):
    o, a = O.get(k, []), A.get(k, [])
    for i in range(max(len(o), len(a))):
        for f in ("value", "se", "stars", "n_obs"):
            fields += 1
            vo = norm(o[i][f]) if i < len(o) else "MISSING"
            va = norm(a[i][f]) if i < len(a) else "MISSING"
            if vo == va: agree += 1
            else: mism.append((k, i + 1, f, vo, va))
tab = {}
for tname in ("Table 1", "Table 2"):
    def nums(t):
        c = Counter()
        for x in t:
            if x["table_or_figure"] == tname:
                for f in ("value", "se"):
                    v = norm(x.get(f))
                    if v and re.fullmatch(r"-?[\d.]+", v): c[v] += 1
        return c
    co, ca = nums(load("opus")), nums(load("astra"))
    tab[tname] = {"opus_numbers": sum(co.values()), "astra_numbers": sum(ca.values()), "common": sum((co & ca).values()),
                  "only_opus": sorted((co - ca).elements())[:30], "only_astra": sorted((ca - co).elements())[:30]}
res = {"regression_fields": fields, "regression_fields_agree": agree, "mismatches": mism, "tables_1_2": tab}
json.dump(res, open(os.path.join(STUDY, "reconciliation/transcription_agreement_initial.json"), "w"), indent=1, default=str)
print(fields, agree, mism[:10]); print(json.dumps(tab, indent=1))
