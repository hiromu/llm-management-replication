"""Freeze sealed comparison targets from the agreed D1 transcription (Tables 3 and 4)."""
import json
tr = json.load(open('reconciliation/transcription_agreement.json'))
MODEL_MAP = {('3', '1'): 'org_M1', ('3', '2'): 'org_M2', ('3', '3'): 'org_M3', ('3', '4'): 'org_M4', ('3', '5'): 'org_M5',
             ('4', '6'): 'mkt_M6', ('4', '7'): 'mkt_M7', ('4', '8'): 'mkt_M8', ('4', '9'): 'mkt_M9', ('4', '10'): 'mkt_M10'}
TERM = {'staffing selectivity': 'STAFF', 'training': 'TRAIN', 'incentive': 'INCENT', 'grievance procedure': 'GRIEV',
        'decentralized decision making': 'DECENT', 'internal labor market': 'ILM', 'vertical hierarchy': 'VHIER',
        'training x staffing': 'TRAIN_x_STAFF', 'grievance x incentive compensation': 'GRIEV_x_INCENT',
        'internal labor market x decentralized decision making': 'ILM_x_DECENT', 'vertical hierarchy x decentralized decision making': 'VHIER_x_DECENT',
        'nonprofit organization': 'NONPROF', 'subsidiary': 'SUBSID', 'log of total employment': 'LOGEMP', 'log of firm age': 'LOGAGE',
        'percent managers': 'PCTMGR', 'union pressure': 'UNION', 'product': 'PRODUCT', 'service': 'SERVICE', 'competition': 'COMPET', 'constant': '(Intercept)'}
cells, unmapped = [], []
for r in tr['rows']:
    t, m, k = r['key']
    v = r['fable']
    if r['status'] != 'agree':
        assert r['key'] == ['3', '3', 'F_deltaR2']; v = dict(r['fable'])  # D1 image: 3.953*
    mid = MODEL_MAP[(t, m)]
    if k in ('R2', 'F', 'deltaR2', 'F_deltaR2', 'N'):
        cells.append(dict(model_id=mid, quantity=k, value=v['value'], stars=v['stars'] or '')); continue
    term = TERM.get(k)
    if term is None: unmapped.append(k); continue
    cells.append(dict(model_id=mid, quantity='coef', term=term, value=v['value'], se=v['se'], stars=v['stars'] or ''))
for c in cells:
    if c.get('term') in ('STAFF','TRAIN','INCENT','GRIEV','DECENT','ILM','VHIER','TRAIN_x_STAFF','GRIEV_x_INCENT','ILM_x_DECENT','VHIER_x_DECENT'):
        c['tier'] = 'focal_cell' if c['model_id'] not in ('org_M1', 'mkt_M6') else 'robustness_cell'
    elif c.get('term'): c['tier'] = 'nuisance_control'
    else: c['tier'] = 'diagnostic'
out = dict(version='v1', source='D1 (governs); agreed by both readers except one star resolved from D1 image',
           star_rule={'†': 'p<.10 one-tailed', '*': 'p<.05 one-tailed', '**': 'p<.01 one-tailed', '': 'p>=.10 one-tailed'},
           sealed_n={'org': 590, 'mkt': 373},
           d1_d2_differences='see readers/*/initial_v1/output/forensic.json and notes.md; D1 used throughout',
           cells=cells, unmapped_rows=unmapped)
json.dump(out, open('sealed/targets_frozen_v1.json', 'w'), indent=1)
print(len(cells), 'cells; unmapped', unmapped)
