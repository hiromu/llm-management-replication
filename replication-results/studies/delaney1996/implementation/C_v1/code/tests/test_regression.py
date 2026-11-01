"""Regression engine tests: OLS, WLS, conventional and HC3 SE, one-tailed p, nested F.

Reference: statsmodels (OLS/WLS, cov_type="HC3", compare_f_test) and scipy.
"""
import os
import sys
import unittest

import numpy as np
import statsmodels.api as sm
from scipy import stats

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from paperk7.regression import FitError, drop_collinear_dummies, fit_linear, nested_f  # noqa: E402


def simulate(n=120, seed=7, hetero=False):
    rng = np.random.default_rng(seed)
    x1 = rng.normal(size=n)
    x2 = rng.normal(size=n)
    d = (rng.uniform(size=n) < 0.3).astype(float)
    scale = np.exp(0.8 * x1) if hetero else 1.0
    y = 1.0 + 2.0 * x1 - 1.0 * x2 + 0.5 * d + rng.normal(size=n) * scale
    X = np.column_stack([np.ones(n), x1, x2, d])
    names = ["(Intercept)", "x1", "x2", "d"]
    return X, y, names


class TestOLS(unittest.TestCase):
    def test_known_structure_exact(self):
        # no noise: coefficients recovered exactly, R2 = 1
        n = 50
        rng = np.random.default_rng(1)
        x1, x2 = rng.normal(size=n), rng.normal(size=n)
        y = 3.0 + 1.5 * x1 - 2.0 * x2
        X = np.column_stack([np.ones(n), x1, x2])
        fit = fit_linear(X, y, ["(Intercept)", "x1", "x2"])
        np.testing.assert_allclose(fit["beta"], [3.0, 1.5, -2.0], atol=1e-10)
        self.assertAlmostEqual(fit["r2"], 1.0, places=12)
        self.assertEqual(fit["df"], n - 3)

    def test_against_statsmodels_ols(self):
        X, y, names = simulate(hetero=True)
        fit = fit_linear(X, y, names)
        ref = sm.OLS(y, X).fit()
        ref_hc3 = sm.OLS(y, X).fit(cov_type="HC3")
        np.testing.assert_allclose(fit["beta"], ref.params, rtol=1e-10)
        np.testing.assert_allclose(fit["se"], ref.bse, rtol=1e-10)
        np.testing.assert_allclose(fit["t"], ref.tvalues, rtol=1e-10)
        np.testing.assert_allclose(fit["p_two"], ref.pvalues, rtol=1e-8)
        self.assertEqual(fit["df"], int(ref.df_resid))
        self.assertAlmostEqual(fit["r2"], ref.rsquared, places=12)
        self.assertAlmostEqual(fit["adj_r2"], ref.rsquared_adj, places=12)
        self.assertAlmostEqual(fit["f"], ref.fvalue, places=8)
        self.assertAlmostEqual(fit["f_p"], ref.f_pvalue, places=10)
        self.assertEqual((fit["f_df1"], fit["f_df2"]), (int(ref.df_model), int(ref.df_resid)))
        # HC3 against statsmodels and against the explicit formula
        np.testing.assert_allclose(fit["se_hc3"], ref_hc3.bse, rtol=1e-10)
        XtXi = np.linalg.inv(X.T @ X)
        h = np.diag(X @ XtXi @ X.T)
        e = y - X @ ref.params
        meat = X.T @ np.diag(e ** 2 / (1 - h) ** 2) @ X
        np.testing.assert_allclose(fit["se_hc3"], np.sqrt(np.diag(XtXi @ meat @ XtXi)), rtol=1e-10)
        # HC3 p values use the t distribution with residual df (not normal)
        t3 = fit["beta"] / fit["se_hc3"]
        np.testing.assert_allclose(fit["t_hc3"], t3)
        np.testing.assert_allclose(fit["p_two_hc3"], 2 * stats.t.sf(np.abs(t3), fit["df"]))
        np.testing.assert_allclose(fit["p_upper_hc3"], stats.t.sf(t3, fit["df"]))
        np.testing.assert_allclose(fit["p_lower_hc3"], stats.t.cdf(t3, fit["df"]))

    def test_one_tailed_p(self):
        X, y, names = simulate()
        fit = fit_linear(X, y, names)
        for j in range(len(names)):
            t, df = fit["t"][j], fit["df"]
            self.assertAlmostEqual(fit["p_upper"][j], stats.t.sf(t, df), places=14)
            self.assertAlmostEqual(fit["p_lower"][j], stats.t.cdf(t, df), places=14)
            self.assertAlmostEqual(fit["p_upper"][j] + fit["p_lower"][j], 1.0, places=14)
            self.assertAlmostEqual(fit["p_two"][j], 2 * min(fit["p_upper"][j], fit["p_lower"][j]), places=14)
        # x1 has a strongly positive true coefficient: upper-tail p tiny, lower-tail p near 1
        self.assertLess(fit["p_upper"][1], 1e-6)
        self.assertGreater(fit["p_lower"][1], 1 - 1e-6)
        # x2 has a negative coefficient: the reverse
        self.assertGreater(fit["p_upper"][2], 1 - 1e-6)

    def test_nested_f_against_statsmodels(self):
        X, y, names = simulate(n=200, seed=3)
        full = fit_linear(X, y, names)
        restricted = fit_linear(X[:, :2], y, names[:2])
        d_r2, f, df1, df2, p = nested_f(full, restricted, 2)
        ref_full = sm.OLS(y, X).fit()
        ref_res = sm.OLS(y, X[:, :2]).fit()
        f_ref, p_ref, df_ref = ref_full.compare_f_test(ref_res)
        self.assertAlmostEqual(f, f_ref, places=10)
        self.assertAlmostEqual(p, p_ref, places=10)
        self.assertEqual(df1, int(df_ref))
        self.assertEqual(df2, int(ref_full.df_resid))
        self.assertAlmostEqual(d_r2, ref_full.rsquared - ref_res.rsquared, places=12)
        # closed form from R2
        f_r2 = (d_r2 / df1) / ((1 - full["r2"]) / df2)
        self.assertAlmostEqual(f, f_r2, places=10)

    def test_nested_f_requires_same_rows(self):
        X, y, names = simulate(n=60)
        full = fit_linear(X, y, names)
        restricted = fit_linear(X[:-1, :2], y[:-1], names[:2])
        with self.assertRaises(FitError):
            nested_f(full, restricted, 2)


