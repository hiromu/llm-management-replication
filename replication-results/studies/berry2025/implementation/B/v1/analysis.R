#!/opt/homebrew/opt/r/bin/Rscript
# PX01: self-contained analysis; only the four input CSVs are read at runtime.
# Usage: Rscript analysis.R --data DIR --out DIR --seed 20261031 --boot 5000
options(stringsAsFactors = FALSE, digits = 17, warn = 1)
invisible(Sys.setlocale("LC_COLLATE", "C"))

parse_args <- function(args) {
  opt <- list(data = NULL, out = NULL, seed = "20261031", boot = "5000")
  if (length(args) %% 2L) stop("Arguments must be --name value pairs")
  if (length(args)) for (i in seq.int(1L, length(args), 2L)) {
    key <- sub("^--", "", args[i])
    if (!startsWith(args[i], "--") || !key %in% names(opt))
      stop("Unknown argument: ", args[i])
    opt[[key]] <- args[i + 1L]
  }
  if (is.null(opt$data) || is.null(opt$out)) stop("--data and --out are required")
  for (nm in c("seed", "boot")) {
    z <- suppressWarnings(as.numeric(opt[[nm]]))
    if (length(z) != 1L || !is.finite(z) || z != floor(z) ||
        z < ifelse(nm == "boot", 2, 0) || z > .Machine$integer.max)
      stop("Invalid --", nm)
    opt[[nm]] <- as.integer(z)
  }
  opt
}
opt <- parse_args(commandArgs(trailingOnly = TRUE))
dir.create(opt$out, recursive = TRUE, showWarnings = FALSE)
packages <- c("lme4", "car", "sandwich")
available <- vapply(packages, requireNamespace, logical(1), quietly = TRUE)
need <- function(package) {
  if (!isTRUE(available[[package]])) stop("Installed package unavailable: ", package)
}
RNGkind("L'Ecuyer-CMRG")
set.seed(opt$seed)
next_stream <- .Random.seed
streams <- list()
results <- list()
influence <- list()
samples <- list()
context <- list(dataset = "", sample_level = "", composite_level = "")
outcomes <- c("you_grant", "prom_voice", "proh_voice")
mediators <- c("benev_trust_broker", "integ_trust_broker",
               "val_align_part_broker", "relconcerns_with_broker")
item_sets <- list(
  benev_trust_broker = paste0("bentrust_broker", 1:3),
  integ_trust_broker = paste0("inttrust_broker", 1:3),
  val_align_part_broker = paste0("me_broker_valal", 1:2),
  relconcerns_with_broker = paste0("broker_rep", 1:3),
  loyal_comb = paste0("loyal", 1:3),
  LoyaltyHouse = paste0("LoyalHouse", 1:3)
)
boot_fields <- c("se_boot", "ci_bc_low", "ci_bc_high", "ci_perc_low",
                 "ci_perc_high", "boot_failed")
path_fields <- c("ind", "a", "b", "c_prime", "total", "se_delta", "p_delta",
                 "ci_norm_low", "ci_norm_high")
med4_fields <- c("ind", "a", "b", "se_delta", "p_delta")
serial_fields <- c("ind", "a1", "d21", "b2", "se_delta", "p_delta")

