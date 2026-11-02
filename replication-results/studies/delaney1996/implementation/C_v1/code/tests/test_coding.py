"""Hand-built rows for every coding rule and axis level (sections 2-4 and 9)."""
import math
import os
import sys
import tempfile
import unittest

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from paperk7 import coding as C  # noqa: E402
from paperk7 import pipeline as P  # noqa: E402

LN = math.log


def base_settings(**over):
    s = {k: "L0" for k in ["records", "market_sample", "market_requires_pop", "case_scope", "item_rule",
                           "staff_coding", "z_reference", "train_log", "no_training", "decision_map",
                           "union_items", "subsidiary", "age", "hierarchy", "employment", "pct_managers",
                           "competition", "neither", "industry", "weights", "centering"]}
    s.update(over)
    return s


# metadata with the declared missing codes of the real file for the variables used
DECLARED = {
    "V9": [8, 9], "V16": [9998, 9999], "V21": [8, 9], "V23": [99998, 99999], "V32": [99998, 99999],
    "V41": [8, 9], "V62": [995, 998, 999], "V97": [995, 998, 999], "V131": [995, 998, 999],
    "V67": [8, 9], "V76": [8, 9], "V102": [8, 9], "V111": [8, 9], "V136": [8, 9], "V79": [8, 9],
    "V114": [8, 9], "V115": [99998, 99999], "V145": [8, 9], "V157": [99998, 99999], "V166": [8, 9],
    "V172": [8, 9], "V209": [7, 8, 9], "V222": [8, 9], "V235": [7, 8, 9], "V220": [8, 9],
    "V233": [7, 8, 9], "V300": [7, 8, 9], "V261": [98, 99], "V270": [7, 8, 9], "V328": [7, 8, 9],
    "WEIGHT": [0],
}
for _v in C.POP_ITEMS + C.PMP_ITEMS + C.DECENT_LARGER + C.DECENT_INDEP:
    DECLARED[_v] = [7, 8, 9]
META = {v: {"name": v, "declared_missing_values": codes, "declared_missing_ranges": []} for v, codes in DECLARED.items()}
META["RANGEVAR"] = {"name": "RANGEVAR", "declared_missing_values": [], "declared_missing_ranges": [[90, 99]]}


def raw_frame(rows):
    """Build a raw DataFrame with all RAW_VARS (NaN default) from a list of dicts."""
    df = pd.DataFrame({v: [np.nan] * len(rows) for v in C.RAW_VARS}, dtype=float)
    for i, r in enumerate(rows):
        for k, val in r.items():
            df.loc[i, k] = val
    if df["V1"].isna().any():
        df["V1"] = np.arange(1, len(rows) + 1, dtype=float)
    return df


def nan_eq(a, b):
    a, b = list(a), list(b)
    if len(a) != len(b):
        return False
    for x, y in zip(a, b):
        if pd.isna(x) and pd.isna(y):
            continue
        if pd.isna(x) or pd.isna(y) or abs(x - y) > 1e-12:
            return False
    return True


