"""Synthetic datasets for implementer development. Built from dictionary definitions and column names, not from
deposited values. Row counts and effects are arbitrary and deliberately unlike any study quantity."""
import csv, os, sys
import numpy as np
STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUNDLE = os.path.join(STUDY, "data/derived/implementer_bundle")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(STUDY, "data/derived/synthetic")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(777)
def cols(i): return next(csv.reader(open(os.path.join(BUNDLE, f"dataset_{i}.csv"))))
def like(x): return np.clip(np.round(x), 1, 7).astype(int)
def noise(n, m=4, s=1.5): return like(rng.normal(m, s, n))
def write(i, d, n):
    c = cols(i)
    with open(os.path.join(OUT, f"dataset_{i}.csv"), "w", newline="") as fh:
        w = csv.writer(fh); w.writerow(c)
        for r in range(n):
            w.writerow([("" if (k not in d or d[k][r] is None) else d[k][r]) for k in c])
# dataset 1
P = 123; n = 2 * P; uid = np.repeat(np.arange(1, P + 1) * 7 + 3, 2); wn = np.repeat(rng.integers(1, 8, P), 2)
loyal = np.tile([1, 0], P); pe = np.repeat(rng.normal(0, 1, P), 2)
d = {"part_uid": uid, "wrongdoing_num": wn, "cond_recode": loyal, "cond": np.where(loyal == 1, "loyal", "control"),
     "wrongdoing": np.array(["sexual harassment", "theft", "false_advertising", "fraud", "bribery", "plagiarism", "dishonesty"])[wn - 1],
     "gender": np.repeat(rng.choice([1, 2, 3], P, p=[.48, .48, .04]), 2), "age": np.repeat(rng.integers(20, 66, P), 2), "attn": wn.copy()}
fail = rng.choice(P, 6, replace=False)
d["attn"][fail * 2] = (d["attn"][fail * 2] % 7) + 1
for k, eff in (("you_grant", .9), ("prom_voice", .6), ("proh_voice", .5)): d[k] = like(3 + eff * loyal + pe + rng.normal(0, 1, n))
for j in (1, 2, 3): d[f"loyal{j}"] = like(3 + 2 * loyal + .6 * pe + rng.normal(0, .8, n))
d["loyal_comb"] = (d["loyal1"] + d["loyal2"] + d["loyal3"]) / 3
for a in ["magnitude1", "magnitude2", "prob_effect1", "prob_effect2", "temp_imm1", "temp_imm2", "proxim_eff1", "proxim_eff2", "social_cons1", "social_cons2", "concen_eff1", "concen_eff2", "pie1", "pie2", "pie3", "pie4", "gender_person", "yearsknown", "poli_1", "industry"]:
    d[a] = noise(n)
for a in ["magnitude1", "prob_effect2", "temp_imm2", "proxim_eff1", "social_cons2", "concen_eff1", "pie4"]: d[a + "_rev"] = 8 - d[a]
d["you_grant"] = d["you_grant"].astype(object); d["you_grant"][11] = None
write(1, d, n)
# dataset 2
n = 111; c = rng.integers(0, 2, n); d = {"cond_recode": c, "cond_num": np.where(c == 1, 1, 2), "cond": np.where(c == 1, "loyal_colleague", "control"), "age": rng.integers(20, 66, n), "gender": rng.choice([1, 2, 3], n, p=[.48, .48, .04]), "poli_1": noise(n), "industry": rng.integers(1, 20, n)}
d["comp1"] = np.where(c == 1, 1, 2); d["comp2"] = np.full(n, 2); d["comp1"][:4] = 3; d["comp2"][2:6] = 1
lat = {}
for k, items, e in (("benev_trust_broker", ["bentrust_broker1", "bentrust_broker2", "bentrust_broker3"], 1.2), ("integ_trust_broker", ["inttrust_broker1", "inttrust_broker2", "inttrust_broker3"], .7), ("val_align_part_broker", ["me_broker_valal1", "me_broker_valal2"], 1.0), ("relconcerns_with_broker", ["broker_rep1", "broker_rep2", "broker_rep3"], 1.1)):
    l = 3 + e * c + rng.normal(0, 1, n); lat[k] = l
    for it in items: d[it] = like(l + rng.normal(0, .5, n))
    d[k] = np.mean([d[it] for it in items], axis=0)
