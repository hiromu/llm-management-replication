"""Tests for the v1.2 repair round: checker items 1-3, plus explicit
re-assertions of the amended behaviour the repair prompt calls out (HC3 with a
leverage-one row, in OLS and WLS; and the copy-rule validity).

Run as a script: python code/tests/test_v1_2.py
"""
import math
import os
import sys
import unittest

import numpy as np
import pandas as pd
import statsmodels.api as sm

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
from paperk7 import coding as C  # noqa: E402
from paperk7 import pipeline as P  # noqa: E402
from paperk7.regression import FitError, drop_collinear_dummies, fit_linear  # noqa: E402
from test_coding import META, base_settings, nan_eq, raw_frame  # noqa: E402
from test_v1_1 import CW, spec, stat, synth_raw  # noqa: E402

LN = math.log


# ----------------------------------------------------------------------------
# Checker item 1: a rank-deficient non-industry design fails with the all-zero /
# collinear reason, never a residual-df reason; residual-df failure is reserved
# for fit_linear after the permitted (industry-dummy) drops (amendment A5).
# ----------------------------------------------------------------------------
class TestItem1NonDummyReason(unittest.TestCase):
    def test_all_zero_non_dummy_with_too_few_rows(self):
        # three rows, an all-zero non-dummy column: the reason is all-zero, not df.
        X = np.column_stack([np.ones(3), np.array([1.0, 2.0, 3.0]), np.zeros(3), np.array([1.0, 0.0, 1.0])])
        with self.assertRaises(FitError) as cm:
            drop_collinear_dummies(X, ["(Intercept)", "STAFF", "SERVICE", "IND_01"], ["IND_01"])
        self.assertIn("all zero: SERVICE", str(cm.exception))
        self.assertNotIn("residual degrees of freedom", str(cm.exception))

    def test_more_non_dummy_columns_than_rows_is_collinear(self):
        # four independent non-dummy columns, three rows: one is collinear in the
        # sample. The reason names collinearity, not the residual df.
        rng = np.random.default_rng(5)
        X = np.column_stack([np.ones(3)] + [rng.normal(size=3) for _ in range(3)] + [rng.normal(size=3)])
        names = ["(Intercept)", "STAFF", "TRAIN", "INCENT", "IND_01"]
        with self.assertRaises(FitError) as cm:
            drop_collinear_dummies(X, names, ["IND_01"])
        self.assertIn("collinear", str(cm.exception))
        self.assertNotIn("residual degrees of freedom", str(cm.exception))

    def test_full_rank_non_dummy_passes_then_fit_reports_df(self):
        # non-dummy columns full rank but n == k after drops: drop_collinear_dummies
        # succeeds (no non-dummy degeneracy) and fit_linear is the one that fails
        # with the residual-df reason.
        n = 3
        X = np.column_stack([np.ones(n), np.array([1.0, 2.0, 3.0]), np.array([1.0, 4.0, 9.0])])
        Xk, names, dropped = drop_collinear_dummies(X, ["(Intercept)", "STAFF", "TRAIN"], [])
        self.assertEqual(dropped, [])
        with self.assertRaises(FitError) as cm:
            fit_linear(Xk, np.array([1.0, 2.0, 3.0]), names)
        self.assertIn("no residual degrees of freedom", str(cm.exception))


