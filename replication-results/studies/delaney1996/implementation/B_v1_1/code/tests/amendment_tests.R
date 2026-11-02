# Additional deterministic v1.1 regression tests, sourced by run_tests.R.
# A1: independent weighted normal-equation HC3, singleton and threshold boundary.
set.seed(1141)
xx <- cbind('(Intercept)'=1,STAFF=rnorm(30),IND_01=c(1,rep(0,29)))
yy <- rnorm(30)
for(weighted in c(FALSE,TRUE)) {
  ww <- if(weighted) seq_len(30)/7 else rep(1,30)
  for(deletion in c(0L,1L,7L)) {
    ix <- if(deletion==0L) 1:30 else setdiff(1:30,deletion)
    xm <- xx[ix,,drop=FALSE]; if(deletion==1L) xm <- xm[,1:2]
    f <- fit_model(xm,yy[ix],ww[ix]); xw <- xm*sqrt(ww[ix])
    bread <- solve(crossprod(xw)); beta <- bread %*% crossprod(xw,yy[ix]*sqrt(ww[ix]))
    residual <- as.vector(yy[ix]-xm%*%beta)
    h <- rowSums((xw%*%bread)*xw); keep <- h<1-1e-8
    meat <- crossprod(xw[keep,,drop=FALSE]*(sqrt(ww[ix][keep])*residual[keep]/(1-h[keep])))
    expected <- sqrt(pmax(0,diag(bread%*%meat%*%bread)))
    eq(f$coef$se_hc3,expected,paste('A1 hand HC3',weighted,deletion))
    eq(f$n_leverage_one,if(deletion==1L) 0L else 1L,paste('A1 leverage count',weighted,deletion))
    ref <- summary(lm(yy[ix]~xm-1,weights=ww[ix]))
    eq(f$coef$se,ref$coef[,2],paste('A1 conventional SE unchanged',weighted,deletion))
  }
}
for(target_gap in c(5e-9,2e-8)) {
  # Centered slope with one dominant row: h[1] = 1/n + A^2/(A^2*n/(n-1)+2).
  nn <- 12; A2 <- 2/(1/(1-target_gap-1/nn)-nn/(nn-1))
  slope <- c(sqrt(A2),rep(-sqrt(A2)/(nn-1),nn-1)); slope[2:3] <- slope[2:3]+c(1,-1)
  near <- fit_model(cbind('(Intercept)'=1,STAFF=slope),sin(1:nn))
  eq(near$n_leverage_one,as.integer(target_gap<1e-8),paste('A1 threshold',target_gap))
  ok(all(is.finite(near$coef$se_hc3)),paste('A1 near-one finite HC3',target_gap))
}
# A2/checker 1: declarations as both values and ranges, across assigned levels.
for(declaration in c('values','ranges')) {
  md <- list(variables=lapply(c('V157','V261','V62','V97','V131'),function(v) {
    code <- if(v=='V157') 99996 else if(v=='V261') 96 else 995
    list(name=v,declared_missing_values=if(declaration=='values') list(code) else list(),
         declared_missing_ranges=if(declaration=='ranges') list(c(code,code+1)) else list())
  }))
  raw <- fixture(); raw$V145 <- 1; raw$V157[1:2] <- c(99996,99997); raw$V261[1:2] <- c(96,97)
  for(v in c('V62','V97','V131')) raw[[v]][1:2] <- c(995,996)
  for(level in c('L0','L1','L2')) {
    settings <- s0; settings$hierarchy <- level; settings$staff_coding <- level
    b <- build_variables(raw,md,cw,settings)
    eq(b$train[1,'V157'],log(100000),paste('A2 TRAIN override',declaration,level))
    eq(b$data$VHIER[1],switch(level,L0=log(100),L1=NA_real_,L2=100),paste('A2 hierarchy override',declaration,level))
    eq(b$staff[1,],rep(if(level=='L2') log(995) else NA_real_,3),paste('A2 STAFF override',declaration,level))
    ok(all(is.na(b$staff[2,])),paste('A9 STAFF 996 excluded',declaration,level))
    if(declaration=='ranges') ok(is.na(b$train[2,'V157']) && is.na(b$data$VHIER[2]),paste('A2 other range codes stay missing',level))
  }
}
# A4/A9: declared identifier inputs obey metadata; system-missing routes stay missing.
raw <- fixture(); raw$V17[1:3] <- c(NA,2,1); raw$V21[1:3] <- c(2,9,2)
for(level in c('L0','L1','L2')) {
  z <- build(raw,'subsidiary',level)$data
  ok(is.na(z$SUBSID[1]) && is.na(z$DECENT[1]) && z$SUBSID[2]==0,paste('A4/A9 routing',level))
}
md <- list(variables=lapply(c('V8','V17','V43','WEIGHT'),function(v)
  list(name=v,declared_missing_values=list(if(v=='V43') 10 else if(v=='WEIGHT') 0 else 1),declared_missing_ranges=list())))
