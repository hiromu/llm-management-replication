#!/usr/bin/env Rscript
## =====================================================================
## analysis.R -- Analysis manifest PX01
##
## Usage:
##   Rscript analysis.R --data DIR --out DIR --seed 20261031 --boot 5000
##
## Reads DIR/dataset_1.csv ... dataset_4.csv and writes to --out:
##   results.csv, influence.csv, samples.csv, session_info.txt
##
## The script never stops on a single failure: every quantity is computed
## inside a guard and a failed quantity is written with status "failed".
## =====================================================================

suppressPackageStartupMessages({
  library(sandwich)   # HC covariance matrices
  library(lme4)       # linear mixed models
})

## ---------------------------------------------------------------------
## 0. Command line
## ---------------------------------------------------------------------
argv <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- match(flag, argv)
  if (is.na(i) || i == length(argv)) return(default)
  argv[i + 1]
}
DATA_DIR <- get_arg("--data", ".")
OUT_DIR  <- get_arg("--out", ".")
SEED     <- as.integer(get_arg("--seed", "20261031"))
NBOOT    <- as.integer(get_arg("--boot", "5000"))
ZCRIT    <- 1.96      # the manifest fixes the normal critical value at 1.96
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

## ---------------------------------------------------------------------
## 1. Output stores and emission helpers
## ---------------------------------------------------------------------
RESULTS <- list(); N_RES  <- 0L
INFL    <- list(); N_INFL <- 0L
SAMPLES <- list()

fmt_num <- function(v) {
  if (length(v) != 1 || is.na(v) || !is.finite(v)) return("")
  sprintf("%.17g", as.numeric(v))
}

add_result <- function(dataset, sl, cl, key, method, value = NA_real_,
                       status = "ok", message = "") {
  N_RES <<- N_RES + 1L
  RESULTS[[N_RES]] <<- c(dataset = dataset, sample_level = sl,
                         composite_level = cl, key = key, method = method,
                         value = fmt_num(value), status = status,
                         message = message)
}

add_infl <- function(dataset, sl, estimand, unit, estimate, p, status, message) {
  N_INFL <<- N_INFL + 1L
  INFL[[N_INFL]] <<- c(dataset = dataset, sample_level = sl, estimand = estimand,
                       deleted_unit = as.character(unit),
                       estimate = fmt_num(estimate), p = fmt_num(p),
                       status = status, message = message)
}

## emit(): evaluate fn() (which returns a named list/vector of quantities)
## and write one row per name in qnames. Any error, or any non-finite value,
## becomes a failed row with a reason. The run never stops here.
emit <- function(dataset, sl, cl, prefix, method, qnames, fn) {
  vals <- tryCatch(fn(), error = function(e) e)
  if (inherits(vals, "error")) {
    msg <- conditionMessage(vals)
    for (q in qnames)
      add_result(dataset, sl, cl, paste(prefix, q, sep = "."), method,
                 NA_real_, "failed", msg)
    return(invisible(NULL))
  }
  reasons <- if (is.list(vals) && !is.null(vals[[".reasons"]])) vals[[".reasons"]] else list()
  for (q in qnames) {
    v <- if (q %in% names(vals)) vals[[q]] else NULL
    key <- paste(prefix, q, sep = ".")
    if (is.null(v) || length(v) != 1 || is.na(v) || !is.finite(v)) {
      msg <- if (!is.null(reasons[[q]])) reasons[[q]] else "value is missing or not finite"
      add_result(dataset, sl, cl, key, method, NA_real_, "failed", msg)
    } else {
      add_result(dataset, sl, cl, key, method, v, "ok", "")
    }
  }
  invisible(NULL)
}

## guard(): evaluate an expression that writes many rows; if the whole block
## errors, record one failed row under the given key so nothing is silent.
guard <- function(dataset, sl, cl, key, method, expr) {
  res <- tryCatch({ expr; NULL }, error = function(e) e)
  if (inherits(res, "error"))
    add_result(dataset, sl, cl, key, method, NA_real_, "failed",
               paste("block failed:", conditionMessage(res)))
  invisible(NULL)
}

## ---------------------------------------------------------------------
## 2. Reading and basic helpers
## ---------------------------------------------------------------------
read_text_csv <- function(path) {
  read.csv(path, colClasses = "character", check.names = FALSE,
           fileEncoding = "UTF-8-BOM", na.strings = character(0))
}

num <- function(x) suppressWarnings(as.numeric(trimws(as.character(x))))

## Numeric copy of a column; a missing column becomes all-NA (reported later
## as missing values) so the rest of the run proceeds.
getnum <- function(raw, name) {
  if (!name %in% names(raw)) {
    warning(sprintf("column '%s' not found; treated as missing", name), call. = FALSE)
    return(rep(NA_real_, nrow(raw)))
  }
  num(raw[[name]])
}

## Composite: mean / sum computed from items (missing if any item missing),
## or the deposited column for level "existing".
composite <- function(raw, items, level, existing) {
  if (level == "existing") return(getnum(raw, existing))
  M <- do.call(cbind, lapply(items, function(it) getnum(raw, it)))
  if (level == "mean") rowMeans(M) else rowSums(M)
}

cc_rows <- function(d, vars) d[complete.cases(d[, vars, drop = FALSE]), , drop = FALSE]

corr_key <- function(a, b) paste(sort(c(a, b), method = "radix"), collapse = "|")

mean_sd <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) < 1) stop("no complete cases")
  list(mean = mean(x), sd = if (length(x) >= 2) sd(x) else NA_real_)
}

pearson_r <- function(x, y) {
  ok <- !is.na(x) & !is.na(y)
  if (sum(ok) < 3) stop("fewer than 3 complete pairs")
  cor(x[ok], y[ok])
}

cronbach_alpha <- function(M) {
  M <- as.matrix(M)
  M <- M[complete.cases(M), , drop = FALSE]
  k <- ncol(M)
  if (nrow(M) < 3) stop("fewer than 3 complete cases on the items")
  if (k < 2) stop("fewer than 2 items")
  k / (k - 1) * (1 - sum(apply(M, 2, var)) / var(rowSums(M)))
}

two_sample_t <- function(x, y, equal_var) {
  x <- x[!is.na(x)]; y <- y[!is.na(y)]
  if (length(x) < 2 || length(y) < 2) stop("fewer than 2 observations in a group")
  r <- t.test(x, y, var.equal = equal_var)
  list(t = unname(r$statistic), df = unname(r$parameter), p = r$p.value)
}

paired_t <- function(a, b) {
  ok <- !is.na(a) & !is.na(b)
  if (sum(ok) < 2) stop("fewer than 2 complete pairs")
  r <- t.test(a[ok], b[ok], paired = TRUE)
  list(t = unname(r$statistic), df = unname(r$parameter), p = r$p.value)
}

## HC p value: OLS of y on a regressor (or intercept only), sandwich HC
## covariance, normal reference distribution. Two-sided.
hc_p <- function(y, x = NULL, type = "HC3") {
  ok <- !is.na(y) & (if (is.null(x)) TRUE else !is.na(x))
  y <- y[ok]
  fit <- if (is.null(x)) lm(y ~ 1) else { x <- x[ok]; lm(y ~ x) }
  b <- coef(fit)
  if (any(is.na(b))) stop("singular design for HC test")
  V <- vcovHC(fit, type = type)
  j <- length(b)
  z <- b[j] / sqrt(V[j, j])
  2 * pnorm(-abs(z))
}

