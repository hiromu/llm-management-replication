# Grid driver: compute order (manifest section 7), outputs (section 8), non-equivalent runs,
# algebraic checks and influence deletions (sections 5, 6, 9)

ORIGIN_U <- c(U1 = 0, U2 = 0, U3 = 0, U4 = 0, U5 = 0, U6 = 0, U7 = 0, U8 = 0)

grid_cells <- function() {
  cells <- list(list(step = 1, U = ORIGIN_U))
  for (k in 1:6) { U <- ORIGIN_U; U[k] <- 1; cells[[length(cells) + 1]] <- list(step = 2, U = U) }
  for (v in 1:2) { U <- ORIGIN_U; U["U7"] <- v; cells[[length(cells) + 1]] <- list(step = 2, U = U) }
  U <- ORIGIN_U; U["U8"] <- 1; cells[[length(cells) + 1]] <- list(step = 2, U = U)
  eg <- expand.grid(U1 = 0:1, U2 = 0:1, U3 = 0:1, U4 = 0:1, U5 = 0:1, U6 = 0:1, U7 = 0:2)
  for (i in seq_len(nrow(eg))) { U <- ORIGIN_U; U[1:7] <- as.numeric(eg[i, ]); cells[[length(cells) + 1]] <- list(step = 3, U = U) }
  cells
}

log_msg <- function(...) cat(sprintf("[%s] ", format(Sys.time(), "%H:%M:%S")), sprintf(...), "\n", sep = "")

# sample cache keyed by U1..U6 and U8 (U8 changes the M1 model-specific complete-case count at S8)
make_sample_store <- function(raw, results_dir) {
  env <- new.env(); env$cache <- list(); env$flows <- list(); env$hash_of <- list()
  get <- function(U) {
    key <- paste(c(U[1:6], U[8]), collapse = "")
    if (!is.null(env$cache[[key]])) return(env$cache[[key]])
    s <- build_sample(raw, U[1], U[2], U[3], U[4], U[5], U[6], U8 = U[8])
    h <- sample_hash(s$data)
    write_sample_file(s$data, h, file.path(results_dir, "samples"))
    fkey <- paste(h, U[8], sep = "_")
    if (is.null(env$flows[[fkey]])) {
      fl <- s$flow; fl$sample_hash <- h
      for (k in 1:6) fl[[paste0("U", k)]] <- U[k]
      fl$U8 <- U[8]
      env$flows[[fkey]] <- fl
    }
    env$hash_of[[key]] <- h
    res <- list(data = s$data, hash = h, n_disagree = s$n_disagree)
    env$cache[[key]] <- res
    res
  }
  list(get = get, env = env)
}

write_flows <- function(store, results_dir) {
  fl <- do.call(rbind, unname(store$env$flows))
  fl <- fl[, c("sample_hash", "U1", "U2", "U3", "U4", "U5", "U6", "U8", "step", "description", "rows")]
  write.csv(fl, file.path(results_dir, "sample_flow.csv"), row.names = FALSE)
  cells <- data.frame(key = names(store$env$hash_of), sample_hash = unlist(store$env$hash_of), stringsAsFactors = FALSE)
  cells$U1 <- substr(cells$key, 1, 1); cells$U2 <- substr(cells$key, 2, 2); cells$U3 <- substr(cells$key, 3, 3)
  cells$U4 <- substr(cells$key, 4, 4); cells$U5 <- substr(cells$key, 5, 5); cells$U6 <- substr(cells$key, 6, 6); cells$U8 <- substr(cells$key, 7, 7)
  write.csv(cells[, c("U1", "U2", "U3", "U4", "U5", "U6", "U8", "sample_hash")], file.path(results_dir, "sample_cells.csv"), row.names = FALSE)
  fl
}

run_sample_stage <- function(raw, results_dir) {
  store <- make_sample_store(raw, results_dir)
  eg <- expand.grid(U1 = 0:1, U2 = 0:1, U3 = 0:1, U4 = 0:1, U5 = 0:1, U6 = 0:1)
  # origin first
  s0 <- store$get(ORIGIN_U)
  log_msg("origin sample: %d rows, hash %s", nrow(s0$data), s0$hash)
  # the U8 = 1 cell (origin U1..U6 with below_indicator in M1)
  U8c <- ORIGIN_U; U8c["U8"] <- 1; s8 <- store$get(U8c)
  log_msg("U8=1 cell sample: %d rows, hash %s", nrow(s8$data), s8$hash)
  for (i in seq_len(nrow(eg))) { U <- ORIGIN_U; U[1:6] <- as.numeric(eg[i, ]); s <- store$get(U) }
  fl <- write_flows(store, results_dir)
  NOTES$add(sprintf("Sample stage: %d distinct realised samples (row sets) over the 64 U1..U6 combinations (row sets depend on U1, U2, U3 only), plus the U8=1 cell's S8 block; same_division vs games.div_game disagreements in the origin sample: %d.",
                    length(unique(fl$sample_hash)), s0$n_disagree))
  invisible(list(store = store, flows = fl))
}

