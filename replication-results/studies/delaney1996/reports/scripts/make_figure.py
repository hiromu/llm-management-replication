"""Public-source reconstruction and influence-checks figure (study delaney1996).

Rows: every HRM-practice and interaction coefficient in the eight multi-practice models
(Table 3 models 2-5, Table 4 models 7-10), in the article's table order (fixed before results).
Left: unstandardized OLS coefficient (null = 0): published (cross), reconstructed origin
(dot), min-max over all leave-one-record-out refits (line).
Right: reconstructed upper-tail p (H: beta > 0) at origin (dot) and deletion range (line), log scale,
threshold .05 one-tailed.
Inputs: runs/run_20261028_v1_1/out_A (agrees with out_B to 1e-12), sealed/targets_frozen_v1.json.
"""
import json, os
import numpy as np, pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
RUN = os.path.join(ROOT, 'runs', 'run_20261028_v1_1', 'out_A')
OUT = os.path.join(ROOT, 'reports', 'figures')
os.makedirs(OUT, exist_ok=True)
MODELS = [('org_M2', 'T3 M2'), ('org_M3', 'T3 M3'), ('org_M4', 'T3 M4'), ('org_M5', 'T3 M5'),
          ('mkt_M7', 'T4 M7'), ('mkt_M8', 'T4 M8'), ('mkt_M9', 'T4 M9'), ('mkt_M10', 'T4 M10')]
TERMS = ['STAFF', 'TRAIN', 'INCENT', 'GRIEV', 'DECENT', 'ILM', 'VHIER',
         'TRAIN_x_STAFF', 'GRIEV_x_INCENT', 'ILM_x_DECENT', 'VHIER_x_DECENT']
LABEL = {'STAFF': 'Staffing selectivity', 'TRAIN': 'Training', 'INCENT': 'Incentive comp.', 'GRIEV': 'Grievance proc.',
         'DECENT': 'Decentralization', 'ILM': 'Internal labor mkt', 'VHIER': 'Vertical hierarchy',
         'TRAIN_x_STAFF': 'Training x staffing', 'GRIEV_x_INCENT': 'Grievance x incentive',
         'ILM_x_DECENT': 'ILM x decentral.', 'VHIER_x_DECENT': 'Hierarchy x decentral.'}

coef = pd.read_csv(os.path.join(RUN, 'coefficients.csv'), na_values=['NA'])
coef = coef[coef.spec_id == 'O']
ms = pd.read_csv(os.path.join(RUN, 'model_stats.csv'), na_values=['NA'])
ms = ms[ms.spec_id == 'O'].set_index('model_id')
inf = pd.read_csv(os.path.join(RUN, 'influence.csv'), na_values=['NA'])
T = json.load(open(os.path.join(ROOT, 'sealed', 'targets_frozen_v1.json')))
pub = {(c['model_id'], c['term']): c for c in T['cells'] if c['quantity'] == 'coef'}

rows = []
for mid, mlab in MODELS:
    for t in TERMS:
        r = coef[(coef.model_id == mid) & (coef.term == t)]
        if len(r) == 0: continue
        r = r.iloc[0]
        g = inf[(inf.model_id == mid) & (inf.term == t)]
        ok = g[g.status == 'ok']
        p = pub.get((mid, t), {})
        rows.append(dict(row_label=f'{mlab}  {LABEL[t]}', model_id=mid, term=t,
                         published=p.get('value'), published_se=p.get('se'), published_stars=p.get('stars'),
                         recon=r.estimate, recon_se=r.se, recon_p_upper=r.p_upper, n=int(ms.loc[mid, 'n']),
                         del_min=ok.estimate.min(), del_max=ok.estimate.max(),
                         del_p_min=ok.p_upper.min(), del_p_max=ok.p_upper.max(),
                         n_deletions=len(g), n_deletion_failures=int((g.status != 'ok').sum()),
                         p_zero_or_underflow=int((ok.p_upper <= 0).sum()),
                         source='NOS 1991 ICPSR 6240 V1 DS0002 (user-supplied, validated); implementation A (R), agrees with B'))
df = pd.DataFrame(rows)
df.to_csv(os.path.join(OUT, 'reconstruction_influence.csv'), index=False)

INK, INK2, MUTED, BLUE, SURF = '#0b0b0b', '#52514e', '#9a9893', '#2a78d6', '#fcfcfb'
n = len(df); y = np.arange(n)[::-1]
fig, (a1, a2) = plt.subplots(1, 2, figsize=(11, 0.26 * n + 1.9), sharey=True, gridspec_kw=dict(width_ratios=[1.35, 1]))
fig.patch.set_facecolor(SURF)
for ax in (a1, a2):
    ax.set_facecolor(SURF)
    for s in ('top', 'right'): ax.spines[s].set_visible(False)
    for s in ('left', 'bottom'): ax.spines[s].set_color(MUTED)
    ax.tick_params(colors=INK2, labelsize=8)
# model group separators
bounds = [i for i in range(1, n) if df.model_id.iloc[i] != df.model_id.iloc[i - 1]]
for b in bounds:
    for ax in (a1, a2): ax.axhline(y[b] + 0.5, color='#e6e5e1', lw=0.8, zorder=0)
a1.axvline(0, color=MUTED, lw=1, zorder=1)
a1.hlines(y, df.del_min, df.del_max, color=MUTED, lw=2, zorder=2, label='Leave-one-record-out range')
a1.scatter(df.recon, y, s=28, color=BLUE, zorder=3, label='Reconstructed (origin)')
a1.scatter(df.published, y, s=40, marker='x', color=INK, linewidths=1.3, zorder=4, label='Published')
a1.set_yticks(y); a1.set_yticklabels(df.row_label, fontsize=7.5, color=INK)
a1.set_xlabel('Unstandardized OLS coefficient (null = 0)', color=INK2, fontsize=8.5)
a1.legend(loc='lower left', bbox_to_anchor=(0, 1.0), ncol=3, frameon=False, fontsize=8, labelcolor=INK)
pl = df.recon_p_upper.clip(lower=1e-12)
a2.hlines(y, df.del_p_min.clip(lower=1e-12), df.del_p_max.clip(lower=1e-12), color=MUTED, lw=2, zorder=2)
a2.scatter(pl, y, s=28, color=BLUE, zorder=3)
a2.axvline(0.05, color=INK2, lw=1, ls='--', zorder=1)
a2.text(0.05, y.max() + 0.9, ' p = .05', color=INK2, fontsize=7.5, va='bottom')
a2.set_xscale('log'); a2.set_xlim(1e-7, 1.5)
a2.set_xlabel('Reconstructed one-tailed p (H: coefficient > 0), log scale', color=INK2, fontsize=8.5)
fig.suptitle('HRM practices and perceived performance: published vs public-source reconstruction', x=0.01, ha='left', fontsize=10.5, color=INK)
fig.text(0.01, 0.005, 'Lines are influence ranges over all single-record deletions, not confidence intervals. Origin N: organizational 361, market 239 '
         '(published 590, 373). Association, not causal effect; outcomes are respondent perceptions.', fontsize=7, color=INK2, ha='left', va='bottom')
fig.tight_layout(rect=(0, 0.03, 1, 0.97))
for ext in ('svg', 'png'):
    fig.savefig(os.path.join(OUT, f'reconstruction_influence.{ext}'), dpi=200, facecolor=SURF)
print(df[['row_label', 'published', 'recon', 'del_min', 'del_max', 'recon_p_upper', 'del_p_min', 'del_p_max', 'n_deletions', 'n_deletion_failures']].round(3).to_string())
