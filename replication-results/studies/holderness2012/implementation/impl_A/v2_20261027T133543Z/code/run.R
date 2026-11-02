#!/usr/bin/env Rscript
# Analysis manifest P-R7M2 v1: probit analyses of POW survival and camp hierarchy.
# Invocation:
#   Rscript run.R --grid grid.json --data data --out results --specs S000[,S001,...|all] --influence all|first20|none
# Optional development flags: --families T4,T5  (restrict families)   --dry  (sample/variable construction only)
# Sourcing this file (e.g. from tests/) defines the functions without running main().

suppressMessages({
  library(data.table)
  library(nanoparquet)
  library(jsonlite)
})
options(warn = 1, stringsAsFactors = FALSE, datatable.print.class = FALSE)

# =====================================================================================
# 0. Logging and CLI
# =====================================================================================
.log_file <- NULL
logf <- function(...) {
  msg <- sprintf("[%s] %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), paste0(..., collapse = ""))
  cat(msg, "\n")
  if (!is.null(.log_file)) cat(msg, "\n", file = .log_file, append = TRUE)
  invisible(msg)
}

parse_args <- function(args) {
  opts <- list(grid = "grid.json", data = "data", out = "results", specs = "S000",
               influence = "all", families = NULL, dry = FALSE)
  i <- 1L
  while (i <= length(args)) {
    a <- args[i]
    if (a == "--dry") { opts$dry <- TRUE; i <- i + 1L; next }
    key <- sub("^--", "", a)
    if (!key %in% names(opts)) stop("unknown argument: ", a)
    opts[[key]] <- args[i + 1L]
    i <- i + 2L
  }
  if (!opts$influence %in% c("all", "first20", "none")) stop("--influence must be all|first20|none")
  opts
}

# =====================================================================================
# 1. Parquet reading with embedded NUL bytes
#    nanoparquet converts BYTE_ARRAY/STRING columns to R strings and fails on NUL bytes.
#    Fallback: copy the file and patch its footer so that the leaves lose the STRING
#    annotation (converted_type field 6 is relabelled as field 7 = scale with value 0;
#    the logicalType field that follows then resolves to the unknown id 11 and is
#    skipped). The reader then returns raw bytes, which are converted here.
# =====================================================================================
.read_varint <- function(b, pos) {
  val <- 0; shift <- 0
  repeat {
    byte <- as.integer(b[pos]); pos <- pos + 1
    val <- val + bitwAnd(byte, 127L) * 2^shift
    shift <- shift + 7
    if (byte < 128) break
  }
  list(val = val, pos = pos)
}
.zigzag <- function(u) if (u %% 2 == 0) u / 2 else -(u + 1) / 2
.skip_value <- function(b, pos, type) {
  if (type %in% c(1L, 2L)) return(pos)
  if (type == 3L) return(pos + 1)
  if (type %in% c(4L, 5L, 6L)) return(.read_varint(b, pos)$pos)
  if (type == 7L) return(pos + 8)
  if (type == 8L) { v <- .read_varint(b, pos); return(v$pos + v$val) }
  if (type %in% c(9L, 10L)) {
    hdr <- as.integer(b[pos]); pos <- pos + 1
    size <- bitwShiftR(hdr, 4); etype <- bitwAnd(hdr, 15L)
    if (size == 15L) { v <- .read_varint(b, pos); size <- v$val; pos <- v$pos }
    for (i in seq_len(size)) pos <- .skip_value(b, pos, etype)
    return(pos)
  }
  if (type == 11L) {
    v <- .read_varint(b, pos); size <- v$val; pos <- v$pos
    if (size > 0) {
      kv <- as.integer(b[pos]); pos <- pos + 1
      kt <- bitwShiftR(kv, 4); vt <- bitwAnd(kv, 15L)
      for (i in seq_len(size)) { pos <- .skip_value(b, pos, kt); pos <- .skip_value(b, pos, vt) }
    }
    return(pos)
  }
  if (type == 12L) return(.skip_struct(b, pos))
  stop("unknown thrift type ", type)
}
.skip_struct <- function(b, pos) {
  last_id <- 0
  repeat {
    hdr <- as.integer(b[pos]); pos <- pos + 1
    if (hdr == 0L) return(pos)
    type <- bitwAnd(hdr, 15L); delta <- bitwShiftR(hdr, 4)
    if (delta == 0L) { v <- .read_varint(b, pos); pos <- v$pos; fid <- .zigzag(v$val) } else fid <- last_id + delta
    last_id <- fid
    pos <- .skip_value(b, pos, type)
  }
}
.parse_schema_element <- function(b, pos) {
  last_id <- 0
  info <- list(type = NA, conv_hdr_pos = NA, conv_val = NA, conv_delta = NA, lt_hdr_pos = NA,
               lt_delta = NA, lt_is_string = NA, fields = integer(0), name = NA)
  repeat {
    hdr_pos <- pos
    hdr <- as.integer(b[pos]); pos <- pos + 1
    if (hdr == 0L) break
    type <- bitwAnd(hdr, 15L); delta <- bitwShiftR(hdr, 4)
    if (delta == 0L) { v <- .read_varint(b, pos); pos <- v$pos; fid <- .zigzag(v$val) } else fid <- last_id + delta
    last_id <- fid
    info$fields <- c(info$fields, as.integer(fid))
    if (fid == 1) { v <- .read_varint(b, pos); info$type <- .zigzag(v$val) }
    if (fid == 4) { v <- .read_varint(b, pos); info$name <- rawToChar(b[v$pos:(v$pos + v$val - 1)]) }
    if (fid == 6) { v <- .read_varint(b, pos); info$conv_val <- .zigzag(v$val); info$conv_hdr_pos <- hdr_pos; info$conv_delta <- delta }
    if (fid == 10) { info$lt_hdr_pos <- hdr_pos; info$lt_delta <- delta; info$lt_is_string <- (as.integer(b[pos]) == 0x1CL) }
    pos <- .skip_value(b, pos, type)
  }
  info$end <- pos
  info
}
patch_parquet_strings <- function(src, dst) {
  sz <- file.size(src)
  con <- file(src, "rb"); on.exit(close(con))
  seek(con, sz - 8); tl <- readBin(con, "raw", 8)
  if (rawToChar(tl[5:8]) != "PAR1") stop("not a parquet file: ", src)
  flen <- sum(as.integer(tl[1:4]) * 256^(0:3))
  fstart <- sz - 8 - flen
  seek(con, fstart); b <- readBin(con, "raw", flen)
  pos <- 1; last_id <- 0; patches <- list(); names_patched <- character(0)
  repeat {
    hdr <- as.integer(b[pos]); pos <- pos + 1
    if (hdr == 0L) break
    type <- bitwAnd(hdr, 15L); delta <- bitwShiftR(hdr, 4)
    if (delta == 0L) { v <- .read_varint(b, pos); pos <- v$pos; fid <- .zigzag(v$val) } else fid <- last_id + delta
    last_id <- fid
    if (fid == 2) {
      lh <- as.integer(b[pos]); pos <- pos + 1
      size <- bitwShiftR(lh, 4); etype <- bitwAnd(lh, 15L)
      if (size == 15L) { v <- .read_varint(b, pos); size <- v$val; pos <- v$pos }
      if (etype != 12L) stop("unexpected parquet schema encoding")
      for (i in seq_len(size)) {
        info <- .parse_schema_element(b, pos)
        if (!is.na(info$type) && info$type == 6 && !is.na(info$conv_hdr_pos) && info$conv_val == 0) {
          ok_layout <- identical(info$fields, c(1L, 3L, 4L, 6L)) || identical(info$fields, c(1L, 3L, 4L, 6L, 10L))
          if (!ok_layout || info$conv_delta != 2L ||
              (!is.na(info$lt_hdr_pos) && !(info$lt_delta == 4L && isTRUE(info$lt_is_string))))
            stop("unexpected SchemaElement layout for column ", info$name)
          patches[[length(patches) + 1]] <- list(pos = info$conv_hdr_pos, byte = as.raw(0x35))
          names_patched <- c(names_patched, info$name)
        }
        pos <- info$end
      }
    } else {
      pos <- .skip_value(b, pos, type)
    }
  }
  if (!file.copy(src, dst, overwrite = TRUE)) stop("could not copy ", src)
  out <- file(dst, "r+b")
  for (p in patches) { seek(out, fstart + p$pos - 1, rw = "write"); writeBin(p$byte, out) }
  close(out)
  invisible(names_patched)
}
# list of raw vectors -> character. Only NUL bytes are removed (manifest: String handling); every other
# byte is kept as is. Bytes above 0x7f (none occur in the data) are preserved by declaring the string
# latin1, in which every byte is one character, so distinct byte values stay distinct and nchar()
# counts the bytes of the fixed-width slice.
raw_to_chr <- function(x) {
  lens <- lengths(x)
  r <- unlist(x, use.names = FALSE)
  if (is.null(r)) r <- raw(0)
  nul <- r == as.raw(0)
  if (any(nul)) {
    idx <- rep.int(seq_along(lens), lens)
    lens <- lens - tabulate(idx[nul], nbins = length(lens))
    r <- r[!nul]
  }
  s <- rawToChar(r)
  if (any(r > as.raw(0x7f))) Encoding(s) <- "latin1"
  ends <- cumsum(lens); starts <- ends - lens + 1
  substring(s, starts, ends)
}
# Read columns from a parquet file, one column at a time, with the NUL-safe fallback.
read_parquet_cols <- function(file, cols) {
  direct <- tryCatch(read_parquet(file, col_select = cols, options = parquet_options(class = "data.frame")),
                     error = function(e) e)
  if (!inherits(direct, "error")) return(as.data.table(direct))
  if (!grepl("embedded nul", conditionMessage(direct))) stop(direct)
  tmp <- tempfile(fileext = ".parquet"); on.exit(unlink(tmp))
  patch_parquet_strings(file, tmp)
  out <- list()
  for (cc in cols) {
    x <- read_parquet(tmp, col_select = cc, options = parquet_options(use_arrow_metadata = FALSE, class = "data.frame"))[[1]]
    out[[cc]] <- if (is.list(x)) raw_to_chr(x) else x
  }
  as.data.table(out)
}

# =====================================================================================
# 2. String cleaning and small helpers
# =====================================================================================
cl <- function(x) {
  x <- gsub("\\x00", "", x, fixed = TRUE)   # literal escape text (crosswalk csv)
  trimws(x)
}
num_or_na <- function(x) suppressWarnings(ifelse(grepl("^[0-9]+$", x), as.integer(x), NA_integer_))
haversine_km <- function(lat1, lon1, lat2, lon2) {
  rad <- pi / 180
  dlat <- (lat2 - lat1) * rad; dlon <- (lon2 - lon1) * rad
  a <- sin(dlat / 2)^2 + cos(lat1 * rad) * cos(lat2 * rad) * sin(dlon / 2)^2
  2 * 6371 * asin(pmin(1, sqrt(a)))
}
read_code_list_codes <- function(path) {
  # the NARA code lists contain unescaped quotes inside fields; take the first quoted field per line,
  # cleaned like every other code (manifest line 12) before it is compared with the cleaned CAMP
  lines <- readLines(path, warn = FALSE)[-1]
  m <- regmatches(lines, regexpr('^"([^"]*)"', lines))
  cl(gsub('"', "", m))
}

# =====================================================================================
# 3. Inputs (parameter independent)
# =====================================================================================
load_inputs <- function(data_dir) {
  t0 <- Sys.time()
  pow_cols <- c("record_seq", "SERIAL_NO", "GRADE_ALPHA", "GRADE_CODE", "SERVICE_CODE", "ARM_SVC_ALPHA",
                "ARM_SVC_CODE", "DATE_REPORTED_MONTH", "DATE_REPORTED_YEAR", "TYPE_ORG", "PARENT_UNIT_NUM",
                "PARENT_UNIT_TYPE", "STA", "DET_POWER", "CAMP")
  pow <- read_parquet_cols(file.path(data_dir, "pow.parquet"), pow_cols)
  for (v in setdiff(pow_cols, "record_seq")) set(pow, j = v, value = cl(pow[[v]]))
  pow[, record_seq := as.numeric(record_seq)]
  logf("POW rows read: ", nrow(pow), " (", format(round(difftime(Sys.time(), t0, units = "secs"), 1)), ")")

  # enlistment: link on serial early, keep all duplicates (dup rule is a spec parameter)
  t0 <- Sys.time()
  enl_file <- file.path(data_dir, "enl.parquet")
  serials <- unique(pow$SERIAL_NO[pow$SERIAL_NO != ""])
  ser <- read_parquet_cols(enl_file, "SER_NUM")$SER_NUM
  key <- cl(gsub("#", " ", ser, fixed = TRUE))
  keep <- which(key != "" & key %in% serials)
  rm(ser)
  enl <- data.table(ser_key = key[keep])
  rm(key)
  enl_cols <- c("record_seq", "CARD_NUM", "HEIGHT", "ERC_HEIGHT", "YR_BIRTH", "ERC_YR_BIRTH", "EDUCATION",
                "ERC_EDUCATION", "MARITAL_STATUS", "ERC_MARITAL_STATUS")
  for (cc in enl_cols) {
    x <- read_parquet_cols(enl_file, cc)[[1]][keep]
    if (cc != "record_seq") x <- cl(x) else x <- as.numeric(x)
    set(enl, j = cc, value = x)
  }
  enl[, n_dup := .N, by = ser_key]   # card layout is applied in enl_covariates(), after the dup_serial rule
  logf("Enlistment rows linked to POW serials: ", nrow(enl), " (distinct serials ", uniqueN(enl$ser_key),
       ", serials with >1 record ", uniqueN(enl$ser_key[enl$n_dup > 1]), ") (",
       format(round(difftime(Sys.time(), t0, units = "secs"), 1)), ")")

  cw <- fread(file.path(data_dir, "camp_location_crosswalk.csv"), colClasses = "character", encoding = "UTF-8")
  # every crosswalk field that is compared or parsed is cleaned first (manifest line 12)
  cw[, code := cl(camp_code)]
  cw[, confidence := cl(confidence)]
  cw[, identified_place_name := cl(identified_place_name)]
  cw[, nara_degree_coords_text := cl(nara_degree_coords_text)]
  cw[, lat := suppressWarnings(as.numeric(latitude))]
  cw[, lon := suppressWarnings(as.numeric(longitude))]
  cw <- cw[order(code, entry_id)]

  rank_alpha <- fread(file.path(data_dir, "rank_map_grade_alpha.csv"), colClasses = "character")
  rank_alpha[, label := trimws(grade_alpha)]
  rank_alpha <- rank_alpha[!duplicated(label)]            # first row per label
  rank_code <- fread(file.path(data_dir, "rank_map_grade_code.csv"), colClasses = "character")
  rank_code[, code := trimws(grade_code)]
  rank_code <- rank_code[!duplicated(code)]

  camp_codes_defined <- read_code_list_codes(file.path(data_dir, "..", "code_lists", "pow_CAMP_cl1277.csv"))
  if (!length(camp_codes_defined)) stop("could not read camp code list")
  list(pow = pow, enl = enl, cw = cw, rank_alpha = rank_alpha, rank_code = rank_code,
       camp_codes_defined = camp_codes_defined)
}

# =====================================================================================
# 4. Rank
# =====================================================================================
to_rank <- function(x) suppressWarnings(as.integer(ifelse(is.na(x) | x == "", NA, x)))
rank_alpha_lookup <- function(label, navy, tab, which) {
  idx <- match(label, tab$label)
  if (which == "origin") {
    v <- ifelse(navy, tab$rank_origin_navy[idx], tab$rank_origin_service_not_navy[idx])
  } else {
    v <- ifelse(navy, tab$rank_strict_navy[idx], tab$rank_strict_service_not_navy[idx])
  }
  to_rank(v)
}
rank_code_lookup <- function(code, officer, navy, tab) {
  idx <- match(code, tab$code)
  v <- ifelse(officer & !navy, tab$rank_officer_not_navy[idx],
       ifelse(officer & navy, tab$rank_officer_navy[idx],
       ifelse(!officer & navy, tab$rank_enlisted_navy[idx], tab$rank_enlisted_not_navy[idx])))
  to_rank(v)
}
compute_rank <- function(pow, rule, inputs) {
  navy <- pow$SERVICE_CODE == "2"
  officer <- substr(pow$SERIAL_NO, 1, 1) %in% c("O", "T")
  if (rule == "origin") {
    r <- rank_alpha_lookup(pow$GRADE_ALPHA, navy, inputs$rank_alpha, "origin")
    m <- is.na(r)
    r[m] <- rank_code_lookup(pow$GRADE_CODE[m], officer[m], navy[m], inputs$rank_code)
  } else if (rule == "strict") {
    r <- rank_alpha_lookup(pow$GRADE_ALPHA, navy, inputs$rank_alpha, "strict")
  } else if (rule == "grade_code") {
    r <- rank_code_lookup(pow$GRADE_CODE, officer, navy, inputs$rank_code)
    m <- is.na(r)
    r[m] <- rank_alpha_lookup(pow$GRADE_ALPHA[m], navy[m], inputs$rank_alpha, "origin")
  } else stop("unknown rank_rule ", rule)
  r
}

# =====================================================================================
# 5. Spec-level variable construction
# =====================================================================================
camp_coordinates <- function(cw, coords_rule) {
  # first row (lowest entry_id, string order) per code with confidence exact/approximate
  ok <- cw[confidence %in% c("exact", "approximate")]
  ok <- ok[!duplicated(code)]
  if (coords_rule == "crosswalk") {
    ok[, `:=`(use_lat = lat, use_lon = lon)]
  } else if (coords_rule == "nara_degree") {
    # the crosswalk latitude/longitude are used only when the text is absent (blank after cleaning);
    # text that is present but cannot be parsed as LAT-LON gives missing coordinates
    absent <- cl(ok$nara_degree_coords_text) == ""
    txt <- gsub(" ", "", ok$nara_degree_coords_text)
    first <- sub(";.*$", "", txt)              # multi-valued text: first LAT-LON pair
    m <- regmatches(first, regexec("^([0-9]+)-([0-9]+)$", first))
    plat <- vapply(m, function(z) if (length(z) == 3) as.numeric(z[2]) else NA_real_, 1)
    plon <- vapply(m, function(z) if (length(z) == 3) as.numeric(z[3]) else NA_real_, 1)
    ok[, `:=`(use_lat = ifelse(absent, lat, plat), use_lon = ifelse(absent, lon, plon))]
  } else stop("unknown coords ", coords_rule)
  ok[, .(code, use_lat, use_lon, place = identified_place_name)]
}

ENL_FIELDS <- c("CARD_NUM", "HEIGHT", "ERC_HEIGHT", "YR_BIRTH", "ERC_YR_BIRTH", "EDUCATION", "ERC_EDUCATION",
                "MARITAL_STATUS", "ERC_MARITAL_STATUS")
# card layout (manifest lines 60-63): CARD_NUM = "3" -> ERC_* fields, otherwise the standard fields
card_layout <- function(e) {
  erc <- e$CARD_NUM == "3"
  data.table(ser_key = e$ser_key,
             height_raw = ifelse(erc, e$ERC_HEIGHT, e$HEIGHT),
             yob_raw = ifelse(erc, e$ERC_YR_BIRTH, e$YR_BIRTH),
             educ_raw = ifelse(erc, e$ERC_EDUCATION, e$EDUCATION),
             marital_raw = ifelse(erc, e$ERC_MARITAL_STATUS, e$MARITAL_STATUS))
}
enl_covariates <- function(enl, P) {
  # apply dup_serial rule to the enlistment records -> one record per serial key, then the card layout
  if (P$dup_serial == "unmatched") {
    e <- enl[n_dup == 1]
  } else if (P$dup_serial == "first") {
    e <- enl[order(ser_key, record_seq)][!duplicated(ser_key)]
  } else if (P$dup_serial == "combine") {
    # field by field over the original record fields (CARD_NUM included): the common value when all
    # non-blank duplicates agree, blank (missing) otherwise; the card layout is applied to the combined record
    comb <- function(x) { u <- unique(x[x != ""]); if (length(u) == 1) u else "" }
    e <- rbind(enl[n_dup == 1, c("ser_key", ENL_FIELDS), with = FALSE],
               enl[n_dup > 1, lapply(.SD, comb), by = ser_key, .SDcols = ENL_FIELDS])
  } else stop("unknown dup_serial ", P$dup_serial)
  e <- card_layout(e)
  # height
  h <- num_or_na(e$height_raw)
  if (P$height_rule == "range") h[!is.na(h) & (h < 48 | h > 84)] <- NA
  else if (P$height_rule == "none") h[] <- NA
  else stop("unknown height_rule")
  # age
  yb <- num_or_na(e$yob_raw)
  yb[!grepl("^[0-9]{2}$", e$yob_raw)] <- NA     # two-digit numeric field
  age <- 1945 - (1900 + yb)
  if (P$age_rule == "range") age[!is.na(age) & (age < 15 | age > 70)] <- NA
  else if (P$age_rule != "none") stop("unknown age_rule")
  # education
  ed <- num_or_na(e$educ_raw)
  ed[!grepl("^[0-9]$", e$educ_raw)] <- NA
  ed <- as.numeric(ed)
  if (identical(P$educ_postgrad, "missing")) ed[!is.na(ed) & ed == 9] <- NA
  else ed[!is.na(ed) & ed == 9] <- as.numeric(P$educ_postgrad)
  # dependents
  ms <- e$marital_raw
  dep <- rep(NA_real_, length(ms))
  dep[ms %in% c("1", "3", "4", "5")] <- 1
  dep[ms %in% c("6", "7", "8", "9")] <- 0
  if (identical(P$married, "missing")) dep[ms == "2"] <- NA else dep[ms == "2"] <- as.numeric(P$married)
  data.table(ser_key = e$ser_key, height = h / 10, age = age / 100, education = ed / 10, dependents = dep)
}

build_spec_data <- function(inputs, P) {
  pow <- copy(inputs$pow)
  pow[, rank := compute_rank(pow, P$rank_rule, inputs)]
  pow[, officer := ifelse(is.na(rank), NA_real_, as.numeric(rank >= 5))]
  pow[, camp := CAMP]
  pow[, camp_valid := nchar(camp) == 3 & camp != "000"]
  if (P$camp_valid == "defined") pow[, camp_valid := camp_valid & camp %in% inputs$camp_codes_defined]
  else if (P$camp_valid != "nonblank") stop("unknown camp_valid")
  pow[, month_valid := DATE_REPORTED_YEAR %in% as.character(1:6) & DATE_REPORTED_MONTH %in% sprintf("%02d", 1:12)]
  pow[, year := ifelse(month_valid, 1940L + suppressWarnings(as.integer(DATE_REPORTED_YEAR)), NA_integer_)]
  pow[, month := ifelse(month_valid, suppressWarnings(as.integer(DATE_REPORTED_MONTH)), NA_integer_)]
  pow[, cohort := ifelse(camp_valid & month_valid, paste(camp, year, sprintf("%02d", month), sep = "_"), NA_character_)]
  pow[, survival := ifelse(STA %in% c("7", "8", "9"), 1, ifelse(STA %in% c("4", "5"), 0, NA_real_))]
  pow[, executed := as.numeric(STA == "4")]
  pow[, japan := as.numeric(DET_POWER == "2")]
  end_month <- ifelse(pow$DET_POWER == "1", 5, ifelse(pow$DET_POWER == "2", 9, NA))
  set(pow, j = "length", value = ((1945 - pow$year) * 12 + (end_month - pow$month)) / 10)
  # distance
  cc <- camp_coordinates(inputs$cw, P$coords)
  ci <- match(pow$camp, cc$code)
  cap_lat <- ifelse(pow$DET_POWER == "1", 52.5200, ifelse(pow$DET_POWER == "2", 35.6762, NA))
  cap_lon <- ifelse(pow$DET_POWER == "1", 13.4050, ifelse(pow$DET_POWER == "2", 139.6503, NA))
  km <- haversine_km(cc$use_lat[ci], cc$use_lon[ci], cap_lat, cap_lon)
  is_capital <- (pow$DET_POWER == "1" & cc$place[ci] %in% "Berlin") | (pow$DET_POWER == "2" & cc$place[ci] %in% "Tokyo")
  km[is_capital] <- 1
  km[!is.na(km) & km <= 0] <- NA
  km[!pow$camp_valid] <- NA
  set(pow, j = "distance", value = log(km) / 10)
  # enlistment covariates
  ec <- enl_covariates(inputs$enl, P)
  ei <- match(pow$SERIAL_NO, ec$ser_key)
  ei[pow$SERIAL_NO == ""] <- NA
  pow[, `:=`(height = ec$height[ei], age = ec$age[ei], education = ec$education[ei], dependents = ec$dependents[ei],
             linked = !is.na(ei))]
  # unit and AAF flag
  pow[, unit := ifelse(TYPE_ORG == "" & PARENT_UNIT_NUM == "" & PARENT_UNIT_TYPE == "", NA_character_,
                       paste(TYPE_ORG, PARENT_UNIT_NUM, PARENT_UNIT_TYPE, sep = "|"))]
  pow[, aaf := SERVICE_CODE == "1" & (ARM_SVC_CODE == "20" | ARM_SVC_ALPHA == "AC") & DET_POWER == "1"]

  # ---- samples ----
  svc_ex <- unlist(P$svc_exclude)
  set(pow, j = "in_D", value = !(pow$SERVICE_CODE %in% svc_ex) & pow$DET_POWER %in% c("1", "2") & pow$STA %in% c("4", "5", "7", "8", "9"))
  set(pow, j = "in_R_cap", value = pow$in_D & pow$camp_valid & pow$month_valid)
  if (isTRUE(P$sample_common)) set(pow, j = "in_R_camp", value = pow$in_R_cap)
  else set(pow, j = "in_R_camp", value = pow$in_D & pow$camp_valid)

  # ---- reference fractions ----
  if (P$pop_fractions == "descriptive") pr_rows <- pow$in_D & !is.na(pow$rank)
  else if (P$pop_fractions == "regression") pr_rows <- pow$in_R_cap & !is.na(pow$rank)
  else stop("unknown pop_fractions")
  p <- tabulate(pow$rank[pr_rows], 9) / sum(pr_rows)
  c_same <- if (P$sameness_constant == "fixed") 1.319 else if (P$sameness_constant == "recomputed") (1 - p[9])^2 + sum(p[1:8]^2) else stop("unknown sameness_constant")

  # ---- group members ----
  # member sets: "all" = the model's estimation sample is R (or the column-specific sample); "aaf" = the
  # R_aaf estimation sample (AAF rows of R), whose group variables are computed over its own rows
  # (manifest line 31; line 91 gives no pre-subsetting exception). "file" membership does not depend on the
  # estimation sample and is identical for both sets.
  member_sets <- list(all = rep(TRUE, nrow(pow)), aaf = pow$aaf)
  members <- list(); gstats <- list()
  for (ms in names(member_sets)) {
    members[[ms]] <- list(); gstats[[ms]] <- list()
    for (g in c("cap", "camp")) {
      gid <- if (g == "cap") pow$cohort else pow$camp
      if (P$group_members == "regression") {
        sel <- (if (g == "cap") pow$in_R_cap else pow$in_R_camp) & !is.na(pow$rank) & member_sets[[ms]]
      } else if (P$group_members == "complete") {
        sel <- (if (g == "cap") pow$in_R_cap else pow$in_R_camp) & !is.na(pow$rank) & member_sets[[ms]] &
          !is.na(pow$height) & !is.na(pow$age) & !is.na(pow$education) & !is.na(pow$dependents)
      } else if (P$group_members == "file") {
        sel <- pow$camp_valid & (if (g == "cap") pow$month_valid else TRUE) & !is.na(pow$rank)
      } else stop("unknown group_members")
      sel <- sel & !is.na(gid)
      mb <- data.table(record_seq = pow$record_seq[sel], g = gid[sel], rank = pow$rank[sel], unit = pow$unit[sel])
      members[[ms]][[g]] <- mb
      gstats[[ms]][[g]] <- group_stats(mb$g, mb$rank, p, c_same)
    }
  }
  list(pow = pow, p = p, c_same = c_same, members = members, gstats = gstats, P = P)
}

# =====================================================================================
# 6. Hierarchy measures
# =====================================================================================
group_stats <- function(gid, rank, p, c_same) {
  dt <- data.table(g = gid, r = as.integer(rank))[!is.na(g) & !is.na(r)]
  if (!nrow(dt)) return(data.table(g = character(0), n_g = integer(0), steepness = numeric(0), sameness = numeric(0),
                                   ratio_sameness = numeric(0), absdev_sameness = numeric(0), n_distinct_ranks = numeric(0),
                                   sum_ranks = numeric(0), admin_intensity = numeric(0)))
  setorder(dt, g, r)
  dt[, {
    n <- .N; i <- seq_len(n); sr <- sum(r)
    fr <- tabulate(r, 9) / n
    list(n_g = n,
         steepness = 1 + 1 / n - 2 * sum((n + 1 - i) * r) / (n * sr),
         sameness = 1 - sum((fr - p)^2) / c_same,
         ratio_sameness = 1 - sum((fr / p - 1)^2) / 10000,
         absdev_sameness = 1 - sum(abs(fr - p)) / (2 * (1 - p[9])),
         n_distinct_ranks = as.numeric(length(unique(r))),
         sum_ranks = as.numeric(sr),
         admin_intensity = 100 * mean(r >= 2))
  }, by = g]
}
steepness_vec <- function(r) { r <- sort(r); n <- length(r); i <- seq_len(n); 1 + 1 / n - 2 * sum((n + 1 - i) * r) / (n * sum(r)) }
sameness_vec <- function(r, p, c_same) { fr <- tabulate(r, 9) / length(r); 1 - sum((fr - p)^2) / c_same }

# model frame for one group type: base-sample rows with generic variable names; mset selects the member set
model_frame <- function(S, gtype, friends_def, mset = "all") {
  pow <- S$pow
  base <- if (gtype == "cap") pow[in_R_cap == TRUE] else pow[in_R_camp == TRUE]
  gid <- if (gtype == "cap") base$cohort else base$camp
  gs <- S$gstats[[mset]][[gtype]]
  idx <- match(gid, gs$g)
  for (v in c("n_g", "steepness", "sameness", "ratio_sameness", "absdev_sameness", "n_distinct_ranks", "sum_ranks", "admin_intensity"))
    set(base, j = v, value = gs[[v]][idx])
  base[, men := log(n_g) / 10]
  base[, men_sq := men^2]
  base[, gid := gid]
  # friends and unit-level hierarchy (R_friends family)
  mb <- S$members[[mset]][[gtype]]
  mbu <- mb[!is.na(unit)]
  cnt <- mbu[, .(cnt = .N), by = .(g, unit)]
  ukey <- paste(base$gid, base$unit, sep = "#")
  ci <- match(ukey, paste(cnt$g, cnt$unit, sep = "#"))
  n_same <- ifelse(is.na(ci), 0, cnt$cnt[ci])     # group members with the row's unit (the row included if it is a member)
  is_member <- base$record_seq %in% mb$record_seq
  # "incl_self": the count of members with the same unit; a non-member row (missing rank) is not counted,
  # and a row with no such member has friends missing (ln 0). "others": members other than the row; zero -> missing.
  if (friends_def == "incl_self") nf <- n_same
  else if (friends_def == "others") nf <- n_same - ifelse(is_member, 1, 0)
  else stop("unknown friends_def")
  nf[nf <= 0] <- NA
  nf[is.na(base$unit)] <- NA
  base[, friends := log(nf)]
  ugs <- group_stats(paste(mbu$g, mbu$unit, sep = "#"), mbu$rank, S$p, S$c_same)
  ui <- match(ukey, ugs$g)
  base[, steepness_unit := ugs$steepness[ui]]
  base[, sameness_unit := ugs$sameness[ui]]
  base[is.na(unit), `:=`(steepness_unit = NA_real_, sameness_unit = NA_real_)]
  base
}

# =====================================================================================
# 7. Model definitions
# =====================================================================================
BINARY_VARS <- c("japan", "dependents", "officer")
model_defs <- function(families, P) {
  defs <- list()
  add <- function(id, family, gtype, vars, inter = list(), filter = NULL, hier = NULL, members = "all") {
    defs[[id]] <<- list(model_id = id, family = family, gtype = gtype, vars = vars, inter = inter,
                        filter = filter, fe = (gtype == "cap"), hier = hier, members = members)
  }
  full_vars <- function(gtype, hier, omit_japan = FALSE, nosq = FALSE) {
    v <- if (gtype == "cap") c(hier, "men", "men_sq", "length", "height", "age", "education", "dependents", "officer")
         else c(hier, "japan", "men", "men_sq", "distance", "length", "height", "age", "education", "dependents", "officer")
    if (omit_japan) v <- setdiff(v, "japan")
    if (nosq) v <- setdiff(v, "men_sq")
    v
  }
  simple_vars <- function(gtype, hier, omit_japan = FALSE) if (gtype == "cap") hier else { v <- c(hier, "japan"); if (omit_japan) setdiff(v, "japan") else v }
  vars_for <- function(gtype, size, hier, omit_japan = FALSE, nosq = FALSE)
    if (size == "full") full_vars(gtype, hier, omit_japan, nosq) else simple_vars(gtype, hier, omit_japan)
  H <- c("steepness", "sameness"); GT <- c("cap", "camp"); SZ <- c("simple", "full")
  cc_filter <- function(gtype) {
    force(gtype)   # bind the group type now; otherwise the promise would read the loop variable later
    function(mf) {
      ok <- !is.na(mf$height) & !is.na(mf$age) & !is.na(mf$education) & !is.na(mf$dependents) & !is.na(mf$officer)
      if (gtype == "camp") ok <- ok & !is.na(mf$distance)
      ok
    }
  }
  for (fam in families) {
    if (fam == "T4") for (h in H) for (g in GT) for (s in SZ)
      add(sprintf("T4_%s_%s_%s", h, g, s), "T4", g, vars_for(g, s, h), hier = h)
    if (fam == "T5") for (g in GT) for (s in SZ)
      add(sprintf("T5_%s_%s", g, s), "T5", g, vars_for(g, s, H), hier = H)
    if (fam == "T6") for (h in H) for (g in GT) for (s in SZ)
      add(sprintf("T6_%s_%s_%s", h, g, s), "T6", g, unique(c(vars_for(g, s, h), "officer")), inter = list(c("officer", h)), hier = h)
    if (fam == "R_cc") for (h in H) for (g in GT)
      add(sprintf("Rcc_%s_%s_full", h, g), "R_cc", g, full_vars(g, h), filter = cc_filter(g), hier = h)
    if (fam == "R_n50") for (h in H) for (g in GT) for (s in SZ)
      add(sprintf("Rn50_%s_%s_%s", h, g, s), "R_n50", g, vars_for(g, s, h), filter = function(mf) !is.na(mf$n_g) & mf$n_g >= 50, hier = h)
    if (fam == "R_n100") for (h in H) for (g in GT) for (s in SZ)
      add(sprintf("Rn100_%s_%s_%s", h, g, s), "R_n100", g, vars_for(g, s, h), filter = function(mf) !is.na(mf$n_g) & mf$n_g >= 100, hier = h)
    if (fam == "R_noexec") for (h in H) for (g in GT) for (s in SZ)
      add(sprintf("Rnoexec_%s_%s_%s", h, g, s), "R_noexec", g, vars_for(g, s, h), filter = function(mf) mf$executed != 1, hier = h)
    if (fam == "R_ger") for (h in H) for (g in GT) for (s in SZ)
      add(sprintf("Rger_%s_%s_%s", h, g, s), "R_ger", g, vars_for(g, s, h, omit_japan = TRUE), filter = function(mf) mf$DET_POWER == "1", hier = h)
    if (fam == "R_jap") for (h in H) for (g in GT) for (s in SZ)
      add(sprintf("Rjap_%s_%s_%s", h, g, s), "R_jap", g, vars_for(g, s, h, omit_japan = TRUE), filter = function(mf) mf$DET_POWER == "2", hier = h)
    if (fam == "R_aaf") for (h in H) for (g in GT) for (s in SZ)
      add(sprintf("Raaf_%s_%s_%s", h, g, s), "R_aaf", g, vars_for(g, s, h, omit_japan = TRUE), filter = function(mf) mf$aaf, hier = h, members = "aaf")
    if (fam == "R_nosq") for (h in H) for (g in GT)
      add(sprintf("Rnosq_%s_%s_full", h, g), "R_nosq", g, full_vars(g, h, nosq = TRUE), hier = h)
    if (fam == "R_alt") {
      for (g in GT) for (s in SZ) {
        add(sprintf("Ralt_ratio_%s_%s", g, s), "R_alt", g, vars_for(g, s, "ratio_sameness"), hier = "ratio_sameness")
        add(sprintf("Ralt_absdev_%s_%s", g, s), "R_alt", g, vars_for(g, s, "absdev_sameness"), hier = "absdev_sameness")
      }
      for (g in GT) for (alt in c("n_distinct_ranks", "sum_ranks", "admin_intensity"))
        add(sprintf("Ralt_%s_%s_full", alt, g), "R_alt", g, full_vars(g, alt), hier = alt)
    }
    if (fam == "R_friends") {
      for (g in GT) add(sprintf("Rfriends_only_%s_full", g), "R_friends", g, full_vars(g, "friends"), hier = "friends")
      for (h in H) for (g in GT) add(sprintf("Rfriends_%s_%s_full", h, g), "R_friends", g, full_vars(g, c(h, "friends")), hier = h)
      for (h in H) for (g in GT) add(sprintf("Rfriends_unit_%s_%s_full", h, g), "R_friends", g, full_vars(g, c(paste0(h, "_unit"), "friends")), hier = paste0(h, "_unit"))
    }
    if (fam == "R_int") for (h in H) for (g in GT)
      add(sprintf("Rint_%s_%s_full", h, g), "R_int", g, full_vars(g, h), inter = list(c(h, "men")), hier = h)
  }
  defs
}

# =====================================================================================
# 8. Estimation machinery
# =====================================================================================
# Design: missing -> 0 plus indicator (omitted if constant); constants dropped. An interaction product is
# missing when either component is missing: it is set to 0 and gets its own indicator (manifest line 52).
build_design <- function(mf, vars, inter = list()) {
  cols <- list(); binary <- character(0); miss_cols <- list(); miss_v <- list()
  for (v in vars) {
    if (is.null(mf[[v]])) stop("variable not found: ", v)
    x <- as.numeric(mf[[v]])
    x[!is.finite(x)] <- NA          # NaN/Inf (e.g. ratio sameness with a zero reference share) are missing
    m <- is.na(x)
    if (any(m)) { x[m] <- 0; miss_cols[[paste0(v, "_miss")]] <- as.numeric(m) }
    cols[[v]] <- x; miss_v[[v]] <- m
    if (v %in% BINARY_VARS) binary <- c(binary, v)
  }
  for (ia in inter) {
    nm <- paste(ia, collapse = "_x_")
    cols[[nm]] <- cols[[ia[1]]] * cols[[ia[2]]]      # components are already 0 where missing
    pm <- miss_v[[ia[1]]] | miss_v[[ia[2]]]
    if (any(pm)) miss_cols[[paste0(nm, "_miss")]] <- as.numeric(pm)
  }
  for (nm in names(miss_cols)) { cols[[nm]] <- miss_cols[[nm]]; binary <- c(binary, nm) }
  X <- do.call(cbind, cols)
  colnames(X) <- names(cols)
  const <- apply(X, 2, function(z) all(z == z[1]))
  dropped <- colnames(X)[const]
  X <- X[, !const, drop = FALSE]
  X <- cbind("(Intercept)" = 1, X)
  list(X = X, binary = intersect(binary, colnames(X)), dropped = dropped)
}

probit_ll <- function(y, xb) sum(ifelse(y == 1, pnorm(xb, log.p = TRUE), pnorm(xb, lower.tail = FALSE, log.p = TRUE)))
probit_lambda <- function(y, xb) {
  l1 <- exp(dnorm(xb, log = TRUE) - pnorm(xb, log.p = TRUE))
  l0 <- -exp(dnorm(xb, log = TRUE) - pnorm(xb, lower.tail = FALSE, log.p = TRUE))
  ifelse(y == 1, l1, l0)
}
# X'v and X'WX for the design [Xd, FE dummies for levels 2..G]
.xt_v <- function(Xd, v, fe, G) {
  out <- as.vector(crossprod(Xd, v))
  if (G > 1) out <- c(out, rowsum(v, fe)[-1, 1])
  out
}
.xt_w_x <- function(Xd, w, fe, G) {
  A <- crossprod(Xd * w, Xd)
  if (G <= 1) return(A)
  K <- ncol(Xd); P <- K + G - 1
  B <- rowsum(Xd * w, fe)[-1, , drop = FALSE]          # (G-1) x K
  d <- rowsum(w, fe)[-1, 1]
  M <- matrix(0, P, P)
  M[1:K, 1:K] <- A
  M[(K + 1):P, 1:K] <- B
  M[1:K, (K + 1):P] <- t(B)
  M[cbind((K + 1):P, (K + 1):P)] <- d
  M
}
.xb <- function(Xd, b, fe, G) {
  K <- ncol(Xd)
  v <- as.vector(Xd %*% b[1:K])
  if (G > 1) v <- v + c(0, b[(K + 1):(K + G - 1)])[fe]
  v
}
# Newton-Raphson probit with analytic gradient and observed Hessian. fe: integer codes 1..G (level 1 omitted) or NULL.
probit_newton <- function(y, Xd, fe = NULL, maxit = 200L, tol = 1e-10) {
  G <- if (is.null(fe)) 0L else max(fe)
  K <- ncol(Xd); P <- K + max(G - 1L, 0L)
  b <- numeric(P)
  if (colnames(Xd)[1] == "(Intercept)") b[1] <- qnorm(min(max(mean(y), 1e-6), 1 - 1e-6))
  xb <- .xb(Xd, b, fe, G); ll <- probit_ll(y, xb)
  converged <- FALSE; iter <- 0L; msg <- ""
  for (iter in seq_len(maxit)) {
    lam <- probit_lambda(y, xb)
    w <- lam * (lam + xb)
    g <- .xt_v(Xd, lam, fe, G)
    H <- .xt_w_x(Xd, w, fe, G)
    step <- tryCatch(solve(H, g), error = function(e) NULL)
    if (is.null(step)) { msg <- "singular Hessian"; break }
    decr <- sum(g * step)
    if (decr < tol * (1 + abs(ll))) { converged <- TRUE; break }
    t <- 1; ok <- FALSE
    for (h in 1:40) {
      b_new <- b + t * step
      xb_new <- .xb(Xd, b_new, fe, G); ll_new <- probit_ll(y, xb_new)
      if (is.finite(ll_new) && ll_new >= ll - 1e-10 * (1 + abs(ll))) { ok <- TRUE; break }
      t <- t / 2
    }
    if (!ok) { msg <- "line search failed"; break }
    if (abs(ll_new - ll) < 1e-12 * (1 + abs(ll)) && t == 1) { b <- b_new; xb <- xb_new; ll <- ll_new; converged <- TRUE; break }
    b <- b_new; xb <- xb_new; ll <- ll_new
  }
  lam <- probit_lambda(y, xb); w <- lam * (lam + xb)
  H <- .xt_w_x(Xd, w, fe, G)
  Hinv <- tryCatch(solve(H), error = function(e) NULL)
  if (is.null(Hinv)) { converged <- FALSE; msg <- paste(msg, "singular Hessian at solution") }
  nm <- colnames(Xd); if (G > 1) nm <- c(nm, paste0("camp_", attr(fe, "levels")[-1]))
  names(b) <- nm
  list(coef = b, ll = ll, converged = converged, iter = iter, message = msg, xb = xb, lambda = lam, w = w,
       Hinv = Hinv, Xd = Xd, fe = fe, G = G, K = K, P = P, y = y, n = length(y))
}
# cluster-robust sandwich with G/(G-1); observed-information bread
vcov_cluster <- function(fit, cluster) {
  clf <- as.integer(factor(cluster)); Gc <- max(clf)
  S <- rowsum(fit$Xd * fit$lambda, clf)
  if (fit$G > 1) {
    dt <- data.table(cl = clf, fe = fit$fe, l = fit$lambda)[fe > 1, .(s = sum(l)), by = .(cl, fe)]
    Sfe <- matrix(0, Gc, fit$G - 1)
    Sfe[cbind(dt$cl, dt$fe - 1L)] <- dt$s
    S <- cbind(S, Sfe)
  }
  meat <- crossprod(S)
  V <- fit$Hinv %*% meat %*% fit$Hinv * Gc / (Gc - 1)
  list(V = V, n_clusters = Gc)
}
# marginal effects at means with delta-method gradient
marginal_effects <- function(b, xbar, binary) {
  P <- length(b); z <- sum(xbar * b); phi <- dnorm(z)
  me <- rep(NA_real_, P); J <- matrix(0, P, P)
  for (k in seq_len(P)) {
    if (names(b)[k] == "(Intercept)") next
    if (names(b)[k] %in% binary) {
      x1 <- xbar; x1[k] <- 1; x0 <- xbar; x0[k] <- 0
      z1 <- sum(x1 * b); z0 <- sum(x0 * b)
      me[k] <- pnorm(z1) - pnorm(z0)
      J[k, ] <- dnorm(z1) * x1 - dnorm(z0) * x0
    } else {
      me[k] <- phi * b[k]
      J[k, ] <- -phi * z * b[k] * xbar
      J[k, k] <- J[k, k] + phi
    }
  }
  list(me = me, J = J)
}
me_se_p <- function(J, V) {
  se <- sqrt(pmax(rowSums((J %*% V) * J), 0))
  se[rowSums(J != 0) == 0] <- NA
  se
}
# full-design column means (dense + FE shares)
design_means <- function(fit) {
  xbar <- colMeans(fit$Xd)
  if (fit$G > 1) xbar <- c(xbar, tabulate(fit$fe, fit$G)[-1] / fit$n)
  xbar
}
# DeLong, DeLong and Clarke-Pearson (1988) test for two correlated AUCs
delong_test <- function(p1, p2, y) {
  pos <- y == 1; neg <- !pos; m <- sum(pos); n <- sum(neg)
  placements <- function(p) {
    sp <- p[pos]; sn <- p[neg]
    sns <- sort(sn); sps <- sort(sp)
    le <- findInterval(sp, sns); lt <- findInterval(sp, sns, left.open = TRUE)
    V10 <- (lt + 0.5 * (le - lt)) / n
    le_p <- findInterval(sn, sps); lt_p <- findInterval(sn, sps, left.open = TRUE)
    V01 <- ((m - le_p) + 0.5 * (le_p - lt_p)) / m
    list(V10 = V10, V01 = V01, auc = mean(V10))
  }
  a <- placements(p1); b <- placements(p2)
  S10 <- cov(cbind(a$V10, b$V10)); S01 <- cov(cbind(a$V01, b$V01))
  S <- S10 / m + S01 / n
  v <- S[1, 1] + S[2, 2] - 2 * S[1, 2]
  diff <- a$auc - b$auc
  z <- if (diff == 0) 0 else diff / sqrt(v)
  list(auc1 = a$auc, auc2 = b$auc, diff = diff, var = v, z = z, p = 2 * pnorm(-abs(z)))
}

# Fit one model on a prepared estimation frame; returns everything needed for reporting.
fit_model <- function(mf, m) {
  y <- mf$survival
  D <- build_design(mf, m$vars, m$inter)
  fe <- NULL; levels <- NULL
  if (m$fe) {
    f <- factor(mf$camp); levels <- levels(f); fe <- as.integer(f); attr(fe, "levels") <- levels
  }
  Xd <- D$X
  # exact-collinearity check on the correlation-scaled cross-product matrix (pivoted Cholesky):
  # drop dependent dense columns / merge dependent dummies into the reference level
  dropped_rank <- character(0)
  repeat {
    G <- if (is.null(fe)) 0L else length(attr(fe, "levels"))
    M0 <- .xt_w_x(Xd, rep(1, nrow(Xd)), fe, G)
    P0 <- ncol(M0)
    # correlation scaling; earlier columns get a marginally larger scale so that, among exactly
    # duplicated columns, the pivoting keeps the earliest one (e.g. the hierarchy's missing indicator)
    s <- (1 + 1e-3 * (P0 - seq_len(P0)) / P0) / sqrt(diag(M0))
    Ms <- M0 * tcrossprod(s)
    ch <- suppressWarnings(chol(Ms, pivot = TRUE, tol = 1e-9))
    rk <- attr(ch, "rank")
    if (rk == ncol(M0)) break
    bad <- sort(attr(ch, "pivot")[(rk + 1):ncol(M0)])
    K <- ncol(Xd)
    bad_dense <- bad[bad <= K]; bad_fe <- bad[bad > K] - K + 1   # fe level index (2..G)
    if (length(bad_dense)) { dropped_rank <- c(dropped_rank, colnames(Xd)[bad_dense]); Xd <- Xd[, -bad_dense, drop = FALSE] }
    if (length(bad_fe)) {
      lv <- attr(fe, "levels")
      dropped_rank <- c(dropped_rank, paste0("camp_", lv[bad_fe]))
      newf <- as.integer(fe); newf[newf %in% bad_fe] <- 1L
      f2 <- factor(lv[newf], levels = lv[-bad_fe]); fe <- as.integer(f2); attr(fe, "levels") <- levels(f2)
    }
  }
  fit <- probit_newton(y, Xd, fe)
  if (is.null(fit$Hinv)) stop("singular Hessian at solution")
  # binary regressors: japan, dependents, officer, missing indicators and the camp dummies (discrete-change ME)
  fit$binary <- c(D$binary, if (fit$P > fit$K) names(fit$coef)[(fit$K + 1):fit$P])
  fit$dropped_const <- D$dropped
  fit$dropped_rank <- dropped_rank
  fit$record_seq <- mf$record_seq
  fit$p_hat <- pnorm(fit$xb)
  # null log likelihood
  pb <- mean(y); fit$ll0 <- sum(y) * log(pb) + sum(1 - y) * log(1 - pb)
  # clustering
  cl_main <- if (m$fe) mf$cohort else mf$camp
  vc <- vcov_cluster(fit, cl_main)
  fit$V <- vc$V; fit$n_clusters <- vc$n_clusters
  xbar <- design_means(fit)
  me <- marginal_effects(fit$coef, xbar, fit$binary)
  fit$me <- me$me
  fit$me_se <- me_se_p(me$J, fit$V)
  fit$coef_se <- sqrt(pmax(diag(fit$V), 0))
  if (m$fe) {
    vc2 <- vcov_cluster(fit, mf$camp)
    fit$me_se_camp <- me_se_p(me$J, vc2$V)
  } else fit$me_se_camp <- rep(NA_real_, fit$P)
  fit
}

# =====================================================================================
# 9. Running models and writing outputs
# =====================================================================================
result_rows <- function(spec_id, m, fit, n, dropped_rows, dropped_camps, status = "ok", error = "") {
  if (is.null(fit)) {
    return(data.table(spec_id = spec_id, model_id = m$model_id, family = m$family, term = NA_character_, coef = NA_real_,
                      coef_se = NA_real_, me = NA_real_, me_se = NA_real_, me_p = NA_real_, me_se_campcluster = NA_real_,
                      me_p_campcluster = NA_real_, n = n, n_clusters = NA_integer_, dropped_rows_pp = dropped_rows,
                      dropped_camps_pp = dropped_camps, ll = NA_real_, ll0 = NA_real_, pseudo_r2 = NA_real_,
                      converged = NA, status = status, error = error))
  }
  p_main <- 2 * pnorm(-abs(fit$me / fit$me_se))
  p_camp <- 2 * pnorm(-abs(fit$me / fit$me_se_camp))
  rows <- data.table(spec_id = spec_id, model_id = m$model_id, family = m$family, term = names(fit$coef), coef = fit$coef,
                     coef_se = fit$coef_se, me = fit$me, me_se = fit$me_se, me_p = p_main, me_se_campcluster = fit$me_se_camp,
                     me_p_campcluster = p_camp, n = fit$n, n_clusters = fit$n_clusters, dropped_rows_pp = dropped_rows,
                     dropped_camps_pp = dropped_camps, ll = fit$ll, ll0 = fit$ll0, pseudo_r2 = 1 - fit$ll / fit$ll0,
                     converged = fit$converged, status = status, error = error)
  # required terms that had to be omitted because they are exactly collinear with earlier columns
  # (duplicate missing indicators, a camp dummy collinear with the dense columns) are reported with NA estimates
  if (length(fit$dropped_rank)) {
    omit <- rows[rep(1L, length(fit$dropped_rank))]
    omit[, term := fit$dropped_rank]
    omit[, c("coef", "coef_se", "me", "me_se", "me_p", "me_se_campcluster", "me_p_campcluster") := NA_real_]
    rows <- rbind(rows, omit)
  }
  rows
}

# estimation sample for a model: filter, then (cap models) drop camps with constant survival
estimation_frame <- function(mf_all, m) {
  mf <- if (is.null(m$filter)) mf_all else mf_all[which(m$filter(mf_all))]
  dropped_rows <- 0L; dropped_camps <- 0L
  if (m$fe && nrow(mf)) {
    cs <- mf[, .(const = all(survival == survival[1])), by = camp]
    bad <- cs[const == TRUE, camp]
    dropped_rows <- sum(mf$camp %in% bad); dropped_camps <- length(bad)
    mf <- mf[!camp %in% bad]
  }
  list(mf = mf, dropped_rows = dropped_rows, dropped_camps = dropped_camps)
}

write_outputs <- function(out, results, roc, infl) {
  if (length(results)) fwrite(rbindlist(results), file.path(out, "results.csv"))
  if (length(roc)) fwrite(rbindlist(roc), file.path(out, "roc.csv"))
  if (length(infl)) fwrite(rbindlist(infl), file.path(out, "influence.csv"))
}

run_spec <- function(spec, inputs, opts, state) {
  spec_id <- spec$spec_id; P <- spec$params
  logf("=== Spec ", spec_id, " (", spec$role, ") deviation: ", if (is.null(spec$deviation)) "none" else toJSON(spec$deviation, auto_unbox = TRUE))
  t0 <- Sys.time()
  S <- build_spec_data(inputs, P)
  pow <- S$pow
  logf(sprintf("Samples: D0=%d, D=%d, R_cap=%d, R_camp=%d; ranks non-missing in D0: %d; linked enlistment rows in R_cap: %d",
               nrow(pow), sum(pow$in_D), sum(pow$in_R_cap), sum(pow$in_R_camp), sum(!is.na(pow$rank)), sum(pow$in_R_cap & pow$linked)))
  logf("Reference fractions p_r: ", paste(sprintf("%.4f", S$p), collapse = " "), "; sameness constant c = ", sprintf("%.4f", S$c_same))
  logf(sprintf("Groups: captured cohorts with members = %d, camps with members = %d", nrow(S$gstats$all$cap), nrow(S$gstats$all$camp)))
  mfs <- list(all = list(cap = model_frame(S, "cap", P$friends_def), camp = model_frame(S, "camp", P$friends_def)),
              aaf = list(cap = model_frame(S, "cap", P$friends_def, "aaf"), camp = model_frame(S, "camp", P$friends_def, "aaf")))
  for (g in c("cap", "camp")) {
    mf <- mfs$all[[g]]
    vars <- c("survival", "steepness", "sameness", "men", "length", "distance", "height", "age", "education", "dependents", "officer", "friends", "steepness_unit")
    miss <- vapply(vars, function(v) mean(is.na(mf[[v]])), 1)
    logf(sprintf("Model frame %s: rows=%d; share missing: %s", g, nrow(mf), paste(sprintf("%s=%.3f", vars, miss), collapse = ", ")))
    logf(sprintf("Model frame %s: survival mean=%.4f, camps=%d, cohorts=%d", g, mean(mf$survival), uniqueN(mf$camp), uniqueN(mf$cohort)))
  }
  logf("Variable construction done in ", format(round(difftime(Sys.time(), t0, units = "secs"), 1)))
  if (opts$dry) return(invisible(NULL))

  fams <- unlist(spec$families)
  if (!is.null(opts$families)) fams <- fams[fams %in% strsplit(opts$families, ",")[[1]]]
  if (opts$influence == "none") fams <- setdiff(fams, "INFLUENCE")
  defs <- model_defs(fams, P)
  fits <- list(); est <- list()
  model_fams <- c("T4", "T5", "T6", "R_cc", "R_n50", "R_n100", "R_noexec", "R_ger", "R_jap", "R_aaf", "R_nosq", "R_alt", "R_friends", "R_int")
  # families run in the order listed in grid.json (T5ROC in its listed place, right after T5); INFLUENCE last
  for (fam in setdiff(fams, "INFLUENCE")) {
    if (fam == "T5ROC") { run_t5roc(spec_id, fits, state); write_outputs(opts$out, state$results, state$roc, state$infl); next }
    if (!fam %in% model_fams) { logf("unknown family ", fam, " skipped"); next }
    for (m in defs[vapply(defs, function(d) d$family == fam, TRUE)]) {
      t1 <- Sys.time()
      ef <- estimation_frame(mfs[[m$members]][[m$gtype]], m)
      mf <- ef$mf
      # the estimation rows are determined before fitting: write them and keep them for the influence loop
      # whether or not the fit succeeds
      writeLines(as.character(sort(mf$record_seq)), file.path(opts$out, "sample_ids", paste0(spec_id, "__", m$model_id, ".txt")))
      if (m$family == "T4") est[[m$model_id]] <- mf      # only T4 frames are needed (influence loop)
      res <- tryCatch({
        if (nrow(mf) < 2 || length(unique(mf$survival)) < 2) stop("estimation sample has no outcome variation")
        fit <- fit_model(mf, m)
        fits[[m$model_id]] <- list(record_seq = fit$record_seq, p_hat = fit$p_hat, y = fit$y)
        st <- if (fit$converged) "ok" else "not_converged"
        notes <- c(if (length(fit$dropped_const)) paste0("dropped constant: ", paste(fit$dropped_const, collapse = "|")),
                   if (length(fit$dropped_rank)) paste0("omitted exactly collinear (reported with NA): ", paste(fit$dropped_rank, collapse = "|")),
                   if (nzchar(fit$message)) fit$message)
        rows <- result_rows(spec_id, m, fit, fit$n, ef$dropped_rows, ef$dropped_camps, st, paste(notes, collapse = "; "))
        logf(sprintf("%s %s: n=%d clusters=%d ll=%.2f iter=%d conv=%s dropped(pp)=%d rows/%d camps [%s] %s",
                     spec_id, m$model_id, fit$n, fit$n_clusters, fit$ll, fit$iter, fit$converged, ef$dropped_rows, ef$dropped_camps,
                     format(round(difftime(Sys.time(), t1, units = "secs"), 2)), paste(notes, collapse = "; ")))
        rows
      }, error = function(e) {
        logf(sprintf("%s %s: FAILED: %s", spec_id, m$model_id, conditionMessage(e)))
        result_rows(spec_id, m, NULL, nrow(mf), ef$dropped_rows, ef$dropped_camps, "failed", conditionMessage(e))
      })
      state$results[[length(state$results) + 1]] <- res
    }
    write_outputs(opts$out, state$results, state$roc, state$infl)
  }
  # ---- INFLUENCE (leave-one-camp-out on T4 models) ----
  if ("INFLUENCE" %in% fams) {
    t4_ids <- names(defs)[vapply(defs, function(d) d$family == "T4", TRUE)]
    for (mid in t4_ids) {
      m <- defs[[mid]]; mf <- est[[mid]]    # the estimation frame, kept even when the base fit failed
      camps <- if (is.null(mf)) character(0) else sort(unique(mf$camp))
      if (!length(camps)) {
        state$infl[[length(state$infl) + 1]] <- data.table(spec_id = spec_id, model_id = mid, deleted_camp = NA_character_, me = NA_real_,
                                                           me_p = NA_real_, n = if (is.null(mf)) NA_integer_ else nrow(mf), status = "failed",
                                                           error = "no camp in the estimation sample")
        next
      }
      if (opts$influence == "first20") camps <- head(camps, 20)
      t1 <- Sys.time()
      for (cp in camps) {
        sub <- mf[camp != cp]
        r <- tryCatch({
          if (nrow(sub) < 2 || length(unique(sub$survival)) < 2) stop("no outcome variation")
          fit <- fit_model(sub, m)
          k <- match(m$hier, names(fit$coef))
          if (is.na(k)) stop("hierarchy term dropped from design")
          data.table(spec_id = spec_id, model_id = mid, deleted_camp = cp, me = fit$me[k],
                     me_p = 2 * pnorm(-abs(fit$me[k] / fit$me_se[k])), n = fit$n,
                     status = if (fit$converged) "ok" else "not_converged", error = fit$message)
        }, error = function(e) data.table(spec_id = spec_id, model_id = mid, deleted_camp = cp, me = NA_real_, me_p = NA_real_,
                                          n = nrow(sub), status = "failed", error = conditionMessage(e)))
        state$infl[[length(state$infl) + 1]] <- r
      }
      logf(sprintf("%s INFLUENCE %s: %d camps refitted in %s", spec_id, mid, length(camps), format(round(difftime(Sys.time(), t1, units = "secs"), 1))))
      write_outputs(opts$out, state$results, state$roc, state$infl)
    }
  }
  invisible(NULL)
}

# T5ROC: DeLong comparisons of the T5 models with the T4 models of the same column (manifest line 84)
run_t5roc <- function(spec_id, fits, state) {
    for (g in c("cap", "camp")) for (s in c("simple", "full")) {
      t5 <- sprintf("T5_%s_%s", g, s)
      for (row in c("steepness", "sameness")) {
        t4 <- sprintf("T4_%s_%s_%s", if (row == "steepness") "sameness" else "steepness", g, s)  # T4 model omitting `row`
        r <- tryCatch({
          a <- fits[[t5]]; b <- fits[[t4]]
          if (is.null(a) || is.null(b)) stop("missing fit: ", if (is.null(a)) t5 else t4)
          if (!identical(a$record_seq, b$record_seq)) {
            ob <- match(a$record_seq, b$record_seq)
            if (any(is.na(ob)) || length(a$record_seq) != length(b$record_seq)) stop("estimation rows differ between ", t5, " and ", t4)
            b$p_hat <- b$p_hat[ob]
          }
          d <- delong_test(a$p_hat, b$p_hat, a$y)
          data.table(spec_id = spec_id, model_id = t5, family = "T5ROC", row = row, compare_model_id = t4, auc_t5 = d$auc1,
                     auc_t4 = d$auc2, diff = d$diff, z = d$z, p = d$p, n = length(a$y), status = "ok", error = "")
        }, error = function(e) data.table(spec_id = spec_id, model_id = t5, family = "T5ROC", row = row, compare_model_id = t4,
                                          auc_t5 = NA_real_, auc_t4 = NA_real_, diff = NA_real_, z = NA_real_, p = NA_real_,
                                          n = NA_integer_, status = "failed", error = conditionMessage(e)))
        state$roc[[length(state$roc) + 1]] <- r
        logf(sprintf("%s T5ROC %s row=%s vs %s: auc_t5=%s auc_t4=%s z=%s p=%s %s", spec_id, t5, row, t4,
                     format(r$auc_t5, digits = 5), format(r$auc_t4, digits = 5), format(r$z, digits = 4), format(r$p, digits = 4), r$status))
      }
    }
  invisible(NULL)
}

main <- function() {
  opts <- parse_args(commandArgs(trailingOnly = TRUE))
  dir.create(file.path(opts$out, "sample_ids"), recursive = TRUE, showWarnings = FALSE)
  .log_file <<- file.path(opts$out, "run_log.txt")
  logf("run.R start; args: ", paste(commandArgs(trailingOnly = TRUE), collapse = " "))
  logf(R.version.string, "; data.table ", packageVersion("data.table"), "; nanoparquet ", packageVersion("nanoparquet"))
  grid <- fromJSON(opts$grid, simplifyVector = FALSE)
  all_ids <- vapply(grid$specs, function(s) s$spec_id, "")
  want <- if (opts$specs == "all") all_ids else strsplit(opts$specs, ",")[[1]]
  missing_ids <- setdiff(want, all_ids)
  if (length(missing_ids)) stop("spec ids not in grid: ", paste(missing_ids, collapse = ","))
  specs <- grid$specs[all_ids %in% want]
  specs <- specs[order(vapply(specs, function(s) s$spec_id, ""))]
  inputs <- load_inputs(opts$data)
  state <- new.env()
  state$results <- list(); state$roc <- list(); state$infl <- list()
  for (spec in specs) {
    tryCatch(run_spec(spec, inputs, opts, state),
             error = function(e) logf("SPEC ", spec$spec_id, " ABORTED: ", conditionMessage(e)))
    write_outputs(opts$out, state$results, state$roc, state$infl)
  }
  write_outputs(opts$out, state$results, state$roc, state$infl)
  logf("run.R done")
}

if (sys.nframe() == 0L) main()
