"""Tests for the v1.1 amendment (A1-A10) and the checker items.

Run as a script: python code/tests/test_v1_1.py
"""
import copy
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
from paperk7.regression import FitError, drop_collinear_dummies, fit_linear, nested_f  # noqa: E402
from test_coding import META, base_settings, nan_eq, raw_frame  # noqa: E402

LN = math.log
CW = {10: ["01"], 600: ["59"], 20: ["07"], 122: []}


def synth_raw(n, groups, seed=0, v41=None, v17=None):
    """A fully valid synthetic raw frame (every variable valid on every row)."""
    rng = np.random.default_rng(seed)
    rows = []
    for i in range(n):
        # V8 = 2 (non-profit) on the first two rows so that NONPROF is not all zero; the market
        # family therefore holds rows 2..n-1
        r = {"V1": 1000 + i, "V3": 1, "V8": 2 if i < 2 else 1, "V9": 4, "V16": int(rng.integers(1900, 1985)),
             "V17": int(rng.integers(1, 3)) if v17 is None else v17[i], "V21": 2,
             "V23": int(rng.integers(5, 200)), "V32": int(rng.integers(0, 50)),
             "V41": int(rng.integers(1, 4)) if v41 is None else v41[i], "V43": groups[i], "V79": 1, "V114": 1,
             "V115": int(rng.integers(1, 5)), "V145": 1, "V157": int(rng.integers(1, 50)),
             "V172": int(rng.integers(1, 4)), "V220": int(rng.integers(1, 4)), "V233": int(rng.integers(1, 4)),
             "V261": int(rng.integers(1, 10)), "V270": int(rng.integers(1, 3)), "V328": int(rng.integers(1, 5)),
             "NEWTOTAL": int(rng.integers(5, 250)), "WEIGHT": float(rng.uniform(0.5, 2.0))}
        for v in C.POP_ITEMS + C.PMP_ITEMS:
            r[v] = int(rng.integers(1, 5))
        for v in C.STAFF_ITEMS:
            r[v] = int(rng.integers(1, 60))
        for v in C.INCENT_ITEMS:
            r[v] = int(rng.integers(1, 4))
        for v in C.ILM_ITEMS:
            r[v] = int(rng.integers(1, 3))
        for v in C.DECENT_LARGER + C.DECENT_INDEP:
            r[v] = int(rng.integers(1, 6))
        rows.append(r)
    return raw_frame(rows)


def spec(settings, spec_id="O", check=None):
    s = {"spec_id": spec_id, "type": "origin", "settings": settings}
    if check:
        s["check"] = check
    return s


def stat(res, model_id):
    return [r for r in res.model_stats if r["model_id"] == model_id][0]


