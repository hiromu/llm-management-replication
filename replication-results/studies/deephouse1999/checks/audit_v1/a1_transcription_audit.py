"""Audit task 1: transcription audit of Table 2 (DOC01 PDF p12 = printed p158) and the p13 text values.

Auditor values below were read by the auditor from sources/packet_v1/pages/DOC01_p12.png and DOC01_p13 text
(pdftotext -layout of papers/journal_collection/SMJ/SMJ_1999_Deephouse.pdf pages 12-13), independently of the
reader files, then compared with both readers' sealed targets. Also checks the internal arithmetic of the
printed SSE / delta SSE / F statistics.
Run: ~/.venv/bin/python -I checks/audit_v1/a1_transcription_audit.py <STUDY>
"""
import json, sys, csv
from pathlib import Path

ST = Path(sys.argv[1]); OUT = ST / "checks/audit_v1"

# auditor reading: (model, term) -> (coef, se, stars)
AUD = {
    ("M1", "intercept"): (0.929, 0.169, "***"), ("M1", "MS"): (-0.576, 0.138, "***"),
    ("M1", "TER"): (-9.948, 2.001, "***"), ("M1", "RMG"): (0.014, 0.004, "***"), ("M1", "lag"): (0.369, 0.028, "***"),
    ("M2", "intercept"): (1.164, 0.172, "***"), ("M2", "SD"): (-0.020, 0.004, "***"), ("M2", "MS"): (-0.093, 0.161, ""),
    ("M2", "TER"): (-10.601, 1.974, "***"), ("M2", "RMG"): (0.016, 0.004, "***"), ("M2", "lag"): (0.361, 0.027, "***"),
    ("M3", "intercept"): (0.511, 0.171, "**"), ("M3", "SD2"): (-0.006, 0.001, "***"), ("M3", "SD"): (0.170, 0.017, "***"),
    ("M3", "MS"): (-0.457, 0.155, "**"), ("M3", "TER"): (-15.387, 1.895, "***"), ("M3", "RMG"): (0.018, 0.003, "***"),
    ("M3", "lag"): (0.403, 0.026, "***"),
}
AUD_SSE = {"M1": 2.978, "M2": 2.886, "M3": 2.530}
AUD_DSSE = {"M2 vs M1": (0.092, "***", 30.4, (1, 954), "p<0.001"), "M3 vs M1": (0.448, "***", 84.4, (2, 953), "p<0.001"),
            "M3 vs M2": (0.356, "***", 134.1, (1, 953), "p<0.001")}
AUD_SQ = {"coef": -0.001, "se": 0.0001, "SSE": 2.803, "text": "remained negative and significant"}
AUD_N = 960

MODEL = {"Model 1": "M1", "Model 2": "M2", "Model 3": "M3", "M1": "M1", "M2": "M2", "M3": "M3"}
def term_of(s):
    s = s.replace("²", "^2").replace("−", "-")
    if s.startswith("Intercept"): return "intercept"
    if s.startswith("Strategic Deviation^2"): return "SD2"
    if s.startswith("Strategic Deviation"): return "SD"
    if s.startswith("Market Share"): return "MS"
    if s.startswith("Total Expense"): return "TER"
    if s.startswith("Real Market"): return "RMG"
    if s.startswith("Relative ROA"): return "lag"
    return None

A = json.load(open(ST / "readers/fable/initial_v1/out/sealed_targets.json"))["targets"]
B = json.load(open(ST / "readers/astra/initial_v1/out/sealed_targets.json"))

def index(tg):
    out, sse, f, sq = {}, {}, {}, None
    for t in tg:
        if t.get("table") == "Table 2":
            m = MODEL.get(t["model"]); rt = t["row_term"]
            if "Sum of squared errors" in rt and "elta" not in rt and "Δ" not in rt and "over" not in rt:
                sse[m] = t["other_stats"]["SSE"]; continue
            if "over" in rt:
                key = f"{m} vs " + ("M1" if rt.endswith(("Model 1", "M1")) else "M2")
                os_ = t.get("other_stats") or {}
                f[key] = (os_.get("delta_SSE"), (t.get("test_statistic") or {}).get("value"), t.get("stars_or_inequality"))
                continue
            tm = term_of(rt)
            if tm and t.get("coefficient") is not None:
                out[(m, tm)] = (t["coefficient"], t["published_se"], (t.get("stars_or_inequality") or ""), t.get("n"))
        elif t.get("model") in ("Model 3 without first-order term", "M3_SQ"):
            sq = (t["coefficient"], t["published_se"], (t.get("other_stats") or {}).get("SSE"))
    return out, sse, f, sq

