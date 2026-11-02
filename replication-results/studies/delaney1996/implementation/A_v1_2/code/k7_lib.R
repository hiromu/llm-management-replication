# k7_lib.R -- functions for implementation specification PAPER_K7 v1, as amended by
# spec_amendment_v1_1.md (items A1-A10 are referenced in comments where they apply).
# Code version v1.2 (repair round: checker items 1-3 of checker_items.md).
# Sourced by run_grid.R and by the tests in code/tests/.
# Base R + stats only (jsonlite is used by run_grid.R for I/O).

HRM_TERMS <- c("STAFF", "TRAIN", "INCENT", "GRIEV", "DECENT", "ILM", "VHIER")
ORG_CONTROLS <- c("NONPROF", "SUBSID", "LOGEMP", "LOGAGE", "PCTMGR", "UNION",
                  "PRODUCT", "SERVICE", "COMPET")
MKT_CONTROLS <- setdiff(ORG_CONTROLS, "NONPROF")

AXES <- c("records", "market_sample", "market_requires_pop", "case_scope",
          "item_rule", "staff_coding", "z_reference", "train_log", "no_training",
          "decision_map", "union_items", "subsidiary", "age", "hierarchy",
          "employment", "pct_managers", "competition", "neither", "industry",
          "weights", "centering")

# ---------------------------------------------------------------------------
# Metadata / missing codes
# ---------------------------------------------------------------------------

#' Build a named list var -> list(values = numeric, ranges = list(c(lo, hi)))
parse_metadata <- function(meta) {
  vars <- meta$variables
  out <- list()
  for (v in vars) {
    vals <- unlist(v$declared_missing_values)
    vals <- if (length(vals)) suppressWarnings(as.numeric(vals)) else numeric(0)
    rngs <- lapply(v$declared_missing_ranges, function(r) {
      lo <- r$low; hi <- r$high
      lo <- if (is.character(lo) && toupper(lo) %in% c("LO", "LOWEST")) -Inf else as.numeric(lo)
      hi <- if (is.character(hi) && toupper(hi) %in% c("HI", "HIGHEST")) Inf else as.numeric(hi)
      c(lo, hi)
    })
    out[[v$name]] <- list(values = vals, ranges = rngs)
  }
  out
}

#' Apply declared missing codes of variable `name` to numeric vector x.
#' `keep` = codes that must NOT be treated as missing (level-specific rules).
#' `extra` = additional codes that are missing although not declared.
apply_missing <- function(x, name, mis, keep = numeric(0), extra = numeric(0)) {
  x <- suppressWarnings(as.numeric(x))
  m <- mis[[name]]
  codes <- c(if (!is.null(m)) m$values else numeric(0), extra)
  codes <- setdiff(codes, keep)
  if (length(codes)) x[x %in% codes] <- NA
  if (!is.null(m)) for (r in m$ranges) x[!is.na(x) & x >= r[1] & x <= r[2] & !(x %in% keep)] <- NA
  x
}

# ---------------------------------------------------------------------------
# Elementary coding helpers
# ---------------------------------------------------------------------------

#' Reverse a 1..k item: k+1-x. Values outside 1..k become missing.
reverse_item <- function(x, k) {
  x <- as.numeric(x)
  x[!is.na(x) & (x < 1 | x > k | x != round(x))] <- NA
  k + 1 - x
}

#' Natural log; values <= 0 give NA.
safe_log <- function(x) {
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))
  ok <- !is.na(x) & x > 0
  out[ok] <- log(x[ok])
  out
}

#' Index of items under item_rule (matrix rows = records).
#' L0 and L2: mean of valid items (>= 1 valid). L1: all items must be valid.
make_index <- function(items, item_rule) {
  items <- as.matrix(items)
  nvalid <- rowSums(!is.na(items))
  if (item_rule == "L1") {
    out <- rowMeans(items)
    out[nvalid < ncol(items)] <- NA
  } else {
    out <- rowMeans(items, na.rm = TRUE)
    out[nvalid == 0] <- NA
  }
  as.numeric(out)
}

#' Validity of an index given its items (A8): L0/L2 need at least one valid item,
#' L1 needs every item. Depends only on which items are valid.
index_valid <- function(items, item_rule) {
  items <- as.matrix(items)
  nvalid <- rowSums(!is.na(items))
  if (item_rule == "L1") nvalid == ncol(items) else nvalid >= 1
}

#' STAFF count validity under staff_coding (A7/A9). Input: the raw count after the
#' declared missing codes (with 995 kept only under L2). Returns the count with every
#' invalid value set to NA: codes 995-999 are never counts (995 is a value under L2 only);
#' L0/L2 need x >= 1 (0 is missing); L1 needs x >= 0.
staff_valid <- function(x, staff_coding) {
  x <- as.numeric(x)
  special <- !is.na(x) & x >= 995 & x <= 999
  if (staff_coding == "L0") {
    x[special | (!is.na(x) & x < 1)] <- NA
  } else if (staff_coding == "L1") {
    x[special | (!is.na(x) & x < 0)] <- NA
  } else if (staff_coding == "L2") {
    x[(special & x != 995) | (!is.na(x) & x < 1)] <- NA
  } else stop("unknown staff_coding ", staff_coding)
  x
}

#' Standard score over reference rows (logical), using rows with a valid value.
#' pop_sd: divide by n instead of n-1.
zscore <- function(x, ref = NULL, pop_sd = FALSE) {
  x <- as.numeric(x)
  if (is.null(ref)) ref <- rep(TRUE, length(x))
  v <- x[ref & !is.na(x)]
  n <- length(v)
  if (n < 2) return(rep(NA_real_, length(x)))
  m <- mean(v)
  s <- sqrt(sum((v - m)^2) / (if (pop_sd) n else n - 1))
  if (!is.finite(s) || s == 0) return(rep(NA_real_, length(x)))
  (x - m) / s
}

