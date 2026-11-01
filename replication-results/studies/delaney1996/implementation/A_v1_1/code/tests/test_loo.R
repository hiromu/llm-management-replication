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

# A1 in the original fit: row 5 is the only member of IND_B, so it has leverage one
check(fit$n_leverage_one == 1 && all(is.finite(fit$coefs$se_hc3)), "original fit: leverage-one row counted, HC3 finite")

# A5 in the refits: the original design has n = k + 1 with IND_A collinear-free; use a design
# where deleting one row makes IND_B all zero AND leaves n = k (no residual df) -> refit fails
Xs <- X[1:8, c("(Intercept)", "STAFF", "TRAIN", "TRAIN_x_STAFF", "C1", "IND_A")]
Xs[, "IND_A"] <- c(1, 1, 0, 0, 1, 0, 0, 0)
Xs <- cbind(Xs, IND_B = c(0, 0, 0, 1, 0, 0, 0, 0))   # n = 8, k = 7, df = 1
fs <- fit_model(Xs, y[1:8]); fs$X <- Xs[, fs$terms, drop = FALSE]; fs$y <- y[1:8]; fs$w <- NULL; fs$V1 <- V1[1:8]
check(fs$status == "ok" && fs$df == 1, "small design fits with df = 1")
infs <- influence_loo(fs, "org_M2", c("STAFF"))
check(nrow(infs) == 8 && sum(infs$status == "failed") == 7, "A5/A6: refits with n = k fail and are retained (one row each), the deletion that frees a dummy succeeds")
check(infs$status[infs$deleted_V1 == V1[4]] == "ok" && grepl("IND_B \\(all zero\\)", infs$note[infs$deleted_V1 == V1[4]]), "A5: deleting the only member of IND_B drops the dummy before the df check, so that refit succeeds")
check(all(grepl("no positive residual df", infs$note[infs$status == "failed"])), "failed refits carry the reason")

# A5 in the refits: a deletion that makes a non-industry term constant fails the refit with that reason
Xg <- cbind(X[, c("(Intercept)", "STAFF", "TRAIN", "C1", "IND_A")], GRIEV = as.numeric(seq_len(n) != 3))
fg <- fit_model(Xg, y); fg$X <- Xg[, fg$terms, drop = FALSE]; fg$y <- y; fg$w <- NULL; fg$V1 <- V1
infg <- influence_loo(fg, "org_M2", c("STAFF", "GRIEV"))
bad <- infg[infg$deleted_V1 == V1[3], ]
check(nrow(bad) == 1 && bad$status == "failed" && grepl("collinear", bad$note) && grepl("GRIEV", bad$note), "A5: refit fails with reason when a deletion makes a non-industry term constant (never a reduced model)")
check(all(infg$status[infg$deleted_V1 != V1[3]] == "ok"), "other deletions succeed")

# A6: a failed original model still yields one failed influence row per estimation-sample record
Xs2 <- cbind(Xs[, 1:6], D1 = c(1, 0, 0, 0, 0, 0, 0, 0), D2 = c(0, 1, 0, 0, 0, 0, 0, 0))   # 8 full-rank columns, n = 8
ff <- fit_model(Xs2, y[1:8]); ff$y <- y[1:8]; ff$w <- NULL; ff$V1 <- V1[1:8]
check(ff$status == "failed" && grepl("no positive residual df", ff$error), "base fit with no residual df fails with reason")
infl <- influence_loo(ff, "org_M2", c("STAFF"))
check(nrow(infl) == 8 && all(infl$status == "failed") && all(grepl("original model not fitted", infl$note)) && setequal(infl$deleted_V1, V1[1:8]),
      "A6: failed original model -> one failed row per estimation-sample record with the reason")
check(all(is.na(infl$term)) && all(is.na(infl$estimate)), "A6: those rows have NA term and statistics")

# weighted LOO against lm(weights=)
w <- runif(n, 0.5, 2)
fw <- fit_model(X, y, w); fw$X <- X[, fw$terms, drop = FALSE]; fw$y <- y; fw$w <- w; fw$V1 <- V1
infw <- influence_loo(fw, "org_M4", c("STAFF"))
i <- 12
refw <- summary(lm(y ~ STAFF * TRAIN + C1 + IND_A + IND_B, data = data.frame(y, STAFF, TRAIN, C1, IND_A, IND_B)[-i, ], weights = w[-i]))$coefficients
check_equal(c(infw$estimate[infw$deleted_V1 == V1[i]], infw$se[infw$deleted_V1 == V1[i]]), refw["STAFF", 1:2], "weighted LOO refit matches lm(weights=) with the row deleted")

res <- test_summary("test_loo")
