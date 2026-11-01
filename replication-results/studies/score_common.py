"""Rescore the six studies under the common rule (scoring_rules_common_v1.json).

Reads each study's existing scoring outputs; refits nothing. Writes
<study>/scoring/common_v1/{terms.csv,claims.csv,paper_record.json},
<study>/reports/common_rule_v1.md and common_v1_summary.{csv,md} here.
Frozen rules, original outputs, hash records and transcripts are not touched.

Run from this folder: python score_common.py
"""
import json
import math
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
RULES = {
    "common": dict(ok=1.5, grey=3.0, n_strict=True),
    "lenient": dict(ok=2.0, grey=4.0, n_strict=False),
}
STUDIES = {
    "deephouse1999": dict(name="Deephouse (1999)", v1_paper="indeterminate",
                          v1_rules="registry/scoring_rules_v1.json"),
    "holderness2012": dict(name="Holderness and Pontiff (2012)", v1_paper="partially reproduced",
                           v1_rules="sealed/scoring/scoring_rules_v1.json"),
    "lehman2011": dict(name="Lehman, Hahn, Ramanujam and Alge (2011)",
                       v1_paper="consistent (comparability mapping: partially reproduced)",
                       v1_rules="reconciliation/scoring_rules_v1.json"),
    "thebaud2015": dict(name="Thébaud (2015)", v1_paper="indeterminate",
                        v1_rules="reconciliation/frozen/scoring_rules.json and addenda v1_1, v1_2"),
    "twenge2010": dict(name="Twenge, Campbell, Hoffman and Lance (2010)", v1_paper="indeterminate",
                       v1_rules="sealed/scoring_rules.json"),
    "delaney1996": dict(name="Delaney and Huselid (1996)",
                        v1_paper="indeterminate (sample reconstruction; label-sensitive)",
                        v1_rules="checks/scoring_rules_v1.json"),
}
NOT_RESCORED = {
    "deephouse1999": "F tests (M2 vs M1, M3 vs M1, M3 vs M2).",
    "holderness2012": "Text-only robustness statements; three were not reproduced and human-confirmed under the study rule, which would make the paper partially reproduced. ROC comparisons and pseudo R2.",
    "lehman2011": "Publication diagnostics.",
    "thebaud2015": "Descriptive claims (Figures 1 to 3, Tables A1 and A2).",
    "twenge2010": "Fit, invariance and reliability diagnostics (10 claims): 3 consistent, 5 indeterminate, 2 discrepant_provisional under the study rule.",
    "delaney1996": "H2's four interaction-block F tests, which decide H2 under the study rule (all indeterminate on sample size); HRM-block F tests, R2 and N cells; descriptive Tables 1 and 2. H2 therefore has no rescored claim.",
}


def isnan(x):
    return x is None or (isinstance(x, float) and math.isnan(x))


def band_from_p(p):
    if isnan(p):
        return np.nan
    return 1 if p < .01 else 2 if p < .05 else 3 if p < .10 else 4


def sgn(x):
    if isnan(x) or x == 0:
        return None
    return 1 if x > 0 else -1


def term_outcome(r, rule):
    if isinstance(r.get("override"), str):
        return r["override"]
    if r.get("missing") is True:
        return "indeterminate"
    n_rel = 0 if isnan(r.get("n_rel")) else r["n_rel"]
    if rule["n_strict"] and abs(n_rel) > .15:
        return "indeterminate"
    fails, greys = [], []
    d = r.get("dist")
    if not isnan(d):
        if d > rule["grey"]:
            fails.append("magnitude")
        elif d > rule["ok"]:
            greys.append("magnitude")
    pb, rb = r.get("pub_band"), r.get("rec_band")
    pub_sig = not isnan(pb) and pb <= 3
    ps, rs = r.get("pub_sign"), r.get("rec_sign")
    if pub_sig and ps in (1, -1) and rs in (1, -1) and ps != rs:
        (fails if (not isnan(r.get("rec_p")) and r["rec_p"] < .10) else greys).append("sign")
    if pub_sig and not isnan(rb):
        if rb - pb >= 2:
            fails.append("inference")
        elif rb - pb == 1:
            greys.append("inference")
    if fails:
        return "indeterminate" if abs(n_rel) > .15 else "candidate"
    if greys:
        return "indeterminate"
    return "consistent"


