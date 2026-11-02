"""Deterministic scoring criteria for twenge2010 (implements sealed/scoring_rules.json v1).

Written before any implementation output was read. Pure functions; tested in checks/scripts/test_scoring_lib.py.
"""
import math

AGREE, GREY, MISMATCH, NA = "agree", "grey", "mismatch", "not_assessable"


def interval(value, decimals):
    h = 0.5 * 10 ** (-decimals)
    return (value - h, value + h)


def diff_interval(a, b):
    """Interval of b - a for intervals a, b."""
    return (b[0] - a[1], b[1] - a[0])


def distance(x, iv):
    lo, hi = iv
    if lo <= x <= hi:
        return 0.0
    return lo - x if x < lo else x - hi


def magnitude_band(x, iv, se):
    if se is None or not (se > 0):
        return NA, None
    z = distance(x, iv) / se
    if z <= 2:
        return AGREE, z
    if z <= 4:
        return GREY, z
    return MISMATCH, z


def sign_check(x, iv, se):
    """Sign criterion: not assessable if the published interval contains 0."""
    lo, hi = iv
    if lo <= 0 <= hi:
        return NA
    pub_sign = 1 if lo > 0 else -1
    if x == 0 or math.copysign(1, x) == pub_sign:
        return AGREE
    band, _ = magnitude_band(x, iv, se)
    # scoring_rules.json: mismatch only if the distance exceeds the grey bound (4 SE); otherwise agree
    return MISMATCH if band == MISMATCH else AGREE


def se_d(d_pub, n1, n2):
    return math.sqrt((n1 + n2) / (n1 * n2) + d_pub ** 2 / (2 * (n1 + n2)))


def p_band(p):
    if p is None or (isinstance(p, float) and math.isnan(p)):
        return None
    return 1 if p < 0.01 else 2 if p < 0.05 else 3 if p < 0.10 else 4


def published_band_set(n_stars):
    if n_stars >= 2:
        return {1}
    if n_stars == 1:
        return {2}
    return {3, 4}


def inference_check(p_rec, n_stars):
    """Returns (status, band_distance). Stronger reconstructed significance than a published significance claim is not a failure."""
    b = p_band(p_rec)
    if b is None:
        return NA, None
    pub = published_band_set(n_stars)
    dist = min(abs(b - x) for x in pub)
    if n_stars >= 1 and b < min(pub):
        dist = 0
    if dist >= 2:
        return MISMATCH, dist
    return AGREE, dist


def claim_outcome(impl_agreed, crit, inconsistent_targets=False, not_attemptable=False):
    """Precedence from scoring_rules.json. crit: dict name -> status (AGREE/GREY/MISMATCH/NA)."""
    if not_attemptable:
        return "not_attemptable", "core_input_or_all_implementations_failed"
    if not impl_agreed:
        return "indeterminate", "implementation_disagreement"
    vals = [v for v in crit.values() if v != NA]
    if not vals:
        return "indeterminate", "no_assessable_criterion"
    if MISMATCH in vals:
        which = ",".join(k for k, v in crit.items() if v == MISMATCH)
        return "discrepant_provisional", which
    if GREY in vals:
        return "indeterminate", "grey_zone:" + ",".join(k for k, v in crit.items() if v == GREY)
    if inconsistent_targets:
        return "indeterminate", "inconsistent_targets"
    return "consistent", "all_assessable_criteria_agree"


def rq_outcome(contrast_outcomes, contrast_sign_mismatch):
    """contrast_outcomes: list of 3 (outcome, subcode); contrast_sign_mismatch: list of 3 bools."""
    outs = [o for o, _ in contrast_outcomes]
    if all(o == "consistent" for o in outs):
        return "consistent", "all_contrasts_consistent"
    if any(contrast_sign_mismatch) or sum(o == "discrepant_provisional" for o in outs) >= 2:
        return "discrepant_provisional", "sign_mismatch" if any(contrast_sign_mismatch) else "two_or_more_contrasts_discrepant"
    if any(o == "not_attemptable" for o in outs):
        return "not_attemptable", "contrast_not_attemptable"
    sub = ";".join(s for o, s in contrast_outcomes if o != "consistent")
    return "indeterminate", "mixed:" + sub


def paper_outcome(rq_outcomes, lower_tier_outcomes):
    outs = [o for o, _ in rq_outcomes]
    if any(o in ("indeterminate", "not_attemptable") for o in outs):
        return "indeterminate", "indeterminate_focal_evidence"
    nd = sum(o == "discrepant_provisional" for o in outs)
    lower_disc = any(o == "discrepant_provisional" for o in lower_tier_outcomes)
    if nd == 0:
        return ("partially_reproduced", "focal_consistent_lower_tier_discrepant") if lower_disc else ("fully_reproduced", "all_focal_consistent")
    if nd >= 3:
        return "not_reproduced", f"{nd}_of_5_rq_discrepant_provisional"
    return "mixed_focal", f"{nd}_of_5_rq_discrepant_provisional"
