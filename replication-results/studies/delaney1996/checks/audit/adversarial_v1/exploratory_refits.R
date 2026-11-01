# EXPLORATORY, POST-HOC, NOT PART OF THE FROZEN PROTOCOL. Does not change any frozen classification.
# Configurations declared before running (see REVIEW.md):
#  X0 origin reproduction with code_A functions (sanity check against out_A)
#  X1 COMPET = 1 if V328 == 4 else 0, with code 7 (not applicable) -> 0 (code 9 missing)
#  X2 X1 + PCTMGR for V114 == 2 using the CORE count V45 (else GSS count V80) as numerator (Fable A15.L0; CORE-first is an arbitrary choice)
#  X3 X2 + STAFF set to 0 (the z-score mean) where no STAFF item is valid (mean substitution; no documented basis)
source("../../../runs/run_20261028_v1_1/code_A/k7_lib.R")
d <- read.csv("../../../runs/run_20261028_v1_1/inputs/survey.csv", check.names = FALSE)
f0 <- readRDS("frame_origin_A.rds"); stopifnot(all(f0$V1 == d$V1))
V45 <- d$V45; V80 <- d$V80; V45[V45 %in% c(99998, 99999)] <- NA; V80[V80 %in% c(99998, 99999)] <- NA
cfg <- function(id) {
  f <- f0
  if (id %in% c("X1", "X2", "X3")) f$COMPET <- ifelse(d$V328 %in% 1:4, as.numeric(d$V328 == 4), ifelse(d$V328 == 7, 0, NA))
  if (id %in% c("X2", "X3")) {
    num2 <- ifelse(!is.na(V45), V45, V80)
    den <- d$V23 + d$V32; den[d$V23 %in% c(99998, 99999) | d$V32 %in% c(99998, 99999) | den == 0] <- NA
    idx <- d$V114 == 2
    f$PCTMGR[idx] <- 100 * num2[idx] / den[idx]
  }
  if (id == "X3") { f$STAFF[is.na(f$STAFF)] <- 0; f$STAFF_valid <- TRUE }
  f
}
spec <- list(weights = "L0", market_sample = "L0", market_requires_pop = "L0")
models <- list(org_M2 = c("STAFF","TRAIN","INCENT","GRIEV","DECENT","ILM"), org_M3 = c("STAFF","TRAIN","INCENT","GRIEV","DECENT","VHIER"),
               mkt_M7 = c("STAFF","TRAIN","INCENT","GRIEV","DECENT","ILM"), mkt_M8 = c("STAFF","TRAIN","INCENT","GRIEV","DECENT","VHIER"))
out <- list()
for (id in c("X0", "X1", "X2", "X3")) {
  f <- cfg(id)
  for (fam in c("org", "mkt")) {
    rows <- family_sample_L0(f, fam, spec)
    dg <- industry_dummy_groups(f$IND[rows])
    for (mid in grep(paste0("^", fam), names(models), value = TRUE)) {
      X <- build_design(f, rows, models[[mid]], character(0), family_controls(fam), dg)
      fit <- fit_model(X, f[[family_outcome(fam)]][rows])
      cf <- fit$coefs[fit$coefs$term %in% c(HRM_TERMS, "SUBSID", "UNION", "COMPET", "PCTMGR"), c("term", "estimate", "se", "p_upper", "p_lower")]
      out[[length(out) + 1]] <- cbind(config = id, model_id = mid, n = fit$n, cf)
    }
  }
}
res <- do.call(rbind, out); res[, 5:8] <- round(res[, 5:8], 4)
print(res, row.names = FALSE)
write.csv(res, "exploratory_refits_EXPLORATORY_POSTHOC.csv", row.names = FALSE)
# sanity: X0 vs out_A origin
ca <- read.csv("../../../runs/run_20261028_v1_1/out_A/coefficients.csv")
ca <- ca[ca$spec_id == "O", c("model_id", "term", "estimate")]
m <- merge(res[res$config == "X0", ], ca, by = c("model_id", "term"))
cat("max |X0 - out_A| (rounded to 4dp):", max(abs(m$estimate.x - m$estimate.y)), "\n")
