# Pre-unsealing adversarial diagnostic: Table 6 Distance coefficient under alternative distance constructions.
# Only 'km' and 'miles' have a textual basis ("geodesic (as the crow flies)", unit unstated); others are diagnostic probes.
# Universe includes Massachusetts as treated (lookup coding), which reproduces published N exactly (81,007; boundary 58,715).
suppressMessages({library(data.table); library(haven); library(fixest)})
D <- "data/derived/run_input_v1/"
cl <- fread(paste0(D,"county_lookup.csv")); U <- cl[, .(fips=as.integer(FIPS), treat)]
acs <- as.data.table(zap_labels(read_dta(paste0(D,"acs5year.dta")))); acs[, fips:=as.integer(geo_fips)]
CTRL <- c("population","popdensity","popmales","households","unemploymentrate","income_householdmedian","income_medianearnings","income_percapita","popeduc","popyoungmales")
qg <- function(x,k=4){ r <- rank(x, ties.method="min", na.last="keep"); n <- sum(!is.na(x)); 1+floor(k*(r-1)/n) }
pk <- merge(U[,.(fips)], acs, by="fips"); pk[, d:=abs(acsyear-2011)]; setorder(pk,fips,d,acsyear); pk <- pk[!duplicated(fips)]
cs <- merge(U, pk[, c("fips",CTRL), with=FALSE], by="fips", all.x=TRUE); cs[, `:=`(q1=qg(popdensity), q2=qg(income_householdmedian), q3=qg(income_percapita))]
dst <- fread(paste0(D,"distance.csv"), sep="\t"); rad <- pi/180
hav <- function(la1,lo1,la2,lo2,R=6371.0088) 2*R*asin(sqrt(sin((la2-la1)*rad/2)^2 + cos(la1*rad)*cos(la2*rad)*sin((lo2-lo1)*rad/2)^2))
dst[, km := hav(origin_lat,origin_lon,dest_lat,dest_lon)]
dst[, miles := km/1.609344]
dst[, km_swapped_latlon := hav(origin_lon,origin_lat,dest_lon,dest_lat)]
dst[, deg_euclid := sqrt((dest_lat-origin_lat)^2+(dest_lon-origin_lon)^2)]
dst[, route_km_google := ggl_distance/1000]
dst[, log_km := log(km)]
dst <- dst[!is.na(ggl_distance) & !is.na(osrm_distance)]; dst[, err:=abs(osrm_distance-ggl_distance)]; dst <- dst[err>0]; dst[, y:=log(err)]
p <- merge(dst, cs, by="fips"); fc <- paste(CTRL, collapse="+")
out <- rbindlist(lapply(c("km","miles","km_swapped_latlon","deg_euclid","route_km_google","log_km"), function(v){
  p[, dv := get(v)]; p2 <- p[is.finite(dv)]
  m <- feols(as.formula(paste0("y ~ treat + dv + ", fc, " | q1+q2+q3")), data=p2, cluster=~fips, notes=FALSE); ct <- coeftable(m)
  data.table(distance=v, N=nobs(m), dist_coef=ct["dv",1], dist_se=ct["dv",2], z_vs_pub=(abs(ct["dv",1]-0.0340)-0.00005)/0.00262, treat=ct["treat",1]) }))
print(out); fwrite(out, "audit/adversarial_v1/d12_table6_distance_constructions.csv")