# ---------------------------------------------------------------------------
# Industry crosswalk
# ---------------------------------------------------------------------------

#' Returns list(first = named chr, nlisted = named int) keyed by integer code as character.
parse_crosswalk <- function(cw) {
  code <- as.character(as.integer(cw$census1980_code))
  field <- trimws(as.character(cw$sic2_from_printed))
  field[is.na(field)] <- ""
  parts <- lapply(field, function(f) {
    if (f == "") return(character(0))
    p <- trimws(unlist(strsplit(f, "[;,]")))
    p[p != ""]
  })
  first <- vapply(parts, function(p) if (length(p)) p[1] else NA_character_, "")
  nlisted <- vapply(parts, length, 1L)
  names(first) <- code; names(nlisted) <- code
  list(first = first, nlisted = nlisted)
}

#' Industry group per row. industry L0: first listed; empty/not found -> "UNCL".
#' L1: multiple listed, empty or not found -> NA. V43 missing -> NA.
#' `v43` must already have its declared missing codes applied (A4/A9: a missing V43
#' gives a missing group at every level; UNCL applies only to non-missing codes).
industry_group <- function(v43, cwp, level) {
  v43 <- suppressWarnings(as.numeric(v43))
  key <- ifelse(is.na(v43), NA_character_, as.character(as.integer(v43)))
  found <- !is.na(key) & key %in% names(cwp$first)
  first <- rep(NA_character_, length(v43)); nl <- rep(0L, length(v43))
  first[found] <- cwp$first[key[found]]
  nl[found] <- cwp$nlisted[key[found]]
  if (level == "L0") {
    out <- first
    out[!is.na(key) & (!found | is.na(first))] <- "UNCL"
  } else if (level == "L1") {
    out <- first
    out[!found | nl != 1] <- NA
  } else stop("unknown industry level ", level)
  out
}

# ---------------------------------------------------------------------------
# Variable construction
# ---------------------------------------------------------------------------

num <- function(d, v) suppressWarnings(as.numeric(d[[v]]))

