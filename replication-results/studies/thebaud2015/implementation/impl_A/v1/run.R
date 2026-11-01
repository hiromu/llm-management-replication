#!/usr/bin/env Rscript
## ---------------------------------------------------------------------------
## run.R -- analysis script for manifest P-7Q3 (neutral, version 1)
##
## Usage:  Rscript run.R <data_dir> <out_dir> <run_ids>
##   run_ids: comma-separated list of run IDs (ORIGIN, U01, ..., N01),
##            "all" (ORIGIN + every deviation, no influence),
##            "influence" (influence runs for M3-M8),
##            "influence:M4" (influence runs for one model; extension for testing).
##
## Software: R, lme4, Matrix, sandwich, lmtest, data.table, jsonlite, digest.
## ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(data.table)
  library(Matrix)
  library(lme4)
  library(sandwich)
  library(lmtest)
  library(jsonlite)
  library(digest)
})

options(warn = 1, stringsAsFactors = FALSE, scipen = 999)

## ---------------------------------------------------------------------------
## 0. Command line
## ---------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop("Usage: Rscript run.R <data_dir> <out_dir> <run_ids>")
}
data_dir <- args[1]
out_dir  <- args[2]
run_arg  <- args[3]
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

t_start <- Sys.time()
logmsg <- function(...) cat(format(Sys.time(), "%H:%M:%S"), "-", sprintf(...), "\n")

## ---------------------------------------------------------------------------
## 1. Constants: roster, deviation table, model table
## ---------------------------------------------------------------------------
ROSTER <- list(
  AUS = 2002:2006, AUT = c(2005, 2007), BEL = 2001:2008,
  CAN = c(2001, 2002, 2003, 2006), CZE = 2006, DNK = 2001:2008,
  FIN = 2001:2008, FRA = 2002:2008, DEU = c(2001:2006, 2008),
  GRC = 2003:2008, ISL = 2002:2008, IRL = 2001:2008,
  ITA = c(2001:2003, 2005:2008), JPN = 2001:2008, NLD = 2002:2008,
  NZL = c(2001, 2003, 2004, 2005), NOR = c(2002:2006, 2008),
  POL = c(2001, 2002, 2004), PRT = c(2001, 2004, 2007), ESP = 2002:2008,
  SWE = 2001:2007, CHE = c(2002, 2003, 2005, 2007), GBR = 2001:2008,
  USA = 2001:2008
)
COUNTRIES <- names(ROSTER)
ROSTER_DT <- rbindlist(lapply(COUNTRIES, function(c) data.table(iso3 = c, year = as.integer(ROSTER[[c]]))))

