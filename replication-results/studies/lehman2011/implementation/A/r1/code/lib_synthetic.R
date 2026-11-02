# Synthetic checks (manifest section 10; assignment stage "synthetic")

gen_synthetic <- function(seed = 20261027, n_per_ts = 115, sigma_team = 0.5, beta = NULL) {
  set.seed(seed)
  teams <- sprintf("T%02d", 1:32); seasons <- 2000:2005
  N <- 32 * 6 * n_per_ts
  d <- data.frame(team = rep(rep(teams, each = n_per_ts), 6), season = rep(seasons, each = 32 * n_per_ts), stringsAsFactors = FALSE)
  d$game_id <- paste0(d$season, "_", sprintf("%02d", sample(1:17, N, TRUE)), "_", d$team)
  d$play_id <- seq_len(N)
  d$total_points <- rpois(N, 12)
  d$yards_first_down <- sample(1:20, N, TRUE, prob = 1 / (1:20))
  d$yards_touchdown <- sample(1:99, N, TRUE)
  d$same_division <- rbinom(N, 1, 0.4)
  d$same_conference <- pmax(d$same_division, rbinom(N, 1, 0.5))
  d$home_field <- rbinom(N, 1, 0.5)
  d$week <- as.numeric(sample(1:17, N, TRUE))
  d$minutes <- runif(N, 2, 60)
  d$d <- round(rnorm(N, 0, 11)) - 1
  d$perf_below <- pmin(d$d, 0); d$perf_below_sq <- d$perf_below^2; d$perf_above <- pmax(d$d, 0)
  d$below_indicator <- as.numeric(d$d <= 0)
  d$perf_below_x_min <- d$perf_below * d$minutes; d$perf_below_sq_x_min <- d$perf_below_sq * d$minutes; d$perf_above_x_min <- d$perf_above * d$minutes
  for (s in 2001:2005) d[[paste0("season_", s)]] <- as.numeric(d$season == s)
  d$team_season <- paste(d$team, d$season, sep = "_")
  terms <- model_terms("M3", U7 = 0)
  if (is.null(beta)) {
    beta <- c(total_points = 0.02, yards_first_down = -0.15, yards_touchdown = -0.01, same_division = 0.1, same_conference = -0.1,
              home_field = 0.15, week = 0.01, minutes = -0.02, perf_below = -0.04, perf_below_sq = 0.001, perf_above = 0.03,
              below_indicator = 0.3, perf_below_x_min = 0.0005, perf_below_sq_x_min = -0.00002, perf_above_x_min = -0.0005,
              season_2001 = 0.1, season_2002 = -0.1, season_2003 = 0.2, season_2004 = 0.05, season_2005 = -0.15)
  }
  beta <- beta[terms]
  alpha <- rnorm(32, 0, sigma_team); names(alpha) <- teams
  intercept <- -0.8
  eta <- intercept + alpha[d$team] + as.vector(as.matrix(d[, terms]) %*% beta)
  d$y <- rbinom(N, 1, plogis(eta))
  list(data = d, beta = beta, alpha = alpha, intercept = intercept, sigma_team = sigma_team, terms = terms)
}

fmt <- function(x, digits = 6) ifelse(is.na(x), "NA", formatC(x, digits = digits, format = "g"))

