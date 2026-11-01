#!/usr/bin/env python3
"""PX01 analysis. Requires only the four input CSVs and installed scientific packages."""
import argparse
import hashlib
import itertools
import platform
import sys
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
import scipy
from scipy import stats
import statsmodels
import statsmodels.api as sm
import statsmodels.formula.api as smf
from statsmodels.stats.anova import anova_lm

OUTCOMES = ['you_grant', 'prom_voice', 'proh_voice']
ITEMS = {
    'benev_trust_broker': [f'bentrust_broker{i}' for i in range(1, 4)],
    'integ_trust_broker': [f'inttrust_broker{i}' for i in range(1, 4)],
    'val_align_part_broker': ['me_broker_valal1', 'me_broker_valal2'],
    'relconcerns_with_broker': [f'broker_rep{i}' for i in range(1, 4)],
    'loyal_comb': [f'loyal{i}' for i in range(1, 4)],
    'LoyaltyHouse': [f'LoyalHouse{i}' for i in range(1, 4)],
}
MEDIATORS = list(ITEMS)[:4]
BOOT_KEYS = ['se_boot', 'ci_bc_low', 'ci_bc_high', 'ci_perc_low', 'ci_perc_high', 'boot_failed']
PATH_KEYS = ['ind', 'a', 'b', 'c_prime', 'total', 'se_delta', 'p_delta', 'ci_norm_low', 'ci_norm_high']
MED4_KEYS = ['ind', 'a', 'b', 'se_delta', 'p_delta']
SERIAL_KEYS = ['ind', 'a1', 'd21', 'b2', 'se_delta', 'p_delta']
PAIRED_KEYS = ['mean_loyal', 'sd_loyal', 'mean_control', 'sd_control', 'mean_diff',
               'se_diff', 't', 'df', 'p', 'n', 'd', 'dz', 'p_hc3']
GROUP_DESC = ['mean_loyal', 'sd_loyal', 'mean_control', 'sd_control', 'mean_diff', 'd', 'p_hc3']
LOGIT_TERMS = ['coef', 'se', 'z', 'p', 'or', 'p_hc0']
RESULT_COLUMNS = ['dataset', 'sample_level', 'composite_level', 'key', 'method', 'value', 'status', 'message']
INFLUENCE_COLUMNS = ['dataset', 'sample_level', 'estimand', 'deleted_unit', 'estimate', 'p', 'status', 'message']


def col(d, name):
    return d[name] if name in d else pd.Series(np.nan, index=d.index, name=name)


def cc(d, names):
    return d.reindex(columns=names).dropna()


def require(test, reason):
    if not test:
        raise ValueError(reason)


def ratio(a, b):
    return float(a / b) if np.isfinite(b) and b != 0 else np.nan


def mean(a):
    return float(np.mean(a)) if len(a) else np.nan


def sd(a):
    return float(np.std(a, ddof=1)) if len(a) > 1 else np.nan


def npvalue(z):
    return float(2 * stats.norm.sf(abs(z)))


class Report:
    def __init__(self, args):
        self.args = args
        self.rows, self.influence, self.samples = [], [], []
        self.context = None
        self.warnings = set()

    def emit(self, prefix, method, keys, compute):
        try:
            with warnings.catch_warnings(record=True) as caught:
                warnings.simplefilter('always')
                values = compute()
            for w in caught:
                self.warnings.add(f'{prefix} ({method}): {w.message}')
            error = ''
        except Exception as exc:
            values, error = {}, f'{type(exc).__name__}: {exc}'
        for key in keys:
            value = values.get(key, np.nan)
            reason = error
            if isinstance(value, Exception):
                reason, value = str(value), np.nan
            if not np.isscalar(value) or not np.isfinite(value):
                reason = reason or 'Undefined quantity: insufficient complete cases, zero variance, or non-finite fit/statistic.'
                value = np.nan
            self.rows.append(dict(zip(RESULT_COLUMNS,
                [*self.context, f'{prefix}.{key}' if key else prefix, method,
                 float(value), 'failed' if reason else 'ok', reason])))

    def scalar(self, key, method, compute):
        self.emit(key, method, [''], lambda: {'': compute()})

    def loo(self, d, estimand, compute):
        for unit in pd.unique(d['_unit']):
            reduced = d.loc[d['_unit'] != unit]
            try:
                with warnings.catch_warnings():
                    warnings.simplefilter('ignore')
                    estimate, p = compute(reduced)
                require(np.isfinite(estimate) and np.isfinite(p), 'Undefined estimate or p value after deletion')
                status, message = 'ok', ''
            except Exception as exc:
                estimate, p, status, message = np.nan, np.nan, 'failed', f'{type(exc).__name__}: {exc}'
            self.influence.append(dict(zip(INFLUENCE_COLUMNS,
                [self.context[0], self.context[1], estimand, unit, estimate, p, status, message])))


def read_data(path, k):
    d = pd.read_csv(path, dtype=str, keep_default_na=False)
    text_cols = {'part_uid', 'cond', 'cond_rel', 'broker_hist', 'wrongdoing', 'gender_recode', 'StrongLoyaltyRequestor_char'}
    for name in d:
        if name not in text_cols:
            d[name] = pd.to_numeric(d[name], errors='coerce').replace([np.inf, -np.inf], np.nan)
        else:
            d[name] = d[name].mask(d[name].eq(''))
    if k == 1:
        # A missing identifier cannot link rows; preserve it as an isolated retained unit.
        uid = col(d, 'part_uid').copy()
        for i in d.index[uid.isna()]:
            uid.loc[i] = f'__missing_part_uid_row_{i + 1}'
        d['_unit'] = uid
    else:
        d['_unit'] = np.arange(1, len(d) + 1)
    return d


