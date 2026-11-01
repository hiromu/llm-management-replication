# Run the deposited analysis script on a copy of the data, evaluating each expression so one failure does not stop the rest.
# Run with network denied. Every text change to the script is listed in CHANGES and written to the log.
args <- commandArgs(TRUE); label <- args[1]; apply_changes <- args[2] == "changes"
root <- getwd(); rd <- file.path(root, "runs/author_rerun"); .libPaths(c(Sys.getenv("AUTHOR_RLIB"), .libPaths()))
src <- readLines(file.path(rd, "script/original.Rmd"))
CHANGES <- list(
  list(from = "PROLIFIC_PID", to = "part_uid", why = "column absent from deposited Study 1 file; part_uid is the anonymized person ID per dictionary"),
  list(from = "reputation_with_broker", to = "relconcerns_with_broker", why = "column absent from deposited Study 2 and 3 files; dictionary lists relconcerns_with_broker built from broker_rep items"),
  list(from = ": =", to = ":=", why = "current lavaan 0.6-21 rejects the space in the defined-parameter operator; same meaning"),
  list(from = "PseudoR2(", to = "DescTools::PseudoR2(", why = "function's package is never loaded by the script"),
  list(from = "library(psycho)", to = "# library(psycho)", why = "unavailable or unused; see install log", cond = !requireNamespace("psycho", quietly = TRUE)),
  list(from = "library(reporttools)", to = "# library(reporttools)", why = "unavailable or unused; see install log", cond = !requireNamespace("reporttools", quietly = TRUE)))
if (apply_changes) for (ch in CHANGES) if (is.null(ch$cond) || isTRUE(ch$cond)) src <- gsub(ch$from, ch$to, src, fixed = TRUE)
writeLines(src, file.path(rd, "script", paste0(label, ".Rmd")))
pur <- file.path(rd, "script", paste0(label, ".R")); knitr::purl(file.path(rd, "script", paste0(label, ".Rmd")), output = pur, quiet = TRUE, documentation = 0)
setwd(file.path(rd, "data"))
exprs <- parse(pur); log <- file(file.path(rd, paste0(label, "_output.txt")), "w"); sink(log); sink(log, type = "message")
env <- new.env(parent = globalenv()); rec <- list(); fails <- list(); set.seed(1)
for (i in seq_along(exprs)) {
  e <- exprs[[i]]; txt <- paste(deparse(e, width.cutoff = 200), collapse = " ")
  cat("\n>>> [", i, "] ", substr(txt, 1, 200), "\n", sep = "")
  res <- tryCatch(withCallingHandlers(withVisible(eval(e, env)), warning = function(w) invokeRestart("muffleWarning")), error = function(err) { fails[[length(fails) + 1]] <<- list(i = i, expr = substr(txt, 1, 160), error = conditionMessage(err)); cat("ERROR:", conditionMessage(err), "\n"); NULL })
  if (!is.null(res)) {
    if (res$visible) try(print(res$value))
    keep <- res$value
    if (inherits(keep, c("data.frame", "htest", "effsize", "emmGrid", "numeric")) || is.numeric(keep) || is.list(keep)) rec[[as.character(i)]] <- list(expr = txt, value = if (inherits(keep, "lavaan")) NULL else keep)
    if (grepl("^fit[0-9]* <- (sem|lavaan::sem)", txt) || grepl("<- sem\\(|lavaan::sem\\(", txt)) {
      n <- sub(" <-.*", "", txt); f <- get(n, env); rec[[paste0("pe_", i)]] <- list(expr = txt, value = lavaan::parameterEstimates(f, boot.ci.type = "bca.simple"), se_option = lavaan::lavInspect(f, "options")$se, boot_R = lavaan::lavInspect(f, "options")$bootstrap, nobs = lavaan::lavInspect(f, "nobs"))
    }
  }
}
sink(type = "message"); sink(); close(log)
saveRDS(rec, file.path(rd, paste0(label, "_records.rds")))
sum_ <- list(label = label, n_expressions = length(exprs), n_failed = length(fails), failures = fails, r = R.version.string, changes = if (apply_changes) CHANGES else list())
writeLines(jsonlite::toJSON(sum_, auto_unbox = TRUE, pretty = TRUE), file.path(rd, paste0(label, "_summary.json")))
ip <- as.data.frame(installed.packages()[, c("Package", "Version")]); write.csv(ip[ip$Package %in% c("lavaan", "emmeans", "effsize", "heplots", "rstatix", "DescTools", "car", "Rmisc", "pwr", "kableExtra", "reporttools", "psycho", "stargazer", "skimr", "margins", "labelled", "ez", "lmerTest", "lme4", "psych", "tidyverse"), ], file.path(rd, paste0(label, "_versions.csv")), row.names = FALSE)
