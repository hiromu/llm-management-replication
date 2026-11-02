#!/opt/homebrew/opt/r/bin/Rscript
# PX02 v1. The immutable specification grid is embedded at the end of this file.
suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(haven)
  library(readxl)
  library(jsonlite)
})
setDTthreads(1L)
setFixest_nthreads(1L)
setFixest_notes(FALSE)
options(warn = 1)

controls <- c('population', 'popdensity', 'popmales', 'households',
              'unemploymentrate', 'income_householdmedian',
              'income_medianearnings', 'income_percapita', 'popeduc', 'popyoungmales')
log_controls <- setdiff(controls, c('popdensity', 'unemploymentrate'))
count_cols <- c('totaltigerall','totalowneredit','totaltaga','totaltagv2a',
  'totaltagb','totaltagv2b','totaltagh','totaltagv2h','totalversion2',
  'totalversion3','totalversion4plus','totalchange','totalcontrib','totalusers',
  'totalnewusers','totalpctcontrib25','totalpctcontrib50','totalpctcontrib75',
  'totalpctcontrib99','totaloldusers_active','totaloldfocused1','totaloldfocused5',
  'totalpctcontrib10','totalpctcontrib90')

mean_na <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm=TRUE)
sum_na <- function(x) if (anyNA(x)) NA_real_ else sum(x)
param <- function(s, name, default) {
  x <- s[[name]]
  if (is.null(x) || is.na(x) || x == '') default else x
}
transform_y <- function(x, g) {
  if (g == 'G1') return(suppressWarnings(log1p(x)))
  ans <- rep(NA_real_, length(x))
  ans[!is.na(x) & x == 0] <- 0
  pos <- !is.na(x) & x > 0
  ans[pos] <- log(x[pos])
  ans
}
groups <- function(x, k) {
  n <- sum(!is.na(x))
  if (!n) return(rep(NA_integer_, length(x)))
  as.integer(1 + floor(k * (rank(x, ties.method='min', na.last='keep') - 1) / n))
}

# Hash exactly the ASCII county list, without a final newline. Use the system
# SHA-256 implementation, never R's session-dependent object serialization.
hash_cache <- new.env(parent=emptyenv())
hash_cache$keys <- character()
hash_cache$values <- character()
sample_hash <- function(fips) {
  key <- paste(sort(unique(as.integer(fips))), collapse=',')
  # Store long county lists as string values, not environment variable names:
  # the latter have a 10,000-byte limit, below the full real-data county list.
  cached <- match(key,hash_cache$keys)
  if (!is.na(cached)) return(hash_cache$values[cached])
  path <- tempfile('county-hash-', tmpdir=out_dir)
  on.exit(unlink(path))
  writeBin(charToRaw(key), path)
  if (nzchar(Sys.which('shasum'))) {
    h <- system2(Sys.which('shasum'), c('-a', '256', shQuote(path)), stdout=TRUE)
  } else if (nzchar(Sys.which('sha256sum'))) {
    h <- system2(Sys.which('sha256sum'), shQuote(path), stdout=TRUE)
  } else if (nzchar(Sys.which('openssl'))) {
    h <- system2(Sys.which('openssl'), c('dgst', '-sha256', shQuote(path)), stdout=TRUE)
  } else stop('A system SHA-256 utility (shasum, sha256sum, or openssl) is required')
  hit <- regmatches(h, regexpr('[0-9a-fA-F]{64}', h))
  if (length(hit) != 1L || nchar(hit) != 64L) stop('SHA-256 utility failed')
  hit <- tolower(hit)
  hash_cache$keys <- c(hash_cache$keys,key)
  hash_cache$values <- c(hash_cache$values,hit)
  hit
}

prepare <- function(data_dir) {
  read_tab <- function(name, ...) fread(file.path(data_dir, name), ...)
  lookup <- read_tab('county_lookup.csv')
  U <- lookup[!is.na(STATE_NAME) & STATE_NAME != 'Massachusetts',
              .(fips=as.integer(FIPS), treat=as.numeric(treat))]
  setorder(U, fips)
  stopifnot(!anyDuplicated(U$fips), !anyNA(U$fips), all(U$treat %in% 0:1))
  raw <- read_tab('quarterly.csv', sep='\t', colClasses='character',
                  na.strings=NULL, strip.white=FALSE, quote='"')
  hdr <- !is.na(raw$geoid) & raw$geoid == 'geoid'
  log <- list(counties_universe=nrow(U), quarterly_rows_read=nrow(raw),
              quarterly_removed_repeated_header=sum(hdr))
  raw <- raw[!hdr]
  empty <- is.na(raw$quarter) | trimws(raw$quarter) == ''
  nums <- lapply(raw[, ..count_cols], function(x) suppressWarnings(as.numeric(x)))
  bad <- Reduce(`|`, lapply(nums, function(x) is.na(x) | !is.finite(x)))
  # Report both overlapping reason counts and mutually exclusive removal counts.
  log$quarterly_empty_quarter <- sum(empty)
  log$quarterly_unparseable_counts <- sum(bad)
  log$quarterly_both_empty_and_unparseable <- sum(empty & bad)
  log$quarterly_removed_empty_quarter <- sum(empty)
  log$quarterly_removed_bad_counts_after_empty <- sum(bad & !empty)
  log$quarterly_removed_total <- sum(hdr) + sum(empty | bad)
  raw[, (count_cols) := nums]
  raw <- raw[!(empty | bad)]
  raw[, fips := suppressWarnings(as.integer(geoid))]
  qi <- seq.int((2005-1960)*4+1, (2014-1960)*4+3)
  quarters <- data.table(qidx=qi, year=qi %/% 4L + 1960L,
                         quarter=paste0(qi %/% 4L + 1960L, 'q', qi %% 4L + 1L))
  outside_u <- is.na(raw$fips) | !raw$fips %in% U$fips
  outside_q <- !raw$quarter %in% quarters$quarter
  log$quarterly_unused_outside_universe <- sum(outside_u)
  log$quarterly_unused_outside_quarter_range <- sum(outside_q)
  log$quarterly_unused_outside_either <- sum(outside_u | outside_q)
  raw <- raw[!outside_u & !outside_q, c('fips','quarter',count_cols), with=FALSE]
  if (anyDuplicated(raw[, .(fips, quarter)])) stop('Duplicate valid county-quarter keys')
  panel <- merge(CJ(fips=U$fips, qidx=qi), quarters, by='qidx', sort=FALSE)
  raw[, observed := TRUE]
  panel <- merge(panel, raw, by=c('fips','quarter'), all.x=TRUE, sort=FALSE)
  absent <- is.na(panel$observed)
  log$balanced_zero_filled_county_quarters <- sum(absent)
  for (v in count_cols) set(panel, which(absent), v, 0)
  panel[, observed := NULL]
  panel <- merge(panel, U, by='fips', sort=FALSE)
  panel[, post := as.integer(year >= 2008)]
  setorder(panel, fips, qidx)
  log$negative_low_own_O1_cells <- panel[, sum(totaloldfocused5-totaloldfocused1 < 0)]

  acs <- as.data.table(read_dta(file.path(data_dir,'acs5year.dta')))
  acs <- acs[, c('geo_fips','acsyear',controls), with=FALSE]
  setnames(acs, 'geo_fips', 'fips')
  for (v in names(acs)) set(acs, j=v, value=as.numeric(acs[[v]]))
  acs[, fips := as.integer(fips)]
  if (anyDuplicated(acs[, .(fips,acsyear)])) stop('Duplicate ACS county-year keys')
  acs <- acs[!is.na(acsyear) & !is.na(fips)]
  setorder(acs, fips, acsyear)
  log$counties_without_any_acs <- sum(!U$fips %in% acs$fips)
  latest <- max(acs$acsyear)
  nearest <- function(target) {
    ans <- acs[, .SD[which.min(abs(acsyear-target))], by=fips]
    merge(U[, .(fips)], ans[, c('fips',controls), with=FALSE], by='fips', all.x=TRUE)
  }
  pc <- rbindlist(lapply(2005:2014, function(yr) {
    z <- nearest(min(yr,latest)); z[, year := yr]; z
  }))
  panel <- merge(panel, pc, by=c('fips','year'), all.x=TRUE, sort=FALSE)
  setorder(panel, fips, qidx)
  cs <- list(Y1=nearest(2011), Y2=nearest(2008))
  cs$Y3 <- merge(U[, .(fips)], acs[, lapply(.SD, mean_na), by=fips,
                                  .SDcols=controls], by='fips', all.x=TRUE)
  for (nm in names(cs)) cs[[nm]] <- merge(cs[[nm]], U, by='fips', all.x=TRUE)

  boundary <- read_tab('boundary-counties.csv', sep=',', strip.white=FALSE)
  opposite <- control_neighbor <- rep(FALSE,nrow(U))
  for (i in seq_len(nrow(boundary))) {
    source <- suppressWarnings(as.integer(boundary[[1L]][i]))
    j <- match(source,U$fips)
    if (is.na(j)) next
    neighbors <- suppressWarnings(as.integer(strsplit(as.character(boundary[[2L]][i]),
                                                       ';',fixed=TRUE)[[1L]]))
    neighbors <- neighbors[!is.na(neighbors) & neighbors != source & neighbors %in% U$fips]
    t <- U$treat[match(neighbors,U$fips)]
    opposite[j] <- opposite[j] | any(t != U$treat[j])
    control_neighbor[j] <- control_neighbor[j] | any(t == 0)
  }
  timing <- as.data.table(read_excel(file.path(data_dir,'timing.xlsx'), sheet=1))
  delivery <- timing[['Sch SB Delivery']]
  if (inherits(delivery,'POSIXt') || inherits(delivery,'Date')) {
    ty <- as.integer(format(delivery,'%Y'))
  } else if (is.numeric(delivery)) {
    ty <- as.integer(format(as.Date(delivery,origin='1899-12-30'),'%Y'))
  } else {
    ty <- suppressWarnings(as.integer(substr(as.character(delivery),1,4)))
  }
  timed_fips <- suppressWarnings(as.integer(timing$FIPS[!is.na(ty) & ty %in% c(2005,2006)]))
  membership <- copy(U)
  membership[, `:=`(B1=as.integer(opposite),
                    B2=as.integer(treat == 0 | control_neighbor),
                    timing=as.integer(fips %in% timed_fips))]

  pairs <- read_tab('distance.csv', sep='\t')
  pairs[, fips := as.integer(fips)]
  log$distance_pairs_outside_universe <- pairs[, sum(!fips %in% U$fips)]
  log$distance_pairs_missing_distance_in_universe <- pairs[fips %in% U$fips,
                                      sum(is.na(ggl_distance) | is.na(osrm_distance))]
  pairs <- pairs[fips %in% U$fips & !is.na(ggl_distance) & !is.na(osrm_distance)]
  rad <- pi/180
  a <- with(pairs, sin((dest_lat-origin_lat)*rad/2)^2 +
    cos(origin_lat*rad)*cos(dest_lat*rad)*sin((dest_lon-origin_lon)*rad/2)^2)
  pairs[, `:=`(dist_km=2*6371.0088*asin(sqrt(pmin(1,pmax(0,a)))),
                err=abs(osrm_distance-ggl_distance))]
  draws <- read_tab('placebo_draws.csv')
  list(U=U, panel=panel, cs=cs, membership=membership, pairs=pairs,
       draws=draws, log=log)
}

outcome <- function(panel, s, which=param(s,'outcome','followon')) {
  f <- param(s,'F','F1'); d <- param(s,'D','D1'); o <- param(s,'O','O1')
  with(panel, switch(which,
    total=totalcontrib,
    followon=switch(f,F1=totaltaga+totaltagb+totaltagh,
                      F2=totaltagv2a+totaltagv2b+totaltagv2h,
                      F3=totalversion2+totalversion3+totalversion4plus,
                      F4=totaltaga+totaltagb+totaltagh+totaltagv2a+totaltagv2b+totaltagv2h),
    distant={
      b <- switch(f,F1=totaltagb,F2=totaltagv2b,F3=totaltagb,F4=totaltagb+totaltagv2b)
      if (d=='D2') b <- b + switch(f,F1=totaltaga,F2=totaltagv2a,F3=totaltaga,
                                  F4=totaltaga+totaltagv2a)
      b
    },
    incremental=switch(f,F1=totaltagh,F2=totaltagv2h,F3=totaltagh,F4=totaltagh+totaltagv2h),
    contributors=totalusers,new=totalnewusers,old=totaloldusers_active,
    high_own=totaloldfocused1,
    low_own={ z <- if (o=='O1') totaloldfocused5-totaloldfocused1 else totaloldfocused5
              if (o=='O1') z[z<0] <- NA_real_; z },
    owner=totalowneredit,
    { v <- paste0('totalpctcontrib',sub('^pct','',which))
      if (!v %in% names(panel)) stop('Unknown outcome: ',which)
      panel[[v]] }
  ))
}

sample_keys <- function(s) {
  typ <- param(s,'sample','full')
  if (typ=='boundary') {
    keys <- prep$membership[get(param(s,'B','B1')) == 1L, fips]
  } else if (typ=='timing') keys <- prep$membership[timing==1L,fips]
  else keys <- prep$U$fips
  if (s$analysis=='AN13') {
    density <- copy(prep$cs$Y1[,.(fips,popdensity)])
    density[, dec := groups(popdensity,10)]
    keys <- intersect(keys,density[!is.na(dec) & dec == as.integer(s$decile),fips])
  }
  keys
}
cross_controls <- function(s, keys) {
  z <- copy(prep$cs[[param(s,'Y','Y1')]])
  if (param(s,'R','R1')=='R2') z <- z[fips %in% keys]
  vars <- c(if (param(s,'Q','Q1')=='Q1') 'popdensity' else 'population',
            'income_householdmedian','income_percapita')
  for (j in seq_along(vars)) z[, (paste0('fe',j)) := groups(get(vars[j]),4)]
  z <- z[fips %in% keys]
  if (param(s,'L','L1')=='L2') z[, (log_controls) := lapply(.SD,function(x)
    suppressWarnings(log1p(x))), .SDcols=log_controls]
  z
}

# FE rank is exact, including disconnected sets and coincident quartile groups.
# Two FE sets form a bipartite graph with rank V - connected components.
fe_rank <- function(d, fes) {
  if (length(fes)==2L) {
    a <- as.integer(factor(d[[fes[1L]]]))
    b <- as.integer(factor(d[[fes[2L]]]))
    na <- max(a); nb <- max(b)
    edges <- unique(data.table(a=a,b=b+na))
    labels <- seq_len(na+nb)
    repeat {
      old <- labels
      edges[, m := pmin(labels[a],labels[b])]
      aa <- edges[,.(v=min(m)),by=a]
      bb <- edges[,.(v=min(m)),by=b]
      labels[aa$a] <- aa$v; labels[bb$b] <- bb$v
      if (identical(old,labels)) break
    }
    return(na+nb-uniqueN(labels))
  }
  # Cross-section group matrices have at most 12 columns, regardless of N.
  mat <- do.call(cbind,lapply(fes,function(v) {
    f <- factor(d[[v]]); m <- matrix(0,nrow(d),nlevels(f))
    m[cbind(seq_len(nrow(d)),as.integer(f))] <- 1
    m
  }))
  qr(mat,tol=1e-9)$rank
}

result_row <- function(s, term, status='ok', error='') {
  data.table(spec_id=s$spec_id, analysis=s$analysis, term=term,
    status=status,error=error,n_obs=NA_integer_,n_counties=NA_integer_,
    n_dropped_missing=NA_integer_,estimate=NA_real_,se_cluster=NA_real_,
    p_cluster=NA_real_,df_cluster=NA_real_,se_hc1=NA_real_,p_hc1=NA_real_,
    df_hc1=NA_real_,ci_low=NA_real_,ci_high=NA_real_,r2=NA_real_,
    k_slopes=NA_integer_,sample_hash=NA_character_)
}
expected_terms <- function(s) {
  if (s$analysis=='AN07') return(c('treat','dist_km'))
  if (s$analysis=='AN11') return(paste0('treat_year_',setdiff(2005:2014,2007)))
  if (s$analysis %in% c('AN04','AN06','AN12') ||
      (s$analysis=='AN13' && s$est=='M2')) return('treat')
  if (s$analysis %in% c('AN01','AN02','AN09','AN10')) return('summary')
  'post_treat'
}

make_model <- function(s) {
  keys <- sample_keys(s)
  cross <- s$analysis %in% c('AN04','AN06','AN07','AN12') ||
    (s$analysis=='AN13' && s$est=='M2')
  g <- param(s,'G','G1')
  excluded <- 0L
  if (cross) {
    cs <- cross_controls(s,keys)
    fes <- paste0('fe',1:3)
    slopes <- c('treat',controls)
    if (s$analysis=='AN07') {
      d <- copy(prep$pairs[fips %in% keys])
      w <- param(s,'W','W1')
      invalid <- switch(w,W1=d$err==0,W3=rep(FALSE,nrow(d)),
                         W4=d$ggl_distance<=0 | d$osrm_distance<=0)
      excluded <- sum(invalid)
      prep$log$address_outcome_exclusions[[s$spec_id]] <<- list(W=w,
        zero_difference=if (w=='W1') excluded else 0L,
        nonpositive_distance=if (w=='W4') excluded else 0L)
      d <- d[!invalid]
      d[, y := switch(w,W1=log(err),W3=log1p(err),
                       W4=abs(log(osrm_distance)-log(ggl_distance))) ]
      d <- merge(d,cs,by='fips',all.x=TRUE,sort=FALSE)
      slopes <- c('treat','dist_km',controls)
    } else {
      d <- copy(prep$panel[fips %in% keys])
      period <- param(s,'period','P0814')
      if (period=='P0814') d <- d[year>=2008]
      else if (period=='P14') d <- d[year==2014]
      else d <- d[year==as.integer(sub('^P','',period))]
      d[, raw_y := outcome(d,s)]
      d <- d[,.(y=transform_y(sum_na(raw_y),g)),by=fips]
      d <- merge(d,cs,by='fips',all.x=TRUE,sort=FALSE)
    }
  } else {
    d <- copy(prep$panel[fips %in% keys])
    d[, raw_y := outcome(d,s)]
    if (s$analysis=='AN11') {
      d <- d[,.(y=transform_y(sum_na(raw_y),g),treat=treat[1L]),by=.(fips,year)]
      slopes <- expected_terms(s)
      for (yr in setdiff(2005:2014,2007))
        d[, (paste0('treat_year_',yr)) := treat*as.integer(year==yr)]
      fes <- c('fips','year')
    } else {
      d[, y := transform_y(raw_y,g)]
      if (s$variant %in% c('placebo_perm','placebo_bern')) {
        seed_value <- as.integer(s$seed)
        vec <- copy(prep$draws[seed==seed_value & fips %in% prep$U$fips])
        if (nrow(vec)!=nrow(prep$U) || anyDuplicated(vec$fips) ||
            anyNA(vec$u) || any(vec$u<0 | vec$u>=1)) stop('Invalid/incomplete placebo draws')
        setorder(vec,u,fips)
        nt <- sum(prep$U$treat)
        vec[, placebo_treat := if (s$variant=='placebo_perm')
          as.integer(seq_len(.N)<=nt) else as.integer(u<nt/nrow(prep$U))]
        placebo_output[[s$spec_id]] <<- vec[,.(spec_id=s$spec_id,fips,placebo_treat)]
        d[, treat := vec$placebo_treat[match(fips,vec$fips)]]
      }
      d[, post_treat := post*treat]
      use_ctrl <- s$analysis %in% c('AN08','AN13','AN14') || param(s,'ctrl',0)==1
      slopes <- c('post_treat',if (use_ctrl) controls)
      if (use_ctrl && param(s,'L','L1')=='L2')
        d[, (log_controls) := lapply(.SD,function(x) suppressWarnings(log1p(x))),
          .SDcols=log_controls]
      fes <- c('fips','qidx')
      if (s$variant=='dtt') {
        quart <- prep$cs$Y1[,.(fips,quart=groups(popdensity,4))]
        d[, density_quarter := ifelse(is.na(quart$quart[match(fips,quart$fips)]),
          NA_character_,paste(quart$quart[match(fips,quart$fips)],qidx,sep='_'))]
        fes <- c('fips','density_quarter')
      }
    }
  }
  needed <- unique(c('y',slopes,fes,'fips'))
  good <- Reduce(`&`,lapply(d[,..needed],function(x) {
    if (is.numeric(x)) is.finite(x) else !is.na(x)
  }))
  list(data=d[good],slopes=slopes,fes=fes,terms=expected_terms(s),
       n_dropped_missing=sum(!good),n_excluded_outcome=excluded)
}

fit_model <- function(s, model) {
  d <- copy(model$data)
  N <- nrow(d); G <- uniqueN(d$fips)
  if (N==0L || G<2L) stop('Fewer than two counties in the estimation sample')
  # Rescale nuisance controls solely for numerical conditioning. Focal slopes
  # and the model's column space are unchanged.
  for (v in intersect(controls,model$slopes)) {
    scale <- sd(d[[v]])
    if (is.finite(scale) && scale>0) set(d,j=v,value=(d[[v]]-mean(d[[v]]))/scale)
  }
  # Absorb the fixed effects, then solve by QR rather than normal equations.
  # This also keeps singletons: none are silently removed by an estimator.
  dm <- fixest::demean(as.matrix(d[,c('y',model$slopes),with=FALSE]),
    f=as.list(d[,model$fes,with=FALSE]),tol=1e-12,iter=10000,notes=FALSE)
  X <- dm[,-1L,drop=FALSE]
  colnames(X) <- model$slopes
  decomposition <- qr(X,tol=1e-10)
  k <- decomposition$rank
  if (k==0L) stop('All slope regressors are absorbed by fixed effects')
  X <- X[,decomposition$pivot[seq_len(k)],drop=FALSE]
  decomposition <- qr(X,tol=1e-10)
  beta <- qr.coef(decomposition,dm[,1L])
  residual <- qr.resid(decomposition,dm[,1L])
  K <- k+fe_rank(d,model$fes)
  if (N<=K) stop(sprintf('No positive HC1 residual degrees of freedom: N=%d, K=%d',N,K))
  if (any(!is.finite(beta))) stop('Nonfinite model coefficients')
  # Q R^(-T) equals X (X'X)^(-1), computed without squaring X's
  # condition number. Cross-products of these weighted scores are the
  # requested sandwich covariance matrices.
  scores <- (qr.Q(decomposition) %*% t(backsolve(qr.R(decomposition),diag(k)))) * residual
  colnames(scores) <- colnames(X)[decomposition$pivot]
  scores <- scores[,names(beta),drop=FALSE]
  county_scores <- rowsum(scores,group=d$fips,reorder=FALSE)
  vc <- (G/(G-1))*((N-1)/(N-k)) * crossprod(county_scores)
  vh <- (N/(N-K)) * crossprod(scores)
  sc <- sqrt(pmax(0,diag(vc))); sh <- sqrt(pmax(0,diag(vh)))
  names(sc) <- names(sh) <- names(beta)
  tss <- sum((d$y-mean(d$y))^2)
  rsq <- if (tss>0) 1-sum(residual^2)/tss else NA_real_
  hash <- sample_hash(d$fips)
  rbindlist(lapply(model$terms,function(term) {
    z <- result_row(s,term)
    z[, `:=`(n_obs=N,n_counties=G,n_dropped_missing=model$n_dropped_missing,
              df_cluster=G-1L,df_hc1=N-K,r2=rsq,k_slopes=k,sample_hash=hash)]
    if (!term %in% names(beta)) {
      z[, `:=`(status='failed',error='Focal term is not identified (collinear)')]
      return(z)
    }
    z[, `:=`(estimate=unname(beta[term]),se_cluster=unname(sc[term]),
       p_cluster=2*pt(-abs(beta[term]/sc[term]),G-1),se_hc1=unname(sh[term]),
       p_hc1=2*pt(-abs(beta[term]/sh[term]),N-K))]
    ci_se <- if (s$analysis=='AN12') sh[term] else sc[term]
    ci_df <- if (s$analysis=='AN12') N-K else G-1
    z[, `:=`(ci_low=unname(beta[term]-qt(.975,ci_df)*ci_se),
              ci_high=unname(beta[term]+qt(.975,ci_df)*ci_se))]
    z
  }))
}

