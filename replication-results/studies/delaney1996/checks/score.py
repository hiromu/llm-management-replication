"""Deterministic scorer for study delaney1996 (implements checks/scoring_rules_v1.json).

Usage: python score.py --impl A=<dir> --impl B=<dir> --impl C=<dir> --targets <json> --out <dir>
"""
import argparse, json, math, os
import numpy as np
import pandas as pd

TOL = 1e-6
HRM = ['STAFF', 'TRAIN', 'INCENT', 'GRIEV', 'DECENT', 'ILM', 'VHIER']
INTER = ['TRAIN_x_STAFF', 'GRIEV_x_INCENT', 'ILM_x_DECENT', 'VHIER_x_DECENT']
NO_MAG = {'(Intercept)', 'PCTMGR'}
PUB_BAND = {'**': 0, '*': 1, '†': 2, '': 3}
SEALED_N = {'org': 590, 'mkt': 373}
FAMILY_OF = lambda mid: 'org' if mid.startswith('org') else 'mkt'


def band(p):
    if p is None or (isinstance(p, float) and math.isnan(p)): return None
    return 0 if p < .01 else 1 if p < .05 else 2 if p < .10 else 3


def load_impl(d):
    r = {}
    for f in ['coefficients', 'model_stats', 'nested_tests', 'samples', 'influence']:
        p = os.path.join(d, f + '.csv')
        r[f] = pd.read_csv(p, na_values=['NA']) if os.path.exists(p) else None
    return r


# ---------- implementation agreement ----------
def sample_sets(impl, spec):
    s = impl['samples']; s = s[s.spec_id == spec]
    out = {}
    for fam, g in s.groupby('family'):
        out[fam] = frozenset(g.V1.astype(int))
    return out


def coef_frame(impl, spec):
    c = impl['coefficients']; c = c[c.spec_id == spec]
    return c.set_index(['model_id', 'term'])[['estimate', 'se']]


def pair_agree(i1, i2, spec):
    s1, s2 = sample_sets(i1, spec), sample_sets(i2, spec)
    same_samples = s1 == s2 and len(s1) > 0
    c1, c2 = coef_frame(i1, spec), coef_frame(i2, spec)
    j = c1.join(c2, lsuffix='_1', rsuffix='_2', how='outer')
    j = j[~j.index.get_level_values('term').astype(str).str.startswith('IND_')]
    both = j.dropna()
    missing = len(j) - len(both)
    maxdiff = float(np.nanmax(np.abs(both[['estimate_1', 'se_1']].values - both[['estimate_2', 'se_2']].values))) if len(both) else float('nan')
    agree = same_samples and missing == 0 and len(both) > 0 and maxdiff <= TOL
    return dict(same_samples=bool(same_samples), n_terms=int(len(j)), unmatched_terms=int(missing), max_abs_diff=maxdiff, agree=bool(agree))


# ---------- recon lookup ----------
def recon_value(impl, spec, cell):
    mid = cell['model_id']; q = cell['quantity']
    if q == 'coef':
        model = mid + '_' + cell['term'] if mid in ('org_M1', 'mkt_M6') else mid
        c = impl['coefficients']; r = c[(c.spec_id == spec) & (c.model_id == model) & (c.term == cell['term'])]
        if len(r) != 1 or pd.isna(r.estimate.iloc[0]): return None
        r = r.iloc[0]
        return dict(est=r.estimate, se=r.se, p_upper=r.p_upper, p_lower=r.p_lower, p_upper_hc3=r.p_upper_hc3, p_lower_hc3=r.p_lower_hc3)
    if q in ('R2', 'F', 'N'):
        m = impl['model_stats']; r = m[(m.spec_id == spec) & (m.model_id == mid)]
        if len(r) != 1 or r.status.iloc[0] != 'ok': return None
        r = r.iloc[0]
        return dict(est={'R2': r.r2, 'F': r.f, 'N': r.n}[q], p_upper=r.f_p if q == 'F' else None)
    if q in ('deltaR2', 'F_deltaR2'):
        n = impl['nested_tests']; r = n[(n.spec_id == spec) & (n.full_model == mid)]
        if len(r) != 1 or pd.isna(r.f.iloc[0]): return None
        r = r.iloc[0]
        return dict(est=r.delta_r2 if q == 'deltaR2' else r.f, p_upper=r.p if q == 'F_deltaR2' else None)
    return None


