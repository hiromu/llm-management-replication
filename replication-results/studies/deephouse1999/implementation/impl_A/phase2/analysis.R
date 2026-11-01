#!/usr/bin/env Rscript
# =============================================================================
# analysis.R -- P-OPAQUE-01 (v1): parameterised implementation of manifest.md
#               and grid.json.  Run from this directory:  Rscript analysis.R
#
# Options:
#   --out-dir=PATH          write outputs under PATH instead of ./out
#   --construction-only     build the O_A / O_B samples, logs and descriptives
#                           only (no model fitting; used for debugging)
#
# Structure (all in this file):
#   0. setup, option parsing, logging helpers
#   1. input loading (Parquet via nanoparquet)
#   2. sample construction S1-S6 (build_sample), one function per step
#   3. estimation: design matrices, WLS/OLS/AR(1) fit, covariance, F tests,
#      centred-basis back-transformation, studentized-residual outlier rule
#   4. specification grid (origins, one-at-a-time deviations, checks)
#   5. influence diagnostics
#   6. outputs under out/
# The file can be source()d with ANALYSIS_SOURCE_ONLY <- TRUE to expose the
# functions without running (used by tests/).
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
  library(digest)
  library(nanoparquet)
})
options(warn = 1, stringsAsFactors = FALSE, width = 200)

# ---------------------------------------------------------------- 0. setup ---
ROOT <- normalizePath(".", mustWork = TRUE)
ARGS <- commandArgs(trailingOnly = TRUE)
opt_val <- function(flag, default) {
  hit <- grep(paste0("^", flag, "="), ARGS, value = TRUE)
  if (length(hit)) sub(paste0("^", flag, "="), "", hit[1]) else default
}
OUT_DIR <- opt_val("--out-dir", file.path(ROOT, "out"))
CONSTRUCTION_ONLY <- "--construction-only" %in% ARGS

YEARS_ALL  <- 1984:1992      # years with annual variables (1984 supplies lags)
YEARS_EST  <- 1985:1992      # estimation years
OUTLIER_ID <- 995151L
OUTLIER_YR <- 1987L
MARKET_AREA_CODE <- "5120"
MERGER_CODES <- c(213, 221, 222, 223, 810, 812)   # merger / absorption / consolidation (institution level)
CONTINUATION_CODES <- c(420, 440, 510, 820)       # charter change, org-type change, name change, reorganisation
# RSSD9425 bank type analysis code (manifest amendment v1.1 C2, code table in
# docs/rssd9425_codes.txt): 1, 2 = bankers' banks; 4 = primarily credit card activities;
# 9 = depository trust company. R02.no_special excludes these; missing counts as 0.
SPECIAL_CODES <- c(1, 2, 4, 9)
# Exact identities (total = sum of components) used by R15.identity_fill
IDENTITIES <- list("0010" = c("0081", "0071"), "1600" = c("1755", "1766"),
                   "1766" = c("1763", "1764"), "1975" = c("2008", "2011"),
                   "1350" = c("0276", "0277"))
# R13.components: the six component categories enumerated in grid.json, each
# mapped to item codes of the "other_loans_and_leases_and_loan_totals" group of
# docs/call_item_candidates.json (validated at run time; dictionary names quoted).
# Every code enters exactly once, so no acceptances or other items are added.
COMPONENT_ITEMS <- list(
  lease_financing_receivables                         = "2165",                    # "Lease financing receivables (net of unearned income)"
  loans_to_depository_institutions                    = c("1505", "1510", "1517"), # commercial banks in the U.S.; banks in foreign countries (1516 is a sub-item of 1510); other U.S. depository institutions
  obligations_of_states_and_political_subdivisions    = "2107",                    # "Obligations (other than securities and leases) of states and political subdivisions"
  loans_to_foreign_governments                        = "2081",                    # "Loans to foreign governments and official institutions"
  loans_to_purchase_securities_and_all_other_loans    = "1563")                    # "Other loans" = 1545 (purchasing or carrying securities) + 1564 (all other loans); 1564 has no RCFD column
COMPONENT_GROUP <- "other_loans_and_leases_and_loan_totals"

# Condition class for specifications that cannot be implemented from the inputs
# (manifest introduction: status `unavailable`, never a substitute).
unavailable <- function(...) {
  stop(structure(class = c("unavailable", "error", "condition"),
                 list(message = sprintf(...), call = NULL)))
}
need_input <- function(inp, name, what) {
  if (is.null(inp[[name]])) unavailable("%s requires input `%s`, which could not be loaded (%s)", what, name,
                                        inp$load_errors[[name]] %||% "missing")
  inp[[name]]
}
need_cols <- function(dt, cols, what) {
  miss <- setdiff(cols, names(dt))
  if (length(miss)) unavailable("%s requires column(s) %s, absent from the inputs", what, paste(miss, collapse = ", "))
  invisible(TRUE)
}

CONSTRUCTION_AXES <- sprintf("R%02d", 1:21)
MODEL_TERMS <- list(M1    = c("MS", "TER", "RMG", "lag"),
                    M2    = c("SD", "MS", "TER", "RMG", "lag"),
                    M3    = c("SD2", "SD", "MS", "TER", "RMG", "lag"),
                    M3_SQ = c("SD2", "MS", "TER", "RMG", "lag"))
F_COMPARISONS <- list(c("M2", "M1"), c("M3", "M1"), c("M3", "M2"), c("M3_SQ", "M1"))

msg <- function(...) cat(format(Sys.time(), "%H:%M:%S"), "-", sprintf(...), "\n")

