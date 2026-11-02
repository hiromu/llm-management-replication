"""Public-source reconstruction and influence-checks figure (registration: reconciliation/figure_registration_v1.json).

Usage: ~/.venv/bin/python -I reports/make_figure.py <study_root>
Inputs: frozen outputs runs/exec_v1/{A,C}/results, sealed/targets_reconciled_v1.json.
Outputs: reports/figure_reconstruction_influence.{svg,png,csv}
"""
import json, math, os, sys
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = sys.argv[1]
ORIGIN = 'U1=0|U2=0|U3=0|U4=0|U5=0|U6=0|U7=0|U8=0'
ROWS = [('M2', 'perf_below'), ('M2', 'perf_below_sq'), ('M2', 'perf_above'), ('M2', 'below_indicator'),
        ('M3', 'perf_below'), ('M3', 'perf_below_sq'), ('M3', 'perf_above'), ('M3', 'below_indicator'),
        ('M3', 'perf_below_x_min'), ('M3', 'perf_below_sq_x_min'), ('M3', 'perf_above_x_min')]
LABEL = {'perf_below': 'Performance (≤ aspiration)', 'perf_below_sq': 'Performance² (≤ aspiration)',
         'perf_above': 'Performance (> aspiration)', 'below_indicator': 'Indicator (≤ aspiration)',
         'perf_below_x_min': 'Perf. (≤ asp.) × minutes', 'perf_below_sq_x_min': 'Perf.² (≤ asp.) × minutes',
         'perf_above_x_min': 'Perf. (> asp.) × minutes'}
BAND = {'**': (1e-300, .01), '*': (.01, .05), '+': (.05, .10), 'none': (.10, 1.0)}
INK, INK2, MUTED, SURF = '#0b0b0b', '#52514e', '#c3c2b7', '#fcfcfb'
REC, PUB, RANGE = '#2a78d6', '#eb6834', '#86b6ef'
PFLOOR = 1e-300

T = json.load(open(os.path.join(ROOT, 'sealed/targets_reconciled_v1.json')))['targets']
coefs = pd.read_csv(os.path.join(ROOT, 'runs/exec_v1/A/results/coefs.csv')).drop_duplicates(['spec_id', 'term'])
infl = pd.read_csv(os.path.join(ROOT, 'runs/exec_v1/C/results/influence.csv'))
specs = pd.read_csv(os.path.join(ROOT, 'runs/exec_v1/A/results/specs.csv')).drop_duplicates('spec_id')
N = int(specs[specs.spec_id == f'M2|{ORIGIN}'].iloc[0].n_obs)

recs = []
for m, term in ROWS:
    t = T[f'T5|{m}|{term}']
    orv, ors = float(t['value']), float(t['published_se'])
    se_up = (ors + 0.0005) / (orv - 0.0005)
    o = coefs[(coefs.spec_id == f'{m}|{ORIGIN}') & (coefs.term == term)].iloc[0]
    row = dict(row=f'{m} {term}', model=m, term=term, published_or=orv, published_or_se=ors, published_stars=t['stars'],
               published_logor=math.log(orv), published_log_se_upper=se_up, reconstructed_coef=o.estimate,
               reconstructed_se=o.se_native, reconstructed_p=o.p_native, reconstructed_p_bench=None)
    for unit in ('game', 'team', 'season'):
        g = infl[(infl.unit_type == unit) & (infl.model == m) & (infl.term == term)]
        ok = g[g.status == 'ok']
        row.update({f'{unit}_n_units': len(g), f'{unit}_n_failed': int((g.status != 'ok').sum()),
                    f'{unit}_coef_min': ok.estimate.min(), f'{unit}_coef_max': ok.estimate.max(),
                    f'{unit}_p_min': ok.p_native.min(), f'{unit}_p_max': ok.p_native.max()})
    row['p_underflow_flag'] = bool(row['reconstructed_p'] < PFLOOR or row['game_p_min'] < PFLOOR)
    recs.append(row)
df = pd.DataFrame(recs)
df['provenance'] = ('nflverse play-by-play 2000-2005 (release pbp, acquired 2026-10-27) and schedules; '
                    'team-season alignment from nfldata standings and Wikipedia templates; '
                    'estimates from implementation A (agrees with B and C); deletions from implementation C (agrees with A)')
