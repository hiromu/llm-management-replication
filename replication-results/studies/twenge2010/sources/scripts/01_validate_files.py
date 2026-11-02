"""Source role: compare supplied files with setup inventory and ICPSR manifests (read-only)."""
import hashlib, json, os, re, sys
STUDY = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SUP = os.path.join(STUDY, 'data', 'supplied')
inv = json.load(open(os.path.join(SUP, 'supplied_sources.json')))

def digest(p, algo):
    h = hashlib.new(algo)
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()

def parse_manifest(path):
    ds = None; out = {}; labels = {}
    for line in open(path, encoding='utf-8', errors='replace'):
        m = re.match(r'^(DS\d{4})\s+(.*\S)\s*$', line)
        if m:
            ds = m.group(1); labels[ds] = m.group(2); continue
        if line.startswith('Study-level'):
            ds = 'study'
        m = re.match(r'^\s{4}(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*$', line)
        if m and m.group(1) != 'Filename':
            fn, rl, rc, vc, date, md5 = m.groups()
            out[fn] = dict(ds=ds, record_count=rc, var_count=vc, date_updated=date,
                           md5=None if md5 == '-' else md5)
    return out, labels

result = {'sources': []}
for s in inv['sources']:
    root = os.path.join(SUP, os.path.basename(s['path_from_study']))
    num = '%05d' % s['study_number']
    man, labels = parse_manifest(os.path.join(root, f'{num}-manifest.txt'))
    actual = []
    for dp, dn, fns in os.walk(root):
        for fn in fns:
            actual.append(os.path.relpath(os.path.join(dp, fn), root))
    actual = sorted(a for a in actual if not os.path.basename(a).startswith('.'))
    hidden = sorted(os.path.relpath(os.path.join(dp, fn), root) for dp, dn, fns in os.walk(root) for fn in fns if fn.startswith('.'))
    invmap = {f['path']: f for f in s['file_inventory']}
    files = []
    for a in actual:
        p = os.path.join(root, a)
        rec = dict(path=a, bytes=os.path.getsize(p), sha256=digest(p, 'sha256'), md5=digest(p, 'md5'))
        i = invmap.get(a)
        rec['in_setup_inventory'] = i is not None
        rec['setup_sha256_match'] = (i is not None and i['sha256'] == rec['sha256'])
        rec['setup_bytes_match'] = (i is not None and i['bytes'] == rec['bytes'])
        m = man.get(os.path.basename(a))
        rec['in_provider_manifest'] = m is not None
        if m:
            rec['manifest_ds'] = m['ds']; rec['manifest_label'] = labels.get(m['ds'])
            rec['manifest_record_count'] = m['record_count']; rec['manifest_var_count'] = m['var_count']
            rec['manifest_date_updated'] = m['date_updated']
            rec['manifest_md5'] = m['md5']
            rec['manifest_md5_match'] = None if m['md5'] is None else (m['md5'] == rec['md5'])
        files.append(rec)
    missing_from_disk = sorted(set(invmap) - set(actual))
    result['sources'].append(dict(source_id=s['source_id'], root=os.path.relpath(root, STUDY),
        manifest_dataset_labels=labels, files=files, hidden_files=hidden,
        setup_inventory_missing_on_disk=missing_from_disk,
        manifest_files_not_supplied=sorted(set(man) - set(os.path.basename(a) for a in actual))))
json.dump(result, open(sys.argv[1], 'w'), indent=1)
for r in result['sources']:
    print(r['source_id'], r['manifest_dataset_labels'])
    for f in r['files']:
        print('  ', f['path'], f['bytes'], 'inv', f['setup_sha256_match'], 'man', f.get('manifest_md5_match'), f.get('manifest_ds'), f.get('manifest_record_count'), f.get('manifest_var_count'))
    print('  hidden', r['hidden_files'], 'missing', r['setup_inventory_missing_on_disk'])
