"""Freeze the identical reader packet. Adopted from setup_drafts/build_reader_packet.py with changes:
writes to packet/frozen_v1, adds a text form of the Study 2 deviation report and scans dictionaries."""
import csv, hashlib, json, os, re, shutil, subprocess
import pandas as pd

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(STUDY, "data/raw/osf_3h6vc")
OUT = os.path.join(STUDY, "packet/frozen_v1")
PDFTOTEXT = "/opt/homebrew/bin/pdftotext"
os.makedirs(OUT, exist_ok=False)

pdfs = {"D01_article.pdf": ("packet/berry2025.pdf", "the article"),
        "D02_appendixA_materials.pdf": ("data/raw/osf_3h6vc/AppendixA.pdf", "deposit study materials"),
        "D03_online_appendix.pdf": ("packet/berry2025_online_appendix.pdf", "Online Appendix; Studies S1-S7 out of scope")}
for i in (1, 2, 3, 4):
    pdfs[f"D1{i}_prereg_study{i}.pdf"] = (f"data/raw/osf_3h6vc/Study {i}/study{i}_pre-registration_ltran.pdf", f"preregistration Study {i}")
docs = []
for name, (src, role) in pdfs.items():
    dest = os.path.join(OUT, name)
    shutil.copyfile(os.path.join(STUDY, src), dest)
    subprocess.run([PDFTOTEXT, "-layout", dest, dest[:-4] + ".txt"], check=True)
    docs.append((name, src, role))
docx_src = "data/raw/osf_3h6vc/Study 2/study2_preregistration_deviation_report.docx"
shutil.copyfile(os.path.join(STUDY, docx_src), os.path.join(OUT, "D22_deviation_report_study2.docx"))
subprocess.run(["/usr/bin/textutil", "-convert", "txt", "-output", os.path.join(OUT, "D22_deviation_report_study2.txt"),
                os.path.join(OUT, "D22_deviation_report_study2.docx")], check=True)
docs.append(("D22_deviation_report_study2.docx", docx_src, "Study 2 deviation report"))

flag = re.compile(r"\b(mean|sd|std|median|min|max|n\s*=|frequency|freq|percent|missing)\b", re.I)
scan = {}
for i, f in {1: "Study 1/study1_datadict_ltran.xlsx", 2: "Study 2/study2_datadict_ltran.xlsx",
             3: "Study 3/study3_datadict_ltran.xlsx", 4: "Study 4/studyS4_datadict_ltran.xlsx"}.items():
    d = pd.read_excel(os.path.join(RAW, f), dtype=str)
    name = f"D3{i}_dictionary_study{i}.csv" if i < 4 else "D34_dictionary_filed_in_study4_folder.csv"
    d.to_csv(os.path.join(OUT, name), index=False, quoting=csv.QUOTE_ALL)
    hits = [c for c in d.fillna("").astype(str).agg(" ".join, axis=1) if flag.search(c)]
    scan[name] = {"rows": len(d), "summary_stat_pattern_hits": hits}
    data = f"Study {i}/study{i}_data_ltran.csv"
    cols = pd.read_csv(os.path.join(RAW, data), nrows=0, encoding="utf-8-sig").columns.tolist()
    with open(os.path.join(OUT, f"D4{i}_columns_study{i}.txt"), "w") as fh:
        fh.write("\n".join(cols))
    docs.append((name, f, f"dictionary filed with Study {i}"))
    docs.append((f"D4{i}_columns_study{i}.txt", data, f"column names only, Study {i}"))

files = {f: hashlib.sha256(open(os.path.join(OUT, f), "rb").read()).hexdigest() for f in sorted(os.listdir(OUT))}
packet = {"version": "frozen_v1", "study_id": "berry2025", "order": [d[0] for d in docs], "documents": [
    {"id": d[0], "source": d[1], "role": d[2], "sha256": files[d[0]], "text_form": d[0].rsplit(".", 1)[0] + ".txt" if d[0].rsplit(".", 1)[0] + ".txt" in files else None,
     "identity_check": "byte copy of the source"} for d in docs],
    "all_files_sha256": files,
    "known_gaps": ["No dictionary for the Study 4 data file: the file in the Study 4 folder is byte-identical to the Study S4 dictionary and shares no variable names with the Study 4 columns.",
                   "Three Study 3 data columns are absent from its dictionary."],
    "dictionary_summary_stat_scan": scan,
    "note": "Text forms are mechanical conversions; PDF page numbers come from the PDFs."}
json.dump(packet, open(os.path.join(STUDY, "packet/publication_packet.json"), "w"), indent=1)
print(len(files), "files"); print(json.dumps(scan, indent=0)[:1500])
