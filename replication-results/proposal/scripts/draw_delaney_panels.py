"""Render two readable supplement figures from the saved Delaney export.

No estimation or modification of the original study record. The original
single-panel figure is preserved in
old_materials/unused_assets/supplement_assets/delaney1996.pdf.
Run with ~/.venv/bin/python scripts/draw_delaney_panels.py.
"""
from pathlib import Path
import hashlib
import json

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
# Artifact root: the sibling folder in the proposal workspace, or the repository root when this
# folder sits at <repo>/proposal/.
BASE = ROOT / "orgsci-proposal-supplement" if (ROOT / "orgsci-proposal-supplement").is_dir() else ROOT.parent
SOURCE = BASE / "studies/delaney1996/reports/figures/reconstruction_influence.csv"
OUT = ROOT / "supplement_assets"
df = pd.read_csv(SOURCE)
assert len(df) == 60 and not df.duplicated(["model_id", "term"]).any()
INK, MUTED, BLUE = "#242424", "#8b8985", "#246ac0"
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9, "pdf.fonttype": 42})
coef_lo = min(df.del_min.min(), df.published.min())
coef_hi = max(df.del_max.max(), df.published.max())
pad = (coef_hi - coef_lo) * .06
p_floor = 10 ** np.floor(np.log10(max(1e-12, df.del_p_min.min())))
panels = []
for prefix, name, title in [
    ("org_", "organizational", "Organizational performance: Table 3, models 2-5"),
    ("mkt_", "market", "Market performance: Table 4, models 7-10"),
]:
    data = df[df.model_id.str.startswith(prefix)].reset_index(drop=True)
    assert len(data) == 30
    y = np.arange(len(data))[::-1]
    fig, axes = plt.subplots(1, 2, figsize=(6.8, 7.55), sharey=True,
                             gridspec_kw={"width_ratios": [1.3, 1]})
    fig.subplots_adjust(left=.337, right=.98, bottom=.15, top=.90, wspace=.19)
    left, right = axes
    for ax in axes:
        ax.spines[["top", "right"]].set_visible(False)
        ax.spines[["left", "bottom"]].set_color(MUTED)
        ax.tick_params(axis="both", labelsize=8.5, colors=INK)
        ax.tick_params(axis="y", length=0)
        ax.set_ylim(-.7, len(data) - .3)
        for i in range(1, len(data)):
            if data.model_id.iloc[i] != data.model_id.iloc[i-1]:
                ax.axhline(y[i] + .5, color="#deddd9", lw=.7, zorder=0)
    left.axvline(0, color=MUTED, lw=.8)
    left.hlines(y, data.del_min, data.del_max, color=MUTED, lw=1.6)
    left.scatter(data.recon, y, s=16, color=BLUE, zorder=3)
    left.scatter(data.published, y, s=22, marker="x", color=INK, linewidths=.9, zorder=4)
    left.set_yticks(y, data.row_label, fontsize=8.5)
    left.set_xlim(coef_lo-pad, coef_hi+pad)
    left.set_xlabel("OLS coefficient\n(unstandardized; null = 0)", fontsize=9)
    right.hlines(y, data.del_p_min.clip(lower=p_floor), data.del_p_max.clip(lower=p_floor),
                 color=MUTED, lw=1.6)
    right.scatter(data.recon_p_upper.clip(lower=p_floor), y, s=16, color=BLUE, zorder=3)
    right.axvline(.05, color=INK, lw=.8, ls="--")
    right.set_xscale("log")
    right.set_xlim(p_floor*.7, 1.4)
    right.set_xticks([p_floor, .001, .05, 1], [f"$10^{{{int(np.log10(p_floor))}}}$", ".001", ".05", "1"])
    right.minorticks_off()
    right.set_xlabel("One-tailed p (log scale)\nPositive-effect test; line at .05", fontsize=9)
    fig.suptitle(title, x=.02, y=.985, ha="left", fontsize=11, color=INK)
    handles = [Line2D([0], [0], color=MUTED, lw=1.6, label="Deletion range"),
               Line2D([0], [0], marker="o", color=BLUE, linestyle="none", markersize=4, label="Rebuilt"),
               Line2D([0], [0], marker="x", color=INK, linestyle="none", markersize=5, label="Published")]
    fig.legend(handles=handles, loc="upper center", bbox_to_anchor=(.5, .957),
               ncol=3, frameon=False, fontsize=9)
    fig.text(.02, .018, "Ranges cover single-record deletions, not confidence intervals.\n"
             "Outcomes are informants' perceptions; coefficients describe associations.", fontsize=8.5, color=INK)
    filename = f"delaney1996_{name}.pdf"
    fig.savefig(OUT / filename, metadata={"Title": title})
    plt.close(fig)
    panels.append({"file": filename, "rows": len(data), "models": data.model_id.unique().tolist()})

(OUT / "generated/delaney_panel_provenance.json").write_text(json.dumps({
    "source": str(SOURCE.relative_to(BASE)),
    "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    "empirical_models_refitted": False,
    "all_exported_rows_shown_once": sum(p["rows"] for p in panels) == len(df),
    "panels": panels,
}, indent=2) + "\n")
print("Rendered two 30-row panels from the unchanged 60-row export.")
