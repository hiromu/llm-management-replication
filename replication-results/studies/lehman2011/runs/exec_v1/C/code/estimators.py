"""Likelihoods and inference. No empirical data access in this module.

Exact conditional denominator: coefficient of z**m in prod(1+exp(eta_i)z).
An exponential tilt converts this to a well-scaled Poisson-binomial PMF.
Batched polynomial multiplication and reverse differentiation calculate the
coefficient and its score, without a tie approximation or subset sampling.
"""
from dataclasses import dataclass
import numpy as np
from scipy.fft import rfft, irfft, next_fast_len
from scipy.linalg import solve_triangular
from scipy.optimize import minimize, brentq
from scipy.special import expit, gammaln, logsumexp, roots_hermite, xlogy


def polynomial_probability(q, m):
    """Return P(S=m) and its derivatives w.r.t. Bernoulli probabilities."""
    n = len(q)
    size = 1 << (n - 1).bit_length()
    a = np.zeros((size, 2))
    a[:, 0] = 1
    a[:n, 0], a[:n, 1] = 1 - q, q
    levels = []
    while len(a) > 1:
        left, right = a[::2], a[1::2]
        width = min(m + 1, 2 * a.shape[1] - 1)
        if a.shape[1] <= 8:
            parent = np.zeros((len(left), width))
            for j in range(a.shape[1]):
                k = min(a.shape[1], width - j)
                if k > 0:
                    parent[:, j:j+k] += left[:, j:j+1] * right[:, :k]
            fftsize = None
        else:
            fftsize = next_fast_len(2 * a.shape[1] - 1)
            parent = irfft(rfft(left, fftsize) * rfft(right, fftsize), fftsize)[:, :width]
        levels.append((a, fftsize))
        a = parent
    pm = a[0, m]
    if not np.isfinite(pm) or pm <= 0:
        raise FloatingPointError("Non-positive tilted exact probability")
    adj = np.zeros_like(a)
    adj[0, m] = 1
    for child, fftsize in reversed(levels):
        left, right = child[::2], child[1::2]
        width, pw = child.shape[1], adj.shape[1]
        back = np.zeros_like(child)
        if fftsize is None:
            for j in range(width):
                k = min(width, pw - j)
                if k > 0:
                    back[::2, j] = np.sum(adj[:, j:j+k] * right[:, :k], axis=1)
                    back[1::2, j] = np.sum(adj[:, j:j+k] * left[:, :k], axis=1)
        else:
            # Circular cross-correlation is linear on indices 0..width-1
            # because the FFT is padded to at least 2*width-1.
            af = rfft(adj, fftsize)
            back[::2] = irfft(af * np.conj(rfft(right, fftsize)), fftsize)[:, :width]
            back[1::2] = irfft(af * np.conj(rfft(left, fftsize)), fftsize)[:, :width]
        adj = back
    return pm, adj[:n, 1] - adj[:n, 0]


def conditional_group(eta, y):
    m, n = int(y.sum()), len(y)
    if m == 0 or m == n:
        return 0., np.zeros(n)
    # Complementing cases is an exact identity and reduces polynomial degree.
    sign = 1
    if m > n // 2:
        eta, y, m, sign = -eta, 1 - y, n - m, -1
    tilt = brentq(lambda a: expit(eta + a).sum() - m,
                  -float(np.max(eta)) - 40, -float(np.min(eta)) + 40,
                  xtol=1e-12)
    t = eta + tilt
    q = expit(t)
    pm, dp = polynomial_probability(q, m)
    ll = y @ t - np.logaddexp(0, t).sum() - np.log(pm)
    score = sign * (y - q - dp * q * (1 - q) / pm)
    return float(ll), score


def jacobian(fun, x, step=2e-5):
    x = np.asarray(x, float)
    h = step * np.maximum(1, np.abs(x))
    cols = []
    for j in range(len(x)):
        d = np.zeros_like(x)
        d[j] = h[j]
        cols.append((np.asarray(fun(x + d)) - np.asarray(fun(x - d))) / (2*h[j]))
    return np.stack(cols, axis=-1)


def inverse_information(info):
    info = (info + info.T) / 2
    np.linalg.cholesky(info)  # Do not silently use a generalized inverse.
    return np.linalg.inv(info)


@dataclass
class Fit:
    beta: np.ndarray
    cov: np.ndarray
    names: list
    ll: float
    null_ll: float
    null_label: str
    df: int
    converged: bool
    iterations: int
    n: int
    groups: int
    dropped: int
    used: np.ndarray
    routine: str
    error: str = ""
    bench: np.ndarray | None = None
    clusters: int | None = None
    sigma: float | None = None


