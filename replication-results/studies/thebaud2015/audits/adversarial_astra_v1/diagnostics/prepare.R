# Post hoc independent audit. Run from audits/adversarial_astra_v1.
Sys.setenv(OMP_NUM_THREADS=1, OPENBLAS_NUM_THREADS=1, MKL_NUM_THREADS=1, VECLIB_MAXIMUM_THREADS=1)
source('../../implementation/impl_B/v1/run.R')
library(data.table); setDTthreads(1)
out <- 'diagnostics'
t0 <- proc.time()
inputs <- list(g=as.data.frame(fread('../../data/derived/gem_extract.csv', colClasses=c(ID_9817_RDM='character'))), c=as.data.frame(fread('../../data/derived/country_year_inputs.csv')))
p <- prepare_run(inputs, 'U14')
# Retain only potential owner observations; the standardization anchor stays stage 1.
p$data <- select_rows(p$data, p$data$pass_roster & p$data$pass_age & p$data$pass_work & p$data$owner==1)
saveRDS(p, file.path(out,'owners_U14.rds'))
jsonlite::write_json(p$constants,file.path(out,'constants_U14.json'),pretty=TRUE,auto_unbox=TRUE,digits=16)
base <- model_sample(p,'M5','ORIGIN')$data
m4 <- model_sample(p,'M4','ORIGIN')$data
m6 <- model_sample(p,'M6','ORIGIN')$data
common <- select_rows(base,complete(base,c('planb','growth')))
common09 <- common; common09$planb <- as.numeric(common09$OMREASON %in% c(2,3))
summary <- function(d,label,y='growth',w=rep(1,nrow(d))) {
 ok <- !is.na(d[[y]]) & is.finite(w) & w>0; d <- d[ok,]; w<-w[ok]
 mm <- function(v) weighted.mean(v,w,na.rm=TRUE)
 r0 <- weighted.mean(d[[y]][d$female==0],w[d$female==0]); r1 <- weighted.mean(d[[y]][d$female==1],w[d$female==1])
 data.frame(sample=label,outcome=y,n=nrow(d),mean=mm(d[[y]]),female=mm(d$female),male_rate=r0,female_rate=r1,raw_female_logOR=qlogis(r1)-qlogis(r0),age=mm(d$age),postsecondary=mm(d$postsecondary),size=mm(d$size),bage=mm(d$bage))
}
ss <- list(summary(m4,'M4 origin','planb'),summary(transform(m4,planb=as.numeric(OMREASON %in% c(2,3))),'M4 U09','planb'),summary(m6,'M6 origin'),summary(common,'common'),summary(common09,'common U09','planb'))
for(nm in c('WEIGHT','WEIGHT_L','WEIGHT_A')) {
 ss[[length(ss)+1]] <- summary(common,paste('common',nm),w=common[[nm]])
 ss[[length(ss)+1]] <- summary(common,paste('common',nm),'planb',common[[nm]])
 ss[[length(ss)+1]] <- summary(common09,paste('common U09',nm),'planb',common09[[nm]])
}
# Fault injection, not a valid missing-value treatment: mimics unguarded Stata comparison.
bad <- base; bad$growth[is.na(bad$growth)] <- 1
ss[[length(ss)+1]] <- summary(bad,'FAULT: missing growth coded 1')
for(cut in c(0,2,5)) {
 z<-common; z$growth<-as.numeric(z$OMYR5JOB-z$OMNOWJOB>cut)
 ss[[length(ss)+1]]<-summary(z,paste('additional >',cut))
}
fwrite(rbindlist(ss),file.path(out,'descriptives.csv'))
fwrite(as.data.table(base)[,.(n=.N,missing_growth=sum(is.na(growth)),share_missing=mean(is.na(growth))),by=female],file.path(out,'growth_missing_by_gender.csv'))
samples<-lapply(paste0('M',4:8),function(m){d<-model_sample(p,m,'ORIGIN')$data; cc<-complete(d,c('planb','size','growth'));data.frame(model=m,per_model=nrow(d),common=sum(cc))})
fwrite(rbindlist(samples),file.path(out,'sample_counts.csv'))
fwrite(as.data.table(common)[,.(n=.N,share=.N/nrow(common)),by=GEM_YR],file.path(out,'common_years.csv'))
fwrite(as.data.table(m4)[,.(n=.N),by=OMREASON],file.path(out,'planb_counts.csv'))
# Build alternative leave from the article's policy-change list, never printed country values.
changers<-c('DNK','DEU','IRL','NZL','PRT','SWE','CHE','GBR')
c<-inputs$c
ref<-c$leave_fte_weeks[match(paste(c$iso3,2008),paste(c$iso3,c$year))]
c$leave_fte_weeks[!c$iso3 %in% changers]<-ref[!c$iso3 %in% changers]
inputs$c<-c
pa<-prepare_run(inputs,'U14'); pa$data<-select_rows(pa$data,pa$data$pass_roster & pa$data$pass_age & pa$data$pass_work & pa$data$owner==1)
saveRDS(pa,file.path(out,'owners_altleave_U14.rds'))
fwrite(c[,c('iso3','year','leave_fte_weeks')],file.path(out,'altleave.csv'))
writeLines(c(capture.output(sessionInfo()),paste('preparation CPU',sum((proc.time()-t0)[1:2]))),file.path(out,'session_info.txt'))
print(rbindlist(ss)); print(rbindlist(samples))
