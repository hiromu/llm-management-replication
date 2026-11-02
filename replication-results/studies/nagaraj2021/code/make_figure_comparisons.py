"""Side-by-side figure comparisons, v2 (instructions/reporting.md, figure comparison).

v2 draws every reconstructed and author-specification panel in the visual form of the published figure: same chart
type, marker and line styles, group encoding, uncertainty display, reference lines, panel titles and axis ranges
(widened only when the reconstruction falls outside them). Readers' plot readings use a separate encoding (orange open
triangles with thin interval bars) that cannot be mistaken for a confidence interval. v1 (code/make_figure_comparisons_v1.py,
reports/figures/comparison_v1/) drew uncertainty as error bars and readings as grey boxes.

Published panels: crops of 150-dpi renders of packet/frozen_v1/D01_article.pdf. Reconstruction: frozen implementation-A
outputs (runs/run_20261101_v1). Author specification: post-unsealing diagnostics (post_unseal/diagnostics,
post_unseal/figure_diagnostics). Presentation only: no score changes.
usage: make_figure_comparisons.py
"""
import json, os
import geopandas as gpd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
import numpy as np
import pandas as pd
from PIL import Image

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(STUDY, "reports/figures/comparison")
PAGES = os.path.join(OUT, "published_pages")
RUN = os.path.join(STUDY, "runs/run_20261101_v1/out/A")
DIAG = os.path.join(STUDY, "post_unseal/diagnostics")
FDIAG = os.path.join(STUDY, "post_unseal/figure_diagnostics")

# Styles taken from the published figures
STATA_BLUE = "#2b6a8c"     # Figures 4-5 estimate markers and line
CI_GREY = "#8c8c8c"        # dashed interval lines (Figures 4-5)
REF_PINK = "#e0457b"       # vertical event line / zero line (Figures 3, 4, 6)
CTRL_INK = "#111111"       # Figure 3 control: dark dashed, filled circles
TREAT_GREY = "#9a9a9a"     # Figure 3 treatment: light grey solid, open squares
MAP_TREAT, MAP_CTRL = "#2e9e3f", "#d3d3d3"
READ = "#eb6834"           # reader readings overlay (not part of the published style)
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 8, "axes.edgecolor": "#444444", "xtick.color": "#444444",
                     "ytick.color": "#444444", "axes.facecolor": "white", "figure.facecolor": "white"})

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


def block_title(ax_or_fig, text, **kw):
    ax_or_fig.set_title(text, fontsize=9, loc="left", color="#111111", **kw)


def pub_axis(ax, key):
    im, loc = PUB[key]
    ax.imshow(im)
    ax.set_axis_off()
    block_title(ax, f"Published ({loc})")


def save(fig, name):
    fig.savefig(os.path.join(OUT, f"{name}.png"), dpi=170, bbox_inches="tight")
    fig.savefig(os.path.join(OUT, f"{name}.svg"), bbox_inches="tight")
    plt.close(fig)


def stata_axes(ax, xlim=None, ylim=None, data=None):
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
    ax.tick_params(length=3)
    if xlim:
        ax.set_xlim(*xlim)
    if ylim is not None:
        lo, hi = ylim
        if data is not None and len(data):
            lo, hi = min(lo, np.nanmin(data)), max(hi, np.nanmax(data))   # widen only if the data fall outside
        ax.set_ylim(lo, hi)


def readings(unit):
    out = {}
    for key, rs in claims[unit]["published"].items():
        lo, hi = min(r["interval"][0] for r in rs), max(r["interval"][1] for r in rs)
        out[key] = (lo, hi)
    return out


def overlay_readings(ax, xs, rd, label=True):
    xs = np.asarray(xs, dtype=float)
    lo = np.array([r[0] for r in rd])
    hi = np.array([r[1] for r in rd])
    mid = (lo + hi) / 2
    ax.errorbar(xs, mid, yerr=[mid - lo, hi - mid], fmt="^", ms=4.5, mfc="none", mec=READ, ecolor=READ, elinewidth=0.8,
                capsize=1.5, zorder=5, label="published value read from plot (reader interval)" if label else None)


# ---------------- maps (Figures 1-2): green hatched treated, light grey control, white elsewhere -----------------
cty = gpd.read_file("zip://" + os.path.join(STUDY, "data/derived/bundle_v1/tl_2010_us_county10.zip"))
cty["fips"] = cty.GEOID10.astype(int)
cty = cty[~cty.STATEFP10.isin(["02", "15", "60", "66", "69", "72", "78"])].to_crs(5070)
M_ai = pd.read_csv(os.path.join(RUN, "an09_membership.csv"))
M_ma = pd.read_csv(os.path.join(DIAG, "D01_MA_as_controls/out/an09_membership.csv"))
M_tw = pd.read_csv(os.path.join(DIAG, "D08_timing_window/out/an09_membership.csv"))


