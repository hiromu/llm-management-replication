"""Leave-one-out refits on a small case, checked against explicit statsmodels refits."""
import os
import sys
import unittest

import numpy as np
import pandas as pd
import statsmodels.api as sm
from scipy import stats

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from paperk7 import pipeline as P  # noqa: E402
from paperk7.regression import fit_linear  # noqa: E402


def small_model(n=25, seed=4, weights=False, singleton=True, groups=None):
    rng = np.random.default_rng(seed)
    staff = rng.normal(size=n)
    train = rng.normal(size=n)
    ctrl = rng.normal(size=n)
    g = rng.integers(0, 3, size=n) if groups is None else np.asarray(groups)
    X = pd.DataFrame({"(Intercept)": 1.0, "STAFF": staff, "TRAIN": train, "TRAIN_x_STAFF": train * staff,
                      "LOGEMP": ctrl, "IND_20": (g == 1).astype(float), "IND_59": (g == 2).astype(float)})
    if singleton:
        X["IND_73"] = 0.0
        X.loc[n - 1, "IND_73"] = 1.0
    y = pd.Series(0.5 + 1.0 * staff - 0.5 * train + 0.3 * train * staff + ctrl + rng.normal(size=n))
    w = pd.Series(rng.uniform(0.5, 2.0, size=n)) if weights else None
    dummies = [c for c in X.columns if c.startswith("IND_")]
    fit = fit_linear(X.values, y.values, list(X.columns), None if w is None else w.values)
    return {"family": "org", "X": X, "y": y, "w": w, "dummies": dummies, "fit": fit, "names": list(X.columns),
            "dropped": [], "hrm": ["STAFF", "TRAIN"], "ints": ["TRAIN_x_STAFF"], "rows": X.index,
            "V1": pd.Series(np.arange(1001, 1001 + n)), "center_means": {}, "reference_group": "01"}


class TestInfluence(unittest.TestCase):
    def _check(self, model):
        rows, failures = P.influence_rows("org_M4", model)
        self.assertEqual(failures, [])
        rows = pd.DataFrame(rows)
        X, y, w = model["X"], model["y"], model["w"]
        n = len(y)
        self.assertEqual(len(rows), n * 3)
        self.assertEqual(set(rows["term"]), {"STAFF", "TRAIN", "TRAIN_x_STAFF"})
        self.assertEqual(sorted(rows["deleted_V1"].unique()), list(model["V1"]))
        for i in range(n):
            keep = np.ones(n, dtype=bool)
            keep[i] = False
            Xi = X[keep]
            dropped = [c for c in model["dummies"] if (Xi[c] != 0).sum() == 0]
            Xi = Xi.drop(columns=dropped)
            if w is None:
                ref = sm.OLS(y[keep].values, Xi.values).fit()
            else:
                ref = sm.WLS(y[keep].values, Xi.values, weights=w[keep].values).fit()
            sub = rows[rows["deleted_V1"] == model["V1"][i]].set_index("term")
            for t in ["STAFF", "TRAIN", "TRAIN_x_STAFF"]:
                j = list(Xi.columns).index(t)
                self.assertEqual(sub.loc[t, "status"], "ok")
                self.assertAlmostEqual(sub.loc[t, "estimate"], ref.params[j], places=10)
                self.assertAlmostEqual(sub.loc[t, "se"], ref.bse[j], places=10)
                self.assertAlmostEqual(sub.loc[t, "p_two"], ref.pvalues[j], places=10)
                self.assertAlmostEqual(sub.loc[t, "p_upper"], stats.t.sf(ref.tvalues[j], ref.df_resid), places=10)
            if dropped:
                self.assertIn("dropped all-zero dummies: " + ",".join(dropped), sub.loc["STAFF", "note"])
            else:
                self.assertEqual(sub.loc["STAFF", "note"], "NA")
        return rows

    def test_ols_loo_matches_explicit_refits(self):
        model = small_model()
        rows = self._check(model)
        # deleting the singleton member drops IND_73 and is flagged
        last = rows[rows["deleted_V1"] == model["V1"].iloc[-1]]
        self.assertTrue((last["note"] == "dropped all-zero dummies: IND_73").all())
        self.assertEqual((rows["note"] != "NA").sum(), 3)

    def test_wls_loo_matches_explicit_refits(self):
        model = small_model(weights=True, singleton=False)
        rows = self._check(model)
        self.assertTrue((rows["note"] == "NA").all())

    def test_failure_is_recorded(self):
        # with n = k + 1 = 8 (k = 7) and no group that can empty, every deletion leaves zero
        # residual df -> every refit fails and is retained with its reason
        model = small_model(n=8, singleton=False, groups=[0, 0, 0, 1, 1, 1, 2, 2])
        self.assertEqual(model["fit"]["k"], 7)
        rows, failures = P.influence_rows("org_M4", model)
        rows = pd.DataFrame(rows)
        self.assertEqual(len(rows), 8 * 3)
        self.assertTrue((rows["status"] == "failed").all())
        self.assertTrue(rows["estimate"].isna().all())
        self.assertTrue(rows["note"].str.contains("no residual degrees of freedom").all())
        # every failed deletion is also a failures entry for run_info.json (A6/A10)
        self.assertEqual(len(failures), 8)
        self.assertEqual(sorted(f["deleted_V1"] for f in failures), list(model["V1"]))
        self.assertTrue(all("no residual degrees of freedom" in f["error"] for f in failures))

    def test_values_held_fixed(self):
        # the influence routine must not recompute anything from the data: the design passed in is used as is.
        model = small_model(n=20, singleton=False)
        X = model["X"].copy()
        rows = pd.DataFrame(P.influence_rows("org_M4", model)[0])
        pd.testing.assert_frame_equal(X, model["X"])
        # sanity: the LOO estimate equals the closed-form DFBETA update for OLS
        fit = model["fit"]
        Xv = model["X"].values
        XtXi = np.linalg.inv(Xv.T @ Xv)
        j = model["names"].index("STAFF")
        for i in range(5):
            h = fit["leverage"][i]
            b_loo = fit["beta"] - (XtXi @ Xv[i]) * fit["resid"][i] / (1 - h)
            est = rows[(rows["deleted_V1"] == model["V1"][i]) & (rows["term"] == "STAFF")]["estimate"].iloc[0]
            self.assertAlmostEqual(est, b_loo[j], places=10)


if __name__ == "__main__":
    unittest.main()