pooled_sd <- function(a, b) {
  na <- length(a); nb <- length(b)
  sqrt(((na - 1) * var(a) + (nb - 1) * var(b)) / (na + nb - 2))
}

## Fast OLS with classical covariance (used by path models and bootstraps).
ols <- function(y, X) {
  fit <- lm.fit(X, y)
  if (fit$rank < ncol(X)) stop("rank-deficient OLS design")
  b <- fit$coefficients
  if (any(!is.finite(b))) stop("non-finite OLS coefficients")
  df <- length(y) - ncol(X)
  if (df < 1) stop("no residual degrees of freedom")
  s2 <- sum(fit$residuals^2) / df
  V <- s2 * chol2inv(qr.R(fit$qr))
  dimnames(V) <- list(colnames(X), colnames(X))
  names(b) <- colnames(X)
  list(coef = b, vcov = V)
}

## Fast logistic regression by ML (IRLS) with model-based covariance.
logit_fit <- function(y, X) {
  if (!all(y %in% c(0, 1))) stop("binary outcome must be coded 0/1")
  fit <- suppressWarnings(glm.fit(X, y, family = binomial()))
  if (!isTRUE(fit$converged)) stop("logistic fit did not converge")
  if (fit$rank < ncol(X)) stop("rank-deficient logistic design")
  b <- fit$coefficients
  if (any(!is.finite(b))) stop("non-finite logistic coefficients")
  V <- chol2inv(qr.R(fit$qr))
  dimnames(V) <- list(colnames(X), colnames(X))
  names(b) <- colnames(X)
  list(coef = b, vcov = V)
}

design <- function(d, vars) {
  X <- cbind(1, as.matrix(d[, vars, drop = FALSE]))
  colnames(X) <- c("(Intercept)", vars)
  X
}

## ---------------------------------------------------------------------
## 3. Bootstrap (units = rows of d; one seeded stream per model)
## ---------------------------------------------------------------------
## stat_fn(d) returns a named numeric vector of estimates and must stop()
## when the fit fails. Returns per-estimate se_boot, BC and percentile CIs,
## plus the number of discarded resamples.
run_boot <- function(d, stat_fn, B, seed) {
  est <- stat_fn(d)
  n <- nrow(d)
  set.seed(seed)
  draws <- matrix(NA_real_, nrow = B, ncol = length(est),
                  dimnames = list(NULL, names(est)))
  failed <- 0L
  for (b in seq_len(B)) {
    idx <- sample.int(n, n, replace = TRUE)
    r <- tryCatch(stat_fn(d[idx, , drop = FALSE]), error = function(e) NULL)
    if (is.null(r) || any(!is.finite(r))) { failed <- failed + 1L; next }
    draws[b, ] <- r
  }
  draws <- draws[complete.cases(draws), , drop = FALSE]
  stats <- lapply(names(est), function(nm) {
    th <- est[[nm]]; bs <- draws[, nm]
    if (length(bs) < 2) stop("fewer than 2 successful resamples")
    z0 <- qnorm((sum(bs < th) + 0.5 * sum(bs == th)) / length(bs))
    bc <- if (is.finite(z0)) {
      c(quantile(bs, pnorm(2 * z0 - ZCRIT), names = FALSE),
        quantile(bs, pnorm(2 * z0 + ZCRIT), names = FALSE))
    } else c(NA_real_, NA_real_)
    list(se_boot = sd(bs), ci_bc_low = bc[1], ci_bc_high = bc[2],
         ci_perc_low = quantile(bs, 0.025, names = FALSE),
         ci_perc_high = quantile(bs, 0.975, names = FALSE),
         .reasons = list(ci_bc_low = "all resamples on one side of the estimate; z0 infinite",
                         ci_bc_high = "all resamples on one side of the estimate; z0 infinite"))
  })
  names(stats) <- names(est)
  list(stats = stats, boot_failed = failed)
}

BOOT_Q <- c("se_boot", "ci_bc_low", "ci_bc_high", "ci_perc_low", "ci_perc_high")

## Write bootstrap rows for a model whose estimates are named by `units`
## (e.g. mediators); prefix_fn(unit) gives the key prefix for each.
emit_boot <- function(dataset, sl, cl, method, units, prefix_fn, d, stat_fn) {
  br <- tryCatch(run_boot(d, stat_fn, NBOOT, SEED), error = function(e) e)
  for (u in units) {
    emit(dataset, sl, cl, prefix_fn(u), method, BOOT_Q, function() {
      if (inherits(br, "error")) stop(conditionMessage(br))
      br$stats[[u]]
    })
    emit(dataset, sl, cl, prefix_fn(u), method, "boot_failed", function() {
      if (inherits(br, "error")) stop(conditionMessage(br))
      list(boot_failed = br$boot_failed)
    })
  }
}

## ---------------------------------------------------------------------
## 4. Shared descriptive / reliability blocks
## ---------------------------------------------------------------------
desc_block <- function(dataset, sl, cl, prefix, d, vars) {
  for (v in vars) {
    emit(dataset, sl, cl, paste0(prefix, ".mean"), "descriptive", v,
         function() setNames(list(mean_sd(d[[v]])$mean), v))
    emit(dataset, sl, cl, paste0(prefix, ".sd"), "descriptive", v,
         function() setNames(list(mean_sd(d[[v]])$sd), v))
  }
  if (length(vars) >= 2) {
    pairs <- combn(vars, 2)
    for (j in seq_len(ncol(pairs))) {
      a <- pairs[1, j]; b <- pairs[2, j]
      emit(dataset, sl, cl, paste0(prefix, ".r"), "descriptive", corr_key(a, b),
           function() setNames(list(pearson_r(d[[a]], d[[b]])), corr_key(a, b)))
    }
  }
}

alpha_item <- function(dataset, sl, cl, key_prefix, d, items) {
  emit(dataset, sl, cl, key_prefix, "descriptive", "alpha",
       function() list(alpha = cronbach_alpha(d[, items, drop = FALSE])))
}

r_item <- function(dataset, sl, cl, key_prefix, d, items) {
  emit(dataset, sl, cl, key_prefix, "descriptive", "r",
       function() list(r = pearson_r(d[[items[1]]], d[[items[2]]])))
}

## ---------------------------------------------------------------------
## 5. Dataset 1: within-person loyal versus control
## ---------------------------------------------------------------------
SCENARIOS <- c("1" = "sexual_harassment", "2" = "theft", "3" = "false_advertising",
               "4" = "fraud", "5" = "bribery", "6" = "plagiarism", "7" = "dishonesty")
GENDERS <- c(female = 1, male = 2)
D1_OUT3 <- c("you_grant", "prom_voice", "proh_voice")
D1_OUT  <- c(D1_OUT3, "loyal_comb")
R1_ITEMS <- list(magnitude = c("magnitude1_rev", "magnitude2"),
                 prob_of_effect = c("prob_effect1", "prob_effect2_rev"),
                 temp_immediacy = c("temp_imm1", "temp_imm2_rev"),
                 proximity_effect = c("proxim_eff1_rev", "proxim_eff2"),
                 social_consensus = c("social_cons1", "social_cons2_rev"),
                 concentration_of_effect = c("concen_eff1_rev", "concen_eff2"))

