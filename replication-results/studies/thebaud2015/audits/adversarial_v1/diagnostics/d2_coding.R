## POST-HOC adversarial diagnostic (no model fitting): alternative outcome codings
## versus the published descriptive means (Table A2 panel B). Cannot change any score.
source("audits/adversarial_v1/diagnostics/load_impl.R")
s <- origin_settings()
prep <- prepare_run(inputs, s); d <- prep$d
o <- d[step1 & step2 & step3 & owner == 1]
base_ok <- complete.cases(as.data.frame(o[, c("female", "age", "postsecondary", "sole", "bage", X_VARS, C_VARS), with = FALSE]))
ob <- o[base_ok]
lor <- function(y, f) { m1 <- mean(y[f == 1], na.rm = TRUE); m0 <- mean(y[f == 0], na.rm = TRUE)
  log(m1 / (1 - m1)) - log(m0 / (1 - m0)) }
show <- function(name, y, x = ob) data.table(coding = name, n = sum(!is.na(y)), mean = mean(y, na.rm = TRUE),
                                             raw_female_logOR = lor(y, x$female))
## plan B
r <- list(
  show("planb origin: 2 vs 1,3,4,6", ob$planb),
  show("U09: 2,3 vs 1,4,6", fifelse(ob$OMREASON %in% c(2, 3), 1, fifelse(ob$OMREASON %in% c(1, 4, 6), 0, NA_real_))),
  show("2 vs 1 only", fifelse(ob$OMREASON == 2, 1, fifelse(ob$OMREASON == 1, 0, NA_real_))),
  show("2 vs 1,3", fifelse(ob$OMREASON == 2, 1, fifelse(ob$OMREASON %in% c(1, 3), 0, NA_real_))),
  show("2 vs all incl missing codes as 0", fifelse(ob$OMREASON == 2, 1, 0)),
  show("U10 OMWHY -1 vs 0,1", fifelse(ob$OMWHY == -1, 1, fifelse(ob$OMWHY %in% c(0, 1), 0, NA_real_))))
pb <- rbindlist(r); pb[, published_mean := 0.31]; print(pb)
print(ob[, .N, by = .(OMREASON, OMWHY)][order(OMREASON, OMWHY)])
## growth
jm <- c(999999, 9999997, 9999999)
cat("OMYR5JOB missing-code counts among covariate-complete owners:\n")
print(ob[, .N, by = .(code = fifelse(is.na(OMYR5JOB), "NA", fifelse(OMYR5JOB %in% jm, as.character(OMYR5JOB), "valid")))])
cat("OMNOWJOB missing-code counts:\n")
print(ob[, .N, by = .(code = fifelse(is.na(OMNOWJOB), "NA", fifelse(OMNOWJOB %in% jm, as.character(OMNOWJOB), "valid")))])
nowv <- fifelse(!is.na(ob$OMNOWJOB) & !(ob$OMNOWJOB %in% jm), ob$OMNOWJOB, NA_real_)
y5v <- fifelse(!is.na(ob$OMYR5JOB) & !(ob$OMYR5JOB %in% jm), ob$OMYR5JOB, NA_real_)
g <- list(
  show("origin: y5 - now > 5", ob$growth),
  show("y5 - now >= 5", fifelse(!is.na(nowv) & !is.na(y5v), as.numeric(y5v - nowv >= 5), NA_real_)),
  show("y5 - now > 0", fifelse(!is.na(nowv) & !is.na(y5v), as.numeric(y5v - nowv > 0), NA_real_)),
  show("y5 - now > 1", fifelse(!is.na(nowv) & !is.na(y5v), as.numeric(y5v - nowv > 1), NA_real_)),
  show("y5 - now > 2", fifelse(!is.na(nowv) & !is.na(y5v), as.numeric(y5v - nowv > 2), NA_real_)),
  show("U23: y5 > 5", fifelse(!is.na(y5v), as.numeric(y5v > 5), NA_real_)),
  show("y5 >= 10", fifelse(!is.na(y5v), as.numeric(y5v >= 10), NA_real_)),
  show("y5 >= 20", fifelse(!is.na(y5v), as.numeric(y5v >= 20), NA_real_)),
  show("y5 - now > 5, missing codes kept as numbers", fifelse(!is.na(ob$OMNOWJOB) & !is.na(ob$OMYR5JOB), as.numeric(ob$OMYR5JOB - ob$OMNOWJOB > 5), NA_real_)),
  show("y5 - now > 5, missing y5/now -> 0", fifelse(!is.na(nowv) & !is.na(y5v), as.numeric(y5v - nowv > 5), 0)))
gg <- rbindlist(g); gg[, published_mean := 0.17]; print(gg)
## growth jointly with sample: common sample
## business age
bm <- function(v) c(mean = mean(v, na.rm = TRUE), sd = sd(v, na.rm = TRUE), n = sum(!is.na(v)))
o2 <- o[complete.cases(as.data.frame(o[, c("female", "age", "postsecondary", "sole", X_VARS, C_VARS), with = FALSE]))]
by <- fifelse(!is.na(o2$OMWAGEYR) & o2$OMWAGEYR >= 1990 & o2$OMWAGEYR <= o2$year, o2$year - o2$OMWAGEYR, NA_real_)
bb <- rbind(
  origin_log_years_pos = bm(fifelse(by > 0, log(by), NA_real_)),
  U11_log_years_plus1 = bm(log(by + 1)),
  log_years_pos_floor1 = bm(fifelse(!is.na(by), log(pmax(by, 1)), NA_real_)),
  published = c(2.01, 0.92, 28775))
print(round(bb, 3))
print(table(OMWAGEYR_code = cut(o2$OMWAGEYR, c(-Inf, 1989, 1990, 2008, 9996, 9997, 9998, 9999, Inf)), useNA = "ifany"))
fwrite(pb, "audits/adversarial_v1/diagnostics/d2_planb_codings.csv")
fwrite(gg, "audits/adversarial_v1/diagnostics/d2_growth_codings.csv")
fwrite(data.table(coding = rownames(bb), bb), "audits/adversarial_v1/diagnostics/d2_bage_codings.csv")
