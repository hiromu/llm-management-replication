# lib_specs.R -- specification grid (MANIFEST Section 5) and JSON output (Section 7)

MANIFEST_ID <- "PAPER_X version 1"

SPEC_DEFS <- list(
  S00  = list(change = "none", outputs = c("items", "alpha", "single", "multigroup")),
  S01  = list(change = "weighted (V5)", weighted = TRUE, outputs = c("items", "alpha", "single", "multigroup")),
  S02  = list(change = "ML normalization: S divisor n, c_g = n", norm = "ml", outputs = "multigroup"),
  S03  = list(change = "samples restricted to records complete on all items of the form", complete_all = TRUE,
              outputs = c("items", "alpha", "single", "multigroup")),
  S04  = list(change = "FIML on raw data, records with >= 1 valid model item, c_g = n", fiml = TRUE, norm = "ml", outputs = "multigroup"),
  S05  = list(change = "effects-coding identification in M3-M5", effects = TRUE, outputs = "multigroup"),
  S06  = list(change = "MLR: ML estimates with Huber-White sandwich SEs, n normalization", mlr = TRUE, norm = "ml", outputs = "multigroup"),
  S07a = list(change = "seven-factor model with K6 = {V4239, V4237}, K7 = {V4241, V4247}", k67 = "a", outputs = c("single_f4_7", "alpha_K67")),
  S07b = list(change = "seven-factor model with K6 = {V4239, V4247}, K7 = {V4241, V4237}", k67 = "b", outputs = c("single_f4_7", "alpha_K67")),
  S08  = list(change = "Form 3 one-factor model on V3222-V3226 (V3222, V3223 reversed), V3227 excluded", outputs = c("single_f3_one", "alpha_S08")),
  CHK1 = list(change = "M4 identified by 1976 factor means 0 / variances 1, all loadings free and equal", chk1 = TRUE, outputs = "multigroup_M4"),
  CHK2 = list(change = "alternative markers K1 V4246, K2 V4225, K3 V4235, K4 V4245, K5 V4244", markers = "chk2", outputs = "multigroup")
)

est_options <- function(spec) {
  ml <- identical(spec$norm, "ml")
  list(likelihood = if (ml) "normal" else "wishart",
       estimator = if (isTRUE(spec$mlr)) "MLR" else "ML",
       missing = if (isTRUE(spec$fiml)) "fiml" else "listwise",
       information = "expected",
       divisor = if (ml) "n" else "n-1",
       input_type = if (isTRUE(spec$fiml) || isTRUE(spec$mlr)) "data" else "moments",
       cg_rule = if (ml) "n" else "n-1")
}

software_record <- function() {
  pk <- c("lavaan", "data.table", "jsonlite", "numDeriv", "sandwich", "readr")
  list(R = R.version.string, platform = R.version$platform,
       packages = as.list(setNames(vapply(pk, function(p) as.character(packageVersion(p)), ""), pk)),
       sessionInfo = paste(capture.output(print(sessionInfo())), collapse = "\n"))
}

k67_factors <- function(k67) {
  f <- FACTORS_F4
  if (identical(k67, "a")) { f$K6 <- c("V4239", "V4237"); f$K7 <- c("V4241", "V4247") }
  if (identical(k67, "b")) { f$K6 <- c("V4239", "V4247"); f$K7 <- c("V4241", "V4237") }
  f
}

# ---- item statistics (4.6) ---------------------------------------------------------------------
run_item_statistics <- function(D, spec) {
  res <- list()
  for (form in c("f4", "f3")) {
    items <- if (form == "f4") F4_ITEMS else F3_ITEMS
    fn <- function(y, it) select_sample(D[[key_for(y, form)]], required = it, spec = spec)
    r <- item_statistics(items, fn, weighted = isTRUE(spec$weighted))
    res[[paste0("form", substr(form, 2, 2))]] <- r
  }
  list(statistics = list(form4 = res$form4$items, form3 = res$form3$items),
       samples = list(form4 = res$form4$samples, form3 = res$form3$samples),
       test = if (isTRUE(spec$weighted)) "weighted z (v = s_w^2 sum w^2 / W^2), two-sided normal p" else "Student pooled t and Welch t, two-sided")
}

# ---- coefficient alpha (4.5) -------------------------------------------------------------------
run_alpha <- function(D, spec, scales) {
  out <- list(); samples <- list()
  for (sc in names(scales)) {
    items <- scales[[sc]]
    form <- if (all(items %in% F4_ITEMS)) "f4" else "f3"
    out[[sc]] <- list(items = items)
    for (y in YEARS) {
      s <- select_sample(D[[key_for(y, form)]], required = items, spec = spec)
      a <- coefficient_alpha(s[, items, with = FALSE], w = if (isTRUE(spec$weighted)) s$w else NULL)
      out[[sc]][[y]] <- a
      samples[[sc]][[y]] <- sample_record(s)
    }
  }
  list(alpha = out, samples = samples)
}

