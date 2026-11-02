# Pre-unsealing adversarial diagnostic: Table 5 Panel A boundary/timing columns. Independent re-implementation of the
# origin rows (G1, F1, controls L1 panel rule; county + quarter FE) and without controls; then the z-distance of each
# reconstruction to every published Panel A boundary/timing cell under three column layouts. Diagnostic only.
suppressMessages({library(data.table); library(haven); library(fixest); library(readxl)})
D <- "data/derived/run_input_v1/"
cl <- fread(paste0(D,"county_lookup.csv")); U <- cl[STATE_NAME!="Massachusetts", .(fips=as.integer(FIPS), treat)]
q <- fread(paste0(D,"quarterly.csv"), sep="\t", colClasses="character")
q <- q[geoid!="geoid" & quarter!=""]
num <- setdiff(names(q), c("geoid","quarter")); q[, (num):=lapply(.SD, as.numeric), .SDcols=num]; q[, fips:=as.integer(geoid)]
qs <- c(paste0("2005q",2:4), as.vector(t(outer(2006:2014, 1:4, function(y,k) paste0(y,"q",k)))))
pan <- CJ(fips=U$fips, quarter=qs); pan <- merge(pan, q[, c("fips","quarter",num), with=FALSE], by=c("fips","quarter"), all.x=TRUE)
for (v in num) set(pan, which(is.na(pan[[v]])), v, 0)
pan <- merge(pan, U, by="fips"); pan[, year:=as.integer(substr(quarter,1,4))]; pan[, post:=as.integer(year>=2008)]
pan[, fo := log(totaltaga+totaltagb+totaltagh+1)]; pan[, cn := log(totalusers+1)]
acs <- as.data.table(zap_labels(read_dta(paste0(D,"acs5year.dta")))); acs[, fips:=as.integer(geo_fips)]
CTRL <- c("population","popdensity","popmales","households","unemploymentrate","income_householdmedian","income_medianearnings","income_percapita","popeduc","popyoungmales")
cy <- CJ(fips=U$fips, year=2005:2014); cy[, target:=pmin(year, 2011L)]
m <- merge(cy, acs[, c("fips","acsyear",CTRL), with=FALSE], by="fips", allow.cartesian=TRUE)
m[, d:=abs(acsyear-target)]; setorder(m, fips, year, d, acsyear); m <- m[!duplicated(m[, .(fips, year)])]
pan <- merge(pan, m[, c("fips","year",CTRL), with=FALSE], by=c("fips","year"), all.x=TRUE)
bd <- fread(paste0(D,"boundary-counties.csv"), colClasses="character"); setnames(bd, c("src","nb"))
tr <- setNames(U$treat, U$fips)
nbl <- lapply(strsplit(bd$nb, ";"), as.integer); names(nbl) <- as.character(as.integer(bd$src))
B1 <- U$fips[sapply(U$fips, function(c){ v <- nbl[[as.character(c)]]; v <- v[!is.na(v) & v!=c & as.character(v) %in% names(tr)]; length(v)>0 && any(tr[as.character(v)]!=tr[as.character(c)]) })]
tm <- as.data.table(read_excel(paste0(D,"timing.xlsx"))); tm[, yr:=as.integer(format(as.Date(`Sch SB Delivery`),"%Y"))]
TS <- intersect(U$fips, as.integer(tm[yr %in% c(2005,2006), FIPS]))
fc <- paste(CTRL, collapse="+")
est <- function(y, S, ctrl){ f <- if (ctrl) paste0(y," ~ post:treat + ",fc," | fips + quarter") else paste0(y," ~ post:treat | fips + quarter")
  mm <- feols(as.formula(f), data=pan[fips %in% S], cluster=~fips, notes=FALSE); ct <- coeftable(mm)
  data.table(est=ct["post:treat",1], se=ct["post:treat",2], p=ct["post:treat",4], N=nobs(mm)) }
R <- rbind(cbind(cell="bFO",ctrl=1,est("fo",B1,TRUE)), cbind(cell="bC",ctrl=1,est("cn",B1,TRUE)),
           cbind(cell="tFO",ctrl=1,est("fo",TS,TRUE)), cbind(cell="tC",ctrl=1,est("cn",TS,TRUE)),
           cbind(cell="bFO",ctrl=0,est("fo",B1,FALSE)), cbind(cell="bC",ctrl=0,est("cn",B1,FALSE)),
           cbind(cell="tFO",ctrl=0,est("fo",TS,FALSE)), cbind(cell="tC",ctrl=0,est("cn",TS,FALSE)))
print(R)
pub <- data.table(col=5:8, v=c(-0.135,-0.282,-0.0335,-0.0795), se=c(0.0563,0.0634,0.0194,0.0227), dig=c(3,3,4,4), N=c(86502,70980,86502,70980), stars=c("**","***","*","***"))
layouts <- list(L0_as_labelled=c(`5`="bFO",`6`="bC",`7`="tFO",`8`="tC"),
                L1_N_SE_implied_boundary2218=c(`5`="bFO",`6`="tFO",`7`="bC",`8`="tC"),
                L2_N_SE_implied_boundary1820=c(`5`="tFO",`6`="bFO",`7`="tC",`8`="bC"))
out <- list()
for (L in names(layouts)) for (k in 5:8) for (cc in c(1,0)) {
  cl_ <- unname(layouts[[L]][as.character(k)]); r <- R[R$cell==cl_ & R$ctrl==cc][1]; P <- pub[pub$col==k]
  h <- 0.5*10^(-P$dig); lo <- P$v-h; hi <- P$v+h; dd <- if (r$est<lo) lo-r$est else if (r$est>hi) r$est-hi else 0
  out[[length(out)+1]] <- data.table(layout=L, col=k, cell=cl_, ctrl=cc, est=r$est, p_cr1=r$p, N=r$N, pub=P$v, pub_se=P$se, pub_N=P$N, z=dd/P$se) }
O <- rbindlist(out); print(O, nrows=100)
fwrite(O, "audit/adversarial_v1/d09_table5A_layouts.csv"); fwrite(R, "audit/adversarial_v1/d09_table5A_estimates.csv")
cat("Published SE pattern: FO-type SEs (full-sample DTT FO 0.0469; boundary FO 0.0563) vs contributor-type (DTT 0.0144). Col6 se 0.0634 is FO-type; col7 se 0.0194 is contributor-type.\n")
cat("Reconstructed SE CR1: "); print(R[, .(cell, ctrl, se)])
