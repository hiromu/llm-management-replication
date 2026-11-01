# Implementation assignment

You are an independent statistical programmer. Implement the frozen analysis specification in `manifest.md` and `grid.json` in this directory, in Python. Other programmers implement the same specification separately; you will not see their work.

Read `manifest.md`, `grid.json`, `docs/ENVIRONMENT.md` and the other files in `docs/`, and `data/dictionary/data_dictionary.md`.

Deliverable: one parameterised entry script, `code/run_all.py` (helper files in `code/` are allowed). Run from this directory, it reads only `data/` and writes every output in manifest section 8 to `results/`. It must take one optional argument, `--stage`, with values `synthetic`, `sample` or `full`:
- `synthetic`: generate synthetic data with known parameters; check that each estimator (U7 = 0, 1, 2; N1) recovers them; check the exact conditional likelihood on a small case against a direct enumeration; check the marginal-effect and sandwich code against numerical derivatives. Write `results/synthetic_checks.md`.
- `sample`: build the samples and variables for every grid cell and write `sample_flow.csv` and `samples/`, but fit no model on the real data.
- `full`: everything in manifest sections 1-9.

In this session run only the `synthetic` and `sample` stages. Do not fit any model to the real data. The full run is executed later, in a frozen environment, after an independent check of your code against the manifest. Make sure `full` would run end to end without intervention. Keep run time reasonable; the full grid has about 600 fits plus influence refits.

Influence deletions (manifest section 9): your full run will include the `game` unit. Run `team` and `season` in all cases.

Work only inside this directory. There is no network access, and you must not install packages. There are no published results here to match; do not look for any. Record anything you could not implement in `results/implementation_notes.md`.

When finished, reply with a short summary: files written, synthetic-check results, sample-stage row counts for the origin, and any manifest items not implemented.


# Repair round

Your code from the previous round is in code/. An independent checker compared it with the manifest and reported the unmet items below (verbatim). Fix them without changing anything else. Then rerun only the synthetic and sample stages, and append a note of the changes to results/implementation_notes.md. Do not fit models to the real data.

- manifest §7 / grid.json `compute_order` step 3: `duplicate_of` is specified only for step-3 combinations that equal an earlier cell. The code flags any later execution with the same spec_id (`code/run_all.py:203-207`), and the step-1 auxiliary U7=1 fits (`code/run_all.py:271-272`) register those spec_ids first. So the step-2 individual-deviation cell U7=1 (M1, M2, M3) is written to `specs.csv` with `duplicate_of` set to its own spec_id, and the step-2 auxiliary fits add rows for two-axis cells (e.g. U1=1,U7=1) labelled `step=2`, which `compute_order` step 2 defines as single-axis deviations only.
