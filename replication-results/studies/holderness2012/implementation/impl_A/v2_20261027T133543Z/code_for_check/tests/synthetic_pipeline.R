# End-to-end exercise of run_spec() on a SYNTHETIC POW-like data set (no real data), covering every
# model family, the T5ROC comparisons and the influence loop. Appends to tests/test_log.txt.
# Run from the project folder:  Rscript tests/synthetic_pipeline.R
src <- if (file.exists("run.R")) "run.R" else file.path("..", "run.R")
source(src)
source(file.path(dirname(src), "tests", "synthetic_data.R"))
log_path <- file.path(dirname(src), "tests", "test_log.txt")
tlog <- function(...) { msg <- paste0(..., collapse = ""); cat(msg, "\n"); cat(msg, "\n", file = log_path, append = TRUE) }
n_fail <- 0
check <- function(name, cond, detail = "") {
  if (isTRUE(cond)) tlog("PASS ", name, if (nzchar(detail)) paste0("  [", detail, "]")) else { n_fail <<- n_fail + 1; tlog("FAIL ", name, "  [", detail, "]") }
}
tlog("--- Test 7: synthetic end-to-end pipeline (all families), ", format(Sys.time()))
inputs <- make_synthetic_inputs(20000)
grid <- fromJSON(if (file.exists("grid.json")) "grid.json" else "../grid.json", simplifyVector = FALSE)
spec <- grid$specs[[1]]
out_dir <- file.path(dirname(src), "tests", "_synthetic_out")
unlink(out_dir, recursive = TRUE); dir.create(file.path(out_dir, "sample_ids"), recursive = TRUE, showWarnings = FALSE)
.log_file <<- file.path(out_dir, "run_log.txt")
opts <- list(out = out_dir, influence = "first20", families = NULL, dry = FALSE)
state <- new.env(); state$results <- list(); state$roc <- list(); state$infl <- list()
t0 <- Sys.time()
run_spec(spec, inputs, opts, state)
write_outputs(out_dir, state$results, state$roc, state$infl)
tlog(sprintf("  synthetic run of all S000 families (%d POW rows) took %s", nrow(inputs$pow), format(round(difftime(Sys.time(), t0, units = "secs"), 1))))

res <- fread(file.path(out_dir, "results.csv"))
roc <- fread(file.path(out_dir, "roc.csv"))
inf <- fread(file.path(out_dir, "influence.csv"))
defs <- model_defs(unlist(spec$families), spec$params)
expected_models <- names(defs)
got <- unique(res$model_id)
check("7a every defined model appears in results.csv", setequal(expected_models, got), sprintf("%d models expected, %d found; missing: %s", length(expected_models), length(got), paste(setdiff(expected_models, got), collapse = ",")))
check("7b model count by family matches manifest (8,4,8,4,8,8,8,8,8,8,4,14,10,4)",
      identical(as.integer(table(factor(vapply(defs, `[[`, "", "family"), levels = c("T4", "T5", "T6", "R_cc", "R_n50", "R_n100", "R_noexec", "R_ger", "R_jap", "R_aaf", "R_nosq", "R_alt", "R_friends", "R_int")))),
                c(8L, 4L, 8L, 4L, 8L, 8L, 8L, 8L, 8L, 8L, 4L, 14L, 10L, 4L)))
st <- res[, .(status = status[1], error = error[1]), by = model_id]
# synthetic cohorts rarely reach 100 members, so R_n100 captured-cohort fits may legitimately have an
# empty estimation sample; that exercises the failure path (status "failed" with an error, run continues)
bad <- st[status != "ok"]
check("7c all synthetic fits ok except (possibly) R_n100 cap fits with an empty sample",
      all(grepl("^Rn100_.*_cap_", bad$model_id)) && all(bad$status == "failed") && all(nzchar(bad$error)),
      paste(bad[, paste(model_id, status, error)], collapse = "; "))
ok <- res[status == "ok"]
expected_models_ok <- setdiff(expected_models, bad$model_id)
check("7d cap models report camp-clustered SEs, camp models do not",
      all(!is.na(ok[grepl("_cap_", model_id) & term != "(Intercept)" & !is.na(coef), me_se_campcluster])) && all(is.na(ok[grepl("_camp_", model_id), me_se_campcluster])))
check("7e cap models contain camp dummies and dropped-camp counts", all(ok[grepl("_cap_", model_id), any(grepl("^camp_", term)), by = model_id]$V1) && all(!is.na(ok[grepl("_cap_", model_id), dropped_camps_pp])))
check("7f R_ger/R_jap camp models omit japan", !any(ok[family %in% c("R_ger", "R_jap") & grepl("_camp_", model_id), term] == "japan"))
check("7g T6 models have the interaction term", all(ok[family == "T6", any(grepl("officer_x_", term)), by = model_id]$V1))
check("7h R_int models have hierarchy x men", all(ok[family == "R_int", any(grepl("_x_men$", term)), by = model_id]$V1))
check("7i R_nosq models have no men_sq", !any(ok[family == "R_nosq", term] == "men_sq"))
check("7j roc.csv has 8 rows, all ok, with equal-row comparisons", nrow(roc) == 8 && all(roc$status == "ok"), paste(roc$status, collapse = ","))
check("7k influence.csv has 20 camps x 8 T4 models", nrow(inf) == 160 && all(inf$status == "ok"), sprintf("rows = %d; statuses: %s", nrow(inf), paste(unique(inf$status), collapse = ",")))
check("7l sample id files written for every fitted model", all(file.exists(file.path(out_dir, "sample_ids", paste0("S000__", expected_models_ok, ".txt")))))
check("7m pseudo R2 in (0,1) and ll >= ll0", all(ok[, pseudo_r2 > 0 & pseudo_r2 < 1 & ll >= ll0]),
      sprintf("pseudo R2 range %.4f..%.4f", min(ok$pseudo_r2), max(ok$pseudo_r2)))
