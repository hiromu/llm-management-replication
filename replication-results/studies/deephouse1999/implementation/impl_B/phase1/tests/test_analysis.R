#!/opt/homebrew/bin/Rscript
# All fitting in this file uses generated/hand-made data, never supplied observations.
source('analysis.R')
grid<-jsonlite::fromJSON('grid.json',simplifyVector=FALSE)
cfg<-grid$origins$O_A
passed<-0L
check<-function(label,expr) {
  if(!isTRUE(expr)) stop(paste('FAIL:',label))
  passed<<-passed+1L; cat(sprintf('PASS %02d: %s\n',passed,label))
}
close<-function(a,b,tol=1e-8) isTRUE(all.equal(as.numeric(a),as.numeric(b),tolerance=tol))
set.seed(41019)
d<-CJ(RSSD9001=1:18,year=1985:1992)
d[,`:=`(MS=runif(.N,.002,.12),TER=runif(.N,.025,.19),RMG=rnorm(.N),lag=rnorm(.N),SD=runif(.N,1,13))]
d[,SD2:=SD^2]; d[,y:=.2+.003*SD2-.11*SD+1.2*MS-2*TER+.04*RMG+.5*lag+rnorm(.N,sd=.3)]
d[,w:=MS]
fits<-list()
for(m in names(model_terms)) {
  f<-fit_model(d,m,cfg); fits[[m]]<-f
  X<-cbind(1,as.matrix(d[,model_terms[[m]],with=FALSE])); W<-diag(d$MS)
  bread<-solve(t(X)%*%W%*%X); beta<-bread%*%t(X)%*%W%*%d$y
  e<-d$y-drop(X%*%beta); sse<-drop(t(e)%*%W%*%e); df<-nrow(d)-ncol(X)
  V<-sse/df*bread
  check(paste(m,'WLS estimates vs direct normal equations'),close(f$beta,beta))
  check(paste(m,'WLS SEs vs direct normal equations'),close(f$results$se,sqrt(diag(V))))
  check(paste(m,'weighted SSE vs direct matrix expression'),close(f$sse_w,sse))
  check(paste(m,'t and two-sided Student p'),close(f$results$p_two_sided,2*pt(-abs(drop(beta)/sqrt(diag(V))),df)))
  singular<-svd(sweep(X*sqrt(d$MS),2,sqrt(colSums(X^2*d$MS)),'/'),nu=0,nv=0)$d
  check(paste(m,'scaled condition index includes intercept'),close(f$cond_max,max(singular)/min(singular)))
}
for(pair in list(c('M1','M2'),c('M1','M3'),c('M2','M3'),c('M1','M3_SQ'))) {
  direct_sse<-function(m) {
    X<-cbind(1,as.matrix(d[,model_terms[[m]],with=FALSE])); Xw<-X*sqrt(d$MS); yw<-d$y*sqrt(d$MS)
    b<-solve(crossprod(Xw),crossprod(Xw,yw)); sum((yw-Xw%*%b)^2)
  }
  q<-length(model_terms[[pair[2]]])-length(model_terms[[pair[1]]]); df<-nrow(d)-length(model_terms[[pair[2]]])-1
  F<-((direct_sse(pair[1])-direct_sse(pair[2]))/q)/(direct_sse(pair[2])/df)
  actual<-nested_f(fits[[pair[1]]],fits[[pair[2]]])
  check(paste(pair[2],'vs',pair[1],'F and p vs direct matrices'),close(actual$F,F) && close(actual$p_upper,pf(F,q,df,lower.tail=FALSE)))
}
# Hand-made market: each category is an affine transformation of (1,2,3).
# Sample z-scores are (-1,0,1); sum of absolute z-scores is (11,0,11).
market<-outer(c(1,2,3),1:11,function(x,j) x*j/100)
s<-strategic_deviation(market)
check('hand-made eleven-category SD equals 11, 0, 11',close(s$SD,c(11,0,11)))
check('population SD uses denominator n',close(strategic_deviation(market,rule='R17.population_sd')$SD,c(11,0,11)*sqrt(3/2)))
market[,11]<-.2
check('zero sample SD contributes zero',close(strategic_deviation(market)$SD,c(10,0,10)))
check('zero-SD-missing rule makes whole score missing',all(is.na(strategic_deviation(market,rule='R17.zero_sd_missing')$SD)))
market[1,1]<-NA_real_
check('collected bank-level missing share propagates',is.na(strategic_deviation(market)$SD[1]))
lagdata<-data.table(RSSD9001=c(2,1,1,1,2,3),year=c(1986,1984,1985,1987,1985,1988),y=c(20,10,11,13,19,30))
check('lag uses calendar t-1, handles unsorted entries and gaps',identical(consecutive_lag(lagdata),c(19,NA_real_,10,NA_real_,NA_real_,NA_real_)))
lagdata$y[2]<-NA_real_
check('missing prior outcome is never skipped',is.na(consecutive_lag(lagdata)[3]))
hd<-data.table(RSSD9001=c(20,3,20),year=c(1986L,1985L,1985L))
expected_text<-'20,1985\n20,1986\n3,1985\n'
hash<-sample_hash(hd)
check('sample SHA-256 hashes sorted integer lines with trailing LF',identical(hash,digest::digest(expected_text,algo='sha256',serialize=FALSE)))
check('hash is 64 lower-case hex and order invariant',grepl('^[0-9a-f]{64}$',hash) && identical(hash,sample_hash(hd[c(3,1,2)])))
check('empty sample hashes empty bytes',identical(sample_hash(hd[0]),digest::digest('',algo='sha256',serialize=FALSE)))
for(m in names(model_terms)) {
  scaled<-cfg; scaled$R24<-'R24.mean1'; f<-fit_model(d,m,scaled)
  check(paste(m,'mean-one weights preserve coefficients and SEs'),close(f$beta,fits[[m]]$beta) && close(f$results$se,fits[[m]]$results$se))
  check(paste(m,'weight scaling scales SSE only'),close(f$sse_w,fits[[m]]$sse_w/mean(d$MS)))
  centered<-cfg; centered$R26<-'R26.centered'; f<-fit_model(d,m,centered)
  check(paste(m,'centered basis restores coefficients and full covariance'),close(f$beta,fits[[m]]$beta) && close(f$V,fits[[m]]$V))
}
X<-cbind(1,as.matrix(d[,model_terms$M3,with=FALSE])); Xw<-X*sqrt(d$MS)
bread<-solve(crossprod(Xw)); e<-fits$M3$weighted_residual; score<-Xw*e
for(cov in c('R23.hc1','R23.cluster_bank')) {
  cc<-cfg; cc$R23<-cov; f<-fit_model(d,'M3',cc)
  meat<-if(cov=='R23.hc1') crossprod(score)*nrow(d)/f$df_resid else {
    sums<-rowsum(score,d$RSSD9001); G<-uniqueN(d$RSSD9001)
    crossprod(sums)*G/(G-1)*(nrow(d)-1)/f$df_resid
  }
  check(paste(cov,'matches direct sandwich'),close(f$V,bread%*%meat%*%bread))
}
previous<-c(NA_integer_,1L,NA_integer_,NA_integer_,4L)
XX<-cbind(1,1:5); yy<-1:5; rho<-.4
pw<-prais_winsten(XX,yy,rho,previous)
Tmat<-diag(sqrt(1-rho^2),5); Tmat[2,2]<-1; Tmat[2,1]<--rho; Tmat[5,5]<-1; Tmat[5,4]<--rho
check('Prais-Winsten restarts at entries and gaps',close(pw$X,Tmat%*%XX) && close(pw$y,Tmat%*%yy))
ar<-cfg; ar$R25<-'R25.wls_ar1'; f<-fit_model(d,'M3',ar)
prev<-match(key(d$RSSD9001,d$year-1L),key(d$RSSD9001,d$year)); cur<-which(!is.na(prev))
rho<-sum(e[cur]*e[prev[cur]])/sum(e[prev[cur]]^2); rho<-max(-.999,min(.999,rho))
Tmat<-diag(1,nrow(d)); starts<-which(is.na(prev)); Tmat[cbind(starts,starts)]<-sqrt(1-rho^2); Tmat[cbind(cur,prev[cur])]<--rho
Z<-Tmat%*%Xw; v<-Tmat%*%(sqrt(d$MS)*d$y); b<-solve(crossprod(Z),crossprod(Z,v)); V<-sum((v-Z%*%b)^2)/(nrow(d)-ncol(Z))*solve(crossprod(Z))
check('two-step AR(1) coefficients and SEs match direct transformation',close(f$beta,b) && close(f$V,V))
check('AR(1) reports original weighted SSE',close(f$sse_w,sum(d$MS*(d$y-X%*%b)^2)))
for(i in c(1,19,53)) {
  raw<-fits$M3; deleted<-fit_model(d[-i],'M3',cfg)
  t_i<-raw$weighted_residual[i]/sqrt((raw$sse_w-raw$weighted_residual[i]^2/(1-raw$h[i]))/(raw$df_resid-1)*(1-raw$h[i]))
  # Deleted variance is independently available from the actual deleted fit.
  direct<-raw$weighted_residual[i]/sqrt(deleted$sse_w/deleted$df_resid*(1-raw$h[i]))
  check(paste('external studentization row',i,'agrees with deletion refit'),close(t_i,direct))
}
check('fitting guard refuses construction-only fits',inherits(tryCatch(fit_model(d,'M1',cfg,allow_fit=FALSE),error=identity),'error'))
# S1-S6 synthetic integration fixture: no input observations are used.
source('tests/synthetic_fixture.R')
z<-synthetic_inputs()
built<-construct_sample(z,cfg); check('synthetic annual construction returns complete sample',nrow(built$sample)>0 && all(complete.cases(built$sample[,.(y,lag,SD,SD2,MS,TER,RMG)])))
annual<-construct_annual(z,cfg,cfg,new_log())
row<-annual[RSSD9001==101 & year==1985]
q<-z$call[RSSD9001==101 & year==1985]
check('income uses Q4 YTD once, AA uses quarterly mean',close(row$NI,q[q==4]$RIAD4340) && close(row$AA,mean(q$RCFD3368)))
check('expense ratio uses Q4 expense over average assets',close(row$TER,(q[q==4]$RIAD4073+q[q==4]$RIAD4093)/mean(q$RCFD3368)))
source('tests/test_construction_edges.R')
# End-to-end every grid level plus influence, on synthetic data only.
original_loader<-load_inputs
load_inputs<-function(data_dir='data') synthetic_inputs()
synthetic_out<-'tests/synthetic_out'
run_analysis(outdir=synthetic_out)
load_inputs<-original_loader
rr<-fread(file.path(synthetic_out,'spec_results.csv')); ff<-fread(file.path(synthetic_out,'f_tests.csv'))
check('every grid specification produces result rows',setequal(rr$spec_id,vapply(make_specs(grid),`[[`,character(1),'spec_id')))
check('no unexpected synthetic full-grid failures',!any(rr$status=='failed'))
check('only missing documented special-bank codes unavailable',all(rr[status=='unavailable']$level_id=='R02.no_special'))
check('four F-test entries for every specification',all(ff[,.N,by=spec_id]$N==4))
inf<-fread(file.path(synthetic_out,'influence.csv'))
check('influence retains every synthetic row and bank deletion',all(vapply(names(grid$origins),function(o) {
 sample<-fread(file.path(synthetic_out,'samples',paste0(o,'.csv')))
 nrow(inf[origin==o])==3L*(nrow(sample)+uniqueN(sample$RSSD9001))
},logical(1))))
check('all synthetic influence fits succeed',all(inf$status=='ok'))
cat(sprintf('\nALL %d TESTS PASSED. All fitted observations were synthetic.\n',passed))