def samples(d, k):
    if k == 1:
        passed = col(d, 'attn').notna() & col(d, 'attn').eq(col(d, 'wrongdoing_num'))
        all_pass = passed.groupby(d['_unit']).transform('all')
        return {'D1_key': d.loc[all_pass].copy(), 'D1_none': d.copy()}
    if k == 2:
        c1 = col(d, 'comp1').eq(col(d, 'cond').map({'loyal_colleague': 1, 'control': 2}))
        c2 = col(d, 'comp2').eq(2)
        return {'D2_any': d.loc[c1 & c2].copy(), 'D2_both': d.loc[c1 | c2].copy(), 'D2_none': d.copy()}
    if k == 3:
        comp = (col(d, 'comp2').eq(2)
                & col(d, 'comp1').eq(col(d, 'cond_rel').map({'loyal_colleague': 1, 'control': 2}))
                & col(d, 'comp3').eq(col(d, 'broker_hist').map({'divisive': 2, 'control': 1})))
        attn = col(d, 'attn_afterscen').eq(col(d, 'cond_num').map({1: 1, 2: 3, 3: 2, 4: 4}))
        return {'D3_all': d.loc[comp & attn].copy(), 'D3_comp': d.loc[comp].copy(), 'D3_none': d.copy()}
    return {'D4_loyal': d.loc[col(d, 'LoyalRequestor').notna()].copy()}


def composites(d, k, level):
    d = d.copy()
    names = ['loyal_comb'] if k == 1 else (['LoyaltyHouse'] if k == 4 else MEDIATORS)
    for name in names:
        items = d.reindex(columns=ITEMS[name])
        if level == 'existing':
            d[name] = col(d, name).where(items.notna().all(axis=1))
        else:
            d[name] = items.sum(axis=1, min_count=len(ITEMS[name]))
            if level == 'mean':
                d[name] /= len(ITEMS[name])
    return d


def ols_arrays(y, x):
    y, x = np.asarray(y, float), np.asarray(x, float)
    require(len(y) > x.shape[1], 'OLS has no residual degrees of freedom')
    require(np.linalg.matrix_rank(x) == x.shape[1], 'OLS design is rank deficient')
    beta, _, _, _ = np.linalg.lstsq(x, y, rcond=None)
    residual = y - x @ beta
    covariance = (residual @ residual / (len(y) - x.shape[1])) * np.linalg.inv(x.T @ x)
    require(np.isfinite(beta).all() and np.isfinite(covariance).all(), 'Non-finite OLS fit')
    return beta, np.sqrt(np.maximum(np.diag(covariance), 0))


def logit_arrays(y, x, robust=False):
    y, x = np.asarray(y, float), np.asarray(x, float)
    require(len(y) > x.shape[1], 'Logit has insufficient complete cases')
    require(set(np.unique(y)) == {0.0, 1.0}, 'Signed must contain both binary outcomes 0 and 1')
    require(np.linalg.matrix_rank(x) == x.shape[1], 'Logit design is rank deficient')
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter('always')
        fit = sm.Logit(y, x).fit(disp=False, maxiter=200, method='newton', **({'cov_type': 'HC0'} if robust else {}))
    require(fit.mle_retvals.get('converged', False), 'Logit failed to converge')
    require(not any('separation' in str(w.message).lower() for w in caught), 'Logit separation detected')
    require(np.isfinite(fit.params).all() and np.isfinite(fit.bse).all(), 'Non-finite logit coefficients or SEs')
    # Strict sign separation also catches diverging fits in older statsmodels versions.
    margin = (2 * y - 1) * (x @ fit.params)
    require(not np.all(margin > 0), 'Logit perfect separation detected')
    return fit


def hc3_group(a, b):
    y = np.r_[a, b]
    x = sm.add_constant(np.r_[np.ones(len(a)), np.zeros(len(b))], has_constant='add')
    require(len(a) > 1 and len(b) > 1, 'HC3 requires at least two observations per group')
    fit = sm.OLS(y, x).fit(cov_type='HC3', use_t=False)
    return float(fit.pvalues[1])


def independent(a, b, method):
    a, b = np.asarray(a, float), np.asarray(b, float)
    require(len(a) >= 2 and len(b) >= 2, 'Two-sample test requires at least two complete observations per group')
    na, nb, va, vb = len(a), len(b), np.var(a, ddof=1), np.var(b, ddof=1)
    diff = mean(a) - mean(b)
    if method == 'student':
        df = na + nb - 2
        se = np.sqrt(((na - 1) * va + (nb - 1) * vb) / df * (1 / na + 1 / nb))
    else:
        se = np.sqrt(va / na + vb / nb)
        df = ratio((va / na + vb / nb) ** 2, (va / na) ** 2 / (na - 1) + (vb / nb) ** 2 / (nb - 1))
    t = ratio(diff, se)
    return dict(mean_diff=diff, t=t, df=df, p=float(2 * stats.t.sf(abs(t), df)))


def group_desc(a, b):
    na, nb = len(a), len(b)
    pooled = np.sqrt(((na - 1) * sd(a)**2 + (nb - 1) * sd(b)**2) / (na + nb - 2)) if na > 1 and nb > 1 else np.nan
    try:
        robust = hc3_group(a, b)
    except Exception as exc:
        robust = exc
    return dict(mean_loyal=mean(a), sd_loyal=sd(a), mean_control=mean(b), sd_control=sd(b),
                mean_diff=mean(a) - mean(b), d=ratio(mean(a) - mean(b), pooled), p_hc3=robust)


