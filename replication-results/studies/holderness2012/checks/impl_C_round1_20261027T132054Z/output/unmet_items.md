# Unmet items

1. Manifest line 12 (string handling: remove NUL characters and leading/trailing spaces). `code/run.py:46` uses `.str.strip()` with no argument, which removes all leading/trailing whitespace characters (tabs, newlines, carriage returns, form feeds, Unicode whitespace), not only spaces.

2. Manifest lines 5–10 and 20 (all inputs are in data/; "defined" camp validity uses code_lists/pow_CAMP_cl1277.csv). `code/run.py:152` reads the code list from `ROOT / "code_lists"` (the script's own directory) instead of the `data` directory passed to `construct_records`; the rank tables and crosswalk are read from `data`, so the code list is the only input not taken from data/.

3. Manifest line 37 (GRADE_ALPHA compared "after removing spaces from both sides") and line 40 (first row used when a label appears more than once). `code/run.py:101` and `code/run.py:106` delete every space character, including interior spaces, from both the table label and the POW field, so labels that differ only by interior spaces are merged; `code/run.py:102` then drops duplicates on the space-stripped label, so a table row with a distinct original label can be discarded in favour of an earlier row with a different label.

4. Manifest line 57 ("the first crosswalk row for the code (lowest entry_id)"). `code/run.py:125–127` orders eligible rows by `entry_id` as a string (lexicographic), not by numeric value; for identifiers with differing digit counts (for example "99" vs "100", or "1000" vs "359a") the lexicographically first row is not the lowest entry_id.

5. Manifest line 71 (binary regressors for discrete-change marginal effects are "japan, dependents, officer, missing indicators"; all other regressors get the derivative phi(xbar'b) * b_k). `code/run.py:486–488` adds every camp fixed-effect dummy to the binary set, so camp dummies are reported with the discrete change Phi(x_k = 1) − Phi(x_k = 0) (and the corresponding delta-method Jacobian at `code/run.py:334–339`) rather than the derivative.
