#!/usr/bin/env Rscript
# =============================================================================
# run_analysis.R -- implementation of manifest PX02 v1
#
# Usage:
#   Rscript run_analysis.R <data_dir> <output_dir>
#   Rscript run_analysis.R <data_dir> <output_dir> --influence <spec_id>
#
# Grid file: grid_v1.csv is searched in this order: environment variable
# PX02_GRID, <data_dir>/grid_v1.csv, <data_dir>/../grid_v1.csv,
# <script_dir>/grid_v1.csv, <script_dir>/../input/grid_v1.csv, ./grid_v1.csv,
# ./input/grid_v1.csv.
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(haven)
  library(readxl)
  library(jsonlite)
})
options(warn = 1, stringsAsFactors = FALSE)
setFixest_notes(FALSE)
setFixest_nthreads(1)

t_start <- Sys.time()

# ----------------------------------------------------------------------------
# Arguments
# ----------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("usage: run_analysis.R <data_dir> <output_dir> [--influence <spec_id>]")
data_dir <- normalizePath(args[1], mustWork = TRUE)
out_dir  <- args[2]
infl_spec <- NULL
if (length(args) >= 3) {
  if (args[3] != "--influence" || length(args) < 4) stop("third argument must be --influence <spec_id>")
  infl_spec <- args[4]
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_dir <- normalizePath(out_dir, mustWork = TRUE)

script_dir <- tryCatch({
  fa <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(fa)) dirname(normalizePath(sub("^--file=", "", fa[1]))) else getwd()
}, error = function(e) getwd())

find_grid <- function() {
  cands <- c(Sys.getenv("PX02_GRID", ""),
             file.path(data_dir, "grid_v1.csv"),
             file.path(dirname(data_dir), "grid_v1.csv"),
             file.path(script_dir, "grid_v1.csv"),
             file.path(dirname(script_dir), "input", "grid_v1.csv"),
             file.path(getwd(), "grid_v1.csv"),
             file.path(getwd(), "input", "grid_v1.csv"))
  cands <- cands[nzchar(cands)]
  hit <- cands[file.exists(cands)]
  if (!length(hit)) stop("grid_v1.csv not found; set PX02_GRID")
  hit[1]
}
grid_path <- find_grid()

msg <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")
msg("data_dir:", data_dir, " out_dir:", out_dir, " grid:", grid_path)

LOG <- list()

# ----------------------------------------------------------------------------
# Small helpers
# ----------------------------------------------------------------------------
clean_txt <- function(x) {
  x <- trimws(x)
  x <- gsub('^"|"$', "", x)
  trimws(x)
}
to_num <- function(x) suppressWarnings(as.numeric(x))
sha256_str <- function(s) unname(as.character(tools::sha256sum(bytes = charToRaw(enc2utf8(s)))))
hash_keys <- function(keys) sha256_str(paste(sort(unique(as.integer(keys))), collapse = ","))
qlabel <- function(y, q) sprintf("%dq%d", y, q)

# Quantile-group rule of P7.
# vals: values for the counties in `keys`; ref: logical, which of them belong to
# the reference set. Returns group for every key (NA if value missing or if key
# is not ranked; keys outside the reference set get NA).
qgroup_rule <- function(vals, ref, k) {
  out <- rep(NA_integer_, length(vals))
  use <- ref & !is.na(vals)
  n <- sum(use)
  if (n == 0) return(out)
  r <- rank(vals[use], ties.method = "min")
  out[use] <- as.integer(1 + floor(k * (r - 1) / n))
  out
}

gtrans <- function(y, G) {
  if (G == "G1") {
    out <- suppressWarnings(log(y + 1))
  } else if (G == "G2") {
    out <- rep(NA_real_, length(y))
    pos <- !is.na(y) & y > 0
    out[pos] <- log(y[pos])
    out[!is.na(y) & y == 0] <- 0
  } else stop("unknown G: ", G)
  out[!is.finite(out)] <- NA_real_
  out
}

CTRL <- c("population", "popdensity", "popmales", "households", "unemploymentrate",
          "income_householdmedian", "income_medianearnings", "income_percapita",
          "popeduc", "popyoungmales")
LOGCTRL <- c("population", "popmales", "households", "popeduc", "popyoungmales",
             "income_householdmedian", "income_medianearnings", "income_percapita")
ltrans <- function(dt, L) {
  # dt: data.table / data.frame with CTRL columns; returns numeric matrix
  m <- as.matrix(as.data.frame(dt)[, CTRL, drop = FALSE])
  storage.mode(m) <- "double"
  if (L == "L2") {
    for (v in LOGCTRL) {
      z <- suppressWarnings(log1p(m[, v]))
      z[!is.finite(z)] <- NA_real_
      m[, v] <- z
    }
  } else if (L != "L1") stop("unknown L: ", L)
  m
}

# ============================================================================
# P1. County universe
# ============================================================================
cl_raw <- fread(file.path(data_dir, "county_lookup.csv"), encoding = "UTF-8")
setnames(cl_raw, trimws(names(cl_raw)))
cl_raw[, STATE_NAME := trimws(as.character(STATE_NAME))]
n_lookup <- nrow(cl_raw)
n_ma <- sum(!is.na(cl_raw$STATE_NAME) & cl_raw$STATE_NAME == "Massachusetts")
Udt <- cl_raw[is.na(STATE_NAME) | STATE_NAME != "Massachusetts"]
Udt[, fips := as.integer(round(to_num(FIPS)))]
n_bad_fips <- sum(is.na(Udt$fips))
Udt <- Udt[!is.na(fips)]
n_dup_fips <- sum(duplicated(Udt$fips))
Udt <- Udt[!duplicated(fips)]
Udt[, treat := as.integer(to_num(treat))]
n_bad_treat <- sum(is.na(Udt$treat) | !(Udt$treat %in% c(0L, 1L)))
Udt[!(treat %in% c(0L, 1L)), treat := NA_integer_]
setorder(Udt, fips)
U_fips <- Udt$fips
U_treat <- Udt$treat
treat_of <- function(f) U_treat[match(f, U_fips)]
LOG$P1 <- list(rows_county_lookup = n_lookup,
               rows_massachusetts_removed = n_ma,
               rows_fips_unparseable_removed = n_bad_fips,
               rows_duplicate_fips_removed = n_dup_fips,
               counties_in_U = length(U_fips),
               treated_in_U = sum(U_treat == 1, na.rm = TRUE),
               control_in_U = sum(U_treat == 0, na.rm = TRUE),
               treat_missing_or_invalid = n_bad_treat)
msg("P1: U has", length(U_fips), "counties")

# ============================================================================
# P2. Contribution panel (read as text)
# ============================================================================
qraw <- fread(file.path(data_dir, "quarterly.csv"), sep = "\t", header = FALSE,
              colClasses = "character", quote = "", fill = TRUE, na.strings = NULL,
              strip.white = FALSE, encoding = "UTF-8", blank.lines.skip = TRUE)