prep1 <- function(raw, cl) {
  d <- data.frame(.row = seq_len(nrow(raw)),
                  .pid = trimws(as.character(raw[["part_uid"]])),
                  cond = tolower(trimws(as.character(raw[["cond"]]))),
                  stringsAsFactors = FALSE)
  for (v in c("cond_recode", "wrongdoing_num", "gender", "age", "attn",
              D1_OUT3, "loyal1", "loyal2", "loyal3",
              "pie1", "pie2", "pie3", "pie4_rev", unlist(R1_ITEMS)))
    d[[v]] <- getnum(raw, v)
  d$loyal_comb <- composite(raw, c("loyal1", "loyal2", "loyal3"), cl, "loyal_comb")
  d
}

## Persons retained under a sample level (file order of first appearance).
persons_keep1 <- function(d, sl) {
  all_p <- unique(d$.pid)
  if (sl == "D1_key") {
    ok <- !is.na(d$attn) & !is.na(d$wrongdoing_num) & d$attn == d$wrongdoing_num
    bad <- unique(d$.pid[!ok])
    all_p <- all_p[!all_p %in% bad]
  }
  all_p
}

## One row per person with exactly one loyal and one control row.
## Person-level covariates come from the person's first row in file order.
wide1 <- function(d) {
  pids <- unique(d$.pid)
  nl <- tapply(d$cond == "loyal", d$.pid, sum)
  nc <- tapply(d$cond == "control", d$.pid, sum)
  ok <- names(nl)[nl == 1 & nc == 1]
  keep <- pids[pids %in% ok]
  L <- d[d$cond == "loyal", ];   L <- L[match(keep, L$.pid), ]
  C <- d[d$cond == "control", ]; C <- C[match(keep, C$.pid), ]
  F1 <- d[!duplicated(d$.pid), ]; F1 <- F1[match(keep, F1$.pid), ]
  w <- data.frame(.pid = keep, wrongdoing_num = F1$wrongdoing_num,
                  gender = F1$gender, age = F1$age, stringsAsFactors = FALSE)
  for (o in D1_OUT) { w[[paste0("L.", o)]] <- L[[o]]; w[[paste0("C.", o)]] <- C[[o]] }
  w
}

paired_stats <- function(a, b) {
  ok <- !is.na(a) & !is.na(b)
  a <- a[ok]; b <- b[ok]; n <- length(a)
  if (n < 2) stop("fewer than 2 complete pairs")
  dif <- a - b
  md <- mean(dif); sdd <- sd(dif); se <- sdd / sqrt(n)
  tt <- md / se; df <- n - 1
  list(mean_loyal = mean(a), sd_loyal = sd(a), mean_control = mean(b),
       sd_control = sd(b), mean_diff = md, se_diff = se, t = tt, df = df,
       p = 2 * pt(-abs(tt), df), n = n,
       d = md / sqrt((var(a) + var(b)) / 2), dz = md / sdd,
       p_hc3 = hc_p(dif, NULL, "HC3"))
}

anova_diff <- function(dif, wd) {
  ok <- !is.na(dif) & !is.na(wd)
  dif <- dif[ok]; W <- factor(wd[ok])
  if (nlevels(W) < 2) stop("fewer than 2 wrongdoing levels")
  a <- anova(lm(dif ~ W))
  list(F = a[["F value"]][1], df1 = a[["Df"]][1], df2 = a[["Df"]][2], p = a[["Pr(>F)"]][1])
}

main_effect_diff <- function(dif, wd) {
  ok <- !is.na(dif) & !is.na(wd)
  dif <- dif[ok]; W <- factor(wd[ok])
  fit <- if (nlevels(W) >= 2) lm(dif ~ W, contrasts = list(W = "contr.sum")) else lm(dif ~ 1)
  s <- summary(fit)$coefficients
  tt <- s["(Intercept)", "t value"]
  list(F = tt^2, df1 = 1, df2 = fit$df.residual, p = s["(Intercept)", "Pr(>|t|)"])
}

lmm1 <- function(d, o, nested) {
  vars <- c(o, "cond_recode", ".pid", if (nested) "wrongdoing_num")
  dd <- cc_rows(d, vars)
  dd$pid <- factor(dd$.pid)
  dd$wd <- factor(dd$wrongdoing_num)
  f <- if (nested) as.formula(paste(o, "~ cond_recode + (1 | wd/pid)"))
       else as.formula(paste(o, "~ cond_recode + (1 | pid)"))
  fit <- suppressMessages(lmer(f, data = dd, REML = TRUE))
  s <- summary(fit)$coefficients
  b <- s["cond_recode", "Estimate"]; se <- s["cond_recode", "Std. Error"]
  list(coef = b, se = se, p = 2 * pnorm(-abs(b / se)))
}

analyze_d1 <- function(raw) {
  ds <- "1"
  for (sl in c("D1_key", "D1_none")) {
    for (cl in c("mean", "sum", "existing")) {
      d <- prep1(raw, cl)
      keep <- persons_keep1(d, sl)
      d <- d[d$.pid %in% keep, ]
      if (cl == "mean") SAMPLES[[length(SAMPLES) + 1]] <<-
        data.frame(dataset = ds, sample_level = sl, unit_id = keep, stringsAsFactors = FALSE)
      w <- wide1(d)

      ## P1: paired quantities
      for (o in D1_OUT)
        emit(ds, sl, cl, paste0("P1.", o), "paired",
             c("mean_loyal", "sd_loyal", "mean_control", "sd_control", "mean_diff",
               "se_diff", "t", "df", "p", "n", "d", "dz", "p_hc3"),
             function() paired_stats(w[[paste0("L.", o)]], w[[paste0("C.", o)]]))

      ## M1 / ME1 / LMM1
      for (o in D1_OUT3) {
        dif <- w[[paste0("L.", o)]] - w[[paste0("C.", o)]]
        emit(ds, sl, cl, paste0("M1.", o), "mixed_anova", c("F", "df1", "df2", "p"),
             function() anova_diff(dif, w$wrongdoing_num))
        emit(ds, sl, cl, paste0("ME1.", o), "mixed_anova", c("F", "df1", "df2", "p"),
             function() main_effect_diff(dif, w$wrongdoing_num))
        emit(ds, sl, cl, paste0("LMM1.", o), "ri_person", c("coef", "se", "p"),
             function() lmm1(d, o, FALSE))
        emit(ds, sl, cl, paste0("LMM1.", o), "ri_person_wrongdoing", c("coef", "se", "p"),
             function() lmm1(d, o, TRUE))
      }

      ## D1 descriptives on all retained rows, stacked
      desc_block(ds, sl, cl, "D1", d, c("cond_recode", D1_OUT3))

      ## R1 reliability
      alpha_item(ds, sl, cl, "R1.loyal_comb", d, c("loyal1", "loyal2", "loyal3"))
      alpha_item(ds, sl, cl, "R1.perceived_ethic_import", d, c("pie1", "pie2", "pie3", "pie4_rev"))
      for (nm in names(R1_ITEMS)) r_item(ds, sl, cl, paste0("R1.", nm), d, R1_ITEMS[[nm]])

      ## N1
      emit(ds, sl, cl, "N1", "descriptive", "rows", function() list(rows = nrow(d)))
      emit(ds, sl, cl, "N1", "descriptive", "n", function() list(n = nrow(w)))
      first <- d[!duplicated(d$.pid), ]
      emit(ds, sl, cl, "N1.age", "descriptive", c("mean", "sd"), function() mean_sd(first$age))

      ## G1W: loyal versus control within gender (and scenario)
      for (s in c("sexual_harassment", "all")) for (g in names(GENDERS)) {
        prefix <- paste("G1W", s, g, sep = ".")
        rs <- d[!is.na(d$gender) & d$gender == GENDERS[[g]] &
                (s == "all" | (!is.na(d$wrongdoing_num) & d$wrongdoing_num == 1)), ]
        ws <- w[!is.na(w$gender) & w$gender == GENDERS[[g]] &
                (s == "all" | (!is.na(w$wrongdoing_num) & w$wrongdoing_num == 1)), ]
        emit(ds, sl, cl, prefix, "paired", c("t", "df", "p"),
             function() paired_t(ws[["L.you_grant"]], ws[["C.you_grant"]]))
        emit(ds, sl, cl, prefix, "student", c("t", "df", "p"),
             function() two_sample_t(rs$you_grant[rs$cond == "loyal"],
                                     rs$you_grant[rs$cond == "control"], TRUE))
        emit(ds, sl, cl, prefix, "welch", c("t", "df", "p"),
             function() two_sample_t(rs$you_grant[rs$cond == "loyal"],
                                     rs$you_grant[rs$cond == "control"], FALSE))
      }

      ## G1C: male minus female within condition and scenario
      for (wn in c(names(SCENARIOS), "average")) for (cnd in c("loyal", "control")) {
        wname <- if (wn == "average") "average" else SCENARIOS[[wn]]
        prefix <- paste("G1C", wname, cnd, sep = ".")
        in_scen <- if (wn == "average") rep(TRUE, nrow(d)) else
          (!is.na(d$wrongdoing_num) & d$wrongdoing_num == as.numeric(wn))
        rs <- d[d$cond == cnd & !is.na(d$gender) & d$gender %in% c(1, 2) & in_scen, ]
        xm <- rs$you_grant[rs$gender == 2]; xf <- rs$you_grant[rs$gender == 1]
        emit(ds, sl, cl, prefix, "descriptive",
             c("mean_male", "sd_male", "mean_female", "sd_female"),
             function() { m <- mean_sd(xm); f <- mean_sd(xf)
               list(mean_male = m$mean, sd_male = m$sd, mean_female = f$mean, sd_female = f$sd) })
        emit(ds, sl, cl, prefix, "student", c("t", "df", "p"), function() two_sample_t(xm, xf, TRUE))
        emit(ds, sl, cl, prefix, "welch", c("t", "df", "p"), function() two_sample_t(xm, xf, FALSE))
      }
    }
  }
}

