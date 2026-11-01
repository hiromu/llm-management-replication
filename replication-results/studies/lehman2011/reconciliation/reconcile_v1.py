"""Reconciliation v1: ledger and initial agreement statistics (rules_v1.md).

Run: ~/.venv/bin/python -I reconciliation/reconcile_v1.py <study_root>
The item matches below were coded by the coordinator from both readers' sealed run1 outputs,
following the matching rules in rules_v1.md. Labels are read from the reader files, not retyped.
"""
import json, sys, re, unicodedata, collections, datetime

ROOT = sys.argv[1]
def load(who, f):
    return json.load(open(f"{ROOT}/readers/{who}/run1/out/{f}"))

F, A = 'fable', 'astra'
cm = {w: {c['claim_id']: c for c in load(w, 'claim_map.json')['claims']} for w in (F, A)}
mf = {w: load(w, 'manifest.json') for w in (F, A)}
ss = {w: load(w, 'spec_space.json') for w in (F, A)}
tg = {w: load(w, 'targets_sealed.json')['targets'] for w in (F, A)}

def var(w, name):
    return next(v for v in mf[w]['variables'] if v['name'] == name)
def step(w, n):
    return next(s for s in mf[w]['sample_steps'] if s['step'] == n)
def level(w, lid):
    for a in ss[w]['axes']:
        for l in a['levels']:
            if l['level_id'] == lid:
                return l
    raise KeyError(lid)

# ---- matched items (fable id, astra id, note) ----
CLAIMS = [('C1', 'C2', 'H1A'), ('C2', 'C3', 'H1B'), ('C3', 'C4', 'H2'), ('C4', 'C5', 'H3'),
          ('C5', 'C9', 'situational controls; fable splits minutes into C6'),
          ('C7', 'C10', 'model fit and LR improvement; fable splits M3 into C9'),
          ('C8', 'C11', 'below vs above aspiration difference test'),
          ('C10', 'C15', 'unexpected first-quarter finding just below aspiration'),
          ('C11', 'C7', 'quarters-remaining robustness'),
          ('C12', 'C18', 'alternative aspiration and separate-choice robustness; astra splits into C18, C19'),
          ('C13', 'C6', 'fourth-down choice context'),
          ('C14', 'C8', 'conversion attempts per game and timing')]
CLAIMS_UNMATCHED = {F: ['C6', 'C9', 'C15', 'C16', 'C17'], A: ['C1', 'C12', 'C13', 'C14', 'C16', 'C17', 'C19']}

VARS = [('risk_taking', 'risk_taking'), ('performance', 'performance_gap'), ('perf_below', 'performance_below'),
        ('perf_below_sq', 'performance_below_sq'), ('perf_above', 'performance_above'),
        ('below_indicator', 'below_indicator'), ('minutes_remaining', 'minutes_remaining'),
        ('perf_below_x_min', 'below_x_time'), ('perf_below_sq_x_min', 'below_sq_x_time'),
        ('perf_above_x_min', 'above_x_time'), ('total_points', 'total_points'),
        ('yards_to_go_first_down', 'yards_first_down'), ('yards_to_go_touchdown', 'yards_touchdown'),
        ('same_division', 'same_division'), ('same_conference', 'same_conference'),
        ('home_field', 'home_field'), ('week_of_season', 'season_week'), ('team_fe', 'offense_team'),
        ('year_fe', 'season_effect')]
VARS_UNMATCHED = {F: [], A: ['quarters_remaining', 'recent_spread_aspiration', 'within_field_goal_range']}
STEPS = [(1, 1, 'regular season, 2000-2005'), (3, 4, 'decision-play classification'), (4, 3, 'exclude overtime'),
         (5, 5, 'exclude last two minutes'), (6, 2, 'join games file, team-code mapping'),
         (7, 7, 'missing data')]
STEPS_UNMATCHED = {F: [2, 8], A: [6]}

LEVELS = [('A2.1', 'A1.1', 'keep a play at exactly 2:00'),
          ('A1.1', 'A2.1', 'include nullified fourth-down plays with an identifiable choice'),
          ('A3.2', 'A3.1', 'quarters remaining in place of minutes remaining'),
          ('A5.1', 'A5.1', 'unconditional logit with team and season dummies')]
