"""Audit: independent transcription check of sealed targets (sealed/targets_v2.json) against the article PDF.

Re-extracts the article text with pdftotext -layout (independent of sources/publication), parses Table 1, Table 2
and the Method-text Ns, and compares every parsed cell with the sealed printed string and numeric value.
Reports (a) a random sample of >= 60 cells drawn with random.Random(2010) from all keyed cells and
(b) the full required sets: 15 d, 15 latent mean/SD/CI/SE groups, all Table 2 cells, 6 form Ns.
Run from the study root: ~/.venv/bin/python -I checks/audit/transcription_audit.py <scratch_dir>
"""
import json, re, subprocess, sys, random, os

SCR = sys.argv[1]
PDF = "../../papers/journal_collection/JOM/JOM_2010_Twenge.pdf"
txt_path = os.path.join(SCR, "audit_article_layout.txt")
subprocess.run(["pdftotext", "-layout", PDF, txt_path], check=True)
pages = open(txt_path, encoding="utf-8").read().split("\f")
T = json.load(open("sealed/targets_v2.json"))

norm = lambda s: s.replace("−", "-").replace("–", "-").replace(" ", "")
NUM = re.compile(r"[−-]?\d*\.\d+\*{0,3}|\b\d{1,3}(?:,\d{3})+\b|\b\d+\b")


def find_line(page_lines, label):
    key = re.sub(r"[^a-z]", "", label.lower())[:22]
    for i, l in enumerate(page_lines):
        if key and key in re.sub(r"[^a-z]", "", l.lower()):
            return i
    return None


# ---- Table 1 parse (pages 11-13 of the PDF = index 10-12)
t1_lines = []
for pi in (10, 11, 12):
    t1_lines += [(pi + 1, l) for l in pages[pi].split("\n")]
lines_only = [l for _, l in t1_lines]


def row_tokens(i):
    """Numbers on the label line (after the label text) and parenthesized numbers on following lines."""
    l = lines_only[i]
    body = l[38:] if len(l) > 38 else ""
    toks = re.findall(r"\d\.\d\d-\s?\d\.\d\d|[−-]?\d*\.\d+\*{0,3}", body)
    par = []
    for j in range(i + 1, min(i + 3, len(lines_only))):
        par += re.findall(r"\(([\d.]+)\)", lines_only[j])
        if par:
            break
    return toks, par


parsed = {}
LAT = {"K1": "Leisure rewards", "K2": "Intrinsic rewards", "K3": "Altruistic rewards", "K4": "Social rewards", "K5": "Extrinsic rewards"}
YRS = ["1976", "1991", "2006"]
for K, lab in LAT.items():
    i = next(k for k, l in enumerate(lines_only) if l.strip().startswith(lab))
    toks, par = row_tokens(i)
    # toks: 3 means, 3 CIs, 3 d ; par: 3 SDs, 3 SEs
    for j, y in enumerate(YRS):
        parsed[f"latent.{K}_{y}.mean"] = toks[j]
        parsed[f"latent.{K}_{y}.ci"] = toks[3 + j]
        parsed[f"latent.{K}_{y}.sd"] = f"({par[j]})"
        parsed[f"latent.{K}_{y}.se"] = f"({par[3 + j]})"
    for j, P in enumerate(["P1", "P2", "P3"]):
        parsed[f"d.{K}_{P}"] = toks[6 + j]

for V, tv in T["items"].items():
    lab = tv["mean_1976"]["locator"]["row"]
    i = find_line(lines_only, lab)
    if i is None:
        continue
    toks, par = row_tokens(i)
    if len(toks) < 9:
        parsed[f"items.{V}.PARSE_FAIL"] = str(toks)
        continue
    for j, y in enumerate(YRS):
        parsed[f"items.{V}.mean_{y}"] = toks[j]
        parsed[f"items.{V}.pct_{y}"] = toks[3 + j]
        parsed[f"items.{V}.sd_{y}"] = f"({par[j]})" if j < len(par) else None
    for j, P in enumerate(["P1", "P2", "P3"]):
        parsed[f"items.{V}.t_{P}"] = toks[6 + j]

