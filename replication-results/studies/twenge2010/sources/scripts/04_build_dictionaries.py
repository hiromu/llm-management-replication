"""Source role: build summary-free dictionaries for every supplied data file.

Variable metadata come from the SPSS files (via the R haven metadata dump, which is the only loader that exposes
declared missing values for .por files). Question wording comes from the ICPSR codebook PDFs (text extracted with
pdftotext -layout). Only question wording is taken from codebooks; all frequency tables, percentages, weighted Ns,
case counts and valid-code ranges are dropped.
Run: ~/.venv/bin/python -I 04_build_dictionaries.py <haven_dump_dir> <codebook_text_dir>
"""
import json, os, re, sys, glob, hashlib, datetime
STUDY = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
HAVEN, CB = sys.argv[1], sys.argv[2]
OUT = os.path.join(STUDY, 'data', 'derived', 'dictionaries')
os.makedirs(OUT, exist_ok=True)
SRC = {'1976': ('icpsr07927', 'ICPSR 7927 V4', 'data/supplied/ICPSR_07927/07927-Codebook.pdf'),
       '1991': ('icpsr09871', 'ICPSR 9871 V1', 'data/supplied/ICPSR_09871/09871-Codebook.pdf'),
       '2006': ('icpsr20022', 'ICPSR 20022 V3', 'data/supplied/ICPSR_20022/DS{ds}/20022-{ds}-Codebook.pdf')}
LABELS = {'1976': {'DS0001': 'Form 1 Questionnaire', 'DS0002': 'Form 2 Questionnaire', 'DS0003': 'Form 3 Questionnaire',
                   'DS0004': 'Form 4 Questionnaire', 'DS0005': 'Form 5 Questionnaire', 'DS0006': 'Core Variables'},
          '1991': {'DS0001': 'Core Data', 'DS0002': 'Form 1 Data', 'DS0003': 'Form 2 Data', 'DS0004': 'Form 3 Data',
                   'DS0005': 'Form 4 Data', 'DS0006': 'Form 5 Data', 'DS0007': 'Form 6 Data'}}
LABELS['2006'] = dict(LABELS['1991'])

def clean(lines):
    t = ' '.join(l.strip() for l in lines if l.strip())
    t = re.sub(r'\s+', ' ', t).strip()
    return t or None

PAGE = re.compile(r'^\s*(ICPSR 20022\s+MTF 2006.*|Page \d+\s+MTF 2006.*|page \d+\s*$|[ivxlc]+\s*$)', re.I)

# ---------------- 2006: one codebook per dataset ----------------
def parse_2006(path):
    L = open(path, encoding='utf-8', errors='replace').read().replace('\f', '').split('\n')
    start = next(i for i, l in enumerate(L) if re.match(r'^\s+FREQUENCIES\s*$', l) and i > 200)
    ent = {}; i = start
    hdr = re.compile(r'^\s{3,8}(CASEID|V\d+)\s{2,}(\S.*)$')
    while i < len(L):
        m = hdr.match(L[i])
        if not m: i += 1; continue
        name = m.group(1); j = i + 1; item = None; q = []; state = None; vls = []; mdc = None
        while j < len(L) and not hdr.match(L[j]):
            s = L[j].strip()
            if PAGE.match(L[j]) or s.startswith('APPENDI'): j += 1; continue
            if not s: j += 1; continue
            if s.startswith('Item Number:'):
                item = s.split(':', 1)[1].strip() or None; state = None
            elif s.startswith('Question Number(s):'):
                state = 'q'; q.append(s.split(':', 1)[1].strip())
            elif s.startswith('PCT') or 'cases (Wtd)' in s or s.startswith('Data type') or s.startswith('Columns:') or s.startswith('Decimals:'):
                state = None
            elif s.startswith('Missing-data code'):
                mdc = s.split(':', 1)[1].strip(); state = None
            elif state == 'q':
                if re.match(r'^-?\d+="', s): state = 'vl'; vls.append(s)
                else: q.append(s)
            elif state == 'vl':
                vls.append(s)
            j += 1
        ent[name] = dict(item_number=item, question_text=clean(q), codebook_missing_data_codes=mdc,
                         codebook_value_label_text=clean(vls))
        i = j
    return ent

