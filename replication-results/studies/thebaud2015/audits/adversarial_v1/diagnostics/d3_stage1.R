## POST-HOC adversarial diagnostic (no model fitting): stage-1 outcome shares vs published text.
source("audits/adversarial_v1/diagnostics/load_impl.R")
s <- origin_settings(); prep <- prepare_run(inputs, s); d <- prep$d
m3 <- build_sample(d, "M3", s)
tea <- suppressWarnings(as.numeric(m3$TEA))
r <- data.table(
  quantity = c("activity (published 13%)", "nascent SUBOANWT (published 3%)", "TEA column (early stage)",
               "U03 nascent BSTART & SUWAGE!=1", "OMBABYBT new owner", "female share (published .49)",
               "postsecondary (published .45)", "age mean (published 38.76)"),
  value = c(mean(m3$activity), mean(m3$nascent), mean(tea[tea %in% c(0, 1)]),
            mean(fifelse(in_set(m3$bstart_c, 1) & !in_set(m3$SUWAGE, 1), 1, fifelse(in_set(m3$bstart_c, 0), 0, NA_real_)), na.rm = TRUE),
            mean(m3$OMBABYBT %in% 1), mean(m3$female), mean(m3$postsecondary), mean(m3$age)))
print(r)
print(table(TEA = m3$TEA, useNA = "ifany"))
lor <- function(y, f) { m1 <- mean(y[f == 1], na.rm = TRUE); m0 <- mean(y[f == 0], na.rm = TRUE); log(m1/(1-m1)) - log(m0/(1-m0)) }
cat("raw female logOR: nascent", lor(m3$nascent, m3$female), " TEA", lor(tea[tea %in% c(0,1)], m3$female[tea %in% c(0,1)]),
    " activity", lor(m3$activity, m3$female), "\n")
fwrite(r, "audits/adversarial_v1/diagnostics/d3_stage1_shares.csv")
## activity share under alternative definitions (same M3 rows)
u04 <- fifelse(in_set(m3$SUBOANWT, 1) | in_set(m3$OMBABYBT, 1) | in_set(m3$OMESTBBT, 1), 1, 0)
ownmod <- fifelse(in_set(m3$OMBABYBT, 1) | in_set(m3$OMESTBBT, 1), 1, 0)
cat(sprintf("U04 activity share %.4f; OWNMGE=1 share %.4f; OMBABYBT|OMESTBBT share %.4f; OMESTBBT share %.4f\n",
            mean(u04), mean(m3$ownmge_c %in% 1), mean(ownmod), mean(m3$OMESTBBT %in% 1)))
cat(sprintf("SUBOANWT | OMESTBBT share %.4f\n", mean(in_set(m3$SUBOANWT, 1) | in_set(m3$OMESTBBT, 1))))
print(m3[, .(owner = mean(ownmge_c %in% 1), modowner = mean(OMBABYBT %in% 1 | OMESTBBT %in% 1)), by = year][order(year)])