class TestWLS(unittest.TestCase):
    def test_against_statsmodels_wls(self):
        X, y, names = simulate(n=150, seed=11, hetero=True)
        rng = np.random.default_rng(5)
        w = rng.uniform(0.2, 5.0, size=len(y))
        fit = fit_linear(X, y, names, weights=w)
        ref = sm.WLS(y, X, weights=w).fit()
        ref_hc3 = sm.WLS(y, X, weights=w).fit(cov_type="HC3")
        np.testing.assert_allclose(fit["beta"], ref.params, rtol=1e-10)
        np.testing.assert_allclose(fit["se"], ref.bse, rtol=1e-10)
        np.testing.assert_allclose(fit["se_hc3"], ref_hc3.bse, rtol=1e-10)
        self.assertAlmostEqual(fit["r2"], ref.rsquared, places=12)
        self.assertAlmostEqual(fit["adj_r2"], ref.rsquared_adj, places=12)
        self.assertAlmostEqual(fit["f"], ref.fvalue, places=8)
        self.assertAlmostEqual(fit["f_p"], ref.f_pvalue, places=10)
        # weighted R2 equals 1 - SSR_w / SST_w with weighted mean
        ybar = np.sum(w * y) / np.sum(w)
        sst = np.sum(w * (y - ybar) ** 2)
        ssr = np.sum(w * (y - X @ fit["beta"]) ** 2)
        self.assertAlmostEqual(fit["r2"], 1 - ssr / sst, places=12)
        # HC3 with the weighted design, explicit formula
        sw = np.sqrt(w)
        Xw, ew = X * sw[:, None], (y - X @ fit["beta"]) * sw
        XtXi = np.linalg.inv(Xw.T @ Xw)
        h = np.einsum("ij,jk,ik->i", Xw, XtXi, Xw)
        meat = Xw.T @ np.diag(ew ** 2 / (1 - h) ** 2) @ Xw
        np.testing.assert_allclose(fit["se_hc3"], np.sqrt(np.diag(XtXi @ meat @ XtXi)), rtol=1e-10)

    def test_weighted_nested_f(self):
        X, y, names = simulate(n=150, seed=12)
        w = np.random.default_rng(6).uniform(0.5, 3.0, size=len(y))
        full = fit_linear(X, y, names, weights=w)
        restricted = fit_linear(X[:, :2], y, names[:2], weights=w)
        d_r2, f, df1, df2, p = nested_f(full, restricted, 2)
        rf = sm.WLS(y, X, weights=w).fit()
        rr = sm.WLS(y, X[:, :2], weights=w).fit()
        f_ref, p_ref, _ = rf.compare_f_test(rr)
        self.assertAlmostEqual(f, f_ref, places=10)
        self.assertAlmostEqual(p, p_ref, places=10)
        self.assertAlmostEqual(d_r2, rf.rsquared - rr.rsquared, places=12)

    def test_bad_weights(self):
        X, y, names = simulate(n=30)
        w = np.ones(30)
        w[3] = 0.0
        with self.assertRaises(FitError):
            fit_linear(X, y, names, weights=w)


