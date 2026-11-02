"""Tests for the v1.2 repair round.

Covers the three checker items addressed in v1.2, plus the two behaviours the
repair prompt names explicitly: HC3 with a leverage-one row and copy-rule
validity. The underlying amendment is v1.1 (A1-A10); these tests pin the
amended reading of A5/A10 (df check after the permitted dummy drops), A6 (one
influence row per record when the original model fails) and section 6 (k and
the industry-dummy count reported even on a failed fit).

Run as a script: python code/tests/test_v1_2.py
"""
import math
import os
import sys
import unittest

import numpy as np
import pandas as pd

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
# Checker item 1: A5/A10 -- dummy collinearity is resolved, and a degenerate
# non-dummy column reported with its reason, before any residual-df check. A
# rank-deficient non-dummy design is never reported as a residual-df error at
# the drop stage, including when there are no more rows than non-dummy columns.
# ----------------------------------------------------------------------------
class TestItem1DfOrder(unittest.TestCase):
    def test_all_zero_non_dummy_reported_not_df(self):
        n = 3  # fewer rows than the four non-dummy columns
        X = np.column_stack([np.ones(n), np.array([1.0, 2.0, 3.0]), np.zeros(n), np.array([2.0, 4.0, 6.0])])
        names = ["(Intercept)", "STAFF", "SERVICE", "TRAIN"]
        with self.assertRaises(FitError) as cm:
            drop_collinear_dummies(X, names, [])  # no droppable dummies
        self.assertNotIn("no residual degrees of freedom", str(cm.exception))
        self.assertIn("all zero: SERVICE", str(cm.exception))

    def test_collinear_non_dummy_reported_not_df(self):
        # n == number of non-dummy columns, rank deficient by a genuine copy
        x = np.array([1.0, 2.0, 3.0, 4.0])
        X = np.column_stack([np.ones(4), x, 2.0 * x, np.array([0.0, 1.0, 0.0, 1.0])])
        names = ["(Intercept)", "STAFF", "TRAIN", "GRIEV"]
        with self.assertRaises(FitError) as cm:
            drop_collinear_dummies(X, names, [])
        self.assertNotIn("no residual degrees of freedom", str(cm.exception))
        self.assertIn("collinear: TRAIN", str(cm.exception))

    def test_too_few_rows_without_degenerate_column_is_collinear(self):
        # two rows, three independent-looking non-dummy columns: the excess one
        # cannot raise the rank and is reported as collinear, not residual-df.
        X = np.column_stack([np.ones(2), np.array([1.0, 2.0]), np.array([3.0, 5.0])])
        names = ["(Intercept)", "STAFF", "TRAIN"]
        with self.assertRaises(FitError) as cm:
            drop_collinear_dummies(X, names, [])
        self.assertNotIn("no residual degrees of freedom", str(cm.exception))
        self.assertIn("collinear: TRAIN", str(cm.exception))

    def test_full_rank_base_defers_df_check_to_fit(self):
        # full-rank non-dummy base but k == n after resolution: the resolution
        # succeeds and the df failure is raised by fit_linear, not the drop step.
        n = 3
        X = np.column_stack([np.ones(n), np.array([0.0, 1.0, 2.0]), np.array([0.0, 0.0, 1.0])])
        names = ["(Intercept)", "STAFF", "TRAIN"]
        Xk, names_k, dropped = drop_collinear_dummies(X, names, [])  # no raise
        self.assertEqual(names_k, names)
        self.assertEqual(dropped, [])
        with self.assertRaises(FitError) as cm:
            fit_linear(Xk, np.array([1.0, 2.0, 3.0]), names_k)
        self.assertIn("no residual degrees of freedom", str(cm.exception))


