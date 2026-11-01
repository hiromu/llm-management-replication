run_synthetic <- function() {
  suppressPackageStartupMessages(library(survival))
  set.seed(27102026)
  report<-c('# Synthetic checks','','Seed: 27102026. All fits in this stage use generated data.','')
  failures<-character()
  check<-function(name,value,tol) {
    ok<-is.finite(value)&&value<=tol
    report<<-c(report,sprintf('- %s: **%s**; error/statistic %.8g, limit %.8g.',name,if(ok)'PASS' else 'FAIL',value,tol))
    if(!ok)failures<<-c(failures,name)
  }
  # Tiny exact likelihood includes strata with m>n/2, and invariant groups.
  X<-matrix(c(-1.2,.3,.8,1.4,-.5,.7,-1,.1,.5,1.1, .2,-.6),ncol=2)
  y<-c(1,0,1,0,1,1);lens<-c(3L,3L);b<-c(.37,-.21)
  enumerate<-function(b) {
    eta<-drop(X%*%b);ll<-0
    for(ii in list(1:3,4:6)) {
      subsets<-combn(ii,sum(y[ii]));z<-apply(subsets,2,function(j)sum(eta[j]));a<-max(z)
      ll<-ll+sum(y[ii]*eta[ii])-a-log(sum(exp(z-a)))
    };ll
  }
  ev<-conditional_eval(b,X,y,lens)
  check('Exact conditional LL versus direct enumeration',abs(ev$value+enumerate(b)),1e-11)
  check('Exact analytic score versus numerical derivative',max(abs(ev$gradient+drop(num_jac(enumerate,b)))),1e-7)
  zz<-.Call('conditional_kernel',as.double(c(X%*%b,3,-2)),as.double(c(y,0,0)),as.integer(c(lens,2L)))
  check('Invariant group contributes zero likelihood',abs(zz[[1]]+ev$value),1e-11)
  # Independent trusted exact implementation at a fixed coefficient and MLE.
  dd<-data.frame(y=y,x1=X[,1],x2=X[,2],g=rep(1:2,each=3))
  sf<-survival::clogit(y~x1+x2+strata(g),dd,method='exact',init=b,control=survival::coxph.control(iter.max=0))
  check('Exact conditional LL versus survival::clogit(method=exact)',abs(tail(sf$loglik,1)+ev$value),1e-10)
  G<-100L;nper<-96L;N<-G*nper;team<-rep(sprintf('T%03d',1:G),each=nper)
  season<-rep(rep(2000:2005,each=16),G);X<-cbind(x1=rnorm(N),x2=rnorm(N))
  alpha<-rnorm(G,0,.65);beta<-c(.55,-.4)
  y<-rbinom(N,1,plogis(-.8+alpha[match(team,unique(team))]+drop(X%*%beta)))
  fits<-list('U7=0'=fit_conditional(X,y,team),
             'U7=1'=fit_unconditional(X,y,team,rep(seq_len(N/8),each=8)),
             'U7=2'=fit_conditional(X,y,paste(team,season)),
             'N1'=fit_random(X,y,team))
  for(nm in names(fits)) {
    f<-fits[[nm]];ii<-match(c('x1','x2'),names(f$b));z<-abs((f$b[ii]-beta)/sqrt(diag(f$V))[ii])
    check(paste(nm,'known slope recovery (maximum absolute z)'),max(z),4)
    check(paste(nm,'convergence'),as.numeric(!f$converged),0)
    report<-c(report,sprintf('  Estimates: x1 = %.6f (truth %.2f); x2 = %.6f (truth %.2f).',f$b[ii[1]],beta[1],f$b[ii[2]],beta[2]))
  }
  re<-fits$N1
  check('N1 population intercept recovery (absolute z)',abs((re$b['(Intercept)']+.8)/sqrt(re$V['(Intercept)','(Intercept)'])),4)
  check('N1 random-effect SD recovery (log-scale absolute z)',abs((re$b['log_sigma']-log(.65))/sqrt(re$V['log_sigma','log_sigma'])),4)
  report<-c(report,sprintf('  N1 sigma estimate = %.6f; truth = 0.65; 16 adaptive GH nodes.',exp(re$b['log_sigma'])))
  rule32<-gh_rule(32);par<-re$b
  check('N1 16 versus 32 adaptive GH nodes at MLE',abs(re_objective(par,cbind(1,X),y,split(seq_along(y),team),rule32)+re$loglik),1e-5)
  # Compare MLE and observed covariance with survival on modest strata.
  dd<-data.frame(y=y[1:576],x1=X[1:576,1],x2=X[1:576,2],g=team[1:576])
  cf<-fit_conditional(as.matrix(dd[,c('x1','x2')]),dd$y,dd$g)
  sf<-survival::clogit(y~x1+x2+strata(g),dd,method='exact',control=survival::coxph.control(eps=1e-10))
  check('Exact MLE versus survival::clogit',max(abs(cf$b-coef(sf))),1e-5)
  check('Exact observed covariance versus survival::clogit',max(abs(cf$V-vcov(sf))),1e-6)
  # Sandwich checked against numerical individual scores and numerical Hessian.
  Z<-cbind(1,X[1:180,,drop=FALSE]);yy<-y[1:180];bb<-c(-.6,.4,-.3);cl<-rep(1:30,each=6)
  prob<-plogis(drop(Z%*%bb));H<-crossprod(Z,Z*as.numeric(prob*(1-prob)));V<-solve(H)
  rob<-sandwich(Z,yy,bb,V,cl)
  individual_ll<-function(b)yy*drop(Z%*%b)-softplus(drop(Z%*%b))
  Snum<-num_jac(individual_ll,bb);Hnum<--num_jac(function(b)drop(crossprod(Z,yy-plogis(drop(Z%*%b)))),bb)
  Vnum<-solve(Hnum);Sc<-rowsum(Snum,cl);Bnum<-Vnum%*%crossprod(Sc)%*%Vnum*30/29*179/177
  check('Logit information versus numerical Hessian',max(abs(H-Hnum)),1e-7)
  check('CR1 sandwich versus numerical scores and Hessian',max(abs(rob$V-Bnum)),1e-8)
  # Full performance design, multiple team effects, all five ME variants.
  nm<-c('(Intercept)','teamB',base_terms,perf_terms,interaction_terms,paste0('season',2001:2005))
  B<-setNames(rep(0,length(nm)),nm)
  B[c('(Intercept)','teamB','perf_below','perf_below_sq','perf_above','below_indicator','minutes')]<-c(-.8,.5,.07,.001,-.04,.2,-.01)
  B[interaction_terms]<-c(.001,.00002,-.0004)
  XM<-matrix(runif(40*length(nm)),40,dimnames=list(NULL,nm));XM[,'(Intercept)']<-1;XM[,'teamB']<-rep(0:1,each=20)
  ff<-list(b=B,V=diag(length(B))*.01,X=XM,active=seq_along(B),model='M3')
  worst<-0;effecterr<-0
  for(v in c('ME0','U9a','U9b','U10a','N3'))for(d in if(v=='U10a')0 else c(-14,0,14))for(m in c(8,53)) {
    a<-margin_value(ff,d,m,v);ng<-drop(num_jac(function(b)margin_value(ff,d,m,v,b)$effect,B,h=1e-7))
    worst<-max(worst,max(abs(ng-a$gradient)))
    # Derivative with respect to d, one-sided at the discontinuity.
    if(v %in% c('ME0','U9a','N3')) {
      h<-1e-5
      if(d==0)num<-(margin_value(ff,d,m,v)$prob-margin_value(ff,d-h,m,v)$prob)/h else num<-(margin_value(ff,d+h,m,v)$prob-margin_value(ff,d-h,m,v)$prob)/(2*h)
      effecterr<-max(effecterr,abs(num-a$effect))
    }
  }
  check('All marginal-effect gradients versus numerical coefficient derivatives',worst,2e-4)
  check('Marginal effects versus numerical d derivatives (left branch at zero)',effecterr,1e-7)
  # Real-size exact-kernel workload, still entirely synthetic.
  tt<-system.time(for(k in 1:5)conditional_eval(c(.4,-.3),X,y,rep(nper,G)))[['elapsed']]
  report<-c(report,sprintf('- Exact likelihood/score timing: %.3f seconds for five evaluations on %d generated rows.',tt,N))
  # Exercise sample classification/CC without touching real data.
  toy<-data.frame(game_id=rep('G',6),play_id=1:6,season=2000,season_type='REG',down=4,
    play_type=c('run','no_play','no_play','no_play','qb_kneel','punt'),punt_attempt=c(0,1,0,0,0,1),field_goal_attempt=0,
    pass=c(0,1,1,0,0,0),rush=0,qtr=1,game_seconds_remaining=c(121,121,121,121,121,120),posteam='A',defteam='B',
    posteam_score=0,defteam_score=0,ydstogo=1,yardline_100=50,posteam_type='home',week=1)
  inp<-list(pbp=toy,games=data.frame(game_id='G',div_game=1,location='Neutral'),
    align=data.frame(season=2000,team_abbr_pbp=c('A','B'),division='X',conference='AFC'))
  u<-origin;u[1:3]<-1;zz<-make_variables(construct_base(inp,u)$data,u)
  check('S3 flag priority and unclassified no-play exclusion',as.numeric(!identical(zz$y,c(1,0,1,0,0))),0)
  check('S5 strict boundary',nrow(construct_base(inp,origin)$data)-1,0)
  u[4:6]<-1;zz<-make_variables(construct_base(inp,u)$data,u)
  check('Floor minutes, exclusive conference, neutral-site override',max(abs(c(zz$minutes-2,zz$same_conference,zz$home_field))),0)
  report<-c(report,'','## Synthetic pipeline smoke test','')
  message('Running all full-pipeline branches on generated data only')
  smoke_error<-tryCatch({synthetic_smoke();NULL},error=function(e)conditionMessage(e))
  check('Synthetic end-to-end orchestration and output schemas',as.numeric(!is.null(smoke_error)),0)
  if(!is.null(smoke_error))report<-c(report,paste('  Error:',smoke_error))
  report<-c(report,'',if(length(failures))paste('FAILED checks:',paste(failures,collapse='; ')) else 'All synthetic checks passed.')
  writeLines(report,'results/synthetic_checks.md')
  if(length(failures))stop('Synthetic checks failed; see results/synthetic_checks.md')
  invisible(TRUE)
}
synthetic_smoke <- function() {
  set.seed(27102027);N<-8*6*24
  x<-data.frame(game_id=sprintf('SYN_%05d',rep(1:(N/4),each=4)),play_id=rep(1:4,N/4),
    team=rep(sprintf('T%d',1:8),each=6*24),season=rep(rep(2000:2005,each=24),8),qtr=sample(1:4,N,TRUE),
    posteam_score=sample(0:35,N,TRUE),defteam_score=sample(0:35,N,TRUE),ydstogo=sample(1:15,N,TRUE),
    yardline_100=runif(N,1,99),same_division=rbinom(N,1,.4),same_conference=1,
    game_seconds_remaining=runif(N,121,3600),posteam_type=sample(c('home','away'),N,TRUE),week=sample(1:17,N,TRUE),game_location='Home')
  x$posteam<-x$team;x$same_conference<-pmax(x$same_division,rbinom(N,1,.5))
  xx<-make_variables(x,origin)
  a<-rnorm(8,0,.7);eta<--1.5+a[match(x$team,unique(x$team))]+.015*xx$total_points-.04*xx$yards_first_down-.007*xx$yards_touchdown+.025*xx$perf_above-.03*xx$perf_below
  x$y<-rbinom(N,1,plogis(eta))
  cells<-list(list(u=origin,step=1L,models=c('M1','M2','M3')))
  for(k in 1:2){u<-origin;u['U7']<-k;cells[[length(cells)+1]]<-list(u=u,step=2L,models=c('M1','M2','M3'))}
  u<-origin;u['U8']<-1;cells[[4]]<-list(u=u,step=2L,models='M1');cells[[5]]<-list(u=origin,step=3L,models=c('M1','M2','M3'))
  for(i in seq_along(cells)){cells[[i]]$sample_hash<-'synthetic';cells[[i]]$base_key<-'toy'}
  bases<-new.env();assign('toy',list(data=x),bases)
  wd<-getwd();dir.create('results/synthetic_smoke/results',recursive=TRUE,showWarnings=FALSE)
  setwd('results/synthetic_smoke');on.exit(setwd(wd))
  run_full(list(plan=cells,bases=bases))
  specs<-read.csv('results/specs.csv');stopifnot(nrow(specs)==13,all(specs$status=='ok'))
  inf<-read.csv('results/influence.csv');stopifnot(nrow(inf)==(8+6)*11,all(inf$status=='ok'),all(inf$benchmark_status=='ok'))
  ne<-read.csv('results/nonequiv.csv');ss<-ne[ne$record_type=='specs' & ne$run_id %in% c('N1','N2','N4'),];stopifnot(nrow(ss)==9,all(ss$status=='ok'))
  alg<-read.csv('results/algebraic_checks.csv');aa<-alg[alg$record_type=='comparison',];stopifnot(nrow(aa)==2,max(abs(aa$loglik_difference))<1e-5)
  stopifnot(abs(aa$original_estimate[aa$run_id=='K2']+aa$transformed_estimate[aa$run_id=='K2'])<1e-5)
  mm<-read.csv('results/margins.csv');stopifnot(all(c('ME0','U9a','U9b','U10a','N3') %in% mm$variant),all(is.finite(mm$se_native)))
}
