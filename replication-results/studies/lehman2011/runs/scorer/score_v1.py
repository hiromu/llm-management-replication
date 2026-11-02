"""Deterministic scorer implementing reconciliation/scoring_rules_v1.json.

Usage:
  score_v1.py <study_root> <run_dir> <out_dir>
run_dir contains A/results, B/results, C/results (frozen execution outputs).
"""
import json, math, sys, os, itertools
import pandas as pd

PUB_N = 22603  # sealed N branch (both readers); used only here, downstream of implementation
BAND_FROM_STARS = {'**': 1, '*': 2, '+': 3, 'none': 4}
Q_MIN = {'q1': 53, 'q2': 38, 'q3': 23, 'q4': 8}
ORIGIN = 'U1=0|U2=0|U3=0|U4=0|U5=0|U6=0|U7=0|U8=0'
CLAIMS = {
    'H1A': {'primary': ['T5|M2|perf_below', 'T5|M2|perf_below_sq'], 'model': 'M2', 'side': 'below', 'quarters': ['all']},
    'H1B': {'primary': ['T5|M2|perf_above'], 'model': 'M2', 'side': 'above', 'quarters': ['all']},
    'H2': {'primary': ['T5|M3|perf_below_x_min', 'T5|M3|perf_below_sq_x_min'], 'model': 'M3', 'side': 'below', 'quarters': ['q1', 'q2', 'q3', 'q4']},
    'H3': {'primary': ['T5|M3|perf_above_x_min'], 'model': 'M3', 'side': 'above', 'quarters': ['q1', 'q2', 'q3', 'q4']},
}
FOCAL_TERMS = {'perf_below', 'perf_below_sq', 'perf_above', 'below_indicator',
               'perf_below_x_min', 'perf_below_sq_x_min', 'perf_above_x_min'}


def band(p):
    if p is None or (isinstance(p, float) and math.isnan(p)):
        return None
    return 1 if p < .01 else 2 if p < .05 else 3 if p < .10 else 4


def norm_stars(s):
    s = (s or 'none').strip()
    return s if s in BAND_FROM_STARS else 'none'


def compare_target(t, est, p_native, p_bench=None):
    """t: reconciled target record; est: reconstructed estimate on the comparison scale (log-odds or probability)."""
    v = float(t['value'])
    se = t['published_se']
    if t['quantity'] == 'odds_ratio':
        lo, hi = math.log(v - 0.0005), math.log(v + 0.0005)
        se_up = None if se is None else (float(se) + 0.0005) / (v - 0.0005)
        pub_point = math.log(v)
        low_res = se is not None and float(se) == 0.0
    else:
        lo, hi = v - 0.00005, v + 0.00005
        se_up = None if se is None else float(se) + 0.00005
        pub_point = v
        low_res = se is not None and float(se) == 0.0
    rec = {'pub_value': v, 'pub_se': se, 'pub_stars': norm_stars(t['stars']), 'pub_interval': [lo, hi],
           'reconstructed': est, 'p_native': p_native, 'p_bench': p_bench, 'low_resolution_se': low_res}
    if est is None or (isinstance(est, float) and math.isnan(est)):
        rec.update(outcome='not_assessable', reason='missing reconstruction')
        return rec
    # sign
    assessable = lo > 0 or hi < 0
    sign_mismatch = assessable and ((lo > 0 and est < 0) or (hi < 0 and est > 0))
    rec['sign'] = 'not_assessable' if not assessable else ('mismatch' if sign_mismatch else 'ok')
    # inference
    pb = BAND_FROM_STARS[rec['pub_stars']]
    rb = band(p_native)
    diff = None if rb is None else rb - pb
    if rb is None:
        inf = 'not_assessable'
    elif pb <= 3:
        inf = 'discrepant_candidate' if diff >= 2 else 'consistent'
    else:
        inf = 'discrepant_candidate' if abs(diff) >= 2 else 'consistent'
    rec.update(pub_band=pb, rec_band=rb, band_diff=diff, inference=inf)
    bb = band(p_bench)
    rec['bench_band'] = bb
    rec['fragile_inference'] = bool(inf == 'consistent' and bb is not None and pb <= 3 and bb - pb >= 2)
    # magnitude
    dist = 0.0 if lo <= est <= hi else min(abs(est - lo), abs(est - hi))
    if se_up is None:
        mag, dse = 'not_audited', None
    else:
        dse = dist / se_up
        mag = 'consistent' if dse <= 1.5 else ('grey' if dse <= 3 else 'discrepant_candidate')
    rec.update(delta_se=dse, magnitude=mag,
               relative_effect=None if pub_point == 0 else (est - pub_point) / abs(pub_point))
    if sign_mismatch or inf == 'discrepant_candidate' or mag == 'discrepant_candidate':
        out = 'discrepant_candidate'
    elif mag == 'grey':
        out = 'grey'
    elif mag == 'not_audited':
        out = 'consistent_partial_criteria'
    else:
        out = 'consistent'
    rec['outcome'] = out
    return rec


