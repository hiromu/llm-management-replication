"""Public-source reconstruction and influence-checks figure (Table 4 focal hierarchy marginal effects).
Inputs: scoring/claim_scores.csv (A-B agreed origin values, printed targets), scoring/influence_summary.csv (implementation A,
all leave-one-camp-out deletions). Outputs: reconstruction_influence.svg/.png and reconstruction_influence.csv."""
import os
import numpy as np, pandas as pd
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.dirname(os.path.abspath(__file__))
INK, INK2, BLUE, BLUE_LIGHT, GRID, SURF = '#0b0b0b', '#52514e', '#2a78d6', '#86b6ef', '#e4e3df', '#fcfcfb'
ORDER = [('steepness', 'cap', 'simple'), ('steepness', 'cap', 'full'), ('steepness', 'camp', 'simple'), ('steepness', 'camp', 'full'),
         ('sameness', 'cap', 'simple'), ('sameness', 'cap', 'full'), ('sameness', 'camp', 'simple'), ('sameness', 'camp', 'full')]
LAB = {'steepness': 'Steepness', 'sameness': 'Sameness', 'cap': 'captured cohort', 'camp': 'camp cohort', 'simple': 'simple', 'full': 'full controls'}
cs = pd.read_csv(f'{ROOT}/scoring/claim_scores.csv'); cs = cs[cs.tier == 'focal']
inf = pd.read_csv(f'{ROOT}/scoring/influence_summary.csv')
rows = []
for m, g, s in ORDER:
    c = cs[(cs.measure == m) & (cs.group == g) & (cs.spec == s)].iloc[0]
    i = inf[inf.model_key == f't4|{g}|{s}|{m}'].iloc[0]
    pp = float(c.printed_p)
    rows.append({'row': f"{LAB[m]}, {LAB[g]}, {LAB[s]}", 'measure': m, 'group': g, 'spec': s,
                 'published_me': float(c.printed_value), 'published_p_printed': c.printed_p,
                 'published_p_plot': max(pp, 0.005), 'published_p_is_upper_bound': pp == 0.0,
                 'reconstructed_me': c.rec_me, 'reconstructed_p': c.rec_p, 'n_reconstructed': int(c.n_rec), 'n_published': 100464,
                 'deletion_me_min': i.me_min, 'deletion_me_max': i.me_max, 'deletion_p_min': i.p_min, 'deletion_p_max': i.p_max,
                 'deletions_ok': int(i.deletions_ok), 'deletions_failed': int(i.deletions_failed), 'outcome': c.outcome,
                 'source': 'NARA RG 389 POW Data File (NAID 1263907) linked to NARA RG 64 Army enlistment file (NAID 1263923); values from implementations A and B (agree within tolerance)'})
d = pd.DataFrame(rows); d.to_csv(f'{OUT}/reconstruction_influence.csv', index=False)

plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 9, 'axes.edgecolor': INK2, 'axes.labelcolor': INK, 'xtick.color': INK2, 'ytick.color': INK})
fig, (a1, a2) = plt.subplots(1, 2, figsize=(10.5, 4.8), sharey=True, gridspec_kw={'width_ratios': [1.15, 1]})
fig.patch.set_facecolor(SURF)
y = np.arange(len(d))[::-1]
for ax in (a1, a2):
    ax.set_facecolor(SURF); ax.grid(axis='x', color=GRID, lw=0.8); ax.set_axisbelow(True)
    for sp in ('top', 'right'): ax.spines[sp].set_visible(False)
    ax.axhline(3.5, color=GRID, lw=1)
a1.hlines(y, d.deletion_me_min, d.deletion_me_max, color=BLUE_LIGHT, lw=3, label='Leave-one-camp-out range (influence, not a CI)', zorder=2)
a1.scatter(d.reconstructed_me, y, s=46, color=BLUE, edgecolor=SURF, linewidth=1.5, zorder=4, label='Reconstructed (public sources)')
a1.scatter(d.published_me, y, s=60, marker='x', color=INK, linewidth=1.6, zorder=5, label='Published (rounded to 0.01)')
a1.axvline(0, color=INK2, lw=1)
a1.set_yticks(y); a1.set_yticklabels(d.row)
a1.set_xlabel('Marginal effect on Pr(survive) at means (null = 0)')
a1.set_title('Hierarchy effect', loc='left', color=INK, fontsize=10)
a2.set_xscale('log')
a2.hlines(y, d.deletion_p_min, d.deletion_p_max, color=BLUE_LIGHT, lw=3, zorder=2)
a2.scatter(d.reconstructed_p, y, s=46, color=BLUE, edgecolor=SURF, linewidth=1.5, zorder=4)
ub = d.published_p_is_upper_bound
a2.scatter(d.published_p_plot[~ub], y[~ub], s=60, marker='x', color=INK, linewidth=1.6, zorder=5)
a2.scatter(d.published_p_plot[ub], y[ub], s=60, marker=r'$\leftarrow$', color=INK, zorder=5)
for t, ls in [(0.05, '-'), (0.10, ':')]:
    a2.axvline(t, color=INK2, lw=1, ls=ls)
a2.text(0.05, len(d) - 0.35, 'p = 0.05', ha='right', va='bottom', fontsize=8, color=INK2)
a2.text(0.10, len(d) - 0.35, ' 0.10', ha='left', va='bottom', fontsize=8, color=INK2)
a2.set_xlim(1e-12, 1)
a2.set_xlabel('Two-sided p value, clustered (log scale)')
a2.set_title('Inference', loc='left', color=INK, fontsize=10)
h, l = a1.get_legend_handles_labels()
arrow = plt.Line2D([], [], marker=r'$\leftarrow$', color=INK, ls='none', markersize=9)
fig.legend(h[::-1] + [arrow], l[::-1] + ['Published p printed as 0.00 (p < 0.005)'], loc='lower center', ncol=4, frameon=False,
           fontsize=8.5, bbox_to_anchor=(0.52, -0.01))
fig.tight_layout(rect=(0, 0.07, 1, 1))
fig.savefig(f'{OUT}/reconstruction_influence.svg', facecolor=SURF); fig.savefig(f'{OUT}/reconstruction_influence.png', dpi=200, facecolor=SURF)
print(d[['row', 'published_me', 'reconstructed_me', 'deletion_me_min', 'deletion_me_max', 'published_p_printed', 'reconstructed_p', 'deletion_p_min', 'deletion_p_max']].round(4).to_string())
