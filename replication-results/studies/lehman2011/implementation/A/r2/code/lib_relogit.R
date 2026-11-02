# Random-intercept logit (N1): normal random effect by group, maximum likelihood with
# adaptive Gauss-Hermite quadrature (Q points, default 12).  Parameters: beta (with
# intercept), log sigma_u.  Internally the non-constant columns are standardised
# (centred and scaled) and the estimates and covariance are transformed back.

gauss_hermite <- function(Q) {
  # Golub-Welsch for weight exp(-z^2)
  i <- seq_len(Q - 1)
  J <- matrix(0, Q, Q); J[cbind(i, i + 1)] <- sqrt(i / 2); J[cbind(i + 1, i)] <- sqrt(i / 2)
  e <- eigen(J, symmetric = TRUE)
  nodes <- e$values; weights <- sqrt(pi) * e$vectors[1, ]^2
  o <- order(nodes)
  list(z = nodes[o], w = weights[o])
}

log1pexp <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))

# returns a function f(theta, want) with want in "ll", "grad" (list(ll, grad)), "parts"
re_make_loglik <- function(X, y, gid, Q = 12) {
  G <- max(gid); p <- ncol(X)
  gh <- gauss_hermite(Q)
  env <- new.env(); env$u <- rep(0, G)
  function(theta, want = "ll") {
    beta <- theta[1:p]; lsig <- theta[p + 1]; sigma <- exp(lsig)
    eta0 <- as.vector(X %*% beta)
    u <- env$u
    for (it in 1:200) {
      pr <- plogis(eta0 + u[gid])
      grad <- as.vector(rowsum(y - pr, gid)) - u / sigma^2
      hess <- -as.vector(rowsum(pr * (1 - pr), gid)) - 1 / sigma^2
      step <- -grad / hess
      step <- pmax(pmin(step, 2), -2)
      u <- u + step
      if (max(abs(step)) < 1e-10) break
    }
    env$u <- u
    pr <- plogis(eta0 + u[gid])
    tau <- 1 / sqrt(as.vector(rowsum(pr * (1 - pr), gid)) + 1 / sigma^2)
    L <- matrix(0, G, Q)
    R <- if (want != "ll") matrix(0, length(y), Q) else NULL
    U2 <- matrix(0, G, Q)
    for (q in 1:Q) {
      uq <- u + sqrt(2) * tau * gh$z[q]
      eta <- eta0 + uq[gid]
      h <- as.vector(rowsum(y * eta - log1pexp(eta), gid)) - uq^2 / (2 * sigma^2) - lsig - 0.5 * log(2 * pi)
      L[, q] <- log(gh$w[q]) + log(sqrt(2) * tau) + h + gh$z[q]^2
      if (want != "ll") { R[, q] <- y - plogis(eta); U2[, q] <- uq^2 / sigma^2 - 1 }
    }
    mx <- apply(L, 1, max)
    llg <- mx + log(rowSums(exp(L - mx)))
    ll <- sum(llg)
    if (want == "ll") return(ll)
    P <- exp(L - llg)                       # G x Q normalised quadrature weights
    wres <- rowSums(R * P[gid, , drop = FALSE])
    gbeta <- as.vector(crossprod(X, wres))
    glsig <- sum(rowSums(U2 * P))
    list(ll = ll, grad = c(gbeta, glsig), u = u, tau = tau, llg = llg)
  }
}

num_grad <- function(f, x, h = 1e-5) {
  sapply(seq_along(x), function(k) { e <- rep(0, length(x)); e[k] <- h * max(1, abs(x[k])); (f(x + e) - f(x - e)) / (2 * e[k]) })
}