# ----------------------------------------------------------------------------
# A1: HC3 with leverage-one rows
# ----------------------------------------------------------------------------
class TestA1HC3(unittest.TestCase):
    def _design(self, n=40, seed=2, singleton_at=5):
        rng = np.random.default_rng(seed)
        x1, x2 = rng.normal(size=n), rng.normal(size=n)
        y = 1 + 2 * x1 - x2 + rng.normal(size=n) * np.exp(0.5 * x1)
        single = np.zeros(n)
        single[singleton_at] = 1.0
        X = np.column_stack([np.ones(n), x1, x2, single])
        return X, y, ["(Intercept)", "x1", "x2", "IND_single"]

    def test_ols_leverage_one_row_contributes_zero(self):
        X, y, names = self._design()
        fit = fit_linear(X, y, names)
        self.assertEqual(fit["n_leverage_one"], 1)
        self.assertGreaterEqual(fit["leverage"][5], 1 - 1e-8)
        self.assertAlmostEqual(fit["resid"][5], 0.0, places=10)
        for key in ("se_hc3", "t_hc3", "p_two_hc3", "p_upper_hc3", "p_lower_hc3"):
            self.assertTrue(np.all(np.isfinite(fit[key])), key)
        # explicit formula with the leverage-one row excluded from the meat
        XtXi = np.linalg.inv(X.T @ X)
        h = np.einsum("ij,jk,ik->i", X, XtXi, X)
        e = y - X @ fit["beta"]
        ok = h < 1 - 1e-8
        meat = X[ok].T @ np.diag(e[ok] ** 2 / (1 - h[ok]) ** 2) @ X[ok]
        np.testing.assert_allclose(fit["se_hc3"], np.sqrt(np.diag(XtXi @ meat @ XtXi)), rtol=1e-10)
        # bread and every other statistic unchanged
        ref = sm.OLS(y, X).fit()
        np.testing.assert_allclose(fit["beta"], ref.params, rtol=1e-10)
        np.testing.assert_allclose(fit["se"], ref.bse, rtol=1e-10)
        self.assertAlmostEqual(fit["r2"], ref.rsquared, places=12)
        self.assertEqual(fit["df"], int(ref.df_resid))
        # the HC3 SEs of the other coefficients equal HC3 on the design without the
        # singleton row and its dummy (that row is fitted exactly and carries no information)
        keep = ok
        ref2 = sm.OLS(y[keep], X[keep][:, :3]).fit(cov_type="HC3")
        np.testing.assert_allclose(fit["se_hc3"][:3], ref2.bse, rtol=1e-8)

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
        ref = sm.WLS(y, X, weights=w).fit()
        np.testing.assert_allclose(fit["se"], ref.bse, rtol=1e-10)

    def test_no_leverage_one_rows_unchanged(self):
        X, y, names = self._design()
        X = X[:, :3]
        fit = fit_linear(X, y, names[:3])
        self.assertEqual(fit["n_leverage_one"], 0)
        ref = sm.OLS(y, X).fit(cov_type="HC3")
        np.testing.assert_allclose(fit["se_hc3"], ref.bse, rtol=1e-10)

    def test_model_stats_column_and_influence_refits(self):
        # the pipeline reports n_leverage_one per model and HC3 for every coefficient
        groups = [10] * 12 + [600] * 5 + [20] * 1
        raw = synth_raw(18, groups, seed=5)
        res = P.run_spec(spec(base_settings()), raw, META, CW)
        s = stat(res, "org_base")
        self.assertEqual(s["status"], "ok")
        self.assertEqual(s["n_leverage_one"], 1)  # IND_07 has a single member
        coef = pd.DataFrame([r for r in res.coefficients if r["model_id"] == "org_base"])
        self.assertTrue(coef["se_hc3"].notna().all())
        self.assertTrue(coef["p_two_hc3"].notna().all())
        self.assertIn("n_leverage_one", s)


