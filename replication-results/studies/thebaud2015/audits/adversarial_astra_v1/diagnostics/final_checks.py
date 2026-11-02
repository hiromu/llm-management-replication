"""Post hoc final artifact checks, no refits."""
from pathlib import Path
import json, hashlib, csv, ast, re
S=Path('../..').resolve(); O=Path('diagnostics')
manifest=json.loads((S/'registry/construction/derived_hashes.json').read_text())
rows=[]
for rel,spec in manifest['files'].items():
 h=hashlib.sha256((S/rel).read_bytes()).hexdigest()
 rows.append(dict(path=rel,expected=spec['sha256'],observed=h,match=h==spec['sha256']))
frozen={}
for name in ['freeze_hashes_v1.txt','freeze_hashes_v1_2.txt']:
 for line in (S/'reconciliation/frozen'/name).read_text().splitlines():
  h,rel=line.split(maxsplit=1)
  if rel.startswith('../'):rel=rel[3:]
  if rel=='role_record.json':rel='implementation/role_record.json'
  frozen[rel]=h
for rel,expected in frozen.items():
 observed=hashlib.sha256((S/rel).read_bytes()).hexdigest()
 rows.append(dict(path=rel,expected=expected,observed=observed,match=observed==expected))
assert all(r['match'] for r in rows)
(O/'input_hash_check.json').write_text(json.dumps(rows,indent=2))
for p in O.glob('*.py'):ast.parse(p.read_text())
review=Path('review.md').read_text()
assert '**' not in review and r'\[' not in review and r'\]' not in review
assert 'Summary:' in review
assert all(int(r['unexplained'])==0 for r in csv.DictReader((O/'raw_extract_check.csv').open()))
fits=list(csv.DictReader((O/'validation.csv').open()))
assert len(fits)==8, len(fits)
assert all(r['converged']=='TRUE' for r in fits),fits
cpu=sum(float(r['cpu_seconds']) for r in fits)
assert cpu+900 < 7200 # conservative upper allowance for interrupted single-thread fit
print('PASS: 8 saved fits; convergence and artifact checks; registered input hashes unchanged.')
print('Successful fit CPU seconds:',cpu,'; conservative total including aborted fit:',cpu+900)
print('Review word count:',len(review.split()))