# A captured failure is never silently dropped. Warnings accompany valid results.
capture <- function(fun) {
  warnings <- character()
  val <- tryCatch(withCallingHandlers(fun(), warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
  }), error = function(e) structure(list(reason = conditionMessage(e)), class = "failed"))
  list(value = val, message = paste(unique(warnings), collapse = "; "))
}
unwrap <- function(x) {
  if (inherits(x$value, "failed")) stop(x$value$reason, call. = FALSE)
  if (nzchar(x$message)) warning(x$message, call. = FALSE)
  x$value
}
emit <- function(prefix, fields, method, fun) {
  z <- capture(fun)
  err <- inherits(z$value, "failed")
  for (field in fields) {
    value <- if (!err && field %in% names(z$value)) unname(z$value[[match(field, names(z$value))]]) else NA_real_
    good <- is.numeric(value) && length(value) == 1L && is.finite(value)
    message <- if (err) z$value$reason else if (!good)
      paste0("Quantity undefined or non-finite: ", field,
             " (insufficient complete cases, zero variance, or non-estimability)") else ""
    message <- paste(c(message[nzchar(message)], z$message[nzchar(z$message)]), collapse = "; ")
    results[[length(results) + 1L]] <<- data.frame(
      dataset = context$dataset, sample_level = context$sample_level,
      composite_level = context$composite_level,
      key = if (nzchar(field)) paste(prefix, field, sep = ".") else prefix,
      method = method, value = if (good) value else NA_real_,
      status = if (good) "ok" else "failed", message = message)
  }
  invisible(z)
}
one <- function(key, method, fun) emit(key, "", method, function() setNames(fun(), ""))
num <- function(x) {
  z <- suppressWarnings(as.numeric(trimws(x)))
  z[!is.finite(z)] <- NA_real_
  z
}
col <- function(d, name) {
  if (!name %in% names(d)) return(rep(NA_real_, nrow(d)))
  d[[name]]
}
text_col <- function(d, name) {
  if (!name %in% names(d)) return(rep(NA_character_, nrow(d)))
  d[[name]]
}
cc <- function(d, vars) {
  missing <- setdiff(vars, names(d))
  if (length(missing)) stop("Missing columns: ", paste(missing, collapse = ", "))
  d[complete.cases(d[, vars, drop = FALSE]), , drop = FALSE]
}
keep <- function(d, test) d[which(!is.na(test) & test), , drop = FALSE]
avg <- function(x) mean(x[!is.na(x)])
sd1 <- function(x) sd(x[!is.na(x)])
normal_p <- function(z) 2 * pnorm(abs(z), lower.tail = FALSE)
cor_pair <- function(x, y) {
  ok <- complete.cases(x, y)
  if (sum(ok) < 2L) stop("Fewer than two complete pairs")
  cor(x[ok], y[ok], method = "pearson")
}
alpha <- function(d, items) {
  z <- cc(d, items)[, items, drop = FALSE]
  if (nrow(z) < 2L) stop("Fewer than two complete item rows")
  k <- length(items)
  v <- var(rowSums(z))
  if (!is.finite(v) || v <= 0) stop("Total item-score variance is zero or undefined")
  k / (k - 1) * (1 - sum(vapply(z, var, numeric(1))) / v)
}
composite <- function(d, level, dataset) {
  sets <- if (dataset == 1) item_sets["loyal_comb"] else if (dataset == 4)
    item_sets["LoyaltyHouse"] else item_sets[mediators]
  for (nm in names(sets)) {
    items <- sets[[nm]]
    z <- as.data.frame(setNames(lapply(items, function(v) col(d, v)), items))
    d[[nm]] <- if (level == "existing") col(d, nm) else if (level == "mean")
      rowMeans(z, na.rm = FALSE) else rowSums(z, na.rm = FALSE)
    d[[nm]][!complete.cases(z)] <- NA_real_
  }
  d
}
describe <- function(d, prefix, vars) {
  for (v in vars) {
    one(paste0(prefix, ".mean.", v), "descriptive", function() avg(col(d, v)))
    one(paste0(prefix, ".sd.", v), "descriptive", function() sd1(col(d, v)))
  }
  pairs <- combn(sort(vars, method = "radix"), 2L, simplify = FALSE)
  for (p in pairs) one(paste0(prefix, ".r.", paste(p, collapse = "|")), "pearson",
                       function() cor_pair(col(d, p[1]), col(d, p[2])))
}
fit_lm <- function(d, y, xs) {
  z <- cc(d, c(y, xs))
  formula <- if (length(xs)) reformulate(xs, response = y) else as.formula(paste(y, "~ 1"))
  fit <- lm(formula, data = z, na.action = na.fail)
  if (fit$rank < length(coef(fit))) stop("Rank-deficient OLS model")
  if (df.residual(fit) <= 0L) stop("No residual degrees of freedom")
  fit
}
fit_logit <- function(d, xs) {
  z <- cc(d, c("Signed", xs))
  if (!nrow(z) || any(!z$Signed %in% c(0, 1))) stop("Signed must contain binary 0/1 complete cases")
  if (length(unique(z$Signed)) < 2L) stop("Logistic outcome has only one observed class")
  fit <- glm(reformulate(xs, response = "Signed"), data = z,
             family = binomial(), na.action = na.fail,
             control = glm.control(maxit = 100L))
  if (!isTRUE(fit$converged)) stop("Logistic regression did not converge")
  if (fit$rank < length(coef(fit)) || any(!is.finite(coef(fit))))
    stop("Logistic model is rank deficient or has non-finite coefficients")
  fit
}
coef_se <- function(fit, term) {
  tab <- summary(fit)$coefficients
  if (!term %in% rownames(tab)) stop("Coefficient not estimable: ", term)
  c(coef = unname(tab[term, 1]), se = unname(tab[term, 2]))
}
robust_p <- function(fit, term, type = "HC3") {
  need("sandwich")
  v <- sandwich::vcovHC(fit, type = type)
  normal_p(coef(fit)[term] / sqrt(v[term, term]))
}
test_two <- function(a, b, method) {
  a <- a[!is.na(a)]; b <- b[!is.na(b)]
  tt <- t.test(a, b, var.equal = method == "student", alternative = "two.sided")
  c(mean_diff = mean(a) - mean(b), t = unname(tt$statistic),
    df = unname(tt$parameter), p = tt$p.value)
}
pooled_sd <- function(a, b) {
  a <- a[!is.na(a)]; b <- b[!is.na(b)]
  sqrt(((length(a) - 1) * var(a) + (length(b) - 1) * var(b)) /
         (length(a) + length(b) - 2))
}
gender_compare <- function(d, prefix) {
  a <- col(d, "you_grant")[which(col(d, "gender") == 2)]
  b <- col(d, "you_grant")[which(col(d, "gender") == 1)]
  emit(prefix, c("mean_male", "sd_male", "mean_female", "sd_female"), "descriptive",
       function() c(mean_male = avg(a), sd_male = sd1(a), mean_female = avg(b), sd_female = sd1(b)))
  for (method in c("student", "welch")) emit(prefix, c("t", "df", "p"), method,
                                           function() test_two(a, b, method))
}