class TestGeneralRules(unittest.TestCase):
    def test_apply_missing_values_and_ranges(self):
        s = pd.Series([1, 7, 8, 9, np.nan, 2])
        out = C.apply_missing(s, META, "V270")
        self.assertTrue(nan_eq(out, [1, np.nan, np.nan, np.nan, np.nan, 2]))
        out = C.apply_missing(pd.Series([1, 90, 95, 99, 100]), META, "RANGEVAR")
        self.assertTrue(nan_eq(out, [1, np.nan, np.nan, np.nan, 100]))
        # extra and keep
        out = C.apply_missing(pd.Series([995, 997, 5]), META, "V62", extra_missing=[997], keep=[995])
        self.assertTrue(nan_eq(out, [995, np.nan, 5]))

    def test_reverse(self):
        self.assertTrue(nan_eq(C.reverse(pd.Series([1, 4, np.nan]), 4), [4, 1, np.nan]))
        self.assertTrue(nan_eq(C.reverse(pd.Series([1, 2]), 2), [2, 1]))

    def test_index_rules(self):
        items = pd.DataFrame({"a": [1, 1, np.nan], "b": [3, np.nan, np.nan]})
        self.assertTrue(nan_eq(C.index_of(items, "L0"), [2, 1, np.nan]))
        self.assertTrue(nan_eq(C.index_of(items, "L2"), [2, 1, np.nan]))
        self.assertTrue(nan_eq(C.index_of(items, "L1"), [2, np.nan, np.nan]))

    def test_log_nonpositive_missing(self):
        self.assertTrue(nan_eq(C.safe_log(pd.Series([1, 0, -1, np.nan, math.e])), [0, np.nan, np.nan, np.nan, 1]))
        self.assertAlmostEqual(C.safe_log(pd.Series([100.0]), base=10)[0], 2.0)

    def test_zscore(self):
        s = pd.Series([1.0, 2.0, 3.0, 4.0, np.nan])
        z, info = C.zscore(s)
        self.assertEqual(info["n"], 4)
        self.assertAlmostEqual(info["sd"], s.std(ddof=1))
        self.assertTrue(nan_eq(z, (s - 2.5) / s.std(ddof=1)))
        z0, info0 = C.zscore(s, ddof=0)
        self.assertAlmostEqual(info0["sd"], s.std(ddof=0))
        # reference subset: rows outside the reference are still scored with the reference moments
        ref = pd.Series([True, True, False, False, False])
        zr, infr = C.zscore(s, ref_mask=ref)
        self.assertEqual(infr["n"], 2)
        self.assertAlmostEqual(infr["mean"], 1.5)
        self.assertAlmostEqual(zr[2], (3 - 1.5) / math.sqrt(0.5))
        # standardize_and_index keeps base (L0) values outside the reference
        items = pd.DataFrame({"a": s})
        idx, zz, _ = C.standardize_and_index(items, "L0", ref_mask=ref, ddof=1, base_z=pd.DataFrame({"a": z}))
        self.assertAlmostEqual(zz["a"][0], (1 - 1.5) / math.sqrt(0.5))
        self.assertAlmostEqual(zz["a"][2], z[2])
        # constant reference -> all missing
        zc, _ = C.zscore(pd.Series([2.0, 2.0, 2.0]))
        self.assertTrue(zc.isna().all())


class TestOutcomes(unittest.TestCase):
    def test_pop_pmp(self):
        rows = [
            {**{v: 1 for v in C.POP_ITEMS}, **{v: 4 for v in C.PMP_ITEMS}},  # all much better -> POP 4, PMP 1
            {"V289": 2, "V290": 7, "V291": 8, "V292": 9, "V296": 3, "V297": 7},  # partial
            {"V289": 7},  # none valid
        ]
        raw = raw_frame(rows)
        items = C.build_raw_items(raw, META, base_settings())
        pop, pmp = C.build_pop_pmp(items, "L0")
        self.assertTrue(nan_eq(pop, [4, 3, np.nan]))
        self.assertTrue(nan_eq(pmp, [1, 2, np.nan]))
        pop1, pmp1 = C.build_pop_pmp(items, "L1")
        self.assertTrue(nan_eq(pop1, [4, np.nan, np.nan]))
        self.assertTrue(nan_eq(pmp1, [1, np.nan, np.nan]))


