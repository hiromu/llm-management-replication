#!/opt/homebrew/bin/Rscript
# Offline, parameterised implementation of manifest.md and grid.json.
# Sourcing defines functions only. --construct-only cannot enter model fitting.
suppressPackageStartupMessages(library(data.table))
options(stringsAsFactors = FALSE)
`%||%` <- function(x, y) if (is.null(x)) y else x
mean_ok <- function(x) if (any(is.finite(x))) mean(x[is.finite(x)]) else NA_real_
sum_ok <- function(x) if (any(is.finite(x))) sum(x[is.finite(x)]) else NA_real_
key <- function(id, year) paste(id, year, sep = ',')
unavailable <- function(message) stop(structure(list(message = message, call = NULL),
                                              class = c('unavailable', 'error', 'condition')))
error_status <- function(e) {
  if (inherits(e, 'not_applicable')) 'not_applicable' else if (inherits(e, 'unavailable')) 'unavailable' else 'failed'
}
sample_hash <- function(d) {
  # Lexically sort the complete integer lines, with a final LF, no header.
  lines <- sort(sprintf('%.0f,%d', d$RSSD9001, as.integer(d$year)), method = 'radix')
  digest::digest(paste0(if (length(lines)) paste0(lines, '\n') else '', collapse = ''),
                 algo = 'sha256', serialize = FALSE)
}
parse_date <- function(x) {
  x <- as.character(x); ans <- as.Date(rep(NA_character_, length(x)))
  iso <- grepl('^\\d{4}-', x); us <- grepl('/', x); compact <- grepl('^\\d{8}$', x)
  ans[iso] <- as.Date(substr(x[iso], 1, 10), '%Y-%m-%d')
  ans[us] <- as.Date(x[us], '%m/%d/%Y')
  ans[compact] <- as.Date(x[compact], '%Y%m%d'); ans
}
load_inputs <- function(data_dir = 'data') {
  files <- c(call = 'call_mnwi_core_1983q4_1993q4', presence = 'call_item_presence_by_quarter',
    institutions = 'fdic_institutions_mnwi_and_linked', events = 'fdic_structure_events_mnwi_1983_1994',
    financials = 'fdic_financials_core_mnwi_1984q1_1994q4', deflators = 'deflators_long',
    msa = 'msa_minneapolis_stpaul_counties_by_vintage')
  z <- lapply(files, function(f) as.data.table(nanoparquet::read_parquet(file.path(data_dir,paste0(f,'.parquet')))))
  county_path <- file.path(data_dir,'county_fips_mn_wi.parquet')
  if (file.exists(county_path)) z$counties <- as.data.table(nanoparquet::read_parquet(county_path))
  z$call[, `:=`(year = as.integer(substr(quarter,1,4)), q = as.integer(substr(quarter,6,6)))]
  z$call[, county_fips5 := sprintf('%02d%03d', as.integer(RSSD9210), as.integer(RSSD9150))]
  z$financials[, date := parse_date(REPDTE)]
  z$financials[, `:=`(year = as.integer(format(date,'%Y')), month = as.integer(format(date,'%m')))]
  z$events[, year := as.integer(format(parse_date(EFFDATE),'%Y'))]
  z$institutions[, opening := parse_date(ESTYMD)]
  z$msa[, vintage_date := parse_date(omb_definition_date)]
  z$deflators[, year := as.integer(substr(date,1,4))]
  z$candidates <- jsonlite::fromJSON('docs/call_item_candidates.json', simplifyVector = FALSE)
  z
}
new_log <- function() {
  e <- new.env(parent = emptyenv()); e$counts <- list(); e$special <- list(); e
}
log_count <- function(log, step, reason, d, kept = TRUE, unit = 'bank_year') {
  if (!nrow(d)) return(invisible(NULL))
  cnt <- d[, .(count = .N), by = year]
  cnt[, `:=`(step = step, reason = reason, disposition = if (kept) 'kept' else 'dropped', unit = unit)]
  log$counts[[length(log$counts)+1L]] <- cnt
}
log_special <- function(log, type, detail) {
  log$special[[length(log$special)+1L]] <- list(type = type, detail = detail)
}
freeze_log <- function(log) list(counts = rbindlist(log$counts, fill=TRUE), special = log$special)
market_counties <- function(z, cfg, yr) {
  m <- z$msa[as.character(area_code) == '5120']
  vintage <- as.Date('1983-06-27')
  if (cfg$R01 == 'R01.dynamic') vintage <- max(m$vintage_date[m$vintage_date <= as.Date(sprintf('%d-12-31',yr))])
  m <- m[vintage_date == vintage]
  if (cfg$R01 == 'R01.mnonly') m <- m[as.integer(state_fips) == 27L]
  if (!nrow(m)) unavailable(paste('No county definition for', yr))
  sprintf('%05d', as.integer(m$county_fips5))
}
filter_records <- function(z, cfg, origin_cfg, log) {
  d <- copy(z$call); log_count(log,'S1','input',d,unit='record')
  rule <- cfg$R02
  base_rule <- if (rule %in% c('R02.add_savings','R02.no_special')) origin_cfg$R02 else rule
  reporting <- d$CALL8786 %in% c(1,2)
  charters <- if (rule == 'R02.add_savings') c(200,300) else 200
  eligible <- switch(base_rule,
    R02.charter_entity = d$RSSD9048 %in% charters & d$RSSD9331 == 1,
    R02.charter = d$RSSD9048 %in% charters, R02.entity = d$RSSD9331 == 1,
    stop('Unknown record filter'))
  eligible[is.na(eligible)] <- FALSE
  log_count(log,'S1','reporting_level',d[!reporting],FALSE,'record')
  log_count(log,'S1','charter_entity',d[reporting & !eligible],FALSE,'record')
  d <- d[reporting & eligible]
  if (rule == 'R02.no_special') {
    # Amendment C2 and docs/rssd9425_codes.txt; missing codes count as zero.
    special <- d$RSSD9425 %in% c(1,2,4,9)
    if (!'RSSD9425' %in% names(d)) special <- rep(FALSE,nrow(d))
    log_count(log,'S1','special_purpose_bank',d[special],FALSE,'record')
    d <- d[!special]
  }
  if (rule == 'R02.add_savings') {
    n_savings <- sum(d$RSSD9048 == 300,na.rm=TRUE)
    log_special(log,'savings_admission',list(qualifying_records=n_savings,
      message=if(n_savings==0) 'No savings records qualify; specification still run' else 'Savings records satisfy all other origin filters'))
  }
  setorder(d,RSSD9001,year,q,CALL8786)
  dup <- duplicated(d,by=c('RSSD9001','quarter'))
  log_count(log,'S1','duplicate_bank_quarter',d[dup],FALSE,'record')
  if (any(dup)) log_special(log,'duplicate_records',d[dup,.(RSSD9001,quarter,CALL8786)])
  d <- d[!dup]; log_count(log,'S1','filtered_unique',d,unit='record'); d
}
# Item resolver only applies zero/identity rules to component amounts; never to
# total assets, average assets, deposits, or income/expense flows.
resolve_items <- function(d, z, cfg, log) {
  prefix <- if (cfg$R16 == 'R16.domestic') 'RCON' else 'RCFD'
  cache <- new.env(parent=emptyenv())
  identities <- list('0010'=c('0081','0071'), '1600'=c('1755','1766'),
                     '1766'=c('1763','1764'), '1350'=c('0276','0277'),
                     '1975'=c('2008','2011'), '2165'=c('2182','2183'))
  function(code, explicit = NULL, component = TRUE) {
    name <- explicit %||% paste0(prefix,code)
    cachekey <- paste(name,component)
    if (exists(cachekey,cache,inherits=FALSE)) return(get(cachekey,cache))
    v <- if (name %in% names(d)) as.numeric(d[[name]]) else rep(NA_real_,nrow(d))
    if (!name %in% names(d)) log_special(log,'unavailable_column',name)
    if (component && cfg$R15 == 'R15.zero_if_not_collected') {
      p <- z$presence[item == name]; idx <- match(d$quarter,p$quarter)
      fill <- is.na(v) & !is.na(idx) & (p$in_file[idx] == 0 | p$any_nonmissing_mnwi[idx] == 0)
      fill[is.na(fill)] <- FALSE
      if (any(fill)) log_special(log,'zero_not_collected',d[fill,.(n=.N),by=.(year,quarter)][,item:=name])
      v[fill] <- 0
    }
    if (component && cfg$R15 == 'R15.identity_fill' && code %in% names(identities)) {
      cols <- paste0(substr(name,1,4),identities[[code]])
      if (all(cols %in% names(d))) {
        total <- rowSums(as.matrix(d[,..cols]))
        fill <- is.na(v) & is.finite(total)
        # 1600 = 1755 + 1766 documented after 1984Q1 only.
        if (code == '1600') fill <- fill & d$quarter > '1984Q1'
        v[fill] <- total[fill]
        if (any(fill)) log_special(log,'identity_fill',d[fill,.(n=.N),by=year][,item:=name])
      }
    }
    assign(cachekey,v,cache); v
  }
}
construct_annual <- function(z,cfg,origin_cfg,log) {
  d <- filter_records(z,cfg,origin_cfg,log)
  item <- resolve_items(d,z,cfg,log)
  d[, assets := item('2170',component=FALSE)]
  d[, avg_assets := item('3368',component=FALSE)]
  if (cfg$R06 == 'R06.rck_days') {
    d[,avg_assets := item('3368',explicit='RCFD3368',component=FALSE)]
    d[is.na(avg_assets),avg_assets := item('3368',explicit='RCON3368',component=FALSE)[is.na(d$avg_assets)]]
  } else if (cfg$R05 == 'R05.min2_fallback' && cfg$R16 != 'R16.domestic')
    d[is.na(avg_assets), avg_assets := RCON3368]
  commercial <- item(if (cfg$R11 == 'R11.incl_accept') '1600' else '1766')
  realestate <- item('1410'); agriculture <- item('1590'); individuals <- item('1975')
  if (cfg$R12 == 'R12.plus_farmland') {
    farmland <- item('1420',explicit='RCON1420')
    realestate <- realestate - farmland; agriculture <- agriculture + farmland
  }
  other <- item('1400') - commercial - realestate - agriculture - individuals
  if (cfg$R13 == 'R13.components') {
    # Non-overlapping components: 1510 is the foreign-bank total; 1516 is a subset.
    codes <- c('2165','1505','1517','1510','1545','2107','2081','2080')
    stopifnot(all(codes %in% unlist(z$candidates$other_loans_and_leases_and_loan_totals$codes)))
    other <- Reduce(`+`, lapply(codes,item))
    log_special(log,'other_loan_components',codes)
  }
  if (cfg$R13 %in% c('R13.net_unearned','R13.net_allowance')) other <- other-item('2123')
  if (cfg$R13 == 'R13.net_allowance') other <- other-item('3123')
  amounts <- cbind(commercial,realestate,individuals,agriculture,other,item('0010'),
                   item('1350'),item('0390'),item('2146'),item('2145'))
  otherassets <- switch(cfg$R14, R14.broad = Reduce(`+`,lapply(c('2150','2130','2155','2143','2160'),item)),
                        R14.literal = item('2160'), R14.residual = d$assets-rowSums(amounts))
  amounts <- cbind(amounts,otherassets); sh <- paste0('a',1:11)
  for (j in 1:11) d[,(sh[j]) := amounts[,j]]
  # S3 assigns deposit scope to R18 independently of R16 asset scope.
  depname <- if (cfg$R18 == 'R18.domestic') 'RCON2200' else 'RCFD2200'
  d[, DEP := item('2200',explicit=depname,component=FALSE)]
  d[, NI := get(if (cfg$R07 == 'R07.net_income') 'RIAD4340' else 'RIAD4300')]
  d[, EXP := RIAD4073 + RIAD4093]
  d[, days := as.numeric(as.Date(sprintf('%d-%02d-01',year+(q==4),ifelse(q==4,1,q*3+1))) -
                          as.Date(sprintf('%d-%02d-01',year,(q-1)*3+1))) ]
  q4 <- d[q==4 & year %in% 1984:1992]
  bankyears <- unique(d[year %in% 1984:1992,.(RSSD9001,year)])
  log_count(log,'S2','no_Q4_record',bankyears[!key(RSSD9001,year) %in% key(q4$RSSD9001,q4$year)],FALSE)
  log_count(log,'S2','Q4_candidates',q4)
  in_market <- q4$RSSD9180 == 5120
  if (cfg$R01 != 'R01.rssdmsa') for (yr in unique(q4$year)) {
    ii <- which(q4$year == yr)
    in_market[ii] <- q4$county_fips5[ii] %in% market_counties(z,cfg,yr)
  }
  in_market[is.na(in_market)] <- FALSE
  positive <- is.finite(q4$RCFD2170) & q4$RCFD2170 > 0
  log_count(log,'S2','outside_geography',q4[!in_market],FALSE)
  log_count(log,'S2','nonpositive_missing_assets',q4[in_market & !positive],FALSE)
  q4[, market := in_market & positive]
  log_count(log,'S2','market_population',q4[market==TRUE])
  # Calculate annual variables for all filtered Q4 banks, also supporting merger predecessors.
  annual <- d[year %in% 1984:1992, {
    aa <- avg_assets; nav <- sum(is.finite(aa))
    required <- if(cfg$R06=='R06.rck_days') 4L else switch(cfg$R05,R05.all4=4L,R05.any=1L,R05.min2_fallback=2L)
    value <- if (nav >= required) {
      if (cfg$R06 == 'R06.rck_days') weighted.mean(aa[is.finite(aa)],days[is.finite(aa)]) else mean_ok(aa)
    } else NA_real_
    list(AA=value,nav=nav)
  },by=.(RSSD9001,year)]
  prev_idx <- match(key(q4$RSSD9001,q4$year-1),key(d[q==4]$RSSD9001,d[q==4]$year))
  prev_assets <- d[q==4]$assets[prev_idx]
  annual_idx <- match(key(q4$RSSD9001,q4$year),key(annual$RSSD9001,annual$year))
  q4[, `:=`(AA=annual$AA[annual_idx], nav=annual$nav[annual_idx])]
  stocks <- d[year %in% 1984:1992,.(stock_sum=sum_ok(assets), stock_n=sum(is.finite(assets))),by=.(RSSD9001,year)]
  si <- match(key(q4$RSSD9001,q4$year),key(stocks$RSSD9001,stocks$year))
  npoints <- stocks$stock_n[si]+is.finite(prev_assets)
  sums <- ifelse(stocks$stock_n[si]>0,stocks$stock_sum[si],0)+ifelse(is.finite(prev_assets),prev_assets,0)
  if (cfg$R06 == 'R06.five_point') q4[,AA:=ifelse(npoints==5,sums/5,NA_real_)]
  if (cfg$R06 == 'R06.two_point') q4[,AA:=(assets+prev_assets)/2]
  if (cfg$R05 == 'R05.min2_fallback' && cfg$R06 %in% c('R06.rck_mean','R06.fdic_roa')) {
    use <- q4$nav==0 & npoints>0
    q4[use,AA:=sums[use]/npoints[use]]
    log_special(log,'average_assets_fallback',q4[use,.(RSSD9001,year)])
  }
  if (cfg$R08 == 'R08.year_end') {
    for (nm in sh) q4[,(nm):=get(nm)/assets]
  } else {
    agg <- d[year %in% 1984:1992, {
      vals <- lapply(.SD,function(x) if(cfg$R08=='R08.mean_of_quarter_shares') mean_ok(x/assets) else mean_ok(x)/mean_ok(assets))
      c(vals,list(DEP=mean_ok(DEP)))
    }, by=.(RSSD9001,year),.SDcols=sh]
    ai <- match(key(q4$RSSD9001,q4$year),key(agg$RSSD9001,agg$year))
    for(nm in c(sh,'DEP')) q4[,(nm):=agg[[nm]][ai]]
  }
  first <- z$call[,.(first_date=min(parse_date(DATE),na.rm=TRUE)),by=RSSD9001]
  q4[,opening:=z$institutions$opening[match(RSSD9050,z$institutions$CERT)]]
  fallback <- is.na(q4$opening)
  q4[fallback,opening:=first$first_date[match(RSSD9001,first$RSSD9001)]]
  log_special(log,'opening_date_first_appearance_fallback',q4[fallback,.(RSSD9001,year,opening)])
  if (cfg$R04 == 'R04.annualise') {
    same_year <- as.integer(format(q4$opening,'%Y')) == q4$year
    months <- 13-as.integer(format(q4$opening,'%m'))
    # Opening month included; no daily proration specified.
    q4[which(same_year),`:=`(NI=NI*12/months[which(same_year)],EXP=EXP*12/months[which(same_year)])]
  }
  q4[,`:=`(ROA=ifelse(AA>0,NI/AA,NA_real_),TER=ifelse(AA>0,EXP/AA,NA_real_))]
  if (cfg$R06 == 'R06.fdic_roa') {
    f <- z$financials[month==12]; if(anyDuplicated(f,by=c('CERT','year'))) unavailable('Ambiguous FDIC CERT/year match')
    q4[,ROA:=f$ROA[match(key(RSSD9050,year),key(f$CERT,f$year))]/100]
  }
  for(nm in c('AA','NI','ROA','TER','DEP',sh))
    log_count(log,'S3',paste0('missing_',nm),q4[market & !is.finite(get(nm))],FALSE)
  log_count(log,'S3','annual_variables_built',q4[market==TRUE])
  q4[,c('RSSD9001','RSSD9050','year','market','opening','AA','NI','EXP','ROA','TER','DEP',sh),with=FALSE]
}
price_index <- function(z,cfg) {
  d <- z$deflators
  p <- switch(cfg$R20,
    R20.cpi_annual = d[provider=='FRED' & series_id=='CPIAUCNS' & grepl('annual_avg',source_file)],
    R20.cpi_december = d[provider=='FRED' & series_id=='CPIAUCNS' & grepl('_native',source_file) & substr(date,6,7)=='12'],
    R20.local_cpi = d[provider=='FRED' & series_id=='CUUSA211SA0'],
    R20.gdp_current = d[provider=='FRED' & series_id=='A191RD3A086NBEA'],
    R20.gdp_historical = d[provider=='ALFRED' & series_id=='GDPDEF' & grepl('1999-01-01',vintage)])
  p <- p[year %in% 1984:1992]
  if (cfg$R20=='R20.gdp_historical') {
    p <- p[,.(P=if(sum(is.finite(value))==4 && uniqueN(date)==4) mean(value) else NA_real_),by=year]
  } else {
    if(anyDuplicated(p$year)) unavailable(paste('Ambiguous annual price observations:',cfg$R20))
    p <- p[,.(year,P=value)]
  }
  if (!all(1984:1992 %in% p$year) || any(!is.finite(p$P) | p$P<=0))
    unavailable(paste('Incomplete/nonpositive price index:',cfg$R20))
  p
}
insured_deposits <- function(z,cfg,log) {
  f <- copy(z$financials[month==12 & year %in% 1984:1992])
  counties <- z$counties
  numeric_county <- grepl('^[0-9]{5}$',f$STCNTY)
  if (is.null(counties) && any(!numeric_county))
    unavailable('All-insured deposits require county_fips_mn_wi.parquet to map FDIC county names; optional crosswalk absent.')
  normalize <- function(x) tolower(trimws(sub(' County$','',x)))
  countykey <- paste(counties$state_abbr,normalize(counties$county_name))
  if(anyDuplicated(countykey)) unavailable('County name/state crosswalk is not unique')
  f[,county_code:=STCNTY]
  f[!numeric_county,county_code:=sprintf('%05d',as.integer(counties$county_fips5[match(paste(STALP,normalize(STCNTY)),countykey)]))]
  # Avoid silently omitting insured institutions with an unresolvable geography.
  if(any(f$county_code=='   NA' | is.na(f$county_code))) unavailable('FDIC financials contains unmapped county names')
  if(anyDuplicated(f,by=c('CERT','year'))) unavailable('FDIC deposits has duplicate CERT/year records')
  f[,in_market:=FALSE]
  for (yr in unique(f$year)) f[year==yr,in_market:=county_code %in% market_counties(z,cfg,yr)]
  log_special(log,'insured_deposit_geography','STCNTY county names mapped by STALP and supplied county table; fixed/dynamic R01 county vintage.')
  f[in_market==TRUE,.(year,DEP)][,.(D_insured=sum_ok(DEP)),by=year]
}
strategic_deviation <- function(shares, reference=shares, rule='R17.sample_sd') {
  shares <- as.matrix(shares); reference <- as.matrix(reference)
  m <- apply(reference,2,mean_ok)
  s <- apply(reference,2,function(x) {
    x<-x[is.finite(x)]
    if(!length(x)) return(NA_real_)
    if(rule=='R17.population_sd') sqrt(mean((x-mean(x))^2)) else stats::sd(x)
  })
  scores <- abs(sweep(sweep(shares,2,m,'-'),2,s,'/'))
  zero <- which(is.finite(s) & s==0)
  if(length(zero)) {
    if(rule=='R17.zero_sd_missing') scores[,zero]<-NA_real_ else
      scores[,zero]<-ifelse(is.finite(shares[,zero,drop=FALSE]),0,NA_real_)
  }
  list(SD=rowSums(scores),means=m,sds=s,zero=zero)
}
consecutive_lag <- function(d,value='y') {
  if(anyDuplicated(key(d$RSSD9001,d$year))) stop('Duplicate bank-year in lag construction')
  d[[value]][match(key(d$RSSD9001,d$year-1L),key(d$RSSD9001,d$year))]
}
merger_links <- function(z) {
  e <- z$events[grepl('merg|absorp|absorb|consol',CHANGECODE_DESC,ignore.case=TRUE) &
                  !grepl('branch',CHANGECODE_DESC,ignore.case=TRUE)]
  links <- rbind(e[,.(year,survivor=SUR_CERT,predecessor=OUT_CERT)],
                 e[,.(year,survivor=ACQ_CERT,predecessor=OUT_CERT)])
  unique(links[is.finite(survivor) & survivor>0 & is.finite(predecessor) & predecessor>0 & survivor!=predecessor])
}
apply_continuity <- function(d,annual,z,cfg,log) {
  d[,lag:=consecutive_lag(d)]
  if(cfg$R03=='R03.continuity') {
    e <- z$events[grepl('charter|legal name|reorgani|organization type',CHANGECODE_DESC,ignore.case=TRUE) &
                    !grepl('merg|absorp|absorb|consol',CHANGECODE_DESC,ignore.case=TRUE)]
    for(i in which(is.na(d$lag))) {
      cert <- d$RSSD9050[i]; yr <- d$year[i]
      # Only a missing predecessor record, never a missing outcome on an existing record.
      exists_prior <- any(annual$RSSD9001==d$RSSD9001[i] & annual$year==yr-1L)
      ev <- e[year==yr & CERT==cert & (is.na(FRM_CERT) | FRM_CERT==cert)]
      absorbed <- merger_links(z)[year==yr & survivor==cert]
      prior <- d[year==yr-1L & RSSD9050==cert & RSSD9001!=d$RSSD9001[i]]
      if(!exists_prior && nrow(ev)>0 && nrow(absorbed)==0 && nrow(prior)==1) {
        d$lag[i]<-prior$y; log_special(log,'legal_continuation',list(bank=d$RSSD9001[i],year=yr,predecessor=prior$RSSD9001))
      }
    }
  }
  if(cfg$R03=='R03.proforma') {
    links<-merger_links(z)
    for(i in seq_len(nrow(d))) {
      cert<-d$RSSD9050[i]; yr<-d$year[i]
      ev<-links[year==yr & survivor==cert]
      if(!nrow(ev)) next
      # Include the survivor's own prior-year business, and recursively any
      # institution absorbed earlier within the same calendar year.
      certs<-unique(c(cert,ev$predecessor))
      repeat {
        expanded<-unique(c(certs,links[year==yr & survivor %in% certs]$predecessor))
        if(setequal(certs,expanded)) break
        certs<-expanded
      }
      prior<-annual[year==yr-1L & RSSD9050 %in% certs]
      if(!all(certs %in% prior$RSSD9050) || anyDuplicated(prior$RSSD9050) ||
         any(!is.finite(prior$NI) | !is.finite(prior$AA) | prior$AA<=0)) {
        d$lag[i]<-NA_real_
        log_special(log,'proforma_unavailable_bank_year',list(bank=d$RSSD9001[i],year=yr,required_cert=certs,
          reason='Missing/ambiguous predecessor prior-year income or average assets; no substitute'))
      } else {
        market_mean<-unique(d[year==yr-1L]$mean_ROA)
        d$lag[i]<-if(length(market_mean)==1) 100*(sum(prior$NI)/sum(prior$AA)-market_mean) else NA_real_
        log_special(log,'proforma_lag',list(bank=d$RSSD9001[i],year=yr,predecessor_cert=certs))
      }
    }
  }
  d
}
benchmarks <- function(annual,z,cfg,log,reference_keys=NULL) {
  d<-copy(annual[market==TRUE]); sh<-paste0('a',1:11)
  if(cfg$R10=='R10.before_benchmarks') {
    log_count(log,'S4','named_before_benchmarks',d[RSSD9001==995151 & year==1987],FALSE)
    d<-d[!(RSSD9001==995151 & year==1987)]
  }
  p<-price_index(z,cfg)
  insured<-if(cfg$R19=='R19.all_insured' || cfg$R21=='R21.all_insured') insured_deposits(z,cfg,log) else NULL
  for(yr in 1984:1992) {
    idx<-which(d$year==yr); ref<-d[idx]
    if(cfg$R09=='R09.joint_complete') {
      complete <- complete.cases(ref[,c(sh,'ROA','DEP'),with=FALSE])
      log_count(log,'S4','excluded_from_joint_reference',ref[!complete],FALSE)
      ref<-ref[complete]
    }
    if(!is.null(reference_keys)) {
      keep <- key(ref$RSSD9001,ref$year) %in% reference_keys
      log_count(log,'S4','excluded_from_analytic_reference',ref[!keep],FALSE)
      ref<-ref[keep]
    }
    log_count(log,'S4','reference_population',ref)
    stats<-strategic_deviation(d[idx,..sh],ref[,..sh],cfg$R17)
    mr<-if(cfg$R09=='R09.weighted_roa') {
      valid<-is.finite(ref$ROA) & is.finite(ref$AA) & ref$AA>0
      if(any(valid)) weighted.mean(ref$ROA[valid],ref$AA[valid]) else NA_real_
    } else mean_ok(ref$ROA)
    total<-sum_ok(ref$DEP)
    ins<-if(!is.null(insured)) insured$D_insured[match(yr,insured$year)] else NA_real_
    d[idx,`:=`(SD=stats$SD,mean_ROA=mr,D_share=if(cfg$R19=='R19.all_insured') ins else total,
              D_growth=if(cfg$R21=='R21.all_insured') ins else total)]
    log_special(log,'benchmark',list(year=yr,n=nrow(ref),means=stats$means,sds=stats$sds,zero_sd=sh[stats$zero]))
  }
  d[,`:=`(SD2=SD^2,y=100*(ROA-mean_ROA),MS=DEP/D_share)]
  totals<-unique(d[,.(year,D_growth)])
  totals[,real_D:=D_growth/p$P[match(year,p$year)]]
  totals[,RMG:=100*(real_D/real_D[match(year-1L,year)]-1)]
  d[,RMG:=totals$RMG[match(year,totals$year)]]
  d<-apply_continuity(d,annual,z,cfg,log)
  if(cfg$R10=='R10.suppress_lag') d[RSSD9001==995151 & year==1988,lag:=NA_real_]
  log_count(log,'S5','derived_variables_built',d)
  for(nm in c('y','lag','SD','MS','TER','RMG')) log_count(log,'S5',paste0('missing_',nm),d[!is.finite(get(nm))],FALSE)
  d
}
select_sample <- function(d,z,cfg,log) {
  log_count(log,'S6','outside_estimation_years',d[!year %in% 1985:1992],FALSE)
  d<-copy(d[year %in% 1985:1992]); log_count(log,'S6','candidate_bank_years',d)
  if(cfg$R03=='R03.drop_merger_years') {
    links<-merger_links(z); bad<-unique(c(key(links$survivor,links$year),key(links$survivor,links$year+1L)))
    drop<-key(d$RSSD9050,d$year) %in% bad
    log_count(log,'S6','merger_year_and_following',d[drop],FALSE); d<-d[!drop]
  }
  if(cfg$R04=='R04.full_prior_year') {
    keep<-!is.na(d$opening) & d$opening<as.Date(sprintf('%d-01-01',d$year-1L))
    log_count(log,'S6','not_full_prior_year',d[!keep],FALSE); d<-d[keep]
  }
  # Sequential attrition gives disjoint S6 reasons; S3/S5 diagnostics overlap.
  for(nm in c('y','lag','SD','SD2','MS','TER','RMG')) {
    keep<-is.finite(d[[nm]])
    log_count(log,'S6',paste0('missing_nonfinite_',nm),d[!keep],FALSE); d<-d[keep]
  }
  log_count(log,'S6','nonpositive_market_share',d[MS<=0],FALSE); d<-d[MS>0]
  if(cfg$R10 %in% c('R10.delete_named','R10.suppress_lag')) {
    log_count(log,'S6','named_outlier',d[RSSD9001==995151 & year==1987],FALSE)
    d<-d[!(RSSD9001==995151 & year==1987)]
  }
  d[,w:=if(cfg$R25=='R25.ols') 1 else MS]
  if(cfg$R24=='R24.mean1' && nrow(d)) d[,w:=w/mean(w)]
  setorder(d,RSSD9001,year); log_count(log,'S6','estimation_sample',d); d
}
construct_sample <- function(z,cfg,origin_cfg=cfg) {
  log<-new_log(); annual<-construct_annual(z,cfg,origin_cfg,log)
  d<-benchmarks(annual,z,cfg,log); sample<-select_sample(d,z,cfg,log)
  if(cfg$R09=='R09.analytic') {
    fixedkeys<-key(sample$RSSD9001,sample$year)
    lagkeys<-key(sample[year==1985]$RSSD9001,1984L)
    log_special(log,'analytic_reference',paste('One recomputation on fixed initial estimation rows.',
      '1984 reference contains only the prior bank-years supplying first-pass 1985 lags; undefined rebuilt rows are dropped.'))
    d<-benchmarks(annual,z,cfg,log,reference_keys=c(fixedkeys,lagkeys))
    sample<-d[match(fixedkeys,key(RSSD9001,year))]
    valid<-Reduce(`&`,lapply(sample[,.(y,lag,SD,SD2,MS,TER,RMG)],is.finite)) & sample$MS>0
    log_count(log,'S6','analytic_rebuilt_undefined',sample[!valid],FALSE)
    log_special(log,'analytic_rebuild',list(first_pass_rows=length(fixedkeys),dropped_rows=sum(!valid)))
    sample<-sample[valid]
    sample[,w:=if(cfg$R25=='R25.ols') 1 else MS]
    if(cfg$R24=='R24.mean1') sample[,w:=w/mean(w)]
    setorder(sample,RSSD9001,year)
    log_count(log,'S6','analytic_fixed_rows',sample)
  }
  messages<-vapply(log$special,function(entry) {
    if(entry$type=='savings_admission') return(paste0(entry$detail$message,
      '; qualifying savings records=',entry$detail$qualifying_records))
    if(entry$type=='analytic_rebuild') return(sprintf('Analytic rebuild: first-pass rows=%d; undefined rows dropped=%d',
      entry$detail$first_pass_rows,entry$detail$dropped_rows))
    ''
  },character(1))
  list(sample=sample,log=freeze_log(log),message=paste(messages[nzchar(messages)],collapse='; '))
}
model_terms <- list(M1=c('MS','TER','RMG','lag'), M2=c('SD','MS','TER','RMG','lag'),
                    M3=c('SD2','SD','MS','TER','RMG','lag'), M3_SQ=c('SD2','MS','TER','RMG','lag'))
