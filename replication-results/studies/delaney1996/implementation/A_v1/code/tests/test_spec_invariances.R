# test_spec_invariances.R -- run_spec() end to end on the synthetic survey file and check the
# algebraic invariances the CHK_ specs and the centering axis are designed to have.
# (Synthetic results are meaningless; only structural invariances are tested here.)
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "helpers.R"))
suppressPackageStartupMessages(library(jsonlite))

root <- file.path(tests_dir, "..", "..")
d <- read.csv(file.path(root, "data", "survey.csv"), check.names = FALSE, stringsAsFactors = FALSE)
mis <- parse_metadata(fromJSON(file.path(root, "data", "survey_metadata.json"), simplifyVector = FALSE))
cwp <- parse_crosswalk(read.csv(file.path(root, "data", "industry_crosswalk.csv"), colClasses = "character"))
grid <- fromJSON(file.path(root, "grid_v1.json"), simplifyVector = FALSE)
specs <- setNames(grid$specs, vapply(grid$specs, function(x) x$spec_id, ""))

run <- function(id) { r <- run_spec(d, specs[[id]], mis, cwp); list(co = do.call(rbind, r$coefficients), ms = do.call(rbind, r$model_stats), nt = do.call(rbind, r$nested_tests), sm = do.call(rbind, r$samples)) }
O <- run("O")
check(all(O$ms$status == "ok"), "origin: all 24 models fit on synthetic data")
check(nrow(O$ms) == 24 && length(unique(O$ms$model_id)) == 24, "origin: 24 distinct model ids")
check(all(O$ms$n[O$ms$family == "org"] == O$ms$n[O$ms$family == "org"][1]), "case_scope L0: every org model uses the same N")
check(identical(sort(unique(O$sm$model_id)), "ALL"), "samples: one set per family with model_id ALL under case_scope L0")
check(sum(O$sm$family == "org") == O$ms$n[O$ms$model_id == "org_base"], "samples: org row count equals org N")
check(all(O$co$term[O$co$model_id == "org_M5"][1:7] == c("(Intercept)", "STAFF", "TRAIN", "INCENT", "GRIEV", "DECENT", "VHIER")), "org_M5 term names and order")
check(all(c("TRAIN_x_STAFF", "GRIEV_x_INCENT", "VHIER_x_DECENT") %in% O$co$term[O$co$model_id == "mkt_M10"]), "mkt_M10 interaction terms present")
check(!"NONPROF" %in% O$co$term[O$co$family == "mkt"] && "NONPROF" %in% O$co$term[O$co$family == "org"], "NONPROF only in the organizational family")
check(all(O$nt$df1 == c(6, 6, 3, 3, 6, 6, 3, 3)), "nested tests: numerator df = number of added terms")
check(all(O$nt$df2 == O$ms$f_df2[match(O$nt$full_model, O$ms$model_id)]), "nested tests: denominator df = residual df of the larger model")

hrm_t <- function(R, mid, terms) { x <- R$co[R$co$model_id == mid, ]; x$t[match(terms, x$term)] }
hrm_b <- function(R, mid, terms) { x <- R$co[R$co$model_id == mid, ]; x$estimate[match(terms, x$term)] }

A <- run("CHK_industry_ref_alt")
for (mid in c("org_M2", "org_M5", "mkt_M7", "mkt_M10"))
  check_equal(hrm_b(A, mid, HRM_TERMS[HRM_TERMS %in% A$co$term[A$co$model_id == mid]]),
              hrm_b(O, mid, HRM_TERMS[HRM_TERMS %in% O$co$term[O$co$model_id == mid]]),
              paste("CHK_industry_ref_alt: HRM estimates invariant to the omitted industry group,", mid), tol = 1e-7)
check_equal(A$ms$r2, O$ms$r2, "CHK_industry_ref_alt: R2 invariant", tol = 1e-9)
check(!identical(A$co$term[A$co$model_id == "org_base"], O$co$term[O$co$model_id == "org_base"]), "CHK_industry_ref_alt: a different group is omitted")

