# Invoked from test_analysis.R: uses its check(), close(), cfg and synthetic z.
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