def load_impl(run_dir, who):
    d = os.path.join(run_dir, who, 'results')
    if not os.path.isdir(d):
        return None
    r = {k: pd.read_csv(os.path.join(d, f'{k}.csv')) for k in ('specs', 'coefs', 'margins')
         if os.path.exists(os.path.join(d, f'{k}.csv'))}
    if len(r) != 3:
        return None
    # v1.1 (mechanical, before any target comparison): step-3 duplicates repeat step-1 spec_ids, so keep the first
    # occurrence; harmonise season-dummy names (season2001 -> season_2001) across implementations.
    r['coefs']['term'] = r['coefs']['term'].str.replace(r'^season(\d{4})$', r'season_\1', regex=True)
    r['specs'] = r['specs'].drop_duplicates('spec_id', keep='first')
    r['coefs'] = r['coefs'].drop_duplicates(['spec_id', 'term'], keep='first')
    r['margins']['minutes_eval'] = r['margins']['minutes_eval'].round(6)
    r['margins'] = r['margins'].drop_duplicates(['spec_id', 'variant', 'minutes_eval', 'd'], keep='first')
    return r


def spec_id(model, cell):
    return f'{model}|{cell}'


def origin_values(impl):
    out = {}
    for m in ('M1', 'M2', 'M3'):
        sid = spec_id(m, ORIGIN)
        s = impl['specs'][impl['specs'].spec_id == sid]
        if len(s) != 1:
            return None
        s = s.iloc[0]
        out[(m, 'sample_hash')] = s.sample_hash
        out[(m, 'loglik')] = s.loglik
        out[(m, 'n_obs')] = s.n_obs
        c = impl['coefs'][impl['coefs'].spec_id == sid]
        for _, r in c.iterrows():
            out[(m, 'b', r.term)] = r.estimate
            out[(m, 'se', r.term)] = r.se_native
        if m != 'M1':
            g = impl['margins'][(impl['margins'].spec_id == sid) & (impl['margins'].variant == 'ME0')]
            for _, r in g.iterrows():
                out[(m, 'me', round(float(r.minutes_eval), 6) if m == 'M3' else 'mean', int(r.d))] = r.effect
    return out


def pair_agrees(a, b):
    fails = []
    for k in set(a) | set(b):
        if k not in a or k not in b:
            fails.append((k, 'missing'))
            continue
        x, y = a[k], b[k]
        kind = k[1]
        if kind == 'sample_hash':
            ok = str(x) == str(y)
        elif kind == 'n_obs':
            ok = int(x) == int(y)
        elif kind == 'loglik':
            ok = abs(x - y) <= 1e-3
        elif kind == 'b':
            ok = abs(x - y) <= max(1e-4 * abs(x), 1e-5)
        elif kind == 'se':
            ok = abs(x - y) <= 1e-3 * abs(x) + 1e-7
        elif kind == 'me':
            ok = abs(x - y) <= max(1e-3 * abs(x), 1e-7)
        else:
            ok = x == y
        if not ok:
            fails.append((k, x, y))
    return fails


def bench_lookup(impl, model, cell, term):
    bcell = cell.replace('U7=0', 'U7=1')
    c = impl['coefs'][(impl['coefs'].spec_id == spec_id(model, bcell)) & (impl['coefs'].term == term)]
    return None if len(c) != 1 else float(c.iloc[0].p_bench)


