#!/opt/homebrew/bin/Rscript
# PAPER_K7 v1. Sourceable functions; CLI runs only when executed directly.
HRM <- c('STAFF','TRAIN','INCENT','GRIEV','DECENT','ILM','VHIER')
CONTROLS <- c('NONPROF','SUBSID','LOGEMP','LOGAGE','PCTMGR','UNION','PRODUCT','SERVICE','COMPET')
INTERACTIONS <- list(TRAIN_x_STAFF=c('TRAIN','STAFF'), GRIEV_x_INCENT=c('GRIEV','INCENT'),
                     ILM_x_DECENT=c('ILM','DECENT'), VHIER_x_DECENT=c('VHIER','DECENT'))
REQUIRED <- unique(c('V1','V3','V8','V9','V16','V17','V21','V23','V32','V41','V43',
                    paste0('V',c(62,67,76,79,97,102,111,114,115,131,136,145,157,166,172,
                                 209,220,222,233,235,261,270:300,328)), 'NEWTOTAL','WEIGHT'))
`%||%` <- function(x,y) if(is.null(x)) y else x
valid <- function(x, values) { x[!x %in% values] <- NA_real_; x }
safe_log <- function(x, plus=FALSE) {
  x[!is.finite(x) | if(plus) x < 0 else x <= 0] <- NA_real_
  if(plus) log1p(x) else log(x)
}
index_mean <- function(x, rule='L0') {
  x <- as.matrix(x); x[!is.finite(x)] <- NA_real_
  y <- rowMeans(x, na.rm=rule!='L1'); y[!is.finite(y)] <- NA_real_; y
}
clean_data <- function(raw, metadata, settings) {
  d <- raw
  for(m in metadata$variables) {
    v <- m$name
    if(!v %in% names(d)) next
    miss <- unlist(m$declared_missing_values)
    if(v %in% c('V62','V97','V131') && settings$staff_coding=='L2') miss <- setdiff(miss,995)
    d[[v]][d[[v]] %in% miss] <- NA_real_
    for(r in m$declared_missing_ranges) {
      z <- as.numeric(unlist(r)); if(length(z)!=2L) stop('Invalid missing range for ',v)
      d[[v]][!is.na(d[[v]]) & d[[v]]>=z[1] & d[[v]]<=z[2]] <- NA_real_
    }
    d[[v]][!is.finite(d[[v]])] <- NA_real_
  }
  d
}
staff_valid <- function(x, level) {
  x[x %in% (if(level=='L2') 996:999 else 995:999)] <- NA_real_
  x[!is.na(x) & x < if(level=='L1') 0 else 1] <- NA_real_; x
}
apply_copy <- function(d, raw, s) {
  for(v in c('V62','V97','V131')) d[[v]] <- staff_valid(d[[v]],s$staff_coding)
  for(v in c('V67','V76','V102','V111','V136')) d[[v]] <- valid(d[[v]],1:2)
  for(v in c('V209','V222','V235')) d[[v]] <- valid(d[[v]],1:3)
  if(s$item_rule!='L2') return(d)
  for(pair in list(c('V97','V62'),c('V102','V67'),c('V111','V76'),c('V235','V222'))) {
    use <- raw$V79 %in% 2 | (is.na(raw$V79) & !is.na(d[[pair[2]]]))
    d[[pair[1]]][use] <- d[[pair[2]]][use]
  }
  for(p in list(c('V131','V62','V97'),c('V136','V67','V102'),c('V209','V222','V235'))) {
    use <- raw$V114 %in% 2 | is.na(raw$V114)
    source <- d[[p[2]]]; source[is.na(source)] <- d[[p[3]]][is.na(source)]
    d[[p[1]]][use] <- source[use]
  }
  d
}
industry_groups <- function(x,crosswalk,level) {
  codes <- suppressWarnings(as.numeric(crosswalk$census1980_code))
  if(anyDuplicated(codes)) stop('Duplicate crosswalk codes')
  field <- crosswalk$sic2_from_printed[match(x,codes)]
  vapply(field, function(f) {
    if(is.na(f) || !nzchar(trimws(f))) return(if(level=='L0') 'UNCL' else NA_character_)
    gs <- trimws(strsplit(f,'[,;]')[[1]]); gs <- gs[nzchar(gs)]
    if(!length(gs)) return(if(level=='L0') 'UNCL' else NA_character_)
    if(any(!grepl('^[0-9]{1,2}$',gs))) stop('Invalid SIC group: ',f)
    if(level=='L1' && length(gs)>1) return(NA_character_)
    sprintf('%02d',as.integer(gs[1]))
  }, character(1), USE.NAMES=FALSE)
}
build_variables <- function(raw,metadata,crosswalk,s,check=NULL) {
  if(s$records=='L1') raw <- raw[!raw$V3 %in% 0,,drop=FALSE]
  d <- apply_copy(clean_data(raw,metadata,s),raw,s)
  ix <- function(cols,k) index_mean(sapply(cols,function(v) k+1-valid(d[[v]],seq_len(k))),s$item_rule)
  out <- data.frame(V1=raw$V1, POP=ix(paste0('V',289:295),4), PMP=ix(paste0('V',296:299),4))
  staff <- sapply(c('V62','V97','V131'),function(v) safe_log(d[[v]],s$staff_coding=='L1'))
  count <- d$V157; count[d$V157 %in% 99996] <- 100000; count[count %in% c(99998,99999)] <- NA
  yes <- 3-valid(d$V145,1:2); effect <- 4-valid(d$V172,1:3)
  no <- d$V145 %in% 2
  count[no] <- if(s$no_training=='L0') NA_real_ else 0
  effect[no] <- if(s$no_training=='L1') 1 else NA_real_
  if(s$train_log!='L2') count <- safe_log(count,s$no_training!='L0')
  if(s$train_log=='L0') {yes <- safe_log(yes); effect <- safe_log(effect)}
  train <- cbind(V145=yes,V157=count,V172=effect)
  # Provisional scores encode validity only; reference membership precedes z scoring.
  out$STAFF <- index_mean(staff,s$item_rule); out$TRAIN <- index_mean(train,s$item_rule)
  out$INCENT <- ix(c('V209','V222','V235'),3)
  out$GRIEV <- 2-valid(d$V270,1:2)
  decisions <- matrix(NA_real_,nrow(d),8)
  map <- if(s$decision_map=='L0') c(3,5,1,4,2) else c(1,5,3,4,2)
  for(j in 1:8) {
    v <- rep(NA_real_,nrow(d)); a <- d$V17 %in% 1; b <- d$V17 %in% 2
    v[a] <- d[[paste0('V',270+j)]][a]; v[b] <- d[[paste0('V',278+j)]][b]
    decisions[,j] <- map[valid(v,1:5)]
  }
  out$DECENT <- index_mean(decisions,s$item_rule)
  out$ILM <- ix(c('V67','V76','V102','V111','V136'),2)
  h <- d$V261; h[h %in% c(98,99)] <- NA
  h[h %in% 96] <- if(s$hierarchy=='L1') NA_real_ else 100
  out$VHIER <- if(s$hierarchy=='L2') h else safe_log(h)
  if(identical(check,'hierarchy_log10')) out$VHIER <- safe_log(h)/log(10)
  out$NONPROF <- valid(d$V8,1:2)-1
  if(s$subsidiary=='L0') out$SUBSID <- ifelse(is.na(d$V17),NA_real_,as.numeric(d$V17==1)) else {
    v <- d$V21; v[v %in% 8:9] <- NA
    out$SUBSID <- ifelse(is.na(v),NA_real_,as.numeric(v %in% if(s$subsidiary=='L1') 2 else 1:3))
    out$SUBSID[d$V17 %in% 2] <- 0
  }
  v23 <- d$V23; v32 <- d$V32
  v23[v23 %in% c(99998,99999)] <- NA; v32[v32 %in% c(99998,99999)] <- NA
  total <- v23+v32
  out$LOGEMP <- safe_log(switch(s$employment,L0=total,L1=d$NEWTOTAL,L2=v23))
  year <- d$V16; year[year %in% c(9998,9999)] <- NA; age <- 1991-year
  out$LOGAGE <- switch(s$age,L0=safe_log(age),L1=safe_log(age,TRUE),L2=age)
  numerator <- rep(NA_real_,nrow(d)); numerator[d$V114 %in% 1] <- d$V115[d$V114 %in% 1]
  if(s$pct_managers!='L1') numerator[d$V114 %in% 3] <- 0
  den <- if(s$pct_managers=='L2') d$NEWTOTAL else total; den[den %in% 0] <- NA
  out$PCTMGR <- 100*numerator/den
  if(identical(check,'pct_proportion')) out$PCTMGR <- out$PCTMGR/100
  union <- sapply(c('V220','V233'),function(v) 4-valid(d[[v]],1:3))
  if(s$union_items!='L0') union <- cbind(union,4-valid(d$V300,1:3))
  if(s$union_items=='L2') union <- cbind(union,5-2*valid(d$V166,1:2))
  out$UNION <- index_mean(union,s$item_rule)
  product <- valid(d$V41,if(s$neither=='L0') 1:3 else 1:4)
  out$PRODUCT <- as.numeric(product==1); out$SERVICE <- as.numeric(product==2)
  comp <- valid(d$V328,1:4)
  out$COMPET <- switch(s$competition,L0=comp,L1=as.numeric(comp==4),L2=as.numeric(comp>=3))
  out$industry <- industry_groups(d$V43,crosswalk,s$industry)
  out$weight <- if(s$weights=='L1') d$WEIGHT else rep(1,nrow(d))
  out$weight[!is.finite(out$weight) | out$weight<=0] <- NA_real_
  out$market <- d$V8 %in% 1 & (s$market_sample=='L0' | d$V9 %in% 4)
  for(v in names(out)) if(is.numeric(out[[v]])) out[[v]][!is.finite(out[[v]])] <- NA_real_
  list(data=out,staff=staff,train=train,clean=d,raw=raw,decisions=decisions)
}
family_controls <- function(family) if(family=='org') CONTROLS else setdiff(CONTROLS,'NONPROF')
outcome <- function(family) if(family=='org') 'POP' else 'PMP'
rows_for <- function(d,s,family,terms) {
  cols <- c(outcome(family),family_controls(family),terms,'industry','weight')
  ok <- complete.cases(d[,cols,drop=FALSE])
  if(family=='mkt') {
    ok <- ok & d$market
    if(s$market_requires_pop=='L1') ok <- ok & !is.na(d$POP)
  }
  which(ok)
}
z_scores <- function(items, ref, population=FALSE) {
  ans <- items
  for(j in seq_len(ncol(items))) {
    v <- items[ref,j]; v <- v[is.finite(v)]; mu <- mean(v)
    sdv <- if(population && length(v)) sqrt(mean((v-mu)^2)) else sd(v)
    ans[,j] <- if(length(v)<2 || !is.finite(sdv) || sdv==0) NA_real_ else (items[,j]-mu)/sdv
  }
  ans
}
family_data <- function(b,s,family) {
  d <- b$data; frame <- seq_len(nrow(d)); ref <- frame
  if(s$z_reference %in% c('L1','L2')) ref <- rows_for(d,s,if(s$z_reference=='L1') 'org' else family,HRM)
  for(v in c('STAFF','TRAIN')) {
    items <- b[[tolower(v)]]
    z <- z_scores(items,frame,s$z_reference=='L3')
    if(s$z_reference %in% c('L1','L2')) {
      own <- z_scores(items,ref); z[ref,] <- own[ref,,drop=FALSE]
    }
    d[[v]] <- index_mean(z,s$item_rule)
  }
  attr(d,'z_reference_rows') <- ref; d
}
model_defs <- function(family) {
  a <- setdiff(HRM,'VHIER'); b <- setdiff(HRM,'ILM'); prefix <- if(family=='org') 'org_' else 'mkt_'
  nums <- if(family=='org') 1:5 else 6:10
  defs <- list(list(id=paste0(prefix,'base'),terms=character(),inter=character()))
  for(p in HRM) defs[[length(defs)+1]] <- list(id=paste0(prefix,'M',nums[1],'_',p),terms=p,inter=character())
  for(j in 2:5) defs[[length(defs)+1]] <- list(id=paste0(prefix,'M',nums[j]),terms=if(j %in% c(2,4)) a else b,
    inter=if(j<4) character() else c('TRAIN_x_STAFF','GRIEV_x_INCENT',if(j==4) 'ILM_x_DECENT' else 'VHIER_x_DECENT'))
  defs
}
industry_schema <- function(groups,check=NULL) {
  tab <- table(groups); if(!length(tab)) return(list(reference=NA_character_,groups=character()))
  codes <- names(tab); ord <- order(ifelse(codes=='UNCL',Inf,as.numeric(replace(codes,codes=='UNCL',NA))),na.last=TRUE)
  codes <- codes[ord]; counts <- as.numeric(tab[codes])
  ref <- if(identical(check,'industry_ref_alt')) tail(codes[counts==min(counts)],1) else codes[counts==max(counts)][1]
  list(reference=ref,groups=setdiff(codes,ref))
}
design_matrix <- function(d,rows,def,family,s,schema) {
  sub <- d[rows,,drop=FALSE]
  x <- cbind('(Intercept)'=rep(1,length(rows)),as.matrix(sub[,c(family_controls(family),def$terms),drop=FALSE]))
  for(v in def$inter) {
    pair <- INTERACTIONS[[v]]; a <- sub[[pair[1]]]; b <- sub[[pair[2]]]
    if(s$centering=='L1') {a <- a-mean(a); b <- b-mean(b)}
    x <- cbind(x,a*b); colnames(x)[ncol(x)] <- v
  }
  for(g in schema$groups) {x <- cbind(x,as.numeric(sub$industry==g)); colnames(x)[ncol(x)] <- paste0('IND_',g)}
  x
}
empty_coefs <- function(terms) {
  cols <- c('estimate','se','t','df','p_two','p_upper','p_lower','se_hc3','t_hc3','p_two_hc3','p_upper_hc3','p_lower_hc3')
  data.frame(term=terms,as.data.frame(setNames(rep(list(rep(NA_real_,length(terms))),length(cols)),cols)))
}
fit_model <- function(x,y,w=rep(1,length(y))) {
  n <- length(y); dropped <- character(); k <- NA_integer_
  failure <- function(msg) list(status='failed',error=msg,n=n,k=k,dropped=dropped,
    n_industry_dummies=NA_integer_,coef=empty_coefs(colnames(x)),x=x,y=y,w=w)
  if(!n) return(failure('No complete cases'))
  if(any(!is.finite(x)) || any(!is.finite(y)) || any(!is.finite(w)) || any(w<=0)) return(failure('Nonfinite design/outcome or invalid weights'))
  # Protect substantive terms. Only industry columns may be dropped for aliasing.
  keep <- which(!startsWith(colnames(x),'IND_')); xw <- x*sqrt(w)
  rank_of <- function(z) qr(z,tol=1e-9,LAPACK=FALSE)$rank
  if(rank_of(xw[,keep,drop=FALSE])<length(keep)) return(failure('Rank-deficient non-industry terms'))
  for(j in which(startsWith(colnames(x),'IND_'))) {
    if(rank_of(xw[,c(keep,j),drop=FALSE])>length(keep)) keep <- c(keep,j) else dropped <- c(dropped,colnames(x)[j])
  }
  x <- x[,keep,drop=FALSE]; xw <- x*sqrt(w); k <- ncol(x)
  if(n<=k) return(failure('No positive residual degrees of freedom'))
  fit <- tryCatch(lm.wfit(x,y,w,tol=1e-9),error=function(e)e)
  if(inherits(fit,'error')) return(failure(conditionMessage(fit)))
  if(fit$rank!=k) return(failure('Numerical rank deficiency'))
  df <- n-k; e <- fit$residuals; rss <- sum(w*e^2)
  tss <- sum(w*(y-weighted.mean(y,w))^2); r2 <- if(tss>0) 1-rss/tss else NA_real_
  adj <- 1-(1-r2)*(n-1)/df
  f <- if(k>1 && tss>0) max(0,(tss-rss)/(k-1))/(rss/df) else NA_real_
  # lm.wfit uses pivoted QR; undo pivot for covariance and use weighted leverage.
  invp <- order(fit$qr$pivot)
  bread <- chol2inv(qr.R(fit$qr))[invp,invp,drop=FALSE]
  se <- sqrt(pmax(0,diag(bread)*rss/df)); h <- rowSums(qr.Q(fit$qr)^2)
  note <- ''
  if(any(1-h <= 1e-12)) {sehc <- rep(NA_real_,k); note <- 'HC3 undefined: leverage equals one'} else {
    a <- xw * (sqrt(w)*e/(1-h)); hc <- bread %*% crossprod(a) %*% bread
    sehc <- sqrt(pmax(0,diag(hc)))
  }
  co <- empty_coefs(colnames(x)); co$estimate <- unname(fit$coefficients); co$se <- se; co$t <- co$estimate/se; co$df <- df
  co$p_two <- 2*pt(-abs(co$t),df); co$p_upper <- pt(co$t,df,lower.tail=FALSE); co$p_lower <- pt(co$t,df)
  co$se_hc3 <- sehc; co$t_hc3 <- co$estimate/sehc
  co$p_two_hc3 <- 2*pt(-abs(co$t_hc3),df); co$p_upper_hc3 <- pt(co$t_hc3,df,lower.tail=FALSE); co$p_lower_hc3 <- pt(co$t_hc3,df)
  list(status='ok',error='',note=note,n=n,k=k,n_industry_dummies=sum(startsWith(colnames(x),'IND_')),dropped=dropped,
       r2=r2,adj_r2=adj,f=f,f_df1=k-1,f_df2=df,f_p=pf(f,k-1,df,lower.tail=FALSE),coef=co,rss=rss,df=df,x=x,y=y,w=w,
       fitted=fit$fitted.values)
}
nested_stat <- function(full,restricted,q) {
  if(full$status!='ok' || restricted$status!='ok') stop('Nested fit failed: ',paste(c(full$error,restricted$error),collapse='; '))
  if(full$n!=restricted$n || !identical(full$y,restricted$y) || !identical(full$w,restricted$w)) stop('Nested fits have different rows')
  if(full$k-restricted$k!=q) stop('Added terms are not all estimable (rank increment differs from nominal df)')
  if(qr(cbind(full$x,restricted$x),tol=1e-9)$rank>full$k) stop('Restricted design is not nested')
  f <- max(0,restricted$rss-full$rss)/q/(full$rss/full$df)
  list(n=full$n,delta_r2=full$r2-restricted$r2,f=f,df1=q,df2=full$df,p=pf(f,q,full$df,lower.tail=FALSE))
}
leave_one_out <- function(x,y,w,ids,terms,model_id) {
  res <- vector('list',length(ids))
  for(i in seq_along(ids)) {
    fit <- fit_model(x[-i,,drop=FALSE],y[-i],w[-i]); c <- fit$coef[match(terms,fit$coef$term),,drop=FALSE]
    note <- paste(c(if(fit$status=='failed') fit$error else fit$note,
                    if(length(fit$dropped)) paste('dropped',paste(fit$dropped,collapse=';'))),collapse='; ')
    res[[i]] <- data.frame(model_id=model_id,deleted_V1=ids[i],term=terms,estimate=c$estimate,se=c$se,
                           p_upper=c$p_upper,p_two=c$p_two,status=fit$status,note=note)
  }
  if(length(res)) do.call(rbind,res) else NULL
}
OUTPUT_COLUMNS <- list(
 coefficients=c('spec_id','family','model_id',names(empty_coefs(character()))),
 model_stats=c('spec_id','family','model_id','status','error','n','k','n_industry_dummies','dropped_columns','r2','adj_r2','f','f_df1','f_df2','f_p'),
 nested_tests=c('spec_id','family','test_id','full_model','restricted_model','n','delta_r2','f','df1','df2','p'),
 samples=c('spec_id','family','model_id','V1'),
 influence=c('model_id','deleted_V1','term','estimate','se','p_upper','p_two','status','note'))