md_table <- function(df, digits = 6) {
  cols <- names(df)
  fmtcol <- function(v) if (is.numeric(v)) fmt(v, digits) else as.character(v)
  body <- do.call(cbind, lapply(df, fmtcol))
  if (is.null(dim(body))) body <- matrix(body, nrow = 1)
  c(paste0("| ", paste(cols, collapse = " | "), " |"), paste0("|", paste(rep("---", length(cols)), collapse = "|"), "|"),
    apply(body, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}

run_synthetic_checks <- function(out_file) {
  md <- c("# Synthetic checks", "", sprintf("Generated %s by code/run_all.R --stage synthetic.", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")), "")
  status <- list()
  # ---------------------------------------------------------------- 1. exact conditional likelihood vs enumeration
  set.seed(11)
  G <- 4; n <- c(6, 9, 11, 7); p <- 3; g <- rep(1:G, n); N <- sum(n)
  X <- matrix(rnorm(N * p), N, p); colnames(X) <- paste0("x", 1:p)
  y <- rbinom(N, 1, plogis(X %*% c(0.5, -1, 0.3) + rep(rnorm(G), n)))
  while (any(tapply(y, g, sum) == 0) || any(tapply(y, g, sum) == tapply(y, g, length))) y <- rbinom(N, 1, plogis(X %*% c(0.5, -1, 0.3)))
  b <- c(0.4, -0.8, 0.2)
  D <- cl_prepare(X, y, g); ev <- cl_eval(b, D, "info")
  ll_enum <- cl_enum_loglik(b, X, y, g)
  h <- 1e-5
  ng <- sapply(1:p, function(k) { e <- rep(0, p); e[k] <- h; (cl_enum_loglik(b + e, X, y, g) - cl_enum_loglik(b - e, X, y, g)) / (2 * h) })
  nh <- matrix(0, p, p)
  for (k in 1:p) for (l in 1:p) { ek <- rep(0, p); ek[k] <- h; el <- rep(0, p); el[l] <- h
    nh[k, l] <- (cl_enum_loglik(b + ek + el, X, y, g) - cl_enum_loglik(b + ek - el, X, y, g) - cl_enum_loglik(b - ek + el, X, y, g) + cl_enum_loglik(b - ek - el, X, y, g)) / (4 * h^2) }
  fit <- cl_fit(X, y, g)
  opt <- optim(rep(0, p), function(bb) -cl_enum_loglik(bb, X, y, g), method = "BFGS", control = list(reltol = 1e-14))
  cf <- survival::clogit(y ~ x1 + x2 + x3 + strata(g), data = data.frame(X, y = y, g = g), method = "exact")
  null_enum <- -sum(lchoose(n, tapply(y, g, sum)))
  ll_zero <- cl_eval(rep(0, p), D, "ll")$ll
  c1 <- c(abs(ev$ll - ll_enum) < 1e-9, max(abs(ev$score - ng)) < 1e-5, max(abs(ev$info + nh)) < 1e-3,
          max(abs(fit$coef - opt$par)) < 1e-4, max(abs(fit$coef - coef(cf))) < 1e-6, abs(fit$loglik - cf$loglik[2]) < 1e-8,
          max(abs(sqrt(diag(fit$vcov)) - sqrt(diag(vcov(cf))))) < 1e-6, abs(fit$null_loglik - null_enum) < 1e-9, abs(ll_zero - null_enum) < 1e-9)
  status$enum <- all(c1)
  md <- c(md, "## 1. Exact conditional likelihood: small case against direct enumeration", "",
          sprintf("Four strata of sizes %s with %s events; p = 3; direct enumeration sums over all C(n_g, d_g) subsets (%d terms in total).",
                  paste(n, collapse = ", "), paste(tapply(y, g, sum), collapse = ", "), sum(choose(n, tapply(y, g, sum)))), "",
          md_table(data.frame(check = c("log-likelihood at test beta: recursion vs enumeration (abs diff)",
                                        "score vs central-difference gradient of enumeration LL (max abs diff)",
                                        "observed information vs numerical Hessian of enumeration LL (max abs diff)",
                                        "MLE: cl_fit vs optim on enumeration LL (max abs diff)",
                                        "MLE: cl_fit vs survival::clogit(method='exact') (max abs diff)",
                                        "maximised LL: cl_fit vs survival::clogit (abs diff)",
                                        "native SE: cl_fit vs survival::clogit (max abs diff)",
                                        "null conditional LL: -sum log C(n,d) vs analytic (abs diff)",
                                        "LL at beta = 0 vs -sum log C(n,d) (abs diff)"),
                              value = c(abs(ev$ll - ll_enum), max(abs(ev$score - ng)), max(abs(ev$info + nh)), max(abs(fit$coef - opt$par)),
                                        max(abs(fit$coef - coef(cf))), abs(fit$loglik - cf$loglik[2]), max(abs(sqrt(diag(fit$vcov)) - sqrt(diag(vcov(cf))))),
                                        abs(fit$null_loglik - null_enum), abs(ll_zero - null_enum)),
                              pass = c1), 4),
          "", sprintf("Result: %s", if (status$enum) "PASS" else "FAIL"), "")
  # medium case vs survival
  set.seed(12)
  G <- 32; n_g <- 120; p <- 6; N <- G * n_g; g <- rep(1:G, each = n_g)
  X <- matrix(rnorm(N * p), N, p); colnames(X) <- paste0("x", 1:p)
  bt <- c(0.5, -0.3, 0.2, 0, 0.8, -0.1)
  y <- rbinom(N, 1, plogis(-1.5 + rnorm(G, 0, 0.7)[g] + X %*% bt))
  fit <- cl_fit(X, y, g)
  cf <- survival::coxph(survival::Surv(rep(1, N), y) ~ X + survival::strata(g), ties = "exact")
  c2 <- c(max(abs(fit$coef - coef(cf))) < 1e-6, abs(fit$loglik - cf$loglik[2]) < 1e-6, max(abs(sqrt(diag(fit$vcov)) / sqrt(diag(vcov(cf))) - 1)) < 1e-6)
  status$surv <- all(c2)
  md <- c(md, "## 2. Exact conditional likelihood: medium case against survival (exact partial likelihood)", "",
          sprintf("32 strata x 120 observations, p = 6 (survival::coxph(Surv(1, y) ~ X + strata(g), ties = 'exact'), the routine behind survival::clogit(method = 'exact'))."), "",
          md_table(data.frame(check = c("max abs coefficient difference", "abs LL difference", "max relative SE difference"),
                              value = c(max(abs(fit$coef - coef(cf))), abs(fit$loglik - cf$loglik[2]), max(abs(sqrt(diag(fit$vcov)) / sqrt(diag(vcov(cf))) - 1))), pass = c2), 4),
          "", sprintf("Result: %s", if (status$surv) "PASS" else "FAIL"), "")
  # ---------------------------------------------------------------- 3. recovery on synthetic data of the real structure
  syn <- gen_synthetic()
  dat <- syn$data; terms <- syn$terms
  f0 <- fit_model(dat, terms, U7 = 0)
  f1 <- fit_model(dat, terms, U7 = 1)
  f2 <- fit_model(dat, model_terms("M3", U7 = 2), U7 = 2)
  Xre <- cbind("(Intercept)" = 1, as.matrix(dat[, terms]))
  fre <- re_fit(Xre, dat$y, dat$team, Q = 12)
  truth <- syn$beta
  tab <- data.frame(term = terms, truth = as.numeric(truth),
                    est_U7_0 = as.numeric(f0$coef[terms]), se_U7_0 = sqrt(diag(f0$vcov))[terms],
                    est_U7_1 = as.numeric(f1$coef[terms]), se_U7_1 = sqrt(diag(f1$vcov))[terms],
                    est_U7_2 = as.numeric(f2$coef[intersect(terms, names(f2$coef))][match(terms, names(f2$coef))]),
                    est_N1 = as.numeric(fre$theta[terms]), se_N1 = sqrt(diag(fre$vcov))[terms], stringsAsFactors = FALSE)
  tab$se_U7_2 <- sqrt(diag(f2$vcov))[terms]
  tab$z_U7_0 <- (tab$est_U7_0 - tab$truth) / tab$se_U7_0
  tab$z_U7_1 <- (tab$est_U7_1 - tab$truth) / tab$se_U7_1
  tab$z_U7_2 <- (tab$est_U7_2 - tab$truth) / tab$se_U7_2
  tab$z_N1 <- (tab$est_N1 - tab$truth) / tab$se_N1
  zmax <- c(U7_0 = max(abs(tab$z_U7_0)), U7_1 = max(abs(tab$z_U7_1)), U7_2 = max(abs(tab$z_U7_2), na.rm = TRUE), N1 = max(abs(tab$z_N1)))
  sig_z <- (fre$sigma_u - syn$sigma_team) / fre$sigma_u_se
  alpha_hat <- c(0, f1$coef[paste0("team_", sprintf("T%02d", 2:32))]) + f1$coef["(Intercept)"]
  alpha_true <- syn$alpha + syn$intercept
  cor_alpha <- cor(alpha_hat, alpha_true)
  c3 <- c(all(zmax < 3.5), abs(sig_z) < 3.5, f0$converged, f1$converged, f2$converged, fre$converged, cor_alpha > 0.9)
  status$recover <- all(c3)
  md <- c(md, "## 3. Parameter recovery on synthetic data with the structure of the real sample", "",
          sprintf("N = %d plays, 32 teams x 6 seasons, M3 regressor list, team effects ~ N(0, %.2f^2), intercept %.2f. Event rate %.3f.",
                  nrow(dat), syn$sigma_team, syn$intercept, mean(dat$y)), "",
          "Estimates and native SEs by estimator (U7 = 0 exact conditional logit by team; U7 = 1 logit with team dummies; U7 = 2 exact conditional logit by team x season, no season dummies; N1 random-intercept logit, AGHQ 12 points). z = (estimate - truth)/SE.", "",
          md_table(tab[, c("term", "truth", "est_U7_0", "se_U7_0", "z_U7_0", "est_U7_1", "z_U7_1", "est_U7_2", "z_U7_2", "est_N1", "z_N1")], 4), "",
          md_table(data.frame(check = c("max |z| U7=0", "max |z| U7=1", "max |z| U7=2", "max |z| N1", "N1 sigma_u: estimate", "N1 sigma_u: truth", "N1 sigma_u z",
                                        "U7=0 converged", "U7=1 converged", "U7=2 converged", "N1 converged", "N1 max |analytic gradient| at optimum", "N1 max |numerical gradient| at optimum",
                                        "corr(U7=1 team effects, true team effects)",
                                        "U7=0 iterations", "N1 LL", "U7=1 LL (for reference)"),
                              value = c(zmax, fre$sigma_u, syn$sigma_team, sig_z, f0$converged, f1$converged, f2$converged, fre$converged, fre$max_grad, fre$max_grad_numeric, cor_alpha, f0$iter, fre$loglik, f1$loglik)), 4),
          "", sprintf("Criterion: every |z| < 3.5, all fits converged, team-effect correlation > 0.9. Result: %s", if (status$recover) "PASS" else "FAIL"), "")
  # ---------------------------------------------------------------- 4. marginal effects: delta-method gradient vs numerical derivatives
  bench <- cluster_vcov(f1, dat$game_id)
  f0m <- f0; f1m <- f1
  variants <- c("ME0", "U9a", "U9b", "U10a", "N3")
  mrows <- margins_for_fit(f0, dat, "M3", TIME_MIN, variants = variants, fit_u71 = f1, V_bench = NULL, time_grid = c(53, 8))
  eff_fun <- function(beta, which_fit, fit_u71) {
    ff <- which_fit; ff$coef <- beta
    margins_for_fit(ff, dat, "M3", TIME_MIN, variants = setdiff(variants, "U9a"), fit_u71 = NULL, time_grid = c(53, 8))$effect
  }
  # finite-difference steps scaled by the magnitude of each regressor (steps of fixed size are
  # far too coarse for regressors such as perf_below_sq_x_min, which reach 1e5)
  col_scales <- function(fit) { s <- setNames(rep(1, length(fit$coef)), names(fit$coef)); for (tm in fit$terms) s[tm] <- max(1, max(abs(dat[[tm]]))); s }
  num_jac <- function(fun, beta, s) sapply(seq_along(beta), function(k) { h <- 1e-6 / s[k]; e <- beta; e[k] <- e[k] + h; e2 <- beta; e2[k] <- e2[k] - h; (fun(e) - fun(e2)) / (2 * h) })
  base <- f0$coef; s0 <- col_scales(f0)
  Jn <- num_jac(function(b) eff_fun(b, f0), base, s0)
  sub <- mrows[mrows$variant != "U9a", ]
  se_num <- sqrt(rowSums((Jn %*% f0$vcov) * Jn))
  d_me <- max(abs(se_num / sub$se_native - 1))
  # U9a numerical check on the U7=1 fit
  u9 <- mrows[mrows$variant == "U9a", ]
  eff_u9 <- function(beta) { ff <- f1; ff$coef <- beta; margins_for_fit(f0, dat, "M3", TIME_MIN, variants = "U9a", fit_u71 = ff, time_grid = c(53, 8))$effect }
  b1 <- f1$coef; s1 <- col_scales(f1)
  Jn9 <- num_jac(eff_u9, b1, s1)
  se_num9 <- sqrt(rowSums((Jn9 %*% f1$vcov) * Jn9))
  d_u9 <- max(abs(se_num9 / u9$se_native - 1))
  # U7=1 ME0 with benchmark covariance
  m1 <- margins_for_fit(f1, dat, "M3", TIME_MIN, variants = "ME0", V_bench = bench$vcov, time_grid = c(53, 8))
  effb <- function(beta) { ff <- f1; ff$coef <- beta; margins_for_fit(ff, dat, "M3", TIME_MIN, variants = "ME0", time_grid = c(53, 8))$effect }
  Jb <- num_jac(effb, b1, s1)
  se_numb <- sqrt(rowSums((Jb %*% bench$vcov) * Jb))
  d_b <- max(abs(se_numb / m1$se_bench - 1))
  # finite-difference consistency: at a point, derivative vs (p(d+h)-p(d))/h
  c4 <- c(d_me < 1e-5, d_u9 < 1e-5, d_b < 1e-5)
  status$me <- all(c4)
  md <- c(md, "## 4. Marginal effects: delta-method SE against numerical derivatives", "",
          "For every marginal-effect row (variants ME0, U9b, U10a, N3 on the U7 = 0 fit; U9a and benchmark-covariance ME0 on the U7 = 1 fit; d grid x minutes in {53, 8}), the gradient of the effect with respect to the coefficients was recomputed by central differences and the delta-method SE compared with the analytic one.", "",
          md_table(data.frame(check = c("max relative SE difference, ME0/U9b/U10a/N3 (native covariance, U7=0 fit)",
                                        "max relative SE difference, U9a (native covariance, U7=1 fit)",
                                        "max relative SE difference, ME0 with benchmark (cluster-robust) covariance (U7=1 fit)",
                                        "number of marginal-effect rows checked"),
                              value = c(d_me, d_u9, d_b, nrow(sub) + nrow(u9) + nrow(m1)), pass = c(c4, TRUE)), 4),
          "", sprintf("Result: %s", if (status$me) "PASS" else "FAIL"), "")
  # ---------------------------------------------------------------- 5. sandwich against numerical derivatives
  ok <- !is.na(f1$coef); Xf <- f1$X[, ok]; yy <- f1$y; bb <- f1$coef[ok]
  lli <- function(b, i) { eta <- sum(Xf[i, ] * b); yy[i] * eta - log1pexp(eta) }
  ll_tot <- function(b) { eta <- as.vector(Xf %*% b); sum(yy * eta - log1pexp(eta)) }
  idx <- c(1, 500, 2000, 10000)
  sok <- s1[ok]
  sc_num <- sapply(idx, function(i) num_jac(function(b) lli(b, i), bb, sok))
  sc_an <- sapply(idx, function(i) Xf[i, ] * (yy[i] - f1$fitted[i]))
  d_sc <- max(abs(sc_num - sc_an) / pmax(1, abs(sc_an)))
  Hn <- matrix(0, length(bb), length(bb))
  gfun <- function(b) as.vector(crossprod(Xf, yy - plogis(as.vector(Xf %*% b))))
  for (k in seq_along(bb)) { h <- 1e-6 / sok[k]; e <- bb; e[k] <- e[k] + h; e2 <- bb; e2[k] <- e2[k] - h; Hn[, k] <- (gfun(e) - gfun(e2)) / (2 * h) }
  Hn <- (Hn + t(Hn)) / 2
  info_an <- solve(f1$vcov[ok, ok])
  d_bread <- norm(Hn + info_an, "F") / norm(info_an, "F")
  bread_num <- solve(-Hn)
  # brute-force CR1 with explicit loops
  cl <- factor(dat$game_id); Gc <- nlevels(cl); meat <- matrix(0, length(bb), length(bb))
  u <- Xf * (yy - f1$fitted)
  for (lev in levels(cl)) { s <- colSums(u[cl == lev, , drop = FALSE]); meat <- meat + tcrossprod(s) }
  Nn <- nrow(Xf); K <- length(bb)
  V_bf <- (Gc / (Gc - 1)) * ((Nn - 1) / (Nn - K)) * bread_num %*% meat %*% bread_num
  d_sw <- max(abs(sqrt(diag(V_bf)) / sqrt(diag(bench$vcov[ok, ok])) - 1))
  c5 <- c(d_sc < 1e-6, d_bread < 1e-6, d_sw < 1e-5, bench$n_clusters == Gc, bench$K == K)
  status$sw <- all(c5)
  md <- c(md, "## 5. Cluster-robust sandwich (CR1) against numerical derivatives", "",
          "On the U7 = 1 synthetic fit: per-observation scores vs central-difference gradients of the observation log-likelihood; bread vs the inverse of the numerically differentiated Hessian; the full CR1 sandwich (clustered by game_id) vs an explicit-loop computation using the numerical bread.", "",
          md_table(data.frame(check = c("max relative score difference (4 observations)", "relative Frobenius difference, numerical Hessian vs X'WX", "max relative SE difference, CR1 sandwich (explicit loops, numerical bread) vs cluster_vcov",
                                        "clusters (G)", "parameters K (incl. intercept and team dummies)"),
                              value = c(d_sc, d_bread, d_sw, bench$n_clusters, bench$K), pass = c5), 4),
          "", sprintf("Result: %s", if (status$sw) "PASS" else "FAIL"), "")
  # ---------------------------------------------------------------- 6. random-intercept: quadrature accuracy
  f20 <- re_fit(Xre, dat$y, dat$team, Q = 20, start = fre$theta)
  d_q <- max(abs(f20$theta - fre$theta))
  c6 <- abs(f20$loglik - fre$loglik) < 1e-3 && d_q < 1e-3
  status$re <- c6
  md <- c(md, "## 6. Random-intercept logit: quadrature sensitivity", "",
          md_table(data.frame(check = c("abs LL difference, 12 vs 20 adaptive points", "max abs parameter difference, 12 vs 20 points"),
                              value = c(abs(f20$loglik - fre$loglik), d_q), pass = c(abs(f20$loglik - fre$loglik) < 1e-3, d_q < 1e-3)), 4),
          "", sprintf("Result: %s", if (c6) "PASS" else "FAIL"), "")
  # ---------------------------------------------------------------- 7. hash
  hv <- tools::sha256sum(bytes = charToRaw("abc"))
  c7 <- hv == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  status$hash <- c7
  md <- c(md, "## 7. SHA-256 (tools::sha256sum) known test vector", "", sprintf("sha256('abc') = %s; expected ba7816bf...15ad. Result: %s", hv, if (c7) "PASS" else "FAIL"), "")
  # ---------------------------------------------------------------- 8. algebraic invariances on synthetic data
  dat$elapsed <- 60 - dat$minutes
  dat$perf_below_x_elapsed <- dat$perf_below * dat$elapsed; dat$perf_below_sq_x_elapsed <- dat$perf_below_sq * dat$elapsed; dat$perf_above_x_elapsed <- dat$perf_above * dat$elapsed
  fk1 <- fit_model(dat, model_terms("M3", U7 = 0, time = TIME_ELAPSED), U7 = 0)
  c8 <- abs(fk1$loglik - f0$loglik) < 1e-6
  status$k1 <- c8
  md <- c(md, "## 8. Algebraic invariance (K1 analogue) on synthetic data", "",
          sprintf("M3 with elapsed = 60 - minutes: LL difference from the minutes fit = %s (expected 0). Result: %s", fmt(fk1$loglik - f0$loglik, 4), if (c8) "PASS" else "FAIL"), "")
  overall <- all(unlist(status))
  md <- c(md, "## Summary", "", md_table(data.frame(check = names(status), pass = unlist(status))), "", sprintf("Overall: %s", if (overall) "ALL PASS" else "SOME CHECKS FAILED"))
  writeLines(md, out_file)
  invisible(status)
}