def fit_fixed(X, y, groups, names, conditional=True, start=None, start_cov=None):
    X, y, groups = np.asarray(X, float), np.asarray(y, float), np.asarray(groups)
    unique, codes = np.unique(groups, return_inverse=True)
    blocks = [np.flatnonzero(codes == j) for j in range(len(unique))]
    good = [i for i in blocks if 0 < y[i].sum() < len(i)]
    dropped = len(blocks) - len(good) if conditional else 0
    used = np.sort(np.concatenate(good)) if conditional else np.arange(len(y))
    if not len(used):
        raise ValueError("No informative observations")
    X, y, groups = X[used], y[used], groups[used]
    unique, codes = np.unique(groups, return_inverse=True)
    blocks = [np.flatnonzero(codes == j) for j in range(len(unique))]
    C = X.copy()
    if conditional:
        for ix in blocks:
            C[ix] -= C[ix].mean(axis=0)
    # QR is a numerical reparameterization, not variable selection.
    scale = np.sqrt(np.mean(C*C, axis=0))
    if np.any(scale < 1e-14):
        raise ValueError("Unidentified constant/absent regressor: " + str(np.array(names)[scale < 1e-14].tolist()))
    _, R = np.linalg.qr(C / scale, mode="reduced")
    if np.min(np.abs(np.diag(R))) < 1e-9:
        raise ValueError("Rank-deficient fixed regressor list")
    T = solve_triangular(R, np.eye(len(names))) * np.sqrt(len(y))
    T = T / scale[:, None]
    Z = C @ T
    if conditional:
        def objective(theta):
            eta = Z @ theta
            ll, s = 0., np.empty(len(y))
            for ix in blocks:
                lg, sg = conditional_group(eta[ix], y[ix])
                ll += lg
                s[ix] = sg
            return -ll, -(Z.T @ s)
        null = -sum(gammaln(len(i)+1) - gammaln(y[i].sum()+1)
                    - gammaln(len(i)-y[i].sum()+1) for i in blocks)
        label, df = "exact conditional, no regressors", len(names)
    else:
        def objective(theta):
            eta = Z @ theta
            return float(np.logaddexp(0, eta).sum() - y @ eta), Z.T @ (expit(eta)-y)
        null = sum(xlogy(y[i].sum(), y[i].mean()) +
                   xlogy(len(i)-y[i].sum(), 1-y[i].mean()) for i in blocks)
        label, df = "intercept and team dummies only", len(names)-len(unique)
    initial = np.zeros(len(names)) if start is None else np.linalg.solve(T, start)
    opts = dict(gtol=2e-6, maxiter=250)
    if start_cov is not None:
        invT = np.linalg.inv(T)
        h0 = invT @ start_cov @ invT.T
        h0 = (h0 + h0.T)/2
        try:
            np.linalg.cholesky(h0)
            opts["hess_inv0"] = h0
        except np.linalg.LinAlgError:
            pass
    else:
        rate = max(y.mean()*(1-y.mean()), .01)
        opts["hess_inv0"] = np.eye(len(names))/(len(y)*rate)
    opt = minimize(objective, initial, jac=True, method="BFGS", options=opts)
    theta = opt.x
    if conditional:
        info = jacobian(lambda t: objective(t)[1], theta)
    else:
        p = expit(Z @ theta)
        info = Z.T @ ((p*(1-p))[:, None]*Z)
    vtheta = inverse_information(info)
    value, grad = objective(theta)
    # The score criterion is invariant to sample size in SE units.
    score_size = float(np.sqrt(max(0, grad @ vtheta @ grad)))
    converged = bool(np.isfinite(value) and score_size < 1e-4)
    cov = T @ vtheta @ T.T
    return Fit(T @ theta, (cov+cov.T)/2, names, -value, float(null), label, df,
               converged, int(opt.nit), len(y), len(unique), dropped, used,
               "estimators.fit_fixed: exact tilted polynomial product/reverse score; "
               "BFGS gtol=2e-6 maxiter=250; central-score observed information h=2e-5"
               if conditional else "estimators.fit_fixed: unpenalized dummy logit ML; "
               "BFGS gtol=2e-6 maxiter=250; analytic observed information",
               "" if converged else str(opt.message) + f"; score norm in SE units={score_size:g}")


def sandwich(X, y, beta, cov, clusters):
    X, y = np.asarray(X, float), np.asarray(y, float)
    _, ix = np.unique(np.asarray(clusters), return_inverse=True)
    G, N, K = ix.max()+1, len(y), len(beta)
    if G <= 1 or N <= K:
        raise ValueError("CR1 requires G>1 and N>K")
    score = X * (y-expit(X @ beta))[:, None]
    sums = np.zeros((G, K))
    np.add.at(sums, ix, score)
    v = cov @ (sums.T @ sums) @ cov * (G/(G-1)*(N-1)/(N-K))
    return (v+v.T)/2, int(G)


