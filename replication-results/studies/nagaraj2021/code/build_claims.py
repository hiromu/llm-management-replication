"""Freeze the scored claim records: each ledger unit with its sealed published values (from the readers' initial
targets), its origin grid row and its uncertain-branch grid rows. Writes sealed/targets/targets_v1.json and
scoring/claims_v1.json. Run before any empirical fit."""
import csv, json, os, re

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T_O = json.load(open(os.path.join(STUDY, "readers/opus/initial_v1/targets.json")))
T_A = json.load(open(os.path.join(STUDY, "readers/astra/initial_v1/targets.json")))
LEDGER = {r["unit"]: r for r in csv.DictReader(open(os.path.join(STUDY, "reconciliation/claim_ledger_initial.csv")))}
GRID = list(csv.DictReader(open(os.path.join(STUDY, "manifest/grid_v1.csv"))))
BASEKEYS = ["analysis", "outcome", "sample", "ctrl", "variant", "seed", "period", "decile", "est"]


def norm(v):
    return None if v in (None, "") else str(v).replace("−", "-").replace(",", "").strip("() ")


def specs(**base):
    base.setdefault("sample", "full")
    rows = [g for g in GRID if all(g[k] == str(base.get(k, "")) for k in BASEKEYS)]
    origin = [g["spec_id"] for g in rows if g["stage"] == "1_origin"]
    return (origin[0] if origin else None), [g["spec_id"] for g in rows if g["stage"] in ("2_deviation", "3_crossing")]


def reg(table, panel, col_index):
    rows = [x for x in T_O if x["table_or_figure"] == table and x["statistic_type"] == "coefficient"
            and ((panel is None) or (x["panel"] or "").endswith(panel))]
    return rows


claims = []


def add(unit, kind, base, term, published, extra=None):
    o, u = specs(**base)
    led = LEDGER.get(unit, {})
    c = {"unit": unit, "kind": kind, "tier": led.get("reconciled_tier"), "opus_claim": led.get("opus_claim"),
         "astra_claim": led.get("astra_claim"), "origin_spec": o, "uncertain_specs": u, "term": term, "published": published}
    if extra:
        c.update(extra)
    claims.append(c)


FOCAL = {"T3|(3)", "T3|(4)", "T3|(5)", "T3|(6)", "T4|(3)", "T4|(4)", "T4|(5)", "T4|(6)", "T6|(1) Treat"}

# Regression tables: Opus order equals column order (verified identical to Astra in transcription check).
def pub(x):
    return {"value": norm(x["value"]), "se": norm(x["se"]), "stars": x["stars"] or "", "n_obs": norm(x["n_obs"]),
            "reader_targets": [x["target_id"]]}

t3 = reg("Table 3", None, None)
for i, (o, c) in enumerate([("total", 0), ("total", 1), ("followon", 0), ("followon", 1), ("contributors", 0), ("contributors", 1)]):
    add(f"T3|({i + 1})", "regression", dict(analysis="AN03", outcome=o, sample="full", ctrl=c), "post_treat", pub(t3[i]))
t4 = reg("Table 4", None, None)
for i, (o, p) in enumerate([("total", "P0814"), ("total", "P14"), ("followon", "P0814"), ("followon", "P14"), ("contributors", "P0814"), ("contributors", "P14")]):
    add(f"T4|({i + 1})", "regression", dict(analysis="AN04", outcome=o, sample="full", period=p), "treat", pub(t4[i]))
t5a = reg("Table 5", "A", None)
for i, (o, v) in enumerate([("followon", "dtt"), ("contributors", "dtt"), ("followon", "placebo_perm"), ("contributors", "placebo_perm"),
                            ("followon", "boundary"), ("contributors", "boundary"), ("followon", "timing"), ("contributors", "timing")]):
    smp = v if v in ("boundary", "timing") else "full"
    base = dict(analysis="AN05", outcome=o, sample=smp, ctrl=1, variant=v, seed=0 if v.startswith("placebo") else "")
    kind = "placebo" if v.startswith("placebo") else "regression"
    alt = dict(analysis="AN05", outcome=o, sample=smp, ctrl=0, variant=v, seed=0 if v.startswith("placebo") else "")
    add(f"T5A|({i + 1})", kind, base, "post_treat", pub(t5a[i]), {"uncertain_specs_extra": [specs(**alt)[0]] + specs(**alt)[1] +
        ([specs(analysis="AN05", outcome=o, sample="full", ctrl=1, variant="placebo_bern", seed=0)[0]] if kind == "placebo" else [])})
