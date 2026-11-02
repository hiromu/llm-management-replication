# Read variable names/labels of original GEM APS 2001/2002 .sav files with foreign (readstat fails on MR-set records)
args <- commandArgs(trailingOnly = TRUE)
suppressWarnings(suppressPackageStartupMessages(library(foreign)))
for (f in args) {
  d <- suppressWarnings(read.spss(f, to.data.frame = FALSE, use.value.labels = FALSE, max.value.labels = Inf))
  lab <- attr(d, "variable.labels"); vl <- attr(d, "label.table")
  cat("==", basename(f), " rows=", length(d[[1]]), " cols=", length(d), "\n")
  for (v in names(d)) {
    l <- if (!is.null(lab[[v]])) lab[[v]] else ""
    if (grepl("status|respect|setid|countr|ctry|weigh|wgt|year|sex|gender|^age|educ|work|own|start|skill|fear|know|reason|opport|better", paste(v, l), ignore.case = TRUE)) {
      vls <- vl[[v]]; vtxt <- if (!is.null(vls)) paste(paste(names(vls), vls, sep="="), collapse="; ") else ""
      cat("  ", v, "|", substr(l, 1, 110), "|", substr(vtxt, 1, 160), "\n")
    }
  }
}
