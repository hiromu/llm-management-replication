# Pre-unsealing adversarial diagnostic: Table 6 (address-pair quality regression). Independent re-implementation of the
# origin row (W1, Y1, L1, Q1, R1) and diagnostic-only variants. Diagnostics cannot change frozen scores.
suppressMessages({library(data.table); library(haven); library(fixest); library(readxl)})
D <- "data/derived/run_input_v1/"
cl <- fread(paste0(D,"county_lookup.csv")); U <- cl[STATE_NAME!="Massachusetts", .(fips=as.integer(FIPS), treat)]
acs <- as.data.table(zap_labels(read_dta(paste0(D,"acs5year.dta")))); acs[, fips:=as.integer(geo_fips)]
CTRL <- c("population","popdensity","popmales","households","unemploymentrate","income_householdmedian","income_medianearnings","income_percapita","popeduc","popyoungmales")
pick <- function(target){ m <- merge(U[,.(fips)], acs, by="fips"); m[, d:=abs(acsyear-target)]; setorder(m,fips,d,acsyear); m[!duplicated(fips)] }
cs <- merge(U, pick(2011)[, c("fips",CTRL), with=FALSE], by="fips", all.x=TRUE)
qg <- function(x,k=4){ r <- rank(x, ties.method="min", na.last="keep"); n <- sum(!is.na(x)); 1+floor(k*(r-1)/n) }
cs[, `:=`(q1=qg(popdensity), q2=qg(income_householdmedian), q3=qg(income_percapita))]
dst <- fread(paste0(D,"distance.csv"), sep="\t")
R <- 6371.0088; rad <- pi/180
dst[, dist_km := 2*R*asin(sqrt(sin((dest_lat-origin_lat)*rad/2)^2 + cos(origin_lat*rad)*cos(dest_lat*rad)*sin((dest_lon-origin_lon)*rad/2)^2))]
dst <- dst[!is.na(ggl_distance) & !is.na(osrm_distance)]
p <- merge(dst, cs, by="fips")
p[, err := abs(osrm_distance-ggl_distance)]
pz <- p[err>0]; pz[, y := log(err)]
f_ctrl <- paste(CTRL, collapse="+")
run <- function(lbl, fml, data, cl=~fips){ m <- feols(as.formula(fml), data=data, cluster=cl, warn=FALSE, notes=FALSE)
  ct <- coeftable(m); out <- data.table(label=lbl, term=rownames(ct)[rownames(ct) %in% c("treat","dist_km","dist_mi","route_km","log_dist_km","mean_dist_km")], N=nobs(m))
  out[, `:=`(est=ct[term,1], se_cr1=ct[term,2], p=ct[term,4])]; print(out); out }
res <- list()
res[[1]] <- run("origin W1 Y1 L1 Q1 (independent re-implementation)", paste0("y ~ treat + dist_km + ", f_ctrl, " | q1 + q2 + q3"), pz)
res[[2]] <- run("no controls, no FE", "y ~ treat + dist_km", pz)
res[[3]] <- run("FE only", "y ~ treat + dist_km | q1+q2+q3", pz)
res[[4]] <- run("controls only", paste0("y ~ treat + dist_km + ", f_ctrl), pz)
res[[5]] <- run("controls without income_medianearnings (keeps counties lacking it)", paste0("y ~ treat + dist_km + ", paste(setdiff(CTRL,"income_medianearnings"),collapse="+"), " | q1+q2+q3"), pz)
pz[, dist_mi := dist_km/1.609344]; pz[, route_km := ggl_distance/1000]; pz[, log_dist_km := log(dist_km)]
res[[6]] <- run("distance in miles (unit check)", paste0("y ~ treat + dist_mi + ", f_ctrl, " | q1+q2+q3"), pz)
res[[7]] <- run("DIAG ONLY: Google route km as distance (contradicts 'as the crow flies')", paste0("y ~ treat + route_km + ", f_ctrl, " | q1+q2+q3"), pz)
pz[, y_signed := log(osrm_distance/ggl_distance)]
pp <- pz[osrm_distance>0 & ggl_distance>0]
res[[8]] <- run("DIAG: signed log ratio ln(osrm/ggl) ('log-difference', p.4925)", paste0("y_signed ~ treat + dist_km + ", f_ctrl, " | q1+q2+q3"), pp)
pz[, y_rel := log(err/ggl_distance)]
res[[9]] <- run("DIAG: ln(|d|/ggl) relative error", paste0("y_rel ~ treat + dist_km + ", f_ctrl, " | q1+q2+q3"), pz[ggl_distance>0])
# County-level mean logged error (Section 2.4.3 'average logged error at the county level'): non-equivalent W2, diagnostic
cm <- pz[, .(y=mean(y), mean_dist_km=mean(dist_km), npairs=.N), by=.(fips)]
cm <- merge(cm, cs, by="fips")
m <- feols(as.formula(paste0("y ~ treat + mean_dist_km + ", f_ctrl, " | q1+q2+q3")), data=cm, vcov="hetero")
ct <- coeftable(m); cat("DIAG county-mean ln error (W2, non-equivalent): N", nobs(m), " treat", ct["treat",1], " se_hc1", ct["treat",2], " p", ct["treat",4], "\n")
m2 <- feols(as.formula(paste0("y ~ treat + mean_dist_km")), data=cm, vcov="hetero"); ct2 <- coeftable(m2)
cat("DIAG county-mean ln error, no controls: treat", ct2["treat",1], " se", ct2["treat",2], "\n")
# Raw means by group
cat("raw mean ln|d|: T", pz[treat==1, mean(y)], " C", pz[treat==0, mean(y)], "\n")
# Boundary and timing pair samples for completeness (sample definitions as frozen P8/P9)
bd <- fread(paste0(D,"boundary-counties.csv"), colClasses="character"); setnames(bd, c("src","nb"))
tr <- setNames(U$treat, U$fips)
nbl <- lapply(strsplit(bd$nb, ";"), function(v) as.integer(v)); names(nbl) <- as.character(as.integer(bd$src))
B1 <- U$fips[sapply(U$fips, function(c){ v <- nbl[[as.character(c)]]; v <- v[!is.na(v) & v!=c & as.character(v) %in% names(tr)]; length(v)>0 && any(tr[as.character(v)]!=tr[as.character(c)]) })]
tm <- as.data.table(read_excel(paste0(D,"timing.xlsx"))); tm[, yr:=as.integer(format(as.Date(`Sch SB Delivery`),"%Y"))]
TS <- intersect(U$fips, as.integer(tm[yr %in% c(2005,2006), FIPS]))
cat("boundary counties", length(B1), " timing counties", length(TS), "\n")
res[[10]] <- run("boundary origin (independent)", paste0("y ~ treat + dist_km + ", f_ctrl, " | q1+q2+q3"), pz[fips %in% B1])
res[[11]] <- run("timing origin (independent)", paste0("y ~ treat + dist_km + ", f_ctrl, " | q1+q2+q3"), pz[fips %in% TS])
fwrite(rbindlist(res), "audit/adversarial_v1/d08_table6_results.csv")