def draw_map(ax, m, col, title):
    g = cty.merge(m[m[col] == 1][["fips", "treat"]], on="fips", how="left")
    g.plot(ax=ax, color="white", edgecolor="#9a9a9a", linewidth=0.08)
    g[g.treat == 0].plot(ax=ax, color=MAP_CTRL, edgecolor="#9a9a9a", linewidth=0.08)
    g[g.treat == 1].plot(ax=ax, color=MAP_TREAT, edgecolor="#1f6e2b", linewidth=0.08, hatch="//////")
    n1 = int(((m[col] == 1) & (m.treat == 1)).sum())
    n0 = int(((m[col] == 1) & (m.treat == 0)).sum())
    ax.legend(handles=[Patch(facecolor=MAP_CTRL, edgecolor="#9a9a9a", label="Control Counties"),
                       Patch(facecolor=MAP_TREAT, edgecolor="#1f6e2b", hatch="////", label="Treated Counties")],
              loc="lower left", frameon=False, fontsize=7)
    ax.set_axis_off()
    block_title(ax, f"{title}\n{n1 + n0:,} counties: {n1:,} treated, {n0:,} control")
    plotted.append({"figure": title, "counties": n1 + n0, "treated": n1, "control": n0})


for key, col, name, panels in [
        ("fig1a", "in_full", "Figure 1(a)", [(M_ai, "Reconstruction: Massachusetts excluded (as the article states)"),
                                            (M_ma, "Author specification (diagnostic): Massachusetts kept as control")]),
        ("fig2a", "in_boundary_B1", "Figure 2(a)", [(M_ai, "Reconstruction: boundary sample"),
                                                   (M_ma, "Author specification (diagnostic): Massachusetts kept")]),
        ("fig2b", "in_timing", "Figure 2(b)", [(M_ai, "Reconstruction: scheduled in calendar 2005-2006"),
                                              (M_tw, "Author specification (diagnostic): within 12 months of June 2005")])]:
    fig = plt.figure(figsize=(16, 4.4))
    gs = fig.add_gridspec(1, 3, wspace=0.03)
    pub_axis(fig.add_subplot(gs[0]), key)
    for i, (m, t) in enumerate(panels):
        draw_map(fig.add_subplot(gs[i + 1]), m, col, t)
    fig.suptitle(f"{name}: published | reconstruction | author specification", x=0.01, ha="left", fontsize=10.5)
    save(fig, key)

# ---------------- Figure 3: control dark dashed + filled circles, treatment light grey solid + open squares ----------
a10 = pd.read_csv(os.path.join(RUN, "an10_means.csv"))
a10 = a10[a10.followon_def.isna() | (a10.followon_def == "followon_F1")]
a10["x"] = a10.quarter.str[:4].astype(int) + (a10.quarter.str[-1].astype(int) - 1) / 4
f3 = pd.read_csv(os.path.join(FDIAG, "fig3_author_annual.csv"))
cumstat = [s for s in a10.statistic.unique() if "cum" in s][0]
YL3 = {("total", "log"): (0, 8), ("total", "cum"): (0, 150000), ("followon", "log"): (0, 4), ("followon", "cum"): (0, 25000)}


def fig3_block(fig, outer, source, title):
    gs = outer.subgridspec(2, 2, hspace=0.45, wspace=0.35)
    for r, o in enumerate(("total", "followon")):
        for c, kind in enumerate(("log", "cum")):
            ax = fig.add_subplot(gs[r, c])
            ys_all = []
            for tr in (1, 0):
                if source == "recon":
                    s = a10[(a10.outcome == o) & (a10.treat == tr) & (a10.statistic == ("mean_log_y_plus_1" if kind == "log" else cumstat))].sort_values("x")
                    x, y = s.x, s.value
                else:
                    s = f3[(f3.outcome == o) & (f3.treat == tr)].sort_values("year")
                    x, y = s.year, (s.lnmean if kind == "log" else s.cummean)
                ys_all.append(np.asarray(y, dtype=float))
                if tr == 0:
                    ax.plot(x, y, ls=(0, (5, 3)), color=CTRL_INK, lw=1.1, marker="o", ms=2.6, label="Control Counties")
                else:
                    ax.plot(x, y, "-", color=TREAT_GREY, lw=1.1, marker="s", ms=2.6, mfc="white", label="Treatment Counties")
            ax.axvline(2007.5, color=REF_PINK, lw=0.7, ls=":")
            stata_axes(ax, (2004, 2014.9), YL3[(o, kind)], data=np.concatenate(ys_all))
            ax.set_xticks(range(2004, 2015, 2))
            ax.set_title(f"({'a' if o == 'total' else 'b'}) {'i. Logged' if kind == 'log' else 'ii. Cumulative'}", fontsize=8, style="italic")
            if r == 0 and c == 1:
                ax.legend(loc="upper left", frameon=False, fontsize=6.5)
    fig.text(outer.get_position(fig).x0, outer.get_position(fig).y1 + 0.075, title, fontsize=9)