# ---- single-group CFA (4.1) --------------------------------------------------------------------
run_single_group <- function(D, spec, est, form, factors, markers, single_indicator = character(0), label = "") {
  items <- unname(unlist(factors))
  syntax <- build_syntax(factors, markers, G = 1L, ident = "marker", single_indicator = single_indicator)
  out <- list(model = label, items = items, factors = factors, markers = as.list(markers), syntax = as.character(syntax), by_year = list())
  for (y in YEARS) {
    fd <- D[[key_for(y, form)]]
    s <- select_sample(fd, required = items, spec = spec)
    mom <- sample_moments(s[, items, with = FALSE], w = if (isTRUE(spec$weighted)) s$w else NULL, divisor = est$divisor)
    input <- list(type = "moments", cov = setNames(list(mom$cov), y), mean = setNames(list(mom$mean), y), nobs = mom$nobs)
    f <- fit_lavaan(syntax, input, est)
    rec <- list(sample = sample_record(s), convergence = convergence_record(f))
    if (!is.null(f$fit)) {
      cg <- if (est$cg_rule == "n-1") mom$nobs - 1 else mom$nobs
      rec$fit <- tryCatch(fit_indices(f$fit, setNames(list(mom$cov), y), setNames(list(mom$mean), y), cg, mom$nobs, "manifest"),
                          error = function(e) list(error = conditionMessage(e)))
      rec$parameters <- param_table(f$fit)
    }
    out$by_year[[y]] <- rec
  }
  out
}

# ---- multigroup sequence (4.2-4.4) -------------------------------------------------------------
model_options <- function(M, spec) {
  ident_scalar <- if (isTRUE(spec$effects)) "effects" else "marker_scalar"
  switch(M,
    M1 = list(ident = "marker"),
    M2 = list(ident = "marker", loadings_equal = TRUE),
    M3 = list(ident = ident_scalar, loadings_equal = TRUE, intercepts_equal = TRUE),
    M4 = list(ident = ident_scalar, loadings_equal = TRUE, intercepts_equal = TRUE, released = RELEASED),
    M5 = list(ident = ident_scalar, loadings_equal = TRUE, intercepts_equal = TRUE, released = RELEASED, means_equal = TRUE),
    M4_CHK1 = list(ident = "fixed_factor", loadings_equal = TRUE, intercepts_equal = TRUE, released = RELEASED))
}

