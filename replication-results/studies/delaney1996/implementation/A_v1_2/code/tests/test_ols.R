# test_ols.R -- OLS/WLS, conventional SE, HC3, one-tailed p, nested F and overall F
# against base R (lm, anova) and sandwich::vcovHC on simulated data with known structure.
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "helpers.R"))
suppressPackageStartupMessages({ library(sandwich); library(lmtest) })

set.seed(20261028)
n <- 80
x1 <- rnorm(n); x2 <- rnorm(n); x3 <- rnorm(n)
g <- sample(c("A", "B", "C"), n, replace = TRUE)
dA <- as.numeric(g == "A"); dB <- as.numeric(g == "B")
e <- rnorm(n) * (1 + 0.5 * abs(x1))   # heteroskedastic
y <- 1 + 2 * x1 - 1 * x2 + 0 * x3 + 0.5 * dA + e
w <- runif(n, 0.2, 3)

X <- cbind("(Intercept)" = 1, x1 = x1, x2 = x2, x3 = x3, IND_A = dA, IND_B = dB)
fit <- fit_model(X, y)
ref <- lm(y ~ x1 + x2 + x3 + dA + dB)
sref <- summary(ref)

check(fit$status == "ok", "OLS fit status ok")
check_equal(fit$coefs$estimate, coef(ref), "OLS estimates match lm")
check_equal(fit$coefs$se, sref$coefficients[, 2], "OLS conventional SE match lm")
check_equal(fit$coefs$t, sref$coefficients[, 3], "OLS t match lm")
check_equal(fit$coefs$p_two, sref$coefficients[, 4], "OLS two-sided p match lm")
check_equal(fit$coefs$df, rep(ref$df.residual, 6), "residual df match lm")
check_equal(fit$r2, sref$r.squared, "R2 matches lm")
check_equal(fit$adj_r2, sref$adj.r.squared, "adjusted R2 matches lm")
check_equal(c(fit$f, fit$f_df1, fit$f_df2), sref$fstatistic, "overall F and df match lm")
check_equal(fit$f_p, pf(sref$fstatistic[1], sref$fstatistic[2], sref$fstatistic[3], lower.tail = FALSE), "overall F p matches")
check(abs(fit$coefs$estimate[2] - 2) < 0.3 && abs(fit$coefs$estimate[3] + 1) < 0.3, "recovers known slopes (2, -1) approximately")

# one-tailed p values
check_equal(fit$coefs$p_upper + fit$coefs$p_lower, rep(1, 6), "p_upper + p_lower = 1")
pos <- fit$coefs$t > 0
check_equal(fit$coefs$p_upper[pos], fit$coefs$p_two[pos] / 2, "p_upper = p_two/2 for positive t")
check_equal(fit$coefs$p_lower[!pos], fit$coefs$p_two[!pos] / 2, "p_lower = p_two/2 for negative t")
check_equal(fit$coefs$p_upper, pt(fit$coefs$t, ref$df.residual, lower.tail = FALSE), "p_upper = P(T > t)")
check(fit$coefs$p_upper[2] < 1e-6 && fit$coefs$p_lower[3] < 1e-6, "known signs give small one-tailed p in the right tail")

# HC3
V3 <- vcovHC(ref, type = "HC3")
check_equal(fit$coefs$se_hc3, sqrt(diag(V3)), "HC3 SE match sandwich vcovHC(type='HC3')")
ct <- coeftest(ref, vcov. = V3, df = ref$df.residual)
check_equal(fit$coefs$t_hc3, ct[, 3], "HC3 t match lmtest::coeftest")
check_equal(fit$coefs$p_two_hc3, ct[, 4], "HC3 two-sided p (t dist, residual df) match coeftest")
check_equal(fit$coefs$p_upper_hc3 + fit$coefs$p_lower_hc3, rep(1, 6), "HC3 one-tailed p sum to 1")
# explicit HC3 formula
h <- hatvalues(ref); eh <- resid(ref)
XtXi <- solve(crossprod(X))
V3m <- XtXi %*% crossprod(X * (eh / (1 - h))) %*% XtXi
check_equal(fit$coefs$se_hc3, sqrt(diag(V3m)), "HC3 SE match explicit formula")