#' Build all derived variables for one spec. Returns a data.frame (record frame).
#' STAFF/TRAIN items are returned transformed but NOT yet standardized
#' (columns staff_i1..3, train_i1..3); use add_z_indices().
build_frame <- function(d, s, mis, cwp, check = NULL) {
  g <- function(v, keep = numeric(0), extra = numeric(0)) apply_missing(d[[v]], v, mis, keep, extra)
  n <- nrow(d)
  f <- data.frame(V1 = num(d, "V1"))

  # --- record frame ---
  V3 <- num(d, "V3")
  keep_row <- if (s$records == "L1") !(!is.na(V3) & V3 == 0) else rep(TRUE, n)
  f$keep_row <- keep_row

  # --- outcomes ---
  pop_items <- matrix(sapply(paste0("V", 289:295), function(v) reverse_item(g(v), 4)), nrow = n)
  pmp_items <- matrix(sapply(paste0("V", 296:299), function(v) reverse_item(g(v), 4)), nrow = n)
  f$POP <- make_index(pop_items, s$item_rule)
  f$PMP <- make_index(pmp_items, s$item_rule)

  # --- raw items subject to the copy rule ---
  # A7: a source item is "valid" for copying only after every exclusion that applies to it at
  # the current axis level. So every level-specific exclusion is applied to the raw items
  # BEFORE the copy; the copy then moves values that are valid, and NA otherwise.
  # staff counts: 996/997/998/999 always missing; 995 missing except staff_coding L2 (A2: the
  # spec-level assignment of 995 under L2 takes precedence over the declared missing code).
  staff_keep <- if (s$staff_coding == "L2") 995 else numeric(0)
  V62  <- staff_valid(g("V62",  keep = staff_keep, extra = c(996, 997)), s$staff_coding)
  V97  <- staff_valid(g("V97",  keep = staff_keep, extra = c(996, 997)), s$staff_coding)
  V131 <- staff_valid(g("V131", keep = staff_keep, extra = c(996, 997)), s$staff_coding)
  # ILM items: valid only when in 1..2; INCENT items: valid only when in 1..3
  in_range <- function(x, k) { x[!is.na(x) & !(x %in% seq_len(k))] <- NA; x }
  V67 <- in_range(g("V67"), 2); V76 <- in_range(g("V76"), 2); V102 <- in_range(g("V102"), 2)
  V111 <- in_range(g("V111"), 2); V136 <- in_range(g("V136"), 2)
  V209 <- in_range(g("V209"), 3); V222 <- in_range(g("V222"), 3); V235 <- in_range(g("V235"), 3)

  if (s$item_rule == "L2") {
    V79_raw <- num(d, "V79")
    V114_raw <- num(d, "V114")
    # GSS = CORE: V79 == 2, or V79 system-missing while the CORE item is valid
    gss_same <- function(core) (!is.na(V79_raw) & V79_raw == 2) | (is.na(V79_raw) & !is.na(core))
    cp <- function(gss, core) { m <- gss_same(core); gss[m] <- core[m]; gss }
    V97  <- cp(V97,  V62)
    V102 <- cp(V102, V67)
    V111 <- cp(V111, V76)
    V235 <- cp(V235, V222)
    # manager same: V114 == 2 or V114 system-missing
    mgr_same <- (!is.na(V114_raw) & V114_raw == 2) | is.na(V114_raw)
    cpm <- function(mgr, core, gss) { m <- mgr_same; src <- ifelse(is.na(core), gss, core); mgr[m] <- src[m]; mgr }
    V131 <- cpm(V131, V62, V97)
    V136 <- cpm(V136, V67, V102)
    V209 <- cpm(V209, V222, V235)
  }

  # --- STAFF items (transformed, not standardized) ---
  # The items are already restricted to valid counts (staff_valid); L0/L2 use ln(x) (995 under
  # L2 is a kept value, so it gives ln 995), L1 uses ln(1+x).
  staff_tr <- function(x) if (s$staff_coding == "L1") log1p(x) else log(x)
  f$staff_i1 <- staff_tr(V62); f$staff_i2 <- staff_tr(V97); f$staff_i3 <- staff_tr(V131)

  # --- TRAIN items ---
  V145 <- g("V145")
  t145 <- ifelse(!is.na(V145) & V145 == 1, 2, ifelse(!is.na(V145) & V145 == 2, 1, NA))
  V157 <- g("V157", keep = 99996)   # A2: the top code assignment precedes any declared missing code
  V157[!is.na(V157) & V157 == 99996] <- 100000
  V172 <- g("V172", extra = 4)
  t172 <- reverse_item(V172, 3)
  no_tr <- !is.na(V145) & V145 == 2
  if (s$no_training == "L0") {
    V157[no_tr] <- NA; t172[no_tr] <- NA
  } else if (s$no_training == "L1") {
    V157[no_tr] <- 0; t172[no_tr] <- 1
  } else if (s$no_training == "L2") {
    V157[no_tr] <- 0; t172[no_tr] <- NA
  } else stop("unknown no_training ", s$no_training)
  log157 <- function(x) {
    if (s$no_training == "L0") safe_log(x) else { out <- rep(NA_real_, n); ok <- !is.na(x) & x >= 0; out[ok] <- log1p(x[ok]); out }
  }
  if (s$train_log == "L0") {
    f$train_i1 <- safe_log(t145); f$train_i2 <- log157(V157); f$train_i3 <- safe_log(t172)
  } else if (s$train_log == "L1") {
    f$train_i1 <- t145; f$train_i2 <- log157(V157); f$train_i3 <- t172
  } else if (s$train_log == "L2") {
    f$train_i1 <- t145; f$train_i2 <- V157; f$train_i3 <- t172
  } else stop("unknown train_log ", s$train_log)

  # A8: index validity is determined from item validity alone, never from standardized values
  f$STAFF_valid <- index_valid(cbind(f$staff_i1, f$staff_i2, f$staff_i3), s$item_rule)
  f$TRAIN_valid <- index_valid(cbind(f$train_i1, f$train_i2, f$train_i3), s$item_rule)

  # --- INCENT ---
  f$INCENT <- make_index(cbind(reverse_item(V209, 3), reverse_item(V222, 3), reverse_item(V235, 3)), s$item_rule)

  # --- GRIEV ---
  V270 <- g("V270")
  f$GRIEV <- ifelse(!is.na(V270) & V270 == 1, 1, ifelse(!is.na(V270) & V270 == 2, 0, NA))

  # --- DECENT ---
  V17 <- g("V17")   # A9: metadata declarations apply; A4: a missing V17 gives missing DECENT and SUBSID
  dmap <- if (s$decision_map == "L0") c("1" = 3, "2" = 5, "3" = 1, "4" = 4, "5" = 2) else
          if (s$decision_map == "L1") c("1" = 1, "2" = 5, "3" = 3, "4" = 4, "5" = 2) else stop("unknown decision_map")
  dec_items <- matrix(NA_real_, n, 8)
  for (j in 1:8) {
    a <- g(paste0("V", 270 + j)); b <- g(paste0("V", 278 + j))
    raw <- ifelse(!is.na(V17) & V17 == 1, a, ifelse(!is.na(V17) & V17 == 2, b, NA))
    raw[!is.na(raw) & !(raw %in% 1:5)] <- NA   # code 6 "depends" (and anything else) missing
    dec_items[, j] <- unname(dmap[as.character(raw)])
  }
  f$DECENT <- make_index(dec_items, s$item_rule)

  # --- ILM ---
  f$ILM <- make_index(cbind(reverse_item(V67, 2), reverse_item(V76, 2), reverse_item(V102, 2),
                            reverse_item(V111, 2), reverse_item(V136, 2)), s$item_rule)

  # --- VHIER ---
  V261 <- g("V261", keep = 96)   # A2: the "96 means 100 or more" assignment precedes declared missing codes
  if (s$hierarchy == "L0") { V261[!is.na(V261) & V261 == 96] <- 100; f$VHIER <- safe_log(V261) }
  else if (s$hierarchy == "L1") { V261[!is.na(V261) & V261 == 96] <- NA; f$VHIER <- safe_log(V261) }
  else if (s$hierarchy == "L2") { V261[!is.na(V261) & V261 == 96] <- 100; f$VHIER <- V261 }
  else stop("unknown hierarchy ", s$hierarchy)
  if (identical(check, "hierarchy_log10")) {
    # A3: log10 of the recoded count (96 taken as 100) = ln(count) / ln(10)
    V261c <- g("V261", keep = 96); V261c[!is.na(V261c) & V261c == 96] <- 100
    f$VHIER <- safe_log(V261c) / log(10)
  }

  # --- controls ---
  V8 <- g("V8"); V9 <- g("V9")   # A9: V8 follows its metadata declarations
  f$V8 <- V8; f$V9 <- V9
  f$NONPROF <- ifelse(!is.na(V8) & V8 == 2, 1, ifelse(!is.na(V8) & V8 == 1, 0, NA))

  V21 <- g("V21")
  if (s$subsidiary == "L0") {
    f$SUBSID <- ifelse(is.na(V17), NA, ifelse(V17 == 1, 1, 0))
  } else {
    sub <- ifelse(!is.na(V21), ifelse(V21 == 2, 1, 0), NA)
    if (s$subsidiary == "L2") sub <- ifelse(!is.na(V21), ifelse(V21 %in% c(1, 2, 3), 1, 0), NA)
    sub[!is.na(V17) & V17 == 2] <- 0   # A9: V17 == 2 gives 0 whatever V21 says
    sub[is.na(V17)] <- NA              # A4: SUBSID missing at every level when V17 is missing
    f$SUBSID <- sub
  }

  V23 <- g("V23"); V32 <- g("V32"); NEWTOTAL <- g("NEWTOTAL")
  f$LOGEMP <- switch(s$employment,
                     L0 = safe_log(V23 + V32),
                     L1 = safe_log(NEWTOTAL),
                     L2 = safe_log(V23),
                     stop("unknown employment"))

  V16 <- g("V16"); age <- 1991 - V16
  f$LOGAGE <- switch(s$age,
                     L0 = safe_log(age),
                     L1 = { o <- rep(NA_real_, n); ok <- !is.na(age) & age >= 0; o[ok] <- log1p(age[ok]); o },
                     L2 = age,
                     stop("unknown age"))

  V114 <- g("V114"); V115 <- g("V115")
  numer <- ifelse(!is.na(V114) & V114 == 1, V115, ifelse(!is.na(V114) & V114 == 3, 0, NA))
  if (s$pct_managers == "L1") numer[!is.na(V114) & V114 == 3] <- NA
  denom <- if (s$pct_managers == "L2") NEWTOTAL else V23 + V32
  denom[!is.na(denom) & denom == 0] <- NA
  f$PCTMGR <- 100 * numer / denom
  if (identical(check, "pct_proportion")) f$PCTMGR <- f$PCTMGR / 100

  V220 <- g("V220"); V233 <- g("V233"); V300 <- g("V300"); V166 <- g("V166")
  u_items <- cbind(reverse_item(V220, 3), reverse_item(V233, 3))
  if (s$union_items %in% c("L1", "L2")) u_items <- cbind(u_items, reverse_item(V300, 3))
  if (s$union_items == "L2") {
    # V166 yes gives 3, no gives 1: these are the final (already reversed-scale) values,
    # aligned with the other items where 3 = "very important" after reversal.
    v166 <- ifelse(!is.na(V166) & V166 == 1, 3, ifelse(!is.na(V166) & V166 == 2, 1, NA))
    u_items <- cbind(u_items, v166)
  }
  if (!s$union_items %in% c("L0", "L1", "L2")) stop("unknown union_items")
  f$UNION <- make_index(u_items, s$item_rule)

  V41 <- g("V41")
  f$PRODUCT <- ifelse(is.na(V41), NA, ifelse(V41 == 1, 1, ifelse(V41 %in% c(2, 3), 0, NA)))
  f$SERVICE <- ifelse(is.na(V41), NA, ifelse(V41 == 2, 1, ifelse(V41 %in% c(1, 3), 0, NA)))
  if (s$neither == "L1") {
    f$PRODUCT[!is.na(V41) & V41 == 4] <- 0; f$SERVICE[!is.na(V41) & V41 == 4] <- 0
  } else if (s$neither != "L0") stop("unknown neither")

  V328 <- g("V328")
  V328[!is.na(V328) & !(V328 %in% 1:4)] <- NA
  f$COMPET <- switch(s$competition,
                     L0 = V328,
                     L1 = ifelse(is.na(V328), NA, as.numeric(V328 == 4)),
                     L2 = ifelse(is.na(V328), NA, as.numeric(V328 >= 3)),
                     stop("unknown competition"))

  # --- industry (A4/A9: declared missing codes of V43 apply; a missing V43 is never UNCL) ---
  f$IND <- industry_group(g("V43"), cwp, s$industry)

  # --- weight ---
  W <- g("WEIGHT")
  W[!is.na(W) & W <= 0] <- NA
  f$WEIGHT <- W

  f[keep_row, , drop = FALSE]
}

