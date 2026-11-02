# Model fitting (manifest section 3), covariance, tests and marginal effects (section 4)

BASE_TERMS <- c("total_points", "yards_first_down", "yards_touchdown", "same_division",
                "same_conference", "home_field", "week")
PERF_TERMS <- c("perf_below", "perf_below_sq", "perf_above", "below_indicator")
SEASON_TERMS <- paste0("season_", 2001:2005)

# time = list(main = "minutes", inter = c(below, below_sq, above interaction names))
TIME_MIN <- list(main = "minutes", inter = c("perf_below_x_min", "perf_below_sq_x_min", "perf_above_x_min"))
TIME_QTR <- list(main = "quarters_remaining", inter = c("perf_below_x_qtr", "perf_below_sq_x_qtr", "perf_above_x_qtr"))
TIME_ELAPSED <- list(main = "elapsed", inter = c("perf_below_x_elapsed", "perf_below_sq_x_elapsed", "perf_above_x_elapsed"))

model_terms <- function(model, U7 = 0, U8 = 0, time = TIME_MIN, home_var = "home_field") {
  base <- BASE_TERMS; base[base == "home_field"] <- home_var
  t <- c(base, time$main)
  if (model == "M1" && U8 == 1) t <- c(t, "below_indicator")
  if (model %in% c("M2", "M3")) t <- c(t, PERF_TERMS)
  if (model == "M3") t <- c(t, time$inter)
  if (U7 != 2) t <- c(t, SEASON_TERMS)
  t
}

spec_id <- function(model, U) sprintf("%s|U1=%d|U2=%d|U3=%d|U4=%d|U5=%d|U6=%d|U7=%d|U8=%d", model, U[1], U[2], U[3], U[4], U[5], U[6], U[7], U[8])

# ---- fitting -------------------------------------------------------------

