#!/opt/homebrew/bin/Rscript
suppressPackageStartupMessages(library(lavaan))
suppressPackageStartupMessages(library(jsonlite))
options(digits = 17, warn = 1)
YEARS <- c("1976", "1991", "2006")
PAIRS <- list(P1 = c(1L, 2L), P2 = c(2L, 3L), P3 = c(1L, 3L))
K <- list(K1=c("V4236","V4238","V4240","V4246"),
          K2=c("V4227","V4225","V4231","V4232","V4234","V4242","V4243"),
          K3=c("V4235","V4229"), K4=c("V4233","V4245"),
          K5=c("V4226","V4228","V4230","V4244"),
          K6=c("V4239","V4241"), K7=c("V4237","V4247"))
C <- list(C1=c("V3224","V3225","V3222","V3223","V3227"), C2="V3226")
RELEASED <- c("V4238","V4240","V4231","V4229","V4230","V4228")
F4 <- paste0("V",4225:4247); F3 <- paste0("V",3222:3227)
SPECS <- c(sprintf("S%02d",0:6),"S07a","S07b","S08","CHK1","CHK2")
software <- function() list(R=R.version.string,
  packages=lapply(c("lavaan","jsonlite","numDeriv"), function(p)
    list(package=p,version=as.character(packageVersion(p)))),
  sessionInfo=capture.output(sessionInfo()))
write_json_full <- function(x,path) write_json(x,path,pretty=TRUE,auto_unbox=TRUE,
  digits=17,na="null",null="null",dataframe="rows",matrix="rowmajor")