class TestDegenerate(unittest.TestCase):
    def test_leverage_one_gives_na_hc3(self):
        # a dummy with a single member -> leverage 1 -> HC3 undefined (NA), conventional SE fine
        X, y, names = simulate(n=40, seed=2)
        single = np.zeros(40)
        single[5] = 1.0
        X2 = np.column_stack([X, single])
        fit = fit_linear(X2, y, names + ["IND_single"])
        self.assertEqual(fit["n_leverage_one"], 1)
        self.assertFalse(fit["hc3_ok"])
        self.assertTrue(np.all(np.isnan(fit["se_hc3"])))
        self.assertTrue(np.all(np.isfinite(fit["se"])))
        ref = sm.OLS(y, X2).fit()
        np.testing.assert_allclose(fit["se"], ref.bse, rtol=1e-10)

    def test_rank_deficient_and_no_df(self):
        X, y, names = simulate(n=30)
        with self.assertRaises(FitError):
            fit_linear(np.column_stack([X, X[:, 1]]), y, names + ["dup"])
        with self.assertRaises(FitError):
            fit_linear(X[:4], y[:4], names)

    def test_drop_collinear_dummies(self):
        X, y, names = simulate(n=40)
        zero = np.zeros(40)
        dup = X[:, 3].copy()  # identical to d -> collinear
        # dummies that sum to the intercept -> last one collinear
        g1 = (np.arange(40) < 20).astype(float)
        g2 = 1.0 - g1
        Xd = np.column_stack([X, zero, dup, g1, g2])
        nm = names + ["IND_zero", "IND_dup", "IND_g1", "IND_g2"]
        Xk, kept, dropped = drop_collinear_dummies(Xd, nm, ["IND_zero", "IND_dup", "IND_g1", "IND_g2"])
        self.assertEqual(dict(dropped), {"IND_zero": "all_zero", "IND_dup": "collinear", "IND_g2": "collinear"})
        self.assertEqual(kept, names + ["IND_g1"])
        self.assertEqual(Xk.shape[1], 5)
        # non-dummy collinearity is an error, not a silent drop
        with self.assertRaises(FitError):
            drop_collinear_dummies(np.column_stack([X, X[:, 1]]), names + ["x1b"], [])


if __name__ == "__main__":
    unittest.main()
