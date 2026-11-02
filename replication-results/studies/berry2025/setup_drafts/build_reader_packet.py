"""Freeze the identical reader packet: article, appendix, preregistrations, dictionaries."""
import csv
import hashlib
import json
import os
import shutil
import subprocess

import pandas as pd

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(STUDY, "data/raw/osf_3h6vc")
OUT = os.path.join(STUDY, "packet/reader_v1")
PDFTOTEXT = "/opt/homebrew/bin/pdftotext"
os.makedirs(OUT, exist_ok=True)

pdfs = {
    "D01_article.pdf": os.path.join(STUDY, "packet/berry2025.pdf"),
    "D02_appendixA_materials.pdf": os.path.join(RAW, "AppendixA.pdf"),
    "D03_online_appendix.pdf": os.path.join(STUDY, "packet/berry2025_online_appendix.pdf"),
}
for i in (1, 2, 3, 4):
    pdfs[f"D1{i}_prereg_study{i}.pdf"] = os.path.join(RAW, f"Study {i}/study{i}_pre-registration_ltran.pdf")
for name, src in pdfs.items():
    dest = os.path.join(OUT, name)
    shutil.copyfile(src, dest)
    subprocess.run([PDFTOTEXT, "-layout", dest, dest[:-4] + ".txt"], check=True)

shutil.copyfile(os.path.join(RAW, "Study 2/study2_preregistration_deviation_report.docx"),
                os.path.join(OUT, "D22_deviation_report_study2.docx"))

# Dictionaries only. No data rows. Study 4 gets the header because its dictionary does not match.
for i in (1, 2, 3):
    d = pd.read_excel(os.path.join(RAW, f"Study {i}/study{i}_datadict_ltran.xlsx"), dtype=str)
    d.to_csv(os.path.join(OUT, f"D3{i}_dictionary_study{i}.csv"), index=False, quoting=csv.QUOTE_ALL)
    cols = pd.read_csv(os.path.join(RAW, f"Study {i}/study{i}_data_ltran.csv"), nrows=0).columns.tolist()
    with open(os.path.join(OUT, f"D4{i}_columns_study{i}.txt"), "w") as fh:
        fh.write("\n".join(cols))
d = pd.read_excel(os.path.join(RAW, "Study 4/studyS4_datadict_ltran.xlsx"), dtype=str)
d.to_csv(os.path.join(OUT, "D34_dictionary_filed_in_study4_folder.csv"), index=False, quoting=csv.QUOTE_ALL)
cols = pd.read_csv(os.path.join(RAW, "Study 4/study4_data_ltran.csv"), nrows=0).columns.tolist()
with open(os.path.join(OUT, "D44_columns_study4.txt"), "w") as fh:
    fh.write("\n".join(cols))

manifest = {}
for f in sorted(os.listdir(OUT)):
    if f != "PACKET_SHA256.json":
        with open(os.path.join(OUT, f), "rb") as fh:
            manifest[f] = hashlib.sha256(fh.read()).hexdigest()
with open(os.path.join(OUT, "PACKET_SHA256.json"), "w") as fh:
    json.dump(manifest, fh, indent=1)
print(len(manifest), "files;", "study4 columns:", cols)