def load(study):
    s = HERE / study
    rows = []
    if study == "deephouse1999":
        d = pd.read_csv(s / "scoring/run_v1/term_scores.csv")
        pubmap = {"p<.01": 1, ".01-.05": 2, ".05-.10": 3, "p>=.05": 4, ">=.10": 4}
        # Focal structure: H3 = Model 3 SD and SD^2 scored jointly; H2 = Model 2 SD.
        focal = {"T2.3.sd": "H3", "T2.3.sd2": "H3", "T2.2.sd": "H2"}
        for _, x in d.iterrows():
            rows.append(dict(table="Table 2" if x.target_id.startswith("T2") else "Text", claim=focal.get(x.target_id),
                             term=f"{x.model} {x.term}", origin=x.origin, pub=x.pub_coef, pub_se=x.pub_se,
                             rec=x.rec_coef, dist=x.d_se_units, pub_band=pubmap.get(x.pub_band, np.nan),
                             rec_band=band_from_p(x.rec_p2), pub_sign=sgn(x.pub_coef), rec_sign=sgn(x.rec_coef),
                             rec_p=x.rec_p2, n_rel=(x.n - 960) / 960, v1=x.term_outcome))
    elif study == "holderness2012":
        h = pd.read_csv(s / "scoring/claim_scores.csv")
        for _, x in h.iterrows():
            claim = f"{x.measure}, {x.group}" if x.tier == "focal" else None
            rows.append(dict(table=f"Table {x.family[1:]}", claim=claim, term=f"{x.target_id} {x.spec} {x.term}",
                             origin="O", pub=x.printed_value, pub_se=np.nan, rec=x.rec_me, dist=np.nan,
                             pub_band=band_from_p(x.printed_p + .005) if not isnan(x.printed_p) else np.nan,
                             rec_band=band_from_p(x.rec_p), pub_sign=sgn(x.printed_value), rec_sign=sgn(x.rec_me),
                             rec_p=x.rec_p, n_rel=(x.n_rec - x.n_pub) / x.n_pub, v1=x.outcome))
    elif study == "lehman2011":
        l = pd.read_csv(s / "runs/score_v1/target_comparisons_all_cells.csv")
        l = l[l.cell == "U1=0|U2=0|U3=0|U4=0|U5=0|U6=0|U7=0|U8=0"]
        focal = {"T5|M2|perf_below": "H1A", "T5|M2|perf_below_sq": "H1A", "T5|M2|perf_above": "H1B",
                 "T5|M3|perf_below_x_min": "H2", "T5|M3|perf_below_sq_x_min": "H2", "T5|M3|perf_above_x_min": "H3"}
        for _, x in l.iterrows():
            tab = x.key.split("|")[0]
            pub_scale = math.log(x.pub_value) if tab == "T5" else x.pub_value  # Table 5 prints odds ratios
            rows.append(dict(table=f"Table {tab[1:]}", claim=focal.get(x.key), term=x.key, origin="O",
                             pub=x.pub_value, pub_se=x.pub_se, rec=x.reconstructed, dist=x.delta_se,
                             pub_band=x.pub_band, rec_band=band_from_p(x.p_native), pub_sign=sgn(round(pub_scale, 6)),
                             rec_sign=sgn(x.reconstructed), rec_p=x.p_native, n_rel=(21540 - 22603) / 22603,
                             v1=x.outcome))
    elif study == "thebaud2015":
        t = pd.read_csv(s / "reports/exports/term_comparisons.csv")
        cc = pd.read_csv(s / "reports/exports/claim_comparisons.csv")
        # Hypothesis-deciding claims as defined in the study report.
        hyp = {"F02": "H1", "F05": "H2", "F06": "H2", "F08": "H3", "F09": "H3", "F10": "H3", "F11": "H3"}
        focal = {}
        for _, c in cc.iterrows():
            if c.claim in hyp:
                for term in str(c.terms).split(";"):
                    focal[(c.model, term.strip())] = hyp[c.claim]
        for _, x in t.iterrows():
            table = "Table 1" if x.model in ("M1", "M2", "M3") else "Table 2" if x.model.startswith("M") else "Table A3"
            rows.append(dict(table=table, claim=focal.get((x.model, x.term)), term=f"{x.model} {x.term}", origin="O",
                             pub=x.pub_value, pub_se=x.pub_se, rec=x.rec_value, dist=x.distance_pub_se,
                             pub_band=x.pub_band + 1,  # file bands are 0-indexed
                             rec_band=band_from_p(x.rec_p), pub_sign=sgn(x.pub_value), rec_sign=sgn(x.rec_value),
                             rec_p=x.rec_p, n_rel=(x.n_rec - x.n_pub) / x.n_pub if not isnan(x.n_rec) else np.nan,
                             missing=bool(pd.isna(x.rec_value)), v1=x.outcome))
    elif study == "twenge2010":
        w = pd.read_csv(s / "reports/claim_comparisons.csv")
        for _, x in w.iterrows():
            if x.tier.startswith("identification"):
                continue
            focal = x.tier == "focal"
            # Published Ns are within 2% of the rebuilt form samples; SEM inference is not audited.
            rows.append(dict(table="Table 1", claim=x.claim.split()[2] if focal else None, term=x.claim, origin="O",
                             pub=x.published, pub_se=np.nan, rec=x.reconstructed, dist=x.distance_se,
                             pub_band=np.nan, rec_band=np.nan, pub_sign=None, rec_sign=None, rec_p=x.native_p,
                             n_rel=0.02, override="indeterminate" if "inconsistent" in str(x.subcode) else None,
                             v1=x.outcome))
    elif study == "delaney1996":
        d = pd.read_csv(s / "reports/data/claim_cell_comparisons.csv")
        d = d[d.quantity == "coef"]
        n_pub, n_rec = {"org": 590, "mkt": 373}, {"org": 361, "mkt": 239}
        # H1 primary cells as defined in the study report; H2 rests on F tests, which are not rescored.
        h1 = {("org_M2", "TRAIN"), ("org_M2", "INCENT"), ("org_M3", "TRAIN"), ("org_M3", "INCENT"),
              ("org_M3", "VHIER"), ("mkt_M7", "STAFF"), ("mkt_M7", "INCENT"), ("mkt_M8", "STAFF"),
              ("mkt_M8", "TRAIN"), ("mkt_M8", "INCENT")}
        for _, x in d.iterrows():
            fam = x.model_id.split("_")[0]
            # The article's stars are one-tailed; the study's bands follow them and are 0-indexed.
            rec_p = (2 * min(x.origin_p_upper, x.origin_p_lower)
                     if not (isnan(x.origin_p_upper) or isnan(x.origin_p_lower)) else np.nan)
            rows.append(dict(table="Table 3" if fam == "org" else "Table 4",
                             claim="H1" if (x.model_id, x.term) in h1 else None,
                             term=f"{x.model_id} {x.term}", origin="O", pub=x.value, pub_se=x.se,
                             rec=x.origin_est, dist=x.origin_m, pub_band=x.origin_pub_band + 1,
                             rec_band=x.origin_recon_band + 1, pub_sign=sgn(x.value), rec_sign=sgn(x.origin_est),
                             rec_p=rec_p, n_rel=(n_rec[fam] - n_pub[fam]) / n_pub[fam],
                             missing=bool(pd.isna(x.origin_est)), v1=x.outcome))
    return pd.DataFrame(rows)


