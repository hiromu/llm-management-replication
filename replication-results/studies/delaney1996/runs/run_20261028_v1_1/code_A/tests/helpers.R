# helpers.R -- minimal assertion helpers for the tests (base R only).
K7_NO_MAIN <- TRUE
tests_dir <- local({
  a <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", a, value = TRUE)
  if (length(fa)) dirname(normalizePath(sub("^--file=", "", fa[1]))) else getwd()
})
source(file.path(tests_dir, "..", "k7_lib.R"))

.k7_results <- new.env()
.k7_results$pass <- 0L; .k7_results$fail <- 0L; .k7_results$log <- character(0)

check <- function(cond, label) {
  ok <- isTRUE(all(cond))
  if (ok) .k7_results$pass <- .k7_results$pass + 1L else .k7_results$fail <- .k7_results$fail + 1L
  line <- sprintf("[%s] %s", if (ok) "PASS" else "FAIL", label)
  .k7_results$log <- c(.k7_results$log, line)
  cat(line, "\n")
  invisible(ok)
}
check_equal <- function(a, b, label, tol = 1e-8) {
  a <- as.numeric(a); b <- as.numeric(b)
  same <- length(a) == length(b) && all((is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & abs(a - b) <= tol * pmax(1, abs(b))))
  if (!same) cat("   expected:", format(b, digits = 10), "\n   got:     ", format(a, digits = 10), "\n")
  check(same, label)
}
test_summary <- function(name) {
  cat(sprintf("== %s: %d passed, %d failed ==\n", name, .k7_results$pass, .k7_results$fail))
  invisible(list(pass = .k7_results$pass, fail = .k7_results$fail, log = .k7_results$log))
}
