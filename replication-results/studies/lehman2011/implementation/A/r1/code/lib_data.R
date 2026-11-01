# Data loading, sample construction (manifest section 1) and variables (section 2)

PBP_COLS <- c("play_id", "game_id", "season", "season_type", "week", "posteam", "defteam",
              "posteam_type", "qtr", "down", "play_type", "game_seconds_remaining",
              "posteam_score", "defteam_score", "ydstogo", "yardline_100",
              "punt_attempt", "field_goal_attempt", "pass", "rush", "goal_to_go")

load_raw <- function(data_dir = "data") {
  pbp <- lapply(2000:2005, function(s) {
    x <- nanoparquet::read_parquet(file.path(data_dir, "pbp", sprintf("play_by_play_%d.parquet", s)), col_select = PBP_COLS)
    x <- as.data.frame(x)
    x$goal_to_go <- as.numeric(x$goal_to_go)      # double in 2000-2002, int32 in 2003-2005
    x$week <- as.integer(x$week); x$season <- as.integer(x$season)
    x
  })
  pbp <- do.call(rbind, pbp)
  games <- as.data.frame(nanoparquet::read_parquet(file.path(data_dir, "games", "games.parquet")))
  align <- read.csv(file.path(data_dir, "alignment", "team_season_alignment.csv"), stringsAsFactors = FALSE)
  list(pbp = pbp, games = games, align = align)
}

empty_or_na <- function(x) is.na(x) | x == ""

