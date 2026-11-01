# test_synthetic.R -- tests of the estimation code on synthetic data with known parameters.
# Invoked by:  Rscript code/run.R test     (writes code/TESTS.md)

rmvn <- function(n, mu, Sigma) {
  L <- chol(Sigma)
  Z <- matrix(rnorm(n * length(mu)), n)
  sweep(Z %*% L, 2, mu, "+")
}

# ---- synthetic truth ---------------------------------------------------------------------------
synthetic_truth <- function() {
  f <- FACTORS_F4
  items <- unname(unlist(f))
  set.seed(20261028)
  lambda <- setNames(rep(1, length(items)), items)
  nu <- setNames(rep(0, length(items)), items)
  for (K in names(f)) {
    its <- f[[K]]
    lambda[its[-1]] <- round(runif(length(its) - 1, 0.7, 1.3), 2)
    nu[its[-1]] <- round(runif(length(its) - 1, -0.5, 0.5), 2)
  }
  # group-specific shifts for released intercepts (non-invariance)
  shift <- matrix(0, 3, length(items), dimnames = list(YEARS, items))
  shift["1991", RELEASED] <- c(0.3, -0.2, 0.25, -0.3, 0.2, -0.25)
  shift["2006", RELEASED] <- c(-0.2, 0.3, -0.15, 0.2, -0.3, 0.35)
  alpha <- matrix(c(0, 0, 0, 0, 0, 0, 0,
                    0.3, -0.2, 0.4, 0.1, -0.3, 0.2, 0.0,
                    -0.1, 0.5, 0.2, -0.4, 0.3, -0.2, 0.3), 3, 7, byrow = TRUE, dimnames = list(YEARS, names(f)))
  psi_var <- matrix(c(1, 1.1, 0.9, 1.2, 0.8, 1, 1,
                      1.3, 0.9, 1.1, 1.0, 1.2, 0.9, 1.1,
                      0.8, 1.2, 1.0, 0.9, 1.1, 1.2, 0.9), 3, 7, byrow = TRUE, dimnames = list(YEARS, names(f)))
  R <- matrix(0.3, 7, 7); diag(R) <- 1
  theta <- setNames(round(runif(length(items), 0.4, 0.8), 2), items)
  list(factors = f, items = items, lambda = lambda, nu = nu, shift = shift, alpha = alpha, psi_var = psi_var, R = R, theta = theta,
       n = c("1976" = 3000, "1991" = 2500, "2006" = 2000))
}

gen_f4 <- function(tr, y) {
  n <- tr$n[[y]]
  D <- diag(sqrt(tr$psi_var[y, ]))
  Psi <- D %*% tr$R %*% D
  eta <- rmvn(n, tr$alpha[y, ], Psi)
  colnames(eta) <- names(tr$factors)
  X <- matrix(0, n, length(tr$items), dimnames = list(NULL, tr$items))
  for (K in names(tr$factors)) for (it in tr$factors[[K]]) {
    X[, it] <- tr$nu[it] + tr$shift[y, it] + tr$lambda[it] * eta[, K] + rnorm(n, sd = sqrt(tr$theta[it]))
  }
  d <- data.table(V4 = seq_len(n) * 7L, V5 = round(runif(n, 0.3, 3), 4))
  for (it in tr$items) d[[it]] <- X[, it]
  d$w_valid <- TRUE
  d
}

gen_f3 <- function(y, n = 1500) {
  # C1: 5 indicators (marker V3224, loading 1, intercept 0), C2 single indicator V3226
  Psi <- matrix(c(1, 0.4, 0.4, 0.9), 2)
  eta <- rmvn(n, c(0.2, -0.1), Psi)
  lam <- c(V3224 = 1, V3225 = 0.8, V3222_r = 1.1, V3223_r = 0.9, V3227_r = 0.5)
  nu <- c(V3224 = 0, V3225 = 0.3, V3222_r = -0.2, V3223_r = 0.1, V3227_r = 0.4)
  d <- data.table(V4 = seq_len(n) * 3L, V5 = round(runif(n, 0.3, 3), 4))
  for (it in names(lam)) d[[it]] <- nu[it] + lam[it] * eta[, 1] + rnorm(n, sd = 0.7)
  d$V3226 <- eta[, 2]
  d$V3222 <- 6 - d$V3222_r; d$V3223 <- 6 - d$V3223_r; d$V3227 <- 3 - d$V3227_r
  d$w_valid <- TRUE
  d
}

