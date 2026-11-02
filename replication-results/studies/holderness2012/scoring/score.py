"""Stage 2: deterministic scoring against sealed targets (sealed/scoring/scoring_rules_v1.json).
Run only after compare_implementations.py. Inputs: scoring/implementation_comparison_terms.csv, scoring/implementation_comparison_models.csv,
sealed/targets_reconciled_tables4to6.csv, run influence files. Outputs: scoring/claim_scores.csv, scoring/paper_score.json,
scoring/branch_summary.csv, scoring/influence_summary.csv."""
import json, os, math
import numpy as np, pandas as pd

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
RULES = json.load(open(f'{ROOT}/sealed/scoring/scoring_rules_v1.json'))
TOL = RULES['implementation_agreement']['tolerances']
RUNS = json.load(open(f'{ROOT}/scoring/scored_runs.json'))
T = pd.read_csv(f'{ROOT}/sealed/targets_reconciled_tables4to6.csv', dtype=str)
TERMS = pd.read_csv(f'{ROOT}/scoring/implementation_comparison_terms.csv')
MODELS = pd.read_csv(f'{ROOT}/scoring/implementation_comparison_models.csv')
IMPLS = [k for k in ['A', 'B', 'C'] if k in RUNS]
PUB_N = {'T4': 100464, 'T6': 102334}
BANDS = [0.01, 0.05, 0.10]

def band(p): return sum(p >= b for b in BANDS)  # 0: p<.01, 1: .01-.05, 2: .05-.10, 3: >=.10
def num(s): return float(str(s).replace('−', '-'))
def p_interval(s):
    v = num(s); lo = max(0.0, v - 0.005); hi = v + 0.005
    return lo, hi
def bands_of_interval(lo, hi):
    return sorted({b for b in range(4) if (b == 0 and lo < 0.01) or (b == 1 and lo < 0.05 and hi > 0.01) or (b == 2 and lo < 0.10 and hi > 0.05) or (b == 3 and hi > 0.10)})

def close(a, b):
    if pd.isna(a) or pd.isna(b): return False
    d = abs(a - b); return d <= TOL['me_abs'] or d / max(abs(a), abs(b), 1e-300) <= TOL['me_rel']

def agreeing(row):
    """Return (pair, value, p) under the two-of-three rule, or (None,...)"""
    for a, b in [('A', 'B'), ('A', 'C'), ('B', 'C')]:
        if a in IMPLS and b in IMPLS and close(row.get(a), row.get(b)):
            return a + b, row[a], row[a + '_p']
    return None, np.nan, np.nan

FAMKEY = {'T4': 't4', 'T5': 't5', 'T6': 't6'}
def key_for(t):
    fam = FAMKEY[t['family']]
    var = 'both' if t['family'] == 'T5' else t['measure']
    mk = f"{fam}|{t['group']}|{t['spec']}|{var}"
    tk = t['term']
    if tk == 'hierarchy': tk = t['measure']
    return mk, tk

