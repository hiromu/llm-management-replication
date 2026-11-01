# Post hoc two-year-lag diagnostic, with separately standardized raw square.
Sys.setenv(OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1,VECLIB_MAXIMUM_THREADS=1)
source('../../implementation/impl_B/v1/run.R');library(data.table);setDTthreads(1)
i<-list(g=as.data.frame(fread('../../data/derived/gem_extract.csv',colClasses=c(ID_9817_RDM='character'))),c=as.data.frame(fread('../../data/derived/country_year_inputs.csv')))
p<-prepare_run(i,'U18')
d<-p$data
anchor<-select_rows(d,d$pass_roster & d$pass_age & d$pass_work & complete(d,c('activity','female','age','postsecondary',paste0('raw_',SURVEY_VARS))))
x<-anchor$raw_leave[!duplicated(anchor$survey)]^2
p$constants$variables$leave_sq<-list(mean=mean(x),sd=sd(x))
p$data$leave_sq<-(d$raw_leave^2-mean(x))/sd(x)
p$data<-select_rows(p$data,p$data$pass_roster & p$data$pass_age & p$data$pass_work & p$data$owner==1)
saveRDS(p,'diagnostics/owners_U18_U14.rds')