# Each multi-equation mediation model uses its joint complete-case sample.
# Parallel indirect effects share the same resampled rows and outcome equation.
path_model <- function(d, y, x, ms, logistic = FALSE) {
  z <- cc(d, c(y, x, ms))
  outcome_fit <- if (logistic) fit_logit(z, c(x, ms)) else fit_lm(z, y, c(x, ms))
  total_fit <- if (logistic) NULL else fit_lm(z, y, x)
  ans <- lapply(ms, function(m) {
    aa <- coef_se(fit_lm(z, m, x), x)
    bb <- coef_se(outcome_fit, m)
    ind <- aa["coef"] * bb["coef"]
    se <- sqrt(aa["coef"]^2 * bb["se"]^2 + bb["coef"]^2 * aa["se"]^2)
    setNames(c(ind, aa["coef"], bb["coef"], coef(outcome_fit)[x],
               if (logistic) NA_real_ else coef(total_fit)[x], se, normal_p(ind / se),
               ind - 1.96 * se, ind + 1.96 * se), path_fields)
  })
  setNames(ans, ms)
}
serial_model <- function(d, m2) {
  x <- "cond_recode"; m1 <- "benev_trust_broker"; y <- "you_grant"
  z <- cc(d, c(x, m1, m2, y))
  a <- coef_se(fit_lm(z, m1, x), x)
  dd <- coef_se(fit_lm(z, m2, c(x, m1)), m1)
  b <- coef_se(fit_lm(z, y, c(x, m1, m2)), m2)
  ind <- a[1] * dd[1] * b[1]
  se <- sqrt((dd[1] * b[1])^2 * a[2]^2 + (a[1] * b[1])^2 * dd[2]^2 +
               (a[1] * dd[1])^2 * b[2]^2)
  setNames(c(ind, a[1], dd[1], b[1], se, normal_p(ind / se)), serial_fields)
}
bootstrap_model <- function(d, vars, fit_fun, extract, id) {
  # Failure of the initial fit is reported separately from failed resamples.
  start <- next_stream
  next_stream <<- parallel::nextRNGStream(next_stream)
  streams[[id]] <<- start
  assign(".Random.seed", start, envir = .GlobalEnv)
  z <- cc(d, vars)
  if (!nrow(z)) stop("No joint complete cases for bootstrap model")
  values <- vector("list", opt$boot)
  failures <- 0L
  warnings <- character()
  for (i in seq_len(opt$boot)) {
    ix <- sample.int(nrow(z), nrow(z), replace = TRUE)
    got <- capture(function() extract(fit_fun(z[ix, , drop = FALSE])))
    if (inherits(got$value, "failed") || any(!is.finite(got$value))) {
      failures <- failures + 1L
    } else values[[i]] <- got$value
    if (nzchar(got$message)) warnings <- unique(c(warnings, got$message))
  }
  valid <- values[!vapply(values, is.null, logical(1))]
  mat <- if (length(valid)) do.call(rbind, valid) else NULL
  list(draws = mat, failed = failures, warnings = paste(warnings, collapse = "; "))
}
boot_summary <- function(boot, estimate, column) {
  z <- unwrap(boot)
  if (is.null(z$draws)) stop("All bootstrap fits failed; ", z$failed, " discarded")
  draws <- z$draws[, column]
  if (length(draws) < 2L) stop("Fewer than two successful bootstrap fits")
  # type=7 is R's default interpolated sample quantile. Infinite z0 gives endpoints.
  share <- (sum(draws < estimate) + 0.5 * sum(draws == estimate)) / length(draws)
  probs <- pnorm(2 * qnorm(share) + c(-1.96, 1.96))
  bc <- quantile(draws, probs, type = 7, names = FALSE)
  pc <- quantile(draws, c(.025, .975), type = 7, names = FALSE)
  setNames(c(sd(draws), bc, pc), boot_fields[1:5])
}
emit_boot <- function(prefix, method, boot, point, column) {
  emit(prefix, boot_fields[1:5], method, function() {
    z <- unwrap(boot)
    if (nzchar(z$warnings)) warning(z$warnings)
    boot_summary(boot, point(), column)
  })
  one(paste0(prefix, ".boot_failed"), method, function() unwrap(boot)$failed)
}

# Pair eligibility depends only on the row structure, not on outcome missingness.
pair_frame <- function(d, outcome = NULL) {
  ids <- unique(d$.unit)
  good <- vapply(ids, function(id) {
    z <- d[d$.unit == id, , drop = FALSE]
    nrow(z) == 2L && sum(z$cond == "loyal", na.rm = TRUE) == 1L &&
      sum(z$cond == "control", na.rm = TRUE) == 1L && !anyNA(z$part_uid)
  }, logical(1))
  ids <- ids[good]
  # Explicit indexing preserves the same person order on both sides.
  li <- which(d$cond == "loyal"); ci <- which(d$cond == "control")
  l <- d[li[match(ids, d$.unit[li])], , drop = FALSE]
  c <- d[ci[match(ids, d$.unit[ci])], , drop = FALSE]
  z <- data.frame(unit = ids, wrongdoing = col(l, "wrongdoing_num"),
                  wrong_control = col(c, "wrongdoing_num"))
  if (!is.null(outcome)) {
    z$loyal <- col(l, outcome); z$control <- col(c, outcome)
    z <- z[complete.cases(z[, c("loyal", "control")]), , drop = FALSE]
    z$diff <- z$loyal - z$control
  }
  z
}
paired_test <- function(p) {
  tt <- t.test(p$loyal, p$control, paired = TRUE, alternative = "two.sided")
  c(mean_diff = mean(p$diff), t = unname(tt$statistic), df = unname(tt$parameter), p = tt$p.value)
}
mixed_difference_fit <- function(p) {
  if (any(!is.na(p$wrongdoing) & !is.na(p$wrong_control) & p$wrongdoing != p$wrong_control))
    stop("Between-person wrongdoing differs across the two rows")
  z <- cc(p, c("diff", "wrongdoing", "wrong_control"))
  z$wrongdoing <- factor(z$wrongdoing)
  if (nlevels(z$wrongdoing) == 0L) stop("No observed wrongdoing levels")
  if (nlevels(z$wrongdoing) == 1L) return(fit_lm(z, "diff", character()))
  contrasts(z$wrongdoing) <- contr.sum(nlevels(z$wrongdoing))
  fit_lm(z, "diff", "wrongdoing")
}

