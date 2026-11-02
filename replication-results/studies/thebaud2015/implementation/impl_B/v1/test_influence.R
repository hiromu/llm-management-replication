source('run.R')
t0 <- Sys.time()
run_analysis('synthetic','test_influence','influence',influence_models='M3')
writeLines(sprintf('Elapsed seconds: %.3f',as.numeric(difftime(Sys.time(),t0,units='secs'))),'test_influence_timing.txt')
