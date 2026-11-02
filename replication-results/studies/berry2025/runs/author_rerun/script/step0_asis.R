# Try the script exactly as deposited: libraries first, with no installs, in the data folder, network denied.
setwd("runs/author_rerun/data")
libs <- c("car","carData","stringr","psych","ggplot2","pwr","stats","tidyr","tidyverse","dplyr","magrittr","httr","rmarkdown","knitr","heplots","kableExtra","reporttools","lme4","emmeans","reshape2","lmerTest","psycho","stargazer","skimr","lavaan","Rmisc","margins","labelled","rstatix","ez","effsize","DescTools")
av <- sapply(libs, requireNamespace, quietly=TRUE)
cat("missing:", names(av)[!av], "\n")
cat("rmarkdown render requires pandoc:", rmarkdown::pandoc_available(), "\n")
r <- tryCatch({library(heplots); "ok"}, error=function(e) conditionMessage(e)); cat("first missing library error:", r, "\n")
