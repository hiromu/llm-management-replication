## POST-HOC adversarial diagnostic (no model fitting). Cannot change any score.
## Run from study root: Rscript audits/adversarial_v1/diagnostics/d1_data.R
source("audits/adversarial_v1/diagnostics/load_impl.R")
out <- "audits/adversarial_v1/diagnostics/"
s <- origin_settings()
prep <- prepare_run(inputs, s)
d <- prep$d; sv <- prep$survey_table

## A. roster coverage
ros <- paste(ROSTER_DT$iso3, ROSTER_DT$year, sep = "_")
m1 <- build_sample(d, "M1", s); m3 <- build_sample(d, "M3", s)
cat("Roster surveys absent from M1:", setdiff(ros, unique(m1$survey)), "\n")
cat("Roster surveys absent from M3:", setdiff(ros, unique(m3$survey)), "\n")
miss <- sv[survey %in% setdiff(ros, unique(m3$survey))]
print(miss[, .(survey, leave, childcare, parttime, gdp, unemp, epl, status, wmgr, fert)])
## rows of steps 1-3 by survey with missing female/age/educ
st <- d[step1 & step2 & step3]
cat("steps1-3 rows:", nrow(st), " missing postsec:", sum(is.na(st$postsecondary)),
    " missing activity:", sum(is.na(st$activity)), "\n")
cat("rows before step3 (steps1-2):", nrow(d[step1 & step2]), "\n")

