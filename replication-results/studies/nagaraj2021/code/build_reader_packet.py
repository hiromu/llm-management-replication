"""Freeze the identical reader packet. Setup draft for nagaraj2021, untested."""
import csv, hashlib, json, os, shutil, struct, subprocess, zipfile
import pandas as pd

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(STUDY, "data/raw/osf_a47e9/rawdata")
TIGER = os.path.join(STUDY, "data/raw/census_tiger2010/tl_2010_us_county10.zip")
OUT = os.path.join(STUDY, "packet/frozen_v1")
PDFTOTEXT = shutil.which("pdftotext") or "/opt/homebrew/bin/pdftotext"
HEADERLESS = {"h12.csv"}
os.makedirs(OUT, exist_ok=False)

docs = []
for name, src, role in [("D01_article.pdf", "packet/nagaraj2021.pdf", "the article"),
                        ("D02_online_appendix.pdf", "data/raw/osf_a47e9/writing/appendix.pdf", "online appendix, deposit copy; out of scope as targets")]:
    dest = os.path.join(OUT, name)
    shutil.copyfile(os.path.join(STUDY, src), dest)
    subprocess.run([PDFTOTEXT, "-layout", dest, dest[:-4] + ".txt"], check=True)
    docs.append((name, src, role))
shutil.copyfile(os.path.join(STUDY, "packet/deposit_data_notes.txt"), os.path.join(OUT, "D03_deposit_data_notes.txt"))
docs.append(("D03_deposit_data_notes.txt", "packet/deposit_data_notes.txt", "Rawdata section of the deposit Readme"))


def column_type(values):
    vals = [v for v in values if v not in ("", "NA")]
    for kind, test in [("integer", int), ("number", float)]:
        try:
            [test(v) for v in vals]
            return kind
        except ValueError:
            pass
    if vals and all(len(v) >= 10 and v[4] == "-" and v[7] == "-" for v in vals):
        return "date_or_timestamp_text"
    return "text"


for i, f in enumerate(sorted(os.listdir(RAW)), start=41):
    path, name = os.path.join(RAW, f), f"D{i}_columns_{os.path.splitext(f)[0]}.txt"
    if f.endswith(".csv"):
        with open(path, newline="", encoding="utf-8-sig", errors="replace") as fh:
            sample = fh.read(65536)
        delim = csv.Sniffer().sniff(sample.splitlines()[0], delimiters=",\t;|").delimiter
        rows = list(csv.reader(sample.splitlines()[:1000], delimiter=delim))
        if f in HEADERLESS:
            body = [f"no header row; {len(rows[0])} columns; delimiter {delim!r}"]
            body += [f"column {j + 1}: {column_type([r[j] for r in rows if len(r) > j])}" for j in range(len(rows[0]))]
        else:
            body = [f"delimiter {delim!r}"] + rows[0]
    elif f.endswith(".dta"):
        labels = pd.read_stata(path, iterator=True).variable_labels()
        body = [f"{k}\t{v}" for k, v in labels.items()]
    elif f.endswith(".xlsx"):
        body = [str(c) for c in pd.read_excel(path, nrows=0).columns]
    else:
        continue
    with open(os.path.join(OUT, name), "w") as fh:
        fh.write("\n".join(body) + "\n")
    docs.append((name, f"data/raw/osf_a47e9/rawdata/{f}", "column names only" if f not in HEADERLESS else "column count and types only"))

with zipfile.ZipFile(TIGER) as z:
    dbf = z.read(next(n for n in z.namelist() if n.endswith(".dbf")))
fields, pos = [], 32
while dbf[pos] != 0x0D:
    fields.append(dbf[pos:pos + 11].split(b"\x00")[0].decode())
    pos += 32
with open(os.path.join(OUT, "D60_tiger_fields.txt"), "w") as fh:
    fh.write("Census TIGER/Line 2010 county file (tl_2010_us_county10), attribute fields:\n" + "\n".join(fields) + "\n")
docs.append(("D60_tiger_fields.txt", "data/raw/census_tiger2010/tl_2010_us_county10.zip", "field names only"))

files = {f: hashlib.sha256(open(os.path.join(OUT, f), "rb").read()).hexdigest() for f in sorted(os.listdir(OUT))}
packet = {"version": "frozen_v1", "study_id": "nagaraj2021", "order": [d[0] for d in docs], "documents": [
    {"id": d[0], "source": d[1], "role": d[2], "sha256": files[d[0]],
     "text_form": d[0][:-4] + ".txt" if d[0].endswith(".pdf") else None} for d in docs],
    "all_files_sha256": files,
    "known_gaps": ["The deposit has no variable dictionary; D03 describes files, not columns.",
                   "h12.csv has no header row."],
    "note": "Text forms are mechanical conversions; PDF page numbers come from the PDFs."}
json.dump(packet, open(os.path.join(STUDY, "packet/publication_packet.json"), "w"), indent=1)
print(len(files), "files")