check("7n p values in [0,1]", all(ok[!is.na(me_p), me_p >= 0 & me_p <= 1]))
check("7o R_n50 samples only contain groups with n_g >= 50 (n smaller than T4)", all(ok[family == "R_n50", n][1] < ok[family == "T4", n][1]))
# cross-check one camp-cohort model against glm on the same design (name-matched; glm gives NA for collinear columns)
S <- build_spec_data(inputs, spec$params)
m <- defs[["T4_steepness_camp_full"]]
mf <- model_frame(S, "camp", "incl_self")
D <- build_design(mf, m$vars, m$inter)
g <- glm(mf$survival ~ D$X[, -1], family = binomial(link = "probit"), control = glm.control(maxit = 200, epsilon = 1e-12))
cf <- coef(g); names(cf) <- sub("^D\\$X\\[, -1\\]", "", names(cf))
mine <- res[model_id == "T4_steepness_camp_full"]; mc <- setNames(mine$coef, mine$term)
common <- intersect(names(mc), names(cf)[!is.na(cf)])
check("7p T4 camp full coefficients equal glm on the same design (glm precision ~1e-4) and LL not below glm",
      max(abs(mc[common] - cf[common])) < 1e-3 && mine$ll[1] >= as.numeric(logLik(g)) - 1e-6,
      sprintf("max diff = %.2e over %d terms, n = %d, ll mine %.6f glm %.6f", max(abs(mc[common] - cf[common])), length(common), mine$n[1], mine$ll[1], as.numeric(logLik(g))))
# cross-check one cap model against glm with camp dummies
m2 <- defs[["T4_sameness_cap_full"]]
ef <- estimation_frame(model_frame(S, "cap", "incl_self"), m2)
D2 <- build_design(ef$mf, m2$vars, m2$inter)
g2 <- glm(ef$mf$survival ~ D2$X[, -1] + factor(ef$mf$camp), family = binomial(link = "probit"), control = glm.control(maxit = 200, epsilon = 1e-12))
cf2 <- coef(g2); names(cf2) <- sub("^D2\\$X\\[, -1\\]", "", names(cf2)); names(cf2) <- sub("^factor\\(ef\\$mf\\$camp\\)", "camp_", names(cf2))
mine2 <- res[model_id == "T4_sameness_cap_full"]; mc2 <- setNames(mine2$coef, mine2$term)
common2 <- intersect(names(mc2), names(cf2)[!is.na(cf2)])
check("7q T4 cap full coefficients equal glm with camp dummies (glm precision ~1e-4) and LL not below glm",
      max(abs(mc2[common2] - cf2[common2])) < 1e-3 && mine2$ll[1] >= as.numeric(logLik(g2)) - 1e-6,
      sprintf("max diff = %.2e over %d terms, n = %d, camps dropped = %d, ll mine %.4f glm %.4f", max(abs(mc2[common2] - cf2[common2])), length(common2), mine2$n[1], ef$dropped_camps, mine2$ll[1], as.numeric(logLik(g2))))
# the synthetic truth: officer effect positive, japan negative in camp models
check("7r synthetic truth: officer ME positive and significant in T4 cap full (japan is camp-level: 45 camps, reported only)",
      res[model_id == "T4_steepness_cap_full" & term == "officer", me > 0 & me_p < 0.01],
      sprintf("japan ME = %.3f (p %.3f), officer ME = %.3f (p %.3f)", res[model_id == "T4_steepness_camp_full" & term == "japan", me],
              res[model_id == "T4_steepness_camp_full" & term == "japan", me_p], res[model_id == "T4_steepness_cap_full" & term == "officer", me],
              res[model_id == "T4_steepness_cap_full" & term == "officer", me_p]))
# the hierarchy's own missing indicator is kept when it duplicates other indicators; the omitted duplicates
# are reported as terms with NA estimates
omitted_ok <- res[grepl("omitted exactly collinear", error), {
  nm <- strsplit(sub(".*omitted exactly collinear \\(reported with NA\\): ([^;]*).*", "\\1", error[1]), "|", fixed = TRUE)[[1]]
  all(nm %in% term[is.na(coef)]) && all(!is.na(coef[!term %in% nm]))
}, by = model_id]$V1
check("7s duplicate missing indicators: the hierarchy's own indicator is kept in T4; every omitted column is reported as a term with NA estimates",
      !any(grepl("steepness_miss|sameness_miss", res[family == "T4", error])) && length(omitted_ok) > 0 && all(omitted_ok),
      sprintf("%d models with omitted columns", length(omitted_ok)))