## B. survey-level country means over the M3 surveys (raw scale)
svm3 <- unique(m3[, .(iso3, survey)])
raw <- merge(svm3, sv[, c("survey", SURVEY_RAW), with = FALSE], by = "survey")
cm <- raw[, lapply(.SD, mean), by = iso3, .SDcols = SURVEY_RAW]
## Table A1 country means (publication diagnostic only)
a1 <- fread(text = "iso3,leave,childcare,parttime,gdp,unemp,epl,status,wmgr,fert
AUS,0,0.18,37.59,0.82,5.5,1.19,0.67,36.60,1.78
AUT,16,0.30,31.11,0.84,4.8,1.93,0.71,27.0,1.39
BEL,13.9,0.23,34.45,0.83,7.68,2.18,0.60,31.38,1.74
CAN,27.5,0,25.95,0.83,7.20,0.75,0.68,35.50,1.53
CZE,62.8,0.14,5.09,0.76,7.10,2.09,0.43,29.0,1.33
DNK,19.4,0.69,23.11,0.83,4.44,1.5,0.73,26.50,1.80
FIN,29,0.73,14.32,0.82,8.13,2.01,0.85,28.63,1.79
FRA,19.8,0.36,23.32,0.82,8.51,3.05,0.64,37.43,1.93
DEU,36,0.07,37.36,0.82,9.27,2.14,0.74,36.57,1.35
GRC,33.5,0.13,12.64,0.78,9.17,2.73,0.72,27.17,1.37
ISL,20.6,0.60,26.08,0.82,2.96,1.37,0.70,29.14,2.05
IRL,16.7,0.26,34.05,0.82,4.53,1.07,0.81,30.0,1.97
ITA,25.1,0.15,28.29,0.81,7.86,1.88,0.65,28.14,1.32
JPN,26,0.23,31.66,0.82,4.59,1.43,0.51,9.63,1.32
NLD,16,0.14,60.01,0.84,3.63,2.08,0.68,26.86,1.73
NZL,10.5,0.08,34.27,0.77,4.5,1.47,0.67,36.0,1.96
NOR,38,0.52,32.75,0.88,3.88,2.60,0.64,30.17,1.84
POL,39.1,0,14.58,0.68,19.03,1.48,0.56,34.0,1.26
PRT,15,0.003,8.62,0.77,6.23,3.53,0.66,32.0,1.40
ESP,16,0.44,19.27,0.80,10.14,2.99,0.59,31.43,1.35
SWE,39.7,0.58,19.81,0.82,6.19,2.24,0.60,30.71,1.74
CHE,2.8,0.09,44.20,0.85,3.75,1.14,0.71,28.50,1.41
GBR,9.93,0.38,38.18,0.83,4.96,0.74,0.72,33.5,1.78
USA,0,0.08,18.24,0.86,5.26,0.21,0.65,43.88,2.06")
cmp <- merge(cm, a1, by = "iso3", suffixes = c("_ours", "_A1"), all = TRUE)
fwrite(cmp, paste0(out, "d1_country_means_vs_A1.csv"))
cors <- sapply(SURVEY_RAW, function(v) {
  ok <- complete.cases(cmp[[paste0(v, "_ours")]], cmp[[paste0(v, "_A1")]])
  c(pearson = cor(cmp[[paste0(v, "_ours")]][ok], cmp[[paste0(v, "_A1")]][ok]),
    spearman = cor(cmp[[paste0(v, "_ours")]][ok], cmp[[paste0(v, "_A1")]][ok], method = "spearman"),
    n = sum(ok))
})
print(round(t(cors), 3))
fwrite(data.table(var = SURVEY_RAW, t(cors)), paste0(out, "d1_country_mean_correlations.csv"))
print(cmp[, .(iso3, childcare_ours = round(childcare_ours, 2), childcare_A1, leave_ours = round(leave_ours, 1), leave_A1,
              pt_ours = round(parttime_ours, 1), parttime_A1)])

## C. leave_sq scale: z^2 versus standardized raw square (survey level, M3 set)
z <- (raw$leave - mean(raw$leave)) / sd(raw$leave)
zsq <- z^2; rsq <- raw$leave^2; rsqz <- (rsq - mean(rsq)) / sd(rsq)
cat(sprintf("leave: mean %.2f sd %.2f; z^2 mean %.3f sd %.3f; cor(z, z^2) %.3f; cor(z, z(raw^2)) %.3f\n",
            mean(raw$leave), sd(raw$leave), mean(zsq), sd(zsq), cor(z, zsq), cor(z, rsqz)))

## D. owner sample construction
o <- d[step1 & step2 & step3 & owner == 1]
cat("owners steps1-3:", nrow(o), "\n")
sv_need <- c(X_VARS, C_VARS)
base_ok <- complete.cases(as.data.frame(o[, c("female", "age", "postsecondary", "sole", "bage", sv_need), with = FALSE]))
ob <- o[base_ok]
cat("owners complete on covariates:", nrow(ob), "\n")
tab <- data.table(
  sample = c("planb", "size", "growth", "newprod (2002-08)", "newtech (2005-08)",
             "common planb&size&growth", "common planb&size&growth, 2002-08 & newprod",
             "common planb&size&growth, 2005-08 & newtech",
             "common all five outcomes (any year)"),
  n = c(sum(!is.na(ob$planb)), sum(!is.na(ob$size)), sum(!is.na(ob$growth)),
        sum(!is.na(ob$newprod) & ob$year >= 2002), sum(!is.na(ob$newtech) & ob$year >= 2005),
        sum(!is.na(ob$planb) & !is.na(ob$size) & !is.na(ob$growth)),
        sum(!is.na(ob$planb) & !is.na(ob$size) & !is.na(ob$growth) & ob$year >= 2002 & !is.na(ob$newprod)),
        sum(!is.na(ob$planb) & !is.na(ob$size) & !is.na(ob$growth) & ob$year >= 2005 & !is.na(ob$newtech)),
        NA))
tab$published <- c(28775, 28775, 28775, 27107, 17498, 28775, 27107, 17498, NA)
print(tab)
fwrite(tab, paste0(out, "d1_owner_sample_sizes.csv"))

## outcome / covariate means vs Table A2 panel B
cs <- ob[!is.na(planb) & !is.na(size) & !is.na(growth)]
desc <- function(x) data.table(
  female = mean(x$female), age = mean(x$age), postsec = mean(x$postsecondary),
  planb = mean(x$planb, na.rm = TRUE), size_mean = mean(x$size, na.rm = TRUE), size_sd = sd(x$size, na.rm = TRUE),
  growth = mean(x$growth, na.rm = TRUE), newprod = mean(x$newprod[x$year >= 2002], na.rm = TRUE),
  newtech = mean(x$newtech[x$year >= 2005], na.rm = TRUE), sole = mean(x$sole),
  bage_mean = mean(x$bage), bage_sd = sd(x$bage), n = nrow(x))
dd <- rbind(cbind(set = "owners complete on covariates", desc(ob)),
            cbind(set = "common planb&size&growth", desc(cs)),
            cbind(set = "published Table A2 B", data.table(female = .37, age = 41.31, postsec = .44, planb = .31,
              size_mean = 1.08, size_sd = 1.07, growth = .17, newprod = .09, newtech = .22, sole = .62,
              bage_mean = 2.01, bage_sd = .92, n = 28775)))
print(dd)
fwrite(dd, paste0(out, "d1_owner_descriptives_vs_A2.csv"))
## year shares
ys <- rbind(cbind(set = "common", cs[, .(share = .N / nrow(cs)), by = year]),
            cbind(set = "published", data.table(year = 2001:2008, share = c(.04,.09,.11,.18,.14,.18,.14,.12))))
print(dcast(ys, year ~ set, value.var = "share"))

## E. plan-B coding: OMREASON distribution among owners
print(o[, .N, by = OMREASON][order(OMREASON)])
print(o[, .N, by = .(year, has_reason = !is.na(planb))][order(year)])
## F. growth distribution
cat("growth by definitions among covariate-complete owners:\n")
print(ob[, .(origin = mean(growth, na.rm = TRUE), total_gt5 = mean(OMYR5JOB > 5 & !(OMYR5JOB %in% c(999999, 9999997, 9999999)), na.rm = TRUE),
            n_growth = sum(!is.na(growth)))])
print(quantile(ob$OMYR5JOB[!(ob$OMYR5JOB %in% c(999999, 9999997, 9999999))], c(.5, .75, .9, .95, .99), na.rm = TRUE))
print(ob[, .(growth = mean(growth, na.rm = TRUE)), by = female])
print(ob[, .(growth = mean(growth, na.rm = TRUE), n = sum(!is.na(growth))), by = year][order(year)])
