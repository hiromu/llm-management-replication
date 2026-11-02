# Internal check: in original GEM 2001/2002 APS files, for the paper's 24 countries, is NBSTATUS substantively answered
# (codes 0/1) in each country? Also row-count agreement with ICPSR harmonized file. Output to registry/validation.
args <- commandArgs(trailingOnly = TRUE)
suppressWarnings(suppressPackageStartupMessages(library(foreign)))
paper <- c(1,30,31,32,33,34,39,41,43,44,45,46,47,48,49,61,64,81,101,351,353,354,358,420)
out <- data.frame()
for (f in args[-1]) {
  d <- suppressWarnings(read.spss(f, to.data.frame = TRUE, use.value.labels = FALSE))
  d <- d[d$country %in% paper, ]
  for (c in sort(unique(d$country))) {
    s <- d[d$country == c, ]
    out <- rbind(out, data.frame(file = basename(f), country_code = c, records = nrow(s),
      nbstatus_valid_share = round(mean(s$nbstatus %in% c(0, 1)), 3)))
  }
}
write.csv(out, args[1], row.names = FALSE); print(out)