raw <- fixture(); raw$WEIGHT[1] <- 0
settings <- s0; settings$weights <- 'L1'
z <- build_variables(raw,md,cw,settings)$data
ok(all(is.na(z$NONPROF)) && !any(z$market),'A9 V8 declaration excludes market')
ok(all(is.na(z$SUBSID)) && all(is.na(z$DECENT)),'A9 V17 declaration routes to missing')
ok(all(is.na(z$industry)) && is.na(z$weight[1]),'A9 V43 and WEIGHT declarations')
# A7: invalid CORE never replaces valid GSS on system-missing V79; manager falls back.
raw <- fixture(); raw$V79 <- NA; raw$V114 <- NA
raw$V62[1:8] <- c(0,995:999,42,NA); raw$V97 <- 12; raw$V131 <- 20
md <- list(variables=list(list(name='V62',declared_missing_values=list(42),declared_missing_ranges=list())))
for(level in c('L0','L1','L2')) {
  settings <- s0; settings$item_rule <- 'L2'; settings$staff_coding <- level
  cp <- build_variables(raw,md,cw,settings)$clean
  expected <- rep(12,8); if(level=='L1') expected[1] <- 0; if(level=='L2') expected[2] <- 995
  eq(cp$V97[1:8],expected,paste('A7 valid-only GSS copy',level))
  eq(cp$V131[1:8],expected,paste('A7 valid-only manager fallback',level))
}
raw$V62 <- 0; raw$V79 <- 2
settings <- s0; settings$item_rule <- 'L2'
cp <- build_variables(raw,md,cw,settings)$clean
ok(all(is.na(cp$V97)) && all(is.na(cp$V131)),'A7 explicit same occupation cannot copy invalid CORE')
# A5/A6/A10: allowed drops precede df check and survive later failures.
xd <- cbind('(Intercept)'=1,STAFF=1:4,IND_01=0,IND_02=1:4,IND_03=1)
f <- fit_model(xd,c(2,4,5,9))
ok(f$status=='ok' && f$df==2 && length(f$dropped)==3,'A5 drops before df check')
f <- fit_model(xd[1:2,],c(2,4))
ok(f$status=='failed' && length(f$dropped)==3 && grepl('degrees',f$error),'A6 drops retained on df failure')
f <- fit_model(cbind(xd,TRAIN=1:4),c(2,4,5,9))
ok(f$status=='failed' && length(f$dropped)==3 && grepl('non-industry',f$error),'A6 drops retained on substantive failure')
lf <- leave_one_out(xd,c(2,4,5,9),rep(1,4),1:4,'STAFF','drops')
ok(all(lf$status=='ok') && all(grepl('IND_01',lf$note)),'A10 refits drop before df check')
original <- fit_model(cbind(xd,TRAIN=1:4),c(2,4,5,9))
lf <- leave_one_out(cbind(xd,TRAIN=1:4),c(2,4,5,9),rep(1,4),1:4,c('STAFF','TRAIN'),'failed_original',original)
ok(nrow(lf)==8 && all(lf$status=='failed') && all(is.na(lf$estimate)) && all(grepl('Original model failed',lf$note)),
   'A6 failed original retains every deletion/term with reason')