hdr <- clean_txt(unlist(qraw[1]))
hdr[1] <- sub("^﻿", "", hdr[1])
hdr[is.na(hdr) | hdr == ""] <- paste0("V_extra", which(is.na(hdr) | hdr == ""))
qb <- qraw[-1]
setnames(qb, hdr)
for (j in names(qb)) set(qb, j = j, value = clean_txt(qb[[j]]))
for (j in names(qb)) { x <- qb[[j]]; x[is.na(x)] <- ""; set(qb, j = j, value = x) }

needed_q <- c("geoid", "quarter", "totalcontrib", "totaltaga", "totaltagb", "totaltagh",
              "totaltagv2a", "totaltagv2b", "totaltagv2h", "totalversion2", "totalversion3",
              "totalversion4plus", "totalusers", "totalnewusers", "totaloldusers_active",
              "totaloldfocused1", "totaloldfocused5", "totalowneredit",
              paste0("totalpctcontrib", c(10, 25, 50, 75, 90, 99)))
miss_cols <- setdiff(needed_q, names(qb))
if (length(miss_cols)) stop("quarterly.csv lacks columns: ", paste(miss_cols, collapse = ","))
count_cols <- setdiff(hdr[!grepl("^V_extra", hdr)], c("geoid", "quarter"))

n_q_lines <- nrow(qb)
is_hdr <- qb$geoid == "geoid"
qb <- qb[!is_hdr]
empty_q <- qb$quarter == ""
numok <- rep(TRUE, nrow(qb))
for (j in count_cols) numok <- numok & !is.na(to_num(qb[[j]]))
n_empty_q <- sum(empty_q)
n_empty_q_and_unparse <- sum(empty_q & !numok)
n_unparse <- sum(!empty_q & !numok)
qb <- qb[!empty_q & numok]
geoid_int <- suppressWarnings(as.integer(round(to_num(qb$geoid))))
n_bad_geoid <- sum(is.na(geoid_int))
qfmt_ok <- grepl("^[0-9]{4}q[1-4]$", qb$quarter)
n_bad_qfmt <- sum(!qfmt_ok & !is.na(geoid_int))
keep <- !is.na(geoid_int) & qfmt_ok
qb <- qb[keep]
qd <- data.table(fips = geoid_int[keep], quarter = qb$quarter)
for (j in count_cols) set(qd, j = j, value = to_num(qb[[j]]))
qd[, year := as.integer(substr(quarter, 1, 4))]
qd[, qn := as.integer(substr(quarter, 6, 6))]
n_dup_cq <- sum(duplicated(qd[, .(fips, quarter)]))
qd <- qd[!duplicated(qd[, .(fips, quarter)])]
rm(qraw, qb)

# ============================================================================
# P3. Balanced panel
# ============================================================================
QT <- CJ(year = 2005:2014, qn = 1:4)[!(year == 2005 & qn == 1)]
QT[, quarter := qlabel(year, qn)]
QT[, t := .I]
stopifnot(nrow(QT) == 39)
in_U <- qd$fips %in% U_fips
in_rng <- qd$quarter %in% QT$quarter
n_out_U <- sum(!in_U)
n_out_rng_inU <- sum(in_U & !in_rng)
pan <- CJ(fips = U_fips, t = QT$t)
pan <- merge(pan, QT, by = "t", all.x = TRUE)
qd_use <- qd[in_U & in_rng]
pan <- merge(pan, qd_use[, c("fips", "quarter", count_cols), with = FALSE],
             by = c("fips", "quarter"), all.x = TRUE)
n_filled <- sum(is.na(pan$totalcontrib))
n_U_no_rows <- length(setdiff(U_fips, unique(qd_use$fips)))
for (j in count_cols) { x <- pan[[j]]; x[is.na(x)] <- 0; set(pan, j = j, value = x) }
setorder(pan, fips, t)
pan[, post := as.integer(year >= 2008)]
pan[, qidx := (year - 1960L) * 4L + qn - 1L]
pan[, treat := treat_of(fips)]

LOG$P2 <- list(data_lines_excluding_first_header = n_q_lines,
               rows_removed_repeated_header = sum(is_hdr),
               rows_removed_empty_quarter = n_empty_q,
               rows_removed_empty_quarter_that_also_had_unparseable_counts = n_empty_q_and_unparse,
               rows_removed_unparseable_counts = n_unparse,
               rows_removed_unparseable_geoid = n_bad_geoid,
               rows_removed_malformed_quarter = n_bad_qfmt,
               rows_removed_duplicate_county_quarter = n_dup_cq,
               rows_retained = nrow(qd))
LOG$P3 <- list(rows_not_used_total = n_out_U + n_out_rng_inU,
               rows_not_used_county_outside_U = n_out_U,
               rows_not_used_quarter_outside_range_county_in_U = n_out_rng_inU,
               rows_used = nrow(qd_use),
               panel_rows = nrow(pan), panel_counties = length(U_fips), panel_quarters = nrow(QT),
               county_quarters_filled_with_zero = n_filled,
               counties_in_U_without_any_row = n_U_no_rows)
msg("P2/P3: panel rows", nrow(pan))

# ============================================================================
# P4. Outcomes
# ============================================================================
pan[, total := totalcontrib]
pan[, followon_F1 := totaltaga + totaltagb + totaltagh]
pan[, followon_F2 := totaltagv2a + totaltagv2b + totaltagv2h]
pan[, followon_F3 := totalversion2 + totalversion3 + totalversion4plus]
pan[, followon_F4 := totaltaga + totaltagb + totaltagh + totaltagv2a + totaltagv2b + totaltagv2h]
pan[, distant_F1_D1 := totaltagb]
pan[, distant_F2_D1 := totaltagv2b]
pan[, distant_F4_D1 := totaltagb + totaltagv2b]
pan[, distant_F3_D1 := distant_F1_D1]
pan[, distant_F1_D2 := totaltagb + totaltaga]
pan[, distant_F2_D2 := totaltagv2b + totaltagv2a]
pan[, distant_F4_D2 := totaltagb + totaltagv2b + totaltaga + totaltagv2a]
pan[, distant_F3_D2 := distant_F1_D2]
pan[, incremental_F1 := totaltagh]
pan[, incremental_F2 := totaltagv2h]
pan[, incremental_F4 := totaltagh + totaltagv2h]
pan[, incremental_F3 := incremental_F1]
pan[, contributors := totalusers]
pan[, new := totalnewusers]
pan[, old := totaloldusers_active]
pan[, high_own := totaloldfocused1]
pan[, low_own_O1 := totaloldfocused5 - totaloldfocused1]
n_neg_low <- sum(pan$low_own_O1 < 0, na.rm = TRUE)
pan[low_own_O1 < 0, low_own_O1 := NA_real_]
pan[, low_own_O2 := totaloldfocused5]
pan[, owner := totalowneredit]
for (p in c(10, 25, 50, 75, 90, 99)) set(pan, j = paste0("pct", p), value = pan[[paste0("totalpctcontrib", p)]])
LOG$P4 <- list(low_own_O1_negative_cells_set_missing = n_neg_low)

