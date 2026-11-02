#!/opt/homebrew/bin/Rscript
# Manifest P-7Q3. Sourceable for validation; CLI entry point is at the end.
suppressPackageStartupMessages(library(lme4))
SURVEY_VARS <- c('leave','childcare','parttime','gdp','unemp','epl','status','wmgr','fert')
X_TERMS <- c('leave','leave_sq','childcare','parttime')
INTERACTIONS <- paste0('female:', X_TERMS)
MODELS <- c(paste0('M',1:8),paste0('R',1:3))
INFLUENCE_MODELS <- paste0('M',3:8)
ROSTER <- list(AUS=2002:2006,AUT=c(2005,2007),BEL=2001:2008,
 CAN=c(2001,2002,2003,2006),CZE=2006,DNK=2001:2008,FIN=2001:2008,
 FRA=2002:2008,DEU=c(2001:2006,2008),GRC=2003:2008,ISL=2002:2008,
 IRL=2001:2008,ITA=c(2001:2003,2005:2008),JPN=2001:2008,NLD=2002:2008,
 NZL=c(2001,2003:2005),NOR=c(2002:2006,2008),POL=c(2001,2002,2004),
 PRT=c(2001,2004,2007),ESP=2002:2008,SWE=2001:2007,CHE=c(2002,2003,2005,2007),
 GBR=2001:2008,USA=2001:2008)
RUN_MODELS <- list(ORIGIN=MODELS)
for (id in c('U01','U02','U05','U12','U13','U14','U15','U16','U17','U18','U19','U20','U22')) RUN_MODELS[[id]] <- INFLUENCE_MODELS
for (id in c('U03','U04','U06')) RUN_MODELS[[id]] <- if (id=='U03') c('M3','R1') else 'M3'
for (id in c('U07','U08','U11','U24')) RUN_MODELS[[id]] <- paste0('M',4:8)
for (id in c('U09','U10')) RUN_MODELS[[id]] <- 'M4'
RUN_MODELS$U23 <- 'M6'; RUN_MODELS$U25 <- 'M5'; RUN_MODELS$U26 <- 'R2'
RUN_MODELS$N01 <- INFLUENCE_MODELS
RUN_ORDER <- c(names(RUN_MODELS),'influence')
OUTCOMES <- c(M1='activity',M2='activity',M3='activity',M4='planb',M5='size',M6='growth',M7='newprod',M8='newtech',R1='nascent',R2='activity',R3='activity')
key <- function(country,year) paste(country,year,sep=':')
binary <- function(x, yes, no) ifelse(x %in% yes,1,ifelse(x %in% no,0,NA_real_))
screen <- function(x,u06=FALSE) binary(x,c(1,100),if(u06)c(0,8) else 0)
sample_hash <- function(ids) digest::digest(paste(sort(as.character(ids),method='radix'),collapse=','),algo='sha256',serialize=FALSE)
select_rows <- function(d, keep) d[which(keep %in% TRUE),,drop=FALSE]
complete <- function(d, cols) if(!length(cols)) rep(TRUE,nrow(d)) else complete.cases(d[,cols,drop=FALSE])

read_inputs <- function(data_dir) {
 g <- read.csv(file.path(data_dir,'gem_extract.csv'),na.strings='',fileEncoding='UTF-8',colClasses=c(ID_9817_RDM='character',iso3='character'),check.names=FALSE)
 c <- read.csv(file.path(data_dir,'country_year_inputs.csv'),na.strings='',fileEncoding='UTF-8',colClasses=c(iso3='character'),check.names=FALSE)
 req_g <- c('ID_9817_RDM','GEM_YR','iso3','GEMSEX','GEMAGE','GEMEDUC','GEMWORK','BSTART','SUWAGE','SUBOANWT','OWNMGE','OMBABYBT','OMESTBBT','OMOWN','OMOWNERS','OMWAGEYR','OMREASON','OMWHY','OMNOWJOB','OMYR5JOB','OMNEWCST','OMNEWT_5','SUSKILL','FEARFAIL','KNOWENT','NBSTATUS')
 req_c <- c('iso3','year','leave_fte_weeks','childcare_interp','childcare_pct_gdp_annual','pt_common_employees_women','pt_national_women','pt_common_total_women','gdp_index_undp','unemployment_rate','epl_overall','women_managers_pct','fertility_rate')
 if(length(setdiff(req_g,names(g))) || length(setdiff(req_c,names(c)))) stop('Required input columns are missing')
 if(anyNA(g$ID_9817_RDM)||anyDuplicated(g$ID_9817_RDM)) stop('Respondent IDs must be nonmissing and unique')
 if(anyNA(g[c('iso3','GEM_YR')])||anyNA(c[c('iso3','year')])) stop('Country/year keys must be nonmissing')
 if(anyDuplicated(key(c$iso3,c$year))) stop('Duplicate country-year input keys')
 list(g=g,c=c)
}