# nested F: adding x3 and the dummies
Xr <- X[, c("(Intercept)", "x1", "x2")]
fr <- fit_model(Xr, y)
nf <- nested_f(fit, fr)
an <- anova(lm(y ~ x1 + x2), ref)
check_equal(nf$f, an$F[2], "nested F matches anova()")
check_equal(nf$p, an$`Pr(>F)`[2], "nested F p matches anova()")
check_equal(c(nf$df1, nf$df2), c(an$Df[2], an$Res.Df[2]), "nested F df match anova()")
check_equal(nf$delta_r2, sref$r.squared - summary(lm(y ~ x1 + x2))$r.squared, "delta R2 matches")

# WLS
fitw <- fit_model(X, y, w)
refw <- lm(y ~ x1 + x2 + x3 + dA + dB, weights = w)
srefw <- summary(refw)
check_equal(fitw$coefs$estimate, coef(refw), "WLS estimates match lm(weights=)")
check_equal(fitw$coefs$se, srefw$coefficients[, 2], "WLS conventional SE match lm(weights=)")
check_equal(fitw$coefs$p_two, srefw$coefficients[, 4], "WLS two-sided p match")
check_equal(fitw$r2, srefw$r.squared, "WLS weighted R2 matches lm(weights=)")
check_equal(fitw$adj_r2, srefw$adj.r.squared, "WLS adjusted R2 matches")
check_equal(c(fitw$f, fitw$f_df1, fitw$f_df2), srefw$fstatistic, "WLS overall F matches")
check_equal(fitw$coefs$se_hc3, sqrt(diag(vcovHC(refw, type = "HC3"))), "WLS HC3 SE match sandwich on weighted lm")
frw <- fit_model(Xr, y, w)
nfw <- nested_f(fitw, frw)
anw <- anova(lm(y ~ x1 + x2, weights = w), refw)
check_equal(nfw$f, anw$F[2], "WLS nested F matches anova() on weighted fits")
check_equal(nfw$p, anw$`Pr(>F)`[2], "WLS nested F p matches")
check_equal(nfw$delta_r2, srefw$r.squared - summary(lm(y ~ x1 + x2, weights = w))$r.squared, "WLS delta weighted R2")

