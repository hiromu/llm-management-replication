"""Leave-one-camp-out influence summary for the eight T4 origin models (frozen scope: A all camps; B, C first 20 camps)."""
import json, os, re
import numpy as np, pandas as pd
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
RUNS = json.load(open(f'{ROOT}/scoring/scored_runs.json'))
import sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare_implementations import model_key
inf = {}
for k, p in RUNS.items():
    d = pd.read_csv(f'{ROOT}/{p}/results/influence.csv', dtype={'deleted_camp': str})
    d['mkey'] = d.model_id.map(model_key); d['impl'] = k
    d['camp'] = d.deleted_camp.astype(str).str.strip()
    inf[k] = d
A = inf['A']
rows = []
for mk, g in A.groupby('mkey'):
    ok = g[g.status.astype(str).str.lower() == 'ok']
    rows.append({'model_key': mk, 'deletions_attempted': len(g), 'deletions_ok': len(ok), 'deletions_failed': len(g) - len(ok),
                 'me_min': ok.me.min(), 'me_max': ok.me.max(), 'p_min': ok.me_p.min(), 'p_max': ok.me_p.max(),
                 'camp_at_me_max': ok.loc[ok.me.idxmax(), 'camp'], 'camp_at_p_max': ok.loc[ok.me_p.idxmax(), 'camp'],
                 'share_negative': (ok.me < 0).mean(), 'share_p05': (ok.me_p < 0.05).mean(), 'share_p10': (ok.me_p < 0.10).mean()})
s = pd.DataFrame(rows)
# cross-check: same deletions in B and C versus A
chk = []
for k in ['B', 'C']:
    if k not in inf: continue
    m = inf[k].merge(A, on=['mkey', 'camp'], suffixes=('', '_A'))
    d = (m.me - m.me_A).abs()
    chk.append({'impl': k, 'matched_deletions': len(m), 'max_abs_me_diff_vs_A': d.max(), 'within_tol': int(((d <= 5e-4) | (d / m.me_A.abs() <= 1e-3)).sum())})
s.to_csv(f'{ROOT}/scoring/influence_summary.csv', index=False)
json.dump(chk, open(f'{ROOT}/scoring/influence_crosscheck.json', 'w'), indent=2, default=float)
print(s.round(4).to_string()); print(chk)
