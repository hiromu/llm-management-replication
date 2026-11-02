# Synthetic-data tests for analysis.R.  Run from the project root:
#   Rscript tests/run_tests.R > tests/test_output.txt 2>&1
# No real data are read: analysis.R is sourced with ANALYSIS_SOURCE_ONLY = TRUE.
ANALYSIS_SOURCE_ONLY <- TRUE
source("analysis.R")
set.seed(20261027)

PASS <- 0L; FAIL <- 0L
check <- function(cond, label) {
  ok <- isTRUE(cond)
  if (ok) PASS <<- PASS + 1L else FAIL <<- FAIL + 1L
  cat(if (ok) "PASS" else "FAIL", ":", label, "\n")
}
near <- function(a, b, tol = 1e-8) {
  a <- as.numeric(a); b <- as.numeric(b)
  length(a) == length(b) && all(is.finite(a) == is.finite(b)) && all(abs(a - b) <= tol * pmax(1, abs(b)), na.rm = TRUE)
}

# =============================================================================
cat("\n== (a) WLS estimates, SEs, SSE, condition index and F tests vs direct matrix computation ==\n")
n <- 300
bank <- rep(1:60, each = 5); year <- rep(1985:1989, times = 60)
X <- cbind(1, rnorm(n), rnorm(n), runif(n), rnorm(n)); colnames(X) <- c("(Intercept)", "x1", "x2", "x3", "x4")
w <- runif(n, 0.1, 2)
y <- X %*% c(1, 0.5, -0.3, 2, 0) + rnorm(n) / sqrt(w)
y <- as.vector(y)
f <- fit_core(y, X, w, bank, year)
W <- diag(w)
XtWX <- t(X) %*% W %*% X
beta_d <- solve(XtWX, t(X) %*% W %*% y)
e_d <- y - X %*% beta_d
sse_d <- sum(w * e_d^2)
V_d <- as.numeric(sse_d / (n - ncol(X))) * solve(XtWX)
check(near(f$beta, beta_d, 1e-10), "WLS coefficients equal (X'WX)^-1 X'Wy")
check(near(f$se, sqrt(diag(V_d)), 1e-10), "WLS SEs equal sqrt(diag(s2 (X'WX)^-1)), s2 = SSE_w/(N-K)")
check(near(f$sse, sse_d, 1e-10), "weighted SSE equals sum w e^2")
check(f$df == n - ncol(X) && f$K == ncol(X) && f$n == n, "N, K, df_resid")
check(near(f$p, 2 * pt(-abs(f$beta / f$se), n - ncol(X)), 1e-12), "two-sided p from t(df_resid)")
lmw <- lm(y ~ X - 1, weights = w)
check(near(f$beta, coef(lmw), 1e-10) && near(f$se, sqrt(diag(vcov(lmw))), 1e-10), "matches lm(weights=) coefficients and SEs")
Xt <- X * sqrt(w); Xs <- sweep(Xt, 2, sqrt(colSums(Xt^2)), "/"); sv <- svd(Xs)$d
check(near(f$cond_max, max(sv) / min(sv), 1e-10), "largest condition index of unit-length-scaled weighted design")
check(near(rstudent_ext(f), rstudent(lmw), 1e-8), "externally studentized residuals match rstudent(lm)")
# nested F test: restricted model drops x3 and x4
fr <- fit_core(y, X[, 1:3], w, bank, year)
q <- f$K - fr$K
F_mine <- ((fr$sse - f$sse) / q) / (f$sse / f$df)
lmr <- lm(y ~ X[, 1:3] - 1, weights = w)
an <- anova(lmr, lmw)
check(near(F_mine, an$F[2], 1e-10) && near(pf(F_mine, q, f$df, lower.tail = FALSE), an$`Pr(>F)`[2], 1e-10), "nested F and upper-tail p equal anova() on weighted lm")
# HC1 and CR1 against direct formulas on the sqrt(w)-transformed regression
fh <- fit_core(y, X, w, bank, year, cov_type = "R23.hc1")
et <- as.vector(sqrt(w) * e_d); XtXi <- solve(crossprod(Xt))
V_hc1 <- XtXi %*% crossprod(Xt * et) %*% XtXi * n / (n - ncol(X))
check(near(fh$se, sqrt(diag(V_hc1)), 1e-10), "HC1 SEs equal direct sandwich with N/(N-K)")
fc <- fit_core(y, X, w, bank, year, cov_type = "R23.cluster_bank")
ug <- rowsum(Xt * et, bank); G <- nrow(ug)
V_cr1 <- XtXi %*% crossprod(ug) %*% XtXi * (G / (G - 1)) * ((n - 1) / (n - ncol(X)))
check(near(fc$se, sqrt(diag(V_cr1)), 1e-10), "CR1 cluster-by-bank SEs equal direct formula with G/(G-1)*(N-1)/(N-K)")
check(near(fc$beta, f$beta) && near(fh$beta, f$beta), "covariance choice leaves coefficients unchanged")
# rank deficiency is reported, not silently handled
err <- tryCatch(fit_core(y, cbind(X, X[, 2]), w, bank, year), error = function(e) conditionMessage(e))
check(is.character(err) && grepl("rank", err), "rank-deficient design raises an error")
check(!is.null(names(f$p)) && identical(names(f$p), colnames(X)) && identical(names(f$t), colnames(X)), "t and p vectors carry term names")
# N = K + 1 is a valid fit (df_resid = 1); N = K is not
f6 <- fit_core(y[1:6], X[1:6, ], w[1:6], bank[1:6], year[1:6])
check(f6$df == 1 && all(is.finite(f6$se)) && all(is.finite(f6$p)), "N = K + 1 fits with df_resid = 1 and finite inference")
err <- tryCatch(fit_core(y[1:5], X[1:5, ], w[1:5], bank[1:5], year[1:5]), error = function(e) conditionMessage(e))
check(is.character(err) && grepl("df_resid", err), "N = K is rejected")
err <- tryCatch(fit_core(c(NA, y[-1]), X, w, bank, year), error = function(e) conditionMessage(e))
check(is.character(err) && grepl("missing", err), "missing values raise an explicit error")

