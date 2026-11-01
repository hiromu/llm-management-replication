# EXPLORATORY, POST-HOC, NOT PART OF THE FROZEN PROTOCOL. Does not change any frozen classification.
# X4: staff_coding L1 (ln(1+x)) and, for a block whose 'hired from outside' item is No (V50/V85/V119 == 2),
#     the application count is taken as 0 (no openings filled from outside). Other variables as X2 (COMPET N/A -> 0,
#     PCTMGR V114==2 mapped CORE-first). Reported to test whether the STAFF candidates depend on non-hiring handling.
source("../../../runs/run_20261028_v1_1/code_A/k7_lib.R")
d <- read.csv("../../../runs/run_20261028_v1_1/inputs/survey.csv", check.names = FALSE)
f <- readRDS("frame_origin_A.rds"); stopifnot(all(f$V1 == d$V1))
item <- function(cnt, hired) { x <- ifelse(!is.na(cnt) & cnt >= 0 & cnt <= 994, log1p(cnt), NA); x[is.na(x) & hired %in% 2] <- 0; x }
z <- function(x) (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)
S <- cbind(z(item(d$V62, d$V50)), z(item(d$V97, d$V85)), z(item(d$V131, d$V119)))
f$STAFF <- make_index(S, "L0"); f$STAFF_valid <- !is.na(f$STAFF)
V45 <- d$V45; V80 <- d$V80; V45[V45 %in% c(99998, 99999)] <- NA; V80[V80 %in% c(99998, 99999)] <- NA
f$COMPET <- ifelse(d$V328 %in% 1:4, as.numeric(d$V328 == 4), ifelse(d$V328 == 7, 0, NA))
den <- d$V23 + d$V32; den[d$V23 %in% c(99998, 99999) | d$V32 %in% c(99998, 99999) | den == 0] <- NA
idx <- d$V114 == 2; f$PCTMGR[idx] <- 100 * ifelse(!is.na(V45), V45, V80)[idx] / den[idx]
cat("STAFF valid rows:", sum(f$STAFF_valid), "\n")
cat("pairwise r(PMP,STAFF) mkt frame:", round(cor(f$PMP[f$V8 == 1], f$STAFF[f$V8 == 1], use = "pairwise.complete.obs"), 3),
    " r(STAFF,LOGEMP):", round(cor(f$STAFF, f$LOGEMP, use = "pairwise.complete.obs"), 3), "\n")
spec <- list(weights = "L0", market_sample = "L0", market_requires_pop = "L0")
models <- list(org_M2 = c("STAFF","TRAIN","INCENT","GRIEV","DECENT","ILM"), org_M3 = c("STAFF","TRAIN","INCENT","GRIEV","DECENT","VHIER"),
               mkt_M7 = c("STAFF","TRAIN","INCENT","GRIEV","DECENT","ILM"), mkt_M8 = c("STAFF","TRAIN","INCENT","GRIEV","DECENT","VHIER"))
out <- list()
for (fam in c("org", "mkt")) {
  rows <- family_sample_L0(f, fam, spec); dg <- industry_dummy_groups(f$IND[rows])
  for (mid in grep(paste0("^", fam), names(models), value = TRUE)) {
    fit <- fit_model(build_design(f, rows, models[[mid]], character(0), family_controls(fam), dg), f[[family_outcome(fam)]][rows])
    cf <- fit$coefs[fit$coefs$term %in% c(HRM_TERMS, "SUBSID", "UNION"), c("term", "estimate", "se", "p_upper")]
    out[[length(out) + 1]] <- cbind(config = "X4", model_id = mid, n = fit$n, cf)
  }
}
res <- do.call(rbind, out); res[, 5:7] <- round(res[, 5:7], 4); print(res, row.names = FALSE)
write.csv(res, "exploratory_refits_X4_EXPLORATORY_POSTHOC.csv", row.names = FALSE)
