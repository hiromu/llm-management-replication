# Amendment C1-C8 regressions; invoked by test_analysis.R, synthetic inputs only.
local({
  records<-CJ(RSSD9425=c(0:18,NA_real_),RSSD9048=c(200,300),
              RSSD9331=c(1,2,NA_real_),CALL8786=c(1,2,3))
  records[,`:=`(RSSD9001=.I,year=1985L,q=4L,quarter='1985Q4')]
  for(origin in names(grid$origins)) {
    oc<-grid$origins[[origin]]; cc<-oc; cc$R02<-'R02.no_special'; lg<-new_log()
    expected<-records[RSSD9048==200 & CALL8786 %in% c(1,2) &
      (oc$R02!='R02.charter_entity' | (!is.na(RSSD9331) & RSSD9331==1)) &
      !RSSD9425 %in% c(1,2,4,9)]
    actual<-filter_records(list(call=records),cc,oc,lg)
    check(paste(origin,'special exclusion uses exactly codes 1, 2, 4, 9 and preserves origin filters'),
      setequal(actual$RSSD9001,expected$RSSD9001) && any(is.na(actual$RSSD9425)))
    check(paste(origin,'special exclusions are counted'),
      sum(freeze_log(lg)$counts[reason=='special_purpose_bank']$count)>0)
    cc$R02<-'R02.add_savings'; fixture<-synthetic_inputs(); lg<-new_log()
    filter_records(fixture,cc,oc,lg)
    entry<-Filter(function(x) x$type=='savings_admission',lg$special)[[1]]$detail
    check(paste(origin,'zero qualifying savings is logged and still constructs'),
      entry$qualifying_records==0 && grepl('No savings records qualify',entry$message) &&
      nrow(construct_sample(fixture,cc,oc)$sample)>0)
  }
})
local({
  # Both origins, every coverage level, 0 through 4 observed quarters.
  for(origin in names(grid$origins)) for(coverage in c('R05.min2_fallback','R05.all4','R05.any')) {
    oc<-grid$origins[[origin]]; cc<-oc; cc$R06<-'R06.rck_days'; cc$R05<-coverage
    fixture<-synthetic_inputs()
    fixture$call[year==1988 & RSSD9001 %in% 101:105,
      `:=`(RCFD3368=ifelse(q<=RSSD9001-101,100*q,NA_real_),
           RCON3368=ifelse(q<=RSSD9001-101,100*q,NA_real_))]
    a<-construct_annual(fixture,cc,oc,new_log())
    check(paste(origin,coverage,'day weighting rejects zero to three quarters without asset fallback'),
      all(is.na(a[year==1988 & RSSD9001 %in% 101:104]$AA)) &&
      close(a[year==1988 & RSSD9001==105]$AA,weighted.mean(100*(1:4),c(91,91,92,92))))
    fixture$call[RSSD9001==105 & year==1988 & q==2,RCFD3368:=NA_real_]
    a<-construct_annual(fixture,cc,oc,new_log())
    check(paste(origin,coverage,'day weighting uses RCON fallback per quarter'),
      close(a[year==1988 & RSSD9001==105]$AA,weighted.mean(100*(1:4),c(91,91,92,92))))
  }
  fixture<-synthetic_inputs(); cc<-cfg; cc$R06<-'R06.rck_days'
  fixture$call<-fixture$call[!(RSSD9001==101 & year==1985 & q==2)]
  a<-construct_annual(fixture,cc,cfg,new_log())
  check('day weighting rejects a missing quarterly record',is.na(a[RSSD9001==101 & year==1985]$AA))
  fixture$call[RSSD9001==102 & year==1985,RCFD3368:=q*100]
  a<-construct_annual(fixture,cc,cfg,new_log())
  check('day weighting uses non-leap quarter lengths',
    close(a[RSSD9001==102 & year==1985]$AA,weighted.mean(100*(1:4),c(90,91,92,92))))
})
local({
  # An excluded 1985 row must not contribute its 1984 bank-year to references.
  fixture<-synthetic_inputs()
  fixture$call[RSSD9001==101 & year==1985 & q==4,RIAD4340:=NA_real_]
  for(origin in names(grid$origins)) {
    oc<-grid$origins[[origin]]; cc<-oc; cc$R09<-'R09.analytic'
    first<-construct_sample(fixture,oc)$sample
    annual<-construct_annual(fixture,oc,oc,new_log())
    rebuilt<-construct_sample(fixture,cc,oc)
    support<-annual[year==1984 & RSSD9001 %in% first[year==1985]$RSSD9001]
    ref85<-annual[key(RSSD9001,year) %in% key(first$RSSD9001,first$year) & year==1985]
    expected_growth<-100*((sum(ref85$DEP)/1.03)/sum(support$DEP)-1)
    row<-rebuilt$sample[RSSD9001==102 & year==1985]
    prior<-support[RSSD9001==102]
    check(paste(origin,'analytic 1984 lag and growth references use only first-pass 1985 lag suppliers'),
      !101 %in% support$RSSD9001 && close(row$lag,100*(prior$ROA-mean(support$ROA))) &&
      close(row$RMG,expected_growth))
    check(paste(origin,'analytic sample never admits new rows'),
      all(key(rebuilt$sample$RSSD9001,rebuilt$sample$year) %in% key(first$RSSD9001,first$year)))
  }
  # One first-pass 1986 row gives undefined sample SDs on rebuilding, then drops.
  fixture<-synthetic_inputs()
  fixture$call[year==1986 & RSSD9001!=101 & q==4,RIAD4340:=NA_real_]
  first<-construct_sample(fixture,cfg)$sample
  cc<-cfg; cc$R09<-'R09.analytic'; rebuilt<-construct_sample(fixture,cc,cfg)
  drops<-rebuilt$log$counts[reason=='analytic_rebuilt_undefined' & disposition=='dropped']
  check('analytic undefined rebuilt rows drop and are counted without aborting construction',
    nrow(first[year==1986])==1 && nrow(rebuilt$sample)>0 && !any(rebuilt$sample$year==1986) &&
    sum(drops$count)==nrow(first)-nrow(rebuilt$sample))
  check('analytic surviving sample fits successfully',fit_model(rebuilt$sample,'M3',cc)$n==nrow(rebuilt$sample))
  # Missing 1986 must not use 1985 as the lag or market-growth base for 1987.
  annual<-construct_annual(synthetic_inputs(),cfg,cfg,new_log())[year!=1986]
  derived<-benchmarks(annual,synthetic_inputs(),cfg,new_log())
  check('market growth and bank lags do not skip a missing calendar year',
    all(is.na(derived[year==1987]$RMG)) && all(is.na(derived[year==1987]$lag)) &&
    all(is.finite(derived[year==1988]$RMG)))
})
check('missing-input conditions and runtime errors have distinct statuses',
  error_status(tryCatch(unavailable('Missing supplied input'),error=identity))=='unavailable' &&
  error_status(tryCatch(stop('Runtime failure'),error=identity))=='failed')