# column dropping (A5): only industry dummies may be dropped, when all zero or collinear
Xz <- cbind(X, IND_Z = 0, IND_C = as.numeric(g == "C"))   # IND_C completes the dummy set -> collinear with the intercept
fz <- fit_model(Xz, y)
check(fz$status == "ok", "fit with an all-zero and a collinear industry dummy succeeds")
check(identical(fz$dropped, c("IND_Z (all zero)", "IND_C (collinear)")), "all-zero and collinear industry dummies are dropped and recorded")
check_equal(fz$coefs$estimate, coef(ref), "estimates unchanged after the industry drops")
check(fz$n_ind == 2 && fz$k == 6, "n_industry_dummies and k reflect the drops")
fdup <- fit_model(cbind(X, x1dup = 2 * x1), y)
check(fdup$status == "failed" && grepl("collinear", fdup$error) && grepl("x1dup", fdup$error), "A5: a collinear non-industry term fails the model with that reason")
fzero <- fit_model(cbind(X, GRIEV = 0), y)
check(fzero$status == "failed" && grepl("all zero", fzero$error) && grepl("GRIEV", fzero$error), "A5: an all-zero non-industry term fails the model with that reason")
fconst <- fit_model(cbind(X, GRIEV = 1), y)
check(fconst$status == "failed" && grepl("collinear", fconst$error) && grepl("GRIEV", fconst$error), "A5: a constant non-industry term (collinear with the intercept) fails the model")
# A6: dropped-column information is retained when the fit later fails
fboth <- fit_model(cbind(X, IND_Z = 0, x1dup = 2 * x1), y)
check(fboth$status == "failed" && identical(fboth$dropped, "IND_Z (all zero)"), "A6: dropped industry dummy recorded although the fit failed on a collinear term")
# A5: industry collinearity is resolved before the residual-df check
Xsm <- cbind("(Intercept)" = 1, x1 = x1[1:5], x2 = x2[1:5], IND_A = c(1, 1, 0, 0, 0), IND_B = c(0, 0, 1, 1, 1))  # n = k = 5, IND_B = 1 - IND_A
fsm <- fit_model(Xsm, y[1:5])
check(fsm$status == "ok" && identical(fsm$dropped, "IND_B (collinear)") && fsm$df == 1, "A5: n = k before the permitted drop still fits (collinear dummy dropped first, df = 1 after)")
Xsm2 <- cbind("(Intercept)" = 1, x1 = x1[1:4], x2 = x2[1:4], x3 = x3[1:4], IND_A = c(1, 0, 0, 0))
fsm2 <- fit_model(Xsm2, y[1:4])
check(fsm2$status == "failed" && grepl("no positive residual df", fsm2$error), "A5: fails only when no positive residual df remains after the permitted drops")
check(identical(fsm2$dropped, "IND_A (collinear)"), "v1.2 checker 1: the collinear industry drop is recorded although the fit then failed on df")
# v1.2 checker item 1: no early exit on n. The QR runs first; industry drops are recorded; a
# collinear non-industry term is identified even when n <= number of non-industry columns.
Xc1 <- cbind("(Intercept)" = 1, x1 = x1[1:4], x2 = x2[1:4], x3 = x3[1:4], IND_A = c(1, 0, 0, 0), IND_B = c(0, 1, 0, 0))  # n = 4 = non-industry columns
fc1 <- fit_model(Xc1, y[1:4])
check(fc1$status == "failed" && grepl("no positive residual df", fc1$error) && identical(fc1$dropped, c("IND_A (collinear)", "IND_B (collinear)")),
      "checker 1: n = number of non-industry columns -> both collinear dummies dropped and recorded, then the df failure")
Xc2 <- cbind("(Intercept)" = 1, x1 = x1[1:3], x2 = x2[1:3], x3 = x3[1:3], IND_A = c(1, 0, 0))   # n = 3 < 4 non-industry columns
fc2 <- fit_model(Xc2, y[1:3])
check(fc2$status == "failed" && grepl("collinear", fc2$error) && grepl("x3", fc2$error) && grepl("n \\(3\\)", fc2$error),
      "checker 1: n < number of non-industry columns -> the aliased non-industry term is named as the reason, with the n context")
check(identical(fc2$dropped, "IND_A (collinear)"), "checker 1: the industry drop is recorded in that failure too")
Xc3 <- cbind(X, x1dup = 2 * x1, IND_C = as.numeric(g == "C"))
fc3 <- fit_model(Xc3, y)
check(fc3$status == "failed" && grepl("x1dup", fc3$error) && !grepl("IND_C", fc3$error) && identical(fc3$dropped, "IND_C (collinear)"),
      "checker 1 / A6: aliased dummy and aliased non-industry term together -> dummy drop recorded, failure names only the non-industry term")
fz2 <- fit_model(cbind(X, IND_Z = 0, GRIEV = 0), y)
check(fz2$status == "failed" && grepl("GRIEV", fz2$error) && identical(fz2$dropped, "IND_Z (all zero)"), "A6: all-zero dummy recorded although an all-zero non-industry term fails the fit")

# failure recording
ff <- fit_model(X[1:4, ], y[1:4])
check(ff$status == "failed" && !is.na(ff$error), "n <= k is recorded as a failure with reason")
fna <- fit_model(X, replace(y, 1, NA))
check(fna$status == "failed" && grepl("missing", fna$error), "NA in outcome is recorded as a failure")
fempty <- fit_model(X[0, , drop = FALSE], y[0])
check(fempty$status == "failed" && grepl("n \\(0\\)", fempty$error), "empty estimation sample is recorded as a failure with reason")

