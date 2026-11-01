# Source acquisition log

Role: source acquisition (coordinator subagent allowed to know the paper). Session date 2026-10-27 (UTC timestamps per file are in registry/source_registry.json). Work was confined to studies/deephouse1999. No accounts were created, nothing was purchased, no CAPTCHA or access control was attempted or bypassed, nobody was contacted, and no prior replication materials were opened. No numbers printed in the article were used as data or to make any acquisition decision.

## Runtime

- Downloads: /usr/bin/curl 8.7.1 through data/scripts/fetch.py (and data/scripts/fetch_fdic_api.py for the FDIC API).
- Python: ~/.venv/bin/python 3.13.4 run with -I; pandas 2.2.3, numpy 2.4.2, pyreadstat 1.3.3, pyarrow 26.0.0, PyYAML 6.0.3.
- R: /opt/homebrew/bin/Rscript, R 4.6.1, readr 2.2.0, nanoparquet 0.5.2, jsonlite, digest 0.6.39.
- The project Python cannot load its OpenSSL library (`_ssl` import fails: libssl.3.dylib missing under /opt/homebrew/opt/openssl@3), so Python's urllib cannot make HTTPS requests. The first download attempt failed locally for that reason (48 attempts, logged in registry/download_log_attempt1_python_ssl_failure.jsonl; no request left the machine). All downloads were then made with curl.

## Obtained

| source | raw folder | content |
|---|---|---|
| Federal Reserve Bank of Chicago, Commercial Bank Data, complete files 1976-2000 | data/raw/chicagofed_call_reports | 41 quarterly zipped SAS XPORT files, 1983Q4-1993Q4, national |
| Chicago Fed documentation | data/raw/chicagofed_documentation | data pages, "Notes on forming consistent time series", regulatory capital notes, legal notices |
| Federal Reserve MDRM data dictionary | data/raw/frb_mdrm | MDRM.zip (full CSV dictionary), RSSD.PDF |
| FDIC BankFind API documentation | data/raw/fdic_bankfind_docs | field definition YAML for financials, institutions, history; swagger; FDIC website policies |
| FDIC BankFind institutions | data/raw/fdic_bankfind_institutions | all MN/WI institutions (active and inactive), plus records for linked certificates found in the Call Report extract or history events |
| FDIC BankFind history | data/raw/fdic_bankfind_history | structure-change events 1980-1996 involving MN/WI institutions, offices or former locations |
| FDIC BankFind financials | data/raw/fdic_bankfind_financials | MN/WI institutions, 1984Q1-1994Q4, 101 curated fields per quarter (plus 5 retained partial files from an abandoned all-fields attempt) |
| FRED / ALFRED price indexes | data/raw/fred_deflators | CPIAUCSL, CPIAUCNS, GDPDEF, A191RD3A086NBEA, CUURA211SA0, CUUSA211SA0 (native frequency), FRED annual averages for four series, ALFRED GDPDEF vintages 1996-01-01, 1997-06-30, 1999-01-01, series pages and FRED terms |
| BLS Public Data API v2 | data/raw/bls_cpi_api | CUUR0000SA0, CUSR0000SA0, CUURS24ASA0, CUUSS24ASA0, 1980-1999 |
| Census historical metropolitan delineations | data/raw/census_msa_definitions | 1981 SMSA file, 1983, 1990, 1993, 1999 MSA files, change notes 1984-1990 and 1993, metro history workbook 1950-2020, landing page |
| Census county FIPS codes | data/raw/census_county_fips | national_county.txt (2010) |

Every raw file is read-only (0444), hashed (SHA-256) at download, and re-verified on disk by data/scripts/build_registry.py (all 154 files verified; no unlogged raw files).

## Failed or blocked

| source | what happened | consequence |
|---|---|---|
| FFIEC NIC bulk data download (attributes, relationships, transformations) | HTTP 403; the page is CAPTCHA-protected ("CAPTCHA Error" page). Not bypassed. Empty folder data/raw/ffiec_nic_bulk kept as a record. | No NIC transformation (merger) table. FDIC BankFind history events and institution records are the public substitute; RSSD holder IDs and entry/exit of RSSD IDs in the Call Report files are additional evidence. |
| BLS LABSTAT flat files (download.bls.gov/pub/time.series/cu/) | HTTP 403 for automated requests. Not circumvented. Empty folder data/raw/bls_cpi kept. | Same CPI series obtained from the BLS API and FRED. |
| FDIC financials, all 2,378 fields in chunks of 250 | HTTP 400 (API caps page size at 500 when many fields are requested). Run stopped after 1984Q1-1985Q1; 5 successful partial files retained unused. | Replaced by one curated 101-field request per quarter. |
| FRED/ALFRED with the default User-Agent | HTTP/2 stream reset (curl error 92). | Re-run successfully with User-Agent "curl/8.7.1". |
| BLS API first try | malformed URL from a shell quoting error in this session. | Corrected and re-run successfully. |

All failed attempts are listed with their errors and classifications in registry/source_registry.json (failed_attempts).

## Derived extracts (data/derived; scripts in data/scripts)

