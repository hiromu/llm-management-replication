"""Synthetic rule tests for scoring_lib (run before any implementation output is read).
~/.venv/bin/python -I checks/scripts/test_scoring_lib.py
"""
import sys, json
sys.path.insert(0, "checks/scripts")
from scoring_lib import *

res = []


def check(name, got, want):
    ok = got == want
    res.append({"test": name, "got": str(got), "want": str(want), "ok": ok})


iv = interval(0.35, 2)
check("interval", tuple(round(x, 6) for x in iv), (0.345, 0.355))
check("distance inside", distance(0.35, iv), 0.0)
se = se_d(0.35, 3000, 2500)
check("magnitude agree", magnitude_band(0.35 + 0.005 + 1.5 * se, iv, se)[0], AGREE)
check("magnitude grey", magnitude_band(0.35 + 0.005 + 3 * se, iv, se)[0], GREY)
check("magnitude mismatch", magnitude_band(0.35 + 0.005 + 5 * se, iv, se)[0], MISMATCH)
check("magnitude no se", magnitude_band(0.3, iv, None)[0], NA)
check("sign NA when interval spans zero", sign_check(-0.2, interval(0.00, 2), se), NA)
check("sign agree", sign_check(0.1, iv, se), AGREE)
check("sign mismatch far", sign_check(-0.3, iv, se), MISMATCH)
check("sign opposite but within 2se", sign_check(-0.001, interval(0.01, 2), 0.03), AGREE)
check("planted inconsistent sign -.05 vs .05 (within 4 SE -> agree per rule text)", sign_check(0.05, interval(-0.05, 2), 0.026), AGREE)
check("p band", [p_band(x) for x in (0.001, 0.02, 0.07, 0.5)], [1, 2, 3, 4])
check("inference *** vs p=.2", inference_check(0.2, 3)[0], MISMATCH)
check("inference * vs p=.07 adjacent", inference_check(0.07, 1)[0], AGREE)
check("inference ns vs p=.001", inference_check(0.001, 0)[0], MISMATCH)
check("inference ns vs p=.03 adjacent", inference_check(0.03, 0)[0], AGREE)
check("inference * vs stronger p", inference_check(1e-9, 1), (AGREE, 0))
check("null data: p=.6 vs ns", inference_check(0.6, 0)[0], AGREE)
check("outcome consistent", claim_outcome(True, {"sign": AGREE, "magnitude": AGREE})[0], "consistent")
check("outcome impl disagreement", claim_outcome(False, {"sign": AGREE})[0], "indeterminate")
check("outcome grey", claim_outcome(True, {"sign": AGREE, "magnitude": GREY})[0], "indeterminate")
check("outcome discrepant", claim_outcome(True, {"sign": MISMATCH, "magnitude": GREY})[0], "discrepant_provisional")
check("outcome unreachable target", claim_outcome(True, {"sign": AGREE, "magnitude": MISMATCH})[0], "discrepant_provisional")
check("outcome all NA", claim_outcome(True, {"sign": NA, "magnitude": NA})[0], "indeterminate")
check("outcome not attemptable", claim_outcome(True, {}, not_attemptable=True)[0], "not_attemptable")
c = ("consistent", "x"); d = ("discrepant_provisional", "m"); g = ("indeterminate", "grey_zone:magnitude")
check("rq consistent", rq_outcome([c, c, c], [False] * 3)[0], "consistent")
check("rq one discrepant magnitude", rq_outcome([c, d, c], [False] * 3)[0], "indeterminate")
check("rq sign mismatch", rq_outcome([c, d, c], [False, True, False])[0], "discrepant_provisional")
check("rq two discrepant", rq_outcome([d, d, c], [False] * 3)[0], "discrepant_provisional")
R = ("consistent", ""); D = ("discrepant_provisional", ""); I = ("indeterminate", "")
check("paper full", paper_outcome([R] * 5, ["consistent"])[0], "fully_reproduced")
check("paper partial", paper_outcome([R] * 5, ["discrepant_provisional"])[0], "partially_reproduced")
check("paper indeterminate", paper_outcome([R, R, I, R, R], [])[0], "indeterminate")
check("paper mixed", paper_outcome([R, D, R, R, R], [])[0], "mixed_focal")
check("paper not reproduced", paper_outcome([D, D, D, R, R], [])[0], "not_reproduced")
fails = [r for r in res if not r["ok"]]
json.dump({"n_tests": len(res), "n_failed": len(fails), "tests": res}, open("checks/scoring_rule_tests.json", "w"), indent=1)
print(len(res), "tests;", len(fails), "failed")
for f in fails:
    print(f)