# ----------------------------------------------------------------------------
# Checker item 2: A6 -- when the influence-diagnostic original model fails,
# influence.csv gets exactly one row per estimation-sample record (term NA),
# never one per term, and no row with a missing deleted_V1 for an empty sample.
# ----------------------------------------------------------------------------
class TestItem2InfluenceFailedOrigin(unittest.TestCase):
    def test_one_row_per_record_term_na(self):
        model = {"family": "org", "fit": None, "hrm": ["STAFF", "TRAIN"], "ints": ["TRAIN_x_STAFF"],
                 "V1": pd.Series([11.0, 12.0, 13.0]), "error": "FitError: no residual degrees of freedom"}
        rows, failures = P.influence_rows("org_M4", model, spec_id="O")
        df = pd.DataFrame(rows)
        self.assertEqual(len(df), 3)  # one per record, not 3 x 3 terms
        self.assertEqual(sorted(df["deleted_V1"].tolist()), [11.0, 12.0, 13.0])
        self.assertTrue((df["term"] == "NA").all())
        self.assertTrue((df["status"] == "failed").all())
        self.assertTrue(df["note"].str.startswith("original model failed:").all())
        self.assertTrue(df["estimate"].isna().all())
        self.assertEqual(len(failures), 1)
        self.assertEqual(failures[0]["stage"], "influence:org_M4")

    def test_empty_sample_emits_no_rows(self):
        model = {"family": "org", "fit": None, "hrm": ["STAFF"], "ints": [],
                 "V1": pd.Series([], dtype=float), "error": "empty estimation sample"}
        rows, failures = P.influence_rows("org_M2", model, spec_id="O")
        self.assertEqual(rows, [])  # no record, so no influence row (A6)
        self.assertEqual(len(failures), 1)

    def test_run_influence_missing_model_has_no_rows(self):
        res = P.SpecResult("O")  # no models at all
        rows, failures = P.run_influence(res)
        self.assertEqual(rows, [])
        self.assertEqual(len(failures), 8)  # one per influence model, all empty

    def test_failed_origin_through_run_spec(self):
        # n = 19: both industry dummies collinear with PRODUCT/SERVICE and dropped,
        # so org_M4/org_M5 have k = 19 = n and fail on df; influence lists one row
        # per record with term NA.
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
            self.assertEqual(sorted(sub["deleted_V1"].unique()), v1s)
            self.assertTrue((sub["term"] == "NA").all())
            self.assertTrue((sub["status"] == "failed").all())

    def test_per_deletion_failure_still_one_row_per_term(self):
        # A single failing deletion inside an otherwise ok model still records one
        # row per HRM/interaction term (section 7), unchanged by item 2.
        rng = np.random.default_rng(2)
        n = 5
        g = np.array([0, 1, 1, 2, 2])
        X = pd.DataFrame({"(Intercept)": 1.0, "STAFF": rng.normal(size=n),
                          "IND_g1": (g == 1).astype(float), "IND_g2": (g == 2).astype(float)})
        y = pd.Series(rng.normal(size=n))
        fit = fit_linear(X.values, y.values, list(X.columns))
        model = {"family": "org", "X": X, "y": y, "w": None, "dummies": ["IND_g1", "IND_g2"], "fit": fit,
                 "names": list(X.columns), "hrm": ["STAFF"], "ints": [], "V1": pd.Series(np.arange(1, 6)),
                 "error": None}
        rows, _ = P.influence_rows("org_M2", model)
        df = pd.DataFrame(rows)
        failed = df[df["status"] == "failed"]
        # four deletions fail, each with one row for the single HRM term STAFF
        self.assertEqual(len(failed), 4)
        self.assertTrue((failed["term"] == "STAFF").all())


# ----------------------------------------------------------------------------
# Checker item 3: section 6 -- k and the industry-dummy count are reported even
# when the fit fails after a successful dummy resolution.
# ----------------------------------------------------------------------------
class TestItem3Counts(unittest.TestCase):
    def test_counts_reported_when_fit_fails_on_df(self):
        groups = [10] * 11 + [600] * 5 + [20] * 3
        v41 = [3] * 11 + [1] * 5 + [2] * 3
        raw = synth_raw(19, groups, seed=8, v41=v41)
        res = P.run_spec(spec(base_settings()), raw, META, CW)
        for mid in ("org_M4", "org_M5"):
            s = stat(res, mid)
            self.assertEqual(s["status"], "failed")
            self.assertIn("no residual degrees of freedom", s["error"])
            self.assertEqual(s["k"], 19)                 # known from the resolved names
            self.assertEqual(s["n_industry_dummies"], 0)  # both dummies dropped
            self.assertEqual(s["dropped_columns"], "IND_07(collinear);IND_59(collinear)")
            self.assertEqual(s["n"], 19)

    def test_counts_na_when_resolution_fails(self):
        # An all-zero non-dummy column makes resolution fail, so no design
        # survives and k / n_industry_dummies stay NA.
        groups = [10] * 20 + [600] * 10 + [20] * 10
        raw = synth_raw(40, groups, seed=5)
        raw.loc[:, "V41"] = 3  # PRODUCT and SERVICE both all-zero (omitted category)
        res = P.run_spec(spec(base_settings()), raw, META, CW)
        s = stat(res, "org_base")
        self.assertEqual(s["status"], "failed")
        self.assertIn("all zero", s["error"])
        self.assertTrue(pd.isna(s["k"]))
        self.assertTrue(pd.isna(s["n_industry_dummies"]))

    def test_counts_na_for_empty_sample(self):
        model = {"family": "org", "fit": None}
        row = P._stat_row("O", "org", "org_base", "failed", "FitError: empty estimation sample", n=0)
        self.assertEqual(row["n"], 0)
        self.assertTrue(pd.isna(row["k"]))
        self.assertTrue(pd.isna(row["n_industry_dummies"]))