outcome_col <- function(outcome, F, D, O) {
  F <- if (is.na(F) || F == "") "F1" else F
  D <- if (is.na(D) || D == "") "D1" else D
  O <- if (is.na(O) || O == "") "O1" else O
  if (!F %in% c("F1", "F2", "F3", "F4")) stop("unknown F: ", F)
  switch(outcome,
         total = "total",
         followon = paste0("followon_", F),
         distant = paste0("distant_", F, "_", D),
         incremental = paste0("incremental_", F),
         contributors = "contributors", new = "new", old = "old",
         high_own = "high_own", low_own = paste0("low_own_", O), owner = "owner",
         pct10 = "pct10", pct25 = "pct25", pct50 = "pct50", pct75 = "pct75",
         pct90 = "pct90", pct99 = "pct99",
         stop("unknown outcome: ", outcome))
}

# ============================================================================
# P6. Controls
# ============================================================================
acs0 <- read_dta(file.path(data_dir, "acs5year.dta"))
setnames(acs0, tolower(names(acs0)))
acs <- as.data.table(lapply(acs0, function(x) {
  x <- zap_labels(x)
  if (is.numeric(x)) as.numeric(x) else to_num(as.character(x))
}))
rm(acs0)
miss_acs <- setdiff(c("geo_fips", "acsyear", CTRL), names(acs))
if (length(miss_acs)) stop("acs5year.dta lacks columns: ", paste(miss_acs, collapse = ","))
acs <- acs[, c("geo_fips", "acsyear", CTRL), with = FALSE]
acs[, fips := as.integer(round(geo_fips))]
acs[, acsyear := as.integer(round(acsyear))]
n_acs_rows <- nrow(acs)
acs <- acs[!is.na(fips) & !is.na(acsyear)]
n_acs_dup <- sum(duplicated(acs[, .(fips, acsyear)]))
acs <- acs[!duplicated(acs[, .(fips, acsyear)])]
acs_maxyear <- max(acs$acsyear)
avail <- unique(acs[, .(fips, ay = acsyear)])

nearest_year <- function(tg) {
  # tg: data.table(fips, target); returns tg with column ay (NA if county has no row)
  m <- merge(tg, avail, by = "fips", allow.cartesian = TRUE)
  m[, d := abs(ay - target)]
  setorder(m, fips, target, d, ay)
  m <- m[!duplicated(m[, .(fips, target)])]
  merge(tg, m[, .(fips, target, ay)], by = c("fips", "target"), all.x = TRUE)
}

# Panel rule: county-year -> ACS values
pc <- CJ(fips = U_fips, year = 2005:2014)
pc[, target := pmin(year, acs_maxyear)]
pcn <- nearest_year(unique(pc[, .(fips, target)]))
pc <- merge(pc, pcn, by = c("fips", "target"), all.x = TRUE)
pc <- merge(pc, acs[, c("fips", "acsyear", CTRL), with = FALSE],
            by.x = c("fips", "ay"), by.y = c("fips", "acsyear"), all.x = TRUE)
setorder(pc, fips, year)
n_U_no_acs <- length(setdiff(U_fips, unique(acs$fips)))
n_cy_nearest <- sum(!is.na(pc$ay) & pc$ay != pc$target)
pan <- merge(pan, pc[, c("fips", "year", CTRL), with = FALSE], by = c("fips", "year"), all.x = TRUE)
setorder(pan, fips, t)
PCTRL <- list(L1 = ltrans(pan, "L1"), L2 = ltrans(pan, "L2"))

# Cross-section rule
cs_raw <- list()
cs_near <- list()
for (Y in c("Y1", "Y2")) {
  tgt <- if (Y == "Y1") 2011L else 2008L
  nn <- nearest_year(data.table(fips = U_fips, target = tgt))
  cs_near[[Y]] <- sum(!is.na(nn$ay) & nn$ay != tgt)
  z <- merge(nn, acs[, c("fips", "acsyear", CTRL), with = FALSE],
             by.x = c("fips", "ay"), by.y = c("fips", "acsyear"), all.x = TRUE)
  z <- z[match(U_fips, z$fips)]
  cs_raw[[Y]] <- z[, c("fips", CTRL), with = FALSE]
}
y3 <- acs[fips %in% U_fips, lapply(.SD, function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)),
          by = fips, .SDcols = CTRL]
y3 <- y3[match(U_fips, y3$fips)]
y3[, fips := U_fips]
cs_raw[["Y3"]] <- y3[, c("fips", CTRL), with = FALSE]
CSCTRL <- list()
for (Y in names(cs_raw)) for (L in c("L1", "L2")) CSCTRL[[paste(Y, L)]] <- ltrans(cs_raw[[Y]], L)

LOG$P6 <- list(acs_rows = n_acs_rows, acs_duplicate_county_year_removed = n_acs_dup,
               acs_latest_year = acs_maxyear,
               counties_in_U_without_any_acs_row = n_U_no_acs,
               panel_county_years_using_nearest_available_year = n_cy_nearest,
               panel_county_quarters_with_missing_controls = sum(!complete.cases(PCTRL$L1)),
               cross_section_Y1_counties_using_nearest_year = cs_near$Y1,
               cross_section_Y2_counties_using_nearest_year = cs_near$Y2,
               cross_section_counties_missing_controls = sapply(c("Y1", "Y2", "Y3"), function(Y)
                 sum(!complete.cases(CSCTRL[[paste(Y, "L1")]])), simplify = FALSE))
msg("P6 done")

# P7: quartile groups --------------------------------------------------------
QVARS <- list(Q1 = c("popdensity", "income_householdmedian", "income_percapita"),
              Q2 = c("population", "income_householdmedian", "income_percapita"))
# returns data.frame of group FE (one column per variable) for counties `fips`
qfe <- function(fips, Y, Q, R, sample_fips) {
  Y <- if (is.na(Y) || Y == "") "Y1" else Y
  R <- if (is.na(R) || R == "") "R1" else R
  raw <- cs_raw[[Y]]
  ref <- if (R == "R1") rep(TRUE, length(U_fips)) else if (R == "R2") U_fips %in% sample_fips else stop("unknown R: ", R)
  out <- list()
  for (v in QVARS[[Q]]) {
    g <- qgroup_rule(raw[[v]], ref, 4)
    out[[paste0("q_", v)]] <- g[match(fips, U_fips)]
  }
  as.data.frame(out)
}
# popdensity quartile / decile under Y1, reference set U
popd_Y1 <- cs_raw$Y1$popdensity
POPD_Q4 <- qgroup_rule(popd_Y1, rep(TRUE, length(U_fips)), 4)
POPD_D10 <- qgroup_rule(popd_Y1, rep(TRUE, length(U_fips)), 10)