def pairs(d, outcome, extra=None):
    # Pair eligibility is structural and precedes outcome-specific complete cases.
    if '_pair_eligible' in d:
        d = d.loc[d['_pair_eligible']]
    counts = pd.crosstab(d['_unit'], col(d, 'cond')).reindex(columns=['loyal', 'control'], fill_value=0)
    sizes = d.groupby('_unit').size()
    ids = counts.index[(counts['loyal'] == 1) & (counts['control'] == 1) & sizes.reindex(counts.index).eq(2)]
    q = d.loc[d['_unit'].isin(ids)]
    p = q.pivot(index='_unit', columns='cond', values=outcome).reindex(columns=['loyal', 'control']).dropna()
    if extra:
        # Between-person metadata must agree across the person's rows.
        values = q.groupby('_unit')[extra].agg(lambda a: a.dropna().iloc[0] if a.dropna().nunique() == 1 else np.nan)
        p[extra] = values
        p = p.dropna()
    return p


def paired_values(d, outcome):
    p = pairs(d, outcome)
    a, b = p['loyal'].to_numpy(), p['control'].to_numpy()
    dif = a - b
    n = len(dif)
    se = sd(dif) / np.sqrt(n) if n else np.nan
    t = ratio(mean(dif), se)
    robust = np.nan
    if n > 1:
        robust = float(sm.OLS(dif, np.ones((n, 1))).fit(cov_type='HC3', use_t=False).pvalues[0])
    return dict(mean_loyal=mean(a), sd_loyal=sd(a), mean_control=mean(b), sd_control=sd(b),
                mean_diff=mean(dif), se_diff=se, t=t, df=n-1 if n else np.nan,
                p=float(2 * stats.t.sf(abs(t), n-1)), n=n,
                d=ratio(mean(dif), np.sqrt((sd(a)**2 + sd(b)**2) / 2)), dz=ratio(mean(dif), sd(dif)), p_hc3=robust)


def descriptives(r, d, k, variables):
    for v in variables:
        r.scalar(f'D{k}.mean.{v}', 'descriptive', lambda v=v: col(d, v).mean())
        r.scalar(f'D{k}.sd.{v}', 'descriptive', lambda v=v: col(d, v).std(ddof=1))
    for a, b in itertools.combinations(sorted(variables, key=lambda x: x.encode('utf-8')), 2):
        r.scalar(f'D{k}.r.{a}|{b}', 'pearson', lambda a=a, b=b: correlation(d, a, b))


def correlation(d, a, b):
    q = cc(d, [a, b])
    require(len(q) >= 2, 'Pearson correlation requires two complete pairs')
    require(q[a].std() > 0 and q[b].std() > 0, 'Pearson correlation requires nonzero variances')
    return float(stats.pearsonr(q[a], q[b]).statistic)


def alpha(d, items):
    q = cc(d, items)
    require(len(q) >= 2, 'Alpha requires at least two complete item rows')
    total_var = q.sum(axis=1).var(ddof=1)
    require(total_var > 0, 'Alpha requires positive total-score variance')
    return len(items) / (len(items)-1) * (1 - q.var(ddof=1).sum() / total_var)


def reliability(r, d, k):
    sets = {}
    cors = {}
    if k == 1:
        sets = {'loyal_comb': ITEMS['loyal_comb'], 'perceived_ethic_import': ['pie1', 'pie2', 'pie3', 'pie4_rev']}
        cors = {'magnitude': ['magnitude1_rev', 'magnitude2'], 'prob_of_effect': ['prob_effect1', 'prob_effect2_rev'],
                'temp_immediacy': ['temp_imm1', 'temp_imm2_rev'], 'proximity_effect': ['proxim_eff1_rev', 'proxim_eff2'],
                'social_consensus': ['social_cons1', 'social_cons2_rev'], 'concentration_of_effect': ['concen_eff1_rev', 'concen_eff2']}
    if k in (2, 3):
        sets = {v: ITEMS[v] for v in MEDIATORS if v != 'val_align_part_broker'}
        cors = {'val_align_part_broker': ITEMS['val_align_part_broker']}
    if k == 2:
        d = d.copy()
        d['_inttrust_accused3_rev'] = 8 - col(d, 'inttrust_accused3')
        sets.update({'benev_trust_accused': [f'bentrust_accused{i}' for i in range(1, 4)],
                     'integ_trust_accused': [f'inttrust_accused{i}' for i in range(1, 4)],
                     'integ_trust_accused_rev3': ['inttrust_accused1', 'inttrust_accused2', '_inttrust_accused3_rev'],
                     'group_cohesion_pre': [f'group_cohesion{i}_pre' for i in range(1, 4)],
                     'group_cohesion_post': [f'group_cohesion{i}_post' for i in range(1, 4)]})
    for name, items in sets.items():
        r.scalar(f'R{k}.{name}.alpha', 'cronbach_alpha', lambda items=items: alpha(d, items))
    for name, items in cors.items():
        r.scalar(f'R{k}.{name}.r', 'pearson', lambda items=items: correlation(d, *items))


def gender_comparison(r, d, prefix):
    a = col(d.loc[col(d, 'gender').eq(2)], 'you_grant').dropna().to_numpy()
    b = col(d.loc[col(d, 'gender').eq(1)], 'you_grant').dropna().to_numpy()
    r.emit(prefix, 'descriptive', ['mean_male', 'sd_male', 'mean_female', 'sd_female'],
           lambda: dict(mean_male=mean(a), sd_male=sd(a), mean_female=mean(b), sd_female=sd(b)))
    for method in ['student', 'welch']:
        r.emit(prefix, method, ['t', 'df', 'p'], lambda method=method: independent(a, b, method))


def mixed_anova(d, outcome, main=False):
    p = pairs(d, outcome, 'wrongdoing_num').reset_index()
    p['difference'] = p['loyal'] - p['control']
    require(p['wrongdoing_num'].nunique() >= 2, 'ANOVA requires two observed wrongdoing levels')
    fit = smf.ols('difference ~ C(wrongdoing_num, Sum)', p).fit()
    require(fit.df_resid > 0, 'ANOVA has no residual degrees of freedom')
    if main:
        t = float(fit.tvalues['Intercept'])
        return dict(F=t*t, df1=1, df2=fit.df_resid, p=float(fit.pvalues['Intercept']))
    return dict(F=fit.fvalue, df1=fit.df_model, df2=fit.df_resid, p=fit.f_pvalue)