recode_individuals <- function(g,run_id) {
 d <- g; u <- run_id
 d$female <- binary(d$GEMSEX,2,1)
 d$age <- ifelse(d$GEMAGE %in% c(99,999),NA,d$GEMAGE)
 d$postsecondary <- binary(d$GEMEDUC,c(1316,1720),c(0,111,1212))
 d$employed <- binary(d$GEMWORK,c(1,2),3:6); d$not_employed <- 1-d$employed
 bs <- screen(d$BSTART,u=='U06'); own <- screen(d$OWNMGE,u=='U06')
 nas <- binary(d$SUBOANWT,1,0)
 d$nascent <- nas
 d$activity <- ifelse(nas==1 | own==1,1,ifelse(nas==0 & own==0,0,NA))
 if(u=='U03') {
  # Literal "is not 1": an empty SUWAGE also satisfies the exclusion.
  active_start <- bs==1 & !(d$SUWAGE %in% 1)
  d$nascent <- ifelse(active_start,1,ifelse(bs==0,0,NA))
  d$activity <- ifelse(active_start | own==1,1,ifelse(bs==0 & own==0,0,NA))
 }
 if(u=='U04') {
  baby <- binary(d$OMBABYBT,1,0); est <- binary(d$OMESTBBT,1,0)
  d$activity <- ifelse(nas==1|baby==1|est==1,1,ifelse(nas==0&baby==0&est==0,0,NA))
 }
 d$skill <- screen(d$SUSKILL,u=='U06'); d$fear <- screen(d$FEARFAIL,u=='U06'); d$knows <- screen(d$KNOWENT,u=='U06')
 d$owner <- own
 if(u=='U07') d$owner <- binary(d$OMESTBBT,1,0)
 if(u=='U08') d$owner <- as.numeric(own==1 & d$OMOWN %in% c(1,2))
 d$planb <- binary(d$OMREASON,2,c(1,3,4,6))
 if(u=='U09') d$planb <- binary(d$OMREASON,c(2,3),c(1,4,6))
 if(u=='U10') d$planb <- binary(d$OMWHY,-1,c(0,1))
 now_size <- ifelse(d$OMNOWJOB>=0 & d$OMNOWJOB<=999998,d$OMNOWJOB,NA)
 d$size <- log1p(now_size)
 clean_count <- function(x) ifelse(x %in% c(999999,9999997,9999999),NA,x)
 now <- clean_count(d$OMNOWJOB); future <- clean_count(d$OMYR5JOB)
 d$growth <- as.numeric(if(u=='U23') future>5 else future-now>5)
 d$newprod <- binary(d$OMNEWCST,1,c(2,3)); d$newtech <- binary(d$OMNEWT_5,c(1,2),3)
 d$sole <- binary(d$OMOWN,1,2)
 if(u=='U24') d$sole <- ifelse(d$OMOWNERS==1,1,ifelse(d$OMOWNERS>=2 & d$OMOWNERS<=998,0,NA))
 by <- ifelse(d$OMWAGEYR>=1990 & d$OMWAGEYR<=d$GEM_YR,d$GEM_YR-d$OMWAGEYR,NA)
 d$bage <- if(u=='U11') log1p(by) else log(ifelse(by>0,by,NA))
 d$survey <- key(d$iso3,d$GEM_YR)
 roster_keys <- unlist(Map(function(co,yr)key(co,yr),names(ROSTER),ROSTER),use.names=FALSE)
 d$pass_roster <- if(u=='U05') d$iso3 %in% names(ROSTER) & d$GEM_YR %in% 2001:2008 else d$survey %in% roster_keys
 if(u=='N01') d$pass_roster <- d$pass_roster & !(d$GEM_YR %in% c(2001,2002))
 d$pass_age <- !is.na(d$age) & if(u=='U01') d$age>=18 else d$age>18
 d$pass_age <- d$pass_age & d$age<55
 d$pass_work <- d$GEMWORK %in% if(u=='U02')c(1,2,6) else c(1,2)
 d
}