# ---- Table 2 parse (PDF page 14 = index 13)
p14 = pages[13].split("\n")
group = None
GRP = {"1976 administration": "1976 administration", "1991 administration": "1991 administration", "2006 administration": "2006 administration"}
for l in p14:
    s = l.strip()
    if s in GRP or s.split("\t")[0].strip() in GRP:
        group = s.split("\t")[0].strip()
        continue
    m = re.match(r"(Form [34]: \d factor|Model 1: configural inv|Model 2: metric invariance|Model 3: scalar invariance|"
                 r"Model 4: partial scalar|Model 5: mean invariance|Delta Model \d vs\. Model \d)\s+(.*)$", s)
    if not m:
        continue
    name, rest = m.group(1).strip(), m.group(2)
    vals = re.findall(r"\d+\.\d+\*{0,3}|\.\d+\*{0,3}|\d+", rest)
    if name.startswith("Delta"):
        for q, v in zip(["delta df", "delta chi-square", "delta CFI"], vals):
            parsed[f"fit.{name}|nested model comparison|{q}"] = v
    else:
        g = group if name.startswith("Form") else "three-group (1976, 1991, 2006) Form 4 five-factor model"
        for q, v in zip(["df", "chi-square", "RMSEA", "SRMSR", "TLI", "CFI"], vals):
            parsed[f"fit.{name}|{g}|{q}"] = v

# ---- Ns (PDF page 10 = index 9)
p10 = " ".join(pages[9].split())
m = re.search(r"1976, n = ([\d,]+) and ([\d,]+).*?2006, n = ([\d,]+) and ([\d,]+)\).*?1991, n = ([\d,]+) and ([\d,]+)\)", p10)
parsed.update({"N.f3_1976": m.group(1), "N.f4_1976": m.group(2), "N.f3_2006": m.group(3), "N.f4_2006": m.group(4),
               "N.f3_1991": m.group(5), "N.f4_1991": m.group(6)})
mt = re.search(r"Total sample size across all three generations and the two forms was ([\d,]+)", p10)
parsed["unkeyed.T007"] = mt.group(1)

# ---- sealed cells
cells = {}
for k, v in T["d"].items():
    cells[f"d.{k}"] = v
for k, v in T["latent"].items():
    for q, c in v.items():
        cells[f"latent.{k}.{q}"] = c
for V, tv in T["items"].items():
    for q, c in tv.items():
        cells[f"items.{V}.{q}"] = c
for f in T["fit"]:
    cells[f"fit.{f['model']}|{f['group']}|{f['quantity']}"] = f
for k, v in T["N"].items():
    cells[f"N.{k}"] = v


def check(key, c):
    p = parsed.get(key)
    if p is None:
        return {"cell": key, "target_id": c["target_id"], "sealed_printed": c["printed"], "pdf": None, "result": "not_parsed"}
    sp = norm(c["printed"])
    pp = norm(p)
    # the CI cell stores the full printed range with the lower bound as value
    ok_str = sp == pp
    try:
        pv = float(re.sub(r"[^\d.\-]", "", pp.split("-")[0] if key.endswith(".ci") else pp.replace(",", "").strip("()*")))
    except ValueError:
        pv = None
    ok_val = c["value"] is not None and pv is not None and abs(pv - c["value"]) < 1e-9
    stars_ok = True
    if "stars" in c:
        stars_ok = c["stars"] == pp.count("*")
    return {"cell": key, "target_id": c["target_id"], "sealed_printed": c["printed"], "sealed_value": c["value"], "pdf": p,
            "result": "match" if (ok_str and ok_val and stars_ok) else "MISMATCH",
            "string_match": ok_str, "value_match": ok_val, "stars_match": stars_ok}


all_res = {k: check(k, c) for k, c in cells.items()}
rng = random.Random(2010)
keys_sorted = sorted(cells)
sample = rng.sample(keys_sorted, 80)
required = [k for k in keys_sorted if k.startswith(("d.", "latent.", "fit.", "N."))]
out = {
    "pdf": PDF, "pdf_text_tool": subprocess.run(["pdftotext", "-v"], capture_output=True, text=True).stderr.split("\n")[0],
    "rng": "random.Random(2010).sample(sorted(cell keys), 80)", "n_cells_total": len(cells),
    "random_sample": [all_res[k] for k in sample],
    "required_sets": [all_res[k] for k in required],
    "all_cells_summary": {r: sum(1 for x in all_res.values() if x["result"] == r) for r in ("match", "MISMATCH", "not_parsed")},
    "all_non_matches": [x for x in all_res.values() if x["result"] != "match"],
    "unkeyed_T007": {"sealed": next(u["printed"] for u in T["unkeyed"] if u["target_id"] == "T007"), "pdf": parsed["unkeyed.T007"]},
}
json.dump(out, open("checks/audit/transcription_audit.json", "w"), indent=1, ensure_ascii=False)
print(json.dumps(out["all_cells_summary"]), "sample:", sum(1 for x in out["random_sample"] if x["result"] == "match"), "/", len(sample),
      "required:", sum(1 for x in out["required_sets"] if x["result"] == "match"), "/", len(required))
for x in out["all_non_matches"]:
    print(x)
print(out["unkeyed_T007"])
