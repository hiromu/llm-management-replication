synthetic_inputs <- function() {
  set.seed(9217)
  q<-CJ(RSSD9001=101:116,year=1983:1992,q=1:4)[year>1983 | q==4]
  q[,quarter:=paste0(year,'Q',q)]
  q[,`:=`(DATE=as.numeric(format(as.Date(sprintf('%d-%02d-01',year+(q==4),ifelse(q==4,1,3*q+1)))-1,'%Y%m%d')),
    CALL8786=1,RSSD9048=200,RSSD9331=1,RSSD9425=0,RSSD9050=RSSD9001,
    RSSD9210=27,RSSD9150=3,RSSD9180=5120,county_fips5='27003')]
  q[,RCFD2170:=runif(.N,800,1800)*(1+.035*(year-1983))]
  q[,RCFD3368:=RCFD2170*runif(.N,.92,1.03)]
  codes<-c('1766','1600','1410','1975','1590','0010','1350','0390','2146','2145',
    '2150','2130','2155','2143','2160','2123','3123','2165','1505','1517','1510','1545','2107','2081','1563','2080',
    '0081','0071','1755','1763','1764','1420')
  for(code in codes) q[,(paste0('RCFD',code)):=RCFD2170*runif(.N,.002,.06)]
  q[,RCFD1400:=RCFD1766+RCFD1410+RCFD1975+RCFD1590+RCFD2170*.15]
  q[,`:=`(RCFD2200=RCFD2170*runif(.N,.5,.85),RIAD4340=RCFD3368*runif(.N,-.015,.025)*q/4,
            RIAD4073=RCFD3368*runif(.N,.02,.06)*q/4,RIAD4093=RCFD3368*runif(.N,.01,.04)*q/4)]
  q[,RIAD4300:=RIAD4340+RCFD3368*.001]
  for(nm in names(q)[startsWith(names(q),'RCFD')]) q[,(sub('RCFD','RCON',nm)):=get(nm)]
  p<-CJ(item=names(q)[grepl('^(RCFD|RCON)',names(q))],quarter=unique(q$quarter))
  p[,`:=`(in_file=1,any_nonmissing_mnwi=1)]
  inst<-data.table(CERT=101:116,opening=as.Date('1970-01-01'),ESTYMD='01/01/1970')
  events<-data.table(year=c(1987L,1989L),CERT=c(101,102),ACQ_CERT=c(101,NA_real_),OUT_CERT=c(103,NA_real_),
    SUR_CERT=c(101,NA_real_),FRM_CERT=c(NA_real_,102),CHANGECODE_DESC=c('Merger -Without Assistance','Change in Chartering Agency'))
  fin<-q[q==4 & year>=1984,.(CERT=RSSD9050,year,month=12L,STALP='MN',STCNTY='Anoka',DEP=RCFD2200,ROA=100*RIAD4340/RCFD3368)]
  series<-list(c('FRED','CPIAUCNS','CPIAUCNS_annual_avg','current','01'),
    c('FRED','CPIAUCNS','CPIAUCNS_native','current','12'),c('FRED','CUUSA211SA0','local_native','current','01'),
    c('FRED','A191RD3A086NBEA','gdp_native','current','01'),c('ALFRED','GDPDEF','historical','1999-01-01','01'))
  price<-rbindlist(lapply(series,function(s) {
    x<-data.table(year=1984:1992,provider=s[1],series_id=s[2],source_file=s[3],vintage=s[4])
    x[,`:=`(date=sprintf('%d-%s-01',year,s[5]),value=100*1.03^(year-1984))]
    if(s[1]=='ALFRED') x<-rbindlist(lapply(c('01','04','07','10'),function(m) {a<-copy(x);a[,date:=sprintf('%d-%s-01',year,m)];a}))
    x
  }))
  list(call=q,presence=p,institutions=inst,events=events,financials=fin,deflators=price,
    msa=data.table(area_code=5120,state_fips='27',county_fips5='27003',vintage_date=as.Date('1983-06-27')),
    counties=data.table(state_abbr='MN',county_name='Anoka County',county_fips5='27003'),
    candidates=jsonlite::fromJSON('docs/call_item_candidates.json',simplifyVector=FALSE))
}