def lmm(d, outcome, nested=False):
    names = [outcome, 'cond_recode', 'part_uid'] + (['wrongdoing_num'] if nested else [])
    q = cc(d, names)
    require(len(q) > 3 and q['part_uid'].nunique() > 1, 'Insufficient complete cases for mixed model')
    require(q['cond_recode'].nunique() > 1, 'No condition variation in mixed model')
    if nested:
        require(q.groupby('part_uid')['wrongdoing_num'].nunique().max() == 1, 'Person is not nested in wrongdoing')
        require(q['wrongdoing_num'].nunique() > 1, 'Nested mixed model needs two wrongdoing groups')
        model = smf.mixedlm(f'{outcome} ~ cond_recode', q, groups=q['wrongdoing_num'],
                            re_formula='1', vc_formula={'person': '0 + C(part_uid)'})
    else:
        model = smf.mixedlm(f'{outcome} ~ cond_recode', q, groups=q['part_uid'], re_formula='1')
    errors = []
    for optimizer in ['lbfgs', 'bfgs', 'powell']:
        try:
            fit = model.fit(reml=True, method=optimizer, disp=False, maxiter=1000)
            require(fit.converged, 'Mixed model did not converge')
            coef, se = float(fit.fe_params['cond_recode']), float(fit.bse_fe['cond_recode'])
            require(np.isfinite(coef) and np.isfinite(se) and se > 0, 'Undefined mixed model coefficient or SE')
            return dict(coef=coef, se=se, p=npvalue(coef/se))
        except Exception as exc:
            errors.append(f'{optimizer}: {exc}')
    raise ValueError('; '.join(errors))


def dataset1(r, d):
    for o in OUTCOMES + ['loyal_comb']:
        r.emit(f'P1.{o}', 'paired', PAIRED_KEYS, lambda o=o: paired_values(d, o))
    for o in OUTCOMES:
        for prefix, main in [('M1', False), ('ME1', True)]:
            r.emit(f'{prefix}.{o}', 'mixed_anova', ['F', 'df1', 'df2', 'p'], lambda o=o, main=main: mixed_anova(d, o, main))
        for method, nested in [('ri_person', False), ('ri_person_wrongdoing', True)]:
            r.emit(f'LMM1.{o}', method, ['coef', 'se', 'p'], lambda o=o, nested=nested: lmm(d, o, nested))
    descriptives(r, d, 1, ['cond_recode'] + OUTCOMES)
    reliability(r, d, 1)
    r.scalar('N1.rows', 'descriptive', lambda: len(d))
    # Structural pairs; no outcome-specific missing-data restriction for this count.
    r.scalar('N1.n', 'descriptive', lambda: structural_pair_count(d))
    person = d.drop_duplicates('_unit', keep='first')
    for stat in ['mean', 'sd']:
        r.scalar(f'N1.age.{stat}', 'descriptive', lambda stat=stat: col(person, 'age').mean() if stat == 'mean' else col(person, 'age').std(ddof=1))
    for s in ['sexual_harassment', 'all']:
        q = d.loc[col(d, 'wrongdoing_num').eq(1)] if s == 'sexual_harassment' else d
        for g, code in [('male', 2), ('female', 1)]:
            sub = q.loc[col(q, 'gender').eq(code)]
            a = col(sub.loc[col(sub, 'cond').eq('loyal')], 'you_grant').dropna().to_numpy()
            b = col(sub.loc[col(sub, 'cond').eq('control')], 'you_grant').dropna().to_numpy()
            r.emit(f'G1W.{s}.{g}', 'paired', ['t', 'df', 'p'], lambda sub=sub: paired_values(sub, 'you_grant'))
            for method in ['student', 'welch']:
                r.emit(f'G1W.{s}.{g}', method, ['t', 'df', 'p'], lambda method=method: independent(a, b, method))
    scenarios = ['sexual_harassment', 'theft', 'false_advertising', 'fraud', 'bribery', 'plagiarism', 'dishonesty']
    for num, w in list(enumerate(scenarios, 1)) + [(None, 'average')]:
        for c in ['loyal', 'control']:
            sub = d.loc[col(d, 'cond').eq(c)]
            if num is not None:
                sub = sub.loc[col(sub, 'wrongdoing_num').eq(num)]
            gender_comparison(r, sub, f'G1C.{w}.{c}')
    if r.context[2] == 'mean':
        for o in OUTCOMES:
            r.loo(d, f'P1.{o}', lambda q, o=o: extract(paired_values(q, o), 'mean_diff', 'p'))


def structural_pair_count(d):
    counts = pd.crosstab(d['_unit'], col(d, 'cond')).reindex(columns=['loyal', 'control'], fill_value=0)
    return int(((counts['loyal'] == 1) & (counts['control'] == 1) & d.groupby('_unit').size().reindex(counts.index).eq(2)).sum())


def extract(values, *keys):
    return tuple(values[key] for key in keys)


def path_fit(arr, nmed, logistic=False):
    # Columns: X, outcome, mediator(s). A single common complete-case analysis sample.
    x, y, mediators = arr[:, 0], arr[:, 1], arr[:, 2:]
    base = np.column_stack([np.ones(len(arr)), x])
    design = np.column_stack([base, mediators])
    if logistic:
        fit = logit_arrays(y, design)
        by, sey = np.asarray(fit.params), np.asarray(fit.bse)
    else:
        by, sey = ols_arrays(y, design)
    total = ols_arrays(y, base)[0][1] if not logistic else np.nan
    result = []
    for j in range(nmed):
        am, sea = ols_arrays(mediators[:, j], base)
        a, b = am[1], by[j+2]
        se = np.sqrt(a*a*sey[j+2]**2 + b*b*sea[1]**2)
        ind = a*b
        result.append(dict(ind=ind, a=a, b=b, c_prime=by[1], total=total, se_delta=se,
                           p_delta=npvalue(ratio(ind, se)), ci_norm_low=ind-1.96*se, ci_norm_high=ind+1.96*se))
    return result