# ----------------------------------------------------------------------------
# HC3 with a leverage-one row (named in the repair prompt): a row fitted exactly
# contributes exactly zero to the meat and HC3 stays finite.
# ----------------------------------------------------------------------------
class TestHC3LeverageOne(unittest.TestCase):
    def _design(self, n=30, seed=7, singleton_at=4):
        rng = np.random.default_rng(seed)
        x1, x2 = rng.normal(size=n), rng.normal(size=n)
        y = 1.0 + 2.0 * x1 - x2 + rng.normal(size=n)
        single = np.zeros(n)
        single[singleton_at] = 1.0  # the only member of its group -> leverage one
        X = np.column_stack([np.ones(n), x1, x2, single])
        return X, y, ["(Intercept)", "x1", "x2", "IND_single"]

    def test_leverage_one_contributes_zero_ols(self):
        X, y, names = self._design()
        fit = fit_linear(X, y, names)
        self.assertEqual(fit["n_leverage_one"], 1)
        self.assertGreaterEqual(fit["leverage"][4], 1 - 1e-8)
        self.assertAlmostEqual(fit["resid"][4], 0.0, places=10)
        for key in ("se_hc3", "t_hc3", "p_two_hc3", "p_upper_hc3", "p_lower_hc3"):
            self.assertTrue(np.all(np.isfinite(fit[key])), key)
        XtXi = np.linalg.inv(X.T @ X)
        h = np.einsum("ij,jk,ik->i", X, XtXi, X)
        e = y - X @ fit["beta"]
        ok = h < 1 - 1e-8
        meat = X[ok].T @ np.diag(e[ok] ** 2 / (1 - h[ok]) ** 2) @ X[ok]
        np.testing.assert_allclose(fit["se_hc3"], np.sqrt(np.diag(XtXi @ meat @ XtXi)), rtol=1e-10)

    def test_leverage_one_contributes_zero_wls(self):
        X, y, names = self._design(n=40, seed=11, singleton_at=9)
        w = np.random.default_rng(1).uniform(0.4, 3.0, size=40)
        fit = fit_linear(X, y, names, weights=w)
        self.assertEqual(fit["n_leverage_one"], 1)
        self.assertTrue(np.all(np.isfinite(fit["se_hc3"])))


# ----------------------------------------------------------------------------
# Copy-rule validity (named in the repair prompt): a source item is copied only
# after it has passed the exclusions that apply at the current axis level (A7).
# ----------------------------------------------------------------------------
class TestCopyRuleValidity(unittest.TestCase):
    def test_gss_copy_only_from_valid_core(self):
        rows = [{"V79": np.nan, "V62": 0, "V97": 12},    # 0 invalid under L0 -> keep GSS
                {"V79": np.nan, "V62": 995, "V97": 12},  # 995 invalid L0, valid L2
                {"V79": np.nan, "V62": 996, "V97": 12},  # 996 never valid
                {"V79": np.nan, "V62": 7, "V97": 12},    # valid -> copy core
                {"V79": 2, "V62": 0, "V97": 12}]         # V79==2: GSS=CORE (invalid -> missing)
        raw = raw_frame(rows)
        it0 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L0"))
        self.assertTrue(nan_eq(it0["V97"], [12, 12, 12, 7, np.nan]))
        it2 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L2"))
        self.assertTrue(nan_eq(it2["V97"], [12, 995, 12, 7, np.nan]))
        it1 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L1"))
        self.assertTrue(nan_eq(it1["V97"], [0, 12, 12, 7, 0]))  # 0 valid under L1 -> copied

    def test_manager_fallback_follows_validity(self):
        rows = [{"V114": 2, "V62": 0, "V97": 12, "V131": 5},    # CORE 0 invalid L0 -> GSS fallback
                {"V114": 2, "V62": 995, "V97": 12, "V131": 5},  # 995 fallback L0, CORE L2
                {"V114": 2, "V62": 0, "V97": 0, "V131": 5}]     # both invalid L0 -> missing
        raw = raw_frame(rows)
        it0 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L0"))
        self.assertTrue(nan_eq(it0["V131"], [12, 12, np.nan]))
        it2 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L2"))
        self.assertTrue(nan_eq(it2["V131"], [12, 995, np.nan]))


if __name__ == "__main__":
    unittest.main()
