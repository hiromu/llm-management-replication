# All fits are post hoc diagnostics, not replacements for frozen results.
Sys.setenv(OMP_NUM_THREADS=1, OPENBLAS_NUM_THREADS=1, MKL_NUM_THREADS=1, VECLIB_MAXIMUM_THREADS=1)
source('../../implementation/impl_B/v1/run.R')
args<-commandArgs(trailingOnly=TRUE)
whichfits<-strsplit(args[1],',')[[1]]
for(label in whichfits) {
 setTimeLimit(cpu=900,elapsed=1200,transient=TRUE)
 t0<-proc.time(); p<-readRDS(if(grepl('U18',label)) 'diagnostics/owners_U18_U14.rds' else if(grepl('altleave',label)) 'diagnostics/owners_altleave_U14.rds' else 'diagnostics/owners_U14.rds')
 model<-if(grepl('M4',label)) 'M4' else 'M6'
 # M4 preferred alternative: mixed motives included, with the three-outcome common sample.
 if(model=='M4' && grepl('U09',label)) p$data$planb<-binary(p$data$OMREASON,c(2,3),c(1,4,6))
 if(grepl('FAULT',label)) p$data$growth[is.na(p$data$growth)]<-1
 ms<-model_sample(p,model,'ORIGIN')
 if(!grepl('FAULT',label)) ms$data<-select_rows(ms$data,complete(ms$data,c('planb','size','growth')))
 d<-ms$data; d$age_c<-d$age-mean(d$age); d$age_c2<-d$age_c^2; d$bage_c<-d$bage-mean(d$bage)
 terms<-ms$spec$terms
 if(grepl('nochildcare',label)) terms<-setdiff(terms,c('childcare','female:childcare'))
 f<-as.formula(paste(OUTCOMES[[model]],'~',paste(terms,collapse='+'),'+ (1 + female || country) + (1 + female || survey)'))
 message(label, ' N=',nrow(d))
 caught<-capture_conditions(glmer(f,data=d,family=binomial,nAGQ=1,na.action=na.fail,
   control=glmerControl()))
 fit<-caught$value
 if(inherits(fit,'error')) {writeLines(conditionMessage(fit),paste0('diagnostics/',label,'_error.txt'));next}
 b<-fixef(fit); V<-as.matrix(vcov(fit)); se<-sqrt(diag(V));
 rr<-data.frame(label=label,model=model,n=nrow(d),term=names(b),estimate=b,se=se,p=2*pnorm(-abs(b/se)),loglik=as.numeric(logLik(fit)),singular=isSingular(fit),cpu_seconds=sum((proc.time()-t0)[1:2]),warnings=paste(caught$notes,collapse=' | '))
 write.csv(rr,paste0('diagnostics/',label,'.csv'),row.names=FALSE)
 saveRDS(list(fit=fit,constants=p$constants,summary=rr),paste0('diagnostics/',label,'.rds'))
 print(rr[rr$term %in% c('female','female:leave','female:leave_sq','female:parttime'),])
 message('completed ',label,' CPU=',rr$cpu_seconds[1])
}
