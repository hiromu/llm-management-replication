"""Deterministic scorer. usage: score.py <run_dir> <out_dir>. Reads run_dir/{A,B,C}/results.csv and sealed targets."""
import csv, json, math, os, re, sys, collections
import pandas as pd
STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUN, OUT = sys.argv[1], sys.argv[2]; os.makedirs(OUT, exist_ok=True)
RULES = json.load(open(os.path.join(STUDY, "scoring/scoring_rules.json")))
T = json.load(open(os.environ.get("TARGETS", os.path.join(STUDY, "sealed/targets/targets_reconciled.json"))))
TOL = RULES["implementation_tolerances"]; M = RULES["magnitude"]
IMPL = [i for i in ("A", "B", "C") if os.path.exists(os.path.join(RUN, i, "results.csv"))]
ORIG = {1: ("D1_key", ["D1_none"]), 2: ("D2_any", ["D2_both", "D2_none"]), 3: ("D3_all", ["D3_comp", "D3_none"]), 4: ("D4_loyal", [])}
COMP0 = {1: "mean", 2: "mean", 3: "mean", 4: "existing"}
def load(i):
    d = pd.read_csv(os.path.join(RUN, i, "results.csv"), dtype=str, keep_default_na=False)
    d["v"] = pd.to_numeric(d["value"], errors="coerce")
    d["dataset"] = d["dataset"].astype(str).str.extract(r"(\d)")[0].astype(int)
    # The manifest leaves method labels open for single-method families; normalize them only
    d.loc[d["key"].str.match(r"^(D[1-4]|R[1-3]|N[1-4]|CHI4)\."), "method"] = "descriptive"
    d["key"] = d["key"].str.replace(r"\.\(?[Ii]ntercept\)?\.", ".intercept.", regex=True)
    return {(r.dataset, r.sample_level, r.composite_level, r.key, r.method): (r.v, r.status) for r in d.itertuples()}
R = {i: load(i) for i in IMPL}
def tol(key, method):
    k = key.rsplit(".", 1)[-1]
    if k == "se_boot": return ("rel", TOL["se_boot_relative"])
    if k.startswith("ci_bc") or k.startswith("ci_perc"): return ("abs", TOL["ci_absolute"])
    if key.startswith("LMM1"): return ("rel", TOL["mixed_model_relative"])
    if key.startswith("L4") or key.startswith("CHI4") or "logit" in method: return ("rel", TOL["logit_relative"])
    return ("rel", TOL["deterministic_relative"])
def close(a, b, t):
    if a is None or b is None or (isinstance(a, float) and math.isnan(a)) or (isinstance(b, float) and math.isnan(b)): return False
    return abs(a - b) <= t[1] if t[0] == "abs" else abs(a - b) <= t[1] * max(1.0, abs(a), abs(b))
CONS = {}; agree_rows = []
allk = set().union(*[set(R[i]) for i in IMPL]) if IMPL else set()
for k in sorted(allk, key=str):
    vals = {i: R[i].get(k, (float("nan"), "absent"))[0] for i in IMPL}
    t = tol(k[3], k[4]); ok = [i for i in IMPL if not (vals[i] is None or math.isnan(vals[i]))]
    pairs = [(a, b) for x, a in enumerate(ok) for b in ok[x + 1:] if close(vals[a], vals[b], t)]
    if len(ok) == len(IMPL) and len(pairs) == 3: st, v = "all_agree", sorted(vals[i] for i in ok)[1]
    elif pairs:
        a, b = pairs[0]; st, v = (f"pair_{a}{b}" if len(pairs) == 1 else "partial"), (vals[a] + vals[b]) / 2
    elif len(ok) == 1 and len(IMPL) == 1: st, v = "single", vals[ok[0]]
    else: st, v = "no_pair" if ok else "all_missing", float("nan")
    CONS[k] = (v, st); agree_rows.append(list(k) + [vals.get(i) for i in ("A", "B", "C") if i in IMPL] + [st, v])
