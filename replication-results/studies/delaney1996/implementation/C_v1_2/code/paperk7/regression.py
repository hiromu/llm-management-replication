"""OLS / WLS with conventional and HC3 standard errors, nested F tests.

Everything is computed with numpy; statsmodels is only used in the tests as a
reference. For WLS the "weighted design" convention is used throughout:
X_w = sqrt(w) X, y_w = sqrt(w) y, and residuals/leverages refer to X_w.

v1.1 (amendment A1): rows whose leverage h_ii >= 1 - 1e-8 contribute exactly
zero to the HC3 meat; the number of such rows is returned as n_leverage_one.
v1.1 (amendment A5): industry-dummy collinearity is resolved before the
residual-df check (drop_collinear_dummies is always called before fit_linear
by the pipeline); non-dummy all-zero / collinear columns fail with that reason.
v1.2 (checker item 1): the non-dummy reason is reported whatever the row count;
the residual-df check is made only in fit_linear, after the permitted drops.
"""
from __future__ import annotations

import numpy as np
from scipy import stats

LEVERAGE_ONE_TOL = 1e-8


class FitError(Exception):
    """Raised when a model cannot be estimated."""


def _tail_p(t, df):
    """Return (p_two, p_upper, p_lower) for t statistics with df degrees."""
    p_upper = stats.t.sf(t, df)
    p_lower = stats.t.cdf(t, df)
    p_two = 2.0 * stats.t.sf(np.abs(t), df)
    return p_two, p_upper, p_lower


def _rank(mat):
    if mat.shape[1] == 0 or mat.shape[0] == 0:
        return 0
    return int(np.linalg.matrix_rank(mat))


def _check_non_dummy_columns(X, names, keep_idx):
    """Fail with a specific reason if the non-droppable columns are degenerate.

    Amendment A5 (v1.2, checker item 1): an all-zero or collinear non-dummy
    column is always reported as such, whatever the number of rows. The
    residual-df check is never made here; it happens in fit_linear, after the
    permitted dummy drops. When the design has no more rows than non-dummy
    columns the non-dummy block is necessarily rank deficient; the columns that
    do not raise the rank are then reported as collinear and the row count is
    appended to the reason.
    """
    n = X.shape[0]
    zero = [names[i] for i in keep_idx if not np.any(X[:, i] != 0)]
    if zero:
        raise FitError("non-dummy column(s) all zero: " + ",".join(zero))
    base = X[:, keep_idx]
    if _rank(base) == len(keep_idx):
        return
    # find the columns that do not increase the rank, in column order
    cur = np.empty((n, 0))
    cur_rank = 0
    bad = []
    for i in keep_idx:
        trial = np.column_stack([cur, X[:, i]])
        r = _rank(trial)
        if r > cur_rank:
            cur, cur_rank = trial, r
        else:
            bad.append(names[i])
    msg = "non-dummy column(s) collinear: " + ",".join(bad)
    if n <= len(keep_idx):
        msg += f" (n={n} rows, {len(keep_idx)} non-dummy columns)"
    raise FitError(msg)


def drop_collinear_dummies(X, names, droppable):
    """Drop all-zero and collinear columns among `droppable` (dummy) columns.

    Columns are checked in their order; a droppable column is removed if it is
    all zero or does not increase the rank of the matrix formed by the columns
    kept so far (including all non-droppable columns, which are never dropped).
    Returns (X_kept, names_kept, dropped: list of (name, reason)).
    Raises FitError if the non-droppable columns are themselves all zero or
    collinear (or if there are not even enough rows for them).
    """
    X = np.asarray(X, dtype=float)
    names = list(names)
    if X.shape[0] == 0:
        raise FitError("empty estimation sample")
    if not np.all(np.isfinite(X)):
        bad = [names[j] for j in range(X.shape[1]) if not np.all(np.isfinite(X[:, j]))]
        raise FitError("non-finite values in design columns: " + ",".join(bad))
    droppable = set(droppable)
    dropped = []
    keep_idx = [i for i, nm in enumerate(names) if nm not in droppable]
    _check_non_dummy_columns(X, names, keep_idx)
    cur = X[:, keep_idx]
    cur_rank = len(keep_idx)
    kept_order = list(keep_idx)
    for i, nm in enumerate(names):
        if nm not in droppable:
            continue
        col = X[:, i]
        if not np.any(col != 0):
            dropped.append((nm, "all_zero"))
            continue
        trial = np.column_stack([cur, col])
        r = _rank(trial)
        if r > cur_rank:
            cur = trial
            cur_rank = r
            kept_order.append(i)
        else:
            dropped.append((nm, "collinear"))
    kept_order = sorted(kept_order)
    return X[:, kept_order], [names[i] for i in kept_order], dropped