# ---- accumulators ------------------------------------------------------------

ACC <- new.env()
acc_init <- function() { for (n in c("specs", "coefs", "margins", "tests", "nonequiv", "algebraic", "influence")) ACC[[n]] <- list() }
acc_add <- function(name, df) if (!is.null(df) && nrow(df) > 0) ACC[[name]][[length(ACC[[name]]) + 1]] <- df
rbind_fill <- function(lst) {
  cols <- unique(unlist(lapply(lst, names)))
  lst <- lapply(lst, function(d) { for (cc in setdiff(cols, names(d))) d[[cc]] <- NA; d[, cols, drop = FALSE] })
  do.call(rbind, lst)
}

SPECS_COLS <- c("spec_id", "step", "model", "U1", "U2", "U3", "U4", "U5", "U6", "U7", "U8", "me_variant_set", "sample_hash", "status", "error",
                "n_obs", "n_groups_used", "n_groups_dropped", "loglik", "null_loglik", "null_label", "lr_chi2", "df", "converged", "iterations", "routine", "duplicate_of")
COEFS_COLS <- c("spec_id", "step", "model", "term", "estimate", "se_native", "z_native", "p_native", "or", "or_se", "se_bench", "p_bench", "n_clusters_bench")
MARGINS_COLS <- c("spec_id", "step", "model", "variant", "minutes_eval", "d", "prob", "effect", "se_native", "z_native", "p_native", "se_bench", "p_bench")
TESTS_COLS <- c("spec_id", "step", "test", "statistic", "df", "p")
# nonequiv.csv / algebraic_checks.csv: run_id, record type, then the union of the four column formats above (in order)
LONG_COLS <- c("run_id", "record", unique(c(SPECS_COLS, COEFS_COLS, MARGINS_COLS, TESTS_COLS)))

acc_write <- function(results_dir) {
  wr <- function(name, file, cols = NULL) {
    x <- ACC[[name]]
    df <- if (length(x)) rbind_fill(x) else NULL
    if (is.null(df)) { if (!is.null(cols)) df <- as.data.frame(setNames(replicate(length(cols), character(0), simplify = FALSE), cols)) else return(invisible()) }
    if (!is.null(cols)) { for (cc in setdiff(cols, names(df))) df[[cc]] <- NA; df <- df[, cols, drop = FALSE] }
    write.csv(df, file.path(results_dir, file), row.names = FALSE, na = "")
  }
  wr("specs", "specs.csv", SPECS_COLS)
  wr("coefs", "coefs.csv", COEFS_COLS)
  wr("margins", "margins.csv", MARGINS_COLS)
  wr("tests", "tests.csv", TESTS_COLS)
  wr("nonequiv", "nonequiv.csv", LONG_COLS)
  wr("algebraic", "algebraic_checks.csv", LONG_COLS)
  wr("influence", "influence.csv", c("unit_type", "unit_id", "model", "term", "estimate", "se_native", "p_native", "se_bench", "p_bench", "n_obs", "status", "error"))
}

# convert spec/coef/margin/test data frames into the long format used by nonequiv.csv / algebraic_checks.csv
to_long <- function(run_id, record, df) { df$run_id <- run_id; df$record <- record; df }

# spec row for a fit that could not be produced at all (error outside fit_model)
failed_spec_row <- function(sid, step, model, U, me_variant_set, sample_hash, duplicate_of, error) {
  data.frame(spec_id = sid, step = step, model = model, U1 = U[1], U2 = U[2], U3 = U[3], U4 = U[4], U5 = U[5], U6 = U[6], U7 = U[7], U8 = U[8],
             me_variant_set = me_variant_set, sample_hash = sample_hash, status = "failed", error = error,
             n_obs = NA, n_groups_used = NA, n_groups_dropped = NA, loglik = NA, null_loglik = NA, null_label = "", lr_chi2 = NA, df = NA,
             converged = FALSE, iterations = NA, routine = "", duplicate_of = duplicate_of, stringsAsFactors = FALSE)
}

err_msg <- function(e) { m <- conditionMessage(e); if (is.null(m) || !nzchar(m)) "error (no message)" else gsub("[\r\n]+", " ", m) }
join_err <- function(...) { x <- c(...); x <- x[!is.na(x) & nzchar(x)]; paste(x, collapse = "; ") }

# ---- one grid cell -----------------------------------------------------------