with open(os.path.join(OUT, "implementer_agreement.csv"), "w", newline="") as fh:
    w = csv.writer(fh); w.writerow(["dataset", "sample_level", "composite_level", "key", "method"] + IMPL + ["status", "consensus"]); w.writerows(agree_rows)
# n branch
NKEY = {1: "N1.n", 2: "N2.n", 3: "N3.n", 4: "N4.n"}
SAMPLE = {}; NB = {}
def getv(ds, sl, cl, key, method): return CONS.get((ds, sl, cl, key, method), (float("nan"), "absent"))
def nmeth(ds, sl):
    for k in CONS:
        if k[0] == ds and k[1] == sl and k[3] == NKEY[ds]: return CONS[k][0]
    return float("nan")
for ds, (o, alts) in ORIG.items():
    pub = float(T[NKEY[ds]]["value"]); rec = {l: nmeth(ds, l) for l in [o] + alts}
    if rec[o] == pub: SAMPLE[ds], code = o, "origin"
    else:
        m = [l for l in alts if rec[l] == pub]
        SAMPLE[ds], code = (m[0], "n_branch_selected") if m else (o, "n_unmatched")
    NB[ds] = {"published_n": pub, "by_level": rec, "scoring_sample": SAMPLE[ds], "code": code}
json.dump(NB, open(os.path.join(OUT, "n_branch.json"), "w"), indent=1)
def V(ds, key, method, sl=None, cl=None):
    return getv(ds, sl or SAMPLE[ds], cl or COMP0[ds], key, method)
def dec(s):
    s = str(s); return len(s.split(".")[1]) if "." in s else 0
def num(s):
    try: return float(str(s).replace("−", "-"))
    except Exception: return None
def rint(s):
    v = num(s)
    if v is None: return None
    h = .5 * 10 ** (-dec(s)); return (v - h, v + h)
def dist_to(x, iv):
    if x < iv[0]: return iv[0] - x
    if x > iv[1]: return x - iv[1]
    return 0.0
BANDS = [(0, .01), (.01, .05), (.05, .10), (.10, 1.0000001)]
def band(p):
    for i, (a, b) in enumerate(BANDS):
        if a <= p < b: return i
    return 3
def pub_bands(t):
    pe, pi = t.get("p_exact"), t.get("p_inequality")
    if pe is not None and num(pe) is not None:
        lo, hi = rint(pe); lo = max(lo, 0); return list(range(band(lo), band(min(hi, 1)) + 1))
    if pi:
        m = re.search(r"<\s*(0?\.\d+)", pi)
        if m:
            c = float(m.group(1)); return list(range(0, band(c - 1e-9) + 1))
    return None
def inf_check(p, t):
    pb = pub_bands(t)
    if pb is None or p is None or math.isnan(p): return "not_audited", None
    b = band(p)
    if b in pb: return "pass", 0
    gap = min(abs(b - x) for x in pb); pub_sig = max(pb) <= 1
    if pub_sig and b < min(pb): return "pass_stronger", gap
    rec_sig = b <= 1
    if gap >= 2: return "out", gap
    if rec_sig != pub_sig: return "grey_cross", gap
    return "pass_adjacent", gap
def mag_check(dist_se):
    if dist_se is None or math.isnan(dist_se): return "not_audited"
    if dist_se <= M["consistent_max"]: return "pass"
    if dist_se <= M["grey_max"]: return "grey"
    return "out"
RES = []; CMP = []
def compare_key(tkey, ds, okey, method, sl=None, cl=None):
    t = T.get(tkey)
    if not t: return
    v, st = V(ds, okey, method, sl, cl); iv = rint(t["value"]); parsed = iv is not None
    match = None if (not parsed or math.isnan(v)) else (dist_to(abs(v) if num(t["value"]) >= 0 and okey.endswith(".t") else v, iv) <= 1e-9)
    CMP.append({"target_key": tkey, "dataset": ds, "output_key": okey, "method": method, "sample": sl or SAMPLE[ds], "composite": cl or COMP0[ds], "published": t["value"], "reconstructed": v, "impl_status": st, "print_match": match, "target_status": t["status"], "locator": t["locator"]})
    return match
