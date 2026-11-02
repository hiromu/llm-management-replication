"""Synthetic rule tests for score.py (no real data)."""
import json, os, sys, tempfile, shutil
import numpy as np, pandas as pd
sys.path.insert(0, os.path.dirname(__file__))
import score as S
from scipy import stats

T = json.load(open(os.path.join(os.path.dirname(__file__), '..', 'sealed', 'targets_frozen_v1.json')))

def p_from(est, se, df=500):
    t = est / se
    return 1 - stats.t.cdf(t, df), stats.t.cdf(t, df)

def make_impl(d, mutate=lambda cell, spec, est, se: (est, se), n=(590, 373), specs=('O', 'D01', 'D02')):
    os.makedirs(d, exist_ok=True)
    co, ms, nt, sa = [], [], [], []
    for spec in specs:
        for fam, nn in zip(('org', 'mkt'), n):
            for i in range(nn): sa.append(dict(spec_id=spec, family=fam, model_id='ALL', V1=i + 1))
        models = set()
        for c in T['cells']:
            mid = c['model_id']
            if c['quantity'] == 'coef':
                model = mid + '_' + c['term'] if mid in ('org_M1', 'mkt_M6') else mid
                models.add(model)
                est, se = mutate(c, spec, c['value'], c['se'] or 0.05)
                pu, pl = p_from(est, se)
                co.append(dict(spec_id=spec, family=S.FAMILY_OF(mid), model_id=model, term=c['term'], estimate=est, se=se, p_upper=pu, p_lower=pl,
                               p_upper_hc3=pu, p_lower_hc3=pl))
            elif c['quantity'] == 'F_deltaR2':
                stars = c['stars']; p = {'**': .001, '*': .03, '†': .07, '': .5}[stars]
                if mutate(c, spec, 1.0, 1.0) == ('F_SIG', None): p = .001
                nt.append(dict(spec_id=spec, family=S.FAMILY_OF(mid), test_id='t', full_model=mid, restricted_model='r', n=0, delta_r2=0.01, f=c['value'], df1=3, df2=500, p=p))
        for m in models | {'org_M2', 'mkt_M7'}:
            fam = S.FAMILY_OF(m)
            ms.append(dict(spec_id=spec, family=fam, model_id=m, status='ok', n=n[0] if fam == 'org' else n[1], r2=.2, f=2.5, f_p=.001))
    pd.DataFrame(co).to_csv(os.path.join(d, 'coefficients.csv'), index=False)
    pd.DataFrame(ms).to_csv(os.path.join(d, 'model_stats.csv'), index=False)
    pd.DataFrame(nt).to_csv(os.path.join(d, 'nested_tests.csv'), index=False)
    pd.DataFrame(sa).to_csv(os.path.join(d, 'samples.csv'), index=False)

def run(tmp, **kw):
    for k in 'ABC': make_impl(os.path.join(tmp, k), **kw)
    impls = {k: S.load_impl(os.path.join(tmp, k)) for k in 'ABC'}
    specs = ['O', 'D01', 'D02']
    cells = S.score_cells(impls['A'], T, specs, {'org': kw.get('n', (590, 373))[0], 'mkt': kw.get('n', (590, 373))[1]})
    return cells, S.aggregate(cells), S.pair_agree(impls['A'], impls['B'], 'O')

def check(name, cond):
    print(('PASS ' if cond else 'FAIL ') + name); return cond

ok = True
tmp = tempfile.mkdtemp()
try:
    # 1 exact reproduction of printed values -> consistent, implementations agree
    cells, agg, pa = run(os.path.join(tmp, 't1'))
    ok &= check('pair agreement on identical outputs', pa['agree'])
    ok &= check('exact reproduction: H1 consistent', agg['H1']['outcome'] == 'consistent')
    ok &= check('exact reproduction: H2 consistent', agg['H2']['outcome'] == 'consistent')
    # 2 sign flip of all HRM cells at all specs -> H1 discrepant candidate
    flip = lambda c, s, e, se: ((-abs(e) - 3 * se, se) if c['quantity'] == 'coef' and c['term'] in S.HRM else (e, se))
    cells, agg, _ = run(os.path.join(tmp, 't2'), mutate=flip)
    ok &= check('sign flip everywhere: H1 discrepant candidate', agg['H1']['outcome'].startswith('discrepant'))
    # 3 sign flip at origin only -> label_sensitive indeterminate
    flip_o = lambda c, s, e, se: ((-abs(e) - 3 * se, se) if s == 'O' and c['quantity'] == 'coef' and c['term'] in S.HRM else (e, se))
    cells, agg, _ = run(os.path.join(tmp, 't3'), mutate=flip_o)
    ok &= check('flip at origin only: H1 indeterminate label_sensitive', agg['H1']['outcome'] == 'indeterminate' and 'label_sensitive' in agg['H1']['reason'])
    # 4 N mismatch -> indeterminate sample_reconstruction
    cells, agg, _ = run(os.path.join(tmp, 't4'), n=(650, 400))
    ok &= check('N mismatch: H1 indeterminate sample_reconstruction', agg['H1']['outcome'] == 'indeterminate' and 'sample_reconstruction' in agg['H1']['reason'])
    # 5 adjacent band weakening only (magnitude within 1 SE) -> consistent
    adj = lambda c, s, e, se: ((e - 0.6 * se, se) if c['quantity'] == 'coef' and c['term'] in S.HRM else (e, se))
    cells, agg, _ = run(os.path.join(tmp, 't5'), mutate=adj)
    prim = cells[cells.apply(lambda r: r.quantity == 'coef' and r.model_id in ('org_M2','org_M3','mkt_M7','mkt_M8') and r.term in S.HRM and r.value > 0 and (r.stars or '') != '', axis=1)]
    ok &= check('ten H1 primary cells identified', len(prim) == 10)
    # 6 newly significant interaction F everywhere -> H2 discrepant
    fsig = lambda c, s, e, se: ('F_SIG', None) if c['quantity'] == 'F_deltaR2' and c['model_id'] in ('org_M4','org_M5','mkt_M9','mkt_M10') and e == 1.0 else (e, se)
    cells, agg, _ = run(os.path.join(tmp, 't6'), mutate=fsig)
    ok &= check('interaction F newly p<.01 everywhere: H2 discrepant', agg['H2']['outcome'].startswith('discrepant'))
    # 7 band function and magnitude
    ok &= check('band edges', [S.band(x) for x in (.009, .01, .049, .05, .099, .1)] == [0, 1, 1, 2, 2, 3])
    c = dict(quantity='coef', term='TRAIN', value=0.125, se=0.041, stars='**', model_id='org_M2')
    r = S.criteria(c, dict(est=0.125 + 2.5 * 0.041, se=.04, p_upper=.001, p_lower=.999))
    ok &= check('magnitude > 2 SE flags discrepancy', r['discrepant'] and r['m'] > 2)
    r = S.criteria(c, dict(est=0.125 + 1.5 * 0.041, se=.04, p_upper=.001, p_lower=.999))
    ok &= check('magnitude 1.5 SE stronger is not discrepant', not r['discrepant'])
    c2 = dict(quantity='coef', term='STAFF', value=0.015, se=0.038, stars='', model_id='org_M2')
    r = S.criteria(c2, dict(est=0.09, se=.038, p_upper=.009, p_lower=.991))
    ok &= check('newly significant p<.01 contradicts non-significance', r['d'] == 3 and r['discrepant'])
finally:
    shutil.rmtree(tmp)
print('ALL PASS' if ok else 'SOME FAILED'); sys.exit(0 if ok else 1)
