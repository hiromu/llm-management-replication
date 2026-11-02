# Adversarial review: descriptive comparison of origin-constructed variables with Table 2 (publication diagnostic only).
suppressPackageStartupMessages(library(jsonlite))
source("../../../runs/run_20261028_v1_1/code_A/k7_lib.R")
f <- readRDS("frame_origin_A.rds")
smp <- read.csv("../../../runs/run_20261028_v1_1/out_A/samples.csv")
so <- smp[smp$spec_id == "O" & smp$family == "org", "V1"]
sm <- smp[smp$spec_id == "O" & smp$family == "mkt", "V1"]
vars <- c("POP","PMP","STAFF","TRAIN","INCENT","GRIEV","DECENT","ILM","VHIER","NONPROF","SUBSID","LOGEMP","LOGAGE","PCTMGR","UNION","PRODUCT","SERVICE","COMPET")
t2 <- c(POP=3.05,PMP=2.85,STAFF=0.09,TRAIN=0.05,INCENT=2.62,GRIEV=0.70,DECENT=3.49,ILM=1.67,VHIER=1.85,NONPROF=1.35,SUBSID=1.44,LOGEMP=4.15,LOGAGE=3.16,PCTMGR=0.24,UNION=1.40,PRODUCT=0.15,SERVICE=0.74,COMPET=0.44)
t2sd <- c(POP=.65,PMP=.76,STAFF=.79,TRAIN=.88,INCENT=.59,GRIEV=.46,DECENT=.97,ILM=.35,VHIER=.66,NONPROF=.48,SUBSID=.50,LOGEMP=2.36,LOGAGE=1.18,PCTMGR=.28,UNION=.59,PRODUCT=.36,SERVICE=.44,COMPET=.50)
o <- f[f$V1 %in% so, ]; all <- f
out <- data.frame(variable = vars, table2_mean = t2[vars], table2_sd = t2sd[vars],
  origin_org_mean = sapply(vars, function(v) mean(o[[v]], na.rm = TRUE)),
  origin_org_sd = sapply(vars, function(v) sd(o[[v]], na.rm = TRUE)),
  frame_mean = sapply(vars, function(v) mean(all[[v]], na.rm = TRUE)),
  frame_sd = sapply(vars, function(v) sd(all[[v]], na.rm = TRUE)),
  frame_n_valid = sapply(vars, function(v) sum(!is.na(all[[v]]))))
out[,-1] <- round(out[,-1], 3)
print(out, row.names = FALSE)
write.csv(out, "descriptives_vs_table2.csv", row.names = FALSE)
cat("raw V17 mean (all rows):", mean(as.numeric(read.csv('../../../runs/run_20261028_v1_1/inputs/survey.csv')$V17)), "\n")
# correlations within the origin org sample, of POP/PMP with selected regressors (diagnostic)
cr <- sapply(c("STAFF","TRAIN","INCENT","GRIEV","DECENT","ILM","VHIER","SUBSID","UNION","COMPET"), function(v) c(POP_org = cor(o$POP, o[[v]]), PMP_mkt = { m <- f[f$V1 %in% sm, ]; cor(m$PMP, m[[v]]) }))
print(round(cr, 3))
write.csv(round(t(cr),3), "origin_correlations.csv")
