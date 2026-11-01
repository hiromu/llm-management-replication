# Diagnostic: pairwise-complete correlations (full record frame) of STAFF and SUBSID with other variables, vs Table 2.
f <- readRDS("frame_origin_A.rds")
f$PCTMGR_prop <- f$PCTMGR / 100
pc <- function(a, b) round(cor(f[[a]], f[[b]], use = "pairwise.complete.obs"), 3)
staff_t2 <- c(TRAIN=.38, INCENT=.05, GRIEV=.30, DECENT=.24, ILM=.38, VHIER=.27, NONPROF=.21, SUBSID=-.12, LOGEMP=.42, LOGAGE=.21, PCTMGR_prop=-.35, UNION=.15, PRODUCT=-.03, SERVICE=-.01, COMPET=-.01)
subs_t2 <- c(POP=.11, STAFF=-.12, TRAIN=-.30, INCENT=.07, GRIEV=-.43, DECENT=.26)
r1 <- data.frame(pair = paste0("STAFF~", names(staff_t2)), ours_pairwise = sapply(names(staff_t2), function(v) pc("STAFF", v)), table2 = staff_t2)
r2 <- data.frame(pair = paste0("SUBSID(V17==1)~", names(subs_t2)), ours_pairwise = sapply(names(subs_t2), function(v) pc("SUBSID", v)), table2 = subs_t2)
r <- rbind(r1, r2); print(r, row.names = FALSE)
write.csv(r, "staff_subsid_correlations_vs_table2.csv", row.names = FALSE)
