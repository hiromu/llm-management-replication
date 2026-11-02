"""Initial reader agreement: raw agreement and Gwet's AC1 over matched units."""
import json, collections
L = json.load(open('reconciliation/ledger_input_v1.json'))
def ac1(pairs, cats):
    n = len(pairs)
    if n == 0: return None, None, None
    pa = sum(a == b for a, b in pairs) / n
    pi = {k: (sum(a == k for a, _ in pairs) + sum(b == k for _, b in pairs)) / (2 * n) for k in cats}
    q = len(cats)
    pe = sum(p * (1 - p) for p in pi.values()) / (q - 1)
    return pa, pe, (pa - pe) / (1 - pe) if pe < 1 else None
out = {}
tiers = ['focal', 'identification_inference_diagnostic', 'robustness', 'descriptive', 'nuisance_control']
cp = [(u['fable'][1], u['astra'][1]) for u in L['claim_units'] if u['fable'] and u['astra']]
pa, pe, a = ac1(cp, tiers)
out['claim_tiers'] = dict(matched_units=len(cp), agreements=sum(x == y for x, y in cp), raw_agreement=pa, pe=pe, gwet_ac1=a,
    unmatched_fable_only=sum(1 for u in L['claim_units'] if u['fable'] and not u['astra']),
    unmatched_astra_only=sum(1 for u in L['claim_units'] if u['astra'] and not u['fable']),
    reader_claim_counts={'fable': 19, 'astra': 24},
    confusion=collections.Counter(f'{x}|{y}' for x, y in cp))
labels = ['origin', 'equivalent', 'non_equivalent', 'uncertain']
lp = [(p['fable'][1], p['astra'][1]) for p in L['level_pairs']]
pa, pe, a = ac1(lp, labels)
out['spec_labels'] = dict(matched_levels=len(lp), agreements=sum(x == y for x, y in lp), raw_agreement=pa, pe=pe, gwet_ac1=a,
    single_reader_levels=collections.Counter(s['reader'] for s in L['single_reader_levels']),
    confusion=collections.Counter(f'{x}|{y}' for x, y in lp),
    disagreements=[p['pair'] + ': ' + p['choice'] for p in L['level_pairs'] if p['fable'][1] != p['astra'][1]])
tr = json.load(open('reconciliation/transcription_agreement.json'))
out['transcription_tables_3_4'] = dict(cells=sum(tr['counts'].values()), agree=tr['counts'].get('agree', 0), differ=tr['counts'].get('differ', 0),
    note='Differing cell: Table 3 model 3 F for delta R2 stars; D1 image shows 3.953* (coordinator check of D1 page 15 at 300 dpi); Reader A matches D1.')
out['axes'] = {'fable': 22, 'astra': 22}
json.dump(out, open('reconciliation/initial_agreement.json', 'w'), indent=1)
print(json.dumps(out, indent=1))
