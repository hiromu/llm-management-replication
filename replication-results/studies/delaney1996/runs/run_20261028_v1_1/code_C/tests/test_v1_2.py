"""Tests for the v1.2 repair round (checker items 1-3) plus the amended behaviour
that the round asked to be covered again: HC3 with a leverage-one row (A1) and
the validity used by the copy rule (A7).

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
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
from paperk7 import coding as C  # noqa: E402
from paperk7 import pipeline as P  # noqa: E402
from paperk7.regression import FitError, drop_collinear_dummies, fit_linear  # noqa: E402
from test_coding import META, base_settings, nan_eq, raw_frame  # noqa: E402
from test_v1_1 import CW, spec, stat, synth_raw  # noqa: E402

LN = math.log


# ----------------------------------------------------------------------------
# checker item 1: non-dummy degeneracy is reported as such whatever the row count;
# the residual-df check comes after the permitted dummy drops (A5, A10)
# ----------------------------------------------------------------------------
class TestItem1NonDummyReason(unittest.TestCase):
    def test_all_zero_non_dummy_with_few_rows(self):
        rng = np.random.default_rng(1)
        X = np.column_stack([np.ones(3), rng.normal(size=3), np.zeros(3), rng.normal(size=3), [1, 0, 0]])
        names = ["(Intercept)", "STAFF", "SERVICE", "TRAIN", "IND_01"]
        with self.assertRaises(FitError) as cm:
            drop_collinear_dummies(X, names, ["IND_01"])
        self.assertTrue(str(cm.exception).startswith("non-dummy column(s) all zero: SERVICE"), str(cm.exception))

    def test_collinear_non_dummy_with_few_rows(self):
        rng = np.random.default_rng(2)
        x = rng.normal(size=3)
        X = np.column_stack([np.ones(3), x, 2 * x, rng.normal(size=3), [1, 0, 0]])
        names = ["(Intercept)", "STAFF", "TRAIN", "INCENT", "IND_01"]
        with self.assertRaises(FitError) as cm:
            drop_collinear_dummies(X, names, ["IND_01"])
        msg = str(cm.exception)
        self.assertTrue(msg.startswith("non-dummy column(s) collinear: TRAIN"), msg)
        self.assertNotIn("no residual degrees of freedom", msg)

    def test_more_non_dummy_columns_than_rows_is_collinear_not_df(self):
        # 2 rows, 4 non-dummy columns: the non-dummy block is necessarily rank deficient and the
        # columns that do not raise the rank are reported as collinear, with the row count appended
        rng = np.random.default_rng(3)
        X = rng.normal(size=(2, 4))
        X[:, 0] = 1.0
        names = ["(Intercept)", "STAFF", "TRAIN", "INCENT"]
        with self.assertRaises(FitError) as cm:
            drop_collinear_dummies(X, names, [])
        msg = str(cm.exception)
        self.assertTrue(msg.startswith("non-dummy column(s) collinear: TRAIN,INCENT"), msg)
        self.assertIn("(n=2 rows, 4 non-dummy columns)", msg)

    def test_df_failure_only_after_permitted_drops(self):
        # full-rank non-dummy block, n = number of non-dummy columns, dummies collinear: the dummies are
        # dropped (recorded), then fit_linear reports the residual df
        rng = np.random.default_rng(4)
        n = 3
        X = np.column_stack([np.ones(n), rng.normal(size=n), rng.normal(size=n), [1, 0, 0], [0, 1, 1]])
        names = ["(Intercept)", "STAFF", "TRAIN", "IND_01", "IND_02"]
        Xk, kept, dropped = drop_collinear_dummies(X, names, ["IND_01", "IND_02"])
        self.assertEqual(kept, ["(Intercept)", "STAFF", "TRAIN"])
        self.assertEqual(dict(dropped), {"IND_01": "collinear", "IND_02": "collinear"})
        with self.assertRaises(FitError) as cm:
            fit_linear(Xk, rng.normal(size=n), kept)
        self.assertIn("no residual degrees of freedom", str(cm.exception))

    def test_run_spec_reports_non_dummy_reason_with_small_sample(self):
        # 10 rows, SERVICE all zero (V41 in {1, 3}); org_M5 has 19 non-dummy columns > n. The reason
        # must be the all-zero control, not the residual df.
        groups = [10] * 6 + [600] * 4
        v41 = [3] * 6 + [1] * 4
        raw = synth_raw(10, groups, seed=31, v41=v41)
        res = P.run_spec(spec(base_settings()), raw, META, CW)
        s = stat(res, "org_M5")
        self.assertEqual(s["status"], "failed")
        self.assertIn("non-dummy column(s) all zero: SERVICE", s["error"])
        self.assertNotIn("no residual degrees of freedom", s["error"])
        s = stat(res, "org_base")
        self.assertEqual(s["status"], "failed")
        self.assertIn("all zero: SERVICE", s["error"])

    def test_run_spec_collinear_reason_with_small_sample(self):
        # 12 valid rows, nothing all zero: org_M4 / org_M5 (19 non-dummy columns) fail as collinear
        groups = [10] * 7 + [600] * 5
        raw = synth_raw(12, groups, seed=32)
        res = P.run_spec(spec(base_settings()), raw, META, CW)
        for mid in ("org_M4", "org_M5"):
            s = stat(res, mid)
            self.assertEqual(s["status"], "failed")
            self.assertTrue(s["error"].startswith("FitError: non-dummy column(s) collinear:"), s["error"])
            self.assertIn("(n=12 rows, 19 non-dummy columns)", s["error"])

    def test_influence_refit_reports_non_dummy_reason(self):
        # n = 4 rows, 4 non-dummy columns + one dummy: deleting any row leaves 3 rows for 4 non-dummy
        # columns -> the refit fails as collinear (checker item 1 through pipeline.influence_rows)
        rng = np.random.default_rng(5)
        n = 4
        X = pd.DataFrame({"(Intercept)": 1.0, "STAFF": rng.normal(size=n), "TRAIN": rng.normal(size=n),
                          "LOGEMP": rng.normal(size=n)})
        y = pd.Series(rng.normal(size=n))
        # a 4-row, 4-column original fit has no df; build a fit on a bigger design to feed the routine
        X5 = pd.concat([X, X.iloc[[0]]], ignore_index=True)
        X5.loc[4, "STAFF"] += 1.0
        y5 = pd.concat([y, pd.Series([0.3])], ignore_index=True)
        fit = fit_linear(X5.values, y5.values, list(X5.columns))
        model = {"family": "org", "X": X, "y": y, "w": None, "dummies": [], "fit": fit, "names": list(X.columns),
                 "hrm": ["STAFF", "TRAIN"], "ints": [], "V1": pd.Series([1, 2, 3, 4]), "error": None}
        rows, failures = P.influence_rows("org_M2", model)
        df = pd.DataFrame(rows)
        self.assertEqual(len(df), 4)
        self.assertTrue((df["status"] == "failed").all())
        self.assertTrue(df["note"].str.startswith("FitError: non-dummy column(s) collinear:").all())
        self.assertTrue(df["note"].str.contains("n=3 rows, 4 non-dummy columns").all())
        self.assertEqual(len(failures), 4)


# ----------------------------------------------------------------------------
# checker item 2: one influence row per estimation-sample record when the original model failed
# ----------------------------------------------------------------------------
class TestItem2InfluenceRows(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # n = 19: both dummies collinear with PRODUCT/SERVICE and dropped; org_M4/org_M5 have k = 19 = n
        groups = [10] * 11 + [600] * 5 + [20] * 3
        v41 = [3] * 11 + [1] * 5 + [2] * 3
        cls.raw = synth_raw(19, groups, seed=8, v41=v41)
        cls.res = P.run_spec(spec(base_settings()), cls.raw, META, CW)

    def test_one_row_per_record_for_failed_origin_model(self):
        rows, failures = P.run_influence(self.res)
        df = pd.DataFrame(rows)
        v1s = sorted(self.raw["V1"])
        for mid in ("org_M4", "org_M5"):
            self.assertEqual(stat(self.res, mid)["status"], "failed")
            sub = df[df["model_id"] == mid]
            self.assertEqual(len(sub), 19)
            self.assertEqual(sorted(sub["deleted_V1"]), v1s)
            self.assertTrue(sub["deleted_V1"].notna().all())
            self.assertTrue(sub["term"].isna().all())
            self.assertTrue(sub[["estimate", "se", "p_upper", "p_two"]].isna().all().all())
            self.assertTrue((sub["status"] == "failed").all())
            self.assertTrue(sub["note"].str.startswith("original model failed: ").all())
        # exactly one failures entry per failed original model
        for mid in ("org_M4", "org_M5"):
            self.assertEqual(sum(1 for f in failures if f["stage"] == f"influence:{mid}"), 1)
        # successful models are unchanged: one ok row per record and term
        for mid in ("org_M2", "org_M3"):
            sub = df[df["model_id"] == mid]
            self.assertEqual(len(sub), 19 * len(set(sub["term"])))
            self.assertTrue(sub["term"].notna().all())
            self.assertTrue((sub["status"] == "ok").all())

    def test_empty_estimation_sample_gives_no_rows(self):
        model = {"family": "org", "fit": None, "hrm": P.A_TERMS, "ints": [], "V1": pd.Series([], dtype=float),
                 "error": "FitError: empty estimation sample"}
        rows, failures = P.influence_rows("org_M2", model)
        self.assertEqual(rows, [])
        self.assertEqual(len(failures), 1)
        self.assertEqual(failures[0]["stage"], "influence:org_M2")
        self.assertIn("empty estimation sample", failures[0]["error"])
        self.assertEqual(failures[0]["n_estimation_sample"], 0)
        # through run_influence with a model missing from the origin result
        res = P.SpecResult("O")
        rows, failures = P.run_influence(res)
        self.assertEqual(rows, [])
        self.assertEqual(len(failures), 8)
        self.assertTrue(all(f["stage"].startswith("influence:") for f in failures))

    def test_failed_deletion_is_one_row(self):
        # n = 5 = k + 1 with groups [0,1,1,2,2]: every deletion but the first fails -> one row each
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
        rows, failures = P.influence_rows("org_M2", model)
        df = pd.DataFrame(rows)
        self.assertEqual(len(df), 5)  # 1 ok row (one term) + 4 failed rows
        self.assertEqual(list(df["status"]), ["ok", "failed", "failed", "failed", "failed"])
        self.assertEqual(df["term"].iloc[0], "STAFF")
        self.assertTrue(df["term"].iloc[1:].isna().all())
        self.assertEqual(sorted(df["deleted_V1"]), [1, 2, 3, 4, 5])
        self.assertEqual(len(failures), 4)


# ----------------------------------------------------------------------------
# checker item 3: n, k and n_industry_dummies reported for failed models when known
# ----------------------------------------------------------------------------
class TestItem3FailedModelCounts(unittest.TestCase):
    def test_counts_reported_when_fit_fails_after_drops(self):
        groups = [10] * 11 + [600] * 5 + [20] * 3
        v41 = [3] * 11 + [1] * 5 + [2] * 3
        raw = synth_raw(19, groups, seed=8, v41=v41)
        res = P.run_spec(spec(base_settings()), raw, META, CW)
        for mid in ("org_M4", "org_M5"):
            s = stat(res, mid)
            self.assertEqual(s["status"], "failed")
            self.assertIn("no residual degrees of freedom", s["error"])
            self.assertEqual(s["n"], 19)
            self.assertEqual(s["k"], 19)  # 1 + 6 + 3 + 9 non-dummy columns, both dummies dropped
            self.assertEqual(s["n_industry_dummies"], 0)
            self.assertEqual(s["dropped_columns"], "IND_07(collinear);IND_59(collinear)")
            self.assertTrue(np.isnan(s["r2"]))
            self.assertTrue(np.isnan(s["n_leverage_one"]))
        fails = {f["stage"]: f for f in res.failures}
        self.assertEqual(fails["org_M5"]["k"], 19)
        self.assertEqual(fails["org_M5"]["n_industry_dummies"], 0)
        self.assertEqual(fails["org_M5"]["n"], 19)

    def test_counts_with_kept_dummies(self):
        # 20 rows: org_M5 has 19 non-dummy columns, so the first dummy raises the rank to 20 and the
        # second is collinear and dropped; the fit then fails on df with k = 20 and 1 dummy used
        groups = [10] * 12 + [600] * 5 + [20] * 3
        raw = synth_raw(20, groups, seed=21)
        res = P.run_spec(spec(base_settings()), raw, META, CW)
        s = stat(res, "org_M5")
        self.assertEqual(s["status"], "failed")
        self.assertIn("no residual degrees of freedom (n=20, k=20)", s["error"])
        self.assertEqual(s["n"], 20)
        self.assertEqual(s["k"], 20)
        self.assertEqual(s["n_industry_dummies"], 1)
        self.assertEqual(s["dropped_columns"], "IND_59(collinear)")
        s = stat(res, "org_M2")
        self.assertEqual(s["status"], "ok")
        self.assertEqual(s["k"], 18)
        self.assertEqual(s["n_industry_dummies"], 2)

    def test_counts_na_when_design_cannot_be_resolved(self):
        # a non-dummy column all zero: dummy resolution fails, k and n_industry_dummies are not defined
        groups = [10] * 6 + [600] * 4
        v41 = [3] * 6 + [1] * 4
        raw = synth_raw(10, groups, seed=31, v41=v41)
        res = P.run_spec(spec(base_settings()), raw, META, CW)
        s = stat(res, "org_base")
        self.assertEqual(s["status"], "failed")
        self.assertEqual(s["n"], 10)
        self.assertTrue(np.isnan(s["k"]))
        self.assertTrue(np.isnan(s["n_industry_dummies"]))
        # an empty sample: n = 0, counts NA
        raw2 = synth_raw(6, [10] * 6, seed=33)
        for v in C.POP_ITEMS:
            raw2[v] = 8.0
        res2 = P.run_spec(spec(base_settings()), raw2, META, CW)
        s = stat(res2, "org_base")
        self.assertEqual(s["status"], "failed")
        self.assertIn("empty estimation sample", s["error"])
        self.assertEqual(s["n"], 0)
        self.assertTrue(np.isnan(s["k"]))


# ----------------------------------------------------------------------------
# A1 again: HC3 with a leverage-one row, through the pipeline (OLS and WLS)
# ----------------------------------------------------------------------------
class TestHC3LeverageOne(unittest.TestCase):
    def _run(self, weights):
        groups = [10] * 14 + [600] * 7 + [20] * 1  # IND_07 has a single member -> leverage one
        raw = synth_raw(22, groups, seed=41)
        settings = base_settings(weights=weights)
        res = P.run_spec(spec(settings), raw, META, CW)
        return res

    def _check(self, res, model_id):
        s = stat(res, model_id)
        self.assertEqual(s["status"], "ok", s["error"])
        self.assertEqual(s["n_leverage_one"], 1)
        m = res.models[model_id]
        fit = m["fit"]
        X = m["X"][fit["names"]].values
        y = m["y"].values
        w = np.ones(len(y)) if m["w"] is None else m["w"].values
        sw = np.sqrt(w)
        Xw, ew = X * sw[:, None], (y - X @ fit["beta"]) * sw
        XtXi = np.linalg.inv(Xw.T @ Xw)
        h = np.einsum("ij,jk,ik->i", Xw, XtXi, Xw)
        j7 = fit["names"].index("IND_07")
        i7 = int(np.argmax(X[:, j7]))
        self.assertGreaterEqual(h[i7], 1 - 1e-8)
        self.assertAlmostEqual(fit["resid"][i7], 0.0, places=8)
        ok = h < 1 - 1e-8
        meat = Xw[ok].T @ np.diag(ew[ok] ** 2 / (1 - h[ok]) ** 2) @ Xw[ok]
        np.testing.assert_allclose(fit["se_hc3"], np.sqrt(np.diag(XtXi @ meat @ XtXi)), rtol=1e-9)
        coef = pd.DataFrame([r for r in res.coefficients if r["model_id"] == model_id])
        for col in ("se_hc3", "t_hc3", "p_two_hc3", "p_upper_hc3", "p_lower_hc3"):
            self.assertTrue(coef[col].notna().all(), col)
        # the conventional statistics are those of the plain (weighted) regression
        ref = sm.WLS(y, X, weights=w).fit()
        np.testing.assert_allclose(fit["beta"], ref.params, rtol=1e-10)
        np.testing.assert_allclose(fit["se"], ref.bse, rtol=1e-10)
        self.assertAlmostEqual(fit["r2"], ref.rsquared, places=12)
        # HC3 of the other coefficients equals HC3 on the design without the singleton row and its dummy
        keep = ok
        cols = [j for j in range(X.shape[1]) if j != j7]
        ref2 = sm.WLS(y[keep], X[keep][:, cols], weights=w[keep]).fit(cov_type="HC3")
        np.testing.assert_allclose(np.delete(fit["se_hc3"], j7), ref2.bse, rtol=1e-8)

    def test_ols(self):
        res = self._run("L0")
        self._check(res, "org_base")
        self._check(res, "org_M2")

    def test_wls(self):
        res = self._run("L1")
        self._check(res, "org_base")
        self._check(res, "org_M3")

    def test_influence_refits_keep_hc3_finite_with_leverage_one(self):
        # deleting another row keeps the singleton's leverage at one in the refit; the refit uses the
        # same rule and succeeds with finite HC3 (not reported, but it must not fail)
        res = self._run("L0")
        rows, failures = P.influence_rows("org_M2", res.models["org_M2"])
        self.assertEqual(failures, [])
        df = pd.DataFrame(rows)
        self.assertTrue((df["status"] == "ok").all())
        self.assertEqual(len(df), 22 * 6)
        # the deletion of the singleton drops its dummy and is flagged
        v1_single = int(res.models["org_M2"]["V1"].iloc[21])
        sub = df[df["deleted_V1"] == v1_single]
        self.assertTrue((sub["note"] == "dropped all-zero dummies: IND_07").all())


# ----------------------------------------------------------------------------
# A7 again: copy-rule validity, up to the STAFF index
# ----------------------------------------------------------------------------
class TestCopyRuleValidity(unittest.TestCase):
    def _raw(self):
        # each row: V79 blank (GSS = CORE only when CORE valid), V114 blank (manager copy)
        rows = [{"V79": np.nan, "V114": np.nan, "V62": 0, "V97": 12, "V131": 30},      # CORE invalid under L0/L2
                {"V79": np.nan, "V114": np.nan, "V62": 995, "V97": 12, "V131": 30},    # CORE valid only under L2
                {"V79": np.nan, "V114": np.nan, "V62": 996, "V97": 12, "V131": 30},    # never valid
                {"V79": np.nan, "V114": np.nan, "V62": 998, "V97": 12, "V131": 30},    # declared missing
                {"V79": np.nan, "V114": np.nan, "V62": 7, "V97": 12, "V131": 30},      # valid everywhere
                {"V79": 2, "V114": 2, "V62": 0, "V97": 12, "V131": 30},                # unconditional copies
                {"V79": np.nan, "V114": np.nan, "V62": 0, "V97": 997, "V131": 30}]     # both invalid under L0
        return raw_frame(rows)

    def test_items_after_copy_by_level(self):
        raw = self._raw()
        it0 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L0"))
        self.assertTrue(nan_eq(it0["V62"], [np.nan, np.nan, np.nan, np.nan, 7, np.nan, np.nan]))
        self.assertTrue(nan_eq(it0["V97"], [12, 12, 12, 12, 7, np.nan, np.nan]))
        self.assertTrue(nan_eq(it0["V131"], [12, 12, 12, 12, 7, np.nan, np.nan]))
        it2 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L2"))
        self.assertTrue(nan_eq(it2["V97"], [12, 995, 12, 12, 7, np.nan, np.nan]))
        self.assertTrue(nan_eq(it2["V131"], [12, 995, 12, 12, 7, np.nan, np.nan]))
        it1 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L1"))
        self.assertTrue(nan_eq(it1["V97"], [0, 12, 12, 12, 7, 0, 0]))
        self.assertTrue(nan_eq(it1["V131"], [0, 12, 12, 12, 7, 0, 0]))
        # without the copy rule (item_rule L0) nothing is copied
        itn = C.build_raw_items(raw, META, base_settings(item_rule="L0", staff_coding="L0"))
        self.assertTrue(nan_eq(itn["V97"], [12, 12, 12, 12, 12, 12, np.nan]))
        self.assertTrue(nan_eq(itn["V131"], [30] * 7))

    def test_staff_index_reflects_validity(self):
        # the transformed items are plain logs of the post-copy valid counts; the index is the mean
        # of the standardized valid items; a row with no valid item has a missing STAFF index
        raw = self._raw()
        for v in C.POP_ITEMS:
            raw[v] = 2.0
        raw["V43"] = 10.0
        f, staff_items, _ = C.build_base_frame(raw, META, CW, base_settings(item_rule="L2", staff_coding="L0"))
        expect97 = [LN(12), LN(12), LN(12), LN(12), LN(7), np.nan, np.nan]
        self.assertTrue(nan_eq(staff_items["V97"], expect97))
        self.assertTrue(nan_eq(staff_items["V131"], expect97))
        self.assertTrue(nan_eq(staff_items["V62"], [np.nan] * 4 + [LN(7)] + [np.nan] * 2))
        idx, z, info = C.standardize_and_index(staff_items, "L2")
        self.assertTrue(idx[:5].notna().all())
        self.assertTrue(idx[5:].isna().all())
        self.assertEqual(info["V97"]["n"], 5)
        np.testing.assert_allclose(idx[:5].values, z.iloc[:5].mean(axis=1, skipna=True).values)


if __name__ == "__main__":
    unittest.main()
