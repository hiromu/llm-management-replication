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

# column dropping: all-zero column and a collinear column
Xz <- cbind(X, IND_Z = 0, x1dup = 2 * x1)
fz <- fit_model(Xz, y)
check(fz$status == "ok", "fit with all-zero and collinear columns succeeds")
check(all(c("IND_Z (all zero)", "x1dup (collinear)") %in% fz$dropped), "all-zero and collinear columns are dropped and recorded")
check_equal(fz$coefs$estimate, coef(ref), "estimates unchanged after drops")
check(fz$n_ind == 2 && fz$k == 6, "n_industry_dummies and k reflect drops")

# failure recording
ff <- fit_model(X[1:4, ], y[1:4])
check(ff$status == "failed" && !is.na(ff$error), "n <= k is recorded as a failure with reason")
fna <- fit_model(X, replace(y, 1, NA))
check(fna$status == "failed" && grepl("missing", fna$error), "NA in outcome is recorded as a failure")

res <- test_summary("test_ols")