loo_d1 <- function(raw) {
  ds <- "1"
  for (sl in c("D1_key", "D1_none")) {
    d <- prep1(raw, "mean")
    keep <- persons_keep1(d, sl)
    d <- d[d$.pid %in% keep, ]
    for (u in keep) {
      w <- tryCatch(wide1(d[d$.pid != u, ]), error = function(e) e)
      for (o in D1_OUT3) {
        r <- tryCatch({
          if (inherits(w, "error")) stop(conditionMessage(w))
          ps <- paired_stats(w[[paste0("L.", o)]], w[[paste0("C.", o)]])
          list(est = ps$mean_diff, p = ps$p)
        }, error = function(e) e)
        if (inherits(r, "error")) add_infl(ds, sl, paste0("P1.", o), u, NA, NA, "failed", conditionMessage(r))
        else add_infl(ds, sl, paste0("P1.", o), u, r$est, r$p, "ok", "")
      }
    }
  }
}

## ---------------------------------------------------------------------
## 6. Dataset 2: two independent groups, mediation
## ---------------------------------------------------------------------
D2_OUT  <- c("you_grant", "prom_voice", "proh_voice")
D2_MED  <- c("benev_trust_broker", "integ_trust_broker", "val_align_part_broker", "relconcerns_with_broker")
MED_ITEMS <- list(benev_trust_broker = c("bentrust_broker1", "bentrust_broker2", "bentrust_broker3"),
                  integ_trust_broker = c("inttrust_broker1", "inttrust_broker2", "inttrust_broker3"),
                  val_align_part_broker = c("me_broker_valal1", "me_broker_valal2"),
                  relconcerns_with_broker = c("broker_rep1", "broker_rep2", "broker_rep3"))

prep2 <- function(raw, cl) {
  d <- data.frame(.row = seq_len(nrow(raw)), stringsAsFactors = FALSE)
  for (v in c("cond_recode", "comp1", "comp2", "gender", "age", D2_OUT, unlist(MED_ITEMS),
              paste0("bentrust_accused", 1:3), paste0("inttrust_accused", 1:3),
              paste0("group_cohesion", 1:3, "_pre"), paste0("group_cohesion", 1:3, "_post")))
    d[[v]] <- getnum(raw, v)
  for (m in D2_MED) d[[m]] <- composite(raw, MED_ITEMS[[m]], cl, m)
  d$cond <- d$cond_recode
  d
}

keep2 <- function(d, sl) {
  if (sl == "D2_none") return(rep(TRUE, nrow(d)))
  c2 <- !is.na(d$comp2) & d$comp2 == 2
  expected <- ifelse(!is.na(d$cond_recode) & d$cond_recode == 1, 1,
                     ifelse(!is.na(d$cond_recode) & d$cond_recode == 0, 2, NA))
  c1 <- !is.na(d$comp1) & !is.na(expected) & d$comp1 == expected
  if (sl == "D2_any") c2 & c1 else c2 | c1
}

group_stats <- function(y, g) {
  ok <- !is.na(y) & !is.na(g)
  y <- y[ok]; g <- g[ok]
  a <- y[g == 1]; b <- y[g == 0]
  if (length(a) < 2 || length(b) < 2) stop("fewer than 2 observations in a group")
  md <- mean(a) - mean(b)
  list(mean_loyal = mean(a), sd_loyal = sd(a), mean_control = mean(b), sd_control = sd(b),
       mean_diff = md, d = md / pooled_sd(a, b), p_hc3 = hc_p(y, g, "HC3"))
}

## Parallel / single mediator OLS path model. d: complete cases on
## cond, o, meds. Returns a list per mediator of the manifest quantities.
pm_core <- function(d, o, meds) {
  fo <- ols(d[[o]], design(d, c("cond", meds)))
  ft <- ols(d[[o]], design(d, "cond"))
  out <- list()
  for (m in meds) {
    fa <- ols(d[[m]], design(d, "cond"))
    a <- fa$coef[["cond"]]; va <- fa$vcov["cond", "cond"]
    b <- fo$coef[[m]];      vb <- fo$vcov[m, m]
    ind <- a * b
    se_d <- sqrt(a^2 * vb + b^2 * va)
    out[[m]] <- list(ind = ind, a = a, b = b, c_prime = fo$coef[["cond"]],
                     total = ft$coef[["cond"]], se_delta = se_d,
                     p_delta = 2 * pnorm(-abs(ind / se_d)),
                     ci_norm_low = ind - ZCRIT * se_d, ci_norm_high = ind + ZCRIT * se_d)
  }
  out
}
pm_ind <- function(d, o, meds) sapply(meds, function(m) pm_core(d, o, meds)[[m]]$ind)

## Serial model: cond -> benev -> m2 -> you_grant.
sm_core <- function(d, m2) {
  f1 <- ols(d[["benev_trust_broker"]], design(d, "cond"))
  f2 <- ols(d[[m2]], design(d, c("cond", "benev_trust_broker")))
  f3 <- ols(d[["you_grant"]], design(d, c("cond", "benev_trust_broker", m2)))
  a1 <- f1$coef[["cond"]]; va1 <- f1$vcov["cond", "cond"]
  d21 <- f2$coef[["benev_trust_broker"]]; vd21 <- f2$vcov["benev_trust_broker", "benev_trust_broker"]
  b2 <- f3$coef[[m2]]; vb2 <- f3$vcov[m2, m2]
  ind <- a1 * d21 * b2
  se_d <- sqrt((d21 * b2)^2 * va1 + (a1 * b2)^2 * vd21 + (a1 * d21)^2 * vb2)
  list(ind = ind, a1 = a1, d21 = d21, b2 = b2, se_delta = se_d,
       p_delta = 2 * pnorm(-abs(ind / se_d)))
}