local({
  # Exercise emitted statuses through the runner without fitting real inputs.
  test_dir<-tempfile('status_cases_',tmpdir='tests'); dir.create(test_dir)
  on.exit(unlink(test_dir,recursive=TRUE))
  small_grid<-grid; small_grid$origins<-list(O_A=cfg); small_grid$axes<-list()
  grid_path<-file.path(test_dir,'grid.json'); jsonlite::write_json(small_grid,grid_path,auto_unbox=TRUE)
  for(stage in c('construction','fit')) for(status in c('unavailable','failed')) {
    env<-new.env(parent=globalenv())
    env$load_inputs<-function(...) synthetic_inputs()
    problem<-if(status=='unavailable') function(...) unavailable('Synthetic missing input') else function(...) stop('Synthetic runtime error')
    assign(if(stage=='construction') 'construct_sample' else 'fit_model',problem,envir=env)
    env$run_influence<-function(...) invisible(NULL)
    runner<-run_analysis; environment(runner)<-env
    out<-file.path(test_dir,paste(stage,status,sep='_'))
    invisible(capture.output(runner(grid_path=grid_path,outdir=out)))
    emitted<-fread(file.path(out,'spec_results.csv'))
    check(paste(stage,status,'condition emits correct status for every model'),all(emitted$status==status))
  }
})
