"""Initial reader agreement (before any clarification round). Mappings follow matching_rules_v1.md."""
import json, glob, re, os, sys
from collections import Counter
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
def out(r): return sorted(glob.glob(f'{ROOT}/readers/{r}/run_*'))[-1] + '/output/'
A = {c['claim_id']: c for c in json.load(open(out('fable') + 'claim_map.json'))['claims']}
B = {c['claim_id']: c for c in json.load(open(out('astra') + 'claim_map.json'))['claims']}

CLAIM_PAIRS = [('C01','C01'),('C02','C01'),('C03','C02'),('C04','C02'),('C05','C03'),('C06','C05'),
 ('C09','C04'),('C10','C04'),('C11','C18'),('C12','C11'),('C13','C16'),('C14','C06'),('C15','C07'),('C15','C08'),
 ('C16','C09'),('C17','C09'),('C18','C09'),('C19','C10'),('C20','C14'),('C21','C13'),('C22','C12'),('C24','C19'),
 ('C25','C19'),('C26','C22'),('C27','C23'),('C28','C21'),('C30','C17')]
UNMATCHED_A = sorted(set(A) - {a for a, _ in CLAIM_PAIRS})
UNMATCHED_B = sorted(set(B) - {b for _, b in CLAIM_PAIRS})
TIERS = ['focal','identification_inference_diagnostic','robustness','descriptive','nuisance_control']

def ac1(pairs, cats):
    n = len(pairs)
    if n == 0: return None, 'undefined (no pairs)'
    pa = sum(a == b for a, b in pairs) / n
    q = len(cats)
    pi = {k: (sum(a == k for a, _ in pairs) + sum(b == k for _, b in pairs)) / (2 * n) for k in cats}
    pe = sum(p * (1 - p) for p in pi.values()) / (q - 1)
    if pe == 1: return pa, 'undefined (pe=1)'
    return pa, (pa - pe) / (1 - pe)

res = {}
tier_pairs = [(A[a]['tier'], B[b]['tier']) for a, b in CLAIM_PAIRS]
pa, v = ac1(tier_pairs, TIERS)
res['claim_tier'] = {'pairs': len(tier_pairs), 'agree': sum(x == y for x, y in tier_pairs), 'raw_agreement': pa, 'gwet_ac1': v,
                     'unmatched_A': UNMATCHED_A, 'unmatched_B': UNMATCHED_B,
                     'disagreements': [(a, b, A[a]['tier'], B[b]['tier']) for a, b in CLAIM_PAIRS if A[a]['tier'] != B[b]['tier']]}
foc = [('focal' if x == 'focal' else 'non_focal', 'focal' if y == 'focal' else 'non_focal') for x, y in tier_pairs]
pa, v = ac1(foc, ['focal', 'non_focal'])
res['focal_binary'] = {'pairs': len(foc), 'agree': sum(x == y for x, y in foc), 'raw_agreement': pa, 'gwet_ac1': v}
# unique-claim view: collapse one-to-many by unique A claims
uniq = {}
for a, b in CLAIM_PAIRS: uniq.setdefault(a, (A[a]['tier'], B[b]['tier']))
pa, v = ac1(list(uniq.values()), TIERS)
res['claim_tier_unique_A_claims'] = {'pairs': len(uniq), 'agree': sum(x == y for x, y in uniq.values()), 'raw_agreement': pa, 'gwet_ac1': v}

# specification-level labels on matched levels (A level -> B level), labels as written by each reader
LEVEL_PAIRS = [('A03L0','A08L1'),('A03L2','A12L1'),('A04L0','A02L0'),('A05L0','A03L0'),('A05L2','A03L1'),('A06L0','A09L1'),
               ('A07L0','A15L0'),('A07L1','A15L1'),('A08L0','A10L0'),('A11L0','A14L0'),('A11L1','A14L1')]
def levels(r):
    s = json.load(open(out(r) + 'specification_space.json'))
    return {l['level_id']: l for a in s['axes'] for l in a['levels']}, s
LA, SA = levels('fable'); LB, SB = levels('astra')
lab = [(LA[a]['label'], LB[b]['label']) for a, b in LEVEL_PAIRS]
pa, v = ac1(lab, ['equivalent', 'non_equivalent', 'uncertain'])
res['level_labels'] = {'pairs': len(lab), 'agree': sum(x == y for x, y in lab), 'raw_agreement': pa, 'gwet_ac1': v,
                       'disagreements': [(a, b, LA[a]['label'], LB[b]['label']) for (a, b), (x, y) in zip(LEVEL_PAIRS, lab) if x != y]}