run_multigroup <- function(D, spec, est, models = c("M1", "M2", "M3", "M4", "M5"), latent_model = "M4") {
  factors <- MODEL_FACTORS
  markers <- if (identical(spec$markers, "chk2")) MARKERS_CHK2 else MARKERS_F4[names(factors)]
  items <- MODEL_ITEMS
  samples <- list(); moms <- list()
  for (y in YEARS) {
    fd <- D[[key_for(y, "f4")]]
    if (isTRUE(spec$fiml)) s <- select_sample(fd, required = character(0), spec = spec, any_of = items)
    else s <- select_sample(fd, required = items, spec = spec)
    samples[[y]] <- s
  }
  nobs <- vapply(samples, nrow, 0L)
  if (est$input_type == "moments") {
    for (y in YEARS) moms[[y]] <- sample_moments(samples[[y]][, items, with = FALSE],
                                                 w = if (isTRUE(spec$weighted)) samples[[y]]$w else NULL, divisor = est$divisor)
    input <- list(type = "moments", cov = lapply(moms, `[[`, "cov"), mean = lapply(moms, `[[`, "mean"), nobs = unname(nobs))
    cov_list <- input$cov; mean_list <- input$mean
  } else {
    stacked <- data.table::rbindlist(lapply(YEARS, function(y) { s <- samples[[y]][, c("V4", items), with = FALSE]; s$group <- y; s }))
    input <- list(type = "data", data = as.data.frame(stacked), group = "group")
    cov_list <- NULL; mean_list <- NULL
    if (!isTRUE(spec$fiml)) {
      for (y in YEARS) moms[[y]] <- sample_moments(samples[[y]][, items, with = FALSE], divisor = "n")
      cov_list <- lapply(moms, `[[`, "cov"); mean_list <- lapply(moms, `[[`, "mean")
    }
  }
  cg <- if (est$cg_rule == "n-1") nobs - 1 else nobs
  out <- list(items = items, factors = factors, markers = as.list(markers), released = RELEASED,
              estimation = est, n = as.list(nobs), c_g = as.list(setNames(cg, YEARS)),
              samples = lapply(samples, sample_record), models = list(), fits = list())
  if (isTRUE(spec$weighted)) out$weights <- lapply(samples, function(s) list(sum_V5 = sum(s$V5), n = nrow(s), sum_w_normalized = sum(s$w)))
  fitted <- list()
  prev_fit <- NULL
  for (M in models) {
    mo <- model_options(M, spec)
    syntax <- do.call(build_syntax, c(list(factors = factors, markers = markers, G = 3L), mo))
    f <- fit_lavaan(syntax, input, est)
    if (!is.null(f$fit) && !f$converged && !is.null(prev_fit)) {
      # one retry warm-started from the previous model in the sequence
      f2 <- fit_lavaan(syntax, input, est, start = prev_fit)
      f2$warnings <- c(f$warnings, "retry warm-started from previous model", f2$warnings)
      if (!is.null(f2$fit)) f <- f2
    }
    rec <- list(options = mo, syntax = as.character(syntax), fixed_via_partable = as.list(attr(syntax, "fixed")),
                convergence = convergence_record(f))
    if (!is.null(f$fit)) {
      cl <- cov_list; ml <- mean_list
      src <- "manifest"
      if (isTRUE(spec$fiml)) {
        h1 <- lavInspect(f$fit, "sampstat.h1")
        cl <- lapply(h1, `[[`, "cov"); ml <- lapply(h1, `[[`, "mean"); names(cl) <- names(ml) <- YEARS
        src <- "lavaan"
      } else if (isTRUE(spec$mlr)) src <- "lavaan"
      rec$fit <- tryCatch(fit_indices(f$fit, cl, ml, cg, nobs, src), error = function(e) list(error = conditionMessage(e)))
      if (isTRUE(spec$mlr)) rec$fit_scaled <- scaled_fit_record(f$fit)
      rec$group_labels <- lavInspect(f$fit, "group.label")
      rec$parameters <- param_table(f$fit)
      fitted[[M]] <- f$fit
      prev_fit <- f$fit
    }
    out$models[[M]] <- rec
  }
  # differences
  diffs <- list(c("M1", "M2"), c("M2", "M3"), c("M2", "M4"), c("M4", "M5"))
  out$differences <- list()
  for (d in diffs) {
    a <- d[1]; b <- d[2]
    if (!all(c(a, b) %in% models)) next
    fa <- out$models[[a]]$fit; fb <- out$models[[b]]$fit
    nm <- paste0(b, "-", a)
    if (is.null(fa) || is.null(fb) || !is.null(fa$error) || !is.null(fb$error)) { out$differences[[nm]] <- list(status = "unavailable", reason = "model fit missing"); next }
    out$differences[[nm]] <- fit_difference(fa, fb, a, b)
    if (isTRUE(spec$mlr)) out$differences[[nm]]$scaled <- scaled_difference(fitted[[a]], fitted[[b]])
  }
  # latent outputs and contrasts
  if (!is.null(fitted[[latent_model]])) {
    lat <- latent_outputs(fitted[[latent_model]], factors, 3L, nobs)
    obs_sd <- observed_scale_sd(samples, factors, weighted = isTRUE(spec$weighted))
    out$latent <- c(list(model = latent_model, se_type = if (isTRUE(spec$mlr)) "robust (sandwich, lavaan MLR)" else "expected information"), lat)
    out$contrasts <- list(model = latent_model, contrasts = standardized_contrasts(lat, factors, nobs, obs_sd), observed_scale_sd = obs_sd)
  } else {
    out$latent <- list(status = "unavailable", reason = paste(latent_model, "did not fit"))
    out$contrasts <- out$latent
  }
  out
}

