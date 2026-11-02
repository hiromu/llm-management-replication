# Invoked from test_analysis.R: uses its check(), close(), cfg and synthetic z.
# Exercise the actual Parquet loader with exactly the seven manifest inputs.
local({
  input_dir<-tempfile('seven_inputs_',tmpdir='tests'); dir.create(input_dir)
  on.exit(unlink(input_dir,recursive=TRUE))
  fixture<-synthetic_inputs()
  fixture$events[,EFFDATE:=sprintf('%d-06-01',year)]
  fixture$financials[,REPDTE:=sprintf('%d-12-31',year)]
  fixture$msa[,omb_definition_date:=as.character(vintage_date)]
  files<-c(call='call_mnwi_core_1983q4_1993q4',presence='call_item_presence_by_quarter',
    institutions='fdic_institutions_mnwi_and_linked',events='fdic_structure_events_mnwi_1983_1994',
    financials='fdic_financials_core_mnwi_1984q1_1994q4',deflators='deflators_long',
    msa='msa_minneapolis_stpaul_counties_by_vintage')
  for(nm in names(files)) nanoparquet::write_parquet(fixture[[nm]],file.path(input_dir,paste0(files[[nm]],'.parquet')))
  loaded<-load_inputs(input_dir)
  check('seven manifest Parquet inputs load without the optional county crosswalk',is.null(loaded$counties))
  for(origin in names(grid$origins))
    check(paste(origin,'constructs without the optional county crosswalk'),nrow(construct_sample(loaded,grid$origins[[origin]])$sample)>0)
  for(axis in c('R19','R21')) {
    cc<-cfg; cc[[axis]]<-paste0(axis,'.all_insured')
    check(paste(axis,'county-name mapping without crosswalk is unavailable'),
      inherits(tryCatch(construct_sample(loaded,cc,cfg),error=identity),'unavailable'))
  }
  loaded$financials[,STCNTY:='27003']
  check('numeric FDIC county codes work without crosswalk',
    close(insured_deposits(loaded,cfg,new_log())$D_insured,fixture$financials[,sum(DEP),by=year]$V1))
  nanoparquet::write_parquet(fixture$counties,file.path(input_dir,'county_fips_mn_wi.parquet'))
  loaded<-load_inputs(input_dir)
  check('optional crosswalk still resolves FDIC county names',
    close(insured_deposits(loaded,cfg,new_log())$D_insured,fixture$financials[,sum(DEP),by=year]$V1))
})
# Savings admission expands charter codes while preserving entity/reporting rules.
record_cases<-CJ(RSSD9048=c(200,300,400),RSSD9331=c(1,2,NA_real_),CALL8786=c(1,2,3))
record_cases[,`:=`(RSSD9001=.I,year=1985L,q=4L,quarter='1985Q4')]
for(origin in names(grid$origins)) {
  oc<-grid$origins[[origin]]; cc<-oc; cc$R02<-'R02.add_savings'
  expected<-record_cases[RSSD9048 %in% c(200,300) & CALL8786 %in% c(1,2) &
    (oc$R02!='R02.charter_entity' | (!is.na(RSSD9331) & RSSD9331==1))]$RSSD9001
  actual<-filter_records(list(call=record_cases),cc,oc,new_log())$RSSD9001
  check(paste(origin,'savings admission preserves all other base filters'),setequal(actual,expected))
}
# Distinguish domestic and consolidated deposits so a scope override cannot hide.
local({
  fixture<-synthetic_inputs(); fixture$call[,RCON2200:=RCFD2200*.7]
  oc<-grid$origins$O_B
  for(timing in c('R08.year_end','R08.mean_of_quarter_shares','R08.ratio_of_means')) {
    cc<-oc; cc$R08<-timing; cc$R16<-'R16.domestic'
    domestic_assets<-construct_annual(fixture,cc,oc,new_log())
    cc$R16<-'R16.consolidated'
    consolidated_assets<-construct_annual(fixture,cc,oc,new_log())
    check(paste(timing,'R16 leaves consolidated deposits unchanged'),close(domestic_assets$DEP,consolidated_assets$DEP))
    cc$R18<-'R18.domestic'
    domestic_deposits<-construct_annual(fixture,cc,oc,new_log())
    check(paste(timing,'R18 alone selects domestic deposits'),close(domestic_deposits$DEP,.7*consolidated_assets$DEP))
  }
})
mini<-data.table(RSSD9001=c(1,2,3),year=1985L,quarter='1985Q4',
  RCFD0010=c(NA,NA,7),RCFD0081=c(2,NA,3),RCFD0071=c(3,4,4))
