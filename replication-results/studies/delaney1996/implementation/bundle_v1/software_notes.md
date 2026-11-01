# Software available (no network access; do not install packages)

R 4.6.1 at /opt/homebrew/bin/Rscript. Installed and permitted: base and stats (lm, lm.wfit, model.matrix, pf, pt, qr), sandwich (vcovHC type "HC3"), lmtest, jsonlite, haven. Not installed: psych, data.table, tidyverse (do not assume).

Python 3.13.4 at ~/.venv/bin/python. Installed: numpy 2.4.2, pandas 2.2.3, scipy 1.16.3, statsmodels 0.14.6 (OLS/WLS, get_robustcov_results or cov_type="HC3").

Notes: HC3 = (X'X)^-1 X' diag(e_i^2/(1-h_ii)^2) X (X'X)^-1; with weights use the weighted design. For WLS, R2 is the weighted R2 from the weighted regression with intercept. Leave-one-out refits may be computed by explicit refitting; closed-form updates are allowed only if they reproduce explicit refits exactly on your synthetic tests.