# ============================================================================
# P8. Boundary samples
# ============================================================================
bd <- fread(file.path(data_dir, "boundary-counties.csv"), colClasses = "character",
            header = TRUE, strip.white = FALSE, sep = ",")
bsrc <- as.integer(round(to_num(clean_txt(bd[[1]]))))
blist <- strsplit(ifelse(is.na(bd[[2]]), "", bd[[2]]), ";", fixed = TRUE)
edges <- rbindlist(lapply(seq_along(bsrc), function(i) {
  nb <- as.integer(round(to_num(clean_txt(blist[[i]]))))
  nb <- nb[!is.na(nb)]
  if (!length(nb) || is.na(bsrc[i])) return(NULL)
  data.table(src = bsrc[i], nb = nb)
}))
n_edges_raw <- nrow(edges)
n_self <- sum(edges$src == edges$nb)
edges <- edges[src != nb]
n_src_outside <- sum(!(edges$src %in% U_fips))
n_nb_outside <- sum(edges$src %in% U_fips & !(edges$nb %in% U_fips))
edges <- edges[src %in% U_fips & nb %in% U_fips]
edges <- unique(edges)
edges[, ts := treat_of(src)]
edges[, tn := treat_of(nb)]
B1 <- sort(unique(edges[!is.na(ts) & !is.na(tn) & ts != tn, src]))
B2 <- sort(unique(c(U_fips[!is.na(U_treat) & U_treat == 0],
                    edges[!is.na(ts) & ts == 1 & !is.na(tn) & tn == 0, src])))
LOG$P8 <- list(rows = nrow(bd), neighbour_entries = n_edges_raw,
               self_neighbour_entries_ignored = n_self,
               entries_with_source_outside_U_ignored = n_src_outside,
               neighbour_entries_outside_U_ignored = n_nb_outside,
               B1_counties = length(B1), B1_treated = sum(treat_of(B1) == 1, na.rm = TRUE),
               B1_control = sum(treat_of(B1) == 0, na.rm = TRUE),
               B2_counties = length(B2), B2_treated = sum(treat_of(B2) == 1, na.rm = TRUE),
               B2_control = sum(treat_of(B2) == 0, na.rm = TRUE))

# ============================================================================
# P9. Timing sample
# ============================================================================
tm <- read_excel(file.path(data_dir, "timing.xlsx"), sheet = 1)
tm <- as.data.frame(tm, check.names = FALSE)
names(tm) <- trimws(names(tm))
tfips <- as.integer(round(to_num(trimws(as.character(tm[["FIPS"]])))))
dcol <- tm[["Sch SB Delivery"]]
parse_xl_date <- function(x) {
  if (inherits(x, "POSIXt")) return(as.Date(format(x, "%Y-%m-%d", tz = "UTC")))
  if (inherits(x, "Date")) return(x)
  if (is.numeric(x)) return(as.Date(x, origin = "1899-12-30"))
  x <- trimws(as.character(x))
  out <- as.Date(rep(NA_character_, length(x)))
  num <- !is.na(to_num(x))
  out[num] <- as.Date(to_num(x[num]), origin = "1899-12-30")
  for (fmt in c("%Y-%m-%d", "%m/%d/%Y", "%Y/%m/%d", "%d-%b-%Y")) {
    nx <- is.na(out) & !num & x != ""
    if (any(nx)) out[nx] <- as.Date(x[nx], format = fmt)
  }
  out
}
tdate <- parse_xl_date(dcol)
tyear <- as.integer(format(tdate, "%Y"))
tdt <- data.table(fips = tfips, year = tyear, mon = (tyear - 1960L) * 12L + as.integer(format(tdate, "%m")) - 1L)
n_tm_dup <- sum(duplicated(tdt$fips[!is.na(tdt$fips)]))
tdt <- tdt[!is.na(fips) & !duplicated(fips)]
TIMING <- sort(intersect(U_fips, tdt[!is.na(mon) & abs(mon - 545L) <= 12L, fips]))
LOG$P9 <- list(rows = nrow(tm), rows_fips_unparseable = sum(is.na(tfips)),
               rows_duplicate_fips_ignored = n_tm_dup,
               rows_missing_date = sum(is.na(tdate)),
               U_counties_not_in_file = length(setdiff(U_fips, tdt$fips)),
               U_counties_missing_date = length(intersect(U_fips, tdt[is.na(year), fips])),
               timing_counties = length(TIMING),
               timing_treated = sum(treat_of(TIMING) == 1, na.rm = TRUE),
               timing_control = sum(treat_of(TIMING) == 0, na.rm = TRUE))

# ============================================================================
# P10. Address pairs
# ============================================================================
dst <- fread(file.path(data_dir, "distance.csv"), sep = "\t", header = TRUE)
setnames(dst, trimws(names(dst)))
for (j in c("origin_lat", "origin_lon", "dest_lat", "dest_lon", "ggl_distance", "osrm_distance"))
  set(dst, j = j, value = to_num(dst[[j]]))
dst[, fips := as.integer(round(to_num(fips)))]
n_dst <- nrow(dst)
n_dst_miss <- sum(is.na(dst$ggl_distance) | is.na(dst$osrm_distance))
dst <- dst[!is.na(ggl_distance) & !is.na(osrm_distance) & !is.na(fips)]
haversine <- function(lat1, lon1, lat2, lon2, R = 6371.0088) {
  rad <- pi / 180
  p1 <- lat1 * rad; p2 <- lat2 * rad
  dp <- (lat2 - lat1) * rad; dl <- (lon2 - lon1) * rad
  a <- sin(dp / 2)^2 + cos(p1) * cos(p2) * sin(dl / 2)^2
  2 * R * asin(pmin(1, sqrt(a)))
}
dst[, dist_km := haversine(origin_lat, origin_lon, dest_lat, dest_lon)]
LOG$P10 <- list(rows = n_dst, rows_missing_a_distance_removed = n_dst_miss,
                rows_county_in_U = sum(dst$fips %in% U_fips),
                rows_county_outside_U = sum(!(dst$fips %in% U_fips)),
                U_counties_with_pairs = length(intersect(U_fips, dst$fips)),
                rows_missing_dist_km = sum(is.na(dst$dist_km)))
msg("prep done")

# ============================================================================
# Placebo draws
# ============================================================================
pdraw <- fread(file.path(data_dir, "placebo_draws.csv"))
setnames(pdraw, trimws(names(pdraw)))
pdraw[, seed := as.integer(round(to_num(seed)))]
pdraw[, fips := as.integer(round(to_num(fips)))]
pdraw[, u := to_num(u)]
n_treat_U <- sum(U_treat == 1, na.rm = TRUE)
placebo_vec <- function(seed_val, variant) {
  d <- pdraw[seed == seed_val & fips %in% U_fips & !is.na(u)]
  d <- d[!duplicated(fips)]
  if (!nrow(d)) stop("no placebo draws for seed ", seed_val)
  if (variant == "placebo_perm") {
    setorder(d, u, fips)
    d[, ptreat := as.integer(seq_len(.N) <= n_treat_U)]
  } else {
    d[, ptreat := as.integer(u < n_treat_U / length(U_fips))]
  }
  pt <- d$ptreat[match(U_fips, d$fips)]
  list(treat = pt, n_missing = sum(is.na(pt)))
}

