"""Auditor's own multigroup ML CFA (numpy/scipy), written independently of implementations A, B, C.

Model: x = nu_g + Lambda_g eta + eps; mu_g = nu_g + Lambda_g alpha_g; Sigma_g = Lambda_g Psi_g Lambda_g' + Theta_g.
Fit function (Wishart): sum_g c_g [log|Sigma| + tr(S Sigma^-1) - log|S| - p + (m - mu)' Sigma^-1 (m - mu)], c_g = n_g - 1.
Parameters are mapped by index arrays (-1 = fixed) so that equality constraints share an index.
"""
import numpy as np
from scipy import optimize


def moments(X):
    n = X.shape[0]
    return n, X.mean(0), np.cov(X, rowvar=False, ddof=1)


class MGModel:
    def __init__(self, items, factors, markers, model, released, groups):
        """groups: list of (n, m, S). model in M1..M5. released: set of items with group-specific intercepts in M4/M5."""
        self.items, self.factors, self.markers, self.model = list(items), factors, markers, model
        self.released = set(released)
        self.groups = groups
        p, K = len(items), list(factors)
        k = len(K)
        G = len(groups)
        self.p, self.k, self.G = p, k, G
        pos = {v: i for i, v in enumerate(items)}
        nxt = [0]
        start = []

        def new(v0):
            nxt[0] += 1
            start.append(v0)
            return nxt[0] - 1

        shared_load, shared_nu, shared_al = {}, {}, {}
        self.spec = []
        for g, (n, m, S) in enumerate(groups):
            L_idx = -np.ones((p, k), int); L_fix = np.zeros((p, k))
            nu_idx = -np.ones(p, int); nu_fix = np.zeros(p)
            th_idx = -np.ones(p, int)
            ps_idx = -np.ones((k, k), int)
            al_idx = -np.ones(k, int); al_fix = np.zeros(k)
            for j, f in enumerate(K):
                mk = markers[f]
                for v in factors[f]:
                    i = pos[v]
                    if v == mk:
                        L_fix[i, j] = 1.0
                    elif model == "M1":
                        L_idx[i, j] = new(1.0)
                    else:
                        if v not in shared_load:
                            shared_load[v] = new(1.0)
                        L_idx[i, j] = shared_load[v]
            for i, v in enumerate(items):
                f = next(ff for ff in K if v in factors[ff])
                mk = markers[f]
                th_idx[i] = new(0.5 * S[i, i])
                if model in ("M1", "M2"):
                    nu_idx[i] = new(m[i])
                else:
                    if v == mk:
                        nu_fix[i] = 0.0
                    elif model in ("M4", "M5") and v in self.released:
                        nu_idx[i] = new(m[i] - m[pos[mk]])
                    else:
                        if v not in shared_nu:
                            shared_nu[v] = new(m[i] - m[pos[mk]])
                        nu_idx[i] = shared_nu[v]
            for a in range(k):  # Psi = C C' with C lower triangular (keeps Psi positive semidefinite)
                for b in range(a + 1):
                    v0 = np.sqrt(0.5 * S[pos[markers[K[a]]], pos[markers[K[a]]]]) if a == b else 0.0
                    ps_idx[a, b] = new(v0)
            for j, f in enumerate(K):
                if model in ("M1", "M2"):
                    continue
                if model == "M5":
                    if f not in shared_al:
                        shared_al[f] = new(m[pos[markers[f]]])
                    al_idx[j] = shared_al[f]
                else:
                    al_idx[j] = new(m[pos[markers[f]]])
            self.spec.append(dict(L_idx=L_idx, L_fix=L_fix, nu_idx=nu_idx, nu_fix=nu_fix, th_idx=th_idx, ps_idx=ps_idx,
                                  al_idx=al_idx, al_fix=al_fix))
        self.npar = nxt[0]
        self.start = np.array(start)
        lb = np.full(self.npar, -np.inf)
        for s in self.spec:
            lb[s["th_idx"]] = 1e-6
            lb[np.diag(s["ps_idx"])] = 1e-4
        self.bounds = list(zip(lb, [np.inf] * self.npar))

    @staticmethod
    def _fill(idx, fix, th):
        out = fix.copy() if fix is not None else np.zeros(idx.shape)
        msk = idx >= 0
        out[msk] = th[idx[msk]]
        return out

    def mats(self, th, g):
        s = self.spec[g]
        L = self._fill(s["L_idx"], s["L_fix"], th)
        nu = self._fill(s["nu_idx"], s["nu_fix"], th)
        Th = th[s["th_idx"]]
        Ch = np.where(s["ps_idx"] >= 0, th[np.maximum(s["ps_idx"], 0)], 0.0)
        Ps = Ch @ Ch.T
        al = self._fill(s["al_idx"], s["al_fix"], th)
        self._Ch = Ch
        return L, nu, Th, Ps, al

    def f_and_grad(self, th):
        F = 0.0
        grad = np.zeros(self.npar)
        for g, (n, m, S) in enumerate(self.groups):
            c = n - 1
            s = self.spec[g]
            L, nu, Th, Ps, al = self.mats(th, g)
            Sig = L @ Ps @ L.T + np.diag(Th)
            try:
                C = np.linalg.cholesky(Sig)
            except np.linalg.LinAlgError:
                return 1e20, np.zeros(self.npar)
            Si = np.linalg.inv(Sig)
            mu = nu + L @ al
            d = m - mu
            logdet = 2 * np.log(np.diag(C)).sum()
            _, logdetS = np.linalg.slogdet(S)
            F += c * (logdet + np.trace(S @ Si) - logdetS - self.p + d @ Si @ d)
            Gm = c * (Si - Si @ (S + np.outer(d, d)) @ Si)  # dF/dSigma (symmetric matrix derivative)
            gmu = -2 * c * Si @ d
            dL = 2 * Gm @ L @ Ps + np.outer(gmu, al)
            dPs = L.T @ Gm @ L
            dCh = 2 * dPs @ self._Ch  # dF/dC for Psi = C C' (dPs symmetric)
            dTh = np.diag(Gm)
            dnu = gmu
            dal = L.T @ gmu
            msk = s["L_idx"] >= 0
            np.add.at(grad, s["L_idx"][msk], dL[msk])
            msk = s["nu_idx"] >= 0
            np.add.at(grad, s["nu_idx"][msk], dnu[msk])
            np.add.at(grad, s["th_idx"], dTh)
            msk = s["ps_idx"] >= 0
            np.add.at(grad, s["ps_idx"][msk], dCh[msk])
            msk = s["al_idx"] >= 0
            np.add.at(grad, s["al_idx"][msk], dal[msk])
        return F, grad

    def fit(self, x0=None):
        x0 = self.start if x0 is None else x0
        best = None
        for _ in range(4):
            r = optimize.minimize(self.f_and_grad, x0, jac=True, method="L-BFGS-B", bounds=self.bounds,
                                  options=dict(maxiter=20000, maxfun=40000, ftol=1e-15, gtol=1e-9, maxcor=50))
            if best is None or r.fun < best.fun - 1e-10:
                best = r
                x0 = r.x
            else:
                break
        self.res = best
        self.theta = best.x
        moments_n = self.G * (self.p * (self.p + 3) // 2)
        self.df = moments_n - self.npar
        self.chisq = best.fun
        self.maxgrad = float(np.max(np.abs(best.jac)))
        return self


    def warm_start(self, singles):
        """Start vector from single-group M1 fits (one per group); shared parameters take the mean over groups."""
        acc = np.zeros(self.npar)
        cnt = np.zeros(self.npar)
        K = list(self.factors)
        pos = {v: i for i, v in enumerate(self.items)}
        for g, sm in enumerate(singles):
            L, nu, Th, Ps, al = sm.mats(sm.theta, 0)
            alpha = np.array([nu[pos[self.markers[f]]] for f in K])
            if self.model in ("M1", "M2"):
                nuv, alv = nu, np.zeros(self.k)
            else:
                nuv, alv = nu - L @ alpha, alpha
            Ch = np.linalg.cholesky(Ps + 1e-8 * np.eye(self.k))
            s = self.spec[g]
            for idx, val in ((s["L_idx"], L), (s["nu_idx"], nuv), (s["th_idx"], Th), (s["ps_idx"], Ch), (s["al_idx"], alv)):
                msk = idx >= 0
                np.add.at(acc, idx[msk], val[msk])
                np.add.at(cnt, idx[msk], 1)
        x0 = acc / np.maximum(cnt, 1)
        lb = np.array([b[0] for b in self.bounds])
        return np.maximum(x0, np.where(np.isfinite(lb), lb, -np.inf))


def fit_mg(items, factors, markers, model, released, groups):
    """Fit from the default start and from a warm start built from single-group fits; keep the lower minimum."""
    singles = [MGModel(items, factors, markers, "M1", [], [g]).fit() for g in groups]
    a = MGModel(items, factors, markers, model, released, groups)
    b = MGModel(items, factors, markers, model, released, groups)
    a.fit()
    b.fit(b.warm_start(singles))
    best = a if a.chisq <= b.chisq else b
    best.alt_chisq = max(a.chisq, b.chisq)
    return best


def baseline_free(groups):
    """Independence baseline: free means and variances per group, zero covariances, no cross-group constraints."""
    chi = 0.0
    p = groups[0][2].shape[0]
    for n, m, S in groups:
        _, ld = np.linalg.slogdet(S)
        chi += (n - 1) * (np.log(np.diag(S)).sum() - ld)
    return chi, len(groups) * p * (p - 1) // 2


def baseline_equal(groups):
    """Independence baseline with item means and variances equal across groups (closed form ML, Wishart weights)."""
    p = groups[0][2].shape[0]
    cs = np.array([n - 1 for n, _, _ in groups], float)
    M = np.array([m for _, m, _ in groups])
    V = np.array([np.diag(S) for _, _, S in groups])
    mu = (cs[:, None] * M).sum(0) / cs.sum()
    s2 = (cs[:, None] * (V + (M - mu) ** 2)).sum(0) / cs.sum()
    chi = 0.0
    for g, (n, m, S) in enumerate(groups):
        _, ld = np.linalg.slogdet(S)
        chi += (n - 1) * (np.log(s2).sum() + ((V[g] + (M[g] - mu) ** 2) / s2).sum() - ld - p)
    df = len(groups) * p * (p + 3) // 2 - 2 * p
    return chi, df


def cfi(chi, df, chib, dfb):
    num = max(chi - df, 0)
    den = max(chib - dfb, chi - df, 0)
    return 1 - num / den if den > 0 else 1.0
