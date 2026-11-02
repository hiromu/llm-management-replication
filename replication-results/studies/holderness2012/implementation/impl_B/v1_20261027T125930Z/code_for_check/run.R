#!/opt/homebrew/bin/Rscript
# P-R7M2 v1. All analysis, ingestion and synthetic checks live in this file.
suppressPackageStartupMessages(library(data.table))
options(stringsAsFactors = FALSE, warn = 1)
setDTthreads(2L)
`%||%` <- function(x, y) if (is.null(x)) y else x
clean <- function(x) { x <- trimws(as.character(x)); x[is.na(x)] <- ""; x }
num <- function(x) suppressWarnings(as.numeric(x))
integer_field <- function(x, pattern = "^[0-9]+$") {
  ans <- num(x); ans[!grepl(pattern, x)] <- NA_real_; ans
}
log_line <- function(...) cat(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), ..., "\n")

# R cannot represent embedded NUL in a character scalar. nanoparquet's normal
# string reader therefore fails on these files. Decode only affected BYTE_ARRAY
# columns from decompressed pages, removing NUL BEFORE rawToChar. No input edits.
plain_strings <- function(bytes, n) {
  out <- character(n); at <- 1L; size <- length(bytes)
  for (i in seq_len(n)) {
    if (at + 3L > size) stop("Truncated PLAIN string length")
    len <- sum(as.integer(bytes[at + 0:3]) * c(1, 256, 65536, 16777216))
    at <- at + 4L
    if (len < 0 || at + len - 1 > size) stop("Invalid PLAIN string length")
    if (len > 0) {
      b <- bytes[seq.int(at, length.out = len)]
      out[i] <- rawToChar(b[b != as.raw(0)])
    }
    at <- at + len
  }
  if (at != size + 1L) stop("Unexpected trailing PLAIN bytes")
  out
}
raw_column <- function(file, column, pages) {
  pp <- pages[pages$column == column, ]; chunks <- list(); dictionary <- NULL
  current_rg <- -1L
  for (j in seq_len(nrow(pp))) {
    p <- nanoparquet:::read_parquet_page(file, pp$page_header_offset[j])
    if (p$row_group != current_rg) { dictionary <- NULL; current_rg <- p$row_group }
    if (p$data_type != "BYTE_ARRAY" || is.null(p$data)) stop("Unsupported NUL fallback page")
    if (p$page_type == "DICTIONARY_PAGE") {
      if (p$encoding != "PLAIN") stop("Unsupported dictionary encoding")
      dictionary <- plain_strings(p$data, p$num_values); next
    }
    if (!p$page_type %in% c("DATA_PAGE", "DATA_PAGE_V2")) next
    if (p$has_repetition_levels) stop("Nested fields are not supported")
    bytes <- p$data; at <- 1L; present <- rep(TRUE, p$num_values)
    if (p$has_definition_levels) {
      if (p$page_type == "DATA_PAGE") {
        if (p$definition_level_encoding != "RLE") stop("Unsupported definition levels")
        len <- sum(as.integer(bytes[1:4]) * c(1, 256, 65536, 16777216)); at <- 5L
      } else len <- p$definition_levels_byte_length
      levels <- nanoparquet:::rle_decode_int(bytes[seq.int(at, length.out = len)],
                                            bit_width = 1L, length = as.integer(p$num_values))
      present <- levels == 1L; at <- at + len
    }
    n <- sum(present)
    if (!n) vals <- character() else if (p$encoding == "PLAIN") {
      vals <- plain_strings(bytes[seq.int(at, length.out = length(bytes) - at + 1L)], n)
    } else if (p$encoding %in% c("RLE_DICTIONARY", "PLAIN_DICTIONARY")) {
      if (is.null(dictionary)) stop("Missing Parquet dictionary")
      width <- as.integer(bytes[at]); at <- at + 1L
      ix <- nanoparquet:::rle_decode_int(bytes[seq.int(at, length.out = length(bytes) - at + 1L)],
                                        bit_width = width, length = as.integer(n))
      if (any(ix < 0 | ix >= length(dictionary))) stop("Invalid dictionary index")
      vals <- dictionary[ix + 1L]
    } else stop("Unsupported fallback encoding: ", p$encoding)
    out <- rep(NA_character_, p$num_values); out[present] <- vals
    chunks[[length(chunks) + 1L]] <- out
  }
  unlist(chunks, use.names = FALSE)
}
column_reader <- function(file) {
  schema <- nanoparquet::read_parquet_schema(file); pages <- NULL
  function(name) {
    tryCatch(nanoparquet::read_parquet(file, col_select = name)[[name]], error = function(e) {
      if (!grepl("embedded nul", conditionMessage(e), fixed = TRUE)) stop(e)
      if (is.null(pages)) pages <<- nanoparquet:::read_parquet_pages(file)
      log_line("NUL-safe page reader:", basename(file), name)
      ans <- raw_column(file, schema$r_col[match(name, schema$name)] - 1L, pages)
      expected <- nanoparquet::read_parquet_metadata(file)$file_meta_data$num_rows
      if (length(ans) != expected) stop("Fallback row count mismatch")
      ans
    })
  }
}
load_inputs <- function(data_dir, root_dir) {
  fields <- c("record_seq", "SERIAL_NO", "GRADE_ALPHA", "GRADE_CODE", "SERVICE_CODE",
              "ARM_SVC_ALPHA", "ARM_SVC_CODE", "DATE_REPORTED_MONTH", "DATE_REPORTED_YEAR",
              "TYPE_ORG", "PARENT_UNIT_NUM", "PARENT_UNIT_TYPE", "STA", "DET_POWER", "CAMP")
  read_pow <- column_reader(file.path(data_dir, "pow.parquet"))
  pow <- as.data.table(setNames(lapply(fields, read_pow), fields))
  for (v in setdiff(fields, "record_seq")) set(pow, j = v, value = clean(pow[[v]]))
  read_enl <- column_reader(file.path(data_dir, "enl.parquet"))
  # Link early: hold one full-length enlistment column at a time, retaining only
  # serials appearing in POW. Duplicate resolution is deliberately later.
  serial <- clean(gsub("#", " ", read_enl("SER_NUM"), fixed = TRUE))
  keep <- which(serial %in% pow$SERIAL_NO)
  enl <- data.table(SER_NUM = serial[keep]); rm(serial); gc(FALSE)
  ef <- c("record_seq", "CARD_NUM", "HEIGHT", "ERC_HEIGHT", "YR_BIRTH", "ERC_YR_BIRTH",
          "EDUCATION", "ERC_EDUCATION", "MARITAL_STATUS", "ERC_MARITAL_STATUS")
  for (v in ef) {
    x <- read_enl(v)[keep]
    if (v != "record_seq") x <- clean(x)
    set(enl, j = v, value = x)
  }
  read_csv <- function(path) withCallingHandlers(
    fread(path, colClasses = "character", na.strings = NULL),
    warning = function(w) { log_line("Input CSV warning:", basename(path), conditionMessage(w)); invokeRestart("muffleWarning") })
  log_line("Input rows: POW", nrow(pow), "; enlistment candidates", nrow(enl))
  list(pow = pow, enl = enl,
       alpha = read_csv(file.path(data_dir, "rank_map_grade_alpha.csv")),
       code = read_csv(file.path(data_dir, "rank_map_grade_code.csv")),
       coords = read_csv(file.path(data_dir, "camp_location_crosswalk.csv")),
       camps = clean(read_csv(file.path(root_dir, "code_lists", "pow_CAMP_cl1277.csv"))$Code))
}
resolve_enl <- function(enl, rule) {
  e <- copy(enl); setorder(e, record_seq)
  if (rule == "unmatched") e <- e[, if (.N == 1L) .SD, by = SER_NUM]
  else if (rule == "first") e <- e[!duplicated(SER_NUM)]
  else if (rule == "combine") {
    fields <- setdiff(names(e), c("SER_NUM", "record_seq"))
    e <- e[, lapply(.SD, function(x) {
      u <- unique(x[x != ""]); if (length(u) == 1L) u else ""
    }), by = SER_NUM, .SDcols = fields]
  } else stop("Unknown dup_serial")
  e
}
assign_ranks <- function(d, inp, rule) {
  a <- copy(inp$alpha); c <- copy(inp$code)
  a[, grade_alpha := clean(grade_alpha)]; c[, grade_code := clean(grade_code)]
  a <- a[!duplicated(grade_alpha)]; c <- c[!duplicated(grade_code)]
  ai <- match(d$GRADE_ALPHA, a$grade_alpha); ci <- match(d$GRADE_CODE, c$grade_code)
  navy <- d$SERVICE_CODE == "2"; off <- substr(d$SERIAL_NO, 1, 1) %in% c("O", "T")
  mode <- if (rule == "strict") "strict" else "origin"
  ar <- ifelse(navy, num(a[[paste0("rank_", mode, "_navy")]][ai]),
               num(a[[paste0("rank_", mode, "_service_not_navy")]][ai]))
  cr <- rep(NA_real_, nrow(d))
  for (nv in c(FALSE, TRUE)) for (of in c(FALSE, TRUE)) {
    col <- paste0("rank_", if (of) "officer" else "enlisted", if (nv) "_navy" else "_not_navy")
    ii <- which(navy == nv & off == of); cr[ii] <- num(c[[col]][ci[ii]])
  }
  ans <- if (rule == "strict") ar else if (rule == "grade_code") ifelse(is.na(cr), ar, cr) else ifelse(is.na(ar), cr, ar)
  if (any(!is.na(ans) & !ans %in% 1:9)) stop("Rank outside 1..9")
  ans
}
camp_distance <- function(d, cw, mode) {
  cw <- copy(cw); cw[, camp_code := clean(camp_code)]
  cw <- cw[clean(confidence) %in% c("exact", "approximate")]
  # entry_id is a string identifier (e.g. 359a), so lexical order is explicit.
  setorder(cw, camp_code, entry_id); cw <- cw[!duplicated(camp_code)]
  ix <- match(d$CAMP, cw$camp_code); lat <- num(cw$latitude[ix]); lon <- num(cw$longitude[ix])
  if (mode == "nara_degree") {
    tx <- clean(cw$nara_degree_coords_text[ix]); valid <- grepl("^[0-9]+[[:space:]]*-[[:space:]]*[0-9]+$", tx)
    lat[tx != "" & !valid] <- NA_real_; lon[tx != "" & !valid] <- NA_real_
    lat[valid] <- num(sub("-.*$", "", tx[valid])); lon[valid] <- num(sub("^.*-", "", tx[valid]))
  }
  lat0 <- ifelse(d$DET_POWER == "1", 52.5200, 35.6762)
  lon0 <- ifelse(d$DET_POWER == "1", 13.4050, 139.6503)
  rad <- pi / 180
  h <- sin((lat - lat0) * rad / 2)^2 + cos(lat * rad) * cos(lat0 * rad) * sin((lon - lon0) * rad / 2)^2
  km <- 6371 * 2 * asin(sqrt(pmin(1, pmax(0, h))))
  capital <- (d$DET_POWER == "1" & clean(cw$identified_place_name[ix]) == "Berlin") |
    (d$DET_POWER == "2" & clean(cw$identified_place_name[ix]) == "Tokyo")
  km[capital] <- 1
  ans <- log(km) / 10; ans[!is.finite(ans)] <- NA_real_; ans
}
construct_base <- function(inp, p) {
  d <- copy(inp$pow); d[, rank := assign_ranks(d, inp, p$rank_rule)]
  e <- resolve_enl(inp$enl, p$dup_serial); ix <- match(d$SERIAL_NO, e$SER_NUM)
  card3 <- e$CARD_NUM[ix] == "3"; card3[is.na(card3)] <- FALSE
  get_field <- function(v) ifelse(card3, e[[paste0("ERC_", v)]][ix], e[[v]][ix])
  h <- integer_field(get_field("HEIGHT")); h[is.na(h) | h < 48 | h > 84] <- NA_real_
  if (p$height_rule == "none") h[] <- NA_real_
  age <- 45 - integer_field(get_field("YR_BIRTH"), "^[0-9]{2}$")
  if (p$age_rule == "range") age[!is.na(age) & (age < 15 | age > 70)] <- NA_real_
  educ <- integer_field(get_field("EDUCATION"), "^[0-9]$")
  educ[!is.na(educ) & educ == 9] <- num(p$educ_postgrad)
  marital <- get_field("MARITAL_STATUS"); dep <- rep(NA_real_, nrow(d))
  dep[marital %in% c("1", "3", "4", "5")] <- 1
  dep[marital %in% c("6", "7", "8", "9")] <- 0
  dep[marital %in% "2"] <- num(p$married)
  d[, `:=`(height = h / 10, age = age / 100, education = educ / 10, dependents = dep,
           linked = !is.na(ix), officer = ifelse(is.na(rank), NA_real_, as.numeric(rank >= 5)),
           survival = as.integer(STA %in% c("7", "8", "9")), executed = as.integer(STA == "4"),
           japan = as.integer(DET_POWER == "2"), camp = CAMP)]
  d[, valid_camp := nchar(CAMP, type = "chars") == 3L & CAMP != "000"]
  if (p$camp_valid == "defined") d[, valid_camp := valid_camp & CAMP %in% inp$camps]
  d[, valid_month := DATE_REPORTED_YEAR %in% as.character(1:6) & DATE_REPORTED_MONTH %in% sprintf("%02d", 1:12)]
  d[, cap := ifelse(valid_camp & valid_month, paste(CAMP, 1940 + num(DATE_REPORTED_YEAR), DATE_REPORTED_MONTH, sep = "|"), NA_character_)]
  d[, length := ifelse(valid_month, ((1945 - (1940 + num(DATE_REPORTED_YEAR))) * 12 +
              ifelse(DET_POWER == "1", 5, 9) - num(DATE_REPORTED_MONTH)) / 10, NA_real_)]
  d[, distance := camp_distance(d, inp$coords, p$coords)]
  d[, unit := ifelse(TYPE_ORG == "" & PARENT_UNIT_NUM == "" & PARENT_UNIT_TYPE == "", NA_character_,
                     paste(TYPE_ORG, PARENT_UNIT_NUM, PARENT_UNIT_TYPE, sep = "|"))]
  d[, descriptive := !SERVICE_CODE %in% unlist(p$svc_exclude) & DET_POWER %in% c("1", "2") & STA %in% c("4", "5", "7", "8", "9")]
  log_line("Sample D0", nrow(d), "D", sum(d$descriptive), "R cap", sum(d$descriptive & d$valid_camp & d$valid_month),
           "R camp", sum(d$descriptive & d$valid_camp & (d$valid_month | !p$sample_common)))
  d
}
hierarchy_counts <- function(counts, p, constant = 1.319) {
  n <- sum(counts)
  if (!n) return(setNames(rep(NA_real_, 8), c("n_g", "steepness", "sameness", "ratio", "absolute", "distinct", "rank_sum", "admin")))
  ranks <- 1:9; f <- counts / n; before <- c(0, head(cumsum(counts), -1))
  weighted <- sum(ranks * (counts * (n + 1) - counts * (2 * before + counts + 1) / 2))
  rs <- sum(ranks * counts)
  steep <- 1 + 1 / n - 2 * weighted / (n * rs)
  if (sum(counts > 0) == 1L) steep <- 0
  ratio <- if (any(p == 0)) NA_real_ else 1 - sum((f / p - 1)^2) / 10000
  absolute <- if (p[9] == 1) NA_real_ else 1 - sum(abs(f - p)) / (2 * (1 - p[9]))
  c(n_g = n, steepness = steep, sameness = if (constant == 0) NA_real_ else 1 - sum((f - p)^2) / constant,
    ratio = ratio, absolute = absolute, distinct = sum(counts > 0), rank_sum = rs, admin = 100 * sum(f[-1]))
}
group_table <- function(members, keys, fractions, constant) {
  members[, as.list(hierarchy_counts(tabulate(rank, nbins = 9), fractions, constant)), by = keys]
}
attach_groups <- function(base, p, group, need_units = FALSE) {
  valid <- base$valid_camp & (base$valid_month | (group == "camp" & !p$sample_common))
  r <- copy(base[descriptive & valid])
  ref <- if (p$pop_fractions == "descriptive") base[descriptive & !is.na(rank)] else r[!is.na(rank)]
  if (!nrow(ref)) stop("No ranks for reference fractions")
  fractions <- tabulate(ref$rank, nbins = 9) / nrow(ref)
  constant <- if (p$sameness_constant == "fixed") 1.319 else (1 - fractions[9])^2 + sum(fractions[1:8]^2)
  if (p$group_members == "file") members <- base[valid_camp & (valid_month | group == "camp") & !is.na(rank)]
  else {
    members <- r[!is.na(rank)]
    if (p$group_members == "complete") members <- members[complete.cases(members[, .(height, age, education, dependents)])]
  }
  gt <- group_table(members, group, fractions, constant)
  cols <- setdiff(names(gt), group); ix <- match(r[[group]], gt[[group]])
  for (v in cols) set(r, j = v, value = gt[[v]][ix])
  r[, `:=`(men = log(n_g) / 10, men_sq = (log(n_g) / 10)^2)]
  if (need_units) {
    ut <- group_table(members[!is.na(unit)], c(group, "unit"), fractions, constant)
    keys <- function(d) paste(d[[group]], d$unit, sep = "\034")
    ui <- match(keys(r), keys(ut)); un <- ut$n_g[ui]
    # Under alternate member rules the row need not itself be a member.
    if (p$friends_def == "others") un <- un - as.integer(r$record_seq %in% members$record_seq)
    friends <- log(un); friends[!is.finite(friends) | is.na(r$unit)] <- NA_real_
    r[, friends := friends]
    for (v in c("steepness", "sameness")) set(r, j = paste0("unit_", v), value = ut[[v]][ui])
  }
  log_line(group, "reference fractions", paste(signif(fractions, 5), collapse = ","), "c", constant)
  miss <- vapply(r[, .(rank, height, age, education, dependents, officer, distance, length, n_g)], function(x) sum(is.na(x)), integer(1))
  log_line(group, "missing:", paste(names(miss), miss, collapse = "; "))
  r
}

