# Summary-free dictionaries

One dictionary per supplied dataset (20 in total): `<year>_<DS>.dictionary.json` (machine-readable) and `<year>_<DS>.dictionary.md` (compact table). `source_description.md` describes the surveys, form design, sampling, weights, missingness and cross-year comparability.

## Contents of each dictionary

- Dataset header: survey year, provider dataset ID and label (for example 1991 DS0005 = Form 4 Data), ICPSR source and release, source data file, codebook used.
- For every variable, in file order: name; SPSS variable label; storage (SPSS format, width, decimals); value labels; declared SPSS missing values (`declared_missing_values`) and range (`declared_missing_range`, with HIGHEST for an open upper bound); and, where the codebook documents it, the question wording (`codebook.question_text`, and for 1976 the section stem in `codebook.question_stem`), the MTF item reference number (1991, 2006), the codebook's missing-data rule (1991, 2006) and the codebook's response-category text (2006). `codebook.matched_by` states how the entry was linked (by variable name, or for 1976 form-file copies of core items by core question number).
- Value labels and missing declarations come from the SPSS files (read with R haven, which exposes declared missing values for .por files). Question wording comes from the ICPSR codebook PDFs.

## Summary-free rule

The ICPSR codebooks print weighted frequency tables. Only question wording and category labels were taken from them. All percentages, frequencies, weighted Ns, case counts and ranges of valid codes were removed. A script scanned every file for such strings. Remaining pattern matches were reviewed and are wording (for example response categories such as "0% to 10%", population thresholds in city-size categories, the word "meaningful"), not data summaries.

## Coverage of question wording

Question wording was found for nearly all variables in 1991 and 2006. In 1976 the codebook is an edited frequency volume without entries for some variables; those entries have `codebook: null` or no `question_text`, and the SPSS label is the only description.