def serial_fit(arr):
    x, y, m1, m2 = arr.T
    base = np.column_stack([np.ones(len(arr)), x])
    a, sa = ols_arrays(m1, base)
    d, sd_ = ols_arrays(m2, np.column_stack([base, m1]))
    b, sb = ols_arrays(y, np.column_stack([base, m1, m2]))
    a1, d21, b2 = a[1], d[2], b[3]
    ind = a1*d21*b2
    se = np.sqrt((d21*b2*sa[1])**2 + (a1*b2*sd_[2])**2 + (a1*d21*sb[3])**2)
    return [dict(ind=ind, a1=a1, d21=d21, b2=b2, se_delta=se, p_delta=npvalue(ratio(ind, se)))]


def bootstrap(arr, fitter, point, boot, seed, identity):
    # SHA-256 produces stable model streams, independent of traversal and Python hash randomization.
    digest = hashlib.sha256(identity.encode('utf-8')).digest()
    rng = np.random.default_rng(np.random.SeedSequence([seed] + list(np.frombuffer(digest, dtype='<u4'))))
    estimates, failed = [], 0
    for _ in range(boot):
        try:
            with warnings.catch_warnings():
                warnings.simplefilter('ignore')
                fits = fitter(arr[rng.integers(0, len(arr), len(arr))])
            estimate = [f['ind'] for f in fits]
            require(np.isfinite(estimate).all(), 'Non-finite bootstrap estimate')
            estimates.append(estimate)
        except Exception:
            failed += 1
    output = []
    for j, original in enumerate(point):
        vals = np.asarray(estimates)[:, j] if estimates else np.array([])
        res = dict(boot_failed=failed)
        if len(vals) >= 2:
            fraction = (np.sum(vals < original['ind']) + 0.5*np.sum(vals == original['ind'])) / len(vals)
            z0 = stats.norm.ppf(fraction)
            probs = stats.norm.cdf([2*z0-1.96, 2*z0+1.96])
            low, high = np.quantile(vals, probs, method='linear')
            plow, phigh = np.quantile(vals, [.025, .975], method='linear')
            res.update(se_boot=sd(vals), ci_bc_low=low, ci_bc_high=high, ci_perc_low=plow, ci_perc_high=phigh)
        else:
            res.update({key: ValueError('Fewer than two successful bootstrap fits') for key in BOOT_KEYS if key != 'boot_failed'})
        output.append(res)
    return output


def mediation(r, d, prefixes, names, fitter, method, keys, do_boot):
    arr = cc(d, names).to_numpy(float)
    try:
        point = fitter(arr)
        point_error = None
    except Exception as exc:
        point = [{key: exc for key in keys} for _ in prefixes]
        point_error = exc
    for prefix, values in zip(prefixes, point):
        r.emit(prefix, method, keys, lambda values=values: values)
    if do_boot:
        if point_error is None:
            identity = '|'.join(map(str, [*r.context, method, *prefixes]))
            bs = bootstrap(arr, fitter, point, r.args.boot, r.args.seed, identity)
        else:
            # With no original fit, interval endpoints are undefined. Still attempt resamples
            # so boot_failed counts only actual failed fits, never skipped attempts.
            placeholder = [dict(ind=np.nan) for _ in prefixes]
            bs = bootstrap(arr, fitter, placeholder, r.args.boot, r.args.seed,
                           '|'.join(map(str, [*r.context, method, *prefixes])))
            for values in bs:
                for key in BOOT_KEYS:
                    if key != 'boot_failed':
                        values[key] = ValueError(f'Original model fit failed: {point_error}')
        for prefix, values in zip(prefixes, bs):
            r.emit(prefix, method, BOOT_KEYS, lambda values=values: values)


def dataset2(r, d):
    for o in OUTCOMES:
        a = col(d.loc[col(d, 'cond_recode').eq(1)], o).dropna().to_numpy()
        b = col(d.loc[col(d, 'cond_recode').eq(0)], o).dropna().to_numpy()
        r.emit(f'T2.{o}', 'descriptive', GROUP_DESC, lambda: group_desc(a, b))
        for method in ['welch', 'student']:
            r.emit(f'T2.{o}', method, ['t', 'df', 'p'], lambda method=method: independent(a, b, method))
        mediation(r, d, [f'PM2.{o}.{m}' for m in MEDIATORS], ['cond_recode', o] + MEDIATORS,
                  lambda a: path_fit(a, 4), 'ols', PATH_KEYS, r.context[2] == 'mean')
        for m in MEDIATORS:
            mediation(r, d, [f'SI2.{o}.{m}'], ['cond_recode', o, m], lambda a: path_fit(a, 1),
                      'ols', PATH_KEYS, r.context[2] == 'mean')
    for m in ['val_align_part_broker', 'relconcerns_with_broker']:
        mediation(r, d, [f'SM2.{m}'], ['cond_recode', 'you_grant', 'benev_trust_broker', m], serial_fit,
                  'ols', SERIAL_KEYS, r.context[2] == 'mean')
    descriptives(r, d, 2, ['cond_recode'] + OUTCOMES + MEDIATORS)
    reliability(r, d, 2)
    for key, value in [('n', len(d)), ('n_loyal', col(d, 'cond_recode').eq(1).sum()), ('n_control', col(d, 'cond_recode').eq(0).sum()),
                       ('age.mean', col(d, 'age').mean()), ('age.sd', col(d, 'age').std(ddof=1))]:
        r.scalar(f'N2.{key}', 'descriptive', lambda value=value: value)
    for g, code in [('male', 2), ('female', 1)]:
        sub = d.loc[col(d, 'gender').eq(code)]
        a = col(sub.loc[col(sub, 'cond_recode').eq(1)], 'you_grant').dropna().to_numpy()
        b = col(sub.loc[col(sub, 'cond_recode').eq(0)], 'you_grant').dropna().to_numpy()
        for method in ['student', 'welch']:
            r.emit(f'G2W.all.{g}', method, ['t', 'df', 'p'], lambda method=method: independent(a, b, method))
    for c, code in [('loyal', 1), ('control', 0)]:
        gender_comparison(r, d.loc[col(d, 'cond_recode').eq(code)], f'G2C.{c}')
    if r.context[2] == 'mean':
        for o in OUTCOMES:
            r.loo(d, f'T2.{o}', lambda q, o=o: extract(independent(
                col(q.loc[col(q, 'cond_recode').eq(1)], o).dropna().to_numpy(),
                col(q.loc[col(q, 'cond_recode').eq(0)], o).dropna().to_numpy(), 'welch'), 'mean_diff', 'p'))
            for m in ['benev_trust_broker', 'val_align_part_broker', 'relconcerns_with_broker']:
                j = MEDIATORS.index(m)
                r.loo(d, f'PM2.{o}.{m}', lambda q, o=o, j=j: extract(path_fit(cc(q, ['cond_recode', o]+MEDIATORS).to_numpy(float), 4)[j], 'ind', 'p_delta'))