def outcome(c):
    o = dict(c); sign, inf, mag = c["sign"], c["inference"], c["magnitude"]
    if c.get("impl") not in ("all_agree", "partial", "single") and not str(c.get("impl", "")).startswith("pair"): return "indeterminate", "implementer_disagreement"
    out = (sign == "fail") or inf == "out" or mag == "out"
    if out:
        return ("discrepant_candidate", "origin_and_every_equivalent_out") if c.get("all_equiv_out", True) else ("indeterminate", "origin_out_equivalent_reads_in")
    if sign == "missing": return "indeterminate", "incomplete_coverage"
    if mag == "grey" or inf == "grey_cross": return "indeterminate", "grey_zone"
    if inf == "not_audited" and c.get("needs_inference", True): return "indeterminate", "inference_not_audited"
    if c.get("equiv_stable") is False: return "fragile", "equivalent_set_unstable"
    if c.get("benchmark_fail"): return "fragile_inference", "benchmark_weakens"
    return "consistent", ""
def add(cid, tier, family, study, typ, **k):
    c = dict(claim=cid, tier=tier, family=family, study=study, type=typ, **k)
    c["outcome"], c["reason"] = outcome(c)
    UE = c.pop("unc_alt", None)
    if UE is not None:
        c2 = dict(c); c2["equiv_stable"] = (c.get("equiv_stable") is not False) and UE; oc, _ = outcome(c2)
        c["label_sensitive"] = oc != c["outcome"]; c["outcome_if_uncertain_equivalent"] = oc
    RES.append(c)
def sidep(p): return None if p is None or math.isnan(p) else p < .05
# Diff-type claims
def diff_claim(cid, tier, fam, study, ds, keyroot, mean_pub, t_key, d_key, tmethod, equiv, uncert, bench=True):
    a, b = T.get(mean_pub[0]), T.get(mean_pub[1]); tt = T.get(t_key)
    dv, ds_ = V(ds, f"{keyroot}.mean_diff", tmethod) if not keyroot.startswith("T2") else V(ds, f"{keyroot}.mean_diff", "descriptive")
    pv, _ = V(ds, f"{keyroot}.p", tmethod); tv, _ = V(ds, f"{keyroot}.t", tmethod)
    ia, ib = rint(a["value"]), rint(b["value"]); pubd = num(a["value"]) - num(b["value"]); iv = (ia[0] - ib[1], ia[1] - ib[0])
    tpub = abs(num(tt["value"])); se = abs(pubd) / tpub if tpub else None
    sign = "missing" if math.isnan(dv) else ("pass" if dv * pubd > 0 else "fail")
    dist = None if (math.isnan(dv) or se in (None, 0)) else dist_to(dv, iv) / se
    inf, gap = inf_check(pv, tt)
    alts = [(m, V(ds, f"{keyroot}.p", m)[0]) for m in equiv]
    stable = all(sidep(x) == sidep(pv) for _, x in alts if not math.isnan(x)) if alts else None
    allout = all(band(x) not in (pub_bands(tt) or [band(x)]) for _, x in alts if not math.isnan(x)) if alts else True
    bp = V(ds, f"{keyroot}.p_hc3", "descriptive" if not keyroot.startswith("P1") else "paired")[0] if bench else float("nan")
    u = [(n, x) for n, x in uncert]; ustab = all(sidep(x) == sidep(pv) for _, x in u if not math.isnan(x))
    compare_key(t_key, ds, f"{keyroot}.t", tmethod); compare_key(d_key, ds, f"{keyroot}.d", "paired" if keyroot.startswith("P1") else "descriptive")
    add(cid, tier, fam, study, "diff", estimate=dv, published_estimate=pubd, published_se_derived=se, se_units=dist, sign=sign, inference=inf, inference_gap=gap, magnitude=mag_check(dist), p=pv, published_p=tt.get("p_exact") or tt.get("p_inequality"), t=tv, published_t=tt["value"], df=V(ds, f"{keyroot}.df", tmethod)[0], published_df=tt.get("df"), benchmark_p=bp, benchmark_fail=(sidep(pv) is True and sidep(bp) is False), equiv_stable=stable, fragility_assessed=bool(alts), all_equiv_out=allout, impl=ds_, unc_alt=ustab, alt_p=dict(alts), uncertain_p=dict(u))
