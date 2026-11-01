"""Reconstruction and influence-checks figure from frozen outputs. Writes SVG, PNG and a CSV of plotted values."""
import glob, json
import numpy as np, pandas as pd
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
RUN = sorted(glob.glob("runs/empirical_*"))[-1]
C = {c["claim"]: c for c in json.load(open("scoring/outputs_v1/claim_outcomes.json"))}
inf = pd.read_csv(f"{RUN}/A/influence.csv", dtype=str, keep_default_na=False); inf["e"] = pd.to_numeric(inf.estimate, errors="coerce"); inf["pv"] = pd.to_numeric(inf.p, errors="coerce")
SAMPLE = {"1": "D1_key", "2": "D2_any", "3": "D3_all", "4": "D4_loyal"}
O = {"you_grant": "grant", "prom_voice": "promotive", "proh_voice": "prohibitive"}; MED = {"benev_trust_broker": "benevolence", "val_align_part_broker": "value alignment", "relconcerns_with_broker": "relational concerns"}
rows = []
def add(ds, label, est, claim, panel, scale, ptype):
    d = inf[(inf.dataset.astype(str).str[-1] == ds) & (inf.sample_level == SAMPLE[ds]) & (inf.estimand == est)]; c = C[claim]
    pub = c["published_estimate"]; pub = float(str(pub).replace("−", "-"))
    rows.append(dict(row=label, panel=panel, effect_scale=scale, null_value=0, claim=claim, influence_estimand=est, published=pub, reconstructed=c["estimate"], inf_min=d.e.min(), inf_max=d.e.max(), p=c["p"], p_type=ptype, p_min=d.pv.min(), p_max=d.pv.max(), n_deletions=len(d), n_failed=int((d.status != "ok").sum()), provenance=f"{RUN} implementer A; all three agree"))
for o, n in O.items(): add("1", f"S1 loyal−control, {n}", f"P1.{o}", f"S1.paired.{o}", "points", "mean difference, 1-7 points", "paired t")
for o, n in O.items(): add("2", f"S2 loyal−control, {n}", f"T2.{o}", f"S2.t.{o}", "points", "mean difference, 1-7 points", "Welch t")
for o, n in O.items():
    for m, l in MED.items():
        s = {"benev_trust_broker": "benev", "val_align_part_broker": "val_align", "relconcerns_with_broker": "relconcerns"}[m]
        add("2", f"S2 indirect via {l}, {n}", f"PM2.{o}.{m}", f"S2.ind.{o}.{s}", "points", "indirect effect, 1-7 points", "delta z")
for h, t in (("H1", "loyal−control, no history"), ("H3", "control−divisive history, loyal")):
    for o, n in O.items(): add("3", f"S3 {t}, {n}", f"C3.{h}.{o}", f"S3.contrast.{o}.{h}", "points", "mean difference, 1-7 points", "pooled contrast t")
for k in ("M1", "M2", "M3"): add("4", f"S4 logit {k}, loyalty", f"L4.{k}.LoyalRequestor", f"S4.{k}.LoyalRequestor", "logodds", "logit coefficient, log-odds", "Wald z")
D = pd.DataFrame(rows); D.to_csv("reports/figures/reconstruction_influence.csv", index=False)
INK = "#222222"; REC = "#1f5fa8"; PUB = "#c2571a"; GRID = "#d9d9d9"
plt.rcParams.update({"font.size": 8.5, "font.family": "DejaVu Sans", "axes.spines.top": False, "axes.spines.right": False, "axes.edgecolor": "#888888", "svg.fonttype": "none"})
sub = [D[D.panel == "points"], D[D.panel == "logodds"]]
fig, axes = plt.subplots(2, 2, figsize=(10.5, 9.4), gridspec_kw={"height_ratios": [len(sub[0]), len(sub[1]) + 1.5], "width_ratios": [1.35, 1], "hspace": .16, "wspace": .05}, sharey="row")
for r, d in enumerate(sub):
    y = np.arange(len(d))[::-1]; a, b = axes[r]
    a.axvline(0, color="#777777", lw=1); a.hlines(y, d.inf_min, d.inf_max, color=REC, lw=2.2, alpha=.45, zorder=2)
    a.scatter(d.reconstructed, y, s=34, color=REC, zorder=3, label="Reconstructed estimate", edgecolor="white", linewidth=.6)
    a.scatter(d.published, y, s=46, marker="x", color=PUB, zorder=4, linewidths=1.5, label="Published estimate")
    a.set_yticks(y); a.set_yticklabels(d.row); a.grid(axis="x", color=GRID, lw=.6); a.set_axisbelow(True); a.tick_params(axis="y", length=0)
    a.set_xlabel("Mean difference or indirect effect, 1-7 scale points (null = 0)" if r == 0 else "Logit coefficient, log-odds (null = 0)")
    FLOOR = 1e-6
    b.axvline(.05, color=PUB, lw=1, ls="--"); show = d.p >= FLOOR
    b.hlines(y[show], d.p_min[show].clip(lower=FLOOR), d.p_max[show], color=REC, lw=2.2, alpha=.45, zorder=2)
    b.scatter(d.p[show], y[show], s=34, color=REC, zorder=3, edgecolor="white", linewidth=.6)
    for yy, (_, q) in zip(y[~show], d[~show].iterrows()):
        b.scatter([FLOOR * 1.25], [yy], marker="<", s=34, color=REC, zorder=3)
        b.text(FLOOR * 1.8, yy, f"p = {q.p:.1e}, range {q.p_min:.1e} to {q.p_max:.1e}, off scale", va="center", fontsize=7.5, color=INK)
    b.set_xscale("log"); b.grid(axis="x", color=GRID, lw=.6); b.set_axisbelow(True); b.tick_params(axis="y", length=0)
    b.set_xlim(1e-6, 2) if r == 0 else b.set_xlim(1e-3, 2)
    b.set_xlabel("Two-sided p, log scale; dashed line at .05")
    if len(d) > 5:
        for i in (2.5, 5.5, 17.5): a.axhline(len(d) - 1 - i, color=GRID, lw=.8); b.axhline(len(d) - 1 - i, color=GRID, lw=.8)
axes[0, 0].legend(loc="lower right", frameon=False, fontsize=8, handletextpad=.2)
axes[0, 0].plot([], [], color=REC, lw=2.2, alpha=.45)
axes[0, 0].legend(handles=[plt.Line2D([], [], marker="o", color=REC, ls="", ms=6, label="Reconstructed"), plt.Line2D([], [], marker="x", color=PUB, ls="", ms=7, mew=1.5, label="Published"), plt.Line2D([], [], color=REC, lw=2.2, alpha=.45, label="Leave-one-out range")], loc="lower right", frameon=False, fontsize=8)
axes[0, 0].set_title("Estimates and influence ranges", loc="left", fontsize=10, fontweight="bold"); axes[0, 1].set_title("p values and influence ranges", loc="left", fontsize=10, fontweight="bold")
fig.savefig("reports/figures/reconstruction_influence.svg", bbox_inches="tight"); fig.savefig("reports/figures/reconstruction_influence.png", dpi=170, bbox_inches="tight")
print(D[["row", "published", "reconstructed", "inf_min", "inf_max", "p", "p_min", "p_max", "n_deletions", "n_failed"]].round(4).to_string())