rows, mism = [], []
for name, tg in [("ReaderA_fable", A), ("ReaderB_astra", B)]:
    co, sse, f, sq = index(tg)
    for k, (c, s, st) in AUD.items():
        r = co.get(k)
        ok = r is not None and abs(r[0] - c) < 1e-9 and abs(r[1] - s) < 1e-9 and r[2].strip() == st and r[3] == AUD_N
        rows.append([name, k[0], k[1], c, s, st, None if r is None else r[0], None if r is None else r[1],
                     None if r is None else r[2], None if r is None else r[3], ok])
        if not ok: mism.append((name, k))
    for m, v in AUD_SSE.items():
        ok = abs(sse.get(m, -1) - v) < 1e-9
        rows.append([name, m, "SSE", v, None, None, sse.get(m), None, None, None, ok])
        if not ok: mism.append((name, m, "SSE"))
    for k, (d, st, F, df, _) in AUD_DSSE.items():
        r = f.get(k)
        ok = r is not None and abs(r[0] - d) < 1e-9 and abs(r[1] - F) < 1e-9 and r[2] is not None and r[2].startswith("***")
        rows.append([name, k, "deltaSSE|F|stars", f"{d}|{F}|{st}", None, None, None if r is None else f"{r[0]}|{r[1]}|{r[2]}", None, None, None, ok])
        if not ok: mism.append((name, k))
    ok = sq is not None and abs(sq[0] - AUD_SQ["coef"]) < 1e-12 and abs(sq[1] - AUD_SQ["se"]) < 1e-12 and abs(sq[2] - AUD_SQ["SSE"]) < 1e-12
    rows.append([name, "M3_SQ", "SD2|SE|SSE", f"{AUD_SQ['coef']}|{AUD_SQ['se']}|{AUD_SQ['SSE']}", None, None, str(sq), None, None, None, ok])
    if not ok: mism.append((name, "M3_SQ"))

with open(OUT / "a1_transcription_audit.csv", "w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["reader", "model", "term", "aud_coef", "aud_se", "aud_stars", "rd_coef", "rd_se", "rd_stars", "rd_n", "match"])
    w.writerows(rows)

# internal arithmetic of printed fit statistics (rounding-aware)
N = 960
arith = []
def F(sr, su, q, k):
    return ((sr - su) / q) / (su / (N - k))
arith.append(("dSSE M2-M1", round(2.978 - 2.886, 3), 0.092))
arith.append(("dSSE M3-M1", round(2.978 - 2.530, 3), 0.448))
arith.append(("dSSE M3-M2", round(2.886 - 2.530, 3), 0.356))
arith.append(("F M2 vs M1 (K=6)", round(F(2.978, 2.886, 1, 6), 2), 30.4))
arith.append(("F M3 vs M1 (K=7)", round(F(2.978, 2.530, 2, 7), 2), 84.4))
arith.append(("F M3 vs M2 (K=7)", round(F(2.886, 2.530, 1, 7), 2), 134.1))
arith.append(("F M3_SQ vs M1 implied (K=6)", round(F(2.978, 2.803, 1, 6), 2), "not printed"))
# implied |t| of the single added term and implied SE range given coefficient rounding
imp = []
for lab, Fv, b in [("M2 SD", 30.4, 0.020), ("M3 vs M2 (SD2 given SD)", 134.1, 0.006), ("M3_SQ SD2 (from SSE 2.803)", F(2.978, 2.803, 1, 6), 0.001)]:
    t = Fv ** 0.5
    hb = 0.0005
    imp.append((lab, round(t, 3), round((b - hb) / t, 6), round((b + hb) / t, 6)))
json.dump({"mismatches": [list(map(str, m)) for m in mism], "n_cells_checked_per_reader": len(rows) // 2,
           "arithmetic": arith, "implied_t_and_se_range_from_F": imp,
           "note": "SE implied by F for M3 SD2 must lie in [0.000475,0.000561] given |b| in [0.0055,0.0065]; printed 0.001 requires >=0.0005, so the true SE is about 0.0005, half the printed value."},
          open(OUT / "a1_transcription_summary.json", "w"), indent=1)
print("mismatches:", mism)
for a in arith: print(a)
for i in imp: print(i)