#' Add standardized STAFF/TRAIN items and indices.
#' ref: logical vector over rows of f (reference sample) or NULL (all rows).
#' Rows outside ref keep L0 values (all-rows, sample SD).
add_z_indices <- function(f, item_rule, ref = NULL, pop_sd = FALSE) {
  for (idx in c("staff", "train")) {
    cols <- paste0(idx, "_i", 1:3)
    z <- sapply(cols, function(cn) {
      z0 <- zscore(f[[cn]], NULL, FALSE)
      if (is.null(ref)) return(zscore(f[[cn]], NULL, pop_sd))
      zr <- zscore(f[[cn]], ref, pop_sd)
      ifelse(ref, zr, z0)
    })
    z <- matrix(z, nrow = nrow(f))
    for (j in 1:3) f[[paste0(idx, "_z", j)]] <- z[, j]
    f[[toupper(idx)]] <- make_index(z, item_rule)
  }
  f
}

#' Common complete-case sample of a family (case_scope L0 definition).
family_filter <- function(f, family, s) {
  ok <- rep(TRUE, nrow(f))
  if (family == "mkt") {
    ok <- ok & !is.na(f$V8) & f$V8 == 1
    if (s$market_sample == "L1") ok <- ok & !is.na(f$V9) & f$V9 == 4
    if (s$market_requires_pop == "L1") ok <- ok & !is.na(f$POP)
  }
  if (s$weights == "L1") ok <- ok & !is.na(f$WEIGHT)
  ok
}

family_outcome <- function(family) if (family == "org") "POP" else "PMP"
family_controls <- function(family) if (family == "org") ORG_CONTROLS else MKT_CONTROLS

complete_rows <- function(f, vars) {
  ok <- rep(TRUE, nrow(f))
  for (v in vars) ok <- ok & !is.na(f[[v]])
  ok
}

#' Common complete-case sample of a family (case_scope L0 definition; also the z_reference
#' L1/L2 reference sample, A8). STAFF and TRAIN enter through their item-validity flags
#' (STAFF_valid, TRAIN_valid), so membership never depends on standardized values.
family_sample_L0 <- function(f, family, s) {
  family_filter(f, family, s) &
    complete_rows(f, c(family_outcome(family), setdiff(HRM_TERMS, c("STAFF", "TRAIN")),
                       family_controls(family), "IND")) &
    f$STAFF_valid & f$TRAIN_valid
}

# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

