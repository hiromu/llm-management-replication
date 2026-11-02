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
check("SD" %in% rc$spec_rows[model == "M3_SQ", term] && near(rc$spec_rows[model == "M3_SQ" & term == "SD2", estimate], rc$fits$M3_SQ$beta["SD2"]), "R26.centered M3_SQ: implied raw SD term listed; SD2 coefficient unchanged")
# direct check of the delta-method map on M3: refit raw with centred regressors by lm and transform
mS <- mean(S$SD); lmc <- lm(y ~ I(SD - mS) + I((SD - mS)^2) + MS + TER + RMG + lag, data = S, weights = MS)
lmr <- lm(y ~ SD2 + SD + MS + TER + RMG + lag, data = S, weights = MS)
check(near(coef(lmr)[["SD"]], coef(lmc)[[2]] - 2 * coef(lmc)[[3]] * mS, 1e-8), "centred->raw identity holds in lm as well")
# R22.year drops RMG, adds year dummies; R22.bank adds bank dummies (not listed)
ry <- run_models(S, modifyList(cfg0, list(R22 = "R22.year")), meta)
check(!"RMG" %in% ry$spec_rows[model == "M3", term] && sum(grepl("^year_", ry$spec_rows[model == "M3", term])) == 7 && grepl("collinear", ry$spec_rows$message[1]), "R22.year: RMG dropped, 7 year indicators, reported in message")
rb <- run_models(S, modifyList(cfg0, list(R22 = "R22.bank")), meta)
check(!any(grepl("^bank_", rb$spec_rows$term)) && rb$spec_rows[model == "M1", k][1] == 5 + uniqueN(S$RSSD9001) - 1, "R22.bank: bank indicators in K but not listed")
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
# failure is retained, not fatal
tiny <- S[1:4]
rt <- run_models(tiny, cfg0, meta)
check(all(rt$spec_rows$status == "failed") && all(nzchar(rt$spec_rows$message)), "too-small sample: failures recorded with messages")

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
check(identical(get_item(recs, "RCFD0010", ci, inp_t), c(15, 25)), "identity_fill: 0010 = 0081 + 0071")
amt <- data.table(RSSD9001 = 1L, year = 1990L, q = 1:4, TA = c(100, 100, 200, 200), DEP = c(10, 20, 30, 40))
for (k in 1:11) amt[, (paste0("A", k)) := 0]
amt[, A1 := c(10, 20, 20, 40)]  # shares 0.1, 0.2, 0.1, 0.2
check(near(shares_by_timing(amt, list(R08 = "R08.year_end"))$s1, 0.2) && near(shares_by_timing(amt, list(R08 = "R08.year_end"))$DEP, 40), "R08.year_end uses Q4")
check(near(shares_by_timing(amt, list(R08 = "R08.mean_of_quarter_shares"))$s1, 0.15) && near(shares_by_timing(amt, list(R08 = "R08.mean_of_quarter_shares"))$DEP, 25), "R08.mean_of_quarter_shares")
check(near(shares_by_timing(amt, list(R08 = "R08.ratio_of_means"))$s1, mean(c(10, 20, 20, 40)) / 150), "R08.ratio_of_means")
# centred/back-transform matrix on a hand-built fit object
fobj <- list(beta = c("(Intercept)" = 1, SD2 = 2, SD = 3, MS = 4), V = diag(4), df = 10)
bt <- back_transform(fobj, 0.5, names(fobj$beta))
check(near(bt$beta, c(1 - 3 * 0.5 + 2 * 0.25, 2, 3 - 2 * 2 * 0.5, 4)), "back_transform: a - b1 m + b2 m^2, b2, b1 - 2 b2 m")

cat(sprintf("\n%d passed, %d failed\n", PASS, FAIL))
if (FAIL > 0) quit(status = 1)