survey_variables <- function(d,c,run_id) {
 s <- unique(d[c('iso3','GEM_YR','survey')]); rownames(s) <- NULL
 ik <- key(c$iso3,c$year); same <- match(s$survey,ik)
 lag <- if(run_id=='U17')0 else if(run_id=='U18')2 else 1
 s$leave <- c$leave_fte_weeks[match(key(s$iso3,s$GEM_YR-lag),ik)]
 s$childcare <- c[[if(run_id=='U19')'childcare_pct_gdp_annual' else 'childcare_interp']][same]
 pt <- switch(run_id,U12='pt_national_women',U13='pt_common_total_women','pt_common_employees_women')
 s$parttime <- c[[pt]][same]
 src <- c(gdp='gdp_index_undp',unemp='unemployment_rate',epl='epl_overall',wmgr='women_managers_pct',fert='fertility_rate')
 for(nm in names(src)) s[[nm]] <- c[[src[[nm]]]][same]
 nb <- screen(d$NBSTATUS)
 keep <- !is.na(nb)
 if(run_id=='U22') keep <- keep & d$pass_roster & d$pass_age & d$pass_work
 status <- tapply(nb[keep],d$survey[keep],mean)
 s$status <- as.numeric(status[match(s$survey,names(status))])
 original <- s$status
 if(run_id!='N01') for(i in which(is.na(original))) {
  later <- which(s$iso3==s$iso3[i] & s$GEM_YR>s$GEM_YR[i] & !is.na(original))
  if(length(later)) s$status[i] <- original[later[which.min(s$GEM_YR[later])]]
 }
 s
}

prepare_run <- function(inputs,run_id) {
 d <- recode_individuals(inputs$g,run_id)
 s <- survey_variables(d,inputs$c,run_id)
 for(v in SURVEY_VARS) d[[paste0('raw_',v)]] <- s[[v]][match(d$survey,s$survey)]
 anchor <- select_rows(d,d$pass_roster & d$pass_age & d$pass_work & complete(d,c('activity','female','age','postsecondary',paste0('raw_',SURVEY_VARS))))
 units <- anchor[,c('iso3','survey',paste0('raw_',SURVEY_VARS)),drop=FALSE]
 names(units)[-(1:2)] <- SURVEY_VARS
 if(run_id!='U16') units <- units[!duplicated(units$survey),,drop=FALSE]
 if(run_id=='U14') units$leave_sq <- units$leave^2
 if(run_id=='U15' && nrow(units)) units <- aggregate(units[SURVEY_VARS],by=list(iso3=units$iso3),FUN=mean)
 vars <- c(SURVEY_VARS,if(run_id=='U14')'leave_sq')
 stats <- setNames(lapply(vars,function(v)list(mean=mean(units[[v]]),sd=sd(units[[v]]))),vars)
 invalid <- vars[!vapply(stats,function(x)is.finite(x$mean)&&is.finite(x$sd)&&x$sd>0,TRUE)]
 for(v in SURVEY_VARS) d[[v]] <- if(v %in% invalid) NA_real_ else (d[[paste0('raw_',v)]]-stats[[v]]$mean)/stats[[v]]$sd
 d$leave_sq <- if(run_id=='U14') {
  if('leave_sq' %in% invalid) NA_real_ else (d$raw_leave^2-stats$leave_sq$mean)/stats$leave_sq$sd
 } else d$leave^2
 constants <- list(method=if(run_id=='U15')'country_means' else if(run_id=='U16')'individual_rows' else 'unique_surveys',
  n_obs=nrow(anchor),n_surveys=length(unique(anchor$survey)),n_countries=length(unique(anchor$iso3)),n_units=nrow(units),
  sample_hash=sample_hash(anchor$ID_9817_RDM),variables=stats,
  leave_sq=if(run_id=='U14')'standardized raw leave squared' else 'square of standardized leave; no additional standardization',invalid_variables=invalid,centering=list())
 list(data=d,constants=constants,invalid=invalid)
}

