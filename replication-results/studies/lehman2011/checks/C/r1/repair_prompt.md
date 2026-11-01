# Repair round

Your code from the previous round is in code/. An independent checker compared it with the manifest and reported the unmet items below (verbatim). Fix them without changing anything else. Then rerun only the synthetic and sample stages, and append a note of the changes to results/implementation_notes.md. Do not fit models to the real data.

- manifest §7 / grid.json `compute_order` step 3: `duplicate_of` is specified only for step-3 combinations that equal an earlier cell. The code flags any later execution with the same spec_id (`code/run_all.py:203-207`), and the step-1 auxiliary U7=1 fits (`code/run_all.py:271-272`) register those spec_ids first. So the step-2 individual-deviation cell U7=1 (M1, M2, M3) is written to `specs.csv` with `duplicate_of` set to its own spec_id, and the step-2 auxiliary fits add rows for two-axis cells (e.g. U1=1,U7=1) labelled `step=2`, which `compute_order` step 2 defines as single-axis deviations only.