H <- run("CHK_hierarchy_log10")
check_equal(hrm_b(H, "org_M3", "VHIER"), hrm_b(O, "org_M3", "VHIER") * log(10), "CHK_hierarchy_log10: VHIER estimate scales by ln(10)", tol = 1e-9)
check_equal(hrm_t(H, "org_M3", c("STAFF", "VHIER")), hrm_t(O, "org_M3", c("STAFF", "VHIER")), "CHK_hierarchy_log10: t statistics invariant", tol = 1e-9)
check_equal(H$ms$r2, O$ms$r2, "CHK_hierarchy_log10: R2 invariant", tol = 1e-9)

P <- run("CHK_pct_proportion")
check_equal(P$co$estimate[P$co$model_id == "org_M2" & P$co$term == "PCTMGR"], 100 * O$co$estimate[O$co$model_id == "org_M2" & O$co$term == "PCTMGR"], "CHK_pct_proportion: PCTMGR estimate scales by 100", tol = 1e-9)
check_equal(hrm_t(P, "mkt_M9", c("STAFF", "TRAIN_x_STAFF")), hrm_t(O, "mkt_M9", c("STAFF", "TRAIN_x_STAFF")), "CHK_pct_proportion: t statistics invariant", tol = 1e-9)

C <- run("D34")
ints <- c("TRAIN_x_STAFF", "GRIEV_x_INCENT", "ILM_x_DECENT")
check_equal(hrm_b(C, "org_M4", ints), hrm_b(O, "org_M4", ints), "centering L1: interaction estimates equal raw-product estimates", tol = 1e-8)
check(any(abs(hrm_b(C, "org_M4", c("STAFF", "TRAIN")) - hrm_b(O, "org_M4", c("STAFF", "TRAIN"))) > 1e-8), "centering L1: main effects change")
check_equal(C$ms$r2, O$ms$r2, "centering L1: R2 invariant", tol = 1e-9)
check_equal(C$nt$f, O$nt$f, "centering L1: nested F invariant", tol = 1e-9)

L1 <- run("D04")
check(any(L1$ms$n != L1$ms$n[1]), "case_scope L1: model-specific N differ")
check(all(L1$nt$n == L1$ms$n[match(L1$nt$full_model, L1$ms$model_id)]), "case_scope L1: nested tests use the full model's rows")
check(length(unique(L1$sm$model_id)) == 24, "case_scope L1: samples written per model")
check(L1$ms$n[L1$ms$model_id == "org_base"] >= O$ms$n[O$ms$model_id == "org_base"], "case_scope L1: base sample at least as large as the common sample")

W <- run("D33")
check(all(W$ms$status == "ok"), "weights L1: WLS models fit")
check(W$ms$n[1] <= O$ms$n[1], "weights L1: rows with missing/zero weight excluded")

Z1 <- run("D09"); Z2 <- run("D10"); Z3 <- run("D11")
check(Z1$ms$n[1] == O$ms$n[1] && Z2$ms$n[1] == O$ms$n[1], "z_reference L1/L2: samples do not depend on standardization")
check(any(abs(hrm_b(Z1, "org_M2", "STAFF") - hrm_b(O, "org_M2", "STAFF")) > 1e-10), "z_reference L1 changes STAFF scale")
check(abs(hrm_b(Z3, "org_M2", "STAFF") - hrm_b(O, "org_M2", "STAFF")) > 1e-10, "z_reference L3: estimate differs from sample-SD scaling")
fO <- build_frame(d, specs[["O"]]$settings, mis, cwp); zO <- add_z_indices(fO, "L0"); z3 <- add_z_indices(fO, "L0", NULL, pop_sd = TRUE)
for (cn in c("staff_z1", "train_z2")) {
  nv <- sum(!is.na(fO[[sub("_z", "_i", cn)]]))
  check_equal(z3[[cn]], zO[[cn]] * sqrt(nv / (nv - 1)), paste("z_reference L3: each item z equals the L0 z times sqrt(n/(n-1)),", cn), tol = 1e-10)
}
check(Z3$ms$n[1] == O$ms$n[1], "z_reference L3: sample unchanged")

res <- test_summary("test_spec_invariances")
