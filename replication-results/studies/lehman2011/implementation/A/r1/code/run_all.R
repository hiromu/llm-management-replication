#!/usr/bin/env Rscript
# Entry script for manifest P01 (neutral, target-free), v1.
# Usage (from the project directory):  Rscript code/run_all.R --stage synthetic|sample|full [--cores N]
# Reads only data/, writes to results/.

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(name, default) {
  i <- which(args == name)
  if (length(i) && i < length(args)) return(args[i + 1])
  kv <- grep(paste0("^", name, "="), args, value = TRUE)
  if (length(kv)) return(sub(paste0("^", name, "="), "", kv[1]))
  default
}
stage <- get_arg("--stage", "full")
cores_arg <- get_arg("--cores", "auto")
if (!stage %in% c("synthetic", "sample", "full")) stop("--stage must be synthetic, sample or full")
nc <- tryCatch(parallel::detectCores(), error = function(e) NA)
cores <- if (cores_arg == "auto") max(1L, min(8L, as.integer(if (is.na(nc)) 1 else nc %/% 2))) else max(1L, as.integer(cores_arg))

# locate project directory (parent of code/)
script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
proj <- if (length(script_path)) normalizePath(file.path(dirname(script_path), "..")) else getwd()
setwd(proj)
code_dir <- file.path(proj, "code"); results_dir <- file.path(proj, "results")
dir.create(results_dir, showWarnings = FALSE); dir.create(file.path(results_dir, "samples"), showWarnings = FALSE)

suppressPackageStartupMessages({ library(survival); library(nanoparquet) })
for (f in c("lib_clogit.R", "lib_data.R", "lib_fit.R", "lib_relogit.R", "lib_synthetic.R", "lib_grid.R")) source(file.path(code_dir, f))

NOTES <- new.env(); NOTES$items <- character(0)
NOTES$add <- function(x) NOTES$items <- c(NOTES$items, x)

t_start <- Sys.time()
write_env <- function(end = NULL) {
  si <- Sys.info()
  lines <- c(sprintf("stage: %s", stage), sprintf("start: %s", format(t_start, "%Y-%m-%dT%H:%M:%S%z")),
             if (!is.null(end)) sprintf("end: %s", format(end, "%Y-%m-%dT%H:%M:%S%z")) else "end: (running)",
             if (!is.null(end)) sprintf("elapsed_minutes: %.1f", as.numeric(end - t_start, units = "mins")),
             sprintf("cores (influence-loop socket workers; --cores, default auto = min(8, detectCores()/2)): %d (detectCores = %s)", cores, as.character(nc)),
             sprintf("R: %s", R.version.string), sprintf("platform: %s", R.version$platform),
             sprintf("OS: %s %s %s", si["sysname"], si["release"], si["machine"]),
             sprintf("survival: %s", as.character(packageVersion("survival"))),
             sprintf("nanoparquet: %s", as.character(packageVersion("nanoparquet"))),
             sprintf("stats/tools: %s", as.character(packageVersion("stats"))),
             sprintf("BLAS: %s", extSoftVersion()["BLAS"]), sprintf("LAPACK: %s", La_version()),
             "language: R", "seed for synthetic data: 20261027 (base R default RNG, Mersenne-Twister)")
  writeLines(lines, file.path(results_dir, "environment.txt"))
}
write_env()

