#!/usr/bin/env python
"""PAPER_X: continuous-indicator CFA, specification grid, and deletion influence."""
import os
# Bound BLAS parallelism before importing numerical libraries; keeps small fits fast.
for _key in ('OPENBLAS_NUM_THREADS', 'OMP_NUM_THREADS', 'MKL_NUM_THREADS', 'VECLIB_MAXIMUM_THREADS'):
    os.environ[_key] = '1'
import argparse
import hashlib
import importlib.metadata
import json
import math
from pathlib import Path
import platform
import time
import traceback
import warnings
import numpy as np
import pandas as pd
from scipy import linalg, optimize, stats

ROOT = Path(__file__).resolve().parent.parent
YEARS = (1976, 1991, 2006)
PAIRS = {'P1': (0, 1), 'P2': (1, 2), 'P3': (0, 2)}
FACTORS = {
    'K1': ['V4236', 'V4238', 'V4240', 'V4246'],
    'K2': ['V4227', 'V4225', 'V4231', 'V4232', 'V4234', 'V4242', 'V4243'],
    'K3': ['V4235', 'V4229'], 'K4': ['V4233', 'V4245'],
    'K5': ['V4226', 'V4228', 'V4230', 'V4244'],
    'K6': ['V4239', 'V4241'], 'K7': ['V4237', 'V4247']}
FIVE = {k: v for k, v in FACTORS.items() if k in ('K1', 'K2', 'K3', 'K4', 'K5')}
CFACTORS = {'C1': ['V3224', 'V3225', 'V3222', 'V3223', 'V3227'], 'C2': ['V3226']}
F3 = [f'V{i}' for i in range(3222, 3228)]
F4 = [f'V{i}' for i in range(4225, 4248)]
RELEASED = {'V4238', 'V4240', 'V4231', 'V4229', 'V4230', 'V4228'}
SPECS = ['S00', 'S01', 'S02', 'S03', 'S04', 'S05', 'S06', 'S07a', 'S07b', 'S08', 'CHK1', 'CHK2']


def versions():
    return {'python': platform.python_version(), **{p: importlib.metadata.version(p)
            for p in ('numpy', 'scipy', 'pandas', 'statsmodels', 'semopy', 'numdifftools')}}


