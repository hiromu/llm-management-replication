# Source descriptions

Neutral descriptions of the public sources acquired for this study folder. File-level provenance (URLs, acquisition times, sizes, SHA-256 hashes, access terms, failed attempts) is in registry/source_registry.json; column definitions of the derived extracts are in registry/data_dictionary.md and registry/data_dictionary.json.

## 1. Federal Reserve Bank of Chicago, Commercial Bank Data (Reports of Condition and Income), 1976-2000 complete files

What it is. Quarterly cross-sections of the Reports of Condition and Income ("Call Reports") filed by every insured commercial bank and some other depository institutions supervised by the Federal Reserve, FDIC or OCC, as archived by the Federal Reserve System and distributed by the Chicago Fed as zipped SAS XPORT files, one file per quarter. Each record is one reporting entity at one report date. The files combine the financial items with selected structure items from the Federal Reserve's RSSD (NIC) database.

Coverage obtained. All 41 quarterly files from 1983Q4 (December 1983) to 1993Q4 (December 1993), national coverage (all states). The provider states that this archive is no longer updated (no further as-of dates after the 2021Q2 dataset).

Identifiers. RSSD9001 (Federal Reserve RSSD ID), RSSD9050 (FDIC certificate), RSSD9055 (OCC charter number), RSSD9348/RSSD9364/RSSD9379 (holding-company and direct-holder RSSD IDs). Location: RSSD9210 (state FIPS), RSSD9200 (state abbreviation), RSSD9150 (county FIPS within state), RSSD9130 (city), RSSD9220 (ZIP), RSSD9180 (MSA/PMSA code). Type: RSSD9048 (charter type), RSSD9331 (entity type), RSSD9047 (organization type), RSSD9421 (chartering authority), CALL8786 (reporting level: consolidated, domestic, head office, branch).

Variables. Item identifiers follow the Federal Reserve MDRM convention: a 4-letter mnemonic plus a 4-digit item code. RCFD = consolidated domestic and foreign offices; RCON = domestic offices; RCFN = foreign offices; RIAD = income statement. On these files RCFD items are populated for all filers and equal the RCON items for banks without foreign offices.

Units and timing. Dollar items are in thousands of U.S. dollars. Balance-sheet items are as of the report date (end of quarter). Schedule RC-K items are quarterly averages (for example item 3368, quarterly average of total assets); the form instructions allow daily or weekly averaging. Income-statement (RIAD) items are cumulative calendar year-to-date, so the fourth-quarter report gives the full calendar year.

Reporting-form changes relevant to 1983-1993. Four report forms were in use from March 1984: FFIEC 031 (banks with foreign offices) and FFIEC 032, 033 and 034 (domestic-office banks of decreasing size). Smaller-bank forms collect fewer detail items, so component items can be missing for some banks while totals are present. The March 1984 revision changed the balance sheet: total investment securities (0390) excludes trading accounts, which are reported separately as assets held in trading accounts (2146); commercial and industrial loans excluding acceptances (1766, the sum of 1763 and 1764) were introduced alongside the older total including acceptances (1600); lease financing receivables are included in total loans (1400). The 1983Q4 file follows the earlier layout (for example 0380 all other securities and 1000 trading account securities). Federal funds sold (0276) and securities purchased under agreements to resell (0277) are populated separately only from 1988; before that only their sum (1350) is available. Held-to-maturity and available-for-sale securities (1754, 1773) begin in 1994 and are empty in this period. The Chicago Fed note "Notes on forming consistent time series" (saved in data/raw/chicagofed_documentation/) documents these and other definitional breaks.

Known limitations. Structure fields are those carried on each quarterly archival file; the metropolitan code (RSSD9180) does not state which OMB definition vintage it reflects. Non-bank and office-level records (Edge corporations, branches of foreign banks, head-office-only records) are present and must be identified with the type and reporting-level codes. Savings and loan associations that filed thrift reports are not in these files; some state savings banks that filed Call Reports are. Provider missing values are kept as missing. A few provider ratio items (item codes 77xx) carry long decimal values.

## 2. Federal Reserve Board, Micro Data Reference Manual (MDRM)

What it is. The Federal Reserve's data dictionary for regulatory reports: one entry per mnemonic plus item code, with item name, item type, reporting forms, validity dates, confidentiality flag and description (instructions text). The bulk CSV was downloaded as of the acquisition date, together with the RSSD structure-item PDF.

Limitations. Validity dates in the dictionary refer to dictionary entries and do not always match actual presence on the archived files; actual presence by quarter is recorded in data/derived/call_item_presence_by_quarter.csv. Some archived columns have no MDRM entry.