zz<-list(presence=data.table(item='RCFD0010',quarter='1985Q4',in_file=0,any_nonmissing_mnwi=0))
resolver<-resolve_items(mini,zz,cfg,new_log())
check('not-collected missing component becomes zero, observed value retained',close(resolver('0010'),c(0,0,7)))
zz$presence[,`:=`(in_file=1,any_nonmissing_mnwi=1)]
resolver<-resolve_items(mini,zz,cfg,new_log())
check('collected component missing for individual bank stays missing',all(is.na(resolver('0010')[1:2])))
icfg<-cfg; icfg$R15<-'R15.identity_fill'
resolver<-resolve_items(mini,zz,icfg,new_log())
check('exact identity fills only from complete component set',close(resolver('0010'),c(5,NA_real_,7)))
check('uncollected denominator is never imputed to zero',all(is.na(resolve_items(mini,zz,cfg,new_log())('2170',component=FALSE))))
const<-matrix(1,3,11); const[1,1]<-NA_real_
check('zero SD does not hide a missing bank share',is.na(strategic_deviation(const)$SD[1]))
# Quarter coverage: one observed 3368 cannot trigger the zero-available fallback.
zc<-synthetic_inputs(); mask<-zc$call$RSSD9001==101 & zc$call$year==1985 & zc$call$q!=4
zc$call[mask,`:=`(RCFD3368=NA_real_,RCON3368=NA_real_)]
a<-construct_annual(zc,cfg,cfg,new_log())
check('min-two rule rejects exactly one average-assets quarter',is.na(a[RSSD9001==101 & year==1985]$AA))
cc<-cfg; cc$R05<-'R05.any'; a<-construct_annual(zc,cc,cfg,new_log())
check('any-quarter rule accepts one average-assets quarter',close(a[RSSD9001==101 & year==1985]$AA,zc$call[RSSD9001==101 & year==1985 & q==4]$RCFD3368))
zc$call[RSSD9001==101 & year==1985,`:=`(RCFD3368=NA_real_,RCON3368=NA_real_)]
a<-construct_annual(zc,cfg,cfg,new_log())
expected<-zc$call[RSSD9001==101 & (year==1985 | year==1984 & q==4)]$RCFD2170
check('zero available averages trigger available five-point fallback',close(a[RSSD9001==101 & year==1985]$AA,mean(expected)))
cc<-cfg; cc$R06<-'R06.five_point'; a<-construct_annual(zc,cc,cfg,new_log())
check('explicit five-point assets use all five endpoints',close(a[RSSD9001==101 & year==1985]$AA,mean(expected)))
zc$call<-zc$call[!(RSSD9001==101 & year==1985 & q==2)]
a<-construct_annual(zc,cc,cfg,new_log())
check('explicit five-point assets reject a missing endpoint',is.na(a[RSSD9001==101 & year==1985]$AA))
# Duplicate selection must keep reporting level 1 even if level 2 comes first.
zc<-synthetic_inputs(); dupe<-copy(zc$call[RSSD9001==101 & year==1985 & q==4]);dupe[,`:=`(CALL8786=2,RIAD4340=999)]
zc$call<-rbind(dupe,zc$call); lg<-new_log(); filtered<-filter_records(zc,cfg,cfg,lg)
check('duplicate bank-quarter selects reporting level 1',filtered[RSSD9001==101 & year==1985 & q==4]$CALL8786==1)
check('duplicate handling is counted and logged',any(vapply(lg$special,function(x) x$type=='duplicate_records',logical(1))))
# Hand-made merger/continuation lag cases with known pre-event ROAs.
panel<-data.table(RSSD9001=c(1,2,1,4),RSSD9050=c(11,22,11,22),year=c(1984L,1984L,1985L,1985L),
  y=c(1,3,5,7),mean_ROA=.01,NI=c(2,6,8,9),AA=c(100,200,300,400))