def score_cell(impl, targets, cell):
    """Score every Table 5 and Table 6 target for one grid cell; returns dict key -> record."""
    res = {}
    for key, t in targets.items():
        parts = key.split('|')
        if parts[0] == 'T5':
            model, term = parts[1], parts[2]
            term = {'minutes_remaining': 'minutes'}.get(term, term)  # v1.2: target row label -> manifest term name
            if t['quantity'] != 'odds_ratio':
                continue
            c = impl['coefs'][(impl['coefs'].spec_id == spec_id(model, cell)) & (impl['coefs'].term == term)]
            if len(c) != 1:
                res[key] = compare_target(t, None, None)
                continue
            c = c.iloc[0]
            res[key] = compare_target(t, float(c.estimate), float(c.p_native), bench_lookup(impl, model, cell, term))
        elif parts[0] == 'T6':
            q, d = parts[1], int(parts[2].replace('gap', ''))
            model = 'M2' if q == 'all' else 'M3'
            g = impl['margins'][(impl['margins'].spec_id == spec_id(model, cell)) & (impl['margins'].variant == 'ME0')
                                & (impl['margins'].d == d)]
            if model == 'M3':
                g = g[(g.minutes_eval - Q_MIN[q]).abs() < 1e-9]
            if len(g) != 1:
                res[key] = compare_target(t, None, None)
                continue
            g = g.iloc[0]
            bcell = cell.replace('U7=0', 'U7=1')
            gb = impl['margins'][(impl['margins'].spec_id == spec_id(model, bcell)) & (impl['margins'].variant == 'ME0')
                                 & (impl['margins'].d == d)]
            if model == 'M3':
                gb = gb[(gb.minutes_eval - Q_MIN[q]).abs() < 1e-9]
            pb = float(gb.iloc[0].p_bench) if len(gb) == 1 else None
            res[key] = compare_target(t, float(g.effect), float(g.p_native), pb)
    return res


def claim_outcome(name, spec, cell_scores, origin_cell, all_cells, impl_agree, n_band):
    if not impl_agree:
        return {'outcome': 'indeterminate', 'sub_code': 'implementation_disagreement'}
    o = cell_scores[origin_cell]
    prim = [o[k] for k in spec['primary']]
    outs = [p['outcome'] for p in prim]
    rec = {'primary': {k: o[k] for k in spec['primary']}}
    # secondary marginal effects
    sec_keys = [k for k in o if k.startswith('T6|') and k.split('|')[1] in spec['quarters']
                and ((spec['side'] == 'below') == (int(k.split('|')[2].replace('gap', '')) <= 0))]
    shares = {}
    for k in sec_keys:
        shares[o[k]['outcome']] = shares.get(o[k]['outcome'], 0) + 1
    rec['secondary_shares'] = {'n': len(sec_keys), **shares}
    if any(x == 'not_assessable' for x in outs):
        rec.update(outcome='indeterminate', sub_code='unavailable_criterion')
    elif all(x in ('consistent', 'consistent_partial_criteria') for x in outs):
        if any(p.get('fragile_inference') for p in prim):
            rec.update(outcome='fragile_inference')
        else:
            rec.update(outcome='consistent', sub_code='partial_criteria' if 'consistent_partial_criteria' in outs else None)
    elif any(x == 'discrepant_candidate' for x in outs):
        rescued = [c for c in all_cells if c != origin_cell and all(
            cell_scores[c][k]['outcome'] in ('consistent', 'consistent_partial_criteria') for k in spec['primary'])]
        if rescued:
            rec.update(outcome='indeterminate', sub_code='label_sensitive', rescuing_cells=rescued[:50], n_rescuing=len(rescued))
        elif n_band == 'large':
            rec.update(outcome='indeterminate', sub_code='source_vintage')
        else:
            rec.update(outcome='discrepant_candidate', sub_code='pending_adversarial_review')
    else:
        rec.update(outcome='indeterminate', sub_code='source_vintage')
    return rec


