# Pre-execution check

You check a program against its specification before it is run on real data. In ./input are the specification (`implementation_manifest_v1.md`, `grid_v1.csv`, `data_registry_impl_v1.json`) and the program (`code/`). You have no data and no results. Do not run anything that needs data.

Read the specification and the code. List every specification item the code does not implement, implements differently, or implements only partly. Include data-preparation steps, outcome and variable definitions, grid parameters that are ignored or misread, fixed effects, the two standard-error formulas and their degrees of freedom, p-values and intervals, influence mode and output files and columns.

Write `output/unmet_items.md` as a bare numbered list. Each item names the manifest section (for example P6 or AN07) and states in one or two sentences what the code does instead, with the file and line. Do not suggest fixes, praise or summarize. If nothing is unmet, write "No unmet items." When finished, print only the word DONE.