# =============================================================================
cat("\n== (b) strategic deviation on a hand-made market ==\n")
toy <- data.table(RSSD9001 = 1:3, year = 1990L, in_U = TRUE, ROA = c(0.01, 0.02, 0.03), AA = c(100, 200, 300), DEP = c(10, 20, 30))
for (k in 1:11) toy[, (paste0("s", k)) := 0]
toy[, s1 := c(0.1, 0.2, 0.3)]      # mean 0.2, sample sd 0.1 -> |z| = 1, 0, 1
toy[, s2 := c(0.5, 0.5, 0.5)]      # zero SD -> contributes 0 (or SD missing under zero_sd_missing)
toy[, s3 := c(0.3, 0.1, 0.2)]      # mean 0.2, sample sd 0.1 -> |z| = 1, 1, 0
cfg_b <- list(R09 = "R09.all_market", R17 = "R17.sample_sd")
bch <- compute_benchmarks(toy, cfg_b)
check(near(bch$m1, 0.2) && near(bch$sd1, 0.1) && near(bch$sd2, 0) && near(bch$meanROA, 0.02) && bch$D == 60, "benchmarks: means, sample SDs, zero SD, mean ROA, market deposits")
SDv <- compute_SD(toy, bch, "R17.sample_sd")
check(near(SDv, c(2, 1, 1)), "SD = sum |z| over categories, zero-SD category contributes 0 (sample sd)")
check(near(SDv^2, c(4, 1, 1)), "SD2 = raw square")
cfg_p <- list(R09 = "R09.all_market", R17 = "R17.population_sd")
bchp <- compute_benchmarks(toy, cfg_p)
check(near(bchp$sd1, sqrt(2 / 3) * 0.1), "population SD uses n denominator")
check(near(compute_SD(toy, bchp, "R17.population_sd"), c(2, 1, 1) / sqrt(2 / 3)), "SD with population SD")
check(sd_fun(5, "R17.population_sd") == 0 && is.na(sd_fun(5, "R17.sample_sd")) && is.na(sd_fun(NA_real_, "R17.population_sd")), "one observation: population SD = 0, sample SD missing; none: missing")
check(all(is.na(compute_SD(toy, bch, "R17.zero_sd_missing"))), "zero-SD category makes SD missing under R17.zero_sd_missing")
toy2 <- copy(toy); toy2[1, s4 := NA_real_]
check(is.na(compute_SD(toy2, compute_benchmarks(toy2, cfg_b), "R17.sample_sd")[1]) && !any(is.na(compute_SD(toy2, compute_benchmarks(toy2, cfg_b), "R17.sample_sd")[2:3])), "missing share makes only that bank's SD missing; benchmarks available-case")
bw <- compute_benchmarks(toy, list(R09 = "R09.weighted_roa", R17 = "R17.sample_sd"))
check(near(bw$meanROA, sum(c(0.01, 0.02, 0.03) * c(100, 200, 300)) / 600), "asset-weighted market ROA")
toy3 <- copy(toy); toy3[2, ROA := NA_real_]
bj <- compute_benchmarks(toy3, list(R09 = "R09.joint_complete", R17 = "R17.sample_sd"))
check(bj$n_pop == 2 && near(bj$m1, 0.2) && near(bj$D, 40), "joint-complete population excludes incomplete bank from all benchmarks")
ba <- compute_benchmarks(toy, cfg_b, ref_keys = data.table(RSSD9001 = c(1L, 2L), year = 1990L))
check(ba$n_pop == 2 && near(ba$m1, 0.15) && near(ba$D, 30), "analytic reference population restricts benchmarks to the given keys")