descriptive <- function(s) {
  p <- copy(prep$panel)
  if (s$analysis=='AN01') {
    for (v in c('total','followon','contributors','owner')) p[, (v) := outcome(p,s,v)]
    z <- p[,lapply(.SD,mean_na),by=.(fips,treat),
           .SDcols=c('total','followon','contributors','owner')]
    errs <- prep$pairs[,.(err_mean=mean_na(err)),by=fips]
    z <- merge(z,errs,by='fips',all.x=TRUE)
    delta <- c('population','households','unemploymentrate','popeduc','popmales',
               'popyoungmales','income_percapita')
    start <- unique(p[year==2005,c('fips',delta),with=FALSE])
    end <- unique(p[year==2014,c('fips',delta),with=FALSE])
    for (v in delta) z[, (paste0('change_',v)) :=
      end[[v]][match(fips,end$fips)]-start[[v]][match(fips,start$fips)]]
    vars <- setdiff(names(z),c('fips','treat'))
    detail <- rbindlist(lapply(vars,function(v) {
      a <- z[treat==1,get(v)]; b <- z[treat==0,get(v)]
      a <- a[!is.na(a)]; b <- b[!is.na(b)]
      tp <- function(equal) tryCatch(t.test(a,b,var.equal=equal)$p.value,
                                     error=function(e) NA_real_)
      data.table(spec_id=s$spec_id,variable=v,treated_mean=mean_na(a),
        control_mean=mean_na(b),difference=mean_na(a)-mean_na(b),n_treated=length(a),
        n_control=length(b),p_welch=tp(FALSE),p_equal_variance=tp(TRUE))
    }))
    descriptive_output$an01[[s$spec_id]] <<- detail
    return(rbindlist(lapply(seq_len(nrow(detail)),function(i) {
      a <- detail[i]; r <- result_row(s,a$variable)
      ids <- z[!is.na(get(a$variable)),fips]
      r[,`:=`(n_obs=a$n_treated+a$n_control,n_counties=length(ids),
        n_dropped_missing=nrow(z)-length(ids),estimate=a$difference,sample_hash=sample_hash(ids))]
      r
    })))
  }
  if (s$analysis=='AN02') {
    vars <- c('total','followon','contributors','distant','incremental','new','old',
              'low_own','high_own','owner')
    for (v in vars) p[, (v) := outcome(p,s,v)]
    vars <- c(vars,'treat','post','year','qidx','population','households',
              'popdensity','income_percapita')
    detail <- rbindlist(lapply(vars,function(v) {
      x <- p[[v]]; x <- x[!is.na(x)]
      data.table(spec_id=s$spec_id,variable=v,mean=mean_na(x),sd=sd(x),
        median=if(length(x)) median(x) else NA_real_,min=if(length(x)) min(x) else NA_real_,
        max=if(length(x)) max(x) else NA_real_,n_nonmissing=length(x),
        n_rows=nrow(p),n_counties=uniqueN(p$fips),n_quarters=uniqueN(p$qidx))
    }))
    descriptive_output$an02[[s$spec_id]] <<- detail
    return(rbindlist(lapply(seq_len(nrow(detail)),function(i) {
      a <- detail[i]; r <- result_row(s,a$variable)
      ids <- p[!is.na(get(a$variable)),fips]
      r[,`:=`(n_obs=a$n_nonmissing,n_counties=uniqueN(ids),
        n_dropped_missing=nrow(p)-a$n_nonmissing,estimate=a$mean,sample_hash=sample_hash(ids))]
      r
    })))
  }
  if (s$analysis=='AN09') {
    z <- copy(prep$membership); z[, spec_id := s$spec_id]
    descriptive_output$an09_membership[[s$spec_id]] <<- z
    counts <- rbindlist(lapply(c('full','B1','B2','timing'),function(typ) {
      k <- if (typ=='full') z else z[get(typ)==1L]
      data.table(spec_id=s$spec_id,sample=typ,treat=0:1,
                  n_counties=c(sum(k$treat==0),sum(k$treat==1)))
    }))
    descriptive_output$an09_counts[[s$spec_id]] <<- counts
  }
  if (s$analysis=='AN10') {
    detail <- rbindlist(lapply(c('total','followon'),function(v) {
      p[, val := outcome(p,s,v)]
      setorder(p,fips,qidx)
      p[, cumulative := cumsum(val),by=fips]
      p[,.(spec_id=s$spec_id,outcome=v,mean_log=mean_na(transform_y(val,'G1')),
           mean_cumulative=mean_na(cumulative),n_counties=.N),by=.(quarter,qidx,treat)]
    }))
    setorder(detail,outcome,qidx,treat)
    descriptive_output$an10[[s$spec_id]] <<- detail
  }
  r <- result_row(s,'summary')
  r[, `:=`(n_obs=if(s$analysis=='AN09') nrow(prep$U) else nrow(p),
            n_counties=nrow(prep$U),n_dropped_missing=0L,sample_hash=sample_hash(prep$U$fips))]
  r
}

write_outputs <- function(results) {
  fwrite(results,file.path(out_dir,'results.csv'),na='')
  templates <- list(
    an01=data.table(spec_id=character(),variable=character(),treated_mean=double(),
      control_mean=double(),difference=double(),n_treated=integer(),n_control=integer(),
      p_welch=double(),p_equal_variance=double()),
    an02=data.table(spec_id=character(),variable=character(),mean=double(),sd=double(),
      median=double(),min=double(),max=double(),n_nonmissing=integer(),n_rows=integer(),
      n_counties=integer(),n_quarters=integer()),
    an09_membership=data.table(fips=integer(),treat=integer(),B1=integer(),B2=integer(),
      timing=integer(),spec_id=character()),
    an09_counts=data.table(spec_id=character(),sample=character(),treat=integer(),n_counties=integer()),
    an10=data.table(quarter=character(),qidx=integer(),treat=integer(),spec_id=character(),
      outcome=character(),mean_log=double(),mean_cumulative=double(),n_counties=integer()))
  files <- c(an01='an01_groups.csv',an02='an02_summary.csv',
    an09_membership='an09_membership.csv',an09_counts='an09_counts.csv',an10='an10_means.csv')
  for (nm in names(files)) {
    z <- if (length(descriptive_output[[nm]])) rbindlist(descriptive_output[[nm]],fill=TRUE)
         else templates[[nm]]
    fwrite(z,file.path(out_dir,files[[nm]]),na='')
  }
  pv <- if (length(placebo_output)) rbindlist(placebo_output) else
    data.table(spec_id=character(),fips=integer(),placebo_treat=integer())
  if (nrow(pv)) setorder(pv,spec_id,fips)
  fwrite(pv,file.path(out_dir,'placebo_vectors.csv'),na='')
  write_json(prep$log,file.path(out_dir,'prep_log.json'),pretty=TRUE,auto_unbox=TRUE,na='null')
  capture.output(sessionInfo(),file=file.path(out_dir,'session_info.txt'))
}

main <- function(grid_text) {
  start_time <- proc.time()[['elapsed']]
  args <- commandArgs(trailingOnly=TRUE)
  if (!(length(args) %in% c(2L,4L)) || (length(args)==4L && args[3L]!='--influence'))
    stop('Usage: Rscript run_analysis.R <data_dir> <output_dir> [--influence <spec_id>]')
  data_dir <- normalizePath(args[1L],mustWork=TRUE)
  dir.create(args[2L],recursive=TRUE,showWarnings=FALSE)
  out_dir <<- normalizePath(args[2L],mustWork=TRUE)
  grid <- fread(text=grid_text,colClasses='character',na.strings=NULL)
  prep <<- prepare(data_dir)
  prep$log$address_outcome_exclusions <<- list()
  placebo_output <<- list()
  descriptive_output <<- setNames(rep(list(list()),5L),
    c('an01','an02','an09_membership','an09_counts','an10'))
  failed <- function(s,e,model=NULL) {
    z <- rbindlist(lapply(expected_terms(s),function(t) result_row(s,t,'failed',conditionMessage(e))))
    if (!is.null(model)) z[,`:=`(n_obs=nrow(model$data),n_counties=uniqueN(model$data$fips),
      n_dropped_missing=model$n_dropped_missing,sample_hash=sample_hash(model$data$fips))]
    z
  }
  if (length(args)==4L) {
    s <- grid[spec_id==args[4L]]
    if (nrow(s)!=1L) stop('Influence spec_id not found or not unique')
    if (s$analysis %in% c('AN01','AN02','AN09','AN10')) stop('Influence requires a regression row')
    s <- as.list(s)
    model <- make_model(s)
    base <- tryCatch(fit_model(s,model),error=function(e) failed(s,e,model))
    ids <- sort(unique(model$data$fips))
    inf <- lapply(ids,function(id) {
      reduced <- model
      reduced$data <- model$data[fips!=id]
      z <- tryCatch(fit_model(s,reduced),error=function(e) failed(s,e,reduced))
      z[, removed_fips := id]
      z
    })
    influence <- if (length(inf)) rbindlist(inf) else {
      z <- base[0]; z[,removed_fips:=integer()]; z
    }
    fwrite(influence,file.path(out_dir,'influence.csv'),na='')
    prep$log$influence <<- list(spec_id=s$spec_id,counties_refitted=length(ids))
    prep$log$elapsed_seconds <<- unname(proc.time()[['elapsed']]-start_time)
    write_outputs(base)
    message('Influence mode completed: ',length(ids),' county deletions')
  } else {
    results <- vector('list',nrow(grid))
    for (i in seq_len(nrow(grid))) {
      s <- as.list(grid[i]); model <- NULL
      results[[i]] <- tryCatch({
        if (s$analysis %in% c('AN01','AN02','AN09','AN10')) descriptive(s)
        else { model <- make_model(s); fit_model(s,model) }
      },error=function(e) failed(s,e,model))
      if (i %% 50L==0L || i==nrow(grid)) message('Completed ',i,' / ',nrow(grid),' specifications')
    }
    results <- rbindlist(results,fill=TRUE)
    prep$log$specifications_total <<- nrow(grid)
    prep$log$specifications_with_failed_terms <<- uniqueN(results[status=='failed',spec_id])
    prep$log$elapsed_seconds <<- unname(proc.time()[['elapsed']]-start_time)
    write_outputs(results)
    message('Full grid completed; ',prep$log$specifications_with_failed_terms,
            ' specifications have failed terms (see results.csv)')
  }
}