run_d1 <- function(d) {
  for (o in c(outcomes, "loyal_comb")) {
    p <- pair_frame(d, o)
    prefix <- paste0("P1.", o)
    emit(prefix, c("mean_loyal", "sd_loyal", "mean_control", "sd_control", "mean_diff",
                   "se_diff", "n", "d", "dz"), "paired", function() {
      diff <- avg(p$diff)
      c(mean_loyal = avg(p$loyal), sd_loyal = sd1(p$loyal), mean_control = avg(p$control),
        sd_control = sd1(p$control), mean_diff = diff, se_diff = sd1(p$diff) / sqrt(nrow(p)),
        n = nrow(p), d = diff / sqrt((var(p$loyal) + var(p$control)) / 2), dz = diff / sd1(p$diff))
    })
    emit(prefix, c("t", "df", "p"), "paired", function() paired_test(p))
    one(paste0(prefix, ".p_hc3"), "paired", function() robust_p(fit_lm(p, "diff", character()), "(Intercept)"))
    if (o %in% outcomes) {
      fit <- capture(function() mixed_difference_fit(p))
      emit(paste0("M1.", o), c("F", "df1", "df2", "p"), "mixed_anova", function() {
        f <- unwrap(fit); a <- anova(f)
        if (!"wrongdoing" %in% rownames(a)) stop("Interaction requires at least two wrongdoing levels")
        c(F = a[1, "F value"], df1 = a[1, "Df"], df2 = df.residual(f), p = a[1, "Pr(>F)"])
      })
      emit(paste0("ME1.", o), c("F", "df1", "df2", "p"), "mixed_anova", function() {
        f <- unwrap(fit); a <- coef_se(f, "(Intercept)"); F <- unname((a[1] / a[2])^2)
        c(F = F, df1 = 1, df2 = df.residual(f), p = pf(F, 1, df.residual(f), lower.tail = FALSE))
      })
      for (method in c("ri_person", "ri_person_wrongdoing")) emit(
        paste0("LMM1.", o), c("coef", "se", "p"), method, function() {
          need("lme4")
          vars <- c(o, "cond_recode", "part_uid", if (method == "ri_person_wrongdoing") "wrongdoing_num")
          z <- cc(d, vars)
          random <- if (method == "ri_person") "(1 | part_uid)" else "(1 | wrongdoing_num / part_uid)"
          f <- lme4::lmer(as.formula(paste(o, "~ cond_recode +", random)), data = z, REML = TRUE)
          conv <- f@optinfo$conv$lme4$messages
          if (length(conv) && !all(grepl("singular", conv))) stop(paste(conv, collapse = "; "))
          if (lme4::isSingular(f)) warning("Singular random-effects fit; fixed-effect Wald quantities retained")
          tab <- coef(summary(f)); a <- tab["cond_recode", "Estimate"]; se <- tab["cond_recode", "Std. Error"]
          c(coef = a, se = se, p = normal_p(a / se))
        })
    }
  }
  describe(d, "D1", c("cond_recode", outcomes))
  one("R1.loyal_comb.alpha", "cronbach", function() alpha(d, item_sets$loyal_comb))
  one("R1.perceived_ethic_import.alpha", "cronbach", function() alpha(d, c("pie1", "pie2", "pie3", "pie4_rev")))
  pairs <- list(magnitude = c("magnitude1_rev", "magnitude2"),
                prob_of_effect = c("prob_effect1", "prob_effect2_rev"),
                temp_immediacy = c("temp_imm1", "temp_imm2_rev"),
                proximity_effect = c("proxim_eff1_rev", "proxim_eff2"),
                social_consensus = c("social_cons1", "social_cons2_rev"),
                concentration_of_effect = c("concen_eff1_rev", "concen_eff2"))
  for (nm in names(pairs)) one(paste0("R1.", nm, ".r"), "pearson",
                              function() cor_pair(col(d, pairs[[nm]][1]), col(d, pairs[[nm]][2])))
  one("N1.rows", "descriptive", function() nrow(d))
  one("N1.n", "descriptive", function() nrow(pair_frame(d)))
  ages <- capture(function() vapply(unique(d$.unit), function(id) {
    a <- col(d[d$.unit == id, , drop = FALSE], "age")
    a <- unique(a[!is.na(a)])
    if (length(a) > 1L) stop("Inconsistent ages within person ", id)
    if (length(a)) a else NA_real_
  }, numeric(1)))
  one("N1.age.mean", "descriptive", function() avg(unwrap(ages)))
  one("N1.age.sd", "descriptive", function() sd1(unwrap(ages)))
  for (s in c("sexual_harassment", "all")) for (g in c("male", "female")) {
    z <- keep(d, col(d, "gender") == ifelse(g == "male", 2, 1))
    if (s != "all") z <- keep(z, col(z, "wrongdoing_num") == 1)
    prefix <- paste("G1W", s, g, sep = ".")
    emit(prefix, c("t", "df", "p"), "paired", function() paired_test(pair_frame(z, "you_grant")))
    for (method in c("student", "welch")) emit(prefix, c("t", "df", "p"), method,
      function() test_two(col(z, "you_grant")[which(z$cond == "loyal")],
                          col(z, "you_grant")[which(z$cond == "control")], method))
  }
  scenarios <- c("sexual_harassment", "theft", "false_advertising", "fraud", "bribery",
                 "plagiarism", "dishonesty", "average")
  for (i in seq_along(scenarios)) for (condition in c("loyal", "control")) {
    z <- keep(d, d$cond == condition)
    if (i < 8L) z <- keep(z, col(z, "wrongdoing_num") == i)
    gender_compare(z, paste("G1C", scenarios[i], condition, sep = "."))
  }
}

