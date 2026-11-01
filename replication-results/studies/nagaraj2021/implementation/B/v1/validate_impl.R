expr <- parse('output/run_analysis.R')
for (e in head(expr,-1)) eval(e,envir=.GlobalEnv)
out_dir <- normalizePath('output/synthetic_run')
prep <- prepare(normalizePath('input/data'))
prep$log$address_outcome_exclusions <- list()
placebo_output <- list()
grid <- fread('input/grid_v1.csv',colClasses='character',na.strings=NULL)
embedded <- fread(text=expr[[length(expr)]][[2]],colClasses='character',na.strings=NULL)
stopifnot(identical(grid,embedded))
stopifnot(nchar(sample_hash(seq_len(3100)))==64L,
          identical(sample_hash(seq_len(3100)),sample_hash(rev(seq_len(3100)))))
stopifnot(identical(groups(c(1,1,2,3,4,NA),4),c(1L,1L,2L,3L,4L,NA_integer_)))
stopifnot(fe_rank(data.table(a=c(1,1,2,2),b=c(1,2,3,4)),c('a','b'))==4)
stopifnot(fe_rank(data.table(a=c(1,1,2,2),b=c(1,1,2,2),c=c(1,1,2,2)),c('a','b','c'))==2)
stopifnot(length(unique(prep$panel$qidx))==39,nrow(prep$panel)==nrow(prep$U)*39)
s <- as.list(grid[spec_id=='S00008'])
m <- make_model(s); z <- fit_model(s,m); d <- copy(m$data)
d[, xw := post_treat-mean(post_treat),by=fips]
d[, xw := xw-mean(xw),by=qidx]
d[, yw := y-mean(y),by=fips]
d[, yw := yw-mean(yw),by=qidx]
b <- sum(d$xw*d$yw)/sum(d$xw^2)
u <- d$yw-b*d$xw
N <- nrow(d); G <- uniqueN(d$fips); K <- G+uniqueN(d$qidx)
cluster_score <- rowsum(d$xw*u,d$fips)
vc <- G/(G-1)*(N-1)/(N-1)*sum(cluster_score^2)/sum(d$xw^2)^2
vh <- N/(N-K)*sum((d$xw*u)^2)/sum(d$xw^2)^2
stopifnot(all.equal(z$estimate,b,tolerance=1e-9),
          all.equal(z$se_cluster,sqrt(vc),tolerance=1e-9),
          all.equal(z$se_hc1,sqrt(vh),tolerance=1e-9),z$df_hc1==N-K)
cat('S00008 independently demeaned coefficient and both covariances verified.\n')
s <- as.list(grid[analysis=='AN04'][1]); m <- make_model(s); z <- fit_model(s,m)
d <- copy(m$data)
for(v in controls) d[,(v):=(get(v)-mean(get(v)))/sd(get(v))]
f <- as.formula(paste('y~',paste(c(m$slopes,paste0('factor(',m$fes,')')),collapse='+')))
fit <- lm(f,data=d)
X <- model.matrix(fit); keep <- fit$qr$pivot[seq_len(fit$rank)]; X <- X[,keep,drop=FALSE]
N <- nrow(X); G <- uniqueN(d$fips); K <- ncol(X); k <- z$k_slopes
# Compute the full-dummy OLS linear map by solving one unit response per row.
# This is independent of the absorbed-regressor implementation.
linear_map <- qr.coef(fit$qr,diag(N))[keep,,drop=FALSE]
scores <- t(linear_map)*residuals(fit)
Vh <- N/(N-K)*crossprod(scores)
Vc <- G/(G-1)*(N-1)/(N-k)*crossprod(rowsum(scores,d$fips))
stopifnot(all.equal(z$estimate,unname(coef(fit)['treat']),tolerance=1e-8),
          all.equal(z$se_cluster,unname(sqrt(Vc['treat','treat'])),tolerance=1e-8),
          all.equal(z$se_hc1,unname(sqrt(Vh['treat','treat'])),tolerance=1e-8),z$df_hc1==N-K)
cat('AN04 explicit dummy OLS coefficient, rank and both covariances verified.\n')
# Validate the larger two-way rank calculation against explicit design rank.
s <- as.list(grid[variant=='dtt'][1]); m <- make_model(s)
small <- m$data[fips %in% head(unique(fips),16)]
MM <- model.matrix(~factor(fips)+factor(density_quarter),small)
stopifnot(fe_rank(small,m$fes)==qr(MM)$rank)
cat('Disconnected density-quarter FE rank verified against dummy matrix.\n')
influence_path <- 'output/synthetic_influence/influence.csv'
if (file.exists(influence_path)) {
  inf <- fread(influence_path)
  s <- as.list(grid[spec_id=='S00008']); base <- make_model(s)
  for (id in head(inf$removed_fips,2)) {
    dd <- copy(base$data[fips!=id])
    dd[, x := post_treat-mean(post_treat),by=fips]
    dd[, x := x-mean(x),by=qidx]
    dd[, y0 := y-mean(y),by=fips]
    dd[, y0 := y0-mean(y0),by=qidx]
    estimate <- sum(dd$x*dd$y0)/sum(dd$x^2)
    stopifnot(all.equal(inf[removed_fips==id,estimate],estimate,tolerance=1e-9))
  }
  cat('County-deletion estimates checked with independent two-way demeaning.\n')
}
cat('All independent checks passed.\n')