for k in ("you_grant", "prom_voice", "proh_voice"): d[k] = like(1 + .4 * lat["benev_trust_broker"] + .2 * lat["relconcerns_with_broker"] + rng.normal(0, 1, n))
for k in ["bentrust_accused1", "bentrust_accused2", "bentrust_accused3", "inttrust_accused1", "inttrust_accused2", "inttrust_accused3", "accept_risk", "loyal_broker", "loyal_accused"]: d[k] = noise(n)
for s in ("pre", "post"):
    b = rng.normal(4, 1, n)
    for j in (1, 2, 3): d[f"group_cohesion{j}_{s}"] = like(b + rng.normal(0, .6, n))
    d[f"group_cohesion_{s}"] = np.mean([d[f"group_cohesion{j}_{s}"] for j in (1, 2, 3)], axis=0)
for q in ["benev_trust_accused", "integ_trust_accused"]: d[q] = noise(n)
write(2, d, n)
# dataset 3
n = 147; r = rng.integers(0, 2, n); h = rng.integers(0, 2, n)
d = {"cond_rel_recode": r, "cond_brokhist_recode": h, "cond_rel": np.where(r == 1, "loyal_colleague", "control"), "broker_hist": np.where(h == 1, "divisive", "control"), "cond_num": np.select([(r == 1) & (h == 0), (r == 0) & (h == 0), (r == 1) & (h == 1)], [1, 2, 3], 4), "age": rng.integers(20, 66, n), "gender": rng.choice([1, 2, 3], n, p=[.48, .48, .04]), "poli_1": noise(n), "industry": rng.integers(1, 20, n)}
d["comp1"] = np.where(r == 1, 1, 2); d["comp2"] = np.full(n, 2); d["comp3"] = np.where(h == 1, 2, 1); d["attn_afterscen"] = np.array([0, 1, 3, 2, 4])[d["cond_num"]]
d["comp3"][:3] = 2 - (h[:3]); d["attn_afterscen"][3:7] = 5; d["comp2"][7:9] = 3
for k, items, e, f in (("benev_trust_broker", ["bentrust_broker1", "bentrust_broker2", "bentrust_broker3"], 1.5, -.5), ("integ_trust_broker", ["inttrust_broker1", "inttrust_broker2", "inttrust_broker3"], 1, -1), ("val_align_part_broker", ["me_broker_valal1", "me_broker_valal2"], 1, -.7), ("relconcerns_with_broker", ["broker_rep1", "broker_rep2", "broker_rep3"], 1.5, -.2)):
    l = 3 + e * r + f * h + rng.normal(0, 1, n)
    for it in items: d[it] = like(l + rng.normal(0, .5, n))
    d[k] = np.mean([d[it] for it in items], axis=0)
for k in ("you_grant", "prom_voice", "proh_voice"): d[k] = like(2 + .6 * r - .4 * h + rng.normal(0, 1.2, n))
write(3, d, n)
# dataset 4
n = 61; l = like(rng.normal(5.5, 1.2, n)).astype(float); l[3] = np.nan
d = {"LoyalRequestor": [None if np.isnan(x) else int(x) for x in l]}
ll = np.nan_to_num(l, nan=5)
d["Signed"] = (rng.uniform(0, 1, n) < 1 / (1 + np.exp(4 - .8 * (ll - 3)))).astype(int)
for k in ["KnowRequestor", "LikeRequestor", "TrustRequestor"]: d[k] = like(rng.normal(5.5, 1, n))
d["SemestersRequestor"] = rng.integers(1, 8, n)
for j in (1, 2, 3): d[f"LoyalHouse{j}"] = like(rng.normal(5.5, 1, n))
d["LoyaltyHouse"] = np.mean([d[f"LoyalHouse{j}"] for j in (1, 2, 3)], axis=0)
d["StrongLoyaltyRequestor"] = [None if np.isnan(x) else int(x == 7) for x in l]
d["ExpLoyaltyRequestor"] = [None if np.isnan(x) else float(np.exp(x / 7)) for x in l]
d["SignedTrust"] = like(2 + .3 * ll + d["Signed"] + rng.normal(0, 1, n)); d["SignedRisk"] = like(rng.normal(3, 1.3, n))
d["Age"] = rng.integers(18, 24, n); d["Requestee"] = np.arange(1, n + 1)
write(4, d, n)
print("written", OUT)
