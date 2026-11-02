"""Machine-readable exports for thebaud2015, generated from saved outputs only.

Usage (from the study root): ~/.venv/bin/python reports/exports/build_exports.py
Writes reports/exports/{claim_comparisons.csv, term_comparisons.csv, specification_results.csv,
influence_results.csv, uncertain_set_substantive.csv, fit_counts.json, paper_record.json}.
"""
import json, os
import numpy as np, pandas as pd

S = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(S, 'reports', 'exports')
p = lambda *a: os.path.join(S, *a)

claims = pd.read_csv(p('scoring/final_v1/claim_scores.csv'))
terms = pd.read_csv(p('scoring/final_v1/term_scores.csv'))
org = pd.read_csv(p('runs/exec_v1/ORIGIN_A/results.csv'), dtype={'deleted_country': str})
orgB = pd.read_csv(p('runs/exec_v1/ORIGIN_B/results.csv'), dtype={'deleted_country': str})
grid = pd.read_csv(p('runs/exec_v1/GRID_A_combined.csv'), dtype={'deleted_country': str})

# Adversarial review classifications (post hoc; they never change a frozen score)
ADV = {'F05': ('(a) plan-B coding', '(d) U09 plausible, undocumented'),
       'F06': ('(c) survives', '(d) unresolved; U18 two-year lag within criteria'),
       'F09': ('(d) unresolved', '(d) unresolved'),
       'R01': ('(b) childcare concept differs', 'not reviewed')}
claims['adversarial_review_claude'] = claims.claim.map(lambda c: ADV.get(c, ('', ''))[0])
claims['adversarial_review_astra'] = claims.claim.map(lambda c: ADV.get(c, ('', ''))[1])
claims['fully_verified_discrepancy'] = np.where(claims.outcome == 'discrepant_candidate',
                                              'withheld: no family-independent adversarial review', '')
claims['implementations'] = 'A (R lme4) scored; B (R lme4) agrees on all ORIGIN terms'
claims.to_csv(os.path.join(OUT, 'claim_comparisons.csv'), index=False)
terms.to_csv(os.path.join(OUT, 'term_comparisons.csv'), index=False)

LABEL = {r: 'uncertain' for r in grid.run_id.unique() if str(r).startswith('U')}
LABEL['N01'] = 'non_equivalent'
REEXPR = {'U14': 'algebraic re-expression (separately standardized leave squared)',
          'U15': 'algebraic re-expression (country-mean standardization constants)',
          'U16': 'algebraic re-expression (individual-level standardization constants)'}
spec = pd.concat([org.assign(implementation='A'), orgB.assign(implementation='B'),
                  grid[~(grid.run_id.str.lower() == 'influence')].assign(implementation='A')])
spec['set'] = spec.run_id.map(lambda r: 'origin' if r == 'ORIGIN' else LABEL.get(r, ''))
spec['fit_class'] = spec.run_id.map(lambda r: REEXPR.get(r, 'substantive'))
spec.loc[(spec.run_id == 'U08'), 'fit_class'] = 'realized duplicate of origin (identical sample and estimates)'
spec.loc[(spec.run_id == 'N01') & (spec.model == 'M8'), 'fit_class'] = 'algebraic re-expression (no 2001-2002 surveys in M8; only constants change)'
spec.to_csv(os.path.join(OUT, 'specification_results.csv'), index=False)

inf = grid[grid.run_id.str.lower() == 'influence']
inf.to_csv(os.path.join(OUT, 'influence_results.csv'), index=False)

# Substantive uncertain set: excludes algebraic re-expressions and realized duplicates (scoring.md)
FOCAL = [('M3', 'female:leave'), ('M3', 'female:leave_sq'), ('M3', 'female:childcare'), ('M3', 'female:parttime'),
         ('M4', 'female:childcare'), ('M4', 'female:parttime'), ('M4', 'female:leave'), ('M4', 'female:leave_sq'),
         ('M5', 'female:leave'), ('M5', 'female:leave_sq'), ('M6', 'female:leave'), ('M6', 'female:leave_sq'),
         ('M7', 'female:leave'), ('M7', 'female:leave_sq'), ('M8', 'female:childcare')]
