# Synthetic-only verification. This file never reads data/ or dictionaries/.
synthetic_samples <- function() {
  set.seed(20261028)
  items<-unlist(K[1:5],use.names=FALSE);p<-length(items)
  lambda<-matrix(0,p,5,dimnames=list(items,names(K)[1:5]))
  for(f in names(K)[1:5])lambda[K[[f]],f]<-c(1,seq(.75,1.15,length.out=length(K[[f]])-1L))
  truth<-list(lambda=lambda,groups=list()); samples<-list()
  for(g in 1:3) {
    n<-c(900L,1100L,1300L)[g]
    psi<-matrix(.18,5,5);diag(psi)<-seq(.7,1.1,length.out=5)*(1+.1*(g-1))
    alpha<-seq(1.1,1.5,length.out=5)+(g-1)*seq(.12,.28,length.out=5)
    nu<-rep(.2,p);names(nu)<-items;nu[vapply(K[1:5],`[`,character(1),1)]<-0
    nu[RELEASED]<-nu[RELEASED]+(g-1)*.07
    Sigma<-lambda%*%psi%*%t(lambda)+diag(seq(.45,.8,length.out=p))
    mu<-as.numeric(nu+lambda%*%alpha)
    z<-matrix(rnorm(n*p),n,p);z<-scale(z,center=TRUE,scale=FALSE)
    x<-z%*%solve(chol(cov(z)))%*%chol(Sigma)
    x<-sweep(x,2,mu,"+");colnames(x)<-items
    samples[[YEARS[g]]]<-list(x=x,n=n,ids=seq_len(n),w=rep(1,n),weighted=FALSE)
    truth$groups[[g]]<-list(alpha=alpha,psi=psi,nu=nu,mean=mu,cov=Sigma)
  }
  list(samples=samples,truth=truth)
}
run_tests <- function() {
  checks<-list();check<-function(name,ok,details=NULL) {
    checks[[name]]<<-list(passed=isTRUE(ok),details=details)
    message(if(isTRUE(ok))"PASS " else "FAIL ",name)
  }
  check("Sample hash sorts IDs and has no terminal newline",
    identical(sha_ids(c(3,1,2)),"ad53e8806d17c82d38902738d1d47d96bddaade27513466322efa0f793149dd0"))
  check("Empty sample hash is SHA-256 of zero bytes",
    identical(sha_ids(numeric()),"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"))
  syn<-synthetic_samples();ss<-syn$samples;cfg<-config("S00")
  errs<-unlist(lapply(seq_along(ss),function(g) {
    mm<-moments(ss[[g]]);c(max(abs(mm$cov-syn$truth$groups[[g]]$cov)),max(abs(mm$mean-syn$truth$groups[[g]]$mean)))
  }))
  check("Synthetic moments equal known population moments",max(errs)<1e-12,max(errs))
  fits<-list();outs<-list();expected_df<-c(M1=426,M2=454,M3=482,M4=470,M5=480)
  for(m in names(expected_df)) {
    fits[[m]]<-fit_model(ss,K[1:5],m,cfg)
    outs[[m]]<-model_output(fits[[m]],ss,cfg)
    check(paste(m,"converges with expected df"),outs[[m]]$converged && identical(as.numeric(outs[[m]]$fit$df),as.numeric(expected_df[m])),
      list(df=outs[[m]]$fit$df,expected=expected_df[m],warnings=fits[[m]]$warnings,error=fits[[m]]$error))
  }
  fit<-fits$M4$fit
  if(!is.null(fit) && isTRUE(lavInspect(fit,"converged"))) {
    lat<-latent_outputs(fit,ss);pe<-parameterEstimates(fit)
    loaderr<-max(vapply(which(pe$op=="=~"),function(i)abs(pe$est[i]-syn$truth$lambda[pe$rhs[i],pe$lhs[i]]),numeric(1)))
    meanerr<-varerr<-interr<-0
    for(g in 1:3)for(k in 1:5) {
      a<-lat$means[[paste0("K",k)]][[YEARS[g]]]
      meanerr<-max(meanerr,abs(a$alpha-syn$truth$groups[[g]]$alpha[k]))
      varerr<-max(varerr,abs(a$psi-syn$truth$groups[[g]]$psi[k,k]))
    }
    for(i in which(pe$op=="~1" & pe$lhs%in%rownames(syn$truth$lambda)))
      interr<-max(interr,abs(pe$est[i]-syn$truth$groups[[pe$group[i]]]$nu[pe$lhs[i]]))
    check("M4 recovers known loadings intercepts latent means and variances",
      max(loaderr,meanerr,varerr,interr)<2e-4,list(loadings=loaderr,intercepts=interr,means=meanerr,variances=varerr))
    check("M4 zero population discrepancy and custom Wishart chi-square",
      abs(outs$M4$fit$chi_square)<1e-5 && abs(outs$M4$fit$chi_square-outs$M4$fit$lavaan_standard_chi_square)<1e-6,
      outs$M4$fit[c("chi_square","lavaan_standard_chi_square","SRMR")])
    derr<-0
    for(k in 1:5)for(pair in names(PAIRS)) {
      a<-PAIRS[[pair]][1];b<-PAIRS[[pair]][2]
      true_delta<-syn$truth$groups[[b]]$alpha[k]-syn$truth$groups[[a]]$alpha[k]
      true_d<-true_delta/sqrt(mean(c(syn$truth$groups[[a]]$psi[k,k],syn$truth$groups[[b]]$psi[k,k])))
      derr<-max(derr,abs(lat$contrasts[[paste0("K",k)]][[pair]]$d_eq-true_d))
    }
    check("All 15 standardized contrasts recover truth",derr<2e-4,derr)
    # Independently verify contrast SE using a numerical delta-method Jacobian.
    pt<-parTable(fit);vi<-vcov(fit);frees<-pt$free[pt$lhs=="K1" & pt$op=="~1"]
    fn<-function(x)x[frees[2]]-x[frees[1]]
    jac<-numDeriv::jacobian(fn,coef(fit));se<-sqrt(as.numeric(jac%*%vi%*%t(jac)))
    check("Contrast SE includes parameter covariance",abs(se-lat$contrasts$K1$P1$SE)<1e-9,
      list(numerical_delta_SE=se,reported_SE=lat$contrasts$K1$P1$SE,covariance=lat$contrasts$K1$P1$covariance_of_means))
    # Alternative identification must preserve standardized effects and likelihood.
    for(id in c("CHK1","CHK2","S05")) {
      cf<-config(id);r<-fit_model(ss,K[1:5],"M4",cf)
      mo<-model_output(r,ss,cf)
      check(paste(id,"M4 converges"),mo$converged,list(error=r$error,warnings=r$warnings,df=mo$fit$df))
      if(mo$converged) {
        ll<-latent_outputs(r$fit,ss,cfg=cf)
        if(id=="CHK1") {
          pp<-parTable(r$fit)
          refmean<-pp[pp$lhs%in%names(K)[1:5] & pp$op=="~1" & pp$group==1L,]
          refvar<-pp[pp$lhs%in%names(K)[1:5] & pp$op=="~~" & pp$lhs==pp$rhs & pp$group==1L,]
          check("CHK1 fixes all five 1976 means to zero and variances to one",
            nrow(refmean)==5L && nrow(refvar)==5L && all(refmean$free==0L) &&
              all(refmean$est==0) && all(refvar$free==0L) && all(refvar$est==1))
          check("CHK1 has M4 df 470 and the same likelihood",
            mo$fit$df==470 && abs(mo$fit$chi_square-outs$M4$fit$chi_square)<1e-5,
            list(df=mo$fit$df,chi_square_difference=mo$fit$chi_square-outs$M4$fit$chi_square))
          check("CHK1 has finite SEs and no identification warning",
            all(is.finite(vcov(r$fit))) && all(is.finite(unlist(lapply(ll$contrasts,function(x)lapply(x,`[[`,"SE"))))) &&
              !any(grepl("not.*identified|positive definite",r$warnings)),r$warnings)
        }
        dif<-max(abs(unlist(lapply(names(K)[1:5],function(f)vapply(names(PAIRS),function(p)ll$contrasts[[f]][[p]]$d_eq-lat$contrasts[[f]][[p]]$d_eq,numeric(1))))))
        if(id!="S05") check(paste(id,"identification invariant d_eq"),dif<2e-4,dif)
        if(id=="S05") {
          pp<-parameterEstimates(r$fit);ce<-0
          for(g in 1:3)for(f in names(K)[1:5]) {
            ce<-max(ce,abs(mean(pp$est[pp$op=="=~" & pp$lhs==f & pp$group==g])-1),
              abs(sum(pp$est[pp$op=="~1" & pp$lhs%in%K[[f]] & pp$group==g])))
          }
          check("S05 exact loading averages and intercept sums",ce<1e-7,ce)
        }
      }
    }
    # Exact deletion, full-fit warm start, and independent cold start agree.
    del<-ss;del[[1]]$x<-del[[1]]$x[-1,,drop=FALSE];del[[1]]$ids<-del[[1]]$ids[-1]
    del[[1]]$w<-del[[1]]$w[-1];del[[1]]$n<-del[[1]]$n-1
    warm<-fit_model(del,K[1:5],"M4",cfg,start=parTable(fit));cold<-fit_model(del,K[1:5],"M4",cfg)
    wd<-latent_outputs(warm$fit,del)$contrasts$K1$P1$d_eq
    cd<-latent_outputs(cold$fit,del)$contrasts$K1$P1$d_eq
    check("Warm-start deletion agrees with cold refit",abs(wd-cd)<1e-5,list(warm=wd,cold=cd))
  }
  # Weighted moments, missing-code logic, raw alpha and test formula fixtures.
  s<-list(x=matrix(c(1,2,4,3,2,5),3,2,dimnames=list(NULL,c("a","b"))),w=c(.5,1,1.5),n=3)
  mm<-moments(s);mu<-c(17/6,11/3)
  manual<-Reduce(`+`,lapply(1:3,function(i)s$w[i]*tcrossprod(s$x[i,]-mu)))/2
  check("S01 normalized weighted covariance divisor n-1",max(abs(mm$mean-mu),abs(mm$cov-manual))<1e-12)
  check("S02 covariance divisor n",max(abs(moments(s,TRUE)$cov-mm$cov*2/3))<1e-12)
  dict<-list(variables=list(list(name="V5",declared_missing_values=list(0,7),declared_missing_range=list(9,"HIGHEST"))))
  check("Weight validity includes dictionary missing codes",identical(weight_valid(c(-1,0,1,7,8,9,NA,Inf),dict),c(FALSE,FALSE,TRUE,FALSE,TRUE,FALSE,FALSE,FALSE)))
  # MLR is fitted from raw observations, not covariance-only input.
  for(id in c("S02","S06","S04")) {
    cf<-config(id);ss2<-ss
    if(id=="S04") {
      set.seed(9)
      for(g in 1:3) {
        ss2[[g]]$x[matrix(runif(length(ss2[[g]]$x))<.06,nrow(ss2[[g]]$x))]<-NA_real_
        ss2[[g]]$x[1,K$K1]<-NA_real_
      }
    }
    r<-fit_model(ss2,K[1:5],"M4",cf);mo<-model_output(r,ss2,cf)
    check(paste(id,"M4 supported and converges"),mo$converged && identical(mo$status,"ok"),list(error=r$error,warnings=r$warnings,fit=mo$fit))
    if(id=="S04" && mo$converged) {
      ll<-latent_outputs(r$fit,ss2,cfg=cf);h1<-lavInspect(r$fit,"sampstat")
      err<-0
      for(f in names(K)[1:5])for(pair in names(PAIRS)) {
        vv<-vapply(PAIRS[[pair]],function(g) {
          w<-setNames(rep(0,ncol(ss2[[g]]$x)),colnames(ss2[[g]]$x))
          w[K[[f]]]<-1/length(K[[f]])
          S<-h1[[g]]$cov[names(w),names(w)]
          as.numeric(t(w)%*%S%*%w)*ss2[[g]]$n/(ss2[[g]]$n-1)
        },numeric(1))
        cc<-ll$contrasts[[f]][[pair]]
        err<-max(err,abs(cc$d_obs-cc$Delta/sqrt(mean(vv))))
      }
      check("S04 all 15 d_obs use full-sample H1 unit-weighted score variances",
        is.finite(err) && err<1e-12 && identical(as.numeric(lavInspect(r$fit,"nobs")),vapply(ss2,`[[`,numeric(1),"n") |> unname()),err)
      complete_fit<-fit_model(ss,K[1:5],"M4",cf)
      cl<-latent_outputs(complete_fit$fit,ss,cfg=cf)
      err<-max(vapply(names(K)[1:5],function(f)max(vapply(names(PAIRS),function(pair) {
        vv<-vapply(PAIRS[[pair]],function(g)var(rowMeans(ss[[g]]$x[,K[[f]],drop=FALSE])),numeric(1))
        abs(cl$contrasts[[f]][[pair]]$d_obs-cl$contrasts[[f]][[pair]]$Delta/sqrt(mean(vv)))
      },numeric(1))),numeric(1)))
      check("S04 complete-data d_obs agrees with empirical n-1 score SD",err<1e-10,err)
    }
    if(id=="S06" && mo$converged) {
      check("S06 reports finite sandwich SE and scaled statistic",is.finite(latent_outputs(r$fit,ss2,cfg=cf)$contrasts$K1$P1$SE) && is.finite(mo$fit$scaled_chi_square$chi_square))
      check("S06 raw-data normalization agrees with explicit divisor-n discrepancy",
        abs(mo$fit$chi_square-mo$fit$lavaan_standard_chi_square)<1e-6 && abs(mo$fit$chi_square)<1e-5,
        mo$fit[c("chi_square","lavaan_standard_chi_square")])
    }
  }
  ok<-all(vapply(checks,`[[`,logical(1),"passed"))
  result<-list(status=if(ok)"ok" else "failed",synthetic_only=TRUE,seed=20261028,
    design="Three groups of 900, 1100, 1300 observations; five correlated factors, 19 indicators; known unequal latent means/variances, invariant loadings, six noninvariant intercepts. Gaussian draws whitened to exact known means/covariances.",
    checks=checks,software=software())
  write_json_full(result,"code/test_results.json")
  lines<-c("# Synthetic estimation tests","",paste("Result:",if(ok)"PASS" else "FAIL"),"",
    "The initial synthetic suite passed and was recorded before opening any supplied survey CSV. The suite was subsequently rerun after correcting raw-data MLR normalization and again for repair round 1. Repair regression checks cover CHK1 fixed parameters and df, S04 observed-score standardization with incomplete data, and newline-free sample hashes. No data/ or dictionaries/ input is used by the test suite.","",
    result$design,"","Run with `/opt/homebrew/bin/Rscript code/analysis.R --test`.","",
    vapply(names(checks),function(n)paste0("- ",if(checks[[n]]$passed)"PASS" else "FAIL",": ",n),character(1)),"",
    "Exact numerical test details and software versions are in `code/test_results.json`.","",
    "S05 is tested against its literal sum constraints; those constraints can change partial-invariance restrictions, so equivalence to marker identification is not assumed.","",
    "## Session information","","```",capture.output(sessionInfo()),"```")
  writeLines(lines,"code/TESTS.md")
  if(!ok)stop("Synthetic tests failed; see code/test_results.json")
  invisible(result)
}