reliability_broker <- function(d, prefix) {
  for (m in setdiff(mediators, "val_align_part_broker"))
    one(paste(prefix, m, "alpha", sep = "."), "cronbach", function() alpha(d, item_sets[[m]]))
  one(paste0(prefix, ".val_align_part_broker.r"), "pearson",
      function() cor_pair(col(d, "me_broker_valal1"), col(d, "me_broker_valal2")))
}
run_d2 <- function(d, do_boot) {
  for (o in outcomes) {
    a <- col(d, o)[which(col(d, "cond_recode") == 1)]
    b <- col(d, o)[which(col(d, "cond_recode") == 0)]
    prefix <- paste0("T2.", o)
    emit(prefix, c("mean_loyal", "sd_loyal", "mean_control", "sd_control", "mean_diff", "d"),
         "descriptive", function() c(mean_loyal = avg(a), sd_loyal = sd1(a), mean_control = avg(b),
           sd_control = sd1(b), mean_diff = avg(a) - avg(b), d = (avg(a) - avg(b)) / pooled_sd(a, b)))
    one(paste0(prefix, ".p_hc3"), "descriptive", function() robust_p(fit_lm(d, o, "cond_recode"), "cond_recode"))
    for (method in c("student", "welch")) emit(prefix, c("t", "df", "p"), method, function() test_two(a, b, method))
    for (kind in c("PM2", "SI2")) {
      groups <- if (kind == "PM2") list(mediators) else as.list(mediators)
      for (ms in groups) {
        fitfun <- function(z) path_model(z, o, "cond_recode", ms)
        point <- capture(function() fitfun(d))
        if (do_boot) {
          id <- paste(context$sample_level, kind, o, paste(ms, collapse = "+"), sep = "/")
          bt <- capture(function() bootstrap_model(d, c(o, "cond_recode", ms), fitfun,
            function(z) vapply(z, function(q) q[["ind"]], numeric(1)), id))
        }
        for (m in ms) {
          prefix <- paste(kind, o, m, sep = ".")
          emit(prefix, path_fields, "ols", function() unwrap(point)[[m]])
          if (do_boot) emit_boot(prefix, "ols", bt, function() unwrap(point)[[m]][["ind"]], m)
        }
      }
    }
  }
  for (m2 in c("val_align_part_broker", "relconcerns_with_broker")) {
    point <- capture(function() serial_model(d, m2))
    prefix <- paste0("SM2.", m2)
    emit(prefix, serial_fields, "ols", function() unwrap(point))
    if (do_boot) {
      bt <- capture(function() bootstrap_model(d, c("cond_recode", "benev_trust_broker", m2, "you_grant"),
        function(z) serial_model(z, m2), function(z) c(ind = z[["ind"]]),
        paste(context$sample_level, prefix, sep = "/")))
      emit_boot(prefix, "ols", bt, function() unwrap(point)[["ind"]], "ind")
    }
  }
  describe(d, "D2", c("cond_recode", outcomes, mediators))
  reliability_broker(d, "R2")
  one("R2.benev_trust_accused.alpha", "cronbach", function() alpha(d, paste0("bentrust_accused", 1:3)))
  one("R2.integ_trust_accused.alpha", "cronbach", function() alpha(d, paste0("inttrust_accused", 1:3)))
  one("R2.integ_trust_accused_rev3.alpha", "cronbach", function() {
    z <- d; z$inttrust_accused3 <- 8 - col(z, "inttrust_accused3")
    alpha(z, paste0("inttrust_accused", 1:3))
  })
  for (when in c("pre", "post")) one(paste0("R2.group_cohesion_", when, ".alpha"), "cronbach",
    function() alpha(d, paste0("group_cohesion", 1:3, "_", when)))
  emit("N2", c("n", "n_loyal", "n_control", "age.mean", "age.sd"), "descriptive", function()
    c(n = nrow(d), n_loyal = sum(col(d, "cond_recode") == 1, na.rm = TRUE),
      n_control = sum(col(d, "cond_recode") == 0, na.rm = TRUE),
      age.mean = avg(col(d, "age")), age.sd = sd1(col(d, "age"))))
  for (g in c("male", "female")) {
    z <- keep(d, col(d, "gender") == ifelse(g == "male", 2, 1))
    for (method in c("student", "welch")) emit(paste0("G2W.all.", g), c("t", "df", "p"), method,
      function() test_two(col(z, "you_grant")[which(col(z, "cond_recode") == 1)],
                          col(z, "you_grant")[which(col(z, "cond_recode") == 0)], method))
  }
  for (condition in c("loyal", "control")) gender_compare(
    keep(d, col(d, "cond_recode") == ifelse(condition == "loyal", 1, 0)), paste0("G2C.", condition))
}

