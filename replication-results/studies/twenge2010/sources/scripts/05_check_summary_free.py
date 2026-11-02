"""Source role: verify that no dictionary or reader-facing description carries codebook frequency/percent/N strings.
Run: ~/.venv/bin/python -I 05_check_summary_free.py
Writes registry/summary_free_check.json. Exit code 1 if any unreviewed hit remains."""
import glob, json, os, re, sys, datetime
STUDY = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
D = os.path.join(STUDY, 'data', 'derived', 'dictionaries')
PATTERNS = {
    'weighted_N': re.compile(r'N\s*\(\s*WTD\s*\)|cases\s*\(Wtd\)', re.I),
    'pct_header': re.compile(r'\bPCT\b|\bVALID\s+ALL\b'),
    'valid_range': re.compile(r'Range of valid codes', re.I),
    'percent_sign': re.compile(r'\d\s*%|%\s*\d|percent', re.I),
    'one_decimal_number': re.compile(r'(?<![\w.$])\d{0,3}\.\d(?![\d.])'),
    'thousands_number': re.compile(r'\b\d{1,3},\d{3}\b'),
    'frequency_words': re.compile(r'\b(frequenc|mean|median|std\.? dev|standard deviation|N\s*=\s*\d)', re.I),
}
# Reviewed false-positive rules (applied to the match context); each was inspected manually on 2026-10-28.
REVIEWED = [
    ('rule statement', lambda h: h['where'].startswith('/notes') or (h['file'].endswith('.md') and 'Summary-free' in h['context']) or h['file'] in ('README.md', 'source_description.md') and re.search(r'summar|frequenc|percent|mean', h['match'], re.I)),
    ('percentage ranges are response-category wording', lambda h: h['pattern'] == 'percent_sign' and re.search(r'\d+%?\s*(-|to)\s*\d+%|\d+%\s*(-|to)\s*\d+', h['context'])),
    ('English word mean/means/meaning(ful/less)', lambda h: h['pattern'] == 'frequency_words' and re.search(r'mean(s|ing|ingful|ingless)\b', h['context'], re.I)),
    ('population thresholds in city-size or metropolitan-area definitions', lambda h: h['pattern'] == 'thousands_number' and re.search(r'city|inhabitants|people|metropolitan', h['context'], re.I)),
    ('fractional quantities in item labels or response categories (WK .5 = half-time work; 1.5 PK/D = packs per day)', lambda h: h['pattern'] == 'one_decimal_number' and re.search(r'WK \.5|1\.5 PK/D', h['context'])),
]
def strings(obj, path=''):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in ('spss_format', 'storage'): continue
            yield from strings(v, f'{path}/{k}')
    elif isinstance(obj, list):
        for i, v in enumerate(obj): yield from strings(v, f'{path}[{i}]')
    elif isinstance(obj, str):
        yield path, obj
hits = []
for f in sorted(glob.glob(os.path.join(D, '*'))):
    base = os.path.basename(f)
    if base.endswith('.json'):
        for p, s in strings(json.load(open(f))):
            for n, rx in PATTERNS.items():
                for m in rx.finditer(s):
                    hits.append(dict(file=base, where=p, pattern=n, match=m.group(0), context=s[max(0, m.start()-60):m.end()+60]))
    elif base.endswith('.md'):
        for ln, line in enumerate(open(f), 1):
            cells = line.split('|')
            if base.endswith('.dictionary.md') and len(cells) > 4: cells[3] = ''  # storage column (SPSS format like F6.4)
            s = '|'.join(cells)
            for n, rx in PATTERNS.items():
                for m in rx.finditer(s):
                    hits.append(dict(file=base, where=f'line {ln}', pattern=n, match=m.group(0), context=s[max(0, m.start()-60):m.end()+60].strip()))
for h in hits:
    h['reviewed_as'] = next((name for name, f in REVIEWED if f(h)), None)
unrev = [h for h in hits if not h['reviewed_as']]
out = dict(created_utc=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
           scanned=sorted(os.path.basename(x) for x in glob.glob(os.path.join(D, '*'))), patterns={k: v.pattern for k, v in PATTERNS.items()},
           reviewed_rules=[n for n, _ in REVIEWED], n_hits=len(hits), n_unreviewed=len(unrev), unreviewed=unrev,
           reviewed_hit_counts={n: sum(1 for h in hits if h['reviewed_as'] == n) for n, _ in REVIEWED})
json.dump(out, open(os.path.join(STUDY, 'registry', 'summary_free_check.json'), 'w'), indent=1, ensure_ascii=False)
from collections import Counter
print('hits', len(hits), 'unreviewed', len(unrev))
for h in unrev[:80]: print(h['file'], h['where'][:40], h['pattern'], repr(h['match']), '::', h['context'][:150])
sys.exit(1 if unrev else 0)
