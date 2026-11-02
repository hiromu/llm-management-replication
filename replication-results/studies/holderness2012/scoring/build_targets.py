"""Build the reconciled sealed target table (Tables 4-6) from Reader A's sealed transcription.
Reader B's transcription of these tables is identical (reconciliation/initial_agreement_v1.json: 248/248)."""
import json, glob, csv, os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
T = json.load(open(sorted(glob.glob(f'{ROOT}/readers/fable/run_*'))[-1] + '/output/targets_sealed.json'))['targets']
cols = {}
for i, (meas, grp, spec) in enumerate([(m, g, s) for m in ('steepness', 'sameness') for g in ('cap', 'camp') for s in ('simple', 'full')]):
    cols[f'M{i+1:02d}'] = ('T4', meas, grp, spec); cols[f'M{i+17:02d}'] = ('T6', meas, grp, spec)
for i, (grp, spec) in enumerate([(g, s) for g in ('cap', 'camp') for s in ('simple', 'full')]):
    cols[f'M{i+9:02d}'] = ('T5', 'both', grp, spec); cols[f'M{i+13:02d}'] = ('T5ROC', 'both', grp, spec)
ROW = {'Hierarchy': 'hierarchy', 'Officer x Hierarchy': 'officer_x_hierarchy', 'POW held by Japan': 'japan', 'Men in hierarchy': 'men',
       'Men in hierarchy squared': 'men_sq', 'Distance to Berlin or Tokyo': 'distance', 'Length of captivity': 'length', 'Height of POW': 'height',
       'Age of POW': 'age', 'Education of POW': 'education', 'POW has dependents': 'dependents', 'POW is officer': 'officer', 'Pseudo R2': 'pseudo_r2'}
out = []
for t in T:
    if t['table'] not in ('Table 4', 'Table 5', 'Table 6') or t['model_id'] not in cols: continue
    fam, meas, grp, spec = cols[t['model_id']]
    row = t['row']
    if fam in ('T5', 'T5ROC'):
        term = 'steepness' if 'Steepness' in row else 'sameness'
    else:
        if row not in ROW: continue
        term = ROW[row]
    out.append({'target_id': t['target_id'], 'claim_id': t['claim_id'], 'family': fam, 'measure': meas, 'group': grp, 'spec': spec, 'term': term,
                'quantity': t['quantity'], 'printed_value': t['value_as_printed'], 'printed_p': (t.get('p_printed_as') or '').strip('()'),
                'locator_pdf_page': t['locator'].get('pdf_page')})
with open(f'{ROOT}/sealed/targets_reconciled_tables4to6.csv', 'w', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(out[0])); w.writeheader(); w.writerows(out)
print(len(out), 'targets')