# ---------------- 1991: one codebook, detailed section split by part ----------------
def parse_1991(path):
    L = open(path, encoding='utf-8', errors='replace').read().replace('\f', '').split('\n')
    # detailed listing begins at the second 'Part 1' heading (after the variable lists)
    part_starts = [i for i, l in enumerate(L) if re.match(r'^\s+Part [1-7]\s*$', l)]
    parts = {}
    for k, s in enumerate(part_starts):
        e = part_starts[k + 1] if k + 1 < len(part_starts) else len(L)
        parts['DS%04d' % (k + 1)] = (s, e)
    out = {}
    hdr = re.compile(r'^VAR\s+(\d+)\s+(\S.*?)\s+(NUMERIC|CHARACTER)\s*$')
    for ds, (s, e) in parts.items():
        ent = {}; i = s
        while i < e:
            m = hdr.match(L[i])
            if not m: i += 1; continue
            name = 'V' + m.group(1); j = i + 1; miss = None; q = []; item = None; under = False
            while j < e and not hdr.match(L[j]):
                t = L[j].strip()
                if t.startswith('REF ') : j += 1; continue
                if t.startswith('MISSING'): miss = t; j += 1; continue
                if PAGE.match(L[j]): j += 1; continue
                mi = re.match(r'^Item\s+(\d+)', t)
                if mi: item = mi.group(1); j += 1; continue
                if re.match(r'^-{5,}$', t): under = True; j += 1; continue
                if t.startswith('.....'): break
                if not under and t: q.append(t)
                j += 1
            q = [x for x in q if not x.startswith('<See Q.')]
            qt = clean(q)
            if qt:  # drop codebook-presentation notes about how percentages were tabulated
                qt = re.sub(r'\s*NOTE:\s*(Percentages|Frequencies)[^.]*\.', '', qt).strip() or None
            ent[name] = dict(item_number=item, question_text=qt, codebook_missing_data_codes=miss)
            i = j
        out[ds] = ent
    return out

# ---------------- 1976: one codebook; Q. entries, V line carries name ----------------
def parse_1976(path):
    """Parse 'Q.xxx :TEXT' / 'Vnnn TEXT' entries and 'Vnnn (X) TEXT pct' mark-all-that-apply rows.
    Value rows '(n) LABEL pct' and 'N(WTD)' lines are skipped; trailing percentage tokens are removed."""
    L = open(path, encoding='utf-8', errors='replace').read().replace('\f', '').split('\n')
    start = next(i for i, l in enumerate(L) if l.startswith('Q.B01'))
    qh = re.compile(r'^Q\.([A-Z]\d+[A-Z]?)\s*:(.*)$')
    mr = re.compile(r'^(V\d+)\s+(?:\(([A-Z0-9]+)\)|([A-Z]\d+[A-Z]?):([A-Z0-9]+))\s+(.*\S)\s{2,}(-|\d*\.\d+|\d+)\s*$')
    tablerow = re.compile(r'\S\s{3,}(-|\d*\.\d+)\s*$')
    vl = re.compile(r'^(V\d+)(?:\s+(.*\S))?\s*$')
    valrow = re.compile(r'^\s*\(\s*\d+\)')
    ent, stem = {}, {}
    code, qtext, mode, cur = None, [], None, None
    def close_q():
        if code and mode == 'qhead' and qtext:
            stem[code] = clean(qtext)
    for l in L[start:]:
        m = qh.match(l)
        if m:
            close_q()
            code, qtext, mode, cur = m.group(1), [m.group(2)], 'qhead', None
            continue
        if code is None or PAGE.match(l):
            continue
        m = mr.match(l)
        if m:
            cur = m.group(1); mode = 'mr'
            sub = '%s(%s)' % (code, m.group(2)) if m.group(2) else '%s(%s)' % (m.group(3), m.group(4))
            ent.setdefault(cur, dict(question_code=sub, question_stem=clean(qtext), question_text=m.group(5).strip()))
            continue
        if mode == 'qhead':
            m = vl.match(l)
            if m:
                cur = m.group(1); mode = 'qvar'
                if m.group(2): qtext.append(m.group(2))
                continue
            if valrow.match(l) or 'N(WTD)' in l or l.startswith('NOTE') or tablerow.search(l):
                mode = 'skip'; continue
            if re.match(r'^\s{5,}\S', l): qtext.append(l)
            continue
        if mode == 'qvar':
            if valrow.match(l) or 'N(WTD)' in l or not l.strip() or tablerow.search(l):
                base = re.match(r'^([A-Z]\d+)', code).group(1)
                ent.setdefault(cur, dict(question_code=code, question_text=clean(qtext),
                                         question_stem=stem.get(base) if base != code else None))
                mode = 'skip'; continue
            qtext.append(l); continue
        if mode == 'mr':
            if 'N(WTD)' in l or valrow.match(l) or tablerow.search(l): mode = 'skip'; continue
            if re.match(r'^\s{8,}\S', l) and cur in ent:
                ent[cur]['question_text'] = clean([ent[cur]['question_text'], l])
            continue
    return ent

def storage(fmt):
    if not fmt: return None
    m = re.match(r'^([A-Z]+)(\d+)(?:\.(\d+))?$', fmt)
    if not m: return dict(spss_format=fmt)
    return dict(spss_format=fmt, kind='numeric' if m.group(1) == 'F' else ('string' if m.group(1) == 'A' else m.group(1)),
                width=int(m.group(2)), decimals=int(m.group(3) or 0))

def as_list(v):
    v = [] if v is None else (v if isinstance(v, list) else [v])
    return list(dict.fromkeys(v))  # SPSS may declare the same discrete missing code twice

