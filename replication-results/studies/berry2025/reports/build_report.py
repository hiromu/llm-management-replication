"""Build tables and exports from saved outputs and fill reports/replication_report.md and technical_supplement.md from their templates."""
import glob, json, shutil
import pandas as pd
run = sorted(glob.glob("runs/empirical_*"))[-1]
C = json.load(open("scoring/outputs_v1/claim_outcomes.json")); S = json.load(open("scoring/outputs_v1/paper_summary.json")); AG = json.load(open("reconciliation/agreement.json"))
def fmt(v, n=3):
    if v is None: return "missing"
    try:
        f = float(v)
    except Exception:
        return str(v)
    if f != f: return "missing"
    return f"{f:.2e}" if abs(f) < .001 and f != 0 else f"{f:.{n}f}"
NAMES = {"you_grant": "granting", "prom_voice": "promotive voice", "proh_voice": "prohibitive voice", "benev": "benevolence", "val_align": "value alignment", "relconcerns": "relational concerns"}
def nm(c):
    p = c.split(".")
    if c.startswith("S1.paired"): return f"Study 1 paired t, {NAMES[p[2]]}"
    if c.startswith("S2.t"): return f"Study 2 Welch t, {NAMES[p[2]]}"
    if c.startswith("S2.ind"): return f"Study 2 indirect via {NAMES[p[3]]}, {NAMES[p[2]]}"
    if c.startswith("S3.contrast"): return f"Study 3 {p[3]} contrast, {NAMES[p[2]]}"
    return "Study 4 logit Model 1, loyalty"
rows = ["| Claim | Published estimate | Reconstructed | SE units | Published p | Reconstructed p | N | Outcome |", "| --- | --- | --- | --- | --- | --- | --- | --- |"]
N = {1: 530, 2: 186, 3: 286, 4: 50}
for c in [x for x in C if x["tier"] == "focal"]:
    rows.append(f"| {nm(c['claim'])} | {fmt(c['published_estimate'], 2)} | {fmt(c['estimate'])} | {fmt(c['se_units'], 2)} | {c.get('published_p')} | {fmt(c['p'])} | {N[c['study']]} | {c['outcome']} |")
FOCAL = "\n".join(rows)
d = pd.read_csv(f"{run}/A/results.csv", dtype=str, keep_default_na=False)
d["spec"] = d.key.str.rsplit(".", n=1).str[0] + "|" + d.method
all_settings = (d.spec + "|" + d.sample_level + "|" + d.composite_level).nunique()
o = d[d.sample_level.isin(["D1_key", "D2_any", "D3_all", "D4_loyal"])]
origin_sample = (o.spec + "|" + o.composite_level).nunique()
oc = o[((o.dataset != "4") & (o.composite_level == "mean")) | ((o.dataset == "4") & (o.composite_level == "existing"))]
single = oc.spec.nunique()
inf = pd.read_csv(f"{run}/A/influence.csv", dtype=str, keep_default_na=False)
infs = inf[inf.sample_level.isin(["D1_key", "D2_any", "D3_all", "D4_loyal"])]
COUNT = {"quantities": len(d), "settings_all": all_settings, "settings_origin_sample": origin_sample, "settings_origin_sample_composite": single, "influence_rows": len(inf), "influence_scoring_samples": len(infs), "influence_failed": int((inf.status != "ok").sum())}
json.dump(COUNT, open("reports/exports/counts.json", "w"), indent=1)
AGE = pd.read_csv("scoring/outputs_v1/implementer_agreement.csv").status.value_counts().to_dict()
tc = pd.DataFrame([{"tier": x["tier"], "outcome": x["outcome"]} for x in C]); TIER = pd.crosstab(tc.tier, tc.outcome)
tl = ["| Tier | " + " | ".join(TIER.columns) + " |", "| --- | " + " | ".join("---" for _ in TIER.columns) + " |"] + ["| " + i + " | " + " | ".join(str(v) for v in r) + " |" for i, r in zip(TIER.index, TIER.values)]
TIERT = "\n".join(tl)
for f in ["scoring/outputs_v1/claim_outcomes.csv", "scoring/outputs_v1/claim_outcomes.json", "scoring/outputs_v1/statistic_comparisons.csv", "scoring/outputs_v1/implementer_agreement.csv", "scoring/outputs_v1/paper_summary.json", "post_unseal/author_vs_published.csv", "post_unseal/diagnostics.json"]:
    shutil.copy(f, "reports/exports/")
shutil.copy(f"{run}/A/influence.csv", "reports/exports/influence_results_implementer_A.csv")
for t in ("replication_report", "technical_supplement"):
    s = open(f"reports/{t}.template.md").read().replace("{FOCAL}", FOCAL).replace("{TIERS}", TIERT).replace("{RUN}", run)
    for k, v in COUNT.items(): s = s.replace("{" + k + "}", f"{v:,}")
    for k, v in AGE.items(): s = s.replace("{age_" + k + "}", str(v))
    s = s.replace("{claims_n}", str(len(C)))
    open(f"reports/{t}.md", "w").write(s)
print(COUNT, AGE); print(FOCAL[:400])
