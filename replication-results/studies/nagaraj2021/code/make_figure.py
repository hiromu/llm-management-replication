"""Reconstruction and influence-checks figure for the nine paper-focal claims.
Left: published estimate (cross), reconstructed origin estimate (dot), min-max across leave-one-county-out refits (line),
zero reference. Right: reconstructed benchmark p (dot) and min-max deletion p (line), log scale, 0.05 threshold.
Rows are fixed in the order of scoring_rules_v1 paper_focal_claims. Influence values come from implementation A.
usage: make_figure.py <run_dir> <out_dir>
"""
import json, os, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUN, OUTD = sys.argv[1], sys.argv[2]
os.makedirs(OUTD, exist_ok=True)
rules = json.load(open(os.path.join(STUDY, "scoring/scoring_rules_v1.json")))
order = rules["paper_level"]["paper_focal_claims"]
scores = {r["unit"]: r for r in json.load(open(os.path.join(RUN, "scoring/claim_scores.json")))}
final = {r["unit"]: r for r in json.load(open(os.path.join(RUN, "scoring/final_outcomes.json")))}
LABEL = {"T3|(3)": "T3 (3) follow-on, DiD, no controls", "T3|(4)": "T3 (4) follow-on, DiD, controls",
         "T3|(5)": "T3 (5) contributors, DiD, no controls", "T3|(6)": "T3 (6) contributors, DiD, controls",
         "T4|(3)": "T4 (3) follow-on, cross-section 2008-14", "T4|(4)": "T4 (4) follow-on, cross-section 2014",
         "T4|(5)": "T4 (5) contributors, cross-section 2008-14", "T4|(6)": "T4 (6) contributors, cross-section 2014",
         "T6|(1) Treat": "T6 (1) log routing error, address pairs"}
FLOOR = 1e-300
rows = []
for u in order:
    s = scores[u]
    spec = s["origin_spec"]
    f = os.path.join(RUN, "influence", f"A_{spec}", f"influence_{spec}.csv")
    inf = pd.read_csv(f) if os.path.exists(f) else pd.DataFrame()
    ok = inf[inf.status == "ok"] if len(inf) else inf
    pcol = "p_hc1" if s["benchmark"] == "HC1" else "p_cluster"
    rows.append({"unit": u, "label": LABEL[u], "origin_spec": spec, "published": float(s["published"]["value"]),
                 "published_se": float(s["published"]["se"]), "published_stars": s["published"]["stars"] or "none",
                 "reconstructed": s["estimate"], "benchmark": s["benchmark"], "p_reconstructed": s["p_benchmark"],
                 "n_obs": s["n_obs"], "n_published": s["n_published"],
                 "deletions_total": len(inf), "deletions_ok": len(ok), "deletions_failed": len(inf) - len(ok),
                 "del_est_min": ok.estimate.min() if len(ok) else np.nan, "del_est_max": ok.estimate.max() if len(ok) else np.nan,
                 "del_p_min": ok[pcol].min() if len(ok) else np.nan, "del_p_max": ok[pcol].max() if len(ok) else np.nan,
                 "p_floored": bool(len(ok) and (ok[pcol] < FLOOR).any()) or (s["p_benchmark"] < FLOOR),
                 "outcome": final[u]["outcome"], "provenance": f"runs/run_20261101_v1 implementation A spec {spec}; influence/A_{spec}"})
D = pd.DataFrame(rows)
D.to_csv(os.path.join(OUTD, "figure_focal_influence.csv"), index=False)

INK, INK2, ACC, GRID, SURF = "#0b0b0b", "#52514e", "#2a78d6", "#e4e3df", "#fcfcfb"
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9, "axes.edgecolor": INK2, "axes.labelcolor": INK, "xtick.color": INK2,
                     "ytick.color": INK, "axes.facecolor": SURF, "figure.facecolor": SURF})
fig, (a1, a2) = plt.subplots(1, 2, figsize=(10.5, 5.2), sharey=True, gridspec_kw={"width_ratios": [1.35, 1], "wspace": 0.06})
y = np.arange(len(D))[::-1]
for ax in (a1, a2):
    ax.grid(axis="x", color=GRID, lw=0.8)
    ax.set_axisbelow(True)
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
a1.axvline(0, color=INK2, lw=1)
a1.hlines(y, D.del_est_min, D.del_est_max, color=ACC, lw=2, alpha=0.55, label="deletion range (min-max)")
a1.scatter(D.reconstructed, y, s=46, color=ACC, edgecolor=SURF, linewidth=1.5, zorder=3, label="reconstructed")
a1.scatter(D.published, y, s=58, marker="x", color=INK, linewidth=1.8, zorder=4, label="published")
a1.set_yticks(y)
a1.set_yticklabels(D.label)
a1.set_xlabel("Coefficient on treatment (log points; null = 0)")
a1.legend(loc="upper right", frameon=False, fontsize=8)
pr = D.p_reconstructed.clip(lower=FLOOR)
a2.hlines(y, D.del_p_min.clip(lower=FLOOR), D.del_p_max.clip(lower=FLOOR), color=ACC, lw=2, alpha=0.55)
a2.scatter(pr, y, s=46, color=ACC, edgecolor=SURF, linewidth=1.5, zorder=3)
a2.axvline(0.05, color=INK2, lw=1, ls="--")
a2.text(0.01, len(D) - 0.45, "dashed line: p = 0.05", color=INK2, fontsize=8, va="bottom", ha="left", transform=a2.get_yaxis_transform())
a2.set_xscale("log")
a2.set_xlabel("Reconstructed benchmark p (two-sided, log scale)")
for yi, st in zip(y, D.published_stars):
    a2.text(1.03, yi, st if st != "none" else "n.s.", color=INK2, fontsize=8, va="center", ha="left", transform=a2.get_yaxis_transform())
a2.text(1.03, len(D) - 0.45, "published\nstars", color=INK2, fontsize=7.5, va="bottom", ha="left", transform=a2.get_yaxis_transform())
fig.suptitle("Paper-focal estimates: published, reconstructed and leave-one-county-out influence", fontsize=10.5, color=INK, x=0.01, ha="left")
fig.savefig(os.path.join(OUTD, "figure_focal_influence.svg"), bbox_inches="tight")
fig.savefig(os.path.join(OUTD, "figure_focal_influence.png"), dpi=200, bbox_inches="tight")
print(D[["unit", "published", "reconstructed", "del_est_min", "del_est_max", "p_reconstructed", "del_p_min", "del_p_max", "deletions_ok", "deletions_failed", "outcome"]].to_string())
