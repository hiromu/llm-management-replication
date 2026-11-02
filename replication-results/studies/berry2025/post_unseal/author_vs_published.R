# Comparison 2: author-script output, with its recorded minimal changes, against sealed published targets.
.libPaths(c(Sys.getenv("AUTHOR_RLIB"), .libPaths())); suppressMessages({library(lavaan);library(emmeans);library(jsonlite)})
rec <- readRDS("runs/author_rerun/changed_records.rds"); T <- fromJSON("sealed/targets/targets_reconciled.json")
out <- list(); add <- function(k,v,src) out[[length(out)+1]] <<- data.frame(key=k,value=as.numeric(v)[1],source=src)
OUT <- "(you_grant|prom_voice|proh_voice|benev_trust_broker|integ_trust_broker|val_align_part_broker|relconcerns_with_broker)"
cur <- NA; term <- c("relationship","history","interaction")
for (n in names(rec)) { e <- rec[[n]]$expr; v <- rec[[n]]$value
  if (grepl("^fit[0-9]* <- lm\\(",e)) cur <- regmatches(e,regexpr(OUT,e))
  if (grepl("^fit[0-9]* <- glm",e)) { f <- if (grepl("LoyaltyHouse",e)) "M3" else if (grepl("KnowRequestor",e)) "M2" else "M1"; curm <- f }
  if (inherits(v,"htest")) { m <- regmatches(e,regexpr(OUT,e)); st <- if (grepl("study1",e)) "P1" else "T2"; add(paste0(st,".",m,".t"),abs(v$statistic),"t.test") }
  if (inherits(v,"effsize")) { m <- regmatches(e,regexpr(OUT,e)); k <- if (grepl("study1",e)) paste0("P1.",m,".d") else if (grepl("study2",e)) paste0("T2.",m,".d") else paste0("C3.",if (grepl("divisive",e)) "H3" else "H1",".",m,".d"); add(k,abs(v$estimate),"effsize::cohen.d") }
  if (grepl("^anova_test",e)) { m <- regmatches(e,regexpr(OUT,e)); d <- as.data.frame(v); add(paste0("M1.",m,".F"),d$F[d$Effect=="wrongdoing:cond"],"rstatix::anova_test") }
  if (grepl("^etasq",e)) { for (i in 1:3) add(paste0("A3.",cur,".",term[i],".eta2"),v[i,1],"heplots::etasq") }
  if (grepl("^test\\(contrast",e)) { t_ <- if (grepl('"cond_rel"\\), "trt',e)) "relationship" else if (grepl('"broker_hist"\\), "trt',e)) "history" else "interaction"; add(paste0("A3.",cur,".",t_,".F"),v$F.ratio,"emmeans joint test") }
  if (grepl("^emmeans\\(fit1, pairwise",e)) { s <- as.data.frame(summary(v$contrasts))
     if (grepl("cond_rel \\| broker_hist",e)) { i <- which(s$broker_hist=="control"); add(paste0("C3.H1.",cur,".t"),abs(s$t.ratio[i]),"emmeans pairwise") } else { i <- which(s$cond_rel=="loyal_colleague"); add(paste0("C3.H3.",cur,".t"),abs(s$t.ratio[i]),"emmeans pairwise") } }
  if (grepl("^summarySE",e)) { d <- as.data.frame(v); o <- cur; for (j in seq_len(nrow(d))) { c_ <- paste0(if (d$cond_rel[j]=="loyal_colleague") "L" else "C", if (d$broker_hist[j]=="divisive") "D" else "C"); y <- d[j,o]; add(paste0("C3.cell.",o,".",c_,".mean"),y,"Rmisc::summarySE"); add(paste0("C3.cell.",o,".",c_,".sd"),d$sd[j],"Rmisc::summarySE") } }
  if (grepl("^summary\\(fit[0-9]+\\)$",e) && !is.null(v$coefficients) && "glm" %in% class(v$call[[1]]) == FALSE && exists("curm")) { cf <- v$coefficients; if (nrow(cf)>1 && colnames(cf)[1]=="Estimate") for (r in rownames(cf)[-1]) { add(paste0("L4.",curm,".",r,".coef"),cf[r,1],"glm"); add(paste0("L4.",curm,".",r,".or"),exp(cf[r,1]),"glm") } }
  if (grepl("DescTools::PseudoR2",e)) { add(paste0("L4.",curm,".fit.mcf"),v["McFadden"],"DescTools"); add(paste0("L4.",curm,".fit.cs"),v["CoxSnell"],"DescTools") }
}
pe <- rec[startsWith(names(rec),"pe_")]; ord <- list(); s2 <- which(sapply(pe,function(p) grepl("model1",p$expr)))
for (i in seq_along(s2)) { d <- pe[[s2[i]]]$value; d <- d[d$op==":=",]; o <- c("you_grant","prom_voice","proh_voice")[i]
  for (x in list(c("indirect1","benev_trust_broker"),c("indirect2","integ_trust_broker"),c("indirect3","val_align_part_broker"),c("indirect5","relconcerns_with_broker"))) { r <- d[d$label==x[1],]; k <- paste0("PM2.",o,".",x[2],".ind"); add(k,r$est,"lavaan"); add(paste0(k,"#se"),r$se,"lavaan"); add(paste0(k,"#ci_low"),r$ci.lower,"lavaan"); add(paste0(k,"#ci_high"),r$ci.upper,"lavaan"); add(paste0(k,"#p"),r$pvalue,"lavaan") } }
