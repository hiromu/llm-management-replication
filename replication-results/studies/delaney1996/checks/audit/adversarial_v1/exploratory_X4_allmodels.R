# EXPLORATORY, POST-HOC, NOT PART OF THE FROZEN PROTOCOL. Same X4 construction as exploratory_staff_X4.R,
# fitted for every reported model (single-practice, A, B, A+int, B+int) so each discrepant-candidate cell can be
# evaluated diagnostically. Output mimics coefficients.csv for spec_id "X4". Does not change any frozen classification.
source("../../../runs/run_20261028_v1_1/code_A/k7_lib.R")
d <- read.csv("../../../runs/run_20261028_v1_1/inputs/survey.csv", check.names = FALSE)
f <- readRDS("frame_origin_A.rds"); stopifnot(all(f$V1 == d$V1))
item <- function(cnt, hired) { x <- ifelse(!is.na(cnt) & cnt >= 0 & cnt <= 994, log1p(cnt), NA); x[is.na(x) & hired %in% 2] <- 0; x }
z <- function(x) (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)
f$STAFF <- make_index(cbind(z(item(d$V62, d$V50)), z(item(d$V97, d$V85)), z(item(d$V131, d$V119))), "L0"); f$STAFF_valid <- !is.na(f$STAFF)
V45 <- d$V45; V80 <- d$V80; V45[V45 %in% c(99998, 99999)] <- NA; V80[V80 %in% c(99998, 99999)] <- NA
f$COMPET <- ifelse(d$V328 %in% 1:4, as.numeric(d$V328 == 4), ifelse(d$V328 == 7, 0, NA))
den <- d$V23 + d$V32; den[d$V23 %in% c(99998, 99999) | d$V32 %in% c(99998, 99999) | den == 0] <- NA
idx <- d$V114 == 2; f$PCTMGR[idx] <- 100 * ifelse(!is.na(V45), V45, V80)[idx] / den[idx]
spec <- list(weights = "L0", market_sample = "L0", market_requires_pop = "L0")
out <- list(); st <- list()
for (fam in c("org", "mkt")) {
  rows <- family_sample_L0(f, fam, spec); dg <- industry_dummy_groups(f$IND[rows])
  ml <- model_list(fam)
  for (mid in names(ml)) {
    fit <- fit_model(build_design(f, rows, ml[[mid]]$hrm, ml[[mid]]$int, family_controls(fam), dg), f[[family_outcome(fam)]][rows])
    out[[length(out) + 1]] <- cbind(spec_id = "X4", family = fam, model_id = mid, fit$coefs)
    st[[length(st) + 1]] <- data.frame(spec_id = "X4", family = fam, model_id = mid, status = fit$status, n = fit$n, r2 = fit$r2, f = fit$f, f_p = fit$f_p)
  }
}
write.csv(do.call(rbind, out), "X4_coefficients_EXPLORATORY_POSTHOC.csv", row.names = FALSE)
write.csv(do.call(rbind, st), "X4_model_stats_EXPLORATORY_POSTHOC.csv", row.names = FALSE)
print(do.call(rbind, st)[, c("model_id", "n", "r2")])