# ----------------------------------------------------------------------------
# A2 / A9: precedence of spec-level assignments over metadata declarations; STAFF codes
# ----------------------------------------------------------------------------
class TestA2A9Codes(unittest.TestCase):
    def setUp(self):
        self.meta = copy.deepcopy(META)
        for v in C.STAFF_ITEMS:  # declared range covering 995
            self.meta[v] = {"name": v, "declared_missing_values": [998, 999],
                            "declared_missing_ranges": [{"low": 990, "high": "HI"}]}
        self.meta["V157"]["declared_missing_values"] = [99996, 99998, 99999]
        self.meta["V261"]["declared_missing_values"] = [96, 98, 99]

    def test_staff_995_kept_under_L2_despite_declared_range(self):
        raw = raw_frame([{"V62": 995}, {"V62": 996}, {"V62": 997}, {"V62": 998}, {"V62": 999}, {"V62": 0}, {"V62": 3}])
        for lvl, expect in {"L0": [np.nan, np.nan, np.nan, np.nan, np.nan, np.nan, LN(3)],
                            "L1": [np.nan, np.nan, np.nan, np.nan, np.nan, 0.0, LN(4)],
                            "L2": [LN(995), np.nan, np.nan, np.nan, np.nan, np.nan, LN(3)]}.items():
            items = C.build_raw_items(raw, self.meta, base_settings(staff_coding=lvl))
            st = C.build_staff_items(items, lvl)
            self.assertTrue(nan_eq(st["V62"], expect), (lvl, list(st["V62"])))
        # with the plain metadata (995 declared as a value) the same holds
        items = C.build_raw_items(raw, META, base_settings(staff_coding="L2"))
        self.assertAlmostEqual(C.build_staff_items(items, "L2")["V62"][0], LN(995))

    def test_staff_996_is_missing_even_if_not_declared(self):
        meta = copy.deepcopy(META)
        for v in C.STAFF_ITEMS:
            meta[v]["declared_missing_values"] = []
        raw = raw_frame([{"V62": 996}, {"V62": 997}, {"V62": 995}])
        for lvl in ("L0", "L1", "L2"):
            items = C.build_raw_items(raw, meta, base_settings(staff_coding=lvl))
            self.assertTrue(pd.isna(items["V62"][0]), lvl)
            self.assertTrue(pd.isna(items["V62"][1]), lvl)
        self.assertEqual(C.build_raw_items(raw, meta, base_settings(staff_coding="L2"))["V62"][2], 995)

    def test_v157_top_code_recoded_despite_declaration(self):
        raw = raw_frame([{"V145": 1, "V157": 99996, "V172": 1}, {"V145": 1, "V157": 99998, "V172": 1}])
        t = C.build_train_items(raw, self.meta, base_settings())
        self.assertAlmostEqual(t["V157"][0], LN(100000))
        self.assertTrue(pd.isna(t["V157"][1]))
        t = C.build_train_items(raw, self.meta, base_settings(train_log="L2"))
        self.assertEqual(t["V157"][0], 100000)

    def test_v261_top_code_recoded_despite_declaration(self):
        raw = raw_frame([{"V261": 96}, {"V261": 98}, {"V261": 4}])
        self.assertTrue(nan_eq(C.build_vhier(raw, self.meta, base_settings()), [LN(100), np.nan, LN(4)]))
        self.assertTrue(nan_eq(C.build_vhier(raw, self.meta, base_settings(hierarchy="L2")), [100, np.nan, 4]))
        self.assertTrue(nan_eq(C.build_vhier(raw, self.meta, base_settings(hierarchy="L1")), [np.nan, np.nan, LN(4)]))
        chk = C.build_vhier(raw, self.meta, base_settings(), check="hierarchy_log10")
        self.assertTrue(nan_eq(chk, [2.0, np.nan, math.log10(4)]))

    def test_a3_log10_is_log_of_recoded_count(self):
        raw = raw_frame([{"V261": 5}, {"V261": 96}, {"V261": 1}])
        chk = C.build_vhier(raw, META, base_settings(), check="hierarchy_log10")
        l0 = C.build_vhier(raw, META, base_settings())
        np.testing.assert_allclose(chk.values, l0.values / LN(10))
        self.assertTrue(nan_eq(chk, [math.log10(5), 2.0, 0.0]))

    def test_declared_range_open_end_strings(self):
        meta = {"X": {"name": "X", "declared_missing_values": [], "declared_missing_ranges": [{"low": 3, "high": "HI"}]},
                "Y": {"name": "Y", "declared_missing_values": [], "declared_missing_ranges": [{"low": "LO", "high": 0}]}}
        self.assertTrue(nan_eq(C.apply_missing(pd.Series([1, 2, 3, 100]), meta, "X"), [1, 2, np.nan, np.nan]))
        self.assertTrue(nan_eq(C.apply_missing(pd.Series([-5, 0, 1]), meta, "Y"), [np.nan, np.nan, 1]))
        self.assertTrue(nan_eq(C.apply_missing(pd.Series([1, 3, 5]), meta, "X", keep=[5]), [1, np.nan, 5]))


