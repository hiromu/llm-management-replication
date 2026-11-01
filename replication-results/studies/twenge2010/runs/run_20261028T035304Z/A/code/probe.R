# probe.R -- diagnostic helper: print a compact summary of results/*.json (convergence, n, fit indices, latent contrasts).
# Usage: Rscript code/probe.R [spec_id ...]   (default: all JSON files in results/)
suppressPackageStartupMessages(library(jsonlite))
args <- commandArgs(trailingOnly = TRUE)
files <- if (length(args)) file.path("results", paste0(args, ".json")) else list.files("results", pattern = "^[SC].*\\.json$", full.names = TRUE)
fmt <- function(x, d = 4) if (is.null(x) || length(x) == 0) "NA" else formatC(as.numeric(x), digits = d, format = "f")
for (f in files) {
  r <- fromJSON(f, simplifyVector = FALSE)
  cat("\n==== ", r$spec_id, " status=", r$status, if (!is.null(r$reason)) paste(" reason:", r$reason), " elapsed ", fmt(r$elapsed_seconds, 1), "s\n", sep = "")
  cat("rows read:", paste(names(r$rows_read), unlist(r$rows_read), collapse = ", "), "\n")
  if (!is.null(r$multigroup)) {
    mg <- r$multigroup
    cat("multigroup n:", paste(names(mg$n), unlist(mg$n), collapse = ", "), "\n")
    for (M in names(mg$models)) {
      m <- mg$models[[M]]; fi <- m$fit
      cat(sprintf("  %-8s %-14s iter=%-4s npar=%-4s chisq=%-12s df=%-4s p=%-8s RMSEA=%s CFI=%s TLI=%s SRMR=%s%s\n", M, m$convergence$status, m$convergence$iterations,
                  fi$npar, fmt(fi$chisq, 3), fi$df, fmt(fi$pvalue, 4), fmt(fi$rmsea), fmt(fi$cfi), fmt(fi$tli), fmt(fi$srmr),
                  if (length(m$convergence$warnings)) paste0("  WARN: ", paste(m$convergence$warnings, collapse = " | ")) else ""))
      if (!is.null(m$fit_scaled)) cat(sprintf("           scaled chisq=%s df=%s p=%s\n", fmt(m$fit_scaled$chisq.scaled, 3), m$fit_scaled$df.scaled, fmt(m$fit_scaled$pvalue.scaled)))
    }
    for (dname in names(mg$differences)) { d <- mg$differences[[dname]]
      cat(sprintf("  diff %-6s dchisq=%-10s ddf=%-3s p=%-8s dCFI=%s\n", dname, fmt(d$chisq_diff, 3), d$df_diff, fmt(d$pvalue), fmt(d$cfi_diff, 5))) }
    if (!is.null(mg$latent$by_group)) {
      for (K in names(mg$latent$by_group)) {
        bg <- mg$latent$by_group[[K]]
        cat(sprintf("  %s alpha: %s   psi: %s\n", K, paste(sapply(bg, function(x) fmt(x$alpha, 3)), collapse = " "), paste(sapply(bg, function(x) fmt(x$psi, 3)), collapse = " ")))
        for (P in names(mg$latent$deltas[[K]])) { dl <- mg$latent$deltas[[K]][[P]]; ct <- mg$contrasts$contrasts[[K]][[P]]
          cat(sprintf("     %s Delta=%s SE=%s z=%s p=%s  d_eq=%s d_df=%s g=%s d_glass=%s d_obs=%s\n", P, fmt(dl$delta, 3), fmt(dl$se, 3), fmt(dl$z, 2), fmt(dl$pvalue, 4),
                      fmt(ct$d_eq, 3), fmt(ct$d_df, 3), fmt(ct$g, 3), fmt(ct$d_glass, 3), fmt(ct$d_obs, 3))) }
      }
    }
  }
  if (!is.null(r$single_group)) for (nm in names(r$single_group)) { sg <- r$single_group[[nm]]
    for (y in names(sg$by_year)) { b <- sg$by_year[[y]]; fi <- b$fit
      cat(sprintf("  single %-22s %s n=%-5s %-14s chisq=%-10s df=%-4s RMSEA=%s CFI=%s TLI=%s SRMR=%s%s\n", nm, y, b$sample$n, b$convergence$status, fmt(fi$chisq, 2), fi$df,
                  fmt(fi$rmsea), fmt(fi$cfi), fmt(fi$tli), fmt(fi$srmr), if (length(b$convergence$warnings)) paste0("  WARN: ", paste(b$convergence$warnings, collapse = " | ")) else "")) } }
  if (!is.null(r$coefficient_alpha)) for (sc in names(r$coefficient_alpha$alpha)) { a <- r$coefficient_alpha$alpha[[sc]]
    cat(sprintf("  alpha %-16s %s\n", sc, paste(sapply(intersect(names(a), c("1976", "1991", "2006")), function(y) sprintf("%s: %s (n=%d)", y, fmt(a[[y]]$alpha, 3), a[[y]]$n)), collapse = "  "))) }
  if (!is.null(r$item_statistics)) { it <- r$item_statistics$statistics$form4[[1]]
    cat("  item stats example", names(r$item_statistics$statistics$form4)[1], ":", paste(sapply(names(it$by_year), function(y) sprintf("%s n=%d mean=%s", y, it$by_year[[y]]$n, fmt(it$by_year[[y]]$mean, 3))), collapse = "; "), "\n") }
  if (length(r$deviations)) cat("  deviations/notes:", length(r$deviations), "\n")
}
