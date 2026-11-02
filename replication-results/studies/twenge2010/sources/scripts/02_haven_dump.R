# Source role: read every supplied SPSS file with R haven, dump raw codes and metadata
# Usage: Rscript 02_haven_dump.R <study_dir> <out_dir>
suppressPackageStartupMessages({library(haven); library(jsonlite)})
args <- commandArgs(trailingOnly = TRUE)
study <- args[1]; out <- args[2]
dir.create(out, showWarnings = FALSE, recursive = TRUE)
files <- list.files(file.path(study, "data/supplied"), pattern = "-Data\\.(por|sav)$", recursive = TRUE, full.names = TRUE)
fmt <- function(x) {
  if (is.character(x)) return(ifelse(is.na(x), "", x))
  x <- as.double(x); r <- sprintf("%.17g", x); r[is.na(x)] <- ""; r
}
for (f in files) {
  yr <- c("07927"="1976","09871"="1991","20022"="2006")[substr(basename(f),1,5)]
  ds <- paste0("DS", substr(basename(f),7,10))
  key <- paste0(yr, "_", ds)
  rd <- if (grepl("por$", f)) read_por else read_sav
  d_raw <- rd(f, user_na = TRUE)
  d_def <- rd(f, user_na = FALSE)
  meta <- lapply(names(d_raw), function(n) {
    x <- d_raw[[n]]
    list(name = n, class = class(x), label = attr(x, "label", exact = TRUE),
         format_spss = attr(x, "format.spss", exact = TRUE),
         na_values = attr(x, "na_values", exact = TRUE), na_range = attr(x, "na_range", exact = TRUE),
         labels = { l <- attr(x, "labels", exact = TRUE); if (is.null(l)) NULL else as.list(setNames(as.numeric(l), names(l))) },
         n_na_user_na_true = sum(is.na(x)), n_na_user_na_false = sum(is.na(d_def[[n]])))
  })
  # raw codes: declared user-missing codes are retained as values (user_na = TRUE)
  raw <- as.data.frame(lapply(d_raw, function(x) { y <- x; attributes(y) <- NULL; if (inherits(x, "haven_labelled_spss") || inherits(x, "haven_labelled")) y <- vctrs::vec_data(x); fmt(y) }), stringsAsFactors = FALSE)
  def <- as.data.frame(lapply(d_def, function(x) { y <- if (inherits(x, "haven_labelled")) vctrs::vec_data(x) else x; attributes(y) <- NULL; fmt(y) }), stringsAsFactors = FALSE)
  names(raw) <- names(d_raw); names(def) <- names(d_def)
  con <- gzfile(file.path(out, paste0(key, "_raw.csv.gz")), "w"); write.csv(raw, con, row.names = FALSE, na = ""); close(con)
  con <- gzfile(file.path(out, paste0(key, "_default.csv.gz")), "w"); write.csv(def, con, row.names = FALSE, na = ""); close(con)
  write_json(list(file = f, key = key, nrow = nrow(d_raw), ncol = ncol(d_raw), vars = meta,
                  haven_version = as.character(packageVersion("haven")), R_version = R.version.string),
             file.path(out, paste0(key, "_meta.json")), auto_unbox = TRUE, null = "null", digits = NA, pretty = FALSE)
  cat(key, nrow(d_raw), ncol(d_raw), "\n")
}
