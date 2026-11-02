"""Side-by-side figure comparisons (instructions/reporting.md, figure comparison).
Published panels are cropped from the frozen article PDF (packet/frozen_v1/D01_article.pdf rendered at 150 dpi).
Reconstructed panels use frozen implementation-A outputs (runs/run_20261101_v1). Author-specification panels are
post-unsealing diagnostics (post_unseal/diagnostics, post_unseal/figure_diagnostics). Readers' plot readings are
overlaid with their reading intervals. Presentation only: no score changes.
usage: make_figure_comparisons.py
"""
import json, os
import geopandas as gpd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from PIL import Image

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(STUDY, "reports/figures/comparison")
PAGES = os.path.join(OUT, "published_pages")
RUN = os.path.join(STUDY, "runs/run_20261101_v1/out/A")
DIAG = os.path.join(STUDY, "post_unseal/diagnostics")
FDIAG = os.path.join(STUDY, "post_unseal/figure_diagnostics")
INK, INK2, ACC, ORG, GRID, SURF = "#0b0b0b", "#52514e", "#2a78d6", "#eb6834", "#e4e3df", "#fcfcfb"
TREAT, CTRL = "#1baf7a", "#d4d3cf"
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 8.5, "axes.edgecolor": INK2, "xtick.color": INK2, "ytick.color": INK2,
                     "axes.facecolor": SURF, "figure.facecolor": SURF})

# crop boxes (left, top, right, bottom) on 150-dpi pages, D01 PDF pages
CROPS = {"fig1a": ("page-07.png", (88, 170, 1132, 708), "D01 PDF p.7"),
         "fig2a": ("page-09.png", (88, 170, 1132, 702), "D01 PDF p.9"),
         "fig2b": ("page-09.png", (88, 725, 1132, 1252), "D01 PDF p.9"),
         "fig3": ("page-13.png", (88, 168, 1132, 1018), "D01 PDF p.13"),
         "fig4": ("page-15.png", (88, 168, 1132, 500), "D01 PDF p.15"),
         "fig5": ("page-16.png", (88, 1070, 592, 1398), "D01 PDF p.16"),
         "fig6a": ("page-20.png", (88, 170, 1132, 660), "D01 PDF p.20"),
         "fig6b": ("page-20.png", (300, 690, 900, 1112), "D01 PDF p.20")}
os.makedirs(os.path.join(OUT, "published_panels"), exist_ok=True)
PUB = {}
for k, (pg, box, loc) in CROPS.items():
    im = Image.open(os.path.join(PAGES, pg)).crop(box)
    im.save(os.path.join(OUT, "published_panels", f"{k}.png"))
    PUB[k] = (im, loc)

claims = {c["unit"]: c for c in json.load(open(os.path.join(STUDY, "scoring/claims_v1.json")))}
R = pd.read_csv(os.path.join(RUN, "results.csv"), dtype={"spec_id": str})
plotted = []


def pub_axis(ax, key, title):
    im, loc = PUB[key]
    ax.imshow(im)
    ax.set_axis_off()
    ax.set_title(f"Published ({loc})", fontsize=9, color=INK, loc="left")


def save(fig, name):
    fig.savefig(os.path.join(OUT, f"{name}.png"), dpi=170, bbox_inches="tight")
    fig.savefig(os.path.join(OUT, f"{name}.svg"), bbox_inches="tight")
    plt.close(fig)


def readings(unit):
    pts = claims[unit]["published"]
    out = {}
    for key, rs in pts.items():
        lo = min(r["interval"][0] for r in rs)
        hi = max(r["interval"][1] for r in rs)
        out[key] = (lo, hi, [r["reader"] for r in rs])
    return out


def overlay(ax, xs, rd, label=True):
    first = label
    for x, (lo, hi, who) in zip(xs, rd):
        ax.add_patch(plt.Rectangle((x - 0.32, lo), 0.64, hi - lo, color=INK, alpha=0.18, lw=0, label="reader reading interval" if first else None))
        first = False


# ---------------- maps ----------------
cty = gpd.read_file("zip://" + os.path.join(STUDY, "data/derived/run_input_v1/../bundle_v1/tl_2010_us_county10.zip"))
cty["fips"] = cty.GEOID10.astype(int)
cty = cty[~cty.STATEFP10.isin(["02", "15", "60", "66", "69", "72", "78"])].to_crs(5070)


def mem(path):
    m = pd.read_csv(path)
    return m