model_list <- function(family) {
  p <- if (family == "org") "org" else "mkt"
  m <- list()
  m[[paste0(p, "_base")]] <- list(hrm = character(0), int = character(0))
  single <- if (family == "org") "M1" else "M6"
  for (h in HRM_TERMS) m[[paste0(p, "_", single, "_", h)]] <- list(hrm = h, int = character(0))
  A <- c("STAFF", "TRAIN", "INCENT", "GRIEV", "DECENT", "ILM")
  B <- c("STAFF", "TRAIN", "INCENT", "GRIEV", "DECENT", "VHIER")
  ids <- if (family == "org") c("M2", "M3", "M4", "M5") else c("M7", "M8", "M9", "M10")
  m[[paste0(p, "_", ids[1])]] <- list(hrm = A, int = character(0))
  m[[paste0(p, "_", ids[2])]] <- list(hrm = B, int = character(0))
  m[[paste0(p, "_", ids[3])]] <- list(hrm = A, int = c("TRAIN_x_STAFF", "GRIEV_x_INCENT", "ILM_x_DECENT"))
  m[[paste0(p, "_", ids[4])]] <- list(hrm = B, int = c("TRAIN_x_STAFF", "GRIEV_x_INCENT", "VHIER_x_DECENT"))
  m
}

nested_pairs <- function(family) {
  if (family == "org") list(
    list(test_id = "org_HRM_A", full = "org_M2", restricted = "org_base"),
    list(test_id = "org_HRM_B", full = "org_M3", restricted = "org_base"),
    list(test_id = "org_INT_A", full = "org_M4", restricted = "org_M2"),
    list(test_id = "org_INT_B", full = "org_M5", restricted = "org_M3"))
  else list(
    list(test_id = "mkt_HRM_A", full = "mkt_M7", restricted = "mkt_base"),
    list(test_id = "mkt_HRM_B", full = "mkt_M8", restricted = "mkt_base"),
    list(test_id = "mkt_INT_A", full = "mkt_M9", restricted = "mkt_M7"),
    list(test_id = "mkt_INT_B", full = "mkt_M10", restricted = "mkt_M8"))
}

#' Choose industry dummy columns for a family given the group vector of the
#' family sample. Returns character vector of groups to enter (reference omitted).
#' alt = TRUE: omit the smallest group (ties: highest code) [CHK_industry_ref_alt].
industry_dummy_groups <- function(groups, alt = FALSE) {
  groups <- groups[!is.na(groups)]
  if (!length(groups)) return(character(0))
  tab <- table(groups)
  codes <- names(tab); cnt <- as.integer(tab)
  ord_codes <- order(codes)  # lexical: "01" < "99" < "UNCL"
  if (!alt) {
    cand <- which(cnt == max(cnt))
    ref <- codes[cand][order(codes[cand])][1]            # ties: lowest code
  } else {
    cand <- which(cnt == min(cnt))
    ref <- codes[cand][order(codes[cand], decreasing = TRUE)][1]  # ties: highest code
  }
  setdiff(codes[ord_codes], ref)
}

#' Build the design matrix for a model on rows `rows` of frame f.
#' dummy_groups: industry groups entering as IND_<group> dummies.
#' centering L1: interactions use components centered at the estimation-sample mean.
build_design <- function(f, rows, hrm, int, controls, dummy_groups, centering = "L0") {
  fr <- f[rows, , drop = FALSE]
  X <- matrix(1, nrow(fr), 1, dimnames = list(NULL, "(Intercept)"))
  for (h in hrm) { X <- cbind(X, fr[[h]]); colnames(X)[ncol(X)] <- h }
  for (term in int) {
    parts <- strsplit(term, "_x_")[[1]]
    a <- fr[[parts[1]]]; b <- fr[[parts[2]]]
    if (centering == "L1") { a <- a - mean(a); b <- b - mean(b) }
    X <- cbind(X, a * b); colnames(X)[ncol(X)] <- term
  }
  for (cn in controls) { X <- cbind(X, fr[[cn]]); colnames(X)[ncol(X)] <- cn }
  for (gname in dummy_groups) {
    X <- cbind(X, as.numeric(!is.na(fr$IND) & fr$IND == gname)); colnames(X)[ncol(X)] <- paste0("IND_", gname)
  }
  X
}

#' Leverage-one threshold (A1): rows with h_ii >= 1 - LEVERAGE_ONE_TOL contribute zero to HC3.
LEVERAGE_ONE_TOL <- 1e-8

