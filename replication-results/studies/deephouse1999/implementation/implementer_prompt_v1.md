# Implementation task

Implement the analysis specified in `manifest.md` and `grid.json` in this directory, in LANGUAGE_LINE.

Work only in this directory. Do not use the internet or any file outside this directory except the language runtime and installed packages. You are one of several independent implementers; you will not see the others' work. There are no expected results: do not try to identify where this design comes from.

Software: SOFTWARE_LINE

Deliverables in this phase:
1. `analysis.EXT`: one parameterised script that, when run from this directory as `RUN_LINE`, executes every specification, check and influence diagnostic in the grid and writes every output listed in manifest section 6 under `out/`.
2. `tests/`: synthetic-data tests that check (a) WLS estimates, SEs, SSE and F tests against a direct matrix computation, (b) the strategic-deviation construction on a small hand-made market, (c) lag construction across gaps and entries, (d) the sample hash format, (e) that weight rescaling leaves coefficients and SEs unchanged. Run them and save the output to `tests/test_output.txt`.
3. `README.md` describing the script structure, every manifest item you implemented, and any you could not implement (with reason).

Rules for this phase: you may load the real data and run the sample-construction steps to debug them, but do not run the model-fitting stage on the real data; the full run happens later in a frozen, network-isolated execution. Do not create files outside this directory. When finished, reply with a short list of the files written and any unimplemented items.
