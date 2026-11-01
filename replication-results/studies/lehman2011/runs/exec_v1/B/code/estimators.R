softplus <- function(x) pmax(x,0)+log1p(exp(-abs(x)))
pnorm2 <- function(z) 2*pnorm(-abs(z))
num_jac <- function(fun, b, h=1e-5) {
  vapply(seq_along(b), function(j) {
    step <- h*max(1,abs(b[j])); a <- b; c <- b
    a[j] <- a[j]+step; c[j] <- c[j]-step
    (fun(a)-fun(c))/(2*step)
  }, numeric(length(fun(b))))
}
init_native <- function() {
  dir.create('results/native',showWarnings=FALSE)
  file.copy('code/exact.c','results/native/exact.c',overwrite=TRUE)
  so <- file.path('results/native',paste0('exact',.Platform$dynlib.ext))
  if (file.exists(so)) unlink(so)
  log <- system2(file.path(R.home('bin'),'R'), c('CMD','SHLIB','-o',shQuote(so),'results/native/exact.c'),stdout=TRUE,stderr=TRUE)
  writeLines(log,'results/native/build.log')
  if (!file.exists(so)) stop('Native exact kernel compilation failed; see results/native/build.log')
  dyn.load(normalizePath(so))
}
conditional_eval <- function(b,X,y,lengths) {
  z <- .Call('conditional_kernel',as.double(X%*%b),as.double(y),as.integer(lengths))
  list(value=-z[[1]],gradient=-drop(crossprod(X,z[[2]])))
}
# Full-rank basis is selected on the centered (conditional) design. Structural
# aliases, e.g. the deleted season's dummy, are retained as NA output terms.
fit_conditional <- function(X,y,group,start=NULL) {
  group <- as.character(group); allg <- unique(group)
  vary <- tapply(y,group,function(v) length(unique(v))==2)
  used <- which(vary[group]); group <- group[used]; X <- X[used,,drop=FALSE]; y <- y[used]
  if(!length(y)) stop('No groups with varying outcome')
  ord <- order(group); X <- X[ord,,drop=FALSE];y <- y[ord];group <- group[ord];used <- used[ord]
  lengths <- as.integer(table(group)); p <- ncol(X)
  centered <- X
  for(j in seq_len(p)) centered[,j] <- X[,j]-ave(X[,j],group,FUN=mean)
  scale <- sqrt(colMeans(centered^2)); scale[scale<1e-12] <- 1
  Z <- sweep(centered,2,scale,'/')
  qrZ <- qr(Z,tol=1e-9); active <- sort(qrZ$pivot[seq_len(qrZ$rank)])
  if(!length(active)) stop('No identified regressors')
  Z <- Z[,active,drop=FALSE]
  cache_b <- NULL; cache_v <- NULL
  ev <- function(b) {
    if(!identical(b,cache_b)) {cache_v <<- conditional_eval(b,Z,y,lengths);cache_b <<- b}
    cache_v
  }
  b0 <- rep(0,length(active))
  if(!is.null(start)) {s <- start[colnames(X)[active]]*scale[active]; s[!is.finite(s)]<-0;b0<-unname(s)}
  opt <- nlminb(b0,function(b)ev(b)$value,function(b)ev(b)$gradient,
                control=list(iter.max=150,eval.max=400,rel.tol=1e-11,x.tol=1e-9))
  # Verify stationarity independently of nlminb's relative-step status. The
  # conditional log likelihood is concave. Positive information plus a small
  # score certifies a finite optimum; Newton steps resolve premature stopping.
  polish <- 0L
  for(it in 1:8) {
    H <- num_jac(function(b)ev(b)$gradient,opt$par); H <- (H+t(H))/2
    g <- ev(opt$par)$gradient
    if(max(abs(g))<1e-5)break
    direction <- drop(solve(H,g));old <- ev(opt$par)$value; rate <- 1
    repeat {
      candidate <- opt$par-rate*direction; val <- ev(candidate)$value
      if(val<=old-1e-4*rate*sum(g*direction) || rate<1e-7)break
      rate <- rate/2
    }
    if(rate<1e-7)break
    opt$par <- candidate;polish <- polish+1L
  }
  H <- num_jac(function(b)ev(b)$gradient,opt$par); H <- (H+t(H))/2
  opt$objective <- ev(opt$par)$value
  V0 <- chol2inv(chol(H)); b <- rep(NA_real_,p);V <- matrix(NA_real_,p,p)
  b[active] <- opt$par/scale[active]
  V[active,active] <- V0/outer(scale[active],scale[active])
  names(b)<-colnames(X);dimnames(V)<-list(names(b),names(b))
  conv <- max(abs(ev(opt$par)$gradient))<1e-4
  list(b=b,V=V,X=X,y=y,used=used,active=active,loglik=-opt$objective,
       null_loglik=-sum(vapply(split(y,group),function(v)lchoose(length(v),sum(v)),0.0)),
       null_label='exact conditional, no regressors',df=length(active),
       n=length(y),groups=length(unique(group)),dropped=length(allg)-length(unique(group)),
       converged=conv,iterations=opt$iterations+polish,error=if(conv)'' else paste(opt$message,'; final scaled score',max(abs(ev(opt$par)$gradient))),
       routine='exact conditional Bernoulli DP (tilted forward/reverse); stats::nlminb(iter.max=150, rel.tol=1e-11) plus at most 8 Newton refinements; final scaled score < 1e-4; observed score-Jacobian information')
}
sandwich <- function(X,y,b,V,cluster) {
  p <- plogis(drop(X%*%b)); S <- rowsum(X*as.numeric(y-p),as.character(cluster),reorder=FALSE)
  G <- nrow(S); N <- nrow(X); K <- ncol(X)
  if(G<2 || N<=K) stop('CR1 undefined: insufficient clusters or residual degrees of freedom')
  list(V=V%*%crossprod(S)%*%V*(G/(G-1))*((N-1)/(N-K)),G=G)
}
fit_unconditional <- function(X,y,group,cluster) {
  team <- factor(group); D <- model.matrix(~team)
  X <- cbind(D,X); q <- qr(X,tol=1e-9); active <- sort(q$pivot[seq_len(q$rank)])
  Z <- X[,active,drop=FALSE]; sc <- sqrt(colMeans(Z^2));sc[sc<1e-12]<-1
  A <- sweep(Z,2,sc,'/')
  f <- glm.fit(A,y,family=binomial(),control=glm.control(epsilon=1e-10,maxit=100))
  b0 <- f$coefficients/sc
  pp <- plogis(drop(Z%*%b0)); V0 <- chol2inv(chol(crossprod(A,A*as.numeric(pp*(1-pp)))))/outer(sc,sc)
  b <- rep(NA_real_,ncol(X));b[active]<-b0;names(b)<-colnames(X)
  V <- matrix(NA_real_,ncol(X),ncol(X),dimnames=list(names(b),names(b)));V[active,active]<-V0
  rob <- sandwich(Z,y,b0,V0,cluster); B<-V;B[active,active]<-rob$V
  null <- glm.fit(D,y,family=binomial(),control=glm.control(epsilon=1e-10,maxit=100))
  ll <- function(eta)sum(y*eta-softplus(eta))
  list(b=b,V=V,B=B,G=rob$G,X=X,y=y,used=seq_along(y),active=active,
       loglik=ll(drop(Z%*%b0)),null_loglik=ll(null$linear.predictors),null_label='intercept and team dummies only',
       df=length(active)-null$rank,n=length(y),groups=nlevels(team),dropped=0,
       converged=f$converged && null$converged,iterations=f$iter,error='',
       routine='stats::glm.fit(binomial logit, epsilon=1e-10,maxit=100); inverse observed information; game CR1 sandwich')
}
gh_rule <- function(n=16L) {
  J<-matrix(0,n,n);J[cbind(1:(n-1),2:n)]<-sqrt((1:(n-1))/2);J<-J+t(J)
  e<-eigen(J,symmetric=TRUE);o<-order(e$values)
  list(x=e$values[o],w=sqrt(pi)*e$vectors[1,o]^2)
}
# Adaptive GH integrates exp(log Bernoulli likelihood + normal log density)
# around each group's posterior mode. All derivatives of the actual adaptive
# quadrature objective (including adaptation) are computed numerically.
re_objective <- function(par,X,y,groups,rule) {
  k<-ncol(X); eta<-drop(X%*%par[seq_len(k)]);sig<-exp(par[k+1]);v<-sig^2
  if(!is.finite(v)||v<1e-12||v>1e12) return(1e100)
  ll<-0
  for(ii in groups) {
    ee<-eta[ii]; yy<-y[ii];a<-0
    for(it in 1:60) {
      pp<-plogis(ee+a); h<-sum(pp*(1-pp))+1/v
      step<-(sum(yy-pp)-a/v)/h;step<-max(-5,min(5,step));a<-a+step
      if(abs(step)<1e-10)break
    }
    h<-sum(plogis(ee+a)*(1-plogis(ee+a)))+1/v;s<-1/sqrt(h)
    nodes<-a+sqrt(2)*s*rule$x
    vals<-vapply(nodes,function(u)sum(yy*(ee+u)-softplus(ee+u))-u^2/(2*v)-log(sig)-log(2*pi)/2,0.0)
    z<-log(rule$w)+vals+rule$x^2;mx<-max(z)
    ll<-ll+log(sqrt(2)*s)+mx+log(sum(exp(z-mx)))
  }
  -ll
}
fit_random <- function(X,y,group,nodes=16L,with_null=TRUE) {
  X<-cbind('(Intercept)'=1,X);sc<-sqrt(colMeans(X^2));sc[sc<1e-12]<-1;Z<-sweep(X,2,sc,'/')
  groups<-split(seq_along(y),group);rule<-gh_rule(nodes)
  f0<-glm.fit(Z,y,family=binomial());b0<-f0$coefficients;b0[!is.finite(b0)]<-0
  fun<-function(b)re_objective(b,Z,y,groups,rule)
  opt<-nlminb(c(b0,log(.5)),fun,control=list(iter.max=180,eval.max=2000,rel.tol=1e-10))
  H<-optimHess(opt$par,fun,control=list(ndeps=rep(1e-4,length(opt$par))))
  V<-chol2inv(chol((H+t(H))/2));ss<-c(sc,1);V<-V/outer(ss,ss)
  b<-opt$par/ss;names(b)<-c(colnames(X),'log_sigma');dimnames(V)<-list(names(b),names(b))
  nul<-if(with_null)fit_random(matrix(numeric(0),length(y),0),y,group,nodes,FALSE) else NULL
  list(b=b,V=V,X=cbind(X,log_sigma=0),y=y,used=seq_along(y),active=seq_along(b),
       loglik=-opt$objective,null_loglik=if(with_null)nul$loglik else NA_real_,
       null_label='random intercept and fixed intercept only (ML AGHQ)',df=ncol(X)-1,
       n=length(y),groups=length(groups),dropped=0,converged=opt$convergence==0,
       iterations=opt$iterations,error=if(opt$convergence==0)'' else opt$message,
       routine=paste0('normal random intercept ML; adaptive Gauss-Hermite ',nodes,' nodes; stats::nlminb; observed numerical Hessian'))
}
