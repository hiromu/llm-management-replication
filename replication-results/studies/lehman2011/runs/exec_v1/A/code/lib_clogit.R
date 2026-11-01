# Exact conditional (fixed-effects) logit.
#
# Likelihood: for stratum g with n_g observations and d_g = sum(y) events,
#   P(y_g | sum y_g = d_g) = exp(sum_{i: y_i = 1} x_i'b) / e_{d_g}(w_g),
# where w_i = exp(x_i'b) and e_d(.) is the elementary symmetric polynomial of
# degree d.  This is the likelihood maximised by Stata's clogit / xtlogit, fe
# and by survival::clogit(method = "exact").
#
# Implementation: e_d and its derivatives are obtained from the forward
# ("prefix") and backward ("suffix") recursions
#   F_j[k] = F_{j-1}[k] + w_j F_{j-1}[k-1],   S_j[k] = S_{j+1}[k] + w_j S_{j+1}[k-1],
# with per-stratum exponential tilting (w_i = exp(x_i'b - c_g), c_g chosen so
# that sum_i w_i/(1+w_i) = d_g) and per-step renormalisation, so that all
# stored quantities are probabilities of a Poisson-binomial distribution and
# never over/underflow.  Conditional inclusion probabilities
#   pi_i = w_i e_{d-1}(w_{-i}) / e_d(w) = w_i sum_k F_{i-1}[k] S_{i+1}[d-1-k] / e_d
# give the score X'(y - pi).  The observed information is
#   sum_i pi_i x_i x_i' + M + M' - g g',   M = sum_i w_i x_i A_i' / e_d,
#   A_i = sum_k dF_{i-1}[k] S_{i+1}[d-1-k],  g = X'pi,
# where dF is the gradient of the prefix polynomial (product rule).
# All strata are processed simultaneously (arrays padded to the largest
# stratum); padded rows have w = 0 and x = 0 and contribute nothing.

cl_prepare <- function(X, y, strata, drop_aliased = TRUE, tol = 1e-9) {
  stopifnot(is.matrix(X), length(y) == nrow(X), length(strata) == nrow(X))
  y <- as.numeric(y)
  if (!all(y %in% c(0, 1))) stop("y must be 0/1")
  sid <- as.integer(factor(strata))
  d_all <- tapply(y, sid, sum)
  n_all <- tapply(y, sid, length)
  keep_g <- which(d_all > 0 & d_all < n_all)
  dropped_groups <- length(d_all) - length(keep_g)
  keep <- sid %in% keep_g
  X <- X[keep, , drop = FALSE]; y <- y[keep]; sid <- as.integer(factor(sid[keep]))
  G <- max(sid)
  # within-stratum centring of X (conditional likelihood is invariant to it)
  Xc <- X - rowsum(X, sid)[sid, , drop = FALSE] / as.vector(tabulate(sid))[sid]
  aliased <- rep(FALSE, ncol(X))
  if (drop_aliased && ncol(X) > 0) {
    q <- qr(Xc, tol = tol)
    if (q$rank < ncol(X)) aliased[q$pivot[(q$rank + 1):ncol(X)]] <- TRUE
  }
  # order by stratum, build padded arrays
  o <- order(sid)
  Xc <- Xc[o, , drop = FALSE]; y <- y[o]; sid <- sid[o]
  n_g <- as.vector(tabulate(sid)); d_g <- as.vector(rowsum(y, sid))
  n_max <- max(n_g); d_max <- max(d_g)
  pos <- sequence(n_g)                      # position within stratum
  idx <- cbind(pos, sid)                    # (j, g)
  list(X = Xc, y = y, sid = sid, G = G, n_g = n_g, d_g = d_g, n_max = n_max,
       d_max = d_max, pos = pos, idx = idx, aliased = aliased, dropped_groups = dropped_groups,
       keep_rows = which(keep)[o], p = ncol(X), colnames = colnames(X))
}