class TestHRM(unittest.TestCase):
    def test_staff_coding_levels(self):
        rows = [{"V62": 5}, {"V62": 0}, {"V62": 995}, {"V62": 997}, {"V62": 998}, {"V62": 999}, {"V62": 1}, {}]
        raw = raw_frame(rows)
        for lvl, expect in {
            "L0": [LN(5), np.nan, np.nan, np.nan, np.nan, np.nan, 0.0, np.nan],
            "L1": [LN(6), 0.0, np.nan, np.nan, np.nan, np.nan, LN(2), np.nan],
            "L2": [LN(5), np.nan, LN(995), np.nan, np.nan, np.nan, 0.0, np.nan],
        }.items():
            items = C.build_raw_items(raw, META, base_settings(staff_coding=lvl))
            st = C.build_staff_items(items, lvl)
            self.assertTrue(nan_eq(st["V62"], expect), lvl)

    def test_train_items(self):
        # rows: 0 training yes w/ counts; 1 training no; 2 yes but V172=4; 3 yes with 99996; 4 yes with V157=0
        rows = [{"V145": 1, "V157": 10, "V172": 1}, {"V145": 2, "V157": 55, "V172": 2},
                {"V145": 1, "V157": 99998, "V172": 4}, {"V145": 1, "V157": 99996, "V172": 3},
                {"V145": 1, "V157": 0, "V172": 2}, {"V145": 8}]
        raw = raw_frame(rows)
        t = C.build_train_items(raw, META, base_settings())  # no_training L0, train_log L0
        self.assertTrue(nan_eq(t["V145"], [LN(2), 0.0, LN(2), LN(2), LN(2), np.nan]))
        self.assertTrue(nan_eq(t["V157"], [LN(10), np.nan, np.nan, LN(100000), np.nan, np.nan]))
        self.assertTrue(nan_eq(t["V172"], [LN(3), np.nan, np.nan, 0.0, LN(2), np.nan]))
        t = C.build_train_items(raw, META, base_settings(no_training="L1"))  # V157 0, V172 1; ln(1+x)
        self.assertTrue(nan_eq(t["V157"], [LN(11), 0.0, np.nan, LN(100001), 0.0, np.nan]))
        self.assertTrue(nan_eq(t["V172"], [LN(3), 0.0, np.nan, 0.0, LN(2), np.nan]))
        t = C.build_train_items(raw, META, base_settings(no_training="L2"))
        self.assertTrue(nan_eq(t["V157"], [LN(11), 0.0, np.nan, LN(100001), 0.0, np.nan]))
        self.assertTrue(nan_eq(t["V172"], [LN(3), np.nan, np.nan, 0.0, LN(2), np.nan]))
        t = C.build_train_items(raw, META, base_settings(train_log="L1"))  # only count logged
        self.assertTrue(nan_eq(t["V145"], [2, 1, 2, 2, 2, np.nan]))
        self.assertTrue(nan_eq(t["V157"], [LN(10), np.nan, np.nan, LN(100000), np.nan, np.nan]))
        self.assertTrue(nan_eq(t["V172"], [3, np.nan, np.nan, 1, 2, np.nan]))
        t = C.build_train_items(raw, META, base_settings(train_log="L2", no_training="L1"))  # no logs
        self.assertTrue(nan_eq(t["V157"], [10, 0, np.nan, 100000, 0, np.nan]))
        self.assertTrue(nan_eq(t["V172"], [3, 1, np.nan, 1, 2, np.nan]))

    def test_incent_griev_ilm(self):
        rows = [{"V209": 1, "V222": 3, "V235": 7, "V270": 1, "V67": 1, "V76": 2, "V102": 8, "V111": 9, "V136": 1},
                {"V209": 9, "V222": 8, "V235": 2, "V270": 2}, {"V270": 7}]
        raw = raw_frame(rows)
        items = C.build_raw_items(raw, META, base_settings())
        self.assertTrue(nan_eq(C.build_incent(items, "L0"), [2.0, 2.0, np.nan]))
        self.assertTrue(nan_eq(C.build_incent(items, "L1"), [np.nan, np.nan, np.nan]))
        self.assertTrue(nan_eq(C.build_griev(raw, META), [1, 0, np.nan]))
        self.assertTrue(nan_eq(C.build_ilm(items, "L0"), [(2 + 1 + 2) / 3, np.nan, np.nan]))

    def test_decent_routing_and_maps(self):
        # row 0: part of larger org (V17=1): uses V271.. ; row 1: independent (V17=2): uses V279..
        r0 = {"V17": 1, **{v: 3 for v in C.DECENT_LARGER}, **{v: 1 for v in C.DECENT_INDEP}}
        r1 = {"V17": 2, **{v: 3 for v in C.DECENT_LARGER}, **{v: 1 for v in C.DECENT_INDEP}}
        r2 = {"V17": 1, "V271": 6, "V272": 5, "V273": 4, "V274": 2, "V275": 7, "V276": 8, "V277": 9}  # V278 blank
        r3 = {"V17": 1, "V271": 6}
        raw = raw_frame([r0, r1, r2, r3])
        items = C.build_raw_items(raw, META, base_settings())
        d0 = C.build_decent(items, raw, base_settings(decision_map="L0"))
        self.assertTrue(nan_eq(d0, [1.0, 3.0, (2 + 4 + 5) / 3, np.nan]))
        d1 = C.build_decent(items, raw, base_settings(decision_map="L1"))
        self.assertTrue(nan_eq(d1, [3.0, 1.0, (2 + 4 + 5) / 3, np.nan]))
        d1_all = C.build_decent(items, raw, base_settings(decision_map="L1", item_rule="L1"))
        self.assertTrue(nan_eq(d1_all, [3.0, 1.0, np.nan, np.nan]))

    def test_vhier(self):
        raw = raw_frame([{"V261": 5}, {"V261": 96}, {"V261": 98}, {"V261": 99}, {}])
        self.assertTrue(nan_eq(C.build_vhier(raw, META, base_settings()), [LN(5), LN(100), np.nan, np.nan, np.nan]))
        self.assertTrue(nan_eq(C.build_vhier(raw, META, base_settings(hierarchy="L1")), [LN(5), np.nan, np.nan, np.nan, np.nan]))
        self.assertTrue(nan_eq(C.build_vhier(raw, META, base_settings(hierarchy="L2")), [5, 100, np.nan, np.nan, np.nan]))
        chk = C.build_vhier(raw, META, base_settings(), check="hierarchy_log10")
        self.assertTrue(nan_eq(chk, [math.log10(5), 2.0, np.nan, np.nan, np.nan]))


