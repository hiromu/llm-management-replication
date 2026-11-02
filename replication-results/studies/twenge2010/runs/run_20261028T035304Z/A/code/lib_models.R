# lib_models.R -- lavaan syntax generation, fitting, fit indices, latent outputs (MANIFEST Section 4)

suppressPackageStartupMessages(library(lavaan))

LAV_CONTROL <- list(rel.tol = 1e-10, iter.max = 10000L, eval.max = 20000L)

# ---- syntax ------------------------------------------------------------------------------------
# factors: named list factor -> items; markers: named chr factor -> marker item
# G: number of groups
# ident: "marker"        marker loading 1, all intercepts free, factor means fixed 0 (4.1, M1, M2)
#        "marker_scalar" marker loading 1, marker intercept 0 in every group, factor means free (M3-M5)
#        "effects"       all loadings free, average 1 per factor (and group); intercepts sum to 0 per factor and group
#        "fixed_factor"  all loadings free, all intercepts free, group 1 factor means 0 and variances 1 (CHK1)
# loadings_equal / intercepts_equal / means_equal: cross-group equality
# released: items whose intercepts are free in every group (never equal across groups)
# single_indicator: factors whose single indicator has loading 1 and residual variance 0 (C2)
build_syntax <- function(factors, markers, G = 1L, ident = "marker",
                         loadings_equal = FALSE, intercepts_equal = FALSE, means_equal = FALSE,
                         released = character(0), single_indicator = character(0)) {
  vec <- function(x) if (G == 1L) x[1] else paste0("c(", paste(x, collapse = ","), ")")
  glab <- function(base) paste0(base, "_g", seq_len(G))
  lines <- character(0)
  constraints <- character(0)
  # lavaan parses a group vector that mixes numbers and labels (e.g. c(0, A_g2, A_g3)) as labels only, so
  # parameters that must be fixed in some groups but free (and labelled) in others are labelled everywhere and
  # fixed afterwards through the parameter table (see fit_lavaan). `fixed` maps label -> fixed value.
  fixed <- numeric(0)
  items_all <- unname(unlist(factors))
  for (K in names(factors)) {
    its <- factors[[K]]
    single <- K %in% single_indicator
    # loadings
    terms <- character(0)
    for (it in its) {
      if (single || (ident %in% c("marker", "marker_scalar") && it == markers[[K]])) {
        lab <- rep("1", G)
      } else if (loadings_equal) {
        lab <- rep(paste0("L_", it), G)
      } else {
        lab <- glab(paste0("L_", it))
      }
      terms <- c(terms, paste0(vec(lab), "*", it))
    }
    lines <- c(lines, paste0(K, " =~ ", paste(terms, collapse = " + ")))
    # factor mean
    if (ident == "marker") {
      amean <- rep("0", G)
    } else if (ident == "fixed_factor") {
      amean <- glab(paste0("A_", K)); fixed[amean[1]] <- 0
    } else if (means_equal) {
      amean <- rep(paste0("A_", K), G)
    } else {
      amean <- glab(paste0("A_", K))
    }
    lines <- c(lines, paste0(K, " ~ ", vec(amean), "*1"))
    # factor variance
    if (ident == "fixed_factor") {
      pvar <- glab(paste0("P_", K)); fixed[pvar[1]] <- 1
    } else {
      pvar <- glab(paste0("P_", K))
    }
    lines <- c(lines, paste0(K, " ~~ ", vec(pvar), "*", K))
    # effects-coding constraints on loadings
    if (ident == "effects" && !single) {
      if (loadings_equal) {
        constraints <- c(constraints, paste0(paste(paste0("L_", its), collapse = " + "), " == ", length(its)))
      } else {
        for (g in seq_len(G)) constraints <- c(constraints, paste0(paste(paste0("L_", its, "_g", g), collapse = " + "), " == ", length(its)))
      }
    }
  }
  # intercepts and residual variances
  for (K in names(factors)) {
    its <- factors[[K]]
    single <- K %in% single_indicator
    ilabs <- list()
    for (it in its) {
      if (ident == "marker") {
        lab <- if (intercepts_equal && !(it %in% released)) rep(paste0("N_", it), G) else glab(paste0("N_", it))
      } else if (ident == "marker_scalar" && it == markers[[K]]) {
        lab <- rep("0", G)
      } else if (it %in% released) {
        lab <- glab(paste0("N_", it))
      } else if (intercepts_equal) {
        lab <- rep(paste0("N_", it), G)
      } else {
        lab <- glab(paste0("N_", it))
      }
      ilabs[[it]] <- lab
      lines <- c(lines, paste0(it, " ~ ", vec(lab), "*1"))
      evar <- if (single) rep("0", G) else glab(paste0("E_", it))
      lines <- c(lines, paste0(it, " ~~ ", vec(evar), "*", it))
    }
    if (ident == "effects" && !single) {
      for (g in seq_len(G)) {
        constraints <- c(constraints, paste0(paste(vapply(its, function(it) ilabs[[it]][g], ""), collapse = " + "), " == 0"))
      }
    }
  }
  # factor covariances, all free in every group
  Ks <- names(factors)
  if (length(Ks) > 1) {
    for (i in 1:(length(Ks) - 1)) for (j in (i + 1):length(Ks)) {
      lines <- c(lines, paste0(Ks[i], " ~~ ", vec(glab(paste0("C_", Ks[i], "_", Ks[j]))), "*", Ks[j]))
    }
  }
  constraints <- unique(constraints)
  out <- paste(c(lines, constraints), collapse = "\n")
  attr(out, "fixed") <- fixed
  attr(out, "ngroups") <- G
  out
}

