# Loader check

Generated 2026-10-27T12:26:17Z by data/scripts/loader_compare.py from registry/loader_check_python.json and registry/loader_check_r.json (produced by data/scripts/loader_check.py and data/scripts/loader_check.R).

Method. Every derived file exists as a CSV (human-readable) and a Parquet twin (binary IEEE doubles). Each was loaded with data/scripts/load_derived.py (pandas; Parquet via pyarrow) and data/scripts/load_derived.R (readr for CSV; nanoparquet for Parquet) using the explicit column types in registry/derived_schema.json. For every column a canonical text rendering was hashed with SHA-256: doubles formatted with C "%.17g" (strict; enough digits to identify every double exactly) or "%.15g", strings verbatim, missing as \N, values joined by newline in file row order. A file hash is the SHA-256 of the ordered column:type:column-hash lines; equal file hashes therefore mean equal shape, column order, column types and values.

Runtimes: Python {'python': '3.13.4', 'pandas': '2.2.3'}; R {'R': 'R version 4.6.1 (2026-06-24)', 'readr': '2.2.0', 'nanoparquet': '0.5.2', 'digest': '0.6.39'}.

## A. Parquet twins: Python vs R (strict, bit-exact)

| file | rows Py/R | cols Py/R | names, order, types equal | columns with equal hash | file hash equal | file SHA-256 |
|---|---|---|---|---|---|---|
| call_mnwi_allitems_1983q4_1993q4.parquet | 49046/49046 | 3279/3279 | yes | 3279 of 3279 | yes | b48a2a35cc55525025308a1808e8f60fa095080abd67380cc4268180fe93f171 |
| call_mnwi_core_1983q4_1993q4.parquet | 49046/49046 | 362/362 | yes | 362 of 362 | yes | 65d9457bfc810f90c05ad6e8a053342422058b8c31f1e2d2bfd734e6e43df2ae |
| call_item_presence_by_quarter.parquet | 134357/134357 | 5/5 | yes | 5 of 5 | yes | 00c3e8c28d9802d008df3282f0285a19e9cc3c9a7c87aa0d393a2b4c9dd0b20f |
| call_source_files.parquet | 41/41 | 6/6 | yes | 6 of 6 | yes | 2cb0387a2fdef4fd76749d7895d52fcd108ec03746b501f8d4cefdb37db3c1de |
| call_items_mdrm_dictionary.parquet | 3279/3279 | 10/10 | yes | 10 of 10 | yes | 0e0d6e81325d8c5c29d336737afc8026ef1876db12c43638e6c534a2e4958ecd |
| fdic_institutions_mnwi_and_linked.parquet | 1802/1802 | 140/140 | yes | 140 of 140 | yes | 597b48b3f35600de8b19fff5ce8cd14b171557338e5be4ed6b3c37419aa25925 |
| fdic_structure_events_mnwi_1983_1994.parquet | 5466/5466 | 174/174 | yes | 174 of 174 | yes | 381deb1d586dd462961fd4531460f80819a91f38c792e452abb857bcd2f38ce6 |
| fdic_financials_core_mnwi_1984q1_1994q4.parquet | 55899/55899 | 102/102 | yes | 102 of 102 | yes | 4b7bddaa7e84973227ba674824ec7fbb97af891e25964ecba1b76089222caa04 |
| deflators_long.parquet | 5109/5109 | 9/9 | yes | 9 of 9 | yes | 0633fa70ddb684263b933e71a6c59d434ee7241ec2f8f2598d44acecab6bad9c |
| msa_minneapolis_stpaul_counties_by_vintage.parquet | 58/58 | 10/10 | yes | 10 of 10 | yes | a4f205925237c13ae1f7585ea783f4eb4cfbf3b530ffaded07bf847af5fb492f |
| county_fips_mn_wi.parquet | 159/159 | 6/6 | yes | 6 of 6 | yes | 4ae601710970279f7857cee766edc9391e1dcfc2ff00a90576fd24d38335816e |

## B. CSV files: Python vs R

| file | rows Py/R | cols Py/R | names, order, types equal | strict: columns equal | strict file hash equal | 15-digit file hash equal | max ULP distance in strictly differing columns |
|---|---|---|---|---|---|---|---|
| call_mnwi_allitems_1983q4_1993q4.csv.gz | 49046/49046 | 3279/3279 | yes | 3156 of 3279 | no | no | 379 |
| call_mnwi_core_1983q4_1993q4.csv | 49046/49046 | 362/362 | yes | 362 of 362 | yes | yes | - |
| call_item_presence_by_quarter.csv | 134357/134357 | 5/5 | yes | 5 of 5 | yes | yes | - |
| call_source_files.csv | 41/41 | 6/6 | yes | 6 of 6 | yes | yes | - |
| call_items_mdrm_dictionary.csv | 3279/3279 | 10/10 | yes | 10 of 10 | yes | yes | - |
| fdic_institutions_mnwi_and_linked.csv | 1802/1802 | 140/140 | yes | 132 of 140 | no | no | 9 |
| fdic_structure_events_mnwi_1983_1994.csv | 5466/5466 | 174/174 | yes | 165 of 174 | no | no | 1 |
| fdic_financials_core_mnwi_1984q1_1994q4.csv | 55899/55899 | 102/102 | yes | 99 of 102 | no | no | 26 |
| deflators_long.csv | 5109/5109 | 9/9 | yes | 9 of 9 | yes | yes | - |
| msa_minneapolis_stpaul_counties_by_vintage.csv | 58/58 | 10/10 | yes | 10 of 10 | yes | yes | - |
| county_fips_mn_wi.csv | 159/159 | 6/6 | yes | 6 of 6 | yes | yes | - |