# Every model of the cell is attempted; an exception anywhere is recorded in the spec row's status/error
# (actual message) and execution continues with the remaining models, tests and cells.
fit_cell <- function(U, step, store, u71_cache, seen) {
  models <- if (U["U8"] == 1) "M1" else c("M1", "M2", "M3")
  variants <- if (step == 1) c("ME0", "U9a", "U9b", "U10a", "N3") else if (step == 2) c("ME0", "U9a", "U9b", "U10a") else "ME0"
  mvs <- function(model) paste(if (model %in% c("M2", "M3")) variants else "", collapse = ",")
  fits <- list(); sids <- list()
  s <- tryCatch(store$get(U), error = function(e) e)
  if (inherits(s, "error")) {
    log_msg("CELL ERROR (sample construction) %s: %s", paste(U, collapse = ""), err_msg(s))
    for (model in models) {
      sid <- spec_id(model, U); dup <- if (step == 3 && !is.null(seen[[sid]])) seen[[sid]] else ""
      if (step <= 2) seen[[sid]] <- sprintf("step %d: %s", step, sid)
      acc_add("specs", failed_spec_row(sid, step, model, U, mvs(model), "", dup, paste("sample construction:", err_msg(s))))
    }
    return(fits)
  }
  dat <- s$data
  for (model in models) {
    sid <- spec_id(model, U); sids[[model]] <- sid
    dup <- if (step == 3 && !is.null(seen[[sid]])) seen[[sid]] else ""
    if (step <= 2) seen[[sid]] <- sprintf("step %d: %s", step, sid)
    terms <- model_terms(model, U["U7"], U["U8"])
    t0 <- Sys.time()
    done <- tryCatch({
      fit <- fit_model(dat, terms, U["U7"])            # fit_model catches its own errors (status = failed, error = message)
      fits[[model]] <- fit
      errs <- fit$error
      bench <- NULL
      if (U["U7"] == 1 && !is.null(fit$vcov)) {
        bench <- tryCatch(cluster_vcov(fit, dat$game_id), error = function(e) { errs <<- join_err(errs, paste("benchmark covariance:", err_msg(e))); NULL })
      }
      if (U["U7"] == 1 && !is.null(fit$vcov)) u71_cache[[sid]] <- list(fit = fit, bench = bench)
      cr <- coef_rows(fit, if (!is.null(bench)) bench$vcov else NULL, if (!is.null(bench)) bench$n_clusters else NA)
      cr <- cbind(spec_id = sid, step = step, model = model, cr, stringsAsFactors = FALSE)
      mr <- NULL
      if (model %in% c("M2", "M3") && !is.null(fit$vcov)) {
        fit71 <- NULL
        if ("U9a" %in% variants) {
          if (U["U7"] == 1) fit71 <- fit
          else {
            U1 <- U; U1["U7"] <- 1; sid1 <- spec_id(model, U1)
            if (is.null(u71_cache[[sid1]])) {
              f71 <- fit_model(dat, model_terms(model, 1, U["U8"]), 1)
              # only the native covariance of the counterpart is used (U9a SE); its benchmark covariance is not reported here
              if (!is.null(f71$vcov)) u71_cache[[sid1]] <- list(fit = f71, bench = NULL)
              log_msg("  (U7=1 counterpart %s fitted for U9a: ll=%s status=%s)", sid1, format(f71$loglik), f71$status)
              if (f71$status != "ok") errs <- join_err(errs, sprintf("U9a counterpart U7=1 fit %s: %s", f71$status, f71$error))
            }
            if (!is.null(u71_cache[[sid1]])) fit71 <- u71_cache[[sid1]]$fit
          }
        }
        # benchmark columns only on U7 = 1 fits (grid.json benchmark_inference): for U7 = 0/2 cells the U9a rows
        # (which use the U7 = 1 counterpart) carry no benchmark SE/p
        mr <- tryCatch(margins_for_fit(fit, dat, model, TIME_MIN, variants = variants, fit_u71 = fit71,
                                       V_bench = if (!is.null(bench)) bench$vcov else NULL,
                                       V_bench_u71 = if (U["U7"] == 1 && !is.null(bench)) bench$vcov else NULL),
                       error = function(e) { errs <<- join_err(errs, paste("marginal effects:", err_msg(e))); NULL })
      }
      fit$error <- errs
      sr <- spec_row(fit, sid, step, model, U, mvs(model), s$hash, dup)
      acc_add("specs", sr)
      acc_add("coefs", cr)
      if (!is.null(mr)) acc_add("margins", cbind(spec_id = sid, step = step, model = model, mr, stringsAsFactors = FALSE))
      log_msg("%s step %d  n=%s groups=%s ll=%s iter=%s status=%s (%.1fs)", sid, step, format(fit$n_obs), format(fit$n_groups), format(fit$loglik), format(fit$iter), fit$status, as.numeric(Sys.time() - t0, units = "secs"))
      TRUE
    }, error = function(e) {
      log_msg("MODEL ERROR %s step %d: %s", sid, step, err_msg(e))
      acc_add("specs", failed_spec_row(sid, step, model, U, mvs(model), s$hash, dup, err_msg(e)))
      FALSE
    })
  }
  tr <- tryCatch(cell_tests(fits, sids), error = function(e) {
    log_msg("TESTS ERROR %s: %s", paste(U, collapse = ""), err_msg(e))
    data.frame(spec_id = sids[[length(sids)]], test = "tests_failed", statistic = NA, df = NA, p = NA, stringsAsFactors = FALSE)
  })
  if (!is.null(tr)) acc_add("tests", cbind(tr[, "spec_id", drop = FALSE], step = step, tr[, c("test", "statistic", "df", "p")], stringsAsFactors = FALSE))
  fits
}