# ----------------------------------------------------------------------------
# A4 / A9: system-missing routing and identifier inputs
# ----------------------------------------------------------------------------
class TestA4Routing(unittest.TestCase):
    def test_v17_missing_subsid_and_decent(self):
        rows = [{"V17": np.nan, "V21": 2, **{v: 1 for v in C.DECENT_LARGER + C.DECENT_INDEP}},
                {"V17": 2, "V21": 2, **{v: 1 for v in C.DECENT_INDEP}},  # checker 6: V17 == 2 wins over V21 == 2
                {"V17": 1, "V21": 2, **{v: 1 for v in C.DECENT_LARGER}},
                {"V17": 1, "V21": 1}, {"V17": 1, "V21": 3}, {"V17": 1, "V21": np.nan}]
        raw = raw_frame(rows)
        c0 = C.build_controls(raw, META, base_settings())
        c1 = C.build_controls(raw, META, base_settings(subsidiary="L1"))
        c2 = C.build_controls(raw, META, base_settings(subsidiary="L2"))
        self.assertTrue(nan_eq(c0["SUBSID"], [np.nan, 0, 1, 1, 1, 1]))
        self.assertTrue(nan_eq(c1["SUBSID"], [np.nan, 0, 1, 0, 0, np.nan]))
        self.assertTrue(nan_eq(c2["SUBSID"], [np.nan, 0, 1, 1, 1, np.nan]))
        items = C.build_raw_items(raw, META, base_settings())
        d = C.build_decent(items, raw, base_settings(), meta=META)
        self.assertTrue(pd.isna(d[0]))
        self.assertEqual(d[1], 3.0)  # independent: V279.. code 1 -> 3 under L0 map
        self.assertEqual(d[2], 3.0)

    def test_v43_missing_industry(self):
        raw = raw_frame([{"V43": np.nan}, {"V43": 122}, {"V43": 555}, {"V43": 10}])
        g0 = C.build_industry(raw, CW, base_settings(), meta=META)
        self.assertTrue(pd.isna(g0[0]))
        self.assertEqual(list(g0[1:]), ["UNCL", "UNCL", "01"])  # empty field / no entry -> UNCL only when V43 present
        g1 = C.build_industry(raw, CW, base_settings(industry="L1"), meta=META)
        self.assertTrue(g1[:3].isna().all())
        self.assertEqual(g1[3], "01")

    def test_weight_follows_metadata(self):
        meta = copy.deepcopy(META)
        meta["WEIGHT"]["declared_missing_values"] = [0, 999]
        raw = raw_frame([{"WEIGHT": 0}, {"WEIGHT": 999}, {"WEIGHT": -1}, {"WEIGHT": 1.5}, {}])
        raw["V43"] = 10.0
        f, _, _ = C.build_base_frame(raw, meta, CW, base_settings(weights="L1"))
        self.assertTrue(nan_eq(f["WEIGHT"], [np.nan, np.nan, np.nan, 1.5, np.nan]))
        # the row is excluded from every sample under weights L1
        self.assertNotIn("WEIGHT", P.required_vars("org", [], base_settings()))
        self.assertIn("WEIGHT", P.required_vars("org", [], base_settings(weights="L1")))

    def test_v8_follows_metadata(self):
        meta = copy.deepcopy(META)
        meta["V8"] = {"name": "V8", "declared_missing_values": [9], "declared_missing_ranges": []}
        raw = raw_frame([{"V8": 1}, {"V8": 2}, {"V8": 9}, {}])
        raw["V43"] = 10.0
        c = C.build_controls(raw, meta, base_settings())
        self.assertTrue(nan_eq(c["NONPROF"], [0, 1, np.nan, np.nan]))
        f, _, _ = C.build_base_frame(raw, meta, CW, base_settings())
        self.assertEqual(list(P.family_filter(f, "mkt", base_settings())), [True, False, False, False])


# ----------------------------------------------------------------------------
# A7: validity used by the copy rule
# ----------------------------------------------------------------------------
class TestA7CopyValidity(unittest.TestCase):
    def test_gss_copy_requires_valid_core_at_level(self):
        rows = [{"V79": np.nan, "V62": 0, "V97": 12},      # 0 invalid under L0 -> no copy
                {"V79": np.nan, "V62": 995, "V97": 12},    # 995 invalid under L0, valid under L2
                {"V79": np.nan, "V62": 996, "V97": 12},    # 996 never valid
                {"V79": np.nan, "V62": 998, "V97": 12},    # declared missing never valid
                {"V79": np.nan, "V62": 7, "V97": 12},      # valid -> copy
                {"V79": 2, "V62": 0, "V97": 12}]           # V79 == 2: GSS = CORE (invalid -> missing)
        raw = raw_frame(rows)
        it0 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L0"))
        self.assertTrue(nan_eq(it0["V97"], [12, 12, 12, 12, 7, np.nan]))
        it2 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L2"))
        self.assertTrue(nan_eq(it2["V97"], [12, 995, 12, 12, 7, np.nan]))
        it1 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L1"))
        self.assertTrue(nan_eq(it1["V97"], [0, 12, 12, 12, 7, 0]))  # 0 is a valid count under L1
        # the copied values are exactly what the transform logs
        st = C.build_staff_items(it0, "L0")
        self.assertTrue(nan_eq(st["V97"], [LN(12), LN(12), LN(12), LN(12), LN(7), np.nan]))

    def test_manager_fallback_uses_validity(self):
        rows = [{"V114": 2, "V62": 0, "V97": 12, "V131": 5},     # CORE 0 invalid under L0 -> GSS fallback
                {"V114": 2, "V62": 998, "V97": 12, "V131": 5},   # declared missing -> GSS fallback
                {"V114": 2, "V62": 995, "V97": 12, "V131": 5},   # 995: fallback under L0, CORE under L2
                {"V114": 2, "V62": 0, "V97": 0, "V131": 5},      # both invalid under L0 -> missing
                {"V114": np.nan, "V62": 9, "V97": 12, "V131": 5}]
        raw = raw_frame(rows)
        it0 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L0"))
        self.assertTrue(nan_eq(it0["V131"], [12, 12, 12, np.nan, 9]))
        it2 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L2"))
        self.assertTrue(nan_eq(it2["V131"], [12, 12, 995, np.nan, 9]))
        it1 = C.build_raw_items(raw, META, base_settings(item_rule="L2", staff_coding="L1"))
        self.assertTrue(nan_eq(it1["V131"], [0, 12, 12, 0, 9]))

    def test_other_items_declared_missing_never_valid(self):
        rows = [{"V79": np.nan, "V67": 8, "V102": 1, "V222": 9, "V235": 2},
                {"V114": 2, "V67": 9, "V102": 1, "V222": 7, "V235": 3, "V136": 2, "V209": 1}]
        raw = raw_frame(rows)
        it = C.build_raw_items(raw, META, base_settings(item_rule="L2"))
        self.assertEqual(it["V102"][0], 1)  # CORE V67 = 8 invalid -> no copy
        self.assertEqual(it["V235"][0], 2)
        self.assertEqual(it["V136"][1], 1)  # manager from GSS because CORE invalid
        self.assertEqual(it["V209"][1], 3)