# ============================================================================
# Estimation engine
# ============================================================================
ncomp2 <- function(a, b) {
  e <- unique(data.table(a = as.integer(factor(a)), b = as.integer(factor(b))))
  na <- max(e$a)
  la <- seq_len(na)
  repeat {
    e[, lab := la[a]]
    lb <- e[, .(m = min(lab)), keyby = b]$m
    e[, lab := lb[b]]
    nl <- e[, .(m = min(lab)), keyby = a]$m
    nl <- pmin(nl, la)
    if (identical(nl, la)) break
    la <- nl
  }
  length(unique(la))
}

# design: list(y, X (matrix), fe (list of vectors), fe_method ("demean"/"dummy"),
#              cluster (county keys), focal (term names), ci ("cluster"/"hc1"))
fit_design <- function(d, drop_county = NULL) {
  sel <- rep(TRUE, length(d$y))
  if (!is.null(drop_county)) sel <- d$cluster != drop_county
  ok <- sel & !is.na(d$y) & !is.na(d$cluster)
  if (ncol(d$X)) ok <- ok & rowSums(is.na(d$X)) == 0
  for (f in d$fe) ok <- ok & !is.na(f)
  n_drop <- sum(sel & !ok)
  y <- d$y[ok]; X <- d$X[ok, , drop = FALSE]; cl <- d$cluster[ok]
  fe <- lapply(d$fe, function(f) f[ok])
  N <- length(y)
  if (N == 0) stop("no observations after dropping missing values")
  if (d$fe_method == "demean") {
    M <- fixest::demean(cbind(y, X), f = as.data.frame(fe), tol = 1e-12, iter = 50000,
                        notes = FALSE, as.matrix = TRUE)
    yt <- M[, 1]; Xt <- M[, -1, drop = FALSE]
    kfe <- if (length(fe) == 1) length(unique(fe[[1]])) else if (length(fe) == 2) {
      length(unique(fe[[1]])) + length(unique(fe[[2]])) - ncomp2(fe[[1]], fe[[2]])
    } else stop("demean method supports at most 2 FE dimensions")
  } else {
    D <- matrix(1, N, 1)
    for (f in fe) {
      ff <- factor(f)
      if (nlevels(ff) > 1) D <- cbind(D, model.matrix(~ff)[, -1, drop = FALSE])
    }
    qd <- qr(D, tol = 1e-9)
    kfe <- qd$rank
    yt <- qr.resid(qd, y); Xt <- qr.resid(qd, X)
    if (!is.matrix(Xt)) Xt <- matrix(Xt, ncol = ncol(X), dimnames = list(NULL, colnames(X)))
  }
  colnames(Xt) <- colnames(X)
  # slopes collinear with the fixed effects
  n0 <- sqrt(colSums(X^2)); n1 <- sqrt(colSums(Xt^2))
  kc <- n1 > 1e-7 * n0 & n1 > 0
  Xk <- Xt[, kc, drop = FALSE]
  if (ncol(Xk) > 0) {
    sc <- sqrt(colSums(Xk^2))
    qx <- qr(sweep(Xk, 2, sc, "/"), tol = 1e-9)
    if (qx$rank < ncol(Xk)) Xk <- Xk[, sort(qx$pivot[seq_len(qx$rank)]), drop = FALSE]
  }
  K <- ncol(Xk)
  if (K == 0) stop("no estimable slope coefficient")
  sc <- sqrt(colSums(Xk^2))
  Xs <- sweep(Xk, 2, sc, "/")
  qx <- qr(Xs, tol = 1e-12)
  if (qx$rank < K) stop("rank deficiency after collinearity removal")
  Ri <- backsolve(qr.R(qx), diag(K))
  XtXi_s <- matrix(0, K, K)
  XtXi_s[qx$pivot, qx$pivot] <- Ri %*% t(Ri)
  bs <- XtXi_s %*% crossprod(Xs, yt)
  u <- as.vector(yt - Xs %*% bs)
  G <- length(unique(cl))
  S <- rowsum(Xs * u, cl, reorder = FALSE)
  Vcl_s <- XtXi_s %*% crossprod(S) %*% XtXi_s
  Vhc_s <- XtXi_s %*% crossprod(Xs * u) %*% XtXi_s
  Dinv <- 1 / sc
  b <- as.vector(bs) * Dinv
  ccl <- if (G > 1 && N > K) (G / (G - 1)) * ((N - 1) / (N - K)) else NA_real_
  Kfull <- kfe + K
  chc <- if (N > Kfull) N / (N - Kfull) else NA_real_
  se_cl <- sqrt(pmax(diag(Vcl_s), 0) * ccl) * Dinv
  se_hc <- sqrt(pmax(diag(Vhc_s), 0) * chc) * Dinv
  names(b) <- names(se_cl) <- names(se_hc) <- colnames(Xk)
  tss <- sum((y - mean(y))^2)
  list(b = b, se_cl = se_cl, se_hc = se_hc, N = N, G = G, n_drop = n_drop, K = K, Kfull = Kfull,
       df_cl = if (G > 1) G - 1 else NA_real_, df_hc = if (N > Kfull) N - Kfull else NA_real_,
       r2 = if (tss > 0) 1 - sum(u^2) / tss else NA_real_,
       counties = sort(unique(cl)))
}

RES_COLS <- c("spec_id", "analysis", "term", "status", "error", "n_obs", "n_counties",
              "n_dropped_missing", "estimate", "se_cluster", "p_cluster", "df_cluster",
              "se_hc1", "p_hc1", "df_hc1", "ci_low", "ci_high", "r2", "k_slopes", "sample_hash")

fit_rows <- function(fit, focal, ci_type) {
  hash <- hash_keys(fit$counties)
  rbindlist(lapply(focal, function(tm) {
    if (!tm %in% names(fit$b)) {
      return(data.table(term = tm, status = "failed",
                        error = "focal term not estimable (collinear with fixed effects or other regressors, or no variation)",
                        n_obs = fit$N, n_counties = fit$G, n_dropped_missing = fit$n_drop,
                        r2 = fit$r2, k_slopes = fit$K, sample_hash = hash,
                        df_cluster = fit$df_cl, df_hc1 = fit$df_hc))
    }
    est <- unname(fit$b[tm]); sc <- unname(fit$se_cl[tm]); sh <- unname(fit$se_hc[tm])
    pc <- 2 * pt(-abs(est / sc), fit$df_cl)
    ph <- 2 * pt(-abs(est / sh), fit$df_hc)
    if (ci_type == "hc1") {
      w <- qt(0.975, fit$df_hc) * sh
    } else {
      w <- qt(0.975, fit$df_cl) * sc
    }
    data.table(term = tm, status = "ok", error = NA_character_, n_obs = fit$N, n_counties = fit$G,
               n_dropped_missing = fit$n_drop, estimate = est, se_cluster = sc, p_cluster = pc,
               df_cluster = fit$df_cl, se_hc1 = sh, p_hc1 = ph, df_hc1 = fit$df_hc,
               ci_low = est - w, ci_high = est + w, r2 = fit$r2, k_slopes = fit$K, sample_hash = hash)
  }), fill = TRUE)
}