#' OLS / WLS fit with conventional and HC3 inference.
#'
#' Column handling (A5): only industry dummies (IND_<group>) may be dropped, when all zero or
#' collinear in the estimation sample. Industry collinearity is resolved before the residual
#' degrees of freedom are checked. Any other all-zero or collinear term fails the model with
#' that reason. Dropped-column information is returned even when the fit later fails (A6).
#'
#' HC3 (A1): rows with h_ii >= 1 - 1e-8 (fitted exactly, residual 0) contribute exactly zero to
#' the HC3 meat; their number is returned as n_leverage_one. For WLS, h is from the weighted
#' design. The bread and every other statistic are unchanged.
fit_model <- function(X, y, w = NULL) {
  dropped <- character(0)
  res <- NULL
  is_ind <- function(nm) grepl("^IND_", nm)
  err <- tryCatch({
    if (is.null(w)) w <- rep(1, length(y))
    if (any(is.na(X)) || any(is.na(y)) || any(is.na(w))) stop("missing values in design, outcome or weights")
    n <- nrow(X)
    if (n == 0) stop("no positive residual df: empty estimation sample, n (0)")
    # all-zero columns: permitted drop for industry dummies, failure for anything else
    zero <- apply(X, 2, function(col) all(col == 0)) & colnames(X) != "(Intercept)"
    # permitted (industry) drops are recorded before any failure, so they survive it (A6)
    if (any(zero & is_ind(colnames(X)))) dropped <- c(dropped, paste0(colnames(X)[zero & is_ind(colnames(X))], " (all zero)"))
    if (any(zero & !is_ind(colnames(X))))
      stop(sprintf("term all zero in the estimation sample: %s", paste(colnames(X)[zero & !is_ind(colnames(X))], collapse = ", ")))
    if (any(zero)) X <- X[, !zero, drop = FALSE]
    # collinearity (A5): resolved BEFORE the residual-df check, with no early exit on n. The
    # pivoted QR of lm.wfit also works when n < number of columns (the trailing columns are
    # aliased); the dummies come last, so they are aliased in preference to earlier columns.
    p_before <- ncol(X)
    fit <- lm.wfit(X, y, w)
    aliased <- is.na(fit$coefficients)
    ind_aliased <- aliased & is_ind(colnames(X))
    oth_aliased <- aliased & !is_ind(colnames(X))
    # permitted drops are recorded first, so that they are kept even if the fit fails next (A6)
    if (any(ind_aliased)) dropped <- c(dropped, paste0(colnames(X)[ind_aliased], " (collinear)"))
    if (any(oth_aliased)) {
      ctx <- if (n <= p_before) sprintf(" [n (%d) is not larger than the number of columns (%d), so the design cannot have full rank]", n, p_before) else ""
      stop(sprintf("term collinear in the estimation sample: %s%s", paste(colnames(X)[oth_aliased], collapse = ", "), ctx))
    }
    if (any(aliased)) {
      X <- X[, !aliased, drop = FALSE]
      fit <- lm.wfit(X, y, w)
      if (any(is.na(fit$coefficients))) stop("rank deficiency persists after dropping aliased industry dummies")
    }
    k <- ncol(X)
    df <- n - k
    if (df <= 0) stop(sprintf("no positive residual df: n (%d) <= number of parameters (%d) after permitted drops", n, k))
    beta <- fit$coefficients
    e <- y - as.vector(X %*% beta)
    sw <- sqrt(w)
    Xw <- X * sw; ew <- e * sw
    XtX_inv <- chol2inv(chol(crossprod(Xw)))
    ssr <- sum(ew^2)
    sigma2 <- ssr / df
    V <- sigma2 * XtX_inv
    se <- sqrt(diag(V))
    h <- rowSums((Xw %*% XtX_inv) * Xw)
    lev1 <- h >= 1 - LEVERAGE_ONE_TOL
    hc3_w <- numeric(n)
    hc3_w[!lev1] <- ew[!lev1] / (1 - h[!lev1])
    meat <- crossprod(Xw * hc3_w)
    V3 <- XtX_inv %*% meat %*% XtX_inv
    se3 <- sqrt(diag(V3))
    t <- beta / se; t3 <- beta / se3
    ybar <- sum(w * y) / sum(w)
    sst <- sum(w * (y - ybar)^2)
    r2 <- 1 - ssr / sst
    adj <- 1 - (1 - r2) * (n - 1) / df
    f_df1 <- k - 1
    fstat <- if (f_df1 > 0) (r2 / f_df1) / ((1 - r2) / df) else NA_real_
    fp <- if (f_df1 > 0) pf(fstat, f_df1, df, lower.tail = FALSE) else NA_real_
    coefs <- data.frame(
      term = colnames(X), estimate = beta, se = se, t = t, df = df,
      p_two = 2 * pt(-abs(t), df), p_upper = pt(t, df, lower.tail = FALSE), p_lower = pt(t, df),
      se_hc3 = se3, t_hc3 = t3, p_two_hc3 = 2 * pt(-abs(t3), df),
      p_upper_hc3 = pt(t3, df, lower.tail = FALSE), p_lower_hc3 = pt(t3, df),
      stringsAsFactors = FALSE, row.names = NULL)
    res <- list(status = "ok", error = NA_character_, coefs = coefs,
                n = n, k = k, df = df, ssr = ssr, sst = sst, r2 = r2, adj_r2 = adj,
                f = fstat, f_df1 = f_df1, f_df2 = df, f_p = fp,
                n_ind = sum(is_ind(colnames(X))), n_leverage_one = sum(lev1), terms = colnames(X))
    NA_character_
  }, error = function(e) conditionMessage(e))
  if (is.null(res)) res <- list(status = "failed", error = err)
  res$dropped <- dropped
  res
}

#' Nested F test from two fits on identical rows (weighted SSR for WLS).
#' df1_required: the number of added terms (A5: 6 for an HRM block, 3 for an interaction
#' block). If the effective rank increase differs, the test is failed with the reason.
nested_f <- function(full, restricted, df1_required = NULL) {
  df1 <- full$k - restricted$k
  df2 <- full$df
  if (!is.null(df1_required) && df1 != df1_required)
    return(list(status = "failed",
                error = sprintf("effective rank increase (%d) differs from the number of added terms (%d)", df1, df1_required),
                delta_r2 = NA_real_, f = NA_real_, df1 = NA_real_, df2 = NA_real_, p = NA_real_))
  if (df1 <= 0)
    return(list(status = "failed", error = sprintf("effective rank increase (%d) is not positive", df1),
                delta_r2 = NA_real_, f = NA_real_, df1 = NA_real_, df2 = NA_real_, p = NA_real_))
  fstat <- ((restricted$ssr - full$ssr) / df1) / (full$ssr / df2)
  list(status = "ok", error = NA_character_, delta_r2 = full$r2 - restricted$r2, f = fstat, df1 = df1, df2 = df2,
       p = pf(fstat, df1, df2, lower.tail = FALSE))
}

# ---------------------------------------------------------------------------
# Running one specification
# ---------------------------------------------------------------------------

#' samples.csv rows (robust to an empty sample).
sample_rows <- function(spec_id, family, model_id, v1) {
  data.frame(spec_id = rep(spec_id, length(v1)), family = rep(family, length(v1)),
             model_id = rep(model_id, length(v1)), V1 = v1, stringsAsFactors = FALSE)
}

