"""Public-source reconstruction and influence-checks figure (reporting.md, adapted to WLS coefficients).
Rows are fixed by registry/influence_registration_v1.json. Reads only frozen run and scoring outputs."""
import json, sys
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ST = Path(sys.argv[1]); RUN = "run_v1"; REF = "impl_B"
OUT = ST / "reports"
reg = json.load(open(ST / "registry/influence_registration_v1.json"))
terms = pd.read_csv(ST / f"scoring/{RUN}/term_scores.csv")
res = pd.read_csv(ST / f"runs/{RUN}/{REF}/out/spec_results.csv")
inf = pd.read_csv(ST / f"runs/{RUN}/{REF}/out/influence.csv")
nev = json.load(open(ST / f"scoring/{RUN}/n_eval.json"))["n_eval"]

INK, INK2, MUTED, GRID, BASE, SURF = "#0b0b0b", "#52514e", "#898781", "#e1e0d9", "#c3c2b7", "#fcfcfb"
COL = {"O_A": "#2a78d6", "O_B": "#eb6834"}
MARK = {"O_A": "o", "O_B": "s"}
OFF = {"O_A": 0.14, "O_B": -0.14}
P_FLOOR = 1e-300

rows = []
for r in reg["focal_rows_fixed_order"]:
    m, t = r["model"], r["term"]
    for o in ["O_A", "O_B"]:
        ts = terms[(terms.origin == o) & (terms.model == m) & (terms.term == t)].iloc[0]
        g = inf[(inf.origin == o) & (inf.model == m) & (inf.term == t) & (inf.deletion_type == "bank_year")]
        ok = g[g.status == "ok"]
        rows.append({"row": r["row"], "row_id": r["id"], "claim": r["claim"], "origin": o, "model": m, "term": t,
                     "published_coef": ts.pub_coef, "published_se": ts.pub_se, "published_p": "p<.001 (***)",
                     "reconstructed_coef": ts.rec_coef, "reconstructed_se": ts.rec_se,
                     "reconstructed_p_two_sided": max(ts.rec_p2, P_FLOOR),
                     "p_floored": bool(ts.rec_p2 < P_FLOOR), "n": int(ts.n),
                     "deletion_unit": "bank-year", "deletion_fits": len(g), "deletion_ok": len(ok),
                     "deletion_failed": int((g.status != "ok").sum()),
                     "deletion_coef_min": ok.estimate.min(), "deletion_coef_max": ok.estimate.max(),
                     "deletion_p_min": max(ok.p_two_sided.min(), P_FLOOR), "deletion_p_max": ok.p_two_sided.max(),
                     "source": f"runs/{RUN}/{REF}/out (agrees with impl_A and impl_C at origins)",
                     "provenance": "Chicago Fed Call Report archive 1983Q4-1993Q4; FRED CPIAUCNS; Census 1983 MSA 5120 counties"})
D = pd.DataFrame(rows)
D.to_csv(OUT / "figure_reconstruction_influence.csv", index=False)

plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9, "axes.edgecolor": BASE, "axes.labelcolor": INK2,
                     "xtick.color": INK2, "ytick.color": INK2, "axes.facecolor": SURF, "figure.facecolor": SURF})
fig, axes = plt.subplots(3, 2, figsize=(10, 6.6), gridspec_kw={"width_ratios": [1.15, 1], "hspace": 0.75, "wspace": 0.18})
labels = {"M2_SD": "Model 2: strategic deviation", "M3_SD": "Model 3: strategic deviation",
          "M3_SD2": "Model 3: strategic deviation squared"}
