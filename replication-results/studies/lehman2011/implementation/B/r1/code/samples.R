axes <- paste0('U',1:8)
origin <- setNames(rep(0L,8),axes)
base_terms <- c('total_points','yards_first_down','yards_touchdown','same_division','same_conference','home_field','week','minutes')
perf_terms <- c('perf_below','perf_below_sq','perf_above','below_indicator')
interaction_terms <- paste0(perf_terms[1:3],'_x_min')
terms_for <- function(model,u) {
  z<-base_terms
  if(u['U7']!=2)z<-c(z,paste0('season',2001:2005))
  if(model!='M1')z<-c(z,perf_terms) else if(u['U8']==1)z<-c(z,'below_indicator')
  if(model=='M3')z<-c(z,interaction_terms)
  unique(z)
}
cell_key <- function(u)paste(paste0(names(u),'=',u),collapse='|')
spec_id <- function(model,u)paste(model,cell_key(u),sep='|')
make_plan <- function() {
  cells<-list(list(u=origin,step=1L,models=c('M1','M2','M3')))
  for(j in 1:8) for(level in if(j==7)1:2 else 1L) {
    u<-origin;u[j]<-level
    cells[[length(cells)+1]]<-list(u=u,step=2L,models=if(j==8)'M1' else c('M1','M2','M3'))
  }
  # Lexicographic axis order U1,...,U7 (U7 varies fastest).
  cross<-expand.grid(U7=0:2,U6=0:1,U5=0:1,U4=0:1,U3=0:1,U2=0:1,U1=0:1)
  for(i in seq_len(nrow(cross))) {
    u<-origin;u[1:7]<-as.integer(unlist(cross[i,paste0('U',1:7)]))
    cells[[length(cells)+1]]<-list(u=u,step=3L,models=c('M1','M2','M3'))
  }
  cells
}
read_inputs <- function() {
  cols<-c('game_id','play_id','season','season_type','down','play_type','punt_attempt','field_goal_attempt','pass','rush','qtr','game_seconds_remaining','posteam','defteam','posteam_score','defteam_score','ydstogo','yardline_100','posteam_type','week')
  pp<-data.table::rbindlist(lapply(2000:2005,function(s) {
    x<-as.data.frame(nanoparquet::read_parquet(sprintf('data/pbp/play_by_play_%d.parquet',s),col_select=cols))
    for(nm in setdiff(cols,c('game_id','season_type','play_type','posteam','defteam','posteam_type')))x[[nm]]<-as.numeric(x[[nm]])
    x
  }),use.names=TRUE)
  games<-as.data.frame(nanoparquet::read_parquet('data/games/games.parquet',col_select=c('game_id','div_game','location')))
  align<-read.csv('data/alignment/team_season_alignment.csv',stringsAsFactors=FALSE)
  stopifnot(!anyDuplicated(games$game_id),!anyDuplicated(paste(align$season,align$team_abbr_pbp)))
  list(pbp=as.data.frame(pp),games=games,align=align)
}
construct_base <- function(inp,u) {
  x<-inp$pbp; flow<-list()
  rec<-function(step,description)flow[[length(flow)+1]]<<-data.frame(step=step,description=description,rows=nrow(x))
  keep<-function(z)x<<-x[which(z),,drop=FALSE]
  keep(x$season_type=='REG');rec('S1','Stack six seasons; regular season')
  keep(x$down==4);rec('S2','Fourth down')
  x$y<-NA_real_;x$y[x$play_type %in% c('run','pass')]<-1;x$y[x$play_type %in% c('punt','field_goal')]<-0
  if(u['U1']==1) {
    no<-x$play_type %in% 'no_play';kick<-x$punt_attempt %in% 1|x$field_goal_attempt %in% 1
    attempt<-x$pass %in% 1|x$rush %in% 1
    x$y[no & attempt & !kick]<-1;x$y[no & kick]<-0
  }
  if(u['U2']==1)x$y[x$play_type %in% c('qb_kneel','qb_spike')]<-0
  keep(!is.na(x$y));rec('S3','Classified decision rows (U1/U2 applied)')
  keep(x$qtr %in% 1:4);rec('S4','Regulation')
  keep(if(u['U3']==1)x$game_seconds_remaining>=120 else x$game_seconds_remaining>120)
  rec('S5','Terminal-time exclusion')
  keep(!is.na(x$posteam)&nzchar(x$posteam)&!is.na(x$defteam)&nzchar(x$defteam));rec('S6','Nonempty offense and defense')
  gi<-match(x$game_id,inp$games$game_id)
  ai<-match(paste(x$season,x$posteam),paste(inp$align$season,inp$align$team_abbr_pbp))
  di<-match(paste(x$season,x$defteam),paste(inp$align$season,inp$align$team_abbr_pbp))
  if(anyNA(c(gi,ai,di)))stop('S7 unmatched game or team-season alignment')
  x$game_location<-inp$games$location[gi];x$div_game<-inp$games$div_game[gi]
  x$same_division<-as.numeric(inp$align$division[ai]==inp$align$division[di])
  x$same_conference<-as.numeric(inp$align$conference[ai]==inp$align$conference[di])
  rec('S7','Validated many-to-one game and offense/defense alignment joins')
  list(data=x,flow=data.table::rbindlist(flow))
}
make_variables <- function(x,u) {
  x$d<-x$posteam_score-x$defteam_score-1
  x$perf_below<-pmin(x$d,0);x$perf_below_sq<-x$perf_below^2;x$perf_above<-pmax(x$d,0)
  x$below_indicator<-as.numeric(x$d<=0)
  x$minutes<-x$game_seconds_remaining/60;if(u['U4']==1)x$minutes<-floor(x$minutes)
  for(j in 1:3)x[[interaction_terms[j]]]<-x[[perf_terms[j]]]*x$minutes
  x$total_points<-x$posteam_score;x$yards_first_down<-x$ydstogo;x$yards_touchdown<-x$yardline_100
  if(u['U5']==1)x$same_conference<-as.numeric(x$same_conference==1 & x$same_division==0)
  # Literal 'home, else zero', including missing posteam_type.
  x$home_field<-as.numeric(x$posteam_type %in% 'home')
  if(u['U6']==1)x$home_field[x$game_location %in% 'Neutral']<-0
  x$team<-x$posteam;x$week<-as.integer(x$week)
  for(s in 2001:2005)x[[paste0('season',s)]]<-as.numeric(x$season==s)
  x
}
sample_ids <- function(x) {
  stopifnot(!anyNA(x[c('game_id','play_id')]),!anyDuplicated(x[c('game_id','play_id')]))
  lines<-paste(x$game_id,format(x$play_id,trim=TRUE,scientific=FALSE),sep='|')
  o<-order(lines,method='radix');lines<-lines[o]
  tmp<-'results/samples/.hash_input';writeLines(lines,tmp,useBytes=TRUE)
  if(nzchar(Sys.which('sha256sum'))) ans<-system2(Sys.which('sha256sum'),shQuote(tmp),stdout=TRUE) else ans<-system2(Sys.which('shasum'),c('-a','256',shQuote(tmp)),stdout=TRUE)
  hash<-strsplit(ans,'[[:space:]]+')[[1]][1];unlink(tmp)
  if(!grepl('^[a-f0-9]{64}$',hash))stop('SHA-256 command failed')
  path<-file.path('results/samples',paste0(hash,'.csv.gz'))
  if(!file.exists(path)) {con<-gzfile(path,'wt');write.csv(x[o,c('game_id','play_id')],con,row.names=FALSE);close(con)}
  hash
}
build_samples <- function(plan) {
  inp<-read_inputs();base_cache<-new.env();hash_cache<-new.env();flows<-list();maps<-list()
  for(i in seq_along(plan)) {
    u<-plan[[i]]$u;key<-paste(u[1:3],collapse='')
    if(!exists(key,base_cache,inherits=FALSE))assign(key,construct_base(inp,u),base_cache)
    base<-get(key,base_cache);x<-make_variables(base$data,u)
    cc<-lapply(c('M1','M2','M3'),function(m)complete.cases(x[,c('y','team',terms_for(m,u)),drop=FALSE]))
    common<-Reduce('&',cc);ncc<-vapply(cc,sum,0L);n<-sum(common)
    hashkey<-paste(key,paste(which(!common),collapse=','),sep=':')
    if(!exists(hashkey,hash_cache,inherits=FALSE))assign(hashkey,sample_ids(x[common,,drop=FALSE]),hash_cache)
    hash<-get(hashkey,hash_cache)
    f<-data.table::rbindlist(list(base$flow,data.frame(step=c('S8','S8_dropped','S8_M1','S8_M2','S8_M3'),
      description=c('Common complete cases','Dropped by common complete cases','Model-specific complete cases M1','Model-specific complete cases M2','Model-specific complete cases M3'),rows=c(n,nrow(x)-n,ncc))))
    f$cell_id<-sprintf('cell_%03d',i);f$grid_step<-plan[[i]]$step;f$cell<-cell_key(u);f$sample_hash<-hash
    f$cc_differs<-any(ncc!=n);f$division_disagreements<-sum(x$same_division!=x$div_game,na.rm=TRUE)
    f$division_comparison_missing<-sum(is.na(x$same_division)|is.na(x$div_game))
    flows[[i]]<-f
    maps[[i]]<-data.frame(cell_id=f$cell_id[1],grid_step=plan[[i]]$step,as.list(u),sample_hash=hash,n_obs=n,
       cc_M1=ncc[1],cc_M2=ncc[2],cc_M3=ncc[3],cc_differs=any(ncc!=n),division_disagreements=f$division_disagreements[1])
    plan[[i]]$sample_hash<-hash;plan[[i]]$base_key<-key
  }
  data.table::fwrite(data.table::rbindlist(flows),'results/sample_flow.csv',na='')
  data.table::fwrite(data.table::rbindlist(maps),'results/sample_cells.csv',na='')
  list(plan=plan,bases=base_cache)
}
cell_data <- function(samples,cell) {
  x<-make_variables(get(cell$base_key,samples$bases)$data,cell$u)
  cc<-complete.cases(x[,unique(c('y','team',unlist(lapply(c('M1','M2','M3'),terms_for,u=cell$u)))),drop=FALSE])
  x[cc,,drop=FALSE]
}