# Observed-information bread and individual likelihood scores for probit MLE.
probit_parts <- function(X, y, beta) {
  eta <- drop(X %*% beta)
  lp <- pnorm(eta, log.p = TRUE); lq <- pnorm(eta, lower.tail = FALSE, log.p = TRUE)
  a <- exp(dnorm(eta, log = TRUE) - lp); b <- exp(dnorm(eta, log = TRUE) - lq)
  score <- y * a - (1 - y) * b
  weight <- y * a * (eta + a) + (1 - y) * b * (b - eta)
  list(scores = X * score, information = crossprod(X, X * weight))
}
cluster_cov <- function(parts, cluster) {
  g <- length(unique(cluster)); if (g < 2L) stop("Fewer than two clusters")
  bread <- solve(parts$information)
  sums <- rowsum(parts$scores, as.character(cluster), reorder = FALSE)
  v <- (g / (g - 1)) * bread %*% crossprod(sums) %*% bread
  (v + t(v)) / 2
}
marginal_effects <- function(beta, mean_x, binary, covariance) {
  k <- length(beta); eta <- sum(mean_x * beta); dens <- dnorm(eta)
  effect <- rep(NA_real_, k); jac <- matrix(0, k, k)
  for (j in seq_len(k)) {
    if (names(beta)[j] == "(Intercept)") next
    if (names(beta)[j] %in% binary) {
      x1 <- x0 <- mean_x; x1[j] <- 1; x0[j] <- 0
      e1 <- sum(x1 * beta); e0 <- sum(x0 * beta)
      effect[j] <- pnorm(e1) - pnorm(e0)
      jac[j, ] <- dnorm(e1) * x1 - dnorm(e0) * x0
    } else {
      effect[j] <- dens * beta[j]
      jac[j, ] <- -eta * dens * beta[j] * mean_x
      jac[j, j] <- jac[j, j] + dens
    }
  }
  se <- sqrt(pmax(0, rowSums((jac %*% covariance) * jac)))
  se[is.na(effect)] <- NA_real_
  list(me = effect, se = se, p = 2 * pnorm(-abs(effect / se)), jacobian = jac)
}
delong <- function(y, first, second) {
  if (length(y) != length(first) || length(y) != length(second) || anyNA(c(y, first, second))) stop("Invalid ROC inputs")
  m <- sum(y == 1); n <- sum(y == 0)
  if (m < 2L || n < 2L) stop("DeLong requires at least two observations per class")
  placement <- function(s) {
    pos <- s[y == 1]; neg <- s[y == 0]
    r <- rank(c(pos, neg), ties.method = "average")
    v1 <- (r[seq_len(m)] - rank(pos, ties.method = "average")) / n
    v0 <- 1 - (r[m + seq_len(n)] - rank(neg, ties.method = "average")) / m
    list(auc = mean(v1), v1 = v1, v0 = v0)
  }
  a <- placement(first); b <- placement(second)
  variance <- var(a$v1 - b$v1) / m + var(a$v0 - b$v0) / n
  diff <- a$auc - b$auc
  z <- if (variance == 0 && diff == 0) 0 else diff / sqrt(variance)
  c(auc_full = a$auc, auc_reduced = b$auc, difference = diff, z = z, p = 2 * pnorm(-abs(z)))
}

