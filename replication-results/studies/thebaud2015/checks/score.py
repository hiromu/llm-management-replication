"""Deterministic scorer under reconciliation/frozen/scoring_rules.json (v1). Written before real results were seen.

Usage: python score.py <results.csv of the scoring implementation> <agreement.csv or ''> <deviation+influence results.csv or ''> <out_dir>
Reads sealed targets from reconciliation/target_transcription_ledger.csv (rows where both readers agree).
"""
import sys, os, json, math, re
import numpy as np, pandas as pd

S = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
res_path, agr_path, grid_path, out = sys.argv[1:5]
os.makedirs(out, exist_ok=True)

TERM = {'female': 'female', 'paid leave for mothers': 'leave', 'paid leave squared': 'leave_sq',
        'state childcare spending': 'childcare', 'women s part time employment': 'parttime',
        'paid leave x female': 'female:leave', 'paid leave squared x female': 'female:leave_sq',
        'childcare x female': 'female:childcare', 'part time employment x female': 'female:parttime',
        'age': 'age_c', 'age squared': 'age_c2', 'postsecondary degree or higher': 'postsecondary',
        'sole owner of business 1 yes': 'sole', 'business age': 'bage_c', 'gdp': 'gdp', 'unemployment rate': 'unemp',
        'employment protection index': 'epl', 'social status of entrepreneurship': 'status',
        'percent women managers': 'wmgr', 'fertility rate': 'fert', 'intercept': '(Intercept)',
        'not employed': 'not_employed', 'self assessed entrepreneurial ability': 'skill',
        'fears business failure': 'fear', 'knows another entrepreneur': 'knows'}
for y in range(2002, 2009):
    TERM[str(y)] = f'year{y}'
MODEL = {('Table 1', '1'): 'M1', ('Table 1', '2'): 'M2', ('Table 1', '3'): 'M3', ('Table 2', '4'): 'M4',
         ('Table 2', '5'): 'M5', ('Table 2', '6'): 'M6', ('Table 2', '7'): 'M7', ('Table 2', '8'): 'M8',
         ('Table A3', '1'): 'R1', ('Table A3', '2'): 'R2', ('Table A3', '3'): 'R3'}

led = pd.read_csv(os.path.join(S, 'reconciliation/target_transcription_ledger.csv'), dtype={'model': str})
led = led[led.status == 'agree']
led['model_id'] = [MODEL.get((t, m)) for t, m in zip(led.table, led.model)]
coef = led[led.quantity == 'coefficient'].copy()
coef['term'] = coef.row.map(TERM)
nrow = led[led.quantity == 'n_individuals'].set_index('model_id')['astra_value']


def half_unit(printed):
    s = re.sub(r'[^0-9.]', '', str(printed).split('(')[0].replace('–', '-'))
    if '.' in s:
        return 0.5 * 10 ** (-len(s.split('.')[1]))
    return 0.5


def pub_band(stars):
    k = str(stars or '').count('•')
    return {3: 0, 2: 1, 1: 2}.get(k, 3)


def rec_band(p):
    if p is None or (isinstance(p, float) and math.isnan(p)):
        return None
    return 0 if p < .01 else 1 if p < .05 else 2 if p < .10 else 3


res = pd.read_csv(res_path, dtype={'deleted_country': str})
org = res[(res.run_id == 'ORIGIN') & (res.deleted_country.isna())]
agree = pd.read_csv(agr_path, dtype={'deleted_country': str}) if agr_path else None

