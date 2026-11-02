source('run.R')
t0 <- Sys.time()
run_analysis('synthetic','test_deviations','U03,U09,U25')
writeLines(sprintf('Elapsed seconds: %.3f',as.numeric(difftime(Sys.time(),t0,units='secs'))),'test_deviations_timing.txt')