model_definitions <- function(family) {
  defs <- list()
  add <- function(group, full, hierarchy, variant = NULL, friends = FALSE, interaction = NULL) {
    label <- paste(c(group, if (full) "full" else "simple", paste(hierarchy, collapse = "+"), variant), collapse = "_")
    defs[[length(defs) + 1L]] <<- list(id = paste(family, label, sep = "__"), family = family,
      group = group, full = full, hierarchy = hierarchy, friends = friends, interaction = interaction)
  }
  if (family == "T5") {
    for (g in c("cap", "camp")) for (f in c(FALSE, TRUE)) add(g, f, c("steepness", "sameness"))
  } else if (family == "R_alt") {
    for (h in c("ratio", "absolute")) for (g in c("cap", "camp")) for (f in c(FALSE, TRUE)) add(g, f, h)
    for (h in c("distinct", "rank_sum", "admin")) for (g in c("cap", "camp")) add(g, TRUE, h)
  } else if (family == "R_friends") {
    for (g in c("cap", "camp")) add(g, TRUE, "friends")
    for (h in c("steepness", "sameness")) for (g in c("cap", "camp")) add(g, TRUE, h, "friends", friends = TRUE)
    for (h in c("unit_steepness", "unit_sameness")) for (g in c("cap", "camp")) add(g, TRUE, h, "friends", friends = TRUE)
  } else {
    allowed <- c("T4", "T6", "R_cc", "R_n50", "R_n100", "R_noexec", "R_ger", "R_jap", "R_aaf", "R_nosq", "R_int")
    if (!family %in% allowed) stop("Unknown model family: ", family)
    fulls <- if (family %in% c("R_cc", "R_nosq", "R_int")) TRUE else c(FALSE, TRUE)
    for (h in c("steepness", "sameness")) for (g in c("cap", "camp")) for (f in fulls)
      add(g, f, h, interaction = if (family == "T6") "officer" else if (family == "R_int") "men" else NULL)
  }
  defs
}
restrict_model <- function(d, def) {
  family <- def$family
  if (family == "R_cc") {
    vars <- c("height", "age", "education", "dependents", "officer", if (def$group == "camp") "distance")
    d <- d[complete.cases(d[, ..vars])]
  }
  if (family %in% c("R_n50", "R_n100")) d <- d[!is.na(n_g) & n_g >= if (family == "R_n50") 50 else 100]
  if (family == "R_noexec") d <- d[executed == 0]
  if (family == "R_ger") d <- d[DET_POWER == "1"]
  if (family == "R_jap") d <- d[DET_POWER == "2"]
  if (family == "R_aaf") d <- d[SERVICE_CODE == "1" & (ARM_SVC_CODE == "20" | ARM_SVC_ALPHA == "AC") & DET_POWER == "1"]
  copy(d)
}
design_matrix <- function(d, def) {
  vars <- def$hierarchy
  if (def$group == "camp" && !def$family %in% c("R_ger", "R_jap", "R_aaf")) vars <- c(vars, "japan")
  if (def$full) vars <- c(vars, "men", if (def$family != "R_nosq") "men_sq",
    if (def$group == "camp") "distance", "length", "height", "age", "education", "dependents", "officer")
  if (def$friends) vars <- c(vars, "friends")
  if (!is.null(def$interaction)) {
    vars <- unique(c(vars, def$interaction))
    for (h in def$hierarchy) {
      term <- paste(h, def$interaction, sep = ":")
      set(d, j = term, value = d[[h]] * d[[def$interaction]])
      vars <- c(vars, term)
    }
  }
  vars <- unique(vars); out <- list("(Intercept)" = rep(1, nrow(d))); omitted <- character()
  binary <- c("japan", "dependents", "officer")
  for (v in vars) {
    z <- d[[v]]; missing <- !is.finite(z); z[missing] <- 0
    if (length(unique(z)) > 1L) out[[v]] <- z else omitted <- c(omitted, v)
    if (any(missing) && !all(missing)) {
      term <- paste0(v, "_missing"); out[[term]] <- as.numeric(missing); binary <- c(binary, term)
    }
  }
  if (def$group == "cap") {
    camps <- sort(unique(d$camp))
    if (length(camps) > 1L) for (cc in camps[-1L]) out[[paste0("camp[", cc, "]")]] <- as.numeric(d$camp == cc)
  }
  X <- do.call(cbind, out); storage.mode(X) <- "double"
  q <- qr(X, tol = 1e-9); aliases <- character()
  if (q$rank < ncol(X)) {
    keep <- sort(q$pivot[seq_len(q$rank)]); aliases <- colnames(X)[-keep]; X <- X[, keep, drop = FALSE]
  }
  list(X = X, binary = binary, omitted = omitted, aliases = aliases)
}
result_template <- function() data.table(
  spec_id = character(), model_id = character(), family = character(), term = character(),
  coef = double(), coef_se = double(), me = double(), me_se = double(), me_p = double(),
  me_se_campcluster = double(), me_p_campcluster = double(), n = integer(), n_clusters = integer(),
  dropped_rows_pp = integer(), dropped_camps_pp = integer(), ll = double(), ll0 = double(),
  pseudo_r2 = double(), converged = logical(), status = character(), error = character())