#' Rows valid on a given set of HRM terms (STAFF/TRAIN through their validity flags, A8).
hrm_complete <- function(f, hrm) {
  ok <- complete_rows(f, setdiff(hrm, c("STAFF", "TRAIN")))
  if ("STAFF" %in% hrm) ok <- ok & f$STAFF_valid
  if ("TRAIN" %in% hrm) ok <- ok & f$TRAIN_valid
  ok
}

#' One model_stats.csv row from a fit (ok or failed).
model_stats_row <- function(spec_id, family, mid, fit, n_rows) {
  ok <- fit$status == "ok"
  data.frame(
    spec_id = spec_id, family = family, model_id = mid, status = fit$status, error = fit$error,
    n = if (ok) fit$n else n_rows, k = if (ok) fit$k else NA,
    n_industry_dummies = if (ok) fit$n_ind else NA,
    dropped_columns = if (length(fit$dropped)) paste(fit$dropped, collapse = "; ") else NA,
    r2 = if (ok) fit$r2 else NA, adj_r2 = if (ok) fit$adj_r2 else NA,
    f = if (ok) fit$f else NA, f_df1 = if (ok) fit$f_df1 else NA,
    f_df2 = if (ok) fit$f_df2 else NA, f_p = if (ok) fit$f_p else NA,
    n_leverage_one = if (ok) fit$n_leverage_one else NA,
    stringsAsFactors = FALSE)
}

#' One nested_tests.csv row. `dropped` = industry dummies dropped in the restricted refit
#' (A6: recorded whether or not that refit succeeded), written as restricted_dropped_columns.
nested_row <- function(spec_id, family, np, n = NA, nf = NULL, status = "failed", error = NA_character_,
                       dropped = character(0)) {
  if (is.null(nf)) nf <- list(delta_r2 = NA, f = NA, df1 = NA, df2 = NA, p = NA)
  data.frame(spec_id = spec_id, family = family, test_id = np$test_id,
             full_model = np$full, restricted_model = np$restricted,
             n = n, delta_r2 = nf$delta_r2, f = nf$f, df1 = nf$df1, df2 = nf$df2, p = nf$p,
             status = status, error = error,
             restricted_dropped_columns = if (length(dropped)) paste(dropped, collapse = "; ") else NA_character_,
             stringsAsFactors = FALSE)
}

#' Outcome of one nested test given the full fit and the restricted refit (both fit_model()
#' results on identical rows). Returns list(status, error, nf, dropped, n): a failed full model,
#' a failed restricted model (its dropped columns retained, A6) or a rank-increase mismatch (A5)
#' each give status "failed" with the reason.
nested_outcome <- function(full, rfit, n_added) {
  if (full$status != "ok")
    return(list(status = "failed", error = paste("full model failed:", full$error), nf = NULL,
                dropped = character(0)))
  rdropped <- if (!is.null(rfit$dropped)) rfit$dropped else character(0)
  if (rfit$status != "ok")
    return(list(status = "failed", error = paste("restricted model failed:", rfit$error), nf = NULL,
                dropped = rdropped))
  nf <- nested_f(full, rfit, df1_required = n_added)
  list(status = nf$status, error = nf$error, nf = nf, dropped = rdropped)
}

#' Run one spec. Returns list(coefficients, model_stats, nested_tests, samples,
#' designs (for influence), error).
run_spec <- function(d, spec, mis, cwp) {
  s <- spec$settings
  check <- if (!is.null(spec$check)) spec$check else NULL
  spec_id <- spec$spec_id
  out <- list(coefficients = list(), model_stats = list(), nested_tests = list(),
              samples = list(), designs = list(), error = NA_character_)
  pop_sd <- s$z_reference == "L3"

  f0 <- build_frame(d, s, mis, cwp, check)
  # A8: the family samples (also the z_reference L1/L2 reference samples) are determined once,
  # from validity alone, before any standardization; membership is never recomputed.
  S <- list(org = family_sample_L0(f0, "org", s), mkt = family_sample_L0(f0, "mkt", s))
  f0 <- add_z_indices(f0, s$item_rule, NULL, pop_sd)

  frames <- list(org = f0, mkt = f0)
  if (s$z_reference == "L1") {
    fz <- add_z_indices(f0, s$item_rule, S$org, pop_sd); frames <- list(org = fz, mkt = fz)
  } else if (s$z_reference == "L2") {
    frames <- list(org = add_z_indices(f0, s$item_rule, S$org, pop_sd),
                   mkt = add_z_indices(f0, s$item_rule, S$mkt, pop_sd))
  } else if (!s$z_reference %in% c("L0", "L3")) stop("unknown z_reference ", s$z_reference)

  for (family in c("org", "mkt")) {
    f <- frames[[family]]
    ycol <- family_outcome(family); controls <- family_controls(family)
    models <- model_list(family)
    fits <- list(); rows_of <- list()

    if (s$case_scope == "L0") {
      fam_rows <- S[[family]]
      dummy_groups <- industry_dummy_groups(f$IND[fam_rows], alt = identical(check, "industry_ref_alt"))
      out$samples[[length(out$samples) + 1]] <- sample_rows(spec_id, family, "ALL", f$V1[fam_rows])
    } else if (s$case_scope == "L1") {
      base_rows <- family_filter(f, family, s) & complete_rows(f, c(ycol, controls, "IND"))
      dummy_groups <- industry_dummy_groups(f$IND[base_rows], alt = identical(check, "industry_ref_alt"))
    } else stop("unknown case_scope ", s$case_scope)

    for (mid in names(models)) {
      m <- models[[mid]]
      rows <- if (s$case_scope == "L0") S[[family]] else
        family_filter(f, family, s) & complete_rows(f, c(ycol, controls, "IND")) & hrm_complete(f, m$hrm)
      rows_of[[mid]] <- rows
      if (s$case_scope == "L1") out$samples[[length(out$samples) + 1]] <- sample_rows(spec_id, family, mid, f$V1[rows])
      V1_rows <- f$V1[rows]
      y <- f[[ycol]][rows]
      w <- if (s$weights == "L1") f$WEIGHT[rows] else NULL
      fit <- tryCatch({
        X <- build_design(f, rows, m$hrm, m$int, controls, dummy_groups, s$centering)
        fit <- fit_model(X, y, w)
        # keep the design actually estimated (after any column drops) for the influence refits
        fit$X <- if (fit$status == "ok") X[, fit$terms, drop = FALSE] else X
        fit
      }, error = function(e) list(status = "failed", error = conditionMessage(e), dropped = character(0)))
      # estimation-sample identifiers are attached even when the fit failed (A6: influence rows)
      fit$y <- y; fit$w <- w; fit$V1 <- V1_rows
      fits[[mid]] <- fit
      out$model_stats[[length(out$model_stats) + 1]] <- model_stats_row(spec_id, family, mid, fit, sum(rows))
      if (fit$status == "ok") {
        out$coefficients[[length(out$coefficients) + 1]] <- cbind(
          data.frame(spec_id = spec_id, family = family, model_id = mid, stringsAsFactors = FALSE), fit$coefs)
      }
    }

    # nested tests: restricted model refitted on the full model's rows; numerator df must equal
    # the number of added terms (A5); every failure carries its reason (A6)
    for (np in nested_pairs(family)) {
      full <- fits[[np$full]]
      rm <- models[[np$restricted]]
      fm <- models[[np$full]]
      n_added <- length(setdiff(c(fm$hrm, fm$int), c(rm$hrm, rm$int)))
      rfit <- if (full$status != "ok") NULL else tryCatch({
        Xr <- build_design(f, rows_of[[np$full]], rm$hrm, rm$int, controls, dummy_groups, s$centering)
        fit_model(Xr, full$y, full$w)   # returns dropped industry dummies even on failure (A6)
      }, error = function(e) list(status = "failed", error = conditionMessage(e), dropped = character(0)))
      o <- nested_outcome(full, rfit, n_added)
      out$nested_tests[[length(out$nested_tests) + 1]] <- nested_row(
        spec_id, family, np, n = sum(rows_of[[np$full]]), nf = o$nf, status = o$status, error = o$error,
        dropped = o$dropped)
    }
    out$designs[[family]] <- fits
  }
  out
}