t5b = reg("Table 5", "B", None)
for i, (s, o, p) in enumerate([("boundary", "followon", "P0814"), ("boundary", "followon", "P14"), ("boundary", "contributors", "P0814"), ("boundary", "contributors", "P14"),
                               ("timing", "followon", "P0814"), ("timing", "followon", "P14"), ("timing", "contributors", "P0814"), ("timing", "contributors", "P14")]):
    add(f"T5B|({i + 1})", "regression", dict(analysis="AN06", outcome=o, sample=s, period=p), "treat", pub(t5b[i]))
t6 = reg("Table 6", None, None)
for i, s in enumerate(["full", "boundary", "timing"]):
    add(f"T6|({i + 1}) Treat", "regression", dict(analysis="AN07", outcome="err", sample=s), "treat", pub(t6[2 * i]))
    add(f"T6|({i + 1}) Distance", "regression_nuisance_unit", dict(analysis="AN07", outcome="err", sample=s), "dist_km", pub(t6[2 * i + 1]),
        {"unit_readings": {"km": 1.0, "miles": 1.609344}})
t7 = reg("Table 7", None, None)
for i, o in enumerate(["distant", "incremental", "old", "new", "high_own", "low_own", "owner"]):
    add(f"T7|({i + 1})", "regression", dict(analysis="AN08", outcome=o, sample="full", ctrl=1), "post_treat", pub(t7[i]))

# Table 1: four printed numbers per row; variable names map to AN01 output names.
T1VARS = {"Contributions": "total", "Follow-on Contributions": "followon", "Contributors": "contributors", "Error-Score": "err_mean",
          "Owner-Contributions": "owner", "Δ Population": "d_population", "Δ Households": "d_households",
          "Δ Unemployed Pop.": "d_unemploymentrate", "Δ Educ. Population": "d_popeduc",
          "Δ Male Population (18−45)": "d_popyoungmales|d_popmales", "Δ Income per Capita": "d_income_percapita"}
ledger_t1 = [u for u in LEDGER if u.startswith("T1|")]
for unit in ledger_t1:
    row = unit.split("|", 1)[1]
    key = next(k for k in T1VARS if k.replace("Δ ", "D ").replace("−", "-") == row or k == row)
    vals = {x["statistic_type"] + ("_t" if "(1)" in x["column"] else "_c" if "(2)" in x["column"] else ""): norm(x["value"])
            for x in T_O if x["table_or_figure"] == "Table 1" and x["row_term"] == key}
    add(unit, "descriptive_group", dict(analysis="AN01"), T1VARS[key],
        {"mean_treated": vals.get("mean_t"), "mean_control": vals.get("mean_c"), "difference": vals.get("difference"), "p": vals.get("p"),
         "n_treated_header": "1851", "n_control_header": "1242"})

# Table 2
T2VARS = {"Total Contributions": "total", "Total Follow-on Contributions": "followon", "Contributors": "contributors", "Distant Follow-on": "distant",
          "Incremental Follow-On": "incremental", "New Contributors": "new", "Old Contributors": "old", "Low Ownership Contributions": "low_own",
          "High Ownership Contributions": "high_own", "Owner-Contributions": "owner", "Treat": "treat", "Post": "post", "Year": "year",
          "Quarter": "qidx", "Population": "population", "Households": "households", "Population Density": "popdensity", "Per-Capita Income": "income_percapita"}
for name, var in T2VARS.items():
    vals = {x["statistic_type"]: norm(x["value"]) for x in T_O if x["table_or_figure"] == "Table 2" and x["row_term"] == name}
    add(f"T2|{name}", "descriptive_summary", dict(analysis="AN02"), var, vals)

# Figures 1-2 counts
for unit, term, n in [("F1|a", "full", {"treated": "1851", "control": "1256", "all": "3107"}),
                      ("F2|a", "boundary_B1", {"treated": "1096", "control": "724", "all": "1820"}),
                      ("F2|b", "timing", {"treated": "1228", "control": "990", "all": "2218"})]:
    add(unit, "count", dict(analysis="AN09"), term, n)

