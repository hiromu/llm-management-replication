# Software

Language: Python 3.13 (~/.venv/bin/python). Available: numpy, scipy, pandas, pyarrow, statsmodels 0.14.6, scikit-learn 1.6.1. You may use statsmodels Probit, but you must compute marginal effects at means (with discrete changes for binary regressors and means of all regressors including dummies), the delta-method standard errors from the cluster-robust covariance with the G/(G-1) factor, and the DeLong test yourself and verify them as required.

Script: run.py. Invocation: ~/.venv/bin/python -I run.py --grid grid.json --data data --out results --specs S000[,S001,...|all] --influence all|first20|none
Memory: the enlistment file has about nine million rows; read only the needed columns and link on serial number early.