DEV_MODELS <- list(
  U01 = c("M3", "M4", "M5", "M6", "M7", "M8"),
  U02 = c("M3", "M4", "M5", "M6", "M7", "M8"),
  U03 = c("M3", "R1"),
  U04 = c("M3"),
  U05 = c("M3", "M4", "M5", "M6", "M7", "M8"),
  U06 = c("M3"),
  U07 = c("M4", "M5", "M6", "M7", "M8"),
  U08 = c("M4", "M5", "M6", "M7", "M8"),
  U09 = c("M4"),
  U10 = c("M4"),
  U11 = c("M4", "M5", "M6", "M7", "M8"),
  U12 = c("M3", "M4", "M5", "M6", "M7", "M8"),
  U13 = c("M3", "M4", "M5", "M6", "M7", "M8"),
  U14 = c("M3", "M4", "M5", "M6", "M7", "M8"),
  U15 = c("M3", "M4", "M5", "M6", "M7", "M8"),
  U16 = c("M3", "M4", "M5", "M6", "M7", "M8"),
  U17 = c("M3", "M4", "M5", "M6", "M7", "M8"),
  U18 = c("M3", "M4", "M5", "M6", "M7", "M8"),
  U19 = c("M3", "M4", "M5", "M6", "M7", "M8"),
  U20 = c("M3", "M4", "M5", "M6", "M7", "M8"),
  U22 = c("M3", "M4", "M5", "M6", "M7", "M8"),
  U23 = c("M6"),
  U24 = c("M4", "M5", "M6", "M7", "M8"),
  U25 = c("M5"),
  U26 = c("R2"),
  N01 = c("M3", "M4", "M5", "M6", "M7", "M8")
)
ORIGIN_MODELS <- c("M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "R1", "R2", "R3")
INFLUENCE_MODELS <- c("M3", "M4", "M5", "M6", "M7", "M8")
ALL_RUNS <- c("ORIGIN", names(DEV_MODELS))

X_VARS  <- c("leave", "leave_sq", "childcare", "parttime")
C_VARS  <- c("gdp", "unemp", "epl", "status", "wmgr", "fert")
FX_VARS <- c("female:leave", "female:leave_sq", "female:childcare", "female:parttime")
SURVEY_RAW <- c("leave", "childcare", "parttime", "gdp", "unemp", "epl", "status", "wmgr", "fert")

## Model table
MODELS <- list(
  M1 = list(outcome = "activity", sample = "S1", family = "logit", ref = 2001L, years = 2001:2008,
            terms = "base"),
  M2 = list(outcome = "activity", sample = "S1", family = "logit", ref = 2001L, years = 2001:2008,
            terms = "XC"),
  M3 = list(outcome = "activity", sample = "S1", family = "logit", ref = 2001L, years = 2001:2008,
            terms = "FX"),
  M4 = list(outcome = "planb",    sample = "S2", family = "logit", ref = 2001L, years = 2001:2008,
            terms = "S2"),
  M5 = list(outcome = "size",     sample = "S2", family = "gaussian", ref = 2001L, years = 2001:2008,
            terms = "S2"),
  M6 = list(outcome = "growth",   sample = "S2", family = "logit", ref = 2001L, years = 2001:2008,
            terms = "S2"),
  M7 = list(outcome = "newprod",  sample = "S2", family = "logit", ref = 2002L, years = 2002:2008,
            terms = "S2"),
  M8 = list(outcome = "newtech",  sample = "S2", family = "logit", ref = 2008L, years = 2005:2008,
            terms = "S2"),
  R1 = list(outcome = "nascent",  sample = "S1", family = "logit", ref = 2001L, years = 2001:2008,
            terms = "FX"),
  R2 = list(outcome = "activity", sample = "R2", family = "logit", ref = 2001L, years = 2001:2008,
            terms = "R2"),
  R3 = list(outcome = "activity", sample = "R3", family = "logit", ref = 2001L, years = 2001:2008,
            terms = "R3")
)

## ---------------------------------------------------------------------------
## 2. Settings (origin defaults; each deviation changes exactly one entry)
## ---------------------------------------------------------------------------
origin_settings <- function() {
  list(
    roster       = "origin",   # U05: all surveys 2001-2008 of the 24 countries
    age_rule     = "origin",   # U01: 18 <= age < 55
    employ_rule  = "origin",   # U02: GEMWORK in {1,2,6}
    activity_def = "origin",   # U03 / U04
    screen8      = "origin",   # U06: 8 -> 0 for BSTART, OWNMGE, SUSKILL, FEARFAIL, KNOWENT
    owner_def    = "origin",   # U07 / U08
    planb_def    = "origin",   # U09 / U10
    bage_def     = "origin",   # U11
    parttime_var = "pt_common_employees_women",  # U12 / U13
    leave_sq_std = "origin",   # U14
    std_method   = "origin",   # U15 / U16
    leave_lag    = 1L,         # U17: 0, U18: 2
    childcare_var = "childcare_interp",          # U19
    cov          = "indep",    # U20: unstructured
    status_sample = "origin",  # U22
    growth_def   = "origin",   # U23
    sole_def     = "origin",   # U24
    m5_reml      = FALSE,      # U25
    r2_fert      = FALSE,      # U26
    n01          = FALSE       # N01: drop 2001/2002, no status carry-back
  )
}

settings_for <- function(run_id) {
  s <- origin_settings()
  switch(run_id,
    ORIGIN = NULL,
    U01 = { s$age_rule <- "U01" },
    U02 = { s$employ_rule <- "U02" },
    U03 = { s$activity_def <- "U03" },
    U04 = { s$activity_def <- "U04" },
    U05 = { s$roster <- "U05" },
    U06 = { s$screen8 <- "U06" },
    U07 = { s$owner_def <- "U07" },
    U08 = { s$owner_def <- "U08" },
    U09 = { s$planb_def <- "U09" },
    U10 = { s$planb_def <- "U10" },
    U11 = { s$bage_def <- "U11" },
    U12 = { s$parttime_var <- "pt_national_women" },
    U13 = { s$parttime_var <- "pt_common_total_women" },
    U14 = { s$leave_sq_std <- "U14" },
    U15 = { s$std_method <- "U15" },
    U16 = { s$std_method <- "U16" },
    U17 = { s$leave_lag <- 0L },
    U18 = { s$leave_lag <- 2L },
    U19 = { s$childcare_var <- "childcare_pct_gdp_annual" },
    U20 = { s$cov <- "unstructured" },
    U22 = { s$status_sample <- "U22" },
    U23 = { s$growth_def <- "U23" },
    U24 = { s$sole_def <- "U24" },
    U25 = { s$m5_reml <- TRUE },
    U26 = { s$r2_fert <- TRUE },
    N01 = { s$n01 <- TRUE },
    stop("unknown run id: ", run_id)
  )
  s
}

## ---------------------------------------------------------------------------
## 3. Read inputs
## ---------------------------------------------------------------------------
read_inputs <- function(data_dir) {
  gem <- fread(file.path(data_dir, "gem_extract.csv"), na.strings = c("", "NA"),
               colClasses = list(character = "ID_9817_RDM"), encoding = "UTF-8")
  cy  <- fread(file.path(data_dir, "country_year_inputs.csv"), na.strings = c("", "NA"),
               encoding = "UTF-8")
  num_cols <- c("GEM_YR", "GEMSEX", "GEMAGE", "GEMEDUC", "GEMWORK", "BSTART", "SUWAGE",
                "SUBOANWT", "OWNMGE", "OMBABYBT", "OMESTBBT", "OMOWN", "OMOWNERS",
                "OMWAGEYR", "OMREASON", "OMWHY", "OMNOWJOB", "OMYR5JOB", "OMNEWCST",
                "OMNEWT_5", "SUSKILL", "FEARFAIL", "KNOWENT", "NBSTATUS")
  for (v in num_cols) {
    if (!v %in% names(gem)) stop("gem_extract.csv lacks column ", v)
    set(gem, j = v, value = suppressWarnings(as.numeric(gem[[v]])))
  }
  gem[, iso3 := toupper(trimws(as.character(iso3)))]
  gem[, year := as.integer(GEM_YR)]
  gem[, ID_9817_RDM := trimws(ID_9817_RDM)]
  cy_num <- c("year", "leave_fte_weeks", "childcare_interp", "childcare_pct_gdp_annual",
              "pt_common_employees_women", "pt_national_women", "pt_common_total_women",
              "gdp_index_undp", "unemployment_rate", "epl_overall", "women_managers_pct",
              "fertility_rate")
  for (v in cy_num) {
    if (!v %in% names(cy)) stop("country_year_inputs.csv lacks column ", v)
    set(cy, j = v, value = suppressWarnings(as.numeric(cy[[v]])))
  }
  cy[, iso3 := toupper(trimws(as.character(iso3)))]
  cy[, year := as.integer(year)]
  cy <- unique(cy, by = c("iso3", "year"))
  list(gem = gem, cy = cy)
}

## ---------------------------------------------------------------------------
## 4. Individual-level variables and sample steps 1-3
## ---------------------------------------------------------------------------
## Screening item coding: 1 or 100 = yes (1), 0 = no (0), 8 / 9 = missing;
## under U06, 8 -> 0 for the listed items.
code_screen <- function(x, eight_is_zero = FALSE) {
  out <- rep(NA_real_, length(x))
  out[!is.na(x) & (x == 1 | x == 100)] <- 1
  out[!is.na(x) & x == 0] <- 0
  if (eight_is_zero) out[!is.na(x) & x == 8] <- 0
  out
}
in_set <- function(x, set) !is.na(x) & x %in% set

build_individual <- function(gem, s) {
  d <- copy(gem)
  u06 <- identical(s$screen8, "U06")
  d[, female := fifelse(GEMSEX == 2, 1, fifelse(GEMSEX == 1, 0, NA_real_))]
  d[, age := fifelse(!is.na(GEMAGE) & !(GEMAGE %in% c(99, 999)), GEMAGE, NA_real_)]
  d[, postsecondary := fifelse(in_set(GEMEDUC, c(1316, 1720)), 1,
                        fifelse(in_set(GEMEDUC, c(0, 111, 1212)), 0, NA_real_))]
  d[, employed := fifelse(in_set(GEMWORK, c(1, 2)), 1,
                   fifelse(in_set(GEMWORK, c(3, 4, 5, 6)), 0, NA_real_))]
  d[, not_employed := 1 - employed]
  d[, bstart_c := code_screen(BSTART, u06)]
  d[, ownmge_c := code_screen(OWNMGE, u06)]
  d[, skill := code_screen(SUSKILL, u06)]
  d[, fear  := code_screen(FEARFAIL, u06)]
  d[, knows := code_screen(KNOWENT, u06)]
  d[, nbstatus_c := code_screen(NBSTATUS, FALSE)]   # NBSTATUS: 8 always missing

  ## activity
  if (s$activity_def == "origin") {
    d[, activity := fifelse(in_set(SUBOANWT, 1) | in_set(ownmge_c, 1), 1,
                     fifelse(in_set(SUBOANWT, 0) & in_set(ownmge_c, 0), 0, NA_real_))]
  } else if (s$activity_def == "U03") {
    d[, activity := fifelse((in_set(bstart_c, 1) & !in_set(SUWAGE, 1)) | in_set(ownmge_c, 1), 1,
                     fifelse(in_set(bstart_c, 0) & in_set(ownmge_c, 0), 0, NA_real_))]
  } else if (s$activity_def == "U04") {
    d[, activity := fifelse(in_set(SUBOANWT, 1) | in_set(OMBABYBT, 1) | in_set(OMESTBBT, 1), 1,
                     fifelse(in_set(SUBOANWT, 0) & in_set(OMBABYBT, 0) & in_set(OMESTBBT, 0), 0, NA_real_))]
  }
  ## nascent
  if (s$activity_def == "U03") {
    d[, nascent := fifelse(in_set(bstart_c, 1) & !in_set(SUWAGE, 1), 1,
                    fifelse(in_set(bstart_c, 0), 0, NA_real_))]
  } else {
    d[, nascent := fifelse(in_set(SUBOANWT, 1), 1, fifelse(in_set(SUBOANWT, 0), 0, NA_real_))]
  }
  ## owner
  if (s$owner_def == "origin") {
    d[, owner := fifelse(in_set(ownmge_c, 1), 1, 0)]
  } else if (s$owner_def == "U07") {
    d[, owner := fifelse(in_set(OMESTBBT, 1), 1, 0)]
  } else if (s$owner_def == "U08") {
    d[, owner := fifelse(in_set(ownmge_c, 1) & in_set(OMOWN, c(1, 2)), 1, 0)]
  }
  ## planb
  if (s$planb_def == "origin") {
    d[, planb := fifelse(in_set(OMREASON, 2), 1, fifelse(in_set(OMREASON, c(1, 3, 4, 6)), 0, NA_real_))]
  } else if (s$planb_def == "U09") {
    d[, planb := fifelse(in_set(OMREASON, c(2, 3)), 1, fifelse(in_set(OMREASON, c(1, 4, 6)), 0, NA_real_))]
  } else if (s$planb_def == "U10") {
    d[, planb := fifelse(in_set(OMWHY, -1), 1, fifelse(in_set(OMWHY, c(0, 1)), 0, NA_real_))]
  }
  ## size
  d[, size := fifelse(!is.na(OMNOWJOB) & OMNOWJOB >= 0 & OMNOWJOB <= 999998, log(OMNOWJOB + 1), NA_real_)]
  ## growth
  job_miss <- c(999999, 9999997, 9999999)
  d[, now_ok := !is.na(OMNOWJOB) & !(OMNOWJOB %in% job_miss)]
  d[, yr5_ok := !is.na(OMYR5JOB) & !(OMYR5JOB %in% job_miss)]
  if (s$growth_def == "origin") {
    d[, growth := fifelse(now_ok & yr5_ok, fifelse((OMYR5JOB - OMNOWJOB) > 5, 1, 0), NA_real_)]
  } else {
    d[, growth := fifelse(yr5_ok, fifelse(OMYR5JOB > 5, 1, 0), NA_real_)]
  }
  ## newprod, newtech
  d[, newprod := fifelse(in_set(OMNEWCST, 1), 1, fifelse(in_set(OMNEWCST, c(2, 3)), 0, NA_real_))]
  d[, newtech := fifelse(in_set(OMNEWT_5, c(1, 2)), 1, fifelse(in_set(OMNEWT_5, 3), 0, NA_real_))]
  ## sole
  if (s$sole_def == "origin") {
    d[, sole := fifelse(in_set(OMOWN, 1), 1, fifelse(in_set(OMOWN, 2), 0, NA_real_))]
  } else {
    d[, sole := fifelse(in_set(OMOWNERS, 1), 1,
                 fifelse(!is.na(OMOWNERS) & OMOWNERS >= 2 & OMOWNERS <= 998, 0, NA_real_))]
  }
  ## business age
  d[, bage_years := fifelse(!is.na(OMWAGEYR) & OMWAGEYR >= 1990 & OMWAGEYR <= year,
                            year - OMWAGEYR, NA_real_)]
  if (s$bage_def == "origin") {
    d[, bage := fifelse(!is.na(bage_years) & bage_years > 0, log(bage_years), NA_real_)]
  } else {
    d[, bage := fifelse(!is.na(bage_years), log(bage_years + 1), NA_real_)]
  }
  d[, survey := paste(iso3, year, sep = "_")]

  ## ---- sample steps ----
  ## step 1: roster
  if (s$roster == "origin") {
    d[, step1 := paste(iso3, year) %in% paste(ROSTER_DT$iso3, ROSTER_DT$year)]
  } else {
    d[, step1 := iso3 %in% COUNTRIES & !is.na(year) & year >= 2001 & year <= 2008]
  }
  if (isTRUE(s$n01)) d[, step1 := step1 & !(year %in% c(2001, 2002))]
  ## step 2: age
  if (s$age_rule == "origin") {
    d[, step2 := !is.na(age) & age > 18 & age < 55]
  } else {
    d[, step2 := !is.na(age) & age >= 18 & age < 55]
  }
  ## step 3: employment
  if (s$employ_rule == "origin") {
    d[, step3 := in_set(employed, 1)]
  } else {
    d[, step3 := in_set(GEMWORK, c(1, 2, 6))]
  }
  d
}

## ---------------------------------------------------------------------------
## 5. Survey-level variables
## ---------------------------------------------------------------------------
## Returns one row per (iso3, year) survey present in gem_extract with the raw
## (unstandardized) survey-level variables.
build_survey <- function(gem_ind, cy, s) {
  surveys <- unique(gem_ind[!is.na(year), .(iso3, year)])
  setorder(surveys, iso3, year)
  ## status: proportion of NBSTATUS == 1 among respondents coded 0/1
  if (s$status_sample == "origin") {
    base <- gem_ind
  } else {
    base <- gem_ind[step1 & step2 & step3]
  }
  st <- base[!is.na(nbstatus_c), .(status_raw = mean(nbstatus_c), n_status = .N), by = .(iso3, year)]
  surveys <- merge(surveys, st, by = c("iso3", "year"), all.x = TRUE)
  surveys[is.na(n_status), n_status := 0L]
  surveys[, status := status_raw]
  surveys[, status_source_year := fifelse(n_status > 0, year, NA_integer_)]
  if (!isTRUE(s$n01)) {
    ## carry back from the earliest later year of the same country with responses
    surveys[, c("status", "status_source_year") := {
      st_y <- status_raw; src <- status_source_year
      for (i in seq_len(.N)) {
        if (n_status[i] == 0) {
          later <- which(year > year[i] & n_status > 0)
          if (length(later)) {
            j <- later[which.min(year[later])]
            st_y[i] <- status_raw[j]; src[i] <- year[j]
          }
        }
      }
      list(st_y, src)
    }, by = iso3]
  }
  ## country-year inputs
  cy_same <- cy[, .(iso3, year,
                    childcare = get(s$childcare_var),
                    parttime  = get(s$parttime_var),
                    gdp = gdp_index_undp, unemp = unemployment_rate, epl = epl_overall,
                    wmgr = women_managers_pct, fert = fertility_rate)]
  cy_leave <- cy[, .(iso3, year = year + s$leave_lag, leave = leave_fte_weeks)]
  surveys <- merge(surveys, cy_same, by = c("iso3", "year"), all.x = TRUE)
  surveys <- merge(surveys, cy_leave, by = c("iso3", "year"), all.x = TRUE)
  surveys[, leave_sq_raw := leave^2]
  surveys[, survey := paste(iso3, year, sep = "_")]
  surveys
}

## ---------------------------------------------------------------------------
## 6. Standardization constants
## ---------------------------------------------------------------------------
## m3_sample: the M3-equivalent stage-1 sample (individual rows) under the run's
## settings, with the raw survey-level variables merged in.
compute_constants <- function(m3_sample, s) {
  vars <- SURVEY_RAW
  if (s$leave_sq_std == "U14") vars <- c(vars, "leave_sq_raw")
  cons <- list()
  if (s$std_method == "U16") {
    base <- m3_sample
    n_units <- nrow(base)
    unit <- "individual rows of the M3 estimation sample"
  } else if (s$std_method == "U15") {
    sv <- unique(m3_sample[, c("iso3", "survey", vars), with = FALSE], by = "survey")
    base <- sv[, lapply(.SD, mean), by = iso3, .SDcols = vars]
    n_units <- nrow(base)
    unit <- "country means over surveys of the M3 stage-1 sample"
  } else {
    base <- unique(m3_sample[, c("survey", vars), with = FALSE], by = "survey")
    n_units <- nrow(base)
    unit <- "surveys of the M3 stage-1 sample (each once)"
  }
  for (v in vars) {
    x <- base[[v]]
    cons[[v]] <- list(mean = mean(x), sd = sd(x))   # sd(): n - 1 divisor
  }
  degenerate <- names(cons)[sapply(cons, function(k) is.na(k$sd) || k$sd == 0)]
  list(constants = cons, n_units = n_units, unit = unit,
       n_surveys = uniqueN(m3_sample$survey), n_rows = nrow(m3_sample),
       degenerate = degenerate)
}

apply_constants <- function(d, cons, s) {
  d <- copy(d)
  for (v in SURVEY_RAW) {
    d[, (v) := (get(v) - cons$constants[[v]]$mean) / cons$constants[[v]]$sd]
  }
  if (s$leave_sq_std == "U14") {
    d[, leave_sq := (leave_sq_raw - cons$constants$leave_sq_raw$mean) / cons$constants$leave_sq_raw$sd]
  } else {
    d[, leave_sq := leave^2]
  }
  d
}

## ---------------------------------------------------------------------------
## 7. Model samples and formulas
## ---------------------------------------------------------------------------
model_survey_vars <- function(model, s) {
  m <- MODELS[[model]]
  if (m$terms == "base") return(character(0))
  v <- c(X_VARS, C_VARS)
  if (m$terms == "R2" && !isTRUE(s$r2_fert)) v <- setdiff(v, "fert")
  v
}

model_fixed_terms <- function(model, s, year_levels) {
  m <- MODELS[[model]]
  yr <- paste0("year", year_levels[-1])
  base <- c("female", "age_c", "age_c2", "postsecondary", yr)
  if (m$terms == "base") return(base)
  xc <- c(X_VARS, C_VARS)
  if (m$terms == "XC") return(c(base, xc))
  if (m$terms == "FX") return(c(base, xc, FX_VARS))
  if (m$terms == "S2") return(c(base, xc, FX_VARS, "sole", "bage_c"))
  if (m$terms == "R2") {
    if (!isTRUE(s$r2_fert)) xc <- setdiff(xc, "fert")
    return(c(base, xc, FX_VARS, "not_employed"))
  }
  if (m$terms == "R3") return(c(base, xc, FX_VARS, "skill", "fear", "knows"))
  stop("unknown term set")
}

## Build the estimation sample for a model. `d` has steps 1-3 flags, the
## individual variables, and the (standardized) survey variables merged in.
## Returns the data.table (uncentred) or NULL.
build_sample <- function(d, model, s) {
  m <- MODELS[[model]]
  sv <- model_survey_vars(model, s)
  if (m$sample == "S1" || m$sample == "R3") {
    x <- d[step1 & step2 & step3]
    need <- c("activity", "female", "age", "postsecondary", sv)
    if (m$outcome != "activity") need <- c(need, m$outcome)
    if (m$sample == "R3") need <- c(need, "skill", "fear", "knows")
  } else if (m$sample == "R2") {
    x <- d[step1 & step2]
    need <- c("activity", "female", "age", "postsecondary", "not_employed", sv)
  } else if (m$sample == "S2") {
    x <- d[step1 & step2 & step3 & owner == 1]
    need <- c(m$outcome, "female", "age", "postsecondary", "sole", "bage", sv)
    x <- x[year %in% m$years]
  }
  need <- unique(need)
  ok <- complete.cases(as.data.frame(x[, need, with = FALSE]))
  x <- x[ok]
  x
}

center_sample <- function(x, model, means = NULL) {
  x <- copy(x)
  uses_bage <- MODELS[[model]]$sample == "S2"
  if (is.null(means)) {
    means <- list(age = if (nrow(x)) mean(x$age) else NA_real_,
                  bage = if (uses_bage && nrow(x)) mean(x$bage) else NA_real_)
  }
  x[, age_c := age - means$age]
  x[, age_c2 := age_c^2]
  if (uses_bage) x[, bage_c := bage - means$bage]
  attr(x, "centering") <- means
  x
}

year_levels_for <- function(x, model) {
  m <- MODELS[[model]]
  present <- sort(unique(x$year))
  ref <- m$ref
  if (!ref %in% present) ref <- present[1]     # reference absent (e.g. N01): earliest year present
  c(ref, setdiff(present, ref))
}

make_formulas <- function(model, s, year_levels) {
  terms <- model_fixed_terms(model, s, year_levels)
  ## year dummies are generated by factor(year); use "year" in the formula
  terms_f <- unique(ifelse(grepl("^year", terms), "year", terms))
  fixed <- paste(terms_f, collapse = " + ")
  if (s$cov == "indep") {
    re <- "(1 | iso3) + (0 + female | iso3) + (1 | survey) + (0 + female | survey)"
  } else {
    re <- "(1 + female | iso3) + (1 + female | survey)"
  }
  outcome <- MODELS[[model]]$outcome
  list(
    mixed = as.formula(paste(outcome, "~", fixed, "+", re)),
    fixed = as.formula(paste(outcome, "~", fixed)),
    terms = terms
  )
}

## ---------------------------------------------------------------------------
## 8. Fitting
## ---------------------------------------------------------------------------
sample_hash <- function(ids) {
  ids <- as.character(ids)
  if (all(grepl("^[0-9]+$", ids))) {
    ids <- ids[order(nchar(ids), ids)]             # numeric order for integer ids
  } else {
    ids <- sort(ids, method = "radix")             # C-locale byte order
  }
  digest(paste(ids, collapse = ","), algo = "sha256", serialize = FALSE)
}

fit_mixed <- function(f, x, model, s) {
  warns <- character(0)
  fam <- MODELS[[model]]$family
  fit <- withCallingHandlers({
    if (fam == "logit") {
      glmer(f, data = x, family = binomial(link = "logit"), nAGQ = 1L)
    } else {
      reml <- (model == "M5" && isTRUE(s$m5_reml))
      lmer(f, data = x, REML = reml)
    }
  }, warning = function(w) {
    warns <<- c(warns, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  list(fit = fit, warnings = unique(warns))
}

routine_name <- function(model, s) {
  if (MODELS[[model]]$family == "logit") {
    "lme4::glmer(family=binomial(logit), nAGQ=1 [Laplace], ML)"
  } else if (model == "M5" && isTRUE(s$m5_reml)) {
    "lme4::lmer(REML=TRUE)"
  } else {
    "lme4::lmer(REML=FALSE [ML])"
  }
}

extract_varcorr <- function(fit) {
  vc <- as.data.frame(VarCorr(fit))
  vc$grp0 <- sub("\\.[0-9]+$", "", vc$grp)
  pick <- function(g, v) {
    r <- vc[vc$grp0 == g & !is.na(vc$var1) & vc$var1 == v & is.na(vc$var2), "sdcor"]
    if (length(r) == 1) r else NA_real_
  }
  list(sd_country_intercept = pick("iso3", "(Intercept)"),
       sd_country_female    = pick("iso3", "female"),
       sd_survey_intercept  = pick("survey", "(Intercept)"),
       sd_survey_female     = pick("survey", "female"))
}

## Benchmark: pooled regression with country-clustered CR1 sandwich SE
fit_bench <- function(f, x, model) {
  fam <- MODELS[[model]]$family
  if (fam == "logit") {
    bf <- glm(f, data = x, family = binomial(link = "logit"))
  } else {
    bf <- lm(f, data = x)
  }
  V <- vcovCL(bf, cluster = x$iso3, type = "HC0", cadjust = TRUE)   # G/(G-1) only
  b <- coef(bf)
  se <- rep(NA_real_, length(b)); names(se) <- names(b)
  se[colnames(V)] <- sqrt(diag(V))
  p <- 2 * pnorm(-abs(b / se))
  list(fit = bf, est = b, se = se, p = p)
}

## Wild cluster bootstrap (Rademacher, null imposed, restricted residuals) for
## the F x X terms of M5. Returns named vector of p-values.
wild_cluster_p <- function(f_fixed, x, terms, B = 999L, seed = 20261028L) {
  mf <- model.frame(f_fixed, data = x)
  y  <- model.response(mf)
  X  <- model.matrix(f_fixed, data = mf)
  keep <- !is.na(coef(lm.fit(X, y)))
  X <- X[, keep, drop = FALSE]
  cl <- as.integer(factor(x$iso3))
  G  <- max(cl)
  n  <- nrow(X)
  XtX_inv <- solve(crossprod(X))
  A <- XtX_inv %*% t(X)                         # k x n
  cr1_var_j <- function(E, u) {
    ## E: n x B residual matrix, u: n-vector X %*% XtX_inv[, j]
    S <- rowsum(u * E, cl)                      # G x B
    (G / (G - 1)) * colSums(S^2)
  }
  out <- setNames(rep(NA_real_, length(terms)), terms)
  ## full-model statistics
  b_full <- drop(A %*% y)
  e_full <- y - drop(X %*% b_full)
  for (tj in terms) {
    if (!tj %in% colnames(X)) next
    j <- match(tj, colnames(X))
    u <- drop(X %*% XtX_inv[, j])
    t_obs <- b_full[j] / sqrt(cr1_var_j(matrix(e_full, ncol = 1), u))
    ## restricted model (term j dropped)
    Xr <- X[, -j, drop = FALSE]
    br <- solve(crossprod(Xr), crossprod(Xr, y))
    fr <- drop(Xr %*% br)
    er <- y - fr
    set.seed(seed)
    W <- matrix(sample(c(-1, 1), G * B, replace = TRUE), nrow = G, ncol = B)   # Rademacher
    Ystar <- fr + er * W[cl, , drop = FALSE]      # n x B
    Bstar <- A %*% Ystar                           # k x B
    Estar <- Ystar - X %*% Bstar
    vj <- cr1_var_j(Estar, u)
    tstar <- Bstar[j, ] / sqrt(vj)
    out[tj] <- mean(abs(tstar) >= abs(t_obs))
  }
  out
}

## Fit one model on a prepared, centred sample; return result rows (data.table)
fit_one <- function(run_id, model, x, s, deleted_country = "", degenerate = character(0)) {
  rows_template <- function() data.table(
    run_id = run_id, model = model, deleted_country = deleted_country,
    status = NA_character_, error = "", n_obs = NA_integer_, n_countries = NA_integer_,
    n_surveys = NA_integer_, sample_hash = NA_character_, term = NA_character_,
    estimate = NA_real_, se = NA_real_, z = NA_real_, p = NA_real_,
    bench_se = NA_real_, bench_p = NA_real_, wild_p = NA_real_,
    loglik = NA_real_, aic = NA_real_, converged = NA, singular = NA,
    routine = routine_name(model, s),
    sd_country_intercept = NA_real_, sd_country_female = NA_real_,
    sd_survey_intercept = NA_real_, sd_survey_female = NA_real_)

  base <- rows_template()
  n_obs <- nrow(x)
  base$n_obs <- n_obs
  if (n_obs > 0) {
    base$n_countries <- uniqueN(x$iso3)
    base$n_surveys   <- uniqueN(x$survey)
    base$sample_hash <- sample_hash(x$ID_9817_RDM)
  }
  outcome <- MODELS[[model]]$outcome
  ## not estimable checks
  reason <- NULL
  if (n_obs == 0) {
    reason <- "empty estimation sample"
    if (length(degenerate)) reason <- paste0(reason, " (standardization SD undefined or zero for: ",
                                             paste(degenerate, collapse = ", "), ")")
  } else if (uniqueN(x[[outcome]]) < 2) reason <- paste0("outcome ", outcome, " has no variation")
  else if (uniqueN(x$iso3) < 2) reason <- "fewer than two countries in sample"
  if (!is.null(reason)) {
    base$status <- "not_estimable"; base$error <- reason
    return(base)
  }
  yl <- year_levels_for(x, model)
  x[, year := factor(year, levels = yl)]
  fm <- make_formulas(model, s, yl)

  ## ---- mixed fit ----
  mixed <- tryCatch(fit_mixed(fm$mixed, x, model, s), error = function(e) e)
  ## ---- benchmark ----
  bench <- tryCatch(fit_bench(fm$fixed, x, model), error = function(e) e)
  wild <- NULL
  if (model == "M5") {
    wild <- tryCatch(wild_cluster_p(fm$fixed, x, FX_VARS), error = function(e) e)
  }

  mixed_ok <- !inherits(mixed, "error")
  bench_ok <- !inherits(bench, "error")
  term_names <- character(0)
  if (mixed_ok) term_names <- names(fixef(mixed$fit))
  if (bench_ok) term_names <- union(term_names, names(bench$est))
  if (!length(term_names)) {
    base$status <- "failed"
    base$error <- paste0("mixed: ", conditionMessage(mixed), " | bench: ", conditionMessage(bench))
    return(base)
  }
  res <- base[rep(1, length(term_names))]
  res$term <- term_names
  if (mixed_ok) {
    fit <- mixed$fit
    cf <- summary(fit)$coefficients
    est <- cf[, "Estimate"]; se <- cf[, "Std. Error"]
    z <- est / se; p <- 2 * pnorm(-abs(z))
    idx <- match(term_names, rownames(cf))
    res$estimate <- est[idx]; res$se <- se[idx]; res$z <- z[idx]; res$p <- p[idx]
    ll <- logLik(fit)
    res$loglik <- as.numeric(ll)
    res$aic <- AIC(fit)
    conv_msgs <- unlist(fit@optinfo$conv$lme4$messages)
    opt_code <- fit@optinfo$conv$opt
    ## singularity is reported in its own column; it does not count as non-convergence
    conv_msgs_nonsing <- conv_msgs[!grepl("singular", conv_msgs, ignore.case = TRUE)]
    res$converged <- (length(conv_msgs_nonsing) == 0) && (is.null(opt_code) || opt_code == 0)
    res$singular <- isSingular(fit)
    vc <- extract_varcorr(fit)
    for (nm in names(vc)) res[[nm]] <- vc[[nm]]
    res$status <- "ok"
    msgs <- c(mixed$warnings, unlist(conv_msgs))
    if (length(msgs)) res$error <- paste0("warning: ", paste(unique(msgs), collapse = " || "))
  } else {
    res$status <- "failed"
    res$error <- paste0("mixed fit error: ", conditionMessage(mixed))
  }
  if (bench_ok) {
    idx <- match(term_names, names(bench$est))
    res$bench_se <- bench$se[idx]
    res$bench_p  <- bench$p[idx]
  } else {
    res$error <- paste(res$error, paste0("bench error: ", conditionMessage(bench)), sep = " || ")
  }
  if (!is.null(wild)) {
    if (inherits(wild, "error")) {
      res$error <- paste(res$error, paste0("wild bootstrap error: ", conditionMessage(wild)), sep = " || ")
    } else {
      idx <- match(term_names, names(wild))
      res$wild_p <- wild[idx]
    }
  }
  res$error <- sub("^ \\|\\| ", "", res$error)
  res
}

failed_row <- function(run_id, model, msg, deleted_country = "", s = origin_settings()) {
  data.table(
    run_id = run_id, model = model, deleted_country = deleted_country,
    status = "failed", error = msg, n_obs = NA_integer_, n_countries = NA_integer_,
    n_surveys = NA_integer_, sample_hash = NA_character_, term = NA_character_,
    estimate = NA_real_, se = NA_real_, z = NA_real_, p = NA_real_,
    bench_se = NA_real_, bench_p = NA_real_, wild_p = NA_real_,
    loglik = NA_real_, aic = NA_real_, converged = NA, singular = NA,
    routine = tryCatch(routine_name(model, s), error = function(e) NA_character_),
    sd_country_intercept = NA_real_, sd_country_female = NA_real_,
    sd_survey_intercept = NA_real_, sd_survey_female = NA_real_)
}

## ---------------------------------------------------------------------------
## 9. Run drivers
## ---------------------------------------------------------------------------
## Prepare everything for a run: individual data with survey variables merged
## (standardized), plus the constants object.
prepare_run <- function(inputs, s) {
  d <- build_individual(inputs$gem, s)
  sv <- build_survey(d, inputs$cy, s)
  d <- merge(d, sv[, c("survey", SURVEY_RAW, "leave_sq_raw", "status_source_year"), with = FALSE],
             by = "survey", all.x = TRUE, sort = FALSE)
  ## M3-equivalent stage-1 sample under these settings (raw survey variables;
  ## leave_sq is missing exactly when leave is missing)
  d[, leave_sq := leave_sq_raw]
  m3 <- build_sample(d, "M3", s)
  cons <- compute_constants(m3, s)
  d <- apply_constants(d, cons, s)
  list(d = d, cons = cons, survey_table = sv)
}

run_models <- function(run_id, models, inputs, results, constants_out) {
  s <- settings_for(run_id)
  logmsg("run %s: preparing data", run_id)
  prep <- tryCatch(prepare_run(inputs, s), error = function(e) e)
  if (inherits(prep, "error")) {
    msg <- paste0("data preparation error: ", conditionMessage(prep))
    logmsg("run %s: %s", run_id, msg)
    for (m in models) results[[length(results) + 1]] <- failed_row(run_id, m, msg, s = s)
    return(list(results = results, constants_out = constants_out))
  }
  constants_out[[run_id]] <- c(list(settings = s), prep$cons)
  for (m in models) {
    t0 <- Sys.time()
    row <- tryCatch({
      x <- build_sample(prep$d, m, s)
      x <- center_sample(x, m)
      r <- fit_one(run_id, m, x, s, degenerate = prep$cons$degenerate)
      cm <- attr(x, "centering")
      constants_out[[run_id]]$centering[[m]] <- list(age_mean = cm$age, bage_mean = cm$bage,
                                                      n_obs = nrow(x))
      r
    }, error = function(e) failed_row(run_id, m, conditionMessage(e), s = s))
    results[[length(results) + 1]] <- row
    logmsg("run %s model %s: status=%s n=%s (%.1fs)", run_id, m, row$status[1],
           as.character(row$n_obs[1]), as.numeric(difftime(Sys.time(), t0, units = "secs")))
  }
  list(results = results, constants_out = constants_out)
}

run_influence <- function(models, inputs, results, constants_out) {
  s <- settings_for("ORIGIN")
  logmsg("influence: preparing origin data")
  prep <- tryCatch(prepare_run(inputs, s), error = function(e) e)
  if (inherits(prep, "error")) {
    msg <- paste0("data preparation error: ", conditionMessage(prep))
    for (m in models) results[[length(results) + 1]] <- failed_row("INFLUENCE", m, msg, s = s)
    return(list(results = results, constants_out = constants_out))
  }
  constants_out[["INFLUENCE"]] <- c(list(settings = s, note = "constants and centering means from the full ORIGIN sample"), prep$cons)
  for (m in models) {
    full <- tryCatch({ x <- build_sample(prep$d, m, s); center_sample(x, m) }, error = function(e) e)
    if (inherits(full, "error")) {
      results[[length(results) + 1]] <- failed_row("INFLUENCE", m, conditionMessage(full), s = s)
      next
    }
    cm <- attr(full, "centering")
    constants_out[["INFLUENCE"]]$centering[[m]] <- list(age_mean = cm$age, bage_mean = cm$bage, n_obs = nrow(full))
    countries <- sort(unique(full$iso3))
    for (cc in countries) {
      t0 <- Sys.time()
      row <- tryCatch({
        x <- copy(full[iso3 != cc])       # centring already done with full-sample means
        fit_one("INFLUENCE", m, x, s, deleted_country = cc)
      }, error = function(e) failed_row("INFLUENCE", m, conditionMessage(e), deleted_country = cc, s = s))
      results[[length(results) + 1]] <- row
      logmsg("influence %s minus %s: status=%s n=%s (%.1fs)", m, cc, row$status[1],
             as.character(row$n_obs[1]), as.numeric(difftime(Sys.time(), t0, units = "secs")))
    }
  }
  list(results = results, constants_out = constants_out)
}

## ---------------------------------------------------------------------------
## 10. Main
## ---------------------------------------------------------------------------
tokens <- trimws(unlist(strsplit(run_arg, ",")))
tokens <- tokens[nzchar(tokens)]
plan <- list()       # list of list(type, run_id, models)
for (tk in tokens) {
  if (tolower(tk) == "all") {
    for (r in ALL_RUNS) plan[[length(plan) + 1]] <- list(type = "run", run_id = r)
  } else if (tolower(tk) == "influence") {
    plan[[length(plan) + 1]] <- list(type = "influence", models = INFLUENCE_MODELS)
  } else if (grepl("^influence:", tolower(tk))) {
    ms <- toupper(unlist(strsplit(sub("^influence:", "", tk, ignore.case = TRUE), "\\+")))
    bad <- setdiff(ms, INFLUENCE_MODELS)
    if (length(bad)) stop("influence models not allowed: ", paste(bad, collapse = ","))
    plan[[length(plan) + 1]] <- list(type = "influence", models = ms)
  } else {
    r <- toupper(tk)
    if (!r %in% ALL_RUNS) stop("unknown run id: ", tk)
    plan[[length(plan) + 1]] <- list(type = "run", run_id = r)
  }
}
## de-duplicate runs, keep manifest order for plain runs
run_ids <- unique(unlist(lapply(plan, function(p) if (p$type == "run") p$run_id else NULL)))
run_ids <- ALL_RUNS[ALL_RUNS %in% run_ids]
infl <- unique(unlist(lapply(plan, function(p) if (p$type == "influence") p$models else NULL)))
infl <- INFLUENCE_MODELS[INFLUENCE_MODELS %in% infl]

logmsg("reading inputs from %s", data_dir)
inputs <- read_inputs(data_dir)
logmsg("gem_extract rows: %d; country_year rows: %d", nrow(inputs$gem), nrow(inputs$cy))

results <- list()
constants_out <- list()

for (r in run_ids) {
  models <- if (r == "ORIGIN") ORIGIN_MODELS else DEV_MODELS[[r]]
  out <- run_models(r, models, inputs, results, constants_out)
  results <- out$results; constants_out <- out$constants_out
  if (r == "ORIGIN") {
    ## Weighted branch: not executable with lme4 (section 7); report as unavailable.
    results[[length(results) + 1]] <- failed_row(
      "WEIGHTED", "", "weighted branch unavailable: lme4 glmer/lmer weights are not sampling weights (manifest section 7); not implemented",
      s = origin_settings())[, status := "not_estimable"]
  }
}
if (length(infl)) {
  out <- run_influence(infl, inputs, results, constants_out)
  results <- out$results; constants_out <- out$constants_out
}

## ---------------------------------------------------------------------------
## 11. Write outputs
## ---------------------------------------------------------------------------
col_order <- c("run_id", "model", "deleted_country", "status", "error", "n_obs", "n_countries",
               "n_surveys", "sample_hash", "term", "estimate", "se", "z", "p", "bench_se",
               "bench_p", "wild_p", "loglik", "aic", "converged", "singular", "routine",
               "sd_country_intercept", "sd_country_female", "sd_survey_intercept", "sd_survey_female")
if (length(results)) {
  res <- rbindlist(results, use.names = TRUE, fill = TRUE)
} else {
  res <- failed_row("NONE", "", "no runs requested")[0]
}
setcolorder(res, col_order)
res[, wild_p := fifelse(model == "M5" & term %in% FX_VARS, wild_p, NA_real_)]
res[, error := gsub("[[:space:]]+", " ", error)]   # single-line error/warning text
fwrite(res, file.path(out_dir, "results.csv"), na = "", quote = "auto")

## constants.json
const_json <- lapply(constants_out, function(cobj) {
  list(
    settings = cobj$settings,
    note = cobj$note,
    standardization_unit = cobj$unit,
    n_units = cobj$n_units,
    n_surveys_m3_stage1 = cobj$n_surveys,
    n_rows_m3_stage1 = cobj$n_rows,
    constants = cobj$constants,
    leave_sq_rule = if (identical(cobj$settings$leave_sq_std, "U14")) "standardized raw leave^2" else "(standardized leave)^2, not restandardized",
    centering = cobj$centering
  )
})
write_json(const_json, file.path(out_dir, "constants.json"), auto_unbox = TRUE, pretty = TRUE,
           digits = NA, null = "null", na = "null")

## session_info.txt
si <- c(capture.output(print(sessionInfo())), "",
        "Package versions:",
        sapply(c("lme4", "Matrix", "sandwich", "lmtest", "data.table", "jsonlite", "digest"),
               function(p) sprintf("  %s %s", p, as.character(packageVersion(p)))),
        "", sprintf("Script: run.R; run argument: %s", run_arg),
        sprintf("Data dir: %s", data_dir),
        sprintf("Started: %s; finished: %s; elapsed: %.1f min", format(t_start), format(Sys.time()),
                as.numeric(difftime(Sys.time(), t_start, units = "mins"))))
writeLines(si, file.path(out_dir, "session_info.txt"))
logmsg("done: %d result rows written to %s", nrow(res), out_dir)
