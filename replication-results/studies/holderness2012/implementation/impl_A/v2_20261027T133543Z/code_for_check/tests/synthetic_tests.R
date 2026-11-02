# Synthetic validation of the estimation machinery in run.R (no real data used).
# Run from the project folder:  Rscript tests/synthetic_tests.R
# Writes tests/test_log.txt.
src <- if (file.exists("run.R")) "run.R" else file.path("..", "run.R")
source(src)
log_path <- file.path(dirname(src), "tests", "test_log.txt")
if (file.exists(log_path)) file.remove(log_path)
tlog <- function(...) { msg <- paste0(..., collapse = ""); cat(msg, "\n"); cat(msg, "\n", file = log_path, append = TRUE) }
n_fail <- 0
check <- function(name, cond, detail = "") {
  if (isTRUE(cond)) tlog("PASS ", name, if (nzchar(detail)) paste0("  [", detail, "]")) else { n_fail <<- n_fail + 1; tlog("FAIL ", name, "  [", detail, "]") }
}
set.seed(20261027)
tlog("Synthetic tests, ", format(Sys.time()), ", ", R.version.string)

# ---------------------------------------------------------------- 1. probit recovers known coefficients
tlog("--- Test 1: probit with known coefficients")
N <- 20000
x1 <- rnorm(N); x2 <- rbinom(N, 1, 0.4); x3 <- runif(N)
beta <- c(0.3, -0.5, 0.8, 1.2)
ystar <- beta[1] + beta[2] * x1 + beta[3] * x2 + beta[4] * x3 + rnorm(N)
y <- as.numeric(ystar > 0)
Xd <- cbind("(Intercept)" = 1, x1 = x1, x2 = x2, x3 = x3)
fit <- probit_newton(y, Xd)
ref <- glm(y ~ x1 + x2 + x3, family = binomial(link = "probit"))
tlog("  true: ", paste(sprintf("%.3f", beta), collapse = " "), " | estimated: ", paste(sprintf("%.3f", fit$coef), collapse = " "),
     " | glm: ", paste(sprintf("%.3f", coef(ref)), collapse = " "))
check("1a coefficients within 4 SE of truth", all(abs(fit$coef - beta) / sqrt(diag(solve(-optimHess(fit$coef, function(b) probit_ll(y, Xd %*% b))))) < 4),
      sprintf("max |b - beta| = %.4f", max(abs(fit$coef - beta))))
check("1b coefficients equal glm probit", max(abs(fit$coef - coef(ref))) < 1e-6, sprintf("max diff = %.2e", max(abs(fit$coef - coef(ref)))))
check("1c log likelihood equals glm", abs(fit$ll - as.numeric(logLik(ref))) < 1e-6, sprintf("diff = %.2e", fit$ll - as.numeric(logLik(ref))))
check("1d converged flag", fit$converged, sprintf("iterations = %d", fit$iter))
# with fixed effects
G <- 12
fe_id <- sample.int(G, N, replace = TRUE)
alpha <- c(0, rnorm(G - 1, 0, 0.7))
y2 <- as.numeric(beta[1] + beta[2] * x1 + beta[3] * x2 + beta[4] * x3 + alpha[fe_id] + rnorm(N) > 0)
fe <- fe_id; attr(fe, "levels") <- as.character(seq_len(G))
fit2 <- probit_newton(y2, Xd, fe)
ref2 <- glm(y2 ~ x1 + x2 + x3 + factor(fe_id), family = binomial(link = "probit"))
check("1e FE model coefficients equal glm with dummies", max(abs(fit2$coef - coef(ref2))) < 1e-6, sprintf("max diff = %.2e", max(abs(fit2$coef - coef(ref2)))))
check("1f FE model recovers true camp effects (max abs error < 0.15)", max(abs(fit2$coef[5:(G + 3)] - alpha[-1])) < 0.15, sprintf("max abs error = %.3f", max(abs(fit2$coef[5:(G + 3)] - alpha[-1]))))