OC = ["you_grant", "prom_voice", "proh_voice"]; MECH = ["benev_trust_broker", "integ_trust_broker", "val_align_part_broker", "relconcerns_with_broker"]
for o in OC + ["loyal_comb"]:
    root = f"P1.{o}"
    for s in ("mean_loyal", "sd_loyal", "mean_control", "sd_control"): compare_key(f"{root}.{s}", 1, f"{root}.{s}", "paired")
    unc = [] if o == "loyal_comb" else [("ME1", V(1, f"ME1.{o}.p", "mixed_anova")[0]), ("LMM_person", V(1, f"LMM1.{o}.p", "ri_person")[0]), ("LMM_person_wrongdoing", V(1, f"LMM1.{o}.p", "ri_person_wrongdoing")[0])]
    diff_claim(f"S1.paired.{o}" if o != "loyal_comb" else "S1.manipcheck", "focal" if o != "loyal_comb" else "identification_or_inference_diagnostic", "H1" if o != "loyal_comb" else None, 1, 1, root, (f"{root}.mean_loyal", f"{root}.mean_control"), f"{root}.t", f"{root}.d", "paired", [], unc)
for o in OC:
    root = f"T2.{o}"
    for s in ("mean_loyal", "sd_loyal", "mean_control", "sd_control"): compare_key(f"{root}.{s}", 2, f"{root}.{s}", "descriptive")
    diff_claim(f"S2.t.{o}", "focal", "H1", 2, 2, root, (f"{root}.mean_loyal", f"{root}.mean_control"), f"{root}.t", f"{root}.d", "welch", ["student"], [])
for o in OC + MECH:
    is_main = o in OC
    for cell in ("LC", "CC", "LD"):
        for s in ("mean", "sd"): compare_key(f"C3.cell.{o}.{cell}.{s}", 3, f"C3.cell.{o}.{cell}.{s}", "descriptive"); compare_key(f"C3.cell.{o}.{cell}_h3print.{s}", 3, f"C3.cell.{o}.LC.{s}", "descriptive") if cell == "LC" else None
    for h, (a, b) in {"H1": ("LC", "CC"), "H3": ("LC", "LD")}.items():
        root = f"C3.{h}.{o}"; ak = f"C3.cell.{o}.{a}.mean"; bk = f"C3.cell.{o}.{b}.mean"
        unc = [(m, V(3, f"{root}.p", m)[0]) for m in ("student", "welch")]
        cl = f"S3.contrast.{o}.{h}" if is_main else f"S3.mechanism.{o}.{h}"
        diff_claim(cl, "focal" if is_main else "robustness", h if is_main else None, 3, 3, root, (ak, bk), f"{root}.t", f"{root}.d", "pooled", [], unc)
    for term in ("relationship", "history", "interaction"):
        tk = f"A3.{o}.{term}.F"; t = T.get(tk)
        if not t: continue
        Fv, st = V(3, tk, "type3"); pv = V(3, f"A3.{o}.{term}.p", "type3")[0]; compare_key(tk, 3, tk, "type3"); compare_key(f"A3.{o}.{term}.eta2", 3, f"A3.{o}.{term}.eta2", "type3")
        iv = rint(t["value"]); d = None if math.isnan(Fv) else dist_to(math.sqrt(max(Fv, 0)), (math.sqrt(max(iv[0], 0)), math.sqrt(iv[1])))
        inf, gap = inf_check(pv, t); u = V(3, f"A3.{o}.{term}.p", "type2")[0]
        add(f"S3.anova.{o}.{term}" if is_main else f"S3.mechanism.{o}.{term}", "uncertain" if is_main else "robustness", None, 3, "F1", estimate=Fv, published_estimate=t["value"], se_units=d, sign="pass" if not math.isnan(Fv) else "missing", inference=inf, inference_gap=gap, magnitude=mag_check(d), p=pv, published_p=t.get("p_exact") or t.get("p_inequality"), impl=st, equiv_stable=None, fragility_assessed=False, unc_alt=sidep(u) == sidep(pv))