# Solve for tilting constants c_g: sum_i plogis(eta_i - c_g) = d_g
cl_tilt <- function(eta, D) {
  c <- as.vector(rowsum(eta, D$sid)) / D$n_g
  for (it in 1:100) {
    pr <- plogis(eta - c[D$sid])
    f <- as.vector(rowsum(pr, D$sid)) - D$d_g
    fp <- -as.vector(rowsum(pr * (1 - pr), D$sid))
    step <- f / fp
    step <- pmax(pmin(step, 5), -5)
    c <- c - step
    if (max(abs(f)) < 1e-10 * max(1, max(D$d_g))) break
  }
  c
}

# Core evaluation: returns loglik, (score), (information)
cl_eval <- function(beta, D, want = "ll") {
  p <- D$p; G <- D$G; n_max <- D$n_max; Dm <- D$d_max
  eta <- as.vector(D$X %*% beta)
  cg <- cl_tilt(eta, D)
  leta <- eta - cg[D$sid]
  W <- matrix(0, n_max, G); W[D$idx] <- exp(leta)           # padded weights (n_max x G)
  # suffix sweep (values only), stored
  S <- array(0, c(n_max + 2, G, Dm + 1)); sS <- matrix(0, n_max + 2, G)
  cur <- matrix(0, G, Dm + 1); cur[, 1] <- 1
  S[n_max + 1, , ] <- cur
  for (j in n_max:1) {
    wj <- W[j, ]
    new <- cur
    new[, 2:(Dm + 1)] <- cur[, 2:(Dm + 1)] + wj * cur[, 1:Dm]
    m <- rowSums(new); new <- new / m
    sS[j, ] <- sS[j + 1, ] + log(m)
    S[j, , ] <- new; cur <- new
  }
  # prefix sweep (values), stored
  Fv <- array(0, c(n_max + 1, G, Dm + 1)); sF <- matrix(0, n_max + 1, G)
  cur <- matrix(0, G, Dm + 1); cur[, 1] <- 1
  Fv[1, , ] <- cur
  for (j in 1:n_max) {
    wj <- W[j, ]
    new <- cur
    new[, 2:(Dm + 1)] <- cur[, 2:(Dm + 1)] + wj * cur[, 1:Dm]
    m <- rowSums(new); new <- new / m
    sF[j + 1, ] <- sF[j, ] + log(m)
    Fv[j + 1, , ] <- new; cur <- new
  }
  # log e_d per stratum
  Fn <- Fv[n_max + 1, , , drop = FALSE]
  Fnd <- Fn[cbind(1, 1:G, D$d_g + 1)]
  log_ed <- log(Fnd) + sF[n_max + 1, ]
  ll <- sum(leta[D$y == 1]) - sum(log_ed)
  out <- list(ll = ll)
  if (want == "ll") return(out)
  # inclusion probabilities pi
  Sdot <- matrix(0, n_max, G)      # sum_k F_{j-1}[k] S_{j+1}[d-1-k]
  for (g in 1:G) {
    d <- D$d_g[g]; n <- D$n_g[g]
    Fm <- Fv[1:n, g, 1:d, drop = FALSE]; dim(Fm) <- c(n, d)
    Sm <- S[2:(n + 1), g, d:1, drop = FALSE]; dim(Sm) <- c(n, d)
    Sdot[1:n, g] <- rowSums(Fm * Sm)
  }
  # scale factor r[j,g] = w exp(sF[j-1]+sS[j+1]-log e_d)
  lr <- log(W) + sF[1:n_max, ] + sS[2:(n_max + 1), ] - rep(log_ed, each = n_max)
  lr[W == 0] <- -Inf
  R <- exp(lr)
  PI <- R * Sdot
  pi_i <- PI[D$idx]
  score <- as.vector(crossprod(D$X, D$y - pi_i))
  out$pi <- pi_i; out$score <- score; out$pi_sum_check <- max(abs(as.vector(rowsum(pi_i, D$sid)) - D$d_g))
  if (want == "score") return(out)
  # information: prefix gradient sweep (layout p x G x (Dm+1))
  Xp <- array(0, c(n_max, G, p)); Xp[cbind(rep(D$idx[, 1], p), rep(D$idx[, 2], p), rep(1:p, each = nrow(D$X)))] <- as.vector(D$X)
  # reversed-S index: Rmat[g, k+1] = S[j+1, g, d_g - k] for k = 0..d_g-1
  kk <- rep(0:(Dm - 1), each = G); gg <- rep(1:G, Dm)
  col <- D$d_g[gg] - kk; valid <- col >= 1
  GF <- array(0, c(p, G, Dm + 1))
  M <- matrix(0, p, p)
  cur <- matrix(0, G, Dm + 1); cur[, 1] <- 1
  for (j in 1:n_max) {
    wj <- W[j, ]
    Fprev <- Fv[j, , , drop = TRUE]; if (G == 1) Fprev <- matrix(Fprev, 1)
    xj <- Xp[j, , , drop = TRUE]; if (G == 1) xj <- matrix(xj, 1) ; if (p == 1) xj <- matrix(xj, G, 1)
    # A_j = sum_k GF[,,k] * Rmat[g,k]
    Sj <- S[j + 1, , , drop = TRUE]; if (G == 1) Sj <- matrix(Sj, 1)
    Rm <- matrix(0, G, Dm)
    Rm[cbind(gg[valid], kk[valid] + 1)] <- Sj[cbind(gg[valid], col[valid])]
    A <- rowSums(GF[, , 1:Dm, drop = FALSE] * rep(Rm, each = p), dims = 2)   # p x G
    rj <- R[j, ]                                                            # length G
    M <- M + crossprod(xj * rj, t(A))
    # update GF
    xrep <- as.vector(t(xj))                                                # p*G
    GFnew <- GF
    GFnew[, , 2:(Dm + 1)] <- GF[, , 2:(Dm + 1)] + rep(wj, each = p) * (GF[, , 1:Dm, drop = FALSE] + xrep * rep(Fprev[, 1:Dm], each = p))
    # renormalise with the same factor used for Fv at step j: factor = exp(sF[j+1]-sF[j])
    fac <- exp(sF[j + 1, ] - sF[j, ])
    GF <- GFnew / rep(fac, each = p)
  }
  # information = sum_i pi_i x_i x_i' + M + M' - sum_g g_g g_g'
  Gm <- rowsum(D$X * pi_i, D$sid)                                           # G x p stratum gradients
  info <- crossprod(D$X * pi_i, D$X) + M + t(M) - crossprod(Gm)
  out$info <- info
  out
}