# ---------------------------------------------------------------- 2. marginal effects and delta method vs finite differences
tlog("--- Test 2: marginal effects at means and delta-method SEs vs numerical finite differences")
binary <- c("x2")
xbar <- design_means(fit)
me <- marginal_effects(fit$coef, xbar, binary)
me_num <- function(b) { b <- setNames(b, names(fit$coef)); marginal_effects(b, xbar, binary)$me }
# numerical ME check: derivative of Phi(xbar'b) wrt x_k for continuous, discrete change for binary
z <- sum(xbar * fit$coef); h <- 1e-6
me_fd <- c(NA, (pnorm(z + h * fit$coef[2]) - pnorm(z - h * fit$coef[2])) / (2 * h),
           pnorm(sum(replace(xbar, 3, 1) * fit$coef)) - pnorm(sum(replace(xbar, 3, 0) * fit$coef)),
           (pnorm(z + h * fit$coef[4]) - pnorm(z - h * fit$coef[4])) / (2 * h))
check("2a marginal effects match finite-difference derivative/discrete change", max(abs(me$me[-1] - me_fd[-1])) < 1e-7, sprintf("max diff = %.2e", max(abs(me$me[-1] - me_fd[-1]))))
Jnum <- matrix(0, 4, 4)
for (j in 1:4) { e <- rep(0, 4); e[j] <- 1e-6; Jnum[, j] <- (me_num(fit$coef + e) - me_num(fit$coef - e)) / 2e-6 }
Jnum[1, ] <- 0
check("2b delta-method gradient matches numerical Jacobian", max(abs(me$J - Jnum)) < 1e-6, sprintf("max diff = %.2e", max(abs(me$J - Jnum))))
clus_id <- sample.int(200, N, replace = TRUE)
V <- vcov_cluster(fit, clus_id)$V
se_a <- me_se_p(me$J, V); se_n <- sqrt(diag(Jnum %*% V %*% t(Jnum))); se_n[1] <- NA
check("2c delta-method SEs match numerical-Jacobian SEs", max(abs(se_a[-1] - se_n[-1])) < 1e-8, sprintf("max diff = %.2e; SEs = %s", max(abs(se_a[-1] - se_n[-1])), paste(sprintf("%.5f", se_a[-1]), collapse = " ")))
tlog("  ME at means: ", paste(sprintf("%s=%.4f (se %.4f)", names(fit$coef)[-1], me$me[-1], se_a[-1]), collapse = ", "))

# ---------------------------------------------------------------- 3. cluster-robust covariance vs direct sandwich on a tiny example
tlog("--- Test 3: cluster-robust covariance vs direct sandwich (tiny example, with camp dummies)")
n <- 60
xa <- rnorm(n); xb <- rbinom(n, 1, 0.5); camp <- rep(1:4, each = 15); clus <- rep(1:12, each = 5)
yt <- as.numeric(0.2 + 0.7 * xa - 0.4 * xb + c(0, 0.5, -0.5, 0.3)[camp] + rnorm(n) > 0)
Xs <- cbind("(Intercept)" = 1, xa = xa, xb = xb)
fes <- camp; attr(fes, "levels") <- as.character(1:4)
fit3 <- probit_newton(yt, Xs, fes)
Vmine <- vcov_cluster(fit3, clus)$V
# direct: full dense design, per-observation numerical scores, numerical Hessian
Xfull <- cbind(Xs, camp_2 = as.numeric(camp == 2), camp_3 = as.numeric(camp == 3), camp_4 = as.numeric(camp == 4))
lli <- function(b) ifelse(yt == 1, pnorm(Xfull %*% b, log.p = TRUE), pnorm(Xfull %*% b, lower.tail = FALSE, log.p = TRUE))
b <- fit3$coef
scores <- matrix(0, n, length(b))
for (j in seq_along(b)) { e <- rep(0, length(b)); e[j] <- 1e-6; scores[, j] <- (lli(b + e) - lli(b - e)) / 2e-6 }
Hn <- optimHess(b, function(bb) sum(lli(bb)))
bread <- solve(-Hn)
Sg <- rowsum(scores, clus)
Gc <- nrow(Sg)
Vdirect <- bread %*% crossprod(Sg) %*% bread * Gc / (Gc - 1)
check("3a cluster-robust covariance equals direct sandwich", max(abs(Vmine - Vdirect)) / max(abs(Vdirect)) < 1e-5,
      sprintf("max rel diff = %.2e", max(abs(Vmine - Vdirect)) / max(abs(Vdirect))))