AXIS_PAIRS = [('A03','A08'),('A04','A02'),('A05','A03'),('A06','A09'),('A07','A15'),('A08','A10'),('A11','A14')]
def origin(s, ax): return [l['level_id'] for a in s['axes'] if a['axis_id'] == ax for l in a['levels'] if l['is_origin']]
same_origin = {('A03','A08'): False, ('A04','A02'): True, ('A05','A03'): True, ('A06','A09'): False,
               ('A07','A15'): True, ('A08','A10'): True, ('A11','A14'): True}  # semantic judgement recorded in ledger
res['axes'] = {'A_axes': len(SA['axes']), 'B_axes': len(SB['axes']), 'matched_axis_pairs': len(AXIS_PAIRS),
               'origin_agree': sum(same_origin.values()), 'origin_pairs': len(same_origin),
               'origins': {f'{a}/{b}': [origin(SA, a), origin(SB, b), same_origin[(a, b)]] for a, b in AXIS_PAIRS},
               'unmatched_A_axes': sorted(set(a['axis_id'] for a in SA['axes']) - {a for a, _ in AXIS_PAIRS}),
               'unmatched_B_axes': sorted(set(a['axis_id'] for a in SB['axes']) - {b for _, b in AXIS_PAIRS})}
pa, v = ac1([(x, y) for x, y in [('same', 'same') if s else ('A', 'B') for s in same_origin.values()]], ['same','A','B'])

# transcription agreement: Tables 4-6 hierarchy-table entries (marginal effects, p values, pseudo R2)
def norm(s):
    if s is None: return None
    s = str(s).replace('−', '-').replace('–', '-').replace(' ', '').strip('()')
    return s
TA = json.load(open(out('fable') + 'targets_sealed.json'))['targets']
TB = json.load(open(out('astra') + 'targets_sealed.json'))['targets']
MAPM = {**{f'M{i:02d}': f'M{i:02d}' for i in range(1, 13)}, **{f'M{16+i:02d}': f'M{12+i:02d}' for i in range(1, 9)}}
def rowkey(r):
    r = (r or '').lower()
    for k in ['officer x', 'officer×', 'officer ×', 'officer_x', 'officer * ']:
        if k in r: return 'officerxhier'
    keys = [('steepness', 'steep'), ('sameness', 'same'), ('hierarchy squared', 'mensq'), ('squared', 'mensq'),
            ('men in hierarchy', 'men'), ('japan', 'japan'), ('distance', 'dist'), ('length', 'length'), ('height', 'height'),
            ('age', 'age'), ('education', 'educ'), ('dependents', 'dep'), ('officer', 'officer'), ('pseudo', 'r2'), ('hierarchy', 'hier')]
    for k, v in keys:
        if k in r: return v
    return r
def key(t, mapm=None):
    m = t.get('model_id'); m = mapm.get(m, m) if mapm else m
    q = t.get('quantity'); val = norm(t.get('value_as_printed'))
    return m, rowkey(t.get('row')), q
def collect(T, mapm=None):
    d = {}
    for t in T:
        tab = str(t.get('table') or '').replace('Table ', '')
        if tab not in ('4', '5', '6'): continue
        m, r, q = key(t, mapm)
        rl = (t.get('row') or '').lower()
        if 'panel b' in rl or 'roc' in rl:
            m = {'M13':'M09','M14':'M10','M15':'M11','M16':'M12'}.get(t.get('model_id'), t.get('model_id')) if mapm is None else t.get('model_id')
            d[(m, r, 'roc_p')] = norm(t.get('value_as_printed')); continue
        if t.get('value_as_printed') in (None, '', 'blank'): continue
        if q in ('marginal_effect', 'coefficient'): d[(m, r, 'est')] = norm(t['value_as_printed'])
        if q == 'pseudo_r2': d[(m, r, 'r2')] = norm(t['value_as_printed'])
        if q in ('marginal_effect', 'coefficient') and t.get('p_printed_as'): d.setdefault((m, r, 'p'), norm(t['p_printed_as']))
        if q == 'p_value': d[(m, r, 'p')] = norm(t.get('value_as_printed'))
    return d
DA = collect(TA); DB = collect(TB, {v: k for k, v in MAPM.items()})
common = sorted(set(DA) & set(DB))
agree = [k for k in common if DA[k] == DB[k]]
res['transcription_tables_4_6'] = {'A_entries': len(DA), 'B_entries': len(DB), 'matched': len(common), 'exact_agree': len(agree),
    'disagreements': [(list(k), DA[k], DB[k]) for k in common if DA[k] != DB[k]],
    'only_A': [list(k) for k in sorted(set(DA) - set(DB))][:40], 'only_B': [list(k) for k in sorted(set(DB) - set(DA))][:40]}
json.dump(res, open(f'{ROOT}/reconciliation/initial_agreement_v1.json', 'w'), indent=2, default=str)
print(json.dumps({k: {kk: vv for kk, vv in v.items() if kk not in ('only_A', 'only_B', 'origins')} for k, v in res.items()}, indent=1, default=str))