fig = plt.figure(figsize=(21, 7.0))
gs = fig.add_gridspec(1, 3, width_ratios=[1.25, 1, 1], wspace=0.12)
pub_axis(fig.add_subplot(gs[0]), "fig3")
fig3_block(fig, gs[1], "recon", "Reconstruction (frozen AI, quarterly, as the manifest specifies)")
fig3_block(fig, gs[2], "author", "Author specification (diagnostic): annual means")
fig.suptitle("Figure 3: published | reconstruction | author specification (not scored)", x=0.01, ha="left", fontsize=10.5)
save(fig, "fig3")

# ---------------- Figure 4: connected estimates, dashed CI lines, long-dash zero line, event line at 2007 ----------
fig = plt.figure(figsize=(16, 4.6))
gs = fig.add_gridspec(1, 3, width_ratios=[1.8, 1, 1], wspace=0.22)
pub_axis(fig.add_subplot(gs[0]), "fig4")
for i, (o, spec, unit, ylim) in enumerate((("followon", "S00055", "F4|follow-on", (-0.4, 0.2)),
                                           ("contributors", "S00056", "F4|contributors", (-0.3, 0.1)))):
    ax = fig.add_subplot(gs[i + 1])
    r = R[R.spec_id == spec].copy()
    r["year"] = r.term.str[-4:].astype(int)
    r = pd.concat([r, pd.DataFrame([{"year": 2007, "estimate": 0.0, "ci_low": 0.0, "ci_high": 0.0}])]).sort_values("year")
    ax.axhline(0, color=CI_GREY, lw=0.8, ls=(0, (10, 5)))
    ax.axvline(2007, color=REF_PINK, lw=0.7, ls=(0, (3, 3)))
    ax.plot(r.year, r.ci_low, ls=(0, (4, 3)), color=CI_GREY, lw=0.8, label="95% confidence interval")
    ax.plot(r.year, r.ci_high, ls=(0, (4, 3)), color=CI_GREY, lw=0.8)
    pre, post = r[r.year <= 2007], r[r.year >= 2007]
    ax.plot(pre.year, pre.estimate, "-", color=STATA_BLUE, lw=1, marker="o", ms=3.5, mfc="white", label="estimate (reconstruction)")
    ax.plot(post.year, post.estimate, "-", color=STATA_BLUE, lw=1, marker="s", ms=3.5, mfc="white")
    rd = readings(unit)
    yrs = sorted(int(k) for k in rd)
    overlay_readings(ax, yrs, [rd[str(y)] for y in yrs])
    stata_axes(ax, (2004, 2014.4), ylim, data=np.r_[r.ci_low, r.ci_high])
    ax.set_xticks(range(2004, 2015, 2))
    ax.set_xlabel("Years")
    ax.set_title("Follow-on Contributions" if o == "followon" else "Contributors", fontsize=8.5)
    plotted += [{"figure": "Figure 4", "series": o, "year": int(y), "estimate": float(e), "ci_low": float(lo), "ci_high": float(hi)}
                for y, e, lo, hi in zip(r.year, r.estimate, r.ci_low, r.ci_high)]
    if i == 0:
        ax.legend(loc="lower left", frameon=False, fontsize=6.5)
fig.suptitle("Figure 4: published | reconstruction (same specification as the author code)", x=0.01, ha="left", fontsize=10.5)
save(fig, "fig4")


