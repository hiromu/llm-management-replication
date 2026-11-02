"""Adversarial review: agreement of influence.csv between implementations A and B (and C, informational)."""
import pandas as pd, numpy as np, json
root = '../../../runs/run_20261028_v1_1'
def load(x):
    d = pd.read_csv(f'{root}/out_{x}/influence.csv', na_values=['NA'])
    return d
A, B = load('A'), load('B')
res = {}
for name, X in (('B', B),):
    key = ['model_id', 'deleted_V1', 'term']
    print('rows A', len(A), 'rows', name, len(X), 'status A', A.status.value_counts().to_dict(), 'status', name, X.status.value_counts().to_dict())
    j = A.merge(X, on=key, how='outer', suffixes=('_A', '_' + name), indicator=True)
    print('merge', j['_merge'].value_counts().to_dict())
    both = j[j['_merge'] == 'both']
    out = {'rows_A': len(A), 'rows_' + name: len(X), 'unmatched': int((j['_merge'] != 'both').sum())}
    for col in ['estimate', 'se', 'p_upper', 'p_two']:
        diff = (both[col + '_A'] - both[col + '_' + name]).abs()
        out['max_abs_diff_' + col] = float(diff.max())
        out['n_na_mismatch_' + col] = int((both[col + '_A'].isna() != both[col + '_' + name].isna()).sum())
    out['status_mismatch'] = int((both['status_A'] != both['status_' + name]).sum())
    per_model = both.groupby('model_id').apply(lambda g: pd.Series({'n_deletions': g.deleted_V1.nunique(), 'max_abs_diff_estimate': (g.estimate_A - g['estimate_' + name]).abs().max()}))
    print(per_model)
    res[name] = out
print(json.dumps(res, indent=1))
# influence ranges at origin for H1-primary candidate terms (A)
rng = A[A.term.isin(['INCENT', 'STAFF'])].groupby(['model_id', 'term']).estimate.agg(['min', 'max', 'count'])
print(rng)
json.dump(res, open('influence_agreement_AB.json', 'w'), indent=1)
rng.to_csv('influence_ranges_candidate_terms_A.csv')
