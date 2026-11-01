"""Internal check: UNDP HDR PDFs (country names and indicator labels present in text layer),
World Bank Doing Business historical file (economies and DB years), OGHIST (classification years).
Presence only; no values written. Usage: python -I hdr_db_oghist_check.py <study_dir>"""
import sys, os, subprocess, json, re, openpyxl
st = sys.argv[1]; raw = os.path.join(st, "data", "raw")
NAMES = ["Australia","Austria","Belgium","Canada","Czech Republic","Denmark","Finland","France","Germany","Greece",
         "Iceland","Ireland","Italy","Japan","Netherlands","New Zealand","Norway","Poland","Portugal","Spain","Sweden",
         "Switzerland","United Kingdom","United States"]
res = {"undp_hdr": {}, "worldbank_doing_business": {}, "worldbank_income_class": {}}
for f in sorted(os.listdir(os.path.join(raw, "undp_hdr"))):
    t = subprocess.run(["/opt/homebrew/bin/pdftotext", "-layout", os.path.join(raw, "undp_hdr", f), "-"], capture_output=True, text=True).stdout
    res["undp_hdr"][f] = {
        "label_GDP_index": len(re.findall(r"GDP\s+index", t, re.I)),
        "label_female_legislators_officials_managers": len(re.findall(r"legislators,\s+senior\s+officials\s+and\s+managers", t, re.I)),
        "label_income_index": len(re.findall(r"income\s+index", t, re.I)),
        "countries_missing_from_text": [n for n in NAMES if n not in t],
    }
wb = openpyxl.load_workbook(os.path.join(raw, "worldbank_doing_business", "Historical-data---COMPLETE-dataset-with-scores.xlsx"), read_only=True)
res["worldbank_doing_business"]["sheets"] = wb.sheetnames
ws = wb[wb.sheetnames[0]]
rows = ws.iter_rows(values_only=True)
hdr = None; econ = set(); dbyears = set()
for r in rows:
    if hdr is None:
        if r and any(isinstance(c, str) and c.strip().lower() in ("economy", "country code") for c in r): hdr = [str(c).strip() if c else "" for c in r]
        continue
    if not r: continue
    d = dict(zip(hdr, r)); econ.add(d.get("Economy")); dbyears.add(d.get("DB Year"))
res["worldbank_doing_business"]["header_columns_first40"] = hdr[:40] if hdr else None
res["worldbank_doing_business"]["db_years"] = sorted(y for y in dbyears if isinstance(y, (int, float)))
res["worldbank_doing_business"]["paper_countries_missing"] = [n for n in NAMES if not any(isinstance(e, str) and e.startswith(n.replace("Czech Republic", "Czech")) for e in econ)]
wb = openpyxl.load_workbook(os.path.join(raw, "worldbank_income_class", "OGHIST.xlsx"), read_only=True)
res["worldbank_income_class"]["sheets"] = wb.sheetnames
json.dump(res, open(os.path.join(st, "registry", "validation", "hdr_doingbusiness_oghist_check_INTERNAL.json"), "w"), indent=1, default=str)
print(json.dumps(res, indent=1, default=str)[:4000])
