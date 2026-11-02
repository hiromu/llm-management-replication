"""Merge both readers' Table 5 and Table 6 targets on a canonical key; write sealed reconciled targets.

Run: ~/.venv/bin/python -I reconciliation/reconcile_targets_v1.py <study_root>
"""
import json, sys, re

ROOT = sys.argv[1]
def load(w):
    return json.load(open(f"{ROOT}/readers/{w}/run1/out/targets_sealed.json"))['targets']

ROWS = {'total points': 'total_points', 'yards to go for 1st down': 'yards_first_down',
        'yards to go for touchdown': 'yards_touchdown', 'same division': 'same_division',
        'same conference': 'same_conference', 'home-field advantage': 'home_field',
        'week of season': 'week', 'minutes remaining': 'minutes_remaining',
        'performance (<=aspiration)': 'perf_below', 'performance^2 (<=aspiration)': 'perf_below_sq',
        'performance (>aspiration)': 'perf_above', 'indicator variable': 'below_indicator',
        'performance (<=aspiration) x minutes remaining': 'perf_below_x_min',
        'performance^2 (<=aspiration) x minutes remaining': 'perf_below_sq_x_min',
        'performance (>aspiration) x minutes remaining': 'perf_above_x_min',
        'log likelihood (ll)': 'loglik', 'lr chi2': 'lr_chi2', 'df': 'df', 'delta lr chi2': 'delta_lr_chi2'}
QTR = {'all quarters': 'all', '1st quarter': 'q1', '2nd quarter': 'q2', '3rd quarter': 'q3', '4th quarter': 'q4'}

def norm(s):
    s = str(s or '')
    for a, b in [('χ²', 'chi2'), ('≤', '<='), ('²', '^2'), ('×', 'x'), ('Δ', 'delta'), ('−', '-'), ('–', '-')]:
        s = s.replace(a, b)
    return re.sub(r'\s+', ' ', s).strip().lower()

def canon(t):
    tab = norm(t['table_or_figure'])
    if tab.startswith('table 5'):
        m = re.search(r'model (\d)', norm(t['model_label']))
        row = ROWS.get(norm(t['row_label']))
        if m and row:
            return f"T5|M{m.group(1)}|{row}"
    if tab.startswith('table 6'):
        r = norm(t['row_label'])
        q = next((v for k, v in QTR.items() if k in r), None)
        g = re.findall(r'-?\d+', r.split('=')[-1] if '=' in r else r.split(',')[-1])
        if q and g:
            return f"T6|{q}|gap{int(g[-1])}"
    return None

def num(s):
    s = norm(s).replace(',', '')
    m = re.search(r'-?\d+(\.\d+)?', s)
    return m.group(0) if m else None

def stars(t):
    s = norm(t.get('stars_or_inequality'))
    if s in ('', 'none', 'none printed'):
        s = re.sub(r'[^*+]', '', norm(t['value_as_printed'])) or 'none'
    return s.replace('none printed', 'none')

merged, issues = {}, []
by = {}
for w in ('fable', 'astra'):
    for t in load(w):
        k = canon(t)
        if k:
            by.setdefault(k, {})[w] = t
for k, d in sorted(by.items()):
    f, a = d.get('fable'), d.get('astra')
    rec = {'key': k, 'fable_id': f and f['target_id'], 'astra_id': a and a['target_id']}
    if f and a:
        same_v = num(f['value_as_printed']) == num(a['value_as_printed'])
        same_se = f.get('published_se') == a.get('published_se')
        same_st = stars(f) == stars(a)
        rec.update(value=num(f['value_as_printed']), published_se=f.get('published_se'), stars=stars(f),
                   quantity=f['quantity'], agree_value=same_v, agree_se=same_se, agree_stars=same_st,
                   source=f['source'])
        if not (same_v and same_se and same_st):
            issues.append(k)
            rec.update(fable_value=f['value_as_printed'], astra_value=a['value_as_printed'],
                       fable_se=f.get('published_se'), astra_se=a.get('published_se'),
                       fable_stars=stars(f), astra_stars=stars(a))
    else:
        t = f or a
        rec.update(value=num(t['value_as_printed']), published_se=t.get('published_se'), stars=stars(t),
                   quantity=t['quantity'], single_reader=('fable' if f else 'astra'), source=t['source'])
    merged[k] = rec

out = {'version': 'v1', 'sealed': True, 'scale_note': 'Table 5 values are odds ratios with parenthesised SEs (scale of SE not stated; both readers note delta-method odds-ratio SEs as the likely convention). Table 6 values are marginal effects on the probability scale with SEs.',
       'significance_key': '+ p<0.10; * p<0.05; ** p<0.01 (both readers; tail not stated)',
       'n_keys': len(merged), 'n_both': sum('single_reader' not in r for r in merged.values()),
       'n_disagree': len(issues), 'disagreements': issues, 'targets': merged}
json.dump(out, open(f"{ROOT}/sealed/targets_reconciled_v1.json", 'w'), indent=1, ensure_ascii=False)
print({k: out[k] for k in ('n_keys', 'n_both', 'n_disagree', 'disagreements')})
print([r['key'] for r in merged.values() if 'single_reader' in r])