# =============================================================================
cat("\n== (c) lag construction across gaps and entries ==\n")
A <- data.table(RSSD9001 = c(1L, 1L, 1L, 2L, 2L, 3L, 4L, 4L, 5L, 5L),
                year     = c(1984L, 1985L, 1986L, 1984L, 1986L, 1986L, 1984L, 1985L, 1984L, 1985L),
                in_U     = c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE),
                ROA      = c(0.02, 0.02, 0.03, 0.06, 0.08, 0.05, 0.10, 0.04, NA, 0.03))
bench <- data.table(year = c(1984L, 1985L, 1986L), meanROA = c(0.01, 0.015, 0.02), D = 1)
A <- relative_roa(A, bench)
check(near(A[RSSD9001 == 1 & year == 1984, y], 1) && near(A[RSSD9001 == 1 & year == 1985, y], 0.5), "y = 100*(ROA - same-year market mean)")
L <- lag_as_reported(A)
g <- function(id, yr, col = "lag") L[RSSD9001 == id & year == yr][[col]]
check(is.na(g(1, 1984)) && g(1, 1984, "lag_source") == "no_t-1_row", "first year of a bank: lag missing")
check(near(g(1, 1985), 1) && near(g(1, 1986), 0.5), "consecutive years: lag is previous-year y computed with t-1 benchmarks")
check(is.na(g(2, 1986)) && g(2, 1986, "lag_source") == "no_t-1_row", "gap year: no gap-skipping, lag missing")
check(is.na(g(3, 1986)), "entrant: lag missing")
check(is.na(g(4, 1985)) && g(4, 1985, "lag_source") == "no_t-1_row", "t-1 row outside the market population gives no lag")
check(is.na(g(5, 1985)) && g(5, 1985, "lag_source") == "t-1_y_missing", "t-1 y missing gives missing lag with reason")
check(nrow(L) == nrow(A), "lag merge keeps one row per bank-year")

# =============================================================================
cat("\n== (d) sample hash format ==\n")
h <- sample_hash(c(2L, 1L, 10L), c(1985L, 1985L, 1986L))
expected <- digest("1,1985\n10,1986\n2,1985\n", algo = "sha256", serialize = FALSE)
check(nchar(h) == 64 && grepl("^[0-9a-f]{64}$", h), "hash is 64 lowercase hex characters")
check(h == expected, "hash equals SHA-256 of sorted, newline-terminated 'RSSD9001,year' lines")
check(sample_hash(c(10L, 2L, 1L), c(1986L, 1985L, 1985L)) == h, "hash independent of row order")
check(sample_hash(c(2L, 1L, 10L), c(1985L, 1985L, 1987L)) != h, "hash changes when the sample changes")
check(sample_hash(995151, 1987) == digest("995151,1987\n", algo = "sha256", serialize = FALSE), "integers formatted without decimals or spaces")