rows = []
for _, t in coef.iterrows():
    if t.model_id is None or not isinstance(t.term, str):
        continue
    r = org[(org.model == t.model_id) & (org.term == t.term)]
    rec = dict(model=t.model_id, term=t.term, printed=t.astra_printed, pub_value=t.astra_value, pub_se=t.astra_se,
               pub_stars=t.astra_stars if isinstance(t.astra_stars, str) else '', page=t.page)
    if not len(r) or r.iloc[0].status != 'ok':
        rec.update(status='not_estimated', outcome='indeterminate:implementation_failure')
        rows.append(rec); continue
    r = r.iloc[0]
    rec.update(status='ok', rec_value=r.estimate, rec_se=r.se, rec_z=r.z, rec_p=r.p, bench_p=r.bench_p,
               wild_p=r.get('wild_p'), n_rec=r.n_obs, n_countries=r.n_countries, n_surveys=r.n_surveys)
    h = half_unit(t.astra_printed)
    lo, hi = t.astra_value - h, t.astra_value + h
    dist = 0.0 if lo <= r.estimate <= hi else min(abs(r.estimate - lo), abs(r.estimate - hi))
    se = t.astra_se
    if se is None or (isinstance(se, float) and math.isnan(se)) or se <= 0:
        mag = 'not_audited'; dse = None
    else:
        dse = dist / se
        mag = 'within' if dse <= 1.5 else 'grey' if dse <= 3 else 'outside'
    rec.update(distance_pub_se=dse, magnitude=mag, relative_effect=(r.estimate / t.astra_value) if t.astra_value else None)
    pub_has_sign = not (lo <= 0 <= hi)
    if not pub_has_sign:
        sign = 'no_published_sign'
    elif np.sign(r.estimate) == np.sign(t.astra_value):
        sign = 'match'
    else:
        sign = 'mismatch' if abs(r.z) >= 1.645 else 'grey'
    pb, rb = pub_band(t.astra_stars), rec_band(r.p)
    if pb == 3:
        inf = 'outside' if rb == 0 else 'consistent'
    elif rb <= pb:
        inf = 'consistent' if (sign in ('match', 'no_published_sign')) else 'outside'
    else:
        inf = 'consistent' if rb - pb <= 1 else 'outside'
    bb = rec_band(r.wild_p if (t.model_id == 'M5' and isinstance(r.get('wild_p'), float) and not math.isnan(r.get('wild_p'))) else r.bench_p)
    rec.update(pub_band=pb, rec_band=rb, bench_band=bb, inference=inf, sign=sign)
    n_pub = nrow.get(t.model_id)
    nrel = abs(r.n_obs - n_pub) / n_pub if n_pub else None
    ncat = None if nrel is None else 'match' if nrel <= .05 else 'grey' if nrel <= .15 else 'mismatch'
    rec.update(n_pub=n_pub, n_rel_diff=nrel, n_status=ncat)
    impl_ok = True
    if agree is not None:
        a = agree[(agree.run_id == 'ORIGIN') & (agree.model == t.model_id) & (agree.term == t.term) & agree.deleted_country.isna()]
        impl_ok = bool(len(a)) and bool(a.agree.all())
    rec['implementations_agree'] = impl_ok
    crit = [mag, inf, 'outside' if sign == 'mismatch' else ('grey' if sign == 'grey' else 'ok')]
    if not impl_ok:
        out_ = 'indeterminate:implementation_disagreement'
    elif ncat == 'mismatch':
        out_ = 'indeterminate:incomplete_coverage'
    elif 'outside' in crit:
        out_ = 'discrepant_candidate'
    elif 'grey' in crit or ncat == 'grey':
        out_ = 'indeterminate:grey_zone'
    elif mag == 'not_audited':
        out_ = 'indeterminate:unavailable_magnitude_criterion'
    elif pb < 3 and bb is not None and bb - pb >= 2:
        out_ = 'fragile_inference'
    else:
        out_ = 'consistent'
    rec['outcome'] = out_
    rows.append(rec)
terms = pd.DataFrame(rows)
terms.to_csv(os.path.join(out, 'term_scores.csv'), index=False)

rules = json.load(open(os.path.join(S, 'reconciliation/frozen/scoring_rules.json')))
PREC = ['not_attemptable', 'indeterminate:implementation_disagreement', 'indeterminate:implementation_failure',
        'indeterminate:incomplete_coverage', 'discrepant_candidate', 'indeterminate:grey_zone',
        'indeterminate:unavailable_magnitude_criterion', 'fragile_inference', 'consistent']
