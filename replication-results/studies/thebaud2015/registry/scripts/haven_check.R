# Read ICPSR 20320 .sav with R haven; write shape and a fingerprint of selected variables (internal check only)
args <- commandArgs(trailingOnly = TRUE)
suppressPackageStartupMessages(library(haven))
cols <- c("GEM_YR","COUNTRY","CTRYALP","GEMSEX","GEMAGE","GEMEDUC","GEMWORK","OWNMGE","WEIGHT","OMNOWJOB")
d <- read_sav(args[1], col_select = all_of(cols))
full_n <- nrow(d)
hdr <- read_sav(args[1], n_max = 1)
fp <- data.frame(var = cols,
  n_nonmiss = sapply(cols, function(v) sum(!is.na(d[[v]]))),
  sum_or_hash = sapply(cols, function(v) { x <- d[[v]]; if (is.character(x)) sum(utf8ToInt(paste(x[seq(1, length(x), by = 9973)], collapse=""))) else sprintf("%.6f", sum(as.numeric(x), na.rm = TRUE)) }))
cat(sprintf("haven_version=%s R=%s rows=%d cols_total=%d\n", as.character(packageVersion("haven")), R.version.string, full_n, ncol(hdr)))
write.csv(fp, args[2], row.names = FALSE)