df.to_csv(os.path.join(ROOT, 'reports/figure_reconstruction_influence.csv'), index=False)

plt.rcParams.update({'font.size': 9, 'axes.edgecolor': MUTED, 'axes.labelcolor': INK2, 'xtick.color': INK2,
                     'ytick.color': INK2, 'figure.facecolor': SURF, 'axes.facecolor': SURF})
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 5.6), sharey=True, gridspec_kw={'width_ratios': [1.15, 1]})
y = list(range(len(df)))[::-1]
for yi, r in zip(y, df.itertuples()):
    s = r.published_log_se_upper
    ax1.hlines(yi, r.game_coef_min / s, r.game_coef_max / s, color=RANGE, lw=5, zorder=1, capstyle='round')
    ax1.hlines(yi - 0.22, r.team_coef_min / s, r.team_coef_max / s, color=INK2, lw=1.2, zorder=1)
    ax1.scatter(r.reconstructed_coef / s, yi, s=40, color=REC, zorder=3, edgecolor=SURF, linewidth=1.5)
    ax1.scatter(r.published_logor / s, yi, s=55, marker='x', color=PUB, zorder=4, linewidth=2)
    lo, hi = BAND[r.published_stars if r.published_stars in BAND else 'none']
    ax2.add_patch(plt.Rectangle((max(lo, 1e-120), yi - 0.3), min(hi, 1) - max(lo, 1e-120), 0.6, color='#f0efec', zorder=0))
    ax2.hlines(yi, max(r.game_p_min, PFLOOR), r.game_p_max, color=RANGE, lw=5, zorder=1, capstyle='round')
    ax2.scatter(max(r.reconstructed_p, PFLOOR), yi, s=40, color=REC, zorder=3, edgecolor=SURF, linewidth=1.5)
ax1.axvline(0, color=INK2, lw=0.8)
ax1.set_yticks(y)
ax1.set_yticklabels([f'{r.model}  {LABEL[r.term]}' for r in df.itertuples()])
ax1.axhline(6.5, color=MUTED, lw=0.6)
ax1.set_xlabel('Logit coefficient ÷ published SE (log-odds scale; null = 0)')
ax1.set_title('Coefficient: published vs reconstructed', loc='left', color=INK, fontsize=10)
ax2.set_xscale('log')
ax2.set_xlim(1e-110, 1.5)
ax2.axvline(0.05, color=INK2, lw=0.8, ls='--')
ax2.text(0.05, len(df) - 0.4, ' p = 0.05', color=INK2, fontsize=8, va='bottom')
ax2.set_xlabel('Two-sided p (native SE), log scale')
ax2.set_title('Inference: reconstructed p and published star band', loc='left', color=INK, fontsize=10)
for ax in (ax1, ax2):
    ax.grid(axis='x', color='#e6e5e0', lw=0.5)
    for sp in ('top', 'right'):
        ax.spines[sp].set_visible(False)
h = [plt.Line2D([], [], marker='x', ls='', color=PUB, mew=2, label='Published (ln odds ratio)'),
     plt.Line2D([], [], marker='o', ls='', color=REC, label='Reconstructed (origin)'),
     plt.Line2D([], [], color=RANGE, lw=5, label=f'Leave-one-game-out range ({int(df.game_n_units.iloc[0])} games)'),
     plt.Line2D([], [], color=INK2, lw=1.2, label=f'Leave-one-team-out range ({int(df.team_n_units.iloc[0])} teams)'),
     plt.Rectangle((0, 0), 1, 1, color='#f0efec', label='Published significance band (stars)')]
fig.legend(handles=h, loc='lower center', ncol=3, frameon=False, fontsize=8, bbox_to_anchor=(0.5, -0.01))
fig.suptitle(f'Conditional FE logit of fourth-down conversion attempts, NFL 2000-2005 public play-by-play (N = {N:,})',
             x=0.01, ha='left', color=INK, fontsize=11)
fig.tight_layout(rect=(0, 0.07, 1, 0.96))
for ext in ('svg', 'png'):
    fig.savefig(os.path.join(ROOT, f'reports/figure_reconstruction_influence.{ext}'), dpi=200)
print(df[['row', 'published_logor', 'reconstructed_coef', 'game_coef_min', 'game_coef_max', 'reconstructed_p', 'game_p_max']].to_string())