CELL_CODES = {'LC': (1, 0), 'CC': (0, 0), 'LD': (1, 1), 'CD': (0, 1)}


def cell_data(d, outcome):
    q = cc(d, [outcome, 'cond_rel_recode', 'cond_brokhist_recode']).copy()
    q['cell'] = [next((label for label, codes in CELL_CODES.items() if codes == (a, b)), None)
                 for a, b in zip(q['cond_rel_recode'], q['cond_brokhist_recode'])]
    require(q['cell'].notna().all(), 'Factor values outside the specified 0/1 codes')
    return q


def anova3(d, outcome, typ):
    q = cell_data(d, outcome)
    require(q['cell'].nunique() == 4, 'Full factorial ANOVA requires all four cells')
    formula = f'{outcome} ~ C(cond_rel_recode, Sum) * C(cond_brokhist_recode, Sum)'
    fit = smf.ols(formula, q).fit()
    require(fit.df_resid > 0, 'ANOVA has no residual degrees of freedom')
    table = anova_lm(fit, typ=typ)
    sse, sst = float(table.loc['Residual', 'sum_sq']), float(fit.centered_tss)
    names = ['C(cond_rel_recode, Sum)', 'C(cond_brokhist_recode, Sum)',
             'C(cond_rel_recode, Sum):C(cond_brokhist_recode, Sum)']
    result = {}
    for term, name in zip(['relationship', 'history', 'interaction'], names):
        row = table.loc[name]
        ss = float(row['sum_sq'])
        result[term] = dict(F=float(row['F']), df1=float(row['df']), df2=float(fit.df_resid),
                            p=float(row['PR(>F)']), eta2=ratio(ss, ss+sse), eta2_classic=ratio(ss, sst))
    return result


def contrast3(d, outcome, hypothesis, method):
    q = cell_data(d, outcome)
    other = 'CC' if hypothesis == 'H1' else 'LD'
    a = q.loc[q['cell'].eq('LC'), outcome].to_numpy()
    b = q.loc[q['cell'].eq(other), outcome].to_numpy()
    diff = mean(a) - mean(b)
    if method in ('student', 'welch'):
        return independent(a, b, method)
    if method == 'descriptive':
        pooled = np.sqrt(((len(a)-1)*sd(a)**2 + (len(b)-1)*sd(b)**2)/(len(a)+len(b)-2)) if len(a)>1 and len(b)>1 else np.nan
        values = dict(d=ratio(diff, np.sqrt((sd(a)**2+sd(b)**2)/2)), d_pooled=ratio(diff, pooled))
        try:
            require(q['cell'].nunique() == 4, 'HC3 full cell model requires all four cells')
            require(q.groupby('cell').size().min() > 1, 'HC3 full cell model requires at least two rows in each cell')
            x = np.column_stack([q['cell'].eq(c).to_numpy(float) for c in CELL_CODES])
            fit = sm.OLS(q[outcome].to_numpy(float), x).fit(cov_type='HC3', use_t=False)
            contrast = np.array([1, -1 if other == 'CC' else 0, -1 if other == 'LD' else 0, 0])
            values['p_hc3'] = float(np.asarray(fit.t_test(contrast).pvalue).item())
        except Exception as exc:
            values['p_hc3'] = exc
        return values
    require(q['cell'].nunique() == 4, 'Pooled contrast requires all four cells')
    require(len(q) > 4 and len(a) > 0 and len(b) > 0, 'Insufficient observations for pooled contrast')
    residual = q[outcome] - q.groupby('cell')[outcome].transform('mean')
    df = len(q)-4
    mse = float(residual @ residual / df)
    se = np.sqrt(mse*(1/len(a)+1/len(b)))
    t = ratio(diff, se)
    return dict(mean_diff=diff, t=t, df=df, p=float(2*stats.t.sf(abs(t), df)))