for o in OC:
    tk = f"M1.{o}.F"; t = T[tk]; Fv, st = V(1, tk, "mixed_anova"); pv = V(1, f"M1.{o}.p", "mixed_anova")[0]; compare_key(tk, 1, tk, "mixed_anova")
    iv = rint(t["value"]); d = None if math.isnan(Fv) else dist_to(Fv, iv); inf, gap = inf_check(pv, t)
    mg = "not_audited" if d is None else ("pass" if d <= M["multi_df_F"]["consistent_max"] else "grey" if d <= M["multi_df_F"]["grey_max"] else "out")
    add(f"S1.interaction.{o}", "identification_or_inference_diagnostic", None, 1, "Fk", estimate=Fv, published_estimate=t["value"], absolute_F_distance=d, sign="pass" if not math.isnan(Fv) else "missing", inference=inf, inference_gap=gap, magnitude=mg, p=pv, published_p=t.get("p_exact"), impl=st, fragility_assessed=False)
# Indirect effects
def ind_claim(cid, tier, fam, study, ds, root, method, tk, equiv_comp=None, cl=None, unc_extra=None, ci_usable=True):
    t = T[tk]; est, st = V(ds, f"{root}.ind", method, cl=cl); lo = V(ds, f"{root}.ci_bc_low", method, cl=cl)[0]; hi = V(ds, f"{root}.ci_bc_high", method, cl=cl)[0]
    pd_ = V(ds, f"{root}.p_delta", method, cl=cl)[0]; pl = V(ds, f"{root}.ci_perc_low", method, cl=cl)[0]; ph = V(ds, f"{root}.ci_perc_high", method, cl=cl)[0]
    plo, phi = num(t["ci_low"]), num(t["ci_high"]); iv = rint(t["value"]); se = num(t["se"])
    sign = "missing" if math.isnan(est) else ("pass" if est * num(t["value"]) > 0 or abs(num(t["value"])) < .005 else "fail")
    dist = None if (math.isnan(est) or not se) else dist_to(est, iv) / se
    excl = lambda a, b: None if (math.isnan(a) or math.isnan(b)) else (a > 0 or b < 0)
    if ci_usable and plo is not None and phi is not None and plo <= phi:
        pubx = plo > 0 or phi < 0; recx = excl(lo, hi)
        inf = "not_audited" if recx is None else ("pass" if recx == pubx else "out_zero")
    else: pubx = None; recx = excl(lo, hi); inf = "not_audited"
    binf, gap = inf_check(pd_, t)
    if inf == "not_audited": inf = binf
    elif inf == "out_zero": inf = "grey_cross" if binf in ("pass", "pass_adjacent", "pass_stronger") else "out"
    percx = excl(pl, ph); stable = None if (percx is None or recx is None) else percx == recx
    u = excl(V(ds, f"{root}.ci_norm_low", method, cl=cl)[0], V(ds, f"{root}.ci_norm_high", method, cl=cl)[0]) if ds == 2 else sidep(pd_)
    uok = (u == recx) if (u is not None and recx is not None) else True
    if unc_extra: uok = uok and all(excl(V(ds, f"{root}.ci_bc_low", m)[0], V(ds, f"{root}.ci_bc_high", m)[0]) == recx for m in unc_extra)
    compare_key(tk, ds, f"{root}.ind", method, cl=cl)
    add(cid, tier, fam, study, "ind", estimate=est, published_estimate=t["value"], published_se=t["se"], se_boot=V(ds, f"{root}.se_boot", method, cl=cl)[0], se_delta=V(ds, f"{root}.se_delta", method, cl=cl)[0], ci_bc=[lo, hi], ci_perc=[pl, ph], published_ci=[t["ci_low"], t["ci_high"]], se_units=dist, sign=sign, inference=inf, delta_p_band=binf, inference_gap=gap, magnitude=mag_check(dist), p=pd_, published_p=t.get("p_exact") or t.get("p_inequality"), equiv_stable=stable, fragility_assessed=stable is not None, all_equiv_out=True, impl=st, unc_alt=uok, ci_excludes_zero=recx, published_ci_excludes_zero=pubx)