# Returns a list with: coef, vcov (full, NA for aliased), loglik, null_loglik, null_label,
# n_obs, n_groups, n_groups_dropped, converged, iter, status, error, routine, df_model,
# terms (regressor names), est_rows (row indices of the estimation sample within dat),
# and for U7 = 1: X, y, groups (team), group_terms, cluster info
fit_model <- function(dat, terms, U7, start = NULL, info0 = NULL, group_var = "team") {
  y <- dat$y
  X <- as.matrix(dat[, terms, drop = FALSE]); storage.mode(X) <- "double"
  res <- tryCatch({
    if (U7 %in% c(0, 2)) {
      strata <- if (U7 == 0) dat[[group_var]] else dat$team_season
      f <- cl_fit(X, y, strata, start = if (!is.null(start)) start[terms] else NULL,
                  info0 = if (!is.null(info0) && !is.null(start)) info0[terms, terms] else NULL)
      list(coef = f$coef, vcov = f$vcov, info = f$info, loglik = f$loglik, null_loglik = f$null_loglik,
           null_label = if (U7 == 0) "conditional null (no regressors), same groups" else "conditional null (no regressors), same team x season groups",
           n_obs = f$n_obs, n_groups = f$n_groups, n_groups_dropped = f$n_groups_dropped,
           converged = f$converged, iter = f$iter, status = f$status, error = f$message,
           routine = f$routine, df_model = f$df, terms = terms, est_rows = f$keep_rows,
           U7 = U7, group_terms = character(0), max_score = f$max_score)
    } else {
      g <- factor(dat[[group_var]])
      lev <- levels(g)
      TD <- if (length(lev) > 1) { m <- model.matrix(~ g)[, -1, drop = FALSE]; colnames(m) <- paste0("team_", lev[-1]); m } else NULL
      Xf <- cbind("(Intercept)" = 1, X, TD)
      ctrl <- glm.control(epsilon = 1e-12, maxit = 200)
      st <- NULL
      if (!is.null(start)) { st <- rep(0, ncol(Xf)); names(st) <- colnames(Xf); cm <- intersect(names(start), names(st)); st[cm] <- start[cm]; st[is.na(st)] <- 0 }
      ww <- NULL
      gf <- withCallingHandlers(glm.fit(Xf, y, family = binomial(), control = ctrl, start = st, intercept = TRUE),
                                warning = function(w) { ww <<- c(ww, conditionMessage(w)); invokeRestart("muffleWarning") })
      coef <- gf$coefficients; names(coef) <- colnames(Xf)
      ok <- !is.na(coef)
      p <- gf$fitted.values; w <- p * (1 - p)
      info <- crossprod(Xf[, ok, drop = FALSE] * w, Xf[, ok, drop = FALSE])
      V <- matrix(NA_real_, ncol(Xf), ncol(Xf), dimnames = list(colnames(Xf), colnames(Xf)))
      V[ok, ok] <- solve(info)
      ll <- sum(y * log(p) + (1 - y) * log(1 - p))
      # null: intercept + team dummies
      X0 <- cbind(1, TD)
      g0 <- suppressWarnings(glm.fit(X0, y, family = binomial(), control = ctrl))
      p0 <- g0$fitted.values
      ll0 <- sum(y * log(p0) + (1 - y) * log(1 - p0))
      status <- if (gf$converged) "ok" else "not_converged"
      list(coef = coef, vcov = V, loglik = ll, null_loglik = ll0, null_label = "intercept and team dummies only",
           n_obs = length(y), n_groups = length(lev), n_groups_dropped = 0L,
           converged = gf$converged, iter = gf$iter, status = status, error = if (is.null(ww)) "" else paste(unique(ww), collapse = "; "),
           routine = "stats::glm.fit(family = binomial(link = logit), epsilon = 1e-12, maxit = 200), intercept + team dummies (first level omitted)",
           df_model = sum(ok[names(coef) %in% terms]), terms = terms, est_rows = seq_len(nrow(dat)),
           U7 = 1, group_terms = c("(Intercept)", colnames(TD)), X = Xf, y = y, fitted = p, team_levels = lev,
           max_score = max(abs(crossprod(Xf[, ok, drop = FALSE], y - p))))
    }
  }, error = function(e) list(coef = setNames(rep(NA_real_, length(terms)), terms), vcov = NULL, loglik = NA, null_loglik = NA,
                               null_label = "", n_obs = nrow(dat), n_groups = NA, n_groups_dropped = NA, converged = FALSE, iter = NA,
                               status = "failed", error = conditionMessage(e), routine = "", df_model = NA, terms = terms,
                               est_rows = integer(0), U7 = U7, group_terms = character(0)))
  res$lr_chi2 <- if (is.finite(res$loglik) && is.finite(res$null_loglik)) 2 * (res$loglik - res$null_loglik) else NA
  res
}

# cluster-robust sandwich (CR1) for a U7 = 1 fit
cluster_vcov <- function(fit, cluster) {
  ok <- !is.na(fit$coef)
  X <- fit$X[, ok, drop = FALSE]; y <- fit$y; p <- fit$fitted
  N <- nrow(X); K <- ncol(X)
  bread <- fit$vcov[ok, ok]
  u <- X * (y - p)
  cl <- as.integer(factor(cluster))
  G <- max(cl)
  U <- rowsum(u, cl)
  meat <- crossprod(U)
  V <- (G / (G - 1)) * ((N - 1) / (N - K)) * bread %*% meat %*% bread
  Vf <- matrix(NA_real_, length(fit$coef), length(fit$coef), dimnames = dimnames(fit$vcov))
  Vf[ok, ok] <- V
  list(vcov = Vf, n_clusters = G, K = K, N = N)
}

# ---- tests ---------------------------------------------------------------

wald_test <- function(coef, vcov, L, r = 0) {
  ok <- !is.na(coef)
  if (any(L[, !ok, drop = FALSE] != 0)) return(list(statistic = NA, df = NA, p = NA))
  b <- coef[ok]; V <- vcov[ok, ok]; L <- L[, ok, drop = FALSE]
  diff <- as.vector(L %*% b) - r
  S <- L %*% V %*% t(L)
  stat <- tryCatch(as.numeric(t(diff) %*% solve(S, diff)), error = function(e) NA)
  df <- nrow(L)
  list(statistic = stat, df = df, p = if (is.na(stat)) NA else pchisq(stat, df, lower.tail = FALSE))
}

