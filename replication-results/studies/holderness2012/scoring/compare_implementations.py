"""Stage 1: compare implementations A, B, C before any target comparison (scoring_rules_v1: implementation_agreement).
Reads frozen run outputs only. Writes scoring/implementation_comparison.csv and scoring/implementation_agreement.json."""
import json, os, re, sys, glob
import numpy as np, pandas as pd

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
RUNS = json.load(open(f'{ROOT}/scoring/scored_runs.json'))  # {"A": "runs/A_...", ...}
RULES = json.load(open(f'{ROOT}/sealed/scoring/scoring_rules_v1.json'))['implementation_agreement']['tolerances']

GROUPS, SPECS = {'cap', 'camp'}, {'simple', 'full'}
FAMALIAS = {'rfriends': 'r_friends', 'ralt': 'r_alt', 'rcc': 'r_cc', 'rn50': 'r_n50', 'rn100': 'r_n100', 'rnoexec': 'r_noexec',
            'rger': 'r_ger', 'rjap': 'r_jap', 'raaf': 'r_aaf', 'rnosq': 'r_nosq', 'rint': 'r_int'}
VARALIAS = {'absolute': 'absdev', 'abs': 'absdev', 'absdev': 'absdev', 'ratio': 'ratio', 'distinct': 'distinct', 'nranks': 'distinct',
            'sum': 'sumranks', 'sumranks': 'sumranks', 'administrative': 'adminint', 'admin': 'adminint', 'adminint': 'adminint',
            'intensity': None, 'ranks': None, 'sameness': 'sameness', 'steepness': 'steepness', 'friends': 'friends', 'only': None,
            'plus': None, 'unit': 'unit', 'hierarchy': None, 'both': 'both'}

def model_key(mid):
    toks = [t for t in re.split(r'_+|\+', str(mid).lower()) if t]
    fam = toks[0]
    rest = toks[1:]
    if fam == 'r' and rest:
        fam = 'r_' + rest[0]; rest = rest[1:]
    fam = FAMALIAS.get(fam, fam)
    grp = next((t for t in rest if t in GROUPS), None)
    spc = next((t for t in rest if t in SPECS), None)
    var = sorted({VARALIAS.get(t, t) for t in rest if t not in GROUPS | SPECS} - {None})
    if fam == 'r_alt':
        alt = {'absdev', 'ratio', 'distinct', 'sumranks', 'adminint'}
        var = [v for v in var if v in alt] or var
    if fam == 'r_friends':
        var = [v for v in var if v != 'friends']
    if fam == 't5' and not var: var = ['both']
    if fam == 't5' and set(var) >= {'steepness', 'sameness'}: var = ['both']
    return f"{fam}|{grp}|{spc}|{'+'.join(var)}"

def term_key(t):
    t = str(t).lower().replace(':', '_x_').replace('*', '_x_')
    t = re.sub(r'_miss$', '_missing', t)
    if 'officer' in t and ('_x_' in t or 'x_' in t or '_x' in t or 'inter' in t): return 'officer_x_hierarchy'
    if ('men' in t and ('_x_' in t or 'hier' in t and 'x' in t)): return 'hierarchy_x_men'
    return t

def load(impl):
    d = f"{ROOT}/{RUNS[impl]}/results"
    r = pd.read_csv(f'{d}/results.csv', low_memory=False)
    r['impl'] = impl
    r['mkey'] = r.model_id.map(model_key)
    r['tkey'] = r.term.map(term_key)
    conv = r['converged'].astype(str).str.lower().isin(['true', '1', 'yes']) if 'converged' in r else True
    r['fit_ok'] = r.status.astype(str).str.lower().isin(['ok', 'omitted_collinear', 'omitted_constant']) & conv
    return r

def ids(impl, spec, mid):
    p = f"{ROOT}/{RUNS[impl]}/results/sample_ids"
    cand = glob.glob(f"{p}/{spec}__{mid}.txt")
    if not cand: return None
    return frozenset(int(float(x)) for x in open(cand[0]).read().split())  # R may write 1e+05