sha_ids <- function(ids) {
  dir.create("results",showWarnings=FALSE)
  f <- tempfile("sample_ids_",tmpdir="results"); on.exit(unlink(f))
  writeLines(sprintf("%.17g",sort(ids)),f,useBytes=TRUE)
  ans <- system2("shasum",c("-a","256",shQuote(f)),stdout=TRUE,stderr=TRUE)
  if (!is.null(attr(ans,"status"))) stop("SHA-256 command failed: ",paste(ans,collapse=" "))
  h <- strsplit(ans[1],"[[:space:]]+")[[1]][1]
  if (!grepl("^[0-9a-f]{64}$",h)) stop("Invalid SHA-256 output")
  h
}
sample_meta <- function(s) list(n=s$n,V4_sha256=sha_ids(s$ids))
config <- function(id) {
  stopifnot(id %in% SPECS)
  list(id=id,weighted=id=="S01",normal=id %in% c("S02","S04","S06"),
       fiml=id=="S04",robust=id=="S06",complete_all=id=="S03",
       effects=id=="S05",check1=id=="CHK1",
       markers=if(id=="CHK2") c(K1="V4246",K2="V4225",K3="V4235",K4="V4245",K5="V4244") else
         vapply(K[1:5],`[`,character(1),1))
}
weight_valid <- function(w,dict) {
  v <- Filter(function(z) identical(z$name,"V5"),dict$variables)
  if(length(v)!=1L) stop("Dictionary must contain exactly one V5 entry")
  v<-v[[1]]; good<-is.finite(w)&w>0
  mv<-unlist(v$declared_missing_values)
  if(length(mv)) good<-good & !(w %in% as.numeric(mv))
  mr<-unlist(v$declared_missing_range)
  if(length(mr)) {
    if(length(mr)!=2L) stop("Unsupported declared missing range")
    endpoint<-function(z) if(z=="HIGHEST") Inf else if(z=="LOWEST") -Inf else as.numeric(z)
    lo<-endpoint(mr[1]); hi<-endpoint(mr[2])
    good<-good & !(w>=lo & w<=hi)
  }
  good[is.na(good)]<-FALSE; good
}
load_inputs <- function() {
  files<-list(); rows<-list(); invalid<-list()
  for(form in c(3L,4L)) for(year in YEARS) {
    key<-paste0("y",year,"_f",form)
    # Read every row and column; no demographic filters.
    con<-gzfile(file.path("data",paste0(key,".csv.gz")),"rt")
    d<-tryCatch(read.csv(con,check.names=FALSE,na.strings="",colClasses="numeric"),finally=close(con))
    rows[[key]]<-nrow(d)
    items<-if(form==3L) F3 else F4
    stopifnot(all(c("V4","V5",items)%in%names(d)),!anyNA(d$V4),!anyDuplicated(d$V4))
    dict<-fromJSON(file.path("dictionaries",paste0(key,".dictionary.json")),simplifyVector=FALSE)
    d<-d[,c("V4","V5",items),drop=FALSE]
    d$.weight_valid<-weight_valid(d$V5,dict)
    invalid[[key]]<-sum(!d$.weight_valid)
    for(item in items) {
      valid<-if(form==4L) 1:4 else if(item=="V3227") 1:2 else 1:5
      d[[item]][!(d[[item]]%in%valid)]<-NA_real_
    }
    files[[key]]<-d
  }
  list(files=files,rows=rows,invalid_weights=invalid)
}
prepare_files <- function(inputs,cfg) {
  out<-inputs$files
  for(key in names(out)) {
    d<-out[[key]]
    if(cfg$weighted) d<-d[d$.weight_valid,,drop=FALSE]
    if(cfg$complete_all) {
      items<-if(grepl("_f3$",key)) F3 else F4
      d<-d[complete.cases(d[,items,drop=FALSE]),,drop=FALSE]
    }
    out[[key]]<-d
  }
  out
}
make_sample <- function(d,items,weighted=FALSE,fiml=FALSE,reverse=FALSE) {
  x<-as.matrix(d[,items,drop=FALSE]); storage.mode(x)<-"double"
  keep<-if(fiml) rowSums(!is.na(x))>0 else complete.cases(x)
  x<-x[keep,,drop=FALSE]
  if(reverse) {
    for(v in intersect(c("V3222","V3223"),colnames(x))) x[,v]<-6-x[,v]
    if("V3227"%in%colnames(x)) x[,"V3227"]<-3-x[,"V3227"]
  }
  n<-nrow(x); w<-if(weighted) d$V5[keep] else rep(1,n)
  if(n) w<-w*n/sum(w)
  list(x=x,n=n,ids=d$V4[keep],w=w,weighted=weighted)
}
moments <- function(s,normal=FALSE) {
  if(s$n<2L) stop("Fewer than two analysis records")
  if(anyNA(s$x)) stop("Complete sample moments requested for incomplete data")
  m<-colSums(s$x*s$w)/sum(s$w)
  xc<-sweep(s$x,2,m)
  cv<-crossprod(xc,xc*s$w)/(s$n-as.integer(!normal))
  list(mean=m,cov=cv)
}
# Every model parameter is explicit: no automatic marker, intercept, or covariance rules.
model_syntax <- function(factors,model="single",cfg=config("S00"),G=3L) {
  if(model=="single") G<-1L
  scalar<-model%in%c("M3","M4","M5")
  metric<-model%in%c("M2","M3","M4","M5")
  partial<-model%in%c("M4","M5")
  effects<-cfg$effects && scalar
  check1<-cfg$check1
  if(check1 && model!="M4") stop("CHK1 only defines M4")
  terms<-character(); constraints<-character()
  mod<-function(z) if(length(z)==1L) z else paste0("c(",paste(z,collapse=","),")")
  lab<-function(prefix,shared=FALSE) if(shared) rep(prefix,G) else paste0(prefix,"_g",seq_len(G))
  add<-function(z) terms<<-c(terms,z)
  L<-N<-list()
  for(f in names(factors)) {
    its<-factors[[f]]
    marker<-if(model=="single") its[1] else unname(cfg$markers[f])
    lt<-character()
    for(v in its) {
      ll<-if(!effects && !check1 && v==marker) rep("1",G) else lab(paste0("L_",f,"_",v),metric)
      L[[v]]<-ll; lt<-c(lt,paste0(mod(ll),"*",v))
    }
    add(paste(f,"=~",paste(lt,collapse=" + ")))
    for(v in its) {
      ni<-if(scalar && !effects && !check1 && v==marker) rep("0",G) else
        lab(paste0("N_",v),scalar && !(partial && v%in%RELEASED))
      N[[v]]<-ni
      add(paste(v,"~",paste0(mod(ni),"*1")))
      rr<-if(f=="C2" && length(its)==1L) rep("0",G) else lab(paste0("E_",v))
      add(paste(v,"~~",paste0(mod(rr),"*",v)))
    }
    aa<-if(!scalar && !check1) rep("0",G) else lab(paste0("A_",f),model=="M5")
    vv<-lab(paste0("P_",f))
    if(check1) {aa[1]<-"0"; vv[1]<-"1"}
    add(paste(f,"~",paste0(mod(aa),"*1")))
    add(paste(f,"~~",paste0(mod(vv),"*",f)))
    if(effects) for(g in seq_len(G)) {
      constraints<-c(constraints,
        paste(paste(vapply(its,function(v)L[[v]][g],character(1)),collapse=" + "),"==",length(its)),
        paste(paste(vapply(its,function(v)N[[v]][g],character(1)),collapse=" + "),"== 0"))
    }
  }
  if(length(factors)>1L) for(i in seq_len(length(factors)-1L)) for(j in (i+1L):length(factors)) {
    a<-names(factors)[i]; b<-names(factors)[j]
    add(paste(a,"~~",paste0(mod(lab(paste0("P_",a,"_",b))),"*",b)))
  }
  paste(c(terms,unique(constraints)),collapse="\n")
}
fit_model <- function(samples,factors,model,cfg,start=NULL) {
  syntax<-model_syntax(factors,model,cfg,length(samples))
  warns<-character(); fit<-NULL; err<-NULL
  args<-list(model=syntax,meanstructure=TRUE,auto.fix.first=FALSE,auto.fix.single=FALSE,
    auto.var=FALSE,auto.cov.lv.x=FALSE,auto.cov.y=FALSE,int.ov.free=FALSE,int.lv.free=FALSE,
    fixed.x=FALSE,std.lv=FALSE,estimator=if(cfg$robust) "MLR" else "ML",
    likelihood=if(cfg$normal) "normal" else "wishart",
    information=if(cfg$robust) "observed" else "expected",
    # Supplied moments are already normalized; raw normal-likelihood data must
    # be rescaled by lavaan from its initial n-1 covariance to divisor n.
    sample.cov.rescale=cfg$robust || cfg$fiml,optim.method="nlminb",
    control=list(rel.tol=1e-10,iter.max=20000L,eval.max=40000L),
    baseline=TRUE)
  if(!is.null(start)) args$start<-start
  if(cfg$fiml || cfg$robust) {
    raw<-do.call(rbind,lapply(seq_along(samples),function(g) {
      d<-as.data.frame(samples[[g]]$x); d$.group<-names(samples)[g]; d
    }))
    args$data<-raw
    if(length(samples)>1L) {args$group<-".group";args$group.label<-names(samples)}
    args$missing<-if(cfg$fiml) "ml" else "listwise"
  } else {
    mm<-lapply(samples,moments,normal=cfg$normal)
    args$sample_cov<-lapply(mm,`[[`,"cov")
    args$sample_mean<-lapply(mm,`[[`,"mean")
    args$sample_nobs<-vapply(samples,`[[`,numeric(1),"n")
    if(length(samples)>1L) args$group.label<-names(samples)
    if(length(samples)==1L) {
      args$sample_cov<-args$sample_cov[[1]];args$sample_mean<-args$sample_mean[[1]]
    }
  }
  elapsed<-system.time({
    fit<-tryCatch(withCallingHandlers(do.call(lavaan,args),warning=function(w) {
      warns<<-c(warns,conditionMessage(w));invokeRestart("muffleWarning")
    }),error=function(e) {err<<-conditionMessage(e);NULL})
  })[["elapsed"]]
  list(fit=fit,error=err,warnings=unique(warns),seconds=elapsed,syntax=syntax)
}
as_groups <- function(x,G) if(G==1L) list(x) else x
logdet <- function(s) {
  d<-determinant(s,logarithm=TRUE)
  if(d$sign<=0) stop("Nonpositive covariance determinant")
  as.numeric(d$modulus)
}
fit_indices <- function(fit,samples,cfg) {
  G<-length(samples); n<-vapply(samples,`[[`,numeric(1),"n"); cc<-n-as.integer(!cfg$normal)
  tests<-lavInspect(fit,"test"); standard<-tests$standard
  df<-as.numeric(standard$df)
  imp<-as_groups(lavInspect(fit,"implied"),G)
  if(cfg$fiml) {
    mm<-as_groups(lavInspect(fit,"sampstat"),G)
    chi<-as.numeric(standard$stat)
    fm<-fitMeasures(fit,c("baseline.chisq","baseline.df"))
    basechi<-unname(fm["baseline.chisq"]); basedf<-unname(fm["baseline.df"])
  } else {
    mm<-lapply(samples,moments,normal=cfg$normal)
    fg<-vapply(seq_len(G),function(g) {
      v<-colnames(imp[[g]]$cov); S<-mm[[g]]$cov[v,v,drop=FALSE]; Sig<-imp[[g]]$cov
      dm<-mm[[g]]$mean[v]-imp[[g]]$mean[v]; inv<-solve(Sig)
      logdet(Sig)+sum(S*t(inv))-logdet(S)-ncol(S)+as.numeric(crossprod(dm,inv%*%dm))
    },numeric(1))
    chi<-sum(cc*fg)
    basechi<-sum(cc*vapply(mm,function(m) sum(log(diag(m$cov)))-logdet(m$cov),numeric(1)))
    p<-ncol(mm[[1]]$cov); basedf<-G*p*(p-1)/2
  }
  sr<-vapply(seq_len(G),function(g) {
    v<-colnames(imp[[g]]$cov); S<-mm[[g]]$cov[v,v,drop=FALSE]
    R<-(S-imp[[g]]$cov)/sqrt(outer(diag(S),diag(S)))
    sqrt(mean(R[lower.tri(R,diag=TRUE)]^2))
  },numeric(1))
  denom<-max(chi-df,basechi-basedf,0)
  cfi<-if(denom==0) 1 else 1-max(chi-df,0)/denom
  tli<-if(df>0 && basedf>0 && basechi!=basedf) 1-((chi-df)/df)/((basechi-basedf)/basedf) else NA_real_
  p<-ncol(mm[[1]]$cov); totalmom<-G*p*(p+3)/2
  out<-list(chi_square=chi,df=df,p=if(df>0) pchisq(chi,df,lower.tail=FALSE) else NA_real_,
    RMSEA=if(df>0) sqrt(G)*sqrt(max(chi-df,0)/(df*sum(cc))) else NA_real_,
    CFI=cfi,TLI=tli,SRMR=sum(n/sum(n)*sr),SRMR_by_group=setNames(as.list(sr),names(samples)),
    baseline=list(chi_square=basechi,df=basedf,definition="Free means and variances; zero covariances; no group constraints"),
    sample_moments=totalmom,effective_free_parameters=totalmom-df,
    c_g=setNames(as.list(cc),names(samples)),lavaan_standard_chi_square=as.numeric(standard$stat))
  if(cfg$robust) {
    tt<-tests[[which(vapply(tests,function(z)grepl("yuan.bentler",z$test),logical(1)))[1]]]
    out$scaled_chi_square<-list(test=tt$test,chi_square=tt$stat,df=tt$df,p=tt$pvalue,
      scaling_factor=tt$scaling.factor)
  }
  out
}
model_output <- function(res,samples,cfg) {
  out<-list(status="failed",reason=res$error,syntax=res$syntax,
    samples=lapply(samples,sample_meta),converged=FALSE,warnings=res$warnings,elapsed_seconds=res$seconds)
  if(is.null(res$fit)) return(out)
  f<-res$fit; cv<-isTRUE(lavInspect(f,"converged")); out$converged<-cv
  out$status<-if(cv) "ok" else "failed"
  out$reason<-if(cv) NULL else "Optimizer did not converge"
  op<-lavInspect(f,"optim")
  out$optimizer<-list(iterations=op$iterations,control=op$control,
    max_abs_gradient=if(length(op$dx)) max(abs(op$dx)) else NA_real_,message=op$warn.txt)
  out$resolved_lavaan_options<-lavInspect(f,"options")
  out$parameters<-as.data.frame(parameterEstimates(f))
  out$fit<-tryCatch(fit_indices(f,samples,cfg),error=function(e) list(status="failed",reason=conditionMessage(e)))
  if(identical(out$fit$status,"failed")) {out$status<-"failed";out$reason<-out$fit$reason}
  out
}
latent_outputs <- function(fit,samples,factors=K[1:5],cfg=config("S00")) {
  pt<-parTable(fit); V<-vcov(fit)
  rowpar<-function(f,op,g) {
    ii<-which(pt$lhs==f & pt$op==op & pt$group==g & if(op=="~~") pt$rhs==f else pt$rhs=="")
    if(length(ii)!=1L) stop("Cannot uniquely locate parameter ",f," ",op," group ",g)
    pt[ii,,drop=FALSE]
  }
  out<-list(means=list(),contrasts=list())
  for(f in names(factors)) {
    aa<-vv<-numeric(3); free<-integer(3); ses<-numeric(3)
    out$means[[f]]<-list()
    for(g in seq_len(3)) {
      a<-rowpar(f,"~1",g); p<-rowpar(f,"~~",g)
      aa[g]<-a$est;vv[g]<-p$est;free[g]<-a$free
      ses[g]<-if(a$free>0) sqrt(V[a$free,a$free]) else 0
      out$means[[f]][[YEARS[g]]]<-list(alpha=aa[g],SE=ses[g],
        CI95=c(lower=aa[g]-1.96*ses[g],upper=aa[g]+1.96*ses[g]),
        psi=vv[g],SD=if(vv[g]>=0)sqrt(vv[g]) else NA_real_)
    }
    out$contrasts[[f]]<-list()
    for(pair in names(PAIRS)) {
      a<-PAIRS[[pair]][1];b<-PAIRS[[pair]][2];n<-c(samples[[a]]$n,samples[[b]]$n)
      cv<-if(all(free[c(a,b)]>0)) V[free[a],free[b]] else 0
      se<-sqrt(ses[a]^2+ses[b]^2-2*cv);delta<-aa[b]-aa[a]; z<-delta/se
      root<-function(x) if(is.finite(x)&&x>0) sqrt(x) else NA_real_
      deq<-delta/root(mean(vv[c(a,b)]))
      obsvar<-vapply(c(a,b),function(g) {
        xx<-samples[[g]]$x[,factors[[f]],drop=FALSE]
        if(anyNA(xx)) return(NA_real_)
        score<-rowMeans(xx); s<-samples[[g]];m<-sum(score*s$w)/sum(s$w)
        sum(s$w*(score-m)^2)/(s$n-1)
      },numeric(1))
      dobs<-delta/root(mean(obsvar))
      out$contrasts[[f]][[pair]]<-list(earlier=YEARS[a],later=YEARS[b],Delta=delta,SE=se,
        covariance_of_means=cv,z=z,p=2*pnorm(abs(z),lower.tail=FALSE),
        SE_type=if(cfg$robust) "Huber-White observed-score sandwich" else "expected information",
        d_eq=deq,d_df=delta/root(sum((n-1)*vv[c(a,b)])/sum(n-1)),
        g=deq*(1-3/(4*sum(n)-9)),d_glass=delta/root(vv[a]),d_obs=dobs,
        observed_score_variances=setNames(as.list(obsvar),YEARS[c(a,b)]))
      if(anyNA(obsvar)) out$contrasts[[f]][[pair]]$d_obs_availability<-list(status="unavailable",
        reason="The multigroup sample has missing factor items. The manifest does not define a unit-weighted complete-item score or its SD for these records; no imputation, available-item averaging, or extra exclusion was substituted.")
    }
  }
  out
}
model_differences <- function(models) {
  comparisons<-list("M2-M1"=c("M2","M1"),"M3-M2"=c("M3","M2"),
    "M4-M2"=c("M4","M2"),"M5-M4"=c("M5","M4"))
  lapply(comparisons,function(ids) {
    a<-models[[ids[1]]]$fit;b<-models[[ids[2]]]$fit
    if(is.null(a$chi_square)||is.null(b$chi_square)) return(list(status="failed",reason="A constituent fit is unavailable"))
    dd<-a$df-b$df; dc<-a$chi_square-b$chi_square
    list(chi_square_difference=dc,df_difference=dd,
      p=if(dd>0) pchisq(dc,dd,lower.tail=FALSE) else NA_real_,CFI_difference=b$CFI-a$CFI,
      test="Ordinary unscaled likelihood-ratio difference")
  })
}
item_statistics <- function(files,cfg) {
  stats<-list(); comparisons<-list()
  for(form in c(3L,4L)) for(v in if(form==3L) F3 else F4) {
    stats[[v]]<-list()
    for(year in YEARS) {
      s<-make_sample(files[[paste0("y",year,"_f",form)]],v,cfg$weighted)
      x<-as.vector(s$x);w<-s$w;W<-sum(w);n<-s$n
      m<-if(n)sum(w*x)/W else NA_real_
      den<-if(cfg$weighted) W-sum(w^2)/W else n-1
      vari<-if(n>1 && den>0)sum(w*(x-m)^2)/den else NA_real_
      top<-if(form==4L) x==4 else if(v=="V3227") x==1 else x%in%c(4,5)
      stats[[v]][[year]]<-c(sample_meta(s),list(mean=m,SD=sqrt(vari),
        percentage_top=if(n)100*sum(w*top)/W else NA_real_,
        mean_variance=if(cfg$weighted)vari*sum(w^2)/W^2 else vari/n))
    }
    comparisons[[v]]<-list()
    for(pair in names(PAIRS)) {
      yy<-YEARS[PAIRS[[pair]]];a<-stats[[v]][[yy[1]]];b<-stats[[v]][[yy[2]]]
      delta<-b$mean-a$mean; out<-list(earlier=yy[1],later=yy[2],mean_difference=delta,
        percentage_difference=b$percentage_top-a$percentage_top)
      if(cfg$weighted) {
        z<-delta/sqrt(a$mean_variance+b$mean_variance)
        out$approximate_z<-list(z=z,p=2*pnorm(abs(z),lower.tail=FALSE))
      } else {
        df<-a$n+b$n-2;pool<-((a$n-1)*a$SD^2+(b$n-1)*b$SD^2)/df
        t<-delta/sqrt(pool*(1/a$n+1/b$n))
        va<-a$SD^2/a$n;vb<-b$SD^2/b$n;tw<-delta/sqrt(va+vb)
        dw<-(va+vb)^2/(va^2/(a$n-1)+vb^2/(b$n-1))
        out$Student<-list(t=t,df=df,p=2*pt(abs(t),df,lower.tail=FALSE))
        out$Welch<-list(t=tw,df=dw,p=2*pt(abs(tw),dw,lower.tail=FALSE))
      }
      comparisons[[v]][[pair]]<-out
    }
  }
  list(by_item_year=stats,comparisons=comparisons)
}
alpha_output <- function(files,factors,form,cfg,reverse=FALSE) {
  lapply(factors,function(its) setNames(lapply(YEARS,function(year) {
    s<-make_sample(files[[paste0("y",year,"_f",form)]],its,cfg$weighted,reverse=reverse)
    if(s$n<2L) return(c(sample_meta(s),list(status="failed",reason="Fewer than two complete records")))
    cv<-moments(s)$cov;k<-length(its)
    c(sample_meta(s),list(alpha=k/(k-1)*(1-sum(diag(cv))/sum(cv)),items=its))
  }),YEARS))
}
run_spec <- function(id,inputs,write=TRUE) {
  message("Running ",id)
  cfg<-config(id);files<-prepare_files(inputs,cfg)
  out<-list(spec_id=id,status="ok",reason=NULL,software=software(),rows_read_per_file=inputs$rows,
    deviations=list(),conventions=list(group_order=YEARS,pairs=lapply(PAIRS,function(p)YEARS[p]),
    difference="later minus earlier",sample_hash="SHA-256 of ascending numeric V4, canonical integer/17-significant-digit text, one ID per line including terminal LF",
    weight_normalization="Within each analysis sample, weights sum to nominal n",
    covariance_divisor=if(cfg$normal) "n" else "n-1",
    information=if(cfg$robust) "observed with Huber-White sandwich" else "expected",
    tolerance="nlminb rel.tol = 1e-10",unspecified_options="Resolved lavaan options are saved for each model",
    nonfinite_numbers="JSON null; associated fit warnings and availability reasons are retained"))
  if(cfg$weighted) out$invalid_weight_rows_dropped_per_file<-inputs$invalid_weights
  if(cfg$fiml) out$conventions$FIML<-paste("Raw-data normal likelihood; chi-square is the likelihood ratio to the unrestricted H1 model.",
    "SRMR uses lavaan's unrestricted H1 EM covariance on the same incomplete sample (default EM settings recorded).",
    "d_obs is unavailable where incomplete items make the specified observed mean score undefined.")
  full<-id%in%c("S00","S01","S03")
  if(full) out$item_statistics<-item_statistics(files,cfg)
  kk<-K
  if(id=="S07a") {kk$K6<-c("V4239","V4237");kk$K7<-c("V4241","V4247")}
  if(id=="S07b") {kk$K6<-c("V4239","V4247");kk$K7<-c("V4241","V4237")}
  cf<-C
  if(id=="S08") cf<-list(C1=c("V3224","V3225","V3222","V3223","V3226"))
  if(full || id%in%c("S07a","S07b","S08")) {
    out$single_group<-list();out$alpha<-list()
    kinds<-if(full)c("form3","form4_seven","form4_five") else if(id=="S08") "form3" else "form4_seven"
    for(kind in kinds) {
      factors<-switch(kind,form3=cf,form4_seven=kk,form4_five=K[1:5])
      form<-if(kind=="form3")3L else 4L
      out$single_group[[kind]]<-list()
      for(year in YEARS) {
        message("  ",kind," / ",year)
        s<-make_sample(files[[paste0("y",year,"_f",form)]],unlist(factors,use.names=FALSE),cfg$weighted,reverse=form==3L)
        ss<-setNames(list(s),year)
        r<-fit_model(ss,factors,"single",cfg)
        out$single_group[[kind]][[year]]<-model_output(r,ss,cfg)
      }
    }
    if(full || id%in%c("S07a","S07b"))
      out$alpha<-c(out$alpha,alpha_output(files,if(full)kk else kk[6:7],4L,cfg))
    if(full || id=="S08")out$alpha<-c(out$alpha,alpha_output(files,cf["C1"],3L,cfg,TRUE))
  }
  if(!(id%in%c("S07a","S07b","S08"))) {
    samples<-setNames(lapply(YEARS,function(year) make_sample(files[[paste0("y",year,"_f4")]],
      unlist(K[1:5],use.names=FALSE),cfg$weighted,cfg$fiml)),YEARS)
    out$multigroup<-list()
    for(m in if(cfg$check1) "M4" else paste0("M",1:5)) {
      message("  ",id," / ",m)
      r<-fit_model(samples,K[1:5],m,cfg)
      out$multigroup[[m]]<-model_output(r,samples,cfg)
      if(m=="M4" && !is.null(r$fit) && isTRUE(lavInspect(r$fit,"converged"))) {
        out$latent<-tryCatch(latent_outputs(r$fit,samples,cfg=cfg),error=function(e)list(status="failed",reason=conditionMessage(e)))
      }
    }
    if(!cfg$check1)out$model_differences<-model_differences(out$multigroup)
  }
  models<-c(unlist(out$single_group,recursive=FALSE),out$multigroup)
  bad<-names(Filter(function(m)identical(m$status,"failed"),models))
  if(length(bad)||identical(out$latent$status,"failed")) {
    out$status<-"failed";out$reason<-paste("Failed requested fit/output:",paste(c(bad,if(identical(out$latent$status,"failed"))"latent"),collapse=", "))
  } else if(cfg$fiml && any(vapply(unlist(out$latent$contrasts,recursive=FALSE),function(z)!is.null(z$d_obs_availability),logical(1)))) {
    out$status<-"unavailable";out$reason<-"FIML model outputs are provided; d_obs is unavailable for incomplete factor scores because no missing-score rule is specified."
    out$deviations<-list(list(quantity="S04 d_obs",status="unavailable",reason=out$reason))
  }
  if(write)write_json_full(out,file.path("results",paste0(id,".json")))
  out
}
influence <- function(inputs,start=1L,limit=1L,write=TRUE) {
  stopifnot(start>=1L,limit>=1L)
  cfg<-config("S00");files<-prepare_files(inputs,cfg)
  samples<-setNames(lapply(YEARS,function(y)make_sample(files[[paste0("y",y,"_f4")]],unlist(K[1:5],use.names=FALSE))),YEARS)
  full<-fit_model(samples,K[1:5],"M4",cfg)
  if(is.null(full$fit)||!isTRUE(lavInspect(full$fit,"converged"))) stop("Full-sample M4 failed: ",full$error)
  # Parameter table includes fitted values; lavaan uses its est column for start.
  warm<-parTable(full$fit)
  index<-do.call(rbind,lapply(seq_along(samples),function(g) {
    s<-samples[[g]];o<-order(s$ids)
    data.frame(group=g,row=o,V4=s$ids[o])
  }))
  if(start>nrow(index))stop("Influence start exceeds analysis sample size")
  end<-min(nrow(index),start+limit-1L)
  cn<-unlist(lapply(c("d_eq","p"),function(q)unlist(lapply(names(K)[1:5],function(f)paste(q,f,names(PAIRS),sep="_")))))
  rows<-list();times<-numeric();warnings<-list();deletion_samples<-list()
  for(idx in seq.int(start,end)) {
    t0<-proc.time()[["elapsed"]];ii<-index[idx,]; ss<-samples;s<-ss[[ii$group]]
    keep<-seq_len(s$n)!=ii$row;s$x<-s$x[keep,,drop=FALSE];s$ids<-s$ids[keep];s$w<-s$w[keep];s$n<-sum(keep)
    ss[[ii$group]]<-s
    row<-c(list(idx=idx,del_group=as.integer(YEARS[ii$group]),del_V4=ii$V4,status="failed",message=""),setNames(as.list(rep(NA_real_,length(cn))),cn))
    r<-fit_model(ss,K[1:5],"M4",cfg,start=warm)
    warnings[[as.character(idx)]]<-r$warnings
    if(is.null(r$fit)) row$message<-r$error else if(!isTRUE(lavInspect(r$fit,"converged"))) row$message<-"Optimizer did not converge" else {
      lat<-tryCatch(latent_outputs(r$fit,ss),error=function(e)e)
      if(inherits(lat,"error"))row$message<-conditionMessage(lat) else {
        row$status<-"ok";row$message<-paste(r$warnings,collapse=" | ")
        for(f in names(K)[1:5])for(p in names(PAIRS))for(q in c("d_eq","p"))row[[paste(q,f,p,sep="_")]]<-lat$contrasts[[f]][[p]][[q]]
      }
    }
    times<-c(times,proc.time()[["elapsed"]]-t0);rows[[length(rows)+1L]]<-as.data.frame(row,check.names=FALSE)
    deletion_samples[[as.character(idx)]]<-lapply(ss,sample_meta)
    message("Influence ",idx," / ",end,": ",row$status," (",tail(times,1)," s)")
  }
  tab<-do.call(rbind,rows)
  meta<-list(mode="influence",status=if(all(tab$status=="ok"))"ok" else "failed",software=software(),
    rows_read_per_file=inputs$rows,samples=lapply(samples,sample_meta),start=start,end=end,
    number_deletions=nrow(tab),seconds_per_deletion=times,mean_seconds_per_deletion=mean(times),
    full_sample_fit=model_output(full,samples,cfg),warnings=warnings,
    deletion_samples=deletion_samples,
    warm_start="Each deletion initialized from the full-sample M4 fitted parameter table",
    recomputation="Exact sample means and covariances recomputed after removing one row",
    timing="Wall time per deletion includes moment computation, fitting, and contrast extraction; excludes full fit, sample hashing, and disk output",
    deviations=list())
  if(write) {
    path<-file.path("results",paste0("influence_",start,"_",end))
    # Use 17 significant digits explicitly rather than write.csv's numeric formatting.
    txt<-lapply(tab,function(x)if(is.numeric(x))ifelse(is.na(x),NA_character_,sprintf("%.17g",x)) else x)
    write.table(as.data.frame(txt,check.names=FALSE),paste0(path,".csv"),sep=",",row.names=FALSE,na="",quote=TRUE)
    write_json_full(meta,paste0(path,".metadata.json"))
  }
  list(rows=tab,metadata=meta)
}
main <- function() {
  args<-commandArgs(trailingOnly=TRUE)
  if(!length(args)||"--help"%in%args) {
    cat("Usage:\n  Rscript code/analysis.R --test\n  Rscript code/analysis.R --spec S00|all|SPEC_ID\n  Rscript code/analysis.R --influence --start 1 --limit 2\n");return(invisible(NULL))
  }
  dir.create("results",showWarnings=FALSE)
  getarg<-function(name,default=NULL) {i<-match(name,args);if(is.na(i))default else {if(i==length(args))stop("Missing value for ",name);args[i+1L]}}
  if("--test"%in%args) {source("code/tests.R");run_tests();return(invisible(NULL))}
  if(!file.exists("code/TESTS.md") || !file.exists("code/test_results.json") ||
     !identical(fromJSON("code/test_results.json")$status,"ok"))
    stop("Run --test successfully and inspect code/TESTS.md before using supplied data")
  inputs<-load_inputs()
  if("--influence"%in%args) {
    influence(inputs,as.integer(getarg("--start","1")),as.integer(getarg("--limit","1")))
  } else {
    spec<-getarg("--spec");if(is.null(spec))stop("Expected --spec or --influence")
    ids<-if(spec=="all") SPECS else spec
    for(id in ids) {
      if(!id%in%SPECS)stop("Unknown specification: ",id)
      tryCatch(run_spec(id,inputs),error=function(e) {
        write_json_full(list(spec_id=id,status="failed",reason=conditionMessage(e),software=software(),
          rows_read_per_file=inputs$rows,deviations=list()),file.path("results",paste0(id,".json")))
        message(id,": ",conditionMessage(e))
      })
    }
  }
  invisible(NULL)
}
if(sys.nframe()==0L) main()