model_spec <- function(model,run_id) {
 s2 <- model %in% paste0('M',4:8)
 years <- if(model=='M7')2002:2008 else if(model=='M8')2005:2008 else 2001:2008
 ref <- if(model=='M7')2002 else if(model=='M8')2008 else 2001
 sv <- if(model=='M1')character() else SURVEY_VARS
 if(model=='R2' && run_id!='U26') sv <- setdiff(sv,'fert')
 terms <- c('female','age_c','age_c2','postsecondary',paste0('year',setdiff(years,ref)))
 if(model!='M1') terms <- c(terms,X_TERMS,setdiff(sv,c('leave','childcare','parttime')))
 if(!(model %in% c('M1','M2'))) terms <- c(terms,INTERACTIONS)
 if(s2) terms <- c(terms,'sole','bage_c')
 if(model=='R2') terms <- c(terms,'not_employed')
 if(model=='R3') terms <- c(terms,'skill','fear','knows')
 list(model=model,outcome=OUTCOMES[[model]],s2=s2,years=years,ref=ref,sv=sv,terms=terms,
  formula=reformulate(terms,OUTCOMES[[model]]),linear=model=='M5')
}

model_sample <- function(prep,model,run_id,centering=NULL) {
 d <- prep$data; sp <- model_spec(model,run_id)
 keep <- d$pass_roster & d$pass_age & d$GEM_YR %in% sp$years
 if(model!='R2') keep <- keep & d$pass_work
 cols <- c(sp$outcome,'female','age','postsecondary',if(length(sp$sv))paste0('raw_',sp$sv) else character())
 if(sp$s2) {keep <- keep & d$owner==1; cols <- c(cols,'sole','bage')}
 else cols <- c(cols,'activity')
 if(model=='R2') cols <- c(cols,'not_employed')
 if(model=='R3') cols <- c(cols,'skill','fear','knows')
 d <- select_rows(d,keep & complete(d,unique(cols)))
 if(is.null(centering)) centering <- list(age=mean(d$age),bage=if(sp$s2)mean(d$bage) else NULL)
 d$age_c <- d$age-centering$age; d$age_c2 <- d$age_c^2
 if(sp$s2) d$bage_c <- d$bage-centering$bage
 for(y in setdiff(sp$years,sp$ref)) d[[paste0('year',y)]] <- as.numeric(d$GEM_YR==y)
 d$country <- factor(d$iso3); d$survey <- factor(d$survey)
 list(data=d,spec=sp,centering=centering)
}

