# Adversarial review: N-shortfall diagnosis at the origin specification (diagnostic only).
# Sources the frozen code_A library; reads runs/run_20261028_v1_1/inputs; writes CSVs here.
suppressPackageStartupMessages(library(jsonlite))
root <- "../../.."
run <- file.path(root, "runs/run_20261028_v1_1")
source(file.path(run, "code_A/k7_lib.R"))
d <- read.csv(file.path(run, "inputs/survey.csv"), check.names = FALSE)
mis <- parse_metadata(fromJSON(file.path(run, "inputs/survey_metadata.json"), simplifyVector = FALSE))
cwp <- parse_crosswalk(read.csv(file.path(run, "inputs/industry_crosswalk.csv"), colClasses = "character"))
grid <- fromJSON(file.path(run, "inputs/grid_v1.json"), simplifyVector = FALSE)
s <- grid$specs[[1]]$settings
f <- build_frame(d, s, mis, cwp)
f <- add_z_indices(f, s$item_rule)
cat("frame rows:", nrow(f), "\n")
vars_org <- c("POP", HRM_TERMS, ORG_CONTROLS, "IND")
vars_mkt <- c("PMP", HRM_TERMS, MKT_CONTROLS, "IND")
miss_tab <- function(f, rows, vars) {
  sub <- f[rows, ]
  M <- sapply(vars, function(v) is.na(sub[[v]]))
  cc <- rowSums(M) == 0
  out <- data.frame(variable = vars,
    n_missing = colSums(M),
    n_missing_only_this = sapply(seq_along(vars), function(j) sum(M[, j] & rowSums(M[, -j, drop = FALSE]) == 0)),
    n_cc_if_dropped = sapply(seq_along(vars), function(j) sum(rowSums(M[, -j, drop = FALSE]) == 0)))
  list(tab = out, n_frame = nrow(sub), n_cc = sum(cc), M = M)
}
org <- miss_tab(f, rep(TRUE, nrow(f)), vars_org)
mkt <- miss_tab(f, !is.na(f$V8) & f$V8 == 1, vars_mkt)
cat("org frame", org$n_frame, "cc", org$n_cc, "\n"); print(org$tab[order(-org$tab$n_missing), ], row.names = FALSE)
cat("mkt frame", mkt$n_frame, "cc", mkt$n_cc, "\n"); print(mkt$tab[order(-mkt$tab$n_missing), ], row.names = FALSE)
write.csv(cbind(family = "org", n_frame = org$n_frame, n_cc = org$n_cc, org$tab), "missingness_org_origin.csv", row.names = FALSE)
write.csv(cbind(family = "mkt", n_frame = mkt$n_frame, n_cc = mkt$n_cc, mkt$tab), "missingness_mkt_origin.csv", row.names = FALSE)
# greedy sequential: which variables, dropped from the complete-case requirement, add the most cases
greedy <- function(M, k = 6) {
  rem <- colnames(M); dropped <- character(0); res <- list()
  for (i in 1:k) {
    gains <- sapply(rem, function(v) sum(rowSums(M[, setdiff(rem, v), drop = FALSE]) == 0))
    best <- names(which.max(gains)); dropped <- c(dropped, best); rem <- setdiff(rem, best)
    res[[i]] <- data.frame(step = i, dropped = best, n_cc_after = max(gains))
  }
  do.call(rbind, res)
}
cat("greedy org\n"); go <- greedy(org$M); print(go)
cat("greedy mkt\n"); gm <- greedy(mkt$M); print(gm)
write.csv(rbind(cbind(family = "org", go), cbind(family = "mkt", gm)), "greedy_requirement_relaxation.csv", row.names = FALSE)
# raw item-level missingness for the components of the heaviest variables (org frame)
saveRDS(f, "frame_origin_A.rds")