# ----------------------------------------------------------------------------
# Checker item 2: when the original influence model failed, write exactly one
# influence row per estimation-sample record (not one per term); term is NA;
# and no rows at all when the estimation sample is empty (amendment A6).
# ----------------------------------------------------------------------------
class TestItem2FailedOriginRows(unittest.TestCase):
    def _failed_model(self, v1s):
        return {"family": "org", "fit": None, "hrm": P.A_TERMS, "ints": P.A_INT,
                "V1": pd.Series(v1s, dtype=float),
                "error": "FitError: no residual degrees of freedom (n=9, k=9)"}

    def test_one_row_per_record(self):
        v1s = [2001, 2002, 2003, 2004]
        rows, failures = P.influence_rows("org_M4", self._failed_model(v1s))
        df = pd.DataFrame(rows)
        self.assertEqual(len(df), len(v1s))                       # one row per record, not per term
        self.assertEqual(sorted(df["deleted_V1"]), v1s)
        self.assertTrue((df["term"] == "NA").all())               # no per-term rows
        self.assertTrue((df["status"] == "failed").all())
        self.assertTrue(df["note"].str.startswith("original model failed:").all())
        for col in ("estimate", "se", "p_upper", "p_two"):
            self.assertTrue(df[col].isna().all(), col)
        self.assertEqual(len(failures), 1)
        self.assertEqual(failures[0]["stage"], "influence:org_M4")

    def test_empty_sample_emits_no_rows(self):
        rows, failures = P.influence_rows("org_M4", self._failed_model([]))
        self.assertEqual(rows, [])                                # no record -> no row
        self.assertEqual(len(failures), 1)

    def test_end_to_end_failed_origin(self):
        # n = 19: both dummies collinear with PRODUCT/SERVICE and dropped; org_M4/org_M5
        # then have k = 19 = n and fail on residual df, so their influence output is one
        # failed row per org record.
        groups = [10] * 11 + [600] * 5 + [20] * 3
        v41 = [3] * 11 + [1] * 5 + [2] * 3
        raw = synth_raw(19, groups, seed=8, v41=v41)
        res = P.run_spec(spec(base_settings()), raw, META, CW)
        rows, _ = P.run_influence(res)
        df = pd.DataFrame(rows)
        v1s = sorted(raw["V1"])
        for mid in ("org_M4", "org_M5"):
            sub = df[df["model_id"] == mid]
            self.assertEqual(len(sub), 19)
            self.assertTrue((sub["term"] == "NA").all())
            self.assertEqual(sorted(sub["deleted_V1"].astype(int)), v1s)


# ----------------------------------------------------------------------------
# Checker item 3: when dummy resolution succeeds but the fit later fails, the
# model_stats row still reports k and the number of industry dummies (spec §6).
# ----------------------------------------------------------------------------
class TestItem3CountsOnFailure(unittest.TestCase):
    def test_counts_reported_when_fit_fails_after_drops(self):
        groups = [10] * 11 + [600] * 5 + [20] * 3
        v41 = [3] * 11 + [1] * 5 + [2] * 3
        raw = synth_raw(19, groups, seed=8, v41=v41)
        res = P.run_spec(spec(base_settings()), raw, META, CW)
        for mid in ("org_M4", "org_M5"):
            s = stat(res, mid)
            self.assertEqual(s["status"], "failed")
            self.assertIn("no residual degrees of freedom", s["error"])
            self.assertEqual(s["k"], 19)                 # k known after the dummy drops
            self.assertEqual(s["n_industry_dummies"], 0)  # both dummies were dropped as collinear
            self.assertEqual(s["dropped_columns"], "IND_07(collinear);IND_59(collinear)")
            self.assertEqual(s["n"], 19)

    def test_counts_na_when_resolution_fails(self):
        # an empty estimation sample fails before any design is built: k and the
        # industry-dummy count have no meaning and stay NA.
        raw = synth_raw(6, [10] * 6, seed=1)
        raw.loc[:, "V289"] = 9  # make POP missing on every row -> empty org sample
        for v in C.POP_ITEMS:
            raw.loc[:, v] = 9
        res = P.run_spec(spec(base_settings()), raw, META, CW)
        s = stat(res, "org_base")
        self.assertEqual(s["status"], "failed")
        self.assertTrue(pd.isna(s["k"]))
        self.assertTrue(pd.isna(s["n_industry_dummies"]))


