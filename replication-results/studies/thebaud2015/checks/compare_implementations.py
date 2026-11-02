"""Compare implementations' results.csv files under the frozen implementation-agreement rule.

Usage: python compare_implementations.py <out_csv> <label>=<results.csv> [<label>=<results.csv> ...]
Compares sample identity (hash, n_obs, countries, surveys) per (run_id, model, deleted_country) and
estimates/SEs per term. No published target is read here.
"""
import sys, itertools
import pandas as pd

out = sys.argv[1]
res = {}
for a in sys.argv[2:]:
    k, p = a.split('=', 1)
    d = pd.read_csv(p, dtype={'deleted_country': str})
    d['deleted_country'] = d['deleted_country'].fillna('')
    res[k] = d

KEY = ['run_id', 'model', 'deleted_country']
rows = []
for (x, y) in itertools.combinations(sorted(res), 2):
    dx, dy = res[x], res[y]
    sx = dx.groupby(KEY).agg(hash=('sample_hash', 'first'), n=('n_obs', 'first'), nc=('n_countries', 'first'), ns=('n_surveys', 'first')).reset_index()
    sy = dy.groupby(KEY).agg(hash=('sample_hash', 'first'), n=('n_obs', 'first'), nc=('n_countries', 'first'), ns=('n_surveys', 'first')).reset_index()
    sm = sx.merge(sy, on=KEY, suffixes=('_x', '_y'))
    tm = dx[KEY + ['term', 'estimate', 'se', 'p', 'status']].merge(dy[KEY + ['term', 'estimate', 'se', 'p', 'status']], on=KEY + ['term'], suffixes=('_x', '_y'))
    tm = tm[tm.term.notna()]
    for _, r in tm.iterrows():
        s = sm[(sm.run_id == r.run_id) & (sm.model == r.model) & (sm.deleted_country == r.deleted_country)]
        same_sample = bool(len(s)) and s.iloc[0].hash_x == s.iloc[0].hash_y
        # Implementation B sorts IDs as strings before hashing; A and C sort numerically (manifest was silent).
        # For pairs with B, sample identity is established by equal n_obs, n_countries and n_surveys (decision before execution).
        if bool(len(s)) and not same_sample and 'B' in (x, y):
            q = s.iloc[0]
            same_sample = (q.n_x == q.n_y) and (q.nc_x == q.nc_y) and (q.ns_x == q.ns_y)
        both_ok = r.status_x == 'ok' and r.status_y == 'ok'
        if both_ok:
            mse = max(r.se_x, r.se_y)
            est_ok = abs(r.estimate_x - r.estimate_y) <= max(0.05 * mse, 0.001)
            se_ok = abs(r.se_x - r.se_y) / mse <= 0.05 if mse > 0 else r.se_x == r.se_y
        else:
            est_ok = se_ok = None
        rows.append(dict(pair=f'{x}-{y}', run_id=r.run_id, model=r.model, deleted_country=r.deleted_country, term=r.term,
                         same_sample=same_sample, n_x=s.iloc[0].n_x if len(s) else None, n_y=s.iloc[0].n_y if len(s) else None,
                         est_x=r.estimate_x, est_y=r.estimate_y, se_x=r.se_x, se_y=r.se_y, status_x=r.status_x, status_y=r.status_y,
                         estimate_agree=est_ok, se_agree=se_ok,
                         agree=bool(same_sample and est_ok and se_ok) if both_ok else False))
df = pd.DataFrame(rows)
df.to_csv(out, index=False)
summ = df.groupby('pair').agg(terms=('agree', 'size'), agree=('agree', 'sum'), same_sample=('same_sample', 'mean'))
print(summ.to_string())
