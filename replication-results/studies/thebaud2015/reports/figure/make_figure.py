"""Public-source reconstruction and influence-checks figure for thebaud2015.

Usage: ~/.venv/bin/python reports/figure/make_figure.py   (run from the study root)
Inputs: runs/exec_v1/ORIGIN_A/results.csv (origin fit, implementation A),
        runs/exec_v1/INF_A_M*/results.csv (country-deletion refits, implementation A),
        scoring/final_v1/term_scores.csv (sealed published values as transcribed by both readers).
Outputs: reports/figure/influence_figure.{svg,png,csv}
Row order is fixed in advance (model order M3-M8, then leave, leave squared, childcare, part-time) and does not depend on results.
"""
import glob, os
import numpy as np, pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

S = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(S, 'reports', 'figure')
MODELS = ['M3', 'M4', 'M5', 'M6', 'M7', 'M8']
TERMS = ['female:leave', 'female:leave_sq', 'female:childcare', 'female:parttime']
TLAB = {'female:leave': 'Female x paid leave', 'female:leave_sq': 'Female x paid leave sq.',
        'female:childcare': 'Female x childcare', 'female:parttime': 'Female x part-time'}
MLAB = {'M3': 'M3 any activity (logit)', 'M4': 'M4 plan-B owner (logit)', 'M5': 'M5 size (linear)',
        'M6': 'M6 growth (logit)', 'M7': 'M7 new product (logit)', 'M8': 'M8 new technology (logit)'}
FOCAL = {('M3', 'female:childcare'): 'F02', ('M3', 'female:leave'): 'F01', ('M3', 'female:leave_sq'): 'F01',
         ('M3', 'female:parttime'): 'F03', ('M4', 'female:childcare'): 'F05', ('M4', 'female:parttime'): 'F06',
         ('M4', 'female:leave'): 'F07', ('M4', 'female:leave_sq'): 'F07', ('M5', 'female:leave'): 'F08',
         ('M5', 'female:leave_sq'): 'F08', ('M6', 'female:leave'): 'F09', ('M6', 'female:leave_sq'): 'F09',
         ('M7', 'female:leave'): 'F10', ('M7', 'female:leave_sq'): 'F10', ('M8', 'female:childcare'): 'F11'}

org = pd.read_csv(os.path.join(S, 'runs/exec_v1/ORIGIN_A/results.csv'), dtype={'deleted_country': str})
org = org[org.run_id == 'ORIGIN']
inf = pd.concat([pd.read_csv(f, dtype={'deleted_country': str})
                 for f in sorted(glob.glob(os.path.join(S, 'runs/exec_v1/INF_A_M*/results.csv')))])
inf = inf[inf.deleted_country.notna() & (inf.run_id.str.lower() == 'influence')]
ts = pd.read_csv(os.path.join(S, 'scoring/final_v1/term_scores.csv'))