def score_target(t, rec, p_rec):
    v = num(t['printed_value']); lo, hi = v - 0.005, v + 0.005
    res = {'printed_value': t['printed_value'], 'printed_p': t['printed_p'], 'rec_me': rec, 'rec_p': p_rec}
    if pd.isna(rec):
        res.update(outcome='indeterminate', reason='no_agreeing_implementations'); return res
    pub_sign = -1 if t['printed_value'].strip().replace('−', '-').startswith('-') else (1 if v > 0 else 0)
    outside = rec < lo or rec > hi
    sign_fail = bool(outside and pub_sign != 0 and np.sign(rec) == -pub_sign)
    res.update(within_rounding=not outside, abs_diff=rec - v, rel_diff=(rec - v) / v if v != 0 else np.nan, sign_fail=sign_fail)
    if t['printed_p'] in ('', 'nan') or pd.isna(t['printed_p']):
        res.update(inference='not_printed'); inf_fail = False
    else:
        plo, phi = p_interval(t['printed_p']); pb = bands_of_interval(plo, phi); rb = band(p_rec)
        significant_claim = max(pb) <= 2  # published at least marginally significant
        # scoring_rules_v1: only a band 2 or more WEAKER is an inference failure; a reconstruction significant at 0.10
        # where the article reports p >= 0.10 is recorded as contradicting nonsignificance, not scored as a failure.
        dist = max(0, rb - max(pb))
        inf_fail = dist >= 2
        res.update(pub_bands=pb, rec_band=rb, band_distance=dist, inference='fail' if inf_fail else 'pass',
                   contradicts_nonsignificance=(not significant_claim and rb <= 2))
    res['outcome'] = 'potential_discrepancy' if (sign_fail or inf_fail) else 'consistent'
    res['reason'] = ','.join([r for r, f in [('sign', sign_fail), ('inference_2plus_bands', inf_fail)] if f]) or 'criteria_met_magnitude_not_audited'
    return res