def paper_outcome(claims, lower_tier_discrepant):
    oc = {k: v['outcome'] for k, v in claims.items()}
    if any(v in ('indeterminate', 'not_attemptable') for v in oc.values()):
        return {'outcome': 'indeterminate', 'driver': {k: v for k, v in oc.items() if v in ('indeterminate', 'not_attemptable')}}
    if all(v == 'consistent' for v in oc.values()):
        return {'outcome': 'consistent', 'mapping': 'partially reproduced' if lower_tier_discrepant else 'fully reproduced'}
    if any(oc[h] == 'discrepant_candidate' for h in oc):
        return {'outcome': 'indeterminate', 'sub_code': 'pending_confirmation',
                'would_map_to': 'not reproduced' if oc['H2'] == 'discrepant_candidate' or oc['H3'] == 'discrepant_candidate' else 'partially reproduced'}
    if any(v == 'fragile_inference' for v in oc.values()):
        return {'outcome': 'fragile_inference'}
    return {'outcome': 'indeterminate', 'sub_code': 'unclassified_combination', 'claims': oc}


def main(root, run_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    targets = json.load(open(os.path.join(root, 'sealed/targets_reconciled_v1.json')))['targets']
    impls = {w: load_impl(run_dir, w) for w in 'ABC'}
    vals = {w: (origin_values(i) if i else None) for w, i in impls.items()}
    agree = {}
    for a, b in itertools.combinations('ABC', 2):
        if vals[a] and vals[b]:
            f = pair_agrees(vals[a], vals[b])
            agree[a + b] = {'agree': not f, 'n_fail': len(f), 'fails': [str(x) for x in f[:25]]}
        else:
            agree[a + b] = {'agree': False, 'reason': 'missing implementation output'}
    pairs = [p for p, v in agree.items() if v['agree']]
    use = pairs[0][0] if pairs else next((w for w in 'ABC' if vals[w]), None)
    impl = impls[use]
    n_obs = int(impl['specs'][impl['specs'].spec_id == spec_id('M2', ORIGIN)].iloc[0].n_obs)
    rel = (n_obs - PUB_N) / PUB_N
    n_band = 'close' if abs(rel) <= .02 else 'moderate' if abs(rel) <= .05 else 'large'
    ok = impl['specs'][impl['specs'].status == 'ok'].spec_id
    cells = sorted({s.split('|', 1)[1] for s in ok if s.startswith('M3|') and s.endswith('U8=0')})
    cell_scores = {c: score_cell(impl, targets, c) for c in cells}
    claims = {h: claim_outcome(h, s, cell_scores, ORIGIN, cells, bool(pairs), n_band) for h, s in CLAIMS.items()}
    nonfocal = {k: v for k, v in cell_scores[ORIGIN].items() if k.startswith('T5|') and k.split('|')[2] not in FOCAL_TERMS}
    lower_disc = [k for k, v in nonfocal.items() if v['outcome'] == 'discrepant_candidate']
    paper = paper_outcome(claims, bool(lower_disc))
    rows = []
    for c, sc in cell_scores.items():
        for k, r in sc.items():
            rows.append({'cell': c, 'key': k, **{x: r.get(x) for x in ('pub_value', 'pub_se', 'pub_stars', 'reconstructed', 'p_native', 'p_bench', 'pub_band', 'rec_band', 'bench_band', 'band_diff', 'sign', 'inference', 'delta_se', 'magnitude', 'relative_effect', 'fragile_inference', 'low_resolution_se', 'outcome')}})
    pd.DataFrame(rows).to_csv(os.path.join(out_dir, 'target_comparisons_all_cells.csv'), index=False)
    record = {'implementation_agreement': agree, 'scored_on': use, 'agreeing_pairs': pairs,
              'N': {'origin_n': n_obs, 'published_n': PUB_N, 'relative_difference': rel, 'band': n_band},
              'claims': claims, 'nonfocal_origin': nonfocal, 'lower_tier_discrepant': lower_disc, 'paper': paper,
              'cells_scored': len(cells)}
    json.dump(record, open(os.path.join(out_dir, 'score_record.json'), 'w'), indent=1, default=str)
    return record


if __name__ == '__main__':
    r = main(*sys.argv[1:4])
    print(json.dumps({k: r[k] for k in ('agreeing_pairs', 'scored_on', 'N', 'paper')}, indent=1, default=str))
    print({h: (c['outcome'], c.get('sub_code')) for h, c in r['claims'].items()})