INTERPRETATIONS <- c(
 'Crosswalk accepts comma and semicolon delimiters, preserving printed order and zero-padding SIC to two digits.',
 'System-missing or declared-missing V43 maps to UNCL under industry L0 and missing under L1.',
 'SUBSID L0 preserves missing V17; L1/L2 independent establishments (V17=2) override missing V21 to zero. Otherwise missing V21 remains missing.',
 'Training routing overrides inconsistent stored V157/V172 whenever V145=2; no other unstated routing is imposed.',
 'Copy validity is evaluated per source item after metadata and domain/STAFF-level exclusions, before transformation; declared-missing routing codes are not system-missing.',
 'CHK_hierarchy_log10 uses log10 of the top-code-adjusted hierarchy count (ln(count)/ln(10)), consistent with the stipulated algebraic invariance.',
 'CHK_industry_ref_alt omits the least frequent group (highest code breaks ties); ordinary reference omits the most frequent (lowest code breaks ties). UNCL sorts after numeric codes.',
 'With case_scope L1, family industry schema/reference is selected on base-model complete cases and reused for every model and nested refit.',
 'Z reference membership uses pre-standardization item validity and all seven HRM indices, outcome, controls, industry, family restrictions and positive weights. L1/L2 retain L0 scores outside reference rows exactly as specified.',
 'If combining case_scope L1 and z_reference L1/L2 (not present in the frozen grid), the reference is the family common complete-case sample.',
 'Zero/undefined reference SD makes that standardized item missing; reference membership is not iteratively recomputed. Partial indices may use the remaining items.',
 'Centering uses unweighted arithmetic means in each model sample, including WLS; standard-score moments are also unweighted.',
 'Categorical items outside specified valid domains are missing; numeric raw counts/age follow the stated restrictions only. Record filtering drops raw V3=0 and retains missing V3.',
 'Only industry columns may be dropped for collinearity; non-industry rank deficiency fails the model. Industry columns are considered in increasing code order after all substantive terms; QR tolerance is 1e-9.',
 'Parameter count is estimable columns including intercept; adjusted R2 uses 1-(1-R2)*(n-1)/(n-k). WLS HC3 uses sqrt(weight) times design and residuals.',
 'HC3 is NA when leverage reaches one (within 1e-12); this is recorded as a diagnostic warning without invalidating conventional statistics.',
 'Nested tests use nominal added-term df (6 or 3); if effective rank increment differs they fail explicitly in run_info, with NA statistics in nested_tests.',
 'Failed models have explicit model_stats entries and NA coefficient rows for intended columns. Failed nested tests have NA rows and run_info reasons. Samples include complete-case rows even if the fit fails.',
 'Influence uses explicit refits and fixed original design columns (including original industry reference); newly empty/aliased industry columns are dropped. Every deletion/HRM term is retained, even on failure. An empty sample has no possible deletions.',
 'Missing numeric CSV values are NA; empty strings mean no error/drop/note. JSON missing values are null. No scientific interpretation of development results is made.')