PM_Q <- c("ind", "a", "b", "c_prime", "total", "se_delta", "p_delta", "ci_norm_low", "ci_norm_high")

analyze_d2 <- function(raw) {
  ds <- "2"
  for (sl in c("D2_any", "D2_both", "D2_none")) {
    for (cl in c("mean", "sum", "existing")) {
      d0 <- prep2(raw, cl)
      d <- d0[keep2(d0, sl), ]
      if (cl == "mean") SAMPLES[[length(SAMPLES) + 1]] <<-
        data.frame(dataset = ds, sample_level = sl, unit_id = d$.row, stringsAsFactors = FALSE)

      ## T2
      for (o in D2_OUT) {
        emit(ds, sl, cl, paste0("T2.", o), "descriptive",
             c("mean_loyal", "sd_loyal", "mean_control", "sd_control", "mean_diff", "d", "p_hc3"),
             function() group_stats(d[[o]], d$cond))
        for (meth in c("welch", "student"))
          emit(ds, sl, cl, paste0("T2.", o), meth, c("t", "df", "p"),
               function() two_sample_t(d[[o]][d$cond == 1], d[[o]][d$cond == 0], meth == "student"))
      }

      ## PM2: parallel mediation
      for (o in D2_OUT) {
        dd <- cc_rows(d, c("cond", o, D2_MED))
        pm <- tryCatch(pm_core(dd, o, D2_MED), error = function(e) e)
        for (m in D2_MED)
          emit(ds, sl, cl, paste("PM2", o, m, sep = "."), "ols", PM_Q, function() {
            if (inherits(pm, "error")) stop(conditionMessage(pm)); pm[[m]] })
        if (cl == "mean")
          emit_boot(ds, sl, cl, "ols", D2_MED, function(m) paste("PM2", o, m, sep = "."),
                    dd, function(x) pm_ind(x, o, D2_MED))
      }

      ## SI2: single mediator
      for (o in D2_OUT) for (m in D2_MED) {
        dd <- cc_rows(d, c("cond", o, m))
        emit(ds, sl, cl, paste("SI2", o, m, sep = "."), "ols", PM_Q, function() pm_core(dd, o, m)[[m]])
        if (cl == "mean")
          emit_boot(ds, sl, cl, "ols", m, function(mm) paste("SI2", o, mm, sep = "."),
                    dd, function(x) pm_ind(x, o, m))
      }

      ## SM2: serial mediation
      for (m2 in c("val_align_part_broker", "relconcerns_with_broker")) {
        dd <- cc_rows(d, c("cond", "benev_trust_broker", m2, "you_grant"))
        emit(ds, sl, cl, paste0("SM2.", m2), "ols",
             c("ind", "a1", "d21", "b2", "se_delta", "p_delta"), function() sm_core(dd, m2))
        if (cl == "mean")
          emit_boot(ds, sl, cl, "ols", m2, function(mm) paste0("SM2.", mm),
                    dd, function(x) setNames(sm_core(x, m2)$ind, m2))
      }

      ## D2 descriptives
      desc_block(ds, sl, cl, "D2", d, c("cond_recode", D2_OUT, D2_MED))

      ## R2 reliability
      for (m in c("benev_trust_broker", "integ_trust_broker", "relconcerns_with_broker"))
        alpha_item(ds, sl, cl, paste0("R2.", m), d, MED_ITEMS[[m]])
      r_item(ds, sl, cl, "R2.val_align_part_broker", d, MED_ITEMS$val_align_part_broker)
      alpha_item(ds, sl, cl, "R2.benev_trust_accused", d, paste0("bentrust_accused", 1:3))
      alpha_item(ds, sl, cl, "R2.integ_trust_accused", d, paste0("inttrust_accused", 1:3))
      drev <- d; drev$inttrust_accused3 <- 8 - drev$inttrust_accused3
      alpha_item(ds, sl, cl, "R2.integ_trust_accused_rev3", drev, paste0("inttrust_accused", 1:3))
      alpha_item(ds, sl, cl, "R2.group_cohesion_pre", d, paste0("group_cohesion", 1:3, "_pre"))
      alpha_item(ds, sl, cl, "R2.group_cohesion_post", d, paste0("group_cohesion", 1:3, "_post"))

      ## N2
      emit(ds, sl, cl, "N2", "descriptive", c("n", "n_loyal", "n_control"), function()
        list(n = nrow(d), n_loyal = sum(d$cond == 1, na.rm = TRUE), n_control = sum(d$cond == 0, na.rm = TRUE)))
      emit(ds, sl, cl, "N2.age", "descriptive", c("mean", "sd"), function() mean_sd(d$age))

      ## G2W / G2C subgroups on you_grant
      for (g in names(GENDERS)) {
        rs <- d[!is.na(d$gender) & d$gender == GENDERS[[g]], ]
        for (meth in c("student", "welch"))
          emit(ds, sl, cl, paste0("G2W.all.", g), meth, c("t", "df", "p"), function()
            two_sample_t(rs$you_grant[rs$cond == 1], rs$you_grant[rs$cond == 0], meth == "student"))
      }
      for (cnd in c("loyal", "control")) {
        cv <- if (cnd == "loyal") 1 else 0
        rs <- d[!is.na(d$cond) & d$cond == cv & !is.na(d$gender) & d$gender %in% c(1, 2), ]
        xm <- rs$you_grant[rs$gender == 2]; xf <- rs$you_grant[rs$gender == 1]
        emit(ds, sl, cl, paste0("G2C.", cnd), "descriptive",
             c("mean_male", "sd_male", "mean_female", "sd_female"),
             function() { m <- mean_sd(xm); f <- mean_sd(xf)
               list(mean_male = m$mean, sd_male = m$sd, mean_female = f$mean, sd_female = f$sd) })
        for (meth in c("student", "welch"))
          emit(ds, sl, cl, paste0("G2C.", cnd), meth, c("t", "df", "p"),
               function() two_sample_t(xm, xf, meth == "student"))
      }
    }
  }
}

loo_d2 <- function(raw) {
  ds <- "2"
  LOO_MED <- c("benev_trust_broker", "val_align_part_broker", "relconcerns_with_broker")
  for (sl in c("D2_any", "D2_both", "D2_none")) {
    d0 <- prep2(raw, "mean")
    d <- d0[keep2(d0, sl), ]
    for (u in d$.row) {
      du <- d[d$.row != u, ]
      for (o in D2_OUT) {
        r <- tryCatch({
          ok <- !is.na(du[[o]]) & !is.na(du$cond)
          a <- du[[o]][ok & du$cond == 1]; b <- du[[o]][ok & du$cond == 0]
          tt <- two_sample_t(a, b, FALSE)
          list(est = mean(a) - mean(b), p = tt$p)
        }, error = function(e) e)
        if (inherits(r, "error")) add_infl(ds, sl, paste0("T2.", o), u, NA, NA, "failed", conditionMessage(r))
        else add_infl(ds, sl, paste0("T2.", o), u, r$est, r$p, "ok", "")

        pm <- tryCatch(pm_core(cc_rows(du, c("cond", o, D2_MED)), o, D2_MED), error = function(e) e)
        for (m in LOO_MED) {
          est <- paste("PM2", o, m, sep = ".")
          if (inherits(pm, "error")) add_infl(ds, sl, est, u, NA, NA, "failed", conditionMessage(pm))
          else add_infl(ds, sl, est, u, pm[[m]]$ind, pm[[m]]$p_delta, "ok", "")
        }
      }
    }
  }
}

