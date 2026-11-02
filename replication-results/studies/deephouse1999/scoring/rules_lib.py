"""Frozen term-level comparison rules (registry/scoring_rules_v1.json), shared by score.py and claim_outcomes.py."""
import numpy as np

def band(p):
    return 0 if p < .01 else 1 if p < .05 else 2 if p < .10 else 3

def pub_band(stars):
    s = (stars or "").strip()
    return {"***": 0, "**": 0, "*": 1}.get(s, None)

def score_term(b, s, stars, prec_b, prec_s, est, se, p, direction=None):
    hb, hs = 0.5 * 10 ** -prec_b, 0.5 * 10 ** -prec_s
    lo, hi = b - hb, b + hb
    rec = {"pub_coef": b, "pub_se": s, "pub_stars": stars, "rec_coef": est, "rec_se": se, "rec_p2": p}
    # one-sided p in the published direction (descriptive)
    t = est / se if se else float("nan")
    rec["rec_t"] = t
    # sign
    if lo <= 0 <= hi:
        rec["sign"] = "not_assessed"
    else:
        rec["sign"] = "agree" if np.sign(est) == np.sign(b) else "opposite"
    # inference
    pb = pub_band(stars)
    rb = band(p)
    rec["rec_band"] = ["p<.01", ".01-.05", ".05-.10", ">=.10"][rb]
    if pb is not None:
        rec["pub_band"] = ["p<.01", ".01-.05"][pb]
        k = rb - pb
        rec["inference"] = "agree" if k <= 0 else "one_band_weaker" if k == 1 else "two_plus_bands_weaker"
    else:
        rec["pub_band"] = "p>=.05"
        rec["inference"] = "agree" if rb >= 2 else "one_band_contradiction" if rb == 1 else "two_band_contradiction"
    # magnitude in published-SE units, benefit of rounding
    if s is None:
        rec["d_se_units"] = None; rec["magnitude"] = "not_audited"
    else:
        dist = 0.0 if lo <= est <= hi else min(abs(est - lo), abs(est - hi))
        d = dist / (s + hs)
        rec["d_se_units"] = d
        rec["magnitude"] = "consistent" if d <= 1.5 else "grey" if d <= 3.0 else "outside"
    rec["relative_diff"] = (est - b) / abs(b) if b else None
    bad = (rec["sign"] == "opposite" or rec["inference"] in ("two_plus_bands_weaker", "two_band_contradiction")
           or rec["magnitude"] == "outside")
    good = (rec["sign"] in ("agree", "not_assessed") and rec["inference"] == "agree"
            and rec["magnitude"] in ("consistent", "not_audited"))
    rec["term_outcome"] = "discrepant_candidate" if bad else "consistent" if good else "grey"
    return rec