zlink<-list(events=data.table(year=c(1985L,1985L),CERT=c(11,22),ACQ_CERT=c(11,NA_real_),
  OUT_CERT=c(22,NA_real_),SUR_CERT=c(11,NA_real_),FRM_CERT=c(NA_real_,22),
  CHANGECODE_DESC=c('Merger -Without Assistance','Change in Legal Name')))
cc<-cfg; cc$R03<-'R03.continuity'; a<-apply_continuity(copy(panel),panel,zlink,cc,new_log())
check('pure same-CERT legal continuation gets predecessor lag',close(a[RSSD9001==4]$lag,3))
cc$R03<-'R03.proforma'; a<-apply_continuity(copy(panel),panel,zlink,cc,new_log())
check('proforma lag sums survivor and absorbed predecessor NI and AA',close(a[RSSD9001==1 & year==1985]$lag,100*(8/300-.01)))
# Named outlier survives in 1988 lag unless the suppression rule is requested.
zc<-synthetic_inputs(); zc$call[RSSD9001==101,RSSD9001:=995151]
b0<-construct_sample(zc,cfg)$sample
cc<-cfg; cc$R10<-'R10.none'; bn<-construct_sample(zc,cc,cfg)$sample
check('named outlier deleted only after variables built',!any(b0$RSSD9001==995151 & b0$year==1987) && any(bn$RSSD9001==995151 & bn$year==1987))
check('named outlier still supplies next-year lag',close(b0[RSSD9001==995151 & year==1988]$lag,bn[RSSD9001==995151 & year==1987]$y))
cc$R10<-'R10.suppress_lag'; bs<-construct_sample(zc,cc,cfg)$sample
check('suppress-lag rule removes 1988 row too',!any(bs$RSSD9001==995151 & bs$year==1988))
cc$R10<-'R10.before_benchmarks'; bb<-construct_sample(zc,cc,cfg)$sample
check('pre-benchmark deletion also removes next-year lag',!any(bb$RSSD9001==995151 & bb$year %in% c(1987,1988)))
# Calendar-day weighting and each stock timing choice against direct values.
zc<-synthetic_inputs(); cc<-cfg; cc$R06<-'R06.rck_days'
a<-construct_annual(zc,cc,cfg,new_log()); q<-zc$call[RSSD9001==101 & year==1988]
check('day-weighted average assets handles leap year',close(a[RSSD9001==101 & year==1988]$AA,weighted.mean(q$RCFD3368,c(91,91,92,92))))
cc<-cfg; cc$R08<-'R08.mean_of_quarter_shares'; a<-construct_annual(zc,cc,cfg,new_log())
check('mean of quarterly shares and deposits uses quarterly values',close(a[RSSD9001==101 & year==1988]$a1,mean(q$RCFD1766/q$RCFD2170)) && close(a[RSSD9001==101 & year==1988]$DEP,mean(q$RCON2200)))
cc$R08<-'R08.ratio_of_means'; a<-construct_annual(zc,cc,cfg,new_log())
check('ratio-of-means differs from mean of shares as specified',close(a[RSSD9001==101 & year==1988]$a1,mean(q$RCFD1766)/mean(q$RCFD2170)))
