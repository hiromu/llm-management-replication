fit_model <- function(data,model,u,random=FALSE,start=NULL) {
  X<-as.matrix(data[,terms_for(model,u),drop=FALSE]);storage.mode(X)<-'double'
  if(random)f<-fit_random(X,data$y,data$team) else if(u['U7']==1)f<-fit_unconditional(X,data$y,data$team,data$game_id) else {
    group<-if(u['U7']==2)paste(data$team,data$season,sep=':') else data$team
    f<-fit_conditional(X,data$y,group,start)
  }
  f$data<-data[f$used,,drop=FALSE];f$model<-model;f$estimator<-if(random)'N1' else paste0('U7=',u['U7']);f
}
safe_fit <- function(...) {
  warnings<-character()
  f<-tryCatch(withCallingHandlers(fit_model(...),warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')}),error=function(e)list(failed=TRUE,error=conditionMessage(e)))
  if(length(warnings))f$error<-paste(c(f$error,unique(warnings)),collapse='; ')
  f
}
coef_rows <- function(f,model) {
  se<-sqrt(diag(f$V));sb<-if(is.null(f$B))rep(NA_real_,length(se)) else sqrt(diag(f$B))
  data.frame(model=model,term=names(f$b),estimate=unname(f$b),se_native=se,z_native=f$b/se,p_native=pnorm2(f$b/se),
             or=ifelse(names(f$b)=='log_sigma',NA_real_,exp(f$b)),or_se=ifelse(names(f$b)=='log_sigma',NA_real_,exp(f$b)*se),se_bench=sb,p_bench=pnorm2(f$b/sb),n_clusters_bench=if(is.null(f$G))NA_integer_ else f$G,row.names=NULL)
}
fit_tests <- function(fits) {
  out<-list();add<-function(test,stat,df)out[[length(out)+1]]<<-data.frame(test=test,statistic=stat,df=df,p=pchisq(stat,df,lower.tail=FALSE))
  for(pair in list(c('M1','M2'),c('M2','M3'))) {
    a<-fits[[pair[1]]];b<-fits[[pair[2]]]
    if(!is.null(a)&&!is.null(b)&&!isTRUE(a$failed)&&!isTRUE(b$failed)) {
      if(!identical(a$data[,c('game_id','play_id')],b$data[,c('game_id','play_id')]))stop('LR samples differ')
      add(paste0('LR_',pair[2],'_vs_',pair[1]),2*(b$loglik-a$loglik),b$df-a$df)
    }
  }
  f<-fits$M2
  if(!is.null(f)&&!isTRUE(f$failed)) {
    a<-setNames(rep(0,length(f$b)),names(f$b));a['perf_below']<-1;a['perf_above']<--1;A<-f$active;a<-a[A]
    add('Wald_M2_below_equals_above',sum(a*f$b[A])^2/drop(a%*%f$V[A,A,drop=FALSE]%*%a),1)
    b<-f$b[perf_terms];V<-f$V[perf_terms,perf_terms];add('Wald_M2_performance_joint_zero',drop(b%*%solve(V,b)),4)
  }
  data.table::rbindlist(out,fill=TRUE)
}
new_writer <- function() {
  spec<-c('spec_id','execution_id','step','model',axes,'me_variant_set','sample_hash','status','error','n_obs','n_groups_used','n_groups_dropped','loglik','null_loglik','null_label','lr_chi2','df','converged','iterations','routine','duplicate_of')
  coef<-c('spec_id','execution_id','model','term','estimate','se_native','z_native','p_native','or','or_se','se_bench','p_bench','n_clusters_bench')
  mar<-c('spec_id','execution_id','model','variant','minutes_eval','d','prob','effect','se_native','z_native','p_native','se_bench','p_bench','estimator_source')
  test<-c('spec_id','execution_id','test','statistic','df','p')
  combined<-unique(c('run_id','record_type',spec,coef,mar,test,'loglik_difference','original_estimate','transformed_estimate'))
  schemas<-list(specs=spec,coefs=coef,margins=mar,tests=test,nonequiv=combined,algebraic_checks=combined,
     influence=c('unit_type','unit_id','model','term','estimate','se_native','p_native','se_bench','p_bench','n_obs','status','error','benchmark_estimate','benchmark_n_obs','benchmark_status','benchmark_error'))
  for(nm in names(schemas))writeLines(paste(schemas[[nm]],collapse=','),paste0('results/',nm,'.csv'))
  function(file,rows) {
    if(!nrow(rows))return(invisible(NULL))
    rows<-as.data.frame(rows)
    for(nm in setdiff(schemas[[file]],names(rows)))rows[[nm]]<-NA
    data.table::fwrite(rows[,schemas[[file]],drop=FALSE],paste0('results/',file,'.csv'),append=TRUE,col.names=FALSE,na='')
  }
}
summary_row <- function(f,model,u,step,hash,variants,dup='') {
  out<-data.frame(spec_id=spec_id(model,u),step=step,model=model,as.list(u),me_variant_set=paste(variants,collapse=','),sample_hash=hash,
    status=if(isTRUE(f$failed))'failed' else if(f$converged)'ok' else 'not_converged',error=f$error,duplicate_of=dup)
  if(!isTRUE(f$failed)) {
    out$n_obs<-f$n;out$n_groups_used<-f$groups;out$n_groups_dropped<-f$dropped;out$loglik<-f$loglik
    out$null_loglik<-f$null_loglik;out$null_label<-f$null_label;out$lr_chi2<-2*(f$loglik-f$null_loglik)
    out$df<-f$df;out$converged<-f$converged;out$iterations<-f$iterations;out$routine<-f$routine
  }
  out
}
run_full <- function(samples) {
  emit<-new_writer();seen<-new.env();origin_fits<-list();origin_u1<-list()
  # All auxiliary unconditional fits are explicitly recorded in nonequiv.csv
  # with run_id U9a_source; these are sources, not extra specification cells.
  record<-function(f,model,u,step,hash,eid,variants,companion=NULL,file=NULL,run_id=NULL,dup='',quarter=FALSE) {
    send<-function(type,rows) {
      if(!nrow(rows))return()
      rows$spec_id<-spec_id(model,u);rows$execution_id<-eid
      if(is.null(file))emit(type,rows) else {rows$record_type<-type;rows$run_id<-run_id;emit(file,rows)}
    }
    send('specs',summary_row(f,model,u,step,hash,variants,dup))
    if(!isTRUE(f$failed)) {
      send('coefs',coef_rows(f,model))
      mr<-tryCatch(margin_rows(f,model,variants,companion,quarter),error=function(e) {
        note(paste('Marginal effect failure',eid,conditionMessage(e)));data.frame()
      })
      send('margins',mr)
    }
  }
  for(i in seq_along(samples$plan)) {
    cell<-samples$plan[[i]];u<-cell$u;x<-cell_data(samples,cell);fits<-list();companions<-list()
    message(sprintf('Cell %d/%d, step %d: %s',i,length(samples$plan),cell$step,cell_key(u)))
    for(model in cell$models) {
      f<-safe_fit(x,model,u);fits[[model]]<-f
      variants<-if(model=='M1')character() else if(cell$step<=2)c('ME0','U9a','U9b','U10a',if(cell$step==1)'N3') else 'ME0'
      comp<-NULL
      if('U9a' %in% variants) {
        if(u['U7']==1)comp<-f else {
          uc<-u;uc['U7']<-1;comp<-safe_fit(x,model,uc)
          record(comp,model,uc,cell$step,cell$sample_hash,paste0('cell_',i,'_',model,'_U9a_source'),character(),file='nonequiv',run_id='U9a_source')
        }
        if(isTRUE(comp$failed)){note(paste('U9a source failed',i,model,comp$error));comp<-NULL}
      }
      id<-spec_id(model,u);dup<-if(exists(id,seen,inherits=FALSE))id else ''
      if(!nzchar(dup))assign(id,TRUE,seen)
      record(f,model,u,cell$step,cell$sample_hash,paste0('cell_',i,'_',model),variants,comp,dup=dup)
      if(i==1) {origin_fits[[model]]<-f;if(model!='M1')origin_u1[[model]]<-comp}
    }
    tt<-tryCatch(fit_tests(fits),error=function(e){note(paste('Test failure cell',i,conditionMessage(e)));data.frame()})
    if(nrow(tt)) {
      tt$model<-ifelse(grepl('M3',tt$test),'M3','M2');tt$spec_id<-vapply(tt$model,spec_id,'',u=u)
      tt$execution_id<-paste0('cell_',i,'_',tt$model);emit('tests',tt)
    }
  }
  cell<-samples$plan[[1]];x<-cell_data(samples,cell)
  for(run in c('N1','N2','N4')) {
    fs<-list();xx<-x
    if(run=='N2') {xx$minutes<-5-xx$qtr;for(j in 1:3)xx[[interaction_terms[j]]]<-xx[[perf_terms[j]]]*xx$minutes}
    for(model in c('M1','M2','M3')) {
      u<-origin
      if(run=='N4') {
        u['U7']<-1
        f<-if(model=='M1')safe_fit(x,model,u) else origin_u1[[model]]
        if(is.null(f))f<-list(failed=TRUE,error='U9a source fit unavailable')
        if(!isTRUE(f$failed)) {
          f<-tryCatch({rob<-sandwich(f$X[,f$active,drop=FALSE],f$y,f$b[f$active],f$V[f$active,f$active,drop=FALSE],f$data$team)
            f$B[f$active,f$active]<-rob$V;f$G<-rob$G;f$routine<-paste(f$routine,'N4 replaces benchmark with team CR1');f},error=function(e)list(failed=TRUE,error=conditionMessage(e)))
        }
      } else f<-safe_fit(xx,model,u,random=run=='N1')
      fs[[model]]<-f
      record(f,model,u,4,cell$sample_hash,paste(run,model,sep='_'),if(model=='M1')character() else 'ME0',
             file='nonequiv',run_id=run,quarter=run=='N2')
    }
    tt<-tryCatch(fit_tests(fs),error=function(e){note(paste('Tests',run,conditionMessage(e)));data.frame()})
    if(nrow(tt)){tt$run_id<-run;tt$record_type<-'tests';tt$spec_id<-vapply(ifelse(grepl('M3',tt$test),'M3','M2'),spec_id,'',u=u);emit('nonequiv',tt)}
  }
  for(run in c('K1','K2')) {
    xx<-x;model<-if(run=='K1')'M3' else 'M2'
    if(run=='K1'){xx$minutes<-60-xx$minutes;for(j in 1:3)xx[[interaction_terms[j]]]<-xx[[perf_terms[j]]]*xx$minutes} else xx$home_field<-1-xx$home_field
    f<-safe_fit(xx,model,origin);record(f,model,origin,5,cell$sample_hash,run,character(),file='algebraic_checks',run_id=run)
    old<-origin_fits[[model]]
    if(!isTRUE(f$failed)&&!isTRUE(old$failed))emit('algebraic_checks',data.frame(run_id=run,record_type='comparison',spec_id=spec_id(model,origin),model=model,
      loglik_difference=f$loglik-old$loglik,original_estimate=if(run=='K2')old$b['home_field'] else NA,
      transformed_estimate=if(run=='K2')f$b['home_field'] else NA))
  }
  for(unit in c('team','season')) for(value in sort(unique(x[[unit]]))) {
    xx<-x[x[[unit]]!=value,,drop=FALSE];message('Influence ',unit,' ',value)
    for(model in c('M2','M3')) {
      f<-safe_fit(xx,model,origin);u<-origin;u['U7']<-1;b<-safe_fit(xx,model,u)
      terms<-c(perf_terms,if(model=='M3')interaction_terms)
      rows<-data.frame(unit_type=unit,unit_id=as.character(value),model=model,term=terms,
        n_obs=if(isTRUE(f$failed))nrow(xx) else f$n,status=if(isTRUE(f$failed))'failed' else if(f$converged)'ok' else 'not_converged',error=f$error,
        benchmark_n_obs=if(isTRUE(b$failed))nrow(xx) else b$n,benchmark_status=if(isTRUE(b$failed))'failed' else if(b$converged)'ok' else 'not_converged',benchmark_error=b$error)
      if(!isTRUE(f$failed)) {cf<-coef_rows(f,model);jj<-match(terms,cf$term);rows$estimate<-cf$estimate[jj];rows$se_native<-cf$se_native[jj];rows$p_native<-cf$p_native[jj]}
      if(!isTRUE(b$failed)) {cf<-coef_rows(b,model);jj<-match(terms,cf$term);rows$benchmark_estimate<-cf$estimate[jj];rows$se_bench<-cf$se_bench[jj];rows$p_bench<-cf$p_bench[jj]}
      emit('influence',rows)
    }
  }
}