lr_test <- function(fit_big, fit_small) {
  if (!is.finite(fit_big$loglik) || !is.finite(fit_small$loglik)) return(list(statistic = NA, df = NA, p = NA))
  stat <- 2 * (fit_big$loglik - fit_small$loglik)
  df <- fit_big$df_model - fit_small$df_model
  list(statistic = stat, df = df, p = pchisq(stat, df, lower.tail = FALSE))
}

# ---- marginal effects ----------------------------------------------------

D_GRID <- c(-42, -28, -14, 0, 14, 28, 42)
MIN_GRID <- c(53, 38, 23, 8)

# performance-term values and slope vector for d, time value m, given branch
perf_values <- function(d, m, branch, model, time) {
  v <- c(perf_below = 0, perf_below_sq = 0, perf_above = 0, below_indicator = 0)
  s <- v
  if (branch == "below") {
    v["perf_below"] <- d; v["perf_below_sq"] <- d^2; v["below_indicator"] <- 1
    s["perf_below"] <- 1; s["perf_below_sq"] <- 2 * d
  } else {
    v["perf_above"] <- d
    s["perf_above"] <- 1
  }
  if (model == "M3") {
    iv <- setNames(c(v["perf_below"] * m, v["perf_below_sq"] * m, v["perf_above"] * m), time$inter)
    is <- setNames(c(s["perf_below"] * m, s["perf_below_sq"] * m, s["perf_above"] * m), time$inter)
    v <- c(v, iv); s <- c(s, is)
  }
  list(values = v, slope = s)
}

# Build full covariate vector (named like coef) from means, with perf terms set
me_x <- function(xbar_full, model, d, m, branch, time, set_time = (model == "M3")) {
  x <- xbar_full
  pv <- perf_values(d, m, branch, model, time)
  x[names(pv$values)] <- pv$values
  if (set_time) x[time$main] <- m
  cvec <- xbar_full * 0; cvec[names(pv$slope)] <- pv$slope
  list(x = x, c = cvec)
}

# derivative ME and gradient wrt beta for covariate vector x and slope vector c
me_deriv <- function(beta, x, cvec) {
  ok <- !is.na(beta); b <- beta; b[!ok] <- 0
  xb <- sum(x * b); p <- plogis(xb); s <- sum(cvec * b)
  eff <- p * (1 - p) * s
  grad <- p * (1 - p) * (1 - 2 * p) * s * x + p * (1 - p) * cvec
  list(prob = p, effect = eff, grad = grad)
}

me_fd <- function(beta, x0, x1) {
  ok <- !is.na(beta); b <- beta; b[!ok] <- 0
  p0 <- plogis(sum(x0 * b)); p1 <- plogis(sum(x1 * b))
  list(prob = p0, effect = p1 - p0, grad = p1 * (1 - p1) * x1 - p0 * (1 - p0) * x0)
}

delta_se <- function(grad, V) {
  ok <- !is.na(diag(V))
  if (any(grad[!ok] != 0)) return(NA_real_)
  sqrt(as.numeric(t(grad[ok]) %*% V[ok, ok] %*% grad[ok]))
}

