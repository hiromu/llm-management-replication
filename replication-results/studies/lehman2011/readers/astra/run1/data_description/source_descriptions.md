# Public source descriptions (for readers)

These public datasets were acquired independently for the replication. Raw data are not provided to readers. They are described here so that the manifest can map variables to source columns. This description contains no counts or statistics.

## S1. nflverse play-by-play, seasons 2000-2005

- Provider: nflverse (nflverse-data GitHub release "pbp"), built with nflfastR from NFL Game Center feeds. Licence CC-BY-4.0. Acquired 2026-10-27.
- One file per season. Each file has every play of every game in that season, including regular-season (season_type REG, weeks 1-17) and postseason (POST) games, and including non-plays (timeouts, penalties, end-of-quarter markers).
- One row per play. Key: game_id + play_id. 372 columns, defined in data_dictionary.md. These include the game clock (qtr, game_seconds_remaining, half_seconds_remaining, quarter_seconds_remaining, time), down and distance (down, ydstogo, yardline_100, goal_to_go), possession (posteam, defteam, posteam_type), scores (posteam_score, defteam_score, score_differential and their _post versions, total_home_score, total_away_score), play type (play_type, punt_attempt, field_goal_attempt, fourth_down_converted, fourth_down_failed and others), penalty and no-play flags, timeouts remaining, roof, surface, temp and wind, and provider model outputs (ep, wp and others).
- The play-by-play is the provider's parse of official NFL play descriptions. It is not necessarily the same vintage or provider that any particular study used. Provider-built model columns can change between vintages.
- Team columns use current franchise abbreviations (LA, LAC, LV); game_id uses the abbreviations in use at the time (STL, SD, OAK).
- Known coverage gap: two regular-season games from 2000 that are listed in the schedule have no play-by-play rows (2000_03_SD_KC and 2000_06_BUF_MIA).

## S2. nflverse schedules/games

- Provider: nflverse (release "schedules"); an identical copy for 2000-2005 is in nflverse/nfldata games.csv. One row per game: season, game_type, week, gameday, weekday, home/away teams and scores, overtime flag, roof, surface, temp, wind, stadium, rest days, divisional-game flag (div_game), spread_line and total_line (closing lines from Pro-Football-Reference), and identifiers that join to S1 (game_id, old_game_id).
- Betting-odds columns other than spread_line and total_line are empty for these seasons.

## Not acquired

- Conference and division membership is not a separate file. The games file has div_game. Conference membership for 2000-2005 would have to be derived from team identity: the 2002 realignment changed divisions, and Houston joined in 2002.
- Pro-Football-Reference play-by-play and the raw Game Center JSON were not acquired.