SHORT = {"benev_trust_broker": "benev", "integ_trust_broker": "integ", "val_align_part_broker": "val_align", "relconcerns_with_broker": "relconcerns"}
for o in OC:
    for m in MECH:
        ind_claim(f"S2.ind.{o}.{SHORT[m]}", "robustness" if m == "integ_trust_broker" else "focal", None if m == "integ_trust_broker" else "H2", 2, 2, f"PM2.{o}.{m}", "ols", f"PM2.{o}.{m}.ind")
for m, c in (("val_align_part_broker", "val_align"), ("relconcerns_with_broker", "relconcerns")):
    ind_claim(f"S2.serial.{c}", "robustness", None, 2, 2, f"SM2.{m}", "ols", f"SM2.{m}.ind", ci_usable=False)
for kind in ("sim", "ind"):
    for m in ("SignedTrust", "SignedRisk"):
        ind_claim(f"S4.med.{kind}.{m}", "robustness", None, 4, 4, f"MED4.{kind}.{m}", "linear_cont", f"MED4.{kind}.{m}.ind", unc_extra=["logit_cont", "linear_strong", "logit_strong"])
# Logit
TERMS = {"M1": ["LoyalRequestor"], "M2": ["LoyalRequestor", "KnowRequestor", "LikeRequestor", "SemestersRequestor"], "M3": ["LoyalRequestor", "KnowRequestor", "LikeRequestor", "SemestersRequestor", "LoyaltyHouse"]}
for mod, ts in TERMS.items():
    for term in ts:
        tk = f"L4.{mod}.{term}.coef"; t = T[tk]; est, st = V(4, tk, "logit"); se = num(t["se"]); pv = V(4, f"L4.{mod}.{term}.p", "logit")[0]; compare_key(tk, 4, tk, "logit"); compare_key(f"L4.{mod}.{term}.or", 4, f"L4.{mod}.{term}.or", "logit")
        iv = rint(t["value"]); d = None if math.isnan(est) else dist_to(est, iv) / se
        sign = "missing" if math.isnan(est) else ("pass" if est * num(t["value"]) > 0 else "fail"); inf, gap = inf_check(pv, t)
        hc = V(4, f"L4.{mod}.{term}.p_hc0", "logit")[0]
        tier = ("focal" if mod == "M1" else "robustness") if term == "LoyalRequestor" else "nuisance"
        add(f"S4.{mod}.{term}", tier, "H1" if (mod == "M1") else None, 4, "coef", estimate=est, published_estimate=t["value"], published_se=t["se"], se_recon=V(4, f"L4.{mod}.{term}.se", "logit")[0], se_units=d, sign=sign, inference=inf, inference_gap=gap, magnitude=mag_check(d), p=pv, p_hc0=hc, published_p=t.get("p_exact") or t.get("p_inequality"), equiv_stable=None, fragility_assessed=False, impl=st, unc_alt=sidep(hc) == sidep(pv), needs_inference=(tier != "nuisance"))
    for f in ("ll", "mcf", "cs"): compare_key(f"L4.{mod}.fit.{f}", 4, f"L4.{mod}.fit.{f}", "logit")
# Table-type: every remaining target key compared at printed precision
def method_for(k):
    if k.startswith(("D", "R", "N")): return None
    return None
def tbl(prefix, ds):
    n = m = 0; miss = []
    for k, t in T.items():
        if not k.startswith(prefix): continue
        if num(t["value"]) is None: miss.append(k + ":unparseable"); continue
        cands = [(ds, SAMPLE[ds], COMP0[ds], k, mm) for mm in ("descriptive", "sample", "reliability", "paired", "ols", "")]
        f = [c for c in CONS if c[0] == ds and c[1] == SAMPLE[ds] and c[2] == COMP0[ds] and c[3] == k]
        if not f: miss.append(k + ":absent"); continue
        v = CONS[f[0]][0]; iv = rint(t["value"]); n += 1
        mt = (not math.isnan(v)) and dist_to(v, iv) <= 1e-9
        m += int(mt)
        CMP.append({"target_key": k, "dataset": ds, "output_key": k, "method": f[0][4], "sample": SAMPLE[ds], "composite": COMP0[ds], "published": t["value"], "reconstructed": v, "impl_status": CONS[f[0]][1], "print_match": mt, "target_status": t["status"], "locator": t["locator"]})
    return n, m, miss