u = spec[(spec.implementation == 'A') & (spec.set == 'uncertain') & (spec.fit_class == 'substantive')]
rows = []
for m, t in FOCAL:
    s = u[(u.model == m) & (u.term == t) & (u.status == 'ok')]
    pv = terms[(terms.model == m) & (terms.term == t)].pub_value.iloc[0]
    o = org[(org.model == m) & (org.term == t)].iloc[0]
    conv = s.converged.astype(str) == 'True'
    rows.append(dict(model=m, term=t, fits=len(s), nonconverged=int((~conv).sum()), published=pv, origin=o.estimate,
                     origin_p=o.p, sign_share_published=float((np.sign(s.estimate) == np.sign(pv)).mean()),
                     sig05_published_direction=float(((s.p < .05) & (np.sign(s.estimate) == np.sign(pv))).mean()),
                     median=s.estimate.median(), min=s.estimate.min(), max=s.estimate.max(),
                     run_of_min=s.loc[s.estimate.idxmin(), 'run_id'], run_of_max=s.loc[s.estimate.idxmax(), 'run_id'],
                     p_min=s.p.min(), p_max=s.p.max(),
                     published_position='inside' if s.estimate.min() <= pv <= s.estimate.max() else 'outside'))
pd.DataFrame(rows).to_csv(os.path.join(OUT, 'uncertain_set_substantive.csv'), index=False)

fits = spec.drop_duplicates(['implementation', 'run_id', 'model'])
fa = fits[fits.implementation == 'A']
infl = inf.drop_duplicates(['model', 'deleted_country'])
counts = dict(
    origin_fits=dict(A=int((fa.run_id == 'ORIGIN').sum()), B=int((fits[fits.implementation == 'B'].run_id == 'ORIGIN').sum()),
                     C='terminated by user before saving estimates; M1-M8 sample counts match A and B'),
    deviation_fits_A=int((fa.set.isin(['uncertain', 'non_equivalent'])).sum()),
    uncertain_substantive=int(((fa.set == 'uncertain') & (fa.fit_class == 'substantive')).sum()),
    uncertain_algebraic_reexpression=int(((fa.set == 'uncertain') & fa.fit_class.str.startswith('algebraic')).sum()),
    uncertain_realized_duplicate=int(((fa.set == 'uncertain') & fa.fit_class.str.startswith('realized')).sum()),
    non_equivalent_fits=int((fa.set == 'non_equivalent').sum()),
    non_equivalent_reexpression=int(((fa.set == 'non_equivalent') & fa.fit_class.str.startswith('algebraic')).sum()),
    equivalent_fits=0,
    deviation_nonconverged=int((fa[fa.set.isin(['uncertain', 'non_equivalent'])].converged.astype(str) != 'True').sum()),
    deviation_failed=int((fa[fa.set.isin(['uncertain', 'non_equivalent'])].status != 'ok').sum()),
    influence_refits=int(len(infl)), influence_failed=int((infl.status != 'ok').sum()),
    influence_nonconverged=int((infl.converged.astype(str) != 'True').sum()),
    influence_singular=int((infl.singular.astype(str) == 'True').sum()),
    unavailable=['U21 (survey weights): weighted three-level mixed models not supported by the executed routines'],
)
json.dump(counts, open(os.path.join(OUT, 'fit_counts.json'), 'w'), indent=2)

paper = json.load(open(p('scoring/final_v1/paper_score.json')))
paper.update(study_id='thebaud2015', doi='10.1177/0001839215591627', execution='exec_v1',
             scoring_rules='reconciliation/frozen/scoring_rules.json v1 with addenda v1.1 and v1.2',
             specification_fragility='not assessed (equivalent set empty)',
             adversarial_review=['audits/adversarial_v1/review.md (Claude Opus 5.5)',
                                 'audits/adversarial_astra_v1/review.md (GPT-6 Astra)'],
             fully_verified_discrepancy='withheld: no adversarial reviewer from a model family independent of every implementer (workflow.md section 6)',
             implementation_agreement='A-B 276/276 ORIGIN terms; C stopped at user direction (runs/exec_v1/unexecuted_runs.json); deviation and influence grid from A only',
             memorization='both reader models recognized the article and its argument; neither recalled numeric results',
             calibration='corpus-level calibration arms not performed in this session')
json.dump(paper, open(os.path.join(OUT, 'paper_record.json'), 'w'), indent=2)
print(json.dumps(counts, indent=1))
print(pd.DataFrame(rows).round(3).to_string())
