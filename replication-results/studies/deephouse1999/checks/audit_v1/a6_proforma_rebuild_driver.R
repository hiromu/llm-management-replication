# Audit task 6 driver (run in a scratch copy outside the study with symlinked read-only data): builds the
# R03.proforma samples at O_A and O_B with impl_A (arg A) and impl_B (arg B) code, unmodified, to locate the row
# on which they differ. Usage from the copy dir: Rscript a6_proforma_rebuild_driver.R A|B <out.csv>

suppressPackageStartupMessages(library(data.table))
args <- commandArgs(trailingOnly=TRUE); impl <- args[1]; outf <- args[2]
res <- list()
for (o in c("O_A","O_B")) {
  if (impl == "A") {
    ANALYSIS_SOURCE_ONLY <- TRUE
    source("analysis.R")
    grid <- jsonlite::fromJSON("grid.json", simplifyVector = FALSE)
    inp <- load_inputs()
    cfg <- make_cfg(grid$origins[[o]], o); cfg$R03 <- "R03.proforma"
    s <- build_sample(cfg, inp)$sample
  } else {
    source("analysis.R")
    grid <- jsonlite::fromJSON("grid.json", simplifyVector = FALSE)
    z <- load_inputs("data")
    cfg <- grid$origins[[o]]; cfg$R03 <- "R03.proforma"
    s <- construct_sample(z, cfg, grid$origins[[o]])$sample
  }
  res[[o]] <- s[, .(origin = o, RSSD9001, year, lag, y, SD, MS)]
}
fwrite(rbindlist(res), outf)