ff <- fit_model(cbind('(Intercept)'=1,STAFF=1:12,TRAIN=sin(1:12)),cos(1:12))
rr <- fit_model(ff$x[,1:2],ff$y)
err <- tryCatch(nested_stat(ff,rr,6),error=function(e) conditionMessage(e))
ok(is.character(err) && grepl('rank increment',err),'A5 nominal nested df mismatch fails')
# A8: zero SD may invalidate scores but must never shrink the already fixed sample.
raw <- fixture(); raw$V8[1] <- 2; raw$V41[2] <- 4
raw$V62 <- raw$V97 <- raw$V131 <- 5
for(level in c('L1','L2')) for(family in c('org','mkt')) {
  settings <- s0; settings$z_reference <- level
  b <- build_variables(raw,metadata,cw,settings)
  expected <- rows_for(b$data,settings,family,HRM)
  z <- family_data(b,settings,family)
  eq(rows_for(z,settings,family,HRM),expected,paste('A8 fixed estimation membership',level,family))
  eq(attr(z,'z_reference_rows'),rows_for(b$data,settings,if(level=='L1') 'org' else family,HRM),paste('A8 fixed reference',level,family))
  ok(all(is.na(z$STAFF)),paste('A8 undefined scores fixture',level,family))
  def <- model_defs(family)[[9]]
  f <- fit_model(design_matrix(z,expected,def,family,settings,industry_schema(z$industry[expected])),z[[outcome(family)]][expected])
  ok(f$status=='failed' && f$n==length(expected) && grepl('Nonfinite',f$error),paste('A8 explicit failure retains N',level,family))
}
# A6/A10 integration: inject fit failures to reach rare runner logging branches.
# The complete frozen grid is read unchanged; no specifications are added.
runner <- new.env(parent=globalenv()); sys.source('code/run_grid.R',envir=runner)
set.seed(611)
nn <- 45; derived <- as.data.frame(matrix(rnorm(nn*(length(HRM)+length(CONTROLS))),nn))
names(derived) <- c(HRM,CONTROLS)
derived$POP <- rnorm(nn); derived$PMP <- rnorm(nn); derived$V1 <- 1:nn
derived$weight <- 1; derived$industry <- rep(c('01','02'),length.out=nn); derived$market <- TRUE
runner$build_variables <- function(...) list(data=derived)
runner$family_data <- function(b,...) b$data
real_fit <- runner$fit_model
runner$fit_model <- function(x,y,w=rep(1,length(y))) {
  f <- real_fit(x,y,w)
  reason <- if(!any(HRM %in% colnames(x))) 'Injected restricted/base failure' else
    if('ILM' %in% colnames(x)) 'Injected original failure' else
      if(length(y)==nn-1) 'Injected deletion failure' else NULL
  if(!is.null(reason)) {f$status <- 'failed'; f$error <- reason; f$coef <- empty_coefs(colnames(x))}
  f
}
integration_dir <- file.path(test_out,'failure_fixture')
run <- runner$run_grid('data/survey.csv','data/survey_metadata.json','data/industry_crosswalk.csv','grid_v1.json',integration_dir)
inf <- read.csv(file.path(integration_dir,'influence.csv'),na.strings='NA')
for(mid in c('org_M2','org_M4','mkt_M7','mkt_M9')) {
  zz <- inf[inf$model_id==mid,]
  ok(setequal(zz$deleted_V1,1:nn) && all(zz$status=='failed') && all(grepl('Original model failed',zz$note)),paste('A6 runner original failure',mid))
}
for(mid in c('org_M3','org_M5','mkt_M8','mkt_M10')) {
  zz <- inf[inf$model_id==mid,]
  ok(setequal(zz$deleted_V1,1:nn) && all(zz$status=='failed') && all(grepl('Injected deletion failure',zz$note)),paste('A10 runner deletion failure',mid))
}
failures <- jsonlite::fromJSON(file.path(integration_dir,'run_info.json'),simplifyVector=FALSE)$failures
for(kind in c('restricted','influence','nested','model'))
  ok(any(vapply(failures,function(f) f$kind==kind && nzchar(f$reason),logical(1))),paste('A6/A10 logged failure kind',kind))
eq(sum(vapply(failures,function(f) f$kind=='influence',logical(1))),nn*8,'A10 every failed deletion logged once')
restricted_failures <- Filter(function(f) f$kind=='restricted',failures)
ok(all(vapply(restricted_failures,function(f) grepl('Injected restricted/base failure',f$reason),logical(1))),
   'A6 restricted failure reasons preserved')
failed_nt <- read.csv(file.path(integration_dir,'nested_tests.csv'),na.strings='NA')
ok(any(is.na(failed_nt$f)) && all(failed_nt$df1==ifelse(startsWith(failed_nt$test_id,'HRM_'),6,3)),
   'A5 failed nested records retain nominal numerator df')
raw_csv <- readLines(file.path(integration_dir,'nested_tests.csv'))
ok(any(grepl(',NA,',raw_csv)), 'A6 CSV missing values written as NA')