# =============================================================================
cat("\n== (e) weight rescaling leaves coefficients and SEs unchanged ==\n")
f1 <- fit_core(y, X, w, bank, year)
f2 <- fit_core(y, X, w / mean(w), bank, year)
check(near(f1$beta, f2$beta, 1e-10) && near(f1$se, f2$se, 1e-10), "w/mean(w): identical coefficients and SEs")
check(near(f2$sse, f1$sse / mean(w), 1e-10), "SSE scales by 1/mean(w)")
check(near(f1$t, f2$t, 1e-10) && near(f1$p, f2$p, 1e-10) && near(f1$cond_max, f2$cond_max, 1e-10), "t, p and condition index unchanged")
# through the configuration layer (R24.mean1 vs R24.raw)
mk_sample <- function(nb = 40, yrs = 1985:1992, gap = TRUE) {
  s <- CJ(RSSD9001 = seq_len(nb) * 1000L, year = yrs)
  if (gap) s <- s[!(RSSD9001 == 3000L & year == 1988L)][!(RSSD9001 == 5000L & year < 1988L)]
  s[, SD := runif(.N, 2, 12)][, SD2 := SD^2][, MS := runif(.N, 0.001, 0.2)][, TER := runif(.N, 0.05, 0.12)]
  s[, RMG := rep(rnorm(length(yrs)), length.out = .N)[match(year, yrs)]]
  s[, lag := rnorm(.N)]
  s[, y := 0.5 - 0.1 * SD + 0.004 * SD2 + 2 * MS - 5 * TER + 0.02 * RMG + 0.4 * lag + rnorm(.N, sd = 0.5)]
  s[, w := MS]; setorder(s, RSSD9001, year); s
}
S <- mk_sample()
cfg0 <- list(R10 = "R10.delete_named", R22 = "R22.none", R23 = "R23.conventional", R24 = "R24.raw", R25 = "R25.wls", R26 = "R26.raw")
cfg1 <- modifyList(cfg0, list(R24 = "R24.mean1"))
m0 <- fit_model(S, "M3", cfg0); m1 <- fit_model(S, "M3", cfg1)
check(near(m0$beta, m1$beta, 1e-10) && near(m0$se, m1$se, 1e-10) && near(m1$sse, m0$sse / mean(S$MS), 1e-10), "R24.mean1 via fit_model: same coefficients/SEs, SSE scaled")

