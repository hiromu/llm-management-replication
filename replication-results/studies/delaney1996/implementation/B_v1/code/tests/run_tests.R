#!/opt/homebrew/bin/Rscript
source('code/run_grid.R')
dir.create('code/dev_out',recursive=TRUE,showWarnings=FALSE)
checks <- 0L
ok <- function(condition,label) {if(!isTRUE(condition)) stop('FAILED: ',label); checks <<- checks+1L; cat('PASS ',label,'\n',sep='')}
eq <- function(a,b,label,tol=1e-8) ok(isTRUE(all.equal(unname(a),unname(b),tolerance=tol,check.attributes=FALSE)),label)
metadata <- jsonlite::fromJSON('data/survey_metadata.json',simplifyVector=FALSE)
grid <- jsonlite::fromJSON('grid_v1.json',simplifyVector=FALSE)
s0 <- grid$specs[[1]]$settings
cw <- data.frame(census1980_code=c('010','020','030','040','050'),sic2_from_printed=c('01','02,03','04;05','','06'))
fixture <- function(n=12) {
  d <- as.data.frame(setNames(rep(list(rep(1,n)),length(REQUIRED)),REQUIRED))
  d$V1 <- seq_len(n); d$V3 <- 1; d$V8 <- 1; d$V9 <- 4; d$V16 <- 1980
  d$V17 <- 1; d$V21 <- 2; d$V23 <- 100; d$V32 <- 20; d$NEWTOTAL <- 150
  d$V41 <- 3; d$V43 <- 10; d$V114 <- 1; d$V115 <- 5; d$V79 <- 1
  d$V62 <- seq_len(n)+1; d$V97 <- seq_len(n)+2; d$V131 <- seq_len(n)+3
  d$V145 <- rep(c(1,2),length.out=n); d$V157 <- seq_len(n)*5
  d$V172 <- rep(1:3,length.out=n); d$V261 <- seq_len(n)+1; d$WEIGHT <- seq_len(n)/3
  d
}
build <- function(d=fixture(),axis=NULL,level=NULL,check=NULL) {
  s <- s0; if(!is.null(axis)) s[[axis]] <- level
  build_variables(d,metadata,cw,s,check)
}
# Estimation: base lm, hand formula, sandwich, exact known coefficients.
set.seed(713)
n <- 80; a <- rnorm(n); b <- rnorm(n); x <- cbind('(Intercept)'=1,STAFF=a,TRAIN=b)
e <- qr.resid(qr(x),rnorm(n)); y <- as.vector(x %*% c(2,1.5,-0.7)+e)
for(weighted in c(FALSE,TRUE)) {
  w <- if(weighted) exp(rnorm(n)/2) else rep(1,n)
  f <- fit_model(x,y,w); lmref <- lm(y~a+b,weights=w); sm <- summary(lmref)
  ok(f$status=='ok',paste('fit status',weighted))
  eq(f$coef$estimate,coef(lmref),paste('coefficients vs lm',weighted))
  eq(f$coef$se,sm$coefficients[,2],paste('conventional SE vs lm',weighted))
  eq(f$coef$t,sm$coefficients[,3],paste('t vs lm',weighted))
  eq(f$coef$p_two,sm$coefficients[,4],paste('two-sided p vs lm',weighted))
  eq(f$coef$p_upper,pt(f$coef$t,77,lower.tail=FALSE),paste('upper-tail p',weighted))
  eq(f$coef$p_lower,pt(f$coef$t,77),paste('lower-tail p',weighted))
  eq(f$coef$p_upper+f$coef$p_lower,rep(1,3),paste('tail complement',weighted))
  eq(f$coef$se_hc3,sqrt(diag(sandwich::vcovHC(lmref,type='HC3'))),paste('HC3 vs sandwich',weighted))
  xw <- x*sqrt(w); bread <- solve(crossprod(xw)); h <- rowSums((xw%*%bread)*xw)
  v <- bread%*%crossprod(xw*(sqrt(w)*resid(lmref)/(1-h)))%*%bread
  eq(f$coef$se_hc3,sqrt(diag(v)),paste('HC3 manual',weighted))
  eq(f$coef$t_hc3,f$coef$estimate/sqrt(diag(v)),paste('HC3 t',weighted))
  eq(f$coef$p_upper_hc3,pt(f$coef$t_hc3,77,lower.tail=FALSE),paste('HC3 upper p',weighted))
  eq(f$coef$p_lower_hc3,pt(f$coef$t_hc3,77),paste('HC3 lower p',weighted))
  eq(f$coef$p_two_hc3,2*pt(-abs(f$coef$t_hc3),77),paste('HC3 two p',weighted))
  eq(f$r2,sm$r.squared,paste('R2',weighted)); eq(f$adj_r2,sm$adj.r.squared,paste('adjusted R2',weighted))
  eq(c(f$f,f$f_df1,f$f_df2),sm$fstatistic,paste('overall F',weighted))
  rest <- fit_model(x[,1:2],y,w); nt <- nested_stat(f,rest,1); ar <- anova(lm(y~a,weights=w),lmref)
  eq(nt$f,ar$F[2],paste('nested F vs anova',weighted)); eq(nt$p,ar$`Pr(>F)`[2],paste('nested p',weighted))
  eq(nt$delta_r2,sm$r.squared-summary(lm(y~a,weights=w))$r.squared,paste('delta R2',weighted))
  if(!weighted) {eq(f$coef$estimate,c(2,1.5,-0.7),'known coefficients'); ok(f$coef$p_upper[2]<0.001 && f$coef$p_lower[3]<0.001,'directional tests')}
}
# Explicit deletions: compare every term in every refit, including weights and dummy loss.
x <- cbind(x[1:18,],IND_01=c(1,rep(0,17))); y <- y[1:18]; w <- seq_len(18)/4
loo <- leave_one_out(x,y,w,101:118,c('STAFF','TRAIN'),'toy')
for(i in 1:18) {
  keep <- setdiff(1:18,i); xx <- x[keep,,drop=FALSE]; if(i==1) xx <- xx[,1:3]
  ref <- lm(y[keep]~xx-1,weights=w[keep]); z <- loo[loo$deleted_V1==100+i,]
  eq(z$estimate,coef(ref)[2:3],paste('LOO estimate',i)); eq(z$se,summary(ref)$coef[2:3,2],paste('LOO SE',i))
  eq(z$p_two,summary(ref)$coef[2:3,4],paste('LOO two p',i))
  eq(z$p_upper,pt(summary(ref)$coef[2:3,3],df.residual(ref),lower.tail=FALSE),paste('LOO upper p',i))
}
ok(nrow(loo)==36 && grepl('IND_01',loo$note[1]),'retain deletions and flag empty dummy')
xf <- cbind('(Intercept)'=1,STAFF=c(1,0,0,0),TRAIN=c(1,2,3,4))
lf <- leave_one_out(xf,c(3,4,6,5),rep(1,4),1:4,c('STAFF','TRAIN'),'failure')
ok(nrow(lf)==8 && all(lf$status[lf$deleted_V1==1]=='failed'),'retain failed deletion rows')
ok(fit_model(xf,c(1,2,3,4))$status=='ok','finite small fit')
ok(fit_model(xf[1:3,],1:3)$status=='failed','no residual df failure')
xd <- cbind('(Intercept)'=1,STAFF=1:10,IND_01=rep(0,10),IND_02=1:10)
fd <- fit_model(xd,c(1:9,12)); eq(fd$dropped,c('IND_01','IND_02'),'zero and collinear industry drop')
ok(fit_model(cbind(xd[,1:2],TRAIN=1:10),1:10)$status=='failed','substantive collinearity fails')
# Metadata, missing ranges, system missing, and the explicit 995 override.
d <- fixture(); d$V62[1:6] <- c(0,995,996,997,998,999)
for(lev in c('L0','L1','L2')) {
  z <- build(d,'staff_coding',lev)$staff[,1]
  expected <- rep(NA_real_,6); if(lev=='L1') expected[1] <- 0; if(lev=='L2') expected[2] <- log(995)
  eq(z[1:6],expected,paste('STAFF coding',lev))
}
m <- metadata; m$variables[[1]] <- list(name='V62',declared_missing_values=list(2),declared_missing_ranges=list(c(4,6)))
c <- clean_data(fixture(),m,s0)$V62; ok(is.na(c[1]) && all(is.na(c[3:5])),'metadata discrete and range missing')
eq(index_mean(rbind(c(1,NA),c(NA,NA),c(1,3)),'L0'),c(1,NA,2),'partial index')
eq(index_mean(rbind(c(1,NA),c(NA,NA),c(1,3)),'L1'),c(NA,NA,2),'complete index')
# All reversals and categorical domains.
d <- fixture(); d[1,paste0('V',289:295)] <- c(1,2,3,4,7,8,9)
d[1,paste0('V',296:299)] <- c(1,2,7,NA)
d[1,c('V209','V222','V235')] <- c(1,2,3)
d[1,c('V67','V76','V102','V111','V136')] <- c(1,2,8,9,NA)
z <- build(d)$data
eq(z$POP[1],2.5,'POP reversal and 7/8/9'); eq(z$PMP[1],3.5,'PMP reversal and missing')
eq(z$INCENT[1],2,'INCENT reversal'); eq(z$ILM[1],1.5,'ILM reversal and missing')
ok(is.na(build(d,'item_rule','L1')$data$POP[1]),'strict POP')
d$V270[1:5] <- c(1,2,7,8,9); eq(build(d)$data$GRIEV[1:5],c(1,0,NA,NA,NA),'GRIEV codes')
# Training levels: force inconsistent routed values to be overwritten; top code and varies.
d <- fixture(); d$V145[1:5] <- c(1,2,1,1,8); d$V157[1:5] <- c(99996,500,0,99998,20); d$V172[1:5] <- c(1,2,4,3,8)
for(no in c('L0','L1','L2')) for(loglev in c('L0','L1','L2')) {
  s <- s0; s$no_training <- no; s$train_log <- loglev
  bld <- build_variables(d,metadata,cw,s); tr <- bld$train
  yes <- c(2,1); cnt <- c(100000,if(no=='L0') NA_real_ else 0); ef <- c(3,if(no=='L1') 1 else NA_real_)
  if(loglev!='L2') cnt <- safe_log(cnt,no!='L0')
  if(loglev=='L0') {yes <- log(yes); ef <- log(ef)}
  eq(tr[1:2,],cbind(yes,cnt,ef),paste('TRAIN no-training/log',no,loglev))
  ok(is.na(tr[3,3]) && is.na(tr[4,2]) && is.na(tr[5,1]),paste('TRAIN invalid items',no,loglev))
  eq(tr[3,2],if(loglev=='L2' || no!='L0') 0 else NA_real_,paste('TRAIN zero count',no,loglev))
}
# Decision routing and every map code, unknown routing.
d <- fixture(12); d$V17 <- c(rep(1,5),rep(2,5),8,2)
for(j in 271:278) d[[paste0('V',j)]] <- c(1:5,rep(2,7))
for(j in 279:286) d[[paste0('V',j)]] <- c(rep(1,5),1:5,1,6)
eq(build(d)$data$DECENT,c(3,5,1,4,2,3,5,1,4,2,NA,NA),'decision L0 and routing')
eq(build(d,'decision_map','L1')$data$DECENT,c(1,5,3,4,2,1,5,3,4,2,NA,NA),'decision L1')
for(j in 279:286) d[[paste0('V',j)]][12] <- 7
ok(is.na(build(d)$data$DECENT[12]),'decision declared NA')
# Copy all pairs, CORE fallback, true system missing vs user missing, source validity.
d <- fixture(); d$V79[1:6] <- c(2,NA,8,2,NA,1); d$V114[1:6] <- c(2,NA,8,2,NA,1)
d$V62[1:6] <- c(10,20,30,NA,995,40); d$V97[1:6] <- c(50,60,70,80,90,100)
d$V131[1:6] <- 200; d$V67 <- 1; d$V102 <- 2; d$V136 <- 2; d$V76 <- 2; d$V111 <- 1
d$V222 <- 3; d$V235 <- 1; d$V209 <- 2
cp <- build(d,'item_rule','L2')$clean
eq(cp$V97[1:6],c(10,20,70,NA,90,100),'GSS copy conditions')
eq(cp$V131[1:6],c(10,20,200,NA,90,200),'manager copy conditions and fallback')
eq(cp$V102[1:3],c(1,1,2),'ILM first GSS copy'); eq(cp$V111[1:3],c(2,2,1),'ILM second GSS copy')
eq(cp$V136[1:3],c(1,1,2),'manager ILM copy'); eq(cp$V235[1:3],c(3,3,1),'GSS INCENT copy'); eq(cp$V209[1:3],c(3,3,2),'manager INCENT copy')
eq(build(d,'item_rule','L0')$clean$V97[1:2],c(50,60),'L0 does not copy')
# Hierarchy and algebraic scaling.
d <- fixture(); d$V261[1:5] <- c(96,0,98,99,10)
eq(build(d)$data$VHIER[1:5],c(log(100),NA,NA,NA,log(10)),'hierarchy L0')
eq(build(d,'hierarchy','L1')$data$VHIER[1:5],c(NA,NA,NA,NA,log(10)),'hierarchy L1')
eq(build(d,'hierarchy','L2')$data$VHIER[1:5],c(100,0,NA,NA,10),'hierarchy L2')
eq(build(d,check='hierarchy_log10')$data$VHIER[1:5],c(2,NA,NA,NA,1),'hierarchy log10 check')
# Controls across every level.
d <- fixture(); d$V8[1:4] <- c(1,2,8,NA)
eq(build(d)$data$NONPROF[1:4],c(0,1,NA,NA),'NONPROF')
d$V17[1:6] <- c(1,1,1,1,2,NA); d$V21[1:6] <- c(1,2,3,8,9,2)
eq(build(d)$data$SUBSID[1:6],c(1,1,1,1,0,NA),'SUBSID L0')
eq(build(d,'subsidiary','L1')$data$SUBSID[1:6],c(0,1,0,NA,0,1),'SUBSID L1')
eq(build(d,'subsidiary','L2')$data$SUBSID[1:6],c(1,1,1,NA,0,1),'SUBSID L2')
d <- fixture(); d$V23[1:4] <- c(10,99998,0,30); d$V32[1:4] <- c(5,10,0,99999); d$NEWTOTAL[1:4] <- c(50,0,100,10)
eq(build(d)$data$LOGEMP[1:4],c(log(15),NA,NA,NA),'employment L0')
eq(build(d,'employment','L1')$data$LOGEMP[1:4],c(log(50),NA,log(100),log(10)),'employment L1')
eq(build(d,'employment','L2')$data$LOGEMP[1:4],c(log(10),NA,NA,log(30)),'employment L2')
d$V16[1:5] <- c(1981,1991,1992,9998,9999)
eq(build(d)$data$LOGAGE[1:5],c(log(10),NA,NA,NA,NA),'age L0')
eq(build(d,'age','L1')$data$LOGAGE[1:5],c(log(11),0,NA,NA,NA),'age L1')
eq(build(d,'age','L2')$data$LOGAGE[1:5],c(10,0,-1,NA,NA),'age L2')
d <- fixture(); d$V114[1:6] <- c(1,3,2,8,1,1); d$V115[1:6] <- c(12,15,15,15,99998,12); d$V23[6] <- 0; d$V32[6] <- 0
# Use metadata-declared code for V115 in the missing-numerator case.
md <- Filter(function(m) m$name=='V115',metadata$variables)[[1]]; d$V115[5] <- unlist(md$declared_missing_values)[1]
eq(build(d)$data$PCTMGR[1:6],c(10,0,NA,NA,NA,NA),'pct managers L0')
eq(build(d,'pct_managers','L1')$data$PCTMGR[1:3],c(10,NA,NA),'pct managers L1')
eq(build(d,'pct_managers','L2')$data$PCTMGR[1:3],c(8,0,NA),'pct managers L2')
eq(build(d,check='pct_proportion')$data$PCTMGR[1:3],c(.1,0,NA),'pct proportion check')
d <- fixture(); d$V220 <- 1; d$V233 <- 3; d$V300 <- 2; d$V166[1:3] <- c(1,2,8)
eq(build(d)$data$UNION[1:3],c(2,2,2),'union L0'); eq(build(d,'union_items','L1')$data$UNION[1:3],c(2,2,2),'union L1')
eq(build(d,'union_items','L2')$data$UNION[1:3],c(2.25,1.75,2),'union L2')
d$V41[1:6] <- c(1,2,3,4,8,9)
eq(build(d)$data$PRODUCT[1:6],c(1,0,0,NA,NA,NA),'product and neither L0')
eq(build(d)$data$SERVICE[1:6],c(0,1,0,NA,NA,NA),'service and neither L0')
eq(build(d,'neither','L1')$data$PRODUCT[1:6],c(1,0,0,0,NA,NA),'neither L1 product')
eq(build(d,'neither','L1')$data$SERVICE[1:6],c(0,1,0,0,NA,NA),'neither L1 service')
d$V328[1:7] <- c(1:4,7:9)
eq(build(d)$data$COMPET[1:7],c(1:4,NA,NA,NA),'competition L0')
eq(build(d,'competition','L1')$data$COMPET[1:7],c(0,0,0,1,NA,NA,NA),'competition L1')
eq(build(d,'competition','L2')$data$COMPET[1:7],c(0,0,1,1,NA,NA,NA),'competition L2')
# Industry parsing, ambiguity, missing, no match, and both reference choices/ties.
eq(industry_groups(c(10,20,30,40,99,NA),cw,'L0'),c('01','02','04','UNCL','UNCL','UNCL'),'industry L0')
eq(industry_groups(c(10,20,30,40,99,NA),cw,'L1'),c('01',NA,NA,NA,NA,NA),'industry L1')
eq(industry_schema(c('01','01','02','02','UNCL'))$reference,'01','largest tie lowest code')
eq(industry_schema(c('01','01','02','UNCL'),'industry_ref_alt')$reference,'UNCL','smallest tie highest code')
# Frame/sample axes, standardization, scope, weight exclusion.
d <- fixture(); d$V3[1:3] <- c(0,1,NA); d$V8[1:3] <- c(1,1,2); d$V9[1:2] <- c(3,4)
eq(build(d,'records','L1')$data$V1,2:12,'record filter retains missing V3')
ok(all(build(d)$data$market[c(1,2)]) && !build(d)$data$market[3],'market sample L0')
ok(!build(d,'market_sample','L1')$data$market[1] && build(d,'market_sample','L1')$data$market[2],'market sample L1')
d[1,paste0('V',289:295)] <- 9; b <- build(d); s <- s0; s$market_requires_pop <- 'L1'
ok(1 %in% rows_for(b$data,s0,'mkt',HRM) && !1 %in% rows_for(b$data,s,'mkt',HRM),'market POP requirement')
d <- fixture(); d$V62[1] <- NA; d$V97[1] <- NA; d$V131[1] <- NA; b <- build(d)
ok(1 %in% rows_for(b$data,s0,'org',character()) && !1 %in% rows_for(b$data,s0,'org',HRM),'common vs model-specific cases')
d$WEIGHT[1:3] <- c(0,-1,NA); z <- build(d,'weights','L1')$data
ok(all(is.na(z$weight[1:3])) && all(!1:3 %in% rows_for(z,s0,'org',character())),'weight exclusions')
eq(build(d)$data$weight,rep(1,12),'OLS ignores WEIGHT')
d <- fixture(); d$V41[1] <- 4; d$V8[2:3] <- 2; b <- build(d)
for(level in c('L0','L1','L2','L3')) for(fam in c('org','mkt')) {
  s <- s0; s$z_reference <- level; z <- family_data(b,s,fam)
  ref <- if(level %in% c('L0','L3')) 1:12 else rows_for(b$data,s,if(level=='L1') 'org' else fam,HRM)
  manual <- b$staff
  for(j in 1:3) {
    v <- b$staff[,j]; manual[,j] <- (v-mean(v))/sd(v)
    if(level=='L3') manual[,j] <- (v-mean(v))/sqrt(mean((v-mean(v))^2))
    if(level %in% c('L1','L2')) manual[ref,j] <- (v[ref]-mean(v[ref]))/sd(v[ref])
  }
  eq(z$STAFF,rowMeans(manual),paste('z reference',level,fam))
  eq(attr(z,'z_reference_rows'),ref,paste('z membership',level,fam))
}
eq(z_scores(cbind(rep(1,5),1:5),1:5)[,1],rep(NA_real_,5),'undefined SD missing')
# TRAIN uses item-specific valid reference sets, then averages standardized items.
for(level in c('L0','L1','L2','L3')) {
  s <- s0; s$z_reference <- level; out <- family_data(b,s,'mkt')
  ref <- attr(out,'z_reference_rows'); manual <- b$train
  for(j in 1:3) {
    v <- b$train[,j]; vv <- v[!is.na(v)]; den <- if(level=='L3') sqrt(mean((vv-mean(vv))^2)) else sd(vv)
    manual[,j] <- (v-mean(vv))/den
    if(level %in% c('L1','L2')) {
      vr <- v[ref]; manual[ref,j] <- (vr-mean(vr,na.rm=TRUE))/sd(vr,na.rm=TRUE)
    }
  }
  eq(out$TRAIN,rowMeans(manual,na.rm=TRUE),paste('TRAIN itemwise z and averaging',level))
}
fh <- fit_model(cbind('(Intercept)'=1,STAFF=1:10,IND_01=c(1,rep(0,9))),c(1:9,12))
ok(fh$status=='ok' && all(is.na(fh$coef$se_hc3)) && grepl('leverage',fh$note),'undefined HC3 explicitly flagged')
# Interaction design and algebraic invariances on a full-rank constructed family dataset.
set.seed(12); N <- 150; d <- as.data.frame(matrix(rnorm(N*(length(HRM)+length(CONTROLS))),N))
names(d) <- c(HRM,CONTROLS); d$POP <- rnorm(N); d$PMP <- rnorm(N); d$V1 <- 1:N
d$industry <- rep(c('01','02','03'),length.out=N); d$weight <- 1; d$market <- TRUE
schema <- industry_schema(d$industry); def <- model_defs('org')[[12]]; s <- s0
x0 <- design_matrix(d,1:N,def,'org',s,schema); s$centering <- 'L1'; x1 <- design_matrix(d,1:N,def,'org',s,schema)
eq(x0[,'TRAIN_x_STAFF'],d$TRAIN*d$STAFF,'raw interaction')
eq(x1[,'TRAIN_x_STAFF'],(d$TRAIN-mean(d$TRAIN))*(d$STAFF-mean(d$STAFF)),'centered interaction')
eq(x0[,'TRAIN'],x1[,'TRAIN'],'main effects uncentered')
f0 <- fit_model(x0,d$POP); f1 <- fit_model(x1,d$POP); eq(f0$fitted,f1$fitted,'centering fitted invariance')
d2 <- d; d2$VHIER <- d2$VHIER/log(10); d2$PCTMGR <- d2$PCTMGR/100
f2 <- fit_model(design_matrix(d2,1:N,def,'org',s0,industry_schema(d$industry,'industry_ref_alt')),d$POP)
eq(f0$fitted,f2$fitted,'all representation fitted invariances'); eq(f0$r2,f2$r2,'representation R2 invariance')
# Model-specific nested test explicitly refits on full-model rows.
d$STAFF[1:10] <- NA; fullrows <- rows_for(d,s0,'org',def$terms); base <- model_defs('org')[[1]]
ff <- fit_model(design_matrix(d,fullrows,def,'org',s0,schema),d$POP[fullrows])
rr <- fit_model(design_matrix(d,fullrows,base,'org',s0,schema),d$POP[fullrows])
nt <- nested_stat(ff,rr,9)
ref_full <- lm(d$POP[fullrows]~ff$x-1); ref_base <- lm(d$POP[fullrows]~rr$x-1)
eq(nt$f,anova(ref_base,ref_full)$F[2],'nested full sample refit')
ok(length(rows_for(d,s0,'org',character()))==150 && nt$n==140,'model-specific samples differ')
cat('ALL ',checks,' CHECKS PASSED\n',sep='')
writeLines(paste('All',checks,'checks passed.'),'code/dev_out/unit_test_result.txt')