# ============================================================================
# Design builders
# ============================================================================
g <- function(row, k) { v <- row[[k]]; if (is.null(v) || is.na(v)) "" else trimws(as.character(v)) }

sample_counties <- function(row) {
  s <- g(row, "sample")
  if (s == "full" || s == "") return(U_fips)
  if (s == "boundary") {
    B <- g(row, "B"); if (B == "") B <- "B1"
    if (B == "B1") return(B1)
    if (B == "B2") return(B2)
    stop("unknown B: ", B)
  }
  if (s == "timing") return(TIMING)
  stop("unknown sample: ", s)
}

PLACEBO_OUT <- list()
EXTRA <- list()

panel_design <- function(row, sfips, outcome, ctrl, treat_vec = U_treat, fe2 = "quarter") {
  idx <- which(pan$fips %in% sfips)
  oc <- outcome_col(outcome, g(row, "F"), g(row, "D"), g(row, "O"))
  G <- g(row, "G"); if (G == "") stop("G missing")
  y <- gtrans(pan[[oc]][idx], G)
  tr <- treat_vec[match(pan$fips[idx], U_fips)]
  X <- matrix(pan$post[idx] * tr, ncol = 1, dimnames = list(NULL, "post_treat"))
  if (ctrl == 1) {
    L <- g(row, "L"); if (L == "") L <- "L1"
    X <- cbind(X, PCTRL[[L]][idx, , drop = FALSE])
  }
  tfe <- if (fe2 == "quarter") pan$t[idx] else {
    qg <- POPD_Q4[match(pan$fips[idx], U_fips)]
    ifelse(is.na(qg), NA_integer_, qg * 1000L + pan$t[idx])
  }
  list(y = y, X = X, fe = list(county = pan$fips[idx], time = tfe), fe_method = "demean",
       cluster = pan$fips[idx], focal = "post_treat", ci = "cluster")
}

period_quarters <- function(p) {
  if (p == "P0814") return(QT[year >= 2008 & year <= 2014, t])
  if (p == "P14") return(QT[year == 2014, t])
  if (grepl("^P[0-9]{4}$", p)) {
    yy <- as.integer(substr(p, 2, 5))
    tt <- QT[year == yy, t]
    if (!length(tt)) stop("period outside panel: ", p)
    return(tt)
  }
  stop("unknown period: ", p)
}

cs_design <- function(row, sfips, outcome, period) {
  sfips <- sort(unique(sfips))
  oc <- outcome_col(outcome, g(row, "F"), g(row, "D"), g(row, "O"))
  tt <- period_quarters(period)
  sm <- pan[fips %in% sfips & t %in% tt, .(v = sum(get(oc))), by = fips]
  G <- g(row, "G"); if (G == "") stop("G missing")
  y <- gtrans(sm$v[match(sfips, sm$fips)], G)
  Y <- g(row, "Y"); if (Y == "") Y <- "Y1"
  L <- g(row, "L"); if (L == "") L <- "L1"
  Q <- g(row, "Q"); if (Q == "") Q <- "Q1"
  ctl <- CSCTRL[[paste(Y, L)]][match(sfips, U_fips), , drop = FALSE]
  X <- cbind(treat = treat_of(sfips), ctl)
  fe <- as.list(qfe(sfips, Y, Q, g(row, "R"), sfips))
  list(y = y, X = X, fe = fe, fe_method = "dummy", cluster = sfips, focal = "treat", ci = "cluster")
}

pair_design <- function(row, sfips) {
  W <- g(row, "W")
  p <- dst[fips %in% sfips]
  dd <- abs(p$osrm_distance - p$ggl_distance)
  n_excl <- 0L
  if (W == "W1") {
    ex <- dd == 0; n_excl <- sum(ex); p <- p[!ex]; y <- log(abs(p$osrm_distance - p$ggl_distance))
  } else if (W == "W3") {
    y <- log(dd + 1)
  } else if (W == "W4") {
    ex <- p$osrm_distance <= 0 | p$ggl_distance <= 0; n_excl <- sum(ex); p <- p[!ex]
    y <- abs(log(p$osrm_distance) - log(p$ggl_distance))
  } else stop("unknown W: ", W)
  y[!is.finite(y)] <- NA_real_
  Y <- g(row, "Y"); if (Y == "") Y <- "Y1"
  L <- g(row, "L"); if (L == "") L <- "L1"
  Q <- g(row, "Q"); if (Q == "") Q <- "Q1"
  ctl <- CSCTRL[[paste(Y, L)]][match(p$fips, U_fips), , drop = FALSE]
  X <- cbind(treat = treat_of(p$fips), dist_km = p$dist_km, ctl)
  fe <- as.list(qfe(p$fips, Y, Q, g(row, "R"), sfips))
  EXTRA[[g(row, "spec_id")]] <<- list(W = W, pairs_in_sample = nrow(p) + n_excl,
                                      pairs_excluded_by_W_rule = n_excl)
  list(y = y, X = X, fe = fe, fe_method = "dummy", cluster = p$fips,
       focal = c("treat", "dist_km"), ci = "cluster")
}

event_design <- function(row) {
  oc <- outcome_col(g(row, "outcome"), g(row, "F"), g(row, "D"), g(row, "O"))
  cy <- pan[, .(v = sum(get(oc))), by = .(fips, year)]
  setorder(cy, fips, year)
  y <- gtrans(cy$v, g(row, "G"))
  tr <- treat_of(cy$fips)
  yrs <- setdiff(2005:2014, 2007)
  X <- sapply(yrs, function(z) tr * as.integer(cy$year == z))
  colnames(X) <- paste0("treat_x_", yrs)
  list(y = y, X = X, fe = list(county = cy$fips, year = cy$year), fe_method = "demean",
       cluster = cy$fips, focal = colnames(X), ci = "cluster")
}