GROUPS = {'F01': ('M3', ['female:leave', 'female:leave_sq']), 'F02': ('M3', ['female:childcare']),
          'F03': ('M3', ['female:parttime']), 'F04': ('M1', ['female']), 'F05': ('M4', ['female:childcare']),
          'F06': ('M4', ['female:parttime']), 'F07': ('M4', ['female:leave', 'female:leave_sq']),
          'F08': ('M5', ['female:leave', 'female:leave_sq']), 'F09': ('M6', ['female:leave', 'female:leave_sq']),
          'F10': ('M7', ['female:leave', 'female:leave_sq']), 'F11': ('M8', ['female:childcare']),
          'R01': ('R1', ['female:childcare']), 'R02': ('R2', ['female:childcare']), 'R03': ('R3', ['female:childcare'])}
claims = []
for gid, (m, ts) in GROUPS.items():
    sub = terms[(terms.model == m) & (terms.term.isin(ts))]
    outs = list(sub.outcome)
    o = min(outs, key=PREC.index) if outs else 'not_attemptable'
    claims.append(dict(claim=gid, model=m, terms=';'.join(ts), outcome=o, term_outcomes=';'.join(outs)))
# F12: remaining nonsignificant interactions in M5-M8
f12 = terms[((terms.model.isin(['M5', 'M6', 'M7'])) & terms.term.isin(['female:childcare', 'female:parttime'])) |
            ((terms.model == 'M8') & terms.term.isin(['female:parttime', 'female:leave', 'female:leave_sq']))]
claims.append(dict(claim='F12', model='M5-M8', terms='null interactions', outcome=min(f12.outcome, key=PREC.index),
                   term_outcomes=';'.join(f12.outcome)))
claims = pd.DataFrame(claims)
claims.to_csv(os.path.join(out, 'claim_scores.csv'), index=False)

hyp = {'H1': ['F02'], 'H2': ['F05', 'F06'], 'H3': ['F08', 'F09', 'F10', 'F11']}
hres = {h: min(claims.set_index('claim').loc[ids].outcome, key=PREC.index) for h, ids in hyp.items()}
vals = list(hres.values())
if any(v.startswith('indeterminate') or v == 'not_attemptable' for v in vals):
    paper = 'indeterminate'
elif any(v == 'discrepant_candidate' for v in vals):
    paper = 'indeterminate:awaiting_confirmation (discrepant_candidate)'
elif all(v == 'consistent' for v in vals):
    lower = claims[claims.claim.str.startswith('R')].outcome
    paper = 'partially reproduced' if any(lower == 'discrepant_candidate') else 'fully reproduced'
else:
    paper = 'not covered by mapping: ' + ','.join(vals)
json.dump(dict(hypothesis_outcomes=hres, paper_outcome=paper, rules_version=rules['version']),
          open(os.path.join(out, 'paper_score.json'), 'w'), indent=2)

if grid_path:
    g = pd.read_csv(grid_path, dtype={'deleted_country': str})
    focal = [(m, t) for gid, (m, ts) in GROUPS.items() if gid.startswith('F') for t in ts]
    rows = []
    for (m, t) in focal:
        pub = terms[(terms.model == m) & (terms.term == t)]
        if not len(pub):
            continue
        pv = pub.iloc[0].pub_value
        for kind, sel in [('uncertain', g.run_id.str.match(r'^U\d')), ('non_equivalent', g.run_id == 'N01'),
                          ('influence', g.deleted_country.notna() & (g.run_id.str.lower() == 'influence'))]:
            s = g[sel & (g.model == m) & (g.term == t)]
            ok = s[s.status == 'ok']
            if not len(s):
                continue
            rows.append(dict(model=m, term=t, set=kind, fits=len(s), ok=len(ok), failed=len(s) - len(ok),
                             sign_share_published=float((np.sign(ok.estimate) == np.sign(pv)).mean()) if len(ok) else None,
                             sig05_published_direction=float(((ok.p < .05) & (np.sign(ok.estimate) == np.sign(pv))).mean()) if len(ok) else None,
                             median=ok.estimate.median(), min=ok.estimate.min(), max=ok.estimate.max(),
                             p_min=ok.p.min(), p_max=ok.p.max(), published=pv,
                             published_position='inside' if len(ok) and ok.estimate.min() <= pv <= ok.estimate.max() else 'outside'))
    pd.DataFrame(rows).to_csv(os.path.join(out, 'set_summaries.csv'), index=False)
print(claims.to_string()); print(hres, paper)