# also check the bread: analytic observed Hessian vs numerical
Hmine <- solve(fit3$Hinv)
check("3b analytic observed Hessian equals numerical Hessian", max(abs(Hmine - (-Hn))) / max(abs(Hn)) < 1e-5, sprintf("max rel diff = %.2e", max(abs(Hmine - (-Hn))) / max(abs(Hn))))
tlog("  cluster SEs: ", paste(sprintf("%.4f", sqrt(diag(Vmine))), collapse = " "))

# ---------------------------------------------------------------- 4. Steepness and Sameness on hand-made groups
tlog("--- Test 4: Steepness and Sameness formulas")
p_ref <- c(0.5, 0.2, 0.1, 0.05, 0.05, 0.04, 0.03, 0.02, 0.01)
# group B: 100 members with rank counts 50,20,10,5,5,4,3,2,1 -> shares exactly p_ref
gs <- group_stats(c(rep("A", 5), rep("B", 100), rep("C", 1), rep("D", 4)),
                  c(rep(3, 5), rep(1:9, c(50, 20, 10, 5, 5, 4, 3, 2, 1)), 7, c(1, 1, 9, 9)), p_ref, 1.319)
check("4a one rank only gives Steepness 0", abs(gs[g == "A", steepness]) < 1e-12, sprintf("S = %.3e", gs[g == "A", steepness]))
check("4b single member gives Steepness 0", abs(gs[g == "C", steepness]) < 1e-12, sprintf("S = %.3e", gs[g == "C", steepness]))
check("4c group with shares equal to reference gives Sameness 1", abs(gs[g == "B", sameness] - 1) < 1e-12, sprintf("M = %.6f", gs[g == "B", sameness]))
check("4d group with shares equal to reference: ratio and absdev sameness = 1",
      abs(gs[g == "B", ratio_sameness] - 1) < 1e-12 && abs(gs[g == "B", absdev_sameness] - 1) < 1e-12)
# hand computation for group D (ranks 1,1,9,9): n=4, sorted r=(1,1,9,9), sum=20
#   S = 1 + 1/4 - 2*(4*1 + 3*1 + 2*9 + 1*9)/(4*20) = 1.25 - 2*34/80 = 0.4
check("4e Steepness hand value for ranks (1,1,9,9) = 0.4", abs(gs[g == "D", steepness] - 0.4) < 1e-12, sprintf("S = %.6f", gs[g == "D", steepness]))
fD <- c(0.5, 0, 0, 0, 0, 0, 0, 0, 0.5)
check("4f Sameness hand value for group D", abs(gs[g == "D", sameness] - (1 - sum((fD - p_ref)^2) / 1.319)) < 1e-12, sprintf("M = %.6f", gs[g == "D", sameness]))
check("4g absolute-deviation sameness hand value for group D", abs(gs[g == "D", absdev_sameness] - (1 - sum(abs(fD - p_ref)) / (2 * (1 - p_ref[9])))) < 1e-12)
check("4h n_g, distinct ranks, sum of ranks, admin intensity for group D",
      gs[g == "D", n_g] == 4 && gs[g == "D", n_distinct_ranks] == 2 && gs[g == "D", sum_ranks] == 20 && abs(gs[g == "D", admin_intensity] - 50) < 1e-12)
# Steepness is a Gini: ranks (1,2,3,4) -> Gini = 0.25 (ordered Gini for n=4: 1 + 1/4 - 2*(4+6+6+4)/(4*10) = 0.25)
gs2 <- group_stats(rep("E", 4), 1:4, p_ref, 1.319)
check("4i Steepness for ranks 1..4 equals 0.25", abs(gs2$steepness - 0.25) < 1e-12, sprintf("S = %.6f", gs2$steepness))
tlog("  recomputed sameness constant for p_ref: ", sprintf("%.4f", (1 - p_ref[9])^2 + sum(p_ref[1:8]^2)))