cb1991 = parse_1991(os.path.join(CB, '1991.txt'))
cb1976 = parse_1976(os.path.join(CB, '1976.txt'))
core1976 = {}
for n, e in cb1976.items():
    if re.match(r'^V\d{1,3}$', n): core1976[e['question_code']] = (n, e)

index = []
for mf in sorted(glob.glob(os.path.join(HAVEN, '*_meta.json'))):
    meta = json.load(open(mf)); key = meta['key']; yr, ds = key.split('_')
    if yr == '2006':
        cb = parse_2006(os.path.join(CB, f'2006_{ds}.txt')); cbsrc = SRC['2006'][2].format(ds=ds)
    elif yr == '1991':
        cb = cb1991.get(ds, {}); cbsrc = SRC['1991'][2]
    else:
        cb = cb1976; cbsrc = SRC['1976'][2]
    vars_out = []; nq = 0
    for v in meta['vars']:
        name = v['name']; c = cb.get(name); via = 'variable name' if c else None
        if yr == '1976' and c is None:
            mm = re.match(r'^76\d\s*([BC]\d+[A-Z]?)\s*:', v.get('label') or '')
            if mm and mm.group(1) in core1976:
                c = core1976[mm.group(1)][1]; via = 'core question %s (codebook variable %s)' % (mm.group(1), core1976[mm.group(1)][0])
        nr = v.get('na_range')
        rec = dict(name=name, label=v.get('label'), storage=storage(v.get('format_spss')),
                   value_labels=({str(int(x) if float(x).is_integer() else x): k for k, x in v['labels'].items()} if v.get('labels') else None),
                   declared_missing_values=as_list(v.get('na_values')) or None,
                   declared_missing_range=([nr[0], 'HIGHEST' if nr[1] == 'Inf' else nr[1]] if nr else None))
        if c:
            nq += 1 if c.get('question_text') else 0
            rec['codebook'] = {k: c.get(k) for k in ('item_number', 'question_code', 'question_stem', 'question_text', 'codebook_missing_data_codes', 'codebook_value_label_text') if c.get(k)}
            rec['codebook']['matched_by'] = via
        else:
            rec['codebook'] = None
        vars_out.append(rec)
    d = dict(dataset=key, survey_year=int(yr), provider_dataset_id=ds, provider_dataset_label=LABELS[yr][ds],
             source_id=SRC[yr][0], source_release=SRC[yr][1], data_file=meta['file'].split(STUDY + '/')[-1],
             extract='data/derived/extracts/%s.csv.gz' % key, codebook_source=cbsrc,
             n_variables=len(vars_out),
             variables_with_codebook_question_text=nq,
             summary_free=True,
             notes=['Value labels and declared missing values come from the SPSS file metadata (read with R haven, user_na=TRUE).',
                    'Question wording comes from the ICPSR codebook; frequencies, percentages, weighted Ns, case counts and valid-code ranges were removed.',
                    'declared_missing_range uses HIGHEST for an open upper bound (SPSS "x THRU HI").',
                    'codebook.matched_by states how the codebook entry was linked to the variable.'],
             variables=vars_out)
    jp = os.path.join(OUT, f'{key}.dictionary.json')
    json.dump(d, open(jp, 'w'), indent=1, ensure_ascii=False)
    # compact markdown
    md = [f'# {key}: MTF {yr} 12th grade, {ds} ({LABELS[yr][ds]})', '',
          f'Source: {SRC[yr][1]}, file {d["data_file"]}. Extract: {d["extract"]}. Codebook: {cbsrc}.', '',
          'Columns: name | label | storage | declared missing | value labels | question wording (codebook). Summary-free: no frequencies, percentages or counts.', '',
          '| name | label | storage | missing | value labels | question |', '|---|---|---|---|---|---|']
    def esc(x): return (x or '').replace('|', '/').replace('\n', ' ')
    for r in vars_out:
        miss = ', '.join(str(x) for x in (r['declared_missing_values'] or []))
        if r['declared_missing_range']: miss += (', ' if miss else '') + '%s thru %s' % tuple(r['declared_missing_range'])
        vl = '; '.join(f'{k}={v}' for k, v in (r['value_labels'] or {}).items())
        cbq = ''
        if r['codebook']:
            parts = []
            if r['codebook'].get('item_number'): parts.append('[item %s]' % r['codebook']['item_number'])
            if r['codebook'].get('question_stem'): parts.append(r['codebook']['question_stem'] + ' /')
            if r['codebook'].get('question_text'): parts.append(r['codebook']['question_text'])
            cbq = ' '.join(parts)
        md.append(f"| {r['name']} | {esc(r['label'])} | {esc((r['storage'] or {}).get('spss_format'))} | {esc(miss)} | {esc(vl)} | {esc(cbq)} |")
    open(os.path.join(OUT, f'{key}.dictionary.md'), 'w').write('\n'.join(md) + '\n')
    index.append((key, len(vars_out), nq))
    print(key, len(vars_out), 'with question text', nq)