# ----------------------------------------------------------------------------
# A8: reference sample under z_reference L1/L2 from validity, fixed
# ----------------------------------------------------------------------------
class TestA8ReferenceSample(unittest.TestCase):
    def test_membership_from_validity_and_moments_within_sample(self):
        n = 14
        raw = synth_raw(n, [10] * 8 + [600] * 6, seed=11)
        # rows 10..13 leave the org sample (POP missing); V97 constant inside the sample, varying outside
        for i in range(10, 14):
            for v in C.POP_ITEMS:
                raw.loc[i, v] = 8
        raw.loc[:9, "V97"] = 10.0
        raw.loc[10:13, "V97"] = [3.0, 20.0, 40.0, 50.0]
        for zref in ("L1", "L2"):
            fams = P.build_family_frames(raw, META, CW, base_settings(z_reference=zref))
            fr = fams["org"]["frame"]
            sample = fams["org"]["sample"]
            self.assertEqual(list(sample), [True] * 10 + [False] * 4)
            # validity-based: identical to the complete-case rule on the un-standardized items
            items = C.build_staff_items(C.build_raw_items(raw, META, base_settings()), "L0")
            self.assertTrue(C.index_of(items, "L0").notna().all())
            # moments are those of the reference sample (n = 10, mean 0, sd 1 for V62)
            info = fams["org"]["z_info"] if "z_info" in fams["org"] else fams["z_info"]["org"]
            self.assertEqual(info["STAFF"]["V62"]["n"], 10)
            z62 = (items["V62"] - items["V62"][:10].mean()) / items["V62"][:10].std(ddof=1)
            # V97 is constant within the reference: its score is undefined there and the STAFF
            # index averages the remaining valid scores; membership is unchanged
            self.assertTrue(np.isnan(info["STAFF"]["V97"]["sd"]) or info["STAFF"]["V97"]["sd"] == 0)
            z131 = (items["V131"] - items["V131"][:10].mean()) / items["V131"][:10].std(ddof=1)
            expect_in = (z62[:10] + z131[:10]) / 2
            np.testing.assert_allclose(fr["STAFF"][:10].values, expect_in.values, rtol=1e-10)
            # rows outside the reference keep the L0 (frame-wide) scores
            fams0 = P.build_family_frames(raw, META, CW, base_settings())
            np.testing.assert_allclose(fr["STAFF"][10:].values, fams0["org"]["frame"]["STAFF"][10:].values)
            self.assertTrue(fams0["org"]["sample"].equals(sample))

    def test_membership_not_recomputed_when_score_undefined(self):
        # inside the reference sample only V62 is valid and it is constant: the standardized index is
        # undefined there, but the sample (from validity) keeps those rows, and the model fails explicitly
        n = 12
        raw = synth_raw(n, [10] * 6 + [600] * 6, seed=12)
        raw.loc[:, "V97"] = 998
        raw.loc[:, "V131"] = 999
        raw.loc[:7, "V62"] = 10.0
        for i in range(8, 12):  # outside the org sample (POP missing), varying V62
            for v in C.POP_ITEMS:
                raw.loc[i, v] = 9
            raw.loc[i, "V62"] = 2.0 * (i - 6)
        fams = P.build_family_frames(raw, META, CW, base_settings(z_reference="L1"))
        self.assertEqual(list(fams["org"]["sample"]), [True] * 8 + [False] * 4)
        self.assertTrue(fams["org"]["frame"]["STAFF"][:8].isna().all())
        res = P.run_spec(spec(base_settings(z_reference="L1"), spec_id="D09"), raw, META, CW)
        s = stat(res, "org_M1_STAFF")
        self.assertEqual(s["status"], "failed")
        self.assertIn("non-finite", s["error"])
        self.assertEqual(s["n"], 8)
        # the sample listing is unchanged by the failure
        self.assertEqual(sum(1 for r in res.samples if r["family"] == "org"), 8)