## C. Python: CSV vs Parquet twin (strict)

| file | names, order, types equal | columns with equal hash | file hash equal |
|---|---|---|---|
| call_mnwi_allitems_1983q4_1993q4.csv.gz | yes | 3279 of 3279 | yes |
| call_mnwi_core_1983q4_1993q4.csv | yes | 362 of 362 | yes |
| call_item_presence_by_quarter.csv | yes | 5 of 5 | yes |
| call_source_files.csv | yes | 6 of 6 | yes |
| call_items_mdrm_dictionary.csv | yes | 10 of 10 | yes |
| fdic_institutions_mnwi_and_linked.csv | yes | 140 of 140 | yes |
| fdic_structure_events_mnwi_1983_1994.csv | yes | 174 of 174 | yes |
| fdic_financials_core_mnwi_1984q1_1994q4.csv | yes | 102 of 102 | yes |
| deflators_long.csv | yes | 9 of 9 | yes |
| msa_minneapolis_stpaul_counties_by_vintage.csv | yes | 10 of 10 | yes |
| county_fips_mn_wi.csv | yes | 6 of 6 | yes |

## Columns whose CSV values differ between pandas and readr

- call_mnwi_allitems_1983q4_1993q4.csv.gz (123 columns): RCFD7701, RCFD7702, RCFD7713, RCFD7714, RCFD7715, RCFD7716, RCFD7717, RCFD7720, RCFD7721, RCFD7722, RCFD7723, RCFD7724, RCFD7727, RCFD7728, RCFD7729, RCFD7730, RCFD7731, RCFD7734, RCFD7735, RCFD7736, RCFD7737, RCFD7738, RCFD7741, RCFD7742, RCFD7743, RCFD7744, RCFD7745, RCFD7748, RCFD7749, RCFD7750, RCFD7751, RCFD7752, RCFD7755, RCFD7756, RCFD7757, RCFD7758, RCFD7759, RCFD7762, RCFD7763, RCFD7764, RCFD7765, RCFD7783, RCFD7784, RCFD7785, RCFD7786, RCFD7787, RCFD7796, RCFD7797, RCFD7798, RCFD7799, RCFD7875, RCFD7876, RCFD7877, RCFD7878, RCFD7887, RCON7700, RCON7701, RCON7702, RCON7710, RCON7713, RCON7714, RCON7715, RCON7716, RCON7717, RCON7720, RCON7721, RCON7722, RCON7723, RCON7724, RCON7727, RCON7728, RCON7729, RCON7730, RCON7731, RCON7734, RCON7735, RCON7736, RCON7737, RCON7738, RCON7741, RCON7742, RCON7743, RCON7744, RCON7745, RCON7748, RCON7749, RCON7750, RCON7751, RCON7752, RCON7755, RCON7756, RCON7757, RCON7758, RCON7759, RCON7762, RCON7763, RCON7764, RCON7765, RCON7769, RCON7770, RCON7771, RCON7772, RCON7776, RCON7777, RCON7778, RCON7779, RCON7780, RCON7783, RCON7784, RCON7785, RCON7786, RCON7787, RCON7796, RCON7797, RCON7798, RCON7799, RCON7875, RCON7876, RCON7877, RCON7878, RCON7879, RCON7886, RCON7887
- fdic_institutions_mnwi_and_linked.csv (8 columns): LATITUDE, LONGITUDE, ROA, ROAPTX, ROAPTXQ, ROAQ, ROE, ROEQ
- fdic_structure_events_mnwi_1983_1994.csv (9 columns): ACQ_LONGITUDE, FRM_OFF_LATITUDE, FRM_OFF_LONGITUDE, LATITUDE, LONGITUDE, OFF_LATITUDE, OFF_LONGITUDE, OUT_LONGITUDE, SUR_LONGITUDE
- fdic_financials_core_mnwi_1984q1_1994q4.csv (3 columns): ASSET5, ROA, ROAPTX

## Result

- Parquet twins: Python and R return identical shapes, column names, order, types and bit-identical values for every file: yes.
- CSV files: identical shapes, column names, order and types in Python and R: yes; bit-identical values: no.
- Python reads the CSV and its Parquet twin identically: yes.

Interpretation. All string columns and all integer-valued numeric columns (which include every dollar-amount Call Report item) are bit-identical when the CSVs are read by pandas and readr. The listed columns hold non-integer values stored with 17 significant digits (provider ratio or rate items, ROA-type ratios, coordinates); readr's decimal-to-double conversion on this machine is not correctly rounded for some such strings, so its values differ from the correctly rounded pandas values by the ULP distances shown. The Parquet twins carry the binary doubles and are read bit-identically by both languages; load_derived.R and load_derived.py therefore read the Parquet twins by default.
