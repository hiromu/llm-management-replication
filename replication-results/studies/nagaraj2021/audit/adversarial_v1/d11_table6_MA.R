# Pre-unsealing adversarial diagnostic: Table 6 with the 14 Massachusetts counties added to the universe (as controls,
# as in the published 3,107 = 1,851 + 1,256 counts, or as treated per county_lookup coding). Diagnostic only: the frozen
# universe excludes Massachusetts per D01 p.4912; this tests whether the published estimates are consistent with MA inclusion.
suppressMessages({library(data.table); library(haven); library(fixest); library(readxl)})
D <- "data/derived/run_input_v1/"
cl <- fread(paste0(D,"county_lookup.csv"))
acs <- as.data.table(zap_labels(read_dta(paste0(D,"acs5year.dta")))); acs[, fips:=as.integer(geo_fips)]
CTRL <- c("population","popdensity","popmales","households","unemploymentrate","income_householdmedian","income_medianearnings","income_percapita","popeduc","popyoungmales")
qg <- function(x,k=4){ r <- rank(x, ties.method="min", na.last="keep"); n <- sum(!is.na(x)); 1+floor(k*(r-1)/n) }
dst <- fread(paste0(D,"distance.csv"), sep="\t"); R <- 6371.0088; rad <- pi/180
dst[, dist_km := 2*R*asin(sqrt(sin((dest_lat-origin_lat)*rad/2)^2 + cos(origin_lat*rad)*cos(dest_lat*rad)*sin((dest_lon-origin_lon)*rad/2)^2))]
dst <- dst[!is.na(ggl_distance) & !is.na(osrm_distance)]; dst[, err:=abs(osrm_distance-ggl_distance)]; dst <- dst[err>0]; dst[, y:=log(err)]
fc <- paste(CTRL, collapse="+")
bd <- fread(paste0(D,"boundary-counties.csv"), colClasses="character"); setnames(bd, c("src","nb"))
nbl <- lapply(strsplit(bd$nb, ";"), as.integer); names(nbl) <- as.character(as.integer(bd$src))
tm <- as.data.table(read_excel(paste0(D,"timing.xlsx"))); tm[, yr:=as.integer(format(as.Date(`Sch SB Delivery`),"%Y"))]
res <- list()
for (scen in c("frozen_U_noMA","MA_as_control","MA_as_treated")) {
  U <- cl[, .(fips=as.integer(FIPS), treat, MA=STATE_NAME=="Massachusetts")]
  if (scen=="frozen_U_noMA") U <- U[MA==FALSE]
  if (scen=="MA_as_control") U[MA==TRUE, treat:=0L]
  pk <- merge(U[,.(fips)], acs, by="fips"); pk[, d:=abs(acsyear-2011)]; setorder(pk,fips,d,acsyear); pk <- pk[!duplicated(fips)]
  cs <- merge(U, pk[, c("fips",CTRL), with=FALSE], by="fips", all.x=TRUE)
  cs[, `:=`(q1=qg(popdensity), q2=qg(income_householdmedian), q3=qg(income_percapita))]
  tr <- setNames(cs$treat, cs$fips)
  B1 <- cs$fips[sapply(cs$fips, function(c){ v <- nbl[[as.character(c)]]; v <- v[!is.na(v) & v!=c & as.character(v) %in% names(tr)]; length(v)>0 && any(tr[as.character(v)]!=tr[as.character(c)]) })]
  TS <- intersect(cs$fips, as.integer(tm[yr %in% c(2005,2006), FIPS]))
  p <- merge(dst, cs, by="fips")
  for (smp in c("full","boundary","timing")) {
    S <- switch(smp, full=cs$fips, boundary=B1, timing=TS)
    m <- feols(as.formula(paste0("y ~ treat + dist_km + ", fc, " | q1+q2+q3")), data=p[fips %in% S], cluster=~fips, notes=FALSE)
    ct <- coeftable(m)
    res[[length(res)+1]] <- data.table(scenario=scen, sample=smp, n_counties_sample=length(S), N=nobs(m), treat=ct["treat",1], se_treat=ct["treat",2], p_treat=ct["treat",4], dist=ct["dist_km",1], se_dist=ct["dist_km",2])
  }
}
O <- rbindlist(res); print(O)
cat("published: full 0.126 (0.0708) dist 0.0340 N 81,007 | boundary 0.149 (0.0800) dist 0.0339 N 58,715 | timing 0.297 (0.0915) dist 0.0376 N 49,095\n")
fwrite(O, "audit/adversarial_v1/d11_table6_MA.csv")