def fmt(x):
    if isinstance(x, str):
        return x
    if isnan(x):
        return ""
    return f"{x:.3g}" if abs(x) < 1000 else f"{x:,.0f}"


def collapse(g):
    first = g.iloc[0]
    out = dict(table=first.table, tier="focal" if isinstance(first.claim, str) else "lower",
               claim=first.claim if isinstance(first.claim, str) else "", origins=" / ".join(g.origin),
               published=fmt(first.pub), published_se=fmt(first.pub_se),
               reconstructed=" / ".join(fmt(v) for v in g.rec), distance_se=" / ".join(fmt(v) for v in g.dist),
               n_gap=fmt(first.n_rel), v1_outcome=" / ".join(str(v) for v in g.v1))
    for name in RULES:
        vals = set(g[name])
        out[name] = vals.pop() if len(vals) == 1 else "indeterminate"
    return pd.Series(out)


def claim_outcome(vals):
    if all(v == "consistent" for v in vals):
        return "consistent"
    if any(v == "candidate" for v in vals):
        return "candidate"
    return "indeterminate"


def paper_outcome(terms, name):
    focal = terms[terms.tier == "focal"]
    claims = focal.groupby("claim", sort=False)[name].apply(lambda s: claim_outcome(list(s)))
    if (claims == "consistent").all():
        return claims, ("partially reproduced" if (terms[terms.tier == "lower"][name] == "candidate").any()
                        else "consistent")
    if (claims == "candidate").any():
        return claims, "not reproduced (unverified)"
    return claims, "indeterminate"


def counts(terms, name):
    tab = pd.crosstab(terms.table, terms[name]).reindex(
        columns=["consistent", "indeterminate", "candidate"], fill_value=0)
    tab["total"] = tab.sum(axis=1)
    return tab


def md_table(df):
    cols = list(df.columns)
    lines = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    lines += ["| " + " | ".join(str(v) for v in row) + " |" for row in df.itertuples(index=False)]
    return "\n".join(lines)