class TestCopyRule(unittest.TestCase):
    def test_gss_copy(self):
        rows = [
            {"V79": 2, "V62": 10, "V97": 3, "V67": 1, "V102": 2, "V76": 2, "V111": 1, "V222": 1, "V235": 3},  # copy
            {"V79": 1, "V62": 10, "V97": 3, "V67": 1, "V102": 2},  # no copy
            {"V79": np.nan, "V62": 10, "V97": 3},  # system-missing V79, CORE valid -> copy
            {"V79": np.nan, "V62": 998, "V97": 3},  # system-missing V79, CORE invalid -> no copy
            {"V79": 9, "V62": 10, "V97": 3},  # user-missing V79 is not system-missing -> no copy
            {"V79": 2, "V62": 999, "V97": 3},  # copy of a missing CORE -> missing
        ]
        raw = raw_frame(rows)
        items = C.build_raw_items(raw, META, base_settings(item_rule="L2"))
        self.assertTrue(nan_eq(items["V97"], [10, 3, 10, 3, 3, np.nan]))
        self.assertTrue(nan_eq(items["V102"], [1, 2, np.nan, np.nan, np.nan, np.nan]))
        self.assertTrue(nan_eq(items["V111"], [2, np.nan, np.nan, np.nan, np.nan, np.nan]))
        self.assertTrue(nan_eq(items["V235"], [1, np.nan, np.nan, np.nan, np.nan, np.nan]))
        # under item_rule L0 nothing is copied
        items0 = C.build_raw_items(raw, META, base_settings(item_rule="L0"))
        self.assertTrue(nan_eq(items0["V97"], [3, 3, 3, 3, 3, 3]))

    def test_manager_copy(self):
        rows = [
            {"V114": 2, "V62": 10, "V97": 4, "V131": 1, "V67": 1, "V102": 2, "V136": 2, "V222": 1, "V235": 2, "V209": 3},
            {"V114": 2, "V62": 998, "V97": 4, "V131": 1, "V67": 8, "V102": 2, "V136": 2, "V222": 9, "V235": 2, "V209": 3},
            {"V114": np.nan, "V62": 10, "V131": 1},
            {"V114": 1, "V62": 10, "V131": 1},
            {"V114": 2, "V79": 2, "V62": 10, "V97": 4, "V131": 1},  # GSS copy applied first, then manager from CORE
        ]
        raw = raw_frame(rows)
        items = C.build_raw_items(raw, META, base_settings(item_rule="L2"))
        self.assertTrue(nan_eq(items["V131"], [10, 4, 10, 1, 10]))
        self.assertTrue(nan_eq(items["V136"], [1, 2, np.nan, np.nan, np.nan]))
        self.assertTrue(nan_eq(items["V209"], [1, 2, np.nan, np.nan, np.nan]))
        # the copy happens before transformation: STAFF items are logged after copying
        st = C.build_staff_items(items, "L0")
        self.assertAlmostEqual(st["V131"][0], LN(10))


