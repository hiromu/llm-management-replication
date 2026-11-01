# Pre-unsealing adversarial diagnostic: Table 6 with 'percent of males' (D01 p.4925 text) in place of male counts,
# and with ln-transformed controls (frozen L2 is in the uncertain grid). Universe: frozen U and MA-as-treated (N = 81,007).
suppressMessages({library(data.table); library(haven); library(fixest)})
D <- "data/derived/run_input_v1/"
cl <- fread(paste0(D,"county_lookup.csv"))
acs <- as.data.table(zap_labels(read_dta(paste0(D,"acs5year.dta")))); acs[, fips:=as.integer(geo_fips)]
acs[, pct_males := popmales/population]; acs[, pct_youngmales := popyoungmales/population]; acs[, unemp_share := unemploymentrate/population]
qg <- function(x,k=4){ r <- rank(x, ties.method="min", na.last="keep"); n <- sum(!is.na(x)); 1+floor(k*(r-1)/n) }
dst <- fread(paste0(D,"distance.csv"), sep="\t"); rad <- pi/180
dst[, dist_km := 2*6371.0088*asin(sqrt(sin((dest_lat-origin_lat)*rad/2)^2 + cos(origin_lat*rad)*cos(dest_lat*rad)*sin((dest_lon-origin_lon)*rad/2)^2))]
dst[, err:=abs(osrm_distance-ggl_distance)]; dst <- dst[!is.na(err) & err>0]; dst[, y:=log(err)]
sets <- list(
 frozen10 = c("population","popdensity","popmales","households","unemploymentrate","income_householdmedian","income_medianearnings","income_percapita","popeduc","popyoungmales"),
 pct_males = c("population","popdensity","pct_males","households","unemploymentrate","income_householdmedian","income_medianearnings","income_percapita","popeduc","pct_youngmales"),
 pct_males_unemp_share = c("population","popdensity","pct_males","households","unemp_share","income_householdmedian","income_medianearnings","income_percapita","popeduc","pct_youngmales"))
res <- list()
for (uni in c("frozen_U","MA_as_treated")) for (yr in c(2011, 2008)) for (s in names(sets)) {
  U <- cl[, .(fips=as.integer(FIPS), treat, MA=STATE_NAME=="Massachusetts")]; if (uni=="frozen_U") U <- U[MA==FALSE]
  pk <- merge(U[,.(fips)], acs, by="fips"); pk[, d:=abs(acsyear-yr)]; setorder(pk,fips,d,acsyear); pk <- pk[!duplicated(fips)]
  cs <- merge(U, pk, by="fips", all.x=TRUE); cs[, `:=`(q1=qg(popdensity), q2=qg(income_householdmedian), q3=qg(income_percapita))]
  p <- merge(dst, cs[, c("fips","treat","q1","q2","q3",unique(unlist(sets))), with=FALSE], by="fips")
  m <- feols(as.formula(paste0("y ~ treat + dist_km + ", paste(sets[[s]],collapse="+"), " | q1+q2+q3")), data=p, cluster=~fips, notes=FALSE); ct <- coeftable(m)
  res[[length(res)+1]] <- data.table(universe=uni, acsyear=yr, controls=s, N=nobs(m), treat=ct["treat",1], se=ct["treat",2], p=ct["treat",4], dist=ct["dist_km",1])
}
O <- rbindlist(res); print(O); fwrite(O, "audit/adversarial_v1/d15_table6_pctmales.csv")