build_design <- function(row) {
  an <- g(row, "analysis")
  sid <- g(row, "spec_id")
  ctrl <- as.integer(to_num(g(row, "ctrl"))); if (is.na(ctrl)) ctrl <- 0L
  if (an %in% c("AN03", "AN08", "AN14")) {
    return(panel_design(row, sample_counties(row), g(row, "outcome"), ctrl))
  }
  if (an == "AN05") {
    v <- g(row, "variant")
    if (v == "dtt") return(panel_design(row, sample_counties(row), g(row, "outcome"), ctrl, fe2 = "dtt"))
    if (v %in% c("placebo_perm", "placebo_bern")) {
      sd <- as.integer(to_num(g(row, "seed")))
      if (is.na(sd)) stop("seed missing")
      pv <- placebo_vec(sd, v)
      PLACEBO_OUT[[sid]] <<- data.table(spec_id = sid, fips = U_fips, placebo_treat = pv$treat)
      EXTRA[[sid]] <<- list(seed = sd, placebo_treated = sum(pv$treat == 1, na.rm = TRUE),
                            counties_without_draw = pv$n_missing)
      return(panel_design(row, sample_counties(row), g(row, "outcome"), ctrl, treat_vec = pv$treat))
    }
    if (v %in% c("boundary", "timing")) {
      return(panel_design(row, sample_counties(row), g(row, "outcome"), ctrl))
    }
    stop("unknown variant: ", v)
  }
  if (an %in% c("AN04", "AN06", "AN12")) {
    return(cs_design(row, sample_counties(row), g(row, "outcome"), g(row, "period")))
  }
  if (an == "AN07") return(pair_design(row, sample_counties(row)))
  if (an == "AN11") return(event_design(row))
  if (an == "AN13") {
    dec <- as.integer(to_num(g(row, "decile")))
    sf <- intersect(sample_counties(row), U_fips[!is.na(POPD_D10) & POPD_D10 == dec])
    if (!length(sf)) stop("decile ", dec, " is empty")
    est <- g(row, "est")
    if (est == "M1") return(panel_design(row, sf, g(row, "outcome"), 1L))
    if (est == "M2") {
      p <- g(row, "period"); if (p == "") p <- "P0814"
      return(cs_design(row, sf, g(row, "outcome"), p))
    }
    stop("unknown est: ", est)
  }
  stop("analysis ", an, " has no regression design")
}

# ============================================================================
# Non-regression analyses
# ============================================================================
AN01_OUT <- list(); AN02_OUT <- list(); AN09_M <- list(); AN09_C <- list(); AN10_OUT <- list()

run_an01 <- function(row) {
  sid <- g(row, "spec_id")
  fo <- outcome_col("followon", g(row, "F"), "", "")
  cm <- pan[, .(total = mean(total), followon = mean(get(fo)), contributors = mean(contributors),
                owner = mean(owner)), by = fips]
  cm <- cm[match(U_fips, cm$fips)]
  em <- dst[fips %in% U_fips, .(err_mean = mean(abs(osrm_distance - ggl_distance))), by = fips]
  cm[, err_mean := em$err_mean[match(fips, em$fips)]]
  dv <- c("population", "households", "unemploymentrate", "popeduc", "popmales", "popyoungmales", "income_percapita")
  a <- pc[year == 2014][match(U_fips, fips)]
  b <- pc[year == 2005][match(U_fips, fips)]
  for (v in dv) set(cm, j = paste0("chg_", v), value = a[[v]] - b[[v]])
  cm[, treat := treat_of(fips)]
  vars <- c("total", "followon", "contributors", "owner", "err_mean", paste0("chg_", dv))
  out <- rbindlist(lapply(vars, function(v) {
    x1 <- cm[treat == 1, get(v)]; x0 <- cm[treat == 0, get(v)]
    x1 <- x1[!is.na(x1)]; x0 <- x0[!is.na(x0)]
    pw <- tryCatch(t.test(x1, x0, var.equal = FALSE)$p.value, error = function(e) NA_real_)
    pe <- tryCatch(t.test(x1, x0, var.equal = TRUE)$p.value, error = function(e) NA_real_)
    m1 <- if (length(x1)) mean(x1) else NA_real_; m0 <- if (length(x0)) mean(x0) else NA_real_
    data.table(spec_id = sid, variable = v,
               statistic = c("mean_treated", "mean_control", "diff_treated_minus_control",
                             "n_treated", "n_control", "p_welch", "p_equal_var"),
               value = c(m1, m0, m1 - m0, length(x1), length(x0), pw, pe))
  }))
  AN01_OUT[[sid]] <<- out
  data.table(term = NA_character_, status = "ok", n_obs = length(U_fips), n_counties = length(U_fips),
             sample_hash = hash_keys(U_fips))
}

run_an02 <- function(row) {
  sid <- g(row, "spec_id")
  F <- g(row, "F"); D <- g(row, "D"); O <- g(row, "O")
  cols <- list(total = "total", followon = outcome_col("followon", F, D, O),
               contributors = "contributors", distant = outcome_col("distant", F, D, O),
               incremental = outcome_col("incremental", F, D, O), new = "new", old = "old",
               low_own = outcome_col("low_own", F, D, O), high_own = "high_own", owner = "owner",
               treat = "treat", post = "post", year = "year", qidx = "qidx",
               population = "population", households = "households", popdensity = "popdensity",
               income_percapita = "income_percapita")
  out <- rbindlist(lapply(names(cols), function(v) {
    x <- as.numeric(pan[[cols[[v]]]]); x <- x[!is.na(x)]
    n <- length(x)
    data.table(spec_id = sid, variable = v,
               statistic = c("mean", "sd", "median", "min", "max", "n_nonmissing"),
               value = c(if (n) mean(x) else NA, if (n > 1) sd(x) else NA, if (n) median(x) else NA,
                         if (n) min(x) else NA, if (n) max(x) else NA, n))
  }))
  out <- rbind(out, data.table(spec_id = sid, variable = "_panel",
                               statistic = c("n_rows", "n_counties", "n_quarters"),
                               value = c(nrow(pan), uniqueN(pan$fips), uniqueN(pan$t))))
  AN02_OUT[[sid]] <<- out
  data.table(term = NA_character_, status = "ok", n_obs = nrow(pan), n_counties = uniqueN(pan$fips),
             sample_hash = hash_keys(pan$fips))
}

run_an09 <- function(row) {
  sid <- g(row, "spec_id")
  m <- data.table(spec_id = sid, fips = U_fips, treat = U_treat,
                  in_full = 1L,
                  in_boundary_B1 = as.integer(U_fips %in% B1),
                  in_boundary_B2 = as.integer(U_fips %in% B2),
                  in_timing = as.integer(U_fips %in% TIMING))
  AN09_M[[sid]] <<- m
  cnt <- rbindlist(lapply(c("in_full", "in_boundary_B1", "in_boundary_B2", "in_timing"), function(s) {
    data.table(spec_id = sid, sample = sub("^in_", "", s),
               group = c("treated", "control", "treat_missing", "all"),
               n_counties = c(sum(m[[s]] == 1 & m$treat %in% 1L), sum(m[[s]] == 1 & m$treat %in% 0L),
                              sum(m[[s]] == 1 & is.na(m$treat)), sum(m[[s]] == 1)))
  }))
  AN09_C[[sid]] <<- cnt
  data.table(term = NA_character_, status = "ok", n_obs = length(U_fips), n_counties = length(U_fips),
             sample_hash = hash_keys(U_fips))
}

