# Adversarial review: is the complete-case loss related to establishment size? (diagnostic only)
f <- readRDS("frame_origin_A.rds")
smp <- read.csv("../../../runs/run_20261028_v1_1/out_A/samples.csv")
so <- smp$V1[smp$spec_id == "O" & smp$family == "org"]
f$in_org <- f$V1 %in% so
grp <- function(lbl, idx) data.frame(group = lbl, n = sum(idx), mean_LOGEMP = mean(f$LOGEMP[idx], na.rm = TRUE), median_emp = exp(median(f$LOGEMP[idx], na.rm = TRUE)), mean_POP = mean(f$POP[idx], na.rm = TRUE))
out <- rbind(grp("all 727", rep(TRUE, nrow(f))),
             grp("origin org sample (361)", f$in_org),
             grp("not in origin org sample", !f$in_org),
             grp("STAFF missing", is.na(f$STAFF)),
             grp("PCTMGR missing", is.na(f$PCTMGR)),
             grp("COMPET missing", is.na(f$COMPET)),
             grp("POP valid & not in sample", !is.na(f$POP) & !f$in_org))
out[, 3:5] <- round(out[, 3:5], 3); print(out, row.names = FALSE)
write.csv(out, "size_selection.csv", row.names = FALSE)
# pairwise-complete correlations in the full record frame (Table 2 used pairwise? unknown) -- diagnostic
v <- c("STAFF","TRAIN","INCENT","GRIEV","DECENT","ILM","VHIER","SUBSID","UNION")
pw <- t(sapply(v, function(x) c(POP_pairwise = cor(f$POP, f[[x]], use = "pairwise.complete.obs"),
                                  PMP_pairwise = cor(f$PMP[f$V8 == 1], f[[x]][f$V8 == 1], use = "pairwise.complete.obs"))))
t2 <- rbind(STAFF=c(.01,.19),TRAIN=c(.06,.19),INCENT=c(.17,.13),GRIEV=c(-.06,.12),DECENT=c(.07,-.01),ILM=c(-.06,.20),VHIER=c(.02,.17),SUBSID=c(.11,-.12),UNION=c(-.12,-.02))
res <- cbind(round(pw, 3), table2_POP = t2[v,1], table2_PMP = t2[v,2])
print(res); write.csv(res, "pairwise_correlations_vs_table2.csv")