write_notes <- function() {
  static <- c(
    "# Implementation notes (code/run_all.R)",
    "",
    sprintf("Stage run: %s. Generated %s.", stage, format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
    "",
    "## Estimators",
    "- U7 = 0 and U7 = 2 (exact conditional logit): own R implementation in code/lib_clogit.R (`cl_fit`). The exact conditional likelihood is evaluated through prefix/suffix recursions of the elementary symmetric polynomials with per-stratum exponential tilting; score and observed information are analytic; Newton-Raphson with step halving; convergence when max |score| < 1e-7 and the relative LL change < 1e-11. survival::clogit(method = 'exact') maximises the same likelihood but is several times slower at the stratum sizes here (about 700 plays with about 80 attempts per team); the synthetic stage verifies equality of LL, coefficients and SEs with survival::clogit / coxph(ties = 'exact') and with a direct enumeration of all subsets on a small case (results/synthetic_checks.md). The native covariance is the inverse of the observed information at the MLE.",
    "- Groups with no variation in y are removed before the U7 = 0/2 fits (they contribute nothing to the conditional likelihood) and counted in n_groups_dropped. The null conditional LL is -sum_g log C(n_g, d_g) over the groups used, which equals the conditional LL at beta = 0.",
    "- Columns that are collinear within strata (aliased) would be dropped with NA estimates; none were expected in the grid.",
    "- U7 = 1: stats::glm.fit, binomial logit, intercept + regressors + team dummies (alphabetically first team omitted), epsilon = 1e-12. Native covariance = inverse Fisher information (observed = expected for the canonical link). The null is intercept + team dummies only.",
    "- Benchmark covariance: CR1 cluster-robust sandwich by game_id, factor G/(G-1) x (N-1)/(N-K), K = all estimated parameters including intercept and team dummies; two-sided normal p.",
    "- N1: own adaptive Gauss-Hermite implementation (12 points; per-team mode and curvature re-estimated at every likelihood evaluation; regressors standardised internally and transformed back), optimised by BFGS with the analytic quadrature gradient followed by Newton polishing; SEs from the inverse of the numerically differentiated Hessian of the marginal log-likelihood. The synthetic stage checks the gradient numerically and the sensitivity to 20 quadrature points. sigma_u is reported with a delta-method SE from ln_sigma_u; rho = sigma_u^2/(sigma_u^2 + pi^2/3). The N1 null model is intercept + random intercept only. Marginal effects for N1 use the index without the intercept and with the random effect set to 0 (same index convention as U7 = 0/1).",
    "",
    "## Samples and variables",
    "- S5 with a missing game_seconds_remaining would drop the row (the condition is not satisfied); S2 drops rows with missing down; S4 drops missing qtr.",
    "- S3b (U1 = 1): a no_play row is a non-attempt if punt_attempt == 1 or field_goal_attempt == 1, otherwise an attempt if pass == 1 or rush == 1, otherwise dropped. Missing flags count as 0.",
    "- Sample files: results/samples/<sha256>.csv.gz, header game_id,play_id, rows sorted in C-locale byte order of the 'game_id|play_id' string (play_id printed as an integer). The hash is SHA-256 (tools::sha256sum) of the sorted 'game_id|play_id' lines joined by newline with a trailing newline.",
    "- sample_flow.csv has one block per distinct realised sample (hash) with the U1..U6 levels of the first cell that produced it; S8 is recorded as the common complete-case count plus rows for the number dropped, the model-specific complete-case counts and a flag row (rows = 1 if they differ). An extra row records the same_division vs games.div_game disagreement count. results/sample_cells.csv maps every U1..U6 combination to its hash.",
    "- The row set depends on U1, U2, U3 only (U4-U6 change variable definitions without creating missing values), so there are at most 8 distinct samples.",
    "- same_conference, same_division: from the alignment table for the season; home_field: posteam_type == 'home' (U6 = 1 sets 0 in games with games.location == 'Neutral').",
    "",
    "## Grid, outputs",
    "- A `step` column was added to coefs.csv, margins.csv and tests.csv (in addition to specs.csv) because step-3 duplicates of step-1/2 cells carry the same spec_id; duplicate rows are flagged in specs.csv (duplicate_of = 'step k: <spec_id>') and are re-fitted, not copied.",
    "- Marginal effects use estimation-sample means over the rows actually used by the fit (after dropping non-varying groups for U7 = 0/2). M2 minutes_eval is the estimation-sample mean of minutes (U4 = 1: of floored minutes). For U7 = 1 fits the index excludes the intercept and team dummies. U9a is computed from the U7 = 1 fit of the same cell (for U7 = 0/2 cells that counterpart is fitted on demand and cached; the same combination is fitted again in step 3). U9a rows also carry se_bench from the U7 = 1 benchmark covariance although only the native SE was required.",
    "- U9b at d uses the branch rule for d and for d + 1 separately (d = 0 -> d + 1 = 1 is on the above branch).",
    "- nonequiv.csv and algebraic_checks.csv are long files: run_id, record (spec/coef/margin/test/check) and the union of the specs/coefs/margins/tests columns. N2 includes all marginal-effect variants with quarters_remaining in {4,3,2,1} (M3) and the sample mean of quarters_remaining (M2); its U9a uses a U7 = 1 fit with quarters_remaining. N4 reports the team-clustered CR1 covariance in the se_bench/p_bench columns (coefficients and ME0).",
    "- K1/K2: the 'check' records hold the LL differences and (K2) both home-field coefficients.",
    "- influence.csv: estimate/se_native/p_native from the U7 = 0 refit; se_bench/p_bench from the game-clustered CR1 covariance of the U7 = 1 refit (p_bench uses the U7 = 1 estimate). Refits are warm-started from the origin estimates (details in the run-specific notes). Units: team, season and game. Every unit is run; failures are recorded with status/error.",
    "- The influence loop runs on a socket cluster (parallel::makeCluster/parLapplyLB; separate R processes, deterministic and identical to a serial run). Optional argument --cores N sets the worker count; default auto = min(8, detectCores()/2); falls back to serial if a cluster cannot be started. All other steps run serially in compute_order.",
    "- Grid fits are cold-started (beta = 0 for U7 = 0/2; glm default for U7 = 1); the conditional and unconditional log-likelihoods are concave so the start does not affect the solution.",
    "- Not executed (grid.json 'unavailable'): spread-based reference point and field-goal-range submodels.",
    "",
    "## Run-specific notes")
  writeLines(c(static, if (length(NOTES$items)) paste0("- ", NOTES$items) else "- (none)"), file.path(results_dir, "implementation_notes.md"))
}

if (stage == "synthetic") {
  log_msg("synthetic checks")
  st <- run_synthetic_checks(file.path(results_dir, "synthetic_checks.md"))
  NOTES$add(sprintf("Synthetic checks: %s.", paste(sprintf("%s=%s", names(st), ifelse(unlist(st), "PASS", "FAIL")), collapse = ", ")))
  print(unlist(st))
} else {
  log_msg("loading raw data")
  raw <- load_raw(file.path(proj, "data"))
  log_msg("play-by-play rows: %d; games rows: %d; alignment rows: %d", nrow(raw$pbp), nrow(raw$games), nrow(raw$align))
  if (stage == "sample") {
    run_sample_stage(raw, results_dir)
  } else {
    run_full(raw, results_dir, cores = cores, code_dir = code_dir)
  }
}
t_end <- Sys.time()
write_env(t_end)
write_notes()
log_msg("done (%s) in %.1f minutes", stage, as.numeric(t_end - t_start, units = "mins"))
