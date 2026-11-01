# Source validation report: twenge2010

Prepared by the source/data role on 2026-10-28 (validation time recorded in registry/registry.json). Scope: identify the article's data sources, validate the user-supplied ICPSR bundles, produce raw-code extracts with a two-loader equivalence check, and build summary-free dictionaries and a neutral source description. No sample, item set, index, weight or exclusion was chosen. No provider was contacted or accessed over the network.

## Source requirements

The article (sha256 verified against STUDY.json) uses Monitoring the Future 12th-grade surveys for 1976, 1991 and 2006, restricted to questionnaire Forms 3 and 4 (pdf pages 9-10, journal pages 1125-1126; item wordings in Table 1, pdf pages 11-13). No other empirical source (census, population or school-level data) is named. Details and locators: registry/source_requirements.json. No printed numbers were transcribed.

## Supplied bundles

| Source | Year | Release | Files on disk vs setup inventory | Data-file MD5 vs ICPSR manifest | Codebook MD5 |
|---|---|---|---|---|---|
| icpsr07927 | 1976 | ICPSR 7927 V4, 2007-05-25, doi 10.3886/ICPSR07927.v4 | 11 of 11, sha256 and size match | 6 of 6 match | match |
| icpsr09871 | 1991 | ICPSR 9871 V1, 2006-03-30, doi 10.3886/ICPSR09871.v1 | 12 of 12, sha256 and size match | 7 of 7 match | match |
| icpsr20022 | 2006 | ICPSR 20022 V3, 2008-09-12, doi 10.3886/ICPSR20022.v3 | 19 of 19, sha256 and size match | 7 of 7 match | 8 of 8 match (user guide and 7 codebooks) |

Release identity (title, principal investigators, version, DOI, distributor date) agrees between each manifest header and description-citation file. No extra, hidden or missing files. Supplied files were re-hashed at the end of the work and are unchanged.

Provenance: downloaded by the user, a human, by hand; download time not recorded. Each TermsOfUse.html records that the user agreed to the ICPSR terms on 2026-10-27 for that study's download. Setup copy time 2026-10-28T01:48:50Z.

Terms (TermsOfUse.html, preserved): research or statistical use only; no re-identification; report any inadvertent identification; cite the recommended citation and send publication citations to ICPSR; no provider liability; sanctions for violations. The text uses SAMHSA/SAMHDA wording and does not address redistribution, so data and extracts stay inside this study folder and never go to readers.

Provider components not supplied: alternative formats (.dta, .txt, .xpt), setup and supplemental syntax files, and the description-citation PDF (supplied as HTML). None is needed: the SPSS files carry all variables, value labels and missing declarations.

## Dataset labels and forms

| Year | Form 3 | Form 4 | Core |
|---|---|---|---|
| 1976 | DS0003 | DS0004 | DS0006 |
| 1991 | DS0004 | DS0005 | DS0001 |
| 2006 | DS0004 | DS0005 | DS0001 |

Confirmed by the manifest labels, description files, the form ID V3 (constant and equal to the form number in every form file), the ICPSR part-number variable (1976 V9002; 1991 labels "Part 4: Form 3 Questionnaire" and "Part 5: Form 4 Questionnaire") and the 2006 per-dataset codebook titles. Row and column counts of every file match the manifest.

## Variables needed by the source requirements

Present in every year with identical variable names, question numbers, MTF item reference numbers, wording and response categories:

- Form 3: V3222-V3226 (A05a-e, leisure and work statements, five categories Disagree to Agree) and V3227 (A06, would want to work given enough money, two categories).
- Form 4: V4225-V4247 (A08a-w, importance of 23 job characteristics, four categories Not important to Very important). The A06 money item also appears in Form 4 as V4263 (A14).

The 2006 cross-time question index flags no wording, category or numbering change for these items over 1976-2006. All non-missing codes of these items lie within the labelled categories in every year. Version-history changes (1976 Form 3 V3319-V3332 removed; 2006 text edits to Form 3 V3342, V3359, V3376 and Form 4 V4223; 2006 Western-region suppression) do not touch these items.

Comparability notes for the coordinator: the source scales are five categories labelled Disagree ... Agree for A05 and four categories labelled Not important ... Very important for A08 in all three years. Missing codes differ by release (1976/1991: 0 and 9-or-higher declared missing, blanks system-missing; 2006: -9).

## Weights, identifiers, design variables

- Weight: V5 SAMPLING WEIGHT in every file, a public-use version modified (1976: bracketed into grouped values) from the original school-varying weight. The provider recommends using it. In 1976 form files and 1991 files the SPSS metadata declare 0 and 9 (1976: 9 or higher) as missing for V5; no weight value falls in those sets, and all weights are positive.
- IDs: V4 serial unique within each file; form-file serials are disjoint and together equal the core-file serials in each year. 2006 adds CASEID. V1 year (76, 91, 2006), V3 form.
- Design: no school, PSU, stratum or geographic identifier below Census region exists in the public files. Available: V13 region, V16 self-representing PSU flag, V17 SMSA/MSA flag. School-clustered variance estimation therefore cannot use school identifiers from these files.

## Loader equivalence

All 20 files pass (registry/loader_check.json). pyreadstat 1.3.3 and R haven 2.5.5 agree on dimensions, variable names and order, variable labels, value labels and every numeric cell (exact double comparison). Handling of declared user-missing values:

- haven read_por/read_sav with user_na = FALSE, and pyreadstat read_sav default: declared codes become missing.
- haven with user_na = TRUE and pyreadstat read_sav(user_missing = True): codes kept, declarations exposed.
- pyreadstat read_por has no user-missing option: it always converts declared codes to missing and does not report the declarations. For the .por files, raw codes are therefore taken from haven (user_na = TRUE); every cell where haven's raw and default reads differ holds a declared missing code, and pyreadstat equals haven's default read on every cell.

## Extracts and dictionaries

- data/derived/extracts/<year>_<DS>.csv.gz: every row and variable of all 20 files, raw numeric codes, declared missing codes retained, system-missing as empty. A JSON sidecar records source and output sha256 (deterministic gzip).
- data/derived/dictionaries/: 20 summary-free dictionaries (JSON and Markdown), README.md and source_description.md. The summary-free scan (registry/summary_free_check.json) finds no unreviewed frequency, percent or N strings. Remaining pattern matches are response-category or label wording.
- Coordinator-only: registry/coverage_internal.json (row and non-missing counts). Not for readers or implementers.

## Newly acquired sources

None. No other public source is required by the article's stated data.

## Blocking issues

None found for the data scope. Open points for the coordinator, not blockers: the public weights are modified versions of the originals; no clustering identifiers are released; the 1976 codebook lacks question wording for some variables outside the needed items. Supplement search and the focal-author package check were outside this role's assignment and were not performed.

## Scripts and runtime

sources/scripts/01_validate_files.py, 02_haven_dump.R, 03_extract_and_check.py, 04_build_dictionaries.py, 05_check_summary_free.py, 06_structure_and_coverage.py, 07_build_registry.py. Python 3.13.4 (~/.venv/bin/python, run with -I), pyreadstat 1.3.3, pandas 2.2.3, numpy 2.4.2; R 4.6.1 with haven 2.5.5; pdftotext 26.10.0 (codebook text, scratch only). Intermediate files (haven dumps from 02_haven_dump.R, and codebook text from `pdftotext -layout` on each codebook PDF and the 2006 user guide) were kept in a session scratch directory and can be regenerated; scripts 03 and 04 take those directories as arguments.