# ---------------- Figure 5: hollow diamonds, dashed capped CI lines, long-dash zero line ----------------------------
def fig5_panel(ax, years, est, lo, hi, title, with_readings):
    ax.axhline(0, color=CI_GREY, lw=0.8, ls=(0, (10, 5)))
    ax.vlines(years, lo, hi, colors=CI_GREY, lw=0.8, linestyles=(0, (4, 3)), label="95% confidence interval")
    ax.hlines(np.r_[lo, hi], np.r_[years, years] - 0.08, np.r_[years, years] + 0.08, colors=CI_GREY, lw=0.8)
    ax.plot(years, est, "D", ms=3.8, mfc="white", mec=STATA_BLUE, mew=1.1, ls="none", label="estimate")
    if with_readings:
        rd = readings("F5|follow-on")
        ys = sorted(int(k) for k in rd)
        overlay_readings(ax, np.array(ys) + 0.22, [rd[str(y)] for y in ys])
    stata_axes(ax, (2004, 2014.5), (-0.5, 0.0), data=np.r_[lo, hi])
    ax.set_xticks(range(2004, 2015, 2))
    ax.set_xlabel("Year")
    ax.set_ylabel("Estimated Treatment Effect")
    ax.set_title("Follow-on Contributions", fontsize=8.5)
    ax.text(0.0, 1.10, title.strip(), transform=ax.transAxes, ha="left", va="bottom", fontsize=9)


f5 = pd.read_csv(os.path.join(FDIAG, "fig5_author_spec.csv"))
sp = claims["F5|follow-on"]["origin_specs_by_point"]
r5 = R[R.spec_id.isin(sp.values()) & (R.term == "treat")].copy()
r5["year"] = r5.spec_id.map({v: int(k) for k, v in sp.items()})
r5 = r5.sort_values("year")
fig = plt.figure(figsize=(17, 4.6))
gs = fig.add_gridspec(1, 3, width_ratios=[1, 1, 1], wspace=0.28)
pub_axis(fig.add_subplot(gs[0]), "fig5")
ax = fig.add_subplot(gs[1])
fig5_panel(ax, r5.year.to_numpy(), r5.estimate.to_numpy(), r5.ci_low.to_numpy(), r5.ci_high.to_numpy(),
           "\nReconstruction (frozen AI: controls and quartile FE)", True)
ax.legend(loc="lower left", frameon=False, fontsize=6.5)
ax = fig.add_subplot(gs[2])
fig5_panel(ax, f5.year.to_numpy(), f5.estimate.to_numpy(), f5.ci_low.to_numpy(), f5.ci_high.to_numpy(),
           "\nAuthor specification (diagnostic): yearly mean, no controls", True)
fig.suptitle("Figure 5: published | reconstruction | author specification", x=0.01, ha="left", fontsize=10.5)
save(fig, "fig5")


# ---------------- Figure 6(a): black diamonds, solid vertical CI lines, dashed pink zero line ----------------------
def fig6a_panel(ax, d, est, lo, hi, ylim, title, unit=None):
    ax.axhline(0, color=REF_PINK, lw=0.7, ls=(0, (3, 3)))
    ax.vlines(d, lo, hi, colors="#111111", lw=1.0)
    ax.plot(d, est, "D", ms=3, color="#111111", ls="none")
    if unit:
        rd = readings(unit)
        ks = sorted(int(k) for k in rd)
        overlay_readings(ax, np.array(ks) + 0.3, [rd[str(k)] for k in ks], label=False)
    stata_axes(ax, (0.5, 10.5), ylim, data=np.r_[lo, hi])
    ax.set_xticks(range(1, 11))
    ax.set_title(title, fontsize=8, fontweight="bold")


f6 = pd.read_csv(os.path.join(FDIAG, "fig6a_author_spec.csv"))
YL6 = {"followon": (-0.5, 1.5), "contributors": (-0.4, 0.6)}
fig = plt.figure(figsize=(17, 9.5))
outer = fig.add_gridspec(1, 2, width_ratios=[1.15, 1.6], wspace=0.08)
pub_axis(fig.add_subplot(outer[0]), "fig6a")
inner = outer[1].subgridspec(3, 2, hspace=0.62, wspace=0.22)
rows = []
for o, unit in (("followon", "F6|a follow-on"), ("contributors", "F6|a contributors")):
    c = claims[unit]
    m1 = R[R.spec_id.isin(c["origin_specs_by_point"].values()) & (R.term == "post_treat")].copy()
    m1["d"] = m1.spec_id.map({v: int(k) for k, v in c["origin_specs_by_point"].items()})
    m2 = R[R.spec_id.isin(c["alt_estimator_specs_by_point"].values()) & (R.term == "treat")].copy()
    m2["d"] = m2.spec_id.map({v: int(k) for k, v in c["alt_estimator_specs_by_point"].items()})
    au = f6[f6.outcome == o].rename(columns={"decile": "d"})
    rows.append((o, unit, m1.sort_values("d"), m2.sort_values("d"), au.sort_values("d")))