# ---------- criteria ----------
def criteria(cell, rv):
    """Return dict of sign_fail, d, m (None when not assessable) and discrepant flag."""
    q = cell['quantity']; pub = cell['value']; stars = cell.get('stars', '') or ''
    pb = PUB_BAND.get(stars, 3)
    out = dict(sign_fail=None, d=None, m=None, recon_band=None, pub_band=pb)
    if rv is None: return None
    if q == 'coef':
        lo, hi = pub - 0.0005, pub + 0.0005
        if lo > 0 or hi < 0:
            out['sign_fail'] = bool((rv['est'] > 0) != (pub > 0)) if rv['est'] != 0 else True
        term = cell['term']
        if pb < 3:
            p = rv['p_upper'] if (term in HRM + INTER or pub > 0) else rv['p_lower']
            rb = band(p); out['recon_band'] = rb; out['d'] = max(0, rb - pb)
        else:
            rb = band(min(rv['p_upper'], rv['p_lower'])); out['recon_band'] = rb; out['d'] = 3 - rb
        if term not in NO_MAG and cell.get('se'):
            dist = max(0.0, abs(rv['est'] - pub) - 0.0005)
            out['m'] = dist / cell['se']; out['rel'] = (rv['est'] - pub) / abs(pub) if abs(pub) >= 0.01 else None
    elif q in ('F', 'F_deltaR2'):
        rb = band(rv['p_upper']); out['recon_band'] = rb
        out['d'] = max(0, rb - pb) if pb < 3 else 3 - rb
    else:  # R2, deltaR2, N: descriptive comparison only
        out['abs_diff'] = rv['est'] - pub
    dflags = [out['sign_fail'] is True, (out['d'] or 0) >= 2, (out['m'] or 0) > 2.0]
    out['discrepant'] = any(dflags)
    out['assessable'] = q in ('coef', 'F', 'F_deltaR2')
    return out


def hc3_fragile(cell, rv):
    if cell['quantity'] != 'coef': return False
    pb = PUB_BAND.get(cell.get('stars', '') or '', 3)
    if pb == 3: return False
    p = rv['p_upper_hc3'] if (cell['term'] in HRM + INTER or cell['value'] > 0) else rv['p_lower_hc3']
    hb = band(p)
    return hb is not None and (hb - pb >= 2 or (pb <= 1 and hb == 3))


