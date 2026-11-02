## POST-HOC adversarial refits with an alternative leave series built only from our own
## derived inputs (no printed article values): article footnote 7 says only DNK, DEU, IRL, NZL,
## PRT, SWE, CHE and GBR had a relevant leave-policy change in the study period. For every other
## country the leave value is held at that country's own 2008 value (the CEPR reference year,
## where construction rule (a) gives the CEPR FTE itself). The eight listed countries keep the
## frozen rule (a) series. CZE stays missing. Cannot change any score.
## Usage: Rscript d10_leave_alt.R <spec1,...> <out.csv>
source("audits/adversarial_v1/diagnostics/load_impl.R")
args <- commandArgs(trailingOnly = TRUE); specs <- strsplit(args[1], ",")[[1]]; out_csv <- args[2]
changers <- c("DNK", "DEU", "IRL", "NZL", "PRT", "SWE", "CHE", "GBR")
cy <- copy(inputs$cy)
ref <- cy[year == 2008, .(iso3, leave2008 = leave_fte_weeks)]
cy <- merge(cy, ref, by = "iso3", all.x = TRUE)
cy[!(iso3 %in% changers), leave_fte_weeks := leave2008]
cy[, leave2008 := NULL]
inputs$cy <- cy
fwrite(cy[, .(iso3, year, leave_fte_weeks)], "audits/adversarial_v1/diagnostics/d10_leave_alt_series.csv")
SPEC <- list(
  M3_alt_U14        = list(model = "M3", common = FALSE, u09 = FALSE),
  M4_alt_U09_U14_common = list(model = "M4", common = TRUE, u09 = TRUE),
  M5_alt_U14_common = list(model = "M5", common = TRUE, u09 = FALSE),
  M6_alt_U14_common = list(model = "M6", common = TRUE, u09 = FALSE),
  M7_alt_U14_common = list(model = "M7", common = TRUE, u09 = FALSE),
  M8_alt_U14_common = list(model = "M8", common = TRUE, u09 = FALSE))
res <- list()
for (sp in specs) {
  cfg <- SPEC[[sp]]; s <- origin_settings(); s$leave_sq_std <- "U14"
  if (cfg$u09) s$planb_def <- "U09"
  t0 <- Sys.time()
  prep <- prepare_run(inputs, s)
  if (sp == specs[1]) {
    cat("constants leave:", unlist(prep$cons$constants$leave), " n_units:", prep$cons$n_units, "\n")
  }
  x <- build_sample(prep$d, cfg$model, s)
  if (cfg$common) x <- x[!is.na(planb) & !is.na(size) & !is.na(growth)]
  x <- center_sample(x, cfg$model)
  r <- fit_one(paste0("POSTHOC_", sp), cfg$model, x, s)
  res[[length(res) + 1]] <- r
  cat(sprintf("%s: n=%d surveys=%d status=%s %.1fs\n", sp, nrow(x), uniqueN(x$survey), r$status[1],
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  fwrite(rbindlist(res, fill = TRUE), out_csv)
}