## ---------------------------------------------------------------------
## 7. Dataset 3: two by two between persons
## ---------------------------------------------------------------------
D3_OUT <- c("you_grant", "prom_voice", "proh_voice", D2_MED)
CELLS <- c(LC = "1_0", CC = "0_0", LD = "1_1", CD = "0_1")

prep3 <- function(raw, cl) {
  d <- data.frame(.row = seq_len(nrow(raw)), stringsAsFactors = FALSE)
  for (v in c("cond_rel_recode", "cond_brokhist_recode", "cond_num", "comp1", "comp2", "comp3",
              "attn_afterscen", "gender", "age", "you_grant", "prom_voice", "proh_voice",
              unlist(MED_ITEMS)))
    d[[v]] <- getnum(raw, v)
  for (m in D2_MED) d[[m]] <- composite(raw, MED_ITEMS[[m]], cl, m)
  d$cell <- ifelse(is.na(d$cond_rel_recode) | is.na(d$cond_brokhist_recode), NA,
                   paste(d$cond_rel_recode, d$cond_brokhist_recode, sep = "_"))
  d$cell <- names(CELLS)[match(d$cell, CELLS)]
  d
}

keep3 <- function(d, sl) {
  if (sl == "D3_none") return(rep(TRUE, nrow(d)))
  c2 <- !is.na(d$comp2) & d$comp2 == 2
  exp1 <- ifelse(!is.na(d$cond_rel_recode) & d$cond_rel_recode == 1, 1,
                 ifelse(!is.na(d$cond_rel_recode) & d$cond_rel_recode == 0, 2, NA))
  c1 <- !is.na(d$comp1) & !is.na(exp1) & d$comp1 == exp1
  exp3 <- ifelse(!is.na(d$cond_brokhist_recode) & d$cond_brokhist_recode == 1, 2,
                 ifelse(!is.na(d$cond_brokhist_recode) & d$cond_brokhist_recode == 0, 1, NA))
  c3 <- !is.na(d$comp3) & !is.na(exp3) & d$comp3 == exp3
  keep <- c1 & c2 & c3
  if (sl == "D3_all") {
    amap <- c("1" = 1, "2" = 3, "3" = 2, "4" = 4)
    expa <- unname(amap[as.character(d$cond_num)])
    ca <- !is.na(d$attn_afterscen) & !is.na(expa) & d$attn_afterscen == expa
    keep <- keep & ca
  }
  keep
}

## Two-way ANOVA by sums of squares from nested OLS fits.
anova3 <- function(y, R, H) {
  ok <- !is.na(y) & !is.na(R) & !is.na(H)
  y <- y[ok]; R <- factor(R[ok]); H <- factor(H[ok])
  if (nlevels(R) < 2 || nlevels(H) < 2) stop("a factor has fewer than 2 levels")
  mm <- model.matrix(~ R * H, data = data.frame(R = R, H = H),
                     contrasts.arg = list(R = "contr.sum", H = "contr.sum"))
  asg <- attr(mm, "assign")      # 0 intercept, 1 relationship, 2 history, 3 interaction
  rss <- function(cols) sum(lm.fit(mm[, cols, drop = FALSE], y)$residuals^2)
  full <- rss(seq_len(ncol(mm)))
  df_err <- length(y) - qr(mm)$rank
  if (df_err < 1) stop("no residual degrees of freedom")
  sst <- sum((y - mean(y))^2)
  rss_01 <- rss(which(asg %in% c(0, 1))); rss_02 <- rss(which(asg %in% c(0, 2)))
  rss_012 <- rss(which(asg %in% c(0, 1, 2))); rss_0 <- rss(which(asg == 0))
  ss <- list(
    type3 = c(relationship = rss(which(asg != 1)) - full, history = rss(which(asg != 2)) - full,
              interaction = rss(which(asg != 3)) - full),
    type2 = c(relationship = rss_02 - rss_012, history = rss_01 - rss_012, interaction = rss_012 - full),
    type1 = c(relationship = rss_0 - rss_01, history = rss_01 - rss_012, interaction = rss_012 - full))
  dfs <- c(relationship = nlevels(R) - 1, history = nlevels(H) - 1,
           interaction = (nlevels(R) - 1) * (nlevels(H) - 1))
  out <- list()
  for (ty in names(ss)) for (tm in names(dfs)) {
    s <- ss[[ty]][[tm]]; df1 <- dfs[[tm]]
    Fv <- (s / df1) / (full / df_err)
    out[[ty]][[tm]] <- list(F = Fv, df1 = df1, df2 = df_err,
                            p = pf(Fv, df1, df_err, lower.tail = FALSE),
                            eta2 = s / (s + full), eta2_classic = s / sst)
  }
  out
}

## Contrast between two cells of the four-cell design.
contrast3 <- function(y, cell, cellA, cellB) {
  ok <- !is.na(y) & !is.na(cell)
  y <- y[ok]; cell <- cell[ok]
  a <- y[cell == cellA]; b <- y[cell == cellB]
  if (length(a) < 2 || length(b) < 2) stop("fewer than 2 observations in a cell")
  md <- mean(a) - mean(b)
  cf <- factor(cell, levels = names(CELLS)[names(CELLS) %in% unique(cell)])
  fit <- lm(y ~ 0 + cf)
  mse <- sum(residuals(fit)^2) / fit$df.residual
  tp <- md / sqrt(mse * (1 / length(a) + 1 / length(b)))
  st <- two_sample_t(a, b, TRUE); we <- two_sample_t(a, b, FALSE)
  V <- vcovHC(fit, type = "HC3")
  L <- as.numeric(levels(cf) == cellA) - as.numeric(levels(cf) == cellB)
  z <- sum(L * coef(fit)) / sqrt(as.numeric(t(L) %*% V %*% L))
  list(pooled = list(mean_diff = md, t = tp, df = fit$df.residual, p = 2 * pt(-abs(tp), fit$df.residual)),
       student = c(list(mean_diff = md), st),
       welch = c(list(mean_diff = md), we),
       descriptive = list(d = md / sqrt((var(a) + var(b)) / 2), d_pooled = md / pooled_sd(a, b),
                          p_hc3 = 2 * pnorm(-abs(z))))
}