# ----------------------------------------------------------------------------
# A5: column dropping and nested tests
# ----------------------------------------------------------------------------
class TestA5Dropping(unittest.TestCase):
    def test_non_dummy_degeneracy_fails_with_reason(self):
        rng = np.random.default_rng(1)
        n = 20
        X = np.column_stack([np.ones(n), rng.normal(size=n), np.zeros(n), rng.normal(size=n)])
        with self.assertRaises(FitError) as cm:
            drop_collinear_dummies(X, ["(Intercept)", "STAFF", "SERVICE", "IND_01"], ["IND_01"])
        self.assertIn("all zero: SERVICE", str(cm.exception))
        X2 = np.column_stack([np.ones(n), rng.normal(size=n)])
        X2 = np.column_stack([X2, 2 * X2[:, 1], rng.normal(size=n)])
        with self.assertRaises(FitError) as cm:
            drop_collinear_dummies(X2, ["(Intercept)", "STAFF", "TRAIN", "IND_01"], ["IND_01"])
        self.assertIn("collinear: TRAIN", str(cm.exception))
        # too few rows for the non-dummy columns: reason is the residual df, not collinearity
        with self.assertRaises(FitError) as cm:
            drop_collinear_dummies(X[:3], ["(Intercept)", "STAFF", "TRAIN", "IND_01"], ["IND_01"])
        self.assertIn("no residual degrees of freedom", str(cm.exception))

    def test_dummies_resolved_before_df_check_in_run_spec(self):
        # n = 20; PRODUCT == IND_59 and SERVICE == IND_07, so both dummies are collinear and dropped.
        # org_M5 then has k = 19 (< n): it succeeds only because the drops happen before the df check.
        groups = [10] * 12 + [600] * 5 + [20] * 3
        v41 = [3] * 12 + [1] * 5 + [2] * 3
        raw = synth_raw(20, groups, seed=21, v41=v41)
        res = P.run_spec(spec(base_settings()), raw, META, CW)
        s = stat(res, "org_M5")
        self.assertEqual(s["status"], "ok", s["error"])
        self.assertEqual(s["dropped_columns"], "IND_07(collinear);IND_59(collinear)")
        self.assertEqual(s["k"], 19)
        self.assertEqual(s["n_industry_dummies"], 0)
        self.assertEqual(s["n"], 20)

    def test_nested_test_rank_increase_mismatch_is_failed(self):
        rng = np.random.default_rng(4)
        n = 60
        cols = {"(Intercept)": np.ones(n)}
        for t in P.A_TERMS:
            cols[t] = rng.normal(size=n)
        cols["GRIEV"] = (rng.uniform(size=n) < 0.4).astype(float)
        cols["LOGEMP"] = rng.normal(size=n)
        cols["IND_59"] = cols["GRIEV"].copy()  # identical to GRIEV -> collinear in the full model
        X = pd.DataFrame(cols)
        y = pd.Series(rng.normal(size=n))
        Xk, names, dropped = P.resolve_dummies(X, ["IND_59"])
        self.assertEqual(dropped, [("IND_59", "collinear")])
        fit = fit_linear(Xk, y.values, names)
        res = P.SpecResult("T")
        res.models["org_M2"] = {"family": "org", "fit": fit, "names": names, "X": X, "y": y, "w": None,
                                "dummies": ["IND_59"], "hrm": P.A_TERMS, "ints": [], "error": None}
        row = P._nested_row(res, "T", "org", "org_M2", "org_base")
        self.assertTrue(np.isnan(row["f"]))
        self.assertEqual(row["n"], n)
        self.assertEqual(len(res.failures), 1)
        self.assertIn("effective rank increase 5 differs from the number of added terms 6", res.failures[0]["error"])
        self.assertEqual(res.failures[0]["stage"], "org_M2_vs_org_base")
        # the direct check in nested_f
        fit_r = fit_linear(X.drop(columns=P.A_TERMS).values, y.values, ["(Intercept)", "LOGEMP", "IND_59"])
        with self.assertRaises(FitError):
            nested_f(fit, fit_r, 6)

    def test_nested_df_equals_added_terms(self):
        groups = [10] * 20 + [600] * 10 + [20] * 10
        raw = synth_raw(40, groups, seed=3)
        res = P.run_spec(spec(base_settings()), raw, META, CW)
        for r in res.nested:
            self.assertFalse(np.isnan(r["f"]), r)
            self.assertEqual(r["df1"], 6 if r["restricted_model"].endswith("base") else 3)
            self.assertEqual(r["df2"], stat(res, r["full_model"])["f_df2"])
        self.assertEqual(res.failures, [])