# =============================================================================
cat("\n== (f) estimation layer: models, checks, FE, covariance, AR(1), outlier rule, influence ==\n")
meta <- list(spec_id = "T", origin = "O_A", axis = NA_character_, level_id = NA_character_)
r0 <- run_models(S, cfg0, meta)
check(all(r0$spec_rows$status == "ok") && nrow(r0$spec_rows) == 5 + 6 + 7 + 6, "four models fitted; one row per term")
check(identical(r0$spec_rows[model == "M3", term], c("(Intercept)", "SD2", "SD", "MS", "TER", "RMG", "lag")), "regressor order as specified")
check(nrow(r0$f_rows) == 4 && all(is.finite(r0$f_rows$F)) && all(r0$f_rows$p_upper >= 0 & r0$f_rows$p_upper <= 1), "four nested F tests with finite F and valid p")
Fchk <- r0$f_rows[comparison == "M3_vs_M1"]
check(Fchk$q == 2 && near(Fchk$F, ((r0$fits$M1$sse - r0$fits$M3$sse) / 2) / (r0$fits$M3$sse / r0$fits$M3$df)), "F = ((SSE_r - SSE_u)/q)/(SSE_u/(N-K_u))")
check(uniqueN(r0$spec_rows$sample_hash) == 1, "same rows (hash) for all models within a specification")
# R26.centered reproduces raw coefficients and SEs
rc <- run_models(S, modifyList(cfg0, list(R26 = "R26.centered")), meta)
for (m in c("M1", "M2", "M3")) {
  a <- r0$spec_rows[model == m]; b <- rc$spec_rows[model == m]
  check(near(a$estimate, b$estimate, 1e-8) && near(a$se, b$se, 1e-8) && near(a$sse_w, b$sse_w, 1e-8), sprintf("R26.centered back-transformed %s equals raw basis", m))
}
b <- rc$spec_rows[model == "M3_SQ"]
check(nrow(b) == 1 && b$status == "not_applicable" && is.na(b$term) && grepl("first-order", b$message) && is.null(rc$fits$M3_SQ), "R26.centered M3_SQ: status not_applicable, not fitted (amendment C6)")
check(is.na(rc$f_rows[comparison == "M3_SQ_vs_M1", F]) && all(is.finite(rc$f_rows[comparison != "M3_SQ_vs_M1", F])), "R26.centered: M3_SQ_vs_M1 F test empty, the other three present")
check(!any(grepl("^SD", rc$spec_rows[model == "M1", term])) && near(rc$spec_rows[model == "M1", estimate], r0$spec_rows[model == "M1", estimate]), "R26.centered M1: nothing to centre, equals raw fit")
err <- tryCatch(build_design(S, "M3_SQ", modifyList(cfg0, list(R26 = "R26.centered"))), error = function(e) conditionMessage(e))
check(is.character(err) && grepl("M3_SQ", err), "build_design refuses a centred M3_SQ design")
# direct check of the delta-method map on M3: refit raw with centred regressors by lm and transform
mS <- mean(S$SD); lmc <- lm(y ~ I(SD - mS) + I((SD - mS)^2) + MS + TER + RMG + lag, data = S, weights = MS)
lmr <- lm(y ~ SD2 + SD + MS + TER + RMG + lag, data = S, weights = MS)
check(near(coef(lmr)[["SD"]], coef(lmc)[[2]] - 2 * coef(lmc)[[3]] * mS, 1e-8), "centred->raw identity holds in lm as well")
# R22.year drops RMG, adds year dummies; R22.bank adds bank dummies (all listed)
ry <- run_models(S, modifyList(cfg0, list(R22 = "R22.year")), meta)
check(!"RMG" %in% ry$spec_rows[model == "M3", term] && sum(grepl("^year_", ry$spec_rows[model == "M3", term])) == 7 && grepl("collinear", ry$spec_rows$message[1]), "R22.year: RMG dropped, 7 year indicators, reported in message")
rb <- run_models(S, modifyList(cfg0, list(R22 = "R22.bank")), meta)
nb_ind <- uniqueN(S$RSSD9001) - 1
check(sum(grepl("^bank_", rb$spec_rows[model == "M1", term])) == nb_ind && rb$spec_rows[model == "M1", k][1] == 5 + nb_ind && nrow(rb$spec_rows[model == "M1"]) == 5 + nb_ind && all(is.finite(rb$spec_rows[model == "M1", p_two_sided])), "R22.bank: bank indicators in K and every coefficient listed with inference")
# covariance choices
rcl <- run_models(S, modifyList(cfg0, list(R23 = "R23.cluster_bank")), meta)
rh <- run_models(S, modifyList(cfg0, list(R23 = "R23.hc1")), meta)
check(near(rcl$spec_rows[model == "M2", estimate], r0$spec_rows[model == "M2", estimate]) && !near(rcl$spec_rows[model == "M2", se], r0$spec_rows[model == "M2", se]), "cluster-robust: same estimates, different SEs")
check(all(rcl$f_rows$F == r0$f_rows$F) && all(rh$f_rows$F == r0$f_rows$F), "SSE-based F unchanged under non-conventional covariance")
# OLS equals lm without weights
ro <- run_models(S, modifyList(cfg0, list(R25 = "R25.ols")), meta)
lmo <- lm(y ~ SD2 + SD + MS + TER + RMG + lag, data = S)
check(near(ro$spec_rows[model == "M3", estimate], coef(lmo), 1e-8) && near(ro$spec_rows[model == "M3", se], sqrt(diag(vcov(lmo))), 1e-8), "R25.ols equals unweighted lm")
# AR(1) Prais-Winsten
ra <- run_models(S, modifyList(cfg0, list(R25 = "R25.wls_ar1")), meta)
rho <- ra$fits$M3$rho
check(all(ra$spec_rows$status == "ok") && is.finite(rho) && abs(rho) < 1 && grepl("rho", ra$spec_rows$message[1]), "R25.wls_ar1 fits with |rho| < 1 and reports rho")
# AR(1) with rho forced to 0 must equal plain WLS: check via direct transformation using the exposed pieces
S0 <- copy(S);
fa <- fit_core(S$y, build_design(S, "M3", cfg0)$X, S$MS, S$RSSD9001, S$year, estimator = "R25.wls_ar1")
Xt <- build_design(S, "M3", cfg0)$X * sqrt(S$MS); yt <- S$y * sqrt(S$MS)
bk <- S$RSSD9001; yr <- S$year; nn <- nrow(S)
hp <- c(FALSE, bk[-1] == bk[-nn] & yr[-1] == yr[-nn] + 1L); ip <- which(hp)
Xs <- Xt; ys <- yt; Xs[ip, ] <- Xt[ip, ] - rho * Xt[ip - 1, ]; ys[ip] <- yt[ip] - rho * yt[ip - 1]
Xs[!hp, ] <- sqrt(1 - rho^2) * Xt[!hp, ]; ys[!hp] <- sqrt(1 - rho^2) * yt[!hp]
check(near(fa$beta, solve(crossprod(Xs), crossprod(Xs, ys)), 1e-8), "Prais-Winsten transform (gaps/entries treated as first observations) reproduced directly")
e_orig <- S$y - build_design(S, "M3", cfg0)$X %*% fa$beta
check(near(fa$sse, sum(S$MS * e_orig^2), 1e-8) && near(fa$sse_t, sum((ys - Xs %*% fa$beta)^2), 1e-8) && !near(fa$sse, fa$sse_t), "AR(1): reported SSE_w = sum w e^2 of the original regression; transformed SSE kept separately")
Fa <- ra$f_rows[comparison == "M3_vs_M1"]
check(near(Fa$F, ((ra$fits$M1$sse - ra$fits$M3$sse) / 2) / (ra$fits$M3$sse / ra$fits$M3$df)), "AR(1): nested F uses the reported SSE_w")
check(near(fit_core(S$y, build_design(S, "M3", cfg0)$X, S$MS, S$RSSD9001, S$year)$sse, r0$fits$M3$sse) && near(r0$fits$M3$sse, r0$fits$M3$sse_t), "WLS without AR(1): reported and transformed SSE coincide")
# R10.max_rstudent deletes one row per model
rm_ <- run_models(S, modifyList(cfg0, list(R10 = "R10.max_rstudent")), meta)
check(all(rm_$spec_rows$n == nrow(S) - 1) && grepl("max_rstudent", rm_$spec_rows$message[1]), "R10.max_rstudent: exactly one row deleted per model")
# influence diagnostics
Ssm <- S[RSSD9001 <= 8000L]
inf <- run_influence(Ssm, cfg0, "O_A")
nb <- uniqueN(Ssm$RSSD9001)
check(nrow(inf) == (nrow(Ssm) + nb) * (1 + 2) && all(inf$status == "ok"), "influence: one row per deletion x term for M2 (SD) and M3 (SD2, SD)")
check(all(inf[deletion_type == "bank_year", n] == nrow(Ssm) - 1) && all(inf[deletion_type == "bank", n] < nrow(Ssm) - 1), "influence: N reflects deleted rows")
chk <- inf[deletion_type == "bank_year" & model == "M2" & deleted_id == sprintf("%d_%d", Ssm$RSSD9001[1], Ssm$year[1])]
fdel <- fit_model(Ssm[-1], "M2", cfg0)
check(near(chk$estimate, fdel$beta["SD"]) && near(chk$se, fdel$se["SD"]), "influence: leave-one-out estimate equals a direct refit")
check(all(is.finite(inf[status == "ok", p_two_sided])) && near(chk$p_two_sided, fdel$p["SD"]) && near(chk$p_two_sided, 2 * pt(-abs(fdel$beta["SD"] / fdel$se["SD"]), fdel$df)), "influence: two-sided p reported for every successful fit and equals the direct refit")
# failure is retained, not fatal
tiny <- S[1:4]
rt <- run_models(tiny, cfg0, meta)
check(all(rt$spec_rows$status == "failed") && all(nzchar(rt$spec_rows$message)), "too-small sample: failures recorded with messages")
# unavailable (cannot be implemented from the inputs) is a distinct condition class from failed
u <- tryCatch(unavailable("no %s", "codes"), error = function(e) e)
check(inherits(u, "unavailable") && inherits(u, "error") && conditionMessage(u) == "no codes", "unavailable() raises a condition of class unavailable/error")
u2 <- tryCatch(filter_records(data.table(year = 1990L, quarter = "1990Q4", RSSD9001 = 1L, CALL8786 = 1, RSSD9048 = 200, RSSD9331 = 1),
                              list(R02 = "R02.no_special", .origin_R02 = "R02.charter"), new.env()), error = function(e) e)