cell_data <- function(d, o) {
  z <- cc(d, c(o, "cond_rel_recode", "cond_brokhist_recode"))
  if (any(!z$cond_rel_recode %in% c(0, 1)) || any(!z$cond_brokhist_recode %in% c(0, 1)))
    stop("Factor recodes must be 0 or 1")
  z$y <- z[[o]]
  z$relationship <- factor(z$cond_rel_recode, levels = c(0, 1))
  z$history <- factor(z$cond_brokhist_recode, levels = c(0, 1))
  z$cell <- factor(paste0(ifelse(z$cond_rel_recode == 1, "L", "C"),
                          ifelse(z$cond_brokhist_recode == 1, "D", "C")),
                   levels = c("LC", "CC", "LD", "CD"))
  z
}
four_cell_fit <- function(z) {
  if (any(table(z$cell) == 0L)) stop("One or more of the four cells is empty")
  fit <- lm(y ~ 0 + cell, data = z)
  if (df.residual(fit) <= 0L) stop("No residual degrees of freedom in four-cell model")
  fit
}
pooled_contrast <- function(z, other) {
  f <- four_cell_fit(z)
  a <- z$y[z$cell == "LC"]; b <- z$y[z$cell == other]
  diff <- mean(a) - mean(b)
  se <- sqrt(deviance(f) / df.residual(f) * (1 / length(a) + 1 / length(b)))
  t <- diff / se; df <- df.residual(f)
  c(mean_diff = diff, t = t, df = df, p = 2 * pt(abs(t), df, lower.tail = FALSE))
}
run_d3 <- function(d) {
  for (o in c(outcomes, mediators)) {
    cells <- capture(function() cell_data(d, o))
    fit <- capture(function() {
      z <- unwrap(cells)
      four_cell_fit(z)
      contrasts(z$relationship) <- contr.sum(2)
      contrasts(z$history) <- contr.sum(2)
      lm(y ~ relationship * history, data = z)
    })
    for (method in c("type3", "type2", "type1")) {
      tab <- capture(function() {
        f <- unwrap(fit)
        if (method == "type1") anova(f) else {
          need("car"); car::Anova(f, type = ifelse(method == "type3", 3, 2))
        }
      })
      for (term in c("relationship", "history", "interaction")) emit(paste("A3", o, term, sep = "."),
        c("F", "df1", "df2", "p", "eta2", "eta2_classic"), method, function() {
          a <- unwrap(tab); f <- unwrap(fit)
          name <- if (term == "interaction") "relationship:history" else term
          ss <- a[name, "Sum Sq"]; ss_error <- deviance(f)
          total <- sum((model.response(model.frame(f)) - mean(model.response(model.frame(f))))^2)
          c(F = a[name, "F value"], df1 = a[name, "Df"], df2 = df.residual(f),
            p = a[name, "Pr(>F)"], eta2 = ss / (ss + ss_error), eta2_classic = ss / total)
        })
    }
    for (cell in c("LC", "CC", "LD", "CD")) emit(paste("C3.cell", o, cell, sep = "."),
      c("mean", "sd", "n"), "descriptive", function() {
        z <- unwrap(cells); y <- z$y[z$cell == cell]
        c(mean = avg(y), sd = sd1(y), n = length(y))
      })
    for (hyp in c("H1", "H3")) {
      other <- if (hyp == "H1") "CC" else "LD"
      prefix <- paste("C3", hyp, o, sep = ".")
      emit(prefix, c("mean_diff", "t", "df", "p"), "pooled", function() pooled_contrast(unwrap(cells), other))
      for (method in c("student", "welch")) emit(prefix, c("mean_diff", "t", "df", "p"), method, function() {
        z <- unwrap(cells); test_two(z$y[z$cell == "LC"], z$y[z$cell == other], method)
      })
      emit(prefix, c("d", "d_pooled"), "descriptive", function() {
        z <- unwrap(cells); a <- z$y[z$cell == "LC"]; b <- z$y[z$cell == other]
        c(d = (mean(a) - mean(b)) / sqrt((var(a) + var(b)) / 2),
          d_pooled = (mean(a) - mean(b)) / pooled_sd(a, b))
      })
      one(paste0(prefix, ".p_hc3"), "descriptive", function() {
        need("sandwich"); f <- four_cell_fit(unwrap(cells)); v <- sandwich::vcovHC(f, type = "HC3")
        contrast <- setNames(rep(0, length(coef(f))), names(coef(f)))
        contrast["cellLC"] <- 1; contrast[paste0("cell", other)] <- -1
        normal_p(sum(contrast * coef(f)) / sqrt(drop(t(contrast) %*% v %*% contrast)))
      })
    }
  }
  describe(d, "D3", c("cond_rel_recode", "cond_brokhist_recode", outcomes, mediators))
  reliability_broker(d, "R3")
  emit("N3", c("n", "age.mean", "age.sd"), "descriptive", function()
    c(n = nrow(d), age.mean = avg(col(d, "age")), age.sd = sd1(col(d, "age"))))
}

logit_predictors <- list(M1 = "LoyalRequestor",
  M2 = c("LoyalRequestor", "KnowRequestor", "LikeRequestor", "SemestersRequestor"),
  M3 = c("LoyalRequestor", "KnowRequestor", "LikeRequestor", "SemestersRequestor", "LoyaltyHouse"))
logit_stats <- function(f, term) {
  tab <- coef_se(f, term); z <- tab[1] / tab[2]
  setNames(c(tab[1], tab[2], z, normal_p(z), exp(tab[1])), c("coef", "se", "z", "p", "or"))
}
run_d4 <- function(d, do_boot) {
  for (model in names(logit_predictors)) {
    fit <- capture(function() fit_logit(d, logit_predictors[[model]]))
    for (term in c("(Intercept)", logit_predictors[[model]])) {
      prefix <- paste("L4", model, term, sep = ".")
      emit(prefix, c("coef", "se", "z", "p", "or"), "logit", function() logit_stats(unwrap(fit), term))
      one(paste0(prefix, ".p_hc0"), "logit", function() robust_p(unwrap(fit), term, "HC0"))
    }
    emit(paste("L4", model, "fit", sep = "."), c("ll", "mcf", "cs", "n"), "logit", function() {
      f <- unwrap(fit); ll <- as.numeric(logLik(f))
      null <- glm(Signed ~ 1, data = model.frame(f), family = binomial())
      ll_null <- as.numeric(logLik(null)); n <- nobs(f)
      c(ll = ll, mcf = 1 - ll / ll_null, cs = 1 - exp(2 * (ll_null - ll) / n), n = n)
    })
  }
  alternatives <- c(strong = "StrongLoyaltyRequestor", exp = "ExpLoyaltyRequestor", house = "LoyaltyHouse")
  for (a in names(alternatives)) emit(paste0("L4.ALT.", a), c("coef", "se", "z", "p", "or"), "logit",
    function() logit_stats(fit_logit(d, alternatives[[a]]), alternatives[[a]]))
  emit("CHI4.strong", c("chi2", "df", "p"), "pearson", function() {
    z <- cc(d, c("Signed", "StrongLoyaltyRequestor"))
    tab <- table(z$Signed, z$StrongLoyaltyRequestor)
    if (any(dim(tab) < 2)) stop("Contingency table needs at least two rows and two columns")
    a <- chisq.test(tab, correct = FALSE)
    c(chi2 = unname(a$statistic), df = unname(a$parameter), p = a$p.value)
  })
  for (method in c("linear_cont", "logit_cont", "linear_strong", "logit_strong")) {
    x <- if (grepl("strong$", method)) "StrongLoyaltyRequestor" else "LoyalRequestor"
    logistic <- startsWith(method, "logit")
    for (kind in c("sim", "ind")) {
      ms_all <- c("SignedTrust", "SignedRisk")
      groups <- if (kind == "sim") list(ms_all) else as.list(ms_all)
      for (ms in groups) {
        fitfun <- function(z) path_model(z, "Signed", x, ms, logistic)
        point <- capture(function() fitfun(d))
        if (do_boot) bt <- capture(function() bootstrap_model(d, c("Signed", x, ms), fitfun,
          function(z) vapply(z, function(q) q[["ind"]], numeric(1)),
          paste("D4_loyal", method, kind, paste(ms, collapse = "+"), sep = "/")))
        for (m in ms) {
          prefix <- paste("MED4", kind, m, sep = ".")
          emit(prefix, med4_fields, method, function() unwrap(point)[[m]])
          if (do_boot) emit_boot(prefix, method, bt, function() unwrap(point)[[m]][["ind"]], m)
        }
      }
    }
  }
  describe(d, "D4", c("Signed", "LoyalRequestor", "KnowRequestor", "LikeRequestor", "SemestersRequestor", "LoyaltyHouse"))
  emit("N4", c("n", "signed_count", "signed_share", "age.mean", "age.sd"), "descriptive", function()
    c(n = nrow(d), signed_count = sum(col(d, "Signed") == 1, na.rm = TRUE),
      signed_share = avg(col(d, "Signed")), age.mean = avg(col(d, "Age")), age.sd = sd1(col(d, "Age"))))
}

