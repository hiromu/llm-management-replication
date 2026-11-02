"""Compare the two readers' transcriptions of regression-table targets (Tables 3 and 4)."""
import json, re, collections
def norm_row(s):
    s = s.lower().replace('×', 'x').replace('–', '-')
    s = re.sub(r'[^a-z0-9 x]', ' ', s)
    s = re.sub(r'\s+', ' ', s).strip()
    aliases = {'competitive pressure': 'competition', 'market competition': 'competition',
               'incentive compensation': 'incentive', 'incentive': 'incentive'}
    for k, v in aliases.items():
        if s == k: return v
    s = s.replace('selective staffing', 'staffing')
    return s
def load(r):
    T = json.load(open(f'readers/{r}/initial_v1/output/targets.json'))['targets']
    out = {}
    for t in T:
        if str(t.get('table')) not in ('3', '4'): continue
        if (t.get('locator') or {}).get('doc_id') == 'D2': continue  # D1 governs; D2 variants compared separately
        q = t.get('quantity')
        if q in ('coef', 'constant'):
            key = (str(t['table']), str(t['model']).replace('Model', '').strip(), norm_row(t['row']) if q == 'coef' else 'constant')
            out[key] = dict(value=t.get('value'), se=t.get('se'), stars=(t.get('stars') or '').replace('t', '†').strip())
        elif q in ('R2', 'F', 'deltaR2', 'F_deltaR2', 'N'):
            key = (str(t['table']), str(t['model']).replace('Model', '').strip(), q)
            out[key] = dict(value=t.get('value'), se=None, stars=(t.get('stars') or '').strip())
    return out
A, B = load('fable'), load('astra')
keys = sorted(set(A) | set(B))
rows = []; c = collections.Counter()
for k in keys:
    a, b = A.get(k), B.get(k)
    if a is None or b is None:
        rows.append(dict(key=k, status='only_' + ('astra' if a is None else 'fable'), fable=a, astra=b)); c['unmatched'] += 1; continue
    same_v = a['value'] == b['value']; same_se = a['se'] == b['se']; same_s = a['stars'] == b['stars']
    st = 'agree' if (same_v and same_se and same_s) else 'differ'
    c[st] += 1
    rows.append(dict(key=k, status=st, fable=a, astra=b, value_agree=same_v, se_agree=same_se, stars_agree=same_s))
json.dump(dict(counts=c, rows=rows), open('reconciliation/transcription_agreement.json', 'w'), indent=1, default=str)
print(c)
for r in rows:
    if r['status'] != 'agree': print(r['status'], r['key'], r['fable'], r['astra'])
