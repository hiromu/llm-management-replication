#!/usr/bin/env Rscript
# run.R -- entry point for MANIFEST PAPER_X v1
#
#   Rscript code/run.R spec S00 [S01 ...]          run named specifications -> results/<spec>.json
#   Rscript code/run.R all                         run every specification in the grid
#   Rscript code/run.R influence <start> <limit>   leave-one-out refits of S00 M4 -> results/influence_<start>_<end>.csv
#   Rscript code/run.R test                        synthetic-data tests -> code/TESTS.md
#
# Run from the project root (the directory containing code/, data/, results/), or pass --root=<dir>.

args <- commandArgs(trailingOnly = TRUE)
root <- getwd()
ri <- grep("^--root=", args)
if (length(ri)) { root <- sub("^--root=", "", args[ri[1]]); args <- args[-ri] }
code_dir <- file.path(root, "code")
for (f in c("lib_data.R", "lib_models.R", "lib_stats.R", "lib_specs.R", "lib_influence.R")) source(file.path(code_dir, f))

usage <- function() {
  cat("usage:\n  run.R spec <ID> [<ID> ...]\n  run.R all\n  run.R influence <start> <limit>\n  run.R test\n")
  quit(status = 1)
}
if (length(args) == 0) usage()
mode <- args[1]

if (mode == "test") {
  source(file.path(code_dir, "test_synthetic.R"))
  run_synthetic_tests(root)
} else if (mode %in% c("spec", "all")) {
  ids <- if (mode == "all") names(SPEC_DEFS) else args[-1]
  if (!length(ids)) usage()
  bad <- setdiff(ids, names(SPEC_DEFS))
  if (length(bad)) stop("unknown specification(s): ", paste(bad, collapse = ", "))
  message("loading data ...")
  D <- load_all_data(root)
  for (id in ids) run_spec(id, D, root)
} else if (mode == "influence") {
  if (length(args) < 3) usage()
  start <- as.integer(args[2]); limit <- as.integer(args[3])
  message("loading data ...")
  D <- load_all_data(root)
  run_influence(D, root, start = start, limit = limit)
} else usage()
