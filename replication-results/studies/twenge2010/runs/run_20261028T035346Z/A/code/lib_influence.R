# lib_influence.R -- leave-one-respondent-out refits of the S00 M4 model (MANIFEST Section 6)

influence_columns <- function() {
  ks <- paste0("K", 1:5); ps <- paste0("P", 1:3)
  d <- as.vector(t(outer(ks, ps, function(k, p) paste0("d_eq_", k, "_", p))))
  p <- as.vector(t(outer(ks, ps, function(k, p) paste0("p_", k, "_", p))))
  c("idx", "del_group", "del_V4", "status", "message", d, p)
}

# d_eq and p for the 15 contrasts from a fitted M4
influence_quantities <- function(fit, factors, nobs) {
  lat <- latent_outputs(fit, factors, 3L, nobs)
  ks <- names(factors); ps <- names(PAIRS)
  d <- c(); p <- c()
  for (K in ks) for (P in ps) {
    delta <- lat$deltas[[K]][[P]]$delta
    psa <- lat$by_group[[K]][[PAIRS[[P]][1]]]$psi; psb <- lat$by_group[[K]][[PAIRS[[P]][2]]]$psi
    d <- c(d, delta / sqrt((psa + psb) / 2))
    p <- c(p, lat$deltas[[K]][[P]]$pvalue)
  }
  c(d, p)
}

# Exact downdating of per-group sums: remove row x from (n, sum, SS about the mean)
downdate_moments <- function(mom, x) {
  n <- mom$nobs; m_old <- mom$sum / n
  n1 <- n - 1
  sum1 <- mom$sum - x
  m1 <- sum1 / n1
  # SS_new = SS_old - (n/(n-1)) (x - m_old)(x - m_old)'
  d <- x - m_old
  SS1 <- mom$SS - (n / n1) * tcrossprod(d)
  S1 <- SS1 / (n1 - 1)
  dimnames(S1) <- dimnames(mom$cov); names(m1) <- names(mom$mean)
  list(cov = S1, mean = m1, nobs = n1, SS = SS1, sum = sum1, divisor = "n-1")
}

run_influence <- function(D, root, start = 1L, limit = 10L, write = TRUE) {
  spec <- SPEC_DEFS$S00; est <- est_options(spec)
  factors <- MODEL_FACTORS; markers <- MARKERS_F4[names(factors)]; items <- MODEL_ITEMS
  samples <- list()
  for (y in YEARS) {
    s <- select_sample(D[[key_for(y, "f4")]], required = items, spec = spec)
    data.table::setorder(s, V4)
    samples[[y]] <- s
  }
  nobs <- vapply(samples, nrow, 0L)
  total <- sum(nobs)
  index <- data.table::rbindlist(lapply(YEARS, function(y) data.table(group = y, V4 = samples[[y]]$V4, row = seq_len(nobs[[y]]))))
  index$idx <- seq_len(nrow(index))
  moms <- lapply(YEARS, function(y) sample_moments(samples[[y]][, items, with = FALSE], divisor = "n-1")); names(moms) <- YEARS
  syntax <- do.call(build_syntax, c(list(factors = factors, markers = markers, G = 3L), model_options("M4", spec)))
  input_full <- list(type = "moments", cov = lapply(moms, `[[`, "cov"), mean = lapply(moms, `[[`, "mean"), nobs = unname(nobs))
  message("fitting full-sample M4 ...")
  full <- fit_lavaan(syntax, input_full, est)
  if (is.null(full$fit)) stop("full-sample M4 failed: ", full$error)
  full_q <- influence_quantities(full$fit, factors, nobs)
  end <- min(total, start + limit - 1L)
  if (start > total) stop("start exceeds sample size ", total)
  cols <- influence_columns()
  rows <- vector("list", end - start + 1L)
  deletions <- vector("list", end - start + 1L)
  times <- numeric(0)
  # full-sample analysis samples: n and SHA-256 of the ascending V4 list per year group (manifest Section 3)
  full_samples <- lapply(samples, sample_record)
  for (i in start:end) {
    g <- index$group[i]; r <- index$row[i]; v4 <- index$V4[i]
    t0 <- proc.time()[["elapsed"]]
    status <- "ok"; msg <- ""; q <- rep(NA_real_, 30)
    # analysis sample of this deletion: the full sample minus the deleted record (n and V4 hash per group)
    n_del <- nobs; n_del[[g]] <- nobs[[g]] - 1L
    hashes_del <- lapply(full_samples, `[[`, "sha256_V4")
    hashes_del[[g]] <- hash_v4(samples[[g]]$V4[-r])
    res <- tryCatch({
      x <- as.numeric(samples[[g]][r, items, with = FALSE])
      m_del <- moms; m_del[[g]] <- downdate_moments(moms[[g]], x)
      input <- list(type = "moments", cov = lapply(m_del, `[[`, "cov"), mean = lapply(m_del, `[[`, "mean"), nobs = unname(n_del))
      f <- fit_lavaan(syntax, input, est, start = full$fit)
      if (is.null(f$fit)) { status <- "error"; msg <- f$error }
      else {
        if (!f$converged) { status <- "not_converged"; msg <- paste(f$warnings, collapse = " | ") }
        else if (length(f$warnings)) msg <- paste(f$warnings, collapse = " | ")
        q <- influence_quantities(f$fit, factors, n_del)
      }
      NULL
    }, error = function(e) { status <<- "error"; msg <<- conditionMessage(e); NULL })
    el <- proc.time()[["elapsed"]] - t0
    times <- c(times, el)
    rows[[i - start + 1L]] <- c(list(idx = i, del_group = g, del_V4 = format_id(v4), status = status, message = msg), as.list(q))
    deletions[[i - start + 1L]] <- list(idx = i, del_group = g, del_V4 = format_id(v4), status = status,
                                        n_per_group = as.list(setNames(n_del, YEARS)), sha256_V4_per_group = hashes_del, seconds = el)
    message(sprintf("idx %d group %s V4 %s status %s (%.2f s)", i, g, format_id(v4), status, el))
  }
  out <- data.table::rbindlist(lapply(rows, as.data.table))
  data.table::setnames(out, cols)
  meta <- list(start = start, end = end, total_sample = total, n_per_group = as.list(nobs),
               full_sample = full_samples,                       # n and SHA-256 of the V4 list per group (S00 multigroup sample)
               seconds_per_deletion_mean = mean(times), seconds_per_deletion = times,
               full_sample_convergence = convergence_record(full), full_sample_quantities = as.list(setNames(full_q, cols[-(1:5)])),
               deletions = deletions,                            # per deletion: analysis n and V4 hash per group, status
               software = software_record())
  if (write) {
    dir.create(file.path(root, "results"), showWarnings = FALSE)
    path <- file.path(root, "results", sprintf("influence_%d_%d.csv", start, end))
    data.table::fwrite(out, path)
    jsonlite::write_json(meta, file.path(root, "results", sprintf("influence_%d_%d.meta.json", start, end)),
                         auto_unbox = TRUE, digits = NA, pretty = TRUE, na = "null", null = "null")
    message(sprintf("written %s ; mean %.2f s per deletion", path, mean(times)))
  }
  invisible(list(table = out, meta = meta))
}
