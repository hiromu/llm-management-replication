"""Descriptive scoring of text-only robustness claims and ROC tests (lower tiers), using A-B agreed values."""
import json, os, sys
import numpy as np, pandas as pd
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare_implementations import model_key
T = pd.read_csv(f'{ROOT}/scoring/implementation_comparison_terms.csv')
s0 = T[T.spec_id.isin(['S000', 'S020'])].copy()
s0['fam'] = s0.mkey.str.split('|').str[0]
def agree(r):
    for a, b in [('A', 'B'), ('A', 'C'), ('B', 'C')]:
        x, y = r.get(a), r.get(b)
        if not pd.isna(x) and not pd.isna(y) and (abs(x - y) <= 5e-4 or abs(x - y) / max(abs(x), abs(y)) <= 1e-3):
            return pd.Series({'pair': a + b, 'me': x, 'p': r.get(a + '_p')})
    return pd.Series({'pair': None, 'me': r.get('A'), 'p': r.get('A_p')})
keep = s0[s0.fam.str.startswith('r_') & s0.tkey.isin(['steepness', 'sameness', 'friends', 'men', 'ratio_sameness', 'absdev_sameness', 'alt_sameness',
          'distinct_ranks', 'sum_ranks', 'admin_intensity', 'administrative_intensity', 'n_distinct_ranks', 'absolute_sameness', 'ratio',
          'hierarchy_x_men', 'unit_steepness', 'unit_sameness']) | s0.tkey.str.contains('x_men|_x_|ranks|intensity|ratio|abs|unit|friends', regex=True)]
keep = keep[~keep.tkey.str.contains('missing')]
out = pd.concat([keep[['spec_id', 'mkey', 'tkey']].reset_index(drop=True), keep.apply(agree, axis=1).reset_index(drop=True)], axis=1)
out.to_csv(f'{ROOT}/scoring/robustness_terms.csv', index=False)
pd.set_option('display.width', 250); pd.set_option('display.max_rows', 400)
print(out.round(4).to_string())