## 3. FDIC BankFind Suite API

What it is. The FDIC's public API for institution, structure-history and financial data on FDIC-insured institutions. Three endpoints were used, all filtered to Minnesota and Wisconsin, plus the documentation files that define every field.

- Institutions (/banks/institutions): one record per institution (active or inactive), with FDIC certificate (CERT), Federal Reserve RSSD ID (FED_RSSD), name, location (including 5-digit state-county code STCNTY), charter class (BKCLASS), regulator, holding company, establishment and inactive dates. Attribute values describe the institution as of the latest FDIC update (or the date it became inactive), not as of earlier years.
- History (/banks/history): structure-change events with effective dates, including mergers, absorptions, consolidations, failures, new institutions, branch acquisitions and sales, and changes of name, location, charter, insurance or regulator. Each event carries acquirer (ACQ_), outgoing (OUT_), survivor (SUR_) and former-value (FRM_) fields where relevant, plus an event code and description. Effective dates 1980-1996 were downloaded.
- Financials (/banks/financials): quarterly financial data from 1984Q1 onward (nothing earlier is returned) for FDIC-insured commercial banks and savings institutions, as processed by the FDIC. A curated set of 101 fields was downloaded for every quarter 1984Q1-1994Q4: identifiers and location, total assets and FDIC-computed average-asset fields, deposits (total, domestic, foreign), loan categories, securities, cash, fed funds and repos, trading accounts, premises, other assets, income and expense aggregates, and FDIC-computed ratios. Dollar amounts are in thousands of U.S. dollars.

Limitations. Field derivations are the FDIC's and can differ from Call Report item definitions; several fields have no description in the FDIC documentation. Savings institutions that filed thrift reports are included in the financials (see BKCLASS and CALLFORM), which the Call Report archive does not cover. The all-field financial download was not possible because the API caps the page size when many fields are requested.

## 4. Price indexes (FRED/ALFRED and the BLS Public Data API)

What they are.
- CPI for All Urban Consumers (CPI-U), all items, U.S. city average, index 1982-84 = 100: monthly seasonally adjusted (FRED CPIAUCSL; BLS CUSR0000SA0) and not seasonally adjusted (FRED CPIAUCNS; BLS CUUR0000SA0). FRED-computed annual averages were also downloaded for several series.
- CPI-U all items for the Minneapolis-St. Paul area, not seasonally adjusted, index 1982-84 = 100: FRED CUURA211SA0 (a discontinued series, observations through December 1986 at the frequency BLS then used for this area), FRED CUUSA211SA0 (annual Minneapolis-St. Paul-Bloomington series from 1984), and BLS API series CUURS24ASA0 (monthly or bimonthly values as published, through December 1986) and CUUSS24ASA0 (semiannual, from 1984). For 1987 onward the area index is therefore available only at semiannual and annual frequency in the files obtained.
- GDP implicit price deflator: quarterly seasonally adjusted (FRED GDPDEF) and annual (FRED A191RD3A086NBEA), current vintage with base year 2017 = 100, plus three real-time vintages of GDPDEF from ALFRED (1996-01-01, 1997-06-30, 1999-01-01), whose base years and values differ from the current vintage.

Limitations. Current-vintage national accounts deflators are revised over time; CPI-U not-seasonally-adjusted values are not revised. Area CPIs are published less often than monthly and the area definitions changed over time. No annual averages were computed during acquisition; only provider-computed averages are included.

## 5. OMB metropolitan area definitions (U.S. Census Bureau historical delineation files)

What they are. National files listing every metropolitan area and its component counties (with FIPS codes) under each OMB definition set: SMSA definitions of June 30, 1981 (file 80mfips.txt), MSA definitions of June 27, 1983, June 30, 1990, June 30, 1993 and June 30, 1999, plus text notes of changes from 1984 to 1990 and the 1993 update, and the Census metropolitan-area history workbook (1950-2020). A convenience table extracts the counties of area code 5120 (Minneapolis-St. Paul, MN-WI) from each vintage; the national files are kept in full. A 2010 county FIPS code list supplies county names for Minnesota and Wisconsin.

Limitations. The files list definitions as of their dates; definitions in force between dates must be inferred from the change notes. City and town components are not listed for every area.

## 6. Sources attempted but not obtained

- FFIEC National Information Center bulk data (attributes, relationships, transformations): the download page is protected by a CAPTCHA and refused automated requests (HTTP 403). It was not bypassed. FDIC BankFind history and institution records are the available public substitute for merger and structure information.
- BLS LABSTAT CPI flat files (download.bls.gov): the server refused automated requests (HTTP 403). The same series were obtained through the BLS Public Data API and FRED.
