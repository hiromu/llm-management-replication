# Code check assignment

This folder holds an analysis specification (manifest.md, grid.json) and code that is meant to implement it exactly (code/). You do not have the data and must not run the code.

Read the manifest and grid in full, then read all of the code. Check, item by item, whether every requirement of the manifest and grid is implemented as written: sample steps, parameter handling for every grid parameter and value, string cleaning, rank lookup and fallback, group definitions and group-member options, hierarchy formulas and constants, regressor construction and scaling, missing-value replacement and indicators, linkage and duplicate handling, model families and their regressor lists, fixed effects and dropping of camps without outcome variation, clustering and the G/(G-1) factor, marginal effects at means with discrete changes for binary regressors, delta-method standard errors, ROC test, robustness families, influence runs, and every required output file and column.

Write output/unmet_items.md containing only a numbered list of unmet or incorrectly implemented manifest items. For each give the manifest line or section and the code file and line. Do not suggest fixes, do not comment on style, and do not list items that are met. If everything is met, write "No unmet items."
