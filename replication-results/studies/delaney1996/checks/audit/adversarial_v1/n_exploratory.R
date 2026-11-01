# EXPLORATORY, POST-HOC, NOT PART OF THE FROZEN PROTOCOL.
# Counts of the origin common complete-case sample under readings that are documented
# (reader levels or the article's own Table 2) but were not executed in grid_v1. Diagnostic only;
# no classification is changed and no reading is selected because of these counts.
source("../../../runs/run_20261028_v1_1/code_A/k7_lib.R")
d <- read.csv("../../../runs/run_20261028_v1_1/inputs/survey.csv", check.names = FALSE)
f <- readRDS("frame_origin_A.rds")
stopifnot(all(f$V1 == d$V1))
V114 <- d$V114; V45 <- d$V45; V80 <- d$V80; V328 <- d$V328
V45[V45 %in% c(99998, 99999)] <- NA; V80[V80 %in% c(99998, 99999)] <- NA
den <- f$PCTMGR; # placeholder
# E1 (Fable A15.L0, not executed): V114 == 2 -> numerator from CORE (V45) or GSS (V80) count; availability only
pct_E1_avail <- !is.na(f$PCTMGR) | (V114 == 2 & (!is.na(V45) | !is.na(V80)) & !is.na(f$LOGEMP))
# E2 (Table 2 mean .44/sd .50 indicates a dummy; N/A code 7 -> 0 not executed): availability
comp_E2_avail <- !is.na(f$COMPET) | V328 == 7
# STAFF: rows with all three blocks not hiring from outside (V50/V85/V119 == 2 or system-missing)
nohire <- (is.na(d$V50) | d$V50 == 2) & (is.na(d$V85) | d$V85 == 2) & (is.na(d$V119) | d$V119 == 2)
cat("STAFF missing:", sum(is.na(f$STAFF)), " of which no outside hiring in any block:", sum(is.na(f$STAFF) & nohire), "\n")
cat("STAFF missing with V50==2 (no CORE outside hiring):", sum(is.na(f$STAFF) & d$V50 %in% 2), "\n")
cat("PCTMGR missing:", sum(is.na(f$PCTMGR)), " V114==2:", sum(is.na(f$PCTMGR) & V114 == 2), " recoverable under E1:", sum(is.na(f$PCTMGR) & pct_E1_avail), "\n")
cat("COMPET missing:", sum(is.na(f$COMPET)), " code 7:", sum(V328 %in% 7), "\n")
base_org <- c("POP", "TRAIN", "INCENT", "GRIEV", "DECENT", "ILM", "VHIER", "NONPROF", "SUBSID", "LOGEMP", "LOGAGE", "UNION", "PRODUCT", "SERVICE", "IND")
base_mkt <- setdiff(c(base_org, "PMP"), c("POP", "NONPROF"))
cc <- function(vars, extra = TRUE, rows = TRUE) sum(rows & extra & complete_rows(f, vars))
mk <- !is.na(f$V8) & f$V8 == 1
staff <- !is.na(f$STAFF); pct <- !is.na(f$PCTMGR); comp <- !is.na(f$COMPET)
res <- data.frame(configuration = c(
  "origin (as frozen)",
  "E1 PCTMGR V114==2 mapped (Fable A15.L0)",
  "E2 COMPET N/A as 0",
  "E1 + E2",
  "E1 + E2 + STAFF not required",
  "STAFF not required (only)",
  "STAFF, PCTMGR, COMPET not required"),
  org_N = c(cc(base_org, staff & pct & comp), cc(base_org, staff & pct_E1_avail & comp), cc(base_org, staff & pct & comp_E2_avail),
            cc(base_org, staff & pct_E1_avail & comp_E2_avail), cc(base_org, pct_E1_avail & comp_E2_avail), cc(base_org, pct & comp), cc(base_org)),
  mkt_N = c(cc(base_mkt, staff & pct & comp, mk), cc(base_mkt, staff & pct_E1_avail & comp, mk), cc(base_mkt, staff & pct & comp_E2_avail, mk),
            cc(base_mkt, staff & pct_E1_avail & comp_E2_avail, mk), cc(base_mkt, pct_E1_avail & comp_E2_avail, mk), cc(base_mkt, pct & comp, mk), cc(base_mkt, TRUE, mk)))
print(res, row.names = FALSE)
write.csv(res, "n_exploratory_EXPLORATORY_POSTHOC.csv", row.names = FALSE)
