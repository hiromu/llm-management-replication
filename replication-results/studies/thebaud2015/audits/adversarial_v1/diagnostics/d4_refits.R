## POST-HOC adversarial refits. Labelled post hoc; they cannot change any score,
## target, tolerance or frozen rule. Uses the frozen impl_A/v1 functions unchanged;
## the only modifications are (1) a common owner sample (rows complete on planb,
## size and growth) and (2) combinations of already-frozen branches (U09, U14).
## Usage (from study root): Rscript d4_refits.R <spec1,spec2,...> <out.csv>
source("audits/adversarial_v1/diagnostics/load_impl.R")
args <- commandArgs(trailingOnly = TRUE)
specs <- strsplit(args[1], ",")[[1]]; out_csv <- args[2]
SPEC <- list(
  M4_common          = list(model = "M4", common = TRUE,  u09 = FALSE, u14 = FALSE),
  M4_U09_common      = list(model = "M4", common = TRUE,  u09 = TRUE,  u14 = FALSE),
  M4_U09_U14_common  = list(model = "M4", common = TRUE,  u09 = TRUE,  u14 = TRUE),
  M4_U09_U14         = list(model = "M4", common = FALSE, u09 = TRUE,  u14 = TRUE),
  M5_common          = list(model = "M5", common = TRUE,  u09 = FALSE, u14 = FALSE),
  M5_U14_common      = list(model = "M5", common = TRUE,  u09 = FALSE, u14 = TRUE),
  M6_common          = list(model = "M6", common = TRUE,  u09 = FALSE, u14 = FALSE),
  M6_U14_common      = list(model = "M6", common = TRUE,  u09 = FALSE, u14 = TRUE),
  M7_U14_common      = list(model = "M7", common = TRUE,  u09 = FALSE, u14 = TRUE),
  M8_U14_common      = list(model = "M8", common = TRUE,  u09 = FALSE, u14 = TRUE)
)
res <- list()
for (sp in specs) {
  cfg <- SPEC[[sp]]; s <- origin_settings()
  if (cfg$u09) s$planb_def <- "U09"
  if (cfg$u14) s$leave_sq_std <- "U14"
  t0 <- Sys.time()
  prep <- prepare_run(inputs, s)
  x <- build_sample(prep$d, cfg$model, s)
  if (cfg$common) x <- x[!is.na(planb) & !is.na(size) & !is.na(growth)]
  x <- center_sample(x, cfg$model)
  r <- fit_one(paste0("POSTHOC_", sp), cfg$model, x, s)
  res[[length(res) + 1]] <- r
  cat(sprintf("%s: n=%d status=%s %.1fs\n", sp, nrow(x), r$status[1], as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  fwrite(rbindlist(res, fill = TRUE), out_csv)
}
