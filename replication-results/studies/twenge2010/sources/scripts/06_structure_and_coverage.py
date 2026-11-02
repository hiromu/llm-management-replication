"""Source role: structural checks (form identity, IDs, linkage, item presence) and coordinator-only coverage counts.
Outputs: registry/structure_check.json (reader-safe: no counts or distributions) and
         registry/coverage_internal.json (coordinator-only: row and non-missing counts).
Run: ~/.venv/bin/python -I 06_structure_and_coverage.py"""
import gzip, json, os, re, glob, datetime
import numpy as np, pandas as pd
STUDY = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
EX = os.path.join(STUDY, 'data', 'derived', 'extracts'); DI = os.path.join(STUDY, 'data', 'derived', 'dictionaries')
FORMS = {'1976': {'DS0001': 1, 'DS0002': 2, 'DS0003': 3, 'DS0004': 4, 'DS0005': 5, 'DS0006': 'core'},
         '1991': {'DS0001': 'core', 'DS0002': 1, 'DS0003': 2, 'DS0004': 3, 'DS0005': 4, 'DS0006': 5, 'DS0007': 6},
         '2006': {'DS0001': 'core', 'DS0002': 1, 'DS0003': 2, 'DS0004': 3, 'DS0005': 4, 'DS0006': 5, 'DS0007': 6}}
# Items named by the article's description of Forms 3 and 4 (located via MTF item reference numbers in the
# 2006 cross-time question index and the codebooks). Presence check only; no selection of the analysis set.
ITEMS = {'V3222': ('08050', 'A05A'), 'V3223': ('08060', 'A05B'), 'V3224': ('08070', 'A05C'), 'V3225': ('08080', 'A05D'),
         'V3226': ('08090', 'A05E'), 'V3227': ('08100', 'A06')}
for i, letter in enumerate('ABCDEFGHIJKLMNOPQRSTUVW'):
    ITEMS['V%d' % (4225 + i)] = ('%05d' % (10090 + 10 * i), 'A08' + letter)
ITEMS['V4263'] = ('08100', 'A14')
ADMIN = ['CASEID', 'V1', 'V3', 'V4', 'V5', 'V13', 'V16', 'V17']

def load(key):
    return pd.read_csv(os.path.join(EX, key + '.csv.gz'), dtype=float, keep_default_na=True)

def missing_mask(x, var):
    m = np.isnan(x)
    for v in var.get('declared_missing_values') or []:
        m |= (x == float(v))
    r = var.get('declared_missing_range')
    if r:
        hi = np.inf if r[1] == 'HIGHEST' else float(r[1])
        m |= (x >= float(r[0])) & (x <= hi)
    return m

