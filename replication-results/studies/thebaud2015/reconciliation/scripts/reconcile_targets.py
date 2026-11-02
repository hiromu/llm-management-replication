"""Compare the two readers' sealed regression targets (Tables 1, 2, A3) and build the reconciled target set.

Rows are matched on (table, model number, normalized row label, quantity). Only coefficient,
variance_component, fit_statistic and n_individuals/n_countries rows of the regression tables are compared.
Transcription agreement is a separate measure from interpretive agreement.
"""
import json, os, re, csv

S = os.path.join(os.path.dirname(__file__), '..', '..')


def norm_model(m):
    mm = re.search(r'Model\s*(\d)', m or '')
    return mm.group(1) if mm else None


def norm_label(s):
    s = (s or '').replace('’', "'").replace('×', 'x').lower()
    s = re.sub(r'^year of survey:\s*', '', s)
    s = re.sub(r'[^a-z0-9 x.]+', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


TABLES = {'Table 1', 'Table 2', 'Table A3'}
QUANT = {'coefficient', 'variance_component', 'fit_statistic', 'n_individuals', 'n_countries'}
data = {}
for r in ['fable', 'astra']:
    t = json.load(open(os.path.join(S, f'readers/{r}/initial_v1/output/sealed_targets.json')))
    d = {}
    for x in t:
        if x.get('table') not in TABLES or x.get('quantity') not in QUANT:
            continue
        k = (x['table'], norm_model(x.get('model_or_column')), norm_label(x.get('row_label')), x['quantity'])
        if k[1] is None:
            continue
        d.setdefault(k, x)
    data[r] = d

keys = sorted(set(data['fable']) | set(data['astra']), key=lambda k: (k[0], k[1], k[3], k[2]))
rows, n_both, n_agree = [], 0, 0
for k in keys:
    f, a = data['fable'].get(k), data['astra'].get(k)
    rec = dict(table=k[0], model=k[1], row=k[2], quantity=k[3],
               fable_value=f.get('value') if f else None, astra_value=a.get('value') if a else None,
               fable_se=f.get('published_se') if f else None, astra_se=a.get('published_se') if a else None,
               fable_stars=f.get('stars_or_p') if f else None, astra_stars=a.get('stars_or_p') if a else None,
               fable_printed=f.get('printed_value') if f else None, astra_printed=a.get('printed_value') if a else None,
               page=(f or a).get('page'), doc=(f or a).get('doc'))
    if f and a:
        n_both += 1
        same = (num(rec['fable_value']) == num(rec['astra_value']) and num(rec['fable_se']) == num(rec['astra_se'])
                and (rec['fable_stars'] or '').strip() == (rec['astra_stars'] or '').strip())
        rec['status'] = 'agree' if same else 'disagree'
        n_agree += same
    else:
        rec['status'] = 'fable_only' if f else 'astra_only'
    rows.append(rec)

out = os.path.join(S, 'reconciliation')
with open(os.path.join(out, 'target_transcription_ledger.csv'), 'w', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0]))
    w.writeheader(); w.writerows(rows)
summ = dict(rows=len(rows), both=n_both, agree=n_agree,
            disagree=sum(r['status'] == 'disagree' for r in rows),
            fable_only=sum(r['status'] == 'fable_only' for r in rows),
            astra_only=sum(r['status'] == 'astra_only' for r in rows))
json.dump(summ, open(os.path.join(out, 'target_transcription_agreement.json'), 'w'), indent=2)
print(summ)
for r in rows:
    if r['status'] != 'agree':
        print(r['status'], r['table'], r['model'], r['row'], r['quantity'], '| F:', r['fable_printed'], '| A:', r['astra_printed'])