# A1: HC3 when a row has leverage one (single-member industry group)
IND_S <- as.numeric(seq_len(n) == 7)
X1 <- cbind(X, IND_S = IND_S)
f1 <- fit_model(X1, y)
ref1 <- lm(y ~ x1 + x2 + x3 + dA + dB + IND_S)
h1 <- hatvalues(ref1)
check(f1$status == "ok" && f1$n_leverage_one == 1 && abs(h1[7] - 1) < 1e-8, "A1: single-member group gives one leverage-one row, fit still ok")
check(all(is.finite(f1$coefs$se_hc3)) && all(is.finite(f1$coefs$p_two_hc3)), "A1: HC3 SE and p are finite despite a leverage-one row")
keep <- h1 < 1 - 1e-8
XtXi1 <- solve(crossprod(X1))
V3ref <- XtXi1 %*% crossprod(X1[keep, ] * (resid(ref1)[keep] / (1 - h1[keep]))) %*% XtXi1
check_equal(f1$coefs$se_hc3, sqrt(diag(V3ref)), "A1: HC3 SE equal the formula with the leverage-one row's contribution set to zero (bread unchanged)")
check_equal(f1$coefs$se, summary(ref1)$coefficients[, 2], "A1: conventional SE unchanged by the leverage-one handling")
check_equal(c(f1$r2, f1$f), c(summary(ref1)$r.squared, summary(ref1)$fstatistic[1]), "A1: R2 and overall F unchanged")
check(!all(is.finite(sqrt(diag(vcovHC(ref1, type = "HC3"))))), "A1: (reference) sandwich HC3 is not finite on this design, which is why the rule is needed")
check(fit$n_leverage_one == 0, "A1: n_leverage_one is 0 when no row has leverage one")
check(abs(resid(ref1)[7]) < 1e-8, "A1: (reference) the leverage-one row is fitted exactly, residual 0")
# two single-member groups -> two leverage-one rows, both zeroed
IND_S2 <- as.numeric(seq_len(n) == 11)
X2l <- cbind(X1, IND_S2 = IND_S2)
f2l <- fit_model(X2l, y)
ref2l <- lm(y ~ x1 + x2 + x3 + dA + dB + IND_S + IND_S2); h2 <- hatvalues(ref2l); keep2 <- h2 < 1 - 1e-8
XtXi2 <- solve(crossprod(X2l))
V3ref2 <- XtXi2 %*% crossprod(X2l[keep2, ] * (resid(ref2l)[keep2] / (1 - h2[keep2]))) %*% XtXi2
check(f2l$status == "ok" && f2l$n_leverage_one == 2 && sum(!keep2) == 2, "A1: two single-member groups give n_leverage_one = 2")
check_equal(f2l$coefs$se_hc3, sqrt(diag(V3ref2)), "A1: HC3 SE with two leverage-one rows zeroed match the explicit formula")
check_equal(f2l$coefs$se, summary(ref2l)$coefficients[, 2], "A1: conventional SE unchanged with two leverage-one rows")
# weighted: threshold on the weighted design
f1w <- fit_model(X1, y, w)
ref1w <- lm(y ~ x1 + x2 + x3 + dA + dB + IND_S, weights = w)
h1w <- hatvalues(ref1w); keepw <- h1w < 1 - 1e-8
Xw1 <- X1 * sqrt(w); ew1 <- resid(ref1w) * sqrt(w)
XtXiw <- solve(crossprod(Xw1))
V3refw <- XtXiw %*% crossprod(Xw1[keepw, ] * (ew1[keepw] / (1 - h1w[keepw]))) %*% XtXiw
check(f1w$n_leverage_one == 1, "A1: WLS leverage-one count from the weighted design")
check_equal(f1w$coefs$se_hc3, sqrt(diag(V3refw)), "A1: WLS HC3 SE equal the weighted-design formula with the leverage-one row zeroed")

# A5: nested-test numerator df must equal the number of added terms
nf6 <- nested_f(fit, fr, df1_required = 3)
check(nf6$status == "ok" && nf6$df1 == 3, "nested_f: ok when the rank increase equals the required df")
nfbad <- nested_f(fit, fr, df1_required = 6)
check(nfbad$status == "failed" && grepl("differs", nfbad$error) && is.na(nfbad$f), "A5: nested test failed with reason when the rank increase differs from the number of added terms")

res <- test_summary("test_ols")