roc_template <- function() data.table(spec_id = character(), model_id = character(), reduced_model_id = character(),
  row = character(), auc_full = double(), auc_reduced = double(), difference = double(), z = double(), p = double(),
  n = integer(), status = character(), error = character())
influence_template <- function() data.table(spec_id = character(), model_id = character(), deleted_camp = character(),
  me = double(), me_p = double(), n = integer(), status = character(), error = character())
fit_model <- function(input, def, spec_id, sample_path = NULL, forced_ids = NULL) {
  start <- proc.time()[[3]]; d <- input; dropped_rows <- 0L; dropped_camps <- 0L
  n_clusters <- NA_integer_; caught <- character(); fit <- NULL
  tryCatch(withCallingHandlers({
    d <- restrict_model(input, def)
    if (!is.null(forced_ids)) d <- d[record_seq %in% forced_ids]
    if (def$group == "cap") {
      pp <- d[, .(constant = uniqueN(survival) == 1L), by = camp][constant == TRUE, camp]
      dropped_rows <- sum(d$camp %in% pp); dropped_camps <- length(pp); d <- d[!camp %in% pp]
    }
    ids <- sort(d$record_seq)
    if (!is.null(sample_path)) writeLines(format(ids, scientific = FALSE, trim = TRUE), sample_path)
    if (!nrow(d) || uniqueN(d$survival) < 2L) stop("Empty sample or constant outcome")
    design <- design_matrix(copy(d), def); X <- design$X; y <- d$survival
    cluster <- d[[def$group]]; n_clusters <- uniqueN(cluster)
    fit <- glm.fit(X, y, family = binomial(link = "probit"), control = glm.control(epsilon = 1e-10, maxit = 150))
    beta <- fit$coefficients
    if (any(!is.finite(beta))) stop("Non-finite coefficient or weighted-design singularity")
    parts <- probit_parts(X, y, beta); cov <- cluster_cov(parts, cluster)
    effect <- marginal_effects(beta, colMeans(X), design$binary, cov)
    if (def$group == "cap") {
      campcov <- cluster_cov(parts, d$camp)
      camp_effect <- marginal_effects(beta, colMeans(X), design$binary, campcov)
    } else camp_effect <- list(se = rep(NA_real_, length(beta)), p = rep(NA_real_, length(beta)))
    eta <- drop(X %*% beta)
    ll <- sum(ifelse(y == 1, pnorm(eta, log.p = TRUE), pnorm(eta, lower.tail = FALSE, log.p = TRUE)))
    ll0 <- sum(dbinom(y, 1, mean(y), log = TRUE))
    status <- if (!fit$converged) "nonconverged" else if (length(caught)) "warning" else "ok"
    result <- data.table(spec_id = spec_id, model_id = def$id, family = def$family, term = names(beta),
      coef = unname(beta), coef_se = sqrt(pmax(0, diag(cov))), me = effect$me, me_se = effect$se, me_p = effect$p,
      me_se_campcluster = camp_effect$se, me_p_campcluster = camp_effect$p, n = nrow(d), n_clusters = n_clusters,
      dropped_rows_pp = dropped_rows, dropped_camps_pp = dropped_camps, ll = ll, ll0 = ll0,
      pseudo_r2 = 1 - ll / ll0, converged = fit$converged, status = status,
      error = paste(c(caught, if (length(design$aliases)) paste("Aliased columns omitted:", paste(design$aliases, collapse = ",")),
                      if (length(design$omitted)) paste("Constant columns omitted:", paste(design$omitted, collapse = ","))), collapse = "; "))
    # Preserve aliased terms as explicit non-estimable output rows.
    if (length(design$aliases)) {
      a <- result[rep(1L, length(design$aliases))]; a[, term := design$aliases]
      for (v in c("coef", "coef_se", "me", "me_se", "me_p", "me_se_campcluster", "me_p_campcluster")) set(a, j = v, value = NA_real_)
      a[, status := "aliased"]; result <- rbind(result, a)
    }
    list(result = result, ids = d$record_seq, prediction = pnorm(eta), y = y, camps = sort(unique(d$camp)),
         elapsed = proc.time()[[3]] - start, success = isTRUE(fit$converged))
  }, warning = function(w) { caught <<- unique(c(caught, conditionMessage(w))); invokeRestart("muffleWarning") }),
  error = function(e) {
    if (!is.null(sample_path)) writeLines(format(sort(d$record_seq), scientific = FALSE, trim = TRUE), sample_path)
    row <- result_template()[1L]
    row[, `:=`(spec_id = spec_id, model_id = def$id, family = def$family, term = "__fit__", n = nrow(d),
      n_clusters = n_clusters, dropped_rows_pp = dropped_rows, dropped_camps_pp = dropped_camps,
      converged = FALSE, status = "failed", error = paste(c(caught, conditionMessage(e)), collapse = "; "))]
    list(result = row, ids = d$record_seq, prediction = NULL, y = d$survival, camps = sort(unique(d$camp)),
         elapsed = proc.time()[[3]] - start, success = FALSE)
  })
}
append_csv <- function(x, path) {
  if (nrow(x)) fwrite(x, path, append = file.exists(path), col.names = !file.exists(path), na = "NA")
}
run_families <- function(groups, spec, families, out, influence_scope, quiet = FALSE) {
  cache <- new.env(parent = emptyenv()); spec_id <- spec$spec_id
  for (family in families) {
    if (family == "T5ROC") {
      for (def in model_definitions("T5")) for (omit in c("steepness", "sameness")) {
        retained <- setdiff(c("steepness", "sameness"), omit)
        reduced <- Filter(function(x) x$group == def$group && x$full == def$full && identical(x$hierarchy, retained), model_definitions("T4"))[[1]]
        row <- roc_template()[1L]; row[, `:=`(spec_id = spec_id, model_id = def$id, reduced_model_id = reduced$id, row = omit)]
        row <- tryCatch({
          if (!exists(def$id, cache, inherits = FALSE) || !exists(reduced$id, cache, inherits = FALSE)) stop("T5ROC requires T4 and T5 in this invocation")
          a <- get(def$id, cache); b <- get(reduced$id, cache)
          if (!a$success || !b$success) stop("A paired ROC fit failed or did not converge")
          if (!setequal(a$ids, b$ids)) stop("Paired ROC estimation rows differ")
          bi <- match(a$ids, b$ids)
          if (!identical(a$y, b$y[bi])) stop("Paired ROC outcomes differ")
          z <- delong(a$y, a$prediction, b$prediction[bi])
          for (v in names(z)) set(row, j = v, value = z[[v]])
          row[, `:=`(n = length(a$ids), status = "ok", error = "")]; row
        }, error = function(e) { row[, `:=`(status = "failed", error = conditionMessage(e))]; row })
        append_csv(row, file.path(out, "roc.csv"))
      }
      next
    }
    if (family == "INFLUENCE") {
      if (spec_id != "S000" || influence_scope == "none") next
      for (def in model_definitions("T4")) {
        if (!exists(def$id, cache, inherits = FALSE)) {
          row <- influence_template()[1L]; row[, `:=`(spec_id = spec_id, model_id = def$id, status = "failed", error = "INFLUENCE requires T4 in this invocation")]
          append_csv(row, file.path(out, "influence.csv")); next
        }
        origin <- get(def$id, cache); camps <- origin$camps
        if (influence_scope == "first20") camps <- head(camps, 20L)
        for (cc in camps) {
          d <- groups[[def$group]][record_seq %in% origin$ids & camp != cc]
          fit <- fit_model(d, def, spec_id)
          rr <- fit$result[term == def$hierarchy]
          row <- data.table(spec_id = spec_id, model_id = def$id, deleted_camp = cc,
            me = if (nrow(rr)) rr$me[1] else NA_real_, me_p = if (nrow(rr)) rr$me_p[1] else NA_real_,
            n = fit$result$n[1], status = if (nrow(rr)) rr$status[1] else "failed",
            error = if (nrow(rr)) rr$error[1] else paste("Hierarchy effect unavailable.", fit$result$error[1]))
          append_csv(row, file.path(out, "influence.csv"))
          if (!quiet) log_line(spec_id, def$id, "deleted", cc, row$status, "seconds", round(fit$elapsed, 3))
        }
      }
      next
    }
    for (def in model_definitions(family)) {
      path <- file.path(out, "sample_ids", paste0(spec_id, "__", def$id, ".txt"))
      fit <- fit_model(groups[[def$group]], def, spec_id, path)
      append_csv(fit$result, file.path(out, "results.csv"))
      if (family %in% c("T4", "T5")) assign(def$id, fit, cache)
      if (!quiet) log_line(spec_id, def$id, fit$result$status[1], "N", fit$result$n[1],
                          "clusters", fit$result$n_clusters[1], "seconds", round(fit$elapsed, 3), fit$result$error[1])
    }
  }
  invisible(NULL)
}

