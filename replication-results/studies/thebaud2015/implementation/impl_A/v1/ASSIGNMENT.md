# Implementation assignment

You are an independent statistical programmer. Write the analysis script specified in MANIFEST.md, in the language named in LANGUAGE.txt, using only the software listed there. Work only inside this directory. Do not use the internet.

Inputs in this directory:

- MANIFEST.md: the full specification. Follow it exactly. Where it is silent, choose the software default and record your choice in IMPLEMENTATION_NOTES.md.
- LANGUAGE.txt: language, interpreter path and permitted packages.
- synthetic/: synthetic test files with the same columns and codes as the real inputs (gem_extract.csv, country_year_inputs.csv) and synthetic_truth.json, the parameters that generated them. The real data will be different. The synthetic roster coverage is incomplete by design.

Deliverables (write them in this directory):

1. The script (run.R or run.jl). Command line: `<interpreter> <script> <data_dir> <out_dir> <run_ids>`, where run_ids is a comma-separated list, "ORIGIN", "all" (every run in manifest section 8 except influence), or "influence". It must read the two CSV files from data_dir and write results.csv, constants.json and session_info.txt to out_dir as specified. It must continue after a failed fit and record the error.
2. IMPLEMENTATION_NOTES.md: how each manifest item is implemented (with the function calls used), every default you relied on, and anything you could not implement.
3. test_report.md: what you ran on the synthetic files and what you checked. At minimum run ORIGIN, three deviation runs of your choice, and influence for one model, on the synthetic files. Check that the synthetic M3 female:childcare estimate is near its generating value and that sample counts follow the manifest rules. Keep total test run time under 25 minutes.

Do not print raw data rows in your outputs. Do not ask for the real data. If a manifest item is impossible with the permitted software, implement everything else, mark that item as not implemented in results (status not_estimable with a reason) and explain it in IMPLEMENTATION_NOTES.md. End with a short summary of what you delivered.