capture_conditions <- function(expr) {
 warnings <- character()
 value <- tryCatch(withCallingHandlers(expr,warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')},message=function(m){warnings<<-c(warnings,conditionMessage(m));invokeRestart('muffleMessage')}),error=function(e)e)
 list(value=value,notes=unique(warnings))
}

# Restricted wild cluster bootstrap-t, computed with fixed-design OLS algebra.
wild_cluster <- function(fit,clusters,terms=INTERACTIONS,B=999L,seed=20261028L) {
 X0 <- model.matrix(fit); keep <- !is.na(coef(fit)); X <- X0[,keep,drop=FALSE]
 y <- model.response(model.frame(fit)); groups <- factor(clusters); G <- nlevels(groups)
 if(G<2) stop('Wild bootstrap requires at least two countries')
 q <- qr(X); bread <- chol2inv(chol(crossprod(X)))
 b <- qr.coef(q,y); e <- qr.resid(q,y)
 # Coefficient-specific cluster scores give exactly the HC0, G/(G-1) variance.
 cluster_se <- function(resid,a) {
  scores <- rowsum(resid * as.numeric(X %*% a),groups,reorder=FALSE)
  sqrt(G/(G-1)*colSums(scores^2))
 }
 set.seed(seed)
 weights <- matrix(sample(c(-1,1),G*B,replace=TRUE),nrow=G)
 # rowsum order above is immaterial to the sums; weights index factor levels.
 ans <- setNames(rep(NA_real_,length(terms)),terms)
 for(term in intersect(terms,colnames(X))) {
  j <- match(term,colnames(X)); a <- bread[,j]
  se0 <- cluster_se(matrix(e,ncol=1),a)
  if(!is.finite(se0)||se0<=0) next
  restricted <- qr(X[,-j,drop=FALSE]); er <- qr.resid(restricted,y); yr <- y-er
  ystar <- yr + er * weights[as.integer(groups),,drop=FALSE]
  bstar <- qr.coef(q,ystar); estar <- qr.resid(q,ystar)
  sest <- cluster_se(estar,a)
  ts <- bstar[j,]/sest; valid <- is.finite(ts)
  if(!all(valid)) stop('Non-finite wild bootstrap statistic')
  ans[term] <- mean(abs(ts)>=abs(b[j]/se0))
 }
 ans
}

benchmark <- function(d,sp) {
 fit <- if(sp$linear) lm(sp$formula,data=d,na.action=na.fail) else glm(sp$formula,data=d,family=binomial(link='logit'),na.action=na.fail)
 if(!sp$linear && !isTRUE(fit$converged)) stop('Pooled logistic regression did not converge')
 if(length(unique(d$iso3))<2) stop('Cluster covariance requires at least two countries')
 v <- sandwich::vcovCL(fit,cluster=d$iso3,type='HC0',cadjust=TRUE)
 se <- sqrt(diag(v)); b <- coef(fit)[names(se)]
 w <- setNames(rep(NA_real_,length(INTERACTIONS)),INTERACTIONS)
 if(sp$linear) {
  wb <- tryCatch(wild_cluster(fit,d$iso3),error=function(e)e)
  if(inherits(wb,'error')) warning('Wild bootstrap unavailable: ',conditionMessage(wb)) else w <- wb
 }
 list(se=se,p=2*pnorm(-abs(b/se)),wild=w)
}

result_template <- function(run_id,model,d,sp,deleted_country='') {
 n <- length(sp$terms)+1L
 data.frame(run_id=run_id,model=model,deleted_country=deleted_country,status='ok',error='',
  n_obs=nrow(d),n_countries=length(unique(d$iso3)),n_surveys=length(unique(d$survey)),sample_hash=sample_hash(d$ID_9817_RDM),
  term=c('(Intercept)',sp$terms),estimate=rep(NA_real_,n),se=NA_real_,z=NA_real_,p=NA_real_,bench_se=NA_real_,bench_p=NA_real_,wild_p=NA_real_,
  loglik=NA_real_,aic=NA_real_,converged=NA,singular=NA,routine=if(sp$linear)if(run_id=='U25')'lme4::lmer (REML)' else 'lme4::lmer (ML)' else 'lme4::glmer (binomial logit; Laplace; nAGQ=1)',
  sd_country_intercept=NA_real_,sd_country_female=NA_real_,sd_survey_intercept=NA_real_,sd_survey_female=NA_real_,stringsAsFactors=FALSE)
}

fit_model <- function(ms,run_id,invalid=character(),deleted_country='') {
 d <- ms$data; sp <- ms$spec
 if(nzchar(deleted_country)) d <- droplevels(select_rows(d,d$iso3!=deleted_country))
 out <- result_template(run_id,sp$model,d,sp,deleted_country)
 bad <- intersect(invalid,c(sp$sv,if('leave_sq' %in% sp$terms)'leave_sq'))
 if(!nrow(d)||length(bad)) {
  out$status <- 'not_estimable'; out$error <- if(!nrow(d))'Empty model-specific complete-case sample' else paste('Undefined standardization:',paste(bad,collapse=', ')); return(out)
 }
 bc <- capture_conditions(benchmark(d,sp))
 notes <- bc$notes
 if(inherits(bc$value,'error')) notes <- c(notes,paste('Benchmark unavailable:',conditionMessage(bc$value)))
 else {
  out$bench_se <- unname(bc$value$se[out$term]); out$bench_p <- unname(bc$value$p[out$term]); out$wild_p <- unname(bc$value$wild[out$term])
 }
 random <- if(run_id=='U20')'(1 + female | country) + (1 + female | survey)' else '(1 + female || country) + (1 + female || survey)'
 f <- as.formula(paste(paste(deparse(sp$formula,width.cutoff=500L),collapse=' '),'+',random))
 fc <- capture_conditions(if(sp$linear) lmer(f,data=d,REML=run_id=='U25',na.action=na.fail) else glmer(f,data=d,family=binomial(link='logit'),nAGQ=1,na.action=na.fail))
 notes <- c(notes,fc$notes)
 if(inherits(fc$value,'error')) {
  out$status <- 'failed'; out$error <- paste(unique(c(notes,paste('Mixed fit failed:',conditionMessage(fc$value)))),collapse=' | '); return(out)
 }
 fit <- fc$value
 extracted <- capture_conditions({
  b <- fixef(fit,add.dropped=TRUE); v <- as.matrix(vcov(fit)); se <- sqrt(diag(v))
  out$estimate <- unname(b[out$term]); out$se <- unname(se[out$term]); out$z <- out$estimate/out$se; out$p <- 2*pnorm(-abs(out$z))
  out$loglik <- as.numeric(logLik(fit)); out$aic <- AIC(fit)
  opt <- fit@optinfo
  convmsg <- unlist(opt$conv$lme4$messages)
  # Boundary singularity is reported separately and does not itself imply nonconvergence.
  nonsingular <- convmsg[!grepl('boundary.*singular',convmsg,ignore.case=TRUE)]
  out$converged <- all(unlist(opt$conv$opt)==0) && !length(nonsingular)
  out$singular <- isSingular(fit)
  notes <- c(notes,convmsg)
  vc <- as.data.frame(VarCorr(fit))
  for(group in c('country','survey')) for(term in c('(Intercept)','female')) {
   k <- startsWith(vc$grp,group) & vc$var1==term & is.na(vc$var2)
   dest <- paste0('sd_',group,'_',if(term=='(Intercept)')'intercept' else 'female')
   out[[dest]] <- if(any(k))vc$sdcor[which(k)[1]] else NA_real_
  }
  missing <- is.na(out$estimate)|is.na(out$se)
  # A dropped column can also make retained coefficients individually
  # unidentified (e.g. every year effect and the intercept when the declared
  # reference year is absent). Do not publish arbitrary pivot constraints.
  if(anyNA(b)) {
   mm <- model.matrix(sp$formula,d)
   retained <- names(b)[!is.na(b)]; dropped <- names(b)[is.na(b)]
   relation <- qr.coef(qr(mm[,retained,drop=FALSE]),mm[,dropped,drop=FALSE])
   affected <- retained[rowSums(abs(relation)>1e-7)>0]
   missing <- missing | out$term %in% c(dropped,affected)
  }
  out$status[missing] <- 'not_estimable'
  out[missing,c('estimate','se','z','p','bench_se','bench_p','wild_p')] <- NA_real_
  out$error <- paste(unique(notes),collapse=' | ')
  out$error[missing] <- paste(out$error[missing],'Fixed term aliased or unavailable (including absent year levels)',sep=' | ')
  out
 })
 if(inherits(extracted$value,'error')) {out$status <- 'failed';out$error <- paste('Mixed-model extraction failed:',conditionMessage(extracted$value));return(out)}
 out <- extracted$value
 if(length(extracted$notes)) out$error <- paste(out$error,paste(extracted$notes,collapse=' | '),sep=' | ')
 out
}

write_outputs <- function(rows,constants,out_dir) {
 write.csv(do.call(rbind,rows),file.path(out_dir,'results.csv'),row.names=FALSE,na='',fileEncoding='UTF-8')
 jsonlite::write_json(constants,file.path(out_dir,'constants.json'),pretty=TRUE,auto_unbox=TRUE,na='null',null='null',digits=16)
}

run_analysis <- function(data_dir,out_dir,run_ids,influence_models=INFLUENCE_MODELS) {
 ids <- if(length(run_ids)==1L)trimws(strsplit(run_ids,',',fixed=TRUE)[[1]]) else run_ids
 if(identical(ids,'all')) ids <- setdiff(RUN_ORDER,'influence')
 if(length(setdiff(ids,RUN_ORDER))) stop('Unknown run IDs: ',paste(setdiff(ids,RUN_ORDER),collapse=', '))
 if(!length(ids)) stop('No run IDs requested')
 ids <- RUN_ORDER[RUN_ORDER %in% ids]
 if(length(setdiff(influence_models,INFLUENCE_MODELS))) stop('Unknown influence model')
 dir.create(out_dir,recursive=TRUE,showWarnings=FALSE)
 pkgs <- c('lme4','Matrix','sandwich','lmtest','data.table','jsonlite','digest')
 writeLines(c(capture.output(sessionInfo()),'',vapply(pkgs,function(p)paste(p,as.character(packageVersion(p))),''),
  '',capture.output(glmerControl()),capture.output(lmerControl()),capture.output(glm.control()),capture.output(RNGkind()),
  'Benchmark: sandwich::vcovCL(type="HC0", cadjust=TRUE); wild bootstrap B=999 seed=20261028.'),file.path(out_dir,'session_info.txt'))
 inputs <- read_inputs(data_dir)
 rows <- list(); constants <- list(); origin <- NULL
 for(id in ids) {
  effective <- if(id=='influence')'ORIGIN' else id
  prep <- if(effective=='ORIGIN' && !is.null(origin))origin else prepare_run(inputs,effective)
  if(effective=='ORIGIN') origin <- prep
  constants[[id]] <- prep$constants
  models <- if(id=='influence')INFLUENCE_MODELS[INFLUENCE_MODELS %in% influence_models] else RUN_MODELS[[id]]
  for(model in models) {
   ms <- model_sample(prep,model,effective)
   constants[[id]]$centering[[model]] <- ms$centering
   deletions <- if(id=='influence')sort(unique(ms$data$iso3)) else ''
   if(!length(deletions)) deletions <- ''
   for(co in deletions) {
    message(id,' ',model,if(nzchar(co))paste(' delete',co) else '',': n=',sum(ms$data$iso3!=co))
    result <- tryCatch(fit_model(ms,id,prep$invalid,co),error=function(e){
     dd <- if(nzchar(co))select_rows(ms$data,ms$data$iso3!=co) else ms$data
     r <- result_template(id,model,dd,ms$spec,co);r$status <- 'failed';r$error <- conditionMessage(e);r
    })
    rows[[length(rows)+1L]] <- result
    write_outputs(rows,constants,out_dir)
   }
  }
 }
 # The manifest provides no weighted run ID. Use a transparent sentinel row.
 unavailable <- rows[[1L]][1,,drop=FALSE]
 unavailable[1,] <- NA
 unavailable$run_id <- 'WEIGHTED_UNAVAILABLE'; unavailable$model <- ''; unavailable$deleted_country <- ''
 unavailable$status <- 'not_estimable'; unavailable$error <- 'Sampling weights unavailable: lme4 weights are not survey sampling weights; no weighted fit performed.'
 unavailable$term <- ''; unavailable$routine <- 'unavailable'
 rows[[length(rows)+1L]] <- unavailable
 write_outputs(rows,constants,out_dir)
 invisible(list(results=do.call(rbind,rows),constants=constants))
}

if(sys.nframe()==0L) {
 args <- commandArgs(trailingOnly=TRUE)
 if(length(args)!=3L) stop('Usage: /opt/homebrew/bin/Rscript run.R <data_dir> <out_dir> <run_ids>')
 run_analysis(args[1],args[2],args[3])
}