class TestControls(unittest.TestCase):
    def test_nonprof_subsid(self):
        raw = raw_frame([{"V8": 2, "V17": 1, "V21": 2}, {"V8": 1, "V17": 1, "V21": 1}, {"V8": 1, "V17": 2},
                         {"V8": 1, "V17": 1, "V21": 9}, {"V8": 1, "V17": 1, "V21": 3}, {"V8": 1, "V17": 1, "V21": 7}])
        c = C.build_controls(raw, META, base_settings())
        self.assertTrue(nan_eq(c["NONPROF"], [1, 0, 0, 0, 0, 0]))
        self.assertTrue(nan_eq(c["SUBSID"], [1, 1, 0, 1, 1, 1]))
        c1 = C.build_controls(raw, META, base_settings(subsidiary="L1"))
        self.assertTrue(nan_eq(c1["SUBSID"], [1, 0, 0, np.nan, 0, 0]))
        c2 = C.build_controls(raw, META, base_settings(subsidiary="L2"))
        self.assertTrue(nan_eq(c2["SUBSID"], [1, 1, 0, np.nan, 1, 0]))

    def test_logemp(self):
        raw = raw_frame([{"V23": 10, "V32": 5, "NEWTOTAL": 20}, {"V23": 99998, "V32": 5, "NEWTOTAL": 20},
                         {"V23": 10, "V32": 99999, "NEWTOTAL": 0}, {"V23": 0, "V32": 0, "NEWTOTAL": 3}])
        c = C.build_controls(raw, META, base_settings())
        self.assertTrue(nan_eq(c["LOGEMP"], [LN(15), np.nan, np.nan, np.nan]))
        c = C.build_controls(raw, META, base_settings(employment="L1"))
        self.assertTrue(nan_eq(c["LOGEMP"], [LN(20), LN(20), np.nan, LN(3)]))
        c = C.build_controls(raw, META, base_settings(employment="L2"))
        self.assertTrue(nan_eq(c["LOGEMP"], [LN(10), np.nan, LN(10), np.nan]))

    def test_logage(self):
        raw = raw_frame([{"V16": 1981}, {"V16": 1991}, {"V16": 1992}, {"V16": 9998}, {"V16": 9999}])
        c = C.build_controls(raw, META, base_settings())
        self.assertTrue(nan_eq(c["LOGAGE"], [LN(10), np.nan, np.nan, np.nan, np.nan]))
        c = C.build_controls(raw, META, base_settings(age="L1"))
        self.assertTrue(nan_eq(c["LOGAGE"], [LN(11), 0.0, np.nan, np.nan, np.nan]))
        c = C.build_controls(raw, META, base_settings(age="L2"))
        self.assertTrue(nan_eq(c["LOGAGE"], [10, 0, -1, np.nan, np.nan]))

    def test_pctmgr(self):
        raw = raw_frame([{"V114": 1, "V115": 5, "V23": 20, "V32": 5, "NEWTOTAL": 50},
                         {"V114": 3, "V23": 20, "V32": 5, "NEWTOTAL": 50},
                         {"V114": 2, "V23": 20, "V32": 5, "NEWTOTAL": 50},
                         {"V114": 1, "V115": 5, "V23": 0, "V32": 0, "NEWTOTAL": 50},
                         {"V114": 1, "V115": 99999, "V23": 20, "V32": 5},
                         {"V114": 1, "V115": 5, "V23": 99998, "V32": 5, "NEWTOTAL": 0}])
        c = C.build_controls(raw, META, base_settings())
        self.assertTrue(nan_eq(c["PCTMGR"], [20.0, 0.0, np.nan, np.nan, np.nan, np.nan]))
        c = C.build_controls(raw, META, base_settings(pct_managers="L1"))
        self.assertTrue(nan_eq(c["PCTMGR"], [20.0, np.nan, np.nan, np.nan, np.nan, np.nan]))
        c = C.build_controls(raw, META, base_settings(pct_managers="L2"))
        self.assertTrue(nan_eq(c["PCTMGR"], [10.0, 0.0, np.nan, 10.0, np.nan, np.nan]))
        c = C.build_controls(raw, META, base_settings(), check="pct_proportion")
        self.assertTrue(nan_eq(c["PCTMGR"], [0.2, 0.0, np.nan, np.nan, np.nan, np.nan]))

    def test_union(self):
        raw = raw_frame([{"V220": 1, "V233": 3, "V300": 2, "V166": 1}, {"V220": 7, "V233": 7, "V300": 7, "V166": 2},
                         {"V220": 3, "V233": 9, "V300": 1, "V166": 8}])
        c = C.build_controls(raw, META, base_settings())
        self.assertTrue(nan_eq(c["UNION"], [2.0, np.nan, 1.0]))
        c = C.build_controls(raw, META, base_settings(union_items="L1"))
        self.assertTrue(nan_eq(c["UNION"], [(3 + 1 + 2) / 3, np.nan, (1 + 3) / 2]))
        c = C.build_controls(raw, META, base_settings(union_items="L2"))
        self.assertTrue(nan_eq(c["UNION"], [(3 + 1 + 2 + 3) / 4, 1.0, (1 + 3) / 2]))
        c = C.build_controls(raw, META, base_settings(union_items="L2", item_rule="L1"))
        self.assertTrue(nan_eq(c["UNION"], [(3 + 1 + 2 + 3) / 4, np.nan, np.nan]))

    def test_product_service_neither(self):
        raw = raw_frame([{"V41": 1}, {"V41": 2}, {"V41": 3}, {"V41": 4}, {"V41": 8}, {}])
        c = C.build_controls(raw, META, base_settings())
        self.assertTrue(nan_eq(c["PRODUCT"], [1, 0, 0, np.nan, np.nan, np.nan]))
        self.assertTrue(nan_eq(c["SERVICE"], [0, 1, 0, np.nan, np.nan, np.nan]))
        c = C.build_controls(raw, META, base_settings(neither="L1"))
        self.assertTrue(nan_eq(c["PRODUCT"], [1, 0, 0, 0, np.nan, np.nan]))
        self.assertTrue(nan_eq(c["SERVICE"], [0, 1, 0, 0, np.nan, np.nan]))

    def test_compet(self):
        raw = raw_frame([{"V328": 1}, {"V328": 3}, {"V328": 4}, {"V328": 7}, {"V328": 9}])
        c = C.build_controls(raw, META, base_settings())
        self.assertTrue(nan_eq(c["COMPET"], [1, 3, 4, np.nan, np.nan]))
        c = C.build_controls(raw, META, base_settings(competition="L1"))
        self.assertTrue(nan_eq(c["COMPET"], [0, 0, 1, np.nan, np.nan]))
        c = C.build_controls(raw, META, base_settings(competition="L2"))
        self.assertTrue(nan_eq(c["COMPET"], [0, 1, 1, np.nan, np.nan]))


