"""End-to-end checks on the synthetic development file (structure only, not results).

- the common complete-case sample equals the rows valid on every required variable
- nested F for the origin spec equals statsmodels compare_f_test on the same design
- algebraic checks: CHK_hierarchy_log10 and CHK_pct_proportion leave R2, t statistics and
  the fit unchanged; CHK_industry_ref_alt leaves R2 and non-industry coefficients unchanged
- case_scope L1 uses model-specific rows; WLS excludes WEIGHT <= 0 / missing
"""
import json
import os
import sys
import unittest

import numpy as np
import pandas as pd
import statsmodels.api as sm

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(HERE, ".."))
from paperk7 import coding as C  # noqa: E402
from paperk7 import pipeline as P  # noqa: E402


def load():
    raw = pd.read_csv(os.path.join(ROOT, "data", "survey.csv"), low_memory=False)
    for v in C.RAW_VARS:
        raw[v] = pd.to_numeric(raw[v], errors="coerce").astype(float)
    meta = C.load_metadata(os.path.join(ROOT, "data", "survey_metadata.json"))
    cw = C.load_crosswalk(os.path.join(ROOT, "data", "industry_crosswalk.csv"))
    with open(os.path.join(ROOT, "grid_v1.json")) as fh:
        grid = json.load(fh)
    specs = {s["spec_id"]: s for s in grid["specs"]}
    return raw, meta, cw, specs


