"""Check the distributed metadata snapshot, without network access."""
from pathlib import Path
from collections import defaultdict,Counter
import csv,json
HERE=Path(__file__).resolve().parent
def rows(name):
 with (HERE/name).open(newline='',encoding='utf-8-sig') as f:return list(csv.DictReader(f))
corpus=rows('corpus_11051.csv');full=rows('fulltext_776.csv');sources=defaultdict(list)
for r in rows('source_assessments.csv'):sources[r['paper_id']].append(r)
broad=[r for r in full if r['tier_group'] in {'A','B','C'}]
no_package=[r for r in broad if r['has_replication_package']=='no']
emp=[r for r in no_package if r['tier_group'] in {'B','C'}]
arch=[r for r in emp if r['method_primary']=='archival_quant']
public={'R','T0','T1','T5'}
def accessible(r,tiers):return bool(sources[r['paper_id']]) and all(s['tier'] in tiers for s in sources[r['paper_id']])
obtain=[r for r in arch if accessible(r,public|{'T2c'})]
pub=[r for r in arch if accessible(r,public)]
counts=dict(corpus=len(corpus),fulltext=len(full),candidate=len(broad),no_package_recorded=len(no_package),empirical=len(emp),archival=len(arch),all_sources_obtainable=len(obtain),all_sources_public=len(pub))
assert counts==json.loads((HERE/'counts.json').read_text())
assert {r['paper_id'] for r in emp}=={r['paper_id'] for r in rows('empirical_277.csv')}
assert {r['paper_id'] for r in pub}=={r['paper_id'] for r in rows('archival_public_154.csv')}
assert {r['paper_id'] for r in rows('six_case_membership.csv')}<={r['paper_id'] for r in pub}
print(json.dumps(counts,indent=2))
print('Empirical methods:',dict(Counter(r['method_primary'] for r in emp)))
