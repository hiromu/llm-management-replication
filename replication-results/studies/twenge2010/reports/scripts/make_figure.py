"""Public-source reconstruction and influence-checks figure (twenge2010).

Inputs: runs/<run>/scoring/scores.json and the implementation-A leave-one-respondent-out file.
Outputs: reports/figure_reconstruction_influence.{svg,png,csv}.
Run: ~/.venv/bin/python -I reports/scripts/make_figure.py runs/run_20261028T035346Z
Row order is fixed in advance: Table 1 factor order (leisure, intrinsic, altruistic, social, extrinsic) by pair (1976-1991, 1991-2006, 1976-2006).
"""
import sys, json, csv, glob, math
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

RUN = sys.argv[1]
S = json.load(open(f"{RUN}/scoring/scores.json"))
infl_path = sorted(glob.glob(f"{RUN}/A/results/influence_1_*.csv"))[-1]
rows = list(csv.DictReader(open(infl_path)))

ORDER = [(K, P) for K in ("K1", "K2", "K3", "K4", "K5") for P in ("P1", "P2", "P3")]
NAMES = {"K1": "Leisure", "K2": "Intrinsic", "K3": "Altruistic", "K4": "Social", "K5": "Extrinsic"}
PAIRL = {"P1": "1976 to 1991", "P2": "1991 to 2006", "P3": "1976 to 2006"}
FLOOR = 1e-300
foc = {(f["factor"], f["pair"]): f for f in S["focal_contrasts"]}

out = []
n_ok = sum(1 for r in rows if r["status"] in ("ok", "converged"))
for K, P in ORDER:
    f = foc[(K, P)]
    ds = [float(r[f"d_eq_{K}_{P}"]) for r in rows if r["status"] in ("ok", "converged") and r[f"d_eq_{K}_{P}"] not in ("", "NA")]
    ps = [float(r[f"p_{K}_{P}"]) for r in rows if r["status"] in ("ok", "converged") and r[f"p_{K}_{P}"] not in ("", "NA")]
    out.append({"row": f"{NAMES[K]}, {PAIRL[P]}", "factor": K, "pair": P, "d_published": f["S00_d_pub"], "d_reconstructed": f["S00_d_rec"],
                "d_loo_min": min(ds), "d_loo_max": max(ds), "p_reconstructed": f["native_wald_p_two_sided"],
                "p_loo_min": min(ps), "p_loo_max": max(ps), "p_zero_count": sum(p == 0 for p in ps), "n_deletions_ok": len(ds),
                "outcome": f["S00_outcome"], "subcode": f["S00_subcode"],
                "provenance": "MTF 12th-grade Form 4, ICPSR 7927 V4 / 9871 V1 / 20022 V3 (user-supplied, validated); manifest S00; implementations A,B,C agree; LOO by implementation A"})

with open("reports/figure_reconstruction_influence.csv", "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(out[0].keys()))
    w.writeheader(); w.writerows(out)

BLUE, ORANGE, INK, MUTED, GRID = "#2a78d6", "#eb6834", "#0b0b0b", "#52514e", "#d9d8d4"
plt.rcParams.update({"font.size": 9, "axes.edgecolor": MUTED, "axes.labelcolor": INK, "xtick.color": MUTED, "ytick.color": INK})
fig, (a1, a2) = plt.subplots(1, 2, figsize=(10, 6.6), sharey=True, gridspec_kw={"width_ratios": [1.15, 1]})
fig.patch.set_facecolor("#fcfcfb")
ys = list(range(len(out)))[::-1]
for y, r in zip(ys, out):
    a1.plot([r["d_loo_min"], r["d_loo_max"]], [y, y], color=BLUE, lw=2, solid_capstyle="round", zorder=5)
    a1.plot([r["d_loo_min"]] * 2, [y - 0.22, y + 0.22], color=BLUE, lw=1.2, zorder=5)
    a1.plot([r["d_loo_max"]] * 2, [y - 0.22, y + 0.22], color=BLUE, lw=1.2, zorder=5)
    a1.scatter([r["d_reconstructed"]], [y], s=22, color=BLUE, edgecolor="#fcfcfb", linewidth=1.2, zorder=3)
    a1.scatter([r["d_published"]], [y], s=46, marker="x", color=ORANGE, linewidth=1.8, zorder=4)
    pr = max(r["p_reconstructed"], FLOOR)
    a2.plot([max(r["p_loo_min"], FLOOR), max(r["p_loo_max"], FLOOR)], [y, y], color=BLUE, lw=2, solid_capstyle="round", zorder=5)
    for e in (r["p_loo_min"], r["p_loo_max"]):
        a2.plot([max(e, FLOOR)] * 2, [y - 0.22, y + 0.22], color=BLUE, lw=1.2, zorder=5)
    a2.scatter([pr], [y], s=22, color=BLUE, edgecolor="#fcfcfb", linewidth=1.2, zorder=3)
a1.axvline(0, color=MUTED, lw=1, zorder=1)
a1.set_yticks(ys); a1.set_yticklabels([r["row"] for r in out])
for y in (2.5, 5.5, 8.5, 11.5):
    a1.axhline(y, color=GRID, lw=0.8); a2.axhline(y, color=GRID, lw=0.8)
a1.set_xlabel("Latent d, later minus earlier year\n(null = 0)")
a1.set_title("Effect size: published (x) vs reconstructed (dot)\ncapped line = min-max over all leave-one-out refits", fontsize=9, color=INK)
a2.set_xscale("log")
a2.axvline(0.05, color=ORANGE, lw=1, ls="--")
a2.text(0.05, len(out) - 0.4, " p = .05", color=MUTED, fontsize=8, va="bottom")
a2.set_xlabel("Two-sided Wald p, native model SEs\n(log scale; inference not audited)")
a2.set_title("Reconstructed p (dot) and deletion range (line)\nno published p exists for these contrasts", fontsize=9, color=INK)
for ax in (a1, a2):
    ax.set_facecolor("#fcfcfb")
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    ax.grid(axis="x", color=GRID, lw=0.6)
    ax.set_ylim(-0.7, len(out) - 0.3)
from matplotlib.lines import Line2D
fig.legend(handles=[Line2D([], [], marker="x", color=ORANGE, ls="", label="Published (Table 1)"),
                    Line2D([], [], marker="o", color=BLUE, ls="", label="Reconstructed, S00 (A, B, C agree)"),
                    Line2D([], [], color=BLUE, lw=2, label=f"Leave-one-out range ({n_ok} refits)")],
           loc="lower center", ncol=3, frameon=False, bbox_to_anchor=(0.5, 0.0))
fig.tight_layout(rect=(0, 0.05, 1, 1))
fig.savefig("reports/figure_reconstruction_influence.svg")
fig.savefig("reports/figure_reconstruction_influence.png", dpi=200)
print("rows", len(out), "deletions ok", n_ok, "of", len(rows), "file", infl_path)