def report(study, meta, terms, claims, papers):
    tabs = {name: counts(terms, name) for name in RULES}
    by_table = pd.DataFrame({
        "Table": tabs["common"].index,
        "Consistent": tabs["common"].consistent.values,
        "Indeterminate": tabs["common"].indeterminate.values,
        "Candidate": tabs["common"].candidate.values,
        "Total": tabs["common"].total.values,
        "Lenient (C / I / Cand)": [f"{r.consistent} / {r.indeterminate} / {r.candidate}"
                                   for r in tabs["lenient"].itertuples()],
    })
    focal = terms[terms.tier == "focal"][["claim", "term", "published", "reconstructed", "distance_se",
                                          "v1_outcome", "common", "lenient"]]
    focal.columns = ["Claim", "Term", "Published", "Reconstructed", "Distance (SE)", "Study rule",
                     "Common rule", "Lenient"]
    claim_tab = claims.rename(columns={"claim": "Claim", "common": "Common rule", "lenient": "Lenient"})
    return f"""# Common rule v1 (post hoc): {meta['name']}

This file rescores the study's existing estimates under one rule shared by all six studies: [scoring_rules_common_v1.json](../../scoring_rules_common_v1.json), applied by [score_common.py](../../score_common.py). The rule was written on 28 October 2026, after every study's results were known. No estimate was refitted. The study's frozen rules ({meta['v1_rules']}) and its [replication report](replication_report.md) remain the protocol outcome.

## Outcome

| Level | Study rule (frozen) | Common rule | Lenient variant |
|---|---|---|---|
| Paper | {meta['v1_paper']} | {papers['common']} | {papers['lenient']} |

A candidate is unverified: no study had an adversarial review from a model family independent of every implementer. "Not reproduced (unverified)" is therefore formally indeterminate.

{md_table(claim_tab)}

## Estimates by table

{md_table(by_table)}

## Focal estimates

Distance is from the published rounding interval in published-SE units.{' Values separated by "/" are the two reader origins.' if study == 'deephouse1999' else ''}

{md_table(focal)}

## Not rescored

{NOT_RESCORED[study]} Their study-rule outcomes stand.

Every rescored term: [scoring/common_v1/terms.csv](../scoring/common_v1/terms.csv).
"""


def main():
    summary = []
    for study, meta in STUDIES.items():
        raw = load(study)
        for name, rule in RULES.items():
            raw[name] = [term_outcome(r, rule) for r in raw.to_dict("records")]
        terms = raw.groupby("term", sort=False).apply(collapse, include_groups=False).reset_index()
        terms = terms[["table", "tier", "claim", "term", "origins", "published", "published_se", "reconstructed",
                       "distance_se", "n_gap", "v1_outcome", "common", "lenient"]]
        papers, claim_cols = {}, {}
        for name in RULES:
            c, p = paper_outcome(terms, name)
            claim_cols[name], papers[name] = c, p
        claims = pd.DataFrame(claim_cols).reset_index()
        out = HERE / study / "scoring/common_v1"
        out.mkdir(parents=True, exist_ok=True)
        terms.to_csv(out / "terms.csv", index=False)
        claims.to_csv(out / "claims.csv", index=False)
        record = dict(rule="../../scoring_rules_common_v1.json", status="post hoc", study_rule_paper=meta["v1_paper"],
                      paper=papers, claims={n: claim_cols[n].to_dict() for n in RULES},
                      terms_by_table={n: counts(terms, n).to_dict(orient="index") for n in RULES})
        (out / "paper_record.json").write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n")
        (HERE / study / "reports/common_rule_v1.md").write_text(report(study, meta, terms, claims, papers))
        tc = counts(terms, "common").sum()
        summary.append(dict(study=meta["name"], folder=study, study_rule=meta["v1_paper"],
                            common=papers["common"], lenient=papers["lenient"],
                            claims_common="; ".join(f"{k} {v}" for k, v in claim_cols["common"].items()),
                            terms_consistent=tc.consistent, terms_indeterminate=tc.indeterminate,
                            terms_candidate=tc.candidate, terms_total=tc.total))
    s = pd.DataFrame(summary)
    s.to_csv(HERE / "common_v1_summary.csv", index=False)
    view = s[["study", "study_rule", "common", "lenient", "terms_consistent", "terms_indeterminate",
              "terms_candidate", "terms_total"]]
    view.columns = ["Paper", "Study rule (frozen)", "Common rule", "Lenient", "Consistent terms",
                    "Indeterminate terms", "Candidate terms", "Total terms"]
    (HERE / "common_v1_summary.md").write_text(f"""# Common rule v1 (post hoc): six studies

All six studies rescored under [scoring_rules_common_v1.json](scoring_rules_common_v1.json) by [score_common.py](score_common.py). The rule was written on 28 October 2026, after the results were known; each study's frozen rule remains its protocol outcome. Per-study detail is in each study's `reports/common_rule_v1.md`.

{md_table(view)}

Claims under the common rule:

{chr(10).join(f"- {r.study}: {r.claims_common}" for r in s.itertuples())}

A candidate is unverified. "Not reproduced (unverified)" is formally indeterminate.
""")
    print(view.to_string(index=False))


if __name__ == "__main__":
    main()