# EMBEDDED_GRID
main("spec_id,stage,analysis,outcome,sample,ctrl,variant,seed,period,decile,est,F,D,O,G,L,Y,Q,R,B,W,deviation,paper_focal
S00001,1_origin,AN01,,full,,,,,,,F1,,,,,,,,,,,0
S00002,1_origin,AN02,,full,,,,,,,F1,D1,O1,,,,,,,,,0
S00003,1_origin,AN09,,full,,,,,,,,,,,,,,,,,,0
S00004,1_origin,AN03,total,full,0,,,,,,,,,G1,,,,,,,,0
S00005,1_origin,AN03,total,full,1,,,,,,,,,G1,L1,,,,,,,0
S00006,1_origin,AN04,total,full,,,,P0814,,,,,,G1,L1,Y1,Q1,,,,,0
S00007,1_origin,AN04,total,full,,,,P14,,,,,,G1,L1,Y1,Q1,,,,,0
S00008,1_origin,AN03,followon,full,0,,,,,,F1,,,G1,,,,,,,,1
S00009,1_origin,AN03,followon,full,1,,,,,,F1,,,G1,L1,,,,,,,1
S00010,1_origin,AN04,followon,full,,,,P0814,,,F1,,,G1,L1,Y1,Q1,,,,,1
S00011,1_origin,AN04,followon,full,,,,P14,,,F1,,,G1,L1,Y1,Q1,,,,,1
S00012,1_origin,AN03,contributors,full,0,,,,,,,,,G1,,,,,,,,1
S00013,1_origin,AN03,contributors,full,1,,,,,,,,,G1,L1,,,,,,,1
S00014,1_origin,AN04,contributors,full,,,,P0814,,,,,,G1,L1,Y1,Q1,,,,,1
S00015,1_origin,AN04,contributors,full,,,,P14,,,,,,G1,L1,Y1,Q1,,,,,1
S00016,1_origin,AN05,followon,full,1,dtt,,,,,F1,,,G1,L1,,,,,,,0
S00017,1_origin,AN05,followon,full,0,dtt,,,,,F1,,,G1,,,,,,,,0
S00018,1_origin,AN05,followon,boundary,1,boundary,,,,,F1,,,G1,L1,,,,B1,,,0
S00019,1_origin,AN05,followon,boundary,0,boundary,,,,,F1,,,G1,,,,,B1,,,0
S00020,1_origin,AN05,followon,timing,1,timing,,,,,F1,,,G1,L1,,,,,,,0
S00021,1_origin,AN05,followon,timing,0,timing,,,,,F1,,,G1,,,,,,,,0
S00022,1_origin,AN05,followon,full,1,placebo_perm,0,,,,F1,,,G1,L1,,,,,,,0
S00023,1_origin,AN05,followon,full,0,placebo_perm,0,,,,F1,,,G1,,,,,,,,0
S00024,1_origin,AN05,followon,full,1,placebo_bern,0,,,,F1,,,G1,L1,,,,,,,0
S00025,1_origin,AN05,followon,full,0,placebo_bern,0,,,,F1,,,G1,,,,,,,,0
S00026,1_origin,AN06,followon,boundary,,,,P0814,,,F1,,,G1,L1,Y1,Q1,R1,B1,,,0
S00027,1_origin,AN06,followon,boundary,,,,P14,,,F1,,,G1,L1,Y1,Q1,R1,B1,,,0
S00028,1_origin,AN06,followon,timing,,,,P0814,,,F1,,,G1,L1,Y1,Q1,R1,,,,0
S00029,1_origin,AN06,followon,timing,,,,P14,,,F1,,,G1,L1,Y1,Q1,R1,,,,0
S00030,1_origin,AN05,contributors,full,1,dtt,,,,,,,,G1,L1,,,,,,,0
S00031,1_origin,AN05,contributors,full,0,dtt,,,,,,,,G1,,,,,,,,0
S00032,1_origin,AN05,contributors,boundary,1,boundary,,,,,,,,G1,L1,,,,B1,,,0
S00033,1_origin,AN05,contributors,boundary,0,boundary,,,,,,,,G1,,,,,B1,,,0
S00034,1_origin,AN05,contributors,timing,1,timing,,,,,,,,G1,L1,,,,,,,0
S00035,1_origin,AN05,contributors,timing,0,timing,,,,,,,,G1,,,,,,,,0
S00036,1_origin,AN05,contributors,full,1,placebo_perm,0,,,,,,,G1,L1,,,,,,,0
S00037,1_origin,AN05,contributors,full,0,placebo_perm,0,,,,,,,G1,,,,,,,,0
S00038,1_origin,AN05,contributors,full,1,placebo_bern,0,,,,,,,G1,L1,,,,,,,0
S00039,1_origin,AN05,contributors,full,0,placebo_bern,0,,,,,,,G1,,,,,,,,0
S00040,1_origin,AN06,contributors,boundary,,,,P0814,,,,,,G1,L1,Y1,Q1,R1,B1,,,0
S00041,1_origin,AN06,contributors,boundary,,,,P14,,,,,,G1,L1,Y1,Q1,R1,B1,,,0
S00042,1_origin,AN06,contributors,timing,,,,P0814,,,,,,G1,L1,Y1,Q1,R1,,,,0
S00043,1_origin,AN06,contributors,timing,,,,P14,,,,,,G1,L1,Y1,Q1,R1,,,,0
S00044,1_origin,AN07,err,full,,,,,,,,,,,L1,Y1,Q1,,,W1,,1
S00045,1_origin,AN07,err,boundary,,,,,,,,,,,L1,Y1,Q1,R1,B1,W1,,0
S00046,1_origin,AN07,err,timing,,,,,,,,,,,L1,Y1,Q1,R1,,W1,,0
S00047,1_origin,AN08,distant,full,1,,,,,,F1,D1,,G1,L1,,,,,,,0
S00048,1_origin,AN08,incremental,full,1,,,,,,F1,,,G1,L1,,,,,,,0
S00049,1_origin,AN08,old,full,1,,,,,,,,,G1,L1,,,,,,,0
S00050,1_origin,AN08,new,full,1,,,,,,,,,G1,L1,,,,,,,0
S00051,1_origin,AN08,high_own,full,1,,,,,,,,,G1,L1,,,,,,,0
S00052,1_origin,AN08,low_own,full,1,,,,,,,,O1,G1,L1,,,,,,,0
S00053,1_origin,AN08,owner,full,1,,,,,,,,,G1,L1,,,,,,,0
S00054,1_origin,AN10,total_followon,full,,,,,,,F1,,,,,,,,,,,0
S00055,1_origin,AN11,followon,full,,,,,,,F1,,,G1,,,,,,,,0
S00056,1_origin,AN11,contributors,full,,,,,,,,,,G1,,,,,,,,0
S00057,1_origin,AN12,followon,full,,,,P2005,,,F1,,,G1,L1,Y1,Q1,,,,,0
S00058,1_origin,AN12,followon,full,,,,P2006,,,F1,,,G1,L1,Y1,Q1,,,,,0
S00059,1_origin,AN12,followon,full,,,,P2007,,,F1,,,G1,L1,Y1,Q1,,,,,0
S00060,1_origin,AN12,followon,full,,,,P2008,,,F1,,,G1,L1,Y1,Q1,,,,,0
S00061,1_origin,AN12,followon,full,,,,P2009,,,F1,,,G1,L1,Y1,Q1,,,,,0
S00062,1_origin,AN12,followon,full,,,,P2010,,,F1,,,G1,L1,Y1,Q1,,,,,0
S00063,1_origin,AN12,followon,full,,,,P2011,,,F1,,,G1,L1,Y1,Q1,,,,,0
S00064,1_origin,AN12,followon,full,,,,P2012,,,F1,,,G1,L1,Y1,Q1,,,,,0
S00065,1_origin,AN12,followon,full,,,,P2013,,,F1,,,G1,L1,Y1,Q1,,,,,0
S00066,1_origin,AN12,followon,full,,,,P2014,,,F1,,,G1,L1,Y1,Q1,,,,,0
S00067,1_origin,AN13,followon,full,1,,,,1,M1,F1,,,G1,L1,,,,,,,0
S00068,1_origin,AN13,followon,full,,,,P0814,1,M2,F1,,,G1,L1,Y1,Q1,,,,,0
S00069,1_origin,AN13,followon,full,1,,,,2,M1,F1,,,G1,L1,,,,,,,0
S00070,1_origin,AN13,followon,full,,,,P0814,2,M2,F1,,,G1,L1,Y1,Q1,,,,,0
S00071,1_origin,AN13,followon,full,1,,,,3,M1,F1,,,G1,L1,,,,,,,0
S00072,1_origin,AN13,followon,full,,,,P0814,3,M2,F1,,,G1,L1,Y1,Q1,,,,,0
S00073,1_origin,AN13,followon,full,1,,,,4,M1,F1,,,G1,L1,,,,,,,0
S00074,1_origin,AN13,followon,full,,,,P0814,4,M2,F1,,,G1,L1,Y1,Q1,,,,,0
S00075,1_origin,AN13,followon,full,1,,,,5,M1,F1,,,G1,L1,,,,,,,0
S00076,1_origin,AN13,followon,full,,,,P0814,5,M2,F1,,,G1,L1,Y1,Q1,,,,,0
S00077,1_origin,AN13,followon,full,1,,,,6,M1,F1,,,G1,L1,,,,,,,0
S00078,1_origin,AN13,followon,full,,,,P0814,6,M2,F1,,,G1,L1,Y1,Q1,,,,,0
S00079,1_origin,AN13,followon,full,1,,,,7,M1,F1,,,G1,L1,,,,,,,0
S00080,1_origin,AN13,followon,full,,,,P0814,7,M2,F1,,,G1,L1,Y1,Q1,,,,,0
S00081,1_origin,AN13,followon,full,1,,,,8,M1,F1,,,G1,L1,,,,,,,0
S00082,1_origin,AN13,followon,full,,,,P0814,8,M2,F1,,,G1,L1,Y1,Q1,,,,,0
S00083,1_origin,AN13,followon,full,1,,,,9,M1,F1,,,G1,L1,,,,,,,0
S00084,1_origin,AN13,followon,full,,,,P0814,9,M2,F1,,,G1,L1,Y1,Q1,,,,,0
S00085,1_origin,AN13,followon,full,1,,,,10,M1,F1,,,G1,L1,,,,,,,0
S00086,1_origin,AN13,followon,full,,,,P0814,10,M2,F1,,,G1,L1,Y1,Q1,,,,,0
S00087,1_origin,AN13,contributors,full,1,,,,1,M1,,,,G1,L1,,,,,,,0
S00088,1_origin,AN13,contributors,full,,,,P0814,1,M2,,,,G1,L1,Y1,Q1,,,,,0
S00089,1_origin,AN13,contributors,full,1,,,,2,M1,,,,G1,L1,,,,,,,0
S00090,1_origin,AN13,contributors,full,,,,P0814,2,M2,,,,G1,L1,Y1,Q1,,,,,0
S00091,1_origin,AN13,contributors,full,1,,,,3,M1,,,,G1,L1,,,,,,,0
S00092,1_origin,AN13,contributors,full,,,,P0814,3,M2,,,,G1,L1,Y1,Q1,,,,,0
S00093,1_origin,AN13,contributors,full,1,,,,4,M1,,,,G1,L1,,,,,,,0
S00094,1_origin,AN13,contributors,full,,,,P0814,4,M2,,,,G1,L1,Y1,Q1,,,,,0
S00095,1_origin,AN13,contributors,full,1,,,,5,M1,,,,G1,L1,,,,,,,0
S00096,1_origin,AN13,contributors,full,,,,P0814,5,M2,,,,G1,L1,Y1,Q1,,,,,0
S00097,1_origin,AN13,contributors,full,1,,,,6,M1,,,,G1,L1,,,,,,,0
S00098,1_origin,AN13,contributors,full,,,,P0814,6,M2,,,,G1,L1,Y1,Q1,,,,,0
S00099,1_origin,AN13,contributors,full,1,,,,7,M1,,,,G1,L1,,,,,,,0
S00100,1_origin,AN13,contributors,full,,,,P0814,7,M2,,,,G1,L1,Y1,Q1,,,,,0
S00101,1_origin,AN13,contributors,full,1,,,,8,M1,,,,G1,L1,,,,,,,0
S00102,1_origin,AN13,contributors,full,,,,P0814,8,M2,,,,G1,L1,Y1,Q1,,,,,0
S00103,1_origin,AN13,contributors,full,1,,,,9,M1,,,,G1,L1,,,,,,,0
S00104,1_origin,AN13,contributors,full,,,,P0814,9,M2,,,,G1,L1,Y1,Q1,,,,,0
S00105,1_origin,AN13,contributors,full,1,,,,10,M1,,,,G1,L1,,,,,,,0
S00106,1_origin,AN13,contributors,full,,,,P0814,10,M2,,,,G1,L1,Y1,Q1,,,,,0
S00107,1_origin,AN14,pct10,full,1,,,,,,,,,G1,L1,,,,,,,0
S00108,1_origin,AN14,pct25,full,1,,,,,,,,,G1,L1,,,,,,,0
S00109,1_origin,AN14,pct50,full,1,,,,,,,,,G1,L1,,,,,,,0
S00110,1_origin,AN14,pct75,full,1,,,,,,,,,G1,L1,,,,,,,0
S00111,1_origin,AN14,pct90,full,1,,,,,,,,,G1,L1,,,,,,,0
S00112,1_origin,AN14,pct99,full,1,,,,,,,,,G1,L1,,,,,,,0
S00113,2_deviation,AN01,,full,,,,,,,F2,,,,,,,,,,F=F2,0
S00114,2_deviation,AN01,,full,,,,,,,F3,,,,,,,,,,F=F3,0
S00115,2_deviation,AN01,,full,,,,,,,F4,,,,,,,,,,F=F4,0
S00116,2_deviation,AN02,,full,,,,,,,F2,D1,O1,,,,,,,,F=F2,0
S00117,2_deviation,AN02,,full,,,,,,,F3,D1,O1,,,,,,,,F=F3,0
S00118,2_deviation,AN02,,full,,,,,,,F4,D1,O1,,,,,,,,F=F4,0
S00119,2_deviation,AN02,,full,,,,,,,F1,D2,O1,,,,,,,,D=D2,0
S00120,2_deviation,AN02,,full,,,,,,,F1,D1,O2,,,,,,,,O=O2,0
S00121,2_deviation,AN03,total,full,0,,,,,,,,,G2,,,,,,,G=G2,0
S00122,2_deviation,AN03,total,full,1,,,,,,,,,G2,L1,,,,,,G=G2,0
S00123,2_deviation,AN03,total,full,1,,,,,,,,,G1,L2,,,,,,L=L2,0
S00124,2_deviation,AN04,total,full,,,,P0814,,,,,,G2,L1,Y1,Q1,,,,G=G2,0
S00125,2_deviation,AN04,total,full,,,,P0814,,,,,,G1,L2,Y1,Q1,,,,L=L2,0
S00126,2_deviation,AN04,total,full,,,,P0814,,,,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00127,2_deviation,AN04,total,full,,,,P0814,,,,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00128,2_deviation,AN04,total,full,,,,P0814,,,,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00129,2_deviation,AN04,total,full,,,,P14,,,,,,G2,L1,Y1,Q1,,,,G=G2,0
S00130,2_deviation,AN04,total,full,,,,P14,,,,,,G1,L2,Y1,Q1,,,,L=L2,0
S00131,2_deviation,AN04,total,full,,,,P14,,,,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00132,2_deviation,AN04,total,full,,,,P14,,,,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00133,2_deviation,AN04,total,full,,,,P14,,,,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00134,2_deviation,AN03,followon,full,0,,,,,,F2,,,G1,,,,,,,F=F2,1
S00135,2_deviation,AN03,followon,full,0,,,,,,F3,,,G1,,,,,,,F=F3,1
S00136,2_deviation,AN03,followon,full,0,,,,,,F4,,,G1,,,,,,,F=F4,1
S00137,2_deviation,AN03,followon,full,0,,,,,,F1,,,G2,,,,,,,G=G2,1
S00138,2_deviation,AN03,followon,full,1,,,,,,F2,,,G1,L1,,,,,,F=F2,1
S00139,2_deviation,AN03,followon,full,1,,,,,,F3,,,G1,L1,,,,,,F=F3,1
S00140,2_deviation,AN03,followon,full,1,,,,,,F4,,,G1,L1,,,,,,F=F4,1
S00141,2_deviation,AN03,followon,full,1,,,,,,F1,,,G2,L1,,,,,,G=G2,1
S00142,2_deviation,AN03,followon,full,1,,,,,,F1,,,G1,L2,,,,,,L=L2,1
S00143,2_deviation,AN04,followon,full,,,,P0814,,,F2,,,G1,L1,Y1,Q1,,,,F=F2,1
S00144,2_deviation,AN04,followon,full,,,,P0814,,,F3,,,G1,L1,Y1,Q1,,,,F=F3,1
S00145,2_deviation,AN04,followon,full,,,,P0814,,,F4,,,G1,L1,Y1,Q1,,,,F=F4,1
S00146,2_deviation,AN04,followon,full,,,,P0814,,,F1,,,G2,L1,Y1,Q1,,,,G=G2,1
S00147,2_deviation,AN04,followon,full,,,,P0814,,,F1,,,G1,L2,Y1,Q1,,,,L=L2,1
S00148,2_deviation,AN04,followon,full,,,,P0814,,,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,1
S00149,2_deviation,AN04,followon,full,,,,P0814,,,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,1
S00150,2_deviation,AN04,followon,full,,,,P0814,,,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,1
S00151,2_deviation,AN04,followon,full,,,,P14,,,F2,,,G1,L1,Y1,Q1,,,,F=F2,1
S00152,2_deviation,AN04,followon,full,,,,P14,,,F3,,,G1,L1,Y1,Q1,,,,F=F3,1
S00153,2_deviation,AN04,followon,full,,,,P14,,,F4,,,G1,L1,Y1,Q1,,,,F=F4,1
S00154,2_deviation,AN04,followon,full,,,,P14,,,F1,,,G2,L1,Y1,Q1,,,,G=G2,1
S00155,2_deviation,AN04,followon,full,,,,P14,,,F1,,,G1,L2,Y1,Q1,,,,L=L2,1
S00156,2_deviation,AN04,followon,full,,,,P14,,,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,1
S00157,2_deviation,AN04,followon,full,,,,P14,,,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,1
S00158,2_deviation,AN04,followon,full,,,,P14,,,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,1
S00159,2_deviation,AN03,contributors,full,0,,,,,,,,,G2,,,,,,,G=G2,1
S00160,2_deviation,AN03,contributors,full,1,,,,,,,,,G2,L1,,,,,,G=G2,1
S00161,2_deviation,AN03,contributors,full,1,,,,,,,,,G1,L2,,,,,,L=L2,1
S00162,2_deviation,AN04,contributors,full,,,,P0814,,,,,,G2,L1,Y1,Q1,,,,G=G2,1
S00163,2_deviation,AN04,contributors,full,,,,P0814,,,,,,G1,L2,Y1,Q1,,,,L=L2,1
S00164,2_deviation,AN04,contributors,full,,,,P0814,,,,,,G1,L1,Y2,Q1,,,,Y=Y2,1
S00165,2_deviation,AN04,contributors,full,,,,P0814,,,,,,G1,L1,Y3,Q1,,,,Y=Y3,1
S00166,2_deviation,AN04,contributors,full,,,,P0814,,,,,,G1,L1,Y1,Q2,,,,Q=Q2,1
S00167,2_deviation,AN04,contributors,full,,,,P14,,,,,,G2,L1,Y1,Q1,,,,G=G2,1
S00168,2_deviation,AN04,contributors,full,,,,P14,,,,,,G1,L2,Y1,Q1,,,,L=L2,1
S00169,2_deviation,AN04,contributors,full,,,,P14,,,,,,G1,L1,Y2,Q1,,,,Y=Y2,1
S00170,2_deviation,AN04,contributors,full,,,,P14,,,,,,G1,L1,Y3,Q1,,,,Y=Y3,1
S00171,2_deviation,AN04,contributors,full,,,,P14,,,,,,G1,L1,Y1,Q2,,,,Q=Q2,1
S00172,2_deviation,AN05,followon,full,1,dtt,,,,,F2,,,G1,L1,,,,,,F=F2,0
S00173,2_deviation,AN05,followon,full,1,dtt,,,,,F3,,,G1,L1,,,,,,F=F3,0
S00174,2_deviation,AN05,followon,full,1,dtt,,,,,F4,,,G1,L1,,,,,,F=F4,0
S00175,2_deviation,AN05,followon,full,1,dtt,,,,,F1,,,G2,L1,,,,,,G=G2,0
S00176,2_deviation,AN05,followon,full,1,dtt,,,,,F1,,,G1,L2,,,,,,L=L2,0
S00177,2_deviation,AN05,followon,full,0,dtt,,,,,F2,,,G1,,,,,,,F=F2,0
S00178,2_deviation,AN05,followon,full,0,dtt,,,,,F3,,,G1,,,,,,,F=F3,0
S00179,2_deviation,AN05,followon,full,0,dtt,,,,,F4,,,G1,,,,,,,F=F4,0
S00180,2_deviation,AN05,followon,full,0,dtt,,,,,F1,,,G2,,,,,,,G=G2,0
S00181,2_deviation,AN05,followon,boundary,1,boundary,,,,,F2,,,G1,L1,,,,B1,,F=F2,0
S00182,2_deviation,AN05,followon,boundary,1,boundary,,,,,F3,,,G1,L1,,,,B1,,F=F3,0
S00183,2_deviation,AN05,followon,boundary,1,boundary,,,,,F4,,,G1,L1,,,,B1,,F=F4,0
S00184,2_deviation,AN05,followon,boundary,1,boundary,,,,,F1,,,G2,L1,,,,B1,,G=G2,0
S00185,2_deviation,AN05,followon,boundary,1,boundary,,,,,F1,,,G1,L2,,,,B1,,L=L2,0
S00186,2_deviation,AN05,followon,boundary,1,boundary,,,,,F1,,,G1,L1,,,,B2,,B=B2,0
S00187,2_deviation,AN05,followon,boundary,0,boundary,,,,,F2,,,G1,,,,,B1,,F=F2,0
S00188,2_deviation,AN05,followon,boundary,0,boundary,,,,,F3,,,G1,,,,,B1,,F=F3,0
S00189,2_deviation,AN05,followon,boundary,0,boundary,,,,,F4,,,G1,,,,,B1,,F=F4,0
S00190,2_deviation,AN05,followon,boundary,0,boundary,,,,,F1,,,G2,,,,,B1,,G=G2,0
S00191,2_deviation,AN05,followon,boundary,0,boundary,,,,,F1,,,G1,,,,,B2,,B=B2,0
S00192,2_deviation,AN05,followon,timing,1,timing,,,,,F2,,,G1,L1,,,,,,F=F2,0
S00193,2_deviation,AN05,followon,timing,1,timing,,,,,F3,,,G1,L1,,,,,,F=F3,0
S00194,2_deviation,AN05,followon,timing,1,timing,,,,,F4,,,G1,L1,,,,,,F=F4,0
S00195,2_deviation,AN05,followon,timing,1,timing,,,,,F1,,,G2,L1,,,,,,G=G2,0
S00196,2_deviation,AN05,followon,timing,1,timing,,,,,F1,,,G1,L2,,,,,,L=L2,0
S00197,2_deviation,AN05,followon,timing,0,timing,,,,,F2,,,G1,,,,,,,F=F2,0
S00198,2_deviation,AN05,followon,timing,0,timing,,,,,F3,,,G1,,,,,,,F=F3,0
S00199,2_deviation,AN05,followon,timing,0,timing,,,,,F4,,,G1,,,,,,,F=F4,0
S00200,2_deviation,AN05,followon,timing,0,timing,,,,,F1,,,G2,,,,,,,G=G2,0
S00201,2_deviation,AN05,followon,full,1,placebo_perm,0,,,,F2,,,G1,L1,,,,,,F=F2,0
S00202,2_deviation,AN05,followon,full,1,placebo_perm,0,,,,F3,,,G1,L1,,,,,,F=F3,0
S00203,2_deviation,AN05,followon,full,1,placebo_perm,0,,,,F4,,,G1,L1,,,,,,F=F4,0
S00204,2_deviation,AN05,followon,full,1,placebo_perm,0,,,,F1,,,G2,L1,,,,,,G=G2,0
S00205,2_deviation,AN05,followon,full,1,placebo_perm,0,,,,F1,,,G1,L2,,,,,,L=L2,0
S00206,2_deviation,AN05,followon,full,0,placebo_perm,0,,,,F2,,,G1,,,,,,,F=F2,0
S00207,2_deviation,AN05,followon,full,0,placebo_perm,0,,,,F3,,,G1,,,,,,,F=F3,0
S00208,2_deviation,AN05,followon,full,0,placebo_perm,0,,,,F4,,,G1,,,,,,,F=F4,0
S00209,2_deviation,AN05,followon,full,0,placebo_perm,0,,,,F1,,,G2,,,,,,,G=G2,0
S00210,2_deviation,AN05,followon,full,1,placebo_bern,0,,,,F2,,,G1,L1,,,,,,F=F2,0
S00211,2_deviation,AN05,followon,full,1,placebo_bern,0,,,,F3,,,G1,L1,,,,,,F=F3,0
S00212,2_deviation,AN05,followon,full,1,placebo_bern,0,,,,F4,,,G1,L1,,,,,,F=F4,0
S00213,2_deviation,AN05,followon,full,1,placebo_bern,0,,,,F1,,,G2,L1,,,,,,G=G2,0
S00214,2_deviation,AN05,followon,full,1,placebo_bern,0,,,,F1,,,G1,L2,,,,,,L=L2,0
S00215,2_deviation,AN05,followon,full,0,placebo_bern,0,,,,F2,,,G1,,,,,,,F=F2,0
S00216,2_deviation,AN05,followon,full,0,placebo_bern,0,,,,F3,,,G1,,,,,,,F=F3,0
S00217,2_deviation,AN05,followon,full,0,placebo_bern,0,,,,F4,,,G1,,,,,,,F=F4,0
S00218,2_deviation,AN05,followon,full,0,placebo_bern,0,,,,F1,,,G2,,,,,,,G=G2,0
S00219,2_deviation,AN06,followon,boundary,,,,P0814,,,F2,,,G1,L1,Y1,Q1,R1,B1,,F=F2,0
S00220,2_deviation,AN06,followon,boundary,,,,P0814,,,F3,,,G1,L1,Y1,Q1,R1,B1,,F=F3,0
S00221,2_deviation,AN06,followon,boundary,,,,P0814,,,F4,,,G1,L1,Y1,Q1,R1,B1,,F=F4,0
S00222,2_deviation,AN06,followon,boundary,,,,P0814,,,F1,,,G2,L1,Y1,Q1,R1,B1,,G=G2,0
S00223,2_deviation,AN06,followon,boundary,,,,P0814,,,F1,,,G1,L2,Y1,Q1,R1,B1,,L=L2,0
S00224,2_deviation,AN06,followon,boundary,,,,P0814,,,F1,,,G1,L1,Y2,Q1,R1,B1,,Y=Y2,0
S00225,2_deviation,AN06,followon,boundary,,,,P0814,,,F1,,,G1,L1,Y3,Q1,R1,B1,,Y=Y3,0
S00226,2_deviation,AN06,followon,boundary,,,,P0814,,,F1,,,G1,L1,Y1,Q2,R1,B1,,Q=Q2,0
S00227,2_deviation,AN06,followon,boundary,,,,P0814,,,F1,,,G1,L1,Y1,Q1,R2,B1,,R=R2,0
S00228,2_deviation,AN06,followon,boundary,,,,P0814,,,F1,,,G1,L1,Y1,Q1,R1,B2,,B=B2,0
S00229,2_deviation,AN06,followon,boundary,,,,P14,,,F2,,,G1,L1,Y1,Q1,R1,B1,,F=F2,0
S00230,2_deviation,AN06,followon,boundary,,,,P14,,,F3,,,G1,L1,Y1,Q1,R1,B1,,F=F3,0
S00231,2_deviation,AN06,followon,boundary,,,,P14,,,F4,,,G1,L1,Y1,Q1,R1,B1,,F=F4,0
S00232,2_deviation,AN06,followon,boundary,,,,P14,,,F1,,,G2,L1,Y1,Q1,R1,B1,,G=G2,0
S00233,2_deviation,AN06,followon,boundary,,,,P14,,,F1,,,G1,L2,Y1,Q1,R1,B1,,L=L2,0
S00234,2_deviation,AN06,followon,boundary,,,,P14,,,F1,,,G1,L1,Y2,Q1,R1,B1,,Y=Y2,0
S00235,2_deviation,AN06,followon,boundary,,,,P14,,,F1,,,G1,L1,Y3,Q1,R1,B1,,Y=Y3,0
S00236,2_deviation,AN06,followon,boundary,,,,P14,,,F1,,,G1,L1,Y1,Q2,R1,B1,,Q=Q2,0
S00237,2_deviation,AN06,followon,boundary,,,,P14,,,F1,,,G1,L1,Y1,Q1,R2,B1,,R=R2,0
S00238,2_deviation,AN06,followon,boundary,,,,P14,,,F1,,,G1,L1,Y1,Q1,R1,B2,,B=B2,0
S00239,2_deviation,AN06,followon,timing,,,,P0814,,,F2,,,G1,L1,Y1,Q1,R1,,,F=F2,0
S00240,2_deviation,AN06,followon,timing,,,,P0814,,,F3,,,G1,L1,Y1,Q1,R1,,,F=F3,0
S00241,2_deviation,AN06,followon,timing,,,,P0814,,,F4,,,G1,L1,Y1,Q1,R1,,,F=F4,0
S00242,2_deviation,AN06,followon,timing,,,,P0814,,,F1,,,G2,L1,Y1,Q1,R1,,,G=G2,0
S00243,2_deviation,AN06,followon,timing,,,,P0814,,,F1,,,G1,L2,Y1,Q1,R1,,,L=L2,0
S00244,2_deviation,AN06,followon,timing,,,,P0814,,,F1,,,G1,L1,Y2,Q1,R1,,,Y=Y2,0
S00245,2_deviation,AN06,followon,timing,,,,P0814,,,F1,,,G1,L1,Y3,Q1,R1,,,Y=Y3,0
S00246,2_deviation,AN06,followon,timing,,,,P0814,,,F1,,,G1,L1,Y1,Q2,R1,,,Q=Q2,0
S00247,2_deviation,AN06,followon,timing,,,,P0814,,,F1,,,G1,L1,Y1,Q1,R2,,,R=R2,0
S00248,2_deviation,AN06,followon,timing,,,,P14,,,F2,,,G1,L1,Y1,Q1,R1,,,F=F2,0
S00249,2_deviation,AN06,followon,timing,,,,P14,,,F3,,,G1,L1,Y1,Q1,R1,,,F=F3,0
S00250,2_deviation,AN06,followon,timing,,,,P14,,,F4,,,G1,L1,Y1,Q1,R1,,,F=F4,0
S00251,2_deviation,AN06,followon,timing,,,,P14,,,F1,,,G2,L1,Y1,Q1,R1,,,G=G2,0
S00252,2_deviation,AN06,followon,timing,,,,P14,,,F1,,,G1,L2,Y1,Q1,R1,,,L=L2,0
S00253,2_deviation,AN06,followon,timing,,,,P14,,,F1,,,G1,L1,Y2,Q1,R1,,,Y=Y2,0
S00254,2_deviation,AN06,followon,timing,,,,P14,,,F1,,,G1,L1,Y3,Q1,R1,,,Y=Y3,0
S00255,2_deviation,AN06,followon,timing,,,,P14,,,F1,,,G1,L1,Y1,Q2,R1,,,Q=Q2,0
S00256,2_deviation,AN06,followon,timing,,,,P14,,,F1,,,G1,L1,Y1,Q1,R2,,,R=R2,0
S00257,2_deviation,AN05,contributors,full,1,dtt,,,,,,,,G2,L1,,,,,,G=G2,0
S00258,2_deviation,AN05,contributors,full,1,dtt,,,,,,,,G1,L2,,,,,,L=L2,0
S00259,2_deviation,AN05,contributors,full,0,dtt,,,,,,,,G2,,,,,,,G=G2,0
S00260,2_deviation,AN05,contributors,boundary,1,boundary,,,,,,,,G2,L1,,,,B1,,G=G2,0
S00261,2_deviation,AN05,contributors,boundary,1,boundary,,,,,,,,G1,L2,,,,B1,,L=L2,0
S00262,2_deviation,AN05,contributors,boundary,1,boundary,,,,,,,,G1,L1,,,,B2,,B=B2,0
S00263,2_deviation,AN05,contributors,boundary,0,boundary,,,,,,,,G2,,,,,B1,,G=G2,0
S00264,2_deviation,AN05,contributors,boundary,0,boundary,,,,,,,,G1,,,,,B2,,B=B2,0
S00265,2_deviation,AN05,contributors,timing,1,timing,,,,,,,,G2,L1,,,,,,G=G2,0
S00266,2_deviation,AN05,contributors,timing,1,timing,,,,,,,,G1,L2,,,,,,L=L2,0
S00267,2_deviation,AN05,contributors,timing,0,timing,,,,,,,,G2,,,,,,,G=G2,0
S00268,2_deviation,AN05,contributors,full,1,placebo_perm,0,,,,,,,G2,L1,,,,,,G=G2,0
S00269,2_deviation,AN05,contributors,full,1,placebo_perm,0,,,,,,,G1,L2,,,,,,L=L2,0
S00270,2_deviation,AN05,contributors,full,0,placebo_perm,0,,,,,,,G2,,,,,,,G=G2,0
S00271,2_deviation,AN05,contributors,full,1,placebo_bern,0,,,,,,,G2,L1,,,,,,G=G2,0
S00272,2_deviation,AN05,contributors,full,1,placebo_bern,0,,,,,,,G1,L2,,,,,,L=L2,0
S00273,2_deviation,AN05,contributors,full,0,placebo_bern,0,,,,,,,G2,,,,,,,G=G2,0
S00274,2_deviation,AN06,contributors,boundary,,,,P0814,,,,,,G2,L1,Y1,Q1,R1,B1,,G=G2,0
S00275,2_deviation,AN06,contributors,boundary,,,,P0814,,,,,,G1,L2,Y1,Q1,R1,B1,,L=L2,0
S00276,2_deviation,AN06,contributors,boundary,,,,P0814,,,,,,G1,L1,Y2,Q1,R1,B1,,Y=Y2,0
S00277,2_deviation,AN06,contributors,boundary,,,,P0814,,,,,,G1,L1,Y3,Q1,R1,B1,,Y=Y3,0
S00278,2_deviation,AN06,contributors,boundary,,,,P0814,,,,,,G1,L1,Y1,Q2,R1,B1,,Q=Q2,0
S00279,2_deviation,AN06,contributors,boundary,,,,P0814,,,,,,G1,L1,Y1,Q1,R2,B1,,R=R2,0
S00280,2_deviation,AN06,contributors,boundary,,,,P0814,,,,,,G1,L1,Y1,Q1,R1,B2,,B=B2,0
S00281,2_deviation,AN06,contributors,boundary,,,,P14,,,,,,G2,L1,Y1,Q1,R1,B1,,G=G2,0
S00282,2_deviation,AN06,contributors,boundary,,,,P14,,,,,,G1,L2,Y1,Q1,R1,B1,,L=L2,0
S00283,2_deviation,AN06,contributors,boundary,,,,P14,,,,,,G1,L1,Y2,Q1,R1,B1,,Y=Y2,0
S00284,2_deviation,AN06,contributors,boundary,,,,P14,,,,,,G1,L1,Y3,Q1,R1,B1,,Y=Y3,0
S00285,2_deviation,AN06,contributors,boundary,,,,P14,,,,,,G1,L1,Y1,Q2,R1,B1,,Q=Q2,0
S00286,2_deviation,AN06,contributors,boundary,,,,P14,,,,,,G1,L1,Y1,Q1,R2,B1,,R=R2,0
S00287,2_deviation,AN06,contributors,boundary,,,,P14,,,,,,G1,L1,Y1,Q1,R1,B2,,B=B2,0
S00288,2_deviation,AN06,contributors,timing,,,,P0814,,,,,,G2,L1,Y1,Q1,R1,,,G=G2,0
S00289,2_deviation,AN06,contributors,timing,,,,P0814,,,,,,G1,L2,Y1,Q1,R1,,,L=L2,0
S00290,2_deviation,AN06,contributors,timing,,,,P0814,,,,,,G1,L1,Y2,Q1,R1,,,Y=Y2,0
S00291,2_deviation,AN06,contributors,timing,,,,P0814,,,,,,G1,L1,Y3,Q1,R1,,,Y=Y3,0
S00292,2_deviation,AN06,contributors,timing,,,,P0814,,,,,,G1,L1,Y1,Q2,R1,,,Q=Q2,0
S00293,2_deviation,AN06,contributors,timing,,,,P0814,,,,,,G1,L1,Y1,Q1,R2,,,R=R2,0
S00294,2_deviation,AN06,contributors,timing,,,,P14,,,,,,G2,L1,Y1,Q1,R1,,,G=G2,0
S00295,2_deviation,AN06,contributors,timing,,,,P14,,,,,,G1,L2,Y1,Q1,R1,,,L=L2,0
S00296,2_deviation,AN06,contributors,timing,,,,P14,,,,,,G1,L1,Y2,Q1,R1,,,Y=Y2,0
S00297,2_deviation,AN06,contributors,timing,,,,P14,,,,,,G1,L1,Y3,Q1,R1,,,Y=Y3,0
S00298,2_deviation,AN06,contributors,timing,,,,P14,,,,,,G1,L1,Y1,Q2,R1,,,Q=Q2,0
S00299,2_deviation,AN06,contributors,timing,,,,P14,,,,,,G1,L1,Y1,Q1,R2,,,R=R2,0
S00300,2_deviation,AN07,err,full,,,,,,,,,,,L2,Y1,Q1,,,W1,L=L2,1
S00301,2_deviation,AN07,err,full,,,,,,,,,,,L1,Y2,Q1,,,W1,Y=Y2,1
S00302,2_deviation,AN07,err,full,,,,,,,,,,,L1,Y3,Q1,,,W1,Y=Y3,1
S00303,2_deviation,AN07,err,full,,,,,,,,,,,L1,Y1,Q2,,,W1,Q=Q2,1
S00304,2_deviation,AN07,err,full,,,,,,,,,,,L1,Y1,Q1,,,W3,W=W3,1
S00305,2_deviation,AN07,err,full,,,,,,,,,,,L1,Y1,Q1,,,W4,W=W4,1
S00306,2_deviation,AN07,err,boundary,,,,,,,,,,,L2,Y1,Q1,R1,B1,W1,L=L2,0
S00307,2_deviation,AN07,err,boundary,,,,,,,,,,,L1,Y2,Q1,R1,B1,W1,Y=Y2,0
S00308,2_deviation,AN07,err,boundary,,,,,,,,,,,L1,Y3,Q1,R1,B1,W1,Y=Y3,0
S00309,2_deviation,AN07,err,boundary,,,,,,,,,,,L1,Y1,Q2,R1,B1,W1,Q=Q2,0
S00310,2_deviation,AN07,err,boundary,,,,,,,,,,,L1,Y1,Q1,R2,B1,W1,R=R2,0
S00311,2_deviation,AN07,err,boundary,,,,,,,,,,,L1,Y1,Q1,R1,B2,W1,B=B2,0
S00312,2_deviation,AN07,err,boundary,,,,,,,,,,,L1,Y1,Q1,R1,B1,W3,W=W3,0
S00313,2_deviation,AN07,err,boundary,,,,,,,,,,,L1,Y1,Q1,R1,B1,W4,W=W4,0
S00314,2_deviation,AN07,err,timing,,,,,,,,,,,L2,Y1,Q1,R1,,W1,L=L2,0
S00315,2_deviation,AN07,err,timing,,,,,,,,,,,L1,Y2,Q1,R1,,W1,Y=Y2,0
S00316,2_deviation,AN07,err,timing,,,,,,,,,,,L1,Y3,Q1,R1,,W1,Y=Y3,0
S00317,2_deviation,AN07,err,timing,,,,,,,,,,,L1,Y1,Q2,R1,,W1,Q=Q2,0
S00318,2_deviation,AN07,err,timing,,,,,,,,,,,L1,Y1,Q1,R2,,W1,R=R2,0
S00319,2_deviation,AN07,err,timing,,,,,,,,,,,L1,Y1,Q1,R1,,W3,W=W3,0
S00320,2_deviation,AN07,err,timing,,,,,,,,,,,L1,Y1,Q1,R1,,W4,W=W4,0
S00321,2_deviation,AN08,distant,full,1,,,,,,F2,D1,,G1,L1,,,,,,F=F2,0
S00322,2_deviation,AN08,distant,full,1,,,,,,F3,D1,,G1,L1,,,,,,F=F3,0
S00323,2_deviation,AN08,distant,full,1,,,,,,F4,D1,,G1,L1,,,,,,F=F4,0
S00324,2_deviation,AN08,distant,full,1,,,,,,F1,D2,,G1,L1,,,,,,D=D2,0
S00325,2_deviation,AN08,distant,full,1,,,,,,F1,D1,,G2,L1,,,,,,G=G2,0
S00326,2_deviation,AN08,distant,full,1,,,,,,F1,D1,,G1,L2,,,,,,L=L2,0
S00327,2_deviation,AN08,incremental,full,1,,,,,,F2,,,G1,L1,,,,,,F=F2,0
S00328,2_deviation,AN08,incremental,full,1,,,,,,F3,,,G1,L1,,,,,,F=F3,0
S00329,2_deviation,AN08,incremental,full,1,,,,,,F4,,,G1,L1,,,,,,F=F4,0
S00330,2_deviation,AN08,incremental,full,1,,,,,,F1,,,G2,L1,,,,,,G=G2,0
S00331,2_deviation,AN08,incremental,full,1,,,,,,F1,,,G1,L2,,,,,,L=L2,0
S00332,2_deviation,AN08,old,full,1,,,,,,,,,G2,L1,,,,,,G=G2,0
S00333,2_deviation,AN08,old,full,1,,,,,,,,,G1,L2,,,,,,L=L2,0
S00334,2_deviation,AN08,new,full,1,,,,,,,,,G2,L1,,,,,,G=G2,0
S00335,2_deviation,AN08,new,full,1,,,,,,,,,G1,L2,,,,,,L=L2,0
S00336,2_deviation,AN08,high_own,full,1,,,,,,,,,G2,L1,,,,,,G=G2,0
S00337,2_deviation,AN08,high_own,full,1,,,,,,,,,G1,L2,,,,,,L=L2,0
S00338,2_deviation,AN08,low_own,full,1,,,,,,,,O2,G1,L1,,,,,,O=O2,0
S00339,2_deviation,AN08,low_own,full,1,,,,,,,,O1,G2,L1,,,,,,G=G2,0
S00340,2_deviation,AN08,low_own,full,1,,,,,,,,O1,G1,L2,,,,,,L=L2,0
S00341,2_deviation,AN08,owner,full,1,,,,,,,,,G2,L1,,,,,,G=G2,0
S00342,2_deviation,AN08,owner,full,1,,,,,,,,,G1,L2,,,,,,L=L2,0
S00343,2_deviation,AN10,total_followon,full,,,,,,,F2,,,,,,,,,,F=F2,0
S00344,2_deviation,AN10,total_followon,full,,,,,,,F3,,,,,,,,,,F=F3,0
S00345,2_deviation,AN10,total_followon,full,,,,,,,F4,,,,,,,,,,F=F4,0
S00346,2_deviation,AN11,followon,full,,,,,,,F2,,,G1,,,,,,,F=F2,0
S00347,2_deviation,AN11,followon,full,,,,,,,F3,,,G1,,,,,,,F=F3,0
S00348,2_deviation,AN11,followon,full,,,,,,,F4,,,G1,,,,,,,F=F4,0
S00349,2_deviation,AN11,followon,full,,,,,,,F1,,,G2,,,,,,,G=G2,0
S00350,2_deviation,AN11,contributors,full,,,,,,,,,,G2,,,,,,,G=G2,0
S00351,2_deviation,AN12,followon,full,,,,P2005,,,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00352,2_deviation,AN12,followon,full,,,,P2005,,,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00353,2_deviation,AN12,followon,full,,,,P2005,,,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00354,2_deviation,AN12,followon,full,,,,P2005,,,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00355,2_deviation,AN12,followon,full,,,,P2005,,,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00356,2_deviation,AN12,followon,full,,,,P2005,,,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00357,2_deviation,AN12,followon,full,,,,P2005,,,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00358,2_deviation,AN12,followon,full,,,,P2005,,,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00359,2_deviation,AN12,followon,full,,,,P2006,,,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00360,2_deviation,AN12,followon,full,,,,P2006,,,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00361,2_deviation,AN12,followon,full,,,,P2006,,,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00362,2_deviation,AN12,followon,full,,,,P2006,,,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00363,2_deviation,AN12,followon,full,,,,P2006,,,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00364,2_deviation,AN12,followon,full,,,,P2006,,,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00365,2_deviation,AN12,followon,full,,,,P2006,,,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00366,2_deviation,AN12,followon,full,,,,P2006,,,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00367,2_deviation,AN12,followon,full,,,,P2007,,,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00368,2_deviation,AN12,followon,full,,,,P2007,,,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00369,2_deviation,AN12,followon,full,,,,P2007,,,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00370,2_deviation,AN12,followon,full,,,,P2007,,,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00371,2_deviation,AN12,followon,full,,,,P2007,,,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00372,2_deviation,AN12,followon,full,,,,P2007,,,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00373,2_deviation,AN12,followon,full,,,,P2007,,,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00374,2_deviation,AN12,followon,full,,,,P2007,,,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00375,2_deviation,AN12,followon,full,,,,P2008,,,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00376,2_deviation,AN12,followon,full,,,,P2008,,,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00377,2_deviation,AN12,followon,full,,,,P2008,,,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00378,2_deviation,AN12,followon,full,,,,P2008,,,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00379,2_deviation,AN12,followon,full,,,,P2008,,,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00380,2_deviation,AN12,followon,full,,,,P2008,,,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00381,2_deviation,AN12,followon,full,,,,P2008,,,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00382,2_deviation,AN12,followon,full,,,,P2008,,,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00383,2_deviation,AN12,followon,full,,,,P2009,,,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00384,2_deviation,AN12,followon,full,,,,P2009,,,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00385,2_deviation,AN12,followon,full,,,,P2009,,,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00386,2_deviation,AN12,followon,full,,,,P2009,,,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00387,2_deviation,AN12,followon,full,,,,P2009,,,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00388,2_deviation,AN12,followon,full,,,,P2009,,,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00389,2_deviation,AN12,followon,full,,,,P2009,,,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00390,2_deviation,AN12,followon,full,,,,P2009,,,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00391,2_deviation,AN12,followon,full,,,,P2010,,,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00392,2_deviation,AN12,followon,full,,,,P2010,,,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00393,2_deviation,AN12,followon,full,,,,P2010,,,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00394,2_deviation,AN12,followon,full,,,,P2010,,,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00395,2_deviation,AN12,followon,full,,,,P2010,,,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00396,2_deviation,AN12,followon,full,,,,P2010,,,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00397,2_deviation,AN12,followon,full,,,,P2010,,,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00398,2_deviation,AN12,followon,full,,,,P2010,,,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00399,2_deviation,AN12,followon,full,,,,P2011,,,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00400,2_deviation,AN12,followon,full,,,,P2011,,,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00401,2_deviation,AN12,followon,full,,,,P2011,,,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00402,2_deviation,AN12,followon,full,,,,P2011,,,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00403,2_deviation,AN12,followon,full,,,,P2011,,,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00404,2_deviation,AN12,followon,full,,,,P2011,,,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00405,2_deviation,AN12,followon,full,,,,P2011,,,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00406,2_deviation,AN12,followon,full,,,,P2011,,,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00407,2_deviation,AN12,followon,full,,,,P2012,,,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00408,2_deviation,AN12,followon,full,,,,P2012,,,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00409,2_deviation,AN12,followon,full,,,,P2012,,,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00410,2_deviation,AN12,followon,full,,,,P2012,,,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00411,2_deviation,AN12,followon,full,,,,P2012,,,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00412,2_deviation,AN12,followon,full,,,,P2012,,,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00413,2_deviation,AN12,followon,full,,,,P2012,,,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00414,2_deviation,AN12,followon,full,,,,P2012,,,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00415,2_deviation,AN12,followon,full,,,,P2013,,,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00416,2_deviation,AN12,followon,full,,,,P2013,,,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00417,2_deviation,AN12,followon,full,,,,P2013,,,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00418,2_deviation,AN12,followon,full,,,,P2013,,,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00419,2_deviation,AN12,followon,full,,,,P2013,,,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00420,2_deviation,AN12,followon,full,,,,P2013,,,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00421,2_deviation,AN12,followon,full,,,,P2013,,,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00422,2_deviation,AN12,followon,full,,,,P2013,,,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00423,2_deviation,AN12,followon,full,,,,P2014,,,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00424,2_deviation,AN12,followon,full,,,,P2014,,,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00425,2_deviation,AN12,followon,full,,,,P2014,,,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00426,2_deviation,AN12,followon,full,,,,P2014,,,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00427,2_deviation,AN12,followon,full,,,,P2014,,,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00428,2_deviation,AN12,followon,full,,,,P2014,,,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00429,2_deviation,AN12,followon,full,,,,P2014,,,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00430,2_deviation,AN12,followon,full,,,,P2014,,,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00431,2_deviation,AN13,followon,full,1,,,,1,M1,F2,,,G1,L1,,,,,,F=F2,0
S00432,2_deviation,AN13,followon,full,1,,,,1,M1,F3,,,G1,L1,,,,,,F=F3,0
S00433,2_deviation,AN13,followon,full,1,,,,1,M1,F4,,,G1,L1,,,,,,F=F4,0
S00434,2_deviation,AN13,followon,full,1,,,,1,M1,F1,,,G2,L1,,,,,,G=G2,0
S00435,2_deviation,AN13,followon,full,1,,,,1,M1,F1,,,G1,L2,,,,,,L=L2,0
S00436,2_deviation,AN13,followon,full,,,,P0814,1,M2,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00437,2_deviation,AN13,followon,full,,,,P0814,1,M2,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00438,2_deviation,AN13,followon,full,,,,P0814,1,M2,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00439,2_deviation,AN13,followon,full,,,,P0814,1,M2,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00440,2_deviation,AN13,followon,full,,,,P0814,1,M2,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00441,2_deviation,AN13,followon,full,,,,P0814,1,M2,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00442,2_deviation,AN13,followon,full,,,,P0814,1,M2,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00443,2_deviation,AN13,followon,full,,,,P0814,1,M2,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00444,2_deviation,AN13,followon,full,1,,,,2,M1,F2,,,G1,L1,,,,,,F=F2,0
S00445,2_deviation,AN13,followon,full,1,,,,2,M1,F3,,,G1,L1,,,,,,F=F3,0
S00446,2_deviation,AN13,followon,full,1,,,,2,M1,F4,,,G1,L1,,,,,,F=F4,0
S00447,2_deviation,AN13,followon,full,1,,,,2,M1,F1,,,G2,L1,,,,,,G=G2,0
S00448,2_deviation,AN13,followon,full,1,,,,2,M1,F1,,,G1,L2,,,,,,L=L2,0
S00449,2_deviation,AN13,followon,full,,,,P0814,2,M2,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00450,2_deviation,AN13,followon,full,,,,P0814,2,M2,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00451,2_deviation,AN13,followon,full,,,,P0814,2,M2,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00452,2_deviation,AN13,followon,full,,,,P0814,2,M2,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00453,2_deviation,AN13,followon,full,,,,P0814,2,M2,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00454,2_deviation,AN13,followon,full,,,,P0814,2,M2,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00455,2_deviation,AN13,followon,full,,,,P0814,2,M2,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00456,2_deviation,AN13,followon,full,,,,P0814,2,M2,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00457,2_deviation,AN13,followon,full,1,,,,3,M1,F2,,,G1,L1,,,,,,F=F2,0
S00458,2_deviation,AN13,followon,full,1,,,,3,M1,F3,,,G1,L1,,,,,,F=F3,0
S00459,2_deviation,AN13,followon,full,1,,,,3,M1,F4,,,G1,L1,,,,,,F=F4,0
S00460,2_deviation,AN13,followon,full,1,,,,3,M1,F1,,,G2,L1,,,,,,G=G2,0
S00461,2_deviation,AN13,followon,full,1,,,,3,M1,F1,,,G1,L2,,,,,,L=L2,0
S00462,2_deviation,AN13,followon,full,,,,P0814,3,M2,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00463,2_deviation,AN13,followon,full,,,,P0814,3,M2,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00464,2_deviation,AN13,followon,full,,,,P0814,3,M2,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00465,2_deviation,AN13,followon,full,,,,P0814,3,M2,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00466,2_deviation,AN13,followon,full,,,,P0814,3,M2,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00467,2_deviation,AN13,followon,full,,,,P0814,3,M2,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00468,2_deviation,AN13,followon,full,,,,P0814,3,M2,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00469,2_deviation,AN13,followon,full,,,,P0814,3,M2,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00470,2_deviation,AN13,followon,full,1,,,,4,M1,F2,,,G1,L1,,,,,,F=F2,0
S00471,2_deviation,AN13,followon,full,1,,,,4,M1,F3,,,G1,L1,,,,,,F=F3,0
S00472,2_deviation,AN13,followon,full,1,,,,4,M1,F4,,,G1,L1,,,,,,F=F4,0
S00473,2_deviation,AN13,followon,full,1,,,,4,M1,F1,,,G2,L1,,,,,,G=G2,0
S00474,2_deviation,AN13,followon,full,1,,,,4,M1,F1,,,G1,L2,,,,,,L=L2,0
S00475,2_deviation,AN13,followon,full,,,,P0814,4,M2,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00476,2_deviation,AN13,followon,full,,,,P0814,4,M2,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00477,2_deviation,AN13,followon,full,,,,P0814,4,M2,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00478,2_deviation,AN13,followon,full,,,,P0814,4,M2,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00479,2_deviation,AN13,followon,full,,,,P0814,4,M2,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00480,2_deviation,AN13,followon,full,,,,P0814,4,M2,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00481,2_deviation,AN13,followon,full,,,,P0814,4,M2,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00482,2_deviation,AN13,followon,full,,,,P0814,4,M2,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00483,2_deviation,AN13,followon,full,1,,,,5,M1,F2,,,G1,L1,,,,,,F=F2,0
S00484,2_deviation,AN13,followon,full,1,,,,5,M1,F3,,,G1,L1,,,,,,F=F3,0
S00485,2_deviation,AN13,followon,full,1,,,,5,M1,F4,,,G1,L1,,,,,,F=F4,0
S00486,2_deviation,AN13,followon,full,1,,,,5,M1,F1,,,G2,L1,,,,,,G=G2,0
S00487,2_deviation,AN13,followon,full,1,,,,5,M1,F1,,,G1,L2,,,,,,L=L2,0
S00488,2_deviation,AN13,followon,full,,,,P0814,5,M2,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00489,2_deviation,AN13,followon,full,,,,P0814,5,M2,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00490,2_deviation,AN13,followon,full,,,,P0814,5,M2,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00491,2_deviation,AN13,followon,full,,,,P0814,5,M2,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00492,2_deviation,AN13,followon,full,,,,P0814,5,M2,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00493,2_deviation,AN13,followon,full,,,,P0814,5,M2,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00494,2_deviation,AN13,followon,full,,,,P0814,5,M2,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00495,2_deviation,AN13,followon,full,,,,P0814,5,M2,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00496,2_deviation,AN13,followon,full,1,,,,6,M1,F2,,,G1,L1,,,,,,F=F2,0
S00497,2_deviation,AN13,followon,full,1,,,,6,M1,F3,,,G1,L1,,,,,,F=F3,0
S00498,2_deviation,AN13,followon,full,1,,,,6,M1,F4,,,G1,L1,,,,,,F=F4,0
S00499,2_deviation,AN13,followon,full,1,,,,6,M1,F1,,,G2,L1,,,,,,G=G2,0
S00500,2_deviation,AN13,followon,full,1,,,,6,M1,F1,,,G1,L2,,,,,,L=L2,0
S00501,2_deviation,AN13,followon,full,,,,P0814,6,M2,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00502,2_deviation,AN13,followon,full,,,,P0814,6,M2,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00503,2_deviation,AN13,followon,full,,,,P0814,6,M2,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00504,2_deviation,AN13,followon,full,,,,P0814,6,M2,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00505,2_deviation,AN13,followon,full,,,,P0814,6,M2,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00506,2_deviation,AN13,followon,full,,,,P0814,6,M2,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00507,2_deviation,AN13,followon,full,,,,P0814,6,M2,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00508,2_deviation,AN13,followon,full,,,,P0814,6,M2,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00509,2_deviation,AN13,followon,full,1,,,,7,M1,F2,,,G1,L1,,,,,,F=F2,0
S00510,2_deviation,AN13,followon,full,1,,,,7,M1,F3,,,G1,L1,,,,,,F=F3,0
S00511,2_deviation,AN13,followon,full,1,,,,7,M1,F4,,,G1,L1,,,,,,F=F4,0
S00512,2_deviation,AN13,followon,full,1,,,,7,M1,F1,,,G2,L1,,,,,,G=G2,0
S00513,2_deviation,AN13,followon,full,1,,,,7,M1,F1,,,G1,L2,,,,,,L=L2,0
S00514,2_deviation,AN13,followon,full,,,,P0814,7,M2,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00515,2_deviation,AN13,followon,full,,,,P0814,7,M2,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00516,2_deviation,AN13,followon,full,,,,P0814,7,M2,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00517,2_deviation,AN13,followon,full,,,,P0814,7,M2,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00518,2_deviation,AN13,followon,full,,,,P0814,7,M2,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00519,2_deviation,AN13,followon,full,,,,P0814,7,M2,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00520,2_deviation,AN13,followon,full,,,,P0814,7,M2,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00521,2_deviation,AN13,followon,full,,,,P0814,7,M2,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00522,2_deviation,AN13,followon,full,1,,,,8,M1,F2,,,G1,L1,,,,,,F=F2,0
S00523,2_deviation,AN13,followon,full,1,,,,8,M1,F3,,,G1,L1,,,,,,F=F3,0
S00524,2_deviation,AN13,followon,full,1,,,,8,M1,F4,,,G1,L1,,,,,,F=F4,0
S00525,2_deviation,AN13,followon,full,1,,,,8,M1,F1,,,G2,L1,,,,,,G=G2,0
S00526,2_deviation,AN13,followon,full,1,,,,8,M1,F1,,,G1,L2,,,,,,L=L2,0
S00527,2_deviation,AN13,followon,full,,,,P0814,8,M2,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00528,2_deviation,AN13,followon,full,,,,P0814,8,M2,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00529,2_deviation,AN13,followon,full,,,,P0814,8,M2,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00530,2_deviation,AN13,followon,full,,,,P0814,8,M2,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00531,2_deviation,AN13,followon,full,,,,P0814,8,M2,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00532,2_deviation,AN13,followon,full,,,,P0814,8,M2,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00533,2_deviation,AN13,followon,full,,,,P0814,8,M2,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00534,2_deviation,AN13,followon,full,,,,P0814,8,M2,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00535,2_deviation,AN13,followon,full,1,,,,9,M1,F2,,,G1,L1,,,,,,F=F2,0
S00536,2_deviation,AN13,followon,full,1,,,,9,M1,F3,,,G1,L1,,,,,,F=F3,0
S00537,2_deviation,AN13,followon,full,1,,,,9,M1,F4,,,G1,L1,,,,,,F=F4,0
S00538,2_deviation,AN13,followon,full,1,,,,9,M1,F1,,,G2,L1,,,,,,G=G2,0
S00539,2_deviation,AN13,followon,full,1,,,,9,M1,F1,,,G1,L2,,,,,,L=L2,0
S00540,2_deviation,AN13,followon,full,,,,P0814,9,M2,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00541,2_deviation,AN13,followon,full,,,,P0814,9,M2,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00542,2_deviation,AN13,followon,full,,,,P0814,9,M2,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00543,2_deviation,AN13,followon,full,,,,P0814,9,M2,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00544,2_deviation,AN13,followon,full,,,,P0814,9,M2,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00545,2_deviation,AN13,followon,full,,,,P0814,9,M2,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00546,2_deviation,AN13,followon,full,,,,P0814,9,M2,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00547,2_deviation,AN13,followon,full,,,,P0814,9,M2,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00548,2_deviation,AN13,followon,full,1,,,,10,M1,F2,,,G1,L1,,,,,,F=F2,0
S00549,2_deviation,AN13,followon,full,1,,,,10,M1,F3,,,G1,L1,,,,,,F=F3,0
S00550,2_deviation,AN13,followon,full,1,,,,10,M1,F4,,,G1,L1,,,,,,F=F4,0
S00551,2_deviation,AN13,followon,full,1,,,,10,M1,F1,,,G2,L1,,,,,,G=G2,0
S00552,2_deviation,AN13,followon,full,1,,,,10,M1,F1,,,G1,L2,,,,,,L=L2,0
S00553,2_deviation,AN13,followon,full,,,,P0814,10,M2,F2,,,G1,L1,Y1,Q1,,,,F=F2,0
S00554,2_deviation,AN13,followon,full,,,,P0814,10,M2,F3,,,G1,L1,Y1,Q1,,,,F=F3,0
S00555,2_deviation,AN13,followon,full,,,,P0814,10,M2,F4,,,G1,L1,Y1,Q1,,,,F=F4,0
S00556,2_deviation,AN13,followon,full,,,,P0814,10,M2,F1,,,G2,L1,Y1,Q1,,,,G=G2,0
S00557,2_deviation,AN13,followon,full,,,,P0814,10,M2,F1,,,G1,L2,Y1,Q1,,,,L=L2,0
S00558,2_deviation,AN13,followon,full,,,,P0814,10,M2,F1,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00559,2_deviation,AN13,followon,full,,,,P0814,10,M2,F1,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00560,2_deviation,AN13,followon,full,,,,P0814,10,M2,F1,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00561,2_deviation,AN13,contributors,full,1,,,,1,M1,,,,G2,L1,,,,,,G=G2,0
S00562,2_deviation,AN13,contributors,full,1,,,,1,M1,,,,G1,L2,,,,,,L=L2,0
S00563,2_deviation,AN13,contributors,full,,,,P0814,1,M2,,,,G2,L1,Y1,Q1,,,,G=G2,0
S00564,2_deviation,AN13,contributors,full,,,,P0814,1,M2,,,,G1,L2,Y1,Q1,,,,L=L2,0
S00565,2_deviation,AN13,contributors,full,,,,P0814,1,M2,,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00566,2_deviation,AN13,contributors,full,,,,P0814,1,M2,,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00567,2_deviation,AN13,contributors,full,,,,P0814,1,M2,,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00568,2_deviation,AN13,contributors,full,1,,,,2,M1,,,,G2,L1,,,,,,G=G2,0
S00569,2_deviation,AN13,contributors,full,1,,,,2,M1,,,,G1,L2,,,,,,L=L2,0
S00570,2_deviation,AN13,contributors,full,,,,P0814,2,M2,,,,G2,L1,Y1,Q1,,,,G=G2,0
S00571,2_deviation,AN13,contributors,full,,,,P0814,2,M2,,,,G1,L2,Y1,Q1,,,,L=L2,0
S00572,2_deviation,AN13,contributors,full,,,,P0814,2,M2,,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00573,2_deviation,AN13,contributors,full,,,,P0814,2,M2,,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00574,2_deviation,AN13,contributors,full,,,,P0814,2,M2,,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00575,2_deviation,AN13,contributors,full,1,,,,3,M1,,,,G2,L1,,,,,,G=G2,0
S00576,2_deviation,AN13,contributors,full,1,,,,3,M1,,,,G1,L2,,,,,,L=L2,0
S00577,2_deviation,AN13,contributors,full,,,,P0814,3,M2,,,,G2,L1,Y1,Q1,,,,G=G2,0
S00578,2_deviation,AN13,contributors,full,,,,P0814,3,M2,,,,G1,L2,Y1,Q1,,,,L=L2,0
S00579,2_deviation,AN13,contributors,full,,,,P0814,3,M2,,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00580,2_deviation,AN13,contributors,full,,,,P0814,3,M2,,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00581,2_deviation,AN13,contributors,full,,,,P0814,3,M2,,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00582,2_deviation,AN13,contributors,full,1,,,,4,M1,,,,G2,L1,,,,,,G=G2,0
S00583,2_deviation,AN13,contributors,full,1,,,,4,M1,,,,G1,L2,,,,,,L=L2,0
S00584,2_deviation,AN13,contributors,full,,,,P0814,4,M2,,,,G2,L1,Y1,Q1,,,,G=G2,0
S00585,2_deviation,AN13,contributors,full,,,,P0814,4,M2,,,,G1,L2,Y1,Q1,,,,L=L2,0
S00586,2_deviation,AN13,contributors,full,,,,P0814,4,M2,,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00587,2_deviation,AN13,contributors,full,,,,P0814,4,M2,,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00588,2_deviation,AN13,contributors,full,,,,P0814,4,M2,,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00589,2_deviation,AN13,contributors,full,1,,,,5,M1,,,,G2,L1,,,,,,G=G2,0
S00590,2_deviation,AN13,contributors,full,1,,,,5,M1,,,,G1,L2,,,,,,L=L2,0
S00591,2_deviation,AN13,contributors,full,,,,P0814,5,M2,,,,G2,L1,Y1,Q1,,,,G=G2,0
S00592,2_deviation,AN13,contributors,full,,,,P0814,5,M2,,,,G1,L2,Y1,Q1,,,,L=L2,0
S00593,2_deviation,AN13,contributors,full,,,,P0814,5,M2,,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00594,2_deviation,AN13,contributors,full,,,,P0814,5,M2,,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00595,2_deviation,AN13,contributors,full,,,,P0814,5,M2,,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00596,2_deviation,AN13,contributors,full,1,,,,6,M1,,,,G2,L1,,,,,,G=G2,0
S00597,2_deviation,AN13,contributors,full,1,,,,6,M1,,,,G1,L2,,,,,,L=L2,0
S00598,2_deviation,AN13,contributors,full,,,,P0814,6,M2,,,,G2,L1,Y1,Q1,,,,G=G2,0
S00599,2_deviation,AN13,contributors,full,,,,P0814,6,M2,,,,G1,L2,Y1,Q1,,,,L=L2,0
S00600,2_deviation,AN13,contributors,full,,,,P0814,6,M2,,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00601,2_deviation,AN13,contributors,full,,,,P0814,6,M2,,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00602,2_deviation,AN13,contributors,full,,,,P0814,6,M2,,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00603,2_deviation,AN13,contributors,full,1,,,,7,M1,,,,G2,L1,,,,,,G=G2,0
S00604,2_deviation,AN13,contributors,full,1,,,,7,M1,,,,G1,L2,,,,,,L=L2,0
S00605,2_deviation,AN13,contributors,full,,,,P0814,7,M2,,,,G2,L1,Y1,Q1,,,,G=G2,0
S00606,2_deviation,AN13,contributors,full,,,,P0814,7,M2,,,,G1,L2,Y1,Q1,,,,L=L2,0
S00607,2_deviation,AN13,contributors,full,,,,P0814,7,M2,,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00608,2_deviation,AN13,contributors,full,,,,P0814,7,M2,,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00609,2_deviation,AN13,contributors,full,,,,P0814,7,M2,,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00610,2_deviation,AN13,contributors,full,1,,,,8,M1,,,,G2,L1,,,,,,G=G2,0
S00611,2_deviation,AN13,contributors,full,1,,,,8,M1,,,,G1,L2,,,,,,L=L2,0
S00612,2_deviation,AN13,contributors,full,,,,P0814,8,M2,,,,G2,L1,Y1,Q1,,,,G=G2,0
S00613,2_deviation,AN13,contributors,full,,,,P0814,8,M2,,,,G1,L2,Y1,Q1,,,,L=L2,0
S00614,2_deviation,AN13,contributors,full,,,,P0814,8,M2,,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00615,2_deviation,AN13,contributors,full,,,,P0814,8,M2,,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00616,2_deviation,AN13,contributors,full,,,,P0814,8,M2,,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00617,2_deviation,AN13,contributors,full,1,,,,9,M1,,,,G2,L1,,,,,,G=G2,0
S00618,2_deviation,AN13,contributors,full,1,,,,9,M1,,,,G1,L2,,,,,,L=L2,0
S00619,2_deviation,AN13,contributors,full,,,,P0814,9,M2,,,,G2,L1,Y1,Q1,,,,G=G2,0
S00620,2_deviation,AN13,contributors,full,,,,P0814,9,M2,,,,G1,L2,Y1,Q1,,,,L=L2,0
S00621,2_deviation,AN13,contributors,full,,,,P0814,9,M2,,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00622,2_deviation,AN13,contributors,full,,,,P0814,9,M2,,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00623,2_deviation,AN13,contributors,full,,,,P0814,9,M2,,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00624,2_deviation,AN13,contributors,full,1,,,,10,M1,,,,G2,L1,,,,,,G=G2,0
S00625,2_deviation,AN13,contributors,full,1,,,,10,M1,,,,G1,L2,,,,,,L=L2,0
S00626,2_deviation,AN13,contributors,full,,,,P0814,10,M2,,,,G2,L1,Y1,Q1,,,,G=G2,0
S00627,2_deviation,AN13,contributors,full,,,,P0814,10,M2,,,,G1,L2,Y1,Q1,,,,L=L2,0
S00628,2_deviation,AN13,contributors,full,,,,P0814,10,M2,,,,G1,L1,Y2,Q1,,,,Y=Y2,0
S00629,2_deviation,AN13,contributors,full,,,,P0814,10,M2,,,,G1,L1,Y3,Q1,,,,Y=Y3,0
S00630,2_deviation,AN13,contributors,full,,,,P0814,10,M2,,,,G1,L1,Y1,Q2,,,,Q=Q2,0
S00631,2_deviation,AN14,pct10,full,1,,,,,,,,,G2,L1,,,,,,G=G2,0
S00632,2_deviation,AN14,pct10,full,1,,,,,,,,,G1,L2,,,,,,L=L2,0
S00633,2_deviation,AN14,pct25,full,1,,,,,,,,,G2,L1,,,,,,G=G2,0
S00634,2_deviation,AN14,pct25,full,1,,,,,,,,,G1,L2,,,,,,L=L2,0
S00635,2_deviation,AN14,pct50,full,1,,,,,,,,,G2,L1,,,,,,G=G2,0
S00636,2_deviation,AN14,pct50,full,1,,,,,,,,,G1,L2,,,,,,L=L2,0
S00637,2_deviation,AN14,pct75,full,1,,,,,,,,,G2,L1,,,,,,G=G2,0
S00638,2_deviation,AN14,pct75,full,1,,,,,,,,,G1,L2,,,,,,L=L2,0
S00639,2_deviation,AN14,pct90,full,1,,,,,,,,,G2,L1,,,,,,G=G2,0
S00640,2_deviation,AN14,pct90,full,1,,,,,,,,,G1,L2,,,,,,L=L2,0
S00641,2_deviation,AN14,pct99,full,1,,,,,,,,,G2,L1,,,,,,G=G2,0
S00642,2_deviation,AN14,pct99,full,1,,,,,,,,,G1,L2,,,,,,L=L2,0
S00643,3_crossing,AN03,followon,full,0,,,,,,F2,,,G2,,,,,,,F=F2;G=G2,1
S00644,3_crossing,AN03,followon,full,0,,,,,,F3,,,G2,,,,,,,F=F3;G=G2,1
S00645,3_crossing,AN03,followon,full,0,,,,,,F4,,,G2,,,,,,,F=F4;G=G2,1
S00646,3_crossing,AN03,followon,full,1,,,,,,F1,,,G2,L2,,,,,,G=G2;L=L2,1
S00647,3_crossing,AN03,followon,full,1,,,,,,F2,,,G1,L2,,,,,,F=F2;L=L2,1
S00648,3_crossing,AN03,followon,full,1,,,,,,F2,,,G2,L1,,,,,,F=F2;G=G2,1
S00649,3_crossing,AN03,followon,full,1,,,,,,F2,,,G2,L2,,,,,,F=F2;G=G2;L=L2,1
S00650,3_crossing,AN03,followon,full,1,,,,,,F3,,,G1,L2,,,,,,F=F3;L=L2,1
S00651,3_crossing,AN03,followon,full,1,,,,,,F3,,,G2,L1,,,,,,F=F3;G=G2,1
S00652,3_crossing,AN03,followon,full,1,,,,,,F3,,,G2,L2,,,,,,F=F3;G=G2;L=L2,1
S00653,3_crossing,AN03,followon,full,1,,,,,,F4,,,G1,L2,,,,,,F=F4;L=L2,1
S00654,3_crossing,AN03,followon,full,1,,,,,,F4,,,G2,L1,,,,,,F=F4;G=G2,1
S00655,3_crossing,AN03,followon,full,1,,,,,,F4,,,G2,L2,,,,,,F=F4;G=G2;L=L2,1
S00656,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G1,L1,Y2,Q2,,,,Y=Y2;Q=Q2,1
S00657,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G1,L1,Y3,Q2,,,,Y=Y3;Q=Q2,1
S00658,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G1,L2,Y1,Q2,,,,L=L2;Q=Q2,1
S00659,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G1,L2,Y2,Q1,,,,L=L2;Y=Y2,1
S00660,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G1,L2,Y2,Q2,,,,L=L2;Y=Y2;Q=Q2,1
S00661,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G1,L2,Y3,Q1,,,,L=L2;Y=Y3,1
S00662,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G1,L2,Y3,Q2,,,,L=L2;Y=Y3;Q=Q2,1
S00663,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G2,L1,Y1,Q2,,,,G=G2;Q=Q2,1
S00664,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G2,L1,Y2,Q1,,,,G=G2;Y=Y2,1
S00665,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G2,L1,Y2,Q2,,,,G=G2;Y=Y2;Q=Q2,1
S00666,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G2,L1,Y3,Q1,,,,G=G2;Y=Y3,1
S00667,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G2,L1,Y3,Q2,,,,G=G2;Y=Y3;Q=Q2,1
S00668,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G2,L2,Y1,Q1,,,,G=G2;L=L2,1
S00669,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G2,L2,Y1,Q2,,,,G=G2;L=L2;Q=Q2,1
S00670,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G2,L2,Y2,Q1,,,,G=G2;L=L2;Y=Y2,1
S00671,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G2,L2,Y2,Q2,,,,G=G2;L=L2;Y=Y2;Q=Q2,1
S00672,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G2,L2,Y3,Q1,,,,G=G2;L=L2;Y=Y3,1
S00673,3_crossing,AN04,followon,full,,,,P0814,,,F1,,,G2,L2,Y3,Q2,,,,G=G2;L=L2;Y=Y3;Q=Q2,1
S00674,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G1,L1,Y1,Q2,,,,F=F2;Q=Q2,1
S00675,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G1,L1,Y2,Q1,,,,F=F2;Y=Y2,1
S00676,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G1,L1,Y2,Q2,,,,F=F2;Y=Y2;Q=Q2,1
S00677,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G1,L1,Y3,Q1,,,,F=F2;Y=Y3,1
S00678,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G1,L1,Y3,Q2,,,,F=F2;Y=Y3;Q=Q2,1
S00679,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G1,L2,Y1,Q1,,,,F=F2;L=L2,1
S00680,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G1,L2,Y1,Q2,,,,F=F2;L=L2;Q=Q2,1
S00681,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G1,L2,Y2,Q1,,,,F=F2;L=L2;Y=Y2,1
S00682,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G1,L2,Y2,Q2,,,,F=F2;L=L2;Y=Y2;Q=Q2,1
S00683,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G1,L2,Y3,Q1,,,,F=F2;L=L2;Y=Y3,1
S00684,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G1,L2,Y3,Q2,,,,F=F2;L=L2;Y=Y3;Q=Q2,1
S00685,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G2,L1,Y1,Q1,,,,F=F2;G=G2,1
S00686,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G2,L1,Y1,Q2,,,,F=F2;G=G2;Q=Q2,1
S00687,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G2,L1,Y2,Q1,,,,F=F2;G=G2;Y=Y2,1
S00688,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G2,L1,Y2,Q2,,,,F=F2;G=G2;Y=Y2;Q=Q2,1
S00689,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G2,L1,Y3,Q1,,,,F=F2;G=G2;Y=Y3,1
S00690,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G2,L1,Y3,Q2,,,,F=F2;G=G2;Y=Y3;Q=Q2,1
S00691,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G2,L2,Y1,Q1,,,,F=F2;G=G2;L=L2,1
S00692,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G2,L2,Y1,Q2,,,,F=F2;G=G2;L=L2;Q=Q2,1
S00693,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G2,L2,Y2,Q1,,,,F=F2;G=G2;L=L2;Y=Y2,1
S00694,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G2,L2,Y2,Q2,,,,F=F2;G=G2;L=L2;Y=Y2;Q=Q2,1
S00695,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G2,L2,Y3,Q1,,,,F=F2;G=G2;L=L2;Y=Y3,1
S00696,3_crossing,AN04,followon,full,,,,P0814,,,F2,,,G2,L2,Y3,Q2,,,,F=F2;G=G2;L=L2;Y=Y3;Q=Q2,1
S00697,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G1,L1,Y1,Q2,,,,F=F3;Q=Q2,1
S00698,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G1,L1,Y2,Q1,,,,F=F3;Y=Y2,1
S00699,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G1,L1,Y2,Q2,,,,F=F3;Y=Y2;Q=Q2,1
S00700,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G1,L1,Y3,Q1,,,,F=F3;Y=Y3,1
S00701,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G1,L1,Y3,Q2,,,,F=F3;Y=Y3;Q=Q2,1
S00702,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G1,L2,Y1,Q1,,,,F=F3;L=L2,1
S00703,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G1,L2,Y1,Q2,,,,F=F3;L=L2;Q=Q2,1
S00704,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G1,L2,Y2,Q1,,,,F=F3;L=L2;Y=Y2,1
S00705,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G1,L2,Y2,Q2,,,,F=F3;L=L2;Y=Y2;Q=Q2,1
S00706,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G1,L2,Y3,Q1,,,,F=F3;L=L2;Y=Y3,1
S00707,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G1,L2,Y3,Q2,,,,F=F3;L=L2;Y=Y3;Q=Q2,1
S00708,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G2,L1,Y1,Q1,,,,F=F3;G=G2,1
S00709,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G2,L1,Y1,Q2,,,,F=F3;G=G2;Q=Q2,1
S00710,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G2,L1,Y2,Q1,,,,F=F3;G=G2;Y=Y2,1
S00711,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G2,L1,Y2,Q2,,,,F=F3;G=G2;Y=Y2;Q=Q2,1
S00712,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G2,L1,Y3,Q1,,,,F=F3;G=G2;Y=Y3,1
S00713,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G2,L1,Y3,Q2,,,,F=F3;G=G2;Y=Y3;Q=Q2,1
S00714,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G2,L2,Y1,Q1,,,,F=F3;G=G2;L=L2,1
S00715,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G2,L2,Y1,Q2,,,,F=F3;G=G2;L=L2;Q=Q2,1
S00716,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G2,L2,Y2,Q1,,,,F=F3;G=G2;L=L2;Y=Y2,1
S00717,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G2,L2,Y2,Q2,,,,F=F3;G=G2;L=L2;Y=Y2;Q=Q2,1
S00718,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G2,L2,Y3,Q1,,,,F=F3;G=G2;L=L2;Y=Y3,1
S00719,3_crossing,AN04,followon,full,,,,P0814,,,F3,,,G2,L2,Y3,Q2,,,,F=F3;G=G2;L=L2;Y=Y3;Q=Q2,1
S00720,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G1,L1,Y1,Q2,,,,F=F4;Q=Q2,1
S00721,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G1,L1,Y2,Q1,,,,F=F4;Y=Y2,1
S00722,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G1,L1,Y2,Q2,,,,F=F4;Y=Y2;Q=Q2,1
S00723,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G1,L1,Y3,Q1,,,,F=F4;Y=Y3,1
S00724,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G1,L1,Y3,Q2,,,,F=F4;Y=Y3;Q=Q2,1
S00725,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G1,L2,Y1,Q1,,,,F=F4;L=L2,1
S00726,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G1,L2,Y1,Q2,,,,F=F4;L=L2;Q=Q2,1
S00727,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G1,L2,Y2,Q1,,,,F=F4;L=L2;Y=Y2,1
S00728,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G1,L2,Y2,Q2,,,,F=F4;L=L2;Y=Y2;Q=Q2,1
S00729,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G1,L2,Y3,Q1,,,,F=F4;L=L2;Y=Y3,1
S00730,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G1,L2,Y3,Q2,,,,F=F4;L=L2;Y=Y3;Q=Q2,1
S00731,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G2,L1,Y1,Q1,,,,F=F4;G=G2,1
S00732,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G2,L1,Y1,Q2,,,,F=F4;G=G2;Q=Q2,1
S00733,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G2,L1,Y2,Q1,,,,F=F4;G=G2;Y=Y2,1
S00734,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G2,L1,Y2,Q2,,,,F=F4;G=G2;Y=Y2;Q=Q2,1
S00735,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G2,L1,Y3,Q1,,,,F=F4;G=G2;Y=Y3,1
S00736,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G2,L1,Y3,Q2,,,,F=F4;G=G2;Y=Y3;Q=Q2,1
S00737,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G2,L2,Y1,Q1,,,,F=F4;G=G2;L=L2,1
S00738,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G2,L2,Y1,Q2,,,,F=F4;G=G2;L=L2;Q=Q2,1
S00739,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G2,L2,Y2,Q1,,,,F=F4;G=G2;L=L2;Y=Y2,1
S00740,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G2,L2,Y2,Q2,,,,F=F4;G=G2;L=L2;Y=Y2;Q=Q2,1
S00741,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G2,L2,Y3,Q1,,,,F=F4;G=G2;L=L2;Y=Y3,1
S00742,3_crossing,AN04,followon,full,,,,P0814,,,F4,,,G2,L2,Y3,Q2,,,,F=F4;G=G2;L=L2;Y=Y3;Q=Q2,1
S00743,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G1,L1,Y2,Q2,,,,Y=Y2;Q=Q2,1
S00744,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G1,L1,Y3,Q2,,,,Y=Y3;Q=Q2,1
S00745,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G1,L2,Y1,Q2,,,,L=L2;Q=Q2,1
S00746,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G1,L2,Y2,Q1,,,,L=L2;Y=Y2,1
S00747,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G1,L2,Y2,Q2,,,,L=L2;Y=Y2;Q=Q2,1
S00748,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G1,L2,Y3,Q1,,,,L=L2;Y=Y3,1
S00749,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G1,L2,Y3,Q2,,,,L=L2;Y=Y3;Q=Q2,1
S00750,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G2,L1,Y1,Q2,,,,G=G2;Q=Q2,1
S00751,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G2,L1,Y2,Q1,,,,G=G2;Y=Y2,1
S00752,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G2,L1,Y2,Q2,,,,G=G2;Y=Y2;Q=Q2,1
S00753,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G2,L1,Y3,Q1,,,,G=G2;Y=Y3,1
S00754,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G2,L1,Y3,Q2,,,,G=G2;Y=Y3;Q=Q2,1
S00755,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G2,L2,Y1,Q1,,,,G=G2;L=L2,1
S00756,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G2,L2,Y1,Q2,,,,G=G2;L=L2;Q=Q2,1
S00757,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G2,L2,Y2,Q1,,,,G=G2;L=L2;Y=Y2,1
S00758,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G2,L2,Y2,Q2,,,,G=G2;L=L2;Y=Y2;Q=Q2,1
S00759,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G2,L2,Y3,Q1,,,,G=G2;L=L2;Y=Y3,1
S00760,3_crossing,AN04,followon,full,,,,P14,,,F1,,,G2,L2,Y3,Q2,,,,G=G2;L=L2;Y=Y3;Q=Q2,1
S00761,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G1,L1,Y1,Q2,,,,F=F2;Q=Q2,1
S00762,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G1,L1,Y2,Q1,,,,F=F2;Y=Y2,1
S00763,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G1,L1,Y2,Q2,,,,F=F2;Y=Y2;Q=Q2,1
S00764,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G1,L1,Y3,Q1,,,,F=F2;Y=Y3,1
S00765,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G1,L1,Y3,Q2,,,,F=F2;Y=Y3;Q=Q2,1
S00766,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G1,L2,Y1,Q1,,,,F=F2;L=L2,1
S00767,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G1,L2,Y1,Q2,,,,F=F2;L=L2;Q=Q2,1
S00768,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G1,L2,Y2,Q1,,,,F=F2;L=L2;Y=Y2,1
S00769,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G1,L2,Y2,Q2,,,,F=F2;L=L2;Y=Y2;Q=Q2,1
S00770,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G1,L2,Y3,Q1,,,,F=F2;L=L2;Y=Y3,1
S00771,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G1,L2,Y3,Q2,,,,F=F2;L=L2;Y=Y3;Q=Q2,1
S00772,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G2,L1,Y1,Q1,,,,F=F2;G=G2,1
S00773,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G2,L1,Y1,Q2,,,,F=F2;G=G2;Q=Q2,1
S00774,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G2,L1,Y2,Q1,,,,F=F2;G=G2;Y=Y2,1
S00775,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G2,L1,Y2,Q2,,,,F=F2;G=G2;Y=Y2;Q=Q2,1
S00776,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G2,L1,Y3,Q1,,,,F=F2;G=G2;Y=Y3,1
S00777,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G2,L1,Y3,Q2,,,,F=F2;G=G2;Y=Y3;Q=Q2,1
S00778,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G2,L2,Y1,Q1,,,,F=F2;G=G2;L=L2,1
S00779,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G2,L2,Y1,Q2,,,,F=F2;G=G2;L=L2;Q=Q2,1
S00780,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G2,L2,Y2,Q1,,,,F=F2;G=G2;L=L2;Y=Y2,1
S00781,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G2,L2,Y2,Q2,,,,F=F2;G=G2;L=L2;Y=Y2;Q=Q2,1
S00782,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G2,L2,Y3,Q1,,,,F=F2;G=G2;L=L2;Y=Y3,1
S00783,3_crossing,AN04,followon,full,,,,P14,,,F2,,,G2,L2,Y3,Q2,,,,F=F2;G=G2;L=L2;Y=Y3;Q=Q2,1
S00784,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G1,L1,Y1,Q2,,,,F=F3;Q=Q2,1
S00785,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G1,L1,Y2,Q1,,,,F=F3;Y=Y2,1
S00786,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G1,L1,Y2,Q2,,,,F=F3;Y=Y2;Q=Q2,1
S00787,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G1,L1,Y3,Q1,,,,F=F3;Y=Y3,1
S00788,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G1,L1,Y3,Q2,,,,F=F3;Y=Y3;Q=Q2,1
S00789,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G1,L2,Y1,Q1,,,,F=F3;L=L2,1
S00790,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G1,L2,Y1,Q2,,,,F=F3;L=L2;Q=Q2,1
S00791,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G1,L2,Y2,Q1,,,,F=F3;L=L2;Y=Y2,1
S00792,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G1,L2,Y2,Q2,,,,F=F3;L=L2;Y=Y2;Q=Q2,1
S00793,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G1,L2,Y3,Q1,,,,F=F3;L=L2;Y=Y3,1
S00794,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G1,L2,Y3,Q2,,,,F=F3;L=L2;Y=Y3;Q=Q2,1
S00795,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G2,L1,Y1,Q1,,,,F=F3;G=G2,1
S00796,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G2,L1,Y1,Q2,,,,F=F3;G=G2;Q=Q2,1
S00797,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G2,L1,Y2,Q1,,,,F=F3;G=G2;Y=Y2,1
S00798,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G2,L1,Y2,Q2,,,,F=F3;G=G2;Y=Y2;Q=Q2,1
S00799,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G2,L1,Y3,Q1,,,,F=F3;G=G2;Y=Y3,1
S00800,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G2,L1,Y3,Q2,,,,F=F3;G=G2;Y=Y3;Q=Q2,1
S00801,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G2,L2,Y1,Q1,,,,F=F3;G=G2;L=L2,1
S00802,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G2,L2,Y1,Q2,,,,F=F3;G=G2;L=L2;Q=Q2,1
S00803,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G2,L2,Y2,Q1,,,,F=F3;G=G2;L=L2;Y=Y2,1
S00804,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G2,L2,Y2,Q2,,,,F=F3;G=G2;L=L2;Y=Y2;Q=Q2,1
S00805,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G2,L2,Y3,Q1,,,,F=F3;G=G2;L=L2;Y=Y3,1
S00806,3_crossing,AN04,followon,full,,,,P14,,,F3,,,G2,L2,Y3,Q2,,,,F=F3;G=G2;L=L2;Y=Y3;Q=Q2,1
S00807,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G1,L1,Y1,Q2,,,,F=F4;Q=Q2,1
S00808,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G1,L1,Y2,Q1,,,,F=F4;Y=Y2,1
S00809,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G1,L1,Y2,Q2,,,,F=F4;Y=Y2;Q=Q2,1
S00810,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G1,L1,Y3,Q1,,,,F=F4;Y=Y3,1
S00811,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G1,L1,Y3,Q2,,,,F=F4;Y=Y3;Q=Q2,1
S00812,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G1,L2,Y1,Q1,,,,F=F4;L=L2,1
S00813,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G1,L2,Y1,Q2,,,,F=F4;L=L2;Q=Q2,1
S00814,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G1,L2,Y2,Q1,,,,F=F4;L=L2;Y=Y2,1
S00815,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G1,L2,Y2,Q2,,,,F=F4;L=L2;Y=Y2;Q=Q2,1
S00816,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G1,L2,Y3,Q1,,,,F=F4;L=L2;Y=Y3,1
S00817,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G1,L2,Y3,Q2,,,,F=F4;L=L2;Y=Y3;Q=Q2,1
S00818,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G2,L1,Y1,Q1,,,,F=F4;G=G2,1
S00819,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G2,L1,Y1,Q2,,,,F=F4;G=G2;Q=Q2,1
S00820,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G2,L1,Y2,Q1,,,,F=F4;G=G2;Y=Y2,1
S00821,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G2,L1,Y2,Q2,,,,F=F4;G=G2;Y=Y2;Q=Q2,1
S00822,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G2,L1,Y3,Q1,,,,F=F4;G=G2;Y=Y3,1
S00823,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G2,L1,Y3,Q2,,,,F=F4;G=G2;Y=Y3;Q=Q2,1
S00824,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G2,L2,Y1,Q1,,,,F=F4;G=G2;L=L2,1
S00825,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G2,L2,Y1,Q2,,,,F=F4;G=G2;L=L2;Q=Q2,1
S00826,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G2,L2,Y2,Q1,,,,F=F4;G=G2;L=L2;Y=Y2,1
S00827,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G2,L2,Y2,Q2,,,,F=F4;G=G2;L=L2;Y=Y2;Q=Q2,1
S00828,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G2,L2,Y3,Q1,,,,F=F4;G=G2;L=L2;Y=Y3,1
S00829,3_crossing,AN04,followon,full,,,,P14,,,F4,,,G2,L2,Y3,Q2,,,,F=F4;G=G2;L=L2;Y=Y3;Q=Q2,1
S00830,3_crossing,AN03,contributors,full,1,,,,,,,,,G2,L2,,,,,,G=G2;L=L2,1
S00831,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G1,L1,Y2,Q2,,,,Y=Y2;Q=Q2,1
S00832,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G1,L1,Y3,Q2,,,,Y=Y3;Q=Q2,1
S00833,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G1,L2,Y1,Q2,,,,L=L2;Q=Q2,1
S00834,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G1,L2,Y2,Q1,,,,L=L2;Y=Y2,1
S00835,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G1,L2,Y2,Q2,,,,L=L2;Y=Y2;Q=Q2,1
S00836,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G1,L2,Y3,Q1,,,,L=L2;Y=Y3,1
S00837,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G1,L2,Y3,Q2,,,,L=L2;Y=Y3;Q=Q2,1
S00838,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G2,L1,Y1,Q2,,,,G=G2;Q=Q2,1
S00839,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G2,L1,Y2,Q1,,,,G=G2;Y=Y2,1
S00840,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G2,L1,Y2,Q2,,,,G=G2;Y=Y2;Q=Q2,1
S00841,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G2,L1,Y3,Q1,,,,G=G2;Y=Y3,1
S00842,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G2,L1,Y3,Q2,,,,G=G2;Y=Y3;Q=Q2,1
S00843,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G2,L2,Y1,Q1,,,,G=G2;L=L2,1
S00844,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G2,L2,Y1,Q2,,,,G=G2;L=L2;Q=Q2,1
S00845,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G2,L2,Y2,Q1,,,,G=G2;L=L2;Y=Y2,1
S00846,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G2,L2,Y2,Q2,,,,G=G2;L=L2;Y=Y2;Q=Q2,1
S00847,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G2,L2,Y3,Q1,,,,G=G2;L=L2;Y=Y3,1
S00848,3_crossing,AN04,contributors,full,,,,P0814,,,,,,G2,L2,Y3,Q2,,,,G=G2;L=L2;Y=Y3;Q=Q2,1
S00849,3_crossing,AN04,contributors,full,,,,P14,,,,,,G1,L1,Y2,Q2,,,,Y=Y2;Q=Q2,1
S00850,3_crossing,AN04,contributors,full,,,,P14,,,,,,G1,L1,Y3,Q2,,,,Y=Y3;Q=Q2,1
S00851,3_crossing,AN04,contributors,full,,,,P14,,,,,,G1,L2,Y1,Q2,,,,L=L2;Q=Q2,1
S00852,3_crossing,AN04,contributors,full,,,,P14,,,,,,G1,L2,Y2,Q1,,,,L=L2;Y=Y2,1
S00853,3_crossing,AN04,contributors,full,,,,P14,,,,,,G1,L2,Y2,Q2,,,,L=L2;Y=Y2;Q=Q2,1
S00854,3_crossing,AN04,contributors,full,,,,P14,,,,,,G1,L2,Y3,Q1,,,,L=L2;Y=Y3,1
S00855,3_crossing,AN04,contributors,full,,,,P14,,,,,,G1,L2,Y3,Q2,,,,L=L2;Y=Y3;Q=Q2,1
S00856,3_crossing,AN04,contributors,full,,,,P14,,,,,,G2,L1,Y1,Q2,,,,G=G2;Q=Q2,1
S00857,3_crossing,AN04,contributors,full,,,,P14,,,,,,G2,L1,Y2,Q1,,,,G=G2;Y=Y2,1
S00858,3_crossing,AN04,contributors,full,,,,P14,,,,,,G2,L1,Y2,Q2,,,,G=G2;Y=Y2;Q=Q2,1
S00859,3_crossing,AN04,contributors,full,,,,P14,,,,,,G2,L1,Y3,Q1,,,,G=G2;Y=Y3,1
S00860,3_crossing,AN04,contributors,full,,,,P14,,,,,,G2,L1,Y3,Q2,,,,G=G2;Y=Y3;Q=Q2,1
S00861,3_crossing,AN04,contributors,full,,,,P14,,,,,,G2,L2,Y1,Q1,,,,G=G2;L=L2,1
S00862,3_crossing,AN04,contributors,full,,,,P14,,,,,,G2,L2,Y1,Q2,,,,G=G2;L=L2;Q=Q2,1
S00863,3_crossing,AN04,contributors,full,,,,P14,,,,,,G2,L2,Y2,Q1,,,,G=G2;L=L2;Y=Y2,1
S00864,3_crossing,AN04,contributors,full,,,,P14,,,,,,G2,L2,Y2,Q2,,,,G=G2;L=L2;Y=Y2;Q=Q2,1
S00865,3_crossing,AN04,contributors,full,,,,P14,,,,,,G2,L2,Y3,Q1,,,,G=G2;L=L2;Y=Y3,1
S00866,3_crossing,AN04,contributors,full,,,,P14,,,,,,G2,L2,Y3,Q2,,,,G=G2;L=L2;Y=Y3;Q=Q2,1
S00867,3_crossing,AN07,err,full,,,,,,,,,,,L1,Y1,Q2,,,W3,Q=Q2;W=W3,1
S00868,3_crossing,AN07,err,full,,,,,,,,,,,L1,Y1,Q2,,,W4,Q=Q2;W=W4,1
S00869,3_crossing,AN07,err,full,,,,,,,,,,,L1,Y2,Q1,,,W3,Y=Y2;W=W3,1
S00870,3_crossing,AN07,err,full,,,,,,,,,,,L1,Y2,Q1,,,W4,Y=Y2;W=W4,1
S00871,3_crossing,AN07,err,full,,,,,,,,,,,L1,Y2,Q2,,,W1,Y=Y2;Q=Q2,1
S00872,3_crossing,AN07,err,full,,,,,,,,,,,L1,Y2,Q2,,,W3,Y=Y2;Q=Q2;W=W3,1
S00873,3_crossing,AN07,err,full,,,,,,,,,,,L1,Y2,Q2,,,W4,Y=Y2;Q=Q2;W=W4,1
S00874,3_crossing,AN07,err,full,,,,,,,,,,,L1,Y3,Q1,,,W3,Y=Y3;W=W3,1
S00875,3_crossing,AN07,err,full,,,,,,,,,,,L1,Y3,Q1,,,W4,Y=Y3;W=W4,1
S00876,3_crossing,AN07,err,full,,,,,,,,,,,L1,Y3,Q2,,,W1,Y=Y3;Q=Q2,1
S00877,3_crossing,AN07,err,full,,,,,,,,,,,L1,Y3,Q2,,,W3,Y=Y3;Q=Q2;W=W3,1
S00878,3_crossing,AN07,err,full,,,,,,,,,,,L1,Y3,Q2,,,W4,Y=Y3;Q=Q2;W=W4,1
S00879,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y1,Q1,,,W3,L=L2;W=W3,1
S00880,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y1,Q1,,,W4,L=L2;W=W4,1
S00881,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y1,Q2,,,W1,L=L2;Q=Q2,1
S00882,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y1,Q2,,,W3,L=L2;Q=Q2;W=W3,1
S00883,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y1,Q2,,,W4,L=L2;Q=Q2;W=W4,1
S00884,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y2,Q1,,,W1,L=L2;Y=Y2,1
S00885,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y2,Q1,,,W3,L=L2;Y=Y2;W=W3,1
S00886,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y2,Q1,,,W4,L=L2;Y=Y2;W=W4,1
S00887,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y2,Q2,,,W1,L=L2;Y=Y2;Q=Q2,1
S00888,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y2,Q2,,,W3,L=L2;Y=Y2;Q=Q2;W=W3,1
S00889,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y2,Q2,,,W4,L=L2;Y=Y2;Q=Q2;W=W4,1
S00890,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y3,Q1,,,W1,L=L2;Y=Y3,1
S00891,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y3,Q1,,,W3,L=L2;Y=Y3;W=W3,1
S00892,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y3,Q1,,,W4,L=L2;Y=Y3;W=W4,1
S00893,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y3,Q2,,,W1,L=L2;Y=Y3;Q=Q2,1
S00894,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y3,Q2,,,W3,L=L2;Y=Y3;Q=Q2;W=W3,1
S00895,3_crossing,AN07,err,full,,,,,,,,,,,L2,Y3,Q2,,,W4,L=L2;Y=Y3;Q=Q2;W=W4,1
S00896,4_placebo_dist,AN05,followon,full,1,placebo_perm,1,,,,F1,,,G1,L1,,,,,,,0
S00897,4_placebo_dist,AN05,followon,full,1,placebo_perm,2,,,,F1,,,G1,L1,,,,,,,0
S00898,4_placebo_dist,AN05,followon,full,1,placebo_perm,3,,,,F1,,,G1,L1,,,,,,,0
S00899,4_placebo_dist,AN05,followon,full,1,placebo_perm,4,,,,F1,,,G1,L1,,,,,,,0
S00900,4_placebo_dist,AN05,followon,full,1,placebo_perm,5,,,,F1,,,G1,L1,,,,,,,0
S00901,4_placebo_dist,AN05,followon,full,1,placebo_perm,6,,,,F1,,,G1,L1,,,,,,,0
S00902,4_placebo_dist,AN05,followon,full,1,placebo_perm,7,,,,F1,,,G1,L1,,,,,,,0
S00903,4_placebo_dist,AN05,followon,full,1,placebo_perm,8,,,,F1,,,G1,L1,,,,,,,0
S00904,4_placebo_dist,AN05,followon,full,1,placebo_perm,9,,,,F1,,,G1,L1,,,,,,,0
S00905,4_placebo_dist,AN05,followon,full,1,placebo_perm,10,,,,F1,,,G1,L1,,,,,,,0
S00906,4_placebo_dist,AN05,followon,full,1,placebo_perm,11,,,,F1,,,G1,L1,,,,,,,0
S00907,4_placebo_dist,AN05,followon,full,1,placebo_perm,12,,,,F1,,,G1,L1,,,,,,,0
S00908,4_placebo_dist,AN05,followon,full,1,placebo_perm,13,,,,F1,,,G1,L1,,,,,,,0
S00909,4_placebo_dist,AN05,followon,full,1,placebo_perm,14,,,,F1,,,G1,L1,,,,,,,0
S00910,4_placebo_dist,AN05,followon,full,1,placebo_perm,15,,,,F1,,,G1,L1,,,,,,,0
S00911,4_placebo_dist,AN05,followon,full,1,placebo_perm,16,,,,F1,,,G1,L1,,,,,,,0
S00912,4_placebo_dist,AN05,followon,full,1,placebo_perm,17,,,,F1,,,G1,L1,,,,,,,0
S00913,4_placebo_dist,AN05,followon,full,1,placebo_perm,18,,,,F1,,,G1,L1,,,,,,,0
S00914,4_placebo_dist,AN05,followon,full,1,placebo_perm,19,,,,F1,,,G1,L1,,,,,,,0
S00915,4_placebo_dist,AN05,followon,full,1,placebo_perm,20,,,,F1,,,G1,L1,,,,,,,0
S00916,4_placebo_dist,AN05,followon,full,1,placebo_perm,21,,,,F1,,,G1,L1,,,,,,,0
S00917,4_placebo_dist,AN05,followon,full,1,placebo_perm,22,,,,F1,,,G1,L1,,,,,,,0
S00918,4_placebo_dist,AN05,followon,full,1,placebo_perm,23,,,,F1,,,G1,L1,,,,,,,0
S00919,4_placebo_dist,AN05,followon,full,1,placebo_perm,24,,,,F1,,,G1,L1,,,,,,,0
S00920,4_placebo_dist,AN05,followon,full,1,placebo_perm,25,,,,F1,,,G1,L1,,,,,,,0
S00921,4_placebo_dist,AN05,followon,full,1,placebo_perm,26,,,,F1,,,G1,L1,,,,,,,0
S00922,4_placebo_dist,AN05,followon,full,1,placebo_perm,27,,,,F1,,,G1,L1,,,,,,,0
S00923,4_placebo_dist,AN05,followon,full,1,placebo_perm,28,,,,F1,,,G1,L1,,,,,,,0
S00924,4_placebo_dist,AN05,followon,full,1,placebo_perm,29,,,,F1,,,G1,L1,,,,,,,0
S00925,4_placebo_dist,AN05,followon,full,1,placebo_perm,30,,,,F1,,,G1,L1,,,,,,,0
S00926,4_placebo_dist,AN05,followon,full,1,placebo_perm,31,,,,F1,,,G1,L1,,,,,,,0
S00927,4_placebo_dist,AN05,followon,full,1,placebo_perm,32,,,,F1,,,G1,L1,,,,,,,0
S00928,4_placebo_dist,AN05,followon,full,1,placebo_perm,33,,,,F1,,,G1,L1,,,,,,,0
S00929,4_placebo_dist,AN05,followon,full,1,placebo_perm,34,,,,F1,,,G1,L1,,,,,,,0
S00930,4_placebo_dist,AN05,followon,full,1,placebo_perm,35,,,,F1,,,G1,L1,,,,,,,0
S00931,4_placebo_dist,AN05,followon,full,1,placebo_perm,36,,,,F1,,,G1,L1,,,,,,,0
S00932,4_placebo_dist,AN05,followon,full,1,placebo_perm,37,,,,F1,,,G1,L1,,,,,,,0
S00933,4_placebo_dist,AN05,followon,full,1,placebo_perm,38,,,,F1,,,G1,L1,,,,,,,0
S00934,4_placebo_dist,AN05,followon,full,1,placebo_perm,39,,,,F1,,,G1,L1,,,,,,,0
S00935,4_placebo_dist,AN05,followon,full,1,placebo_perm,40,,,,F1,,,G1,L1,,,,,,,0
S00936,4_placebo_dist,AN05,followon,full,1,placebo_perm,41,,,,F1,,,G1,L1,,,,,,,0
S00937,4_placebo_dist,AN05,followon,full,1,placebo_perm,42,,,,F1,,,G1,L1,,,,,,,0
S00938,4_placebo_dist,AN05,followon,full,1,placebo_perm,43,,,,F1,,,G1,L1,,,,,,,0
S00939,4_placebo_dist,AN05,followon,full,1,placebo_perm,44,,,,F1,,,G1,L1,,,,,,,0
S00940,4_placebo_dist,AN05,followon,full,1,placebo_perm,45,,,,F1,,,G1,L1,,,,,,,0
S00941,4_placebo_dist,AN05,followon,full,1,placebo_perm,46,,,,F1,,,G1,L1,,,,,,,0
S00942,4_placebo_dist,AN05,followon,full,1,placebo_perm,47,,,,F1,,,G1,L1,,,,,,,0
S00943,4_placebo_dist,AN05,followon,full,1,placebo_perm,48,,,,F1,,,G1,L1,,,,,,,0
S00944,4_placebo_dist,AN05,followon,full,1,placebo_perm,49,,,,F1,,,G1,L1,,,,,,,0
S00945,4_placebo_dist,AN05,followon,full,1,placebo_perm,50,,,,F1,,,G1,L1,,,,,,,0
S00946,4_placebo_dist,AN05,followon,full,1,placebo_perm,51,,,,F1,,,G1,L1,,,,,,,0
S00947,4_placebo_dist,AN05,followon,full,1,placebo_perm,52,,,,F1,,,G1,L1,,,,,,,0
S00948,4_placebo_dist,AN05,followon,full,1,placebo_perm,53,,,,F1,,,G1,L1,,,,,,,0
S00949,4_placebo_dist,AN05,followon,full,1,placebo_perm,54,,,,F1,,,G1,L1,,,,,,,0
S00950,4_placebo_dist,AN05,followon,full,1,placebo_perm,55,,,,F1,,,G1,L1,,,,,,,0
S00951,4_placebo_dist,AN05,followon,full,1,placebo_perm,56,,,,F1,,,G1,L1,,,,,,,0
S00952,4_placebo_dist,AN05,followon,full,1,placebo_perm,57,,,,F1,,,G1,L1,,,,,,,0
S00953,4_placebo_dist,AN05,followon,full,1,placebo_perm,58,,,,F1,,,G1,L1,,,,,,,0
S00954,4_placebo_dist,AN05,followon,full,1,placebo_perm,59,,,,F1,,,G1,L1,,,,,,,0
S00955,4_placebo_dist,AN05,followon,full,1,placebo_perm,60,,,,F1,,,G1,L1,,,,,,,0
S00956,4_placebo_dist,AN05,followon,full,1,placebo_perm,61,,,,F1,,,G1,L1,,,,,,,0
S00957,4_placebo_dist,AN05,followon,full,1,placebo_perm,62,,,,F1,,,G1,L1,,,,,,,0
S00958,4_placebo_dist,AN05,followon,full,1,placebo_perm,63,,,,F1,,,G1,L1,,,,,,,0
S00959,4_placebo_dist,AN05,followon,full,1,placebo_perm,64,,,,F1,,,G1,L1,,,,,,,0
S00960,4_placebo_dist,AN05,followon,full,1,placebo_perm,65,,,,F1,,,G1,L1,,,,,,,0
S00961,4_placebo_dist,AN05,followon,full,1,placebo_perm,66,,,,F1,,,G1,L1,,,,,,,0
S00962,4_placebo_dist,AN05,followon,full,1,placebo_perm,67,,,,F1,,,G1,L1,,,,,,,0
S00963,4_placebo_dist,AN05,followon,full,1,placebo_perm,68,,,,F1,,,G1,L1,,,,,,,0
S00964,4_placebo_dist,AN05,followon,full,1,placebo_perm,69,,,,F1,,,G1,L1,,,,,,,0
S00965,4_placebo_dist,AN05,followon,full,1,placebo_perm,70,,,,F1,,,G1,L1,,,,,,,0
S00966,4_placebo_dist,AN05,followon,full,1,placebo_perm,71,,,,F1,,,G1,L1,,,,,,,0
S00967,4_placebo_dist,AN05,followon,full,1,placebo_perm,72,,,,F1,,,G1,L1,,,,,,,0
S00968,4_placebo_dist,AN05,followon,full,1,placebo_perm,73,,,,F1,,,G1,L1,,,,,,,0
S00969,4_placebo_dist,AN05,followon,full,1,placebo_perm,74,,,,F1,,,G1,L1,,,,,,,0
S00970,4_placebo_dist,AN05,followon,full,1,placebo_perm,75,,,,F1,,,G1,L1,,,,,,,0
S00971,4_placebo_dist,AN05,followon,full,1,placebo_perm,76,,,,F1,,,G1,L1,,,,,,,0
S00972,4_placebo_dist,AN05,followon,full,1,placebo_perm,77,,,,F1,,,G1,L1,,,,,,,0
S00973,4_placebo_dist,AN05,followon,full,1,placebo_perm,78,,,,F1,,,G1,L1,,,,,,,0
S00974,4_placebo_dist,AN05,followon,full,1,placebo_perm,79,,,,F1,,,G1,L1,,,,,,,0
S00975,4_placebo_dist,AN05,followon,full,1,placebo_perm,80,,,,F1,,,G1,L1,,,,,,,0
S00976,4_placebo_dist,AN05,followon,full,1,placebo_perm,81,,,,F1,,,G1,L1,,,,,,,0
S00977,4_placebo_dist,AN05,followon,full,1,placebo_perm,82,,,,F1,,,G1,L1,,,,,,,0
S00978,4_placebo_dist,AN05,followon,full,1,placebo_perm,83,,,,F1,,,G1,L1,,,,,,,0
S00979,4_placebo_dist,AN05,followon,full,1,placebo_perm,84,,,,F1,,,G1,L1,,,,,,,0
S00980,4_placebo_dist,AN05,followon,full,1,placebo_perm,85,,,,F1,,,G1,L1,,,,,,,0
S00981,4_placebo_dist,AN05,followon,full,1,placebo_perm,86,,,,F1,,,G1,L1,,,,,,,0
S00982,4_placebo_dist,AN05,followon,full,1,placebo_perm,87,,,,F1,,,G1,L1,,,,,,,0
S00983,4_placebo_dist,AN05,followon,full,1,placebo_perm,88,,,,F1,,,G1,L1,,,,,,,0
S00984,4_placebo_dist,AN05,followon,full,1,placebo_perm,89,,,,F1,,,G1,L1,,,,,,,0
S00985,4_placebo_dist,AN05,followon,full,1,placebo_perm,90,,,,F1,,,G1,L1,,,,,,,0
S00986,4_placebo_dist,AN05,followon,full,1,placebo_perm,91,,,,F1,,,G1,L1,,,,,,,0
S00987,4_placebo_dist,AN05,followon,full,1,placebo_perm,92,,,,F1,,,G1,L1,,,,,,,0
S00988,4_placebo_dist,AN05,followon,full,1,placebo_perm,93,,,,F1,,,G1,L1,,,,,,,0
S00989,4_placebo_dist,AN05,followon,full,1,placebo_perm,94,,,,F1,,,G1,L1,,,,,,,0
S00990,4_placebo_dist,AN05,followon,full,1,placebo_perm,95,,,,F1,,,G1,L1,,,,,,,0
S00991,4_placebo_dist,AN05,followon,full,1,placebo_perm,96,,,,F1,,,G1,L1,,,,,,,0
S00992,4_placebo_dist,AN05,followon,full,1,placebo_perm,97,,,,F1,,,G1,L1,,,,,,,0
S00993,4_placebo_dist,AN05,followon,full,1,placebo_perm,98,,,,F1,,,G1,L1,,,,,,,0
S00994,4_placebo_dist,AN05,followon,full,1,placebo_perm,99,,,,F1,,,G1,L1,,,,,,,0
S00995,4_placebo_dist,AN05,followon,full,1,placebo_perm,100,,,,F1,,,G1,L1,,,,,,,0
S00996,4_placebo_dist,AN05,followon,full,1,placebo_perm,101,,,,F1,,,G1,L1,,,,,,,0
S00997,4_placebo_dist,AN05,followon,full,1,placebo_perm,102,,,,F1,,,G1,L1,,,,,,,0
S00998,4_placebo_dist,AN05,followon,full,1,placebo_perm,103,,,,F1,,,G1,L1,,,,,,,0
S00999,4_placebo_dist,AN05,followon,full,1,placebo_perm,104,,,,F1,,,G1,L1,,,,,,,0
S01000,4_placebo_dist,AN05,followon,full,1,placebo_perm,105,,,,F1,,,G1,L1,,,,,,,0
S01001,4_placebo_dist,AN05,followon,full,1,placebo_perm,106,,,,F1,,,G1,L1,,,,,,,0
S01002,4_placebo_dist,AN05,followon,full,1,placebo_perm,107,,,,F1,,,G1,L1,,,,,,,0
S01003,4_placebo_dist,AN05,followon,full,1,placebo_perm,108,,,,F1,,,G1,L1,,,,,,,0
S01004,4_placebo_dist,AN05,followon,full,1,placebo_perm,109,,,,F1,,,G1,L1,,,,,,,0
S01005,4_placebo_dist,AN05,followon,full,1,placebo_perm,110,,,,F1,,,G1,L1,,,,,,,0
S01006,4_placebo_dist,AN05,followon,full,1,placebo_perm,111,,,,F1,,,G1,L1,,,,,,,0
S01007,4_placebo_dist,AN05,followon,full,1,placebo_perm,112,,,,F1,,,G1,L1,,,,,,,0
S01008,4_placebo_dist,AN05,followon,full,1,placebo_perm,113,,,,F1,,,G1,L1,,,,,,,0
S01009,4_placebo_dist,AN05,followon,full,1,placebo_perm,114,,,,F1,,,G1,L1,,,,,,,0
S01010,4_placebo_dist,AN05,followon,full,1,placebo_perm,115,,,,F1,,,G1,L1,,,,,,,0
S01011,4_placebo_dist,AN05,followon,full,1,placebo_perm,116,,,,F1,,,G1,L1,,,,,,,0
S01012,4_placebo_dist,AN05,followon,full,1,placebo_perm,117,,,,F1,,,G1,L1,,,,,,,0
S01013,4_placebo_dist,AN05,followon,full,1,placebo_perm,118,,,,F1,,,G1,L1,,,,,,,0
S01014,4_placebo_dist,AN05,followon,full,1,placebo_perm,119,,,,F1,,,G1,L1,,,,,,,0
S01015,4_placebo_dist,AN05,followon,full,1,placebo_perm,120,,,,F1,,,G1,L1,,,,,,,0
S01016,4_placebo_dist,AN05,followon,full,1,placebo_perm,121,,,,F1,,,G1,L1,,,,,,,0
S01017,4_placebo_dist,AN05,followon,full,1,placebo_perm,122,,,,F1,,,G1,L1,,,,,,,0
S01018,4_placebo_dist,AN05,followon,full,1,placebo_perm,123,,,,F1,,,G1,L1,,,,,,,0
S01019,4_placebo_dist,AN05,followon,full,1,placebo_perm,124,,,,F1,,,G1,L1,,,,,,,0
S01020,4_placebo_dist,AN05,followon,full,1,placebo_perm,125,,,,F1,,,G1,L1,,,,,,,0
S01021,4_placebo_dist,AN05,followon,full,1,placebo_perm,126,,,,F1,,,G1,L1,,,,,,,0
S01022,4_placebo_dist,AN05,followon,full,1,placebo_perm,127,,,,F1,,,G1,L1,,,,,,,0
S01023,4_placebo_dist,AN05,followon,full,1,placebo_perm,128,,,,F1,,,G1,L1,,,,,,,0
S01024,4_placebo_dist,AN05,followon,full,1,placebo_perm,129,,,,F1,,,G1,L1,,,,,,,0
S01025,4_placebo_dist,AN05,followon,full,1,placebo_perm,130,,,,F1,,,G1,L1,,,,,,,0
S01026,4_placebo_dist,AN05,followon,full,1,placebo_perm,131,,,,F1,,,G1,L1,,,,,,,0
S01027,4_placebo_dist,AN05,followon,full,1,placebo_perm,132,,,,F1,,,G1,L1,,,,,,,0
S01028,4_placebo_dist,AN05,followon,full,1,placebo_perm,133,,,,F1,,,G1,L1,,,,,,,0
S01029,4_placebo_dist,AN05,followon,full,1,placebo_perm,134,,,,F1,,,G1,L1,,,,,,,0
S01030,4_placebo_dist,AN05,followon,full,1,placebo_perm,135,,,,F1,,,G1,L1,,,,,,,0
S01031,4_placebo_dist,AN05,followon,full,1,placebo_perm,136,,,,F1,,,G1,L1,,,,,,,0
S01032,4_placebo_dist,AN05,followon,full,1,placebo_perm,137,,,,F1,,,G1,L1,,,,,,,0
S01033,4_placebo_dist,AN05,followon,full,1,placebo_perm,138,,,,F1,,,G1,L1,,,,,,,0
S01034,4_placebo_dist,AN05,followon,full,1,placebo_perm,139,,,,F1,,,G1,L1,,,,,,,0
S01035,4_placebo_dist,AN05,followon,full,1,placebo_perm,140,,,,F1,,,G1,L1,,,,,,,0
S01036,4_placebo_dist,AN05,followon,full,1,placebo_perm,141,,,,F1,,,G1,L1,,,,,,,0
S01037,4_placebo_dist,AN05,followon,full,1,placebo_perm,142,,,,F1,,,G1,L1,,,,,,,0
S01038,4_placebo_dist,AN05,followon,full,1,placebo_perm,143,,,,F1,,,G1,L1,,,,,,,0
S01039,4_placebo_dist,AN05,followon,full,1,placebo_perm,144,,,,F1,,,G1,L1,,,,,,,0
S01040,4_placebo_dist,AN05,followon,full,1,placebo_perm,145,,,,F1,,,G1,L1,,,,,,,0
S01041,4_placebo_dist,AN05,followon,full,1,placebo_perm,146,,,,F1,,,G1,L1,,,,,,,0
S01042,4_placebo_dist,AN05,followon,full,1,placebo_perm,147,,,,F1,,,G1,L1,,,,,,,0
S01043,4_placebo_dist,AN05,followon,full,1,placebo_perm,148,,,,F1,,,G1,L1,,,,,,,0
S01044,4_placebo_dist,AN05,followon,full,1,placebo_perm,149,,,,F1,,,G1,L1,,,,,,,0
S01045,4_placebo_dist,AN05,followon,full,1,placebo_perm,150,,,,F1,,,G1,L1,,,,,,,0
S01046,4_placebo_dist,AN05,followon,full,1,placebo_perm,151,,,,F1,,,G1,L1,,,,,,,0
S01047,4_placebo_dist,AN05,followon,full,1,placebo_perm,152,,,,F1,,,G1,L1,,,,,,,0
S01048,4_placebo_dist,AN05,followon,full,1,placebo_perm,153,,,,F1,,,G1,L1,,,,,,,0
S01049,4_placebo_dist,AN05,followon,full,1,placebo_perm,154,,,,F1,,,G1,L1,,,,,,,0
S01050,4_placebo_dist,AN05,followon,full,1,placebo_perm,155,,,,F1,,,G1,L1,,,,,,,0
S01051,4_placebo_dist,AN05,followon,full,1,placebo_perm,156,,,,F1,,,G1,L1,,,,,,,0
S01052,4_placebo_dist,AN05,followon,full,1,placebo_perm,157,,,,F1,,,G1,L1,,,,,,,0
S01053,4_placebo_dist,AN05,followon,full,1,placebo_perm,158,,,,F1,,,G1,L1,,,,,,,0
S01054,4_placebo_dist,AN05,followon,full,1,placebo_perm,159,,,,F1,,,G1,L1,,,,,,,0
S01055,4_placebo_dist,AN05,followon,full,1,placebo_perm,160,,,,F1,,,G1,L1,,,,,,,0
S01056,4_placebo_dist,AN05,followon,full,1,placebo_perm,161,,,,F1,,,G1,L1,,,,,,,0
S01057,4_placebo_dist,AN05,followon,full,1,placebo_perm,162,,,,F1,,,G1,L1,,,,,,,0
S01058,4_placebo_dist,AN05,followon,full,1,placebo_perm,163,,,,F1,,,G1,L1,,,,,,,0
S01059,4_placebo_dist,AN05,followon,full,1,placebo_perm,164,,,,F1,,,G1,L1,,,,,,,0
S01060,4_placebo_dist,AN05,followon,full,1,placebo_perm,165,,,,F1,,,G1,L1,,,,,,,0
S01061,4_placebo_dist,AN05,followon,full,1,placebo_perm,166,,,,F1,,,G1,L1,,,,,,,0
S01062,4_placebo_dist,AN05,followon,full,1,placebo_perm,167,,,,F1,,,G1,L1,,,,,,,0
S01063,4_placebo_dist,AN05,followon,full,1,placebo_perm,168,,,,F1,,,G1,L1,,,,,,,0
S01064,4_placebo_dist,AN05,followon,full,1,placebo_perm,169,,,,F1,,,G1,L1,,,,,,,0
S01065,4_placebo_dist,AN05,followon,full,1,placebo_perm,170,,,,F1,,,G1,L1,,,,,,,0
S01066,4_placebo_dist,AN05,followon,full,1,placebo_perm,171,,,,F1,,,G1,L1,,,,,,,0
S01067,4_placebo_dist,AN05,followon,full,1,placebo_perm,172,,,,F1,,,G1,L1,,,,,,,0
S01068,4_placebo_dist,AN05,followon,full,1,placebo_perm,173,,,,F1,,,G1,L1,,,,,,,0
S01069,4_placebo_dist,AN05,followon,full,1,placebo_perm,174,,,,F1,,,G1,L1,,,,,,,0
S01070,4_placebo_dist,AN05,followon,full,1,placebo_perm,175,,,,F1,,,G1,L1,,,,,,,0
S01071,4_placebo_dist,AN05,followon,full,1,placebo_perm,176,,,,F1,,,G1,L1,,,,,,,0
S01072,4_placebo_dist,AN05,followon,full,1,placebo_perm,177,,,,F1,,,G1,L1,,,,,,,0
S01073,4_placebo_dist,AN05,followon,full,1,placebo_perm,178,,,,F1,,,G1,L1,,,,,,,0
S01074,4_placebo_dist,AN05,followon,full,1,placebo_perm,179,,,,F1,,,G1,L1,,,,,,,0
S01075,4_placebo_dist,AN05,followon,full,1,placebo_perm,180,,,,F1,,,G1,L1,,,,,,,0
S01076,4_placebo_dist,AN05,followon,full,1,placebo_perm,181,,,,F1,,,G1,L1,,,,,,,0
S01077,4_placebo_dist,AN05,followon,full,1,placebo_perm,182,,,,F1,,,G1,L1,,,,,,,0
S01078,4_placebo_dist,AN05,followon,full,1,placebo_perm,183,,,,F1,,,G1,L1,,,,,,,0
S01079,4_placebo_dist,AN05,followon,full,1,placebo_perm,184,,,,F1,,,G1,L1,,,,,,,0
S01080,4_placebo_dist,AN05,followon,full,1,placebo_perm,185,,,,F1,,,G1,L1,,,,,,,0
S01081,4_placebo_dist,AN05,followon,full,1,placebo_perm,186,,,,F1,,,G1,L1,,,,,,,0
S01082,4_placebo_dist,AN05,followon,full,1,placebo_perm,187,,,,F1,,,G1,L1,,,,,,,0
S01083,4_placebo_dist,AN05,followon,full,1,placebo_perm,188,,,,F1,,,G1,L1,,,,,,,0
S01084,4_placebo_dist,AN05,followon,full,1,placebo_perm,189,,,,F1,,,G1,L1,,,,,,,0
S01085,4_placebo_dist,AN05,followon,full,1,placebo_perm,190,,,,F1,,,G1,L1,,,,,,,0
S01086,4_placebo_dist,AN05,followon,full,1,placebo_perm,191,,,,F1,,,G1,L1,,,,,,,0
S01087,4_placebo_dist,AN05,followon,full,1,placebo_perm,192,,,,F1,,,G1,L1,,,,,,,0
S01088,4_placebo_dist,AN05,followon,full,1,placebo_perm,193,,,,F1,,,G1,L1,,,,,,,0
S01089,4_placebo_dist,AN05,followon,full,1,placebo_perm,194,,,,F1,,,G1,L1,,,,,,,0
S01090,4_placebo_dist,AN05,followon,full,1,placebo_perm,195,,,,F1,,,G1,L1,,,,,,,0
S01091,4_placebo_dist,AN05,followon,full,1,placebo_perm,196,,,,F1,,,G1,L1,,,,,,,0
S01092,4_placebo_dist,AN05,followon,full,1,placebo_perm,197,,,,F1,,,G1,L1,,,,,,,0
S01093,4_placebo_dist,AN05,followon,full,1,placebo_perm,198,,,,F1,,,G1,L1,,,,,,,0
S01094,4_placebo_dist,AN05,followon,full,1,placebo_perm,199,,,,F1,,,G1,L1,,,,,,,0
S01095,4_placebo_dist,AN05,followon,full,1,placebo_perm,200,,,,F1,,,G1,L1,,,,,,,0
S01096,4_placebo_dist,AN05,contributors,full,1,placebo_perm,1,,,,,,,G1,L1,,,,,,,0
S01097,4_placebo_dist,AN05,contributors,full,1,placebo_perm,2,,,,,,,G1,L1,,,,,,,0
S01098,4_placebo_dist,AN05,contributors,full,1,placebo_perm,3,,,,,,,G1,L1,,,,,,,0
S01099,4_placebo_dist,AN05,contributors,full,1,placebo_perm,4,,,,,,,G1,L1,,,,,,,0
S01100,4_placebo_dist,AN05,contributors,full,1,placebo_perm,5,,,,,,,G1,L1,,,,,,,0
S01101,4_placebo_dist,AN05,contributors,full,1,placebo_perm,6,,,,,,,G1,L1,,,,,,,0
S01102,4_placebo_dist,AN05,contributors,full,1,placebo_perm,7,,,,,,,G1,L1,,,,,,,0
S01103,4_placebo_dist,AN05,contributors,full,1,placebo_perm,8,,,,,,,G1,L1,,,,,,,0
S01104,4_placebo_dist,AN05,contributors,full,1,placebo_perm,9,,,,,,,G1,L1,,,,,,,0
S01105,4_placebo_dist,AN05,contributors,full,1,placebo_perm,10,,,,,,,G1,L1,,,,,,,0
S01106,4_placebo_dist,AN05,contributors,full,1,placebo_perm,11,,,,,,,G1,L1,,,,,,,0
S01107,4_placebo_dist,AN05,contributors,full,1,placebo_perm,12,,,,,,,G1,L1,,,,,,,0
S01108,4_placebo_dist,AN05,contributors,full,1,placebo_perm,13,,,,,,,G1,L1,,,,,,,0
S01109,4_placebo_dist,AN05,contributors,full,1,placebo_perm,14,,,,,,,G1,L1,,,,,,,0
S01110,4_placebo_dist,AN05,contributors,full,1,placebo_perm,15,,,,,,,G1,L1,,,,,,,0
S01111,4_placebo_dist,AN05,contributors,full,1,placebo_perm,16,,,,,,,G1,L1,,,,,,,0
S01112,4_placebo_dist,AN05,contributors,full,1,placebo_perm,17,,,,,,,G1,L1,,,,,,,0
S01113,4_placebo_dist,AN05,contributors,full,1,placebo_perm,18,,,,,,,G1,L1,,,,,,,0
S01114,4_placebo_dist,AN05,contributors,full,1,placebo_perm,19,,,,,,,G1,L1,,,,,,,0
S01115,4_placebo_dist,AN05,contributors,full,1,placebo_perm,20,,,,,,,G1,L1,,,,,,,0
S01116,4_placebo_dist,AN05,contributors,full,1,placebo_perm,21,,,,,,,G1,L1,,,,,,,0
S01117,4_placebo_dist,AN05,contributors,full,1,placebo_perm,22,,,,,,,G1,L1,,,,,,,0
S01118,4_placebo_dist,AN05,contributors,full,1,placebo_perm,23,,,,,,,G1,L1,,,,,,,0
S01119,4_placebo_dist,AN05,contributors,full,1,placebo_perm,24,,,,,,,G1,L1,,,,,,,0
S01120,4_placebo_dist,AN05,contributors,full,1,placebo_perm,25,,,,,,,G1,L1,,,,,,,0
S01121,4_placebo_dist,AN05,contributors,full,1,placebo_perm,26,,,,,,,G1,L1,,,,,,,0
S01122,4_placebo_dist,AN05,contributors,full,1,placebo_perm,27,,,,,,,G1,L1,,,,,,,0
S01123,4_placebo_dist,AN05,contributors,full,1,placebo_perm,28,,,,,,,G1,L1,,,,,,,0
S01124,4_placebo_dist,AN05,contributors,full,1,placebo_perm,29,,,,,,,G1,L1,,,,,,,0
S01125,4_placebo_dist,AN05,contributors,full,1,placebo_perm,30,,,,,,,G1,L1,,,,,,,0
S01126,4_placebo_dist,AN05,contributors,full,1,placebo_perm,31,,,,,,,G1,L1,,,,,,,0
S01127,4_placebo_dist,AN05,contributors,full,1,placebo_perm,32,,,,,,,G1,L1,,,,,,,0
S01128,4_placebo_dist,AN05,contributors,full,1,placebo_perm,33,,,,,,,G1,L1,,,,,,,0
S01129,4_placebo_dist,AN05,contributors,full,1,placebo_perm,34,,,,,,,G1,L1,,,,,,,0
S01130,4_placebo_dist,AN05,contributors,full,1,placebo_perm,35,,,,,,,G1,L1,,,,,,,0
S01131,4_placebo_dist,AN05,contributors,full,1,placebo_perm,36,,,,,,,G1,L1,,,,,,,0
S01132,4_placebo_dist,AN05,contributors,full,1,placebo_perm,37,,,,,,,G1,L1,,,,,,,0
S01133,4_placebo_dist,AN05,contributors,full,1,placebo_perm,38,,,,,,,G1,L1,,,,,,,0
S01134,4_placebo_dist,AN05,contributors,full,1,placebo_perm,39,,,,,,,G1,L1,,,,,,,0
S01135,4_placebo_dist,AN05,contributors,full,1,placebo_perm,40,,,,,,,G1,L1,,,,,,,0
S01136,4_placebo_dist,AN05,contributors,full,1,placebo_perm,41,,,,,,,G1,L1,,,,,,,0
S01137,4_placebo_dist,AN05,contributors,full,1,placebo_perm,42,,,,,,,G1,L1,,,,,,,0
S01138,4_placebo_dist,AN05,contributors,full,1,placebo_perm,43,,,,,,,G1,L1,,,,,,,0
S01139,4_placebo_dist,AN05,contributors,full,1,placebo_perm,44,,,,,,,G1,L1,,,,,,,0
S01140,4_placebo_dist,AN05,contributors,full,1,placebo_perm,45,,,,,,,G1,L1,,,,,,,0
S01141,4_placebo_dist,AN05,contributors,full,1,placebo_perm,46,,,,,,,G1,L1,,,,,,,0
S01142,4_placebo_dist,AN05,contributors,full,1,placebo_perm,47,,,,,,,G1,L1,,,,,,,0
S01143,4_placebo_dist,AN05,contributors,full,1,placebo_perm,48,,,,,,,G1,L1,,,,,,,0
S01144,4_placebo_dist,AN05,contributors,full,1,placebo_perm,49,,,,,,,G1,L1,,,,,,,0
S01145,4_placebo_dist,AN05,contributors,full,1,placebo_perm,50,,,,,,,G1,L1,,,,,,,0
S01146,4_placebo_dist,AN05,contributors,full,1,placebo_perm,51,,,,,,,G1,L1,,,,,,,0
S01147,4_placebo_dist,AN05,contributors,full,1,placebo_perm,52,,,,,,,G1,L1,,,,,,,0
S01148,4_placebo_dist,AN05,contributors,full,1,placebo_perm,53,,,,,,,G1,L1,,,,,,,0
S01149,4_placebo_dist,AN05,contributors,full,1,placebo_perm,54,,,,,,,G1,L1,,,,,,,0
S01150,4_placebo_dist,AN05,contributors,full,1,placebo_perm,55,,,,,,,G1,L1,,,,,,,0
S01151,4_placebo_dist,AN05,contributors,full,1,placebo_perm,56,,,,,,,G1,L1,,,,,,,0
S01152,4_placebo_dist,AN05,contributors,full,1,placebo_perm,57,,,,,,,G1,L1,,,,,,,0
S01153,4_placebo_dist,AN05,contributors,full,1,placebo_perm,58,,,,,,,G1,L1,,,,,,,0
S01154,4_placebo_dist,AN05,contributors,full,1,placebo_perm,59,,,,,,,G1,L1,,,,,,,0
S01155,4_placebo_dist,AN05,contributors,full,1,placebo_perm,60,,,,,,,G1,L1,,,,,,,0
S01156,4_placebo_dist,AN05,contributors,full,1,placebo_perm,61,,,,,,,G1,L1,,,,,,,0
S01157,4_placebo_dist,AN05,contributors,full,1,placebo_perm,62,,,,,,,G1,L1,,,,,,,0
S01158,4_placebo_dist,AN05,contributors,full,1,placebo_perm,63,,,,,,,G1,L1,,,,,,,0
S01159,4_placebo_dist,AN05,contributors,full,1,placebo_perm,64,,,,,,,G1,L1,,,,,,,0
S01160,4_placebo_dist,AN05,contributors,full,1,placebo_perm,65,,,,,,,G1,L1,,,,,,,0
S01161,4_placebo_dist,AN05,contributors,full,1,placebo_perm,66,,,,,,,G1,L1,,,,,,,0
S01162,4_placebo_dist,AN05,contributors,full,1,placebo_perm,67,,,,,,,G1,L1,,,,,,,0
S01163,4_placebo_dist,AN05,contributors,full,1,placebo_perm,68,,,,,,,G1,L1,,,,,,,0
S01164,4_placebo_dist,AN05,contributors,full,1,placebo_perm,69,,,,,,,G1,L1,,,,,,,0
S01165,4_placebo_dist,AN05,contributors,full,1,placebo_perm,70,,,,,,,G1,L1,,,,,,,0
S01166,4_placebo_dist,AN05,contributors,full,1,placebo_perm,71,,,,,,,G1,L1,,,,,,,0
S01167,4_placebo_dist,AN05,contributors,full,1,placebo_perm,72,,,,,,,G1,L1,,,,,,,0
S01168,4_placebo_dist,AN05,contributors,full,1,placebo_perm,73,,,,,,,G1,L1,,,,,,,0
S01169,4_placebo_dist,AN05,contributors,full,1,placebo_perm,74,,,,,,,G1,L1,,,,,,,0
S01170,4_placebo_dist,AN05,contributors,full,1,placebo_perm,75,,,,,,,G1,L1,,,,,,,0
S01171,4_placebo_dist,AN05,contributors,full,1,placebo_perm,76,,,,,,,G1,L1,,,,,,,0
S01172,4_placebo_dist,AN05,contributors,full,1,placebo_perm,77,,,,,,,G1,L1,,,,,,,0
S01173,4_placebo_dist,AN05,contributors,full,1,placebo_perm,78,,,,,,,G1,L1,,,,,,,0
S01174,4_placebo_dist,AN05,contributors,full,1,placebo_perm,79,,,,,,,G1,L1,,,,,,,0
S01175,4_placebo_dist,AN05,contributors,full,1,placebo_perm,80,,,,,,,G1,L1,,,,,,,0
S01176,4_placebo_dist,AN05,contributors,full,1,placebo_perm,81,,,,,,,G1,L1,,,,,,,0
S01177,4_placebo_dist,AN05,contributors,full,1,placebo_perm,82,,,,,,,G1,L1,,,,,,,0
S01178,4_placebo_dist,AN05,contributors,full,1,placebo_perm,83,,,,,,,G1,L1,,,,,,,0
S01179,4_placebo_dist,AN05,contributors,full,1,placebo_perm,84,,,,,,,G1,L1,,,,,,,0
S01180,4_placebo_dist,AN05,contributors,full,1,placebo_perm,85,,,,,,,G1,L1,,,,,,,0
S01181,4_placebo_dist,AN05,contributors,full,1,placebo_perm,86,,,,,,,G1,L1,,,,,,,0
S01182,4_placebo_dist,AN05,contributors,full,1,placebo_perm,87,,,,,,,G1,L1,,,,,,,0
S01183,4_placebo_dist,AN05,contributors,full,1,placebo_perm,88,,,,,,,G1,L1,,,,,,,0
S01184,4_placebo_dist,AN05,contributors,full,1,placebo_perm,89,,,,,,,G1,L1,,,,,,,0
S01185,4_placebo_dist,AN05,contributors,full,1,placebo_perm,90,,,,,,,G1,L1,,,,,,,0
S01186,4_placebo_dist,AN05,contributors,full,1,placebo_perm,91,,,,,,,G1,L1,,,,,,,0
S01187,4_placebo_dist,AN05,contributors,full,1,placebo_perm,92,,,,,,,G1,L1,,,,,,,0
S01188,4_placebo_dist,AN05,contributors,full,1,placebo_perm,93,,,,,,,G1,L1,,,,,,,0
S01189,4_placebo_dist,AN05,contributors,full,1,placebo_perm,94,,,,,,,G1,L1,,,,,,,0
S01190,4_placebo_dist,AN05,contributors,full,1,placebo_perm,95,,,,,,,G1,L1,,,,,,,0
S01191,4_placebo_dist,AN05,contributors,full,1,placebo_perm,96,,,,,,,G1,L1,,,,,,,0
S01192,4_placebo_dist,AN05,contributors,full,1,placebo_perm,97,,,,,,,G1,L1,,,,,,,0
S01193,4_placebo_dist,AN05,contributors,full,1,placebo_perm,98,,,,,,,G1,L1,,,,,,,0
S01194,4_placebo_dist,AN05,contributors,full,1,placebo_perm,99,,,,,,,G1,L1,,,,,,,0
S01195,4_placebo_dist,AN05,contributors,full,1,placebo_perm,100,,,,,,,G1,L1,,,,,,,0
S01196,4_placebo_dist,AN05,contributors,full,1,placebo_perm,101,,,,,,,G1,L1,,,,,,,0
S01197,4_placebo_dist,AN05,contributors,full,1,placebo_perm,102,,,,,,,G1,L1,,,,,,,0
S01198,4_placebo_dist,AN05,contributors,full,1,placebo_perm,103,,,,,,,G1,L1,,,,,,,0
S01199,4_placebo_dist,AN05,contributors,full,1,placebo_perm,104,,,,,,,G1,L1,,,,,,,0
S01200,4_placebo_dist,AN05,contributors,full,1,placebo_perm,105,,,,,,,G1,L1,,,,,,,0
S01201,4_placebo_dist,AN05,contributors,full,1,placebo_perm,106,,,,,,,G1,L1,,,,,,,0
S01202,4_placebo_dist,AN05,contributors,full,1,placebo_perm,107,,,,,,,G1,L1,,,,,,,0
S01203,4_placebo_dist,AN05,contributors,full,1,placebo_perm,108,,,,,,,G1,L1,,,,,,,0
S01204,4_placebo_dist,AN05,contributors,full,1,placebo_perm,109,,,,,,,G1,L1,,,,,,,0
S01205,4_placebo_dist,AN05,contributors,full,1,placebo_perm,110,,,,,,,G1,L1,,,,,,,0
S01206,4_placebo_dist,AN05,contributors,full,1,placebo_perm,111,,,,,,,G1,L1,,,,,,,0
S01207,4_placebo_dist,AN05,contributors,full,1,placebo_perm,112,,,,,,,G1,L1,,,,,,,0
S01208,4_placebo_dist,AN05,contributors,full,1,placebo_perm,113,,,,,,,G1,L1,,,,,,,0
S01209,4_placebo_dist,AN05,contributors,full,1,placebo_perm,114,,,,,,,G1,L1,,,,,,,0
S01210,4_placebo_dist,AN05,contributors,full,1,placebo_perm,115,,,,,,,G1,L1,,,,,,,0
S01211,4_placebo_dist,AN05,contributors,full,1,placebo_perm,116,,,,,,,G1,L1,,,,,,,0
S01212,4_placebo_dist,AN05,contributors,full,1,placebo_perm,117,,,,,,,G1,L1,,,,,,,0
S01213,4_placebo_dist,AN05,contributors,full,1,placebo_perm,118,,,,,,,G1,L1,,,,,,,0
S01214,4_placebo_dist,AN05,contributors,full,1,placebo_perm,119,,,,,,,G1,L1,,,,,,,0
S01215,4_placebo_dist,AN05,contributors,full,1,placebo_perm,120,,,,,,,G1,L1,,,,,,,0
S01216,4_placebo_dist,AN05,contributors,full,1,placebo_perm,121,,,,,,,G1,L1,,,,,,,0
S01217,4_placebo_dist,AN05,contributors,full,1,placebo_perm,122,,,,,,,G1,L1,,,,,,,0
S01218,4_placebo_dist,AN05,contributors,full,1,placebo_perm,123,,,,,,,G1,L1,,,,,,,0
S01219,4_placebo_dist,AN05,contributors,full,1,placebo_perm,124,,,,,,,G1,L1,,,,,,,0
S01220,4_placebo_dist,AN05,contributors,full,1,placebo_perm,125,,,,,,,G1,L1,,,,,,,0
S01221,4_placebo_dist,AN05,contributors,full,1,placebo_perm,126,,,,,,,G1,L1,,,,,,,0
S01222,4_placebo_dist,AN05,contributors,full,1,placebo_perm,127,,,,,,,G1,L1,,,,,,,0
S01223,4_placebo_dist,AN05,contributors,full,1,placebo_perm,128,,,,,,,G1,L1,,,,,,,0
S01224,4_placebo_dist,AN05,contributors,full,1,placebo_perm,129,,,,,,,G1,L1,,,,,,,0
S01225,4_placebo_dist,AN05,contributors,full,1,placebo_perm,130,,,,,,,G1,L1,,,,,,,0
S01226,4_placebo_dist,AN05,contributors,full,1,placebo_perm,131,,,,,,,G1,L1,,,,,,,0
S01227,4_placebo_dist,AN05,contributors,full,1,placebo_perm,132,,,,,,,G1,L1,,,,,,,0
S01228,4_placebo_dist,AN05,contributors,full,1,placebo_perm,133,,,,,,,G1,L1,,,,,,,0
S01229,4_placebo_dist,AN05,contributors,full,1,placebo_perm,134,,,,,,,G1,L1,,,,,,,0
S01230,4_placebo_dist,AN05,contributors,full,1,placebo_perm,135,,,,,,,G1,L1,,,,,,,0
S01231,4_placebo_dist,AN05,contributors,full,1,placebo_perm,136,,,,,,,G1,L1,,,,,,,0
S01232,4_placebo_dist,AN05,contributors,full,1,placebo_perm,137,,,,,,,G1,L1,,,,,,,0
S01233,4_placebo_dist,AN05,contributors,full,1,placebo_perm,138,,,,,,,G1,L1,,,,,,,0
S01234,4_placebo_dist,AN05,contributors,full,1,placebo_perm,139,,,,,,,G1,L1,,,,,,,0
S01235,4_placebo_dist,AN05,contributors,full,1,placebo_perm,140,,,,,,,G1,L1,,,,,,,0
S01236,4_placebo_dist,AN05,contributors,full,1,placebo_perm,141,,,,,,,G1,L1,,,,,,,0
S01237,4_placebo_dist,AN05,contributors,full,1,placebo_perm,142,,,,,,,G1,L1,,,,,,,0
S01238,4_placebo_dist,AN05,contributors,full,1,placebo_perm,143,,,,,,,G1,L1,,,,,,,0
S01239,4_placebo_dist,AN05,contributors,full,1,placebo_perm,144,,,,,,,G1,L1,,,,,,,0
S01240,4_placebo_dist,AN05,contributors,full,1,placebo_perm,145,,,,,,,G1,L1,,,,,,,0
S01241,4_placebo_dist,AN05,contributors,full,1,placebo_perm,146,,,,,,,G1,L1,,,,,,,0
S01242,4_placebo_dist,AN05,contributors,full,1,placebo_perm,147,,,,,,,G1,L1,,,,,,,0
S01243,4_placebo_dist,AN05,contributors,full,1,placebo_perm,148,,,,,,,G1,L1,,,,,,,0
S01244,4_placebo_dist,AN05,contributors,full,1,placebo_perm,149,,,,,,,G1,L1,,,,,,,0
S01245,4_placebo_dist,AN05,contributors,full,1,placebo_perm,150,,,,,,,G1,L1,,,,,,,0
S01246,4_placebo_dist,AN05,contributors,full,1,placebo_perm,151,,,,,,,G1,L1,,,,,,,0
S01247,4_placebo_dist,AN05,contributors,full,1,placebo_perm,152,,,,,,,G1,L1,,,,,,,0
S01248,4_placebo_dist,AN05,contributors,full,1,placebo_perm,153,,,,,,,G1,L1,,,,,,,0
S01249,4_placebo_dist,AN05,contributors,full,1,placebo_perm,154,,,,,,,G1,L1,,,,,,,0
S01250,4_placebo_dist,AN05,contributors,full,1,placebo_perm,155,,,,,,,G1,L1,,,,,,,0
S01251,4_placebo_dist,AN05,contributors,full,1,placebo_perm,156,,,,,,,G1,L1,,,,,,,0
S01252,4_placebo_dist,AN05,contributors,full,1,placebo_perm,157,,,,,,,G1,L1,,,,,,,0
S01253,4_placebo_dist,AN05,contributors,full,1,placebo_perm,158,,,,,,,G1,L1,,,,,,,0
S01254,4_placebo_dist,AN05,contributors,full,1,placebo_perm,159,,,,,,,G1,L1,,,,,,,0
S01255,4_placebo_dist,AN05,contributors,full,1,placebo_perm,160,,,,,,,G1,L1,,,,,,,0
S01256,4_placebo_dist,AN05,contributors,full,1,placebo_perm,161,,,,,,,G1,L1,,,,,,,0
S01257,4_placebo_dist,AN05,contributors,full,1,placebo_perm,162,,,,,,,G1,L1,,,,,,,0
S01258,4_placebo_dist,AN05,contributors,full,1,placebo_perm,163,,,,,,,G1,L1,,,,,,,0
S01259,4_placebo_dist,AN05,contributors,full,1,placebo_perm,164,,,,,,,G1,L1,,,,,,,0
S01260,4_placebo_dist,AN05,contributors,full,1,placebo_perm,165,,,,,,,G1,L1,,,,,,,0
S01261,4_placebo_dist,AN05,contributors,full,1,placebo_perm,166,,,,,,,G1,L1,,,,,,,0
S01262,4_placebo_dist,AN05,contributors,full,1,placebo_perm,167,,,,,,,G1,L1,,,,,,,0
S01263,4_placebo_dist,AN05,contributors,full,1,placebo_perm,168,,,,,,,G1,L1,,,,,,,0
S01264,4_placebo_dist,AN05,contributors,full,1,placebo_perm,169,,,,,,,G1,L1,,,,,,,0
S01265,4_placebo_dist,AN05,contributors,full,1,placebo_perm,170,,,,,,,G1,L1,,,,,,,0
S01266,4_placebo_dist,AN05,contributors,full,1,placebo_perm,171,,,,,,,G1,L1,,,,,,,0
S01267,4_placebo_dist,AN05,contributors,full,1,placebo_perm,172,,,,,,,G1,L1,,,,,,,0
S01268,4_placebo_dist,AN05,contributors,full,1,placebo_perm,173,,,,,,,G1,L1,,,,,,,0
S01269,4_placebo_dist,AN05,contributors,full,1,placebo_perm,174,,,,,,,G1,L1,,,,,,,0
S01270,4_placebo_dist,AN05,contributors,full,1,placebo_perm,175,,,,,,,G1,L1,,,,,,,0
S01271,4_placebo_dist,AN05,contributors,full,1,placebo_perm,176,,,,,,,G1,L1,,,,,,,0
S01272,4_placebo_dist,AN05,contributors,full,1,placebo_perm,177,,,,,,,G1,L1,,,,,,,0
S01273,4_placebo_dist,AN05,contributors,full,1,placebo_perm,178,,,,,,,G1,L1,,,,,,,0
S01274,4_placebo_dist,AN05,contributors,full,1,placebo_perm,179,,,,,,,G1,L1,,,,,,,0
S01275,4_placebo_dist,AN05,contributors,full,1,placebo_perm,180,,,,,,,G1,L1,,,,,,,0
S01276,4_placebo_dist,AN05,contributors,full,1,placebo_perm,181,,,,,,,G1,L1,,,,,,,0
S01277,4_placebo_dist,AN05,contributors,full,1,placebo_perm,182,,,,,,,G1,L1,,,,,,,0
S01278,4_placebo_dist,AN05,contributors,full,1,placebo_perm,183,,,,,,,G1,L1,,,,,,,0
S01279,4_placebo_dist,AN05,contributors,full,1,placebo_perm,184,,,,,,,G1,L1,,,,,,,0
S01280,4_placebo_dist,AN05,contributors,full,1,placebo_perm,185,,,,,,,G1,L1,,,,,,,0
S01281,4_placebo_dist,AN05,contributors,full,1,placebo_perm,186,,,,,,,G1,L1,,,,,,,0
S01282,4_placebo_dist,AN05,contributors,full,1,placebo_perm,187,,,,,,,G1,L1,,,,,,,0
S01283,4_placebo_dist,AN05,contributors,full,1,placebo_perm,188,,,,,,,G1,L1,,,,,,,0
S01284,4_placebo_dist,AN05,contributors,full,1,placebo_perm,189,,,,,,,G1,L1,,,,,,,0
S01285,4_placebo_dist,AN05,contributors,full,1,placebo_perm,190,,,,,,,G1,L1,,,,,,,0
S01286,4_placebo_dist,AN05,contributors,full,1,placebo_perm,191,,,,,,,G1,L1,,,,,,,0
S01287,4_placebo_dist,AN05,contributors,full,1,placebo_perm,192,,,,,,,G1,L1,,,,,,,0
S01288,4_placebo_dist,AN05,contributors,full,1,placebo_perm,193,,,,,,,G1,L1,,,,,,,0
S01289,4_placebo_dist,AN05,contributors,full,1,placebo_perm,194,,,,,,,G1,L1,,,,,,,0
S01290,4_placebo_dist,AN05,contributors,full,1,placebo_perm,195,,,,,,,G1,L1,,,,,,,0
S01291,4_placebo_dist,AN05,contributors,full,1,placebo_perm,196,,,,,,,G1,L1,,,,,,,0
S01292,4_placebo_dist,AN05,contributors,full,1,placebo_perm,197,,,,,,,G1,L1,,,,,,,0
S01293,4_placebo_dist,AN05,contributors,full,1,placebo_perm,198,,,,,,,G1,L1,,,,,,,0
S01294,4_placebo_dist,AN05,contributors,full,1,placebo_perm,199,,,,,,,G1,L1,,,,,,,0
S01295,4_placebo_dist,AN05,contributors,full,1,placebo_perm,200,,,,,,,G1,L1,,,,,,,0
")