run_grid <- function(data_path,metadata_path,crosswalk_path,grid_path,out_dir) {
  dir.create(out_dir,recursive=TRUE,showWarnings=FALSE)
  start <- format(Sys.time(),tz='UTC',usetz=TRUE)
  info <- list(software='R',versions=list(R=R.version.string,jsonlite=as.character(packageVersion('jsonlite'))),
               start_time=start,end_time=NULL,specs_run=list(),failures=list(),warnings=list(),
               interpretations=INTERPRETATIONS,unimplemented=list(),industry_references=list())
  for(nm in names(OUTPUT_COLUMNS)) {
    empty <- as.data.frame(setNames(rep(list(character()),length(OUTPUT_COLUMNS[[nm]])),OUTPUT_COLUMNS[[nm]]))
    write.table(empty,file.path(out_dir,paste0(nm,'.csv')),sep=',',row.names=FALSE,col.names=TRUE,na='NA')
  }
  emit <- function(name,d) {
    if(is.null(d) || !nrow(d)) return(invisible(NULL))
    write.table(d[,OUTPUT_COLUMNS[[name]],drop=FALSE],file.path(out_dir,paste0(name,'.csv')),
                sep=',',append=TRUE,row.names=FALSE,col.names=FALSE,na='NA',qmethod='double')
  }
  fail <- function(spec,family,model,reason,kind='model') {
    info$failures[[length(info$failures)+1L]] <<- list(spec_id=spec,family=family,model_id=model,kind=kind,reason=reason)
  }
  save_info <- function() {
    info$end_time <<- format(Sys.time(),tz='UTC',usetz=TRUE)
    jsonlite::write_json(info,file.path(out_dir,'run_info.json'),pretty=TRUE,auto_unbox=TRUE,na='null',null='null',digits=16)
  }
  on.exit(save_info(),add=TRUE)
  input <- tryCatch({
    raw <- read.csv(data_path,check.names=FALSE,na.strings=c('','NA'),colClasses='numeric')
    missing <- setdiff(REQUIRED,names(raw)); if(length(missing)) stop('Missing survey columns: ',paste(missing,collapse=','))
    if(anyNA(raw$V1) || anyDuplicated(raw$V1)) stop('V1 must be nonmissing and unique')
    raw <- raw[,REQUIRED,drop=FALSE]
    metadata <- jsonlite::fromJSON(metadata_path,simplifyVector=FALSE)
    if(!all(REQUIRED %in% vapply(metadata$variables,`[[`,character(1),'name'))) stop('Metadata missing required variables')
    cw <- read.csv(crosswalk_path,colClasses='character',check.names=FALSE,na.strings='')
    if(!all(c('census1980_code','sic2_from_printed') %in% names(cw))) stop('Missing crosswalk columns')
    grid <- jsonlite::fromJSON(grid_path,simplifyVector=FALSE)
    ids <- vapply(grid$specs,`[[`,character(1),'spec_id'); order <- unlist(grid$compute_order)
    if(anyDuplicated(ids) || anyDuplicated(order) || !setequal(ids,order)) stop('Invalid compute_order/spec IDs')
    list(raw=raw,metadata=metadata,cw=cw,grid=grid,ids=ids,order=order)
  },error=function(e)e)
  if(inherits(input,'error')) {fail(NA,NA,NA,conditionMessage(input),'input'); stop(conditionMessage(input))}
  for(id in input$order) {
    spec <- input$grid$specs[[match(id,input$ids)]]; s <- spec$settings
    info$specs_run[[length(info$specs_run)+1]] <- id
    message('Running ',id)
    built <- tryCatch(build_variables(input$raw,input$metadata,input$cw,s,spec$check),error=function(e)e)
    if(inherits(built,'error')) fail(id,NA,NA,conditionMessage(built),'spec')
    for(family in c('org','mkt')) {
      defs <- model_defs(family)
      prepared <- tryCatch({
        if(inherits(built,'error')) stop(conditionMessage(built))
        d <- family_data(built,s,family)
        common <- rows_for(d,s,family,HRM)
        schema_rows <- if(s$case_scope=='L0') common else rows_for(d,s,family,character())
        schema <- industry_schema(d$industry[schema_rows],spec$check)
        list(d=d,common=common,schema=schema)
      },error=function(e)e)
      results <- list(); matrices <- list(); rowsets <- list()
      if(!inherits(prepared,'error')) {
        d <- prepared$d; common <- prepared$common; schema <- prepared$schema
        info$industry_references[[paste(id,family,sep='/')]] <- schema$reference
        if(s$case_scope=='L0' && length(common)) emit('samples',data.frame(spec_id=id,family=family,model_id='ALL',V1=d$V1[common]))
      }
      for(def in defs) {
        mid <- def$id
        attempt <- tryCatch({
          if(inherits(prepared,'error')) stop(conditionMessage(prepared))
          rows <- if(s$case_scope=='L0') common else rows_for(d,s,family,def$terms)
          x <- design_matrix(d,rows,def,family,s,schema)
          list(rows=rows,x=x,fit=fit_model(x,d[[outcome(family)]][rows],d$weight[rows]))
        },error=function(e)e)
        if(inherits(attempt,'error')) {
          terms <- c('(Intercept)',family_controls(family),def$terms,def$inter)
          fit <- list(status='failed',error=conditionMessage(attempt),n=NA_integer_,k=NA_integer_,
                      n_industry_dummies=NA_integer_,dropped=character(),coef=empty_coefs(terms))
        } else {
          fit <- attempt$fit; matrices[[mid]] <- attempt$x; rowsets[[mid]] <- attempt$rows
          if(s$case_scope=='L1' && length(attempt$rows)) emit('samples',data.frame(spec_id=id,family=family,model_id=mid,V1=d$V1[attempt$rows]))
        }
        results[[mid]] <- fit
        if(fit$status=='failed') fail(id,family,mid,fit$error)
        if(nzchar(fit$note %||% '')) info$warnings[[length(info$warnings)+1]] <- list(spec_id=id,family=family,model_id=mid,note=fit$note)
        emit('coefficients',cbind(data.frame(spec_id=id,family=family,model_id=mid),fit$coef))
        stats <- list(spec_id=id,family=family,model_id=mid,status=fit$status,error=fit$error,n=fit$n,k=fit$k,
                      n_industry_dummies=fit$n_industry_dummies,dropped_columns=paste(fit$dropped,collapse=';'))
        for(v in c('r2','adj_r2','f','f_df1','f_df2','f_p')) stats[[v]] <- fit[[v]] %||% NA_real_
        emit('model_stats',as.data.frame(stats))
        if(spec$type=='origin' && length(def$terms)==6 && !is.null(matrices[[mid]])) {
          rows <- rowsets[[mid]]
          infl <- leave_one_out(matrices[[mid]],d[[outcome(family)]][rows],d$weight[rows],d$V1[rows],c(def$terms,def$inter),mid)
          emit('influence',infl)
          if(!is.null(infl)) for(v in unique(infl$deleted_V1[infl$status=='failed'])) {
            reason <- infl$note[match(v,infl$deleted_V1)]; fail(id,family,mid,paste('deleted V1',v,reason),'influence')
          }
        }
      }
      # defs 9:12 are A, B, A+int, B+int; restricted models must use full rows.
      for(pair in list(c(9,1),c(10,1),c(11,9),c(12,10))) {
        full_def <- defs[[pair[1]]]; rest_def <- defs[[pair[2]]]
        q <- if(pair[2]==1) 6 else 3
        test_id <- paste0(if(q==6) 'HRM_' else 'interaction_',full_def$id)
        test <- tryCatch({
          full <- results[[full_def$id]]
          if(full$status!='ok') stop('Full model failed: ',full$error)
          rows <- rowsets[[full_def$id]]
          # Same original family dummy coding; same rows and fixed standard scores.
          xr <- design_matrix(d,rows,rest_def,family,s,schema)
          restricted <- fit_model(xr,d[[outcome(family)]][rows],d$weight[rows])
          nested_stat(full,restricted,q)
        },error=function(e)e)
        if(inherits(test,'error')) {
          fail(id,family,test_id,conditionMessage(test),'nested')
          test <- list(n=results[[full_def$id]]$n,delta_r2=NA_real_,f=NA_real_,df1=q,df2=NA_real_,p=NA_real_)
        }
        emit('nested_tests',as.data.frame(c(list(spec_id=id,family=family,test_id=test_id,full_model=full_def$id,restricted_model=rest_def$id),test)))
      }
    }
    save_info()
  }
  info$output_counts <- setNames(lapply(names(OUTPUT_COLUMNS),function(nm) nrow(read.csv(file.path(out_dir,paste0(nm,'.csv'))))),names(OUTPUT_COLUMNS))
  save_info(); invisible(info)
}
main <- function() {
  args <- commandArgs(trailingOnly=TRUE)
  if(length(args)!=10 || any(!args[seq(1,10,2)] %in% c('--data','--metadata','--crosswalk','--grid','--out')) || anyDuplicated(args[seq(1,10,2)]))
    stop('Usage: Rscript code/run_grid.R --data survey.csv --metadata metadata.json --crosswalk crosswalk.csv --grid grid.json --out output_dir')
  a <- setNames(as.list(args[seq(2,10,2)]),sub('^--','',args[seq(1,10,2)]))
  run_grid(a$data,a$metadata,a$crosswalk,a$grid,a$out)
}
if(sys.nframe()==0) main()
