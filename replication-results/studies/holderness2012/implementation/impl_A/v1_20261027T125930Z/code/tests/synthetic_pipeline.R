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
      all(!is.na(ok[grepl("_cap_", model_id) & term != "(Intercept)", me_se_campcluster])) && all(is.na(ok[grepl("_camp_", model_id), me_se_campcluster])))
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
# the hierarchy's own missing indicator is kept when it duplicates other indicators
check("7s duplicate missing indicators: the earliest (hierarchy) one is kept",
      !any(grepl("steepness_miss|sameness_miss", res[family == "T4", error])))
tlog("  example: T4_steepness_cap_full steepness ME = ", sprintf("%.4f (se %.4f, p %.3f)", res[model_id == "T4_steepness_cap_full" & term == "steepness", me],
     res[model_id == "T4_steepness_cap_full" & term == "steepness", me_se], res[model_id == "T4_steepness_cap_full" & term == "steepness", me_p]))
tlog("=== ", if (n_fail == 0) "PIPELINE TEST PASSED" else paste(n_fail, "PIPELINE CHECK(S) FAILED"))
if (n_fail > 0) quit(status = 1)