class TestIndustry(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.NamedTemporaryFile("w", suffix=".csv", delete=False)
        self.tmp.write("census1980_code,title,printed_sic1972,sic2_from_printed\n"
                       '010,"A",01,01\n'
                       '020,"B","07, except 078",07\n'
                       '040,"C","11, 12","11,12"\n'
                       '041,"D","15, 16","15;16"\n'
                       '122,"E",,\n'
                       '600,"F",59,59\n')
        self.tmp.close()
        self.cw = C.load_crosswalk(self.tmp.name)

    def tearDown(self):
        os.unlink(self.tmp.name)

    def test_crosswalk_parse(self):
        self.assertEqual(self.cw[10], ["01"])
        self.assertEqual(self.cw[20], ["07"])
        self.assertEqual(self.cw[40], ["11", "12"])
        self.assertEqual(self.cw[41], ["15", "16"])
        self.assertEqual(self.cw[122], [])

    def test_groups_L0_L1(self):
        raw = raw_frame([{"V43": 10}, {"V43": 40}, {"V43": 41}, {"V43": 122}, {"V43": 999}, {}])
        g0 = C.build_industry(raw, self.cw, base_settings())
        self.assertEqual(list(g0), ["01", "11", "15", "UNCL", "UNCL", "UNCL"])
        g1 = C.build_industry(raw, self.cw, base_settings(industry="L1"))
        self.assertEqual(g1[0], "01")
        self.assertTrue(g1[1:].isna().all())

    def test_reference_group_and_dummies(self):
        g = pd.Series(["01", "01", "59", "59", "UNCL", "UNCL", "07"])
        self.assertEqual(C.choose_reference_group(g), "01")  # tie 01/59/UNCL at 2 -> lowest code
        self.assertEqual(C.choose_reference_group(g, check="industry_ref_alt"), "07")  # smallest
        g2 = pd.Series(["59", "59", "UNCL", "UNCL", "07", "11"])
        self.assertEqual(C.choose_reference_group(g2), "59")  # UNCL sorts after numeric codes
        self.assertEqual(C.choose_reference_group(g2, check="industry_ref_alt"), "11")  # tie 07/11 -> highest
        d = C.industry_dummies(g, "01")
        self.assertEqual(list(d.columns), ["IND_07", "IND_59", "IND_UNCL"])
        self.assertEqual(list(d["IND_59"]), [0, 0, 1, 1, 0, 0, 0])
        d2 = C.industry_dummies(pd.Series(["01", np.nan, "59"]), "01")
        self.assertTrue(d2.iloc[1].isna().all())


class TestFrameAndSamples(unittest.TestCase):
    def test_records_and_market_filters(self):
        raw = raw_frame([{"V3": 0, "V8": 1, "V9": 4, "V289": 1}, {"V3": 1, "V8": 1, "V9": 5, "V289": 1},
                         {"V3": 2, "V8": 2, "V9": 4}, {"V3": 1, "V8": 1, "V9": 4}, {"V3": 1, "V8": 1, "V9": 9}])
        self.assertEqual(len(C.apply_records(raw, base_settings())), 5)
        self.assertEqual(list(C.apply_records(raw, base_settings(records="L1")).index), [1, 2, 3, 4])
        base = pd.DataFrame({"V8": raw["V8"], "V9": C.apply_missing(raw["V9"], META, "V9"),
                             "POP": [4, 4, np.nan, np.nan, np.nan]})
        self.assertEqual(list(P.family_filter(base, "org", base_settings())), [True] * 5)
        self.assertEqual(list(P.family_filter(base, "mkt", base_settings())), [True, True, False, True, True])
        self.assertEqual(list(P.family_filter(base, "mkt", base_settings(market_sample="L1"))),
                         [True, False, False, True, False])
        self.assertEqual(list(P.family_filter(base, "mkt", base_settings(market_requires_pop="L1"))),
                         [True, True, False, False, False])

    def test_required_vars(self):
        s = base_settings()
        self.assertEqual(P.required_vars("org", [], s), ["POP"] + C.HRM_TERMS + C.ORG_CONTROLS + ["IND_GROUP"])
        self.assertEqual(P.required_vars("mkt", ["STAFF"], s, common=False), ["PMP", "STAFF"] + C.MKT_CONTROLS + ["IND_GROUP"])
        self.assertIn("WEIGHT", P.required_vars("org", [], base_settings(weights="L1")))
        self.assertNotIn("NONPROF", P.required_vars("mkt", [], s))

    def test_staff_train_standardization_in_frame(self):
        # three rows with staff counts; z-scores use frame-wide mean/sd (ddof=1) under L0, ddof=0 under L3
        rows = [{"V62": 1, "V97": 1, "V131": 1, "V145": 1, "V157": 1, "V172": 1},
                {"V62": math.e, "V97": math.e, "V131": math.e, "V145": 1, "V157": math.e, "V172": 2},
                {"V62": math.e ** 2, "V97": 998, "V131": 0, "V145": 2, "V157": 5, "V172": 3}]
        raw = raw_frame(rows)
        raw["V8"] = 1.0
        raw["V43"] = 10.0
        cw = {10: ["01"]}
        fams = P.build_family_frames(raw, META, cw, base_settings())
        fr = fams["org"]["frame"]
        logs = np.array([0.0, 1.0, 2.0])
        z62 = (logs - logs.mean()) / logs.std(ddof=1)
        z97 = (logs[:2] - logs[:2].mean()) / logs[:2].std(ddof=1)
        # row 0: mean of z62[0], z97[0], z131[0] (V131 identical to V62 pattern for rows 0,1; row 2 missing)
        z131 = z97
        self.assertAlmostEqual(fr["STAFF"][0], np.mean([z62[0], z97[0], z131[0]]))
        self.assertAlmostEqual(fr["STAFF"][2], z62[2])  # only V62 valid in row 2
        fams3 = P.build_family_frames(raw, META, cw, base_settings(z_reference="L3"))
        z62p = (logs - logs.mean()) / logs.std(ddof=0)
        z97p = (logs[:2] - logs[:2].mean()) / logs[:2].std(ddof=0)
        self.assertAlmostEqual(fams3["org"]["frame"]["STAFF"][0], np.mean([z62p[0], z97p[0], z97p[0]]))


if __name__ == "__main__":
    unittest.main()