check(inherits(u2, "unavailable") && grepl("RSSD9425", conditionMessage(u2)), "R02.no_special without the RSSD9425 column is unavailable")
# R02.no_special with the amendment C2 code table: 1, 2, 4, 9 excluded; 0, 3, 5 and missing kept
callt <- data.table(year = 1990L, q = 4L, quarter = "1990Q4", RSSD9001 = 1:8, CALL8786 = 1, RSSD9048 = 200, RSSD9331 = 1, RSSD9425 = c(0, 1, 2, 3, 4, 5, 9, NA))
lg <- new.env()
kept <- filter_records(callt, list(R02 = "R02.no_special", .origin_R02 = "R02.charter_entity"), lg)
check(identical(sort(kept$RSSD9001), c(1L, 4L, 6L, 8L)) && lg$S1_record_filter$by_year$dropped_special_purpose == 4 && identical(lg$S1_record_filter$special_purpose_filter$codes_excluded, c(1, 2, 4, 9)), "R02.no_special excludes RSSD9425 in {1,2,4,9}; missing counts as 0; logged")
kept0 <- filter_records(callt, list(R02 = "R02.charter_entity", .origin_R02 = "R02.charter_entity"), new.env())
check(nrow(kept0) == 8 && identical(lg$S1_record_filter$by_year$records_after_duplicate_removal, 4L), "origin filter ignores RSSD9425; S1 log carries post-deduplication counts")
u3 <- tryCatch(deflator_series(data.table(series_id = "X", provider = "FRED", frequency = "annual average", date = "1990-01-01", value = 1, vintage = ""), "R20.cpi_annual"), error = function(e) e)
check(inherits(u3, "unavailable"), "a deflator series absent from the inputs is unavailable, not failed")
u4 <- tryCatch(need_input(list(load_errors = list(ev = "file not found")), "ev", "R03.proforma"), error = function(e) e)
check(inherits(u4, "unavailable") && grepl("file not found", conditionMessage(u4)), "need_input reports the load error as unavailable")
check(!inherits(tryCatch(stop("x"), error = function(e) e), "unavailable"), "ordinary errors are not unavailable")