for i, rid in enumerate(["M2_SD", "M3_SD", "M3_SD2"]):
    d = D[D.row_id == rid]
    axl, axr = axes[i, 0], axes[i, 1]
    for ax in (axl, axr):
        ax.set_ylim(-0.5, 0.5); ax.set_yticks([])
        for s in ("top", "right", "left"): ax.spines[s].set_visible(False)
        ax.grid(axis="x", color=GRID, linewidth=0.6); ax.set_axisbelow(True)
    axl.set_title(labels[rid], loc="left", fontsize=9.5, color=INK, pad=4)
    axl.axvline(0, color=MUTED, linewidth=1, linestyle=(0, (3, 2)), zorder=1)
    pc = d.published_coef.iloc[0]
    axl.plot([pc], [0], marker="x", markersize=9, mew=2, color=INK, zorder=4, linestyle="none")
    for _, r in d.iterrows():
        y = OFF[r.origin]
        axl.plot([r.deletion_coef_min, r.deletion_coef_max], [y, y], color=COL[r.origin], linewidth=2, alpha=0.55, solid_capstyle="round")
        axl.plot([r.reconstructed_coef], [y], marker=MARK[r.origin], markersize=7, color=COL[r.origin], mec=SURF, mew=1.5, zorder=5)
        axr.plot([r.deletion_p_min, r.deletion_p_max], [y, y], color=COL[r.origin], linewidth=2, alpha=0.55, solid_capstyle="round")
        axr.plot([r.reconstructed_p_two_sided], [y], marker=MARK[r.origin], markersize=7, color=COL[r.origin], mec=SURF, mew=1.5, zorder=5)
    lo = min(d.deletion_coef_min.min(), pc, 0); hi = max(d.deletion_coef_max.max(), pc, 0)
    pad = 0.08 * (hi - lo); axl.set_xlim(lo - pad, hi + pad)
    axr.set_xscale("log"); axr.set_xlim(1e-30, 1.5)
    axr.axvline(0.05, color=INK2, linewidth=1, linestyle=(0, (4, 2)))
    axr.axvspan(1e-30, 1e-3, color=GRID, alpha=0.55, zorder=0)
    if i == 0:
        axr.text(1.2e-30, 0.38, "published: p < .001", fontsize=8, color=INK2, va="center")
        axr.text(0.058, 0.38, ".05", fontsize=8, color=INK2, va="center")
    axl.set_xlabel("WLS coefficient (outcome: relative ROA x 100); null = 0", fontsize=8, color=MUTED)
    axr.set_xlabel("two-sided p (log scale)", fontsize=8, color=MUTED)
from matplotlib.lines import Line2D
h = [Line2D([], [], marker="x", color=INK, linestyle="none", mew=2, markersize=8, label="published estimate"),
     Line2D([], [], marker="o", color=COL["O_A"], linestyle="-", linewidth=2, markersize=7, label=f"reconstruction O_A (N={nev['O_A']['n_rec']}) with leave-one-bank-year-out range"),
     Line2D([], [], marker="s", color=COL["O_B"], linestyle="-", linewidth=2, markersize=7, label=f"reconstruction O_B (N={nev['O_B']['n_rec']}) with leave-one-bank-year-out range")]
fig.legend(handles=h, loc="upper center", ncol=1, frameon=False, fontsize=8.5, bbox_to_anchor=(0.5, 1.02))
fig.text(0.01, -0.04, "Deletion ranges are influence ranges, not confidence intervals; they are not part of the equivalent-specification set and cannot by themselves "
         "establish fragility.\nPublished N = 960; reconstructed N = 1260 (O_A) and 1255 (O_B) bank-years, listwise complete, 1985-1992, from public Call Reports "
         "(Chicago Fed archive), FRED CPI and 1983 OMB county lists,\nrebuilt independently by three implementations that agree at both origins. "
         "Two-sided p from conventional WLS; hypothesised direction negative for Model 2 SD and Model 3 SD^2, positive for Model 3 SD.",
         fontsize=7.2, color=INK2, va="top")
fig.savefig(OUT / "figure_reconstruction_influence.svg", bbox_inches="tight")
fig.savefig(OUT / "figure_reconstruction_influence.png", dpi=200, bbox_inches="tight")
print(D[["row_id", "origin", "published_coef", "reconstructed_coef", "deletion_coef_min", "deletion_coef_max", "reconstructed_p_two_sided", "deletion_p_max"]].to_string())
