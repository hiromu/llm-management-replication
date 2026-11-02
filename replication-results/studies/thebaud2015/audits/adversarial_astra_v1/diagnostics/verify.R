# Validate diagnostic artifacts and convergence; no refitting.
Sys.setenv(OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1,VECLIB_MAXIMUM_THREADS=1)
library(lme4)
files<-list.files('diagnostics',pattern='^M[46].*\\.rds$',full.names=TRUE)
checks<-list()
for(f in files) {
 x<-readRDS(f); fit<-x$fit; rr<-x$summary
 msg<-unlist(fit@optinfo$conv$lme4$messages)
 cv<-all(unlist(fit@optinfo$conv$opt)==0) && !any(!grepl('boundary.*singular',msg,ignore.case=TRUE))
 stopifnot(nrow(getME(fit,'X'))==unique(rr$n),max(abs(fixef(fit)-rr$estimate))<1e-12,all(is.finite(rr$se)))
 checks[[length(checks)+1]]<-data.frame(label=rr$label[1],n=rr$n[1],outcome_mean=mean(model.response(model.frame(fit))),loglik=rr$loglik[1],converged=cv,singular=isSingular(fit),cpu_seconds=rr$cpu_seconds[1],optimizer=paste(fit@optinfo$optimizer,collapse=';'),messages=paste(msg,collapse=' | '))
}
c<-do.call(rbind,checks);write.csv(c,'diagnostics/validation.csv',row.names=FALSE);print(c)
all<-do.call(rbind,lapply(files,function(f)readRDS(f)$summary))
write.csv(all,'diagnostics/all_refits.csv',row.names=FALSE)
cat('Total successful fit CPU seconds:',sum(c$cpu_seconds),'\n')
# Validate script syntax, including the driver edited during the first launch.
for(f in list.files('diagnostics',pattern='\\.R$',full.names=TRUE)) invisible(parse(f))
