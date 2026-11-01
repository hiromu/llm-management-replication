# This is the sole real-data validation entry point. It makes any accidental
# model invocation an error, independently of --construct-only control flow.
source('analysis.R')
fit_model <- function(...) stop('PROHIBITED: real-data model fitting in this phase')
run_analysis(outdir='tests/construction_out',construct_only=TRUE)
s<-fread('tests/construction_out/construction_status.csv')
print(s[,.(specifications=.N),by=status])
if(any(s$status=='failed')) {print(s[status=='failed']); stop('Construction errors remain')}
cat('PASS: all real-data construction paths completed or explicitly unavailable; no fitting invoked.\n')