initialize_output <- function(out) {
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(out, "sample_ids"), showWarnings = FALSE)
  fwrite(result_template(), file.path(out, "results.csv"))
  fwrite(roc_template(), file.path(out, "roc.csv"))
  fwrite(influence_template(), file.path(out, "influence.csv"))
}
synthetic_checks <- function(test_dir) {
  dir.create(test_dir, recursive = TRUE, showWarnings = FALSE)
  rows <- list()
  check <- function(name, expr) {
    start <- proc.time()[[3]]
    result <- tryCatch({ detail <- force(expr); list(pass = TRUE, detail = as.character(detail)) },
                       error = function(e) list(pass = FALSE, detail = conditionMessage(e)))
    rows[[length(rows) + 1L]] <<- data.table(test = name, passed = result$pass,
      detail = paste(result$detail, collapse = "; "), seconds = proc.time()[[3]] - start)
    log_line("SYNTHETIC", name, if (result$pass) "PASS" else "FAIL", paste(result$detail, collapse = "; "))
  }
  set.seed(704203)
  check("known_probit_coefficients", {
    n <- 60000L; X <- cbind("(Intercept)" = 1, x = rnorm(n), binary = rbinom(n, 1, .4))
    truth <- c(-.35, .6, -.45); y <- rbinom(n, 1, pnorm(drop(X %*% truth)))
    fit <- glm.fit(X, y, family = binomial("probit"))
    parts <- probit_parts(X, y, fit$coefficients); se <- sqrt(diag(solve(parts$information)))
    z <- abs((fit$coefficients - truth) / se)
    stopifnot(fit$converged, max(z) < 4, max(abs(fit$coefficients - truth)) < .06)
    sprintf("max absolute error %.6g; max standardized error %.6g; n=%d", max(abs(fit$coefficients - truth)), max(z), n)
  })
  check("marginal_effects_and_delta_finite_differences", {
    beta <- c("(Intercept)" = -.2, x = .65, officer = -.4, "x:officer" = .13)
    mu <- c(1, .3, .4, .12); V <- matrix(c(.05,.01,0,0, .01,.04,0,0, 0,0,.03,.005, 0,0,.005,.02), 4)
    analytic <- marginal_effects(beta, mu, "officer", V)
    h <- 1e-5
    effect <- function(b) sapply(2:4, function(j) {
      plus <- minus <- mu
      if (j == 3) { plus[j] <- 1; minus[j] <- 0; denom <- 1 }
      else { plus[j] <- plus[j] + h; minus[j] <- minus[j] - h; denom <- 2 * h }
      (pnorm(sum(plus * b)) - pnorm(sum(minus * b))) / denom
    })
    jac <- sapply(1:4, function(j) { bp <- bm <- beta; bp[j] <- bp[j] + h; bm[j] <- bm[j] - h; (effect(bp) - effect(bm)) / (2*h) })
    numerical_se <- sqrt(diag(jac %*% V %*% t(jac)))
    err_me <- max(abs(effect(beta) - analytic$me[-1]))
    err_jac <- max(abs(jac - analytic$jacobian[-1, ])); err_se <- max(abs(numerical_se - analytic$se[-1]))
    stopifnot(err_me < 1e-8, err_jac < 2e-6, err_se < 2e-6)
    sprintf("ME error %.3g; Jacobian error %.3g; delta SE error %.3g", err_me, err_jac, err_se)
  })
  check("cluster_covariance_direct_sandwich", {
    X <- cbind(1, c(-1.5,-1,-.4,.2,.5,.8,1,1.5,1.7)); y <- c(0,1,0,1,0,1,1,0,1)
    b <- c(-.1,.35); cl <- c(1,1,2,2,2,3,3,4,4)
    parts <- probit_parts(X, y, b); got <- cluster_cov(parts, cl)
    eta <- drop(X %*% b); p <- pnorm(eta); f <- dnorm(eta)
    scores <- lapply(seq_along(y), function(i) X[i, ] * (y[i] - p[i]) * f[i] / (p[i] * (1 - p[i])))
    neg_hessian <- matrix(0, 2, 2); meat <- matrix(0, 2, 2)
    for (i in seq_along(y)) {
      derivative <- -eta[i] * f[i] * (y[i] - p[i]) / (p[i] * (1 - p[i])) -
        f[i]^2 / (p[i] * (1 - p[i])) -
        (y[i] - p[i]) * f[i]^2 * (1 - 2*p[i]) / (p[i]^2 * (1 - p[i])^2)
      neg_hessian <- neg_hessian - tcrossprod(X[i, ]) * derivative
    }
    for (g in unique(cl)) { s <- Reduce(`+`, scores[cl == g]); meat <- meat + tcrossprod(s) }
    direct <- 4/3 * solve(neg_hessian) %*% meat %*% solve(neg_hessian)
    err <- max(abs(got - direct)); stopifnot(err < 1e-11)
    sprintf("max covariance error %.3g", err)
  })
  check("handmade_hierarchy_groups", {
    p <- c(2,1,1,1,1,1,1,1,1) / 10
    one <- hierarchy_counts(c(0,0,7,0,0,0,0,0,0), p)
    equal <- hierarchy_counts(c(2,1,1,1,1,1,1,1,1), p)
    two <- hierarchy_counts(c(1,0,0,0,0,0,0,0,1), p)
    ranks <- c(1,1,2,3,4,5,6,7,8,9); n <- length(ranks)
    manual <- 1 + 1/n - 2*sum((n+1-seq_len(n))*ranks)/(n*sum(ranks))
    stopifnot(one['steepness'] == 0, equal['sameness'] == 1, abs(two['steepness'] - .4) < 1e-14,
              abs(equal['steepness'] - manual) < 1e-14,
              hierarchy_counts(c(1,rep(0,8)), p)['steepness'] == 0,
              all(is.na(hierarchy_counts(rep(0,9), p))))
    "single rank S=0; one member S=0; matching shares M=1; ranks 1,9 S=0.4; empty group missing"
  })
  check("delong_identical_and_tied_predictors", {
    y <- c(1,1,1,1,0,0,0,0,0); a <- c(.9,.5,.5,.2,.5,.1,.8,.2,.3); b <- c(.8,.7,.5,.1,.4,.1,.9,.2,.2)
    identical <- delong(y, a, a); stopifnot(identical['z'] == 0, identical['p'] == 1)
    placement <- function(s) outer(s[y == 1], s[y == 0], function(x,z) (x > z) + .5*(x == z))
    aa <- placement(a); bb <- placement(b)
    diff <- mean(aa) - mean(bb)
    variance <- var(rowMeans(aa-bb))/sum(y == 1) + var(colMeans(aa-bb))/sum(y == 0)
    expected <- diff / sqrt(variance); got <- delong(y,a,b)
    stopifnot(abs(got['z'] - expected) < 1e-12, abs(got['auc_full'] - mean(aa)) < 1e-12)
    sprintf("identical z=0, p=1; tied brute-force z error %.3g", abs(got['z']-expected))
  })
  check("NUL_safe_Parquet_pages", {
    path <- file.path(test_dir, "nul_fixture.parquet")
    values <- list(as.raw(c(65,0,66)), charToRaw(" C "), raw(0), NULL, as.raw(c(0,68,0)))
    nanoparquet::write_parquet(data.frame(value = I(values)), path)
    pages <- nanoparquet:::read_parquet_pages(path)
    got <- raw_column(path, 0L, pages)
    stopifnot(identical(got, c("AB", " C ", "", NA_character_, "D")))
    "NUL at beginning/middle/end removed; spaces, empty strings and null values preserved"
  })
  check("duplicate_linkage_and_missing_design", {
    e <- data.table(SER_NUM = c("A","A","B"), record_seq = c(4,2,3), CARD_NUM = c("1","1","3"),
                    HEIGHT = c("70","70",""), YR_BIRTH = c("20","21",""))
    stopifnot(identical(resolve_enl(e,"unmatched")$SER_NUM, "B"), resolve_enl(e,"first")[SER_NUM == "A", record_seq] == 2,
              resolve_enl(e,"combine")[SER_NUM == "A", HEIGHT] == "70", resolve_enl(e,"combine")[SER_NUM == "A", YR_BIRTH] == "")
    d <- data.table(steepness = c(NA,.2,.4,.5), japan = c(0,0,1,1), camp = c("1","1","2","2"))
    def <- Filter(function(z) z$group == "camp" && !z$full, model_definitions("T4"))[[1]]
    m <- design_matrix(d, def)
    stopifnot(m$X[1,"steepness"] == 0, identical(unname(m$X[,"steepness_missing"]), c(1,0,0,0)))
    "duplicate unmatched/first/combine; missing regressor zero replacement and indicator"
  })
  check("coordinate_selection_and_capital_override", {
    d <- data.table(CAMP=c("001","002","003","004","005"),DET_POWER=c("1","2","1","1","1"))
    cw <- data.table(camp_code=c("001","001","002","003","004"), entry_id=c("001b","001a","002","003","004"),
      confidence=c("exact","exact","unknown","exact","approximate"), latitude=c("0","","35","40","40"),
      longitude=c("0","","139","20","20"), identified_place_name=c("Elsewhere","Berlin","Tokyo","Place","Place"),
      nara_degree_coords_text=c("0-0","","35-139","40-20; 41-21",""))
    cross <- camp_distance(d,cw,"crosswalk"); degree <- camp_distance(d,cw,"nara_degree")
    stopifnot(cross[1]==0, is.na(cross[2]), is.na(cross[5]), is.finite(cross[3]),
              is.na(degree[3]), identical(cross[4],degree[4]))
    "lowest entry selected; eligible capital km=1; unknown/no row missing; malformed degree missing; absent degree falls back"
  })
  check("all_families_on_synthetic_data", {
    set.seed(9016); nc <- 12L; per_camp <- 440L; n <- nc * per_camp
    d <- data.table(record_seq = seq_len(n), camp = rep(sprintf("%03d", 1:nc), each = per_camp))
    d[, cap := paste(camp, rep(rep(1:4, each=110), nc), sep="|")]
    d[, rank := sample(1:9, .N, replace=TRUE, prob=runif(9,.3,2)), by=cap]
    d[, `:=`(unit = sample(c("u1","u2","u3",NA_character_), .N, TRUE),
      height = rnorm(.N,6.8,.3), age = runif(.N,.18,.6), education = sample(0:9,.N,TRUE)/10,
      dependents = rbinom(.N,1,.4), officer = as.integer(rank >= 5), distance = runif(.N,.1,.8),
      length = runif(.N,-1,4), japan = as.integer(num(camp)>6), valid_camp=TRUE, valid_month=TRUE, descriptive=TRUE,
      DET_POWER=ifelse(num(camp)>6,"2","1"), SERVICE_CODE="1", ARM_SVC_CODE="20", ARM_SVC_ALPHA="AC")]
    d[, survival := rbinom(.N,1,pnorm(.5-.6*japan+.2*officer-.1*length))]
    d[, executed := as.integer(survival==0 & runif(.N)<.15)]
    d[sample.int(n,100), height := NA_real_]; d[sample.int(n,80), education := NA_real_]
    params <- list(sample_common=TRUE,pop_fractions="descriptive",sameness_constant="fixed",group_members="regression",friends_def="incl_self")
    groups <- list(cap=attach_groups(d,params,"cap",TRUE),camp=attach_groups(d,params,"camp",TRUE))
    output <- file.path(test_dir,"synthetic_models"); initialize_output(output)
    families <- c("T4","T5","T5ROC","T6","R_cc","R_n50","R_n100","R_noexec","R_ger","R_jap","R_aaf","R_nosq","R_alt","R_friends","R_int","INFLUENCE")
    run_families(groups,list(spec_id="S000"),families,output,"first20",quiet=TRUE)
    rr <- fread(file.path(output,"results.csv")); roc <- fread(file.path(output,"roc.csv")); inf <- fread(file.path(output,"influence.csv"))
    expected <- sum(vapply(setdiff(families,c("T5ROC","INFLUENCE")), function(f) length(model_definitions(f)), integer(1)))
    stopifnot(uniqueN(rr$model_id)==expected, !any(rr$status %in% c("failed","nonconverged")), nrow(roc)==8L,
              all(roc$status=="ok"), nrow(inf)==96L, !any(inf$status %in% c("failed","nonconverged")))
    bad <- copy(groups$cap); bad[,survival:=1L]
    failed <- fit_model(bad,model_definitions("T4")[[1]],"TEST")
    stopifnot(failed$result$status[1]=="failed", failed$result$dropped_rows_pp[1]==n)
    sprintf("%d synthetic models, 8 paired ROC comparisons, 96 leave-camp-out fits; constant-outcome failure recorded",expected)
  })
  results <- rbindlist(rows)
  fwrite(results, file.path(test_dir,"test_results.csv"))
  writeLines(c("Deterministic synthetic checks; no real-data fitting.", capture.output(print(results))), file.path(test_dir,"test_log.txt"))
  if (!all(results$passed)) stop("Synthetic validation failed; see ", file.path(test_dir,"test_results.csv"))
  invisible(results)
}

