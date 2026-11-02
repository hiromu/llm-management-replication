import hashlib, json, os, sys, datetime
S = sys.argv[1]
def h(p, algo="sha256"):
    x = hashlib.new(algo); x.update(open(os.path.join(S, p), "rb").read()); return x.hexdigest()
def sz(p): return os.path.getsize(os.path.join(S, p))
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
inv = json.load(open(os.path.join(S, "data/supplied/supplied_sources.json")))["sources"][0]
files = []
for f in inv["file_inventory"]:
    p = "data/supplied/ICPSR_06240/" + f["path"]
    rec = {"path": p, "bytes": sz(p), "sha256": h(p), "sha256_matches_setup_inventory": h(p) == f["sha256"], "bytes_match_inventory": sz(p) == f["bytes"]}
    if "provider_manifest_md5" in f:
        rec.update({"md5": h(p, "md5"), "provider_manifest_md5": f["provider_manifest_md5"], "md5_matches_provider_manifest": h(p, "md5") == f["provider_manifest_md5"]})
    files.append(rec)
le = json.load(open(os.path.join(S, "data/derived/nos1991_v1/loader_equivalence.json")))
reg = {
 "schema_version": 1, "study_id": "delaney1996", "created_utc": now,
 "created_by": "source-acquisition role (Claude Code coordinator subagent, claude-opus-5-5)",
 "sources": [
  {"source_id": "icpsr06240", "type": "user_supplied_original_survey_data",
   "title": "National Organizations Survey (NOS), 1991", "provider": "ICPSR", "study_number": 6240,
   "release": "V1 (ICPSR06240-v1)", "doi": "10.3886/ICPSR06240.v1",
   "provider_original_release_date": "1994-10-17", "provider_version_date": "2006-01-18",
   "codebook_release_statement": "Second ICPSR Release, November 1994 (codebook PDF converted May 1999; manifest date 1999-05-14)",
   "provider_manifest_file_dates": {"06240-0002-Data.por": "1997-06-04", "06240-Codebook.pdf": "1999-05-14", "06240-descriptioncitation.pdf": "2014-07-03"},
   "por_internal_header": {"product": "SPSS Release 4.0 for Sun 4", "creation": "1994-09-19 15:18:36"},
   "path": "data/supplied/ICPSR_06240",
   "provenance": {"acquisition": "Downloaded by hand from ICPSR by the user (a human) under the user's own ICPSR access; no agent downloaded it or logged in to ICPSR.",
                  "user_download_time": "not recorded; TermsOfUse.html states the terms were agreed on 2026-10-27 by the downloading user (date only); filesystem modification times of the files are 2026-10-27 22:36 local time (JST), which is not established as the download time",
                  "setup_copy_time_utc": inv["setup_copy_time_utc"],
                  "location_history": inv["location_history"],
                  "note": "Location history is recorded from the setup inventory only; the earlier location was not inspected."},
   "integrity_check_utc": "2026-10-28T03:31:15Z", "files": files,
   "integrity_result": "all 6 files present; SHA-256 and sizes match the setup inventory; codebook and .por MD5 match the ICPSR manifest",
   "manifest_components_absent": [
      {"file": "DS0001/06240-0001-Data.txt", "note": "fixed-width ASCII version of the same data; not supplied and not needed (DS0002 is complete); not requested"},
      {"file": "DS0001/06240-0001-Setup.sps", "note": "listed in manifest; not offered by ICPSR per setup notes; not needed; not requested"},
      {"file": "06240-descriptioncitation.pdf", "note": "manifest lists PDF; bundle holds 06240-descriptioncitation.html instead (same description content assumed, not verified)"}],
   "validation": {
      "records": 727, "variables": 1016, "matches_manifest_counts": True,
      "unit": "record = GSS-nominated employer (work establishment) linked to one GSS respondent or spouse; 39 records are documented duplicate-employer copies (V3 = 0), leaving 688 distinct establishments per documentation",
      "record_id": "V1 (SRL case identification number; unique per record); SRLID/NOSID copies; GSS person link V5/GSSID/ID; duplicate grouping variables DUP, NUMOBS",
      "weights": "WEIGHT (RAWWGT x 688/83.637; label 'rawwgt adjusted to n=688'), RAWWGT = 1/NEWTOTAL; no weight variable set in .por header; GSS person weights FORMWT/OVERSAMP not applicable to establishments",
      "missing_values": "970 variables carry declared user-missing codes in the .por (one with a range); technical manual states the original SPSS-X file declared none; several declarations are substantive (e.g. 995 'large number of applications') and some non-substantive codes are undeclared (e.g. 997, 'varies/depends' = 4)",
      "loader_equivalence": {k: le[k] for k in le if k.startswith("mismatch") or k.startswith("cells_") or k.startswith("max_abs")},
      "loader_missing_value_handling": le["loader_missing_value_handling"],
      "analytical_coverage": "see registry/coverage_audit.md",
      "embedded_documents_note": "DOCUMENT records in .por inherited from a GSS 1972-1991 cumulative file; not applicable to NOS"},
   "terms_of_use": {"file": "data/supplied/ICPSR_06240/TermsOfUse.html",
      "summary": ["Use solely for research or statistical purposes; no investigation or identification of specific research subjects (individuals or organizations); report inadvertent identification to ICPSR.",
                  "No redistribution of data or other materials without ICPSR written agreement (exceptions for official representatives/collaborating authorized users only).",
                  "Prohibition on sharing ICPSR Membership-sponsored data with persons in specified countries of concern.",
                  "Cite the data in publications and send citations to ICPSR.",
                  "Disclaimer of responsibility by original collectors, ICPSR and funder."],
      "implications_for_study": "Raw and derived microdata stay inside studies/delaney1996; readers receive only summary-free dictionaries; no data publication. ZIP code (V352) and telephone prefixes (V350, V351) are present in the release and are not needed; they should not be used for identification."},
   "focal_author_package": "no (original survey source collection, not a replication package)"},
  {"source_id": "census_io_1980_industry_occupation_code_list", "type": "newly_acquired_public_government_document",
   "title": "1980 Industry and Occupation Code List (Census Bureau); Appendix A-5: 1980 Census of Population Industry Classification System with 1972 SIC code equivalents",
   "provider": "U.S. Census Bureau", "landing_page": "https://www.census.gov/topics/employment/industry-occupation/guidance/code-lists.html",
   "url": "https://www2.census.gov/programs-surveys/demo/guidance/industry-occupation/1980-industry-occupation-code-list.pdf",
   "retrieved_utc": "2026-10-28T03:39:24Z", "http_status": 200, "content_type": "application/pdf",
   "path": "data/raw/census_io_1980_industry_occupation_code_list/1980-industry-occupation-code-list.pdf",
   "bytes": sz("data/raw/census_io_1980_industry_occupation_code_list/1980-industry-occupation-code-list.pdf"),
   "sha256": h("data/raw/census_io_1980_industry_occupation_code_list/1980-industry-occupation-code-list.pdf"),
   "pdf_metadata": "18 pages, scanned image (no text layer), PDF created 2018-07-17",
   "purpose": "crosswalk from 1980 Census industry codes (V43, INDUSTRY) to 1972 SIC for two-digit SIC industry controls",
   "acquired_by": "source-acquisition role via curl"},
  {"source_id": "census_io_1990_census_sic_codes", "type": "newly_acquired_public_government_document",
   "title": "1990 Industrial Classification System (Census Bureau) with 1987 SIC definitions",
   "provider": "U.S. Census Bureau", "landing_page": "https://www.census.gov/topics/employment/industry-occupation/guidance/code-lists.html",
   "url": "https://www2.census.gov/programs-surveys/demo/guidance/industry-occupation/1990-census-sic-codes.pdf",
   "retrieved_utc": "2026-10-28T03:39:25Z", "http_status": 200, "content_type": "application/pdf",
   "path": "data/raw/census_io_1990_census_sic_codes/1990-census-sic-codes.pdf",
   "bytes": sz("data/raw/census_io_1990_census_sic_codes/1990-census-sic-codes.pdf"),
   "sha256": h("data/raw/census_io_1990_census_sic_codes/1990-census-sic-codes.pdf"),
   "pdf_metadata": "4 pages, scanned image", "purpose": "reference for 1987-SIC alternative and for checking the 1980 list (e.g., paints = 285); not transcribed",
   "acquired_by": "source-acquisition role via curl"},
  {"source_id": "census_io_changes_1980_ind_and_occ_classification", "type": "newly_acquired_public_government_document",
   "title": "Changes to the 1980 industry and occupation classifications for the 1990 Census (Census Bureau)",
   "provider": "U.S. Census Bureau", "landing_page": "https://www.census.gov/topics/employment/industry-occupation/guidance/code-lists.html",
   "url": "https://www2.census.gov/programs-surveys/demo/guidance/industry-occupation/changes-1980-ind-and-occ-classification.pdf",
   "retrieved_utc": "2026-10-28T03:39:27Z", "http_status": 200, "content_type": "application/pdf",
   "path": "data/raw/census_io_changes_1980_ind_and_occ_classification/changes-1980-ind-and-occ-classification.pdf",
   "bytes": sz("data/raw/census_io_changes_1980_ind_and_occ_classification/changes-1980-ind-and-occ-classification.pdf"),
   "sha256": h("data/raw/census_io_changes_1980_ind_and_occ_classification/changes-1980-ind-and-occ-classification.pdf"),
   "pdf_metadata": "10 pages, scanned image", "purpose": "context for 1980 vs 1990 code differences; not transcribed",
   "acquired_by": "source-acquisition role via curl"}],
 "derived_products": []}