rows = []
for m in MODELS:
    for t in TERMS:
        o = org[(org.model == m) & (org.term == t)]
        p = ts[(ts.model == m) & (ts.term == t)]
        i_all = inf[(inf.model == m) & (inf.term == t)]
        i_ok = i_all[i_all.status == 'ok']
        n_del = inf[inf.model == m].drop_duplicates('deleted_country')
        rows.append(dict(
            row_id=f'{m}|{t}', model=m, term=t, claim=FOCAL.get((m, t), 'F12'),
            label=f'{MLAB[m]}: {TLAB[t]}',
            scale='linear coefficient, ln(employees+1)' if m == 'M5' else 'log-odds coefficient',
            published=p.pub_value.iloc[0] if len(p) else np.nan, published_printed=p.printed.iloc[0] if len(p) else '',
            published_se=p.pub_se.iloc[0] if len(p) else np.nan,
            reconstructed=o.estimate.iloc[0] if len(o) else np.nan, reconstructed_se=o.se.iloc[0] if len(o) else np.nan,
            reconstructed_p=o.p.iloc[0] if len(o) else np.nan, n_obs=o.n_obs.iloc[0] if len(o) else np.nan,
            n_countries=o.n_countries.iloc[0] if len(o) else np.nan,
            infl_fits=len(n_del), infl_ok=int((n_del.status == 'ok').sum()) if len(n_del) else 0,
            infl_failed=int((n_del.status != 'ok').sum()) if len(n_del) else 0,
            infl_min=i_ok.estimate.min(), infl_max=i_ok.estimate.max(),
            infl_p_min=i_ok.p.min(), infl_p_max=i_ok.p.max(),
            infl_p_zero=int((i_ok.p <= 0).sum()),
            argmin_country=i_ok.loc[i_ok.estimate.idxmin(), 'deleted_country'] if len(i_ok) else '',
            argmax_country=i_ok.loc[i_ok.estimate.idxmax(), 'deleted_country'] if len(i_ok) else '',
            source='GEM APS harmonized 1998-2012 (ICPSR 20320, user-supplied) + OECD/World Bank/ILO/UNDP country inputs; implementation A (R lme4, Laplace)'))
d = pd.DataFrame(rows)
d.to_csv(os.path.join(OUT, 'influence_figure.csv'), index=False)

PFLOOR = 1e-300
n = len(d)
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12, 0.36 * n + 2.4), sharey=True, gridspec_kw=dict(width_ratios=[1.35, 1]))
y = np.arange(n)[::-1]
for k, r in d.iterrows():
    yy = y[k]
    if np.isfinite(r.infl_min):
        a1.hlines(yy, r.infl_min, r.infl_max, color='#5b7fa6', lw=2.2, alpha=.8)
    a1.plot(r.reconstructed, yy, 'o', color='#1f3b5a', ms=5.5, zorder=3)
    if np.isfinite(r.published):
        a1.plot(r.published, yy, 'x', color='#c0392b', ms=7, mew=2, zorder=4)
    if np.isfinite(r.infl_p_min):
        a2.hlines(yy, max(r.infl_p_min, PFLOOR), r.infl_p_max, color='#5b7fa6', lw=2.2, alpha=.8)
    a2.plot(max(r.reconstructed_p, PFLOOR), yy, 'o', color='#1f3b5a', ms=5.5, zorder=3)
for ax in (a1, a2):
    for b in range(1, len(MODELS)):
        ax.axhline(y[4 * b] + .5, color='#bbbbbb', lw=.6)
a1.axvline(0, color='black', lw=.8)
a1.set_yticks(y); a1.set_yticklabels([f"{r.label}  [{r.claim}]" for _, r in d.iterrows()], fontsize=8)
a1.set_xlabel('Coefficient, null = 0\n(log-odds; M5 linear on ln(employees+1); leave terms on z(leave), z(leave)$^2$ basis)', fontsize=9)
a1.set_title('Published (x), reconstructed (dot),\nleave-one-country-out range (line)', fontsize=9.5)
a2.set_xscale('log'); a2.axvline(.05, color='#c0392b', ls='--', lw=1)
a2.set_xlabel('Two-sided Wald p, model-based SE (log scale)\ndashed line: p = .05', fontsize=9)
a2.set_title('Reconstructed p (dot),\nleave-one-country-out p range (line)', fontsize=9.5)
a2.invert_xaxis()
fig.text(.01, .005, 'Lines are influence ranges over leave-one-country-out refits (implementation A), not confidence intervals. '
         'They are not part of any equivalent-specification set. Full caption in reports/replication_report.md.', fontsize=7.5)
fig.tight_layout(rect=(0, .02, 1, 1))
fig.savefig(os.path.join(OUT, 'influence_figure.svg')); fig.savefig(os.path.join(OUT, 'influence_figure.png'), dpi=200)
print(d[['row_id', 'published', 'reconstructed', 'infl_min', 'infl_max', 'infl_ok', 'infl_failed']].to_string())
