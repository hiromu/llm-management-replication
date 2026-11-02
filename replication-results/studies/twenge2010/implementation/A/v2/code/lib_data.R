# lib_data.R -- constants, data loading, coding, samples, hashing (MANIFEST Sections 1-3)

suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
})

YEARS <- c("1976", "1991", "2006")
PAIRS <- list(P1 = c("1976", "1991"), P2 = c("1991", "2006"), P3 = c("1976", "2006"))
FORMS <- c("f3", "f4")
FILE_KEYS <- c("y1976_f3", "y1991_f3", "y2006_f3", "y1976_f4", "y1991_f4", "y2006_f4")

F4_ITEMS <- paste0("V", 4225:4247)                 # 23 items, valid 1-4, top = 4
F3_ITEMS <- paste0("V", 3222:3227)                 # 6 items
F3_ITEMS_5 <- paste0("V", 3222:3226)               # valid 1-5, top = 4 or 5 ; V3227 valid 1-2, top = 1
F3_REVERSED <- c(V3222 = "V3222_r", V3223 = "V3223_r", V3227 = "V3227_r")  # 6-x, 6-x, 3-x

FACTORS_F4 <- list(
  K1 = c("V4236", "V4238", "V4240", "V4246"),
  K2 = c("V4227", "V4225", "V4231", "V4232", "V4234", "V4242", "V4243"),
  K3 = c("V4235", "V4229"),
  K4 = c("V4233", "V4245"),
  K5 = c("V4226", "V4228", "V4230", "V4244"),
  K6 = c("V4239", "V4241"),
  K7 = c("V4237", "V4247")
)
MARKERS_F4 <- c(K1 = "V4236", K2 = "V4227", K3 = "V4235", K4 = "V4233", K5 = "V4226", K6 = "V4239", K7 = "V4237")
MARKERS_CHK2 <- c(K1 = "V4246", K2 = "V4225", K3 = "V4235", K4 = "V4245", K5 = "V4244")
RELEASED <- c("V4238", "V4240", "V4231", "V4229", "V4230", "V4228")
MODEL_FACTORS <- FACTORS_F4[c("K1", "K2", "K3", "K4", "K5")]
MODEL_ITEMS <- unname(unlist(MODEL_FACTORS))        # 19 model items

# Form 3 factors (after reversal). C1 marker V3224. C2 single indicator V3226.
C1_ITEMS <- c("V3224", "V3225", "V3222_r", "V3223_r", "V3227_r")
FACTORS_F3 <- list(C1 = C1_ITEMS, C2 = "V3226")
MARKERS_F3 <- c(C1 = "V3224", C2 = "V3226")
S08_ITEMS <- c("V3224", "V3225", "V3226", "V3222_r", "V3223_r")   # one factor, marker V3224

file_year <- function(key) sub("^y(\\d{4})_f\\d$", "\\1", key)
file_form <- function(key) sub("^y\\d{4}_(f\\d)$", "\\1", key)
key_for <- function(year, form) paste0("y", year, "_", form)

# ---- dictionary: declared missing codes for V5 -------------------------------------------------
read_declared_missing <- function(root, key, var = "V5") {
  path <- file.path(root, "dictionaries", paste0(key, ".dictionary.json"))
  j <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  vars <- if (!is.null(j$variables)) j$variables else j
  idx <- which(vapply(vars, function(e) identical(e$name, var), logical(1)))
  if (length(idx) == 0) return(list(values = numeric(0), range = NULL))
  e <- vars[[idx[1]]]
  vals <- if (is.null(e$declared_missing_values)) numeric(0) else as.numeric(unlist(e$declared_missing_values))
  rng <- NULL
  if (!is.null(e$declared_missing_range) && length(e$declared_missing_range) == 2) {
    lo <- e$declared_missing_range[[1]]; hi <- e$declared_missing_range[[2]]
    lo <- if (is.character(lo)) { if (toupper(lo) %in% c("LOWEST", "LO", "-INF")) -Inf else as.numeric(lo) } else as.numeric(lo)
    hi <- if (is.character(hi)) { if (toupper(hi) %in% c("HIGHEST", "HI", "INF")) Inf else as.numeric(hi) } else as.numeric(hi)
    rng <- c(lo, hi)
  }
  list(values = vals, range = rng)
}

is_declared_missing <- function(x, dm) {
  out <- rep(FALSE, length(x))
  if (length(dm$values)) out <- out | (x %in% dm$values)
  if (!is.null(dm$range)) out <- out | (!is.na(x) & x >= dm$range[1] & x <= dm$range[2])
  out
}