run_an10 <- function(row) {
  sid <- g(row, "spec_id")
  fo <- outcome_col("followon", g(row, "F"), "", "")
  res <- list()
  for (o in c("total", "followon")) {
    oc <- if (o == "total") "total" else fo
    d <- pan[!is.na(treat), .(fips, t, quarter, treat, v = get(oc))]
    setorder(d, fips, t)
    d[, cum := cumsum(v), by = fips]
    d[, lv := gtrans(v, "G1")]
    s <- d[, .(mean_log_y_plus_1 = mean(lv), mean_cumulative_sum = mean(cum), n_counties = as.numeric(.N)),
           by = .(t, quarter, treat)]
    setorder(s, t, treat)
    s <- melt(s, id.vars = c("t", "quarter", "treat"), variable.name = "statistic", value.name = "value")
    s[, `:=`(spec_id = sid, outcome = o, followon_def = if (o == "followon") fo else NA_character_)]
    res[[o]] <- s
  }
  out <- rbindlist(res)
  out[, statistic := as.character(statistic)]
  setcolorder(out, c("spec_id", "outcome", "followon_def", "quarter", "t", "treat", "statistic", "value"))
  AN10_OUT[[sid]] <<- out
  data.table(term = NA_character_, status = "ok", n_obs = nrow(pan), n_counties = uniqueN(pan$fips[!is.na(pan$treat)]),
             sample_hash = hash_keys(pan$fips[!is.na(pan$treat)]))
}

run_spec <- function(row) {
  an <- g(row, "analysis")
  if (an == "AN01") return(run_an01(row))
  if (an == "AN02") return(run_an02(row))
  if (an == "AN09") return(run_an09(row))
  if (an == "AN10") return(run_an10(row))
  d <- build_design(row)
  ci <- if (an == "AN12") "hc1" else d$ci
  fit <- fit_design(d)
  fit_rows(fit, d$focal, ci)
}

# ============================================================================
# Grid
# ============================================================================
grid <- fread(grid_path, colClasses = "character", na.strings = NULL)
for (j in names(grid)) { x <- grid[[j]]; x[is.na(x)] <- ""; set(grid, j = j, value = trimws(x)) }

write_session <- function() {
  pk <- c("data.table", "fixest", "haven", "readxl", "jsonlite", "sandwich", "lmtest", "foreign")
  lines <- c(R.version.string,
             paste0("platform: ", R.version$platform),
             vapply(pk, function(p) paste0(p, " ", tryCatch(as.character(packageVersion(p)), error = function(e) "not installed")), ""),
             "", capture.output(sessionInfo()))
  writeLines(lines, file.path(out_dir, "session_info.txt"))
}
write_log <- function() {
  LOG$grid_file <- grid_path
  if (length(EXTRA)) LOG$per_spec <- EXTRA
  write_json(LOG, file.path(out_dir, "prep_log.json"), auto_unbox = TRUE, pretty = TRUE,
             digits = NA, na = "null", null = "null")
}

# ============================================================================
# Influence mode
# ============================================================================
if (!is.null(infl_spec)) {
  row <- grid[spec_id == infl_spec]
  if (nrow(row) != 1) stop("spec_id not found in grid: ", infl_spec)
  row <- as.list(row)
  an <- g(row, "analysis")
  res <- tryCatch({
    d <- build_design(row)
    base <- fit_design(d)
    ctys <- base$counties
    msg("influence:", infl_spec, an, "refits:", length(ctys))
    rbindlist(lapply(ctys, function(cty) {
      r <- tryCatch({
        f <- fit_design(d, drop_county = cty)
        fr <- fit_rows(f, d$focal[1:ifelse(an == "AN11", length(d$focal), 1)], "cluster")
        fr[, .(term, status, error, n_obs, estimate, se_cluster, p_cluster, se_hc1, p_hc1)]
      }, error = function(e) data.table(term = d$focal[1], status = "failed", error = conditionMessage(e)))
      cbind(data.table(spec_id = infl_spec, removed_county = cty), r)
    }), fill = TRUE)
  }, error = function(e) data.table(spec_id = infl_spec, removed_county = NA_integer_, term = NA_character_,
                                    status = "failed", error = conditionMessage(e)))
  cols <- c("spec_id", "removed_county", "term", "status", "error", "n_obs", "estimate",
            "se_cluster", "p_cluster", "se_hc1", "p_hc1")
  for (cc in setdiff(cols, names(res))) res[, (cc) := NA]
  setcolorder(res, cols)
  fwrite(res[, ..cols], file.path(out_dir, paste0("influence_", infl_spec, ".csv")))
  write_log()
  write_session()
  msg("influence done in", round(as.numeric(difftime(Sys.time(), t_start, units = "secs"))), "s")
  quit(save = "no", status = 0)
}

# ============================================================================
# Full grid
# ============================================================================
out <- vector("list", nrow(grid))
for (i in seq_len(nrow(grid))) {
  row <- as.list(grid[i])
  sid <- row$spec_id; an <- row$analysis
  r <- tryCatch(run_spec(row), error = function(e) {
    data.table(term = NA_character_, status = "failed", error = conditionMessage(e))
  })
  r[, `:=`(spec_id = sid, analysis = an)]
  out[[i]] <- r
  if (i %% 100 == 0) msg("spec", i, "of", nrow(grid))
}
results <- rbindlist(out, fill = TRUE)
for (cc in setdiff(RES_COLS, names(results))) results[, (cc) := NA]
results <- results[, ..RES_COLS]
fwrite(results, file.path(out_dir, "results.csv"))

emptyish <- function(lst, cols) if (length(lst)) rbindlist(lst, fill = TRUE) else
  setnames(data.table(matrix(nrow = 0, ncol = length(cols))), cols)
fwrite(emptyish(AN01_OUT, c("spec_id", "variable", "statistic", "value")), file.path(out_dir, "an01_groups.csv"))
fwrite(emptyish(AN02_OUT, c("spec_id", "variable", "statistic", "value")), file.path(out_dir, "an02_summary.csv"))
fwrite(emptyish(AN09_M, c("spec_id", "fips", "treat", "in_full", "in_boundary_B1", "in_boundary_B2", "in_timing")),
       file.path(out_dir, "an09_membership.csv"))
fwrite(emptyish(AN09_C, c("spec_id", "sample", "group", "n_counties")), file.path(out_dir, "an09_counts.csv"))
fwrite(emptyish(AN10_OUT, c("spec_id", "outcome", "followon_def", "quarter", "t", "treat", "statistic", "value")),
       file.path(out_dir, "an10_means.csv"))
fwrite(emptyish(PLACEBO_OUT, c("spec_id", "fips", "placebo_treat")), file.path(out_dir, "placebo_vectors.csv"))
LOG$run <- list(grid_rows = nrow(grid), result_rows = nrow(results),
                specs_with_failed_rows = uniqueN(results[status == "failed", spec_id]),
                seconds = round(as.numeric(difftime(Sys.time(), t_start, units = "secs")), 1))
write_log()
write_session()
msg("done:", nrow(results), "result rows;", sum(results$status == "failed"), "failed rows")
