"""Versioned presentation contract. Validation never determines scientific verdicts."""
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import re

VERSION = 1
RULES = ('study', 'common', 'lenient')
TERM_OUTCOMES = {'consistent', 'indeterminate', 'candidate', 'fragile', 'not assessed'}
PAPER_OUTCOMES = TERM_OUTCOMES | {'partially reproduced', 'not reproduced (unverified)', 'not attemptable', 'fragile inference'}
ISSUES = {'sample', 'missing', 'variables', 'targets', 'uncertainty', 'calculation'}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def number(value, label, optional=True):
    if value is None and optional:
        return
    require(isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value), f'{label}: finite number required')


def safe_file(root, relative):
    require(isinstance(relative, str) and relative and not Path(relative).is_absolute(), 'Asset path must be relative')
    root = Path(root).resolve()
    path = (root / relative).resolve()
    require(path.is_relative_to(root) and path.is_file(), f'Missing or unsafe asset: {relative}')
    return path


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def validate(bundle):
    """Return a copy with server-computed deltas; reject invalid structured output."""
    require(isinstance(bundle, dict) and bundle.get('schema_version') == VERSION, 'Expected result schema_version 1')
    # Reject nonfinite numbers anywhere, including arbitrary provenance extensions.
    try:
        json.dumps(bundle, allow_nan=False)
    except (ValueError, TypeError):
        raise ValueError('Result must be finite JSON')
    b = deepcopy(bundle)
    s = b.get('study', {})
    require(isinstance(s, dict) and re.fullmatch(r'[a-z][a-z0-9_]{2,63}', str(s.get('id', ''))), 'Invalid study ID')
    for key in ('citation', 'title', 'short', 'journal'):
        require(isinstance(s.get(key), str) and s[key].strip(), f'study.{key} is required')
    require(type(s.get('year')) is int and 1800 <= s['year'] <= 2200, 'Invalid publication year')
    for rule in RULES:
        require(s.get('paper_outcomes', {}).get(rule) in PAPER_OUTCOMES, f'Explicit study.paper_outcomes.{rule} required')
    require(isinstance(b.get('execution'), dict), 'execution must be an object')
    require(b.get('execution', {}).get('status') in ('completed', 'blocked', 'review_required'), 'execution.status required')
    require(isinstance(b.get('report'), str) and b['report'].strip(), 'Replication report required')
    require(isinstance(b.get('provenance'), dict) and b['provenance'].get('kind') in ('archive', 'research', 'import'), 'Provenance kind required')
    require(isinstance(b.get('blockers', []), list) and all(isinstance(x, str) for x in b.get('blockers', [])), 'blockers must be text records')
    if b['execution']['status'] == 'blocked':
        require(bool(b.get('blockers')), 'Blocked execution needs a reason')
        require(s['paper_outcomes']['study'] in ('indeterminate', 'not attemptable', 'not assessed'), 'Blocked execution cannot claim successful replication')
    terms = b.get('terms')
    require(isinstance(terms, list) and len(terms) <= 20000, 'terms must be an array (maximum 20000)')
    for i, t in enumerate(terms):
        require(isinstance(t, dict), 'Invalid term')
        for key in ('term', 'table', 'scale', 'source'):
            require(isinstance(t.get(key), str) and t[key], f'terms[{i}].{key} required')
        require(t.get('tier') in ('focal', 'lower'), 'Term tier must be focal or lower')
        for rule in RULES:
            require(t.get('outcomes', {}).get(rule) in TERM_OUTCOMES, f'Term outcomes.{rule} required')
        for key in ('published_values', 'reconstructed_values', 'distances', 'sample_gap'):
            require(isinstance(t.get(key, []), list), f'{key} must be an array')
            for x in t.get(key, []):
                number(x, key, False)
        require('published_values' in t and 'reconstructed_values' in t, 'Explicit estimate arrays required; use [] for unavailable')
        t.setdefault('id', f'{s["id"]}:{i}')
        t.setdefault('claim', '')
        t.setdefault('origins', '')
        t.setdefault('source_row', None)
        t.setdefault('published_se', '')
        for key, values in [('published', 'published_values'), ('reconstructed', 'reconstructed_values'), ('distance_se', 'distances'), ('n_gap', 'sample_gap')]:
            t.setdefault(key, ' / '.join(map(str, t.get(values, []))))
        t.setdefault('v1_outcome', t['outcomes']['study'])
        t.setdefault('common', t['outcomes']['common'])
        t.setdefault('lenient', t['outcomes']['lenient'])
    displays = b.get('displays')
    require(isinstance(displays, list) and len(displays) <= 500, 'displays must be an ordered array')
    ids = set()
    for d in displays:
        require(isinstance(d, dict) and re.fullmatch(r'[a-zA-Z0-9_-]{1,80}', str(d.get('id', ''))), 'Invalid display ID')
        require(d['id'] not in ids, 'Duplicate display ID')
        ids.add(d['id'])
        require(isinstance(d.get('title'), str) and d['title'], 'Display title required')
        require(isinstance(d.get('source'), dict) and d['source'].get('path'), 'Every display needs source provenance')
        if d.get('original'):
            o = d['original']
            require(type(o.get('page')) is int and 1 <= o['page'] <= 10000, 'Original page must be a one-based PDF page')
            require(re.fullmatch('[a-f0-9]{64}', str(o.get('sha256', ''))), 'Original page mapping needs a PDF SHA-256')
            number(o.get('y', 0), 'original.y', False)
            require(0 <= o.get('y', 0) <= 1, 'original.y must be in [0, 1]')
        if 'annotation' in d:
            require(isinstance(d['annotation'], dict) and all(isinstance(d['annotation'].get(k), str) for k in ('heading', 'text')), 'Annotation heading/text required')
        if d.get('kind') == 'table':
            cols, rows = d.get('columns'), d.get('rows')
            require(isinstance(cols, list) and 1 <= len(cols) <= 50 and all(isinstance(x, str) for x in cols), 'Table columns required')
            require(isinstance(rows, list) and 1 <= len(rows) <= 20000, 'Table rows required')
            for r in rows:
                require(isinstance(r, dict) and isinstance(r.get('cells'), list), 'Row cells must be an array')
                require(isinstance(r.get('label'), str) and len(r.get('cells', [])) == len(cols), 'Table row width must match columns')
                for c in r['cells']:
                    if c is None:
                        continue
                    require(isinstance(c, dict), 'Invalid table cell')
                    for key in ('estimate', 'published', 'se', 'published_se'):
                        c.setdefault(key, None)
                        number(c[key], key)
                    require(c['se'] is None or c['se'] >= 0, 'Negative standard error')
                    require(c['published_se'] is None or c['published_se'] >= 0, 'Negative published standard error')
                    if c.get('original_region'):
                        require(bool(d.get('original')), 'Cell regions require a verified original mapping')
                        for box in c['original_region'].values():
                            require(isinstance(box, dict), 'Invalid PDF region')
                            for k in ('x', 'y', 'w', 'h'):
                                number(box.get(k), 'PDF region.' + k, False)
                            require(min(box['x'], box['y']) >= 0 and min(box['w'], box['h']) > 0 and box['x']+box['w'] <= 1.00001 and box['y']+box['h'] <= 1.00001, 'PDF region is outside page')
                    c['delta'] = c['estimate'] - c['published'] if c['estimate'] is not None and c['published'] is not None else None
                    c['distance_se'] = abs(c['delta']) / c['published_se'] if c['delta'] is not None and c['published_se'] else None
                    distance = c['distance_se']
                    number(c['delta'], 'Computed delta')
                    number(distance, 'Computed distance')
                    c['distance_band'] = 'unavailable' if distance is None else 'close' if distance <= 1 else 'moderate' if distance <= 2 else 'large'
            cells = [c for r in rows for c in r['cells'] if c]
            d['agreement'] = {'within_one_se': sum(c['distance_band'] == 'close' for c in cells), 'compared': sum(c['distance_se'] is not None for c in cells)}
            d.setdefault('sample', [])
            d.setdefault('published_sample', None)
            require(isinstance(d['sample'], list), 'sample must be a numeric array')
            for n in d['sample']:
                number(n, 'sample', False)
            number(d['published_sample'], 'published_sample')
        elif d.get('kind') == 'figure':
            require(isinstance(d.get('asset'), str) and d['asset'], 'Figure asset path required')
        else:
            raise ValueError('Display kind must be table or figure')
    if b['execution']['status'] == 'completed':
        require(bool(displays), 'Completed execution requires a display; use blocked/review_required when unavailable')
    issues = b.setdefault('issues', {})
    require(isinstance(issues, dict) and set(issues) <= ISSUES, 'Unknown issue category')
    for issue in issues.values():
        require(isinstance(issue, dict) and isinstance(issue.get('text'), str) and issue.get('source'), 'Issues require text and a source')
    return b


def study_view(bundle, detail=False):
    b = validate(bundle)
    s = dict(b['study'])
    terms = b['terms']
    s.update(total=len(terms), counts={r: {c: sum(t['outcomes'][r] == c for t in terms) for c in TERM_OUTCOMES} for r in RULES},
             tables=sorted({t['table'] for t in terms}), issues=b['issues'], execution=b['execution'], blockers=b.get('blockers', []),
             result_schema_version=VERSION, provenance=b['provenance'], stages=s.get('stages', []))
    s.setdefault('code', s['journal'])
    s.setdefault('summary', '')
    s.setdefault('outcome', s['paper_outcomes']['study'])
    if detail:
        s.update(terms=terms, displays=b['displays'], report=b['report'], metadata=b.get('metadata', {}), paper_record=b.get('paper_record', {}))
    return s


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Validate a replication console result bundle')
    parser.add_argument('result', type=Path)
    args = parser.parse_args()
    result = validate(json.loads(args.result.read_text()))
    print(f'Valid v{VERSION}: {result["study"]["id"]}, {len(result["terms"])} terms, {len(result["displays"])} displays')