# ----------------------------------------------------------------------------
# Amended behaviour the repair prompt explicitly asks to cover: HC3 with a
# leverage-one row (OLS and WLS).
# ----------------------------------------------------------------------------
class TestHC3LeverageOne(unittest.TestCase):
    def _design(self, n=40, seed=2, singleton_at=5):
        rng = np.random.default_rng(seed)
        x1, x2 = rng.normal(size=n), rng.normal(size=n)
        y = 1 + 2 * x1 - x2 + rng.normal(size=n) * np.exp(0.5 * x1)
        single = np.zeros(n)
        single[singleton_at] = 1.0
        X = np.column_stack([np.ones(n), x1, x2, single])
        return X, y, ["(Intercept)", "x1", "x2", "IND_single"]

    def test_ols_leverage_one_contributes_zero(self):
        X, y, names = self._design()
        fit = fit_linear(X, y, names)
        self.assertEqual(fit["n_leverage_one"], 1)
        self.assertGreaterEqual(fit["leverage"][5], 1 - 1e-8)
        self.assertAlmostEqual(fit["resid"][5], 0.0, places=10)
        self.assertTrue(np.all(np.isfinite(fit["se_hc3"])))  # not NA despite the 0/0 term
        XtXi = np.linalg.inv(X.T @ X)
        h = np.einsum("ij,jk,ik->i", X, XtXi, X)
        e = y - X @ fit["beta"]
        ok = h < 1 - 1e-8
        meat = X[ok].T @ np.diag(e[ok] ** 2 / (1 - h[ok]) ** 2) @ X[ok]
        np.testing.assert_allclose(fit["se_hc3"], np.sqrt(np.diag(XtXi @ meat @ XtXi)), rtol=1e-10)
        ref = sm.OLS(y, X).fit()  # bread and the point estimates are unchanged
        np.testing.assert_allclose(fit["beta"], ref.params, rtol=1e-10)
        np.testing.assert_allclose(fit["se"], ref.bse, rtol=1e-10)

    def test_wls_same_threshold_on_weighted_design(self):
        X, y, names = self._design(n=60, seed=9, singleton_at=17)
        w = np.random.default_rng(3).uniform(0.3, 4.0, size=60)
        fit = fit_linear(X, y, names, weights=w)
        self.assertEqual(fit["n_leverage_one"], 1)
        self.assertTrue(np.all(np.isfinite(fit["se_hc3"])))
        sw = np.sqrt(w)
        Xw, ew = X * sw[:, None], (y - X @ fit["beta"]) * sw
        XtXi = np.linalg.inv(Xw.T @ Xw)
        h = np.einsum("ij,jk,ik->i", Xw, XtXi, Xw)
        self.assertGreaterEqual(h[17], 1 - 1e-8)
        ok = h < 1 - 1e-8
        meat = Xw[ok].T @ np.diag(ew[ok] ** 2 / (1 - h[ok]) ** 2) @ Xw[ok]
        np.testing.assert_allclose(fit["se_hc3"], np.sqrt(np.diag(XtXi @ meat @ XtXi)), rtol=1e-10)


# ----------------------------------------------------------------------------
# Amended behaviour the repair prompt explicitly asks to cover: the copy rule
# copies a source item only when that source is valid at the current level.
# ----------------------------------------------------------------------------
class TestCopyRuleValidity(unittest.TestCase):
    def test_gss_copy_only_from_valid_core(self):
        rows = [{"V79": np.nan, "V62": 0, "V97": 12},    # CORE 0 invalid under L0 -> no copy
                {"V79": np.nan, "V62": 995, "V97": 12},  # 995 invalid under L0, valid under L2
                {"V79": np.nan, "V62": 998, "V97": 12},  # declared missing never valid
                {"V79": np.nan, "V62": 7, "V97": 12},    # valid -> copy
                {"V79": 2, "V62": 0, "V97": 12}]         # V79 == 2: GSS = CORE; invalid CORE -> missing
        raw = raw_frame(rows)
        it0 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L0"))
        self.assertTrue(nan_eq(it0["V97"], [12, 12, 12, 7, np.nan]))
        it2 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L2"))
        self.assertTrue(nan_eq(it2["V97"], [12, 995, 12, 7, np.nan]))

    def test_manager_fallback_uses_validity(self):
        rows = [{"V114": 2, "V62": 0, "V97": 12, "V131": 5},    # CORE invalid under L0 -> GSS fallback
                {"V114": 2, "V62": 0, "V97": 0, "V131": 5}]     # both invalid under L0 -> missing
        raw = raw_frame(rows)
        it0 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L0"))
        self.assertTrue(nan_eq(it0["V131"], [12, np.nan]))


if __name__ == "__main__":
    unittest.main()
