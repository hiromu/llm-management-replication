## POST-HOC diagnostic (no fitting): growth prevalence and raw gender log-odds ratio in subsets,
## versus the published 17 percent (Table A2 panel B). Common owner sample.
source("audits/adversarial_v1/diagnostics/load_impl.R")
s <- origin_settings(); prep <- prepare_run(inputs, s)
x <- build_sample(prep$d, "M6", s); x <- x[!is.na(planb) & !is.na(size) & !is.na(growth)]
lor <- function(y, f) { m1 <- mean(y[f == 1]); m0 <- mean(y[f == 0]); log(m1/(1-m1)) - log(m0/(1-m0)) }
f <- function(lbl, sub) data.table(subset = lbl, n = nrow(sub), growth = mean(sub$growth), raw_female_logOR = lor(sub$growth, sub$female))
r <- rbind(f("common sample", x), f("employers only (OMNOWJOB >= 1)", x[OMNOWJOB >= 1]),
           f("OMNOWJOB >= 2", x[OMNOWJOB >= 2]), f("new businesses OMBABYBT = 1", x[OMBABYBT %in% 1]),
           f("established OMESTBBT = 1", x[OMESTBBT %in% 1]))
print(r); fwrite(r, "audits/adversarial_v1/diagnostics/d9_growth_subsets.csv")