make_synthetic_D <- function(tr) {
  D <- list()
  for (y in YEARS) {
    d4 <- gen_f4(tr, y)
    D[[key_for(y, "f4")]] <- list(key = key_for(y, "f4"), year = y, form = "f4", data = d4, rows_read = nrow(d4), n_invalid_weight = 0L,
                                  v5_declared_missing = list(values = 0, range = NULL))
    d3 <- gen_f3(y)
    D[[key_for(y, "f3")]] <- list(key = key_for(y, "f3"), year = y, form = "f3", data = d3, rows_read = nrow(d3), n_invalid_weight = 0L,
                                  v5_declared_missing = list(values = 0, range = NULL))
  }
  D
}

# ---- test harness ------------------------------------------------------------------------------
run_synthetic_tests <- function(root) {
  results <- list()
  check <- function(name, ok, detail = "") {
    detail <- if (is.null(detail) || !length(detail)) "" else paste(as.character(detail), collapse = " ")
    results[[length(results) + 1]] <<- list(name = name, ok = isTRUE(ok), detail = detail)
    message(sprintf("[%s] %s %s", if (isTRUE(ok)) "PASS" else "FAIL", name, detail))
  }
  fmt <- function(x, d = 6) formatC(x, digits = d, format = "g")
  tr <- synthetic_truth()
  set.seed(1)
  D <- make_synthetic_D(tr)
  spec <- SPEC_DEFS$S00; est <- est_options(spec)

  # --- T1: SHA-256 known value
  check("T1 SHA-256 of 'abc' equals the published digest",
        identical(unname(tools::sha256sum(bytes = charToRaw("abc"))), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"))

  # --- T2: full S00 on synthetic data
  t0 <- proc.time()[["elapsed"]]
  r <- run_spec("S00", D, root, write = FALSE)
  check("T2 S00 runs end to end on synthetic data (status ok)", r$status == "ok", r$reason)
  mg <- r$multigroup
  conv <- vapply(mg$models, function(m) m$convergence$converged, logical(1))
  check("T2b all five multigroup models converged", all(conv), paste(names(conv), conv, collapse = ", "))

  # --- T3: parameter recovery from M4 (true model); released intercept shifts are group specific
  PT <- mg$models$M4$parameters
  lam_est <- vapply(MODEL_ITEMS, function(it) { i <- which(PT$label == paste0("L_", it)); if (length(i)) PT$est[i[1]] else NA }, 0)
  lam_true <- tr$lambda[MODEL_ITEMS]
  dl <- abs(lam_est - lam_true); dl <- dl[!is.na(dl)]
  check("T3a M4 loadings recovered (max abs error < 0.05)", max(dl) < 0.05, paste("max abs error", fmt(max(dl))))
  al_est <- sapply(YEARS, function(y) sapply(names(MODEL_FACTORS), function(K) mg$latent$by_group[[K]][[y]]$alpha))
  al_true <- t(tr$alpha[, names(MODEL_FACTORS)])
  da <- abs(al_est - al_true)
  check("T3b M4 latent means recovered (max abs error < 0.06)", max(da) < 0.06, paste("max abs error", fmt(max(da))))
  al_se <- sapply(YEARS, function(y) sapply(names(MODEL_FACTORS), function(K) mg$latent$by_group[[K]][[y]]$se))
  zz <- da / al_se
  check("T3c latent-mean errors within 3.5 SE", max(zz) < 3.5, paste("max |error|/SE", fmt(max(zz))))
  ps_est <- sapply(YEARS, function(y) sapply(names(MODEL_FACTORS), function(K) mg$latent$by_group[[K]][[y]]$psi))
  ps_true <- t(tr$psi_var[, names(MODEL_FACTORS)])
  ps_se <- sapply(YEARS, function(y) sapply(names(MODEL_FACTORS), function(K) { i <- which(PT$label == paste0("P_", K, "_g", match(y, YEARS))); PT$se[i[1]] }))
  check("T3d M4 factor variances recovered (max rel error < 0.15 and all within 3.5 SE)", max(abs(ps_est / ps_true - 1)) < 0.15 && max(abs(ps_est - ps_true) / ps_se) < 3.5,
        paste("max rel error", fmt(max(abs(ps_est / ps_true - 1))), "max |error|/SE", fmt(max(abs(ps_est - ps_true) / ps_se))))
  rel_shift <- sapply(RELEASED, function(it) {
    e <- sapply(1:3, function(g) PT$est[which(PT$label == paste0("N_", it, "_g", g))[1]])
    (e[2] - e[1]) - (tr$shift["1991", it] - tr$shift["1976", it])
  })
  check("T3e released intercept group shifts recovered (1991-1976, max abs error < 0.08)", max(abs(rel_shift)) < 0.08, paste("max abs error", fmt(max(abs(rel_shift)))))
  nu_est <- vapply(setdiff(MODEL_ITEMS, c(RELEASED, MARKERS_F4[1:5])), function(it) PT$est[which(PT$label == paste0("N_", it))[1]], 0)
  check("T3f invariant intercepts recovered (max abs error < 0.06)", max(abs(nu_est - tr$nu[names(nu_est)])) < 0.06, paste("max abs error", fmt(max(abs(nu_est - tr$nu[names(nu_est)])))))

  # --- T4: chi-square consistency and fit indices vs lavaan
  for (M in c("M1", "M4")) {
    fi <- mg$models[[M]]$fit
    lv <- fi$lavaan_fitmeasures
    check(paste("T4a", M, "manifest chi-square equals lavaan chi-square (1e-6)"), abs(fi$chisq - lv$chisq) < 1e-6, paste(fmt(fi$chisq, 10), "vs", fmt(lv$chisq, 10)))
    check(paste("T4b", M, "df = G p(p+3)/2 - npar equals lavaan df"), fi$df == 3 * fi$sample_moments_per_group - fi$npar && fi$df == lv$df, paste("df", fi$df, "npar", fi$npar))
    check(paste("T4c", M, "closed-form baseline chi-square equals lavaan baseline (1e-6)"), abs(fi$baseline_chisq - lv$baseline.chisq) < 1e-6 && fi$baseline_df == lv$baseline.df,
          paste(fmt(fi$baseline_chisq, 10), "vs", fmt(lv$baseline.chisq, 10)))
    check(paste("T4d", M, "CFI/TLI/RMSEA equal lavaan (1e-8)"), abs(fi$cfi - lv$cfi) < 1e-8 && abs(fi$tli - lv$tli) < 1e-8 && abs(fi$rmsea - lv$rmsea) < 1e-8,
          sprintf("cfi %s/%s tli %s/%s rmsea %s/%s", fmt(fi$cfi), fmt(lv$cfi), fmt(fi$tli), fmt(lv$tli), fmt(fi$rmsea), fmt(lv$rmsea)))
  }
  fi <- mg$models$M4$fit
  check("T4e M4 (true model) chi-square not significant at 0.001", fi$pvalue > 0.001, paste("chisq", fmt(fi$chisq), "df", fi$df, "p", fmt(fi$pvalue)))
  d32 <- mg$differences[["M3-M2"]]; d42 <- mg$differences[["M4-M2"]]
  check("T4f M3-M2 rejects scalar invariance (p < 1e-6) while M4-M2 does not (p > 0.001)", d32$pvalue < 1e-6 && d42$pvalue > 0.001,
        sprintf("M3-M2 chisq %s df %d p %s ; M4-M2 chisq %s df %d p %s", fmt(d32$chisq_diff), d32$df_diff, fmt(d32$pvalue), fmt(d42$chisq_diff), d42$df_diff, fmt(d42$pvalue)))
  check("T4g df: M1 -> M2 adds 28 constraints, M2 -> M3 adds 28 - 6 (released) + ... as expected", mg$models$M2$fit$df - mg$models$M1$fit$df == 28 &&
          mg$models$M4$fit$df - mg$models$M2$fit$df == (19 - 5 - 6) * 2 && mg$models$M5$fit$df - mg$models$M4$fit$df == 10,
        sprintf("df M1..M5 = %s", paste(sapply(c("M1", "M2", "M3", "M4", "M5"), function(M) mg$models[[M]]$fit$df), collapse = ", ")))
  lv <- fi$lavaan_fitmeasures
  check("T4h M4 manifest SRMR (lower triangle incl. diagonal, n_g/N weights) matches a lavaan SRMR variant (informational, 1e-6)",
        any(abs(unlist(lv[grep("srmr", names(lv))]) - fi$srmr) < 1e-6),
        paste("manifest", fmt(fi$srmr, 8), "; lavaan:", paste(names(lv)[grep("srmr", names(lv))], fmt(unlist(lv[grep("srmr", names(lv))]), 8), collapse = ", ")))
  # --- T5: Delta contrasts recovered
  dd <- sapply(names(MODEL_FACTORS), function(K) sapply(names(PAIRS), function(P) {
    tdelta <- tr$alpha[PAIRS[[P]][2], K] - tr$alpha[PAIRS[[P]][1], K]
    abs(mg$latent$deltas[[K]][[P]]$delta - tdelta) / mg$latent$deltas[[K]][[P]]$se
  }))
  check("T5 all 15 latent mean differences within 3.5 SE of truth", max(dd) < 3.5, paste("max |error|/SE", fmt(max(dd))))
  # d_eq against truth
  deq_true <- sapply(names(MODEL_FACTORS), function(K) sapply(names(PAIRS), function(P) {
    a <- PAIRS[[P]][1]; b <- PAIRS[[P]][2]
    (tr$alpha[b, K] - tr$alpha[a, K]) / sqrt((tr$psi_var[a, K] + tr$psi_var[b, K]) / 2)
  }))
  deq_est <- sapply(names(MODEL_FACTORS), function(K) sapply(names(PAIRS), function(P) mg$contrasts$contrasts[[K]][[P]]$d_eq))
  check("T5b d_eq recovered (max abs error < 0.08)", max(abs(deq_est - deq_true)) < 0.08, paste("max abs error", fmt(max(abs(deq_est - deq_true)))))

  # --- T6: identification invariance: CHK1 and S05 (M3) reproduce S00 fit
  rc <- run_spec("CHK1", D, root, write = FALSE)
  c1 <- rc$multigroup$models$M4_CHK1$fit
  check("T6a CHK1 (fixed-factor) M4 chi-square and df equal marker M4", abs(c1$chisq - fi$chisq) < 1e-5 && c1$df == fi$df,
        paste(fmt(c1$chisq, 10), "vs", fmt(fi$chisq, 10), "; df", c1$df, "vs", fi$df, "; npar", c1$npar, "vs", fi$npar))
  deq_chk <- sapply(names(MODEL_FACTORS), function(K) sapply(names(PAIRS), function(P) rc$multigroup$contrasts$contrasts[[K]][[P]]$d_eq))
  p_chk <- sapply(names(MODEL_FACTORS), function(K) sapply(names(PAIRS), function(P) rc$multigroup$latent$deltas[[K]][[P]]$pvalue))
  p_s00 <- sapply(names(MODEL_FACTORS), function(K) sapply(names(PAIRS), function(P) mg$latent$deltas[[K]][[P]]$pvalue))
  check("T6b CHK1 d_eq equals S00 d_eq for all 15 contrasts (1e-5)", max(abs(deq_chk - deq_est)) < 1e-5, paste("max abs diff", fmt(max(abs(deq_chk - deq_est)))))
  check("T6c CHK1 Delta p-values equal S00 p-values (1e-5)", max(abs(p_chk - p_s00)) < 1e-5, paste("max abs diff", fmt(max(abs(p_chk - p_s00)))))
  r5 <- run_spec("S05", D, root, write = FALSE)
  check("T6d S05 effects-coded M3 chi-square equals marker M3 chi-square (1e-5)", abs(r5$multigroup$models$M3$fit$chisq - mg$models$M3$fit$chisq) < 1e-5 &&
          r5$multigroup$models$M3$fit$df == mg$models$M3$fit$df,
        paste(fmt(r5$multigroup$models$M3$fit$chisq, 10), "vs", fmt(mg$models$M3$fit$chisq, 10)))
  e5 <- r5$multigroup$models$M3$parameters
  lsum <- sapply(names(MODEL_FACTORS), function(K) sum(sapply(MODEL_FACTORS[[K]], function(it) e5$est[which(e5$label == paste0("L_", it))[1]])) / length(MODEL_FACTORS[[K]]))
  check("T6e S05 M3 loadings average 1 per factor", max(abs(lsum - 1)) < 1e-6, paste(fmt(lsum), collapse = " "))

  # --- T7: ML normalization (S02): manual = lavaan; chi-square ratio to Wishart
  r2 <- run_spec("S02", D, root, write = FALSE)
  f2 <- r2$multigroup$models$M4$fit
  check("T7a S02 manifest chi-square equals lavaan chi-square", abs(f2$chisq - f2$lavaan_fitmeasures$chisq) < 1e-6, paste(fmt(f2$chisq, 10), "vs", fmt(f2$lavaan_fitmeasures$chisq, 10)))
  check("T7b S02 chi-square / S00 chi-square close to N/(N-G)", abs(f2$chisq / fi$chisq - sum(tr$n) / (sum(tr$n) - 3)) < 0.002,
        paste("ratio", fmt(f2$chisq / fi$chisq), "N/(N-G)", fmt(sum(tr$n) / (sum(tr$n) - 3))))

  # --- T8: MLR (S06) and FIML (S04) run; FIML on complete data equals ML
  r6 <- run_spec("S06", D, root, write = FALSE)
  check("T8a S06 MLR M4 converged and ML chi-square equals S02 chi-square (same n normalization)", r6$multigroup$models$M4$convergence$converged &&
          abs(r6$multigroup$models$M4$fit$chisq - f2$chisq) < 1e-4, paste(fmt(r6$multigroup$models$M4$fit$chisq, 10), "vs", fmt(f2$chisq, 10)))
  check("T8b S06 reports scaled chi-square and robust SEs", !is.null(r6$multigroup$models$M4$fit_scaled$chisq.scaled) && !is.null(r6$multigroup$differences[["M3-M2"]]$scaled$pvalue_scaled),
        paste("scaled chisq", fmt(r6$multigroup$models$M4$fit_scaled$chisq.scaled)))
  r4 <- run_spec("S04", D, root, write = FALSE)
  check("T8c S04 FIML on complete synthetic data reproduces S02 chi-square (1e-3)", abs(r4$multigroup$models$M4$fit$chisq - f2$chisq) < 1e-3,
        paste(fmt(r4$multigroup$models$M4$fit$chisq, 10), "vs", fmt(f2$chisq, 10)))
  # FIML with MCAR holes: point estimates near truth
  D_miss <- D
  for (y in YEARS) { d <- data.table::copy(D_miss[[key_for(y, "f4")]]$data); for (it in MODEL_ITEMS) { i <- sample(nrow(d), round(0.1 * nrow(d))); d[[it]][i] <- NA }; D_miss[[key_for(y, "f4")]]$data <- d }
  r4m <- run_spec("S04", D_miss, root, write = FALSE)
  al_fiml <- sapply(YEARS, function(y) sapply(names(MODEL_FACTORS), function(K) r4m$multigroup$latent$by_group[[K]][[y]]$alpha))
  check("T8d S04 FIML with 10% MCAR per item recovers latent means (max abs error < 0.08) and uses all records", max(abs(al_fiml - al_true)) < 0.08 &&
          all(unlist(r4m$multigroup$n) == tr$n), paste("max abs error", fmt(max(abs(al_fiml - al_true))), "n", paste(unlist(r4m$multigroup$n), collapse = ",")))

  # --- T9: single-group models and alpha
  sg <- r$single_group
  conv_sg <- unlist(lapply(sg, function(m) lapply(m$by_year, function(b) b$convergence$converged)))
  check("T9a all nine single-group fits converged", all(conv_sg), paste(sum(conv_sg), "of", length(conv_sg)))
  p_sg <- unlist(lapply(sg, function(m) lapply(m$by_year, function(b) b$fit$pvalue)))
  check("T9b single-group true models fit (all p > 1e-4)", all(p_sg > 1e-4), paste(fmt(p_sg, 3), collapse = " "))
  c2 <- sg$form3_C1C2$by_year[["1976"]]$parameters
  check("T9c C2 single indicator: loading fixed 1, residual fixed 0", c2$est[c2$lhs == "C2" & c2$op == "=~"] == 1 && c2$est[c2$lhs == "V3226" & c2$op == "~~"] == 0)
  # alpha: closed form on known covariance for K1 1976
  y <- "1976"; its <- FACTORS_F4$K1
  X <- as.matrix(D[[key_for(y, "f4")]]$data[, its, with = FALSE])
  a_direct <- length(its) / (length(its) - 1) * (1 - sum(apply(X, 2, var)) / var(rowSums(X)))
  check("T9d coefficient alpha equals k/(k-1)(1 - sum var / var sum) computed directly", abs(r$coefficient_alpha$alpha$K1[[y]]$alpha - a_direct) < 1e-12,
        paste(fmt(r$coefficient_alpha$alpha$K1[[y]]$alpha, 12), "vs", fmt(a_direct, 12)))

  # --- T10: item statistics vs t.test
  it <- "V4236"; xa <- D$y1976_f4$data[[it]]; xb <- D$y1991_f4$data[[it]]
  ts <- t.test(xb, xa, var.equal = TRUE); tw <- t.test(xb, xa)
  st <- r$item_statistics$statistics$form4[[it]]$pairs$P1
  check("T10a Student t/df/p equal t.test(var.equal=TRUE)", abs(st$student_t - ts$statistic) < 1e-10 && abs(st$student_p - ts$p.value) < 1e-12 && st$student_df == ts$parameter,
        paste(fmt(st$student_t, 10), "vs", fmt(ts$statistic, 10)))
  check("T10b Welch t/df/p equal t.test()", abs(st$welch_t - tw$statistic) < 1e-10 && abs(st$welch_df - tw$parameter) < 1e-8 && abs(st$welch_p - tw$p.value) < 1e-12,
        paste(fmt(st$welch_df, 10), "vs", fmt(tw$parameter, 10)))
  check("T10c mean difference is later minus earlier", abs(st$mean_diff - (mean(xb) - mean(xa))) < 1e-12)

  # --- T11: weighted statistics
  x <- xa; w <- rep(1, length(x))
  dw <- item_desc_w(x, x == 4, w); du <- item_desc(x, x == 4)
  check("T11a weighted descriptives with unit weights equal unweighted (mean, sd)", abs(dw$mean - du$mean) < 1e-12 && abs(dw$sd - du$sd) < 1e-12)
  w2 <- sample(1:3, length(x), TRUE)
  xd <- rep(x, w2)
  mom_w <- sample_moments(cbind(x), w = w2, divisor = "n-1")
  check("T11b weighted mean with integer weights equals mean of duplicated records", abs(mom_w$mean[1] - mean(xd)) < 1e-10)
  Xk <- as.matrix(D$y1976_f4$data[, FACTORS_F4$K2, with = FALSE])
  mom_wk <- sample_moments(Xk, w = w2, divisor = "n-1")
  Xd <- Xk[rep(seq_len(nrow(Xk)), w2), ]
  check("T11c weighted covariance (normalized weights, divisor n-1) proportional to duplicated-record covariance; alpha identical",
        abs(alpha_from_cov(mom_wk$cov) - alpha_from_cov(cov(Xd))) < 1e-10, paste(fmt(alpha_from_cov(mom_wk$cov), 10), "vs", fmt(alpha_from_cov(cov(Xd)), 10)))
  r1 <- run_spec("S01", D, root, write = FALSE)
  check("T11d S01 (weighted) runs end to end and M4 converged", r1$status == "ok" && r1$multigroup$models$M4$convergence$converged, r1$reason)

  # --- T12: exact downdating equals recomputation
  s <- D$y1976_f4$data[, MODEL_ITEMS, with = FALSE]
  mom <- sample_moments(s, divisor = "n-1")
  md <- downdate_moments(mom, as.numeric(s[5]))
  mr <- sample_moments(s[-5], divisor = "n-1")
  check("T12 downdated moments equal recomputed moments (1e-9)", max(abs(md$cov - mr$cov)) < 1e-9 && max(abs(md$mean - mr$mean)) < 1e-12 && md$nobs == mr$nobs,
        paste("max abs cov diff", fmt(max(abs(md$cov - mr$cov)))))

  # --- T13: influence mode on synthetic data (3 deletions); first deleted record is the smallest V4 of 1976
  inf <- run_influence(D, root, start = 1L, limit = 3L, write = FALSE)
  tb <- inf$table
  check("T13a influence mode produced 3 rows with status ok and the required 35 columns", nrow(tb) == 3 && all(tb$status == "ok") && identical(names(tb), influence_columns()) &&
          tb$del_group[1] == "1976" && tb$del_V4[1] == format_id(min(D$y1976_f4$data$V4)), paste(tb$status, collapse = ","))
  # independent check: refit without record 1 from scratch and compare d_eq_K1_P1
  D1 <- D; D1$y1976_f4$data <- D1$y1976_f4$data[-which.min(D1$y1976_f4$data$V4)]
  r_del <- run_spec("S00", D1, root, write = FALSE)
  check("T13b influence d_eq (warm start, downdated moments) equals cold refit without the record (1e-6)",
        abs(tb$d_eq_K1_P1[1] - r_del$multigroup$contrasts$contrasts$K1$P1$d_eq) < 1e-6 && abs(tb$p_K3_P2[1] - r_del$multigroup$latent$deltas$K3$P2$pvalue) < 1e-6,
        paste(fmt(tb$d_eq_K1_P1[1], 10), "vs", fmt(r_del$multigroup$contrasts$contrasts$K1$P1$d_eq, 10)))
  check("T13c deleting one record changes d_eq only slightly (< 0.01)", max(abs(as.numeric(tb[1, 6:20]) - deq_est[cbind(rep(1:3, 5), rep(1:5, each = 3))])) < 0.01)

  # --- T14: hash sorted ascending and independent of input order
  check("T14 V4 hash independent of record order", identical(hash_v4(c(3, 1, 2)), hash_v4(c(1, 2, 3))) && identical(hash_v4(c(1, 2, 3)), unname(tools::sha256sum(bytes = charToRaw("1\n2\n3")))))

  elapsed <- proc.time()[["elapsed"]] - t0
  # ---- write TESTS.md
  ok <- vapply(results, function(x) x$ok, logical(1))
  lines <- c("# Synthetic-data tests", "",
             sprintf("Generated by `Rscript code/run.R test` on %s (R %s, lavaan %s). Elapsed %.0f s.", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), getRversion(), packageVersion("lavaan"), elapsed), "",
             "## Design", "",
             "Three year groups (n = 3000, 2500, 2000) of 23 continuous Form 4 items generated from the manifest's seven-factor structure",
             "(K1-K7, factor correlations 0.3) with known loadings (marker 1, others U(0.7, 1.3)), known intercepts (marker 0),",
             "group-specific shifts on the six released intercepts (V4238, V4240, V4231, V4229, V4230, V4228) in 1991 and 2006,",
             "known latent means (1976 = 0) and known factor variances per group; residual variances U(0.4, 0.8).",
             "Three Form 3 files generated from the C1 (5 indicators, marker V3224) + C2 (single indicator) model, with raw V3222/V3223/V3227 derived",
             "so that the reversals 6 - x / 3 - x recover the simulated indicators.",
             "The synthetic files are pushed through exactly the same functions used for the supplied data (run_spec, run_influence).", "",
             sprintf("## Results: %d of %d checks passed", sum(ok), length(ok)), "",
             "| Test | Result | Detail |", "| --- | --- | --- |",
             vapply(results, function(x) sprintf("| %s | %s | %s |", x$name, if (x$ok) "PASS" else "FAIL", gsub("\\|", "/", x$detail)), ""),
             "", "## Truth used", "",
             "Latent means (rows 1976, 1991, 2006; columns K1-K7):", "", "```", capture.output(print(tr$alpha)), "```", "",
             "Factor variances:", "", "```", capture.output(print(tr$psi_var)), "```", "",
             "Loadings:", "", "```", capture.output(print(tr$lambda)), "```", "")
  writeLines(lines, file.path(root, "code", "TESTS.md"))
  message(sprintf("%d of %d checks passed; written code/TESTS.md", sum(ok), length(ok)))
  invisible(results)
}