# Build the sample for one grid cell.  Returns the analysis data and the flow table.
build_sample <- function(raw, U1 = 0, U2 = 0, U3 = 0, U4 = 0, U5 = 0, U6 = 0) {
  pbp <- raw$pbp; games <- raw$games; align <- raw$align
  flow <- list(); add <- function(step, desc, n) flow[[length(flow) + 1]] <<- data.frame(step = step, description = desc, rows = n, stringsAsFactors = FALSE)
  # S1
  d <- pbp[!is.na(pbp$season_type) & pbp$season_type == "REG", ]
  add("S1", "stack six season files, keep season_type == REG", nrow(d))
  # S2
  d <- d[!is.na(d$down) & d$down == 4, ]
  add("S2", "keep down == 4", nrow(d))
  # S3 decision rows
  pt <- d$play_type; pt[is.na(pt)] <- ""
  keep_origin <- pt %in% c("punt", "field_goal", "run", "pass")
  cls <- rep(NA_integer_, nrow(d))              # 1 = attempt, 0 = non-attempt
  cls[pt %in% c("run", "pass")] <- 1L
  cls[pt %in% c("punt", "field_goal")] <- 0L
  keep <- keep_origin
  desc3 <- "keep play_type in {punt, field_goal, run, pass}"
  if (U1 == 1) {
    np <- pt == "no_play"
    nonatt <- np & ((!is.na(d$punt_attempt) & d$punt_attempt == 1) | (!is.na(d$field_goal_attempt) & d$field_goal_attempt == 1))
    att <- np & !nonatt & ((!is.na(d$pass) & d$pass == 1) | (!is.na(d$rush) & d$rush == 1))
    cls[nonatt] <- 0L; cls[att] <- 1L
    keep <- keep | nonatt | att
    desc3 <- paste0(desc3, "; S3b (U1=1): plus no_play rows classified by punt_attempt/field_goal_attempt (non-attempt) or pass/rush (attempt); unclassifiable no_play rows dropped")
  }
  if (U2 == 1) {
    ks <- pt %in% c("qb_kneel", "qb_spike")
    cls[ks] <- 0L
    keep <- keep | ks
    desc3 <- paste0(desc3, "; S3c (U2=1): plus qb_kneel/qb_spike as non-attempt")
  }
  d <- d[keep, ]; d$y <- cls[keep]
  add("S3", desc3, nrow(d))
  # S4
  d <- d[!is.na(d$qtr) & d$qtr %in% 1:4, ]
  add("S4", "keep qtr in {1,2,3,4}", nrow(d))
  # S5
  if (U3 == 1) { d <- d[!is.na(d$game_seconds_remaining) & d$game_seconds_remaining >= 120, ]; desc5 <- "keep game_seconds_remaining >= 120 (U3=1)" }
  else { d <- d[!is.na(d$game_seconds_remaining) & d$game_seconds_remaining > 120, ]; desc5 <- "keep game_seconds_remaining > 120" }
  add("S5", desc5, nrow(d))
  # S6
  d <- d[!empty_or_na(d$posteam) & !empty_or_na(d$defteam), ]
  add("S6", "drop empty or missing posteam/defteam", nrow(d))
  # S7 merges
  gcols <- c("game_id", "location", "div_game", "home_team", "away_team")
  g <- games[, gcols]
  if (any(duplicated(g$game_id))) stop("games.parquet has duplicated game_id")
  m <- match(d$game_id, g$game_id)
  if (any(is.na(m))) stop(sprintf("S7: %d play rows do not match games.parquet", sum(is.na(m))))
  d$g_location <- g$location[m]; d$g_div_game <- g$div_game[m]
  akey <- paste(align$season, align$team_abbr_pbp)
  if (any(duplicated(akey))) stop("alignment table has duplicated (season, team_abbr_pbp)")
  mo <- match(paste(d$season, d$posteam), akey); md <- match(paste(d$season, d$defteam), akey)
  if (any(is.na(mo))) stop(sprintf("S7: %d rows: offence not in alignment table", sum(is.na(mo))))
  if (any(is.na(md))) stop(sprintf("S7: %d rows: defence not in alignment table", sum(is.na(md))))
  d$off_conf <- align$conference[mo]; d$off_div <- align$division[mo]
  d$def_conf <- align$conference[md]; d$def_div <- align$division[md]
  add("S7", "merge games (game_id) and alignment (offence and defence); all rows matched", nrow(d))
  # Variables (section 2)
  d$d <- d$posteam_score - d$defteam_score - 1
  d$perf_below <- pmin(d$d, 0); d$perf_below_sq <- d$perf_below^2; d$perf_above <- pmax(d$d, 0)
  d$below_indicator <- as.numeric(d$d <= 0)
  d$minutes <- if (U4 == 1) floor(d$game_seconds_remaining / 60) else d$game_seconds_remaining / 60
  d$perf_below_x_min <- d$perf_below * d$minutes; d$perf_below_sq_x_min <- d$perf_below_sq * d$minutes; d$perf_above_x_min <- d$perf_above * d$minutes
  d$total_points <- d$posteam_score
  d$yards_first_down <- d$ydstogo; d$yards_touchdown <- d$yardline_100
  d$same_division <- as.numeric(d$off_div == d$def_div)
  d$same_conference <- if (U5 == 1) as.numeric(d$off_conf == d$def_conf & d$off_div != d$def_div) else as.numeric(d$off_conf == d$def_conf)
  d$home_field <- as.numeric(!is.na(d$posteam_type) & d$posteam_type == "home")
  if (U6 == 1) d$home_field[!is.na(d$g_location) & d$g_location == "Neutral"] <- 0
  d$week <- as.numeric(d$week)
  d$team <- d$posteam
  for (s in 2001:2005) d[[paste0("season_", s)]] <- as.numeric(d$season == s)
  d$team_season <- paste(d$team, d$season, sep = "_")
  # N2 and K1 time variables
  d$quarters_remaining <- 5 - d$qtr
  d$perf_below_x_qtr <- d$perf_below * d$quarters_remaining; d$perf_below_sq_x_qtr <- d$perf_below_sq * d$quarters_remaining; d$perf_above_x_qtr <- d$perf_above * d$quarters_remaining
  d$elapsed <- 60 - d$minutes
  d$perf_below_x_elapsed <- d$perf_below * d$elapsed; d$perf_below_sq_x_elapsed <- d$perf_below_sq * d$elapsed; d$perf_above_x_elapsed <- d$perf_above * d$elapsed
  d$home_field_complement <- 1 - d$home_field
  # cross-check same_division vs games.div_game
  n_disagree <- sum(is.na(d$g_div_game) | d$same_division != d$g_div_game)
  # S8 complete cases
  v_m1 <- c("y", "total_points", "yards_first_down", "yards_touchdown", "same_division", "same_conference", "home_field", "week", "minutes", "season", "team", "game_id", "play_id")
  v_m2 <- c(v_m1, "perf_below", "perf_below_sq", "perf_above", "below_indicator")
  v_m3 <- c(v_m2, "perf_below_x_min", "perf_below_sq_x_min", "perf_above_x_min")
  cc1 <- complete.cases(d[, v_m1]); cc2 <- complete.cases(d[, v_m2]); cc3 <- complete.cases(d[, v_m3])
  common <- cc1 & cc2 & cc3
  n_before <- nrow(d)
  d <- d[common, ]
  add("S8", "common complete cases over the variables of M1, M2 and M3", nrow(d))
  add("S8_dropped", "rows dropped at S8 (missing value in a model variable)", n_before - nrow(d))
  add("S8_M1_specific", "rows M1 would use under model-specific complete cases", sum(cc1))
  add("S8_M2_specific", "rows M2 would use under model-specific complete cases", sum(cc2))
  add("S8_M3_specific", "rows M3 would use under model-specific complete cases", sum(cc3))
  flag <- !(sum(cc1) == nrow(d) && sum(cc2) == nrow(d) && sum(cc3) == nrow(d))
  add("S8_flag", if (flag) "FLAG: model-specific complete-case counts differ from the common sample" else "model-specific complete-case counts equal the common sample (no flag)", as.integer(flag))
  add("check_same_division", "rows where same_division (alignment) disagrees with games.div_game", n_disagree)
  d <- d[order(d$game_id, d$play_id), ]
  rownames(d) <- NULL
  list(data = d, flow = do.call(rbind, flow), n_disagree = n_disagree)
}

sample_id_lines <- function(d) {
  lines <- paste0(d$game_id, "|", sprintf("%.0f", d$play_id))
  sort(lines, method = "radix")                       # C-locale byte order
}

sample_hash <- function(d) {
  lines <- sample_id_lines(d)
  tools::sha256sum(bytes = charToRaw(paste0(paste(lines, collapse = "\n"), "\n")))
}

write_sample_file <- function(d, hash, dir) {
  f <- file.path(dir, paste0(hash, ".csv.gz"))
  if (file.exists(f)) return(invisible(f))
  lines <- sample_id_lines(d)
  con <- gzfile(f, "w")
  writeLines(c("game_id,play_id", sub("|", ",", lines, fixed = TRUE)), con)
  close(con)
  invisible(f)
}
