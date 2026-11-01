# R half of the loader-equivalence check on data/derived/bundle_v1; see code/loader_check.py.
# usage: Rscript loader_check.R <study_dir> <out.json>
suppressMessages({library(data.table); library(haven); library(readxl)})
args <- commandArgs(TRUE)
B <- file.path(args[1], "data/derived/bundle_v1")
TAB <- c("amenitycheck.csv", "distance.csv", "land_area.csv", "maptimes.csv", "osm-events.csv", "quarterly.csv", "h12.csv")
num <- function(x) ifelse(is.na(x), "NA", sprintf("%.10g", as.numeric(x)))
md5 <- function(v) { tf <- tempfile(); con <- file(tf, "wb"); writeBin(charToRaw(enc2utf8(paste0(paste(v, collapse = "\n"), "\n"))), con); close(con); unname(tools::md5sum(tf)) }
res <- list()
for (f in sort(list.files(B))) {
  p <- file.path(B, f)
  if (grepl("\\.csv$", f)) {
    df <- fread(p, sep = if (f %in% TAB) "\t" else ",", colClasses = "character", header = f != "h12.csv",
                na.strings = NULL, encoding = "UTF-8", showProgress = FALSE)
    if (f == "h12.csv") setnames(df, as.character(0:(ncol(df) - 1)))
    cols <- lapply(df, function(v) v)
  } else if (grepl("\\.dta$", f)) {
    df <- read_dta(p); cols <- lapply(df, function(v) num(zap_labels(v)))
  } else if (grepl("\\.xlsx$", f)) {
    df <- read_excel(p)
    cols <- lapply(df, function(v) {
      if (inherits(v, "POSIXct") || inherits(v, "Date")) ifelse(is.na(v), "NA", format(as.Date(v), "%Y-%m-%d"))
      else if (is.numeric(v)) num(v) else ifelse(is.na(v), "NA", as.character(v))
    })
  } else next
  res[[f]] <- list(nrow = nrow(df), ncol = ncol(df), columns = lapply(cols, md5))
}
writeLines(jsonlite::toJSON(res, auto_unbox = TRUE, pretty = TRUE), args[2])
