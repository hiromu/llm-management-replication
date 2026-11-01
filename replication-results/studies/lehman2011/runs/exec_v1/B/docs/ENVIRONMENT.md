# Software environment (offline)

There is no network access, and you may not install packages. Use only what is listed here.

## R
- Command: `Rscript` (R 4.6.1).
- Installed packages you may use: survival 3.8.12, nanoparquet 0.5.2 (reads parquet), data.table 1.18.6.1, jsonlite 2.0.0, MASS, and the base and recommended packages (stats, Matrix and so on).
- Not installed: arrow, sandwich, lme4, fixest, numDeriv. Write any cluster-robust sandwich, delta-method gradient or random-effects quadrature yourself.
- Help pages are in this folder: R_survival_clogit.txt, R_survival_coxph.txt, R_stats_glm.txt and R_nanoparquet_read_parquet.txt. survival::clogit defaults to method = "exact"; check its documented behaviour for large strata in the help text.

## Python
- Command: `~/.venv/bin/python` (3.13.4). Run it with `-I`.
- Installed packages you may use: numpy 2.4.2, pandas 2.2.3, scipy 1.16.3, statsmodels 0.14.6 (including statsmodels.discrete.conditional_models.ConditionalLogit), pyarrow 26.0.0 and matplotlib 3.10.8.
- Docstrings are in this folder: Python_statsmodels_ConditionalLogit.txt, Python_statsmodels_Logit.txt and Python_pyarrow_read_table.txt.

## Data notes
- Each parquet file has 372 columns; data/dictionary/data_dictionary.md defines them. Character columns can hold an empty string as well as missing values; treat the empty string as missing for team columns.
- `goal_to_go` is stored as double in some seasons and as int32 in others. Cast types consistently when you stack seasons.
