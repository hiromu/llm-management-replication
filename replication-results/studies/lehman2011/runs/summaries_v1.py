"""Post-scoring summaries from frozen outputs (implementation A, verified against B and C).

Usage: summaries_v1.py <study_root>
Writes runs/score_v1/{uncertain_set_summary.csv, me_variant_comparison.csv, n_branch_evaluation.json,
nonequivalent_summary.csv, algebraic_checks.json, influence_summary.csv}
"""
import json, math, os, sys
import numpy as np, pandas as pd
sys.path.insert(0, os.path.join(sys.argv[1], 'runs/scorer'))
import score_v1 as S

ROOT = sys.argv[1]
RUN = os.path.join(ROOT, 'runs/exec_v1')
OUT = os.path.join(ROOT, 'runs/score_v1')
T = json.load(open(os.path.join(ROOT, 'sealed/targets_reconciled_v1.json')))['targets']
A = S.load_impl(RUN, 'A')
C_inf = pd.read_csv(os.path.join(RUN, 'C/results/influence.csv'))
A_inf = pd.read_csv(os.path.join(RUN, 'A/results/influence.csv'))

# 1. uncertain set: all grid cells other than the origin (U8=0), focal primary coefficients
cmp_all = pd.read_csv(os.path.join(OUT, 'target_comparisons_all_cells.csv'))
prim = [k for c in S.CLAIMS.values() for k in c['primary']]
rows = []
for k in prim:
    sub = cmp_all[(cmp_all.key == k) & (cmp_all.cell != S.ORIGIN)]
    est = sub.reconstructed.astype(float)
    pub = math.log(T[k]['value'] if isinstance(T[k]['value'], float) else float(T[k]['value']))
    rows.append(dict(target=k, n_cells=len(sub), sign_agree_share=float((np.sign(est) == np.sign(pub)).mean()),
                     sig05_share=float((sub.p_native < .05).mean()), median=float(est.median()), min=float(est.min()),
                     max=float(est.max()), published_logOR=pub,
                     published_percentile=float((est < pub).mean()),
                     outcome_counts=json.dumps(sub.outcome.value_counts().to_dict()),
                     by_U7=json.dumps({u: sub[sub.cell.str.contains(f'U7={u}')].outcome.value_counts().to_dict() for u in (0, 1, 2)})))
pd.DataFrame(rows).to_csv(os.path.join(OUT, 'uncertain_set_summary.csv'), index=False)

# 2. marginal-effect variants (prespecified uncertain readings), origin cell, same criteria
m = A['margins']
recs = []
for k, t in T.items():
    if not k.startswith('T6|'):
        continue
    q, d = k.split('|')[1], int(k.split('|')[2].replace('gap', ''))
    model = 'M2' if q == 'all' else 'M3'
    for var in ('ME0', 'U9a', 'U9b', 'U10a', 'N3'):
        g = m[(m.spec_id == f'{model}|{S.ORIGIN}') & (m.variant == var) & (m.d == d)]
        if model == 'M3':
            g = g[(g.minutes_eval - S.Q_MIN[q]).abs() < 1e-9]
        if len(g) != 1:
            continue
        g = g.iloc[0]
        r = S.compare_target(t, float(g.effect), float(g.p_native))
        recs.append(dict(key=k, variant=var, pub=t['value'], pub_se=t['published_se'], pub_stars=t['stars'],
                         rec=g.effect, prob=g.get('prob'), p=g.p_native, sign=r.get('sign'), inference=r.get('inference'),
                         delta_se=r.get('delta_se'), outcome=r['outcome']))
me = pd.DataFrame(recs)
me.to_csv(os.path.join(OUT, 'me_variant_comparison.csv'), index=False)
me_summary = me.groupby('variant').outcome.value_counts().unstack(fill_value=0)

# 3. N branch by code
flow = pd.read_csv(os.path.join(RUN, 'C/results/sample_flow.csv'))
nb = {}
for w in ('fable', 'astra'):
    nb[w] = json.load(open(os.path.join(ROOT, f'readers/{w}/run1/out/sealed_N_branch.json')))