# ---- spec runner -------------------------------------------------------------------------------
run_spec <- function(spec_id, D, root, write = TRUE) {
  spec <- SPEC_DEFS[[spec_id]]
  if (is.null(spec)) stop("unknown specification ", spec_id)
  est <- est_options(spec)
  t0 <- proc.time()[["elapsed"]]
  res <- list(spec_id = spec_id, manifest = MANIFEST_ID, change_from_S00 = spec$change, status = "ok", reason = NULL,
              timestamp_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
              software = software_record(),
              rows_read = lapply(D, function(fd) fd$rows_read),
              estimation_options = est,
              conventions = list(
                V4_hash = "SHA-256 (hex) of the ascending V4 values joined by '\\n' (no trailing newline), UTF-8",
                form3_reversals = list(V3222_r = "6 - V3222", V3223_r = "6 - V3223", V3227_r = "3 - V3227"),
                optimizer = "lavaan nlminb, rel.tol 1e-10, iter.max 10000",
                chi_square = "sum_g c_g F_g evaluated from lavaan implied moments and the sample moments (manifest formula); for FIML/MLR specs chi-square and baseline from lavaan",
                baseline = "free means and variances, zero covariances per group: F_g = sum log s_ii - log|S_g| (closed form) unless FIML/MLR",
                percentages = "0-100 scale"),
              deviations = list())
  if (isTRUE(spec$weighted)) {
    res$invalid_weights = lapply(D, function(fd) list(n_invalid_V5 = fd$n_invalid_weight, declared_missing = fd$v5_declared_missing))
  }
  outputs <- spec$outputs
  add_dev <- function(x) res$deviations[[length(res$deviations) + 1]] <<- x
  tryCatch({
    if ("items" %in% outputs) res$item_statistics <- run_item_statistics(D, spec)
    if ("alpha" %in% outputs) res$coefficient_alpha <- run_alpha(D, spec, c(FACTORS_F4, list(C1 = C1_ITEMS)))
    if ("alpha_K67" %in% outputs) res$coefficient_alpha <- run_alpha(D, spec, k67_factors(spec$k67)[c("K6", "K7")])
    if ("alpha_S08" %in% outputs) res$coefficient_alpha <- run_alpha(D, spec, list(S08_one_factor = S08_ITEMS))
    if ("single" %in% outputs) {
      res$single_group <- list(
        form3_C1C2 = run_single_group(D, spec, est, "f3", FACTORS_F3, MARKERS_F3, single_indicator = "C2", label = "4.1(a) Form 3 C1-C2"),
        form4_seven_factor = run_single_group(D, spec, est, "f4", FACTORS_F4, MARKERS_F4, label = "4.1(b) Form 4 K1-K7, 23 items"),
        form4_five_factor = run_single_group(D, spec, est, "f4", MODEL_FACTORS, MARKERS_F4[1:5], label = "4.1(c) Form 4 K1-K5, 19 items"))
    }
    if ("single_f4_7" %in% outputs) {
      f67 <- k67_factors(spec$k67)
      m67 <- vapply(f67, `[`, "", 1)   # marker = first listed item (K1-K5 unchanged; K6 V4239, K7 V4241)
      res$single_group <- list(form4_seven_factor = run_single_group(D, spec, est, "f4", f67, m67, label = paste0("4.1(b) ", spec$change)))
    }
    if ("single_f3_one" %in% outputs) {
      res$single_group <- list(form3_one_factor = run_single_group(D, spec, est, "f3", list(C1 = S08_ITEMS), c(C1 = "V3224"), label = "S08 Form 3 one factor"))
    }
    if ("multigroup" %in% outputs) res$multigroup <- run_multigroup(D, spec, est)
    if ("multigroup_M4" %in% outputs) res$multigroup <- run_multigroup(D, spec, est, models = "M4_CHK1", latent_model = "M4_CHK1")
  }, error = function(e) { res$status <<- "failed"; res$reason <<- conditionMessage(e) })
  # notes on conventions that the manifest leaves open
  if (isTRUE(spec$fiml)) {
    add_dev("S04: chi-square, df and baseline model taken from lavaan FIML (likelihood ratio against the saturated model); SRMR uses the saturated-model (EM) means and covariances as s_ij; d_obs uses the mean of the available (non-missing) items of each factor per record.")
  }
  if (isTRUE(spec$mlr)) {
    add_dev("S06: lavaan estimator = 'MLR' defaults used (se = robust.huber.white with observed information); ML chi-square from lavaan plus scaled chi-square and Satorra-Bentler scaled difference tests reported.")
  }
  if (isTRUE(spec$effects)) {
    add_dev("S05: effects-coding constraints implemented as linear equality constraints; released intercepts included in the per-group sum-to-zero constraints as specified, which changes df of M4/M5 relative to S00.")
  }
  if (isTRUE(spec$weighted)) {
    add_dev("S01: weights normalized within each analysis sample (per file) to sum to that sample's n; weighted covariance uses divisor n - 1 with normalized weights; d_obs uses the weighted SD (divisor n - 1) of the unit-weighted item means.")
  }
  res$elapsed_seconds <- proc.time()[["elapsed"]] - t0
  if (write) {
    dir.create(file.path(root, "results"), showWarnings = FALSE)
    path <- file.path(root, "results", paste0(spec_id, ".json"))
    jsonlite::write_json(res, path, auto_unbox = TRUE, digits = NA, pretty = TRUE, na = "null", null = "null", force = TRUE)
    message(sprintf("[%s] status=%s written %s (%.1f s)", spec_id, res$status, path, res$elapsed_seconds))
  }
  invisible(res)
}
