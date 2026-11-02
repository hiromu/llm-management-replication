# Verification of the requested outputs, without fitting additional analyses.
source("code/analysis.R")
checks<-list()
check<-function(name,value,detail=NULL) {
  checks[[name]]<<-list(passed=isTRUE(value),detail=detail)
  if(!isTRUE(value))warning("FAILED: ",name)
}
outputs<-setNames(lapply(SPECS,function(id)fromJSON(file.path("results",paste0(id,".json")),simplifyVector=FALSE)),SPECS)
check("All 12 specification files exist",length(outputs)==12L)
models<-list()
for(id in SPECS) {
  x<-outputs[[id]]
  check(paste(id,"metadata"),identical(x$spec_id,id)&&length(x$software$sessionInfo)>0&&length(x$rows_read_per_file)==6)
  mods<-c(unlist(x$single_group,recursive=FALSE),x$multigroup)
  for(name in names(mods)) {
    m<-mods[[name]];key<-paste(id,name)
    check(paste(key,"converged"),isTRUE(m$converged)&&m$status=="ok")
    check(paste(key,"analysis samples"),all(vapply(m$samples,function(s)s$n>1 && grepl("^[0-9a-f]{64}$",s$V4_sha256),logical(1))))
    check(paste(key,"finite fit indices"),all(is.finite(unlist(m$fit[c("chi_square","df","p","RMSEA","CFI","TLI","SRMR")]))))
    check(paste(key,"manual chi-square agrees with lavaan"),abs(m$fit$chi_square-m$fit$lavaan_standard_chi_square)<1e-6,
      m$fit$chi_square-m$fit$lavaan_standard_chi_square)
    models[[key]]<-m
  }
  if(!is.null(x$latent)) {
    check(paste(id,"all 15 contrasts"),length(x$latent$contrasts)==5L && all(lengths(x$latent$contrasts)==3L))
    for(f in names(K)[1:5])for(pair in names(PAIRS)) {
      p<-x$latent$contrasts[[f]][[pair]]; yy<-YEARS[PAIRS[[pair]]]
      a<-x$latent$means[[f]][[yy[1]]];b<-x$latent$means[[f]][[yy[2]]]
      check(paste(id,f,pair,"direction and covariance"),
        abs(p$Delta-(b$alpha-a$alpha))<1e-12 && abs(p$SE^2-(a$SE^2+b$SE^2-2*p$covariance_of_means))<1e-12)
    }
  }
}
for(id in c("S00","S01","S03")) {
  x<-outputs[[id]]
  check(paste(id,"item and alpha coverage"),length(x$item_statistics$by_item_year)==29 && length(x$alpha)==8 && length(x$single_group)==3)
}
for(id in c("CHK1","CHK2")) {
  d<-max(abs(unlist(lapply(names(K)[1:5],function(f)vapply(names(PAIRS),function(p)
    outputs[[id]]$latent$contrasts[[f]][[p]]$d_eq-outputs$S00$latent$contrasts[[f]][[p]]$d_eq,numeric(1))))))
  check(paste(id,"d_eq identification invariance on survey data"),d<1e-4,d)
}
check("CHK1 reference-group means and variances are fixed as specified",
  all(vapply(outputs$CHK1$latent$means,function(x)
    x[["1976"]]$alpha==0 && x[["1976"]]$SE==0 && x[["1976"]]$psi==1,logical(1))))
check("CHK1 df equals M4 df 470 without identification warnings",
  outputs$CHK1$multigroup$M4$fit$df==470 &&
    !any(grepl("not.*identified|positive definite",unlist(outputs$CHK1$multigroup$M4$warnings))))
check("S04 is ok with all 15 finite d_obs and positive observed-score variances",
  outputs$S04$status=="ok" && all(vapply(outputs$S04$multigroup,function(m)m$status=="ok",logical(1))) &&
    all(vapply(unlist(outputs$S04$latent$contrasts,recursive=FALSE),function(p)
      length(p$d_obs)==1L && is.finite(p$d_obs) && all(unlist(p$observed_score_variances)>0) &&
        abs(p$d_obs-p$Delta/sqrt(mean(unlist(p$observed_score_variances))))<1e-12,logical(1))))
check("All specifications record hashes without terminal newline",
  all(vapply(outputs,function(x)grepl("no terminal newline",x$conventions$sample_hash),logical(1))))
check("Sample hash matches literal newline-separated bytes",
  identical(sha_ids(c(3,1,2)),"ad53e8806d17c82d38902738d1d47d96bddaade27513466322efa0f793149dd0"))
check("S06 uses the observed-score sandwich",all(vapply(outputs$S06$multigroup,function(m)
  m$resolved_lavaan_options$se=="robust.huber.white" && is.finite(m$fit$scaled_chi_square$chi_square),logical(1))))
inf<-read.csv("results/influence_1_2.csv",check.names=FALSE)
expected<-c("idx","del_group","del_V4","status","message",
  unlist(lapply(c("d_eq","p"),function(q)unlist(lapply(names(K)[1:5],function(f)paste(q,f,names(PAIRS),sep="_"))))))
check("Influence CSV exact schema and successful two deletions",identical(names(inf),expected)&&nrow(inf)==2L&&all(inf$status=="ok"))
check("Influence has 30 finite outputs per deletion",all(is.finite(as.matrix(inf[,6:35]))))
im<-fromJSON("results/influence_1_2.metadata.json",simplifyVector=FALSE)
check("Influence includes per-deletion sample hashes",length(im$deletion_samples)==2L && all(vapply(im$deletion_samples,function(s)
  s[[1]]$n==outputs$S00$multigroup$M4$samples[[1]]$n-1L && all(vapply(s,function(g)grepl("^[0-9a-f]{64}$",g$V4_sha256),logical(1))),logical(1))))
# JSON must preserve doubles, not jsonlite's 15-digit default at digits=NA.
f<-tempfile(tmpdir="results");write_json_full(list(value=pi),f)
check("JSON serialization round-trips full double precision",identical(fromJSON(f)$value,pi));unlink(f)
ok<-all(vapply(checks,`[[`,logical(1),"passed"))
lines<-c("# Output validation","",paste("Result:",if(ok)"PASS" else "FAIL"),"",
  paste(length(checks),"checks across",length(models),"fitted models, all specifications, and two influence deletions."),"",
  "No additional statistical analyses were fitted by this validation.","",
  "Checks cover output metadata, convergence, sample hashes, finite fit indices, independently computed versus lavaan chi-square, contrast direction and covariance, requested output coverage, identification-invariant effects, robust standard errors, influence schema, and full-precision JSON serialization.","",
  "## Detailed checks","",vapply(names(checks),function(n)paste0("- ",if(checks[[n]]$passed)"PASS" else "FAIL",": ",n,
    if(is.null(checks[[n]]$detail))"" else paste0(" (",format(checks[[n]]$detail,digits=17),")")),character(1)),"",
  "## Session information","","```",capture.output(sessionInfo()),"```")
writeLines(lines,"code/VALIDATION.md")
cat(if(ok)"PASS" else "FAIL",":",length(checks),"checks;",length(models),"models\n")
if(!ok)stop("Output validation failed")