LEVELS_UNMATCHED = {F: ['A1.2', 'A3.1', 'A4.1', 'A5.2', 'A5.3', 'A6.1', 'A6.2', 'A7.1', 'A7.2', 'A7.3', 'A8.1'],
                    A: ['A3.2', 'A4.1', 'A6.1', 'A7.1', 'A8.1', 'A9.1', 'A10.1', 'A10.2']}

def ac1(pairs, cats):
    n = len(pairs)
    if n < 2:
        return {'n': n, 'pa': None, 'ac1': None, 'note': 'undefined (n<2)'}
    pa = sum(a == b for a, b in pairs) / n
    q = len(cats)
    pis = {k: (sum(a == k for a, _ in pairs) + sum(b == k for _, b in pairs)) / (2 * n) for k in cats}
    pe = sum(p * (1 - p) for p in pis.values()) / (q - 1)
    val = None if pe == 1 else (pa - pe) / (1 - pe)
    return {'n': n, 'agree': sum(a == b for a, b in pairs), 'pa': round(pa, 4), 'pe': round(pe, 4),
            'ac1': None if val is None else round(val, 4)}

ledger = []
tier_pairs, type_pairs = [], []
for f, a, note in CLAIMS:
    cf, ca = cm[F][f], cm[A][a]
    tier_pairs.append((cf['tier'], ca['tier'])); type_pairs.append((cf['type'], ca['type']))
    ledger.append({'kind': 'claim', 'fable': f, 'astra': a, 'note': note, 'fable_tier': cf['tier'], 'astra_tier': ca['tier'],
                   'fable_type': cf['type'], 'astra_type': ca['type'],
                   'decision': 'agree' if cf['tier'] == ca['tier'] else 'tier disagreement -> uncertain tier; both retained'})
for w, ids in CLAIMS_UNMATCHED.items():
    for i in ids:
        ledger.append({'kind': 'claim', w: i, 'note': cm[w][i]['statement'][:160], 'tier': cm[w][i]['tier'],
                       'decision': 'unmatched; retained (union)'})

cert_pairs = []
for f, a in VARS:
    vf, va = var(F, f), var(A, a)
    cert_pairs.append((vf['certainty'], va['certainty']))
    ledger.append({'kind': 'variable', 'fable': f, 'astra': a, 'fable_certainty': vf['certainty'], 'astra_certainty': va['certainty'],
                   'fable_definition': vf['definition'], 'astra_definition': va['definition']})
for w, ids in VARS_UNMATCHED.items():
    for i in ids:
        ledger.append({'kind': 'variable', w: i, 'decision': 'unmatched; retained (union)', 'definition': var(w, i)['definition']})
for f, a, note in STEPS:
    sf, sa = step(F, f), step(A, a)
    cert_pairs.append((sf['certainty'], sa['certainty']))
    ledger.append({'kind': 'sample_step', 'fable': f, 'astra': a, 'note': note, 'fable_certainty': sf['certainty'],
                   'astra_certainty': sa['certainty'], 'fable_rule': sf['rule'], 'astra_rule': sa['rule']})
for w, ids in STEPS_UNMATCHED.items():
    for i in ids:
        ledger.append({'kind': 'sample_step', w: i, 'decision': 'unmatched; retained (union)', 'rule': step(w, i)['rule']})

lab_pairs = []
for f, a, note in LEVELS:
    lf, la = level(F, f), level(A, a)
    lab_pairs.append((lf['label'], la['label']))
    ledger.append({'kind': 'spec_level', 'fable': f, 'astra': a, 'note': note, 'fable_label': lf['label'], 'astra_label': la['label'],
                   'reconciled_label': lf['label'] if lf['label'] == la['label'] else 'uncertain',
                   'fable_rationale': lf.get('rationale'), 'astra_rationale': la.get('rationale')})
for w, ids in LEVELS_UNMATCHED.items():
    for i in ids:
        l = level(w, i)
        ledger.append({'kind': 'spec_level', w: i, 'label': l.get('label'), 'description': l['description'],
                       'decision': 'unmatched; retained (union)'})