- extract_call_mnwi.py: every Call Report record with physical state FIPS 27 or 55, all columns, all quarters (call_mnwi_allitems_1983q4_1993q4, CSV.gz + Parquet), item-by-quarter presence grid, per-zip source file table.
- derive_extracts.py (with call_item_candidates.py): core Call Report file with structure columns and every candidate item for each concept in all mnemonics present; MDRM per-column dictionary; FDIC institutions, structure events (effective 1983-1994) and financials; deflators in long format; county lists of metropolitan area 5120 for each OMB vintage; MN/WI county names.
- build_schema.py, write_parquet_twins.py: explicit column types and Parquet twins for every CSV.
- load_derived.py / load_derived.R: loaders; loader_check.py / loader_check.R / loader_compare.py: equivalence check (registry/loader_check.md).
- build_registry.py, build_data_dictionary.py: registry/source_registry.json, registry/data_dictionary.md and .json.

No sample was chosen: no restriction by charter type, metropolitan area, size, years within the downloaded range, or entity status; no deflator, average-asset formula, or item mapping was selected. Candidate mappings are listed in registry/call_item_candidates.json as alternatives.

## Loader check

Python and R return identical shapes, column names, order and types for every derived file. Reading the Parquet twins, values are bit-identical in both languages for every file. Reading the CSVs, all text and all integer-valued columns (including every dollar-amount Call Report item and the whole core Call Report file) are bit-identical; 123 provider ratio columns (item codes 77xx) in the all-items file and a few FDIC ratio and coordinate columns differ in the last binary digits because readr's decimal conversion on this machine is not correctly rounded for some 17-digit decimals. Details: registry/loader_check.md. Both loaders read the Parquet twins by default.

## Gaps that could affect core variables

- Return on average assets: constructible. Net income (RIAD4340, year-to-date) is present in every quarter. Average assets can be formed from Schedule RC-K quarterly averages of total assets (3368, every quarter) or from end-of-period total assets (2170, every quarter including 1983Q4); the formula is a later decision.
- Asset-allocation shares: constructible for 1984Q1-1993Q4 from total assets (2170) and the category items listed in registry/call_item_candidates.json. Trading account assets (2146) exist from 1984Q1 (1983Q4 uses the older 1000 item). Separate fed funds sold and reverse repos exist only from 1988 (the combined item 1350 covers all quarters). Several categories have more than one defensible mapping (for example C&I with or without acceptances, agricultural loans with or without farmland real estate loans, treatment of unearned income, the allowance for loan losses, lease receivables, and the composition of "other assets"); these are left open.
- Total expense ratio: total interest expense (RIAD4073) and total noninterest expense (RIAD4093) are present from 1984Q1; they are absent (all missing) in the 1983Q4 file, so a 1983 value of this ratio cannot be built from the Call Report archive.
- Market share of deposits and market deposit totals: bank-level total deposits (2200) are available every quarter. Deposits are reported for the whole bank and assigned to the head-office location; branch-level deposit geography (FDIC Summary of Deposits) begins only in 1994 and was not acquired, so a market total for any area is a sum over banks headquartered there. Savings-institution deposits are not in the Call Report archive; the FDIC financials include FDIC-insured savings institutions from 1984Q1 (none earlier). Which institutions and which county definition make up "the market" is a later decision; county lists for every OMB vintage in force are provided.
- Real market deposit growth: deflators obtained (U.S. CPI-U SA and NSA, Minneapolis-St. Paul CPI-U NSA, GDP implicit price deflator current and real-time vintages). The Minneapolis-St. Paul index is monthly/bimonthly only through 1986 and semiannual/annual thereafter.
- Mergers and acquisitions: the NIC transformations table could not be obtained (CAPTCHA). FDIC BankFind history events (mergers, absorptions, consolidations, failures, new charters) are available for 1980-1996 and link to Call Report records through FDIC certificate (RSSD9050) and FED_RSSD.
- Metropolitan location: RSSD9180 on the Call Report files does not state its definition vintage; county FIPS (RSSD9210 + RSSD9150) can be matched to the OMB county lists instead.

None of these gaps makes a core variable impossible to construct from public data; the open items are definitional choices.

## Disclosures

- An initial availability probe (HTTP status checks to eight URLs: Chicago Fed, MDRM, FFIEC NIC, FDIC API, FRED, BLS, Census) sent a User-Agent string containing the user's account handle (not the full e-mail address). All later requests used a generic User-Agent ("... academic-replication-research") or "curl/8.7.1" for FRED.
- Exploratory probes and small test queries (API field tests, file listings) were written to a scratch directory outside the study and not retained. During these tests a few national CPI annual values were displayed on screen; they are deflator values, not study data.
- To identify sources, the methods section of the article text (sources/text/main_article_layout.txt, approximately lines 470-630) was read; it contains sample-description counts and an outlier statement. These were not used for any acquisition or extraction decision. Results sections and tables were not read.
- Internal integrity checks (for example whether consolidated and domestic total-assets items agree, whether keys are unique, which entity types occur) were run on the extracts and viewed on screen; their outputs are not recorded in any deliverable, and no descriptive statistics of variables are reported anywhere.