M_ai = mem(os.path.join(RUN, "an09_membership.csv"))
M_ma = mem(os.path.join(DIAG, "D01_MA_as_controls/out/an09_membership.csv"))
M_tw = mem(os.path.join(DIAG, "D08_timing_window/out/an09_membership.csv"))


def draw_map(ax, m, col, title):
    g = cty.merge(m[m[col] == 1][["fips", "treat"]], on="fips", how="left")
    g.plot(ax=ax, color="white", edgecolor="#bdbcb8", linewidth=0.1)
    g[g.treat == 0].plot(ax=ax, color=CTRL, edgecolor="#a8a7a3", linewidth=0.1)
    g[g.treat == 1].plot(ax=ax, color=TREAT, edgecolor="#13855c", linewidth=0.1)
    n1, n0 = int((m[col] == 1).mul(m.treat == 1).sum()), int((m[col] == 1).mul(m.treat == 0).sum())
    ax.set_axis_off()
    ax.set_title(f"{title}\n{n1 + n0:,} counties: {n1:,} treated (green), {n0:,} control (grey)", fontsize=8.5, color=INK, loc="left")
    plotted.append({"figure": title, "counties": n1 + n0, "treated": n1, "control": n0})


for key, col, pubtitle, panels in [
        ("fig1a", "in_full", "Figure 1(a)", [(M_ai, "Reconstructed (frozen AI): Massachusetts excluded as the article states"),
                                            (M_ma, "Author specification (diagnostic D01): Massachusetts kept as control")]),
        ("fig2a", "in_boundary_B1", "Figure 2(a)", [(M_ai, "Reconstructed boundary sample (B1)"),
                                                   (M_ma, "Author specification (diagnostic D01): Massachusetts kept")]),
        ("fig2b", "in_timing", "Figure 2(b)", [(M_ai, "Reconstructed timing sample: scheduled in calendar 2005-2006"),
                                              (M_tw, "Author specification (diagnostic D08): within 12 months of June 2005")])]:
    fig = plt.figure(figsize=(16, 4.4))
    gs = fig.add_gridspec(1, 3, wspace=0.03)
    pub_axis(fig.add_subplot(gs[0]), key, pubtitle)
    for i, (m, t) in enumerate(panels):
        draw_map(fig.add_subplot(gs[i + 1]), m, col, t)
    fig.suptitle(f"{pubtitle}: published (left), reconstruction (centre), author specification (right)", x=0.01, ha="left", fontsize=10.5)
    save(fig, key)

# ---------------- Figure 3 ----------------
a10 = pd.read_csv(os.path.join(RUN, "an10_means.csv"))
a10 = a10[a10.followon_def.isna() | (a10.followon_def == "followon_F1")]
a10["yq"] = a10.quarter.str[:4].astype(int) + (a10.quarter.str[-1].astype(int) - 1) / 4 + 0.125
f3 = pd.read_csv(os.path.join(FDIAG, "fig3_author_annual.csv"))
fig = plt.figure(figsize=(16, 7.2))
gs = fig.add_gridspec(2, 3, width_ratios=[1.6, 1, 1], wspace=0.25, hspace=0.35)
pub_axis(fig.add_subplot(gs[:, 0]), "fig3", "Figure 3")
for r, o in enumerate(("total", "followon")):
    for c, (stat, lab) in enumerate((("mean_log_y_plus_1", "i. mean of ln(y+1)"), (None, "ii. mean cumulative count"))):
        ax = fig.add_subplot(gs[r, c + 1])
        sub = a10[a10.outcome == o]
        st = "mean_log_y_plus_1" if stat else [s for s in sub.statistic.unique() if "cum" in s][0]
        for tr, ls, col, nm in ((0, "--", INK, "control"), (1, "-", TREAT, "treated")):
            s = sub[(sub.statistic == st) & (sub.treat == tr)].sort_values("yq")
            ax.plot(s.yq, s.value, ls, color=col, lw=1.6, label=f"{nm}, quarterly (frozen AI)")
            a = f3[(f3.outcome == o) & (f3.treat == tr)]
            ax.plot(a.year + 0.5, a.lnmean if stat else a.cummean, "o", ms=4.5, mfc=SURF, mec=col, label=f"{nm}, annual (author spec)")
        ax.axvline(2007.75, color=INK2, lw=0.8, ls=":")
        ax.set_title(f"{'(a) Contributions' if o == 'total' else '(b) Follow-on'}: {lab}", fontsize=8.5, loc="left")
        ax.grid(axis="y", color=GRID, lw=0.6)
        for sp in ("top", "right"):
            ax.spines[sp].set_visible(False)
        if r == 0 and c == 0:
            ax.legend(frameon=False, fontsize=7)
