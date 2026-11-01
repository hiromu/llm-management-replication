"""Build the implementer data bundle from data/raw/ into data/derived/bundle_v1/.

No rows are filtered. Files are copied byte for byte except two columns:
- h12.csv column 3 (OpenStreetMap user names) -> U<n>, numbered by first appearance, so equal names get equal codes.
- osm-events.csv field_3 (free-text event description, can contain handles) -> E<n>, same rule.
No mapping is stored and no original value is printed. File names keep the deposit's base names, which name
no article, author or journal.
"""
import csv, hashlib, json, os, shutil

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(STUDY, "data/raw/osf_a47e9/rawdata")
OUT = os.path.join(STUDY, "data/derived/bundle_v1")
os.makedirs(OUT, exist_ok=False)


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def recode(src, dst, delim, col, prefix, header):
    """col is a 0-based index, or a header name when header is True."""
    codes, n = {}, 0
    with open(src, newline="", encoding="utf-8") as fi, open(dst, "w", newline="", encoding="utf-8") as fo:
        r = csv.reader(fi, delimiter=delim)
        w = csv.writer(fo, delimiter=delim, lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
        for i, row in enumerate(r):
            if header and i == 0:
                col = row.index(col)
            else:
                v = row[col]
                if v not in codes:
                    codes[v] = f"{prefix}{len(codes) + 1}"
                row[col] = codes[v]
            w.writerow(row)
            n += 1
    return n, len(codes)


changes = []
for f in sorted(os.listdir(RAW)):
    src, dst = os.path.join(RAW, f), os.path.join(OUT, f)
    if f == "h12.csv":
        n, k = recode(src, dst, "\t", 2, "U", header=False)
        changes.append({"file": f, "column": "column 3 (no header)", "content": "OpenStreetMap user names",
                        "action": "replaced by U<n> codes numbered by first appearance; equality preserved; no mapping stored",
                        "rows_written": n, "distinct_codes": k})
    elif f == "osm-events.csv":
        n, k = recode(src, dst, "\t", "field_3", "E", header=True)
        changes.append({"file": f, "column": "field_3", "content": "free-text event description; may contain personal handles",
                        "action": "replaced by E<n> codes numbered by first appearance; equality preserved; no mapping stored",
                        "rows_written": n, "distinct_codes": k})
    else:
        shutil.copyfile(src, dst)

tiger_src = os.path.join(STUDY, "data/raw/census_tiger2010/tl_2010_us_county10.zip")
shutil.copyfile(tiger_src, os.path.join(OUT, "tl_2010_us_county10.zip"))

reviewed = {
    "maptimes.csv": "location (city and state), title (group handle), name (county), state_name: names of public community groups and places, not persons; kept",
    "osm-events.csv": "field_4 (6 event-type labels), name (county), state_name kept; field_3 recoded",
    "county_lookup.csv": "NAME (county), STATE_NAME: place names; kept",
    "land_area.csv": "Areaname: place names; kept",
    "tiger_census_2008q2.csv": "county: place names; kept",
    "tiger_osm_2018.csv": "county: place names; kept",
    "timing.xlsx": "County: place names; SB Selected: one-letter code; kept",
    "google_trends.csv": "States/Quarter: state names; kept",
    "amenitycheck.csv": "integer columns only; kept",
    "distance.csv": "coordinates and distances; no names; kept",
    "boundary-counties.csv": "FIPS codes only; kept",
    "acs5year.dta": "numeric only; kept",
    "quarterly.csv": "numeric counts and keys; kept, including embedded header lines",
    "h12.csv": "columns 1, 2, 4, 5 are ids, timestamps, a 46-value category and a small integer; kept; column 3 recoded",
}
files = {f: sha(os.path.join(OUT, f)) for f in sorted(os.listdir(OUT))}
json.dump({"bundle": "bundle_v1", "built_by": "code/build_bundle.py", "source": "data/raw (validated in logs/deposit_validation_pre.json)",
           "prior_failed_build": "A first build on 2026-11-01 recoded osm-events.csv column index 3 (the county name) instead of field_3 (index 2). It was never used and is kept, unchanged, as data/derived/bundle_v0_failed_do_not_use/; its field_3 text equals data/raw. The script now selects the column by header name.",
           "rows_filtered": 0, "changes": changes, "free_text_review": reviewed, "files_sha256": files},
          open(os.path.join(STUDY, "logs/bundle_v1_record.json"), "w"), indent=1)
print(json.dumps(changes, indent=1))
print(len(files), "files")
