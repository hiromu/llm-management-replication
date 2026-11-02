"""Coordinator reconciliation: claim, label and transcription ledgers, and the sealed target table.
Rule set, fixed before comparing: claims match on study, outcome, term and statistic family; levels match
on the operation they perform; readers' first outputs are never altered. Disagreeing labels become
uncertain; structures only one reader proposed are retained with that reader's label and flagged."""
import csv, json, os, re, collections
STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = lambda r, f: json.load(open(os.path.join(STUDY, f"readers/{r}/initial/{f}.json")))
OUT = os.path.join(STUDY, "reconciliation"); os.makedirs(OUT, exist_ok=True)
OC = {"granting request": "you_grant", "promotive voice": "prom_voice", "prohibitive voice": "proh_voice",
      "benevolence trust": "benev_trust_broker", "integrity trust": "integ_trust_broker", "value alignment": "val_align_part_broker",
      "relational concerns": "relconcerns_with_broker", "reputational concerns": "relconcerns_with_broker", "loyalty": "loyal_comb"}
LONG = {"granting request": "you_grant", "promotive ethical voice": "prom_voice", "prohibitive ethical voice": "proh_voice",
        "benevolence-based trust in broker": "benev_trust_broker", "integrity-based trust in broker": "integ_trust_broker",
        "perceived value alignment with broker": "val_align_part_broker", "relational concerns with broker": "relconcerns_with_broker",
        "reputational concerns with broker": "relconcerns_with_broker", "condition": "cond_recode", "relationship condition": "cond_rel_recode",
        "brokering history condition": "cond_brokhist_recode", "signed": "Signed", "loyalty to broker": "LoyalRequestor", "knows broker well": "KnowRequestor",
        "likes broker": "LikeRequestor", "time known broker": "SemestersRequestor", "time known broker (semesters)": "SemestersRequestor", "loyalty to house": "LoyaltyHouse"}
def vname(s, study):
    s = s.strip().lower()
    alias = {"promotive voice": "prom_voice", "prohibitive voice": "proh_voice", "benevolence trust": "benev_trust_broker", "integrity trust": "integ_trust_broker",
             "value alignment": "val_align_part_broker", "relational concerns": "relconcerns_with_broker", "reputational concerns": "relconcerns_with_broker",
             "brokering history": "cond_brokhist_recode"}
    if s in alias: return alias[s]
    if s == "condition": return "cond_recode"
    return LONG.get(s, s)
STAT = {"mean": "mean", "sd": "sd", "t": "t", "F": "F", "d": "d", "eta2": "eta2", "correlation": "r", "alpha_reliability": "alpha",
        "coefficient": "coef", "odds_ratio": "or", "indirect_effect": "ind", "log_likelihood": "ll", "mcfadden_r2": "mcf", "McFadden_R2": "mcf",
        "cox_snell_r2": "cs", "Cox_Snell_R2": "cs", "n_analysed": "n"}