fig.suptitle("Figure 3: published (left); reconstruction from frozen AI outputs (lines) and author annual aggregation (circles, diagnostic)", x=0.01, ha="left", fontsize=10.5)
save(fig, "fig3")


# ---------------- coefficient figures ----------------
def coef_panel(ax, xs, est, lo, hi, color, label, marker="o", dx=0.0):
    ax.errorbar(np.array(xs) + dx, est, yerr=[np.array(est) - np.array(lo), np.array(hi) - np.array(est)], fmt=marker, color=color,
                ms=4.5, lw=1.2, capsize=2, label=label)


def style(ax, title, xlabel):
    ax.axhline(0, color=INK2, lw=0.8)
    ax.grid(axis="y", color=GRID, lw=0.6)
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
    ax.set_title(title, fontsize=8.5, loc="left")
    ax.set_xlabel(xlabel)


# Figure 4
fig = plt.figure(figsize=(16, 4.6))
gs = fig.add_gridspec(1, 3, width_ratios=[1.8, 1, 1], wspace=0.22)
pub_axis(fig.add_subplot(gs[0]), "fig4", "Figure 4")
for i, (o, spec, unit) in enumerate((("followon", "S00055", "F4|follow-on"), ("contributors", "S00056", "F4|contributors"))):
    ax = fig.add_subplot(gs[i + 1])
    r = R[R.spec_id == spec].copy()
    r["year"] = r.term.str[-4:].astype(int)
    r = pd.concat([r, pd.DataFrame([{"year": 2007, "estimate": 0.0, "ci_low": 0.0, "ci_high": 0.0}])]).sort_values("year")
    rd = readings(unit)
    yrs = sorted(int(k) for k in rd)
    overlay(ax, yrs, [rd[str(y)] for y in yrs])
    coef_panel(ax, r.year, r.estimate, r.ci_low, r.ci_high, ACC, "reconstruction (frozen AI = author spec), 95% CI")
    style(ax, f"{'Follow-on contributions' if o == 'followon' else 'Contributors'}", "year (2007 omitted)")
    plotted += [{"figure": "Figure 4", "series": o, "year": int(y), "estimate": float(e)} for y, e in zip(r.year, r.estimate)]
    if i == 0:
        ax.legend(frameon=False, fontsize=7, loc="lower left")
fig.suptitle("Figure 4: published (left); reconstruction with readers' reading intervals (grey boxes)", x=0.01, ha="left", fontsize=10.5)
save(fig, "fig4")

# Figure 5
f5 = pd.read_csv(os.path.join(FDIAG, "fig5_author_spec.csv"))
fig = plt.figure(figsize=(13, 4.6))
gs = fig.add_gridspec(1, 2, width_ratios=[1, 1.3], wspace=0.15)
pub_axis(fig.add_subplot(gs[0]), "fig5", "Figure 5")
ax = fig.add_subplot(gs[1])
c5 = claims["F5|follow-on"]
sp = c5["origin_specs_by_point"]
r = R[R.spec_id.isin(sp.values()) & (R.term == "treat")].copy()
r["year"] = r.spec_id.map({v: int(k) for k, v in sp.items()})
r = r.sort_values("year")
rd = readings("F5|follow-on")
overlay(ax, [int(k) for k in sorted(rd)], [rd[k] for k in sorted(rd)])
coef_panel(ax, r.year, r.estimate, r.ci_low, r.ci_high, ACC, "reconstruction (frozen AI: controls + quartile FE), 95% CI", dx=-0.12)
coef_panel(ax, f5.year, f5.estimate, f5.ci_low, f5.ci_high, ORG, "author spec (diagnostic): yearly mean, no controls, no FE", marker="s", dx=0.12)
style(ax, "Follow-on contributions, one cross-section per year", "year")
ax.legend(frameon=False, fontsize=7, loc="lower left")
fig.suptitle("Figure 5: published (left); reconstruction and author specification with readers' reading intervals (grey boxes)", x=0.01, ha="left", fontsize=10.5)
save(fig, "fig5")