# ---- non-equivalent runs -----------------------------------------------------

re_as_fit <- function(fre, terms) {
  # adapt a random-intercept fit to the fit interface used by margins_for_fit (index without intercept, u = 0)
  cf <- fre$theta[terms]; V <- fre$vcov[terms, terms]
  list(coef = cf, vcov = V, terms = terms, est_rows = seq_len(fre$n_obs), U7 = 9, group_terms = character(0))
}

run_N1 <- function(dat, origin_hash) {
  run_id <- "N1"
  fits <- list()
  Xnull <- matrix(1, nrow(dat), 1, dimnames = list(NULL, "(Intercept)"))
  t0 <- Sys.time()
  null_err <- ""
  fnull <- tryCatch(re_fit(Xnull, dat$y, dat$team, Q = 12), error = function(e) { null_err <<- paste("N1 null fit:", err_msg(e)); NULL })
  if (is.null(fnull)) log_msg("N1 null fit ERROR: %s (continuing with the N1 models; null_loglik = NA)", null_err)
  else log_msg("N1 null (random intercept only): ll=%.4f (%.0fs)", fnull$loglik, as.numeric(Sys.time() - t0, units = "secs"))
  for (model in c("M1", "M2", "M3")) {
    terms <- model_terms(model, U7 = 0); sid <- spec_id(model, ORIGIN_U)
    mvs <- if (model != "M1") "ME0" else ""
    X <- cbind("(Intercept)" = 1, as.matrix(dat[, terms]))
    t0 <- Sys.time()
    fre <- tryCatch(re_fit(X, dat$y, dat$team, Q = 12), error = function(e) e)
    if (inherits(fre, "error")) {
      log_msg("N1 %s ERROR: %s", model, err_msg(fre))
      acc_add("nonequiv", to_long(run_id, "spec", failed_spec_row(sid, 4, model, ORIGIN_U, mvs, origin_hash, "", join_err(paste("re_fit:", err_msg(fre)), null_err))))
      next
    }
    log_msg("N1 %s: ll=%.4f sigma_u=%.4f conv=%s (%.0fs)", model, fre$loglik, fre$sigma_u, fre$converged, as.numeric(Sys.time() - t0, units = "secs"))
    fits[[model]] <- fre
    errs <- null_err
    sp <- data.frame(spec_id = sid, step = 4, model = model, U1 = 0, U2 = 0, U3 = 0, U4 = 0, U5 = 0, U6 = 0, U7 = 0, U8 = 0, me_variant_set = mvs,
                     sample_hash = origin_hash, status = if (fre$converged) "ok" else "not_converged", error = "",
                     n_obs = fre$n_obs, n_groups_used = fre$n_groups, n_groups_dropped = 0, loglik = fre$loglik,
                     null_loglik = if (is.null(fnull)) NA else fnull$loglik,
                     null_label = "random intercept only (intercept + normal team effect, no regressors)",
                     lr_chi2 = if (is.null(fnull)) NA else 2 * (fre$loglik - fnull$loglik),
                     df = length(terms), converged = fre$converged, iterations = fre$iter, routine = fre$routine, duplicate_of = "", stringsAsFactors = FALSE)
    se <- sqrt(diag(fre$vcov)); b <- fre$theta
    cr <- data.frame(spec_id = sid, step = 4, model = model, term = names(b), estimate = as.numeric(b), se_native = as.numeric(se), z_native = as.numeric(b / se),
                     p_native = 2 * pnorm(-abs(as.numeric(b / se))), or = exp(as.numeric(b)), or_se = exp(as.numeric(b)) * as.numeric(se), stringsAsFactors = FALSE)
    sig <- fre$sigma_u; sig_se <- fre$sigma_u_se
    rho <- sig^2 / (sig^2 + pi^2 / 3); rho_se <- abs(2 * sig * (pi^2 / 3) / (sig^2 + pi^2 / 3)^2) * sig_se
    cr <- rbind(cr, data.frame(spec_id = sid, step = 4, model = model, term = c("sigma_u", "rho"), estimate = c(sig, rho), se_native = c(sig_se, rho_se),
                               z_native = NA, p_native = NA, or = NA, or_se = NA, stringsAsFactors = FALSE))
    mr <- NULL
    if (model %in% c("M2", "M3")) {
      mr <- tryCatch(margins_for_fit(re_as_fit(fre, terms), dat, model, TIME_MIN, variants = "ME0"),
                     error = function(e) { errs <<- join_err(errs, paste("marginal effects:", err_msg(e))); NULL })
    }
    sp$error <- errs
    acc_add("nonequiv", to_long(run_id, "spec", sp))
    acc_add("nonequiv", to_long(run_id, "coef", cr))
    if (!is.null(mr)) acc_add("nonequiv", to_long(run_id, "margin", cbind(spec_id = sid, step = 4, model = model, mr, stringsAsFactors = FALSE)))
  }
  # tests
  ff <- lapply(fits, function(f) list(loglik = f$loglik, df_model = f$p - 1, coef = f$theta, vcov = f$vcov))
  tr <- tryCatch(cell_tests(ff, list(M1 = spec_id("M1", ORIGIN_U), M2 = spec_id("M2", ORIGIN_U), M3 = spec_id("M3", ORIGIN_U))),
                 error = function(e) { log_msg("N1 tests ERROR: %s", err_msg(e)); NULL })
  if (!is.null(tr)) acc_add("nonequiv", to_long(run_id, "test", cbind(tr, step = 4, stringsAsFactors = FALSE)))
}

