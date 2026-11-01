# Implementation assignment

You are implementing a fully specified statistical analysis. Everything you need is in this folder:
- manifest.md: the analysis specification (follow it exactly; do not add, drop or change analyses).
- grid.json: the specification grid (parameter settings per spec and which model families each spec runs).
- data/: pow.parquet, enl.parquet (large; read only needed columns), camp_location_crosswalk.csv, rank_map_grade_alpha.csv, rank_map_grade_code.csv.
- dictionaries/ and code_lists/: field definitions and code meanings.
- SOFTWARE.md: the language, the available packages and how your script will be run.

Rules:
- Work only in this folder. Do not use the internet. Do not install packages.
- Write ONE parameterized script (named in SOFTWARE.md) that runs any subset of specs from grid.json and writes the outputs listed in the manifest under the --out folder.
- Before any empirical fitting, validate the estimation machinery on synthetic data you generate: (1) a probit with known coefficients recovers them; (2) your marginal effects at means and delta-method standard errors match a numerical finite-difference check; (3) your cluster-robust covariance matches a direct sandwich computation on a tiny example; (4) Steepness and Sameness formulas give expected values on hand-made groups (one rank only gives Steepness 0; a group whose rank shares equal the reference shares gives Sameness 1); (5) your DeLong test gives z = 0 for identical predictors. Save these checks as tests/ with a log of results.
- On the real data you may run sample construction and variable construction and print row counts and missingness to check your code, and you may fit at most the spec S000 T4 family to confirm the script runs end to end. Do not run the full grid; it will be run later by others in a controlled environment.
- If something in the manifest is impossible or ambiguous, do not guess silently: implement the closest literal reading, and list the issue in NOTES.md with the line of the manifest it concerns. You may abort with a written reason if the task cannot be done.
- Finish with NOTES.md describing your implementation choices, the synthetic test results, runtime estimates per fit, and any manifest items not implemented.
