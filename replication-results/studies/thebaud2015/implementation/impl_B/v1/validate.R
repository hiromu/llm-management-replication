source('run.R')
checks <- character()
check <- function(ok,label) { if(!isTRUE(ok))stop(label); checks <<- c(checks,label) }
inp <- read_inputs('synthetic'); g <- inp$g
p <- prepare_run(inp,'ORIGIN'); d <- p$data
# Independent implementation of the origin selection and complete-case rules.
roster <- unlist(lapply(names(ROSTER),function(co)paste(co,ROSTER[[co]],sep=':')))
base <- paste(g$iso3,g$GEM_YR,sep=':') %in% roster & !is.na(g$GEMAGE) & g$GEMAGE>18 & g$GEMAGE<55
work <- g$GEMWORK %in% c(1,2)
female_ok <- g$GEMSEX %in% c(1,2)
educ_ok <- g$GEMEDUC %in% c(0,111,1212,1316,1720)
own <- ifelse(g$OWNMGE %in% c(1,100),1,ifelse(g$OWNMGE %in% 0,0,NA))
act <- ifelse(g$SUBOANWT==1|own==1,1,ifelse(g$SUBOANWT==0&own==0,0,NA))
sv_ok <- complete.cases(d[paste0('raw_',SURVEY_VARS)])
bage_ok <- !is.na(g$OMWAGEYR) & g$OMWAGEYR>=1990 & g$OMWAGEYR<g$GEM_YR
s2 <- base & work & own==1 & female_ok & educ_ok & sv_ok & g$OMOWN %in% c(1,2) & bage_ok
count_ok <- function(x)!is.na(x)& !(x %in% c(999999,9999997,9999999))
expected <- list(
 M1=base&work&female_ok&educ_ok&!is.na(act),
 M2=base&work&female_ok&educ_ok&!is.na(act)&sv_ok,
 M3=base&work&female_ok&educ_ok&!is.na(act)&sv_ok,
 M4=s2 & g$OMREASON %in% c(1,2,3,4,6),
 M5=s2 & !is.na(g$OMNOWJOB)&g$OMNOWJOB>=0&g$OMNOWJOB<=999998,
 M6=s2 & count_ok(g$OMNOWJOB)&count_ok(g$OMYR5JOB),
 M7=s2 & g$GEM_YR %in% 2002:2008 & g$OMNEWCST %in% 1:3,
 M8=s2 & g$GEM_YR %in% 2005:2008 & g$OMNEWT_5 %in% 1:3,
 R1=base&work&female_ok&educ_ok&!is.na(act)&sv_ok&g$SUBOANWT %in% c(0,1),
 R2=base&female_ok&educ_ok&!is.na(act)&g$GEMWORK %in% 1:6 & complete.cases(d[paste0('raw_',setdiff(SURVEY_VARS,'fert'))]),
 R3=base&work&female_ok&educ_ok&!is.na(act)&sv_ok&g$SUSKILL %in% c(0,1,100)&g$FEARFAIL %in% c(0,1,100)&g$KNOWENT %in% c(0,1,100))