def main():
    terms = TERMS.set_index(['spec_id', 'mkey', 'tkey'])
    models = MODELS.set_index(['spec_id', 'mkey'])
    rows = []
    for _, t in T.iterrows():
        if t['quantity'] not in ('marginal_effect', 'coefficient') or t['family'] not in FAMKEY: continue
        mk, tk = key_for(t)
        try: r = terms.loc[('S000', mk, tk)]
        except KeyError: r = pd.Series(dtype=float)
        pair, val, p = agreeing(r)
        s = score_target(t, val, p)
        nrec = models.loc[('S000', mk)].get(f'n_{pair[0]}') if pair and ('S000', mk) in models.index else np.nan
        tier = {'T4': 'focal' if tk in ('steepness', 'sameness') else 'nuisance_control', 'T5': 'robustness_or_diagnostic',
                'T6': 'uncertain_focal' if tk == 'officer_x_hierarchy' else ('robustness' if tk in ('steepness', 'sameness') else 'nuisance_control')}[t['family']]
        rows.append({'target_id': t['target_id'], 'family': t['family'], 'measure': t['measure'], 'group': t['group'], 'spec': t['spec'],
                     'term': tk, 'tier': tier, 'model_key': mk, 'agreeing_pair': pair, **{f'me_{i}': r.get(i) for i in IMPLS},
                     **{f'p_{i}': r.get(i + '_p') for i in IMPLS}, 'n_rec': nrec, 'n_pub': PUB_N.get(t['family']), **s})
    cs = pd.DataFrame(rows)
    cs['n_match'] = [(abs(a - b) / b <= 0.005) if not pd.isna(a) and b else np.nan for a, b in zip(cs.n_rec, cs.n_pub)]
    # uncertain branches (run on the eight T4 models): label sensitivity for every scored T4 term, focal and control
    br = []
    for _, c in cs[cs.family == 'T4'].iterrows():
        vals = []
        for spec in sorted(TERMS.spec_id.unique()):
            if spec == 'S000': continue
            try: r = terms.loc[(spec, c.model_key, c.term)]
            except KeyError: continue
            pair, v, p = agreeing(r)
            if pair is None: continue
            t = T[T.target_id == c.target_id].iloc[0]
            o = score_target(t, v, p)
            vals.append({'spec_id': spec, 'me': v, 'p': p, 'outcome': o['outcome']})
            br.append({'target_id': c.target_id, 'model_key': c.model_key, 'term': c.term, 'spec_id': spec, 'agreeing_pair': pair, 'me': v, 'p': p, 'outcome': o['outcome']})
        v = pd.DataFrame(vals)
        idx = cs.index[cs.target_id == c.target_id][0]
        if len(v):
            cs.loc[idx, 'branches_n'] = len(v); cs.loc[idx, 'branches_negative'] = int((v.me < 0).sum())
            cs.loc[idx, 'branches_p05'] = int(((v.p < 0.05) & (v.me < 0)).sum()); cs.loc[idx, 'branches_p10'] = int(((v.p < 0.10) & (v.me < 0)).sum())
            cs.loc[idx, 'branches_median'] = v.me.median(); cs.loc[idx, 'branches_min'] = v.me.min(); cs.loc[idx, 'branches_max'] = v.me.max()
            cs.loc[idx, 'label_sensitive'] = bool((v.outcome != c.outcome).any())
            cs.loc[idx, 'branches_changing_outcome'] = ';'.join(v[v.outcome != c.outcome].spec_id)
    pd.DataFrame(br).to_csv(f'{ROOT}/scoring/branch_summary.csv', index=False)
    cs.to_csv(f'{ROOT}/scoring/claim_scores.csv', index=False)
    # claim and paper aggregation
    def claim_outcome(sub):
        o = set(sub.outcome)
        if o == {'consistent'}: return 'consistent'
        if o == {'potential_discrepancy'}: return 'potential_discrepancy'
        if 'indeterminate' in o: return 'indeterminate:implementation_disagreement'
        return 'indeterminate:within_claim_mixed'
    claims = []
    for (fam, meas, grp), sub in cs[cs.tier.isin(['focal', 'uncertain_focal'])].groupby(['family', 'measure', 'group']):
        claims.append({'family': fam, 'measure': meas, 'group': grp, 'tier': sub.tier.iloc[0], 'coefficients': len(sub),
                       'outcome': claim_outcome(sub), 'label_sensitive': bool(sub['label_sensitive'].astype('boolean').fillna(False).any()) if 'label_sensitive' in sub else False})
    cl = pd.DataFrame(claims)
    def paper(cl_focal, lower_disc):
        o = list(cl_focal.outcome)
        if any(x.startswith('indeterminate') for x in o): return 'indeterminate'
        if all(x == 'consistent' for x in o):
            # scoring_rules_v1: 'discrepant' requires adversarial review and human confirmation; unconfirmed lower-tier
            # potential discrepancies leave the mapping provisional.
            return ('fully reproduced on focal claims, provisional: lower-tier potential discrepancies unconfirmed '
                    '(mapping becomes partially reproduced if any is confirmed after adversarial review and human confirmation)') if lower_disc else 'fully reproduced'
        if all(x == 'potential_discrepancy' for x in o): return 'not reproduced (pending adversarial review and human confirmation)'
        return f"not covered by mapping: focal mixed ({sum(x == 'consistent' for x in o)} consistent, {sum(x == 'potential_discrepancy' for x in o)} potential discrepancy)"
    lower = cs[~cs.tier.isin(['focal', 'uncertain_focal'])]
    lower_disc = bool((lower.outcome == 'potential_discrepancy').any())
    focal = cl[cl.family == 'T4']
    out = {'claims': claims, 'paper_outcome_T4_focal': paper(focal, lower_disc),
           'paper_outcome_with_T6_focal': paper(cl[cl.family.isin(['T4', 'T6'])], lower_disc),
           'lower_tier_potential_discrepancies': lower[lower.outcome == 'potential_discrepancy'][['family', 'measure', 'group', 'spec', 'term', 'printed_value', 'printed_p', 'rec_me', 'rec_p']].to_dict('records'),
           'implementations_scored': IMPLS, 'magnitude_criterion': 'not audited (no published SEs)',
           'specification_fragility': 'not assessed (no substantive equivalent alternatives)'}
    json.dump(out, open(f'{ROOT}/scoring/paper_score.json', 'w'), indent=2, default=str)
    print(json.dumps({k: v for k, v in out.items() if k != 'lower_tier_potential_discrepancies'}, indent=1, default=str))
    print('lower-tier potential discrepancies:', len(out['lower_tier_potential_discrepancies']))

if __name__ == '__main__':
    main()