labels = ["Reconstruction M1 (frozen AI): DiD within each decile, with controls",
          "Reconstruction M2 (frozen AI): cross-section within each decile",
          "Author specification (diagnostic): one pooled regression, no controls"]
for j, (o, unit, m1, m2, au) in enumerate(rows):
    for i, df in enumerate((m1, m2, au)):
        ax = fig.add_subplot(inner[i, j])
        fig6a_panel(ax, df.d.to_numpy(), df.estimate.to_numpy(), df.ci_low.to_numpy(), df.ci_high.to_numpy(), YL6[o],
                    "Follow-on Contrib." if o == "followon" else "Contributors", unit)
        if j == 0:
            ax.text(0.0, 1.22, labels[i], transform=ax.transAxes, fontsize=8.5, ha="left")
fig.legend(handles=[plt.Line2D([], [], marker="^", color=READ, mfc="none", ls="none", label="published value read from plot (reader interval)")],
           loc="lower right", frameon=False, fontsize=7.5)
fig.suptitle("Figure 6(a): published | reconstruction (two readings of the method) | author specification", x=0.01, ha="left", fontsize=10.5)
save(fig, "fig6a")

# ---------------- Figure 6(b): one marker and vertical CI line per percentile, labelled, dashed pink zero line ------
PC = [10, 25, 50, 75, 90, 99]
PCOL = ["#111111", "#9a9a9a", "#2a9fd6", "#1baf7a", "#c27aa0", "#e0457b"]


def fig6b_panel(ax, est, lo, hi, title):
    xs = np.arange(1, 7)
    ax.axhline(0, color=REF_PINK, lw=0.7, ls=(0, (3, 3)))
    for x, e, l, h, p, colr in zip(xs, est, lo, hi, PC, PCOL):
        ax.vlines(x, l, h, colors=colr, lw=1.2 if p == 10 else 0.9)
        ax.plot(x, e, "D", ms=3, color=colr)
        ax.text(x + 0.08, e, f"{p}th Pctile", fontsize=6.5, va="center")
    rd = readings("F6|b")
    overlay_readings(ax, xs - 0.18, [rd[str(p)] for p in PC])
    stata_axes(ax, (0.3, 7.0), (-0.1, 0.0), data=np.r_[lo, hi])
    ax.set_xticks([])
    ax.set_xlabel("Treatment Effect")
    block_title(ax, title)


f6b = pd.read_csv(os.path.join(FDIAG, "fig6b_author_spec.csv"))
c = claims["F6|b"]
r6 = R[R.spec_id.isin(c["origin_specs_by_point"].values()) & (R.term == "post_treat")].copy()
r6["p"] = r6.spec_id.map({v: int(k) for k, v in c["origin_specs_by_point"].items()})
r6 = r6.sort_values("p")
fig = plt.figure(figsize=(17, 4.8))
gs = fig.add_gridspec(1, 3, width_ratios=[1, 1, 1], wspace=0.2)
pub_axis(fig.add_subplot(gs[0]), "fig6b")
ax = fig.add_subplot(gs[1])
fig6b_panel(ax, r6.estimate.to_numpy(), r6.ci_low.to_numpy(), r6.ci_high.to_numpy(), "Reconstruction (frozen AI: with controls)")
ax.legend(loc="lower right", frameon=False, fontsize=6.5)
ax = fig.add_subplot(gs[2])
fig6b_panel(ax, f6b.estimate.to_numpy(), f6b.ci_low.to_numpy(), f6b.ci_high.to_numpy(), "Author specification (diagnostic): no controls")
fig.suptitle("Figure 6(b): published | reconstruction | author specification", x=0.01, ha="left", fontsize=10.5)
save(fig, "fig6b")

pd.DataFrame(plotted).to_csv(os.path.join(OUT, "comparison_plotted_values_maps_fig4.csv"), index=False)
json.dump({"version": "v2: reconstructed and author panels drawn in the published figures' visual form",
           "published_crops": {k: {"page_image": v[0], "box_px_150dpi": v[1], "locator": v[2]} for k, v in CROPS.items()},
           "reconstruction": "runs/run_20261101_v1/out/A (frozen; A and B agree on every row)",
           "author_spec_sources": {"maps": "post_unseal/diagnostics D01 and D08", "fig3, fig5, fig6": "post_unseal/figure_diagnostics"},
           "readings_overlay": "scoring/claims_v1.json plot_points: union of reader intervals, orange open triangles",
           "previous_version": "reports/figures/comparison_v1, code/make_figure_comparisons_v1.py"},
          open(os.path.join(OUT, "provenance.json"), "w"), indent=1)
print("done")
