"""Claim and label ledgers with raw agreement and Gwet's AC1, computed before any clarification round."""
import csv, json, os, re, collections
STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = lambda r, f: json.load(open(os.path.join(STUDY, f"readers/{r}/initial/{f}.json")))
OUT = os.path.join(STUDY, "reconciliation")
def ac1(pairs, cats):
    n = len(pairs)
    if n == 0: return None
    pa = sum(a == b for a, b in pairs) / n
    q = len(cats)
    if q < 2: return None
    pi = {c: (sum(a == c for a, _ in pairs) + sum(b == c for _, b in pairs)) / (2 * n) for c in cats}
    pe = sum(p * (1 - p) for p in pi.values()) / (q - 1)
    return None if pe == 1 else (pa - pe) / (1 - pe)
def canon_fable(c):
    i = c["claim_id"]
    m = {"C1.01": "S1.manipcheck", "C1.02": "S1.interaction.you_grant", "C1.03": "S1.interaction.prom_voice", "C1.04": "S1.interaction.proh_voice",
         "C1.05": "S1.paired.you_grant", "C1.06": "S1.paired.prom_voice", "C1.07": "S1.paired.proh_voice", "C1.08": "S1.descriptives", "C1.09": "S1.reliability", "C1.10": "S1.sample",
         "C1.11": "S1.gender_within", "C1.12": "S1.gender_cells", "C1.13": "S1.reliability", "C2.01": "S2.t.you_grant", "C2.02": "S2.t.prom_voice", "C2.03": "S2.t.proh_voice",
         "C2.16": "S2.serial.val_align", "C2.17": "S2.serial.relconcerns", "C2.18": "S2.descriptives", "C2.19": "S2.reliability", "C2.20": "S2.sample", "C2.21": "S2.gender",
         "C3.16": "S3.descriptives", "C3.17": "S3.reliability", "C3.18": "S3.sample", "C4.01": "S4.M1", "C4.02": "S4.M2", "C4.03": "S4.M3", "C4.04": "S4.sample", "C4.05": "S4.descriptives",
         "C4.06": "S4.med.simultaneous", "C4.07": "S4.med.independent", "C4.08": "S4.sample", "C4.09": "S4.fit", "C4.10": "S4.controls"}
    if i in m: return m[i]
    n = int(i.split(".")[1])
    if i.startswith("C2"):
        o = ["you_grant"] * 4 + ["prom_voice"] * 4 + ["proh_voice"] * 4; med = ["benev", "val_align", "relconcerns", "integ", "benev", "val_align", "relconcerns", "integ", "benev", "relconcerns", "val_align", "integ"]
        return f"S2.ind.{o[n-4]}.{med[n-4]}"
    if i.startswith("C3"):
        if n <= 15:
            oc = ["you_grant", "prom_voice", "proh_voice"][(n - 1) // 5 ]; t = ["relationship", "history", "interaction", "H1", "H3"][(n - 1) % 5]
            return f"S3.{'contrast' if t in('H1','H3') else 'anova'}.{oc}.{t}"
        return f"S3.mechanism.{ {19:'benev',20:'integ',21:'val_align',22:'relconcerns'}[n]}"
    raise KeyError(i)
def canon_astra(c):
    i = c["claim_id"]
    short = {"benev_trust_broker": "benev", "integ_trust_broker": "integ", "val_align_part_broker": "val_align", "relconcerns_with_broker": "relconcerns"}
    m = re.match(r"S(\d)_description$", i)
    if m: return f"S{m.group(1)}.descriptives"
    m = re.match(r"S(\d)_reliability$", i)
    if m: return f"S{m.group(1)}.reliability"
    if i == "S1_loyal_comb": return "S1.manipcheck"
    m = re.match(r"S1_(you_grant|prom_voice|proh_voice)$", i)
    if m: return f"S1.paired.{m.group(1)}"
    m = re.match(r"S1_interaction_(\w+)$", i)
    if m: return f"S1.interaction.{m.group(1)}"
    m = re.match(r"S2_(you_grant|prom_voice|proh_voice)$", i)
    if m: return f"S2.t.{m.group(1)}"
    m = re.match(r"S2_ind_(you_grant|prom_voice|proh_voice)_(\w+)$", i)
    if m: return f"S2.ind.{m.group(1)}.{short[m.group(2)]}"
    m = re.match(r"S2_serial_(\w+)$", i)
    if m: return f"S2.serial.{'val_align' if 'val' in m.group(1) else 'relconcerns'}"
    m = re.match(r"S3_anova_(you_grant|prom_voice|proh_voice)_(relationship_history|relationship|history)$", i)
    if m: return f"S3.anova.{m.group(1)}.{'interaction' if m.group(2)=='relationship_history' else m.group(2)}"
    m = re.match(r"S3_H([13])_(you_grant|prom_voice|proh_voice)$", i)
    if m: return f"S3.contrast.{m.group(2)}.H{m.group(1)}"
    m = re.match(r"S3_(anova|H[13])_(benev_trust_broker|integ_trust_broker|val_align_part_broker|relconcerns_with_broker)", i)
    if m: return f"S3.mechanism.{short[m.group(2)]}"
    m = re.match(r"S4_(M\d)_LoyalRequestor$", i)
    if m: return f"S4.{m.group(1)}"
    if re.match(r"S4_M\d_fit$", i): return "S4.fit"
    if re.match(r"S4_M\d_", i): return "S4.controls"
    m = re.match(r"S4_ind_(simultaneous|independent)_", i)
    if m: return f"S4.med.{m.group(1)}"
    if i.startswith("S1_gender_loyalty"): return "S1.gender_within"
    if i.startswith("S1_gender_difference") or i == "S1_gender_summary": return "S1.gender_cells"
    if i.startswith("S2_gender"): return "S2.gender"
    if i == "S4_summary_table_mediation": return "S4.overview_table_mediation_mark"
    raise KeyError(i)
fa = collections.defaultdict(set); ab = collections.defaultdict(set)
for c in R("fable", "claim_map"): fa[canon_fable(c)].add(c["tier"])
for c in R("astra", "claim_map"): ab[canon_astra(c)].add(c["tier"])
rows, pairs = [], []
for k in sorted(set(fa) | set(ab)):
    ta, tb = "/".join(sorted(fa.get(k, []))) or None, "/".join(sorted(ab.get(k, []))) or None
    if ta and tb:
        pairs.append((ta, tb)); final = ta if ta == tb else "uncertain"
        d = "agree" if ta == tb else "tier label differs: tier uncertain, not counted as focal in aggregation"
    else:
        final = ta or tb; d = "structure from one reader: retained"
    rows.append([k, ta, tb, final, d])
with open(os.path.join(OUT, "claims_ledger.csv"), "w", newline="") as fh:
    w = csv.writer(fh); w.writerow(["claim_key", "tier_fable", "tier_astra", "tier_reconciled", "decision"]); w.writerows(rows)
L = [ # level, dataset, label_fable, label_astra
 ("attention: exclude on inferred key (attn == wrongdoing_num)", 1, "equivalent", "uncertain"), ("attention: no filter", 1, "uncertain", None), ("attention: documented rule with no executable form (not runnable)", 1, None, "equivalent"),
 ("attention: exclude if either check fails", 2, "equivalent", "uncertain"), ("attention: exclude only if both fail", 2, "uncertain", None), ("attention: no filter", 2, "uncertain", None), ("attention: documented rule with no executable form (not runnable)", 2, None, "equivalent"),
 ("attention: exclude if any of four checks fails", 3, "equivalent", "uncertain"), ("attention: comp1-comp3 only", 3, "uncertain", None), ("attention: no filter", 3, "uncertain", None), ("attention: documented rule with no executable form (not runnable)", 3, None, "equivalent"),
 ("composite: item mean", 1, "equivalent", "uncertain"), ("composite: literal sum", 1, "non_equivalent", "uncertain"), ("composite: deposited column", 1, None, "equivalent"),
 ("composite: item mean", 2, "equivalent", "uncertain"), ("composite: literal sum", 2, "non_equivalent", "uncertain"), ("composite: deposited column", 2, None, "equivalent"),
 ("composite: item mean", 3, "equivalent", "uncertain"), ("composite: literal sum", 3, "non_equivalent", "uncertain"), ("composite: deposited column", 3, None, "equivalent"),
 ("loyalty predictor: continuous", 4, "equivalent", "equivalent"), ("loyalty predictor: strong dichotomy", 4, "non_equivalent", "non_equivalent"), ("loyalty predictor: exponential", 4, "non_equivalent", "non_equivalent"),
 ("paired test: paired t", 1, "equivalent", None), ("paired test: within main effect of mixed ANOVA", 1, "uncertain", None), ("paired test: mixed model", 1, "uncertain", None),
 ("effect size: d from condition SDs", 1, "equivalent", None), ("effect size: dz", 1, "non_equivalent", None),
 ("t variance: Welch", 2, "equivalent", None), ("t variance: Student", 2, "equivalent", None), ("indirect interval: bias-corrected bootstrap", 2, "equivalent", None), ("indirect interval: delta/Wald", 2, "uncertain", None), ("indirect interval: percentile bootstrap", 2, "equivalent", None),
 ("mediator entry: simultaneous", 2, "equivalent", None), ("mediator entry: single-mediator", 2, "non_equivalent", None),
 ("accused integrity item 3: as dictionary", 2, None, "equivalent"), ("accused integrity item 3: reversed as preregistered", 2, None, "uncertain"),
 ("contrast error: full-model pooled", 3, "equivalent", None), ("contrast error: Student two cells", 3, "uncertain", None), ("contrast error: Welch two cells", 3, "uncertain", None),
 ("SS: Type III", 3, "equivalent", None), ("SS: Type II", 3, "uncertain", None), ("SS: Type I", 3, "non_equivalent", None), ("eta2: partial", 3, "equivalent", None), ("eta2: classical", 3, "non_equivalent", None),
 ("house loyalty: covariate", 4, "equivalent", None), ("house loyalty: focal predictor in place of broker loyalty", 4, "non_equivalent", None), ("logit SE: model-based", 4, "equivalent", None), ("logit SE: sandwich", 4, "uncertain", None),
 ("mediation binary outcome: as stated, link unresolved", 4, "equivalent", None), ("mediation binary outcome: logistic", 4, "uncertain", None), ("mediation binary outcome: linear probability", 4, "uncertain", None),
 ("duration unit: semesters", 4, None, "equivalent"), ("duration unit: months (no column, unavailable)", 4, None, "non_equivalent"),
 ("moral-intensity anchors: appendix", 1, None, "equivalent"), ("moral-intensity anchors: dictionary", 1, None, "uncertain")]
lp, lrows = [], []
for lev, ds, a, b in L:
    if a and b:
        lp.append((a, b)); fin = a if a == b else "uncertain"
    else: fin = a or b
    lrows.append([lev, ds, a, b, fin, "both" if a and b else "one reader"])
with open(os.path.join(OUT, "labels_ledger.csv"), "w", newline="") as fh:
    w = csv.writer(fh); w.writerow(["level", "dataset", "label_fable", "label_astra", "label_reconciled", "structure"]); w.writerows(lrows)
sealed = json.load(open(os.path.join(STUDY, "sealed/targets/targets_reconciled.json")))
tc = collections.Counter(v["status"] for v in sealed.values())
tp = [(a, b) for _, _, _, _, a, b in []]
TIERS = ["focal", "identification_or_inference_diagnostic", "robustness", "descriptive", "nuisance"]
res = {"timing": "initial outputs, before any clarification; none was requested",
 "claims": {"union_keys": len(rows), "both_readers": len(pairs), "raw_agree": sum(a == b for a, b in pairs), "ac1_tier": ac1([p for p in pairs if "/" not in p[0] and "/" not in p[1]], TIERS),
            "ac1_denominator_excl_mixed_tier_groups": len([p for p in pairs if "/" not in p[0] and "/" not in p[1]]), "only_fable": [r[0] for r in rows if r[2] is None], "only_astra": [r[0] for r in rows if r[1] is None]},
 "labels": {"levels_union": len(L), "levels_both": len(lp), "raw_agree": sum(a == b for a, b in lp), "ac1_label": ac1(lp, ["equivalent", "non_equivalent", "uncertain"]), "only_one_reader": len(L) - len(lp)},
 "transcription": {"keyed_statistics": len(sealed), "status_counts": dict(tc), "note": "Separate measure. Agreement on value, SE, CI, exact p, printed inequality and df at printed precision."},
 "reader_raw_counts": {r: {"claims": len(R(r, "claim_map")), "targets": len(R(r, "targets")), "axes": len(R(r, "specification_space")), "forensics": len(R(r, "forensics"))} for r in ("fable", "astra")}}
json.dump(res, open(os.path.join(OUT, "agreement.json"), "w"), indent=1)
print(json.dumps(res, indent=1)); [print(r) for r in rows if r[1] != r[2]]