s <- which(sapply(pe,function(p) grepl("mod2",p$expr))); for (i in seq_along(s)) { d <- pe[[s[i]]]$value; r <- d[d$label=="ind2",]; k <- paste0("SM2.",c("val_align_part_broker","relconcerns_with_broker")[i],".ind"); add(k,r$est,"lavaan"); add(paste0(k,"#se"),r$se,"lavaan"); add(paste0(k,"#p"),r$pvalue,"lavaan") }
s <- which(sapply(pe,function(p) grepl("mod1",p$expr))); nm <- list(c("sim","SignedTrust","indirect1"),c("sim","SignedRisk","indirect2"),c("ind","SignedTrust","indirect1"),c("ind","SignedRisk","indirect1")); j <- 0
for (i in s) { d <- pe[[i]]$value; for (lab in d$label[d$op==":="]) { j <- j+1; x <- nm[[j]]; r <- d[d$label==lab,]; k <- paste0("MED4.",x[1],".",x[2],".ind"); add(k,r$est,"lavaan"); add(paste0(k,"#se"),r$se,"lavaan"); add(paste0(k,"#ci_low"),r$ci.lower,"lavaan"); add(paste0(k,"#ci_high"),r$ci.upper,"lavaan"); add(paste0(k,"#p"),r$pvalue,"lavaan") } }
R <- do.call(rbind,out); dec <- function(s) { s <- as.character(s); if (grepl("\\.",s)) nchar(sub(".*\\.","",s)) else 0 }
res <- list()
for (i in seq_len(nrow(R))) { k <- R$key[i]; base <- sub("#.*","",k); fld <- if (grepl("#",k)) sub(".*#","",k) else "value"; t <- T[[base]]; if (is.null(t)) { res[[i]] <- cbind(R[i,],published=NA,match=NA); next }
  pub <- switch(fld,value=t$value,se=t$se,ci_low=t$ci_low,ci_high=t$ci_high,p=t$p_exact); if (is.null(pub)) { res[[i]] <- cbind(R[i,],published=NA,match=NA); next }
  pv <- suppressWarnings(as.numeric(gsub("−","-",pub))); if (is.na(pv)) { res[[i]] <- cbind(R[i,],published=pub,match=NA); next }
  h <- .5*10^(-dec(pub)); res[[i]] <- cbind(R[i,],published=pub,match=abs(R$value[i]-pv)<=h+1e-9) }
res <- do.call(rbind,res); write.csv(res,"post_unseal/author_vs_published.csv",row.names=FALSE)
tb <- res[!is.na(res$match),]; cat("compared",nrow(tb),"match",sum(tb$match),"\n"); print(tb[!tb$match,c("key","value","published","source")],digits=5,row.names=FALSE); cat("target keys not covered by the script:",sum(!names(T) %in% sub("#.*","",res$key)),"of",length(T),"\n")