make_design <- function(d,model,cfg) {
  if(cfg$R26=='R26.centered' && model=='M3_SQ')
    stop(structure(list(message='R26.centered is not defined for M3_SQ without a first-order term (amendment C6)',call=NULL),
      class=c('not_applicable','error','condition')))
  terms<-model_terms[[model]]; message<-character()
  if(cfg$R22=='R22.year') {terms<-setdiff(terms,'RMG'); message<-'RMG dropped: collinear with year indicators'}
  X<-cbind('(Intercept)'=1,as.matrix(d[,..terms]))
  fe<-if(cfg$R22=='R22.year') d$year else if(cfg$R22=='R22.bank') d$RSSD9001 else NULL
  if(!is.null(fe) && length(unique(fe))>1) {
    vals<-sort(unique(fe)); indicators<-outer(fe,vals[-1L],`==`)*1
    colnames(indicators)<-paste0(if(cfg$R22=='R22.year') 'year_' else 'bank_',vals[-1L])
    X<-cbind(X,indicators)
  }
  A<-diag(ncol(X)); dimnames(A)<-list(colnames(X),colnames(X))
  if(cfg$R26=='R26.centered') {
    center<-mean(d$SD)
    if('SD' %in% colnames(X)) A['(Intercept)','SD']<--center
    if('SD2' %in% colnames(X)) {
      A['SD','SD2']<--2*center; A['(Intercept)','SD2']<-center^2
    }
  }
  list(X=X%*%A,A=A,message=paste(message,collapse='; '))
}
qr_estimate <- function(X,y) {
  n<-nrow(X); k<-ncol(X)
  if(n<=k) stop('No positive residual degrees of freedom')
  norms<-sqrt(colSums(X^2))
  if(any(!is.finite(norms) | norms==0) || any(!is.finite(y))) stop('Nonfinite/zero design column or outcome')
  Z<-sweep(X,2,norms,'/')
  q<-qr(Z,tol=1e-10)
  if(q$rank<k) stop(sprintf('Rank deficient design: rank %d < %d',q$rank,k))
  beta<-qr.coef(q,y)/norms
  inv_pivot<-chol2inv(qr.R(q)); inv<-matrix(0,k,k); inv[q$pivot,q$pivot]<-inv_pivot
  bread<-inv/outer(norms,norms)
  e<-drop(y-X%*%beta)
  singular<-svd(Z,nu=0,nv=0)$d
  list(beta=beta,bread=bread,e=e,sse=sum(e^2),cond=max(singular)/min(singular),
       h=rowSums(qr.Q(q)^2))
}
prais_winsten <- function(X,y,rho,previous) {
  start<-is.na(previous); Xp<-X; yp<-y
  Xp[start,]<-sqrt(1-rho^2)*X[start,,drop=FALSE]
  yp[start]<-sqrt(1-rho^2)*y[start]
  cur<-which(!start); prev<-previous[cur]
  Xp[cur,]<-X[cur,,drop=FALSE]-rho*X[prev,,drop=FALSE]
  yp[cur]<-y[cur]-rho*y[prev]
  list(X=Xp,y=yp)
}
fit_model <- function(d,model,cfg,allow_fit=TRUE) {
  if(!isTRUE(allow_fit)) stop('Model fitting disabled in construction-only mode')
  if(cfg$R26=='R26.centered' && model=='M3_SQ') make_design(d,model,cfg)
  if(!nrow(d)) stop('Empty estimation sample')
  design<-make_design(d,model,cfg); X<-design$X; y<-d$y
  w<-if(cfg$R25=='R25.ols') rep(1,nrow(d)) else d$MS
  if(cfg$R24=='R24.mean1') w<-w/mean(w)
  if(any(!is.finite(w)|w<=0)) stop('Weights must be finite and positive')
  Xw<-X*sqrt(w); yw<-y*sqrt(w); fit<-qr_estimate(Xw,yw); rho<-NA_real_
  if(cfg$R25=='R25.wls_ar1') {
    previous<-match(key(d$RSSD9001,d$year-1L),key(d$RSSD9001,d$year))
    cur<-which(!is.na(previous)); prev<-previous[cur]
    if(!length(cur) || sum(fit$e[prev]^2)==0) stop('Cannot estimate AR(1) rho from consecutive residuals')
    rawrho<-sum(fit$e[cur]*fit$e[prev])/sum(fit$e[prev]^2)
    rho<-max(-0.999,min(0.999,rawrho))
    pw<-prais_winsten(Xw,yw,rho,previous); Xw<-pw$X; yw<-pw$y
    fit<-qr_estimate(Xw,yw)
    design$message<-paste(design$message,sprintf('Two-step Prais-Winsten rho=%.12g (unclipped %.12g); gaps restart; SSE_w uses original weighted residuals',rho,rawrho),sep='; ')
  }
  n<-nrow(X); k<-ncol(X); df<-n-k
  V<-fit$sse/df*fit$bread
  if(cfg$R23=='R23.hc1') {
    score<-Xw*fit$e; V<-n/df*fit$bread%*%crossprod(score)%*%fit$bread
  }
  if(cfg$R23=='R23.cluster_bank') {
    G<-uniqueN(d$RSSD9001); if(G<2) stop('CR1 needs at least two clusters')
    score<-rowsum(Xw*fit$e,d$RSSD9001,reorder=FALSE)
    V<-G/(G-1)*(n-1)/df*fit$bread%*%crossprod(score)%*%fit$bread
  }
  original_e<-drop(y-X%*%fit$beta)
  beta<-drop(design$A%*%fit$beta); V<-design$A%*%V%*%t(design$A)
  names(beta)<-rownames(design$A); dimnames(V)<-list(names(beta),names(beta))
  se<-sqrt(pmax(0,diag(V))); tstat<-beta/se
  results<-data.table(term=names(beta),estimate=beta,se=se,t=tstat,p_two_sided=2*pt(-abs(tstat),df))
  list(results=results,beta=beta,V=V,n=n,n_banks=uniqueN(d$RSSD9001),k=k,df_resid=df,
       sse_w=sum(w*original_e^2),innovation_sse=fit$sse,cond_max=fit$cond,
       residual=original_e,weighted_residual=original_e*sqrt(w),h=fit$h,
       sample_hash=sample_hash(d),message=design$message,rho=rho)
}
nested_f <- function(restricted,unrestricted) {
  if(restricted$sample_hash!=unrestricted$sample_hash) stop('Nested F requires identical estimation rows')
  q<-unrestricted$k-restricted$k
  if(q<=0) stop('Nonpositive restriction count')
  delta<-restricted$sse_w-unrestricted$sse_w
  F<-(delta/q)/(unrestricted$sse_w/unrestricted$df_resid)
  list(delta_sse=delta,q=q,df_resid_u=unrestricted$df_resid,F=F,p_upper=pf(F,q,unrestricted$df_resid,lower.tail=FALSE))
}
studentized_max <- function(fit) {
  if(fit$df_resid<=1) stop('Externally studentized residuals require residual df > 1')
  h<-fit$h; e<-fit$weighted_residual
  s2deleted<-(fit$sse_w-e^2/(1-h))/(fit$df_resid-1)
  score<-abs(e/sqrt(s2deleted*(1-h)))
  score[!is.finite(score)]<-NA_real_
  if(all(is.na(score))) stop('No finite externally studentized residual')
  which.max(score) # sample order gives deterministic RSSD/year tie break
}
prepare_model_samples <- function(d,cfg,allow_fit=TRUE) {
  samples<-setNames(rep(list(d),length(model_terms)),names(model_terms)); message<-''
  if(cfg$R10=='R10.max_rstudent') {
    maxes<-vapply(c('M1','M2','M3'),function(m) studentized_max(fit_model(d,m,cfg,allow_fit)),integer(1))
    for(m in names(samples)) samples[[m]]<-d[-maxes[[if(m=='M3_SQ') 'M3' else m]]]
    message<-paste0('Externally studentized deletion indices: ',paste(names(maxes),maxes,collapse=', '),
      '; M3_SQ follows M3. ',if(length(unique(maxes))>1) 'Model-specific samples; cross-sample F tests unavailable.' else 'Common deletion.')
  }
  list(samples=samples,message=message)
}
make_specs <- function(grid) {
  specs<-list()
  add<-function(origin,axis='',level='',duplicate=FALSE,check=FALSE) {
    cfg<-grid$origins[[origin]]; if(nzchar(axis)) cfg[[axis]]<-level
    specs[[length(specs)+1L]]<<-list(spec_id=if(nzchar(axis)) paste(origin,level,sep='__') else origin,
      origin=origin,axis=axis,level_id=level,cfg=cfg,duplicate=duplicate,check=check)
  }
  for(origin in names(grid$origins)) add(origin)
  for(origin in names(grid$origins)) for(axis in grid$axes) for(level in axis$levels)
    if(!isTRUE(level$check)) add(origin,axis$axis,level$id,level$id==grid$origins[[origin]][[axis$axis]])
  for(origin in names(grid$origins)) for(axis in grid$axes) for(level in axis$levels)
    if(isTRUE(level$check)) add(origin,axis$axis,level$id,check=TRUE)
  specs
}
result_columns<-c('spec_id','origin','axis','level_id','model','status','message','n','n_banks','k','df_resid',
                  'sse_w','cond_max','term','estimate','se','t','p_two_sided','sample_hash')