struct = dict(created_utc=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'), files={}, linkage={}, items={})
cov = dict(note='Coordinator-only. Contains row and non-missing counts; never give to readers or implementers as targets.', files={})
data = {}
for key in sorted(k[:-7] for k in os.listdir(EX) if k.endswith('.csv.gz')):
    yr, ds = key.split('_'); form = FORMS[yr][ds]
    df = load(key); data[key] = df
    dic = {v['name']: v for v in json.load(open(os.path.join(DI, key + '.dictionary.json')))['variables']}
    s = dict(provider_form=form)
    v3 = df['V3'].dropna().unique()
    s['V3_form_id_constant_and_equals_form'] = (bool(len(v3) == 1 and v3[0] == form) if form != 'core' else None)
    s['V3_values_in_core_are_form_numbers_1_to_%d' % (5 if yr == '1976' else 6)] = (bool(set(v3) <= set(range(1, 7 if yr != '1976' else 6))) if form == 'core' else None)
    v1 = df['V1'].dropna().unique()
    s['V1_year_constant'] = bool(len(v1) == 1)
    s['V1_year_code'] = (float(v1[0]) if len(v1) == 1 else None)
    s['V4_serial_unique_within_file'] = bool(df['V4'].notna().all() and df['V4'].is_unique)
    if 'CASEID' in df: s['CASEID_unique_within_file'] = bool(df['CASEID'].is_unique)
    w = missing_mask(df['V5'].to_numpy(), dic['V5'])
    s['V5_weight_has_values_in_declared_missing_set'] = bool(w.any())
    s['V5_weight_positive_where_not_missing'] = bool((df['V5'][~w] > 0).all())
    s['admin_variables_present'] = [a for a in ADMIN if a in df.columns]
    s['school_or_PSU_identifier_present'] = False  # see registry notes: only region (V13), self-representing PSU flag (V16), SMSA/MSA flag (V17)
    s['icpsr_part_variable'] = [n for n, v in dic.items() if re.search(r'ICPSR PART', v.get('label') or '', re.I)]
    struct['files'][key] = s
    c = dict(rows=int(len(df)), columns=int(df.shape[1]), weight_missing_or_declared_missing=int(w.sum()))
    items = {}
    for name in ITEMS:
        if name in df.columns and form in (3, 4, 5):
            x = df[name].to_numpy(); m = missing_mask(x, dic[name])
            valid = [float(k) for k in (dic[name].get('value_labels') or {}) if not k.startswith('-')]
            oor = (~m) & ~np.isin(x, valid)
            items[name] = dict(nonmissing=int((~m).sum()), sysmis=int(np.isnan(x).sum()), declared_missing_codes=int((m & ~np.isnan(x)).sum()),
                               nonmissing_codes_outside_labelled_values=int(oor.sum()))
            s.setdefault('work_items_with_unlabelled_nonmissing_codes', [])
            if oor.any(): s['work_items_with_unlabelled_nonmissing_codes'].append(name)
    c['work_item_nonmissing'] = items
    cov['files'][key] = c

# linkage: are form-file serials found in the core file of the same year?
for yr in FORMS:
    core = [k for k, f in FORMS[yr].items() if f == 'core'][0]
    cs = set(data[f'{yr}_{core}']['V4'].dropna())
    allform = []
    for ds, f in FORMS[yr].items():
        if f == 'core': continue
        fs = set(data[f'{yr}_{ds}']['V4'].dropna()); allform.append(fs)
    union = set().union(*allform)
    disjoint = sum(len(a) for a in allform) == len(union)
    struct['linkage'][yr] = dict(core_dataset=core, form_serials_disjoint_across_forms=disjoint,
                                 every_form_serial_in_core=union <= cs, core_serials_equal_union_of_forms=(union == cs))
# item presence by year and form, with label code and codebook item number
for name, (item, qcode) in ITEMS.items():
    rec = {}
    for yr in FORMS:
        hits = []
        for ds, f in FORMS[yr].items():
            dic = {v['name']: v for v in json.load(open(os.path.join(DI, f'{yr}_{ds}.dictionary.json')))['variables']}
            if name in dic:
                v = dic[name]; cb = v.get('codebook') or {}
                lab = v.get('label') or ''
                hits.append(dict(dataset=ds, form=f, label=lab, label_has_question_code=qcode.replace(' ', '') in lab.replace(' ', ''),
                                 codebook_item_number=cb.get('item_number'),
                                 value_codes=sorted(k for k in (v.get('value_labels') or {}) if not k.startswith('-')),
                                 declared_missing=[v.get('declared_missing_values'), v.get('declared_missing_range')]))
        rec[yr] = hits
    struct['items'][name] = dict(mtf_item_reference=item, question_code=qcode, by_year=rec)
json.dump(struct, open(os.path.join(STUDY, 'registry', 'structure_check.json'), 'w'), indent=1, default=str)
json.dump(cov, open(os.path.join(STUDY, 'registry', 'coverage_internal.json'), 'w'), indent=1)
for k, s in struct['files'].items(): print(k, {a: b for a, b in s.items() if a not in ('admin_variables_present',)})
print(json.dumps(struct['linkage'], indent=0))
for n, r in struct['items'].items():
    print(n, r['question_code'], {yr: [(h['dataset'], h['form'], h['label_has_question_code'], h['codebook_item_number'], ''.join(h['value_codes'])) for h in hs] for yr, hs in r['by_year'].items()})