def fable_key(t):
    c, s, x = t["claim_id"], t["statistic_type"], (t["condition_or_term"] or "")
    st = STAT.get(s); study = int(c[1])
    if st is None: return None
    if c == "C1.01" or c == "C1.05" or c == "C1.06" or c == "C1.07":
        o = {"C1.01": "loyal_comb", "C1.05": "you_grant", "C1.06": "prom_voice", "C1.07": "proh_voice"}[c]
        if st in ("mean", "sd"): return f"P1.{o}.{st}_{'loyal' if 'loyal colleague' in x or ', loyal' in x else 'control'}"
        return f"P1.{o}.{st}"
    if c in ("C1.02", "C1.03", "C1.04"): return f"M1.{ {'C1.02':'you_grant','C1.03':'prom_voice','C1.04':'proh_voice'}[c]}.F"
    if c == "C1.09": return "R1.loyal_comb.alpha"
    if c in ("C1.08", "C2.18", "C3.16", "C4.05"):
        d = f"D{study}"
        m = re.match(r"Table \d row \d+ (.*)$", x)
        if m:
            name = re.sub(r" \(1=.*\)$", "", m.group(1))
            return f"{d}.{st}.{vname(name, study)}"
        a, b = x.split(" x ")
        return f"{d}.r.{'|'.join(sorted([vname(a, study), vname(b, study)]))}"
    if c in ("C1.10", "C2.20", "C3.18", "C4.08"):
        if st == "n": return f"N{study}.n"
        if x == "age": return f"N{study}.age.{st}"
        return None
    if c == "C1.11":
        g = "male" if "men" in x.split("within")[1] and "women" not in x else "female"
        return f"G1W.{'sexual_harassment' if 'sexual' in x else 'all'}.{g}.t"
    if c == "C1.12":
        m = re.match(r"D03 Table 1, (.*), (Loyal|Control), (Men|Women|men vs women)$", x)
        if not m: return None
        w = m.group(1).lower().replace(" ", "_"); cn = m.group(2).lower()
        if m.group(3) == "men vs women": return f"G1C.{w}.{cn}.t"
        return f"G1C.{w}.{cn}.{st}_{'male' if m.group(3)=='Men' else 'female'}"
    if c == "C1.13":
        if "perceived" in x: return "R1.perceived_ethic_import.alpha"
        return "R1." + {"magnitude": "magnitude", "probability": "prob_of_effect", "temporal": "temp_immediacy", "proximity": "proximity_effect", "social": "social_consensus", "concentration": "concentration_of_effect"}[re.search(r"moral intensity: (\w+)", x).group(1)] + ".r"
    if c in ("C2.01", "C2.02", "C2.03"):
        o = {"C2.01": "you_grant", "C2.02": "prom_voice", "C2.03": "proh_voice"}[c]
        if st in ("mean", "sd"): return f"T2.{o}.{st}_{'loyal' if ', loyal' in x else 'control'}"
        return f"T2.{o}.{st}"
    m = re.match(r"(granting request|promotive voice|prohibitive voice) via (benevolence-based trust|perceived value alignment|relational concerns|integrity-based trust)", x)
    if m and s == "indirect_effect":
        med = {"benevolence-based trust": "benev_trust_broker", "perceived value alignment": "val_align_part_broker", "relational concerns": "relconcerns_with_broker", "integrity-based trust": "integ_trust_broker"}[m.group(2)]
        return f"PM2.{OC[m.group(1)]}.{med}.ind"
    if c == "C2.16": return "SM2.val_align_part_broker.ind"
    if c == "C2.17": return "SM2.relconcerns_with_broker.ind"
    if c == "C2.19":
        if "pre-wrong" in x: return "R2.group_cohesion_pre.alpha"
        if "post-wrong" in x: return "R2.group_cohesion_post.alpha"
        if "in accused" in x: return f"R2.{'benev' if 'benev' in x else 'integ'}_trust_accused.alpha"
        return "R2." + ("benev_trust_broker.alpha" if "benev" in x else "val_align_part_broker.r" if "alignment" in x else "relconcerns_with_broker.alpha")
    if c == "C2.21":
        if st == "t":
            if "within men" in x: return "G2W.all.male.t"
            if "within women" in x: return "G2W.all.female.t"
            return f"G2C.{'loyal' if 'loyal' in x else 'control'}.t"
        cn = "loyal" if ", loyal" in x else "control"; g = "female" if "women" in x else "male"
        return f"G2C.{cn}.{st}_{g}"
    if c == "C3.17":
        o = "benev_trust_broker" if "benev" in x else "integ_trust_broker" if "integ" in x else "val_align_part_broker" if "align" in x else "relconcerns_with_broker"
        return f"R3.{o}.{'r' if st=='r' else 'alpha'}"
    if study == 3 and c.startswith("C3."):
        m = re.match(r"(granting request|promotive voice|prohibitive voice|benevolence trust|integrity trust|value alignment|relational concerns): (main effect relationship( to broker)?|main effect brokering history|interaction)", x)
        if m:
            term = "relationship" if "relationship" in m.group(2) else "history" if "history" in m.group(2) else "interaction"
            return f"A3.{OC[m.group(1)]}.{term}.{st}"
        m = re.match(r"(granting request|promotive voice|prohibitive voice|benevolence trust|integrity trust|value alignment|relational concerns), (loyal / control history|control relationship / control history|loyal / divisive history)", x)
        if m:
            cell = {"loyal / control history": "LC", "control relationship / control history": "CC", "loyal / divisive history": "LD"}[m.group(2)]
            if "as printed in H3" in x: cell = "LC_h3print"
            return f"C3.cell.{OC[m.group(1)]}.{cell}.{st}"
        m = re.match(r"H([13]) contrast, (granting request|promotive voice|prohibitive voice)", x)
        if m: return f"C3.H{m.group(1)}.{OC[m.group(2)]}.{st}"
        m = re.match(r"(benevolence trust|integrity trust|value alignment|relational concerns), (loyal vs control within control history|divisive vs control history within loyal)", x)
        if m: return f"C3.H{'1' if m.group(2).startswith('loyal') else '3'}.{OC[m.group(1)]}.{st}"
    if study == 4:
        m = re.match(r"Model (\d): (.*)$", x)
        tm = {"loyalty to broker": "LoyalRequestor", "loyalty to broker (log-odds)": "LoyalRequestor", "knows broker well": "KnowRequestor", "likes broker": "LikeRequestor", "time known broker": "SemestersRequestor", "loyalty to house": "LoyaltyHouse"}
        if m and st in ("coef", "or"): return f"L4.M{m.group(1)}.{tm[m.group(2).lower()]}.{st}"
        m = re.match(r"Model (\d)$", x)
        if m: return f"L4.M{m.group(1)}.fit.{st}"
        if c == "C4.06": return f"MED4.sim.{'SignedTrust' if 'trust' in x else 'SignedRisk'}.ind"
        if c == "C4.07": return f"MED4.ind.{'SignedTrust' if 'trust' in x else 'SignedRisk'}.ind"
    return None