sample_hash <- function(ids, years) {
  lines <- sort(sprintf("%d,%d", as.integer(ids), as.integer(years)), method = "radix")
  digest(paste0(paste0(lines, "\n"), collapse = ""), algo = "sha256", serialize = FALSE)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
nz <- function(x) ifelse(is.na(x), 0, x)

# ------------------------------------------------------------- 1. inputs ---
read_pq <- function(name) as.data.table(read_parquet(file.path(ROOT, "data", name)))

# Every input other than the main Call file is loaded under a guard: a file that
# is missing or lacks the columns a step needs is recorded in `load_errors`, and
# the specifications that depend on it are recorded as `unavailable` (via
# need_input / need_cols) instead of aborting the run or being marked `failed`.
load_inputs <- function() {
  msg("loading inputs")
  load_errors <- list()
  guarded <- function(name, expr) {
    tryCatch(expr, error = function(e) { load_errors[[name]] <<- conditionMessage(e); msg("  input `%s` unavailable: %s", name, conditionMessage(e)); NULL })
  }
  need <- function(dt, cols, file) {
    miss <- setdiff(cols, names(dt))
    if (length(miss)) stop(sprintf("%s lacks column(s) %s", file, paste(miss, collapse = ", ")))
    dt
  }
  # main Call file: required (nothing can be built without it)
  call <- need(read_pq("call_mnwi_core_1983q4_1993q4.parquet"), c("quarter", "RSSD9001", "RSSD9210", "RSSD9150"), "call file")
  call[, year := as.integer(substr(quarter, 1, 4))]
  call[, q := as.integer(substr(quarter, 6, 6))]
  call[, RSSD9001 := as.integer(RSSD9001)]
  call[, cf5 := sprintf("%02d%03d", as.integer(RSSD9210), as.integer(RSSD9150))]
  setkey(call, RSSD9001, year, q)

  pres <- guarded("pres", need(read_pq("call_item_presence_by_quarter.parquet"), c("item", "quarter", "in_file", "any_nonmissing_mnwi"), "presence file"))
  pres_nc <- NULL; pres_items <- NULL
  if (!is.null(pres)) {
    pres[, not_collected := (in_file == 0) | (any_nonmissing_mnwi == 0)]
    # list: item -> character vector of quarters in which the item is not collected
    pres_nc <- split(pres[not_collected == TRUE, quarter], pres[not_collected == TRUE, item])
    pres_items <- unique(pres$item)
  }

  msa <- guarded("msa", {
    m <- need(read_pq("msa_minneapolis_stpaul_counties_by_vintage.parquet"), c("area_code", "omb_definition_date", "definition_vintage", "county_fips5"), "MSA file")
    m <- m[area_code == MARKET_AREA_CODE]
    m[, def_date := as.Date(omb_definition_date)]
    m })

  defl <- guarded("defl", need(read_pq("deflators_long.parquet"), c("series_id", "provider", "frequency", "date", "value"), "deflator file"))

  fin_dec <- guarded("fin_dec", {
    fin <- need(read_pq("fdic_financials_core_mnwi_1984q1_1994q4.parquet"), c("CERT", "REPDTE", "STALP", "STCNTY", "DEP", "ROA"), "FDIC financials")
    fin[, year := as.integer(REPDTE %/% 10000)]
    fin[, is_dec := (REPDTE %% 10000) == 1231]
    fd <- fin[is_dec == TRUE]
    fd[, CERT := as.integer(CERT)]
    fd })
  # county FIPS for FDIC financials: STCNTY carries the county name; map via the county table + state.
  # Guarded separately (amendment v1.1 C1): only the name lookup (R19/R21.all_insured) depends on it.
  cty <- guarded("cty", need(read_pq("county_fips_mn_wi.parquet"), c("county_name", "state_fips", "county_fips5"), "county table"))
  if (!is.null(fin_dec)) {
    fin_dec[, state_fips := ifelse(STALP == "MN", "27", ifelse(STALP == "WI", "55", NA_character_))]
    fin_dec[, name_key := tolower(trimws(STCNTY))]
    if (!is.null(cty)) {
      cty[, name_key := tolower(trimws(sub("\\s+County$", "", county_name)))]
      fin_dec <- merge(fin_dec, cty[, .(state_fips, name_key, cf5 = county_fips5)], by = c("state_fips", "name_key"), all.x = TRUE)
    }
  }

  inst <- guarded("inst", {
    i <- need(read_pq("fdic_institutions_mnwi_and_linked.parquet"), c("CERT", "FED_RSSD", "ESTYMD", "STCNTY"), "FDIC institutions")
    i <- i[, .(CERT = as.integer(CERT), FED_RSSD = as.integer(FED_RSSD), est_date = as.Date(ESTYMD, format = "%m/%d/%Y"), STCNTY)]
    unique(i, by = "CERT") })

  ev <- guarded("ev", {
    e <- need(read_pq("fdic_structure_events_mnwi_1983_1994.parquet"), c("CERT", "ACQ_CERT", "OUT_CERT", "SUR_CERT", "FRM_CERT", "CHANGECODE", "CHANGECODE_DESC", "EFFDATE"), "FDIC structure events")
    e[, .(CERT = as.integer(CERT), ACQ_CERT = as.integer(ACQ_CERT), OUT_CERT = as.integer(OUT_CERT),
          SUR_CERT = as.integer(SUR_CERT), FRM_CERT = as.integer(FRM_CERT),
          CHANGECODE = as.integer(CHANGECODE), CHANGECODE_DESC,
          eff_year = as.integer(substr(EFFDATE, 1, 4)))] })

  candidates <- guarded("candidates", fromJSON(file.path(ROOT, "docs", "call_item_candidates.json"), simplifyVector = FALSE))

  # first appearance of each RSSD9001 in the Call files (all records, before any filter)
  first_app <- call[, .(first_quarter = quarter[which.min(year * 10 + q)]), by = RSSD9001]
  first_app[, first_date := as.Date(sprintf("%s-%02d-01", substr(first_quarter, 1, 4),
                                            (as.integer(substr(first_quarter, 6, 6)) - 1) * 3 + 1))]

  list(call = call, pres_nc = pres_nc, pres_items = pres_items, msa = msa, defl = defl,
       fin_dec = fin_dec, cty = cty, inst = inst, ev = ev, candidates = candidates, first_app = first_app,
       load_errors = load_errors)
}

# ---------------------------------------------------- 2. sample construction ---
lvl <- function(cfg, axis) cfg[[axis]]
scope_prefix <- function(cfg) if (lvl(cfg, "R16") == "R16.domestic") "RCON" else "RCFD"

# Counties of the market for year t under the active R01 rule
market_counties <- function(cfg, msa, year) {
  r01 <- lvl(cfg, "R01")
  if (r01 == "R01.dynamic") {
    cand <- msa[def_date <= as.Date(sprintf("%d-12-31", year))]
    vint <- cand[def_date == max(def_date), unique(definition_vintage)][1]
    cs <- msa[definition_vintage == vint, county_fips5]
  } else {
    cs <- msa[omb_definition_date == "1983-06-27", county_fips5]
  }
  if (r01 == "R01.mnonly") cs <- cs[substr(cs, 1, 2) == "27"]
  sort(unique(cs))
}

# --- S1: record filter ------------------------------------------------------
filter_records <- function(call, cfg, log) {
  r02 <- lvl(cfg, "R02")
  base_level <- if (r02 %in% c("R02.no_special", "R02.add_savings")) cfg$.origin_R02 else r02
  need_cols(call, c("CALL8786", "RSSD9048", "RSSD9331", if (r02 == "R02.no_special") "RSSD9425"), "S1 record filter")
  lev_ok <- call$CALL8786 %in% c(1, 2)
  charter_ok <- !is.na(call$RSSD9048) & call$RSSD9048 == 200
  entity_ok  <- !is.na(call$RSSD9331) & call$RSSD9331 == 1
  keep <- switch(base_level,
                 "R02.charter_entity" = charter_ok & lev_ok & entity_ok,
                 "R02.charter"        = charter_ok & lev_ok,
                 "R02.entity"         = entity_ok & lev_ok,
                 stop("unknown R02 base level ", base_level))
  # R02.no_special: RSSD9425 in SPECIAL_CODES (amendment v1.1 C2); missing RSSD9425 counts as 0
  special <- if (r02 == "R02.no_special") nz(call$RSSD9425) %in% SPECIAL_CODES else rep(FALSE, nrow(call))
  if (r02 == "R02.no_special") keep <- keep & !special
  savings_added <- rep(FALSE, nrow(call))
  if (r02 == "R02.add_savings") {
    savings_added <- !keep & !is.na(call$RSSD9048) & call$RSSD9048 == 300 & lev_ok
    keep <- keep | savings_added
  }
  s1 <- data.table(year = call$year, keep = keep, lev_fail = !lev_ok, charter_fail = !charter_ok,
                   entity_fail = !entity_ok, special = special, savings_added = savings_added)
  by_year <- s1[, .(records = .N, kept = sum(keep), dropped = sum(!keep),
                    dropped_reporting_level = sum(!keep & lev_fail),
                    dropped_charter = sum(!keep & charter_fail),
                    dropped_entity_type = sum(!keep & entity_fail),
                    dropped_special_purpose = sum(!keep & special),
                    savings_banks_admitted = sum(savings_added)), by = year][order(year)]
  special_log <- if (r02 == "R02.no_special") list(codes_excluded = SPECIAL_CODES, missing_treated_as = 0,
                                                   records_excluded_by_code = call[special & !is.na(RSSD9425), .N, by = .(RSSD9425)][order(RSSD9425)]) else "not applied"
  rec <- call[keep]
  # duplicates within quarter x RSSD9001: prefer CALL8786 == 1 over 2
  dup <- rec[, .N, by = .(quarter, RSSD9001)][N > 1]
  n_before <- rec[, .N, by = year]
  if (nrow(dup)) {
    rec[, pref := ifelse(CALL8786 == 1, 0L, 1L)]
    setorder(rec, RSSD9001, year, q, pref)
    rec <- rec[!duplicated(rec[, .(quarter, RSSD9001)])]
    rec[, pref := NULL]
    dup_log <- list(n_bank_quarters = nrow(dup), resolved = "kept CALL8786 == 1 over 2", cases = dup[, .(quarter, RSSD9001)])
  } else {
    dup_log <- list(n_bank_quarters = 0L)
  }
  # yearly attrition from duplicate removal (records kept by the filter -> unique bank-quarters)
  n_after <- rec[, .N, by = year]
  by_year <- merge(by_year, n_before[, .(year, records_before_duplicate_removal = N)], by = "year", all.x = TRUE)
  by_year <- merge(by_year, n_after[, .(year, records_after_duplicate_removal = N)], by = "year", all.x = TRUE)
  by_year[is.na(records_before_duplicate_removal), records_before_duplicate_removal := 0L]
  by_year[is.na(records_after_duplicate_removal), records_after_duplicate_removal := 0L]
  by_year[, duplicate_records_removed := records_before_duplicate_removal - records_after_duplicate_removal]
  log$S1_record_filter <- list(rule = r02, base_rule = base_level, by_year = by_year[order(year)],
                               special_purpose_filter = special_log, duplicate_records = dup_log)
  setkey(rec, RSSD9001, year, q)
  rec
}

# --- S2: market membership --------------------------------------------------
market_population <- function(rec, cfg, inp, log) {
  P <- scope_prefix(cfg)
  need_cols(rec, paste0(P, "2170"), "S2 market population")
  r01 <- lvl(cfg, "R01")
  if (r01 != "R01.rssdmsa") need_input(inp, "msa", "S2 market membership (county list)") else need_cols(rec, "RSSD9180", "R01.rssdmsa")
  # bank-years (RSSD9001 x year) with at least one filtered record but no Q4 record
  yr_all <- rec[year %in% YEARS_ALL, .(records = .N, has_q4 = any(q == 4)), by = .(RSSD9001, year)]
  no_q4_by_year <- yr_all[, .(bank_years_with_records = .N, bank_years_with_q4_record = sum(has_q4),
                              dropped_no_q4_record = sum(!has_q4)), by = year][order(year)]
  q4 <- rec[q == 4 & year %in% YEARS_ALL]
  q4[, TA := get(paste0(P, "2170"))]
  if (r01 == "R01.rssdmsa") {
    q4[, in_market := !is.na(RSSD9180) & RSSD9180 == as.numeric(MARKET_AREA_CODE)]
  } else {
    q4[, in_market := FALSE]
    for (t in YEARS_ALL) {
      cs <- market_counties(cfg, inp$msa, t)
      q4[year == t, in_market := cf5 %in% cs]
    }
  }
  q4[, ta_pos := !is.na(TA) & TA > 0]
  q4[, in_U := in_market & ta_pos]
  removed_before_bench <- 0L
  if (lvl(cfg, "R10") == "R10.before_benchmarks") {
    removed_before_bench <- q4[RSSD9001 == OUTLIER_ID & year == OUTLIER_YR & in_U == TRUE, .N]
    q4[RSSD9001 == OUTLIER_ID & year == OUTLIER_YR, in_U := FALSE]
  }
  by_year <- q4[, .(q4_records = .N, in_market = sum(in_market),
                    dropped_not_in_market = sum(!in_market),
                    dropped_total_assets_not_positive = sum(in_market & !ta_pos),
                    U_t = sum(in_U)), by = year]
  by_year <- merge(no_q4_by_year, by_year, by = "year", all = TRUE)[order(year)]
  log$S2_market_membership <- list(
    rule = r01,
    counties_by_year = lapply(setNames(YEARS_ALL, YEARS_ALL), function(t)
      if (r01 == "R01.rssdmsa") "RSSD9180 == 5120" else market_counties(cfg, inp$msa, t)),
    by_year = by_year,
    outlier_removed_before_benchmarks = removed_before_bench)
  q4[, .(RSSD9001, year, RSSD9050 = as.integer(RSSD9050), cf5, in_U)]
}

# --- S3 helpers: items with R15 handling -----------------------------------
# returns numeric vector for item column `col` over records `recs`
get_item <- function(recs, col, cfg, inp, counter = NULL) {
  x <- if (col %in% names(recs)) as.numeric(recs[[col]]) else rep(NA_real_, nrow(recs))
  r15 <- lvl(cfg, "R15")
  if (r15 == "R15.zero_if_not_collected") {
    # Zero-fill only with evidence from call_item_presence_by_quarter (in_file == 0 or
    # any_nonmissing_mnwi == 0 for that item-quarter). An item without presence metadata
    # has no such evidence and stays missing (counted in the log).
    if (is.null(inp$pres_items)) unavailable("R15.zero_if_not_collected requires call_item_presence_by_quarter, which could not be loaded (%s)", inp$load_errors$pres %||% "missing")
    if (col %in% inp$pres_items) {
      nc <- inp$pres_nc[[col]] %||% character(0)
      idx <- is.na(x) & recs$quarter %in% nc
      if (any(idx)) {
        x[idx] <- 0
        if (!is.null(counter)) counter$zero_filled[[col]] <- (counter$zero_filled[[col]] %||% 0L) + sum(idx)
      }
    } else if (!is.null(counter)) {
      counter$no_presence_metadata[[col]] <- (counter$no_presence_metadata[[col]] %||% 0L) + sum(is.na(x))
    }
  } else if (r15 == "R15.identity_fill") {
    code <- substr(col, 5, 8); pre <- substr(col, 1, 4)
    comps <- IDENTITIES[[code]]
    if (!is.null(comps)) {
      cm <- sapply(paste0(pre, comps), function(cc) if (cc %in% names(recs)) as.numeric(recs[[cc]]) else rep(NA_real_, nrow(recs)))
      cm <- matrix(cm, nrow = nrow(recs))
      fill <- is.na(x) & rowSums(is.na(cm)) == 0
      if (any(fill)) {
        x[fill] <- rowSums(cm[fill, , drop = FALSE])
        if (!is.null(counter)) counter$identity_filled[[col]] <- (counter$identity_filled[[col]] %||% 0L) + sum(fill)
      }
    }
  }
  x
}

# Eleven category amounts, total assets and deposits for a set of records
category_amounts <- function(recs, cfg, inp, counter = NULL) {
  P <- scope_prefix(cfg)
  it <- function(code, pre = P) get_item(recs, paste0(pre, code), cfg, inp, counter)
  TA <- it("2170")
  c_com <- if (lvl(cfg, "R11") == "R11.incl_accept") it("1600") else it("1766")
  re  <- it("1410"); ag <- it("1590"); ind <- it("1975")
  if (lvl(cfg, "R12") == "R12.plus_farmland") {
    farm <- it("1420", "RCON")
    re <- re - farm; ag <- ag + farm
  }
  gross <- it("1400")
  resid <- gross - c_com - re - ind - ag
  r13 <- lvl(cfg, "R13")
  oth <- switch(r13,
    "R13.gross_residual" = resid,
    "R13.net_unearned"   = resid - it("2123"),
    "R13.net_allowance"  = resid - it("2123") - it("3123"),
    "R13.components"     = {
      # Explicit sum over the six enumerated component categories (COMPONENT_ITEMS), every
      # item taken from the candidate list in docs/call_item_candidates.json (validated here).
      # Missing components follow the active R15 rule through it(); nothing else is added.
      cand <- need_input(inp, "candidates", "R13.components (component item list)")
      allowed <- unlist(cand[[COMPONENT_GROUP]]$codes)
      codes <- unlist(COMPONENT_ITEMS, use.names = FALSE)
      bad <- setdiff(codes, allowed)
      if (length(bad)) unavailable("R13.components: item code(s) %s are not in the `%s` group of call_item_candidates.json", paste(bad, collapse = ", "), COMPONENT_GROUP)
      s <- rep(0, nrow(recs))
      for (code in codes) s <- s + it(code)
      s
    },
    stop("unknown R13 level"))
  cash <- it("0010"); ff <- it("1350"); sec <- it("0390"); trd <- it("2146"); prem <- it("2145")
  r14 <- lvl(cfg, "R14")
  other <- switch(r14,
    "R14.broad"    = it("2150") + it("2130") + it("2155") + it("2143") + it("2160"),
    "R14.literal"  = it("2160"),
    "R14.residual" = TA - (c_com + re + ind + ag + oth + cash + ff + sec + trd + prem),
    stop("unknown R14 level"))
  dep_col <- if (lvl(cfg, "R18") == "R18.consolidated") "RCFD2200" else "RCON2200"
  DEP <- get_item(recs, dep_col, cfg, inp, counter)
  data.table(RSSD9001 = recs$RSSD9001, year = recs$year, q = recs$q, TA = TA,
             A1 = c_com, A2 = re, A3 = ind, A4 = ag, A5 = oth, A6 = cash, A7 = ff,
             A8 = sec, A9 = trd, A10 = prem, A11 = other, DEP = DEP)
}

# Shares and deposits at the R08 timing -> one row per bank-year
shares_by_timing <- function(amt, cfg) {
  acols <- paste0("A", 1:11); scols <- paste0("s", 1:11)
  r08 <- lvl(cfg, "R08")
  if (r08 == "R08.year_end") {
    x <- amt[q == 4]
    out <- x[, c("RSSD9001", "year", "TA", "DEP"), with = FALSE]
    for (k in 1:11) out[, (scols[k]) := ifelse(!is.na(x$TA) & x$TA > 0, x[[acols[k]]] / x$TA, NA_real_)]
    return(out[])
  }
  if (r08 == "R08.mean_of_quarter_shares") {
    x <- copy(amt)
    for (k in 1:11) x[, (scols[k]) := ifelse(!is.na(TA) & TA > 0, get(acols[k]) / TA, NA_real_)]
    out <- x[, c(list(TA = TA[q == 4][1], DEP = if (all(is.na(DEP))) NA_real_ else mean(DEP, na.rm = TRUE)),
                 lapply(.SD, function(v) if (all(is.na(v))) NA_real_ else mean(v, na.rm = TRUE))),
             by = .(RSSD9001, year), .SDcols = scols]
    return(out[])
  }
  if (r08 == "R08.ratio_of_means") {
    # share = (mean of the available quarterly item amounts) / (mean of the available
    # quarterly total assets), each mean taken separately over its own available quarters
    x <- copy(amt)
    out <- x[, c(list(TA = TA[q == 4][1], DEP = if (all(is.na(DEP))) NA_real_ else mean(DEP, na.rm = TRUE)),
                 lapply(.SD, function(v) {
                   mTA <- if (all(is.na(TA))) NA_real_ else mean(TA, na.rm = TRUE)
                   mv  <- if (all(is.na(v))) NA_real_ else mean(v, na.rm = TRUE)
                   if (is.na(mTA) || mTA <= 0) NA_real_ else mv / mTA })),
             by = .(RSSD9001, year), .SDcols = acols]
    setnames(out, acols, scols)
    return(out[])
  }
  stop("unknown R08 level")
}

# Average assets per R05/R06/R16 for bank-years in `keys` (RSSD9001, year)
compute_AA <- function(rec, cfg, inp, r06 = lvl(cfg, "R06"), counter = NULL) {
  P <- scope_prefix(cfg); r05 <- lvl(cfg, "R05")
  need_cols(rec, c(paste0(P, "3368"), paste0(P, "2170"), if (r05 == "R05.min2_fallback" && P == "RCFD") "RCON3368"), "average assets (R05/R06/R16)")
  qa <- rec[year %in% c(1983L, YEARS_ALL), .(RSSD9001, year, q)]
  a3368 <- as.numeric(rec[year %in% c(1983L, YEARS_ALL)][[paste0(P, "3368")]])
  if (r05 == "R05.min2_fallback" && P == "RCFD") {
    alt <- as.numeric(rec[year %in% c(1983L, YEARS_ALL)][["RCON3368"]])
    nfb <- sum(is.na(a3368) & !is.na(alt))
    a3368 <- ifelse(is.na(a3368), alt, a3368)
    if (!is.null(counter)) counter$rcon3368_fallback_quarters <- nfb
  }
  qa[, a3368 := a3368]
  qa[, ta := as.numeric(rec[year %in% c(1983L, YEARS_ALL)][[paste0(P, "2170")]])]
  w3 <- dcast(qa[year %in% YEARS_ALL], RSSD9001 + year ~ q, value.var = "a3368")
  wt <- dcast(qa[year %in% YEARS_ALL], RSSD9001 + year ~ q, value.var = "ta")
  for (k in as.character(1:4)) { if (!k %in% names(w3)) w3[, (k) := NA_real_]; if (!k %in% names(wt)) wt[, (k) := NA_real_] }
  setnames(w3, as.character(1:4), paste0("a", 1:4)); setnames(wt, as.character(1:4), paste0("t", 1:4))
  prev <- qa[q == 4, .(RSSD9001, year = year + 1L, t0 = ta)]
  W <- merge(w3, wt, by = c("RSSD9001", "year"), all = TRUE)
  W <- merge(W, prev, by = c("RSSD9001", "year"), all.x = TRUE)
  A <- as.matrix(W[, .(a1, a2, a3, a4)]); Tm <- as.matrix(W[, .(t0, t1, t2, t3, t4)])
  leap <- (W$year %% 4 == 0)
  days <- cbind(ifelse(leap, 91, 90), 91, 92, 92)
  navail <- rowSums(!is.na(A)); nta <- rowSums(!is.na(Tm))
  mean3368 <- ifelse(navail > 0, rowSums(A, na.rm = TRUE) / pmax(navail, 1), NA_real_)
  dmean3368 <- ifelse(navail > 0, rowSums(A * days, na.rm = TRUE) / rowSums(days * !is.na(A)), NA_real_)
  ta_mean <- ifelse(nta > 0, rowSums(Tm, na.rm = TRUE) / pmax(nta, 1), NA_real_)
  val <- if (r06 == "R06.rck_days") dmean3368 else mean3368
  reason <- rep("ok", nrow(W))
  AA <- switch(r06,
    "R06.rck_mean" = , "R06.rck_days" = , "R06.fdic_roa" = {
      switch(r05,
        "R05.min2_fallback" = {
          out <- ifelse(navail >= 2, val, ifelse(navail == 0 & nta >= 1, ta_mean, NA_real_))
          reason[navail == 0 & nta >= 1] <- "fallback_mean_2170_Q4t-1_to_Q4t"
          reason[navail == 1] <- "missing_only_one_quarter_of_3368"
          reason[navail == 0 & nta == 0] <- "missing_no_3368_no_2170"
          out },
        "R05.all4" = { out <- ifelse(navail == 4, val, NA_real_); reason[navail < 4] <- "missing_fewer_than_4_quarters_of_3368"; out },
        "R05.any"  = { out <- ifelse(navail >= 1, val, NA_real_); reason[navail == 0] <- "missing_no_3368"; out },
        stop("unknown R05 level"))
    },
    "R06.five_point" = { out <- ifelse(nta == 5, ta_mean, NA_real_); reason[nta < 5] <- "missing_fewer_than_5_points_of_2170"; out },
    "R06.two_point"  = { out <- ifelse(!is.na(W$t0) & !is.na(W$t4), (W$t0 + W$t4) / 2, NA_real_); reason[is.na(out)] <- "missing_Q4t-1_or_Q4t_2170"; out },
    stop("unknown R06 level"))
  W[, .(RSSD9001, year, AA = AA, AA_reason = reason, n_quarters_3368 = navail)]
}

opening_dates <- function(keys, inp) {
  # keys: RSSD9001, RSSD9050 (unique banks). FDIC ESTYMD via CERT; else first appearance in the Call files
  k <- unique(keys[, .(RSSD9001, RSSD9050)])
  inst <- if (is.null(inp$inst)) data.table(CERT = integer(0), est_date = as.Date(character(0))) else inp$inst
  k <- merge(k, inst[, .(RSSD9050 = CERT, est_date)], by = "RSSD9050", all.x = TRUE)
  k <- merge(k, inp$first_app[, .(RSSD9001, first_date)], by = "RSSD9001", all.x = TRUE)
  k[, open_source := ifelse(!is.na(est_date), "fdic_estymd", "first_call_appearance")]
  k[, open_date := as.Date(ifelse(is.na(est_date), first_date, est_date), origin = "1970-01-01")]
  unique(k[, .(RSSD9001, open_date, open_source)], by = "RSSD9001")
}

# --- S3: annual bank variables (for all filtered Q4 records; in_U flags market) ---
build_annual <- function(rec, U, cfg, inp, log) {
  counter <- new.env()
  P <- scope_prefix(cfg)
  q4 <- rec[q == 4 & year %in% YEARS_ALL]
  base <- q4[, .(RSSD9001, year, RSSD9050 = as.integer(RSSD9050), cf5)]
  base <- merge(base, U[, .(RSSD9001, year, in_U)], by = c("RSSD9001", "year"), all.x = TRUE)
  base[is.na(in_U), in_U := FALSE]
  # shares & deposits
  amt <- category_amounts(rec[year %in% YEARS_ALL], cfg, inp, counter)
  sh <- shares_by_timing(amt, cfg)
  base <- merge(base, sh, by = c("RSSD9001", "year"), all.x = TRUE)
  # average assets
  aa <- compute_AA(rec, cfg, inp, counter = counter)
  base <- merge(base, aa, by = c("RSSD9001", "year"), all.x = TRUE)
  if (lvl(cfg, "R06") == "R06.fdic_roa") {
    aa_ter <- compute_AA(rec, cfg, inp, r06 = "R06.rck_mean")
    base <- merge(base, aa_ter[, .(RSSD9001, year, AA_ter = AA)], by = c("RSSD9001", "year"), all.x = TRUE)
  } else base[, AA_ter := AA]
  # income and expenses (calendar year-to-date at Q4)
  ni_col <- if (lvl(cfg, "R07") == "R07.before_extraordinary") "RIAD4300" else "RIAD4340"
  need_cols(q4, c(ni_col, "RIAD4073", "RIAD4093"), "S3 income and expenses (R07)")
  inc <- q4[, .(RSSD9001, year, NI = as.numeric(get(ni_col)), EXP = as.numeric(RIAD4073) + as.numeric(RIAD4093))]
  base <- merge(base, inc, by = c("RSSD9001", "year"), all.x = TRUE)
  # opening dates (R04)
  od <- opening_dates(base, inp)
  base <- merge(base, od, by = "RSSD9001", all.x = TRUE)
  base[, annualised := FALSE]
  if (lvl(cfg, "R04") == "R04.annualise") {
    base[, open_year := as.integer(format(open_date, "%Y"))]
    base[, months_op := ifelse(!is.na(open_year) & open_year == year, 12L - as.integer(format(open_date, "%m")) + 1L, 12L)]
    base[months_op < 12, `:=`(NI = NI * 12 / months_op, EXP = EXP * 12 / months_op, annualised = TRUE)]
    base[, c("open_year", "months_op") := NULL]
  }
  base[, ROA := ifelse(!is.na(AA) & AA > 0, NI / AA, NA_real_)]
  if (lvl(cfg, "R06") == "R06.fdic_roa") {
    fr <- need_input(inp, "fin_dec", "R06.fdic_roa")[, .(RSSD9050 = CERT, year, ROA_fdic = as.numeric(ROA) / 100)]
    fr <- unique(fr, by = c("RSSD9050", "year"))
    base <- merge(base, fr, by = c("RSSD9050", "year"), all.x = TRUE)
    base[, ROA := ROA_fdic][, ROA_fdic := NULL]
  }
  base[, TER := ifelse(!is.na(AA_ter) & AA_ter > 0, EXP / AA_ter, NA_real_)]
  setkey(base, RSSD9001, year)
  scols <- paste0("s", 1:11)
  u <- base[in_U == TRUE]
  log$S3_annual_variables <- list(
    scope_prefix = P, income_item = ni_col,
    by_year = u[, c(list(U_t = .N, AA_missing = sum(is.na(AA)), NI_missing = sum(is.na(NI)),
                         ROA_missing = sum(is.na(ROA)), TER_missing = sum(is.na(TER)),
                         DEP_missing = sum(is.na(DEP)), any_share_missing = sum(!complete.cases(.SD)),
                         annualised = sum(annualised)),
                    lapply(.SD, function(v) sum(is.na(v)))), by = year, .SDcols = scols][order(year)],
    AA_reasons = u[, .N, by = .(year, AA_reason)][order(year, AA_reason)],
    zero_if_not_collected_substitutions = as.list(counter$zero_filled %||% list()),
    missing_values_of_items_without_presence_metadata_left_missing = as.list(counter$no_presence_metadata %||% list()),
    identity_fills = as.list(counter$identity_filled %||% list()),
    rcon3368_fallback_quarters = counter$rcon3368_fallback_quarters %||% 0L,
    opening_date_source = unique(base[, .(RSSD9001, open_source)])[, .N, by = open_source])
  base
}

# --- S4: market benchmarks ----------------------------------------------------
sd_fun <- function(v, r17) {
  v <- v[!is.na(v)]; n <- length(v)
  if (n == 0) return(NA_real_)
  # population SD (denominator n) is defined for n >= 1 and equals 0 for a single
  # observation; the sample SD (denominator n - 1) needs n >= 2
  if (r17 == "R17.population_sd") return(sqrt(sum((v - mean(v))^2) / n))
  if (n < 2) NA_real_ else sd(v)
}

compute_benchmarks <- function(annual, cfg, ref_keys = NULL, log = NULL) {
  r09 <- lvl(cfg, "R09"); r17 <- lvl(cfg, "R17")
  scols <- paste0("s", 1:11)
  pop <- annual[in_U == TRUE]
  if (r09 == "R09.joint_complete") pop <- pop[complete.cases(pop[, c(scols, "ROA", "DEP"), with = FALSE])]
  if (!is.null(ref_keys)) {
    yrs <- unique(ref_keys$year)
    pop <- rbind(pop[!year %in% yrs], merge(pop, unique(ref_keys[, .(RSSD9001, year)]), by = c("RSSD9001", "year")))
  }
  out <- pop[, {
    m <- sapply(scols, function(s) if (all(is.na(get(s)))) NA_real_ else mean(get(s), na.rm = TRUE))
    sdv <- sapply(scols, function(s) sd_fun(get(s), r17))
    nn <- sapply(scols, function(s) sum(!is.na(get(s))))
    mroa <- if (r09 == "R09.weighted_roa") {
      ok <- !is.na(ROA) & !is.na(AA); if (any(ok)) sum(ROA[ok] * AA[ok]) / sum(AA[ok]) else NA_real_
    } else if (all(is.na(ROA))) NA_real_ else mean(ROA, na.rm = TRUE)
    c(list(n_pop = .N, n_roa = sum(!is.na(ROA)), n_dep = sum(!is.na(DEP)), meanROA = mroa, D = sum(DEP, na.rm = TRUE)),
      setNames(as.list(m), paste0("m", 1:11)), setNames(as.list(sdv), paste0("sd", 1:11)),
      setNames(as.list(nn), paste0("n", 1:11)))
  }, by = year][order(year)]
  if (!is.null(log)) {
    zs <- melt(out[, c("year", paste0("sd", 1:11)), with = FALSE], id.vars = "year")[!is.na(value) & value == 0]
    log$S4_benchmarks <- list(reference_population = r09, sd_rule = r17,
                              by_year = out[, .(year, n_pop, n_roa, n_dep, meanROA, D)],
                              zero_sd_category_years = if (nrow(zs)) zs[, .(year, category = variable)] else "none")
  }
  out
}

# strategic deviation for a table of shares given benchmarks (vectorised; used by tests too)
compute_SD <- function(shares, bench, r17) {
  # shares: data.table with year, s1..s11; bench: data.table with year, m1..m11, sd1..sd11
  scols <- paste0("s", 1:11)
  x <- merge(shares[, c("year", scols), with = FALSE], bench, by = "year", all.x = TRUE, sort = FALSE)
  z <- matrix(NA_real_, nrow(x), 11)
  for (k in 1:11) {
    s <- x[[paste0("s", k)]]; m <- x[[paste0("m", k)]]; sdv <- x[[paste0("sd", k)]]
    zk <- abs((s - m) / sdv)
    if (r17 == "R17.zero_sd_missing") {
      zk[!is.na(sdv) & sdv == 0] <- NA_real_
    } else {
      zk[!is.na(sdv) & sdv == 0 & !is.na(s)] <- 0
    }
    z[, k] <- zk
  }
  rowSums(z)   # NA if any category NA
}

deflator_series <- function(defl, r20) {
  if (is.null(defl)) unavailable("%s requires deflators_long.parquet, which could not be loaded", r20)
  d <- switch(r20,
    "R20.cpi_annual"     = defl[series_id == "CPIAUCNS" & grepl("annual average", frequency), .(year = as.integer(substr(date, 1, 4)), P = value)],
    "R20.cpi_december"   = defl[series_id == "CPIAUCNS" & frequency == "as provided" & substr(date, 6, 7) == "12", .(year = as.integer(substr(date, 1, 4)), P = value)],
    "R20.local_cpi"      = defl[series_id == "CUUSA211SA0" & provider == "FRED", .(year = as.integer(substr(date, 1, 4)), P = value)],
    "R20.gdp_current"    = defl[series_id == "A191RD3A086NBEA" & provider == "FRED", .(year = as.integer(substr(date, 1, 4)), P = value)],
    "R20.gdp_historical" = defl[series_id == "GDPDEF" & provider == "ALFRED" & grepl("1999-01-01", vintage),
                                .(P = mean(value)), by = .(year = as.integer(substr(date, 1, 4)))],
    stop("unknown R20 level"))
  d <- unique(d[!is.na(P)], by = "year")[order(year)]
  if (!nrow(d)) unavailable("%s: the deflator series is not present in deflators_long.parquet", r20)
  d
}

fdic_insured_deposits <- function(inp, cfg) {
  # Sum of FDIC DEP at Dec 31 over all insured institutions located in the market counties of year t
  need_input(inp, "fin_dec", "R19/R21.all_insured"); need_input(inp, "msa", "R19/R21.all_insured (county list)")
  if (is.null(inp$cty)) unavailable("R19/R21.all_insured requires county_fips_mn_wi.parquet for the county-name lookup, which could not be loaded (%s)", inp$load_errors$cty %||% "missing")
  rbindlist(lapply(YEARS_ALL, function(t) {
    cs <- if (lvl(cfg, "R01") == "R01.rssdmsa") market_counties(modifyList(cfg, list(R01 = "R01.fixed1983")), inp$msa, t) else market_counties(cfg, inp$msa, t)
    x <- inp$fin_dec[year == t & !is.na(cf5) & cf5 %in% cs]
    data.table(year = t, D_ins = sum(x$DEP, na.rm = TRUE), n_ins = nrow(x))
  }))
}

# merger events: (CERT, year) of acquirers / survivors, and their outgoing partners
merger_survivors <- function(ev) {
  if (is.null(ev)) unavailable("R03 merger rules require fdic_structure_events, which could not be loaded")
  m <- ev[CHANGECODE %in% MERGER_CODES]
  a <- rbind(m[!is.na(ACQ_CERT), .(CERT = ACQ_CERT, year = eff_year, OUT_CERT)],
             m[!is.na(SUR_CERT), .(CERT = SUR_CERT, year = eff_year, OUT_CERT)])
  a <- a[!is.na(CERT) & (is.na(OUT_CERT) | OUT_CERT != CERT)]
  unique(a)
}

# --- S5 helpers (also exercised by tests/) ------------------------------------
# relative ROA: y_it = 100 * (ROA_it - market mean ROA_t), benchmarks of the same year
relative_roa <- function(A, bench) {
  A <- merge(A, bench[, .(year, meanROA, D_comm = D)], by = "year", all.x = TRUE)
  A[, y := 100 * (ROA - meanROA)]
  A
}

# lag: y of the same RSSD9001 in calendar year t-1, taken from the market population
# of year t-1 (no gap-skipping; entries and gaps give a missing lag)
lag_as_reported <- function(A) {
  lagtab <- A[in_U == TRUE, .(RSSD9001, year = year + 1L, lag = y, lag_source = "as_reported")]
  A <- merge(A, lagtab, by = c("RSSD9001", "year"), all.x = TRUE)
  A[, has_prev_row := !is.na(lag_source)]
  A[is.na(lag_source), lag_source := "no_t-1_row"]
  A[has_prev_row & is.na(lag), lag_source := "t-1_y_missing"]
  A
}

# --- S5: derived variables ------------------------------------------------------
derive_variables <- function(annual, bench, cfg, inp, log, ref_keys = NULL) {
  r17 <- lvl(cfg, "R17"); r03 <- lvl(cfg, "R03")
  A <- copy(annual)
  A[, SD := compute_SD(A, bench[, c("year", paste0("m", 1:11), paste0("sd", 1:11)), with = FALSE], r17)]
  A[in_U == FALSE, SD := NA_real_]
  A[, SD2 := SD^2]
  A <- relative_roa(A, bench)
  # ---- lag (R03): same RSSD9001 at calendar year t-1, within the market population
  A <- lag_as_reported(A)
  A[, merger_drop := FALSE]
  if (r03 == "R03.drop_merger_years") {
    ms <- merger_survivors(inp$ev)[, .(RSSD9050 = CERT, year)]
    key_t  <- paste(ms$RSSD9050, ms$year)
    A[, merger_drop := paste(RSSD9050, year) %in% key_t | paste(RSSD9050, year - 1L) %in% key_t]
  }
  if (r03 == "R03.continuity") {
    cand <- A[!has_prev_row & in_U == TRUE & year > min(YEARS_ALL)]
    if (nrow(cand)) {
      prev <- A[in_U == TRUE, .(RSSD9050, pred_id = RSSD9001, year = year + 1L, pred_y = y)]
      cand <- merge(cand[, .(RSSD9001, RSSD9050, year)], prev, by = c("RSSD9050", "year"), allow.cartesian = TRUE)
      cand <- cand[pred_id != RSSD9001]
      if (nrow(cand)) {
        ev <- need_input(inp, "ev", "R03.continuity")
        cont <- ev[CHANGECODE %in% CONTINUATION_CODES, .(RSSD9050 = CERT, eff_year)]
        absorbed <- ev[CHANGECODE %in% MERGER_CODES & !is.na(OUT_CERT), .(RSSD9050 = OUT_CERT, eff_year)]
        cand[, ok := mapply(function(c, t) any(cont$RSSD9050 == c & cont$eff_year %in% c(t - 1L, t)) &&
                                           !any(absorbed$RSSD9050 == c & absorbed$eff_year %in% c(t - 1L, t)), RSSD9050, year)]
        cand <- cand[ok == TRUE]
        cand <- cand[!duplicated(cand[, .(RSSD9001, year)])]
        if (nrow(cand)) {
          A <- merge(A, cand[, .(RSSD9001, year, cont_lag = pred_y, pred_id)], by = c("RSSD9001", "year"), all.x = TRUE)
          A[!is.na(pred_id), `:=`(lag = cont_lag, lag_source = ifelse(is.na(cont_lag), "continuity_predecessor_y_missing", "continuity_predecessor"))]
          A[, c("cont_lag", "pred_id") := NULL]
        }
      }
    }
  }
  if (r03 == "R03.proforma") {
    ms <- merger_survivors(inp$ev)
    surv <- unique(ms[, .(RSSD9050 = CERT, year)])
    tgt <- merge(A[in_U == TRUE & year > min(YEARS_ALL), .(RSSD9001, RSSD9050, year)], surv, by = c("RSSD9050", "year"))
    if (nrow(tgt)) {
      # The pro forma lag of a survivor is the t-1 relative ROA of the combined entity:
      # 100 * (sum NI_{t-1} / sum AA_{t-1} - mean ROA_{t-1}) over the survivor and every
      # absorbed institution. It replaces the as-reported lag for every survivor-year; if
      # any predecessor is unidentified (OUT_CERT missing), has no t-1 Call record, or has
      # missing NI or AA, the pro forma lag is missing (nothing is silently omitted).
      prevall <- A[, .(RSSD9050, RSSD9001, year = year + 1L, NI_prev = NI, AA_prev = AA)]
      pf <- rbindlist(lapply(seq_len(nrow(tgt)), function(i) {
        cert <- tgt$RSSD9050[i]; t <- tgt$year[i]; id <- tgt$RSSD9001[i]
        evs <- ms[CERT == cert & year == t]
        outs <- evs[!is.na(OUT_CERT), unique(OUT_CERT)]
        own <- prevall[RSSD9001 == id & year == t]
        pred <- prevall[RSSD9050 %in% outs & year == t & RSSD9001 != id]
        reason <- if (any(is.na(evs$OUT_CERT))) "predecessor_unidentified"
                  else if (nrow(own) == 0) "survivor_no_t-1_record"
                  else if (!all(outs %in% pred$RSSD9050)) "predecessor_no_t-1_record"
                  else if (anyNA(own$NI_prev) || anyNA(own$AA_prev) || anyNA(pred$NI_prev) || anyNA(pred$AA_prev)) "predecessor_or_survivor_NI_or_AA_missing"
                  else "ok"
        allp <- rbind(own, pred)
        data.table(RSSD9001 = id, year = t,
                   pf_NI = if (reason == "ok") sum(allp$NI_prev) else NA_real_,
                   pf_AA = if (reason == "ok") sum(allp$AA_prev) else NA_real_,
                   n_pred = nrow(pred), pf_reason = reason)
      }))
      pf <- merge(pf, bench[, .(year = year + 1L, meanROA_prev = meanROA)], by = "year", all.x = TRUE)
      pf[, pf_lag := ifelse(!is.na(pf_AA) & pf_AA > 0 & !is.na(meanROA_prev), 100 * (pf_NI / pf_AA - meanROA_prev), NA_real_)]
      pf[pf_reason == "ok" & is.na(pf_lag), pf_reason := "pro_forma_AA_not_positive_or_benchmark_missing"]
      A <- merge(A, pf[, .(RSSD9001, year, pf_lag, pf_reason)], by = c("RSSD9001", "year"), all.x = TRUE)
      A[!is.na(pf_reason), `:=`(lag = pf_lag,
                                lag_source = ifelse(pf_reason == "ok", "proforma_merger_survivor", paste0("proforma_missing_", pf_reason)))]
      A[, c("pf_lag", "pf_reason") := NULL]
    }
  }
  if (lvl(cfg, "R10") == "R10.suppress_lag") A[RSSD9001 == OUTLIER_ID & year == OUTLIER_YR + 1L, `:=`(lag = NA_real_, lag_source = "suppressed_R10")]
  # ---- market share (R19) and real market growth (R20, R21)
  ins <- NULL
  if (lvl(cfg, "R19") == "R19.all_insured" || lvl(cfg, "R21") == "R21.all_insured") ins <- fdic_insured_deposits(inp, cfg)
  if (lvl(cfg, "R19") == "R19.all_insured") {
    A <- merge(A, ins[, .(year, D_ms = D_ins)], by = "year", all.x = TRUE)
  } else A[, D_ms := D_comm]
  A[, MS := ifelse(!is.na(D_ms) & D_ms > 0, DEP / D_ms, NA_real_)]
  Dg <- if (lvl(cfg, "R21") == "R21.all_insured") ins[, .(year, Dg = D_ins)] else bench[, .(year, Dg = D)]
  Pd <- deflator_series(inp$defl, lvl(cfg, "R20"))
  g <- merge(Dg, Pd, by = "year", all.x = TRUE)[order(year)]
  g[, real := Dg / P]
  # growth from calendar year t-1 exactly (a missing t-1 row gives a missing RMG; no gap-spanning)
  g[, RMG := 100 * (real / real[match(year - 1L, year)] - 1)]
  A <- merge(A, g[, .(year, RMG, P_defl = P, D_growth = Dg)], by = "year", all.x = TRUE)
  setkey(A, RSSD9001, year)
  if (!is.null(log)) {
    u <- A[in_U == TRUE]
    log$S5_derived_variables <- list(
      lag_rule = r03, deflator = lvl(cfg, "R20"),
      by_year = u[, .(U_t = .N, SD_missing = sum(is.na(SD)), y_missing = sum(is.na(y)), lag_missing = sum(is.na(lag)),
                      MS_missing = sum(is.na(MS)), MS_zero = sum(!is.na(MS) & MS <= 0), RMG = RMG[1],
                      P_deflator = P_defl[1], D_growth = D_growth[1], D_market_share = D_ms[1],
                      merger_year_rows = sum(merger_drop)), by = year][order(year)],
      lag_sources = u[, .N, by = .(year, lag_source)][order(year, lag_source)],
      fdic_insured_deposits = if (is.null(ins)) "not used" else ins)
  }
  A
}

# --- S6: estimation sample -----------------------------------------------------
estimation_sample <- function(A, cfg, log) {
  s <- A[year %in% YEARS_EST]
  steps <- list()
  cnt <- function(lbl) { steps[[length(steps) + 1]] <<- s[, .(step = lbl, rows = .N), by = year] }
  cnt("rows_in_estimation_years"); s <- s[in_U == TRUE]; cnt("in_U_t")
  s <- s[!is.na(y)]; cnt("y_nonmissing")
  s <- s[!is.na(lag)]; cnt("lag_nonmissing")
  s <- s[!is.na(SD)]; cnt("SD_nonmissing")
  s <- s[!is.na(MS)]; cnt("MS_nonmissing")
  s <- s[!is.na(TER)]; cnt("TER_nonmissing")
  s <- s[!is.na(RMG)]; cnt("RMG_nonmissing")
  s <- s[MS > 0]; cnt("MS_positive")
  if (lvl(cfg, "R03") == "R03.drop_merger_years") { s <- s[merger_drop == FALSE]; cnt("not_merger_year_R03") }
  if (lvl(cfg, "R04") == "R04.full_prior_year") {
    s <- s[!is.na(open_date) & open_date < as.Date(sprintf("%d-01-01", year - 1L))]; cnt("opened_before_Jan1_of_t-1_R04")
  }
  r10 <- lvl(cfg, "R10")
  outlier_note <- r10
  if (r10 %in% c("R10.delete_named", "R10.suppress_lag")) {
    n0 <- nrow(s); s <- s[!(RSSD9001 == OUTLIER_ID & year == OUTLIER_YR)]
    outlier_note <- sprintf("%s: deleted %d row(s) (RSSD9001 %d, year %d)", r10, n0 - nrow(s), OUTLIER_ID, OUTLIER_YR)
    cnt("outlier_rule_R10")
  }
  setorder(s, RSSD9001, year)
  s[, w := MS]
  log$S6_estimation_sample <- list(
    sequential_counts = dcast(rbindlist(steps)[, step := factor(step, levels = unique(step))], year ~ step, value.var = "rows"),
    outlier_rule = outlier_note, final_rows = nrow(s), final_banks = uniqueN(s$RSSD9001),
    sample_hash = sample_hash(s$RSSD9001, s$year))
  s
}

# --- master builder ---------------------------------------------------------------
build_sample <- function(cfg, inp) {
  log <- new.env()
  rec <- filter_records(inp$call, cfg, log)
  U <- market_population(rec, cfg, inp, log)
  annual <- build_annual(rec, U, cfg, inp, log)
  bench <- compute_benchmarks(annual, cfg, log = log)
  A <- derive_variables(annual, bench, cfg, inp, log)
  s <- estimation_sample(A, cfg, log)
  if (lvl(cfg, "R09") == "R09.analytic") {
    # Second pass (amendment v1.1 C5): reference population of year t in 1985..1992 = the
    # first-pass estimation rows of year t; for 1984 = the 1984 bank-years whose relative
    # ROA is the lag of a first-pass 1985 estimation row (same RSSD9001 at t-1). Variables
    # are rebuilt on these references and the first-pass rows are refitted; a row whose
    # rebuilt variables are undefined is dropped and counted here (not a failure).
    keys <- s[, .(RSSD9001, year)]
    ref1984 <- s[year == min(YEARS_EST), .(RSSD9001, year = year - 1L)]
    ref1984 <- merge(ref1984, annual[in_U == TRUE, .(RSSD9001, year)], by = c("RSSD9001", "year"))
    ref_keys <- unique(rbind(keys, ref1984))
    bench2 <- compute_benchmarks(annual, cfg, ref_keys = ref_keys, log = log)
    A2 <- derive_variables(annual, bench2, cfg, inp, log, ref_keys = ref_keys)
    s2 <- merge(A2, keys, by = c("RSSD9001", "year"))
    setorder(s2, RSSD9001, year)
    s2[, w := MS]
    undefined <- is.na(s2$y) | is.na(s2$lag) | is.na(s2$SD) | is.na(s2$MS) | is.na(s2$TER) | is.na(s2$RMG) | s2$MS <= 0
    log$S6_estimation_sample$analytic_second_pass <- list(
      reference_rows_by_year = ref_keys[, .N, by = year][order(year)],
      first_pass_rows = nrow(s2), rows_dropped_undefined_after_rebuild = sum(undefined),
      dropped_cases = if (any(undefined)) s2[undefined, .(RSSD9001, year)] else "none",
      rows_refitted = sum(!undefined))
    s2 <- s2[!undefined]
    s <- s2; bench <- bench2
  }
  list(sample = s, annual = A, bench = bench, log = as.list(log))
}

# ---------------------------------------------------------- 3. estimation ---
build_design <- function(s, model, cfg) {
  terms <- MODEL_TERMS[[model]]
  r22 <- lvl(cfg, "R22"); r26 <- lvl(cfg, "R26")
  note <- character(0)
  X <- matrix(1, nrow(s), 1, dimnames = list(NULL, "(Intercept)"))
  centre <- NULL
  vals <- list(SD = s$SD, SD2 = s$SD2, MS = s$MS, TER = s$TER, RMG = s$RMG, lag = s$lag)
  if (r26 == "R26.centered") {
    if ("SD" %in% terms) {
      # M2, M3: centred polynomial basis (SD - m), (SD - m)^2; exact reparametrisation
      mSD <- mean(s$SD); SDc <- s$SD - mSD
      vals$SD <- SDc; vals$SD2 <- SDc^2
      centre <- list(kind = "SD", m = mSD)
    } else if ("SD2" %in% terms) {
      # M3_SQ has no first-order term: the centred re-expression is not defined
      # (amendment v1.1 C6); run_models records status not_applicable instead of fitting
      stop("R26.centered is not defined for M3_SQ (no first-order SD term)")
    }
  }
  if (r22 == "R22.year") { terms <- setdiff(terms, "RMG"); note <- c(note, "R22.year: real_market_growth dropped (collinear with year indicators)") }
  for (tm in terms) X <- cbind(X, setNames(data.frame(vals[[tm]]), tm)[[1]])
  colnames(X) <- c("(Intercept)", terms)
  if (r22 == "R22.year") {
    yrs <- sort(unique(s$year))
    for (yy in yrs[-1]) X <- cbind(X, as.numeric(s$year == yy)); colnames(X)[(ncol(X) - length(yrs) + 2):ncol(X)] <- paste0("year_", yrs[-1])
  }
  if (r22 == "R22.bank") {
    ids <- sort(unique(s$RSSD9001))
    D <- sapply(ids[-1], function(b) as.numeric(s$RSSD9001 == b))
    colnames(D) <- paste0("bank_", ids[-1]); X <- cbind(X, D)
    note <- c(note, sprintf("R22.bank: %d bank indicators included (reference bank RSSD9001 %d); their coefficients are listed as terms bank_<RSSD9001>", length(ids) - 1, ids[1]))
  }
  list(X = X, centre = centre, note = note)
}

# Core fit: WLS via sqrt(w) transformation; optional Prais-Winsten AR(1); covariance per R23
fit_core <- function(y, X, w, bank, year, cov_type = "R23.conventional", estimator = "R25.wls") {
  n <- length(y); K <- ncol(X)
  if (anyNA(y) || anyNA(X) || anyNA(w)) stop("missing values in the outcome, design matrix or weights")
  if (n <= K) stop(sprintf("too few observations (n=%d, K=%d): df_resid = N - K must be at least 1", n, K))
  sw <- sqrt(w); Xt <- X * sw; yt <- y * sw
  rho <- NA_real_
  if (estimator == "R25.wls_ar1") {
    o <- order(bank, year); if (any(o != seq_len(n))) stop("AR(1) requires data sorted by bank, year")
    q0 <- qr(Xt); if (q0$rank < K) stop("rank-deficient design")
    e0 <- as.vector(yt - Xt %*% qr.coef(q0, yt))
    has_prev <- c(FALSE, bank[-1] == bank[-n] & year[-1] == year[-n] + 1L)
    ip <- which(has_prev)
    if (length(ip) < 2) stop("too few within-bank consecutive pairs for AR(1)")
    rho <- sum(e0[ip] * e0[ip - 1]) / sum(e0[ip - 1]^2)
    rho <- max(min(rho, 0.999), -0.999)
    Xs <- Xt; ys <- yt
    Xs[ip, ] <- Xt[ip, ] - rho * Xt[ip - 1, ]; ys[ip] <- yt[ip] - rho * yt[ip - 1]
    Xs[!has_prev, ] <- sqrt(1 - rho^2) * Xt[!has_prev, , drop = FALSE]; ys[!has_prev] <- sqrt(1 - rho^2) * yt[!has_prev]
    Xt <- Xs; yt <- ys
  }
  qx <- qr(Xt)
  if (qx$rank < K) stop(sprintf("rank-deficient design (rank %d < K %d)", qx$rank, K))
  XtXi <- chol2inv(qr.R(qx))[order(qx$pivot), order(qx$pivot)]
  beta <- as.vector(XtXi %*% crossprod(Xt, yt))
  et <- as.vector(yt - Xt %*% beta)          # residuals of the (transformed) regression actually estimated
  e  <- as.vector(y - X %*% beta)            # residuals of the original regression y - X beta
  sse_t <- sum(et^2)                          # SSE of the estimated regression (drives s^2 and the covariance)
  sse <- sum(w * e^2)                         # reported SSE_w = sum w e^2 (manifest section 3); equals sse_t unless AR(1)
  df <- n - K; s2 <- sse_t / df
  V <- switch(cov_type,
    "R23.conventional" = s2 * XtXi,
    "R23.hc1" = { meat <- crossprod(Xt * et); (XtXi %*% meat %*% XtXi) * (n / (n - K)) },
    "R23.cluster_bank" = {
      u <- Xt * et; ug <- rowsum(u, bank); G <- nrow(ug)
      (XtXi %*% crossprod(ug) %*% XtXi) * (G / (G - 1)) * ((n - 1) / (n - K)) },
    stop("unknown R23 level"))
  se <- sqrt(pmax(diag(V), 0)); tval <- beta / se; p <- 2 * pt(-abs(tval), df)
  cn <- sqrt(colSums(Xt^2)); sv <- svd(sweep(Xt, 2, cn, "/"), nu = 0, nv = 0)$d
  cond_max <- max(sv) / min(sv)
  h <- rowSums((Xt %*% XtXi) * Xt)
  nm <- colnames(X)
  list(beta = setNames(beta, nm), se = setNames(se, nm), t = setNames(tval, nm), p = setNames(p, nm),
       n = n, K = K, df = df, sse = sse, sse_t = sse_t, cond_max = cond_max, V = V, resid_t = et, hat = h,
       rho = rho, n_banks = length(unique(bank)))
}

rstudent_ext <- function(f) {
  if (f$df < 2) stop("externally studentized residuals require df_resid >= 2")
  e <- f$resid_t; h <- f$hat
  s2i <- (f$sse_t - e^2 / (1 - h)) / (f$df - 1)
  e / sqrt(s2i * (1 - h))
}

# Back-transform centred-basis coefficients to the raw basis (delta method, exact linear map).
# centre = list(kind = "SD", m = mean SD): SD -> SD - m, SD2 -> (SD - m)^2 (models with an SD term)
back_transform <- function(f, centre) {
  nm <- names(f$beta); K <- length(nm)
  j0 <- which(nm == "(Intercept)"); j1 <- which(nm == "SD"); j2 <- which(nm == "SD2")
  Tm <- diag(K); rownames(Tm) <- colnames(Tm) <- nm
  if (!is.null(centre)) {
    m <- centre$m
    if (centre$kind != "SD") stop("unknown centring")
    if (length(j1)) Tm[j0, j1] <- -m
    if (length(j2)) {
      if (!length(j1)) stop("centred SD basis needs the first-order SD term")
      Tm[j0, j2] <- m^2; Tm[j1, j2] <- -2 * m
    }
  }
  b <- as.vector(Tm %*% f$beta); V <- Tm %*% f$V %*% t(Tm)
  se <- sqrt(pmax(diag(V), 0)); tv <- b / se
  list(beta = setNames(b, nm), se = setNames(se, nm), t = setNames(tv, nm), p = setNames(2 * pt(-abs(tv), f$df), nm))
}

weights_for <- function(s, cfg) {
  w <- if (lvl(cfg, "R25") == "R25.ols") rep(1, nrow(s)) else s$MS
  if (lvl(cfg, "R24") == "R24.mean1") w <- w / mean(w)
  w
}

fit_model <- function(s, model, cfg) {
  d <- build_design(s, model, cfg)
  w <- weights_for(s, cfg)
  f <- fit_core(s$y, d$X, w, s$RSSD9001, s$year, cov_type = lvl(cfg, "R23"), estimator = lvl(cfg, "R25"))
  f$design <- d; f$w <- w
  f$hash <- sample_hash(s$RSSD9001, s$year)
  if (lvl(cfg, "R26") == "R26.centered") {
    f$raw <- back_transform(f, d$centre)
    f$note <- c(d$note, if (is.null(d$centre)) "R26.centered: model has no SD term; nothing to centre" else
      sprintf("R26.centered: fitted with SD centred at %.6g; coefficients back-transformed to the raw basis (delta method)", d$centre$m))
  } else { f$raw <- f[c("beta", "se", "t", "p")]; f$note <- d$note }
  if (!is.na(f$rho)) f$note <- c(f$note, sprintf("R25.wls_ar1: Prais-Winsten rho = %.6g; sse_w = sum w e^2 of the original regression; covariance from the transformed regression (SSE_transformed = %.6g)", f$rho, f$sse_t))
  f
}

spec_rows_from_fit <- function(f, meta, model, status = "ok", message = "") {
  # every fitted coefficient is reported, including year_ and bank_ indicators
  data.table(spec_id = meta$spec_id, origin = meta$origin, axis = meta$axis, level_id = meta$level_id,
             model = model, status = status, message = message, n = f$n, n_banks = f$n_banks, k = f$K,
             df_resid = f$df, sse_w = f$sse, cond_max = f$cond_max,
             term = names(f$raw$beta), estimate = unname(f$raw$beta), se = unname(f$raw$se),
             t = unname(f$raw$t), p_two_sided = unname(f$raw$p), sample_hash = f$hash)
}

empty_spec_row <- function(meta, model, status, message) {
  data.table(spec_id = meta$spec_id, origin = meta$origin, axis = meta$axis, level_id = meta$level_id,
             model = model, status = status, message = message, n = NA_integer_, n_banks = NA_integer_,
             k = NA_integer_, df_resid = NA_integer_, sse_w = NA_real_, cond_max = NA_real_, term = NA_character_,
             estimate = NA_real_, se = NA_real_, t = NA_real_, p_two_sided = NA_real_, sample_hash = NA_character_)
}

run_models <- function(s, cfg, meta) {
  s <- copy(s); setorder(s, RSSD9001, year)
  models <- names(MODEL_TERMS)
  del <- setNames(vector("list", length(models)), models)
  r10_note <- ""
  if (lvl(cfg, "R10") == "R10.max_rstudent") {
    mx <- sapply(models, function(m) { f <- fit_model(s, m, cfg); which.max(abs(rstudent_ext(f))) })
    if (length(unique(mx[c("M1", "M2", "M3")])) == 1) {
      for (m in models) del[[m]] <- mx[["M1"]]
      r10_note <- sprintf("R10.max_rstudent: same row (RSSD9001 %d, year %d) deleted for all models", s$RSSD9001[mx[["M1"]]], s$year[mx[["M1"]]])
    } else {
      for (m in models) del[[m]] <- mx[[m]]
      r10_note <- paste0("R10.max_rstudent: max |rstudent| rows differ across M1-M3; each model deletes its own: ",
                         paste(sprintf("%s=(%d,%d)", models, s$RSSD9001[mx], s$year[mx]), collapse = "; "))
    }
  }
  fits <- list(); rows <- list()
  for (m in models) {
    if (m == "M3_SQ" && lvl(cfg, "R26") == "R26.centered") {
      # amendment v1.1 C6: the centred re-expression is not defined without a first-order term
      rows[[m]] <- empty_spec_row(meta, m, "not_applicable", "R26.centered: M3_SQ has no first-order SD term, so the centred re-expression is not defined (manifest amendment v1.1 C6)")
      fits[[m]] <- NULL
      next
    }
    sm <- if (length(del[[m]])) s[-del[[m]]] else s
    f <- tryCatch(fit_model(sm, m, cfg), error = function(e) e)
    if (inherits(f, "error")) {
      rows[[m]] <- empty_spec_row(meta, m, if (inherits(f, "unavailable")) "unavailable" else "failed", conditionMessage(f)); fits[[m]] <- NULL
    } else {
      fits[[m]] <- f
      rows[[m]] <- spec_rows_from_fit(f, meta, m, "ok", paste(c(r10_note, f$note), collapse = " | "))
    }
  }
  frows <- rbindlist(lapply(F_COMPARISONS, function(cp) {
    fu <- fits[[cp[1]]]; fr <- fits[[cp[2]]]
    out <- data.table(spec_id = meta$spec_id, comparison = sprintf("%s_vs_%s", cp[1], cp[2]),
                      delta_sse = NA_real_, q = NA_integer_, df_resid_u = NA_integer_, F = NA_real_, p_upper = NA_real_)
    if (is.null(fu) || is.null(fr) || fu$hash != fr$hash) return(out)
    qq <- as.integer(fu$K - fr$K); dsse <- fr$sse - fu$sse
    Fv <- (dsse / qq) / (fu$sse / fu$df)
    data.table(spec_id = meta$spec_id, comparison = sprintf("%s_vs_%s", cp[1], cp[2]),
               delta_sse = dsse, q = qq, df_resid_u = as.integer(fu$df), F = Fv,
               p_upper = pf(Fv, qq, fu$df, lower.tail = FALSE))
  }))
  list(spec_rows = rbindlist(rows), f_rows = frows, fits = fits)
}

# ------------------------------------------------------ 4. specification grid ---
make_cfg <- function(origin_cfg, origin_name) {
  cfg <- origin_cfg; cfg$.origin <- origin_name; cfg$.origin_R02 <- origin_cfg$R02; cfg
}

enumerate_specs <- function(grid) {
  specs <- list()
  add <- function(spec_id, origin, axis, level_id, cfg, kind) specs[[length(specs) + 1]] <<- list(spec_id = spec_id, origin = origin, axis = axis, level_id = level_id, cfg = cfg, kind = kind)
  for (o in names(grid$origins)) add(o, o, NA_character_, NA_character_, make_cfg(grid$origins[[o]], o), "origin")
  for (o in names(grid$origins)) {
    base <- make_cfg(grid$origins[[o]], o)
    for (ax in grid$axes) for (lv in ax$levels) {
      if (isTRUE(lv$check)) next
      if (identical(base[[ax$axis]], lv$id)) { add(paste0(o, "__", lv$id), o, ax$axis, lv$id, base, "duplicate"); next }
      cfg <- base; cfg[[ax$axis]] <- lv$id
      add(paste0(o, "__", lv$id), o, ax$axis, lv$id, cfg, "deviation")
    }
  }
  for (o in names(grid$origins)) {
    base <- make_cfg(grid$origins[[o]], o)
    for (ax in grid$axes) for (lv in ax$levels) {
      if (!isTRUE(lv$check)) next
      cfg <- base; cfg[[ax$axis]] <- lv$id
      add(paste0(o, "__", lv$id), o, ax$axis, lv$id, cfg, "check")
    }
  }
  specs
}

construction_key <- function(cfg) digest(c(cfg[CONSTRUCTION_AXES], cfg$.origin_R02), algo = "md5")

# ---------------------------------------------------- 5. influence diagnostics ---
run_influence <- function(s, cfg, origin) {
  s <- copy(s); setorder(s, RSSD9001, year)
  out <- list()
  for (m in c("M2", "M3")) {
    terms <- if (m == "M2") "SD" else c("SD2", "SD")
    one <- function(idx_keep, del_type, del_id) {
      sm <- s[idx_keep]
      f <- tryCatch(fit_model(sm, m, cfg), error = function(e) e)
      if (inherits(f, "error")) return(data.table(origin = origin, model = m, deletion_type = del_type, deleted_id = del_id, term = terms,
                                                   estimate = NA_real_, se = NA_real_, p_two_sided = NA_real_, n = nrow(sm), status = "failed", message = conditionMessage(f)))
      data.table(origin = origin, model = m, deletion_type = del_type, deleted_id = del_id, term = terms,
                 estimate = unname(f$raw$beta[terms]), se = unname(f$raw$se[terms]), p_two_sided = unname(f$raw$p[terms]),
                 n = f$n, status = "ok", message = "")
    }
    rows <- vector("list", nrow(s))
    for (r in seq_len(nrow(s))) rows[[r]] <- one(-r, "bank_year", sprintf("%d_%d", s$RSSD9001[r], s$year[r]))
    out[[length(out) + 1]] <- rbindlist(rows)
    ids <- sort(unique(s$RSSD9001))
    rows <- lapply(ids, function(b) one(which(s$RSSD9001 != b), "bank", as.character(b)))
    out[[length(out) + 1]] <- rbindlist(rows)
  }
  rbindlist(out)
}

# ------------------------------------------------------------- 6. outputs ---
write_descriptives <- function(s, path) {
  vars <- c("y", "lag", "SD", "SD2", "MS", "TER", "RMG")
  M <- as.matrix(s[, vars, with = FALSE])
  d <- data.table(variable = vars, n = nrow(M), mean = colMeans(M), sd = apply(M, 2, sd))
  C <- cor(M); colnames(C) <- paste0("cor_", vars)
  fwrite(cbind(d, as.data.table(C)), path)
}

write_environment <- function(path) {
  pk <- c("data.table", "dplyr", "nanoparquet", "jsonlite", "digest")
  lines <- c(R.version.string, sprintf("platform: %s", R.version$platform), sprintf("os: %s %s", Sys.info()[["sysname"]], Sys.info()[["release"]]),
             sapply(pk, function(p) sprintf("%s %s", p, tryCatch(as.character(packageVersion(p)), error = function(e) "not installed"))),
             sprintf("run started: %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")))
  writeLines(lines, path)
}

