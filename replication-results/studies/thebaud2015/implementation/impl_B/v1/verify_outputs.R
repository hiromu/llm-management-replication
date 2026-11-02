source('run.R')
p <- prepare_run(read_inputs('synthetic'),'ORIGIN')
r <- read.csv('test_origin/results.csv',check.names=FALSE)
expected_columns <- c('run_id','model','deleted_country','status','error','n_obs','n_countries','n_surveys','sample_hash','term','estimate','se','z','p','bench_se','bench_p','wild_p','loglik','aic','converged','singular','routine','sd_country_intercept','sd_country_female','sd_survey_intercept','sd_survey_female')
stopifnot(identical(names(r),expected_columns))
counts <- read.csv('validated_sample_counts.csv')
for(m in MODELS) {
 rr <- r[r$model==m,]; cc <- counts[counts$model==m,]
 stopifnot(all(rr$n_obs==cc$n_obs),all(rr$n_countries==cc$n_countries),all(rr$n_surveys==cc$n_surveys),all(rr$sample_hash==cc$sample_hash))
 stopifnot(identical(rr$term,c('(Intercept)',model_spec(m,'ORIGIN')$terms)))
}
truth <- jsonlite::read_json('synthetic/synthetic_truth.json')
cc <- r[r$model=='M3' & r$term=='female:childcare',]
stopifnot(abs(cc$estimate-truth[['female:childcare']]) < cc$se)
check_native <- r[r$status=='ok' & !is.na(r$se),]
stopifnot(max(abs(check_native$z-check_native$estimate/check_native$se))<1e-10,max(abs(check_native$p-2*pnorm(-abs(check_native$z))))<1e-10)
stopifnot(sum(!is.na(r$wild_p))==4,all(r$wild_p[!is.na(r$wild_p)] %in% (0:999/999) | abs(r$wild_p[!is.na(r$wild_p)]*999-round(r$wild_p[!is.na(r$wild_p)]*999))<1e-9))
dev <- read.csv('test_deviations/results.csv')
for(id in c('U03','U09','U25')) {
 pp <- prepare_run(read_inputs('synthetic'),id)
 for(m in RUN_MODELS[[id]]) {
  sm <- model_sample(pp,m,id); rr <- dev[dev$run_id==id & dev$model==m,]
  stopifnot(all(rr$n_obs==nrow(sm$data)),all(rr$sample_hash==sample_hash(sm$data$ID_9817_RDM)))
 }
}
stopifnot(all(grepl('REML',dev$routine[dev$run_id=='U25'])))
i <- read.csv('test_influence/results.csv'); ii <- i[i$run_id=='influence',]
ms <- model_sample(p,'M3','ORIGIN')
stopifnot(identical(sort(unique(ii$deleted_country)),sort(unique(ms$data$iso3))))
for(co in unique(ii$deleted_country)) {
 dd <- ms$data[ms$data$iso3!=co,]; rr <- ii[ii$deleted_country==co,]
 stopifnot(all(rr$n_obs==nrow(dd)),all(rr$n_countries==23),all(rr$n_surveys==length(unique(dd$survey))),all(rr$sample_hash==sample_hash(dd$ID_9817_RDM)))
 # A direct pooled refit on the frozen origin covariates checks the actual saved inference.
 bb <- benchmark(dd,ms$spec)
 stopifnot(max(abs(rr$bench_se-unname(bb$se[rr$term])),na.rm=TRUE)<1e-10)
}
ci <- jsonlite::read_json('test_influence/constants.json')$influence
co <- jsonlite::read_json('test_origin/constants.json')$ORIGIN
stopifnot(identical(ci$variables,co$variables),identical(ci$centering$M3,co$centering$M3))
# Correlated random effects branch: exercise the actual formula and SD extraction.
pu20 <- prepare_run(read_inputs('synthetic'),'U20'); mu20 <- model_sample(pu20,'M5','U20')
u20 <- fit_model(mu20,'U20',pu20$invalid)
stopifnot(all(u20$status=='ok'),all(is.finite(u20$sd_country_intercept)),all(is.finite(u20$sd_country_female)),all(is.finite(u20$sd_survey_intercept)),all(is.finite(u20$sd_survey_female)))
write.csv(u20,'test_u20_m5_results.csv',row.names=FALSE,na='')
# Fractional ages follow the strict mathematical bound, even though supplied ages are integer.
g <- read_inputs('synthetic')$g[1:2,];g$GEMAGE <- c(18,18.5)
stopifnot(identical(recode_individuals(g,'ORIGIN')$pass_age,c(FALSE,TRUE)))
# No valid status responses, no eligible anchor, and constant scaling remain representable.
g <- read_inputs('synthetic');g$g$NBSTATUS <- 9
empty <- prepare_run(g,'ORIGIN'); em <- model_sample(empty,'M3','ORIGIN'); er <- fit_model(em,'ORIGIN',empty$invalid)
stopifnot(all(er$status=='not_estimable'),all(er$n_obs==0))
g <- read_inputs('synthetic');g$c$childcare_interp <- 1
constant <- prepare_run(g,'ORIGIN'); cm <- model_sample(constant,'M3','ORIGIN'); cr <- fit_model(cm,'ORIGIN',constant$invalid)
stopifnot(all(cr$status=='not_estimable'),all(cr$n_obs==nrow(ms$data)))
summary <- c('Output verification passed.',sprintf('M3 childcare interaction: estimate %.9f; SE %.9f; truth %.2f; discrepancy %.3f SE.',cc$estimate,cc$se,truth[['female:childcare']],abs(cc$estimate-truth[['female:childcare']])/cc$se),
 sprintf('Origin: %d model fits; %d nonconverged; %d singular.',length(unique(r$model[r$run_id=='ORIGIN'])),length(unique(r$model[r$converged %in% FALSE])),length(unique(r$model[r$singular %in% TRUE]))),
 sprintf('Influence: %d country deletions; %d failed; %d nonconverged; %d singular.',length(unique(ii$deleted_country)),length(unique(ii$deleted_country[ii$status=='failed'])),length(unique(ii$deleted_country[ii$converged %in% FALSE])),length(unique(ii$deleted_country[ii$singular %in% TRUE]))),
 sprintf('Influence female:childcare estimate range: %.9f to %.9f.',min(ii$estimate[ii$term=='female:childcare'],na.rm=TRUE),max(ii$estimate[ii$term=='female:childcare'],na.rm=TRUE)))
writeLines(summary,'output_verification.txt');cat(paste(summary,collapse='\n'),'\n')
