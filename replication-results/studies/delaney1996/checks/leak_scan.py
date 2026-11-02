"""Scan implementer-visible files for article identity and sealed target values."""
import json, re, sys, pathlib
root = pathlib.Path(sys.argv[1])
T = json.load(open('sealed/targets_frozen_v1.json'))
vals = set()
for c in T['cells']:
    for k in ('value', 'se'):
        v = c.get(k)
        if isinstance(v, (int, float)) and v is not None and abs(v) < 100 and round(v, 3) != round(v, 0):
            vals.add(f'{abs(v):.3f}')
ident = ['delaney', 'huselid', 'academy of management', 'perceptions of organizational performance', 'human resource management practices',
         '256718', 'amj', '\\b590\\b', '\\b373\\b', 'iowa', 'rutgers']
hits = []
for p in sorted(root.rglob('*')):
    if not p.is_file() or p.suffix not in ('.md', '.json', '.txt', '.R', '.py'): continue
    s = p.read_text(errors='ignore'); low = s.lower()
    for w in ident:
        for m in re.finditer(w, low): hits.append((str(p), 'identity:' + w, low[max(0, m.start()-60):m.end()+60].replace('\n', ' ')))
    for v in vals:
        for m in re.finditer(r'(?<![\d.])' + re.escape(v) + r'(?!\d)', s): hits.append((str(p), 'target_value:' + v, s[max(0, m.start()-60):m.end()+40].replace('\n', ' ')))
print(len(vals), 'distinct target strings scanned;', len(hits), 'hits')
for h in hits[:60]: print(h)
json.dump(dict(root=str(root), n_target_strings=len(vals), hits=hits), open(sys.argv[2], 'w'), indent=1)