# ----------------------------------------------------------------------------
# A6 / A10: failure records and influence refits
# ----------------------------------------------------------------------------
class TestA6A10Failures(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # n = 19: both dummies collinear with PRODUCT/SERVICE and dropped; org_M4/org_M5 have k = 19 = n
        groups = [10] * 11 + [600] * 5 + [20] * 3
        v41 = [3] * 11 + [1] * 5 + [2] * 3
        cls.raw = synth_raw(19, groups, seed=8, v41=v41)
        cls.res = P.run_spec(spec(base_settings()), cls.raw, META, CW)

    def test_dropped_columns_recorded_on_failed_fit(self):
        for mid in ("org_M4", "org_M5"):
            s = stat(self.res, mid)
            self.assertEqual(s["status"], "failed")
            self.assertIn("no residual degrees of freedom (n=19", s["error"])
            self.assertEqual(s["dropped_columns"], "IND_07(collinear);IND_59(collinear)")
            self.assertEqual(s["n"], 19)
            self.assertTrue(np.isnan(s["n_leverage_one"]))
        self.assertEqual(stat(self.res, "org_M2")["status"], "ok")
        fails = {f["stage"]: f for f in self.res.failures}
        self.assertEqual(fails["org_M5"]["dropped_columns"], "IND_07(collinear);IND_59(collinear)")
        # nested tests whose full model failed are NA and listed with the reason
        self.assertIn("org_M5_vs_org_M3", fails)
        self.assertIn("no residual degrees of freedom", fails["org_M5_vs_org_M3"]["error"])

    def test_influence_rows_for_failed_origin_model(self):
        rows, failures = P.run_influence(self.res)
        df = pd.DataFrame(rows)
        v1s = sorted(self.raw["V1"])
        for mid in ("org_M4", "org_M5"):
            sub = df[df["model_id"] == mid]
            self.assertEqual(len(sub), 19 * 9)
            self.assertEqual(sorted(sub["deleted_V1"].unique()), v1s)
            self.assertTrue((sub["status"] == "failed").all())
            self.assertTrue(sub["note"].str.startswith("original model failed: FitError: no residual").all())
        stages = [f["stage"] for f in failures]
        self.assertIn("influence:org_M4", stages)
        self.assertIn("influence:org_M5", stages)
        # the ok models have one ok row per record and term, nothing missing
        for mid in ("org_M2", "org_M3"):
            sub = df[df["model_id"] == mid]
            self.assertEqual(sorted(sub["deleted_V1"].unique()), v1s)
            self.assertEqual(len(sub), 19 * len(set(sub["term"])))
            self.assertTrue((sub["status"] == "ok").all())
        # market family: rows with V8 == 1 (17 records); every one is listed for every model
        mkt_v1s = sorted(self.raw.loc[self.raw["V8"] == 1, "V1"])
        for mid in ("mkt_M7", "mkt_M8", "mkt_M9", "mkt_M10"):
            sub = df[df["model_id"] == mid]
            self.assertEqual(sorted(sub["deleted_V1"].unique()), mkt_v1s)
            self.assertEqual(len(sub), 17 * len(set(sub["term"])))

    def test_influence_collinearity_resolved_before_df_check(self):
        # n = 5 = k + 1 with groups [0,1,1,2,2]: deleting row 0 makes IND_g1 + IND_g2 = intercept, so
        # IND_g2 is collinear; dropping it first leaves df = 1 and the refit succeeds (A10).
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
        first = df[df["deleted_V1"] == 1].iloc[0]
        self.assertEqual(first["status"], "ok")
        self.assertEqual(first["note"], "dropped collinear dummies: IND_g2")
        ref = sm.OLS(y.values[1:], X.values[1:, :3]).fit()
        self.assertAlmostEqual(first["estimate"], ref.params[1], places=10)
        self.assertAlmostEqual(first["se"], ref.bse[1], places=10)
        others = df[df["deleted_V1"] != 1]
        self.assertTrue((others["status"] == "failed").all())
        self.assertTrue(others["note"].str.contains("no residual degrees of freedom").all())
        self.assertEqual(len(failures), 4)
        self.assertEqual(sorted(f["deleted_V1"] for f in failures), [2, 3, 4, 5])
        # weighted: the same route
        model["w"] = pd.Series(rng.uniform(0.5, 2.0, size=n))
        model["fit"] = fit_linear(X.values, y.values, list(X.columns), model["w"].values)
        rows, _ = P.influence_rows("org_M2", model)
        first = pd.DataFrame(rows).iloc[0]
        self.assertEqual(first["status"], "ok")
        refw = sm.WLS(y.values[1:], X.values[1:, :3], weights=model["w"].values[1:]).fit()
        self.assertAlmostEqual(first["estimate"], refw.params[1], places=10)

    def test_influence_starts_from_kept_columns(self):
        # a dummy dropped in the original fit is not re-flagged in every deletion
        s = stat(self.res, "org_M2")
        self.assertEqual(s["dropped_columns"], "IND_07(collinear);IND_59(collinear)")
        rows, failures = P.influence_rows("org_M2", self.res.models["org_M2"])
        df = pd.DataFrame(rows)
        self.assertTrue((df["status"] == "ok").all())
        self.assertTrue((df["note"] == "NA").all())
        self.assertEqual(failures, [])


# ----------------------------------------------------------------------------
# development file (structure only)
# ----------------------------------------------------------------------------
@unittest.skipUnless(os.path.exists(os.path.join(ROOT, "data", "survey.csv")), "development data not present")
class TestDevelopmentFile(unittest.TestCase):
    def test_origin_hc3_present_and_leverage_counted(self):
        import json
        raw = pd.read_csv(os.path.join(ROOT, "data", "survey.csv"), low_memory=False)
        for v in C.RAW_VARS:
            raw[v] = pd.to_numeric(raw[v], errors="coerce").astype(float)
        meta = C.load_metadata(os.path.join(ROOT, "data", "survey_metadata.json"))
        cw = C.load_crosswalk(os.path.join(ROOT, "data", "industry_crosswalk.csv"))
        with open(os.path.join(ROOT, "grid_v1.json")) as fh:
            grid = json.load(fh)
        origin = [s for s in grid["specs"] if s["spec_id"] == "O"][0]
        res = P.run_spec(origin, raw, meta, cw)
        coef = pd.DataFrame(res.coefficients)
        stats = pd.DataFrame(res.model_stats)
        ok = stats[stats["status"] == "ok"]
        self.assertGreater(len(ok), 0)
        self.assertTrue((ok["n_leverage_one"] >= 0).all())
        self.assertTrue(coef["se_hc3"].notna().all())
        self.assertTrue(coef["p_upper_hc3"].notna().all())
        # a blank V43 never becomes UNCL
        fams = P.build_family_frames(raw, meta, cw, origin["settings"])
        fr = fams["org"]["frame"]
        self.assertTrue(fr.loc[raw.loc[fr.index, "V43"].isna(), "IND_GROUP"].isna().all())


if __name__ == "__main__":
    unittest.main()