# family order: T5ROC runs right after T5 and before T6 (grid order)
lg <- readLines(file.path(out_dir, "run_log.txt"))
i_roc <- grep(" T5ROC ", lg)[1]; i_t6 <- grep(" T6_", lg)[1]; i_t5 <- grep(" T5_", lg)[1]
check("7t T5ROC runs after T5 and before T6", !is.na(i_roc) && !is.na(i_t6) && i_t5 < i_roc && i_roc < i_t6, sprintf("first T5 line %d, T5ROC %d, T6 %d", i_t5, i_roc, i_t6))
# R_cc cap models do not require distance (distance is a camp-model covariate only)
mf_cap <- model_frame(S, "cap", "incl_self")
ef_cc <- estimation_frame(mf_cap, defs[["Rcc_steepness_cap_full"]])
check("7u R_cc cap sample keeps rows with missing distance (complete-case covariates only) and matches results.csv",
      any(is.na(ef_cc$mf$distance)) && res[model_id == "Rcc_steepness_cap_full", n][1] == nrow(ef_cc$mf),
      sprintf("rows with missing distance in the cap complete-case sample: %d of %d", sum(is.na(ef_cc$mf$distance)), nrow(ef_cc$mf)))
# R_aaf: group variables computed over the AAF estimation sample
mf_aaf <- model_frame(S, "camp", "incl_self", "aaf")
chk <- mf_aaf[aaf == TRUE, .(n_g = fifelse(is.na(n_g[1]), 0, as.numeric(n_g[1])), n_members = sum(!is.na(rank))), by = camp]
check("7v R_aaf camp n_g equals the number of AAF rows of R with a rank in the camp", all(chk$n_g == chk$n_members) && res[family == "R_aaf", n][1] > 0,
      sprintf("%d camps checked", nrow(chk)))
# friends with incl_self: count of members with the row's unit; non-member rows are not counted
mf_camp <- model_frame(S, "camp", "incl_self")
mb <- S$members$all$camp[!is.na(unit)]
cnt <- mb[, .N, by = .(g, unit)]
ref <- cnt$N[match(paste(mf_camp$camp, mf_camp$unit), paste(cnt$g, cnt$unit))]; ref[is.na(ref)] <- 0
exp_fr <- ifelse(is.na(mf_camp$unit) | ref == 0, NA_real_, log(ref))
check("7w friends (incl_self) = ln(members with the same unit); non-members with no such member are missing",
      isTRUE(all.equal(mf_camp$friends, exp_fr)) && any(is.na(mf_camp$rank) & !is.na(mf_camp$unit) & is.na(mf_camp$friends)))
# a failed base fit still writes its sample ids and still runs the influence loop over its estimation rows
fit_model_orig <- fit_model
target <- "T4_steepness_camp_simple"
n_full <- estimation_frame(mf_camp, defs[[target]])$mf[, .N]
fit_model <- function(mf, m) { if (m$model_id == target && nrow(mf) == n_full) stop("synthetic failure"); fit_model_orig(mf, m) }
out2 <- file.path(dirname(src), "tests", "_synthetic_out_fail")
unlink(out2, recursive = TRUE); dir.create(file.path(out2, "sample_ids"), recursive = TRUE, showWarnings = FALSE)
.log_file <<- file.path(out2, "run_log.txt")
state2 <- new.env(); state2$results <- list(); state2$roc <- list(); state2$infl <- list()
spec2 <- spec; spec2$families <- list("T4", "INFLUENCE")
run_spec(spec2, inputs, list(out = out2, influence = "first20", families = NULL, dry = FALSE), state2)
write_outputs(out2, state2$results, state2$roc, state2$infl)
fit_model <- fit_model_orig
res2 <- fread(file.path(out2, "results.csv")); inf2 <- fread(file.path(out2, "influence.csv"))
ids2 <- file.path(out2, "sample_ids", paste0("S000__", target, ".txt"))
check("7x failed base fit: status failed, sample id file written with the estimation rows",
      res2[model_id == target, status][1] == "failed" && file.exists(ids2) && length(readLines(ids2)) == n_full)
check("7y failed base fit: leave-one-camp-out fits still run and are recorded",
      inf2[model_id == target, .N] == 20 && all(inf2[model_id == target, status] == "ok"), sprintf("%d influence rows", inf2[model_id == target, .N]))
unlink(out2, recursive = TRUE)
tlog("  example: T4_steepness_cap_full steepness ME = ", sprintf("%.4f (se %.4f, p %.3f)", res[model_id == "T4_steepness_cap_full" & term == "steepness", me],
     res[model_id == "T4_steepness_cap_full" & term == "steepness", me_se], res[model_id == "T4_steepness_cap_full" & term == "steepness", me_p]))
tlog("=== ", if (n_fail == 0) "PIPELINE TEST PASSED" else paste(n_fail, "PIPELINE CHECK(S) FAILED"))
if (n_fail > 0) quit(status = 1)