# ---------------------------------------------------------------- 5. DeLong test
tlog("--- Test 5: DeLong test")
yy <- rbinom(500, 1, 0.5); s1 <- yy + rnorm(500); s2 <- s1
d0 <- delong_test(s1, s2, yy)
check("5a identical predictors give z = 0 and p = 1", d0$z == 0 && d0$p == 1 && d0$diff == 0, sprintf("auc = %.4f", d0$auc1))
# AUC equals Mann-Whitney statistic
w <- wilcox.test(s1[yy == 1], s1[yy == 0], exact = FALSE)$statistic / (sum(yy == 1) * sum(yy == 0))
check("5b AUC equals Mann-Whitney U / (m n)", abs(d0$auc1 - w) < 1e-12, sprintf("auc = %.6f, U/(mn) = %.6f", d0$auc1, w))
# ties handled: constant predictor has AUC 0.5
d1 <- delong_test(rep(0.3, 500), s1, yy)
check("5c constant predictor has AUC 0.5", abs(d1$auc1 - 0.5) < 1e-12)
# a genuinely better predictor gives a large |z| (sanity)
s3 <- yy + rnorm(500, sd = 5)
d2 <- delong_test(s1, s3, yy)
check("5d better predictor vs noisy predictor gives |z| > 3", abs(d2$z) > 3, sprintf("auc1 = %.3f auc2 = %.3f z = %.2f p = %.2e", d2$auc1, d2$auc2, d2$z, d2$p))
# variance check against the explicit DeLong formula with the 10/01 components computed by double loops
pos <- which(yy == 1); neg <- which(yy == 0)
V10 <- function(s) sapply(pos, function(i) mean((s[i] > s[neg]) + 0.5 * (s[i] == s[neg])))
V01 <- function(s) sapply(neg, function(j) mean((s[pos] > s[j]) + 0.5 * (s[pos] == s[j])))
S10 <- cov(cbind(V10(s1), V10(s3))); S01 <- cov(cbind(V01(s1), V01(s3)))
vv <- (S10[1, 1] + S10[2, 2] - 2 * S10[1, 2]) / length(pos) + (S01[1, 1] + S01[2, 2] - 2 * S01[1, 2]) / length(neg)
check("5e DeLong variance equals double-loop computation", abs(d2$var - vv) < 1e-14, sprintf("var = %.3e", vv))

# ---------------------------------------------------------------- 6. design builder: missing indicators and constants
tlog("--- Test 6: design builder")
mf <- data.table(a = c(1, NA, 3, 4), japan = c(1, 1, 1, 1), b = c(NA, NA, NA, NA), officer = c(0, 1, NA, 1))
D <- build_design(mf, c("a", "japan", "b", "officer"), list(c("officer", "a")))
check("6a missing -> 0 with indicator; all-missing and constant columns dropped; product gets its own indicator",
      identical(colnames(D$X), c("(Intercept)", "a", "officer", "officer_x_a", "a_miss", "officer_miss", "officer_x_a_miss")) && setequal(D$dropped, c("japan", "b", "b_miss")),
      paste0("kept: ", paste(colnames(D$X), collapse = ","), "; dropped: ", paste(D$dropped, collapse = ",")))
check("6b binary set = officer and indicators (product indicator included)", setequal(D$binary, c("officer", "a_miss", "officer_miss", "officer_x_a_miss")))
check("6c interaction uses imputed values", identical(as.numeric(D$X[, "officer_x_a"]), c(0, 0, 0, 4)))
check("6d product missing indicator = 1 where either component is missing", identical(as.numeric(D$X[, "officer_x_a_miss"]), c(0, 1, 1, 0)))
# a product whose components are never missing gets no indicator
D2 <- build_design(data.table(a = c(1, 2, 3, 4), officer = c(0, 1, 0, 1)), c("a", "officer"), list(c("officer", "a")))
check("6e no product indicator when no component is missing", identical(colnames(D2$X), c("(Intercept)", "a", "officer", "officer_x_a")))

