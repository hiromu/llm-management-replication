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

- Manifest §1, S8: Model-specific complete-case reporting does not account for U8=1 adding `below_indicator` to M1. `build_sample` accepts only U1–U6 and always computes M1 complete cases without `below_indicator`; the sample cache also ignores U8. Consequently, the reported M1 count and difference flag can be wrong for that cell (`code/lib_data.R:25`, `code/lib_data.R:108–121`; `code/lib_grid.R:22–24`).
- Manifest §4, ME0: The required marginal-effect z statistic is calculated but never reported. Marginal-effect rows and the output column selection omit it (`code/lib_fit.R:192–198`; `code/lib_grid.R:86`).
- Grid key `benchmark_inference`: Benchmark columns must be empty for U7=0 and U7=2 specifications, but their U9a rows receive the U7=1 counterpart's benchmark SE and p-value (`code/lib_grid.R:128–139`; `code/lib_fit.R:245–248`).
- Manifest §3, fit statistics: N1 reports objective-function evaluation counts as iterations. `re_fit` initializes `iters` from `opt$counts[1]`, adds Newton steps, and exports that total as `iterations` (`code/lib_relogit.R:81–82`, `code/lib_relogit.R:93`, `code/lib_relogit.R:108`; `code/lib_grid.R:172`).
- Manifest §7 and §9: Failure handling does not consistently record the actual error and continue with every remaining fit. Cell-level exceptions only log a message and abandon the remaining models; an N1 null-fit exception skips all N1 models; an exception in K1 can skip K2. N1 model errors are replaced with the generic message `re_fit error`, and influence benchmark-covariance errors are silently replaced with NULL (`code/lib_grid.R:338–339`, `code/lib_grid.R:160`, `code/lib_grid.R:165–166`, `code/lib_grid.R:269`, `code/lib_grid.R:350`, `code/lib_grid.R:357`).
- Manifest §8: `nonequiv.csv` and `algebraic_checks.csv` do not retain the specified column formats with an added `run_id`: their fixed output column list omits `step`, U1–U8, `me_variant_set`, and `duplicate_of` (`code/lib_grid.R:80`, `code/lib_grid.R:88–92`).
- Manifest §10: The empirical execution path does not perform the required synthetic checks beforehand or ensure that they have been performed. Checks and `synthetic_checks.md` are produced only by the separate `--stage synthetic` branch; the default `full` branch proceeds directly to loading data and empirical fitting (`code/run_all.R:14`, `code/run_all.R:88–101`).