run_N2 <- function(dat, origin_hash) {
  run_id <- "N2"; fits <- list(); sids <- list()
  for (model in c("M1", "M2", "M3")) {
    terms <- model_terms(model, U7 = 0, time = TIME_QTR); sid <- spec_id(model, ORIGIN_U); sids[[model]] <- sid
    mvs <- if (model != "M1") "ME0,U9a,U9b,U10a,N3" else ""
    t0 <- Sys.time()
    ok <- tryCatch({
      fit <- fit_model(dat, terms, 0); fits[[model]] <- fit
      errs <- fit$error
      log_msg("N2 %s: ll=%s status=%s (%.0fs)", model, format(fit$loglik), fit$status, as.numeric(Sys.time() - t0, units = "secs"))
      cr <- cbind(spec_id = sid, step = 4, model = model, coef_rows(fit), stringsAsFactors = FALSE)
      mr <- NULL
      if (model %in% c("M2", "M3") && !is.null(fit$vcov)) {
        f71 <- fit_model(dat, model_terms(model, 1, time = TIME_QTR), 1)
        if (f71$status != "ok") errs <- join_err(errs, sprintf("U9a counterpart U7=1 fit %s: %s", f71$status, f71$error))
        # U7 = 0 run: no benchmark columns (also not on the U9a rows)
        mr <- tryCatch(margins_for_fit(fit, dat, model, TIME_QTR, variants = c("ME0", "U9a", "U9b", "U10a", "N3"), fit_u71 = f71, time_grid = c(4, 3, 2, 1)),
                       error = function(e) { errs <<- join_err(errs, paste("marginal effects:", err_msg(e))); NULL })
      }
      fit$error <- errs
      sp <- spec_row(fit, sid, 4, model, ORIGIN_U, mvs, origin_hash)
      acc_add("nonequiv", to_long(run_id, "spec", sp))
      acc_add("nonequiv", to_long(run_id, "coef", cr))
      if (!is.null(mr)) acc_add("nonequiv", to_long(run_id, "margin", cbind(spec_id = sid, step = 4, model = model, mr, stringsAsFactors = FALSE)))
      TRUE
    }, error = function(e) {
      log_msg("N2 %s ERROR: %s", model, err_msg(e))
      acc_add("nonequiv", to_long(run_id, "spec", failed_spec_row(sid, 4, model, ORIGIN_U, mvs, origin_hash, "", err_msg(e))))
      FALSE
    })
  }
  tr <- tryCatch(cell_tests(fits, sids), error = function(e) { log_msg("N2 tests ERROR: %s", err_msg(e)); NULL })
  if (!is.null(tr)) acc_add("nonequiv", to_long(run_id, "test", cbind(tr, step = 4, stringsAsFactors = FALSE)))
}

run_N4 <- function(dat, origin_hash) {
  run_id <- "N4"
  for (model in c("M1", "M2", "M3")) {
    terms <- model_terms(model, U7 = 1); U <- ORIGIN_U; U["U7"] <- 1; sid <- spec_id(model, U)
    mvs <- if (model != "M1") "ME0" else ""
    ok <- tryCatch({
      fit <- fit_model(dat, terms, 1)
      errs <- fit$error
      bt <- if (!is.null(fit$vcov)) tryCatch(cluster_vcov(fit, dat$team), error = function(e) { errs <<- join_err(errs, paste("team-clustered covariance:", err_msg(e))); NULL }) else NULL
      log_msg("N4 %s: ll=%s clusters(team)=%s status=%s", model, format(fit$loglik), if (is.null(bt)) NA else bt$n_clusters, fit$status)
      cr <- cbind(spec_id = sid, step = 4, model = model, coef_rows(fit, if (!is.null(bt)) bt$vcov else NULL, if (!is.null(bt)) bt$n_clusters else NA), stringsAsFactors = FALSE)
      mr <- NULL
      if (model %in% c("M2", "M3") && !is.null(fit$vcov)) {
        mr <- tryCatch(margins_for_fit(fit, dat, model, TIME_MIN, variants = "ME0", V_bench = if (!is.null(bt)) bt$vcov else NULL),
                       error = function(e) { errs <<- join_err(errs, paste("marginal effects:", err_msg(e))); NULL })
      }
      fit$error <- errs
      sp <- spec_row(fit, sid, 4, model, U, mvs, origin_hash)
      sp$routine <- paste0(sp$routine, "; benchmark columns: CR1 sandwich clustered by team (posteam)")
      acc_add("nonequiv", to_long(run_id, "spec", sp))
      acc_add("nonequiv", to_long(run_id, "coef", cr))
      if (!is.null(mr)) acc_add("nonequiv", to_long(run_id, "margin", cbind(spec_id = sid, step = 4, model = model, mr, stringsAsFactors = FALSE)))
      TRUE
    }, error = function(e) {
      log_msg("N4 %s ERROR: %s", model, err_msg(e))
      acc_add("nonequiv", to_long(run_id, "spec", failed_spec_row(sid, 4, model, U, mvs, origin_hash, "", err_msg(e))))
      FALSE
    })
  }
}