counts <- data.frame()
for(m in MODELS) {
 sm <- model_sample(p,m,'ORIGIN')
 ids <- g$ID_9817_RDM[which(expected[[m]] %in% TRUE)]
 check(identical(sort(ids),sort(sm$data$ID_9817_RDM)),paste(m,'independent sample membership'))
 check(abs(mean(sm$data$age_c))<1e-10,paste(m,'age centered within its own sample'))
 if(sm$spec$s2) check(abs(mean(sm$data$bage_c))<1e-10,paste(m,'business age centered within its own sample'))
 counts <- rbind(counts,data.frame(model=m,n_obs=nrow(sm$data),n_countries=length(unique(sm$data$iso3)),n_surveys=length(unique(sm$data$survey)),sample_hash=sample_hash(ids)))
}
check(sum(lengths(ROSTER))==143 && length(ROSTER)==24,'Exact 143-survey, 24-country roster')
anchor <- model_sample(p,'M3','ORIGIN')$data
us <- anchor[!duplicated(anchor$survey),]
for(v in SURVEY_VARS) {
 check(abs(mean(us[[v]]))<1e-10 && abs(sd(us[[v]])-1)<1e-10,paste(v,'survey-level n-1 standardization'))
}
check(identical(d$leave_sq,d$leave^2),'Origin leave squared after standardization')
# Every branch can build its designated samples and constants without fitting.
for(id in setdiff(RUN_ORDER,'influence')) {
 pp <- prepare_run(inp,id)
 for(m in RUN_MODELS[[id]]) {
  sm <- model_sample(pp,m,id)
  check(all(is.finite(sm$data$age_c)),paste(id,m,'sample construction'))
 }
}
p1 <- prepare_run(inp,'U01'); p2 <- prepare_run(inp,'U02'); p5 <- prepare_run(inp,'U05')
s1 <- model_sample(p1,'M3','U01')$data; s2b <- model_sample(p2,'M3','U02')$data; s5 <- model_sample(p5,'M3','U05')$data
check(all(anchor$ID_9817_RDM %in% s1$ID_9817_RDM) && all(s1$age>=18), 'U01 includes origin and permits age 18')
check(all(anchor$ID_9817_RDM %in% s2b$ID_9817_RDM) && all(s2b$GEMWORK %in% c(1,2,6)), 'U02 includes origin and work category 6')
check(all(anchor$ID_9817_RDM %in% s5$ID_9817_RDM),'U05 expands roster')
p15 <- prepare_run(inp,'U15'); p16 <- prepare_run(inp,'U16'); p14 <- prepare_run(inp,'U14')
for(v in SURVEY_VARS) {
 cm <- tapply(us[[paste0('raw_',v)]],us$iso3,mean)
 check(isTRUE(all.equal(p15$constants$variables[[v]]$sd,sd(cm))),paste('U15',v,'country means SD'))
 check(isTRUE(all.equal(p16$constants$variables[[v]]$sd,sd(anchor[[paste0('raw_',v)]]))),paste('U16',v,'individual SD'))
}
check(isTRUE(all.equal(p14$constants$variables$leave_sq$sd,sd(us$raw_leave^2))),'U14 raw leave-square SD')
for(id in c('U17','U18')) {
 pp <- prepare_run(inp,id); lag <- if(id=='U17')0 else 2
 target <- inp$c$leave_fte_weeks[match(key(pp$data$iso3,pp$data$GEM_YR-lag),key(inp$c$iso3,inp$c$year))]
 check(identical(pp$data$raw_leave,target),paste(id,'leave lag keyed by calendar year'))
}
# Controlled code cases (derived in memory; no respondent records printed).
z <- g[rep(1L,8L),]; z$GEM_YR <- 2005;z$GEMAGE <- c(18,19,54,55,99,999,30,30)
z$GEMSEX <- c(1,2,9,NA,1,2,1,2);z$NBSTATUS <- c(100,1,0,8,9,NA,0,1)
z$BSTART <- c(1,1,1,0,8,9,100,1);z$SUWAGE <- c(1,2,NA,1,2,2,8,9)
z$OWNMGE <- 0;z$SUBOANWT <- 0
rz <- recode_individuals(z,'U03')
check(identical(rz$nascent,c(NA_real_,1,1,0,NA_real_,NA_real_,1,1)),'U03 SUWAGE exclusion, including missing and refusal codes')
check(identical(screen(z$NBSTATUS),c(1,1,0,NA_real_,NA_real_,NA_real_,0,1)),'Screening codes including 100 and missing')
check(identical(screen(c(8,9,NA,100),'U06'=='U06'),c(0,NA_real_,NA_real_,1)),'U06 recodes 8 only')
z$OMNOWJOB <- c(0,999998,999999,9999997,9999999,NA,4,4)
z$OMYR5JOB <- c(5,999999,6,6,6,6,9,10)
z$OMWAGEYR <- c(2005,2004,1990,1989,2006,9997,9998,9999)
rz <- recode_individuals(z,'ORIGIN'); uz <- recode_individuals(z,'U11')
check(identical(is.na(rz$size),c(FALSE,FALSE,TRUE,TRUE,TRUE,TRUE,FALSE,FALSE)),'Size count bounds and sentinel codes')
check(identical(rz$growth,c(0,NA_real_,NA_real_,NA_real_,NA_real_,NA_real_,0,1)),'Growth difference strictly greater than five')
check(is.na(rz$bage[1]) && uz$bage[1]==0 && rz$bage[3]==log(15),'Business age zero, censored 1990 and log1p branch')
# Status is computed before age/work filtering and falls back to earliest later responses.
z <- g[rep(1L,5L),];z$iso3 <- 'BEL';z$GEM_YR <- c(2001,2002,2002,2003,2004)
z$GEMAGE <- c(30,80,30,30,30);z$GEMWORK <- c(1,3,1,1,1);z$NBSTATUS <- c(9,100,0,0,1)
rz <- recode_individuals(z,'ORIGIN'); ss <- survey_variables(rz,inp$c,'ORIGIN')
check(ss$status[ss$GEM_YR==2001]==0.5,'Status earliest later year, including ineligible respondents')
ss22 <- survey_variables(recode_individuals(z,'U22'),inp$c,'U22')
check(ss22$status[ss22$GEM_YR==2001]==0,'U22 status uses eligible respondents')
ssn <- survey_variables(recode_individuals(z,'N01'),inp$c,'N01')
check(is.na(ssn$status[ssn$GEM_YR==2001]),'N01 disables status carryback')
# Direct bootstrap refits independently verify the fixed-design matrix algorithm.
ms5 <- model_sample(p,'M5','ORIGIN'); fit <- lm(ms5$spec$formula,data=ms5$data,na.action=na.fail)
fast <- wild_cluster(fit,ms5$data$iso3,B=19L)
X <- model.matrix(fit); y <- model.response(model.frame(fit)); cl <- factor(ms5$data$iso3); G <- nlevels(cl)
set.seed(20261028L); W <- matrix(sample(c(-1,1),G*19L,replace=TRUE),nrow=G)
v <- sandwich::vcovCL(fit,cluster=cl,type='HC0',cadjust=TRUE)
for(term in INTERACTIONS) {
 j <- match(term,colnames(X)); restricted <- lm.fit(X[,-j,drop=FALSE],y)
 t0 <- coef(fit)[term]/sqrt(v[term,term]); tb <- numeric(19)
 for(b in 1:19) {
  ys <- restricted$fitted.values+restricted$residuals*W[as.integer(cl),b]
  f <- lm(ys~X-1)
  vv <- sandwich::vcovCL(f,cluster=cl,type='HC0',cadjust=TRUE)
  tb[b] <- coef(f)[j]/sqrt(vv[j,j])
 }
 check(identical(unname(fast[term]),mean(abs(tb)>=abs(t0))),paste(term,'bootstrap matches direct restricted-residual refits'))
}
# Failure must be recorded without aborting the subsequent model.
bad <- model_sample(p,'M3','ORIGIN');bad$data$activity <- 0
failed <- fit_model(bad,'ORIGIN',p$invalid)
check(all(failed$status=='failed') && all(grepl('constant',failed$error)),'Constant-response mixed fit records failure')
# Rank deficiency with absent reference retains declared parameterization.
n01 <- prepare_run(inp,'N01'); nms <- model_sample(n01,'M3','N01')
check(!any(nms$data$GEM_YR %in% c(2001,2002)) && all(nms$data$year2002==0),'N01 excludes 2001/2002 without silently rebasing year')
write.csv(counts,'validated_sample_counts.csv',row.names=FALSE)
writeLines(c(sprintf('%d checks passed.',length(checks)),checks),'validation_results.txt')
cat(length(checks),'checks passed; aggregate sample counts saved.\n')
