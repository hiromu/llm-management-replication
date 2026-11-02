# Dump implementation A's constructed analysis variables at spec O (org family sample).
suppressPackageStartupMessages(library(jsonlite))
run <- "../../../runs/run_20261028_v1_1"
source(file.path(run, "code_A/k7_lib.R"))
d <- read.csv(file.path(run, "inputs/survey.csv"), check.names = FALSE, stringsAsFactors = FALSE)
mis <- parse_metadata(fromJSON(file.path(run, "inputs/survey_metadata.json"), simplifyVector = FALSE))
cwp <- parse_crosswalk(read.csv(file.path(run, "inputs/industry_crosswalk.csv"), colClasses = "character", check.names = FALSE))
grid <- fromJSON(file.path(run, "inputs/grid_v1.json"), simplifyVector = FALSE)
spec <- Filter(function(x) x$spec_id == "O", grid$specs)[[1]]
s <- spec$settings
f0 <- build_frame(d, s, mis, cwp, NULL)
S <- family_sample_L0(f0, "org", s)
f0 <- add_z_indices(f0, s$item_rule, NULL, FALSE)
cols <- c("V1", "POP", HRM_TERMS, ORG_CONTROLS, "IND", paste0("staff_i", 1:3), paste0("train_i", 1:3),
          paste0("staff_z", 1:3), paste0("train_z", 1:3))
out <- f0[, cols]; out$in_org <- S
write.csv(out, "frame_A_O.csv", row.names = FALSE, na = "NA")
cat("rows", nrow(out), "org sample", sum(S), "\n")