# ---------------------------------------------------------------- 8. raw string conversion (NUL removed, other bytes kept)
tlog("--- Test 8: raw -> string conversion keeps every non-NUL byte")
rx <- list(as.raw(c(0x41, 0x00, 0x42, 0x20)), as.raw(c(0x20, 0xe9, 0x5a, 0x00)), raw(0), as.raw(c(0x30, 0x30, 0x31)))
rs <- raw_to_chr(rx)
check("8a NUL bytes removed, lengths preserved", identical(nchar(rs), c(3L, 3L, 0L, 3L)) && rs[1] == "AB " && rs[4] == "001", paste(rs, collapse = "|"))
check("8b a byte above 0x7f is kept (not replaced by ?)", identical(charToRaw(rs[2]), as.raw(c(0x20, 0xe9, 0x5a))) && !grepl("?", rs[2], fixed = TRUE))
check("8c cleaning then works on such strings", cl(rs)[1] == "AB" && nchar(cl(rs)[2]) == 2 && cl(rs)[3] == "")

# ---------------------------------------------------------------- 9. cleaning before code comparisons; nara_degree fallback
tlog("--- Test 9: code list and crosswalk cleaning; nara_degree coordinates")
tmpcl <- tempfile(fileext = ".csv")
writeLines(c("Code,Meaning,Comments", '" 001 ","Camp one \\x00","x"', '"002\\x00","Camp two","y"', '"0 3","Camp "three"","z"'), tmpcl)
codes <- read_code_list_codes(tmpcl)
check("9a code list codes are cleaned (NUL escape text removed, trimmed)", identical(codes, c("001", "002", "0 3")), paste(codes, collapse = "|"))
cwt <- data.table(camp_code = c("001", "002", "003", "004", "005", "005"), entry_id = c("1", "2", "3", "4", "5a", "5b"),
                  confidence = c(" exact ", "exact", "approximate", "exact", "unknown", "exact"),
                  identified_place_name = c("Berlin ", "A", "B", "C", "", "D"),
                  nara_degree_coords_text = c("", "40-116; 44-26", "abc", "49- 0", "", "  "),
                  latitude = c("52.5", "10", "20", "30", "", "50"), longitude = c("13.4", "10", "20", "30", "", "60"))
cwt[, code := cl(camp_code)]; cwt[, confidence := cl(confidence)]; cwt[, identified_place_name := cl(identified_place_name)]
cwt[, nara_degree_coords_text := cl(nara_degree_coords_text)]
cwt[, lat := as.numeric(latitude)]; cwt[, lon := as.numeric(longitude)]
c1 <- camp_coordinates(cwt, "crosswalk")
check("9b padded confidence value is accepted after cleaning; place name cleaned", c1[code == "001", use_lat] == 52.5 && c1[code == "001", place] == "Berlin")
check("9c first exact/approximate row per code (unknown row skipped)", c1[code == "005", use_lat] == 50)
c2 <- camp_coordinates(cwt, "nara_degree")
check("9d nara_degree: absent text -> crosswalk coordinates", c2[code == "001", use_lat] == 52.5 && c2[code == "005", use_lon] == 60)
check("9e nara_degree: text parsed as whole degrees (first pair; internal spaces ignored)",
      c2[code == "002", use_lat] == 40 && c2[code == "002", use_lon] == 116 && c2[code == "004", use_lat] == 49 && c2[code == "004", use_lon] == 0)
check("9f nara_degree: present but unparsable text -> missing (no fallback)", is.na(c2[code == "003", use_lat]) && is.na(c2[code == "003", use_lon]))

# ---------------------------------------------------------------- 10. dup_serial = "combine" over the original record fields
tlog("--- Test 10: duplicate enlistment records combined field by field before the card layout")
e <- data.table(ser_key = c("A", "A", "B", "B", "C", "D", "D"), record_seq = c(2, 1, 3, 4, 5, 6, 7),
                CARD_NUM = c("1", "3", "1", "1", "3", "1", "1"),
                HEIGHT = c("70", "", "66", "66", "", "60", "61"), ERC_HEIGHT = c("", "99", "", "", "72", "", ""),
                YR_BIRTH = c("20", "", "15", "", "", "18", "18"), ERC_YR_BIRTH = c("", "", "", "", "22", "", ""),
                EDUCATION = c("4", "", "9", "8", "", "3", "3"), ERC_EDUCATION = c("", "", "", "", "6", "", ""),
                MARITAL_STATUS = c("1", "", "6", "", "", "2", "2"), ERC_MARITAL_STATUS = c("", "", "", "", "7", "", ""))
