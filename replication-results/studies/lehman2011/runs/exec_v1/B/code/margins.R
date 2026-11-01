# Evaluation vectors retain all estimated coefficients, but group effects are
# exactly zero except for U9a. Algebraic aliases never enter reported gradients.
margin_design <- function(f,d,m,variant='ME0',above=FALSE) {
  nm<-names(f$b);A<-f$active;X<-f$X[,A,drop=FALSE];namesA<-nm[A]
  groupcols<-namesA=='(Intercept)'|grepl('^team',namesA)|namesA=='log_sigma'
  if(variant=='N3') Z<-X else Z<-matrix(colMeans(X),1,dimnames=list(NULL,namesA))
  Z[,groupcols]<-0
  if(variant=='U9a') {
    D<-unique(X[,groupcols,drop=FALSE]);Z<-Z[rep(1,nrow(D)),,drop=FALSE];Z[,groupcols]<-D
  }
  set<-function(n,v)if(n %in% colnames(Z))Z[,n]<<-v
  if(!(variant=='N3' && identical(f$model,'M2')))set('minutes',m);below<-d<=0 && !above
  set('below_indicator',as.numeric(below));set('perf_below',if(below)d else 0)
  set('perf_below_sq',if(below)d*d else 0);set('perf_above',if(below)0 else d)
  for(j in 1:3)if(interaction_terms[j] %in% colnames(Z))Z[,interaction_terms[j]]<-Z[,perf_terms[j]]*m
  slope<-setNames(rep(0,length(A)),namesA)
  add<-function(n,v)if(n %in% names(slope))slope[n]<<-v
  if(below) {add('perf_below',1);add('perf_below_sq',2*d);add('perf_below_x_min',m);add('perf_below_sq_x_min',2*d*m)} else {add('perf_above',1);add('perf_above_x_min',m)}
  list(Z=Z,slope=slope)
}
margin_value <- function(f,d,m,variant='ME0',b=f$b[f$active]) {
  a<-margin_design(f,d,m,variant,above=variant=='U10a');Z<-a$Z
  p<-plogis(drop(Z%*%b));w<-p*(1-p)
  if(variant=='U9b') {
    Z2<-margin_design(f,d+1,m,'ME0')$Z;p2<-plogis(drop(Z2%*%b))
    effect<-mean(p2-p);grad<-colMeans(Z2*as.numeric(p2*(1-p2))-Z*as.numeric(w))
  } else {
    slope<-sum(a$slope*b);effect<-mean(w*slope)
    grad<-colMeans(Z*as.numeric(w*(1-2*p)*slope))+mean(w)*a$slope
  }
  list(prob=mean(p),effect=effect,gradient=grad)
}
margin_rows <- function(f,model,variants=c('ME0'),uncond=NULL,quarter=FALSE) {
  if(model=='M1')return(data.frame())
  out<-list();idx<-0L
  for(v in variants) {
    ff<-if(v=='U9a')uncond else f
    if(is.null(ff)) next
    ms<-if(model=='M2')mean(ff$data$minutes) else if(quarter)c(4,3,2,1) else c(53,38,23,8)
    for(m in ms) for(d in if(v=='U10a')0 else c(-42,-28,-14,0,14,28,42)) {
      val<-margin_value(ff,d,m,v);A<-ff$active;g<-val$gradient
      se<-sqrt(max(0,drop(g%*%ff$V[A,A,drop=FALSE]%*%g)))
      sb<-if(!is.null(ff$B) && v!='U9a')sqrt(max(0,drop(g%*%ff$B[A,A,drop=FALSE]%*%g))) else NA_real_
      idx<-idx+1L;out[[idx]]<-data.frame(model=model,variant=v,minutes_eval=m,d=d,prob=val$prob,effect=val$effect,
        se_native=se,z_native=val$effect/se,p_native=pnorm2(val$effect/se),se_bench=sb,p_bench=pnorm2(val$effect/sb),
        estimator_source=if(v=='U9a')'U7=1' else ff$estimator)
    }
  }
  data.table::rbindlist(out,fill=TRUE)
}