origin_hash = A['specs'][A['specs'].spec_id == f'M2|{S.ORIGIN}'].iloc[0].sample_hash
nflow = {}
for _, r in flow.iterrows():
    if str(r.get('sample_hash', '')) == origin_hash or r.get('cell', '') == S.ORIGIN:
        nflow[str(r.step)] = int(r.rows)
pub = {'original_fourth_down_decisions': 23965, 'removed_last_two_minutes': 1362, 'analysis_N': 22603, 'games': 1520}
nbe = {'published_sealed': pub, 'reconstructed_origin_flow': nflow,
       'pre_two_minute_rows (S4)': nflow.get('S4'), 'removed_by_S5': (nflow.get('S4') or 0) - (nflow.get('S5') or 0),
       'analysis_N': nflow.get('S8'),
       'rel_diff_pre_two_minute': None if not nflow.get('S4') else (nflow['S4'] - pub['original_fourth_down_decisions']) / pub['original_fourth_down_decisions'],
       'rel_diff_removed': None if not nflow.get('S4') else ((nflow['S4'] - nflow['S5']) - pub['removed_last_two_minutes']) / pub['removed_last_two_minutes'],
       'rel_diff_analysis_N': None if not nflow.get('S8') else (nflow['S8'] - pub['analysis_N']) / pub['analysis_N'],
       'games_in_sample': int(A_inf[A_inf.unit_type == 'game'].unit_id.nunique()), 'games_published': pub['games'],
       'games_missing_from_source': ['2000_03_SD_KC', '2000_06_BUF_MIA'],
       'reader_N_branch_files': ['readers/fable/run1/out/sealed_N_branch.json', 'readers/astra/run1/out/sealed_N_branch.json']}
json.dump(nbe, open(os.path.join(OUT, 'n_branch_evaluation.json'), 'w'), indent=1, default=str)

# 4. non-equivalent runs, algebraic checks
ne = pd.read_csv(os.path.join(RUN, 'C/results/nonequiv.csv'))
ne.to_csv(os.path.join(OUT, 'nonequivalent_C.csv'), index=False)
ak = pd.read_csv(os.path.join(RUN, 'C/results/algebraic_checks.csv'))
ak.to_csv(os.path.join(OUT, 'algebraic_checks_C.csv'), index=False)

# 5. influence summary (game: A and C agree; team, season: all three)
foc = ['perf_below', 'perf_below_sq', 'perf_above', 'below_indicator', 'perf_below_x_min', 'perf_below_sq_x_min', 'perf_above_x_min']
inf = C_inf[C_inf.term.isin(foc)]
orig = A['coefs'][A['coefs'].spec_id.isin([f'M2|{S.ORIGIN}', f'M3|{S.ORIGIN}'])]
irows = []
for (u, mod, term), g in inf.groupby(['unit_type', 'model', 'term']):
    o = orig[(orig.spec_id == f'{mod}|{S.ORIGIN}') & (orig.term == term)]
    if not len(o):
        continue
    o = o.iloc[0]
    ok = g[g.status == 'ok']
    irows.append(dict(unit_type=u, model=mod, term=term, n_units=len(g), n_failed=int((g.status != 'ok').sum()),
                      origin=o.estimate, origin_p=o.p_native, min=ok.estimate.min(), max=ok.estimate.max(),
                      sign_changes=int((np.sign(ok.estimate) != np.sign(o.estimate)).sum()),
                      p_min=ok.p_native.min(), p_max=ok.p_native.max(),
                      n_p_ge_05=int((ok.p_native >= .05).sum()), n_pbench_ge_05=int((ok.p_bench >= .05).sum())))
pd.DataFrame(irows).to_csv(os.path.join(OUT, 'influence_summary.csv'), index=False)

print(pd.DataFrame(rows)[['target', 'n_cells', 'sign_agree_share', 'sig05_share', 'median', 'min', 'max', 'published_logOR', 'outcome_counts']].to_string())
print(me_summary.to_string())
print(json.dumps(nbe, indent=1, default=str)[:1500])
print(pd.DataFrame(irows).to_string())