f_columns<-c('spec_id','comparison','delta_sse','q','df_resid_u','F','p_upper')
influence_columns<-c('origin','model','deletion_type','deleted_id','term','estimate','se','p_two_sided','n','status','message')
empty_table <- function(cols) as.data.table(setNames(rep(list(character()),length(cols)),cols))
result_rows <- function(spec,model,fit=NULL,status='ok',message='',d=NULL) {
  if(is.null(fit)) {
    terms<-c('(Intercept)',model_terms[[model]])
    r<-data.table(term=terms,estimate=NA_real_,se=NA_real_,t=NA_real_,p_two_sided=NA_real_,
      n=if(is.null(d)) NA_integer_ else nrow(d),n_banks=if(is.null(d)) NA_integer_ else uniqueN(d$RSSD9001),
      k=NA_integer_,df_resid=NA_integer_,sse_w=NA_real_,cond_max=NA_real_,sample_hash=if(is.null(d)) NA_character_ else sample_hash(d))
  } else {
    r<-copy(fit$results)
    for(nm in c('n','n_banks','k','df_resid','sse_w','cond_max','sample_hash')) r[,(nm):=fit[[nm]]]
    message<-paste(c(message,fit$message)[nzchar(c(message,fit$message))],collapse='; ')
  }
  r[,`:=`(spec_id=spec$spec_id,origin=spec$origin,axis=spec$axis,level_id=spec$level_id,
           model=model,status=status,message=message)]
  setcolorder(r,result_columns); r
}
write_descriptives <- function(d,path) {
  vars<-c('y','lag','SD','SD2','MS','TER','RMG')
  moments<-rbindlist(lapply(vars,function(v) data.table(statistic=c('mean','sd'),variable=v,
    variable2=NA_character_,value=c(mean_ok(d[[v]]),sd(d[[v]])))))
  C<-if(nrow(d)>1) cor(as.matrix(d[,..vars])) else matrix(NA_real_,length(vars),length(vars),dimnames=list(vars,vars))
  correlations<-as.data.table(as.table(C)); setnames(correlations,c('variable','variable2','value'))
  correlations[,statistic:='correlation']
  fwrite(rbindlist(list(moments,correlations),use.names=TRUE),path,na='NA')
}
write_environment <- function(path) {
  packages<-c('base','stats','data.table','nanoparquet','jsonlite','digest')
  writeLines(c(R.version.string,vapply(packages,function(p) paste(p,as.character(packageVersion(p))),character(1)),
    '',capture.output(sessionInfo())),path)
}
run_influence <- function(base_samples,grid,outdir) {
  path<-file.path(outdir,'influence.csv'); fwrite(empty_table(influence_columns),path)
  for(origin in names(base_samples)) for(model in c('M2','M3')) {
    d<-base_samples[[origin]]; cfg<-grid$origins[[origin]]
    targets<-if(model=='M2') 'SD' else c('SD2','SD')
    for(type in c('bank_year','bank')) {
      ids<-if(type=='bank_year') key(d$RSSD9001,d$year) else as.character(sort(unique(d$RSSD9001)))
      for(id in ids) {
        keep<-if(type=='bank_year') key(d$RSSD9001,d$year)!=id else as.character(d$RSSD9001)!=id
        sub<-d[keep]; fit<-tryCatch(fit_model(sub,model,cfg),error=function(e)e)
        if(inherits(fit,'error')) r<-data.table(term=targets,estimate=NA_real_,se=NA_real_,p_two_sided=NA_real_,
          n=nrow(sub),status=error_status(fit),message=conditionMessage(fit)) else {
          r<-fit$results[term %in% targets,.(term,estimate,se,p_two_sided)]
          r[,`:=`(n=fit$n,status='ok',message=fit$message)]
        }
        r[,`:=`(origin=origin,model=model,deletion_type=type,deleted_id=id)]; setcolorder(r,influence_columns)
        fwrite(r,path,append=TRUE,na='NA')
      }
      cat(sprintf('Influence completed: %s %s %s (%d deletions)\n',origin,model,type,length(ids)))
    }
  }
}
run_analysis <- function(grid_path='grid.json',data_dir='data',outdir='out',construct_only=FALSE) {
  grid<-jsonlite::fromJSON(grid_path,simplifyVector=FALSE); specs<-make_specs(grid)
  z<-load_inputs(data_dir); cache<-new.env(parent=emptyenv()); base_samples<-list(); base_fits<-list()
  dir.create(outdir,showWarnings=FALSE,recursive=TRUE); dir.create(file.path(outdir,'samples'),showWarnings=FALSE)
  write_environment(file.path(outdir,'environment.txt'))
  results<-list(); fs<-list(); checklog<-list(); construction_status<-list()
  # Cache construction only, not fitted results; fitting axes never trigger data rebuilding.
  for(spec in specs) {
    cat(spec$spec_id,if(construct_only) 'construction only' else '', '\n')
    if(spec$duplicate) {
      if(!construct_only) for(m in names(model_terms)) results[[length(results)+1L]]<-result_rows(spec,m,status='duplicate',message='Level identical to origin')
      next
    }
    cfg<-spec$cfg
    construction_cfg<-cfg[paste0('R',sprintf('%02d',1:21))]
    cachekey<-digest::digest(list(construction_cfg,grid$origins[[spec$origin]]$R02),algo='sha256')
    if(exists(cachekey,cache,inherits=FALSE)) built<-get(cachekey,cache) else {
      built<-tryCatch(construct_sample(z,cfg,grid$origins[[spec$origin]]),error=function(e)e)
      assign(cachekey,built,cache)
    }
    if(inherits(built,'error')) {
      status<-error_status(built)
      message<-conditionMessage(built)
      construction_status[[length(construction_status)+1L]]<-data.table(spec_id=spec$spec_id,status=status,message=message,n=NA_integer_)
      if(spec$spec_id==spec$origin) {
        jsonlite::write_json(list(status=status,message=message),file.path(outdir,paste0('construction_log_',spec$origin,'.json')),pretty=TRUE,auto_unbox=TRUE)
        empty<-data.table(RSSD9001=numeric(),year=integer(),y=numeric(),lag=numeric(),SD=numeric(),SD2=numeric(),MS=numeric(),TER=numeric(),RMG=numeric(),w=numeric())
        fwrite(empty,file.path(outdir,'samples',paste0(spec$origin,'.csv')))
        write_descriptives(empty,file.path(outdir,paste0('descriptives_',spec$origin,'.csv')))
      }
      if(!construct_only) for(m in names(model_terms)) results[[length(results)+1L]]<-result_rows(spec,m,status=status,message=message)
      next
    }
    d<-copy(built$sample); d[,w:=if(cfg$R25=='R25.ols') 1 else MS]
    if(cfg$R24=='R24.mean1' && nrow(d)) d[,w:=w/mean(w)]
    construction_status[[length(construction_status)+1L]]<-data.table(spec_id=spec$spec_id,status='ok',
      message=paste(c(built$message,if(cfg$R10=='R10.max_rstudent' && construct_only)
        'Model-dependent outlier selection deferred; undeleted sample' else NULL),collapse='; '),n=nrow(d))
    if(spec$spec_id==spec$origin) {
      base_samples[[spec$origin]]<-d
      fwrite(d[,.(RSSD9001,year,y,lag,SD,SD2,MS,TER,RMG,w)],file.path(outdir,'samples',paste0(spec$origin,'.csv')),na='NA')
      write_descriptives(d,file.path(outdir,paste0('descriptives_',spec$origin,'.csv')))
      jsonlite::write_json(built$log,file.path(outdir,paste0('construction_log_',spec$origin,'.json')),pretty=TRUE,auto_unbox=TRUE,na='null')
    }
    if(construct_only) next
    prepared<-tryCatch(prepare_model_samples(d,cfg),error=function(e)e)
    if(inherits(prepared,'error')) {
      for(m in names(model_terms)) results[[length(results)+1L]]<-result_rows(spec,m,status=error_status(prepared),message=conditionMessage(prepared),d=d)
      next
    }
    prepared$message<-paste(c(built$message,prepared$message)[nzchar(c(built$message,prepared$message))],collapse='; ')
    fits<-list()
    for(m in names(model_terms)) {
      dm<-prepared$samples[[m]]
      fit<-tryCatch(fit_model(dm,m,cfg),error=function(e)e)
      if(inherits(fit,'error')) results[[length(results)+1L]]<-result_rows(spec,m,status=error_status(fit),message=conditionMessage(fit),d=dm) else {
        fits[[m]]<-fit; status<-'ok'; message<-prepared$message
        if(spec$check) {
          raw<-base_fits[[spec$origin]][[m]]
          if(is.null(raw)) {status<-'failed'; message<-paste(message,'Origin fit unavailable for algebraic check')} else {
            coefok<-isTRUE(all.equal(unname(raw$beta),unname(fit$beta),tolerance=1e-7))
            seok<-isTRUE(all.equal(unname(sqrt(diag(raw$V))),unname(sqrt(diag(fit$V))),tolerance=1e-7))
            factor<-if(cfg$R24=='R24.mean1') 1/mean(d$MS) else 1
            sseok<-isTRUE(all.equal(raw$sse_w*factor,fit$sse_w,tolerance=1e-7))
            same<-identical(raw$sample_hash,fit$sample_hash)
            passed<-coefok && seok && sseok && same
            if(!passed) status<-'failed'
            message<-paste(message,paste0('Algebraic check ',if(passed) 'passed' else 'FAILED'))
            checklog[[length(checklog)+1L]]<-data.table(spec_id=spec$spec_id,model=m,coefficients=coefok,SEs=seok,SSE=sseok,same_sample=same,passed=passed)
          }
        }
        results[[length(results)+1L]]<-result_rows(spec,m,fit,status,message)
      }
    }
    if(spec$spec_id==spec$origin) base_fits[[spec$origin]]<-fits
    pairs<-list(c('M1','M2'),c('M1','M3'),c('M2','M3'),c('M1','M3_SQ'))
    for(pair in pairs) {
      comparison<-paste(pair[2],'vs',pair[1])
      test<-tryCatch({if(any(!pair %in% names(fits))) stop('Missing fit'); nested_f(fits[[pair[1]]],fits[[pair[2]]])},error=function(e)e)
      if(inherits(test,'error')) test<-list(delta_sse=NA_real_,q=NA_integer_,df_resid_u=NA_integer_,F=NA_real_,p_upper=NA_real_)
      fs[[length(fs)+1L]]<-as.data.table(c(list(spec_id=spec$spec_id,comparison=comparison),test))
    }
  }
  fwrite(rbindlist(construction_status,fill=TRUE),file.path(outdir,'construction_status.csv'),na='NA')
  if(construct_only) {cat('Construction-only completed; no models or influence fits executed.\n'); return(invisible(construction_status))}
  # Include four explicit NA F rows for unavailable/failed/duplicate specifications too.
  ftable<-if(length(fs)) rbindlist(fs) else empty_table(f_columns)
  for(spec in specs) if(!spec$spec_id %in% ftable$spec_id) {
    ftable<-rbind(ftable,data.table(spec_id=spec$spec_id,comparison=c('M2 vs M1','M3 vs M1','M3 vs M2','M3_SQ vs M1'),
      delta_sse=NA_real_,q=NA_integer_,df_resid_u=NA_integer_,F=NA_real_,p_upper=NA_real_))
  }
  fwrite(rbindlist(results,fill=TRUE),file.path(outdir,'spec_results.csv'),na='NA')
  fwrite(ftable[,..f_columns],file.path(outdir,'f_tests.csv'),na='NA')
  jsonlite::write_json(checklog,file.path(outdir,'algebraic_checks.json'),pretty=TRUE,auto_unbox=TRUE)
  run_influence(base_samples,grid,outdir)
  invisible(TRUE)
}
if(sys.nframe()==0L) {
  args<-commandArgs(trailingOnly=TRUE)
  valid<-args=='--construct-only' | grepl('^--(grid|data|out)=',args)
  if(any(!valid)) stop('Usage: Rscript analysis.R [--construct-only] [--grid=grid.json] [--data=data] [--out=out]')
  argument<-function(name,default) {x<-args[startsWith(args,paste0('--',name,'='))]; if(length(x)) sub('^[^=]*=','',tail(x,1)) else default}
  # All configurable paths are confined to this working directory.
  root<-normalizePath('.',mustWork=TRUE)
  confined<-function(path) {
    if(grepl('(^/|(^|/)\\.\\.(/|$))',path)) stop('Paths must remain inside the working directory')
    existing<-path; while(!file.exists(existing) && existing!='.') existing<-dirname(existing)
    resolved<-normalizePath(existing,mustWork=TRUE)
    if(!(resolved==root || startsWith(resolved,paste0(root,'/')))) stop('Path resolves outside working directory')
    path
  }
  run_analysis(confined(argument('grid','grid.json')),confined(argument('data','data')),
               confined(argument('out','out')),construct_only='--construct-only' %in% args)
}