re_fit <- function(X, y, group, Q = 12, start = NULL) {
  gid <- as.integer(factor(group)); G <- max(gid); p <- ncol(X)
  # standardise non-constant columns
  mu <- colMeans(X); sdv <- apply(X, 2, sd); const <- !is.finite(sdv) | sdv == 0
  mu[const] <- 0; sdv[const] <- 1
  Z <- sweep(sweep(X, 2, mu, "-"), 2, sdv, "/")
  f <- re_make_loglik(Z, y, gid, Q)
  if (is.null(start)) {
    g0 <- suppressWarnings(glm.fit(Z, y, family = binomial()))
    th0 <- c(g0$coefficients, log(0.5)); th0[is.na(th0)] <- 0
  } else {
    # start is on the original scale: gamma = beta * sd, intercept adjusted
    b <- start[1:p]; gam <- b * sdv; gam[const] <- b[const] + sum((b * mu)[!const]); th0 <- c(gam, start[p + 1])
  }
  nf <- function(th) -f(th, "ll")
  ng <- function(th) -f(th, "grad")$grad
  opt <- optim(th0, nf, ng, method = "BFGS", control = list(maxit = 5000, reltol = 1e-14))
  theta <- opt$par
  # iterations: BFGS iterations = accepted quasi-Newton steps (optim's gradient-evaluation count equals vmmin's
  # internal iteration counter, which starts at 1 after the initial gradient; subtract that one), plus the Newton
  # polishing steps below.  Function evaluations (opt$counts[1]) are reported separately in the routine string.
  n_bfgs <- as.integer(opt$counts[2]) - 1L; n_newton <- 0L; n_fn <- as.integer(opt$counts[1])
  # Newton polishing with the numerically differentiated Hessian of the analytic gradient
  H <- optimHess(theta, nf, ng, control = list(ndeps = rep(1e-5, length(theta))))
  g <- ng(theta)
  for (it in 1:20) {
    if (max(abs(g)) < 1e-6) break
    step <- tryCatch(solve(H, -g), error = function(e) NULL)
    if (is.null(step)) break
    t <- 1; f0 <- nf(theta); acc <- FALSE
    for (hh in 1:20) { thn <- theta + t * step; fn <- nf(thn); if (is.finite(fn) && fn <= f0 + 1e-10) { acc <- TRUE; break }; t <- t / 2 }
    if (!acc) break
    theta <- thn; g <- ng(theta); n_newton <- n_newton + 1L
    H <- optimHess(theta, nf, ng, control = list(ndeps = rep(1e-5, length(theta))))
  }
  ll <- f(theta, "ll")
  grad_num <- num_grad(function(th) f(th, "ll"), theta, h = 1e-6)
  Vg <- tryCatch(solve(H), error = function(e) matrix(NA_real_, length(theta), length(theta)))
  # transform back: beta_k = gamma_k / sd_k (k non-constant); intercept = gamma_0 - sum_k gamma_k mu_k / sd_k
  Tm <- diag(length(theta))
  for (k in which(!const)) Tm[k, k] <- 1 / sdv[k]
  ic <- which(const)
  if (length(ic)) for (k in which(!const)) Tm[ic, k] <- -mu[k] / sdv[k]
  beta <- as.vector(Tm %*% theta); V <- Tm %*% Vg %*% t(Tm)
  nm <- c(colnames(X), "ln_sigma_u")
  names(beta) <- nm; dimnames(V) <- list(nm, nm)
  conv <- opt$convergence == 0 && max(abs(g)) < 1e-4
  list(theta = beta, vcov = V, loglik = ll, iter = n_bfgs + n_newton, n_bfgs_iter = n_bfgs, n_newton_iter = n_newton, n_fn_evals = n_fn,
       converged = conv, max_grad = max(abs(g)), max_grad_numeric = max(abs(grad_num)),
       sigma_u = exp(beta[p + 1]), sigma_u_se = exp(beta[p + 1]) * sqrt(V[p + 1, p + 1]),
       n_obs = length(y), n_groups = G, Q = Q, p = p,
       routine = sprintf("re_fit: own R implementation, normal random intercept, ML by adaptive Gauss-Hermite quadrature (%d points; per-group mode and curvature re-estimated at every likelihood evaluation), regressors standardised internally, optim BFGS with the analytic quadrature gradient followed by Newton polishing; SE from the inverse of the numerically differentiated Hessian of the marginal log-likelihood; iterations = %d BFGS iterations + %d Newton polishing steps (%d objective evaluations in BFGS, reported separately)", Q, n_bfgs, n_newton, n_fn))
}