# Compute marginal-effect rows for a fit.
#   fit: fitted model (coef names), dat: data of the cell, model: M2/M3, time: time spec
#   variants: subset of c("ME0","U9a","U9b","U10a","N3"); fit_u71: U7 = 1 fit (for U9a)
#   V_bench: benchmark covariance (same names as fit$coef) or NULL
#   V_bench_u71: benchmark covariance of fit_u71 for the U9a rows; pass NULL unless the cell itself is a U7 = 1 fit
#   time_grid: evaluation values of the time variable for M3
#   Each row reports prob, effect, native SE, z = effect/SE and two-sided p (plus benchmark SE/p when a benchmark covariance is given)
margins_for_fit <- function(fit, dat, model, time = TIME_MIN, variants = "ME0", fit_u71 = NULL,
                            V_bench = NULL, time_grid = MIN_GRID, V_bench_u71 = NULL) {
  out <- list()
  if (is.null(fit$vcov) || all(is.na(fit$coef))) return(NULL)
  cn <- names(fit$coef)
  est <- dat[fit$est_rows, , drop = FALSE]
  xbar <- setNames(rep(0, length(cn)), cn)
  xbar[fit$terms] <- colMeans(as.matrix(est[, fit$terms, drop = FALSE]))   # group terms stay 0
  mgrid <- if (model == "M3") time_grid else xbar[time$main]
  beta <- fit$coef; V <- fit$vcov
  addrow <- function(variant, m, d, r, Vb = V_bench) {
    se <- delta_se(r$grad, V); z <- r$effect / se
    seb <- if (!is.null(Vb)) delta_se(r$grad, Vb) else NA_real_
    out[[length(out) + 1]] <<- data.frame(variant = variant, minutes_eval = m, d = d, prob = r$prob, effect = r$effect,
                                          se_native = se, z_native = z, p_native = 2 * pnorm(-abs(z)),
                                          se_bench = seb, p_bench = if (is.na(seb)) NA_real_ else 2 * pnorm(-abs(r$effect / seb)),
                                          stringsAsFactors = FALSE)
  }
  for (m in mgrid) for (d in D_GRID) {
    branch <- if (d <= 0) "below" else "above"
    if ("ME0" %in% variants) {
      mx <- me_x(xbar, model, d, m, branch, time)
      addrow("ME0", m, d, me_deriv(beta, mx$x, mx$c))
    }
    if ("U9b" %in% variants) {
      mx0 <- me_x(xbar, model, d, m, branch, time)
      mx1 <- me_x(xbar, model, d + 1, m, if (d + 1 <= 0) "below" else "above", time)
      addrow("U9b", m, d, me_fd(beta, mx0$x, mx1$x))
    }
    if ("U10a" %in% variants && d == 0) {
      mx <- me_x(xbar, model, d, m, "above", time)
      addrow("U10a", m, d, me_deriv(beta, mx$x, mx$c))
    }
    if ("N3" %in% variants) {
      Xo <- matrix(0, nrow(est), length(cn), dimnames = list(NULL, cn))
      Xo[, fit$terms] <- as.matrix(est[, fit$terms, drop = FALSE])
      pv <- perf_values(d, m, branch, model, time)
      Xo[, names(pv$values)] <- matrix(pv$values, nrow(est), length(pv$values), byrow = TRUE)
      if (model == "M3") Xo[, time$main] <- m
      cvec <- xbar * 0; cvec[names(pv$slope)] <- pv$slope
      b <- beta; b[is.na(b)] <- 0
      xb <- as.vector(Xo %*% b); p <- plogis(xb); s <- sum(cvec * b)
      eff <- p * (1 - p) * s
      grad <- colMeans(Xo * (p * (1 - p) * (1 - 2 * p) * s)) + mean(p * (1 - p)) * cvec
      addrow("N3", m, d, list(prob = mean(p), effect = mean(eff), grad = grad))
    }
    if ("U9a" %in% variants && !is.null(fit_u71) && !is.null(fit_u71$vcov)) {
      cn1 <- names(fit_u71$coef)
      est1 <- dat[fit_u71$est_rows, , drop = FALSE]
      xbar1 <- setNames(rep(0, length(cn1)), cn1)
      xbar1[fit_u71$terms] <- colMeans(as.matrix(est1[, fit_u71$terms, drop = FALSE]))
      mx <- me_x(xbar1, model, d, m, branch, time)
      lev <- fit_u71$team_levels
      acc_eff <- 0; acc_p <- 0; acc_grad <- xbar1 * 0
      for (j in seq_along(lev)) {
        xj <- mx$x; xj["(Intercept)"] <- 1
        if (j > 1) xj[paste0("team_", lev[j])] <- 1
        r <- me_deriv(fit_u71$coef, xj, mx$c)
        acc_eff <- acc_eff + r$effect; acc_p <- acc_p + r$prob; acc_grad <- acc_grad + r$grad
      }
      nL <- length(lev)
      r <- list(prob = acc_p / nL, effect = acc_eff / nL, grad = acc_grad / nL)
      se <- delta_se(r$grad, fit_u71$vcov); z <- r$effect / se
      seb <- if (!is.null(V_bench_u71)) delta_se(r$grad, V_bench_u71) else NA_real_
      out[[length(out) + 1]] <- data.frame(variant = "U9a", minutes_eval = m, d = d, prob = r$prob, effect = r$effect,
                                           se_native = se, z_native = z, p_native = 2 * pnorm(-abs(z)),
                                           se_bench = seb, p_bench = if (is.na(seb)) NA_real_ else 2 * pnorm(-abs(r$effect / seb)),
                                           stringsAsFactors = FALSE)
    }
  }
  if (length(out) == 0) return(NULL)
  do.call(rbind, out)
}