@unittest.skipUnless(os.path.exists(os.path.join(ROOT, "data", "survey.csv")), "development data not present")
class TestPipeline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw, cls.meta, cls.cw, cls.specs = load()
        cls.origin = P.run_spec(cls.specs["O"], cls.raw, cls.meta, cls.cw)

    def coef(self, res, model_id):
        return pd.DataFrame([r for r in res.coefficients if r["model_id"] == model_id]).set_index("term")

    def stats(self, res, model_id):
        return [r for r in res.model_stats if r["model_id"] == model_id][0]

    def test_common_sample(self):
        fams = P.build_family_frames(self.raw, self.meta, self.cw, self.specs["O"]["settings"])
        for fam in ("org", "mkt"):
            fr = fams[fam]["frame"]
            req = P.required_vars(fam, [], self.specs["O"]["settings"])
            expected = fr[req].notna().all(axis=1)
            self.assertTrue(expected.equals(fams[fam]["sample"]))
            ids = {r["V1"] for r in self.origin.samples if r["family"] == fam}
            self.assertEqual(ids, set(fr.loc[expected, "V1"]))
            # every model of the family uses exactly this sample
            for r in self.origin.model_stats:
                if r["family"] == fam:
                    self.assertEqual(r["status"], "ok")
                    self.assertEqual(r["n"], int(expected.sum()))
        self.assertTrue((fams["mkt"]["frame"]["V8"] == 1).all())

    def test_nested_f_matches_statsmodels(self):
        for full, restricted in [("org_M2", "org_base"), ("org_M4", "org_M2"), ("mkt_M10", "mkt_M8")]:
            mf = self.origin.models[full]
            mr = self.origin.models[restricted]
            rf = sm.OLS(mf["y"].values, mf["X"][mf["names"]].values).fit()
            rr = sm.OLS(mr["y"].values, mr["X"][mr["names"]].values).fit()
            f_ref, p_ref, df_ref = rf.compare_f_test(rr)
            row = [r for r in self.origin.nested if r["full_model"] == full][0]
            self.assertAlmostEqual(row["f"], f_ref, places=8)
            self.assertAlmostEqual(row["p"], p_ref, places=8)
            self.assertEqual(row["df1"], int(df_ref))
            self.assertEqual(row["df2"], int(rf.df_resid))
            self.assertAlmostEqual(row["delta_r2"], rf.rsquared - rr.rsquared, places=10)

    def test_check_specs_are_invariant(self):
        chk_h = P.run_spec(self.specs["CHK_hierarchy_log10"], self.raw, self.meta, self.cw)
        chk_p = P.run_spec(self.specs["CHK_pct_proportion"], self.raw, self.meta, self.cw)
        chk_i = P.run_spec(self.specs["CHK_industry_ref_alt"], self.raw, self.meta, self.cw)
        for fam, ids in {"org": ["org_base", "org_M1_VHIER", "org_M3", "org_M5"], "mkt": ["mkt_M8", "mkt_M10"]}.items():
            for mid in ids:
                o = self.coef(self.origin, mid)
                so = self.stats(self.origin, mid)
                for chk in (chk_h, chk_p, chk_i):
                    s = self.stats(chk, mid)
                    self.assertEqual(s["status"], "ok")
                    self.assertAlmostEqual(s["r2"], so["r2"], places=10)
                    self.assertAlmostEqual(s["f"], so["f"], places=6)
                    self.assertEqual(s["n"], so["n"])
                # log10 rescales VHIER (and VHIER_x_DECENT) by ln(10); t statistics unchanged
                c = self.coef(chk_h, mid)
                for t in o.index:
                    self.assertAlmostEqual(c.loc[t, "t"], o.loc[t, "t"], places=8)
                    if t in ("VHIER", "VHIER_x_DECENT"):
                        self.assertAlmostEqual(c.loc[t, "estimate"], o.loc[t, "estimate"] * np.log(10), places=8)
                    elif not t.startswith("IND_") or True:
                        self.assertAlmostEqual(c.loc[t, "estimate"], o.loc[t, "estimate"], places=8)
                c = self.coef(chk_p, mid)
                self.assertAlmostEqual(c.loc["PCTMGR", "estimate"], o.loc["PCTMGR", "estimate"] * 100, places=6)
                self.assertAlmostEqual(c.loc["PCTMGR", "t"], o.loc["PCTMGR", "t"], places=8)
                # alternative reference group: non-industry slopes identical, intercept shifts
                c = self.coef(chk_i, mid)
                for t in o.index:
                    if t.startswith("IND_") or t == "(Intercept)":
                        continue
                    self.assertAlmostEqual(c.loc[t, "estimate"], o.loc[t, "estimate"], places=8)
                    self.assertAlmostEqual(c.loc[t, "se"], o.loc[t, "se"], places=8)
                self.assertNotEqual(set(c.index), set(o.index))

    def test_case_scope_L1_and_weights(self):
        d04 = P.run_spec(self.specs["D04"], self.raw, self.meta, self.cw)
        fams = P.build_family_frames(self.raw, self.meta, self.cw, self.specs["D04"]["settings"])
        fr = fams["org"]["frame"]
        for mid, hrm, ints in P.model_definitions("org"):
            req = P.required_vars("org", hrm, self.specs["D04"]["settings"], common=False)
            n_expected = int(fr[req].notna().all(axis=1).sum())
            self.assertEqual(self.stats(d04, mid)["n"], n_expected)
            ids = {r["V1"] for r in d04.samples if r["model_id"] == mid}
            self.assertEqual(len(ids), n_expected)
        # nested test under L1 uses the full model's rows
        row = [r for r in d04.nested if r["full_model"] == "org_M2"][0]
        self.assertEqual(row["n"], self.stats(d04, "org_M2")["n"])
        d33 = P.run_spec(self.specs["D33"], self.raw, self.meta, self.cw)
        m = d33.models["org_M2"]
        self.assertTrue((m["w"] > 0).all())
        ref = sm.WLS(m["y"].values, m["X"][m["names"]].values, weights=m["w"].values).fit()
        np.testing.assert_allclose(m["fit"]["beta"], ref.params, rtol=1e-8)
        self.assertAlmostEqual(m["fit"]["r2"], ref.rsquared, places=10)

    def test_centering_changes_only_interactions(self):
        d34 = P.run_spec(self.specs["D34"], self.raw, self.meta, self.cw)
        m = d34.models["org_M4"]
        self.assertEqual(set(m["center_means"]), {"TRAIN", "STAFF", "GRIEV", "INCENT", "ILM", "DECENT"})
        sub = m["X"]
        a, b = sub["TRAIN"], sub["STAFF"]
        np.testing.assert_allclose(sub["TRAIN_x_STAFF"].values, ((a - a.mean()) * (b - b.mean())).values)
        # R2 of the interaction model is invariant to centering; main effects are not
        self.assertAlmostEqual(self.stats(d34, "org_M4")["r2"], self.stats(self.origin, "org_M4")["r2"], places=10)
        self.assertAlmostEqual(self.stats(d34, "org_M2")["r2"], self.stats(self.origin, "org_M2")["r2"], places=10)

    def test_z_reference_levels(self):
        o = P.build_family_frames(self.raw, self.meta, self.cw, self.specs["O"]["settings"])
        d09 = P.build_family_frames(self.raw, self.meta, self.cw, self.specs["D09"]["settings"])
        d10 = P.build_family_frames(self.raw, self.meta, self.cw, self.specs["D10"]["settings"])
        d11 = P.build_family_frames(self.raw, self.meta, self.cw, self.specs["D11"]["settings"])
        # same membership under all reference choices
        for d in (d09, d10, d11):
            for fam in ("org", "mkt"):
                self.assertTrue(d[fam]["sample"].equals(o[fam]["sample"]))
        # L1: market family uses the org-sample standardization
        mk_idx = d09["mkt"]["frame"].index
        pd.testing.assert_series_equal(d09["mkt"]["frame"]["STAFF"], d09["org"]["frame"].loc[mk_idx, "STAFF"])
        # L2: market family standardized within its own sample -> differs from L1
        self.assertFalse(np.allclose(d10["mkt"]["frame"]["STAFF"].dropna(), d09["mkt"]["frame"]["STAFF"].dropna()))
        # L3: population SD (smaller than the sample SD) -> z values scaled by sqrt(n/(n-1)) relative to L0
        info0 = o["z_info"]["L0"]["STAFF"]["V62"]
        n = info0["n"]
        s0 = o["org"]["frame"]["STAFF"]
        s3 = d11["org"]["frame"]["STAFF"]
        # rows where only V62 is valid scale exactly by sqrt(n/(n-1))
        items = C.build_staff_items(C.build_raw_items(self.raw, self.meta, self.specs["O"]["settings"]), "L0")
        only62 = items["V62"].notna() & items["V97"].isna() & items["V131"].isna()
        ratio = (s3[only62] / s0[only62]).dropna()
        self.assertGreater(len(ratio), 0)
        np.testing.assert_allclose(ratio.values, np.sqrt(n / (n - 1)), rtol=1e-10)


if __name__ == "__main__":
    unittest.main()
