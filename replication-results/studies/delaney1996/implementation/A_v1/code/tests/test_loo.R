# test_loo.R -- leave-one-out refits on a small case against explicit lm() refits.
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "helpers.R"))

set.seed(7)
n <- 30
STAFF <- rnorm(n); TRAIN <- rnorm(n); C1 <- rnorm(n)
IND_A <- as.numeric(seq_len(n) %in% 1:10)
IND_B <- as.numeric(seq_len(n) == 5)       # single-row group: deleting row 5 makes it all zero
y <- 0.5 + 1.5 * STAFF - 0.7 * TRAIN + 0.3 * TRAIN * STAFF + C1 + rnorm(n)
X <- cbind("(Intercept)" = 1, STAFF = STAFF, TRAIN = TRAIN, TRAIN_x_STAFF = TRAIN * STAFF, C1 = C1, IND_A = IND_A, IND_B = IND_B)
V1 <- 1000 + seq_len(n)
fit <- fit_model(X, y)
fit$X <- X[, fit$terms, drop = FALSE]; fit$y <- y; fit$w <- NULL; fit$V1 <- V1
inf <- influence_loo(fit, "org_M4", c("STAFF", "TRAIN", "TRAIN_x_STAFF"))

check(nrow(inf) == 3 * n, "one row per deleted record and reported term")
check(all(inf$status == "ok"), "all leave-one-out refits succeed")
check(setequal(unique(inf$deleted_V1), V1), "every record deleted exactly once (V1 recorded)")
ok <- TRUE
for (i in seq_len(n)) {
  dd <- data.frame(y = y, STAFF = STAFF, TRAIN = TRAIN, C1 = C1, IND_A = IND_A, IND_B = IND_B)[-i, ]
  fml <- if (i == 5) y ~ STAFF * TRAIN + C1 + IND_A else y ~ STAFF * TRAIN + C1 + IND_A + IND_B
  ref <- summary(lm(fml, data = dd))$coefficients
  got <- inf[inf$deleted_V1 == V1[i], ]
  est <- got$estimate[match(c("STAFF", "TRAIN", "TRAIN_x_STAFF"), got$term)]
  se <- got$se[match(c("STAFF", "TRAIN", "TRAIN_x_STAFF"), got$term)]
  p2 <- got$p_two[match(c("STAFF", "TRAIN", "TRAIN_x_STAFF"), got$term)]
  pu <- got$p_upper[match(c("STAFF", "TRAIN", "TRAIN_x_STAFF"), got$term)]
  r_est <- ref[c("STAFF", "TRAIN", "STAFF:TRAIN"), 1]; r_se <- ref[c("STAFF", "TRAIN", "STAFF:TRAIN"), 2]
  r_t <- ref[c("STAFF", "TRAIN", "STAFF:TRAIN"), 3]; r_p <- ref[c("STAFF", "TRAIN", "STAFF:TRAIN"), 4]
  dfr <- nrow(dd) - nrow(ref)
  if (max(abs(est - r_est)) > 1e-9 || max(abs(se - r_se)) > 1e-9 || max(abs(p2 - r_p)) > 1e-9 ||
      max(abs(pu - pt(r_t, dfr, lower.tail = FALSE))) > 1e-9) ok <- FALSE
}
check(ok, "LOO estimates, SE, two-sided and upper-tail p match explicit lm() refits for every deletion")
check(all(grepl("IND_B \\(all zero\\)", inf$note[inf$deleted_V1 == V1[5]])), "deleting the only member of a group drops its dummy and flags it")
check(all(is.na(inf$note[inf$deleted_V1 != V1[5]])), "no flags on other deletions")
check(!isTRUE(all.equal(inf$estimate[inf$term == "STAFF"][1], fit$coefs$estimate[2])), "LOO estimates differ from the full-sample estimate")

# failure retention: a design where deleting a row leaves n <= k
Xs <- X[1:8, c("(Intercept)", "STAFF", "TRAIN", "TRAIN_x_STAFF", "C1", "IND_A")]
fs <- fit_model(Xs, y[1:8]); fs$X <- Xs[, fs$terms, drop = FALSE]; fs$y <- y[1:8]; fs$w <- NULL; fs$V1 <- V1[1:8]
Xs2 <- cbind(Xs, D1 = c(1, 0, 0, 0, 0, 0, 0, 0), D2 = c(0, 1, 0, 0, 0, 0, 0, 0))
# n = 8, k = 8 after dummies: full fit fails (no residual df); influence must record failure, not skip
ff <- fit_model(Xs2, y[1:8])
check(ff$status == "failed", "base fit with n <= k fails with reason")
infl <- influence_loo(ff, "org_M2", c("STAFF"))
check(nrow(infl) == 1 && infl$status == "failed" && grepl("not fitted", infl$note), "influence records a failed base model instead of skipping")

# weighted LOO against lm(weights=)
w <- runif(n, 0.5, 2)
fw <- fit_model(X, y, w); fw$X <- X[, fw$terms, drop = FALSE]; fw$y <- y; fw$w <- w; fw$V1 <- V1
infw <- influence_loo(fw, "org_M4", c("STAFF"))
i <- 12
refw <- summary(lm(y ~ STAFF * TRAIN + C1 + IND_A + IND_B, data = data.frame(y, STAFF, TRAIN, C1, IND_A, IND_B)[-i, ], weights = w[-i]))$coefficients
check_equal(c(infw$estimate[infw$deleted_V1 == V1[i]], infw$se[infw$deleted_V1 == V1[i]]), refw["STAFF", 1:2], "weighted LOO refit matches lm(weights=) with the row deleted")

res <- test_summary("test_loo")
