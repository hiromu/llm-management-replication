source('run.R')
t0 <- Sys.time()
# Inject a fitting error to verify run-level continuation without modifying run.R.
RUN_MODELS$ORIGIN <- c('M1','M5')
real_fit_model <- fit_model
fit_model <- function(ms,run_id,invalid=character(),deleted_country='') {
 if(ms$spec$model=='M1') stop('Deliberately injected fit error for continuation test')
 real_fit_model(ms,run_id,invalid,deleted_country)
}
x <- run_analysis('synthetic','test_continuation','ORIGIN')
stopifnot(all(x$results$status[x$results$model=='M1']=='failed'),all(x$results$status[x$results$model=='M5']=='ok'))
writeLines(sprintf('Elapsed seconds: %.3f',as.numeric(difftime(Sys.time(),t0,units='secs'))),'test_continuation_timing.txt')
