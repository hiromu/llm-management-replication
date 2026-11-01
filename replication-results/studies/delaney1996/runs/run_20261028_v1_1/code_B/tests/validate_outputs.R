#!/opt/homebrew/bin/Rscript
source('code/run_grid.R')
p <- 'code/dev_out/v1_1'
g <- jsonlite::fromJSON('grid_v1.json',simplifyVector=FALSE)
ids <- unlist(g$compute_order)
checks <- 0L
ok <- function(x,label) {if(!isTRUE(x)) stop('FAILED: ',label); checks <<- checks+1L; cat('PASS ',label,'\n',sep='')}
eq <- function(a,b,label,tol=1e-7) ok(isTRUE(all.equal(a,b,tolerance=tol,check.attributes=FALSE)),label)
for(file in c(paste0(names(OUTPUT_COLUMNS),'.csv'),'run_info.json')) ok(file.exists(file.path(p,file)),paste('output exists',file))
o <- lapply(names(OUTPUT_COLUMNS),function(nm) read.csv(file.path(p,paste0(nm,'.csv')),check.names=FALSE,na.strings='NA'))
names(o) <- names(OUTPUT_COLUMNS)
for(nm in names(o)) eq(names(o[[nm]]),OUTPUT_COLUMNS[[nm]],paste('exact schema',nm))
info <- jsonlite::fromJSON(file.path(p,'run_info.json'),simplifyVector=FALSE)
eq(unlist(info$specs_run),ids,'compute_order preserved')
expected_models <- unlist(lapply(c('org','mkt'),function(f) vapply(model_defs(f),`[[`,character(1),'id')))
ms <- o$model_stats; co <- o$coefficients; sm <- o$samples; nt <- o$nested_tests; inf <- o$influence
ok(nrow(ms)==length(ids)*24,'all model rows'); ok(nrow(nt)==length(ids)*8,'all nested rows')
eq(unique(ms$spec_id),ids,'model spec order'); eq(unique(co$spec_id),ids,'coefficient spec order')
for(id in ids) {
  ok(setequal(ms$model_id[ms$spec_id==id],expected_models),paste('all models',id))
  ok(nrow(nt[nt$spec_id==id,])==8,paste('all nested tests',id))
  for(j in which(ms$spec_id==id)) {
    row <- ms[j,]; z <- co[co$spec_id==id & co$model_id==row$model_id,]
    ok(nrow(z)>0,paste('coefficients retained',id,row$model_id))
    sample_id <- if(id=='D04') row$model_id else 'ALL'
    sample <- sm[sm$spec_id==id & sm$family==row$family & sm$model_id==sample_id,]
    eq(nrow(sample),row$n,paste('sample size',id,row$model_id))
    ok(!anyDuplicated(sample$V1),paste('unique sample IDs',id,row$model_id))
    if(row$status=='ok') {
      eq(nrow(z),row$k,paste('parameter count',id,row$model_id))
      ok(all(z$df==row$n-row$k),paste('coefficient df',id,row$model_id))
      eq(z$p_upper+z$p_lower,rep(1,nrow(z)),paste('tail identities',id,row$model_id))
      ok(is.finite(row$n_leverage_one) && row$n_leverage_one>=0 && row$n_leverage_one<=row$n,paste('leverage count',id,row$model_id))
      ok(all(is.finite(z$se_hc3)),paste('finite HC3',id,row$model_id))
      eq(z$p_upper_hc3+z$p_lower_hc3,rep(1,nrow(z)),paste('HC3 tail identities',id,row$model_id))
    } else {
      ok(nzchar(row$error),paste('failure reason',id,row$model_id))
      ok(all(is.na(z$estimate)),paste('failure NA estimates',id,row$model_id))
      ok(any(vapply(info$failures,function(f) identical(f$spec_id,id) && identical(f$model_id,row$model_id) && identical(f$kind,'model'),logical(1))),paste('failure logged',id,row$model_id))
    }
  }
}
for(family in c('org','mkt')) for(def in model_defs(family)[9:12]) {
  sample <- sm[sm$spec_id=='O' & sm$family==family & sm$model_id=='ALL',]
  z <- inf[inf$model_id==def$id,]
  ok(setequal(z$deleted_V1,sample$V1),paste('all deletions retained',def$id))
  ok(nrow(z)==nrow(sample)*(length(def$terms)+length(def$inter)),paste('all influence terms retained',def$id))
  ok(all(z$status %in% c('ok','failed')),paste('influence status',def$id))
  ok(all(nzchar(z$note[z$status=='failed'])),paste('influence failures explained',def$id))
}
# Algebraic checks compare each successful model on identical samples.
for(id in ids[startsWith(ids,'CHK_')]) {
  a <- ms[ms$spec_id=='O',]; b <- ms[ms$spec_id==id,]; b <- b[match(a$model_id,b$model_id),]
  eq(a$status,b$status,paste('algebraic statuses',id))
  use <- a$status=='ok' & b$status=='ok'
  for(v in c('n','k','r2','adj_r2','f','f_df1','f_df2','f_p')) eq(a[[v]][use],b[[v]][use],paste('algebraic model invariance',id,v),tol=1e-6)
  a <- nt[nt$spec_id=='O',]; b <- nt[nt$spec_id==id,]; b <- b[match(a$test_id,b$test_id),]
  for(v in c('n','delta_r2','f','df1','df2','p')) eq(a[[v]],b[[v]],paste('algebraic nested invariance',id,v),tol=1e-6)
}
# Changing centering preserves fitted-model fit measures for interaction models.
a <- ms[ms$spec_id=='O' & ms$model_id %in% c('org_M4','org_M5','mkt_M9','mkt_M10'),]
b <- ms[ms$spec_id=='D34' & ms$model_id %in% a$model_id,]; b <- b[match(a$model_id,b$model_id),]
use <- a$status=='ok' & b$status=='ok'; eq(a$r2[use],b$r2[use],'full grid centered interaction R2 invariance')
cat('ALL ',checks,' OUTPUT CHECKS PASSED\n',sep='')
writeLines(c(paste('All',checks,'output checks passed.'),paste('Models:',nrow(ms)),paste('Successful:',sum(ms$status=='ok')),
             paste('Failed:',sum(ms$status=='failed')),paste('Influence rows:',nrow(inf)),paste('Influence failed rows:',sum(inf$status=='failed'))),
           file.path(p,'output_validation_result.txt'))
