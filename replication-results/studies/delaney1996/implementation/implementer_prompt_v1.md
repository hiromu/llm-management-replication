# Implementation task

Working directory contents:
- `implementation_spec.md` (the specification; follow it exactly)
- `grid_v1.json` (specifications to run)
- `software_notes.md`
- `data/` (synthetic development data with the real file's columns and codes, metadata, industry crosswalk)

Write your code in `code/`. Deliver:
1. One main script, `code/run_grid.<ext>`, invoked as `<interpreter> code/run_grid.<ext> --data <survey.csv> --metadata <survey_metadata.json> --crosswalk <industry_crosswalk.csv> --grid <grid_v1.json> --out <output_dir>`. It must run every spec in the grid in `compute_order` and write all outputs of section 8. Specs or models that fail are recorded, not skipped silently.
2. `code/tests/`: meaningful synthetic tests, run by you, covering at least:
   - OLS, conventional SE, HC3, the one-tailed p values and nested F, against a small simulated dataset with known structure (and against base routines);
   - hand-built rows for each coding rule and axis level (missing codes, reversals, logs, top codes, routing and copy rule, decision maps, industry mapping and UNCL, neither, no-training levels);
   - leave-one-out refits on a small case.
3. Run the full grid once on the synthetic `data/survey.csv` to confirm that every spec and output file is produced. Results on synthetic data are meaningless; do not interpret them.
4. `code/README.md`: how to run, every interpretation you had to make where the spec was not explicit (list them all), and test results.

Rules: Use only the files in this directory. No network access. Do not install packages. You will never receive the real data in this task. Do not add specifications, change the grid, or tune anything. If something in the specification cannot be implemented, implement what you can and record the reason in README and run_info.json. When finished, write `code/DONE.txt`.