def dataset3(r, d):
    for o in OUTCOMES + MEDIATORS:
        for typ in [3, 2, 1]:
            try:
                table = anova3(d, o, typ)
            except Exception as exc:
                table = {term: {key: exc for key in ['F', 'df1', 'df2', 'p', 'eta2', 'eta2_classic']}
                         for term in ['relationship', 'history', 'interaction']}
            for term in ['relationship', 'history', 'interaction']:
                r.emit(f'A3.{o}.{term}', f'type{typ}', ['F', 'df1', 'df2', 'p', 'eta2', 'eta2_classic'],
                       lambda term=term: table[term])
        for cell, (rel, hist) in CELL_CODES.items():
            vals = col(d.loc[col(d, 'cond_rel_recode').eq(rel) & col(d, 'cond_brokhist_recode').eq(hist)], o).dropna().to_numpy()
            r.emit(f'C3.cell.{o}.{cell}', 'descriptive', ['mean', 'sd', 'n'], lambda: dict(mean=mean(vals), sd=sd(vals), n=len(vals)))
        for h in ['H1', 'H3']:
            for method in ['pooled', 'student', 'welch', 'descriptive']:
                keys = ['d', 'd_pooled', 'p_hc3'] if method == 'descriptive' else ['mean_diff', 't', 'df', 'p']
                r.emit(f'C3.{h}.{o}', method, keys, lambda method=method, h=h, o=o: contrast3(d, o, h, method))
    descriptives(r, d, 3, ['cond_rel_recode', 'cond_brokhist_recode'] + OUTCOMES + MEDIATORS)
    reliability(r, d, 3)
    for key, value in [('n', len(d)), ('age.mean', col(d, 'age').mean()), ('age.sd', col(d, 'age').std(ddof=1))]:
        r.scalar(f'N3.{key}', 'descriptive', lambda value=value: value)
    if r.context[2] == 'mean':
        for o in OUTCOMES:
            for h in ['H1', 'H3']:
                r.loo(d, f'C3.{h}.{o}', lambda q, o=o, h=h: extract(contrast3(q, o, h, 'pooled'), 'mean_diff', 'p'))


LOGIT_PREDICTORS = {
    'M1': ['LoyalRequestor'],
    'M2': ['LoyalRequestor', 'KnowRequestor', 'LikeRequestor', 'SemestersRequestor'],
    'M3': ['LoyalRequestor', 'KnowRequestor', 'LikeRequestor', 'SemestersRequestor', 'LoyaltyHouse'],
}


def fit_logit(d, predictors):
    q = cc(d, ['Signed'] + predictors)
    x = np.column_stack([np.ones(len(q)), q[predictors].to_numpy(float)])
    return logit_arrays(q['Signed'].to_numpy(float), x)


def logit_summary(d, predictors):
    fit = fit_logit(d, predictors)
    params, bse = np.asarray(fit.params), np.asarray(fit.bse)
    # HC0 = H^-1 (sum of individual score outer products) H^-1, no small-sample correction.
    try:
        bread = np.linalg.inv(-fit.model.hessian(params))
        score = fit.model.score_obs(params)
        covariance = bread @ (score.T @ score) @ bread
        robust_se = np.sqrt(np.diag(covariance))
        robust_p = [npvalue(ratio(b, s)) for b, s in zip(params, robust_se)]
    except Exception as exc:
        robust_p = [exc]*len(params)
    terms = {}
    for j, name in enumerate(['Intercept'] + predictors):
        with np.errstate(over='ignore'):
            odds = float(np.exp(params[j]))
        terms[name] = dict(coef=params[j], se=bse[j], z=ratio(params[j], bse[j]),
                           p=npvalue(ratio(params[j], bse[j])), **{'or': odds}, p_hc0=robust_p[j])
    y = fit.model.endog
    rate = mean(y)
    ll_null = float(np.sum(y*np.log(rate) + (1-y)*np.log1p(-rate)))
    ll = float(fit.llf)
    goodness = dict(ll=ll, mcf=1-ll/ll_null, cs=1-np.exp(2*(ll_null-ll)/len(y)), n=len(y))
    return terms, goodness


def chi4(d):
    q = cc(d, ['Signed', 'StrongLoyaltyRequestor'])
    tab = pd.crosstab(q['Signed'], q['StrongLoyaltyRequestor'])
    require(tab.shape[0] >= 2 and tab.shape[1] >= 2, 'Chi-square requires at least two observed categories in each variable')
    result = stats.chi2_contingency(tab, correction=False)
    return dict(chi2=float(result.statistic), df=int(result.dof), p=float(result.pvalue))


def dataset4(r, d):
    for model, predictors in LOGIT_PREDICTORS.items():
        try:
            terms, goodness = logit_summary(d, predictors)
        except Exception as exc:
            terms = {name: {key: exc for key in LOGIT_TERMS} for name in ['Intercept'] + predictors}
            goodness = {key: exc for key in ['ll', 'mcf', 'cs', 'n']}
            goodness['n'] = len(cc(d, ['Signed']+predictors))
        for term in ['Intercept'] + predictors:
            r.emit(f'L4.{model}.{term}', 'logit', LOGIT_TERMS, lambda term=term: terms[term])
        r.emit(f'L4.{model}.fit', 'logit', ['ll', 'mcf', 'cs', 'n'], lambda: goodness)
    for name, predictor in [('strong', 'StrongLoyaltyRequestor'), ('exp', 'ExpLoyaltyRequestor'), ('house', 'LoyaltyHouse')]:
        r.emit(f'L4.ALT.{name}', 'logit', ['coef', 'se', 'z', 'p', 'or'],
               lambda predictor=predictor: logit_summary(d, [predictor])[0][predictor])
    r.emit('CHI4.strong', 'pearson', ['chi2', 'df', 'p'], lambda: chi4(d))
    for method in ['linear_cont', 'logit_cont', 'linear_strong', 'logit_strong']:
        x = 'LoyalRequestor' if method.endswith('_cont') else 'StrongLoyaltyRequestor'
        logistic = method.startswith('logit')
        for model in ['sim', 'ind']:
            sets = [['SignedTrust', 'SignedRisk']] if model == 'sim' else [['SignedTrust'], ['SignedRisk']]
            for meds in sets:
                mediation(r, d, [f'MED4.{model}.{m}' for m in meds], [x, 'Signed']+meds,
                          lambda a, meds=meds, logistic=logistic: path_fit(a, len(meds), logistic),
                          method, MED4_KEYS, r.context[2] == 'existing')
    descriptives(r, d, 4, ['Signed', 'LoyalRequestor', 'KnowRequestor', 'LikeRequestor', 'SemestersRequestor', 'LoyaltyHouse'])
    for key, value in [('n', len(d)), ('signed_count', col(d, 'Signed').eq(1).sum()),
                       ('signed_share', ratio(col(d, 'Signed').eq(1).sum(), col(d, 'Signed').notna().sum())),
                       ('age.mean', col(d, 'Age').mean()), ('age.sd', col(d, 'Age').std(ddof=1))]:
        r.scalar(f'N4.{key}', 'descriptive', lambda value=value: value)
    if r.context[2] == 'existing':
        for model, predictors in LOGIT_PREDICTORS.items():
            r.loo(d, f'L4.{model}.LoyalRequestor', lambda q, predictors=predictors:
                  extract(logit_summary(q, predictors)[0]['LoyalRequestor'], 'coef', 'p'))