def agree(a, b):
    if pd.isna(a) or pd.isna(b): return False
    d = abs(a - b)
    return d <= RULES['me_abs'] or d / max(abs(a), abs(b), 1e-300) <= RULES['me_rel']

def main():
    R = {k: load(k) for k in RUNS}
    allr = pd.concat(R.values(), ignore_index=True)
    model_rows = allr.drop_duplicates(['impl', 'spec_id', 'mkey'])[['impl', 'spec_id', 'mkey', 'model_id', 'n', 'n_clusters']]
    # hierarchy-type terms of interest: everything except camp dummies and intercepts
    keep = ~allr.tkey.str.match(r'^(camp|\(intercept\)|intercept|__model__)')
    w = allr[keep].pivot_table(index=['spec_id', 'mkey', 'tkey'], columns='impl', values='me', aggfunc='first')
    wp = allr[keep].pivot_table(index=['spec_id', 'mkey', 'tkey'], columns='impl', values='me_p', aggfunc='first')
    ok = allr.groupby(['impl', 'spec_id', 'mkey']).fit_ok.all().unstack('impl')
    n = model_rows.pivot_table(index=['spec_id', 'mkey'], columns='impl', values='n', aggfunc='first')
    mid = model_rows.pivot_table(index=['spec_id', 'mkey'], columns='impl', values='model_id', aggfunc='first')
    out = w.join(wp, rsuffix='_p').reset_index()
    pairs = [(a, b) for a, b in [('A', 'B'), ('A', 'C'), ('B', 'C')] if a in RUNS and b in RUNS]
    for a, b in pairs:
        out[f'me_{a}{b}'] = [agree(x, y) for x, y in zip(out.get(a, np.nan), out.get(b, np.nan))]
        out[f'p_{a}{b}'] = [(not pd.isna(x) and not pd.isna(y) and abs(x - y) <= RULES['p_abs']) for x, y in zip(out.get(a + '_p', np.nan), out.get(b + '_p', np.nan))]
    mod = n.copy(); mod.columns = [f'n_{c}' for c in mod.columns]
    for c in ok.columns: mod[f'ok_{c}'] = ok[c]
    for a, b in pairs:
        mod[f'n_{a}{b}'] = mod.get(f'n_{a}') == mod.get(f'n_{b}')
        same = []
        for (s, k) in mod.index:
            ia = ids(a, s, mid.loc[(s, k)].get(a)) if a in mid.columns and not pd.isna(mid.loc[(s, k)].get(a)) else None
            ib = ids(b, s, mid.loc[(s, k)].get(b)) if b in mid.columns and not pd.isna(mid.loc[(s, k)].get(b)) else None
            same.append(None if ia is None or ib is None else ia == ib)
        mod[f'ids_{a}{b}'] = same
    out.to_csv(f'{ROOT}/scoring/implementation_comparison_terms.csv', index=False)
    mod.reset_index().to_csv(f'{ROOT}/scoring/implementation_comparison_models.csv', index=False)
    # summary on hierarchy terms of the origin core families
    core = out[(out.spec_id == 'S000') & out.mkey.str.match(r'^t[456]\|') & out.tkey.isin(['steepness', 'sameness', 'officer_x_hierarchy'])]
    summ = {'pairs': {}, 'core_terms': int(len(core))}
    for a, b in pairs:
        summ['pairs'][a + b] = {'core_me_agree': int(core[f'me_{a}{b}'].sum()), 'core_p_agree': int(core[f'p_{a}{b}'].sum()),
                                'all_terms_me_agree': int(out[f'me_{a}{b}'].sum()), 'all_terms_compared': int(out[[a, b]].notna().all(axis=1).sum()) if a in out and b in out else 0,
                                'models_n_equal': int(mod[f'n_{a}{b}'].sum()), 'models_ids_equal': int(pd.Series(mod[f'ids_{a}{b}']).fillna(False).sum()),
                                'models_ids_compared': int(pd.Series(mod[f'ids_{a}{b}']).notna().sum())}
    summ['models'] = int(len(mod))
    json.dump(summ, open(f'{ROOT}/scoring/implementation_agreement.json', 'w'), indent=2)
    print(json.dumps(summ, indent=1))

if __name__ == '__main__':
    main()