emit_influence <- function(estimand, deleted, fun) {
  z <- capture(fun)
  err <- inherits(z$value, "failed")
  vals <- if (err) c(estimate = NA_real_, p = NA_real_) else z$value[c("estimate", "p")]
  good <- length(vals) == 2L && all(is.finite(vals))
  message <- if (err) z$value$reason else if (!good) "Non-finite influence estimate or p value" else ""
  influence[[length(influence) + 1L]] <<- data.frame(
    dataset = context$dataset, sample_level = context$sample_level, estimand = estimand,
    deleted_unit = as.character(deleted), estimate = unname(vals[1]), p = unname(vals[2]),
    status = if (good) "ok" else "failed",
    message = paste(c(message[nzchar(message)], z$message[nzchar(z$message)]), collapse = "; "))
}
run_influence <- function(d, dataset) {
  for (id in unique(d$.unit)) {
    z <- d[d$.unit != id, , drop = FALSE]
    if (dataset == 1) for (o in outcomes) emit_influence(paste0("P1.", o), id, function() {
      p <- paired_test(pair_frame(z, o)); c(estimate = p[["mean_diff"]], p = p[["p"]])
    })
    if (dataset == 2) for (o in outcomes) {
      emit_influence(paste0("T2.", o), id, function() {
        p <- test_two(col(z, o)[which(col(z, "cond_recode") == 1)],
                      col(z, o)[which(col(z, "cond_recode") == 0)], "welch")
        c(estimate = p[["mean_diff"]], p = p[["p"]])
      })
      fit <- capture(function() path_model(z, o, "cond_recode", mediators))
      for (m in c("benev_trust_broker", "val_align_part_broker", "relconcerns_with_broker"))
        emit_influence(paste("PM2", o, m, sep = "."), id, function() {
          q <- unwrap(fit)[[m]]; c(estimate = q[["ind"]], p = q[["p_delta"]])
        })
    }
    if (dataset == 3) for (o in outcomes) for (hyp in c("H1", "H3"))
      emit_influence(paste("C3", hyp, o, sep = "."), id, function() {
        q <- pooled_contrast(cell_data(z, o), if (hyp == "H1") "CC" else "LD")
        c(estimate = q[["mean_diff"]], p = q[["p"]])
      })
    if (dataset == 4) for (model in names(logit_predictors))
      emit_influence(paste("L4", model, "LoyalRequestor", sep = "."), id, function() {
        q <- logit_stats(fit_logit(z, logit_predictors[[model]]), "LoyalRequestor")
        c(estimate = q[["coef"]], p = q[["p"]])
      })
  }
}

read_data <- function(dataset) {
  d <- read.csv(file.path(opt$data, paste0("dataset_", dataset, ".csv")),
                colClasses = "character", check.names = FALSE, na.strings = c("", "NA"))
  if (anyDuplicated(names(d))) stop("Duplicate column names in dataset ", dataset)
  text_vars <- c("part_uid", "cond", "cond_rel", "broker_hist", "wrongdoing",
                 "gender_recode", "Requestee", "StrongLoyaltyRequestor_char")
  for (nm in setdiff(names(d), text_vars)) d[[nm]] <- num(d[[nm]])
  d$.row <- seq_len(nrow(d))
  if (dataset == 1) {
    if (!"part_uid" %in% names(d)) d$part_uid <- rep(NA_character_, nrow(d))
    if (!"cond" %in% names(d)) d$cond <- rep(NA_character_, nrow(d))
    # A person's identifier is their first original row number, never renumbered.
    d$.unit <- match(d$part_uid, d$part_uid)
    d$.unit[is.na(d$part_uid)] <- d$.row[is.na(d$part_uid)]
  } else d$.unit <- d$.row
  d
}
pass <- function(x) !is.na(x) & x
sample_data <- function(d, level) {
  if (level == "D1_key") {
    ok <- pass(col(d, "attn") == col(d, "wrongdoing_num"))
    bad <- unique(d$.unit[!ok])
    return(d[!d$.unit %in% bad, , drop = FALSE])
  }
  if (level %in% c("D2_any", "D2_both")) {
    expect <- ifelse(text_col(d, "cond") == "loyal_colleague", 1,
                     ifelse(text_col(d, "cond") == "control", 2, NA_real_))
    c1 <- pass(col(d, "comp1") == expect); c2 <- pass(col(d, "comp2") == 2)
    return(keep(d, if (level == "D2_any") c1 & c2 else c1 | c2))
  }
  if (level %in% c("D3_all", "D3_comp")) {
    expect1 <- ifelse(text_col(d, "cond_rel") == "loyal_colleague", 1,
                      ifelse(text_col(d, "cond_rel") == "control", 2, NA_real_))
    expect3 <- ifelse(text_col(d, "broker_hist") == "divisive", 2,
                      ifelse(text_col(d, "broker_hist") == "control", 1, NA_real_))
    ok <- pass(col(d, "comp1") == expect1) & pass(col(d, "comp2") == 2) & pass(col(d, "comp3") == expect3)
    if (level == "D3_all") {
      expected_attn <- c(1, 3, 2, 4)[match(col(d, "cond_num"), 1:4)]
      ok <- ok & pass(col(d, "attn_afterscen") == expected_attn)
    }
    return(keep(d, ok))
  }
  if (level == "D4_loyal") return(keep(d, !is.na(col(d, "LoyalRequestor"))))
  d
}

