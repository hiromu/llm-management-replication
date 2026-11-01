"""Adversarial review: per-candidate diagnostics using the frozen scorer's own criteria() function.
Columns: origin criteria (frozen), a counterfactual (published estimate with the reconstructed SE/df -> would the
band criterion still fire?), the SUBSID orientation re-expression (exact algebra: coefficient on 1-SUBSID = -coef),
and the EXPLORATORY, POST-HOC X4 configuration. Nothing here changes a frozen classification."""
import sys, json, math
import pandas as pd
from scipy import stats
sys.dont_write_bytecode = True
sys.path.insert(0, '../..')
import score as S  # frozen scorer, imported read-only

root = '../../..'
cells = pd.read_csv(f'{root}/checks/score_output_run_20261028_v1_1/cell_scores.csv')
cand = cells[cells.outcome.str.startswith('discrepant')].copy()
coefA = pd.read_csv(f'{root}/runs/run_20261028_v1_1/out_A/coefficients.csv', na_values=['NA'])
x4 = pd.read_csv('X4_coefficients_EXPLORATORY_POSTHOC.csv', na_values=['NA'])
targets = {(c['model_id'], c.get('term')): c for c in json.load(open(f'{root}/sealed/targets_frozen_v1.json'))['cells'] if c['quantity'] == 'coef'}

def model_name(mid, term):
    return mid + '_' + term if mid in ('org_M1', 'mkt_M6') else mid

def rv_from(df, spec, mid, term, flip=False):
    r = df[(df.spec_id == spec) & (df.model_id == model_name(mid, term)) & (df.term == term)]
    if len(r) != 1: return None
    r = r.iloc[0]; s = -1 if flip else 1
    pu, pl = (r.p_lower, r.p_upper) if flip else (r.p_upper, r.p_lower)
    return dict(est=s * r.estimate, se=r.se, p_upper=pu, p_lower=pl, df=r.df)

rows = []
for _, c in cand.iterrows():
    cell = dict(targets[(c.model_id, c.term)])
    rv0 = rv_from(coefA, 'O', c.model_id, c.term)
    c0 = S.criteria(cell, rv0)
    flags = [k for k, v in (('sign', c0['sign_fail'] is True), ('band', (c0['d'] or 0) >= 2), ('magnitude', (c0['m'] or 0) > 2.0)) if v]
    # counterfactual: reconstructed estimate set equal to the published value, reconstructed SE and df kept
    t = cell['value'] / rv0['se']
    cf = dict(est=cell['value'], se=rv0['se'], p_upper=stats.t.sf(t, rv0['df']), p_lower=stats.t.cdf(t, rv0['df']))
    ccf = S.criteria(cell, cf)
    pub_t = cell['value'] / cell['se']
    rec = dict(model_id=c.model_id, term=c.term, tier=c.tier, published=cell['value'], pub_se=cell['se'], stars=cell.get('stars', ''),
               pub_t=round(pub_t, 2), origin_est=round(rv0['est'], 4), origin_se=round(rv0['se'], 4), se_ratio=round(rv0['se'] / cell['se'], 2),
               origin_p_upper=round(rv0['p_upper'], 4), d=c0['d'], m=round(c0['m'], 2) if c0['m'] is not None else None,
               flags='+'.join(flags), counterfactual_pub_est_recon_se_discrepant=ccf['discrepant'])
    if c.term == 'SUBSID':
        cr = S.criteria(cell, rv_from(coefA, 'O', c.model_id, c.term, flip=True))
        rec.update(subsid_reexpressed_est=round(-rv0['est'], 4), subsid_reexpressed_discrepant=cr['discrepant'])
    r4 = rv_from(x4, 'X4', c.model_id, c.term, flip=False)
    if r4:
        c4 = S.criteria(cell, r4)
        rec.update(X4_est=round(r4['est'], 4), X4_se=round(r4['se'], 4), X4_p_upper=round(r4['p_upper'], 4), X4_d=c4['d'],
                   X4_m=round(c4['m'], 2) if c4['m'] is not None else None, X4_sign_fail=c4['sign_fail'], X4_discrepant=c4['discrepant'])
        if c.term == 'SUBSID':
            c4f = S.criteria(cell, rv_from(x4, 'X4', c.model_id, c.term, flip=True))
            rec.update(X4_subsid_reexpressed_discrepant=c4f['discrepant'])
    rows.append(rec)
out = pd.DataFrame(rows)
out.to_csv('candidate_diagnostics.csv', index=False)
pd.set_option('display.width', 300); pd.set_option('display.max_columns', 40)
print(out.to_string())