json_ready <- function(x) {
  if (is.environment(x)) x <- as.list(x)
  if (is.data.frame(x)) return(as.data.frame(x))
  if (is.list(x)) return(lapply(x, json_ready))
  x
}

main <- function() {
  t0 <- Sys.time()
  dir.create(file.path(OUT_DIR, "samples"), recursive = TRUE, showWarnings = FALSE)
  write_environment(file.path(OUT_DIR, "environment.txt"))
  grid <- fromJSON(file.path(ROOT, "grid.json"), simplifyVector = FALSE)
  inp <- load_inputs()
  specs <- enumerate_specs(grid)
  msg("%d specifications enumerated", length(specs))
  cache <- new.env()
  get_build <- function(cfg) {
    key <- construction_key(cfg)
    if (!is.null(cache[[key]])) return(cache[[key]])
    b <- build_sample(cfg, inp); cache[[key]] <- b; b
  }
  spec_rows <- list(); f_rows <- list()
  origin_builds <- list()
  for (sp in specs) {
    meta <- sp[c("spec_id", "origin", "axis", "level_id")]
    msg("spec %s (%s)", sp$spec_id, sp$kind)
    if (sp$kind == "duplicate") {
      spec_rows[[sp$spec_id]] <- rbindlist(lapply(names(MODEL_TERMS), function(m) empty_spec_row(meta, m, "duplicate", "level identical to the origin's level")))
      next
    }
    res <- tryCatch({
      b <- get_build(sp$cfg)
      if (sp$kind == "origin") {
        origin_builds[[sp$origin]] <- b
        fwrite(b$sample[, .(RSSD9001, year, y, lag, SD, SD2, MS, TER, RMG, w)], file.path(OUT_DIR, "samples", paste0(sp$origin, ".csv")))
        write_descriptives(b$sample, file.path(OUT_DIR, paste0("descriptives_", sp$origin, ".csv")))
        write_json(json_ready(b$log), file.path(OUT_DIR, paste0("construction_log_", sp$origin, ".json")), auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null")
      }
      if (CONSTRUCTION_ONLY) { if (sp$kind != "origin") stop("construction-only mode"); NULL } else run_models(b$sample, sp$cfg, meta)
    }, error = function(e) e)
    if (inherits(res, "error")) {
      # `unavailable` = cannot be implemented from the supplied inputs (manifest introduction);
      # any other error = `failed`
      st <- if (inherits(res, "unavailable")) "unavailable" else "failed"
      msg("  %s: %s", toupper(st), conditionMessage(res))
      spec_rows[[sp$spec_id]] <- rbindlist(lapply(names(MODEL_TERMS), function(m) empty_spec_row(meta, m, st, conditionMessage(res))))
      next
    }
    if (is.null(res)) next
    spec_rows[[sp$spec_id]] <- res$spec_rows; f_rows[[sp$spec_id]] <- res$f_rows
  }
  if (CONSTRUCTION_ONLY) { msg("construction-only mode finished in %.1f s", as.numeric(difftime(Sys.time(), t0, units = "secs"))); return(invisible(NULL)) }
  fwrite(rbindlist(spec_rows), file.path(OUT_DIR, "spec_results.csv"))
  fwrite(rbindlist(f_rows), file.path(OUT_DIR, "f_tests.csv"))
  # influence diagnostics at both origins
  infl <- list()
  for (o in names(grid$origins)) {
    msg("influence diagnostics at %s", o)
    b <- origin_builds[[o]]
    cfg <- make_cfg(grid$origins[[o]], o)
    infl[[o]] <- tryCatch(run_influence(b$sample, cfg, o), error = function(e)
      data.table(origin = o, model = NA_character_, deletion_type = NA_character_, deleted_id = NA_character_, term = NA_character_,
                 estimate = NA_real_, se = NA_real_, p_two_sided = NA_real_, n = NA_integer_, status = "failed", message = conditionMessage(e)))
  }
  fwrite(rbindlist(infl), file.path(OUT_DIR, "influence.csv"))
  msg("finished in %.1f s", as.numeric(difftime(Sys.time(), t0, units = "secs")))
}

if (!exists("ANALYSIS_SOURCE_ONLY") || !isTRUE(ANALYSIS_SOURCE_ONLY)) main()
