# run_tests.R -- runs every test file and writes a summary to code/dev_out/test_results.txt
# Usage: Rscript code/tests/run_tests.R
tests_dir <- local({
  a <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", a, value = TRUE)
  if (length(fa)) dirname(normalizePath(sub("^--file=", "", fa[1]))) else getwd()
})
rscript <- file.path(R.home("bin"), "Rscript")
files <- c("test_ols.R", "test_coding.R", "test_loo.R", "test_spec_invariances.R")
out_dir <- file.path(tests_dir, "..", "dev_out")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
all_lines <- character(0); total_pass <- 0; total_fail <- 0; any_error <- FALSE
for (f in files) {
  cat("\n#### ", f, "\n")
  res <- system2(rscript, shQuote(file.path(tests_dir, f)), stdout = TRUE, stderr = TRUE)
  status <- attr(res, "status")
  cat(res, sep = "\n")
  all_lines <- c(all_lines, paste0("#### ", f), res, "")
  summ <- grep("^== .*: [0-9]+ passed, [0-9]+ failed ==$", res, value = TRUE)
  if (!is.null(status) && status != 0 || !length(summ)) { any_error <- TRUE; all_lines <- c(all_lines, paste("ERROR: test file did not complete:", f)) }
  else {
    total_pass <- total_pass + as.integer(sub(".*: ([0-9]+) passed.*", "\\1", summ))
    total_fail <- total_fail + as.integer(sub(".*, ([0-9]+) failed.*", "\\1", summ))
  }
}
final <- sprintf("TOTAL: %d passed, %d failed%s (R %s, %s)", total_pass, total_fail,
                 if (any_error) ", with test-file errors" else "", getRversion(), format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
cat("\n", final, "\n")
writeLines(c(all_lines, final), file.path(out_dir, "test_results.txt"))
if (total_fail > 0 || any_error) quit(status = 1)