def score_cells(impl, targets, specs, n_by_family):
    rows = []
    for cell in targets['cells']:
        rv0 = recon_value(impl, 'O', cell)
        rec = dict(cell); rec.update(origin_est=None if rv0 is None else rv0['est'])
        if rv0 is None:
            rec.update(outcome='not_attemptable', reason='origin value unavailable'); rows.append(rec); continue
        c0 = criteria(cell, rv0)
        rec.update({f'origin_{k}': v for k, v in c0.items()})
        if cell['quantity'] == 'coef':
            rec.update(origin_se=rv0['se'], origin_p_upper=rv0['p_upper'], origin_p_lower=rv0['p_lower'], origin_p_upper_hc3=rv0['p_upper_hc3'])
        elif rv0.get('p_upper') is not None:
            rec.update(origin_p=rv0['p_upper'])
        dev = []
        for s in specs:
            if s == 'O' or s.startswith('CHK_'): continue
            rv = recon_value(impl, s, cell)
            if rv is None: continue
            cs = criteria(cell, rv); dev.append((s, cs['discrepant'], rv['est']))
        rec['n_dev_fitted'] = len(dev)
        rec['n_dev_discrepant'] = sum(1 for _, x, _ in dev if x)
        if not c0['assessable']:
            rec.update(outcome='descriptive_only', reason='no inference/magnitude criterion'); rows.append(rec); continue
        fam = FAMILY_OF(cell['model_id']); n = n_by_family.get(fam)
        n_ok = n is not None and abs(n - SEALED_N[fam]) / SEALED_N[fam] <= 0.05
        rec['family_n'] = n; rec['n_within_5pct'] = n_ok
        if c0['discrepant']:
            if all(x for _, x, _ in dev):
                rec.update(outcome='discrepant_candidate_pending_human_review', reason='outside tolerance at origin and every fitted deviation')
            else:
                rec.update(outcome='indeterminate', reason='label_sensitive: outside tolerance at origin, within tolerance under some uncertain branch')
        elif not n_ok:
            rec.update(outcome='indeterminate', reason='sample_reconstruction: family N differs from published N by more than 5%')
        elif hc3_fragile(cell, rv0):
            rec.update(outcome='fragile_inference', reason='HC3 benchmark band 2+ weaker or crosses .05 to >=.10')
        else:
            rec.update(outcome='consistent', reason='within tolerance on assessable criteria')
        rows.append(rec)
    return pd.DataFrame(rows)


def aggregate(cells):
    def prim_h1(r):
        return r.quantity == 'coef' and r.model_id in ('org_M2', 'org_M3', 'mkt_M7', 'mkt_M8') and r.term in HRM and r.value > 0 and (r.stars or '') != ''
    def prim_h2(r):
        return r.quantity == 'F_deltaR2' and r.model_id in ('org_M4', 'org_M5', 'mkt_M9', 'mkt_M10')
    cells = cells.copy()
    cells['h1_primary'] = cells.apply(prim_h1, axis=1); cells['h2_primary'] = cells.apply(prim_h2, axis=1)
    def rule(sub, k_disc):
        o = sub.outcome.tolist(); n = len(o)
        disc = sum(x.startswith('discrepant') for x in o)
        if n == 0: return 'not_attemptable', 'no primary cells'
        if all(x == 'not_attemptable' for x in o): return 'not_attemptable', 'all primary cells not attemptable'
        if disc >= k_disc: return 'discrepant_candidate_pending_human_review', f'{disc}/{n} primary cells discrepant'
        ind = [r for x, r in zip(o, sub.reason) if x in ('indeterminate', 'not_attemptable')]
        if ind: return 'indeterminate', '; '.join(sorted(set(r.split(':')[0] for r in ind))) + f' ({len(ind)}/{n} primary cells)'
        fi = sum(x == 'fragile_inference' for x in o)
        if fi >= math.ceil(n * 0.6): return 'fragile_inference', f'{fi}/{n}'
        if all(x in ('consistent', 'fragile_inference') for x in o): return 'consistent', f'{n - fi}/{n} consistent, {fi} fragile_inference'
        return 'indeterminate', 'mixed_cells'
    h1 = rule(cells[cells.h1_primary], 6)
    h2 = rule(cells[cells.h2_primary], 3)
    lower = cells[~cells.h1_primary & ~cells.h2_primary]
    lower_disc = int(lower.outcome.astype(str).str.startswith('discrepant').sum())
    if h1[0] == 'not_attemptable': paper = 'not_attemptable'
    elif h1[0].startswith('discrepant'): paper = 'not_reproduced (pending adversarial review and human confirmation)'
    elif h1[0] == 'indeterminate' or h2[0] == 'indeterminate': paper = 'indeterminate'
    elif h1[0] == 'fragile_inference': paper = 'fragile_inference (not mapped)'
    elif h1[0] == 'consistent' and h2[0] == 'consistent' and lower_disc == 0: paper = 'fully_reproduced'
    elif h1[0] == 'consistent': paper = 'partially_reproduced'
    else: paper = 'indeterminate'
    return dict(H1=dict(outcome=h1[0], reason=h1[1], n_primary=int(cells.h1_primary.sum())),
                H2=dict(outcome=h2[0], reason=h2[1], n_primary=int(cells.h2_primary.sum())),
                lower_tier_discrepant_cells=lower_disc, paper=paper,
                outcome_counts=cells.outcome.value_counts().to_dict())