# Plot readings, union of readers by point.
def reads(fig, match):
    pts = {}
    for r, T in (("opus", T_O), ("astra", T_A)):
        for x in T:
            if x["table_or_figure"] == fig and x.get("read_from_plot") and x["statistic_type"] == "coefficient":
                k = match(x)
                if k:
                    pts.setdefault(k, []).append({"reader": r, "value": norm(x["value"]), "interval": x["reading_interval"], "target_id": x["target_id"]})
    return pts

def yr(x):
    m = re.search(r"(20\d\d)", f"{x['column']} {x['row_term']}")
    return m.group(1) if m else None

for o, lab in (("followon", "Follow-on"), ("contributors", "Contributors")):
    p = reads("Figure 4", lambda x: yr(x) if lab.lower() in str(x["panel"]).lower() else None)
    add(f"F4|{'follow-on' if o == 'followon' else 'contributors'}", "plot_points", dict(analysis="AN11", outcome=o), "treat_x_year", p)
add("F5|follow-on", "plot_points", dict(analysis="AN12", outcome="followon", period="P2014"), "treat_by_year", reads("Figure 5", yr),
    {"origin_specs_by_point": {str(y): specs(analysis="AN12", outcome="followon", period=f"P{y}")[0] for y in range(2005, 2015)}})

def dec(x):
    m = re.search(r"decile (\d+)", f"{x['row_term']} {x['column']}")
    return m.group(1) if m else None

for o, lab in (("followon", "follow"), ("contributors", "contributors")):
    p = reads("Figure 6", lambda x: dec(x) if lab in (str(x["column"]) + str(x["panel"])).lower() and dec(x) else None)
    add(f"F6|a {'follow-on' if o == 'followon' else 'contributors'}", "plot_points", dict(analysis="AN13", outcome=o, ctrl=1, decile=1, est="M1"), "treat_by_decile", p,
        {"origin_specs_by_point": {str(d): specs(analysis="AN13", outcome=o, ctrl=1, decile=d, est="M1")[0] for d in range(1, 11)},
         "alt_estimator_specs_by_point": {str(d): specs(analysis="AN13", outcome=o, period="P0814", decile=d, est="M2")[0] for d in range(1, 11)}})

def pct(x):
    m = re.search(r"(10|25|50|75|90|99)(th)? ?[Pp]ct|(10|25|50|75|90|99)th percentile", f"{x['column']} {x['row_term']}")
    return (m.group(1) or m.group(3)) if m else None

add("F6|b", "plot_points", dict(analysis="AN14", outcome="pct10", ctrl=1), "post_treat_by_pct", reads("Figure 6", lambda x: pct(x) if "contributor type" in str(x["panel"]).lower() or str(x["panel"]) == "b" else None),
    {"origin_specs_by_point": {str(p): specs(analysis="AN14", outcome=f"pct{p}", ctrl=1)[0] for p in (10, 25, 50, 75, 90, 99)}})
for unit in ("F1|b", "F3|a(i)", "F3|a(ii)", "F3|b(i)", "F3|b(ii)"):
    add(unit, "not_audited", dict(analysis="AN10" if unit.startswith("F3") else "AN09"), None, None,
        {"reason": "illustrative image pair, not reproducible from deposited data" if unit == "F1|b" else "no numeric target in either reader's sealed targets"})

for c in claims:
    c["paper_focal"] = c["unit"] in FOCAL
os.makedirs(os.path.join(STUDY, "scoring"), exist_ok=True)
json.dump(claims, open(os.path.join(STUDY, "scoring/claims_v1.json"), "w"), indent=1, ensure_ascii=False)
json.dump({"source": "readers' initial sealed targets (readers/*/initial_v1/targets.json)", "claims": [{k: c[k] for k in ("unit", "published")} for c in claims]},
          open(os.path.join(STUDY, "sealed/targets/targets_v1.json"), "w"), indent=1, ensure_ascii=False)
missing = [c["unit"] for c in claims if c["kind"] not in ("not_audited",) and not c["origin_spec"]]
print(len(claims), "claims; focal", sum(c["paper_focal"] for c in claims), "; missing origin:", missing)
print({c["unit"]: len(c["published"]) if isinstance(c["published"], dict) else None for c in claims if c["kind"] == "plot_points"})
print([ (c["unit"], c["published"]) for c in claims if c["unit"] in ("T1|Contributors", "T1|D Male Population (18-45)", "T2|Quarter")])