analyze_d3 <- function(raw) {
  ds <- "3"
  for (sl in c("D3_all", "D3_comp", "D3_none")) {
    for (cl in c("mean", "sum", "existing")) {
      d0 <- prep3(raw, cl)
      d <- d0[keep3(d0, sl), ]
      if (cl == "mean") SAMPLES[[length(SAMPLES) + 1]] <<-
        data.frame(dataset = ds, sample_level = sl, unit_id = d$.row, stringsAsFactors = FALSE)

      for (o in D3_OUT) {
        ## A3
        an <- tryCatch(anova3(d[[o]], d$cond_rel_recode, d$cond_brokhist_recode), error = function(e) e)
        for (ty in c("type3", "type2", "type1")) for (tm in c("relationship", "history", "interaction"))
          emit(ds, sl, cl, paste("A3", o, tm, sep = "."), ty,
               c("F", "df1", "df2", "p", "eta2", "eta2_classic"), function() {
                 if (inherits(an, "error")) stop(conditionMessage(an)); an[[ty]][[tm]] })

        ## C3 cells
        for (cl3 in names(CELLS))
          emit(ds, sl, cl, paste("C3.cell", o, cl3, sep = "."), "descriptive", c("mean", "sd", "n"),
               function() { x <- d[[o]][!is.na(d$cell) & d$cell == cl3]; ms <- mean_sd(x)
                 list(mean = ms$mean, sd = ms$sd, n = sum(!is.na(x))) })

        ## C3 contrasts
        for (h in c("H1", "H3")) {
          cellB <- if (h == "H1") "CC" else "LD"
          ct <- tryCatch(contrast3(d[[o]], d$cell, "LC", cellB), error = function(e) e)
          for (meth in c("pooled", "student", "welch"))
            emit(ds, sl, cl, paste("C3", h, o, sep = "."), meth, c("mean_diff", "t", "df", "p"),
                 function() { if (inherits(ct, "error")) stop(conditionMessage(ct)); ct[[meth]] })
          emit(ds, sl, cl, paste("C3", h, o, sep = "."), "descriptive", c("d", "d_pooled", "p_hc3"),
               function() { if (inherits(ct, "error")) stop(conditionMessage(ct)); ct$descriptive })
        }
      }

      ## D3 / R3 / N3
      desc_block(ds, sl, cl, "D3", d, c("cond_rel_recode", "cond_brokhist_recode", D3_OUT))
      for (m in c("benev_trust_broker", "integ_trust_broker", "relconcerns_with_broker"))
        alpha_item(ds, sl, cl, paste0("R3.", m), d, MED_ITEMS[[m]])
      r_item(ds, sl, cl, "R3.val_align_part_broker", d, MED_ITEMS$val_align_part_broker)
      emit(ds, sl, cl, "N3", "descriptive", "n", function() list(n = nrow(d)))
      emit(ds, sl, cl, "N3.age", "descriptive", c("mean", "sd"), function() mean_sd(d$age))
    }
  }
}

loo_d3 <- function(raw) {
  ds <- "3"
  for (sl in c("D3_all", "D3_comp", "D3_none")) {
    d0 <- prep3(raw, "mean")
    d <- d0[keep3(d0, sl), ]
    for (u in d$.row) {
      du <- d[d$.row != u, ]
      for (o in c("you_grant", "prom_voice", "proh_voice")) for (h in c("H1", "H3")) {
        cellB <- if (h == "H1") "CC" else "LD"
        est <- paste("C3", h, o, sep = ".")
        r <- tryCatch(contrast3(du[[o]], du$cell, "LC", cellB)$pooled, error = function(e) e)
        if (inherits(r, "error")) add_infl(ds, sl, est, u, NA, NA, "failed", conditionMessage(r))
        else add_infl(ds, sl, est, u, r$mean_diff, r$p, "ok", "")
      }
    }
  }
}

## ---------------------------------------------------------------------
## 8. Dataset 4: binary outcome, measured predictor
## ---------------------------------------------------------------------
D4_VARS <- c("Signed", "LoyalRequestor", "KnowRequestor", "LikeRequestor", "SemestersRequestor", "LoyaltyHouse")
L4_MODELS <- list(M1 = "LoyalRequestor",
                  M2 = c("LoyalRequestor", "KnowRequestor", "LikeRequestor", "SemestersRequestor"),
                  M3 = c("LoyalRequestor", "KnowRequestor", "LikeRequestor", "SemestersRequestor", "LoyaltyHouse"))
L4_ALT <- c(strong = "StrongLoyaltyRequestor", exp = "ExpLoyaltyRequestor", house = "LoyaltyHouse")
MED4_METHODS <- list(linear_cont = list(x = "LoyalRequestor", logit = FALSE),
                     logit_cont = list(x = "LoyalRequestor", logit = TRUE),
                     linear_strong = list(x = "StrongLoyaltyRequestor", logit = FALSE),
                     logit_strong = list(x = "StrongLoyaltyRequestor", logit = TRUE))
MED4_M <- c("SignedTrust", "SignedRisk")

prep4 <- function(raw, cl) {
  d <- data.frame(.row = seq_len(nrow(raw)), stringsAsFactors = FALSE)
  for (v in c("Signed", "LoyalRequestor", "KnowRequestor", "LikeRequestor", "SemestersRequestor",
              "StrongLoyaltyRequestor", "ExpLoyaltyRequestor", "SignedTrust", "SignedRisk", "Age",
              "LoyalHouse1", "LoyalHouse2", "LoyalHouse3"))
    d[[v]] <- getnum(raw, v)
  d$LoyaltyHouse <- composite(raw, c("LoyalHouse1", "LoyalHouse2", "LoyalHouse3"), cl, "LoyaltyHouse")
  d
}

## Logistic regression with model-based and HC0 inference for every term.
logit_terms <- function(d, preds) {
  dd <- cc_rows(d, c("Signed", preds))
  if (nrow(dd) < length(preds) + 2) stop("too few complete cases")
  if (!all(dd$Signed %in% c(0, 1))) stop("Signed must be coded 0/1")
  fit <- suppressWarnings(glm(reformulate(preds, "Signed"), data = dd, family = binomial()))
  if (!isTRUE(fit$converged)) stop("logistic fit did not converge")
  if (any(is.na(coef(fit)))) stop("rank-deficient logistic design")
  s <- summary(fit)$coefficients
  V0 <- vcovHC(fit, type = "HC0")
  terms <- list()
  for (tm in rownames(s)) {
    b <- s[tm, "Estimate"]; se <- s[tm, "Std. Error"]
    nm <- if (tm == "(Intercept)") "intercept" else tm
    terms[[nm]] <- list(coef = b, se = se, z = b / se, p = 2 * pnorm(-abs(b / se)), or = exp(b),
                        p_hc0 = 2 * pnorm(-abs(b / sqrt(V0[tm, tm]))))
  }
  null <- glm(Signed ~ 1, data = dd, family = binomial())
  ll <- as.numeric(logLik(fit)); ll0 <- as.numeric(logLik(null)); n <- nrow(dd)
  list(terms = terms, fit = list(ll = ll, mcf = 1 - ll / ll0, cs = 1 - exp(2 * (ll0 - ll) / n), n = n))
}

## Mediation for dataset 4. Mediator models OLS; outcome model OLS or logit.
med4_core <- function(d, x, meds, use_logit) {
  Xa <- design(d, x)
  Xo <- design(d, c(x, meds))
  fo <- if (use_logit) logit_fit(d$Signed, Xo) else ols(d$Signed, Xo)
  out <- list()
  for (m in meds) {
    fa <- ols(d[[m]], Xa)
    a <- fa$coef[[x]]; va <- fa$vcov[x, x]
    b <- fo$coef[[m]]; vb <- fo$vcov[m, m]
    ind <- a * b; se_d <- sqrt(a^2 * vb + b^2 * va)
    out[[m]] <- list(ind = ind, a = a, b = b, se_delta = se_d, p_delta = 2 * pnorm(-abs(ind / se_d)))
  }
  out
}
med4_ind <- function(d, x, meds, use_logit) sapply(meds, function(m) med4_core(d, x, meds, use_logit)[[m]]$ind)

