"""Implementation agreement (scoring_rules_v1 implementation_agreement), run before any target comparison.

Usage: compare_implementations.py <run_dir> <out_json>
"""
import json, sys, os, itertools
import numpy as np, pandas as pd

RUN, OUT = sys.argv[1], sys.argv[2]
impl = {}
for w in 'ABC':
    d = os.path.join(RUN, w, 'results')
    if os.path.exists(os.path.join(d, 'specs.csv')):
        impl[w] = {k: pd.read_csv(os.path.join(d, f'{k}.csv')) for k in ('specs', 'coefs', 'margins')}
        if os.path.exists(os.path.join(d, 'influence.csv')):
            impl[w]['influence'] = pd.read_csv(os.path.join(d, 'influence.csv'))


def first(df, keys):
    return df.drop_duplicates(subset=keys, keep='first').set_index(keys)


report = {'implementations_present': sorted(impl)}
for a, b in itertools.combinations(sorted(impl), 2):
    A, B = impl[a], impl[b]
    sa, sb = first(A['specs'], ['spec_id']), first(B['specs'], ['spec_id'])
    common = sa.index.intersection(sb.index)
    s = sa.loc[common].join(sb.loc[common], lsuffix='_a', rsuffix='_b')
    origin_ids = [f'M{k}|U1=0|U2=0|U3=0|U4=0|U5=0|U6=0|U7=0|U8=0' for k in (1, 2, 3)]
    ca = first(A['coefs'], ['spec_id', 'term']); cb = first(B['coefs'], ['spec_id', 'term'])
    cc = ca.join(cb, lsuffix='_a', rsuffix='_b', how='inner')
    cc['db'] = (cc.estimate_a - cc.estimate_b).abs()
    cc['tol_b'] = np.maximum(1e-4 * cc.estimate_a.abs(), 1e-5)
    cc['dse'] = (cc.se_native_a - cc.se_native_b).abs()
    cc['tol_se'] = 1e-3 * cc.se_native_a.abs() + 1e-7
    has_bench = cc.se_bench_a.notna() & cc.se_bench_b.notna()
    cc['dsebench_rel'] = ((cc.se_bench_a - cc.se_bench_b).abs() / cc.se_bench_a.abs()).where(has_bench)
    ma = A['margins']; mb = B['margins']
    key = ['spec_id', 'variant', 'minutes_eval', 'd']
    for m in (ma, mb):
        m['minutes_eval'] = m['minutes_eval'].round(6)
    mm = first(ma, key).join(first(mb, key), lsuffix='_a', rsuffix='_b', how='inner')
    mm['de'] = (mm.effect_a - mm.effect_b).abs()
    mm['tol_e'] = np.maximum(1e-3 * mm.effect_a.abs(), 1e-7)
    orig = cc.loc[cc.index.get_level_values(0).isin(origin_ids)]
    morig = mm.loc[mm.index.get_level_values(0).isin(origin_ids) & (mm.index.get_level_values(1) == 'ME0')]
    so = s.loc[s.index.intersection(origin_ids)]
    rec = {
        'specs_common': int(len(common)),
        'sample_hash_equal_all_common': bool((s.sample_hash_a == s.sample_hash_b).all()),
        'n_obs_equal_all_common': bool((s.n_obs_a == s.n_obs_b).all()),
        'origin': {
            'sample_hash_equal': bool((so.sample_hash_a == so.sample_hash_b).all()),
            'loglik_max_absdiff': float((so.loglik_a - so.loglik_b).abs().max()),
            'coef_within_tol': f'{int((orig.db <= orig.tol_b).sum())}/{len(orig)}',
            'coef_max_absdiff': float(orig.db.max()),
            'se_within_tol': f'{int((orig.dse <= orig.tol_se).sum())}/{len(orig)}',
            'se_max_reldiff': float((orig.dse / orig.se_native_a.abs()).max()),
            'me0_within_tol': f'{int((morig.de <= morig.tol_e).sum())}/{len(morig)}',
            'me0_max_absdiff': float(morig.de.max()) if len(morig) else None,
        },
        'grid': {
            'coef_within_tol': f'{int((cc.db <= cc.tol_b).sum())}/{len(cc)}',
            'coef_max_absdiff': float(cc.db.max()),
            'se_within_tol': f'{int((cc.dse <= cc.tol_se).sum())}/{len(cc)}',
            'loglik_max_absdiff': float((s.loglik_a - s.loglik_b).abs().max()),
            'bench_se_max_reldiff': float(cc.dsebench_rel.max()) if has_bench.any() else None,
            'margins_within_tol': f'{int((mm.de <= mm.tol_e).sum())}/{len(mm)}',
            'margins_max_absdiff': float(mm.de.max()),
            'worst_coef_rows': [dict(spec=i[0], term=i[1], a=r.estimate_a, b=r.estimate_b)
                                for i, r in cc.sort_values('db', ascending=False).head(5).iterrows()],
        },
    }
    if 'influence' in A and 'influence' in B:
        ik = ['unit_type', 'unit_id', 'model', 'term']
        ia = first(A['influence'], ik); ib = first(B['influence'], ik)
        ii = ia.join(ib, lsuffix='_a', rsuffix='_b', how='inner')
        dd = (ii.estimate_a - ii.estimate_b).abs()
        rec['influence'] = {'common_rows': int(len(ii)), 'unit_types': sorted(set(ii.index.get_level_values(0))),
                            'estimate_within_tol': f'{int((dd <= np.maximum(1e-4 * ii.estimate_a.abs(), 1e-5)).sum())}/{len(ii)}',
                            'max_absdiff': float(dd.max())}
    report[a + b] = rec
json.dump(report, open(OUT, 'w'), indent=1, default=str)
print(json.dumps(report, indent=1, default=str))