def write_outputs(r, out):
    out.mkdir(parents=True, exist_ok=True)
    results = pd.DataFrame(r.rows, columns=RESULT_COLUMNS)
    influence = pd.DataFrame(r.influence, columns=INFLUENCE_COLUMNS)
    sample = pd.DataFrame(r.samples, columns=['dataset', 'sample_level', 'unit_id'])
    require(not results.duplicated(RESULT_COLUMNS[:5]).any(), 'Internal error: duplicate result identity')
    results.to_csv(out/'results.csv', index=False, float_format='%.17g')
    influence.to_csv(out/'influence.csv', index=False, float_format='%.17g')
    sample.to_csv(out/'samples.csv', index=False)
    info = [f'Python: {sys.version}', f'Executable: {sys.executable}', f'Platform: {platform.platform()}',
            f'numpy: {np.__version__}', f'pandas: {pd.__version__}', f'scipy: {scipy.__version__}',
            f'statsmodels: {statsmodels.__version__}', f'seed: {r.args.seed}', f'boot: {r.args.boot}',
            'RNG: numpy default_rng; model streams derived with SHA-256 and SeedSequence',
            'CSV floats: 17 significant digits; two-sided p values; normal reference for robust and Wald tests',
            'Warnings (deduplicated):'] + sorted(r.warnings)
    (out/'session_info.txt').write_text('\n'.join(info)+'\n')
    failures = results.loc[results.status.eq('failed')]
    influence_failures = influence.loc[influence.status.eq('failed')]
    lines = ['# Unmet quantities', '', 'This file records computational failures for this run, not interpretations of the data.', '']
    if failures.empty and influence_failures.empty:
        lines.append('None. All requested quantities and influence refits were computed.')
    else:
        for row in failures.itertuples():
            lines.append(f'- {row.dataset} / {row.sample_level} / {row.composite_level} / {row.key} / {row.method}: {row.message}')
        for row in influence_failures.itertuples():
            lines.append(f'- Influence {row.dataset} / {row.sample_level} / {row.estimand} / deleted unit {row.deleted_unit}: {row.message}')
    failed_boot = results.loc[results.key.str.endswith('.boot_failed') & results.value.gt(0)]
    if not failed_boot.empty:
        lines += ['', '## Bootstrap fit discards', '', 'These are counted discards; intervals use the remaining successful fits.']
        for row in failed_boot.itertuples():
            lines.append(f'- {row.sample_level} / {row.key} / {row.method}: {int(row.value)} of {r.args.boot} fits failed.')
    (out/'unmet.md').write_text('\n'.join(lines)+'\n')
    # The assignment requires this log alongside the delivered script as well.
    script_out = Path(__file__).resolve().parent
    if script_out != out.resolve():
        try:
            (script_out/'unmet.md').write_text('\n'.join(lines)+'\n')
        except OSError as exc:
            # A deployed, read-only script directory must not prevent the requested outputs.
            with (out/'session_info.txt').open('a') as handle:
                handle.write(f'Could not copy unmet.md beside script: {exc}\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--seed', type=int, default=20261031)
    parser.add_argument('--boot', type=int, default=5000)
    args = parser.parse_args()
    parser.error('--boot must be at least 2') if args.boot < 2 else None
    parser.error('--seed must be nonnegative') if args.seed < 0 else None
    r = Report(args)
    for k, runner in enumerate([dataset1, dataset2, dataset3, dataset4], 1):
        read_error = None
        try:
            raw = read_data(args.data/f'dataset_{k}.csv', k)
        except Exception as exc:
            raw = pd.DataFrame({'_unit': pd.Series(dtype=object)})
            read_error = f'dataset_{k}.csv could not be read: {type(exc).__name__}: {exc}'
            r.warnings.add(read_error)
        for sample_level, sampled in samples(raw, k).items():
            if k == 1:
                counts = pd.crosstab(sampled['_unit'], col(sampled, 'cond')).reindex(columns=['loyal', 'control'], fill_value=0)
                eligible = counts.index[(counts['loyal'] == 1) & (counts['control'] == 1)
                                        & sampled.groupby('_unit').size().reindex(counts.index).eq(2)]
                sampled['_pair_eligible'] = sampled['_unit'].isin(eligible)
            for unit in pd.unique(sampled['_unit']):
                r.samples.append(dict(dataset=k, sample_level=sample_level, unit_id=unit))
            for level in (['existing', 'mean'] if k == 4 else ['mean', 'sum', 'existing']):
                r.context = (k, sample_level, level)
                print(f'Dataset {k}: {sample_level}, {level}', flush=True)
                first_row = len(r.rows)
                runner(r, composites(sampled, k, level))
                if read_error:
                    for row in r.rows[first_row:]:
                        row.update(value=np.nan, status='failed', message=read_error)
    write_outputs(r, args.out)
    print(f'Wrote {len(r.rows)} results, {len(r.influence)} influence rows, and {len(r.samples)} retained units.', flush=True)


if __name__ == '__main__':
    main()
