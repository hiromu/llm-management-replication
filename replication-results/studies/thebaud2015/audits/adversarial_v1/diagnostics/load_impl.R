## Post-hoc adversarial diagnostic helper. Loads the function and constant
## definitions of the frozen impl_A/v1/run.R (lines 39-834) without running its
## main section. The frozen file is read, never modified. Run from study root.
suppressPackageStartupMessages({
  library(data.table); library(Matrix); library(lme4)
  library(sandwich); library(lmtest); library(jsonlite); library(digest)
})
setDTthreads(1)
src <- readLines("implementation/impl_A/v1/run.R")
main_at <- grep("^## 10. Main", src)[1]
eval(parse(text = src[39:(main_at - 2)]), envir = globalenv())
inputs <- read_inputs("data/derived")
