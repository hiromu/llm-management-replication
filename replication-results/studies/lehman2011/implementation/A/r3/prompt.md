# Implementation assignment

You are an independent statistical programmer. Implement the frozen analysis specification in `manifest.md` and `grid.json` in this directory, in R. Other programmers implement the same specification separately; you will not see their work.

Read `manifest.md`, `grid.json`, `docs/ENVIRONMENT.md` and the other files in `docs/`, and `data/dictionary/data_dictionary.md`.

Deliverable: one parameterised entry script, `code/run_all.R` (helper files in `code/` are allowed). Run from this directory, it reads only `data/` and writes every output in manifest section 8 to `results/`. It must take one optional argument, `--stage`, with values `synthetic`, `sample` or `full`:
- `synthetic`: generate synthetic data with known parameters; check that each estimator (U7 = 0, 1, 2; N1) recovers them; check the exact conditional likelihood on a small case against a direct enumeration; check the marginal-effect and sandwich code against numerical derivatives. Write `results/synthetic_checks.md`.
- `sample`: build the samples and variables for every grid cell and write `sample_flow.csv` and `samples/`, but fit no model on the real data.
- `full`: everything in manifest sections 1-9.

In this session run only the `synthetic` and `sample` stages. Do not fit any model to the real data. The full run is executed later, in a frozen environment, after an independent check of your code against the manifest. Make sure `full` would run end to end without intervention. Keep run time reasonable; the full grid has about 600 fits plus influence refits.

Influence deletions (manifest section 9): your full run will include the `game` unit. Run `team` and `season` in all cases.

Work only inside this directory. There is no network access, and you must not install packages. There are no published results here to match; do not look for any. Record anything you could not implement in `results/implementation_notes.md`.

When finished, reply with a short summary: files written, synthetic-check results, sample-stage row counts for the origin, and any manifest items not implemented.


# Repair round

Your code from the previous round is in code/. An independent checker compared it with the manifest and reported the unmet items below (verbatim). Fix them without changing anything else. Then rerun only the synthetic and sample stages, and append a note of the changes to results/implementation_notes.md. Do not fit models to the real data.

- `grid.json` → `compute_order[0]` and `benchmark_inference`; manifest §7: Step 1 does not compute the required benchmark inference. Its auxiliary U7=1 M2/M3 fits are cached with `bench = NULL`, and no U7=1 M1 counterpart is fitted there; game-clustered benchmark inference first occurs in step 2. Code: `code/lib_grid.R:125`, `code/lib_grid.R:150-166`.
- Manifest §§7 and 9 (record failed fits with status and error): An influence deletion whose U7=1 fit fails or does not converge retains the U7=0 fit's status, potentially reporting `status = ok`; only the error text reflects the U7=1 failure. Code: `code/lib_grid.R:380-387`, `code/lib_grid.R:396`.
- Manifest §3 (fit N) and §8 (`influence.csv.n_obs`): Influence rows report the number of rows before fitting, even when the conditional fit drops groups with invariant outcomes, so `n_obs` can exceed the number of observations used for the reported estimate. Code: `code/lib_grid.R:396`; group removal and fitted N: `code/lib_clogit.R:31-34`, `code/lib_clogit.R:214`.
- Manifest §10 (record why an operation cannot be done and continue with the rest): An exception during the synthetic checks aborts the full run before empirical work and before implementation notes are written. Only checks that return a failure flag are handled; exceptions from the check routine are not caught. Code: `code/run_all.R:100-107`, `code/run_all.R:119`, `code/run_all.R:132`; uncaught check calls: `code/lib_synthetic.R:67-69`, `code/lib_synthetic.R:115`, `code/lib_synthetic.R:219`.