run_algebraic <- function(dat, origin_fits, origin_hash) {
  ll_or <- function(m) if (!is.null(origin_fits[[m]]) && is.finite(origin_fits[[m]]$loglik)) origin_fits[[m]]$loglik else NA_real_
  cf_or <- function(m, tm) if (!is.null(origin_fits[[m]]) && !is.null(origin_fits[[m]]$coef) && tm %in% names(origin_fits[[m]]$coef)) as.numeric(origin_fits[[m]]$coef[tm]) else NA_real_
  # K1 (independent of K2: a failure here is recorded and K2 still runs)
  sid <- spec_id("M3", ORIGIN_U)
  tryCatch({
    terms <- model_terms("M3", U7 = 0, time = TIME_ELAPSED)
    fk1 <- fit_model(dat, terms, 0)
    d1 <- fk1$loglik - ll_or("M3")
    log_msg("K1: LL(elapsed) - LL(origin M3) = %s (status %s)", format(d1, digits = 4), fk1$status)
    sp <- spec_row(fk1, sid, 5, "M3", ORIGIN_U, "", origin_hash)
    acc_add("algebraic", to_long("K1", "spec", sp))
    acc_add("algebraic", to_long("K1", "coef", cbind(spec_id = sid, step = 5, model = "M3", coef_rows(fk1), stringsAsFactors = FALSE)))
    acc_add("algebraic", to_long("K1", "check", data.frame(spec_id = sid, step = 5, model = "M3", test = "K1_loglik_elapsed_minus_origin_M3", statistic = d1, df = NA, p = NA,
                                                            term = "loglik_difference", estimate = d1, stringsAsFactors = FALSE)))
  }, error = function(e) {
    log_msg("K1 ERROR: %s", err_msg(e))
    acc_add("algebraic", to_long("K1", "spec", failed_spec_row(sid, 5, "M3", ORIGIN_U, "", origin_hash, "", err_msg(e))))
  })
  # K2
  sid <- spec_id("M2", ORIGIN_U)
  tryCatch({
    terms <- model_terms("M2", U7 = 0, home_var = "home_field_complement")
    fk2 <- fit_model(dat, terms, 0)
    d2 <- fk2$loglik - ll_or("M2")
    b_or <- cf_or("M2", "home_field"); b_k2 <- if ("home_field_complement" %in% names(fk2$coef)) as.numeric(fk2$coef["home_field_complement"]) else NA_real_
    log_msg("K2: LL(1-home_field) - LL(origin M2) = %s; coef origin %s complement %s (status %s)", format(d2, digits = 4), format(b_or), format(b_k2), fk2$status)
    sp <- spec_row(fk2, sid, 5, "M2", ORIGIN_U, "", origin_hash)
    acc_add("algebraic", to_long("K2", "spec", sp))
    acc_add("algebraic", to_long("K2", "coef", cbind(spec_id = sid, step = 5, model = "M2", coef_rows(fk2), stringsAsFactors = FALSE)))
    acc_add("algebraic", to_long("K2", "check", data.frame(spec_id = sid, step = 5, model = "M2",
                                                            test = c("K2_loglik_complement_minus_origin_M2", "K2_coef_home_field_origin", "K2_coef_home_field_complement", "K2_coef_sum"),
                                                            statistic = c(d2, b_or, b_k2, b_or + b_k2),
                                                            df = NA, p = NA, term = c("loglik_difference", "home_field (origin M2)", "home_field_complement (K2 M2)", "sum of the two coefficients"),
                                                            estimate = c(d2, b_or, b_k2, b_or + b_k2), stringsAsFactors = FALSE)))
  }, error = function(e) {
    log_msg("K2 ERROR: %s", err_msg(e))
    acc_add("algebraic", to_long("K2", "spec", failed_spec_row(sid, 5, "M2", ORIGIN_U, "", origin_hash, "", err_msg(e))))
  })
}

# ---- influence deletions -----------------------------------------------------