# Newton-Raphson maximisation
#   start: optional starting values (names matching colnames(X) are not required; positional).
#   info0: optional information matrix at `start` from a previous (full-sample) fit of the same
#          model: when given, iterations use this fixed matrix for the Newton direction (score-only
#          evaluations) until the score tolerance is met, then the exact information is evaluated
#          at the solution for the covariance.  Falls back to full Newton-Raphson if that stalls.
cl_fit <- function(X, y, strata, start = NULL, info0 = NULL, maxit = 50, tol_grad = 1e-7, tol_ll = 1e-11) {
  D <- cl_prepare(X, y, strata)
  p_all <- D$p
  use <- !D$aliased
  Dr <- D; Dr$X <- D$X[, use, drop = FALSE]; Dr$p <- sum(use)
  p <- Dr$p
  beta <- if (is.null(start)) rep(0, p) else { s <- start[use]; s[is.na(s)] <- 0; s }
  fixed <- !is.null(start) && !is.null(info0) && all(dim(info0) == c(p_all, p_all)) && all(is.finite(info0[use, use]))
  ev <- if (fixed) cl_eval(beta, Dr, "score") else cl_eval(beta, Dr, "info")
  ll0_at_zero <- if (is.null(start)) ev$ll else cl_eval(rep(0, p), Dr, "ll")$ll
  converged <- FALSE; iter <- 0; status <- "ok"; msg <- ""; n_fixed <- 0
  if (max(abs(ev$score)) < tol_grad) converged <- TRUE
  while (!converged && iter < maxit) {
    iter <- iter + 1
    H <- if (fixed) info0[use, use, drop = FALSE] else ev$info
    step <- tryCatch(solve(H, ev$score), error = function(e) NULL)
    if (is.null(step) || any(!is.finite(step))) { status <- "failed"; msg <- "singular information matrix"; break }
    # step halving on the (cheap) log-likelihood + score evaluation
    t <- 1; accepted <- FALSE
    for (h in 1:30) {
      bnew <- beta + t * step
      evn <- cl_eval(bnew, Dr, "score")
      if (is.finite(evn$ll) && evn$ll >= ev$ll - 1e-12 * abs(ev$ll)) { accepted <- TRUE; break }
      t <- t / 2
    }
    if (!accepted) { status <- "failed"; msg <- "step halving failed"; break }
    dll <- evn$ll - ev$ll
    beta <- bnew
    if (max(abs(evn$score)) < tol_grad && abs(dll) < tol_ll * (abs(evn$ll) + 1)) {
      converged <- TRUE
      ev <- cl_eval(beta, Dr, "info")        # information at the MLE (covariance)
    } else if (fixed) {
      n_fixed <- n_fixed + 1
      if (n_fixed >= 25 || t < 1) { fixed <- FALSE; ev <- cl_eval(beta, Dr, "info") }   # stalled: switch to full Newton
      else ev <- evn
    } else {
      ev <- cl_eval(beta, Dr, "info")
    }
  }
  if (converged && is.null(ev$info)) ev <- cl_eval(beta, Dr, "info")
  if (!converged && status == "ok") { status <- "not_converged"; msg <- sprintf("max |score| = %.3g after %d iterations", max(abs(ev$score)), iter) }
  if (is.null(ev$info)) ev <- cl_eval(beta, Dr, "info")
  vcov_r <- tryCatch(solve(ev$info), error = function(e) matrix(NA_real_, p, p))
  coef <- rep(NA_real_, p_all); coef[use] <- beta
  V <- matrix(NA_real_, p_all, p_all); V[use, use] <- vcov_r
  I <- matrix(NA_real_, p_all, p_all); I[use, use] <- ev$info
  names(coef) <- D$colnames; dimnames(V) <- list(D$colnames, D$colnames); dimnames(I) <- dimnames(V)
  null_ll <- -sum(lchoose(D$n_g, D$d_g))
  list(coef = coef, vcov = V, info = I, loglik = ev$ll, null_loglik = null_ll, ll_at_zero = ll0_at_zero,
       n_obs = nrow(D$X), n_groups = D$G, n_groups_dropped = D$dropped_groups,
       iter = iter, converged = converged, status = status, message = msg,
       max_score = max(abs(ev$score)), pi_sum_check = ev$pi_sum_check,
       aliased = D$aliased, keep_rows = D$keep_rows, df = p,
       routine = paste0("cl_fit: own R implementation of the exact conditional logit (elementary symmetric polynomial prefix/suffix recursions with exponential tilting), Newton-Raphson with step halving, tol max|score|<1e-7",
                        if (!is.null(start)) "; warm start from full-sample estimates" else "",
                        if (n_fixed > 0) sprintf(" (%d fixed-information iterations)", n_fixed) else ""))
}

# Direct enumeration of the conditional log-likelihood (small strata only)
cl_enum_loglik <- function(beta, X, y, strata) {
  sid <- as.integer(factor(strata)); eta <- as.vector(X %*% beta); ll <- 0
  for (g in unique(sid)) {
    i <- which(sid == g); d <- sum(y[i]); n <- length(i)
    if (d == 0 || d == n) next
    num <- sum(eta[i][y[i] == 1])
    cmb <- combn(n, d)
    terms <- apply(cmb, 2, function(s) sum(eta[i][s]))
    mx <- max(terms)
    ll <- ll + num - (mx + log(sum(exp(terms - mx))))
  }
  ll
}