for study, prefixes in {1: ["D1", "R1", "N1"], 2: ["D2", "R2", "N2"], 3: ["D3", "R3", "N3"], 4: ["D4", "N4"]}.items():
    for p in prefixes:
        n, m, miss = tbl(p + ".", study)
        tier = {"D": "descriptive", "R": "uncertain" , "N": "descriptive"}[p[0]]
        oc = ("consistent", "") if (n and n == m and not miss) else ("indeterminate", "table_mismatch_or_missing")
        RES.append(dict(claim=f"S{study}.table.{p}", tier=tier, family=None, study=study, type="table", n_keys=n, n_print_match=m, missing=miss, outcome=oc[0], reason=oc[1]))
for k, t in T.items():
    if k.startswith(("G1W", "G1C", "G2W", "G2C")):
        ds = 1 if k[1] == "1" else 2; meth = None
        s = k.rsplit(".", 1)[-1]
        if s == "t": meth = "paired" if k.startswith("G1W") else "welch"
        else: meth = "descriptive"
        compare_key(k, ds, k, meth)
        if s == "t":
            alt = ["student", "welch"] if meth == "paired" else ["student"]
            for a in alt: CMP.append({**CMP[-1], "method": a, "reconstructed": V(ds, k, a)[0], "print_match": (not math.isnan(V(ds, k, a)[0])) and dist_to(abs(V(ds, k, a)[0]), rint(t["value"])) <= 1e-9, "note": "uncertain alternative"})
pd.DataFrame(CMP).to_csv(os.path.join(OUT, "statistic_comparisons.csv"), index=False)
pd.DataFrame(RES).to_json(os.path.join(OUT, "claim_outcomes.json"), orient="records", indent=1)
pd.DataFrame(RES).drop(columns=[c for c in ("alt_p", "uncertain_p", "ci_bc", "ci_perc", "published_ci", "missing") if c in pd.DataFrame(RES).columns]).to_csv(os.path.join(OUT, "claim_outcomes.csv"), index=False)
# Aggregation
RANK = {"H1": [], "H2": [], "H3": []}
for c in RES:
    if c.get("family") in RANK and c["tier"] == "focal": RANK[c["family"]].append(c["outcome"])
def fam(o):
    if all(x == "consistent" for x in o): return "consistent"
    dc = sum(x == "discrepant_candidate" for x in o)
    if dc * 2 >= len(o): return "discrepant_candidate"
    if dc or "indeterminate" in o: return "indeterminate"
    if "fragile" in o: return "fragile"
    return "fragile_inference"
fams = {k: fam(v) for k, v in RANK.items()}
vals = set(fams.values())
if vals == {"consistent"}: paper = "consistent"
elif "discrepant_candidate" in vals: paper = "indeterminate"; note = "pending adversarial review and human confirmation"
elif "indeterminate" in vals: paper = "indeterminate"
elif "fragile" in vals: paper = "fragile"
else: paper = "fragile_inference"
summ = {"family_outcomes": fams, "family_claim_outcomes": {k: dict(collections.Counter(v)) for k, v in RANK.items()}, "paper_outcome": paper, "scoring_sample": {str(k): v for k, v in SAMPLE.items()}, "by_tier": {t: dict(collections.Counter(c["outcome"] for c in RES if c["tier"] == t)) for t in set(c["tier"] for c in RES)}, "label_sensitive": [c["claim"] for c in RES if c.get("label_sensitive")], "print_matches": {"total": len(CMP), "match": sum(1 for c in CMP if c.get("print_match") is True)}, "implementations": IMPL}
json.dump(summ, open(os.path.join(OUT, "paper_summary.json"), "w"), indent=1, default=str)
print(json.dumps(summ, indent=1, default=str))
