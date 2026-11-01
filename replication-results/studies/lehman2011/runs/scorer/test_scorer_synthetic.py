"""Synthetic rule tests for score_v1.py (planted errors, null data, unreachable target, implementation disagreement,
label-sensitive rescue). Builds fake implementation outputs from the sealed targets; no empirical data involved.

Usage: test_scorer_synthetic.py <study_root> <scratch_dir>
"""
import json, math, os, sys, shutil, copy
import pandas as pd
sys.path.insert(0, os.path.dirname(__file__))
import score_v1 as S

ROOT, TMP = sys.argv[1], sys.argv[2]
T = json.load(open(os.path.join(ROOT, 'sealed/targets_reconciled_v1.json')))['targets']
P_OF_BAND = {1: 0.001, 2: 0.03, 3: 0.07, 4: 0.5}
ALT = 'U1=1|U2=0|U3=0|U4=0|U5=0|U6=0|U7=0|U8=0'


def build(case):
    rows_s, rows_c, rows_m = [], [], []
    cells = [S.ORIGIN, S.ORIGIN.replace('U7=0', 'U7=1'), ALT, ALT.replace('U7=0', 'U7=1')]
    for cell in cells:
        for m in ('M1', 'M2', 'M3'):
            sid = f'{m}|{cell}'
            rows_s.append(dict(spec_id=sid, model=m, status='ok', sample_hash='h0', n_obs=case.get('n', S.PUB_N), loglik=-1000.0))
            for k, t in T.items():
                p = k.split('|')
                if p[0] == 'T5' and p[1] == m and t['quantity'] == 'odds_ratio':
                    b = math.log(float(t['value']))
                    pv = P_OF_BAND[S.BAND_FROM_STARS[S.norm_stars(t['stars'])]]
                    if case.get('null'):
                        b, pv = 0.0, 0.9
                    if case.get('plant') == k and cell in case.get('plant_cells', [S.ORIGIN, S.ORIGIN.replace('U7=0', 'U7=1')]):
                        se_up = (float(t['published_se']) + 0.0005) / (float(t['value']) - 0.0005)
                        b += 5 * se_up
                    if case.get('drop') == k and cell == S.ORIGIN:
                        continue
                    rows_c.append(dict(spec_id=sid, model=m, term=p[2], estimate=b, se_native=0.01, p_native=pv,
                                       p_bench=pv if 'U7=1' in cell else float('nan')))
            for k, t in T.items():
                p = k.split('|')
                if p[0] != 'T6':
                    continue
                mm = 'M2' if p[1] == 'all' else 'M3'
                if mm != m:
                    continue
                v = 0.0 if case.get('null') else float(t['value'])
                pv = 0.9 if case.get('null') else P_OF_BAND[S.BAND_FROM_STARS[S.norm_stars(t['stars'])]]
                rows_m.append(dict(spec_id=sid, model=m, variant='ME0', minutes_eval=S.Q_MIN.get(p[1], 30.0),
                                   d=int(p[2].replace('gap', '')), effect=v, p_native=pv, p_bench=pv if 'U7=1' in cell else float('nan')))
    return pd.DataFrame(rows_s), pd.DataFrame(rows_c), pd.DataFrame(rows_m)


def run(name, case, disagree=False):
    d = os.path.join(TMP, name)
    shutil.rmtree(d, ignore_errors=True)
    for w in 'ABC':
        s, c, m = build(case)
        if disagree and w != 'A':
            c = c.copy(); c['estimate'] = c['estimate'] + (0.1 if w == 'B' else 0.2)
        os.makedirs(os.path.join(d, 'run', w, 'results'))
        for nm, df in (('specs', s), ('coefs', c), ('margins', m)):
            df.to_csv(os.path.join(d, 'run', w, 'results', f'{nm}.csv'), index=False)
    return S.main(ROOT, os.path.join(d, 'run'), os.path.join(d, 'out'))


results = {}
def check(name, rec, expect):
    got = {h: rec['claims'][h]['outcome'] for h in expect['claims']} if 'claims' in expect else {}
    ok = all(got[h] == v for h, v in expect.get('claims', {}).items())
    if 'paper' in expect:
        ok = ok and rec['paper']['outcome'] == expect['paper']
    if 'sub' in expect:
        ok = ok and all(rec['claims'][h].get('sub_code') == v for h, v in expect['sub'].items())
    results[name] = {'pass': ok, 'claims': {h: (c['outcome'], c.get('sub_code')) for h, c in rec['claims'].items()}, 'paper': rec['paper']}

check('exact_match', run('exact', {}), {'claims': {h: 'consistent' for h in S.CLAIMS}, 'paper': 'consistent'})
check('planted_error_H2', run('plant', {'plant': 'T5|M3|perf_below_x_min', 'plant_cells': None or []}),
      {'claims': {'H2': 'consistent'}})  # plant_cells=[] -> nothing planted: control
check('planted_error_H2_all_cells', run('plant_all', {'plant': 'T5|M3|perf_below_x_min',
      'plant_cells': [S.ORIGIN, S.ORIGIN.replace('U7=0', 'U7=1'), ALT, ALT.replace('U7=0', 'U7=1')]}),
      {'claims': {'H2': 'discrepant_candidate', 'H1A': 'consistent', 'H3': 'consistent'}, 'paper': 'indeterminate'})
check('planted_error_origin_only_rescued', run('plant_origin', {'plant': 'T5|M3|perf_below_x_min'}),
      {'claims': {'H2': 'indeterminate'}, 'sub': {'H2': 'label_sensitive'}})
check('null_data', run('null', {'null': True}), {'claims': {'H1A': 'discrepant_candidate', 'H2': 'discrepant_candidate'}})
check('unreachable_target', run('drop', {'drop': 'T5|M2|perf_above'}), {'claims': {'H1B': 'indeterminate'}, 'sub': {'H1B': 'unavailable_criterion'}})
check('implementation_disagreement', run('disagree', {}, disagree=True), {'claims': {h: 'indeterminate' for h in S.CLAIMS}})
check('large_N_gap', run('bigN', {'n': 20000, 'plant': 'T5|M3|perf_above_x_min',
      'plant_cells': [S.ORIGIN, S.ORIGIN.replace('U7=0', 'U7=1'), ALT, ALT.replace('U7=0', 'U7=1')]}),
      {'claims': {'H3': 'indeterminate'}, 'sub': {'H3': 'source_vintage'}})
json.dump(results, open(os.path.join(ROOT, 'runs/scorer/synthetic_test_results_v1.json'), 'w'), indent=1, default=str)
for k, v in results.items():
    print(('PASS ' if v['pass'] else 'FAIL ') + k, v['claims'], v['paper'].get('outcome'))