# ---------------------------------------------------------------------------
# Influence diagnostic (leave-one-out refits on fixed design)
# ---------------------------------------------------------------------------

#' Leave-one-out refits of one fitted model (fit = element of run_spec()$designs).
#' Returns a data.frame with model_id, deleted_V1, term, estimate, se, p_upper, p_two, status, note.
influence_loo <- function(fit, model_id, report_terms) {
  rows <- list()
  if (is.null(fit) || fit$status != "ok") {
    # A6: one failed row per estimation-sample record when the original model failed. An empty
    # (known) estimation sample has no record to delete, so it yields no row at all; a single
    # row with deleted_V1 = NA is written only when the sample itself is unknown (fit$V1 NULL).
    if (is.null(fit) || is.null(fit$V1)) {
      reason <- if (is.null(fit)) "original model not fitted; estimation sample unknown" else
        paste("original model not fitted; estimation sample unknown:", fit$error)
      return(data.frame(model_id = model_id, deleted_V1 = NA_real_, term = NA_character_, estimate = NA_real_,
                        se = NA_real_, p_upper = NA_real_, p_two = NA_real_, status = "failed", note = reason,
                        stringsAsFactors = FALSE))
    }
    v1 <- as.numeric(fit$V1)
    return(data.frame(model_id = rep(model_id, length(v1)), deleted_V1 = v1, term = rep(NA_character_, length(v1)),
                      estimate = rep(NA_real_, length(v1)), se = rep(NA_real_, length(v1)),
                      p_upper = rep(NA_real_, length(v1)), p_two = rep(NA_real_, length(v1)),
                      status = rep("failed", length(v1)),
                      note = rep(paste("original model not fitted:", fit$error), length(v1)),
                      stringsAsFactors = FALSE))
  }
  X <- fit$X; y <- fit$y; w <- fit$w; V1 <- fit$V1
  n <- nrow(X)
  for (i in seq_len(n)) {
    Xi <- X[-i, , drop = FALSE]; yi <- y[-i]; wi <- if (is.null(w)) NULL else w[-i]
    r <- fit_model(Xi, yi, wi)
    if (r$status == "ok") {
      keep <- r$coefs$term %in% report_terms
      cf <- r$coefs[keep, , drop = FALSE]
      note <- if (length(r$dropped)) paste("dropped:", paste(r$dropped, collapse = "; ")) else NA_character_
      missing_terms <- setdiff(report_terms, cf$term)
      rows[[length(rows) + 1]] <- data.frame(
        model_id = model_id, deleted_V1 = V1[i], term = cf$term, estimate = cf$estimate, se = cf$se,
        p_upper = cf$p_upper, p_two = cf$p_two, status = "ok", note = note, stringsAsFactors = FALSE)
      if (length(missing_terms)) rows[[length(rows) + 1]] <- data.frame(
        model_id = model_id, deleted_V1 = V1[i], term = missing_terms, estimate = NA, se = NA,
        p_upper = NA, p_two = NA, status = "ok", note = "term dropped in refit", stringsAsFactors = FALSE)
    } else {
      # A6: dropped-column information is kept even when the refit fails
      note <- if (length(r$dropped)) paste0(r$error, " [dropped: ", paste(r$dropped, collapse = "; "), "]") else r$error
      rows[[length(rows) + 1]] <- data.frame(
        model_id = model_id, deleted_V1 = V1[i], term = NA, estimate = NA, se = NA,
        p_upper = NA, p_two = NA, status = "failed", note = note, stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}