def clean(obj):
    if isinstance(obj, dict):
        return {str(k): clean(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [clean(v) for v in obj]
    if isinstance(obj, np.ndarray):
        return clean(obj.tolist())
    if isinstance(obj, (np.integer,)):
        return int(obj)
    if isinstance(obj, (float, np.floating)):
        return float(obj) if np.isfinite(obj) else None
    if isinstance(obj, (np.bool_,)):
        return bool(obj)
    return obj


def write_json(path, obj):
    path.parent.mkdir(exist_ok=True)
    path.write_text(json.dumps(clean(obj), indent=2, allow_nan=False) + '\n')


def serial(v):
    f = float(v)
    return str(int(f)) if f.is_integer() else repr(f)


def sample_info(ids, year):
    vals = np.sort(np.asarray(ids, dtype=float))
    if not np.isfinite(vals).all() or len(np.unique(vals)) != len(vals):
        raise ValueError('V4 must be finite and unique within a file')
    # Newline separators, no terminal newline. Integral V4 has no decimal suffix.
    h = hashlib.sha256('\n'.join(serial(x) for x in vals).encode('utf-8')).hexdigest()
    return {'year': int(year), 'n': len(vals), 'V4_sha256': h}


def covariance(x, w=None, ml=False):
    n = len(x)
    if n < 2:
        raise ValueError('At least two observations required')
    w = np.ones(n) if w is None else np.asarray(w) * n / np.sum(w)
    m = np.sum(x * w[:, None], axis=0) / n
    z = x - m
    return m, (z.T * w) @ z / (n if ml else n - 1)


class Sample:
    def __init__(self, x, ids, year, w=None, ml=False, fiml=False):
        self.x = np.asarray(x, dtype=float)
        self.ids = np.asarray(ids)
        self.year = year
        self.n, self.p = self.x.shape
        self.w = w
        self.ml = ml
        self.fiml = fiml
        self.c = self.n if ml or fiml else self.n - 1
        self.info = sample_info(ids, year)
        if fiml:
            self.m = np.nanmean(self.x, axis=0)
            # Pairwise moments initialize unrestricted normal EM only.
            self.s = pd.DataFrame(self.x).cov(ddof=1).to_numpy()
            self.patterns = []
            masks, inverse = np.unique(np.isfinite(self.x), axis=0, return_inverse=True)
            for i, mask in enumerate(masks):
                ix = np.flatnonzero(mask)
                xx = self.x[inverse == i][:, ix]
                m = xx.mean(axis=0)
                z = xx - m
                self.patterns.append((ix, len(xx), m, z.T @ z / len(xx)))
            self.saturated = saturated_fiml(self)
            self.saturated_objective = raw_objective(self.patterns, *self.saturated)
            self.m, self.s = self.saturated
        else:
            self.m, self.s = covariance(self.x, w, ml)
            sign, self.logdet = np.linalg.slogdet(self.s)
            if sign <= 0:
                raise ValueError('Sample covariance is not positive definite')


def raw_objective(patterns, mu, sigma):
    value = 0.0
    for ix, n, m, s in patterns:
        sub = sigma[np.ix_(ix, ix)]
        fac = linalg.cho_factor(sub, lower=True, check_finite=False)
        inv = linalg.cho_solve(fac, np.eye(len(ix)), check_finite=False)
        r = m - mu[ix]
        value += n * (2 * np.log(np.diag(fac[0])).sum() + np.sum(s * inv) + r @ inv @ r)
    return value


def saturated_fiml(sample):
    """Unrestricted MVN EM, using only pattern sufficient statistics."""
    p = sample.p
    mu = sample.m.copy()
    sigma = np.diag(np.nanvar(sample.x, axis=0))
    prev = np.inf
    for iteration in range(20000):
        sx, sxx = np.zeros(p), np.zeros((p, p))
        for obs, n, m, s in sample.patterns:
            mis = np.setdiff1d(np.arange(p), obs)
            ex = mu.copy()
            ex[obs] = m
            cov = np.zeros((p, p))
            cov[np.ix_(obs, obs)] = s
            if len(mis):
                b = linalg.solve(sigma[np.ix_(obs, obs)], sigma[np.ix_(obs, mis)], assume_a='pos').T
                ex[mis] = mu[mis] + b @ (m - mu[obs])
                cov[np.ix_(mis, obs)] = b @ s
                cov[np.ix_(obs, mis)] = s @ b.T
                cov[np.ix_(mis, mis)] = sigma[np.ix_(mis, mis)] - b @ sigma[np.ix_(obs, mis)] + b @ s @ b.T
            sx += n * ex
            sxx += n * (cov + np.outer(ex, ex))
        new_mu = sx / sample.n
        new_sigma = sxx / sample.n - np.outer(new_mu, new_mu)
        delta = max(np.max(np.abs(new_mu - mu)), np.max(np.abs(new_sigma - sigma)))
        mu, sigma = new_mu, (new_sigma + new_sigma.T) / 2
        if delta < 1e-10:
            return mu, sigma
    raise RuntimeError('Saturated FIML EM did not converge')


class CFA:
    """Affine equality constraints; analytic normal-theory likelihood derivatives."""
    def __init__(self, factors, samples, model='M4', effects=False, chk1=False, markers=None):
        self.factors, self.samples, self.model = factors, samples, model
        self.names = list(factors)
        self.items = [v for vs in factors.values() for v in vs]
        self.p, self.q, self.G = len(self.items), len(factors), len(samples)
        self.fi = np.array([k for k, vs in enumerate(factors.values()) for _ in vs])
        self.tri = np.tril_indices(self.q)
        self.h = len(self.tri[0])
        p, q = self.p, self.q
        self.sl_l = slice(0, p)
        self.sl_nu = slice(p, 2*p)
        self.sl_a = slice(2*p, 2*p+q)
        self.sl_psi = slice(2*p+q, 2*p+q+self.h)
        self.sl_t = slice(2*p+q+self.h, 3*p+q+self.h)
        self.d = self.sl_t.stop
        self.b = np.zeros((self.G, self.d))
        keys, entries = {}, []
        def add(g, slot, key, coef=1.):
            if key not in keys:
                keys[key] = len(keys)
            entries.append((g, slot, keys[key], coef))
        self.effects = effects and model in ('M3', 'M4', 'M5')
        scalar = model in ('M3', 'M4', 'M5') or chk1
        partial = model in ('M4', 'M5') or chk1
        equal_loading = model != 'M1' and model != 'single'
        self.markers = markers or {k: vs[0] for k, vs in factors.items()}
        for g in range(self.G):
            for j, item in enumerate(self.items):
                k = self.fi[j]
                marker = self.markers[self.names[k]] == item
                lg = 'shared' if equal_loading else g
                if self.effects and marker:
                    self.b[g, j] = len(factors[self.names[k]])
                    for other in factors[self.names[k]]:
                        if other != item:
                            add(g, j, ('l', lg, other), -1.)
                elif marker and not self.effects and not chk1:
                    self.b[g, j] = 1.
                else:
                    add(g, j, ('l', lg, item))
                if scalar and marker and not self.effects and not chk1:
                    pass
                else:
                    ng = 'shared' if scalar and not (partial and item in RELEASED) else g
                    add(g, p+j, ('nu', ng, item))
                if not (self.names[k] == 'C2' and len(factors['C2']) == 1):
                    add(g, self.sl_t.start+j, ('theta', g, item))
            for k in range(q):
                if scalar and not (chk1 and g == 0):
                    add(g, self.sl_a.start+k, ('alpha', 'shared' if model == 'M5' else g, k))
            for h, (a, b) in enumerate(zip(*self.tri)):
                if chk1 and g == 0 and a == b:
                    self.b[g, self.sl_psi.start+h] = 1.
                else:
                    add(g, self.sl_psi.start+h, ('psi', g, a, b))
        A = np.zeros((self.G, self.d, len(keys)))
        for g, slot, col, coef in entries:
            A[g, slot, col] += coef
        # Effects-coded intercept sums constrain shared and released intercepts jointly.
        # An orthonormal null-space parameterization retains exactly independent constraints.
        if self.effects:
            nu_cols = [v for k, v in keys.items() if k[0] == 'nu']
            other_cols = [v for k, v in keys.items() if k[0] != 'nu']
            rows = [A[g, p + np.flatnonzero(self.fi == k), :].sum(axis=0)
                    for g in range(self.G) for k in range(q)]
            C = np.array(rows)[:, nu_cols]
            Z = linalg.null_space(C, rcond=1e-12)
            A = np.concatenate([A[:, :, other_cols], A[:, :, nu_cols] @ Z], axis=2)
        self.A = A
        self.k = A.shape[2]
        self.df = self.G * p * (p+3) // 2 - self.k
        self.scale = sum(s.c for s in samples)
        self._xlast = None
        self._cache = None
        target = np.zeros((self.G, self.d))
        for g, s in enumerate(samples):
            target[g, self.sl_l] = 1.
            target[g, self.sl_nu] = s.m
            variances = np.diag(s.s)
            target[g, self.sl_t] = variances * .55
            pv = np.array([np.mean(variances[self.fi == k]) * .45 for k in range(q)])
            psi = .15*np.sqrt(np.outer(pv, pv)) + .85*np.diag(pv)
            target[g, self.sl_psi] = psi[self.tri]
            if scalar:
                for k, name in enumerate(self.names):
                    j = self.items.index(self.markers[name])
                    target[g, self.sl_a.start+k] = np.mean(s.m[self.fi == k]) if self.effects else s.m[j]
                    target[g, self.sl_nu][self.fi == k] -= target[g, self.sl_a.start+k]
            if chk1:
                target[g, self.sl_a] = 0.
                target[g, self.sl_nu] = samples[0].m
                target[g, self.sl_psi] = (.85*np.eye(q)+.15*np.ones((q, q)))[self.tri]
        self.x0 = linalg.lstsq(A.reshape(-1, self.k), (target-self.b).ravel())[0]

    def state(self, x, g):
        v = self.b[g] + self.A[g] @ x
        L = np.zeros((self.p, self.q))
        L[np.arange(self.p), self.fi] = v[self.sl_l]
        psi = np.zeros((self.q, self.q))
        psi[self.tri] = v[self.sl_psi]
        psi = psi + np.tril(psi, -1).T
        a = v[self.sl_a]
        nu = v[self.sl_nu]
        theta = v[self.sl_t]
        return L, nu, a, psi, theta, nu + L @ a, L @ psi @ L.T + np.diag(theta)

    def objective(self, x):
        if self._xlast is not None and np.array_equal(x, self._xlast):
            return self._cache
        val, grad = 0., np.zeros(self.k)
        try:
            for g, s in enumerate(self.samples):
                L, nu, a, psi, theta, mu, sigma = self.state(x, g)
                H, u = np.zeros_like(sigma), np.zeros(self.p)
                patterns = s.patterns if s.fiml else [(np.arange(self.p), s.c, s.m, s.s)]
                for ix, c, m, S in patterns:
                    sub = sigma[np.ix_(ix, ix)]
                    fac = linalg.cho_factor(sub, lower=True, check_finite=False)
                    inv = linalg.cho_solve(fac, np.eye(len(ix)), check_finite=False)
                    r = m - mu[ix]
                    val += c * (2*np.log(np.diag(fac[0])).sum() + np.sum(S*inv) + r@inv@r)
                    H[np.ix_(ix, ix)] += c*(inv - inv @ (S + np.outer(r, r)) @ inv)
                    u[ix] -= 2*c*(inv @ r)
                val -= s.saturated_objective if s.fiml else s.c*(s.logdet+self.p)
                vgrad = np.zeros(self.d)
                vgrad[self.sl_l] = 2*(H @ L @ psi)[np.arange(self.p), self.fi] + u*a[self.fi]
                vgrad[self.sl_nu] = u
                vgrad[self.sl_a] = L.T @ u
                pg = L.T @ H @ L
                vgrad[self.sl_psi] = pg[self.tri] * np.where(self.tri[0] == self.tri[1], 1., 2.)
                vgrad[self.sl_t] = np.diag(H)
                grad += self.A[g].T @ vgrad
            result = val/self.scale, grad/self.scale
        except (linalg.LinAlgError, ValueError, FloatingPointError):
            result = 1e30, np.zeros(self.k)
        self._xlast, self._cache = x.copy(), result
        return result

    def derivatives(self, x, g):
        L, nu, a, psi, theta, mu, sigma = self.state(x, g)
        A = self.A[g]
        dl = np.zeros((self.p, self.q, self.k))
        dl[np.arange(self.p), self.fi, :] = A[self.sl_l]
        dp = np.zeros((self.q, self.q, self.k))
        dp[self.tri[0], self.tri[1], :] = A[self.sl_psi]
        dp[self.tri[1], self.tri[0], :] = A[self.sl_psi]
        ds = np.einsum('iak,ab,jb->ijk', dl, psi, L, optimize=True)
        ds = ds + ds.transpose(1, 0, 2) + np.einsum('ia,abk,jb->ijk', L, dp, L, optimize=True)
        ds[np.arange(self.p), np.arange(self.p), :] += A[self.sl_t]
        dm = A[self.sl_nu] + np.einsum('iak,a->ik', dl, a) + L @ A[self.sl_a]
        return dm, ds

    def information(self, x):
        info = np.zeros((self.k, self.k))
        for g, s in enumerate(self.samples):
            sigma = self.state(x, g)[-1]
            dm, ds = self.derivatives(x, g)
            patterns = [(ix, n) for ix, n, _, _ in s.patterns] if s.fiml else [(np.arange(self.p), s.c)]
            for ix, n in patterns:
                inv = linalg.inv(sigma[np.ix_(ix, ix)])
                D = ds[ix[:, None], ix[None, :], :]
                M = dm[ix]
                W = np.einsum('ia,abk,bj->ijk', inv, D, inv, optimize=True)
                info += n*(M.T @ inv @ M + .5*D.reshape(-1, self.k).T @ W.reshape(-1, self.k))
        return (info+info.T)/2

    def fit(self, warm=None, robust=False, inference=True):
        x0 = self.x0 if warm is None else warm
        started = time.perf_counter()
        res = optimize.minimize(self.objective, x0, jac=True, method='L-BFGS-B',
                                options={'ftol': 1e-13, 'gtol': 1e-8, 'maxiter': 12000, 'maxls': 60, 'maxcor': 40})
        # A Newton refinement with expected information checks stationarity independently
        # of the relative objective stopping criterion.
        x = res.x.copy()
        refinements = 0
        for _ in range(200):
            value, grad = self.objective(x)
            if np.max(np.abs(grad)) < 1e-8:
                break
            info = self.information(x)
            try:
                step = linalg.solve(2*info/self.scale, grad, assume_a='pos')
            except linalg.LinAlgError:
                regularized = 2*info/self.scale + np.eye(self.k)*1e-6
                step = linalg.solve(regularized, grad, assume_a='pos')
            accepted = False
            for exponent in range(24):
                candidate = x - step * 0.5**exponent
                v2, g2 = self.objective(candidate)
                if v2 < value - 1e-5 * 0.5**exponent * (grad @ step) or (abs(v2-value) < 1e-13 and np.linalg.norm(g2) < np.linalg.norm(grad)):
                    x = candidate
                    accepted = True
                    refinements += 1
                    break
            if not accepted:
                break
        self.x = x
        value, grad = self.objective(x)
        self.converged = bool(np.isfinite(value) and value < 1e20 and
                              (np.max(np.abs(grad)) < 1e-7 or (res.success and np.max(np.abs(grad)) < 1e-5)))
        self.chi2 = value*self.scale
        self.vcov = None
        self.info_diagnostics = {}
        if inference:
            info = self.information(x)
            eigen = linalg.eigvalsh(info)
            self.info_diagnostics = {'expected_information_min_eigenvalue': eigen[0],
                                     'expected_information_condition': eigen[-1]/eigen[0]}
            if eigen[0] <= eigen[-1]*1e-12:
                raise RuntimeError('Expected information singular or not positive definite; no pseudoinverse SE substitution')
            self.vcov = linalg.inv(info)
        self.robust = None
        if robust:
            self.vcov, self.robust = self.robust_covariance(x)
        self.convergence = {'status': 'ok' if self.converged else 'failed', 'converged': self.converged, 'optimizer_success': bool(res.success),
                            'message': str(res.message), 'iterations': int(res.nit),
                            'fisher_refinements': refinements, 'max_abs_gradient_per_c': np.max(np.abs(grad)),
                            'seconds': time.perf_counter()-started, **self.info_diagnostics}
        return self

    def robust_covariance(self, x):
        """Observed-information bread, individual normal-likelihood score meat.

        Yuan-Bentler/Mplus (MLR) correction uses the unrestricted observed-normal
        moment information to map empirical moment covariance into the likelihood
        residual space. The H1 correction does not enter point estimates or SEs.
        """
        H = np.empty((self.k, self.k))
        for j in range(self.k):
            h = 1e-4 * max(1., abs(x[j]))
            e = np.zeros(self.k); e[j] = h
            H[:, j] = (self.objective(x+e)[1] - self.objective(x-e)[1]) * self.scale/(4*h)
        H = (H+H.T)/2
        if linalg.eigvalsh(H)[0] <= 0:
            raise RuntimeError('Observed information is not positive definite for sandwich covariance')
        meat = np.zeros_like(H)
        # Saturated and restricted normal likelihood score projection gives the
        # Yuan-Bentler T2* (Mplus) scaling, including mean moments.
        trace_h1, trace_h0 = 0., 0.
        for g, s in enumerate(self.samples):
            mu, sigma = self.state(x, g)[-2:]
            inv = linalg.inv(sigma)
            dm, ds = self.derivatives(x, g)
            residual = s.x-mu
            u = residual @ inv
            scores = u @ dm + .5*np.einsum('ni,ijk,nj->nk', u, ds, u, optimize=True) - .5*np.einsum('ij,ijk->k', inv, ds)[None, :]
            meat += scores.T @ scores
            # Empirical saturated scores evaluated at the unrestricted ML moments.
            sinv = linalg.inv(s.s)
            r = s.x-s.m
            v = r @ sinv
            tri = np.tril_indices(self.p)
            basis = np.zeros((self.p, self.p, len(tri[0])))
            basis[tri[0], tri[1], np.arange(len(tri[0]))] = 1.
            basis[tri[1], tri[0], np.arange(len(tri[0]))] = 1.
            sat_scores = np.concatenate([v, .5*np.einsum('ni,ijk,nj->nk', v, basis, v, optimize=True)
                                      -.5*np.einsum('ij,ijk->k', sinv, basis)[None, :]], axis=1)
            sat_info = np.zeros((self.p+len(tri[0]),)*2)
            sat_info[:self.p, :self.p] = sinv
            W = np.einsum('ia,abk,bj->ijk', sinv, basis, sinv, optimize=True)
            sat_info[self.p:, self.p:] = .5*basis.reshape(-1, len(tri[0])).T @ W.reshape(-1, len(tri[0]))
            sat_meat = sat_scores.T @ sat_scores / s.n
            trace_h1 += np.trace(linalg.solve(sat_info, sat_meat, assume_a='pos'))
        Hinv = linalg.inv(H)
        vcov = Hinv @ meat @ Hinv
        trace_h0 = np.trace(Hinv @ meat)
        scale = (trace_h1-trace_h0)/self.df
        return (vcov+vcov.T)/2, {'method': 'Huber-White observed-information sandwich; Yuan-Bentler Mplus T2* correction',
            'scaling_factor': scale, 'scaled_chi_square': self.chi2/scale,
            'scaled_p': stats.chi2.sf(self.chi2/scale, self.df),
            'h1_trace': trace_h1, 'h0_trace': trace_h0,
            'observed_hessian_central_difference_relative_step': 1e-4,
            'scaling_formula': '(trace(H1_inverse J1) - trace(H0_inverse J0)) / df; H0 observed, H1 saturated normal information',
            'score_meat': 'sum of individual score outer products; no degrees-of-freedom adjustment'}

    def baseline(self):
        value, df = 0., self.G*self.p*(self.p-1)//2
        for s in self.samples:
            if s.fiml:
                mu = np.nanmean(s.x, axis=0)
                sig = np.diag(np.nanvar(s.x, axis=0, ddof=0))
                value += raw_objective(s.patterns, mu, sig)-s.saturated_objective
            else:
                value += s.c*(np.log(np.diag(s.s)).sum()-s.logdet)
        return value, df

    def output(self):
        bchi, bdf = self.baseline()
        chi, df = self.chi2, self.df
        cfi = 1-max(chi-df, 0)/max(chi-df, bchi-bdf, 0) if max(chi-df, bchi-bdf, 0)>0 else 1.
        tli = (bchi/bdf-chi/df)/(bchi/bdf-1) if df>0 and bchi!=bdf else np.nan
        n = sum(s.n for s in self.samples)
        srmr, pars, admissibility = 0., {}, []
        for g, s in enumerate(self.samples):
            L, nu, a, psi, theta, mu, sigma = self.state(self.x, g)
            residual = (s.s-sigma)/np.sqrt(np.outer(np.diag(s.s), np.diag(s.s)))
            sr = np.sqrt(np.mean(residual[np.tril_indices(self.p)]**2))
            srmr += s.n/n * sr
            pars[str(s.year)] = {'loadings': dict(zip(self.items, L[np.arange(self.p), self.fi])),
                'intercepts': dict(zip(self.items, nu)), 'factor_means': dict(zip(self.names, a)),
                'factor_covariance': psi, 'factor_order': self.names,
                'residual_variances': dict(zip(self.items, theta)), 'SRMR': sr}
            if np.any(theta < -1e-8):
                admissibility.append(f'{s.year}: negative residual variance')
            if linalg.eigvalsh(psi)[0] <= 0:
                admissibility.append(f'{s.year}: factor covariance is not positive definite')
        return {'model_id': self.model, 'convergence': self.convergence, 'free_parameters': self.k,
            'sample_moments': self.G*self.p*(self.p+3)//2, 'samples': [s.info for s in self.samples],
            'chi_square': chi, 'df': df, 'p': stats.chi2.sf(chi, df),
            'RMSEA': np.sqrt(self.G)*np.sqrt(max(chi-df, 0)/(df*self.scale)) if df>0 else np.nan,
            'CFI': cfi, 'TLI': tli, 'SRMR': srmr,
            'baseline': {'chi_square': bchi, 'df': bdf}, 'parameters': pars,
            'robust': self.robust, 'admissible': not admissibility, 'admissibility_warnings': admissibility}

    def latent(self):
        means, pairs = {}, {}
        for k, name in enumerate(self.names):
            means[name] = {}
            for g, s in enumerate(self.samples):
                _, _, a, psi, _, _, _ = self.state(self.x, g)
                d = self.A[g, self.sl_a.start+k]
                se = np.sqrt(max(d @ self.vcov @ d, 0))
                means[name][str(s.year)] = {'alpha': a[k], 'SE': se, 'CI95': [a[k]-1.96*se, a[k]+1.96*se],
                    'variance': psi[k, k], 'SD': np.sqrt(psi[k, k]) if psi[k, k]>=0 else np.nan}
            pairs[name] = {}
            for pair, (a, b) in PAIRS.items():
                sa, sb = self.samples[a], self.samples[b]
                va, vb = means[name][str(sa.year)], means[name][str(sb.year)]
                delta = vb['alpha']-va['alpha']
                d = self.A[b, self.sl_a.start+k]-self.A[a, self.sl_a.start+k]
                se = np.sqrt(max(d @ self.vcov @ d, 0))
                z = delta/se if se>0 else np.nan
                psia, psib = va['variance'], vb['variance']
                def ratio(var):
                    return delta/np.sqrt(var) if var>0 else np.nan
                # d_obs always uses n-1, including S02/S06; S01 uses normalized
                # weighted covariance, as required for every model/scale moment.
                obsvars = []
                for ss in (sa, sb):
                    scores = ss.x[:, self.fi == k].mean(axis=1)
                    if ss.fiml:
                        # Unit mean is only defined for complete factor items.
                        scores = scores[np.isfinite(scores)]
                    obsvars.append(covariance(scores[:, None], ss.w if not ss.fiml else None)[1][0, 0])
                deq = ratio((psia+psib)/2)
                pairs[name][pair] = {'earlier': sa.year, 'later': sb.year, 'Delta': delta, 'SE': se,
                    'z': z, 'p': 2*stats.norm.sf(abs(z)), 'd_eq': deq,
                    'd_df': ratio(((sa.n-1)*psia+(sb.n-1)*psib)/(sa.n+sb.n-2)),
                    'g': deq*(1-3/(4*(sa.n+sb.n)-9)), 'd_glass': ratio(psia),
                    'd_obs': ratio(sum(obsvars)/2), 'observed_score_variances': obsvars,
                    'inference': 'robust' if self.robust is not None else 'expected_information'}
        return {'means': means, 'contrasts': pairs}


class Data:
    def __init__(self, spec):
        self.spec = spec
        self.frames, self.rows, self.invalid_weights = {}, {}, {}
        for form, items in ((3, F3), (4, F4)):
            for year in YEARS:
                key = f'y{year}_f{form}'
                # Read all records; irrelevant columns do not affect any analysis.
                df = pd.read_csv(ROOT / 'data' / f'{key}.csv.gz', usecols=['V4', 'V5']+items)
                self.rows[key] = len(df)
                sample_info(df.V4.to_numpy(), year)
                for item in items:
                    valid = [1, 2] if item == 'V3227' else list(range(1, 5 if form == 4 else 6))
                    df.loc[~df[item].isin(valid), item] = np.nan
                if spec == 'S01':
                    dictionary = json.loads((ROOT/'dictionaries'/f'{key}.dictionary.json').read_text())
                    weight = next(v for v in dictionary['variables'] if v['name'] == 'V5')
                    good = np.isfinite(df.V5) & (df.V5 > 0)
                    for code in weight.get('declared_missing_values') or []:
                        good &= df.V5 != code
                    ran = weight.get('declared_missing_range')
                    if ran:
                        lo = -np.inf if str(ran[0]).upper() == 'LOWEST' else float(ran[0])
                        hi = np.inf if str(ran[1]).upper() == 'HIGHEST' else float(ran[1])
                        good &= ~df.V5.between(lo, hi)
                    self.invalid_weights[key] = int((~good).sum())
                    df = df.loc[good].copy()
                if spec == 'S03':
                    df = df.dropna(subset=items)
                self.frames[form, year] = df

    def sample(self, form, year, items, reverse=False, fiml=False, ml=False):
        df = self.frames[form, year]
        df = df.loc[df[items].notna().any(axis=1)] if fiml else df.dropna(subset=items)
        x = df[items].to_numpy().copy()
        if reverse:
            for j, item in enumerate(items):
                if item in ('V3222', 'V3223'):
                    x[:, j] = 6-x[:, j]
                if item == 'V3227':
                    x[:, j] = 3-x[:, j]
        return Sample(x, df.V4.to_numpy(), year, df.V5.to_numpy() if self.spec=='S01' else None, ml, fiml)


def alpha_output(data, factors, form, reverse=False):
    out = {}
    for name, items in factors.items():
        out[name] = {}
        for year in YEARS:
            s = data.sample(form, year, items, reverse)
            k = len(items)
            total = s.s.sum()
            alpha = k/(k-1)*(1-np.trace(s.s)/total) if total>0 and k>1 else np.nan
            out[name][str(year)] = {'alpha': alpha, 'items': items, 'sample': s.info}
    return out


def item_outputs(data):
    out = {'by_year': {}, 'comparisons': {}}
    for form, items in ((3, F3), (4, F4)):
        for item in items:
            out['by_year'][item] = {}
            for year in YEARS:
                df = data.frames[form, year].dropna(subset=[item])
                x = df[item].to_numpy()
                n = len(x)
                top = x==4 if form==4 else (x==1 if item=='V3227' else x>=4)
                if data.spec=='S01':
                    w = df.V5.to_numpy(); w = w*n/w.sum()
                    W, W2 = w.sum(), w@w
                    m = w@x/W
                    var = (w @ ((x-m)**2))/(W-W2/W)
                    pct = 100*(w@top)/W
                    vmean = var*W2/W**2
                else:
                    m, var, pct = x.mean(), x.var(ddof=1), 100*top.mean()
                    vmean = var/n
                out['by_year'][item][str(year)] = {'n': n, 'mean': m, 'SD': np.sqrt(var),
                    'percentage_top': pct, 'variance_of_mean': vmean, 'sample': sample_info(df.V4, year)}
            out['comparisons'][item] = {}
            for pair, (a, b) in PAIRS.items():
                aa, bb = (out['by_year'][item][str(YEARS[j])] for j in (a, b))
                diff = bb['mean']-aa['mean']
                result = {'earlier': YEARS[a], 'later': YEARS[b], 'mean_difference': diff,
                    'percentage_point_difference': bb['percentage_top']-aa['percentage_top'],
                    'samples': [aa['sample'], bb['sample']]}
                if data.spec=='S01':
                    z = diff/np.sqrt(aa['variance_of_mean']+bb['variance_of_mean'])
                    result['weighted_z'] = {'z': z, 'p': 2*stats.norm.sf(abs(z))}
                else:
                    na, nb = aa['n'], bb['n']; va, vb = aa['SD']**2, bb['SD']**2
                    df = na+nb-2
                    pooled = ((na-1)*va+(nb-1)*vb)/df
                    t = diff/np.sqrt(pooled*(1/na+1/nb))
                    v = va/na+vb/nb
                    tw = diff/np.sqrt(v)
                    dw = v*v/((va/na)**2/(na-1)+(vb/nb)**2/(nb-1))
                    result['Student'] = {'t': t, 'df': df, 'p': 2*stats.t.sf(abs(t), df)}
                    result['Welch'] = {'t': tw, 'df': dw, 'p': 2*stats.t.sf(abs(tw), dw)}
                out['comparisons'][item][pair] = result
    return out


def differences(outputs):
    answer = {}
    for less, more in (('M1', 'M2'), ('M2', 'M3'), ('M2', 'M4'), ('M4', 'M5')):
        a, b = outputs[less], outputs[more]
        dc, dd = b['chi_square']-a['chi_square'], b['df']-a['df']
        answer[f'{more}-{less}'] = {'chi_square_difference': dc, 'df_difference': dd,
                                  'p': stats.chi2.sf(dc, dd), 'CFI_difference': a['CFI']-b['CFI']}
    return answer


def transfer(previous, current):
    """Project an earlier fitted physical state into the next constraint space."""
    target = previous.b + previous.A @ previous.x
    # Scalar identification is a location change relative to metric identification.
    if current.model in ('M3', 'M4', 'M5') and previous.model in ('M1', 'M2'):
        for g in range(current.G):
            L, nu, a, psi, theta, mu, sigma = previous.state(previous.x, g)
            for k, name in enumerate(current.names):
                ix = np.flatnonzero(current.fi == k)
                marker = current.items.index(current.markers[name])
                shift = nu[marker] / L[marker, k]
                target[g, current.sl_nu][ix] -= L[ix, k]*shift
                target[g, current.sl_a.start+k] = shift
    return linalg.lstsq(current.A.reshape(-1, current.k), (target-current.b).ravel())[0]


def defaults(spec):
    return {
        'estimator': 'custom normal-theory maximum likelihood; scipy.optimize L-BFGS-B plus Fisher scoring refinement',
        'optimizer': {'ftol': 1e-13, 'gtol': 1e-8, 'maxiter': 12000, 'maxls': 60, 'maxcor': 40, 'maximum_fisher_refinements': 200},
        'normalization': 'n' if spec in ('S02', 'S04', 'S06') else 'n-1',
        'standard_errors': 'expected normal information with c_g multipliers' if spec!='S06' else 'observed-information Huber-White sandwich',
        'variance_constraints': 'unbounded covariance and residual parameters; implied covariance must be positive definite; inadmissibility reported',
        'V4_hash_format': 'numeric ascending order, integral values in decimal without .0, UTF-8 newline separators, no terminal newline',
        'nonfinite_output': 'JSON null; model errors and inadmissibility reported separately',
        'weighted_model_covariance': 'normalize sample weights to n, then divide weighted cross products by n-1',
        'FIML_saturated': 'unrestricted MVN EM; maximum 20000 iterations; maximum absolute moment change <1e-10',
        'FIML_SRMR': 'unrestricted saturated normal ML covariance from EM; nominal group n weighting',
        'FIML_d_obs': 'unit-weighted scores require all items in a factor; SD skips undefined scores (pandas-style skipna default); those sample hashes are reported',
        'fit_index_conventions': 'manifest formulas; mean residuals excluded from SRMR; ordinary unscaled indices and differences',
        'confidence_interval_multiplier': 1.96,
    }


def run_spec(spec):
    started = time.perf_counter()
    out = {'spec_id': spec, 'status': 'ok', 'reason': None, 'software': versions(),
           'rows_read_per_file': {}, 'defaults': defaults(spec), 'deviations': []}
    try:
        data = Data(spec)
        out['rows_read_per_file'] = data.rows
        if spec=='S01':
            out['invalid_weights_dropped_per_file'] = data.invalid_weights
        full = spec in ('S00', 'S01', 'S03')
        if full:
            out['item_statistics'] = item_outputs(data)
            out['alpha'] = {**alpha_output(data, FACTORS, 4), **alpha_output(data, {'C1': CFACTORS['C1']}, 3, True)}
        if full or spec in ('S07a', 'S07b', 'S08'):
            seven = {k: v.copy() for k, v in FACTORS.items()}
            if spec=='S07a':
                seven.update(K6=['V4239', 'V4237'], K7=['V4241', 'V4247'])
            if spec=='S07b':
                seven.update(K6=['V4239', 'V4247'], K7=['V4241', 'V4237'])
            if spec in ('S07a', 'S07b'):
                configs = [('Form4_seven_factor', seven, 4, False)]
                out['alpha'] = alpha_output(data, {k: seven[k] for k in ('K6', 'K7')}, 4)
            elif spec=='S08':
                cf = {'C1': ['V3224', 'V3225', 'V3222', 'V3223', 'V3226']}
                configs = [('Form3_one_factor', cf, 3, True)]
                out['alpha'] = alpha_output(data, cf, 3, True)
            else:
                configs = [('Form3_C1_C2', CFACTORS, 3, True),
                           ('Form4_seven_factor', seven, 4, False), ('Form4_five_factor', FIVE, 4, False)]
            out['single_group'] = {}
            for label, factors, form, rev in configs:
                out['single_group'][label] = {}
                items = [v for vs in factors.values() for v in vs]
                for year in YEARS:
                    print(f'{spec}: {label} {year}', flush=True)
                    sample = data.sample(form, year, items, rev)
                    fit = CFA(factors, [sample], 'single').fit(inference=False)
                    out['single_group'][label][str(year)] = fit.output()
                    if not fit.converged:
                        out['status'], out['reason'] = 'failed', f'{label} {year} did not converge'
        if full or spec in ('S02', 'S04', 'S05', 'S06', 'CHK1', 'CHK2'):
            items = [v for vs in FIVE.values() for v in vs]
            samples = [data.sample(4, y, items, fiml=spec=='S04', ml=spec in ('S02', 'S06')) for y in YEARS]
            if spec=='S04':
                out['d_obs_samples'] = {k: [sample_info(s.ids[np.isfinite(s.x[:, [items.index(v) for v in vs]]).all(axis=1)], s.year)
                                           for s in samples] for k, vs in FIVE.items()}
            out['multigroup'] = {}
            previous, fits = None, {}
            for model in (['M4'] if spec=='CHK1' else ['M1', 'M2', 'M3', 'M4', 'M5']):
                print(f'{spec}: {model}', flush=True)
                markers = dict(zip(FIVE, ['V4246', 'V4225', 'V4235', 'V4245', 'V4244'])) if spec=='CHK2' else None
                fit = CFA(FIVE, samples, model, effects=spec=='S05', chk1=spec=='CHK1', markers=markers)
                warm = transfer(previous, fit) if previous is not None and spec!='S05' else None
                fit.fit(warm=warm, robust=spec=='S06', inference=(model=='M4' or spec=='S06'))
                out['multigroup'][model] = fit.output()
                fits[model] = fit
                previous = fit
                if not fit.converged:
                    out['status'], out['reason'] = 'failed', f'{model} did not converge'
            if spec!='CHK1':
                out['model_differences'] = differences(out['multigroup'])
            out['latent_M4'] = fits['M4'].latent()
        out['seconds'] = time.perf_counter()-started
    except Exception as exc:
        out['status'], out['reason'] = 'failed', f'{type(exc).__name__}: {exc}'
        out['traceback'] = traceback.format_exc()
        out['seconds'] = time.perf_counter()-started
    write_json(ROOT/'results'/f'{spec}.json', out)
    print(f'{spec}: {out["status"]} ({out["seconds"]:.2f}s) {out["reason"] or ""}', flush=True)
    return out


def influence(start, limit):
    if start<0 or limit<1:
        raise ValueError('Influence start is zero-based and nonnegative; limit must be positive')
    started = time.perf_counter()
    data = Data('S00')
    items = [v for vs in FIVE.values() for v in vs]
    samples = [data.sample(4, y, items) for y in YEARS]
    fit = CFA(FIVE, samples, 'M4').fit()
    if not fit.converged:
        raise RuntimeError('Full-sample M4 failed; influence requires a converged warm start')
    ordered = [(g, i) for g, s in enumerate(samples) for i in np.argsort(s.ids)]
    end = min(start+limit, len(ordered))
    if start>=end:
        raise ValueError('Start index is beyond the multigroup sample')
    columns = ['idx', 'del_group', 'del_V4', 'status', 'message'] + [f'{field}_{k}_{pair}' for field in ('d_eq', 'p') for k in FIVE for pair in PAIRS]
    rows, times = [], []
    for idx in range(start, end):
        g, i = ordered[idx]
        s = samples[g]
        row = {'idx': idx, 'del_group': s.year, 'del_V4': serial(s.ids[i]), 'status': 'failed', 'message': ''}
        tic = time.perf_counter()
        try:
            mask = np.arange(s.n)!=i
            deleted = Sample(s.x[mask], s.ids[mask], s.year)
            groups = samples.copy(); groups[g] = deleted
            refit = CFA(FIVE, groups, 'M4').fit(warm=fit.x)
            row['status'] = 'ok' if refit.converged else 'failed'
            row['message'] = '' if refit.converged else refit.convergence['message']
            contrasts = refit.latent()['contrasts']
            for k in FIVE:
                for pair in PAIRS:
                    for field in ('d_eq', 'p'):
                        row[f'{field}_{k}_{pair}'] = contrasts[k][pair][field]
        except Exception as exc:
            row['message'] = f'{type(exc).__name__}: {exc}'
        times.append(time.perf_counter()-tic)
        rows.append(row)
        print(f'influence {idx}: {row["status"]} {times[-1]:.3f}s', flush=True)
    path = ROOT/'results'/f'influence_{start}_{end-1}.csv'
    pd.DataFrame(rows).reindex(columns=columns).to_csv(path, index=False)
    metadata = {'spec_id': 'S00_influence', 'status': 'ok' if all(r['status']=='ok' for r in rows) else 'failed',
                'reason': None if all(r['status']=='ok' for r in rows) else 'One or more deletion fits failed; see CSV messages',
                'software': versions(), 'start': start, 'end_inclusive': end-1, 'deletions': len(rows),
                'seconds_per_deletion': times, 'mean_seconds_per_deletion': np.mean(times),
                'total_seconds_including_full_fit': time.perf_counter()-started,
                'rows_read_per_file': data.rows, 'full_samples': [s.info for s in samples],
                'deletion_samples': [{'idx': start+j, 'samples': [sample_info(ss.ids[np.arange(ss.n)!=ordered[start+j][1]], ss.year)
                    if g==ordered[start+j][0] else ss.info for g, ss in enumerate(samples)]} for j in range(len(rows))],
                'full_fit': fit.output(), 'deviations': []}
    write_json(path.with_suffix('.json'), metadata)
    return metadata


def synthetic_tests():
    """No supplied files are accessed by this mode."""
    rng = np.random.default_rng(20261028)
    records = []
    def check(name, passed, detail):
        records.append({'name': name, 'passed': bool(passed), 'detail': clean(detail)})
        print(f'TEST {name}: {"PASS" if passed else "FAIL"} {detail}', flush=True)
    # Synthetic three-group model uses the manifest's 19-item structure, with
    # known parameters in precisely the requested marker-intercept metric.
    n = 18000
    items = [v for vs in FIVE.values() for v in vs]
    fi = np.array([k for k, vs in enumerate(FIVE.values()) for _ in vs])
    q, p = 5, len(items)
    load = rng.uniform(.7, 1.3, p)
    markers = [items.index(vs[0]) for vs in FIVE.values()]
    load[markers] = 1.
    L = np.zeros((p, q)); L[np.arange(p), fi] = load
    psi = .25*np.ones((q, q)) + .75*np.eye(q)
    intercept = rng.uniform(-.3, .3, p); intercept[markers] = 0.
    truth = np.array([[.4, .6, .3, .5, .7], [.6, .5, .7, .6, .8], [.8, .7, .9, .4, 1.0]])
    samples = []
    for g, year in enumerate(YEARS):
        nu = intercept.copy()
        for j, item in enumerate(items):
            if item in RELEASED:
                nu[j] += .15*g
        eta = rng.multivariate_normal(truth[g], psi*(1+.1*g), n)
        x = nu + eta @ L.T + rng.normal(0, np.sqrt(.5), (n, p))
        samples.append(Sample(x, np.arange(1, n+1), year))
    fit = CFA(FIVE, samples, 'M4').fit()
    states = [fit.state(fit.x, g) for g in range(3)]
    aerr = max(np.max(np.abs(states[g][2]-truth[g])) for g in range(3))
    lerr = max(np.max(np.abs(st[0][np.arange(p), fi]-load)) for st in states)
    perr = max(np.max(np.abs(states[g][3]-psi*(1+.1*g))) for g in range(3))
    check('known_parameter_recovery', fit.converged and aerr<.065 and lerr<.065 and perr<.09,
          {'max_mean_error': aerr, 'max_loading_error': lerr, 'max_covariance_error': perr, 'chi2': fit.chi2, 'df': fit.df})
    # Gradient checked away from the optimum, including latent-mean/load interactions.
    testx = fit.x + rng.normal(0, .003, fit.k)
    numeric = optimize._numdiff.approx_derivative(lambda z: fit.objective(z)[0], testx, method='3-point').ravel()
    analytic = fit.objective(testx)[1]
    gerr = np.max(np.abs(numeric-analytic))
    check('analytic_likelihood_gradient', gerr<1e-6, {'maximum_absolute_error': gerr})
    dm, ds = fit.derivatives(fit.x, 0)
    numeric_mu = optimize._numdiff.approx_derivative(lambda z: fit.state(z, 0)[-2], fit.x)
    numeric_sigma = optimize._numdiff.approx_derivative(lambda z: fit.state(z, 0)[-1].ravel(), fit.x)
    derr = max(np.max(np.abs(dm-numeric_mu)), np.max(np.abs(ds.reshape(p*p, fit.k)-numeric_sigma)))
    check('moment_derivatives', derr<1e-6, {'maximum_absolute_error': derr})
    # Expected-information SE agrees with an independently finite-differenced
    # observed-information calculation in this large correctly specified sample.
    H = optimize._numdiff.approx_derivative(lambda z: fit.objective(z)[1], fit.x)*fit.scale/2
    observed_cov = linalg.inv((H+H.T)/2)
    se_ratio = np.sqrt(np.diag(fit.vcov)/np.diag(observed_cov))
    check('expected_information_SE', np.max(np.abs(se_ratio-1))<.08, {'maximum_SE_ratio_error': np.max(np.abs(se_ratio-1))})
    alt = CFA(FIVE, samples, 'M4', chk1=True).fit()
    base_lat, alt_lat = fit.latent(), alt.latent()
    maxd = max(abs(base_lat['contrasts'][k][pair]['d_eq']-alt_lat['contrasts'][k][pair]['d_eq']) for k in FIVE for pair in PAIRS)
    check('reference_mean_variance_identification', alt.converged and maxd<1e-5 and abs(alt.chi2-fit.chi2)<1e-4,
          {'maximum_d_eq_difference': maxd, 'chi2_difference': alt.chi2-fit.chi2})
    altmark = dict(zip(FIVE, ['V4246', 'V4225', 'V4235', 'V4245', 'V4244']))
    marked = CFA(FIVE, samples, 'M4', markers=altmark).fit()
    mark_lat = marked.latent()
    maxdm = max(abs(base_lat['contrasts'][k][pair]['d_eq']-mark_lat['contrasts'][k][pair]['d_eq']) for k in FIVE for pair in PAIRS)
    check('alternate_markers', marked.converged and maxdm<1e-5, {'maximum_d_eq_difference': maxdm})
    ec = CFA(FIVE, samples, 'M4', effects=True).fit()
    residuals = []
    for g in range(3):
        el, enu, *_ = ec.state(ec.x, g)
        for k in range(q):
            residuals.extend([el[fi==k, k].mean()-1, enu[fi==k].sum()])
    check('effects_coding_equalities', ec.converged and np.max(np.abs(residuals))<1e-12,
          {'maximum_constraint_residual': np.max(np.abs(residuals)), 'df': ec.df})
    # FIML should reduce exactly to n-normalized ML when there is no missingness.
    small = [Sample(s.x[:1800], s.ids[:1800], s.year, ml=True) for s in samples]
    raw = [Sample(s.x[:1800], s.ids[:1800], s.year, fiml=True) for s in samples]
    fm = CFA(FIVE, small, 'M4').fit()
    fr = CFA(FIVE, raw, 'M4').fit(warm=fm.x)
    check('FIML_complete_data_equivalence', abs(fm.chi2-fr.chi2)<1e-5 and np.max(np.abs(fm.x-fr.x))<1e-5,
          {'chi2_difference': fr.chi2-fm.chi2, 'max_parameter_difference': np.max(np.abs(fm.x-fr.x))})
    missing = []
    for s in small:
        x = s.x.copy(); x[rng.random(x.shape)<.08] = np.nan
        missing.append(Sample(x, s.ids, s.year, fiml=True))
    mf = CFA(FIVE, missing, 'M4').fit(warm=fm.x)
    merr = max(np.max(np.abs(mf.state(mf.x, g)[2]-truth[g])) for g in range(3))
    check('FIML_missing_data_recovery', mf.converged and merr<.14, {'maximum_mean_error': merr, 'chi2': mf.chi2})
    sw = np.array([1., 2., 4., 3.])
    xx = np.array([[1., 2.], [2., 4.], [3., 3.], [4., 1.]])
    wm, wc = covariance(xx, sw)
    wn = sw*4/sw.sum(); manual_m = np.sum(xx*wn[:, None], axis=0)/4
    manual_c = sum(wn[i]*np.outer(xx[i]-manual_m, xx[i]-manual_m) for i in range(4))/3
    check('weighted_moments', np.allclose(wm, manual_m) and np.allclose(wc, manual_c), {'mean': wm, 'covariance': wc})
    robust_fit = CFA(FIVE, small, 'M4').fit(warm=fm.x, robust=True)
    robust_eig = linalg.eigvalsh(robust_fit.vcov)[0]
    check('robust_covariance', robust_fit.converged and robust_eig>0 and robust_fit.robust['scaling_factor']>0,
          {'minimum_covariance_eigenvalue': robust_eig, **robust_fit.robust})
    # Exact raw removal versus sufficient-statistic covariance downdating.
    s = small[0]; j = 5
    keep = np.arange(s.n)!=j
    reduced = Sample(s.x[keep], s.ids[keep], s.year, ml=True)
    newmean = (s.n*s.m-s.x[j])/(s.n-1)
    scatter = s.n*s.s-s.n/(s.n-1)*np.outer(s.x[j]-s.m, s.x[j]-s.m)
    check('deletion_moments', np.allclose(reduced.m, newmean) and np.allclose(reduced.s, scatter/(s.n-1)), {'deleted_index': j})
    result = {'seed': 20261028, 'software': versions(), 'status': 'ok' if all(r['passed'] for r in records) else 'failed',
              'tests': records, 'synthetic_sample_n_per_group': n, 'supplied_data_accessed': False}
    write_json(ROOT/'code'/'synthetic_tests.json', result)
    lines = ['# Synthetic validation', '', 'This mode uses synthetic data only. The initial suite passed before the first supplied-data run; it was rerun after numerical refinements. The results below describe the latest run.', '',
             'Command: `~/.venv/bin/python -I code/analyze.py test`', '',
             'Seed: 20261028. Three groups, five correlated factors, 19 indicators; 18,000 generated observations per group.',
             'Marker loadings are 1, marker intercepts are 0, other loadings/intercepts are known; six intercepts vary by group.',
             'Latent means and covariances are known. Missing-data tests use the first 1,800 records per group with independent 8% missingness.', '',
             f'Overall result: **{result["status"]}**.', '']
    for record in records:
        lines += [f'- **{record["name"]}: {"PASS" if record["passed"] else "FAIL"}**. `{json.dumps(record["detail"])}`']
    lines += ['', 'Full-precision machine-readable results and package versions: `synthetic_tests.json`.',
              'These checks validate numerical implementation and identification; they do not establish that survey data satisfy normality or the factor model.', '']
    (ROOT/'code'/'TESTS.md').write_text('\n'.join(lines))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='mode', required=True)
    run = sub.add_parser('run'); run.add_argument('spec', choices=SPECS+['all'])
    inf = sub.add_parser('influence'); inf.add_argument('--start', type=int, default=0); inf.add_argument('--limit', type=int, required=True)
    sub.add_parser('test')
    args = parser.parse_args()
    if args.mode=='test':
        result = synthetic_tests()
        return 0 if result['status']=='ok' else 1
    if args.mode=='run':
        results = [run_spec(s) for s in (SPECS if args.spec=='all' else [args.spec])]
        return 1 if any(r['status']=='failed' for r in results) else 0
    influence(args.start, args.limit)
    return 0


if __name__=='__main__':
    raise SystemExit(main())