# Write doubles explicitly with 17 significant digits rather than write.csv's
# default 15-digit conversion. This preserves round-trip double precision.
write_full_csv <- function(d, path) {
  numeric_cols <- vapply(d, is.numeric, logical(1))
  for (nm in names(d)[numeric_cols]) d[[nm]] <- ifelse(is.na(d[[nm]]), "", sprintf("%.17g", d[[nm]]))
  write.table(d, file = path, sep = ",", row.names = FALSE, col.names = TRUE,
              quote = TRUE, na = "", qmethod = "double", fileEncoding = "UTF-8")
}
sample_levels <- list(c("D1_key", "D1_none"), c("D2_any", "D2_both", "D2_none"),
                      c("D3_all", "D3_comp", "D3_none"), "D4_loyal")
for (dataset in 1:4) {
  raw <- read_data(dataset)
  for (sample_level in sample_levels[[dataset]]) {
    d <- sample_data(raw, sample_level)
    context <- list(dataset = paste0("D", dataset), sample_level = sample_level, composite_level = "")
    ids <- unique(d$.unit)
    samples[[length(samples) + 1L]] <- data.frame(dataset = rep(context$dataset, length(ids)),
      sample_level = rep(sample_level, length(ids)), unit_id = as.character(ids))
    levels <- if (dataset == 4) c("existing", "mean") else c("mean", "sum", "existing")
    for (level in levels) {
      context$composite_level <- level
      message("Analyzing ", sample_level, " / ", level)
      z <- composite(d, level, dataset)
      switch(dataset, run_d1(z), run_d2(z, level == "mean"), run_d3(z), run_d4(z, level == "existing"))
    }
    context$composite_level <- if (dataset == 4) "existing" else "mean"
    message("Influence: ", sample_level)
    run_influence(composite(d, context$composite_level, dataset), dataset)
  }
}
results_df <- do.call(rbind, results)
influence_df <- if (length(influence)) do.call(rbind, influence) else data.frame(
  dataset = character(), sample_level = character(), estimand = character(), deleted_unit = character(),
  estimate = numeric(), p = numeric(), status = character(), message = character())
samples_df <- do.call(rbind, samples)
stopifnot(!anyDuplicated(results_df[c("dataset", "sample_level", "composite_level", "key", "method")]))
write_full_csv(results_df, file.path(opt$out, "results.csv"))
write_full_csv(influence_df, file.path(opt$out, "influence.csv"))
write_full_csv(samples_df, file.path(opt$out, "samples.csv"))
session <- c(capture.output(sessionInfo()), "", "Command line:", paste(commandArgs(), collapse = " "),
             "", paste("Seed:", opt$seed), paste("Bootstrap resamples per model:", opt$boot),
             "RNG: L'Ecuyer-CMRG, one nextRNGStream stream per model (shared across parallel paths).",
             "Quantile type: 7; BC tie weight: 0.5; BC critical value: 1.96.", "", "Required packages:",
             vapply(packages, function(p) paste(p, if (available[[p]]) as.character(packageVersion(p)) else "UNAVAILABLE"), character(1)),
             "", "Bootstrap stream starting states:",
             vapply(names(streams), function(id) paste(id, paste(streams[[id]], collapse = ","), sep = ": "), character(1)))
writeLines(session, file.path(opt$out, "session_info.txt"))
failed <- results_df[results_df$status == "failed", ]
failed_inf <- influence_df[influence_df$status == "failed", ]
lines <- c("# Unmet quantities", "", "This report records failures for this invocation only.", "")
if (!nrow(failed) && !nrow(failed_inf)) lines <- c(lines, "None. All requested quantities and influence refits completed.")
if (nrow(failed)) lines <- c(lines, "## Results", "", apply(failed, 1, function(r)
  paste0("- ", paste(r[c("dataset", "sample_level", "composite_level", "key", "method")], collapse = " / "), ": ", r[["message"]])))
if (nrow(failed_inf)) lines <- c(lines, "", "## Influence", "", apply(failed_inf, 1, function(r)
  paste0("- ", paste(r[c("dataset", "sample_level", "estimand", "deleted_unit")], collapse = " / "), ": ", r[["message"]])))
writeLines(lines, file.path(opt$out, "unmet.md"))
message("Wrote ", nrow(results_df), " results and ", nrow(influence_df), " influence rows; ",
        nrow(failed), " result failures and ", nrow(failed_inf), " influence failures.")