influence_one <- function(unit_type, unit_id, dat, origin_fits, origin_fits71) {
  sub <- switch(unit_type, team = dat[dat$team != unit_id, ], season = dat[dat$season != as.integer(unit_id), ], game = dat[dat$game_id != unit_id, ])
  rows <- list()
  as_failed <- function(e) list(coef = NULL, vcov = NULL, status = "failed", error = err_msg(e))
  for (model in c("M2", "M3")) {
    terms <- model_terms(model, U7 = 0)
    rec <- if (model == "M2") PERF_TERMS else c(PERF_TERMS, TIME_MIN$inter)
    st0 <- origin_fits[[model]]$coef; in0 <- origin_fits[[model]]$info; st1 <- origin_fits71[[model]]$coef
    f0 <- tryCatch(fit_model(sub, terms, 0, start = st0, info0 = in0), error = as_failed)
    f1 <- tryCatch(fit_model(sub, model_terms(model, U7 = 1), 1, start = st1), error = as_failed)
    b1 <- NULL; b1_err <- ""
    if (!is.null(f1$vcov)) b1 <- tryCatch(cluster_vcov(f1, sub$game_id), error = function(e) { b1_err <<- paste("benchmark covariance:", err_msg(e)); NULL })
    st <- f0$status
    err <- f0$error
    if (f1$status != "ok") err <- join_err(err, sprintf("U7=1 fit %s: %s", f1$status, f1$error))
    err <- join_err(err, b1_err)
    for (tm in rec) {
      est <- if (!is.null(f0$coef) && tm %in% names(f0$coef)) f0$coef[tm] else NA_real_
      se <- if (!is.null(f0$vcov) && tm %in% rownames(f0$vcov)) sqrt(f0$vcov[tm, tm]) else NA_real_
      seb <- if (!is.null(b1) && tm %in% rownames(b1$vcov)) sqrt(b1$vcov[tm, tm]) else NA_real_
      eb <- if (!is.null(f1$coef) && tm %in% names(f1$coef)) f1$coef[tm] else NA_real_
      rows[[length(rows) + 1]] <- data.frame(unit_type = unit_type, unit_id = as.character(unit_id), model = model, term = tm, estimate = as.numeric(est),
                                             se_native = as.numeric(se), p_native = 2 * pnorm(-abs(as.numeric(est / se))),
                                             se_bench = as.numeric(seb), p_bench = 2 * pnorm(-abs(as.numeric(eb / seb))),
                                             n_obs = nrow(sub), status = st, error = err, stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}

INFL <- new.env()   # shared objects for the influence workers (exported to cluster workers)

influence_worker <- function(id) {
  tryCatch(influence_one(INFL$ut, id, INFL$dat, INFL$origin_fits, INFL$origin_fits71),
           error = function(e) data.frame(unit_type = INFL$ut, unit_id = as.character(id), model = NA, term = NA, estimate = NA, se_native = NA, p_native = NA,
                                          se_bench = NA, p_bench = NA, n_obs = NA, status = "failed", error = err_msg(e), stringsAsFactors = FALSE))
}

run_influence <- function(dat, origin_fits, origin_fits71, cores = 1, results_dir, code_dir = NULL) {
  units <- list(team = sort(unique(dat$team)), season = sort(unique(dat$season)), game = sort(unique(dat$game_id)))
  INFL$dat <- dat; INFL$origin_fits <- origin_fits; INFL$origin_fits71 <- origin_fits71
  cl <- NULL
  if (cores > 1 && !is.null(code_dir)) {
    cl <- tryCatch({
      cl <- parallel::makeCluster(cores)
      parallel::clusterExport(cl, "code_dir", envir = environment())
      parallel::clusterEvalQ(cl, { for (f in c("lib_clogit.R", "lib_data.R", "lib_fit.R", "lib_relogit.R", "lib_grid.R")) source(file.path(code_dir, f)); NULL })
      cl
    }, error = function(e) { log_msg("could not start a cluster (%s); running serially", err_msg(e)); NULL })
    if (!is.null(cl)) on.exit(parallel::stopCluster(cl), add = TRUE)
  }
  for (ut in names(units)) {
    ids <- units[[ut]]
    INFL$ut <- ut
    log_msg("influence: unit %s, %d deletions (%s)", ut, length(ids), if (is.null(cl)) "serial" else sprintf("%d socket workers", cores))
    t0 <- Sys.time()
    res <- NULL
    if (!is.null(cl)) {
      res <- tryCatch({
        parallel::clusterExport(cl, "INFL", envir = globalenv())
        parallel::parLapplyLB(cl, ids, influence_worker)
      }, error = function(e) { log_msg("cluster run failed for unit %s (%s); rerunning this unit serially", ut, err_msg(e)); NULL })
    }
    if (is.null(res)) {
      res <- vector("list", length(ids))
      for (i in seq_along(ids)) {
        res[[i]] <- influence_worker(ids[i])
        if (i %% 25 == 0 || i == length(ids)) log_msg("  %s %d/%d done (%.0fs elapsed)", ut, i, length(ids), as.numeric(Sys.time() - t0, units = "secs"))
      }
    }
    acc_add("influence", do.call(rbind, res))
    acc_write(results_dir)
    log_msg("influence unit %s finished in %.0fs", ut, as.numeric(Sys.time() - t0, units = "secs"))
  }
}

# ---- full run ----------------------------------------------------------------

run_full <- function(raw, results_dir, cores = 1, code_dir = NULL) {
  acc_init()
  store <- make_sample_store(raw, results_dir)
  u71_cache <- new.env(); seen <- new.env()
  cells <- grid_cells()
  origin_fits <- NULL
  for (i in seq_along(cells)) {
    cl <- cells[[i]]
    # fit_cell records failures per model; this outer handler is a backstop that records the actual error
    # for every model of the cell and continues with the next cell
    fits <- tryCatch(fit_cell(cl$U, cl$step, store, u71_cache, seen),
                     error = function(e) {
                       log_msg("CELL ERROR %s: %s", paste(cl$U, collapse = ""), err_msg(e))
                       for (model in if (cl$U["U8"] == 1) "M1" else c("M1", "M2", "M3"))
                         acc_add("specs", failed_spec_row(spec_id(model, cl$U), cl$step, model, cl$U, "", "", "", paste("cell error:", err_msg(e))))
                       NULL
                     })
    if (cl$step == 1) origin_fits <- fits
    if (i %% 20 == 0 || cl$step <= 2) acc_write(results_dir)
  }
  acc_write(results_dir)
  write_flows(store, results_dir)
  s0 <- store$get(ORIGIN_U); dat <- s0$data
  NOTES$add(sprintf("Origin sample: %d rows; same_division vs games.div_game disagreements: %d.", nrow(dat), s0$n_disagree))
  ngd <- function(m) if (!is.null(origin_fits[[m]]) && !is.null(origin_fits[[m]]$n_groups_dropped)) origin_fits[[m]]$n_groups_dropped else NA
  NOTES$add(sprintf("Origin U7=0 fits: groups dropped for no variation in y: M1 %s, M2 %s, M3 %s.", ngd("M1"), ngd("M2"), ngd("M3")))
  # step 4
  log_msg("step 4: non-equivalent runs")
  tryCatch(run_N1(dat, s0$hash), error = function(e) { log_msg("N1 ERROR: %s", err_msg(e)); NOTES$add(paste("N1 failed:", err_msg(e))) })
  acc_write(results_dir)
  tryCatch(run_N2(dat, s0$hash), error = function(e) { log_msg("N2 ERROR: %s", err_msg(e)); NOTES$add(paste("N2 failed:", err_msg(e))) })
  tryCatch(run_N4(dat, s0$hash), error = function(e) { log_msg("N4 ERROR: %s", err_msg(e)); NOTES$add(paste("N4 failed:", err_msg(e))) })
  acc_write(results_dir)
  # step 5
  log_msg("step 5: algebraic checks")
  tryCatch(run_algebraic(dat, origin_fits, s0$hash), error = function(e) { log_msg("K ERROR: %s", err_msg(e)); NOTES$add(paste("Algebraic checks failed:", err_msg(e))) })
  acc_write(results_dir)
  # step 6
  log_msg("step 6: influence deletions")
  U1 <- ORIGIN_U; U1["U7"] <- 1
  origin_fits71 <- list(M2 = u71_cache[[spec_id("M2", U1)]]$fit, M3 = u71_cache[[spec_id("M3", U1)]]$fit)
  tryCatch(run_influence(dat, origin_fits, origin_fits71, cores, results_dir, code_dir), error = function(e) { log_msg("INFLUENCE ERROR: %s", err_msg(e)); NOTES$add(paste("Influence failed:", err_msg(e))) })
  acc_write(results_dir)
  NOTES$add("Influence refits were warm-started from the full-sample (origin) estimates of the same model: U7=0 refits start at the origin coefficients and use the origin information matrix for the Newton direction (score-only iterations) until max|score| < 1e-7, after which the exact information at the solution gives the covariance (verified on synthetic data to give the same estimates and SEs as a cold fit to 1e-13); U7=1 refits pass the origin coefficients as glm starting values. Convergence criteria are unchanged.")
  inf <- if (length(ACC$influence)) rbind_fill(ACC$influence) else NULL
  if (!is.null(inf)) NOTES$add(sprintf("Influence deletions run: team %d, season %d, game %d units; rows with status != ok: %d.",
                                       length(unique(inf$unit_id[inf$unit_type == "team"])), length(unique(inf$unit_id[inf$unit_type == "season"])),
                                       length(unique(inf$unit_id[inf$unit_type == "game"])), sum(inf$status != "ok", na.rm = TRUE)))
  sp <- if (length(ACC$specs)) rbind_fill(ACC$specs) else NULL
  if (!is.null(sp)) NOTES$add(sprintf("Grid fits: %d spec rows; status ok %d, not_converged %d, failed %d.", nrow(sp), sum(sp$status == "ok"), sum(sp$status == "not_converged"), sum(sp$status == "failed")))
  invisible(TRUE)
}