LAVAANIFY_OPTS <- list(meanstructure = TRUE, auto.var = FALSE, auto.fix.first = FALSE, auto.cov.lv.x = FALSE,
                       int.ov.free = FALSE, int.lv.free = FALSE)

# Turn syntax into a lavaan parameter table, fixing the labelled parameters listed in attr(syntax, "fixed").
syntax_to_partable <- function(syntax) {
  fixed <- attr(syntax, "fixed")
  G <- attr(syntax, "ngroups"); if (is.null(G)) G <- 1L
  PT <- do.call(lavaan::lavaanify, c(list(model = as.character(syntax), ngroups = G), LAVAANIFY_OPTS))
  if (length(fixed)) {
    for (lab in names(fixed)) {
      i <- which(PT$label == lab)
      if (!length(i)) stop("label to fix not found: ", lab)
      PT$free[i] <- 0L; PT$ustart[i] <- fixed[[lab]]
      if ("start" %in% names(PT)) PT$start[i] <- fixed[[lab]]
    }
    PT$free[PT$free > 0] <- seq_len(sum(PT$free > 0))
  }
  PT
}

# ---- fitting -----------------------------------------------------------------------------------
# input: list(type = "moments", cov = list, mean = list, nobs = numeric)  or
#        list(type = "data", data = data.frame, group = "group" or NULL)
# est: list(likelihood = "wishart"|"normal", estimator = "ML"|"MLR", missing = "listwise"|"fiml", information = "expected")
fit_lavaan <- function(syntax, input, est, start = NULL) {
  warns <- character(0)
  model <- if (length(attr(syntax, "fixed"))) syntax_to_partable(syntax) else as.character(syntax)
  args <- list(model = model, meanstructure = TRUE, information = est$information,
               control = LAV_CONTROL, estimator = est$estimator, likelihood = est$likelihood,
               auto.var = FALSE, auto.fix.first = FALSE, auto.cov.lv.x = FALSE,
               int.ov.free = FALSE, int.lv.free = FALSE, check.start = FALSE, warn = TRUE)
  if (input$type == "moments") {
    args$sample.cov <- input$cov
    args$sample.mean <- input$mean
    args$sample.nobs <- input$nobs
    args$sample.cov.rescale <- FALSE
  } else {
    args$data <- input$data
    if (!is.null(input$group)) args$group <- input$group
    args$missing <- est$missing
  }
  if (!is.null(start)) args$start <- start
  fit <- NULL; err <- NULL
  t0 <- proc.time()[["elapsed"]]
  fit <- withCallingHandlers(
    tryCatch(do.call(lavaan::lavaan, args), error = function(e) { err <<- conditionMessage(e); NULL }),
    warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") })
  elapsed <- proc.time()[["elapsed"]] - t0
  conv <- if (!is.null(fit)) isTRUE(lavInspect(fit, "converged")) else FALSE
  opt <- if (!is.null(fit)) lavInspect(fit, "optim") else NULL
  list(fit = fit, converged = conv, error = err, warnings = unique(gsub("\\s+", " ", warns)),
       iterations = if (!is.null(opt)) opt$iterations else NA_integer_,
       fx = if (!is.null(opt)) opt$fx else NA_real_, seconds = elapsed,
       status = if (!is.null(err)) "error" else if (conv) "converged" else "not_converged")
}

convergence_record <- function(f) {
  list(status = f$status, converged = f$converged, iterations = f$iterations, objective = f$fx,
       optimizer = "nlminb", control = LAV_CONTROL, error = f$error, warnings = f$warnings,
       seconds = f$seconds, npar = if (!is.null(f$fit)) unname(fitMeasures(f$fit, "npar")) else NA)
}

# ---- fit indices -------------------------------------------------------------------------------
# Manifest discrepancy F_g for one group
F_group <- function(S, m, Sigma, mu) {
  p <- ncol(S)
  Si <- solve(Sigma)
  d <- as.numeric(m - mu)
  as.numeric(determinant(Sigma, logarithm = TRUE)$modulus) + sum(diag(S %*% Si)) -
    as.numeric(determinant(S, logarithm = TRUE)$modulus) - p + as.numeric(t(d) %*% Si %*% d)
}

srmr_group <- function(S, Sigma) {
  sd <- sqrt(diag(S))
  R <- (S - Sigma) / outer(sd, sd)
  r <- R[lower.tri(R, diag = TRUE)]
  sqrt(mean(r^2))
}

baseline_chisq_closed <- function(cov_list, cg) {
  # baseline: free means and variances, zero covariances, no cross-group constraints -> F_g = sum log s_ii - log|S_g|
  Fb <- vapply(cov_list, function(S) sum(log(diag(S))) - as.numeric(determinant(S, logarithm = TRUE)$modulus), 0)
  p <- ncol(cov_list[[1]])
  list(chisq = sum(cg * Fb), df = length(cov_list) * p * (p - 1) / 2, F_g = Fb)
}

# fit indices from a fitted lavaan model.
#   cov_list/mean_list: the sample moments used (per group); cg: per-group weights c_g; nobs: n_g
#   source = "manifest": chi-square from the manifest formula with lavaan's implied moments; baseline closed form
#   source = "lavaan"  : chi-square and baseline from lavaan (FIML, MLR)
fit_indices <- function(fit, cov_list, mean_list, cg, nobs, source = c("manifest", "lavaan")) {
  source <- match.arg(source)
  G <- length(cov_list)
  p <- ncol(cov_list[[1]])
  imp <- lavInspect(fit, "implied")
  if (G == 1L && !is.null(imp$cov)) imp <- list(imp)
  vn <- colnames(cov_list[[1]])
  Fg <- numeric(G); srmr_g <- numeric(G)
  for (g in seq_len(G)) {
    Sigma <- as.matrix(imp[[g]]$cov)[vn, vn]
    mu <- as.numeric(imp[[g]]$mean)[match(vn, names(imp[[g]]$mean))]
    Fg[g] <- F_group(cov_list[[g]][vn, vn], mean_list[[g]][vn], Sigma, mu)
    srmr_g[g] <- srmr_group(cov_list[[g]][vn, vn], Sigma)
  }
  fm <- fitMeasures(fit, c("chisq", "df", "pvalue", "npar", "baseline.chisq", "baseline.df", "cfi", "tli", "rmsea", "srmr"))
  extra <- tryCatch(fitMeasures(fit, c("srmr_bentler", "srmr_bentler_nomean", "srmr_mplus", "srmr_mplus_nomean")), error = function(e) NULL)
  if (!is.null(extra)) fm <- c(fm, extra)
  df <- unname(fm["df"]); npar <- unname(fm["npar"])
  if (source == "manifest") {
    chisq <- sum(cg * Fg)
    bl <- baseline_chisq_closed(lapply(cov_list, function(S) S[vn, vn]), cg)
    chisq_b <- bl$chisq; df_b <- bl$df
  } else {
    chisq <- unname(fm["chisq"]); chisq_b <- unname(fm["baseline.chisq"]); df_b <- unname(fm["baseline.df"])
  }
  N <- sum(nobs)
  pval <- if (df > 0) pchisq(chisq, df, lower.tail = FALSE) else NA_real_
  rmsea <- if (df > 0) sqrt(G) * sqrt(max(chisq - df, 0) / (df * sum(cg))) else NA_real_
  cfi <- 1 - max(chisq - df, 0) / max(chisq_b - df_b, chisq - df, 0)
  tli <- if (df > 0) ((chisq_b / df_b) - (chisq / df)) / ((chisq_b / df_b) - 1) else NA_real_
  srmr <- sum((nobs / N) * srmr_g)
  list(chisq = chisq, df = df, pvalue = pval, npar = npar,
       sample_moments_per_group = p * (p + 3) / 2, n_groups = G, sum_cg = sum(cg), N = N,
       rmsea = rmsea, cfi = cfi, tli = tli, srmr = srmr,
       baseline_chisq = chisq_b, baseline_df = df_b,
       F_g = as.list(setNames(Fg, names(cov_list))), srmr_g = as.list(setNames(srmr_g, names(cov_list))),
       chisq_source = source,
       lavaan_fitmeasures = as.list(fm))
}

# S06: the scaled (Yuan-Bentler, lavaan MLR) model chi-square only (manifest Section 5, S06)
scaled_fit_record <- function(fit) {
  fm <- tryCatch(fitMeasures(fit, c("chisq.scaled", "df.scaled", "pvalue.scaled", "chisq.scaling.factor")), error = function(e) NULL)
  if (is.null(fm)) return(NULL)
  as.list(fm)
}

fit_difference <- function(fa, fb, name_a, name_b) {
  # fa less constrained, fb more constrained
  d_chi <- fb$chisq - fa$chisq; d_df <- fb$df - fa$df
  list(models = paste0(name_b, " - ", name_a), chisq_diff = d_chi, df_diff = d_df,
       pvalue = if (d_df > 0) pchisq(d_chi, d_df, lower.tail = FALSE) else NA_real_,
       cfi_diff = fa$cfi - fb$cfi)
}

# ---- parameter extraction ----------------------------------------------------------------------
param_table <- function(fit) {
  pe <- tryCatch(parameterEstimates(fit, remove.nonfree = FALSE, remove.eq = FALSE), error = function(e) NULL)
  if (is.null(pe)) return(NULL)
  pe[, intersect(c("lhs", "op", "rhs", "group", "label", "est", "se", "z", "pvalue"), names(pe))]
}

# est by label (fixed values included via the parameter table); vcov by label (fixed -> 0)
get_est <- function(PT, lab) { i <- which(PT$label == lab); if (length(i)) PT$est[i[1]] else NA_real_ }

latent_outputs <- function(fit, factors, G, nobs, group_names = YEARS) {
  PT <- parTable(fit)
  V <- lavInspect(fit, "vcov")
  vn <- rownames(V)
  vget <- function(a, b) if (a %in% vn && b %in% vn) V[a, b] else 0
  # estimate of a parameter by position (works for fixed, unlabelled parameters too)
  pt_est <- function(lhs, op, rhs, g) { i <- which(PT$lhs == lhs & PT$op == op & PT$rhs == rhs & PT$group == g); if (length(i)) PT$est[i[1]] else NA_real_ }
  # the vcov label actually used for the mean of factor K in group g (group-specific or shared)
  mean_label <- function(K, g) { i <- which(PT$lhs == K & PT$op == "~1" & PT$group == g); if (length(i) && nzchar(PT$label[i[1]])) PT$label[i[1]] else paste0("A_", K, "_g", g) }
  out <- list(); deltas <- list()
  for (K in names(factors)) {
    byg <- list()
    for (g in seq_len(G)) {
      al <- mean_label(K, g)
      alpha <- pt_est(K, "~1", "", g)
      se <- sqrt(max(vget(al, al), 0))
      psi <- pt_est(K, "~~", K, g)
      byg[[group_names[g]]] <- list(alpha = alpha, se = se, ci_lower = alpha - 1.96 * se, ci_upper = alpha + 1.96 * se,
                                    psi = psi, sd = sqrt(psi), n = nobs[g])
    }
    out[[K]] <- byg
    dl <- list()
    for (P in names(PAIRS)) {
      a <- match(PAIRS[[P]][1], group_names); b <- match(PAIRS[[P]][2], group_names)
      la <- mean_label(K, a); lb <- mean_label(K, b)
      delta <- byg[[b]]$alpha - byg[[a]]$alpha
      vd <- vget(la, la) + vget(lb, lb) - 2 * vget(la, lb)
      se <- sqrt(max(vd, 0))
      z <- delta / se
      dl[[P]] <- list(earlier = PAIRS[[P]][1], later = PAIRS[[P]][2], delta = delta, se = se,
                      cov_alpha_a_b = vget(la, lb), z = z, pvalue = 2 * pnorm(-abs(z)))
    }
    deltas[[K]] <- dl
  }
  list(by_group = out, deltas = deltas)
}

# standardized contrasts (4.4). obs_sd: list factor -> named numeric SD of unit-weighted item means per group
standardized_contrasts <- function(lat, factors, nobs, obs_sd, group_names = YEARS) {
  out <- list()
  for (K in names(factors)) {
    cl <- list()
    for (P in names(PAIRS)) {
      ga <- PAIRS[[P]][1]; gb <- PAIRS[[P]][2]
      a <- match(ga, group_names); b <- match(gb, group_names)
      delta <- lat$deltas[[K]][[P]]$delta
      psa <- lat$by_group[[K]][[ga]]$psi; psb <- lat$by_group[[K]][[gb]]$psi
      na <- nobs[a]; nb <- nobs[b]
      d_eq <- delta / sqrt((psa + psb) / 2)
      d_df <- delta / sqrt(((na - 1) * psa + (nb - 1) * psb) / (na + nb - 2))
      g <- d_eq * (1 - 3 / (4 * (na + nb) - 9))
      d_glass <- delta / sqrt(psa)
      sa <- obs_sd[[K]][[ga]]; sb <- obs_sd[[K]][[gb]]
      d_obs <- if (is.na(sa) || is.na(sb)) NA_real_ else delta / sqrt((sa^2 + sb^2) / 2)
      cl[[P]] <- list(delta = delta, d_eq = d_eq, d_df = d_df, g = g, d_glass = d_glass, d_obs = d_obs,
                      n_a = na, n_b = nb, psi_a = psa, psi_b = psb, s_obs_a = sa, s_obs_b = sb)
      if (is.na(d_obs)) cl[[P]]$d_obs_status <- "unavailable"
    }
    out[[K]] <- cl
  }
  out
}

# SD (divisor n_g - 1; weighted with the normalized weights for S01) of the unit-weighted mean of the factor's
# items, computed over every record of the multigroup analysis sample (manifest 4.4, d_obs). The unit-weighted
# mean is defined only for records with all items of the factor present; if any record of the sample lacks one
# (possible only under FIML, S04) the SD is NA (unavailable) -- no available-item means and no record exclusion.
# Returns list(sd = factor -> group -> SD or NA, n_incomplete = factor -> group -> number of such records).
observed_scale_sd <- function(samples, factors, weighted = FALSE) {
  sds <- list(); ninc <- list()
  for (K in names(factors)) {
    sds[[K]] <- list(); ninc[[K]] <- list()
    for (gname in names(samples)) {
      s <- samples[[gname]]
      X <- as.matrix(s[, factors[[K]], with = FALSE])
      sc <- rowMeans(X)                      # unit-weighted mean; NA if any item of the factor is missing
      n_inc <- sum(!is.finite(sc))
      ninc[[K]][[gname]] <- n_inc
      if (n_inc > 0) { sds[[K]][[gname]] <- NA_real_; next }
      n <- length(sc)
      if (weighted) {
        w <- s$w                              # already normalized to sum n within the analysis sample
        m <- sum(w * sc) / n
        sds[[K]][[gname]] <- sqrt(sum(w * (sc - m)^2) / (n - 1))
      } else {
        sds[[K]][[gname]] <- sd(sc)
      }
    }
  }
  list(sd = sds, n_incomplete = ninc)
}
