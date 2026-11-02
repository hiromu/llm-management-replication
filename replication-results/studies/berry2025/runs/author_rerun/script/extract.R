# Pull author-script results into a long table for comparison with published targets.
.libPaths(c(Sys.getenv("AUTHOR_RLIB"), .libPaths())); suppressMessages({library(lavaan);library(emmeans)})
rec <- readRDS("runs/author_rerun/changed_records.rds"); out <- list(); add <- function(k,v) out[[length(out)+1]] <<- data.frame(key=k,value=as.numeric(v))
ex <- sapply(rec, `[[`, "expr")
for (n in names(rec)) { e <- rec[[n]]$expr; v <- rec[[n]]$value
  if (inherits(v,"htest")) {
    m <- regmatches(e, regexpr("(you_grant|prom_voice|proh_voice)", e)); st <- if (grepl("study1",e)) "P1" else "T2"; add(paste0(st,".",m,".t"),v$statistic); add(paste0(st,".",m,".df"),v$parameter); add(paste0(st,".",m,".p"),v$p.value)}
  if (inherits(v,"effsize")) { m <- regmatches(e, regexpr("(you_grant|prom_voice|proh_voice|benev_trust_broker|integ_trust_broker|val_align_part_broker|relconcerns_with_broker)", e))
    if (grepl("study1",e)) add(paste0("P1.",m,".d"),v$estimate) else if (grepl("study2",e)) add(paste0("T2.",m,".d"),v$estimate) else { h <- if (grepl('divisive',e)) "H3" else "H1"; add(paste0("C3.",h,".",m,".d"),v$estimate) } }
  if (startsWith(n,"pe_")) { cat("\n##",substr(e,1,60), "se option:",rec[[n]]$se_option,"bootstrap R:",rec[[n]]$boot_R,"nobs",rec[[n]]$nobs,"\n"); d <- v[v$op==":=",c("label","est","se","z","pvalue","ci.lower","ci.upper")]; print(d,digits=4); rec[[n]]$defined <- d }
}
print(do.call(rbind,out),digits=6)
write.csv(do.call(rbind,out),"runs/author_rerun/extracted_tests.csv",row.names=FALSE)
pe <- rec[startsWith(names(rec),"pe_")]; saveRDS(pe,"runs/author_rerun/lavaan_estimates.rds")