# ---- transcription agreement on targets ----
SUBS = [('≤', '<='), ('²', '^2'), ('×', 'x'), ('χ²', 'chi2'), ('χ2', 'chi2'), ('Δ', 'delta'), ('−', '-'), ('–', '-'), ('—', '-')]
def norm(s):
    s = '' if s is None else str(s)
    for a, b in SUBS:
        s = s.replace(a, b)
    s = unicodedata.normalize('NFKC', s).lower()
    return re.sub(r'\s+', ' ', s).strip()
def key(t):
    return (norm(t['table_or_figure']), norm(t['model_label']), norm(t['row_label']), norm(t['quantity']))
def numeric(s):
    s = norm(s).replace(',', '').replace('*', '').replace('†', '')
    m = re.search(r'-?\d+(\.\d+)?', s)
    return m.group(0) if m else s
idx = {w: collections.defaultdict(list) for w in (F, A)}
for w in (F, A):
    for t in tg[w]:
        idx[w][key(t)].append(t)
common = [k for k in idx[F] if k in idx[A] and len(idx[F][k]) == 1 and len(idx[A][k]) == 1]
strict = sum(norm(idx[F][k][0]['value_as_printed']) == norm(idx[A][k][0]['value_as_printed']) for k in common)
num = [(k, idx[F][k][0]['value_as_printed'], idx[A][k][0]['value_as_printed']) for k in common]
num_agree = [x for x in num if numeric(x[1]) == numeric(x[2])]
num_disagree = [x for x in num if numeric(x[1]) != numeric(x[2])]
se_pairs = [(idx[F][k][0].get('published_se'), idx[A][k][0].get('published_se')) for k in common]

stats = {
    'computed_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds'),
    'stage': 'initial (before any clarification round)',
    'claim_tier': ac1(tier_pairs, ['focal', 'identification_inference_diagnostic', 'robustness', 'descriptive', 'nuisance_control']),
    'claim_type': ac1(type_pairs, ['hypothesis', 'stated_finding', 'robustness_claim', 'descriptive_claim']),
    'manifest_certainty': ac1(cert_pairs, ['explicit', 'inferred', 'unclear']),
    'equivalence_label': ac1(lab_pairs, ['equivalent', 'non_equivalent', 'uncertain']),
    'structural_coverage': {
        'claims': {'matched': len(CLAIMS), 'fable_only': len(CLAIMS_UNMATCHED[F]), 'astra_only': len(CLAIMS_UNMATCHED[A]),
                   'fable_total': len(cm[F]), 'astra_total': len(cm[A])},
        'variables': {'matched': len(VARS), 'fable_only': 0, 'astra_only': len(VARS_UNMATCHED[A])},
        'sample_steps': {'matched': len(STEPS), 'fable_only': len(STEPS_UNMATCHED[F]), 'astra_only': len(STEPS_UNMATCHED[A])},
        'spec_levels_non_origin': {'matched': len(LEVELS), 'fable_only': len(LEVELS_UNMATCHED[F]), 'astra_only': len(LEVELS_UNMATCHED[A])},
        'models': {'fable': len(mf[F]['models']), 'astra': len(mf[A]['models']), 'same_regressor_lists': True}},
    'transcription': {
        'fable_targets': len(tg[F]), 'astra_targets': len(tg[A]), 'matched_keys': len(common),
        'strict_value_as_printed_agreement': strict,
        'numeric_value_agreement_ignoring_stars_and_commas': len(num_agree),
        'numeric_disagreements': [{'key': list(k), 'fable': a, 'astra': b} for k, a, b in num_disagree],
        'published_se_agreement': sum(a == b for a, b in se_pairs),
        'note': 'strict comparison follows rules_v1 normalisation; fable embeds significance stars in value_as_printed and astra records them separately, so the numeric comparison (added after seeing that formatting difference, not after any result) is reported alongside.'}
}
json.dump({'ledger': ledger}, open(f"{ROOT}/reconciliation/ledger_v1.json", 'w'), indent=1, ensure_ascii=False)
json.dump(stats, open(f"{ROOT}/reconciliation/initial_agreement_v1.json", 'w'), indent=1, ensure_ascii=False)
print(json.dumps(stats, indent=1, ensure_ascii=False)[:4000])
