# Synthetic POW-like inputs in the shape returned by load_inputs() in run.R. No real data involved.
make_synthetic_inputs <- function(N = 20000, seed = 7) {
  set.seed(seed)
  camps <- sprintf("%03d", c(1:25, 501:520))
  camp <- sample(camps, N, replace = TRUE, prob = c(rep(2, 25), rep(1, 20)))
  det <- ifelse(camp < "500", "1", "2")
  labels <- c("PVT", "PFC", "CPL", "SGT", "2 LT", "CAPT", "MAJ", "COL", "GEN", "XYZ", "")
  ranks_lab <- c(1, 1, 2, 3, 5, 6, 7, 8, 9, NA, NA)
  gi <- sample(seq_along(labels), N, replace = TRUE, prob = c(30, 25, 10, 10, 8, 4, 2, 1, 0.2, 1, 2))
  grade_code <- ifelse(gi == 10, "4", ifelse(gi == 11, "", "9"))
  serial <- sprintf("%08d", sample(1e7, N))
  serial[gi >= 5 & gi <= 9] <- paste0("O", substr(serial[gi >= 5 & gi <= 9], 2, 8))
  serial[sample(N, round(N * 0.04))] <- ""
  year <- sample(c("3", "4", "5"), N, replace = TRUE, prob = c(1, 5, 2))
  month <- sprintf("%02d", sample(1:4, N, replace = TRUE))
  month[sample(N, round(N * 0.01))] <- "00"
  unit <- ifelse(runif(N) < 0.3, "", paste0(sample(c("740", "S53", "200"), N, TRUE), "|", sprintf("%04d", sample(1:40, N, TRUE)), "|06"))
  camp_eff <- setNames(rnorm(length(camps), 0, 0.5), camps)
  cohort <- paste(camp, year, month, sep = "_")
  coh_eff <- setNames(rnorm(length(unique(cohort)), 0, 0.3), unique(cohort))
  lin <- 1.0 + camp_eff[camp] + coh_eff[cohort] + 0.3 * (!is.na(ranks_lab[gi]) & ranks_lab[gi] >= 5) - 0.5 * (det == "2")
  surv <- as.numeric(lin + rnorm(N) > 0)
  sta <- ifelse(surv == 1, sample(c("7", "8", "9"), N, TRUE), sample(c("4", "5"), N, TRUE, prob = c(1, 4)))
  sta[sample(N, round(N * 0.02))] <- "0"
  svc <- sample(c("1", "1", "1", "2", "3", "6"), N, TRUE)
  pow <- data.table(record_seq = seq_len(N), SERIAL_NO = serial, GRADE_ALPHA = labels[gi], GRADE_CODE = grade_code,
                    SERVICE_CODE = svc, ARM_SVC_ALPHA = ifelse(runif(N) < 0.4, "AC", "INF"), ARM_SVC_CODE = "",
                    DATE_REPORTED_MONTH = month, DATE_REPORTED_YEAR = year,
                    TYPE_ORG = sub("\\|.*", "", unit), PARENT_UNIT_NUM = ifelse(unit == "", "", sub("^[^|]*\\|([^|]*)\\|.*$", "\\1", unit)),
                    PARENT_UNIT_TYPE = ifelse(unit == "", "", "06"), STA = sta, DET_POWER = det, CAMP = camp)
  pow$CAMP[sample(N, round(N * 0.025))] <- "000"
  ser_link <- unique(serial[serial != "" & runif(N) < 0.65])
  enl <- data.table(ser_key = ser_link, record_seq = seq_along(ser_link) * 3,
                    height_raw = ifelse(runif(length(ser_link)) < 0.9, as.character(sample(55:80, length(ser_link), TRUE)), "00"),
                    yob_raw = sprintf("%02d", sample(5:27, length(ser_link), TRUE)),
                    educ_raw = as.character(sample(0:9, length(ser_link), TRUE)),
                    marital_raw = as.character(sample(1:9, length(ser_link), TRUE)))
  enl[sample(.N, round(.N * 0.03)), educ_raw := "X"]      # some invalid codes -> education missing while age present
  dup <- enl[sample(.N, round(.N * 0.02))]; dup[, record_seq := record_seq + 1]; dup[, height_raw := "99"]
  enl <- rbind(enl, dup); enl[, n_dup := .N, by = ser_key]
  cw <- data.table(camp_code = camps, entry_id = camps, confidence = ifelse(runif(length(camps)) < 0.9, "exact", "unknown"),
                   identified_place_name = "Somewhere", nara_degree_coords_text = "50-10",
                   latitude = as.character(ifelse(camps < "500", runif(length(camps), 45, 55), runif(length(camps), 30, 40))),
                   longitude = as.character(ifelse(camps < "500", runif(length(camps), 5, 20), runif(length(camps), 130, 140))))
  cw[1, `:=`(identified_place_name = "Berlin", confidence = "exact")]
  cw[, code := cl(camp_code)]; cw[, lat := as.numeric(latitude)]; cw[, lon := as.numeric(longitude)]
  rank_alpha <- data.table(grade_alpha = labels[1:10], label = labels[1:10],
                           rank_origin_service_not_navy = as.character(ifelse(is.na(ranks_lab[1:10]), "", ranks_lab[1:10])),
                           rank_origin_navy = as.character(ifelse(is.na(ranks_lab[1:10]), "", ranks_lab[1:10])),
                           rank_strict_service_not_navy = c("1", "1", "", "", "5", "", "", "", "", ""),
                           rank_strict_navy = c("1", "1", "", "", "5", "", "", "", "", ""))
  rank_code <- data.table(grade_code = c("4", "9"), code = c("4", "9"), rank_officer_not_navy = c("7", "4"), rank_enlisted_not_navy = c("3", "1"),
                          rank_officer_navy = c("7", "4"), rank_enlisted_navy = c("3", ""))
  list(pow = pow, enl = enl, cw = cw, rank_alpha = rank_alpha, rank_code = rank_code, camp_codes_defined = camps[-1],
       truth = list(camp_eff = camp_eff, ranks_lab = ranks_lab, labels = labels))
}
