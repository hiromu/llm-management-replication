## POST-HOC diagnostic (no fitting): how many rows the four surveys lost to missing leave
## (CZE 2006; FRA 2002-2004) would add, for stage 1 and for the common owner sample.
source("audits/adversarial_v1/diagnostics/load_impl.R")
s <- origin_settings(); prep <- prepare_run(inputs, s); d <- prep$d
lost <- c("CZE_2006", "FRA_2002", "FRA_2003", "FRA_2004")
st <- d[step1 & step2 & step3 & survey %in% lost]
cat("stage1 rows in lost surveys complete on activity/female/age/postsec:",
    nrow(st[!is.na(activity) & !is.na(female) & !is.na(age) & !is.na(postsecondary)]), "\n")
ow <- st[owner == 1 & !is.na(female) & !is.na(age) & !is.na(postsecondary) & !is.na(sole) & !is.na(bage) &
         !is.na(planb) & !is.na(size) & !is.na(growth)]
cat("common-sample owners in lost surveys:", nrow(ow), "\n")
print(st[, .N, by = survey])
cat("M1 rows:", nrow(build_sample(d, "M1", s)), " steps1-3 rows with missing postsecondary:",
    nrow(d[step1 & step2 & step3 & is.na(postsecondary)]), "\n")
print(d[step1 & step2 & step3 & is.na(postsecondary), .N, by = survey][order(-N)][1:8])