def random_objective(X, y, groups, points=20):
    """Adaptive GH and analytic derivatives, including moving nodes/scale."""
    nodes, weights = roots_hermite(points)
    blocks = [np.flatnonzero(groups == g) for g in np.unique(groups)]
    def objective(theta):
        beta, logsigma = theta[:-1], theta[-1]
        precision = np.exp(-2*logsigma)
        ll, grad = 0., np.zeros_like(theta)
        for ix in blocks:
            x, yy = X[ix], y[ix]
            eta = x @ beta
            u = 0.
            for _ in range(60):
                p = expit(eta+u)
                w = p*(1-p)
                H = w.sum()+precision
                delta = np.clip(((yy-p).sum()-u*precision)/H, -5., 5.)
                u += delta
                if abs(delta) < 1e-11:
                    break
            else:
                # The posterior log density is strictly concave. Bracketing
                # guarantees its unique mode even at line-search trial values.
                bound = len(ix)/precision+1
                u = brentq(lambda v: (yy-expit(eta+v)).sum()-v*precision,
                           -bound, bound, xtol=1e-12)
            p = expit(eta+u)
            w = p*(1-p)
            H = w.sum()+precision
            du = np.r_[-(w @ x)/H, 2*u*precision/H]
            deta = np.column_stack((x, np.zeros(len(ix)))) + du
            dH = (w*(1-2*p)) @ deta
            dH[-1] -= 2*precision
            s = 1/np.sqrt(H)
            dlogs = -.5*dH/H
            un = u + np.sqrt(2)*s*nodes
            dn = du[None, :] + (np.sqrt(2)*s*nodes)[:, None]*dlogs
            z = eta[:, None]+un
            pn = expit(z)
            h = (yy[:, None]*z-np.logaddexp(0, z)).sum(axis=0) - .5*precision*un**2
            h -= logsigma + .5*np.log(2*np.pi)
            vals = np.log(weights)+h+nodes**2
            lognorm = logsumexp(vals)
            post = np.exp(vals-lognorm)
            partial = np.column_stack(((yy[:, None]-pn).T @ x,
                                       precision*un**2-1))
            hu = (yy[:, None]-pn).sum(axis=0)-un*precision
            ll += .5*np.log(2)+np.log(s)+lognorm
            grad += dlogs + post @ (partial + hu[:, None]*dn)
        return -float(ll), -grad
    return objective


def fit_random(X, y, groups, names, points=20):
    X, y, groups = np.asarray(X, float), np.asarray(y, float), np.asarray(groups)
    scales = np.sqrt(np.mean(X*X, axis=0))
    _, R = np.linalg.qr(X/scales, mode="reduced")
    T = solve_triangular(R, np.eye(X.shape[1]))*np.sqrt(len(y))/scales[:, None]
    Z = X @ T
    fun = random_objective(Z, y, groups, points)
    start = np.zeros(X.shape[1]+1)
    raw_start = np.zeros(X.shape[1])
    raw_start[0] = np.log(y.mean()/(1-y.mean()))
    start[:-1] = np.linalg.solve(T, raw_start)
    start[-1] = np.log(.7)
    h0 = np.eye(len(start))/(len(y)*.2)
    h0[-1, -1] = 1/(2*len(np.unique(groups)))
    opt = minimize(fun, start, jac=True, method="BFGS",
                   options=dict(gtol=2e-6, maxiter=250, hess_inv0=h0))
    covall = inverse_information(jacobian(lambda t: fun(t)[1], opt.x))
    value, grad = fun(opt.x)
    converged = float(np.sqrt(max(0, grad @ covall @ grad))) < 1e-4
    nf = random_objective(np.ones((len(y), 1)), y, groups, points)
    no = minimize(nf, [np.log(y.mean()/(1-y.mean())), opt.x[-1]], jac=True,
                  method="BFGS", options=dict(gtol=2e-6, maxiter=250))
    if np.linalg.norm(no.jac) > 1e-3:
        raise RuntimeError("N1 null failed to converge: " + str(no.message))
    # Include log SD in output; it is explicitly an ancillary parameter.
    Tall = np.zeros_like(covall)
    Tall[:-1, :-1], Tall[-1, -1] = T, 1
    return Fit(Tall @ opt.x, Tall @ covall @ Tall.T, names+["log_sigma_team"],
               -value, -float(no.fun), "random intercept + fixed intercept only", len(names)-1,
               converged, int(opt.nit), len(y), len(np.unique(groups)), 0, np.arange(len(y)),
               f"estimators.fit_random: normal random intercept ML; adaptive Gauss-Hermite {points} points; "
               "analytic moving-node score; BFGS maxiter=250 gtol=2e-6; observed information",
               "" if converged else str(opt.message), sigma=float(np.exp(opt.x[-1])))
