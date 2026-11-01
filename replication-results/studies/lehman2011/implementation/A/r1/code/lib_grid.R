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

# sample cache keyed by U1..U6
make_sample_store <- function(raw, results_dir) {
  env <- new.env(); env$cache <- list(); env$flows <- list(); env$hash_of <- list()
  get <- function(U) {
    key <- paste(U[1:6], collapse = "")
    if (!is.null(env$cache[[key]])) return(env$cache[[key]])
    s <- build_sample(raw, U[1], U[2], U[3], U[4], U[5], U[6])
    h <- sample_hash(s$data)
    write_sample_file(s$data, h, file.path(results_dir, "samples"))
    if (is.null(env$flows[[h]])) {
      fl <- s$flow; fl$sample_hash <- h
      for (k in 1:6) fl[[paste0("U", k)]] <- U[k]
      env$flows[[h]] <- fl
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
  fl <- fl[, c("sample_hash", "U1", "U2", "U3", "U4", "U5", "U6", "step", "description", "rows")]
  write.csv(fl, file.path(results_dir, "sample_flow.csv"), row.names = FALSE)
  cells <- data.frame(key = names(store$env$hash_of), sample_hash = unlist(store$env$hash_of), stringsAsFactors = FALSE)
  cells$U1 <- substr(cells$key, 1, 1); cells$U2 <- substr(cells$key, 2, 2); cells$U3 <- substr(cells$key, 3, 3)
  cells$U4 <- substr(cells$key, 4, 4); cells$U5 <- substr(cells$key, 5, 5); cells$U6 <- substr(cells$key, 6, 6)
  write.csv(cells[, c("U1", "U2", "U3", "U4", "U5", "U6", "sample_hash")], file.path(results_dir, "sample_cells.csv"), row.names = FALSE)
  fl
}

run_sample_stage <- function(raw, results_dir) {
  store <- make_sample_store(raw, results_dir)
  eg <- expand.grid(U1 = 0:1, U2 = 0:1, U3 = 0:1, U4 = 0:1, U5 = 0:1, U6 = 0:1)
  # origin first
  s0 <- store$get(ORIGIN_U)
  log_msg("origin sample: %d rows, hash %s", nrow(s0$data), s0$hash)
  for (i in seq_len(nrow(eg))) { U <- ORIGIN_U; U[1:6] <- as.numeric(eg[i, ]); s <- store$get(U) }
  fl <- write_flows(store, results_dir)
  NOTES$add(sprintf("Sample stage: %d distinct realised samples over the 64 U1..U6 combinations (row sets depend on U1, U2, U3 only); same_division vs games.div_game disagreements in the origin sample: %d.",
                    length(store$env$flows), s0$n_disagree))
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

acc_write <- function(results_dir) {
  wr <- function(name, file, cols = NULL) {
    x <- ACC[[name]]
    df <- if (length(x)) rbind_fill(x) else NULL
    if (is.null(df)) { if (!is.null(cols)) df <- as.data.frame(setNames(replicate(length(cols), character(0), simplify = FALSE), cols)) else return(invisible()) }
    if (!is.null(cols)) { for (cc in setdiff(cols, names(df))) df[[cc]] <- NA; df <- df[, cols, drop = FALSE] }
    write.csv(df, file.path(results_dir, file), row.names = FALSE, na = "")
  }
  wr("specs", "specs.csv", c("spec_id", "step", "model", "U1", "U2", "U3", "U4", "U5", "U6", "U7", "U8", "me_variant_set", "sample_hash", "status", "error",
                             "n_obs", "n_groups_used", "n_groups_dropped", "loglik", "null_loglik", "null_label", "lr_chi2", "df", "converged", "iterations", "routine", "duplicate_of"))
  wr("coefs", "coefs.csv", c("spec_id", "step", "model", "term", "estimate", "se_native", "z_native", "p_native", "or", "or_se", "se_bench", "p_bench", "n_clusters_bench"))
  wr("margins", "margins.csv", c("spec_id", "step", "model", "variant", "minutes_eval", "d", "prob", "effect", "se_native", "p_native", "se_bench", "p_bench"))
  wr("tests", "tests.csv", c("spec_id", "step", "test", "statistic", "df", "p"))
  long_cols <- c("run_id", "record", "spec_id", "model", "term", "estimate", "se_native", "z_native", "p_native", "or", "or_se", "se_bench", "p_bench", "n_clusters_bench",
                 "variant", "minutes_eval", "d", "prob", "effect", "test", "statistic", "df", "p",
                 "sample_hash", "status", "error", "n_obs", "n_groups_used", "n_groups_dropped", "loglik", "null_loglik", "null_label", "lr_chi2", "converged", "iterations", "routine")
  wr("nonequiv", "nonequiv.csv", long_cols)
  wr("algebraic", "algebraic_checks.csv", long_cols)
  wr("influence", "influence.csv", c("unit_type", "unit_id", "model", "term", "estimate", "se_native", "p_native", "se_bench", "p_bench", "n_obs", "status", "error"))
}

# convert spec/coef/margin/test data frames into the long format used by nonequiv.csv / algebraic_checks.csv
to_long <- function(run_id, record, df) { df$run_id <- run_id; df$record <- record; df }

# ---- one grid cell -----------------------------------------------------------

fit_cell <- function(U, step, store, u71_cache, seen) {
  s <- store$get(U); dat <- s$data
  models <- if (U["U8"] == 1) "M1" else c("M1", "M2", "M3")
  variants <- if (step == 1) c("ME0", "U9a", "U9b", "U10a", "N3") else if (step == 2) c("ME0", "U9a", "U9b", "U10a") else "ME0"
  fits <- list(); sids <- list()
  for (model in models) {
    sid <- spec_id(model, U); sids[[model]] <- sid
    terms <- model_terms(model, U["U7"], U["U8"])
    t0 <- Sys.time()
    fit <- fit_model(dat, terms, U["U7"])
    fits[[model]] <- fit
    bench <- NULL
    if (U["U7"] == 1 && !is.null(fit$vcov)) bench <- cluster_vcov(fit, dat$game_id)
    if (U["U7"] == 1 && !is.null(fit$vcov)) u71_cache[[sid]] <- list(fit = fit, bench = bench)
    dup <- if (step == 3 && !is.null(seen[[sid]])) seen[[sid]] else ""
    if (step <= 2) seen[[sid]] <- sprintf("step %d: %s", step, sid)
    sr <- spec_row(fit, sid, step, model, U, paste(if (model %in% c("M2", "M3")) variants else "", collapse = ","), s$hash, dup)
    acc_add("specs", sr)
    cr <- coef_rows(fit, if (!is.null(bench)) bench$vcov else NULL, if (!is.null(bench)) bench$n_clusters else NA)
    cr <- cbind(spec_id = sid, step = step, model = model, cr, stringsAsFactors = FALSE)
    acc_add("coefs", cr)
    log_msg("%s step %d  n=%d groups=%s ll=%.4f iter=%s status=%s (%.1fs)", sid, step, fit$n_obs, fit$n_groups, fit$loglik, fit$iter, fit$status, as.numeric(Sys.time() - t0, units = "secs"))
    if (model %in% c("M2", "M3") && !is.null(fit$vcov)) {
      fit71 <- NULL; bench71 <- NULL
      if ("U9a" %in% variants) {
        if (U["U7"] == 1) { fit71 <- fit; bench71 <- bench }
        else {
          U1 <- U; U1["U7"] <- 1; sid1 <- spec_id(model, U1)
          if (is.null(u71_cache[[sid1]])) {
            f71 <- fit_model(dat, model_terms(model, 1, U["U8"]), 1)
            b71 <- if (!is.null(f71$vcov)) cluster_vcov(f71, dat$game_id) else NULL
            u71_cache[[sid1]] <- list(fit = f71, bench = b71)
            log_msg("  (U7=1 counterpart %s fitted for U9a: ll=%.4f)", sid1, f71$loglik)
          }
          fit71 <- u71_cache[[sid1]]$fit; bench71 <- u71_cache[[sid1]]$bench
        }
      }
      mr <- margins_for_fit(fit, dat, model, TIME_MIN, variants = variants, fit_u71 = fit71,
                            V_bench = if (!is.null(bench)) bench$vcov else NULL, V_bench_u71 = if (!is.null(bench71)) bench71$vcov else NULL)
      if (!is.null(mr)) acc_add("margins", cbind(spec_id = sid, step = step, model = model, mr, stringsAsFactors = FALSE))
    }
  }
  tr <- cell_tests(fits, sids)
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
  t0 <- Sys.time(); fnull <- re_fit(Xnull, dat$y, dat$team, Q = 12); log_msg("N1 null (random intercept only): ll=%.4f (%.0fs)", fnull$loglik, as.numeric(Sys.time() - t0, units = "secs"))
  for (model in c("M1", "M2", "M3")) {
    terms <- model_terms(model, U7 = 0); sid <- spec_id(model, ORIGIN_U)
    X <- cbind("(Intercept)" = 1, as.matrix(dat[, terms]))
    t0 <- Sys.time()
    fre <- tryCatch(re_fit(X, dat$y, dat$team, Q = 12), error = function(e) NULL)
    if (is.null(fre)) { acc_add("nonequiv", to_long(run_id, "spec", data.frame(spec_id = sid, model = model, status = "failed", error = "re_fit error", stringsAsFactors = FALSE))); next }
    log_msg("N1 %s: ll=%.4f sigma_u=%.4f conv=%s (%.0fs)", model, fre$loglik, fre$sigma_u, fre$converged, as.numeric(Sys.time() - t0, units = "secs"))
    fits[[model]] <- fre
    sp <- data.frame(spec_id = sid, model = model, sample_hash = origin_hash, status = if (fre$converged) "ok" else "not_converged", error = "",
                     n_obs = fre$n_obs, n_groups_used = fre$n_groups, n_groups_dropped = 0, loglik = fre$loglik, null_loglik = fnull$loglik,
                     null_label = "random intercept only (intercept + normal team effect, no regressors)", lr_chi2 = 2 * (fre$loglik - fnull$loglik),
                     df = length(terms), converged = fre$converged, iterations = fre$iter, routine = fre$routine, stringsAsFactors = FALSE)
    acc_add("nonequiv", to_long(run_id, "spec", sp))
    se <- sqrt(diag(fre$vcov)); b <- fre$theta
    cr <- data.frame(spec_id = sid, model = model, term = names(b), estimate = as.numeric(b), se_native = as.numeric(se), z_native = as.numeric(b / se),
                     p_native = 2 * pnorm(-abs(as.numeric(b / se))), or = exp(as.numeric(b)), or_se = exp(as.numeric(b)) * as.numeric(se), stringsAsFactors = FALSE)
    sig <- fre$sigma_u; sig_se <- fre$sigma_u_se
    rho <- sig^2 / (sig^2 + pi^2 / 3); rho_se <- abs(2 * sig * (pi^2 / 3) / (sig^2 + pi^2 / 3)^2) * sig_se
    cr <- rbind(cr, data.frame(spec_id = sid, model = model, term = c("sigma_u", "rho"), estimate = c(sig, rho), se_native = c(sig_se, rho_se),
                               z_native = NA, p_native = NA, or = NA, or_se = NA, stringsAsFactors = FALSE))
    acc_add("nonequiv", to_long(run_id, "coef", cr))
    if (model %in% c("M2", "M3")) {
      mr <- margins_for_fit(re_as_fit(fre, terms), dat, model, TIME_MIN, variants = "ME0")
      acc_add("nonequiv", to_long(run_id, "margin", cbind(spec_id = sid, model = model, mr, stringsAsFactors = FALSE)))
    }
  }
  # tests
  ff <- lapply(fits, function(f) list(loglik = f$loglik, df_model = f$p - 1, coef = f$theta, vcov = f$vcov))
  tr <- cell_tests(ff, list(M1 = spec_id("M1", ORIGIN_U), M2 = spec_id("M2", ORIGIN_U), M3 = spec_id("M3", ORIGIN_U)))
  if (!is.null(tr)) acc_add("nonequiv", to_long(run_id, "test", tr))
}

run_N2 <- function(dat, origin_hash) {
  run_id <- "N2"; fits <- list(); sids <- list()
  for (model in c("M1", "M2", "M3")) {
    terms <- model_terms(model, U7 = 0, time = TIME_QTR); sid <- spec_id(model, ORIGIN_U); sids[[model]] <- sid
    t0 <- Sys.time(); fit <- fit_model(dat, terms, 0); fits[[model]] <- fit
    log_msg("N2 %s: ll=%.4f status=%s (%.0fs)", model, fit$loglik, fit$status, as.numeric(Sys.time() - t0, units = "secs"))
    sp <- spec_row(fit, sid, 4, model, ORIGIN_U, if (model != "M1") "ME0,U9a,U9b,U10a,N3" else "", origin_hash); sp$step <- NULL
    acc_add("nonequiv", to_long(run_id, "spec", sp))
    acc_add("nonequiv", to_long(run_id, "coef", cbind(spec_id = sid, model = model, coef_rows(fit), stringsAsFactors = FALSE)))
    if (model %in% c("M2", "M3") && !is.null(fit$vcov)) {
      f71 <- fit_model(dat, model_terms(model, 1, time = TIME_QTR), 1)
      b71 <- if (!is.null(f71$vcov)) cluster_vcov(f71, dat$game_id) else NULL
      mr <- margins_for_fit(fit, dat, model, TIME_QTR, variants = c("ME0", "U9a", "U9b", "U10a", "N3"), fit_u71 = f71, time_grid = c(4, 3, 2, 1),
                            V_bench_u71 = if (!is.null(b71)) b71$vcov else NULL)
      acc_add("nonequiv", to_long(run_id, "margin", cbind(spec_id = sid, model = model, mr, stringsAsFactors = FALSE)))
    }
  }
  tr <- cell_tests(fits, sids)
  if (!is.null(tr)) acc_add("nonequiv", to_long(run_id, "test", tr))
}

run_N4 <- function(dat, origin_hash) {
  run_id <- "N4"
  for (model in c("M1", "M2", "M3")) {
    terms <- model_terms(model, U7 = 1); U <- ORIGIN_U; U["U7"] <- 1; sid <- spec_id(model, U)
    fit <- fit_model(dat, terms, 1)
    bt <- if (!is.null(fit$vcov)) cluster_vcov(fit, dat$team) else NULL
    log_msg("N4 %s: ll=%.4f clusters(team)=%s", model, fit$loglik, if (is.null(bt)) NA else bt$n_clusters)
    sp <- spec_row(fit, sid, 4, model, U, if (model != "M1") "ME0" else "", origin_hash); sp$step <- NULL
    sp$routine <- paste0(sp$routine, "; benchmark columns: CR1 sandwich clustered by team (posteam)")
    acc_add("nonequiv", to_long(run_id, "spec", sp))
    acc_add("nonequiv", to_long(run_id, "coef", cbind(spec_id = sid, model = model, coef_rows(fit, if (!is.null(bt)) bt$vcov else NULL, if (!is.null(bt)) bt$n_clusters else NA), stringsAsFactors = FALSE)))
    if (model %in% c("M2", "M3") && !is.null(fit$vcov)) {
      mr <- margins_for_fit(fit, dat, model, TIME_MIN, variants = "ME0", V_bench = if (!is.null(bt)) bt$vcov else NULL)
      acc_add("nonequiv", to_long(run_id, "margin", cbind(spec_id = sid, model = model, mr, stringsAsFactors = FALSE)))
    }
  }
}

run_algebraic <- function(dat, origin_fits, origin_hash) {
  # K1
  terms <- model_terms("M3", U7 = 0, time = TIME_ELAPSED); sid <- spec_id("M3", ORIGIN_U)
  fk1 <- fit_model(dat, terms, 0)
  d1 <- fk1$loglik - origin_fits$M3$loglik
  log_msg("K1: LL(elapsed) - LL(origin M3) = %.3e", d1)
  sp <- spec_row(fk1, sid, 5, "M3", ORIGIN_U, "", origin_hash); sp$step <- NULL
  acc_add("algebraic", to_long("K1", "spec", sp))
  acc_add("algebraic", to_long("K1", "coef", cbind(spec_id = sid, model = "M3", coef_rows(fk1), stringsAsFactors = FALSE)))
  acc_add("algebraic", to_long("K1", "check", data.frame(spec_id = sid, model = "M3", test = "K1_loglik_elapsed_minus_origin_M3", statistic = d1, df = NA, p = NA,
                                                          term = "loglik_difference", estimate = d1, stringsAsFactors = FALSE)))
  # K2
  terms <- model_terms("M2", U7 = 0, home_var = "home_field_complement"); sid <- spec_id("M2", ORIGIN_U)
  fk2 <- fit_model(dat, terms, 0)
  d2 <- fk2$loglik - origin_fits$M2$loglik
  log_msg("K2: LL(1-home_field) - LL(origin M2) = %.3e; coef origin %.6f complement %.6f", d2, origin_fits$M2$coef["home_field"], fk2$coef["home_field_complement"])
  sp <- spec_row(fk2, sid, 5, "M2", ORIGIN_U, "", origin_hash); sp$step <- NULL
  acc_add("algebraic", to_long("K2", "spec", sp))
  acc_add("algebraic", to_long("K2", "coef", cbind(spec_id = sid, model = "M2", coef_rows(fk2), stringsAsFactors = FALSE)))
  acc_add("algebraic", to_long("K2", "check", data.frame(spec_id = sid, model = "M2",
                                                          test = c("K2_loglik_complement_minus_origin_M2", "K2_coef_home_field_origin", "K2_coef_home_field_complement", "K2_coef_sum"),
                                                          statistic = c(d2, origin_fits$M2$coef["home_field"], fk2$coef["home_field_complement"], origin_fits$M2$coef["home_field"] + fk2$coef["home_field_complement"]),
                                                          df = NA, p = NA, term = c("loglik_difference", "home_field (origin M2)", "home_field_complement (K2 M2)", "sum of the two coefficients"),
                                                          estimate = c(d2, origin_fits$M2$coef["home_field"], fk2$coef["home_field_complement"], origin_fits$M2$coef["home_field"] + fk2$coef["home_field_complement"]),
                                                          stringsAsFactors = FALSE)))
}

# ---- influence deletions -----------------------------------------------------

influence_one <- function(unit_type, unit_id, dat, origin_fits, origin_fits71) {
  sub <- switch(unit_type, team = dat[dat$team != unit_id, ], season = dat[dat$season != as.integer(unit_id), ], game = dat[dat$game_id != unit_id, ])
  rows <- list()
  for (model in c("M2", "M3")) {
    terms <- model_terms(model, U7 = 0)
    rec <- if (model == "M2") PERF_TERMS else c(PERF_TERMS, TIME_MIN$inter)
    f0 <- tryCatch(fit_model(sub, terms, 0, start = origin_fits[[model]]$coef, info0 = origin_fits[[model]]$info), error = function(e) NULL)
    f1 <- tryCatch(fit_model(sub, model_terms(model, U7 = 1), 1, start = origin_fits71[[model]]$coef), error = function(e) NULL)
    b1 <- if (!is.null(f1) && !is.null(f1$vcov)) tryCatch(cluster_vcov(f1, sub$game_id), error = function(e) NULL) else NULL
    st <- if (is.null(f0)) "failed" else f0$status
    err <- if (is.null(f0)) "fit error" else f0$error
    if (is.null(f1) || f1$status != "ok") err <- paste(err, sprintf("U7=1 fit: %s", if (is.null(f1)) "error" else paste(f1$status, f1$error)), sep = "; ")
    for (tm in rec) {
      est <- if (!is.null(f0)) f0$coef[tm] else NA; se <- if (!is.null(f0) && !is.null(f0$vcov)) sqrt(f0$vcov[tm, tm]) else NA
      seb <- if (!is.null(b1)) sqrt(b1$vcov[tm, tm]) else NA
      eb <- if (!is.null(f1)) f1$coef[tm] else NA
      rows[[length(rows) + 1]] <- data.frame(unit_type = unit_type, unit_id = as.character(unit_id), model = model, term = tm, estimate = as.numeric(est),
                                             se_native = as.numeric(se), p_native = 2 * pnorm(-abs(as.numeric(est / se))),
                                             se_bench = as.numeric(seb), p_bench = 2 * pnorm(-abs(as.numeric(eb / seb))),
                                             n_obs = nrow(sub), status = st, error = sub("^; ", "", err), stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}

INFL <- new.env()   # shared objects for the influence workers (exported to cluster workers)

influence_worker <- function(id) {
  tryCatch(influence_one(INFL$ut, id, INFL$dat, INFL$origin_fits, INFL$origin_fits71),
           error = function(e) data.frame(unit_type = INFL$ut, unit_id = as.character(id), model = NA, term = NA, estimate = NA, se_native = NA, p_native = NA,
                                          se_bench = NA, p_bench = NA, n_obs = NA, status = "failed", error = conditionMessage(e), stringsAsFactors = FALSE))
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
    }, error = function(e) { log_msg("could not start a cluster (%s); running serially", conditionMessage(e)); NULL })
    if (!is.null(cl)) on.exit(parallel::stopCluster(cl), add = TRUE)
  }
  for (ut in names(units)) {
    ids <- units[[ut]]
    INFL$ut <- ut
    log_msg("influence: unit %s, %d deletions (%s)", ut, length(ids), if (is.null(cl)) "serial" else sprintf("%d socket workers", cores))
    t0 <- Sys.time()
    if (!is.null(cl)) {
      parallel::clusterExport(cl, "INFL", envir = globalenv())
      res <- parallel::parLapplyLB(cl, ids, influence_worker)
    } else {
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
    fits <- tryCatch(fit_cell(cl$U, cl$step, store, u71_cache, seen),
                     error = function(e) { log_msg("CELL ERROR %s: %s", paste(cl$U, collapse = ""), conditionMessage(e)); NULL })
    if (cl$step == 1) origin_fits <- fits
    if (i %% 20 == 0 || cl$step <= 2) acc_write(results_dir)
  }
  acc_write(results_dir)
  write_flows(store, results_dir)
  s0 <- store$get(ORIGIN_U); dat <- s0$data
  NOTES$add(sprintf("Origin sample: %d rows; same_division vs games.div_game disagreements: %d.", nrow(dat), s0$n_disagree))
  if (!is.null(origin_fits)) NOTES$add(sprintf("Origin U7=0 fits: groups dropped for no variation in y: M1 %d, M2 %d, M3 %d.", origin_fits$M1$n_groups_dropped, origin_fits$M2$n_groups_dropped, origin_fits$M3$n_groups_dropped))
  # step 4
  log_msg("step 4: non-equivalent runs")
  tryCatch(run_N1(dat, s0$hash), error = function(e) { log_msg("N1 ERROR: %s", conditionMessage(e)); NOTES$add(paste("N1 failed:", conditionMessage(e))) })
  acc_write(results_dir)
  tryCatch(run_N2(dat, s0$hash), error = function(e) { log_msg("N2 ERROR: %s", conditionMessage(e)); NOTES$add(paste("N2 failed:", conditionMessage(e))) })
  tryCatch(run_N4(dat, s0$hash), error = function(e) { log_msg("N4 ERROR: %s", conditionMessage(e)); NOTES$add(paste("N4 failed:", conditionMessage(e))) })
  acc_write(results_dir)
  # step 5
  log_msg("step 5: algebraic checks")
  tryCatch(run_algebraic(dat, origin_fits, s0$hash), error = function(e) { log_msg("K ERROR: %s", conditionMessage(e)); NOTES$add(paste("Algebraic checks failed:", conditionMessage(e))) })
  acc_write(results_dir)
  # step 6
  log_msg("step 6: influence deletions")
  U1 <- ORIGIN_U; U1["U7"] <- 1
  origin_fits71 <- list(M2 = u71_cache[[spec_id("M2", U1)]]$fit, M3 = u71_cache[[spec_id("M3", U1)]]$fit)
  tryCatch(run_influence(dat, origin_fits, origin_fits71, cores, results_dir, code_dir), error = function(e) { log_msg("INFLUENCE ERROR: %s", conditionMessage(e)); NOTES$add(paste("Influence failed:", conditionMessage(e))) })
  acc_write(results_dir)
  NOTES$add("Influence refits were warm-started from the full-sample (origin) estimates of the same model: U7=0 refits start at the origin coefficients and use the origin information matrix for the Newton direction (score-only iterations) until max|score| < 1e-7, after which the exact information at the solution gives the covariance (verified on synthetic data to give the same estimates and SEs as a cold fit to 1e-13); U7=1 refits pass the origin coefficients as glm starting values. Convergence criteria are unchanged.")
  inf <- if (length(ACC$influence)) rbind_fill(ACC$influence) else NULL
  if (!is.null(inf)) NOTES$add(sprintf("Influence deletions run: team %d, season %d, game %d units; rows with status != ok: %d.",
                                       length(unique(inf$unit_id[inf$unit_type == "team"])), length(unique(inf$unit_id[inf$unit_type == "season"])),
                                       length(unique(inf$unit_id[inf$unit_type == "game"])), sum(inf$status != "ok", na.rm = TRUE)))
  invisible(TRUE)
}