analyze_d4 <- function(raw) {
  ds <- "4"; sl <- "D4_loyal"
  for (cl in c("existing", "mean")) {
    d0 <- prep4(raw, cl)
    d <- d0[!is.na(d0$LoyalRequestor), ]
    if (cl == "existing") SAMPLES[[length(SAMPLES) + 1]] <<-
      data.frame(dataset = ds, sample_level = sl, unit_id = d$.row, stringsAsFactors = FALSE)

    ## L4 models
    for (mk in names(L4_MODELS)) {
      lt <- tryCatch(logit_terms(d, L4_MODELS[[mk]]), error = function(e) e)
      for (tm in c("intercept", L4_MODELS[[mk]]))
        emit(ds, sl, cl, paste("L4", mk, tm, sep = "."), "logit",
             c("coef", "se", "z", "p", "or", "p_hc0"), function() {
               if (inherits(lt, "error")) stop(conditionMessage(lt)); lt$terms[[tm]] })
      emit(ds, sl, cl, paste("L4", mk, "fit", sep = "."), "logit", c("ll", "mcf", "cs", "n"),
           function() { if (inherits(lt, "error")) stop(conditionMessage(lt)); lt$fit })
    }

    ## Alternatives and chi-square
    for (alt in names(L4_ALT))
      emit(ds, sl, cl, paste0("L4.ALT.", alt), "logit", c("coef", "se", "z", "p", "or"),
           function() logit_terms(d, L4_ALT[[alt]])$terms[[L4_ALT[[alt]]]])
    emit(ds, sl, cl, "CHI4.strong", "chisq", c("chi2", "df", "p"), function() {
      dd <- cc_rows(d, c("Signed", "StrongLoyaltyRequestor"))
      tab <- table(dd$Signed, dd$StrongLoyaltyRequestor)
      if (any(dim(tab) < 2)) stop("table has fewer than 2 rows or columns")
      r <- suppressWarnings(chisq.test(tab, correct = FALSE))
      list(chi2 = unname(r$statistic), df = unname(r$parameter), p = r$p.value)
    })

    ## MED4
    for (meth in names(MED4_METHODS)) {
      x <- MED4_METHODS[[meth]]$x; lg <- MED4_METHODS[[meth]]$logit
      ## simultaneous: both mediators in the outcome model
      dd <- cc_rows(d, c("Signed", x, MED4_M))
      mc <- tryCatch(med4_core(dd, x, MED4_M, lg), error = function(e) e)
      for (m in MED4_M)
        emit(ds, sl, cl, paste0("MED4.sim.", m), meth, c("ind", "a", "b", "se_delta", "p_delta"),
             function() { if (inherits(mc, "error")) stop(conditionMessage(mc)); mc[[m]] })
      if (cl == "existing")
        emit_boot(ds, sl, cl, meth, MED4_M, function(m) paste0("MED4.sim.", m),
                  dd, function(z) med4_ind(z, x, MED4_M, lg))
      ## individual: one mediator alone
      for (m in MED4_M) {
        dd1 <- cc_rows(d, c("Signed", x, m))
        emit(ds, sl, cl, paste0("MED4.ind.", m), meth, c("ind", "a", "b", "se_delta", "p_delta"),
             function() med4_core(dd1, x, m, lg)[[m]])
        if (cl == "existing")
          emit_boot(ds, sl, cl, meth, m, function(mm) paste0("MED4.ind.", mm),
                    dd1, function(z) med4_ind(z, x, m, lg))
      }
    }

    ## D4 / N4
    desc_block(ds, sl, cl, "D4", d, D4_VARS)
    emit(ds, sl, cl, "N4", "descriptive", c("n", "signed_count", "signed_share"), function() {
      s <- d$Signed[!is.na(d$Signed)]
      list(n = nrow(d), signed_count = sum(s == 1), signed_share = if (length(s)) mean(s == 1) else NA) })
    emit(ds, sl, cl, "N4.age", "descriptive", c("mean", "sd"), function() mean_sd(d$Age))
  }
}

loo_d4 <- function(raw) {
  ds <- "4"; sl <- "D4_loyal"
  d0 <- prep4(raw, "existing")
  d <- d0[!is.na(d0$LoyalRequestor), ]
  for (u in d$.row) {
    du <- d[d$.row != u, ]
    for (mk in names(L4_MODELS)) {
      est <- paste("L4", mk, "LoyalRequestor", sep = ".")
      r <- tryCatch(logit_terms(du, L4_MODELS[[mk]])$terms[["LoyalRequestor"]], error = function(e) e)
      if (inherits(r, "error")) add_infl(ds, sl, est, u, NA, NA, "failed", conditionMessage(r))
      else add_infl(ds, sl, est, u, r$coef, r$p, "ok", "")
    }
  }
}

## ---------------------------------------------------------------------
## 9. Main
## ---------------------------------------------------------------------
read_dataset <- function(i) {
  path <- file.path(DATA_DIR, sprintf("dataset_%d.csv", i))
  tryCatch(read_text_csv(path), error = function(e) e)
}

run_dataset <- function(i, analyze, loo) {
  raw <- read_dataset(i)
  if (inherits(raw, "error")) {
    add_result(as.character(i), "", "", sprintf("DATASET%d.read", i), "io", NA_real_, "failed",
               paste("could not read dataset:", conditionMessage(raw)))
    return(invisible(NULL))
  }
  guard(as.character(i), "", "", sprintf("DATASET%d.analysis", i), "block", analyze(raw))
  guard(as.character(i), "", "", sprintf("DATASET%d.influence", i), "block", loo(raw))
}

run_dataset(1, analyze_d1, loo_d1)
run_dataset(2, analyze_d2, loo_d2)
run_dataset(3, analyze_d3, loo_d3)
run_dataset(4, analyze_d4, loo_d4)

## ---------------------------------------------------------------------
## 10. Write outputs
## ---------------------------------------------------------------------
res_df <- if (N_RES > 0) as.data.frame(do.call(rbind, RESULTS[seq_len(N_RES)]), stringsAsFactors = FALSE) else
  data.frame(dataset = character(), sample_level = character(), composite_level = character(),
             key = character(), method = character(), value = character(), status = character(),
             message = character())
write.csv(res_df, file.path(OUT_DIR, "results.csv"), row.names = FALSE, na = "")

infl_df <- if (N_INFL > 0) as.data.frame(do.call(rbind, INFL[seq_len(N_INFL)]), stringsAsFactors = FALSE) else
  data.frame(dataset = character(), sample_level = character(), estimand = character(),
             deleted_unit = character(), estimate = character(), p = character(),
             status = character(), message = character())
write.csv(infl_df, file.path(OUT_DIR, "influence.csv"), row.names = FALSE, na = "")

samp_df <- if (length(SAMPLES)) do.call(rbind, SAMPLES) else
  data.frame(dataset = character(), sample_level = character(), unit_id = character())
write.csv(samp_df, file.path(OUT_DIR, "samples.csv"), row.names = FALSE, na = "")

si <- c(capture.output(sessionInfo()), "",
        sprintf("Run: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
        sprintf("Arguments: --data %s --out %s --seed %d --boot %d", DATA_DIR, OUT_DIR, SEED, NBOOT), "",
        "Package versions:",
        vapply(c("sandwich", "lme4", "Matrix", "stats"), function(p)
          sprintf("  %s %s", p, as.character(packageVersion(p))), character(1)))
writeLines(si, file.path(OUT_DIR, "session_info.txt"))

cat(sprintf("results.csv: %d rows (%d failed); influence.csv: %d rows; samples.csv: %d rows\n",
            nrow(res_df), sum(res_df$status == "failed"), nrow(infl_df), nrow(samp_df)))
