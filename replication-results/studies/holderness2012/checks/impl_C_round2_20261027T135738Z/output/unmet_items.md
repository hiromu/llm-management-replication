# Unmet items

1. Manifest line 12 (String handling): cleaning must remove NUL characters and leading/trailing spaces. `clean()` at code/run.py:47 uses `str.strip()` with no argument, which also removes tabs, newlines and other whitespace characters, so fields differing only by such characters are not compared as written.

2. Manifest line 20 (camp_valid "defined"): the code list is specified as an input under data/ (code_lists/pow_CAMP_cl1277.csv). code/run.py:153 reads it from `ROOT / "code_lists"`, i.e. the directory of run.py, not from the `--data` directory. Spec S004 therefore cannot read the list from the specified location.

3. Manifest line 57 (coords "crosswalk", "first crosswalk row for the code (lowest entry_id)"): code/run.py:126-128 orders candidate rows by the entry_id string lexicographically. For entry_ids of different digit lengths (e.g. "99" vs "100") this does not select the lowest entry_id.

4. Manifest line 71 (report "convergence status" for every model) and line 100: a fit whose optimizer did not converge is turned into an exception at code/run.py:573-574 and recorded as status "failed" with no coefficients, standard errors or marginal effects. Non-converged fits are never reported with their estimates and converged = False.

5. grid.json "influence_scope" (only 'all' or 'first20') and "compute_order" (S000 first, then S001 onward): code/run.py:982 defines a default `--influence none` that skips the INFLUENCE family entirely (code/run.py:642-644), a scope not in the grid, and code/run.py:981 defaults `--specs` to "S000" so S001-S020 are not run unless the default is overridden.
