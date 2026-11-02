# Source descriptions

These descriptions are summary-free. They are drawn from provider documentation and contain no counts, frequencies, means or missingness rates computed from the data. Field-level definitions are in `data_dictionary_nara_pow_rg389.csv` and `data_dictionary_nara_asnf_rg64.csv`; code lists (code and meaning only) are in `code_lists/`.

## nara_pow_rg389: World War II Prisoners of War Data File

- Provider: U.S. National Archives and Records Administration (NARA), National Archives at College Park, Electronic Records.
- Catalog: file unit "World War II Prisoners of War Data File, 12/7/1941 - 11/19/1946", National Archives Identifier 1263907, in the series "Records of World War II Prisoners of War" (NAID 583428), Record Group 389, Records of the Office of the Provost Marshal General. Accession NN3-389-98-999. Access and use: unrestricted.
- Origin: IBM punch cards (W.D. A.G.O. Form No. 0326) produced during World War II by the Prisoner of War Information Bureau, Office of the Provost Marshal General, from International Committee of the Red Cross reports, cables and other records. The Veterans Administration converted two groups of cards in 1978; NARA converted the remainder in 1998 and merged the component files into one data file in 2002. The record does not contain a field identifying the component card group it came from.
- Unit of record: one punch-card record per individual prisoner or internee, as carded.
- Coverage (documented): U.S. military officers and enlisted personnel, U.S. civilians and some Allied civilians held as prisoners of war or internees by Germany, Japan and other powers (including internment in neutral countries). Report dates are documented as running from 7 December 1941 to 19 November 1946.
- Content: serial number, name, grade (alphabetic and coded), service, arm or service, date reported, racial group, state of residence, unit (type of organization, parent unit number and type), place of capture (theater and area), latest report date, source of report, status, detaining power, camp (place detained), and, for prisoners of the Japanese who died in 1944 ship sinkings, the ship.
- Documented limitations: NARA describes the carded information as far from consistent or complete. Latest report date and camp are often missing; the latest report date sometimes records file closure rather than release; the camp may be the first or the last camp of detention and does not list all camps; some prisoners were on mobile details. Some original cards carry handwritten notes that may contradict punched values. A small number of bent or damaged cards could not be converted and exist only as paper copies (images in 101.1MA.pdf). There are no records for some prisoners named in ICRC lists. Some code values in the file are undefined in the code lists. Camp codes 359 and 510 each have two meanings in the code list.
- Raw format: ASCII fixed-length records of 80 characters plus carriage return and line feed. Some raw values contain NUL (0x00) bytes, preserved exactly in the derived file.
- Documentation obtained: Technical Specifications Summary (WWIIPOW_TSS.pdf), Documentation Package (101.1DP.pdf: user notes, layout, code tables, processing materials), Unprocessed Punchcards (101.1MA.pdf), AAD field layout, field notes and code lists, AAD FAQ (rg389_wwii_pow_faq_revised.pdf).
- Camp locations: the camp code list gives camp name, place and a whole-degree latitude-longitude. A separate camp location crosswalk geocodes each code (registry/camp_location_crosswalk.csv).

## nara_asnf_rg64: Electronic Army Serial Number Merged File (World War II Army Enlistment Records)

- Provider: NARA, National Archives at College Park, Electronic Records.
- Catalog: file unit "Electronic Army Serial Number Merged File, ca. 1938 - 1946", National Archives Identifier 1263923, in the series "World War II Army Enlistment Records" (NAID 604357), Record Group 64, Records of the National Archives and Records Administration. Accession NN3-064-03-008. Access and use: unrestricted.
- Origin: War Department enlistment punch cards (WD AGO Forms 317 and 372) and Enlisted Reserve Corps statistical cards, microfilmed and later converted by the Bureau of the Census using optical reading (FOSDIC). NARA merged the converted files and collapsed repeated reads into a single best-guess record per card image (2002). Records stating that one or more cards were unreadable are retained at the position where they occurred.
- Unit of record: one enlistment card image per record. Two card layouts exist: the Enlistment card and the E.R.C. Statistical card, which differ from column 58 onward; NARA/NPRC documentation identifies E.R.C. cards by a '3' punched in column 80.
- Coverage (documented): men and women who enlisted in the U.S. Army, including the Women's Army Auxiliary Corps and Women's Army Corps, with enlistment dates ca. 1938-1946 (most 1939-1946). The file is not complete: NARA documents missing serial-number ranges and unreadable microfilm locations.
- Content: Army serial number, name, residence (state and county), place and date of enlistment, grade, arm or branch, term of enlistment, source of Army personnel, nativity, year of birth, race and citizenship, education, civilian occupation, marital and dependency status, component, card number, and microfilm box and reel. Columns 74-78 held height and weight on some card versions and other content on others; NARA could not date their use and excluded them from AAD, but they are present in the raw file.
- Documented limitations: optical conversion errors; characters outside the documented code sets occur in many fields; NARA represented blank characters with '#'; some coded values are not in the code lists; the county code list is available only as scanned code tables.
- Raw format: ASCII fixed-length records of 89 characters plus carriage return and line feed, distributed as a ZIP archive.
- Documentation obtained: Technical Specifications Summary (ASNF_TSS.pdf), Basic Documentation (100.1ND_NC.pdf: user notes, NPRC memo with card layouts, technical manual excerpts), NARA Compiled Code Lists (100.1CL_SD.pdf, scanned code tables including state and county codes and station codes), AAD field layouts, field notes and code lists for the enlistment and reserve-corps tables, AAD FAQ (rg64_army_serial_faq.pdf).

## Linkage

The two files share an Army serial-number field (POW SERIAL_NO, positions 1-8; enlistment SER_NUM, positions 1-8). No linkage, matching rule or sample restriction has been applied in the derived files.

## geonames_dump: GeoNames gazetteer

- Provider: GeoNames (geonames.org), daily export dump; licence Creative Commons Attribution 4.0.
- Use: geocoding camp place names for the camp location crosswalk only. Country dumps for the countries named in the camp code list, plus cities500, countryInfo and admin1 codes.

## Derived files

- `data/derived/pow_rg389_records.parquet` and `data/derived/asnf_rg64_records.parquet`: every raw record and every documented field, as exact fixed-width character slices (no trimming, recoding, type conversion, merging or sample selection), plus `record_seq` (physical record order). The enlistment file additionally carries the E.R.C.-layout slices of columns 58-80 (`ERC_*`) for every record; which layout applies to a record is left to the analysis manifest.
