# Software

Language: R 4.6.1 (Rscript at /opt/homebrew/bin/Rscript). Available packages: base R (stats including glm with binomial(link = "probit")), data.table, nanoparquet (read_parquet; use col_select to limit columns), jsonlite. Packages such as sandwich, fixest, pROC, margins are NOT available: implement cluster-robust covariance, marginal effects, the delta method and the DeLong test yourself.

Script: run.R. Invocation: Rscript run.R --grid grid.json --data data --out results --specs S000[,S001,...|all] --influence all|first20|none
Memory: the enlistment file has about nine million rows; read only the needed columns and link on serial number early.
