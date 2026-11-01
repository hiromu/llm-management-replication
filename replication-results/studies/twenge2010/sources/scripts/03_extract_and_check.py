"""Source role: write raw-code extracts of every supplied SPSS file and check loader equivalence.

Inputs: data/supplied/**-Data.(por|sav) (read-only) and the R haven dumps written by 02_haven_dump.R.
Outputs: data/derived/extracts/<year>_<DS>.csv.gz + .json sidecar, registry/loader_check.json.
Run: ~/.venv/bin/python -I 03_extract_and_check.py <haven_dump_dir>
"""
import csv, glob, gzip, hashlib, io, json, math, os, sys, datetime, platform
import numpy as np, pandas as pd, pyreadstat

STUDY = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
HAVEN = sys.argv[1]
OUT = os.path.join(STUDY, 'data', 'derived', 'extracts')
os.makedirs(OUT, exist_ok=True)
YEAR = {'07927': '1976', '09871': '1991', '20022': '2006'}

def sha256(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()

def read_dump(path):
    """Read an R %.17g dump with exact (correctly rounded) float parsing."""
    with gzip.open(path, 'rt', newline='') as f:
        r = csv.reader(f)
        names = next(r)
        cols = [[] for _ in names]
        for row in r:
            for i, v in enumerate(row):
                cols[i].append(float(v) if v != '' else math.nan)
    return names, {n: np.array(c, dtype=float) for n, c in zip(names, cols)}

def eq(a, b):
    return (a == b) | (np.isnan(a) & np.isnan(b))

def as_list(v):
    if v is None: return []
    return v if isinstance(v, list) else [v]

def in_declared(x, spec):
    vals = as_list(spec.get('na_values'))
    rng = spec.get('na_range')
    m = np.zeros_like(x, dtype=bool)
    for v in vals:
        m |= (x == float(v))
    if rng:
        lo, hi = norm_rng(rng)
        m |= (x >= lo) & (x <= hi)
    return m

def norm_rng(r):
    if r is None: return None
    return [(-math.inf if v == '-Inf' else math.inf if v == 'Inf' else float(v)) for v in r]

def fmt(v):
    if math.isnan(v): return ''
    if v == int(v) and abs(v) < 1e15: return str(int(v))
    return repr(float(v))

results = []
internal_counts = {}
for f in sorted(glob.glob(os.path.join(STUDY, 'data', 'supplied', 'ICPSR_*', 'DS*', '*-Data.*'))):
    base = os.path.basename(f)
    key = f"{YEAR[base[:5]]}_DS{base[6:10]}"
    rel = os.path.relpath(f, STUDY)
    meta = json.load(open(os.path.join(HAVEN, f'{key}_meta.json')))
    hvars = {v['name']: v for v in meta['vars']}
    hnames, hraw = read_dump(os.path.join(HAVEN, f'{key}_raw.csv.gz'))
    _, hdef = read_dump(os.path.join(HAVEN, f'{key}_default.csv.gz'))
    por = f.endswith('.por')
    rec = dict(key=key, source=rel, format='SPSS portable (.por)' if por else 'SPSS system (.sav)', source_sha256=sha256(f))
    if por:
        pdf, pm = pyreadstat.read_por(f)
        p_raw = None
        p_def = pdf
    else:
        p_raw, pm = pyreadstat.read_sav(f, user_missing=True)
        p_def, _ = pyreadstat.read_sav(f)
    names_p = list(p_def.columns)
    rec['dimensions'] = dict(pyreadstat=list(p_def.shape), haven=[meta['nrow'], meta['ncol']], equal=list(p_def.shape) == [meta['nrow'], meta['ncol']])
    rec['variable_names_identical_and_same_order'] = names_p == hnames
    rec['nonnumeric_columns'] = [c for c in names_p if p_def[c].dtype == object] + [n for n, v in hvars.items() if 'character' in v['class']]
    # cell comparisons
    mism_def = {}; mism_raw = {}; bad_usermiss = {}; n_user_cells = 0; n_vars_with_user_cells = 0
    lab_mism = []; vlab_mism = []; miss_decl_mism = []
    for c in names_p:
        a = p_def[c].to_numpy(float)
        d = eq(a, hdef[c]); 
        if (~d).sum(): mism_def[c] = int((~d).sum())
        if p_raw is not None:
            r = eq(p_raw[c].to_numpy(float), hraw[c])
            if (~r).sum(): mism_raw[c] = int((~r).sum())
        diffcells = ~eq(hraw[c], hdef[c])
        k = int(diffcells.sum())
        if k:
            n_user_cells += k; n_vars_with_user_cells += 1
            ok = in_declared(hraw[c][diffcells], hvars[c])
            if (~ok).sum(): bad_usermiss[c] = int((~ok).sum())
        # declared missing values seen by pyreadstat must equal haven's (sav only)
        if not por:
            pr = pm.missing_ranges.get(c, [])
            pset = sorted((x['lo'], x['hi']) for x in pr)
            hv = hvars[c]; hset = sorted([(float(v), float(v)) for v in as_list(hv.get('na_values'))] + ([tuple(norm_rng(hv['na_range']))] if hv.get('na_range') else []))
            if pset != hset: miss_decl_mism.append(c)
        # labels
        hl = hvars[c].get('label') or ''
        if (pm.column_names_to_labels.get(c) or '') != hl: lab_mism.append(c)
        pv = {float(k): v for k, v in (pm.variable_value_labels.get(c) or {}).items()}
        hvl = {float(v): k for k, v in (hvars[c].get('labels') or {}).items()}
        if pv != hvl: vlab_mism.append(c)
    rec['cells_compared'] = int(p_def.shape[0] * p_def.shape[1])
    rec['default_mode_mismatched_cells'] = sum(mism_def.values())
    rec['default_mode_mismatch_by_variable'] = mism_def
    if p_raw is not None:
        rec['raw_mode_mismatched_cells'] = sum(mism_raw.values())
        rec['raw_mode_mismatch_by_variable'] = mism_raw
    else:
        rec['raw_mode_mismatched_cells'] = None
        rec['raw_mode_note'] = 'pyreadstat.read_por has no user_missing option; raw declared-missing codes are only available from haven read_por(user_na=TRUE). Raw codes were verified indirectly: every cell where haven raw and haven default differ holds a code inside that variable\'s declared missing set, and pyreadstat equals haven default on every cell.'
    rec['declared_user_missing_codes_present_in_data'] = n_user_cells > 0
    internal_counts[key] = dict(cells_holding_declared_user_missing_codes=n_user_cells,
                                variables_with_declared_user_missing_codes_present=n_vars_with_user_cells)
    rec['user_missing_cells_outside_declared_set'] = bad_usermiss
    rec['declared_missing_spec_mismatch_variables'] = miss_decl_mism if not por else 'not comparable: pyreadstat.read_por does not expose declared missing values'
    rec['variable_label_mismatch_variables'] = lab_mism
    rec['value_label_mismatch_variables'] = vlab_mism
    # write extract from exact haven raw values (declared user-missing codes retained; system-missing = empty field)
    out = os.path.join(OUT, f'{key}.csv.gz')
    buf = io.StringIO(); w = csv.writer(buf, lineterminator='\n')
    w.writerow(hnames)
    n = meta['nrow']
    cols = [hraw[c] for c in hnames]
    for i in range(n):
        w.writerow([fmt(col[i]) for col in cols])
    data = buf.getvalue().encode('utf-8')
    with open(out, 'wb') as fh:
        with gzip.GzipFile(filename='', mode='wb', fileobj=fh, mtime=0) as gz:
            gz.write(data)
    # round trip
    _, back = read_dump(out)
    rt = all(eq(back[c], hraw[c]).all() for c in hnames)
    rec['extract'] = dict(path=os.path.relpath(out, STUDY), sha256=sha256(out), roundtrip_equal_to_haven_raw=rt)
    rec['pass'] = bool(rec['dimensions']['equal'] and rec['variable_names_identical_and_same_order'] and not rec['nonnumeric_columns']
                       and rec['default_mode_mismatched_cells'] == 0 and (rec['raw_mode_mismatched_cells'] in (0, None))
                       and not bad_usermiss and (por or not miss_decl_mism) and not lab_mism and not vlab_mism and rt)
    side = dict(extract=os.path.relpath(out, STUDY), extract_sha256=rec['extract']['sha256'],
                source_file=rel, source_sha256=rec['source_sha256'], source_format=rec['format'],
                rows=n, columns=len(hnames), variable_names=hnames,
                content='All rows and all variables of the source file, in source order; raw numeric codes; no value-label substitution; no recoding.',
                missing_representation='Empty field = SPSS system-missing. Declared SPSS user-missing codes are kept as their numeric codes; see the matching dictionary for each variable\'s declared missing values.',
                number_format='Integral values written without decimals; other values as the shortest decimal string that round-trips to the same IEEE double.',
                writer='R haven read_%s(user_na = TRUE) dump at %%.17g, re-written by Python csv; gzip with mtime=0' % ('por' if por else 'sav'),
                verified_against='pyreadstat %s (%s)' % (pyreadstat.__version__, 'read_por' if por else 'read_sav user_missing=True and default'),
                loader_check=rec['pass'], created_utc=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
                encoding='UTF-8 CSV; source .sav encoding WINDOWS-1252 per file header; .por has no encoding field')
    json.dump(side, open(os.path.join(OUT, f'{key}.json'), 'w'), indent=1)
    results.append(rec)
    print(key, 'pass' if rec['pass'] else 'FAIL', rec['dimensions'], 'user-missing cells', n_user_cells, 'lab', len(lab_mism), 'vlab', len(vlab_mism), 'decl', miss_decl_mism if not por else '-', 'mism', rec['default_mode_mismatched_cells'], rec['raw_mode_mismatched_cells'])

summary = dict(
    created_utc=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    software=dict(python=platform.python_version(), pyreadstat=pyreadstat.__version__, pandas=pd.__version__, numpy=np.__version__,
                  R=json.load(open(glob.glob(os.path.join(HAVEN, '*_meta.json'))[0]))['R_version'],
                  haven=json.load(open(glob.glob(os.path.join(HAVEN, '*_meta.json'))[0]))['haven_version']),
    method=('Each file was read by R haven (user_na=TRUE and user_na=FALSE) and by pyreadstat (read_por; read_sav with user_missing=True and default). '
            'Dimensions, variable names/order, variable labels, value labels and every numeric cell were compared exactly (doubles dumped from R at %.17g and parsed with correctly rounded float()). '
            'NaN==NaN treated as equal.'),
    user_missing_handling={
        'haven_read_por_read_sav_user_na_FALSE': 'declared user-missing codes become NA (default).',
        'haven_user_na_TRUE': 'declared user-missing codes kept as values; declared set stored in na_values/na_range attributes (class haven_labelled_spss).',
        'pyreadstat_read_sav_default': 'declared user-missing codes become NaN.',
        'pyreadstat_read_sav_user_missing_True': 'declared user-missing codes kept; declared set in metadata.missing_ranges.',
        'pyreadstat_read_por': 'no user_missing option; declared user-missing codes always become NaN and metadata.missing_ranges is empty for .por files.'},
    all_pass=all(r['pass'] for r in results), files=results)
json.dump(summary, open(os.path.join(STUDY, 'registry', 'loader_check.json'), 'w'), indent=1, default=str)
json.dump(dict(note='Coordinator-only. Counts of cells holding declared SPSS user-missing codes, by file (from the loader check).', counts=internal_counts),
          open(os.path.join(STUDY, 'registry', 'work', 'loader_user_missing_counts_internal.json'), 'w'), indent=1)
print('ALL PASS', summary['all_pass'])