# =============================================================================
cat("\n== (g) record-level helpers: R15 rules, category identities, timing ==\n")
inp_t <- list(pres_items = c("RCFD1766", "RCFD2170", "RCFD1400", "RCFD0010", "RCFD0081", "RCFD0071"),
              pres_nc = list(RCFD1766 = c("1983Q4")))
recs <- data.table(RSSD9001 = c(1L, 1L), year = c(1983L, 1984L), q = 4L, quarter = c("1983Q4", "1984Q4"),
                   RCFD1766 = c(NA, 50), RCFD2170 = c(1000, 1000), RCFD0010 = c(NA, NA), RCFD0081 = c(10, 20), RCFD0071 = c(5, 5))
cz <- list(R15 = "R15.zero_if_not_collected"); cm <- list(R15 = "R15.missing"); ci <- list(R15 = "R15.identity_fill")
check(identical(get_item(recs, "RCFD1766", cz, inp_t), c(0, 50)), "zero_if_not_collected: missing & not collected -> 0")
check(identical(get_item(recs, "RCFD1766", cm, inp_t), c(NA, 50)), "R15.missing: stays missing")
check(all(is.na(get_item(recs, "RCFD0010", cz, inp_t))), "zero_if_not_collected: collected but missing for the bank stays missing")
recs[, RCFD9999 := c(NA, 7)]
cnt <- new.env()
check(identical(get_item(recs, "RCFD9999", cz, inp_t, cnt), c(NA, 7)) && cnt$no_presence_metadata$RCFD9999 == 1L, "zero_if_not_collected: item without presence metadata is not zero-filled (no evidence) and is counted")
check(all(is.na(get_item(recs, "RCFD8888", cz, inp_t))), "zero_if_not_collected: column absent from file and from presence metadata stays missing")
u5 <- tryCatch(get_item(recs, "RCFD1766", cz, list(pres_items = NULL, load_errors = list(pres = "missing"))), error = function(e) e)
check(inherits(u5, "unavailable"), "zero_if_not_collected without the presence file is unavailable")
check(identical(get_item(recs, "RCFD0010", ci, inp_t), c(15, 25)), "identity_fill: 0010 = 0081 + 0071")
amt <- data.table(RSSD9001 = 1L, year = 1990L, q = 1:4, TA = c(100, 100, 200, 200), DEP = c(10, 20, 30, 40))
for (k in 1:11) amt[, (paste0("A", k)) := 0]
amt[, A1 := c(10, 20, 20, 40)]  # shares 0.1, 0.2, 0.1, 0.2
check(near(shares_by_timing(amt, list(R08 = "R08.year_end"))$s1, 0.2) && near(shares_by_timing(amt, list(R08 = "R08.year_end"))$DEP, 40), "R08.year_end uses Q4")
check(near(shares_by_timing(amt, list(R08 = "R08.mean_of_quarter_shares"))$s1, 0.15) && near(shares_by_timing(amt, list(R08 = "R08.mean_of_quarter_shares"))$DEP, 25), "R08.mean_of_quarter_shares")
check(near(shares_by_timing(amt, list(R08 = "R08.ratio_of_means"))$s1, mean(c(10, 20, 20, 40)) / 150), "R08.ratio_of_means")
amt2 <- copy(amt); amt2[2, A1 := NA_real_]; amt2[4, TA := NA_real_]
check(near(shares_by_timing(amt2, list(R08 = "R08.ratio_of_means"))$s1, mean(c(10, 20, 40)) / mean(c(100, 100, 200))), "R08.ratio_of_means: numerator and denominator averaged separately over their own available quarters")
# centred/back-transform matrix on a hand-built fit object
fobj <- list(beta = c("(Intercept)" = 1, SD2 = 2, SD = 3, MS = 4), V = diag(4), df = 10)
bt <- back_transform(fobj, list(kind = "SD", m = 0.5))
check(near(bt$beta, c(1 - 3 * 0.5 + 2 * 0.25, 2, 3 - 2 * 2 * 0.5, 4)) && identical(names(bt$p), names(fobj$beta)), "back_transform (SD centred): a - b1 m + b2 m^2, b2, b1 - 2 b2 m; named p")
fobj2 <- list(beta = c("(Intercept)" = 1, SD2 = 2, MS = 4), V = diag(3), df = 10)
err <- tryCatch(back_transform(fobj2, list(kind = "SD", m = 0.5)), error = function(e) conditionMessage(e))
check(is.character(err) && grepl("first-order", err), "back_transform refuses a centred SD2 without the SD term")
check(near(back_transform(fobj, NULL)$beta, fobj$beta), "back_transform without centring is the identity")
# real market growth from calendar year t-1 only (no gap-spanning): same arithmetic as derive_variables
g <- data.table(year = c(1984L, 1985L, 1987L), real = c(100, 110, 150))
g[, RMG := 100 * (real / real[match(year - 1L, year)] - 1)]
check(is.na(g$RMG[1]) && near(g$RMG[2], 10) && is.na(g$RMG[3]), "RMG: missing for the first year and after a gap in the benchmark years")

cat(sprintf("\n%d passed, %d failed\n", PASS, FAIL))
if (FAIL > 0) quit(status = 1)
