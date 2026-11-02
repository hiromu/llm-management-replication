# Post hoc algebra only: no refits. Save full covariance transformations.
Sys.setenv(OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1,VECLIB_MAXIMUM_THREADS=1)
library(lme4)
r<-readRDS('diagnostics/M6_common_U14_default.rds'); fit<-r$fit; co<-r$constants$variables
mu<-co$leave$mean; s<-co$leave$sd; m2<-co$leave_sq$mean; s2<-co$leave_sq$sd
a<-s^2/s2; bb<-2*mu*s/s2; cc<-(mu^2-m2)/s2
b<-fixef(fit); V<-as.matrix(vcov(fit)); T<-diag(length(b)); dimnames(T)<-list(names(b),names(b))
for(pair in list(c('(Intercept)','leave','leave_sq'),c('female','female:leave','female:leave_sq'))) {
 T[pair[1],pair[3]]<-cc; T[pair[2],pair[3]]<-bb; T[pair[3],pair[3]]<-a
}
b_old<-drop(T%*%b); V_old<-T%*%V%*%t(T)
X<-getME(fit,'X'); X_old<-X
X_old[,'leave_sq']<-X[,'leave']^2; X_old[,'female:leave_sq']<-X[,'female']*X[,'leave']^2
idx<-c('female:leave','female:leave_sq')
wald<-function(b,V)drop(t(b[idx])%*%solve(V[idx,idx],b[idx]))
r1<-wald(b,V); r2<-wald(b_old,V_old)
err<-max(abs(drop(X%*%b-X_old%*%b_old)))
stopifnot(err<1e-10,abs(r1-r2)<1e-10)
write.csv(data.frame(term=names(b),U14=b,se_U14=sqrt(diag(V)),origin_basis=b_old,se_origin=sqrt(diag(V_old))), 'diagnostics/basis_covariance.csv',row.names=FALSE)
p<-readRDS('diagnostics/owners_U14.rds'); d<-p$data[complete.cases(p$data[,c('raw_leave','raw_childcare','raw_parttime','raw_gdp','raw_unemp','raw_epl','raw_status','raw_wmgr','raw_fert')]),]
u<-d[!duplicated(d$survey),]
writeLines(c(paste('q = a*z^2 + b*z + c:',a,bb,cc),paste('maximum linear predictor error',err),paste('joint Wald chi2',r1,'df 2 p',pchisq(r1,2,lower.tail=FALSE)),paste('unique survey correlations z,z(raw^2)',cor(u$leave,u$leave_sq),'z,z^2',cor(u$leave,u$leave^2))), 'diagnostics/basis_check.txt')
print(readLines('diagnostics/basis_check.txt'))