def astra_key(t):
    c, s, x = t["claim_id"], t["statistic_type"], (t["condition_or_term"] or "")
    st = STAT.get(s)
    if st is None: return None
    m = re.match(r"S([1-4])_description$", c)
    if m:
        k = m.group(1)
        if st == "n": return f"N{k}.n"
        if x == "age": return f"N{k}.age.{st}"
        if st == "r":
            a, b = x.split(" × "); return f"D{k}.r.{'|'.join(sorted([a, b]))}"
        return f"D{k}.{st}.{x}"
    m = re.match(r"S([123])_reliability$", c)
    if m: return f"R{m.group(1)}.{x}.{st}"
    m = re.match(r"S1_(you_grant|prom_voice|proh_voice|loyal_comb)$", c)
    if m:
        if st in ("mean", "sd"): return f"P1.{m.group(1)}.{st}_{x}"
        return f"P1.{m.group(1)}.{st}"
    m = re.match(r"S1_interaction_(\w+)$", c)
    if m and st == "F": return f"M1.{m.group(1)}.F"
    m = re.match(r"S2_(you_grant|prom_voice|proh_voice)$", c)
    if m:
        if st in ("mean", "sd"): return f"T2.{m.group(1)}.{st}_{x}"
        return f"T2.{m.group(1)}.{st}"
    m = re.match(r"S2_ind_(you_grant|prom_voice|proh_voice)_(\w+)$", c)
    if m and st == "ind": return f"PM2.{m.group(1)}.{m.group(2)}.ind"
    m = re.match(r"S2_serial_(\w+)$", c)
    if m and st == "ind": return f"SM2.{m.group(1)}.ind"
    m = re.match(r"S3_anova_(\w+?)_(relationship_history|relationship|history)$", c)
    if m:
        return f"A3.{m.group(1)}.{'interaction' if m.group(2)=='relationship_history' else m.group(2)}.{st}"
    m = re.match(r"S3_H([13])_(\w+)$", c)
    if m:
        if st in ("mean", "sd"):
            cell = {"loyal/no-history": "LC", "control/no-history": "CC", "loyal/divisive": "LD"}[x]
            if m.group(1) == "3" and cell == "LC": cell = "LC_h3print"
            return f"C3.cell.{m.group(2)}.{cell}.{st}"
        return f"C3.H{m.group(1)}.{m.group(2)}.{st}"
    m = re.match(r"S4_(M\d)_(\w+)$", c)
    if m:
        if m.group(2) == "fit": return f"L4.{m.group(1)}.fit.{st}"
        return f"L4.{m.group(1)}.{m.group(2)}.{st}"
    m = re.match(r"S4_ind_(simultaneous|independent)_(\w+)$", c)
    if m and st == "ind": return f"MED4.{'sim' if m.group(1)=='simultaneous' else 'ind'}.{m.group(2)}.ind"
    m = re.match(r"S1_gender_loyalty_(sexual_harassment|all_wrongdoing)_(male|female)$", c)
    if m: return f"G1W.{'all' if 'all' in m.group(1) else 'sexual_harassment'}.{m.group(2)}.t"
    m = re.match(r"S2_gender_loyalty_sexual_harassment_(male|female)$", c)
    if m: return f"G2W.all.{m.group(1)}.t"
    m = re.match(r"S1_gender_difference_(\w+)_(loyal|control)$", c)
    if m:
        w = m.group(1).lower()
        if st == "t": return f"G1C.{w}.{m.group(2)}.t"
        return f"G1C.{w}.{m.group(2)}.{st}_{x}"
    m = re.match(r"S2_gender_difference_(loyal_colleague|control)$", c)
    if m:
        cn = "loyal" if "loyal" in m.group(1) else "control"
        if st == "t": return f"G2C.{cn}.t"
        return f"G2C.{cn}.{st}_{x}"
    return None