parse_args <- function(args) {
  opts <- list(grid="grid.json",data="data",out="results",specs="S000",influence="none",families=NULL,
               test_only=FALSE,construct_only=FALSE)
  i <- 1L
  while (i <= length(args)) {
    key <- sub("^--", "", args[i]); key <- gsub("-", "_", key, fixed=TRUE)
    if (!startsWith(args[i],"--") || !key %in% names(opts)) stop("Unknown option: ",args[i])
    if (key %in% c("test_only","construct_only")) opts[[key]] <- TRUE
    else { i <- i+1L; if (i > length(args)) stop("Missing option value"); opts[[key]] <- args[i] }
    i <- i+1L
  }
  if (!opts$influence %in% c("all","first20","none")) stop("Invalid --influence")
  opts
}
main <- function(args = commandArgs(trailingOnly=TRUE)) {
  opts <- parse_args(args)
  grid <- jsonlite::fromJSON(opts$grid,simplifyVector=FALSE)
  root <- dirname(normalizePath(opts$grid,mustWork=TRUE))
  specs <- grid$specs; names(specs) <- vapply(specs,`[[`,character(1),"spec_id")
  requested <- if (opts$specs == "all") names(specs) else strsplit(opts$specs,",",fixed=TRUE)[[1]]
  if (any(!requested %in% names(specs))) stop("Unknown spec ids: ",paste(setdiff(requested,names(specs)),collapse=","))
  requested <- sort(unique(requested))
  initialize_output(opts$out)
  log_con <- file(file.path(opts$out,"run_log.txt"), open="wt")
  sink(log_con, split=TRUE)
  on.exit({ sink(); close(log_con) }, add=TRUE)
  log_line("P-R7M2 v1",R.version.string)
  log_line("Arguments:",paste(args,collapse=" "))
  log_line("Packages:",paste(c("data.table","nanoparquet","jsonlite"),
                            vapply(c("data.table","nanoparquet","jsonlite"),function(x)as.character(packageVersion(x)),character(1)),collapse="; "))
  synthetic_checks(file.path(root,"tests"))
  if (opts$test_only) return(invisible(NULL))
  started <- proc.time()[[3]]; inp <- load_inputs(opts$data,root)
  log_line("Input loading seconds",round(proc.time()[[3]]-started,3))
  for (id in requested) {
    spec <- specs[[id]]; families <- unlist(spec$families)
    if (!is.null(opts$families)) {
      wanted <- strsplit(opts$families,",",fixed=TRUE)[[1]]
      if (any(!wanted %in% unique(unlist(lapply(specs,`[[`,"families"))))) stop("Unknown --families value")
      families <- families[families %in% wanted]
    }
    if (!length(families)) next
    # Enforce INFLUENCE last, even for externally edited grid order.
    families <- c(setdiff(families,"INFLUENCE"),intersect(families,"INFLUENCE"))
    log_line("BEGIN",id,"families",paste(families,collapse=","))
    tryCatch({
      base <- construct_base(inp,spec$params)
      groups <- list(cap=attach_groups(base,spec$params,"cap","R_friends" %in% families),
                     camp=attach_groups(base,spec$params,"camp","R_friends" %in% families))
      if (!opts$construct_only) run_families(groups,spec,families,opts$out,opts$influence)
      log_line("END",id)
    }, error=function(e) {
      log_line("SPEC CONSTRUCTION FAILED",id,conditionMessage(e))
      for (family in setdiff(families,c("T5ROC","INFLUENCE"))) for (def in model_definitions(family)) {
        row <- result_template()[1L]; row[,`:=`(spec_id=id,model_id=def$id,family=family,term="__fit__",converged=FALSE,status="failed",error=conditionMessage(e))]
        append_csv(row,file.path(opts$out,"results.csv"))
        writeLines(character(),file.path(opts$out,"sample_ids",paste0(id,"__",def$id,".txt")))
      }
      if ("T5ROC" %in% families) {
        row <- roc_template()[1L]; row[,`:=`(spec_id=id,status="failed",error=conditionMessage(e))]
        append_csv(row,file.path(opts$out,"roc.csv"))
      }
      if ("INFLUENCE" %in% families && opts$influence != "none") {
        row <- influence_template()[1L]; row[,`:=`(spec_id=id,status="failed",error=conditionMessage(e))]
        append_csv(row,file.path(opts$out,"influence.csv"))
      }
    })
  }
  log_line("Run complete")
}
if (sys.nframe() == 0L) main()