def uncertain_summary(impl, targets, specs):
    rows = []
    for cell in targets['cells']:
        if cell['quantity'] != 'coef' or cell['term'] not in HRM + INTER or cell['model_id'] in ('org_M1', 'mkt_M6'): continue
        ests, sig, signs = [], [], []
        for s in specs:
            if s == 'O' or s.startswith('CHK_'): continue
            rv = recon_value(impl, s, cell)
            if rv is None: continue
            ests.append(rv['est']); sig.append(rv['p_upper'] < .05); signs.append(np.sign(rv['est']) == np.sign(cell['value']))
        if not ests: continue
        e = np.array(ests)
        rows.append(dict(model_id=cell['model_id'], term=cell['term'], published=cell['value'], n_uncertain_specs=len(e),
                         sign_agree_share=float(np.mean(signs)), sig_upper_05_share=float(np.mean(sig)), median=float(np.median(e)),
                         min=float(e.min()), max=float(e.max()), published_percentile=float(np.mean(e <= cell['value']))))
    return pd.DataFrame(rows)


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--impl', action='append'); ap.add_argument('--targets'); ap.add_argument('--out')
    a = ap.parse_args(); os.makedirs(a.out, exist_ok=True)
    impls = {k: load_impl(v) for k, v in (x.split('=', 1) for x in a.impl)}
    targets = json.load(open(a.targets))
    names = sorted(impls)
    specs = list(pd.unique(impls[names[0]]['model_stats'].spec_id))
    agree = {}
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            agree[f'{names[i]}-{names[j]}'] = {s: pair_agree(impls[names[i]], impls[names[j]], s) for s in specs}
    origin_pairs = [p for p, v in agree.items() if v.get('O', {}).get('agree')]
    summary = dict(origin_agreeing_pairs=origin_pairs,
                   grid_agreement={p: dict(n_specs=len(v), n_agree=sum(x['agree'] for x in v.values())) for p, v in agree.items()})
    json.dump(dict(summary=summary, detail=agree), open(os.path.join(a.out, 'implementation_agreement.json'), 'w'), indent=1, default=str)
    if not origin_pairs:
        json.dump(dict(paper='indeterminate', reason='implementation_disagreement: no agreeing pair at origin'), open(os.path.join(a.out, 'paper_outcome.json'), 'w'), indent=1)
        print('no agreeing pair'); return
    use = origin_pairs[0].split('-')[0]
    impl = impls[use]
    ms = impl['model_stats']; o = ms[ms.spec_id == 'O'].set_index('model_id')
    n_by_family = {'org': int(o.loc['org_M2', 'n']) if 'org_M2' in o.index else None, 'mkt': int(o.loc['mkt_M7', 'n']) if 'mkt_M7' in o.index else None}
    cells = score_cells(impl, targets, specs, n_by_family)
    cells.to_csv(os.path.join(a.out, 'cell_scores.csv'), index=False)
    agg = aggregate(cells); agg.update(scored_with=use, origin_agreeing_pairs=origin_pairs, family_n=n_by_family, sealed_n=SEALED_N)
    json.dump(agg, open(os.path.join(a.out, 'claim_and_paper_outcomes.json'), 'w'), indent=1, default=str)
    uncertain_summary(impl, targets, specs).to_csv(os.path.join(a.out, 'uncertain_set_summary.csv'), index=False)
    print(json.dumps(agg, indent=1, default=str))


if __name__ == '__main__':
    main()