# Figure 6(a)
f6 = pd.read_csv(os.path.join(FDIAG, "fig6a_author_spec.csv"))
fig = plt.figure(figsize=(16, 4.8))
gs = fig.add_gridspec(1, 3, width_ratios=[1.7, 1, 1], wspace=0.22)
pub_axis(fig.add_subplot(gs[0]), "fig6a", "Figure 6(a)")
for i, (o, unit) in enumerate((("followon", "F6|a follow-on"), ("contributors", "F6|a contributors"))):
    ax = fig.add_subplot(gs[i + 1])
    c = claims[unit]
    m1 = R[R.spec_id.isin(c["origin_specs_by_point"].values()) & (R.term == "post_treat")].copy()
    m1["d"] = m1.spec_id.map({v: int(k) for k, v in c["origin_specs_by_point"].items()})
    m2 = R[R.spec_id.isin(c["alt_estimator_specs_by_point"].values()) & (R.term == "treat")].copy()
    m2["d"] = m2.spec_id.map({v: int(k) for k, v in c["alt_estimator_specs_by_point"].items()})
    m1, m2 = m1.sort_values("d"), m2.sort_values("d")
    rd = readings(unit)
    ks = sorted(int(k) for k in rd)
    overlay(ax, ks, [rd[str(k)] for k in ks])
    coef_panel(ax, m1.d, m1.estimate, m1.ci_low, m1.ci_high, ACC, "AI M1: DiD per decile, controls", dx=-0.2)
    coef_panel(ax, m2.d, m2.estimate, m2.ci_low, m2.ci_high, INK2, "AI M2: cross-section per decile", marker="^", dx=0.0)
    a = f6[f6.outcome == o]
    coef_panel(ax, a.decile, a.estimate, a.ci_low, a.ci_high, ORG, "author spec (diagnostic): pooled, no controls", marker="s", dx=0.2)
    style(ax, "Follow-on contributions" if o == "followon" else "Contributors", "population-density decile")
    ax.set_xticks(range(1, 11))
    if i == 0:
        ax.legend(frameon=False, fontsize=7, loc="upper left")
fig.suptitle("Figure 6(a): published (left); reconstruction (two uncertain estimators) and author specification, readers' intervals in grey", x=0.01, ha="left", fontsize=10.5)
save(fig, "fig6a")

# Figure 6(b)
f6b = pd.read_csv(os.path.join(FDIAG, "fig6b_author_spec.csv"))
fig = plt.figure(figsize=(13, 4.6))
gs = fig.add_gridspec(1, 2, width_ratios=[1, 1.2], wspace=0.15)
pub_axis(fig.add_subplot(gs[0]), "fig6b", "Figure 6(b)")
ax = fig.add_subplot(gs[1])
c = claims["F6|b"]
pc = [10, 25, 50, 75, 90, 99]
r = R[R.spec_id.isin(c["origin_specs_by_point"].values()) & (R.term == "post_treat")].copy()
r["p"] = r.spec_id.map({v: int(k) for k, v in c["origin_specs_by_point"].items()})
r = r.sort_values("p")
xs = np.arange(len(pc))
rd = readings("F6|b")
overlay(ax, xs, [rd[str(p)] for p in pc])
coef_panel(ax, xs, r.estimate, r.ci_low, r.ci_high, ACC, "reconstruction (frozen AI: with controls), 95% CI", dx=-0.12)
coef_panel(ax, xs, f6b.estimate, f6b.ci_low, f6b.ci_high, ORG, "author spec (diagnostic): no controls", marker="s", dx=0.12)
style(ax, "New contributors reaching each lifetime percentile", "percentile")
ax.set_xticks(xs)
ax.set_xticklabels([f"{p}th" for p in pc])
ax.legend(frameon=False, fontsize=7, loc="lower right")
fig.suptitle("Figure 6(b): published (left); reconstruction and author specification with readers' reading intervals (grey boxes)", x=0.01, ha="left", fontsize=10.5)
save(fig, "fig6b")

pd.DataFrame(plotted).to_csv(os.path.join(OUT, "comparison_plotted_values_maps_fig4.csv"), index=False)
json.dump({"published_crops": {k: {"page_image": v[0], "box_px_150dpi": v[1], "locator": v[2]} for k, v in CROPS.items()},
           "reconstruction": "runs/run_20261101_v1/out/A (frozen; A and B agree on every row)",
           "author_spec_sources": {"maps": "post_unseal/diagnostics D01 and D08", "fig3, fig5, fig6": "post_unseal/figure_diagnostics (reproduction checks in reproduction_checks.json)"},
           "readings": "scoring/claims_v1.json plot_points (union of reader intervals)"}, open(os.path.join(OUT, "provenance.json"), "w"), indent=1)
print("done", sorted(os.listdir(OUT)))