# ---- output row builders -------------------------------------------------

coef_rows <- function(fit, V_bench = NULL, n_clusters = NA) {
  if (is.null(fit$vcov)) {
    return(data.frame(term = fit$terms, estimate = NA_real_, se_native = NA_real_, z_native = NA_real_, p_native = NA_real_,
                      or = NA_real_, or_se = NA_real_, se_bench = NA_real_, p_bench = NA_real_, n_clusters_bench = NA, stringsAsFactors = FALSE))
  }
  b <- fit$coef; se <- sqrt(diag(fit$vcov)); z <- b / se
  seb <- if (!is.null(V_bench)) sqrt(diag(V_bench)) else rep(NA_real_, length(b))
  data.frame(term = names(b), estimate = as.numeric(b), se_native = as.numeric(se), z_native = as.numeric(z),
             p_native = 2 * pnorm(-abs(as.numeric(z))), or = exp(as.numeric(b)), or_se = exp(as.numeric(b)) * as.numeric(se),
             se_bench = as.numeric(seb), p_bench = 2 * pnorm(-abs(as.numeric(b) / as.numeric(seb))),
             n_clusters_bench = if (!is.null(V_bench)) n_clusters else NA, stringsAsFactors = FALSE)
}

spec_row <- function(fit, sid, step, model, U, me_variant_set, sample_hash, duplicate_of = "") {
  data.frame(spec_id = sid, step = step, model = model, U1 = U[1], U2 = U[2], U3 = U[3], U4 = U[4], U5 = U[5], U6 = U[6], U7 = U[7], U8 = U[8],
             me_variant_set = me_variant_set, sample_hash = sample_hash, status = fit$status, error = fit$error,
             n_obs = fit$n_obs, n_groups_used = fit$n_groups, n_groups_dropped = fit$n_groups_dropped,
             loglik = fit$loglik, null_loglik = fit$null_loglik, null_label = fit$null_label,
             lr_chi2 = fit$lr_chi2, df = fit$df_model, converged = fit$converged, iterations = fit$iter,
             routine = fit$routine, duplicate_of = duplicate_of, stringsAsFactors = FALSE)
}

cell_tests <- function(fits, sids) {
  rows <- list()
  add <- function(sid, test, r) rows[[length(rows) + 1]] <<- data.frame(spec_id = sid, test = test, statistic = r$statistic, df = r$df, p = r$p, stringsAsFactors = FALSE)
  if (!is.null(fits$M1) && !is.null(fits$M2)) add(sids$M2, "LR_M2_vs_M1", lr_test(fits$M2, fits$M1))
  if (!is.null(fits$M2) && !is.null(fits$M3)) add(sids$M3, "LR_M3_vs_M2", lr_test(fits$M3, fits$M2))
  if (!is.null(fits$M2) && !is.null(fits$M2$vcov)) {
    cn <- names(fits$M2$coef)
    L1 <- matrix(0, 1, length(cn), dimnames = list(NULL, cn)); L1[1, "perf_below"] <- 1; L1[1, "perf_above"] <- -1
    add(sids$M2, "Wald_perf_below_eq_perf_above", wald_test(fits$M2$coef, fits$M2$vcov, L1))
    L4 <- matrix(0, 4, length(cn), dimnames = list(NULL, cn)); for (i in 1:4) L4[i, PERF_TERMS[i]] <- 1
    add(sids$M2, "Wald_perf_terms_joint_zero", wald_test(fits$M2$coef, fits$M2$vcov, L4))
  }
  if (length(rows) == 0) return(NULL)
  do.call(rbind, rows)
}
