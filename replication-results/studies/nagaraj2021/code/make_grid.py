"""Build manifest/grid_v1.csv, the frozen finite specification grid.

Compute order (column `stage`): 1 origin rows; 2 single-axis deviations from the origin; 3 full crossings of the
uncertain axes for the paper-focal models; 4 placebo permutation distribution. Labels: all non-origin levels are
uncertain (reconciliation/axis_ledger_v1.json); there are no equivalent alternatives, and non-equivalent levels are
not run. Origin levels: F1 D1 O1 G1 L1 Y1 Q1 R1 B1 W1; Table-5A-style variants use ctrl=1 as origin (X1).
"""
import csv, itertools, os

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORIGIN = dict(F="F1", D="D1", O="O1", G="G1", L="L1", Y="Y1", Q="Q1", R="R1", B="B1", W="W1")
LEVELS = dict(F=["F1", "F2", "F3", "F4"], D=["D1", "D2"], O=["O1", "O2"], G=["G1", "G2"], L=["L1", "L2"],
              Y=["Y1", "Y2", "Y3"], Q=["Q1", "Q2"], R=["R1", "R2"], B=["B1", "B2"], W=["W1", "W3", "W4"])
COLS = ["spec_id", "stage", "analysis", "outcome", "sample", "ctrl", "variant", "seed", "period", "decile", "est",
        "F", "D", "O", "G", "L", "Y", "Q", "R", "B", "W", "deviation", "paper_focal"]
rows, seen = [], set()


def axes_for(base):
    a, out, s = base["analysis"], [], base["sample"]
    o = base["outcome"]
    if o in ("followon", "distant", "incremental") or a in ("AN01", "AN02", "AN10"):
        out.append("F")
    if o == "distant" or a == "AN02":
        out.append("D")
    if o == "low_own" or a == "AN02":
        out.append("O")
    if a in ("AN03", "AN04", "AN05", "AN06", "AN08", "AN11", "AN12", "AN13", "AN14"):
        out.append("G")
    xs = a in ("AN04", "AN06", "AN07", "AN12") or (a == "AN13" and base["est"] == "M2")
    if base["ctrl"] == "1" or xs:
        out.append("L")
    if xs:
        out += ["Y", "Q"]
    if a in ("AN06", "AN07") and s in ("boundary", "timing"):
        out.append("R")
    if s == "boundary":
        out.append("B")
    if a == "AN07":
        out.append("W")
    return out


def add(base, stage, deviation, focal):
    r = {k: "" for k in COLS}
    r.update(base)
    ax = axes_for(base)
    for k in ORIGIN:
        if k in ax:
            r[k] = r.get(k) or ORIGIN[k]
        else:
            r[k] = ""
    key = tuple(r[k] for k in COLS if k not in ("spec_id", "stage", "deviation", "paper_focal"))
    if key in seen:
        return
    seen.add(key)
    r["stage"], r["deviation"], r["paper_focal"] = stage, deviation, focal
    r["spec_id"] = f"S{len(rows) + 1:05d}"
    rows.append(r)


def model(analysis, outcome="", sample="full", ctrl="", variant="", seed="", period="", decile="", est="", focal="0"):
    return dict(analysis=analysis, outcome=outcome, sample=sample, ctrl=ctrl, variant=variant, seed=seed,
                period=period, decile=decile, est=est, paper_focal=focal)


bases = [model("AN01"), model("AN02"), model("AN09")]
for o in ("total", "followon", "contributors"):
    for c in ("0", "1"):
        bases.append(model("AN03", o, ctrl=c, focal="1" if o != "total" else "0"))
    for p in ("P0814", "P14"):
        bases.append(model("AN04", o, period=p, focal="1" if o != "total" else "0"))
for o in ("followon", "contributors"):
    for v in ("dtt", "boundary", "timing"):
        for c in ("1", "0"):
            bases.append(model("AN05", o, sample=v if v != "dtt" else "full", ctrl=c, variant=v))
    for v in ("placebo_perm", "placebo_bern"):
        for c in ("1", "0"):
            bases.append(model("AN05", o, ctrl=c, variant=v, seed="0"))
    for s in ("boundary", "timing"):
        for p in ("P0814", "P14"):
            bases.append(model("AN06", o, sample=s, period=p))
for s in ("full", "boundary", "timing"):
    bases.append(model("AN07", "err", sample=s, focal="1" if s == "full" else "0"))
for o in ("distant", "incremental", "old", "new", "high_own", "low_own", "owner"):
    bases.append(model("AN08", o, ctrl="1"))
bases.append(model("AN10", "total_followon"))
for o in ("followon", "contributors"):
    bases.append(model("AN11", o))
for yr in range(2005, 2015):
    bases.append(model("AN12", "followon", period=f"P{yr}"))
for o in ("followon", "contributors"):
    for d in range(1, 11):
        bases.append(model("AN13", o, ctrl="1", decile=str(d), est="M1"))
        bases.append(model("AN13", o, period="P0814", decile=str(d), est="M2"))
for p in (10, 25, 50, 75, 90, 99):
    bases.append(model("AN14", f"pct{p}", ctrl="1"))

for b in bases:                                   # stage 1: origin
    add(dict(b), "1_origin", "", b["paper_focal"])
for b in bases:                                   # stage 2: single-axis deviations
    for ax in axes_for(b):
        for lev in LEVELS[ax][1:]:
            d = dict(b)
            d[ax] = lev
            add(d, "2_deviation", f"{ax}={lev}", b["paper_focal"])
for b in bases:                                   # stage 3: crossings for paper-focal models
    if b["paper_focal"] != "1":
        continue
    ax = axes_for(b)
    for combo in itertools.product(*[LEVELS[a] for a in ax]):
        d = dict(b)
        d.update(dict(zip(ax, combo)))
        add(d, "3_crossing", ";".join(f"{a}={l}" for a, l in zip(ax, combo) if l != ORIGIN[a]), "1")
for o in ("followon", "contributors"):           # stage 4: placebo distribution
    for seed in range(1, 201):
        add(model("AN05", o, ctrl="1", variant="placebo_perm", seed=str(seed)), "4_placebo_dist", "", "0")

with open(os.path.join(STUDY, "manifest/grid_v1.csv"), "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=COLS)
    w.writeheader()
    w.writerows(rows)
from collections import Counter
print(len(rows), Counter(r["stage"] for r in rows), Counter(r["analysis"] for r in rows))