e[, n_dup := .N, by = ser_key]
P0 <- list(dup_serial = "combine", height_rule = "range", age_rule = "range", educ_postgrad = 9, married = 1)
ec <- enl_covariates(e, P0)
check("10a serial A: CARD_NUM disagrees -> blank -> standard layout; HEIGHT taken from the only non-blank duplicate",
      ec[ser_key == "A", height] == 7.0 && ec[ser_key == "A", age] == 0.25 && ec[ser_key == "A", education] == 0.4 && ec[ser_key == "A", dependents] == 1)
check("10b serial B: agreeing field kept, disagreeing field missing, blank-vs-value keeps the value",
      ec[ser_key == "B", height] == 6.6 && is.na(ec[ser_key == "B", education]) && ec[ser_key == "B", age] == 0.30 && ec[ser_key == "B", dependents] == 0)
check("10c single records unchanged (CARD_NUM 3 uses ERC fields)", ec[ser_key == "C", height] == 7.2 && ec[ser_key == "C", age] == 0.23 && ec[ser_key == "C", education] == 0.6 && ec[ser_key == "C", dependents] == 0)
check("10d serial D: HEIGHT disagrees -> missing, other fields agree", is.na(ec[ser_key == "D", height]) && ec[ser_key == "D", age] == 0.27)
check("10e one row per serial", nrow(ec) == 4 && !any(duplicated(ec$ser_key)))
ecf <- enl_covariates(e, modifyList(P0, list(dup_serial = "first")))
check("10f 'first' uses the smallest record_seq (serial A -> record 1, CARD_NUM 3, ERC height 99 -> out of range -> missing)", is.na(ecf[ser_key == "A", height]) && ecf[ser_key == "B", height] == 6.6)
ecu <- enl_covariates(e, modifyList(P0, list(dup_serial = "unmatched")))
check("10g 'unmatched' keeps only serials with one record", identical(ecu$ser_key, "C"))

# ---------------------------------------------------------------- 11. complete-case filter is bound to its group type
tlog("--- Test 11: R_cc filter: distance required for camp models only")
defs_cc <- model_defs("R_cc", list())
mfx <- data.table(height = 1, age = 1, education = 1, dependents = 1, officer = 1, distance = NA_real_)
check("11a cap complete-case filter does not require distance", isTRUE(defs_cc[["Rcc_steepness_cap_full"]]$filter(mfx)))
check("11b camp complete-case filter requires distance", isFALSE(defs_cc[["Rcc_steepness_camp_full"]]$filter(mfx)))

# ---------------------------------------------------------------- 12. marginal effects of camp dummies are discrete changes
tlog("--- Test 12: camp dummies treated as binary regressors")
set.seed(3)
nn <- 3000; cp <- sample(c("A", "B", "C"), nn, TRUE); xx <- rnorm(nn)
mf12 <- data.table(record_seq = seq_len(nn), survival = as.numeric(0.2 + 0.5 * xx + c(A = 0, B = 0.6, C = -0.4)[cp] + rnorm(nn) > 0),
                   steepness = xx, camp = cp, cohort = paste0(cp, sample(1:5, nn, TRUE)))
m12 <- list(model_id = "x", family = "T4", gtype = "cap", vars = "steepness", inter = list(), filter = NULL, fe = TRUE, hier = "steepness", members = "all")
f12 <- fit_model(mf12, m12)
xbar <- design_means(f12); kB <- match("camp_B", names(f12$coef))
disc <- pnorm(sum(replace(xbar, kB, 1) * f12$coef)) - pnorm(sum(replace(xbar, kB, 0) * f12$coef))
check("12a camp dummies are in the binary set", all(c("camp_B", "camp_C") %in% f12$binary))
check("12b camp dummy ME equals the discrete change", abs(f12$me[kB] - disc) < 1e-12 && abs(f12$me[kB] - dnorm(sum(xbar * f12$coef)) * f12$coef[kB]) > 1e-6,
      sprintf("me = %.5f, discrete = %.5f, derivative = %.5f", f12$me[kB], disc, dnorm(sum(xbar * f12$coef)) * f12$coef[kB]))

tlog("=== ", if (n_fail == 0) "ALL TESTS PASSED" else paste(n_fail, "TEST(S) FAILED"))
if (n_fail > 0) quit(status = 1)