def norm(v):
    if v is None: return None
    v = str(v).replace("−", "-").strip()
    m = re.fullmatch(r"(-?)0?\.(\d+)", v)
    if m: v = f"{m.group(1)}0.{m.group(2)}"
    return v
FIELDS = ["value", "se", "ci_low", "ci_high", "p_exact", "p_inequality"]
def dfnorm(d):
    if d is None: return None
    if isinstance(d, list): return ",".join(str(x) for x in d)
    return str(d).replace(" ", "")
def build(r, fn):
    out, un = {}, []
    for t in R(r, "targets"):
        k = fn(t)
        if k is None:
            un.append((t["target_id"], t["claim_id"], t["statistic_type"], t["condition_or_term"])); continue
        pi = t.get("p_inequality")
        rec = {f: norm(t.get(f)) for f in FIELDS}
        rec["p_inequality"] = re.sub(r"\s", "", pi.split("(")[0]) if pi and "<" in pi else None
        rec["p_exact"] = rec["p_exact"]
        rec["df"] = dfnorm(t.get("df")); rec["locator"] = t.get("locator"); rec["target_id"] = t["target_id"]; rec["tail"] = t.get("tail"); rec["alpha"] = t.get("alpha")
        if k in out: un.append((t["target_id"], "duplicate_key", k, t["condition_or_term"]))
        out[k] = rec
    return out, un
fa, un_a = build("fable", fable_key); ab, un_b = build("astra", astra_key)
keys = sorted(set(fa) | set(ab))
rows, sealed = [], {}
agree = both = 0
def peq(a, b):
    def fl(s):
        try: return float(s)
        except Exception: return s
    return fl(a) == fl(b)
for k in keys:
    a, b = fa.get(k), ab.get(k)
    status = "single_reader"
    diffs = []
    if a and b:
        both += 1
        for f in ["value", "se", "ci_low", "ci_high", "p_exact", "p_inequality", "df"]:
            va, vb = a.get(f), b.get(f)
            if not (va == vb or (va is not None and vb is not None and peq(va, vb))): diffs.append(f)
        status = "agree" if not diffs else "disagree"
        if not diffs: agree += 1
    src = a or b
    sealed[k] = {"key": k, "status": status, "differing_fields": diffs, "fable": a, "astra": b,
                 "value": src["value"], "se": src["se"], "ci_low": src["ci_low"], "ci_high": src["ci_high"], "p_exact": src["p_exact"], "p_inequality": src["p_inequality"], "df": src["df"], "locator": src["locator"]}
    rows.append([k, status, "|".join(diffs), a and a["value"], b and b["value"], a and a["df"], b and b["df"], a and a["target_id"], b and b["target_id"]])
with open(os.path.join(OUT, "transcription_ledger.csv"), "w", newline="") as fh:
    w = csv.writer(fh); w.writerow(["key", "status", "differing_fields", "value_fable", "value_astra", "df_fable", "df_astra", "id_fable", "id_astra"]); w.writerows(rows)
os.makedirs(os.path.join(STUDY, "sealed/targets"), exist_ok=True)
json.dump(sealed, open(os.path.join(STUDY, "sealed/targets/targets_reconciled.json"), "w"), indent=1)
json.dump({"fable_unmapped": un_a, "astra_unmapped": un_b}, open(os.path.join(OUT, "targets_unmapped.json"), "w"), indent=1)
print("keys", len(keys), "both", both, "agree", agree, "single", len(keys) - both, "unmapped", len(un_a), len(un_b))
print("disagreements:", [(k, sealed[k]["differing_fields"], fa[k]["value"], ab[k]["value"], fa[k]["df"], ab[k]["df"], fa[k]["p_exact"], ab[k]["p_exact"], fa[k]["p_inequality"], ab[k]["p_inequality"]) for k in keys if sealed[k]["status"] == "disagree"][:40])
print("single:", [k for k in keys if sealed[k]["status"] == "single_reader"][:60])
print("unmapped A:", [u[1:] for u in un_a][:50]); print("unmapped B:", collections.Counter(u[2] for u in un_b), [u[1:] for u in un_b if u[2] not in("percentage","count","n_planned","power","alpha","n_recruited","n_excluded","confidence_level","n_eligible","n_by_cell_range")][:30])
