# lib_stats.R -- item statistics (4.6) and coefficient alpha (4.5)

item_top <- function(item, x) {
  if (item %in% F4_ITEMS) return(x == 4)
  if (item == "V3227") return(x == 1)
  if (item %in% F3_ITEMS_5) return(x %in% c(4, 5))
  stop("unknown item ", item)
}

# unweighted descriptives for one item in one sample (x already restricted to valid values)
item_desc <- function(x, top) {
  n <- length(x)
  list(n = n, mean = mean(x), sd = sd(x), pct_top = 100 * mean(top))
}

# weighted descriptives (S01); w normalized to sum n
item_desc_w <- function(x, top, w) {
  n <- length(x); W <- sum(w); w2 <- sum(w^2)
  m <- sum(w * x) / W
  s2 <- sum(w * (x - m)^2) / (W - w2 / W)
  v <- s2 * w2 / W^2
  list(n = n, sum_w = W, sum_w2 = w2, mean = m, sd = sqrt(s2), var_mean = v, pct_top = 100 * sum(w * top) / W)
}

pair_tests <- function(a, b) {
  # a, b: item_desc lists (unweighted). Student pooled and Welch.
  diff <- b$mean - a$mean
  na <- a$n; nb <- b$n; va <- a$sd^2; vb <- b$sd^2
  sp2 <- ((na - 1) * va + (nb - 1) * vb) / (na + nb - 2)
  t_s <- diff / sqrt(sp2 * (1 / na + 1 / nb)); df_s <- na + nb - 2
  se_w2 <- va / na + vb / nb
  t_w <- diff / sqrt(se_w2)
  df_w <- se_w2^2 / ((va / na)^2 / (na - 1) + (vb / nb)^2 / (nb - 1))
  list(mean_diff = diff,
       student_t = t_s, student_df = df_s, student_p = 2 * pt(-abs(t_s), df_s),
       welch_t = t_w, welch_df = df_w, welch_p = 2 * pt(-abs(t_w), df_w),
       pct_top_diff = b$pct_top - a$pct_top)
}

pair_tests_w <- function(a, b) {
  diff <- b$mean - a$mean
  z <- diff / sqrt(a$var_mean + b$var_mean)
  list(mean_diff = diff, z = z, z_p = 2 * pnorm(-abs(z)), pct_top_diff = b$pct_top - a$pct_top)
}

# item statistics for all items of a form over the three years.
# samples_fn(year, item) returns the analysis sample (data.table with item column and w)
item_statistics <- function(items, samples_fn, weighted = FALSE) {
  out <- list(); samples <- list()
  for (it in items) {
    byy <- list(); desc <- list()
    for (y in YEARS) {
      s <- samples_fn(y, it)
      x <- s[[it]]; top <- item_top(it, x)
      d <- if (weighted) item_desc_w(x, top, s$w) else item_desc(x, top)
      desc[[y]] <- d
      byy[[y]] <- d
      samples[[it]][[y]] <- sample_record(s)
    }
    pr <- list()
    for (P in names(PAIRS)) {
      a <- desc[[PAIRS[[P]][1]]]; b <- desc[[PAIRS[[P]][2]]]
      pr[[P]] <- c(list(earlier = PAIRS[[P]][1], later = PAIRS[[P]][2]), if (weighted) pair_tests_w(a, b) else pair_tests(a, b))
    }
    out[[it]] <- list(by_year = byy, pairs = pr)
  }
  list(items = out, samples = samples)
}

# coefficient alpha from a covariance matrix (raw covariance version)
alpha_from_cov <- function(C) {
  k <- ncol(C)
  k / (k - 1) * (1 - sum(diag(C)) / sum(C))
}

coefficient_alpha <- function(X, w = NULL) {
  X <- as.matrix(X)
  mom <- sample_moments(X, w = w, divisor = "n-1")
  list(k = ncol(X), n = nrow(X), alpha = alpha_from_cov(mom$cov))
}