def add(p, lineage, note, readers=False):
    reg["derived_products"].append({"path": p, "bytes": sz(p), "sha256": h(p), "lineage": lineage, "note": note, "may_go_to_readers": readers})
add("data/derived/nos1991_v1/nos1991_ds0002.csv", ["icpsr06240: DS0002/06240-0002-Data.por", "scripts/por_parser.py", "scripts/02_convert_and_validate.py"], "raw stored codes, all records and variables; for implementers only under role rules")
add("data/derived/nos1991_v1/nos1991_ds0002_metadata.json", ["icpsr06240 .por metadata"], "labels, formats, value labels, declared missing; no statistics")
add("data/derived/nos1991_v1/loader_equivalence.json", ["por_parser.py", "pyreadstat 1.3.3", "haven 2.5.5"], "mismatch counts only")
add("data/derived/nos1991_v1/coverage_counts_coordinator_only.json", ["nos1991_ds0002.csv"], "COORDINATOR ONLY: contains counts")
add("data/derived/census1980_ind_sic1972_v1/census1980_industry_sic1972.csv", ["census_io_1980_industry_occupation_code_list (pages 13-18)", "tesseract 5.5.3 OCR", "scripts/transcribe_census1980_industry.py with visual corrections"], "1980 Census industry codes with printed 1972 SIC equivalents; 232 categories", readers=True)
add("sources/reader_dictionary/nos1991_dictionary.json", ["nos1991_ds0002_metadata.json", "06240-Codebook.pdf Section III wording (frequencies removed)", "scripts/04_build_reader_dictionary.py"], "summary-free reader dictionary", readers=True)
add("sources/reader_dictionary/nos1991_dictionary.md", ["as above"], "summary-free reader dictionary (Markdown)", readers=True)
add("sources/reader_dictionary/nos1991_source_description.md", ["06240-descriptioncitation.html", "06240-Codebook.pdf technical manual and file-creation syntax", ".por header"], "design/release facts only", readers=True)
add("registry/coverage_audit.json", ["nos1991_ds0002_metadata.json", "article Measures section (constructs only)"], "coordinator-facing coverage audit; no counts")
add("registry/coverage_audit.md", ["as above"], "coordinator-facing coverage audit; no counts")
reg["supplied_folder_unchanged_check"] = "re-hashed at registry creation; all hashes match setup inventory"
reg["software"] = le["software"] | {"tesseract": "5.5.3", "pdftoppm/pdftotext": "26.10.0 (poppler)"}
json.dump(reg, open(os.path.join(S, "registry/source_registry.json"), "w"), indent=1)
print(all(f["sha256_matches_setup_inventory"] for f in files), len(reg["derived_products"]))
