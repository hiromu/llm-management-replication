#!/usr/bin/env Rscript
# run_grid.R -- run every specification of grid_v1.json (PAPER_K7 v1) and write outputs.
#
# Usage:
#   Rscript code/run_grid.R --data <survey.csv> --metadata <survey_metadata.json> \
#       --crosswalk <industry_crosswalk.csv> --grid <grid_v1.json> --out <output_dir>

suppressPackageStartupMessages(library(jsonlite))

script_dir <- local({
  a <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", a, value = TRUE)
  if (length(fa)) dirname(normalizePath(sub("^--file=", "", fa[1]))) else getwd()
})
source(file.path(script_dir, "k7_lib.R"))

parse_args <- function(args) {
  opts <- list()
  i <- 1
  while (i <= length(args)) {
    key <- args[i]
    if (!grepl("^--", key)) stop("unexpected argument: ", key)
    if (i == length(args)) stop("missing value for ", key)
    opts[[sub("^--", "", key)]] <- args[i + 1]
    i <- i + 2
  }
  need <- c("data", "metadata", "crosswalk", "grid", "out")
  miss <- setdiff(need, names(opts))
  if (length(miss)) stop("missing required arguments: ", paste(paste0("--", miss), collapse = ", "))
  opts
}

main <- function() {
  opts <- parse_args(commandArgs(trailingOnly = TRUE))
  start_time <- Sys.time()
  dir.create(opts$out, showWarnings = FALSE, recursive = TRUE)

  d <- read.csv(opts$data, check.names = FALSE, stringsAsFactors = FALSE)
  if (anyDuplicated(d$V1)) stop("V1 is not unique")
  meta <- fromJSON(opts$metadata, simplifyVector = FALSE)
  mis <- parse_metadata(meta)
  cw <- read.csv(opts$crosswalk, colClasses = "character", check.names = FALSE)
  cwp <- parse_crosswalk(cw)
  grid <- fromJSON(opts$grid, simplifyVector = FALSE)
  specs <- setNames(grid$specs, vapply(grid$specs, function(x) x$spec_id, ""))
  order_ids <- unlist(grid$compute_order)
  missing_specs <- setdiff(order_ids, names(specs))
  if (length(missing_specs)) stop("compute_order refers to unknown specs: ", paste(missing_specs, collapse = ", "))

  coefs <- list(); stats <- list(); nested <- list(); samples <- list(); influence <- list()
  failures <- list(); specs_run <- character(0); notes <- list()

  all_models <- c(names(model_list("org")), names(model_list("mkt")))
  influence_models <- c("org_M2", "org_M3", "org_M4", "org_M5", "mkt_M7", "mkt_M8", "mkt_M9", "mkt_M10")

  for (sid in order_ids) {
    spec <- specs[[sid]]
    missing_axes <- setdiff(AXES, names(spec$settings))
    if (length(missing_axes)) {
      failures[[length(failures) + 1]] <- list(spec_id = sid, model_id = NA, error = paste("missing axes:", paste(missing_axes, collapse = ", ")))
    }
    message(sprintf("[%s] spec %s (%s)", format(Sys.time(), "%H:%M:%S"), sid, spec$type))
    res <- tryCatch(run_spec(d, spec, mis, cwp), error = function(e) list(error = conditionMessage(e)))
    specs_run <- c(specs_run, sid)
    if (!is.null(res$error) && !is.na(res$error)) {
      # whole-spec failure: record every expected model and nested test as failed
      failures[[length(failures) + 1]] <- list(spec_id = sid, model_id = NA, error = res$error)
      stats[[length(stats) + 1]] <- data.frame(
        spec_id = sid, family = ifelse(grepl("^org", all_models), "org", "mkt"), model_id = all_models,
        status = "failed", error = res$error, n = NA, k = NA, n_industry_dummies = NA, dropped_columns = NA,
        r2 = NA, adj_r2 = NA, f = NA, f_df1 = NA, f_df2 = NA, f_p = NA, n_leverage_one = NA, stringsAsFactors = FALSE)
      for (fam in c("org", "mkt")) for (np in nested_pairs(fam)) nested[[length(nested) + 1]] <- data.frame(
        spec_id = sid, family = fam, test_id = np$test_id, full_model = np$full, restricted_model = np$restricted,
        n = NA, delta_r2 = NA, f = NA, df1 = NA, df2 = NA, p = NA, status = "failed",
        error = paste("spec failed:", res$error), stringsAsFactors = FALSE)
      if (identical(spec$type, "origin")) for (mid in influence_models) {
        influence[[length(influence) + 1]] <- data.frame(
          model_id = mid, deleted_V1 = NA, term = NA, estimate = NA, se = NA, p_upper = NA, p_two = NA,
          status = "failed", note = paste("spec failed:", res$error), stringsAsFactors = FALSE)
        failures[[length(failures) + 1]] <- list(spec_id = sid, model_id = paste0("influence:", mid),
                                                 deleted_V1 = NA, error = paste("spec failed:", res$error))
      }
      next
    }
    coefs <- c(coefs, res$coefficients); stats <- c(stats, res$model_stats)
    nested <- c(nested, res$nested_tests); samples <- c(samples, res$samples)
    for (ms in res$model_stats) if (ms$status != "ok")
      failures[[length(failures) + 1]] <- list(spec_id = sid, model_id = ms$model_id, error = ms$error)
    # A6: nested-test failures (full or restricted model failed, or rank increase mismatch) with reasons
    for (nt in res$nested_tests) if (nt$status != "ok")
      failures[[length(failures) + 1]] <- list(spec_id = sid, model_id = paste0("nested:", nt$test_id), error = nt$error)

    if (identical(spec$type, "origin")) {
      message("  influence diagnostic (leave-one-out refits) ...")
      for (mid in influence_models) {
        fam <- if (grepl("^org", mid)) "org" else "mkt"
        fit <- res$designs[[fam]][[mid]]
        m <- model_list(fam)[[mid]]
        inf <- tryCatch(influence_loo(fit, mid, c(m$hrm, m$int)),
                        error = function(e) data.frame(model_id = mid, deleted_V1 = NA, term = NA, estimate = NA,
                                                       se = NA, p_upper = NA, p_two = NA, status = "failed",
                                                       note = conditionMessage(e), stringsAsFactors = FALSE))
        influence[[length(influence) + 1]] <- inf
        # A10: every failed deletion is listed in the failures list as well as in influence.csv
        bad <- inf[inf$status != "ok", , drop = FALSE]
        for (j in seq_len(nrow(bad)))
          failures[[length(failures) + 1]] <- list(spec_id = sid, model_id = paste0("influence:", mid),
                                                   deleted_V1 = bad$deleted_V1[j], error = bad$note[j])
      }
    }
  }

  bind <- function(lst, cols) {
    if (!length(lst)) return(setNames(data.frame(matrix(nrow = 0, ncol = length(cols))), cols))
    df <- do.call(rbind, lst); df[, cols, drop = FALSE]
  }
  wcsv <- function(df, name) write.csv(df, file.path(opts$out, name), row.names = FALSE, na = "NA")

  wcsv(bind(coefs, c("spec_id", "family", "model_id", "term", "estimate", "se", "t", "df", "p_two", "p_upper",
                     "p_lower", "se_hc3", "t_hc3", "p_two_hc3", "p_upper_hc3", "p_lower_hc3")), "coefficients.csv")
  wcsv(bind(stats, c("spec_id", "family", "model_id", "status", "error", "n", "k", "n_industry_dummies",
                     "dropped_columns", "r2", "adj_r2", "f", "f_df1", "f_df2", "f_p", "n_leverage_one")), "model_stats.csv")
  wcsv(bind(nested, c("spec_id", "family", "test_id", "full_model", "restricted_model", "n", "delta_r2",
                      "f", "df1", "df2", "p", "status", "error")), "nested_tests.csv")
  wcsv(bind(samples, c("spec_id", "family", "model_id", "V1")), "samples.csv")
  wcsv(bind(influence, c("model_id", "deleted_V1", "term", "estimate", "se", "p_upper", "p_two", "status", "note")),
       "influence.csv")

  end_time <- Sys.time()
  pkgs <- c("jsonlite")
  info <- list(
    software = "R",
    versions = c(list(R = R.version.string, platform = R.version$platform),
                 setNames(lapply(pkgs, function(p) as.character(packageVersion(p))), pkgs)),
    script = "code/run_grid.R (+ code/k7_lib.R)",
    specification = "PAPER_K7 v1 (frozen) as amended by spec_amendment_v1_1.md",
    code_version = "v1.1",
    grid_version = grid$grid_version,
    inputs = list(data = opts$data, metadata = opts$metadata, crosswalk = opts$crosswalk, grid = opts$grid),
    n_records_in_data = nrow(d),
    start_time = format(start_time, "%Y-%m-%dT%H:%M:%S%z"),
    end_time = format(end_time, "%Y-%m-%dT%H:%M:%S%z"),
    elapsed_seconds = as.numeric(difftime(end_time, start_time, units = "secs")),
    specs_run = specs_run,
    n_specs_run = length(specs_run),
    failures = failures,
    n_failures = length(failures),
    not_implemented = list(),
    implementation_notes = list(
      "Crosswalk field sic2_from_printed is split on ';' as well as ',' (the supplied file uses ';').",
      "Census codes are matched as integers (crosswalk codes are zero-padded strings, V43 is numeric).",
      "Out-of-range codes on reversed 1..k items (e.g. a stored 0 on V233) are treated as missing.",
      "HC3: rows with hat value >= 1 - 1e-8 contribute zero (A1); their count is model_stats.csv n_leverage_one.",
      "Only industry dummies are ever dropped (A5); nested_tests.csv carries status/error columns (A5/A6).",
      "Missing values are NA in the CSV files and null in this JSON file (A6).",
      "See code/README.md for the full list of interpretations and the v1.1 change list."))
  writeLines(toJSON(info, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null"),
             file.path(opts$out, "run_info.json"))
  message(sprintf("done: %d specs, %d failures, %.1f s", length(specs_run), length(failures), info$elapsed_seconds))
  invisible(info)
}

if (!exists("K7_NO_MAIN") && !interactive()) main()