def fit_linear(X, y, names, weights=None):
    """Fit OLS (weights None) or WLS. Returns a dict of results.

    X: (n, k) design including the intercept column; names: column names.
    Raises FitError on degenerate inputs. Callers that may hold droppable
    industry dummies must call drop_collinear_dummies first (amendment A5).
    """
    X = np.asarray(X, dtype=float)
    y = np.asarray(y, dtype=float)
    n, k = X.shape
    if n == 0:
        raise FitError("empty estimation sample")
    if n <= k:
        raise FitError(f"no residual degrees of freedom (n={n}, k={k})")
    if not np.all(np.isfinite(X)) or not np.all(np.isfinite(y)):
        raise FitError("non-finite values in design or outcome")
    if weights is None:
        w = np.ones(n)
    else:
        w = np.asarray(weights, dtype=float)
        if np.any(~np.isfinite(w)) or np.any(w <= 0):
            raise FitError("weights must be positive and finite")
    sw = np.sqrt(w)
    Xw = X * sw[:, None]
    yw = y * sw
    XtX = Xw.T @ Xw
    if _rank(Xw) < k:
        raise FitError("design matrix is rank deficient")
    XtX_inv = np.linalg.inv(XtX)
    beta = XtX_inv @ (Xw.T @ yw)
    resid = y - X @ beta  # unweighted residuals
    ew = resid * sw  # weighted residuals
    df = n - k
    ssr = float(ew @ ew)
    sigma2 = ssr / df
    cov = sigma2 * XtX_inv
    se = np.sqrt(np.diag(cov))
    # leverage of the weighted design
    h = np.einsum("ij,jk,ik->i", Xw, XtX_inv, Xw)
    # Amendment A1: rows with h_ii >= 1 - 1e-8 are fitted exactly (residual 0);
    # their HC3 term e_i^2/(1-h_ii)^2 is set to exactly zero, i.e. the meat is
    # formed from the other rows only. The bread (X'X)^-1 is unchanged.
    lev_one = (1.0 - h) <= LEVERAGE_ONE_TOL
    n_lev_one = int(np.sum(lev_one))
    omega = np.zeros(n)
    ok = ~lev_one
    omega[ok] = (ew[ok] / (1.0 - h[ok])) ** 2
    meat = (Xw * omega[:, None]).T @ Xw
    cov_hc3 = XtX_inv @ meat @ XtX_inv
    se_hc3 = np.sqrt(np.maximum(np.diag(cov_hc3), 0.0))
    with np.errstate(divide="ignore", invalid="ignore"):
        t = beta / se
        t_hc3 = beta / se_hc3
    p_two, p_upper, p_lower = _tail_p(t, df)
    p_two_hc3, p_upper_hc3, p_lower_hc3 = _tail_p(t_hc3, df)
    # R2 (weighted, centred on the weighted mean) and overall F
    ybar_w = float(np.sum(w * y) / np.sum(w))
    sst = float(np.sum(w * (y - ybar_w) ** 2))
    r2 = 1.0 - ssr / sst if sst > 0 else np.nan
    adj_r2 = 1.0 - (1.0 - r2) * (n - 1) / df if sst > 0 else np.nan
    q = k - 1  # slopes
    if q > 0 and ssr > 0 and sst > 0:
        f = ((sst - ssr) / q) / (ssr / df)
        f_p = float(stats.f.sf(f, q, df))
    else:
        f, f_p = np.nan, np.nan
    return {
        "names": list(names),
        "beta": beta,
        "se": se,
        "t": t,
        "df": df,
        "p_two": p_two,
        "p_upper": p_upper,
        "p_lower": p_lower,
        "se_hc3": se_hc3,
        "t_hc3": t_hc3,
        "p_two_hc3": p_two_hc3,
        "p_upper_hc3": p_upper_hc3,
        "p_lower_hc3": p_lower_hc3,
        "n": n,
        "k": k,
        "ssr": ssr,
        "sst": sst,
        "r2": r2,
        "adj_r2": adj_r2,
        "f": f,
        "f_df1": q,
        "f_df2": df,
        "f_p": f_p,
        "n_leverage_one": n_lev_one,
        "resid": resid,
        "leverage": h,
    }


def nested_f(fit_full, fit_restricted, n_added):
    """F test of the added terms; both fits on identical rows.

    df1 = number of added terms, df2 = residual df of the full model. The
    effective rank increase (k_full - k_restricted) must equal df1 (A5),
    otherwise a FitError is raised and the test is recorded as failed.
    Returns (delta_r2, f, df1, df2, p).
    """
    if fit_full["n"] != fit_restricted["n"]:
        raise FitError("nested models fitted on different rows")
    df1 = int(n_added)
    rank_increase = int(fit_full["k"]) - int(fit_restricted["k"])
    if rank_increase != df1:
        raise FitError(f"effective rank increase {rank_increase} differs from the number of added terms {df1}")
    df2 = int(fit_full["df"])
    ssr_f = fit_full["ssr"]
    ssr_r = fit_restricted["ssr"]
    delta_r2 = fit_full["r2"] - fit_restricted["r2"]
    if df1 <= 0 or ssr_f <= 0:
        return delta_r2, np.nan, df1, df2, np.nan
    f = ((ssr_r - ssr_f) / df1) / (ssr_f / df2)
    p = float(stats.f.sf(f, df1, df2))
    return delta_r2, f, df1, df2, p