# ---- loading and coding ------------------------------------------------------------------------
recode_valid <- function(x, valid) { x <- as.numeric(x); x[!(x %in% valid)] <- NA_real_; x }

load_all_data <- function(root) {
  out <- list()
  for (key in FILE_KEYS) {
    path <- file.path(root, "data", paste0(key, ".csv.gz"))
    dt <- data.table::fread(path, showProgress = FALSE)
    rows_read <- nrow(dt)
    form <- file_form(key)
    items <- if (form == "f4") F4_ITEMS else F3_ITEMS
    d <- data.table(V4 = as.numeric(dt$V4), V5 = as.numeric(dt$V5))
    if (form == "f4") {
      for (it in F4_ITEMS) d[[it]] <- recode_valid(dt[[it]], 1:4)
    } else {
      for (it in F3_ITEMS_5) d[[it]] <- recode_valid(dt[[it]], 1:5)
      d[["V3227"]] <- recode_valid(dt[["V3227"]], 1:2)
      d[["V3222_r"]] <- 6 - d[["V3222"]]
      d[["V3223_r"]] <- 6 - d[["V3223"]]
      d[["V3227_r"]] <- 3 - d[["V3227"]]
    }
    dm <- read_declared_missing(root, key, "V5")
    d[["w_valid"]] <- !is.na(d$V5) & d$V5 > 0 & !is_declared_missing(d$V5, dm)
    if (anyDuplicated(d$V4)) warning("V4 not unique in ", key)
    out[[key]] <- list(key = key, year = file_year(key), form = form, data = d, rows_read = rows_read,
                       n_invalid_weight = sum(!d$w_valid), v5_declared_missing = dm)
  }
  out
}

# ---- samples -----------------------------------------------------------------------------------
# Returns the analysis sample (data.table) for one file given required items and the spec options.
#  required: items that must all be valid (complete-case rule)
#  any_of:   if non-NULL, instead require at least one valid value among these items (FIML rule)
#  weighted: drop records with invalid V5 and add normalized weight column `w` (sum = n)
#  complete_all: additionally require complete on all items of the form (S03)
select_sample <- function(fd, required, spec, any_of = NULL) {
  d <- fd$data
  keep <- rep(TRUE, nrow(d))
  if (!is.null(any_of)) {
    keep <- keep & (rowSums(!is.na(as.matrix(d[, any_of, with = FALSE]))) >= 1)
  }
  if (length(required)) keep <- keep & complete.cases(as.matrix(d[, required, with = FALSE]))
  if (isTRUE(spec$complete_all)) {
    all_items <- if (fd$form == "f4") F4_ITEMS else F3_ITEMS
    keep <- keep & complete.cases(as.matrix(d[, all_items, with = FALSE]))
  }
  if (isTRUE(spec$weighted)) keep <- keep & d$w_valid
  s <- d[keep]
  if (isTRUE(spec$weighted)) {
    n <- nrow(s)
    s[["w"]] <- s$V5 * n / sum(s$V5)
  } else {
    s[["w"]] <- rep(1, nrow(s))
  }
  s
}

format_id <- function(x) {
  if (all(is.finite(x)) && all(x == round(x))) formatC(x, format = "d") else as.character(x)
}

hash_v4 <- function(v4) {
  v4 <- sort(as.numeric(v4))
  s <- paste(format_id(v4), collapse = "\n")
  unname(tools::sha256sum(bytes = charToRaw(s)))
}

sample_record <- function(s) list(n = nrow(s), sha256_V4 = hash_v4(s$V4))

# ---- sample moments ----------------------------------------------------------------------------
# divisor: "n-1" or "n". If weights w present (normalized to sum n), weighted moments are used.
sample_moments <- function(X, w = NULL, divisor = c("n-1", "n")) {
  divisor <- match.arg(divisor)
  X <- as.matrix(X)
  n <- nrow(X)
  if (is.null(w)) w <- rep(1, n)
  w <- w * n / sum(w)
  m <- colSums(w * X) / n
  Xc <- sweep(X, 2, m)
  SS <- crossprod(Xc * w, Xc)
  den <- if (divisor == "n-1") n - 1 else n
  S <- SS / den
  dimnames(S) <- list(colnames(X), colnames(X))
  names(m) <- colnames(X)
  list(cov = S, mean = m, nobs = n, SS = SS, sum = colSums(w * X), divisor = divisor)
}
