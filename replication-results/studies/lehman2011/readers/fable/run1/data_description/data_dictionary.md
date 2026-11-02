# Data dictionary: NFL play-by-play and games files, seasons 2000-2005

Created 2026-10-27T11:42:25Z by data/scripts/build_dictionary.py. This dictionary describes columns only. It contains no counts, means, frequencies or value distributions. Coding categories list distinct codes without counts.

## Files and sources

- Play-by-play: one parquet file per season (2000-2005) in data/raw/nflverse/pbp_release_20261027T113315Z/, with byte-equivalent content in the matching .csv.gz files (see registry/loader_check.json). Each season file contains regular-season and postseason plays (column season_type). All six files share the same 372 columns in the same order.
- Games/schedules: data/raw/nflverse/schedules_release_20261027T113315Z/games.parquet (all seasons from 1999 onward; the missingness flags below refer to rows with season 2000-2005). The same content is in games.csv in that directory and in data/raw/nfldata/games_csv_20261027T113315Z/games.csv.
- Definitions: provider dictionaries data/raw/nflverse/dictionaries_20261027T113315Z/nflreadr_dictionary_pbp.csv and data/raw/nflverse/dictionaries_20261027T113315Z/nflreadr_dictionary_schedules.csv (nflreadr, pinned commit), cross-checked with the nflfastR field_descriptions dataset. Where the two play-by-play definitions differ, both are given in the JSON copy (registry/data_dictionary.json).
- Units/coding notes are written by the acquisition role from the provider definitions and stored types; they are not provider text.
- Stored type is the Arrow type in the parquet file. Where it differs by season the per-season types are listed.
- Several columns are outputs of nflfastR statistical models (ep, epa, wp, wpa and related columns, cp, xyac_*, xpass and similar). They are model estimates computed by the provider at build time, not official records, and can change between data vintages.
- Linkage: play-by-play game_id equals games.game_id; play-by-play old_game_id equals games.old_game_id. Play-by-play team columns (home_team, away_team, posteam, defteam and other *_team columns) use current franchise abbreviations (LA, LAC, LV), while game_id and the games file use the abbreviations in use at the time (STL, SD, OAK).
- Coverage gap: two regular-season 2000 games listed in the games file have no rows in play_by_play_2000 (game_id 2000_03_SD_KC and 2000_06_BUF_MIA). They are also absent from the 2022 zip vintage.
- Game-level weather: the play-by-play weather text column is entirely missing in 2000; roof, surface, temp and wind are present in both files (temp and wind only for outdoors/open roofs per provider definition).

## Columns entirely missing in 2000-2005

Play-by-play columns with no non-missing value in any season 2000-2005: pass_length, air_yards, yards_after_catch, air_epa, yac_epa, comp_air_epa, comp_yac_epa, total_home_comp_air_epa, total_away_comp_air_epa, total_home_comp_yac_epa, total_away_comp_yac_epa, total_home_raw_air_epa, total_away_raw_air_epa, total_home_raw_yac_epa, total_away_raw_yac_epa, air_wpa, yac_wpa, comp_air_wpa, comp_yac_wpa, total_home_comp_air_wpa, total_away_comp_air_wpa, total_home_comp_yac_wpa, total_away_comp_yac_wpa, total_home_raw_air_wpa, total_away_raw_air_wpa, total_home_raw_yac_wpa, total_away_raw_yac_wpa, lateral_sack_player_id, lateral_sack_player_name, assist_tackle_3_player_id, assist_tackle_3_player_name, assist_tackle_3_team, assist_tackle_4_player_id, assist_tackle_4_player_name, assist_tackle_4_team, tackle_with_assist_2_player_id, tackle_with_assist_2_player_name, tackle_with_assist_2_team, cp, cpoe, xyac_epa, xyac_mean_yardage, xyac_median_yardage, xyac_success, xyac_fd, xpass, pass_oe.

Play-by-play columns entirely missing in some but not all seasons 2000-2005: lateral_rusher_player_id (missing in 2003); lateral_rusher_player_name (missing in 2003); lateral_rushing_yards (missing in 2003); tackle_for_loss_1_player_id (missing in 2003, 2004, 2005); tackle_for_loss_1_player_name (missing in 2003, 2004, 2005); tackle_for_loss_2_player_id (missing in 2000, 2003, 2004, 2005); tackle_for_loss_2_player_name (missing in 2000, 2003, 2004, 2005); qb_hit_1_player_id (missing in 2004, 2005); qb_hit_1_player_name (missing in 2004, 2005); qb_hit_2_player_id (missing in 2004, 2005); qb_hit_2_player_name (missing in 2004, 2005); order_sequence (missing in 2000); start_time (missing in 2000); time_of_day (missing in 2000); stadium (missing in 2000); weather (missing in 2000); nfl_api_id (missing in 2000); play_clock (missing in 2000); play_deleted (missing in 2000); play_type_nfl (missing in 2000); special_teams_play (missing in 2000); st_play_type (missing in 2000, 2003, 2004, 2005); end_clock_time (missing in 2000, 2003, 2004, 2005); end_yard_line (missing in 2000, 2003, 2004, 2005); drive_real_start_time (missing in 2000, 2001, 2002); drive_yards_penalized (missing in 2000); passer_jersey_number (missing in 2000); rusher_jersey_number (missing in 2000); receiver_jersey_number (missing in 2000); jersey_number (missing in 2000).

Games columns with no non-missing value for seasons 2000-2005: nfl_detail_id, pff, ftn, away_moneyline, home_moneyline, away_spread_odds, home_spread_odds, under_odds, over_odds.

Games columns entirely missing in some but not all seasons 2000-2005: none.

Games columns without a provider definition: ftn. Provider-defined fields absent from the file: none.

## Play-by-play columns

| Column | Definition (provider) | Provider type | Stored type | Units / coding | Coding categories | Seasons with values (2000-2005) |
|---|---|---|---|---|---|---|
| play_id | Numeric play id that when used with game_id and drive provides the unique identifier for a single play. | numeric | double | Identifier; unique within game_id. Not a sequence counter of plays. |  | 2000-2005 |
| game_id | Ten digit identifier for NFL game. | character | string | Text 'SEASON_WW_AWAY_HOME' (WW = two-digit week); joins to games.game_id. |  | 2000-2005 |
| old_game_id | Legacy NFL game ID. | character | string | Ten-digit legacy NFL game identifier (YYYYMMDDNN) stored as text; joins to games.old_game_id. |  | 2000-2005 |
| home_team | String abbreviation for the home team. | character | string | Team abbreviation (current franchise abbreviations LA, LAC, LV for relocated franchises; game_id uses the abbreviations of the time). | ARI, ATL, BAL, BUF, CAR, CHI, CIN, CLE, DAL, DEN, DET, GB, HOU, IND, JAX, KC, LA, LAC, LV, MIA, MIN, NE, NO, NYG, NYJ, PHI, PIT, SEA, SF, TB, TEN, WAS | 2000-2005 |
| away_team | String abbreviation for the away team. | character | string | Team abbreviation (current franchise abbreviations; see home_team). | ARI, ATL, BAL, BUF, CAR, CHI, CIN, CLE, DAL, DEN, DET, GB, HOU, IND, JAX, KC, LA, LAC, LV, MIA, MIN, NE, NO, NYG, NYJ, PHI, PIT, SEA, SF, TB, TEN, WAS | 2000-2005 |
| season_type | 'REG' or 'POST' indicating if the game belongs to regular or post season. | character | string | Coded: REG = regular season, POST = postseason. | POST, REG | 2000-2005 |
| week | Season week. | numeric | int32 | Integer week of the season. In these files regular-season weeks run 1-17 and postseason weeks are numbered after them (18-21); season_type distinguishes them. |  | 2000-2005 |
| posteam | String abbreviation for the team with possession. | character | string | Team abbreviation of the team with possession. Team columns use current franchise abbreviations (LA, LAC, LV) for relocated franchises, whereas game_id and the games file use the abbreviations of the time (STL, SD, OAK). Empty string on some rows. | (empty string), ARI, ATL, BAL, BUF, CAR, CHI, CIN, CLE, DAL, DEN, DET, GB, HOU, IND, JAX, KC, LA, LAC, LV, MIA, MIN, NE, NO, NYG, NYJ, PHI, PIT, SEA, SF, TB, TEN, WAS | 2000-2005 |
| posteam_type | String indicating whether the posteam team is home or away. | character | string | Coded: home or away (relative to posteam). | away, home | 2000-2005 |
| defteam | String abbreviation for the team on defense. | character | string | Team abbreviation of the defending team (current franchise abbreviations; see posteam). | ARI, ATL, BAL, BUF, CAR, CHI, CIN, CLE, DAL, DEN, DET, GB, HOU, IND, JAX, KC, LA, LAC, LV, MIA, MIN, NE, NO, NYG, NYJ, PHI, PIT, SEA, SF, TB, TEN, WAS | 2000-2005 |
| side_of_field | String abbreviation for which team's side of the field the team with possession is currently on. | character | string | Team abbreviation of the side of the field the ball is on; MID or 50 at midfield; empty string on some rows. | (empty string), 50, ARI, ATL, BAL, BUF, CAR, CHI, CIN, CLE, DAL, DEN, DET, GB, HOU, IND, JAX, KC, LA, LAC, LV, MIA, MID, MIN, NE, NO, NYG, NYJ, PHI, PIT, SEA, SF, TB, TEN, WAS | 2000-2005 |
| yardline_100 | Numeric distance in the number of yards from the opponent's endzone for the posteam. | numeric | double | Yards from the opponent's end zone at the line of scrimmage, on a 0-100 scale (provider definition); relative to posteam. |  | 2000-2005 |
| game_date | Date of the game. | character | string | Text date YYYY-MM-DD. |  | 2000-2005 |
| quarter_seconds_remaining | Numeric seconds remaining in the quarter. | numeric | double | Seconds remaining in the quarter. |  | 2000-2005 |
| half_seconds_remaining | Numeric seconds remaining in the half. | numeric | double | Seconds remaining in the half. |  | 2000-2005 |
| game_seconds_remaining | Numeric seconds remaining in the game. | numeric | double | Seconds remaining in the game (provider definition); regulation is 3600 seconds. |  | 2000-2005 |
| game_half | String indicating which half the play is in, either Half1, Half2, or Overtime. | character | string | Coded: Half1, Half2, Overtime. | Half1, Half2, Overtime | 2000-2005 |
| quarter_end | Binary indicator for whether or not the row of the data is marking the end of a quarter. | numeric | double | Binary indicator coded 1/0. | 0, 1 | 2000-2005 |
| drive | Numeric drive number in the game. | numeric | double |  |  | 2000-2005 |
| sp | Binary indicator for whether or not a score occurred on the play. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| qtr | Quarter of the game (5 is overtime). | numeric | double | Integer quarter; 5 (and 6 for a second overtime period) denote overtime. | 1, 2, 3, 4, 5, 6 | 2000-2005 |
| down | The down for the given play. | numeric | double | Integer 1-4; missing when the play has no down (e.g. kickoffs, extra points, timeouts, some penalties). | 1, 2, 3, 4 | 2000-2005 |
| goal_to_go | Binary indicator for whether or not the posteam is in a goal down situation. | numeric | 2000: double; 2001: double; 2002: double; 2003: int32; 2004: int32; 2005: int32 | Binary indicator coded 1/0. |  | 2000-2005 |
| time | Time at start of play provided in string format as minutes:seconds remaining in the quarter. | character | string | Game clock at the start of the play, text MM:SS, counting down within the quarter. |  | 2000-2005 |
| yrdln | String indicating the current field position for a given play. | character | string | Text field position: team abbreviation followed by yard line (e.g. 'ABC 30'), or 'MID 50'. |  | 2000-2005 |
| ydstogo | Numeric yards in distance from either the first down marker or the endzone in goal down situations. | numeric | double | Yards to the first-down marker, or to the end zone in goal-to-go situations (provider definition). |  | 2000-2005 |
| ydsnet | Numeric value for total yards gained on the given drive. | numeric | double |  |  | 2000-2005 |
| desc | Detailed string description for the given play. | character | string | Free-text play description from the official play-by-play. |  | 2000-2005 |
| play_type | String indicating the type of play: pass (includes sacks), run (includes scrambles), punt, field_goal, kickoff, extra_point, qb_kneel, qb_spike, no_play (timeouts and penalties), and missing for rows indicating end of play. | character | string | Coded string; see coding categories. Provider: pass includes sacks, run includes scrambles, no_play covers timeouts and penalties; missing on rows marking end of play/period. An empty-string code also occurs. | (empty string), extra_point, field_goal, kickoff, no_play, pass, punt, qb_kneel, qb_spike, run | 2000-2005 |
| yards_gained | Numeric yards gained (or lost) by the possessing team, excluding yards gained via fumble recoveries and laterals. | numeric | double | Yards gained or lost by posteam (provider definition excludes fumble-recovery and lateral yardage). |  | 2000-2005 |
| shotgun | Binary indicator for whether or not the play was in shotgun formation. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| no_huddle | Binary indicator for whether or not the play was in no_huddle formation. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| qb_dropback | Binary indicator for whether or not the QB dropped back on the play (pass attempt, sack, or scrambled). | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| qb_kneel | Binary indicator for whether or not the QB took a knee. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| qb_spike | Binary indicator for whether or not the QB spiked the ball. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| qb_scramble | Binary indicator for whether or not the QB scrambled. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| pass_length | String indicator for pass length: short or deep. | character | string |  |  | none (entirely missing 2000-2005) |
| pass_location | String indicator for pass location: left, middle, or right. | character | string |  | left, middle, right | 2000-2005 |
| air_yards | Numeric value for distance in yards perpendicular to the line of scrimmage at where the targeted receiver either caught or didn't catch the ball. | numeric | double |  |  | none (entirely missing 2000-2005) |
| yards_after_catch | Numeric value for distance in yards perpendicular to the yard line where the receiver made the reception to where the play ended. | numeric | double |  |  | none (entirely missing 2000-2005) |
| run_location | String indicator for location of run: left, middle, or right. | character | string |  | left, middle, right | 2000-2005 |
| run_gap | String indicator for line gap of run: end, guard, or tackle | character | string |  | end, guard, tackle | 2000-2005 |
| field_goal_result | String indicator for result of field goal attempt: made, missed, or blocked. | character | string |  | blocked, made, missed | 2000-2005 |
| kick_distance | Numeric distance in yards for kickoffs, field goals, and punts. | numeric | double |  |  | 2000-2005 |
| extra_point_result | String indicator for the result of the extra point attempt: good, failed, blocked, safety (touchback in defensive endzone is 1 point apparently), or aborted. | character | string |  | aborted, blocked, failed, good | 2000-2005 |
| two_point_conv_result | String indicator for result of two point conversion attempt: success, failure, safety (touchback in defensive endzone is 1 point apparently), or return. | character | string |  | failure, success | 2000-2005 |
| home_timeouts_remaining | Numeric timeouts remaining in the half for the home team. | numeric | double | Count of home timeouts remaining (0-3). |  | 2000-2005 |
| away_timeouts_remaining | Numeric timeouts remaining in the half for the away team. | numeric | double | Count of away timeouts remaining (0-3). |  | 2000-2005 |
| timeout | Binary indicator for whether or not a timeout was called by either team. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| timeout_team | String abbreviation for which team called the timeout. | character | string |  | ARI, ATL, BAL, BUF, CAR, CHI, CIN, CLE, DAL, DEN, DET, GB, HOU, IND, JAX, KC, LA, LAC, LV, MIA, MIN, NE, NO, NYG, NYJ, PHI, PIT, SEA, SF, TB, TEN, WAS | 2000-2005 |
| td_team | String abbreviation for which team scored the touchdown. | character | string |  | ARI, ATL, BAL, BUF, CAR, CHI, CIN, CLE, DAL, DEN, DET, GB, HOU, IND, JAX, KC, LA, LAC, LV, MIA, MIN, NE, NO, NYG, NYJ, PHI, PIT, SEA, SF, TB, TEN, WAS | 2000-2005 |
| td_player_name | String name of the player who scored a touchdown. | character | string |  |  | 2000-2005 |
| td_player_id | Unique identifier of the player who scored a touchdown. | character | string |  |  | 2000-2005 |
| posteam_timeouts_remaining | Number of timeouts remaining for the possession team. | numeric | double | Count of posteam timeouts remaining (0-3). |  | 2000-2005 |
| defteam_timeouts_remaining | Number of timeouts remaining for the team on defense. | numeric | double | Count of defteam timeouts remaining (0-3). |  | 2000-2005 |
| total_home_score | Score for the home team at the start of the play. | numeric | double | Home team points. nflreadr dictionary says at the start of the play; nflfastR field_descriptions says at the end of the play. Timing not resolved at acquisition. |  | 2000-2005 |
| total_away_score | Score for the away team at the start of the play. | numeric | double | Away team points. Same start/end-of-play definitional conflict as total_home_score. |  | 2000-2005 |
| posteam_score | Score the posteam at the start of the play. | numeric | double | Points of posteam before the play. |  | 2000-2005 |
| defteam_score | Score the defteam at the start of the play. | numeric | double | Points of defteam before the play. |  | 2000-2005 |
| score_differential | Score differential between the posteam and defteam at the start of the play. | numeric | double | posteam_score minus defteam_score, before the play. |  | 2000-2005 |
| posteam_score_post | Score for the posteam at the end of the play. | numeric | double | Points of posteam after the play. |  | 2000-2005 |
| defteam_score_post | Score for the defteam at the end of the play. | numeric | double | Points of defteam after the play. |  | 2000-2005 |
| score_differential_post | Score differential between the posteam and defteam at the end of the play. | numeric | double | posteam_score_post minus defteam_score_post. |  | 2000-2005 |
| no_score_prob | Predicted probability of no score occurring for the rest of the half based on the expected points model. | numeric | double |  |  | 2000-2005 |
| opp_fg_prob | Predicted probability of the defteam scoring a FG next. 'Next' in this context means the next score in the same game half. | numeric | double |  |  | 2000-2005 |
| opp_safety_prob | Predicted probability of the defteam scoring a safety next. 'Next' in this context means the next score in the same game half. | numeric | double |  |  | 2000-2005 |
| opp_td_prob | Predicted probability of the defteam scoring a TD next. 'Next' in this context means the next score in the same game half. | numeric | double |  |  | 2000-2005 |
| fg_prob | Predicted probability of the posteam scoring a FG next. 'Next' in this context means the next score in the same game half. | numeric | double |  |  | 2000-2005 |
| safety_prob | Predicted probability of the posteam scoring a safety next. 'Next' in this context means the next score in the same game half. | numeric | double |  |  | 2000-2005 |
| td_prob | Predicted probability of the posteam scoring a TD next. 'Next' in this context means the next score in the same game half. | numeric | double |  |  | 2000-2005 |
| extra_point_prob | Predicted probability of the posteam scoring an extra point. | numeric | double |  |  | 2000-2005 |
| two_point_conversion_prob | Predicted probability of the posteam scoring the two point conversion. | numeric | double |  |  | 2000-2005 |
| ep | Using the scoring event probabilities, the estimated expected points with respect to the possession team for the given play. | numeric | double | Model-estimated expected points before the play; nflfastR model output. |  | 2000-2005 |
| epa | Expected points added (EPA) by the posteam for the given play. | numeric | double | Model-estimated expected points added; nflfastR model output. |  | 2000-2005 |
| total_home_epa | Cumulative total EPA for the home team in the game so far. | numeric | double |  |  | 2000-2005 |
| total_away_epa | Cumulative total EPA for the away team in the game so far. | numeric | double |  |  | 2000-2005 |
| total_home_rush_epa | Cumulative total rushing EPA for the home team in the game so far. | numeric | double |  |  | 2000-2005 |
| total_away_rush_epa | Cumulative total rushing EPA for the away team in the game so far. | numeric | double |  |  | 2000-2005 |
| total_home_pass_epa | Cumulative total passing EPA for the home team in the game so far. | numeric | double |  |  | 2000-2005 |
| total_away_pass_epa | Cumulative total passing EPA for the away team in the game so far. | numeric | double |  |  | 2000-2005 |
| air_epa | EPA from the air yards alone. For completions this represents the actual value provided through the air. For incompletions this represents the hypothetical value that could've been added through the air if the pass was completed. | numeric | double |  |  | none (entirely missing 2000-2005) |
| yac_epa | EPA from the yards after catch alone. For completions this represents the actual value provided after the catch. For incompletions this represents the difference between the hypothetical air_epa and the play's raw observed EPA (how much the incomplete pass cost the posteam). | numeric | double |  |  | none (entirely missing 2000-2005) |
| comp_air_epa | EPA from the air yards alone only for completions. | numeric | double |  |  | none (entirely missing 2000-2005) |
| comp_yac_epa | EPA from the yards after catch alone only for completions. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_home_comp_air_epa | Cumulative total completions air EPA for the home team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_away_comp_air_epa | Cumulative total completions air EPA for the away team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_home_comp_yac_epa | Cumulative total completions yac EPA for the home team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_away_comp_yac_epa | Cumulative total completions yac EPA for the away team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_home_raw_air_epa | Cumulative total raw air EPA for the home team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_away_raw_air_epa | Cumulative total raw air EPA for the away team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_home_raw_yac_epa | Cumulative total raw yac EPA for the home team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_away_raw_yac_epa | Cumulative total raw yac EPA for the away team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| wp | Estimated win probabiity for the posteam given the current situation at the start of the given play. | numeric | double | Model-estimated win probability for posteam (0-1); derived by nflfastR model, not an official record. |  | 2000-2005 |
| def_wp | Estimated win probability for the defteam. | numeric | double | Model-estimated win probability for defteam (0-1); nflfastR model output. |  | 2000-2005 |
| home_wp | Estimated win probability for the home team. | numeric | double | Model-estimated home win probability (0-1); nflfastR model output. |  | 2000-2005 |
| away_wp | Estimated win probability for the away team. | numeric | double | Model-estimated away win probability (0-1); nflfastR model output. |  | 2000-2005 |
| wpa | Win probability added (WPA) for the posteam. | numeric | double | Model-estimated win probability added; nflfastR model output. |  | 2000-2005 |
| vegas_wpa | Win probability added (WPA) for the posteam: spread_adjusted model. | numeric | double |  |  | 2000-2005 |
| vegas_home_wpa | Win probability added (WPA) for the home team: spread_adjusted model. | numeric | double |  |  | 2000-2005 |
| home_wp_post | Estimated win probability for the home team at the end of the play. | numeric | double |  |  | 2000-2005 |
| away_wp_post | Estimated win probability for the away team at the end of the play. | numeric | double |  |  | 2000-2005 |
| vegas_wp | Estimated win probabiity for the posteam given the current situation at the start of the given play, incorporating pre-game Vegas line. | numeric | double | Model-estimated posteam win probability incorporating the spread (0-1); nflfastR model output. |  | 2000-2005 |
| vegas_home_wp | Estimated win probability for the home team incorporating pre-game Vegas line. | numeric | double |  |  | 2000-2005 |
| total_home_rush_wpa | Cumulative total rushing WPA for the home team in the game so far. | numeric | double |  |  | 2000-2005 |
| total_away_rush_wpa | Cumulative total rushing WPA for the away team in the game so far. | numeric | double |  |  | 2000-2005 |
| total_home_pass_wpa | Cumulative total passing WPA for the home team in the game so far. | numeric | double |  |  | 2000-2005 |
| total_away_pass_wpa | Cumulative total passing WPA for the away team in the game so far. | numeric | double |  |  | 2000-2005 |
| air_wpa | WPA through the air (same logic as air_epa). | numeric | double |  |  | none (entirely missing 2000-2005) |
| yac_wpa | WPA from yards after the catch (same logic as yac_epa). | numeric | double |  |  | none (entirely missing 2000-2005) |
| comp_air_wpa | The air_wpa for completions only. | numeric | double |  |  | none (entirely missing 2000-2005) |
| comp_yac_wpa | The yac_wpa for completions only. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_home_comp_air_wpa | Cumulative total completions air WPA for the home team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_away_comp_air_wpa | Cumulative total completions air WPA for the away team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_home_comp_yac_wpa | Cumulative total completions yac WPA for the home team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_away_comp_yac_wpa | Cumulative total completions yac WPA for the away team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_home_raw_air_wpa | Cumulative total raw air WPA for the home team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_away_raw_air_wpa | Cumulative total raw air WPA for the away team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_home_raw_yac_wpa | Cumulative total raw yac WPA for the home team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| total_away_raw_yac_wpa | Cumulative total raw yac WPA for the away team in the game so far. | numeric | double |  |  | none (entirely missing 2000-2005) |
| punt_blocked | Binary indicator for if the punt was blocked. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| first_down_rush | Binary indicator for if a running play converted the first down. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| first_down_pass | Binary indicator for if a passing play converted the first down. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| first_down_penalty | Binary indicator for if a penalty converted the first down. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| third_down_converted | Binary indicator for if the first down was converted on third down. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| third_down_failed | Binary indicator for if the posteam failed to convert first down on third down. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| fourth_down_converted | Binary indicator for if the first down was converted on fourth down. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| fourth_down_failed | Binary indicator for if the posteam failed to convert first down on fourth down. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| incomplete_pass | Binary indicator for if the pass was incomplete. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| touchback | Binary indicator for if a touchback occurred on the play. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| interception | Binary indicator for if the pass was intercepted. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| punt_inside_twenty | Binary indicator for if the punt ended inside the twenty yard line. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| punt_in_endzone | Binary indicator for if the punt was in the endzone. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| punt_out_of_bounds | Binary indicator for if the punt went out of bounds. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| punt_downed | Binary indicator for if the punt was downed. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| punt_fair_catch | Binary indicator for if the punt was caught with a fair catch. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| kickoff_inside_twenty | Binary indicator for if the kickoff ended inside the twenty yard line. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| kickoff_in_endzone | Binary indicator for if the kickoff was in the endzone. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| kickoff_out_of_bounds | Binary indicator for if the kickoff went out of bounds. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| kickoff_downed | Binary indicator for if the kickoff was downed. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| kickoff_fair_catch | Binary indicator for if the kickoff was caught with a fair catch. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| fumble_forced | Binary indicator for if the fumble was forced. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| fumble_not_forced | Binary indicator for if the fumble was not forced. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| fumble_out_of_bounds | Binary indicator for if the fumble went out of bounds. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| solo_tackle | Binary indicator if the play had a solo tackle (could be multiple due to fumbles). | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| safety | Binary indicator for whether or not a safety occurred. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| penalty | Binary indicator for whether or not a penalty occurred. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| tackled_for_loss | Binary indicator for whether or not a tackle for loss on a run play occurred. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| fumble_lost | Binary indicator for if the fumble was lost. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| own_kickoff_recovery | Binary indicator for if the kicking team recovered the kickoff. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| own_kickoff_recovery_td | Binary indicator for if the kicking team recovered the kickoff and scored a TD. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| qb_hit | Binary indicator if the QB was hit on the play. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| rush_attempt | Binary indicator for if the play was a run. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| pass_attempt | Binary indicator for if the play was a pass attempt (includes sacks). | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| sack | Binary indicator for if the play ended in a sack. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| touchdown | Binary indicator for if the play resulted in a TD. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| pass_touchdown | Binary indicator for if the play resulted in a passing TD. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| rush_touchdown | Binary indicator for if the play resulted in a rushing TD. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| return_touchdown | Binary indicator for if the play resulted in a return TD. Returns may occur on any of: interception, fumble, kickoff, punt, or blocked kicks. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| extra_point_attempt | Binary indicator for extra point attempt. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| two_point_attempt | Binary indicator for two point conversion attempt. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| field_goal_attempt | Binary indicator for field goal attempt. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| kickoff_attempt | Binary indicator for kickoff. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| punt_attempt | Binary indicator for punts. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| fumble | Binary indicator for if a fumble occurred. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| complete_pass | Binary indicator for if the pass was completed. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| assist_tackle | Binary indicator for if an assist tackle occurred. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| lateral_reception | Binary indicator for if a lateral occurred on the reception. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| lateral_rush | Binary indicator for if a lateral occurred on a run. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| lateral_return | Binary indicator for if a lateral occurred on a return. Returns may occur on any of: interception, fumble, kickoff, punt, or blocked kicks. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| lateral_recovery | Binary indicator for if a lateral occurred on a fumble recovery. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| passer_player_id | Unique identifier for the player that attempted the pass. | character | string |  |  | 2000-2005 |
| passer_player_name | String name for the player that attempted the pass. | character | string |  |  | 2000-2005 |
| passing_yards | Numeric yards by the passer_player_name, including yards gained in pass plays with laterals. This should equal official passing statistics. | numeric | double |  |  | 2000-2005 |
| receiver_player_id | Unique identifier for the receiver that was targeted on the pass. | character | string |  |  | 2000-2005 |
| receiver_player_name | String name for the targeted receiver. | character | string |  |  | 2000-2005 |
| receiving_yards | Numeric yards by the receiver_player_name, excluding yards gained in pass plays with laterals. This should equal official receiving statistics but could miss yards gained in pass plays with laterals. Please see the description of `lateral_receiver_player_name` for further information. | numeric | double |  |  | 2000-2005 |
| rusher_player_id | Unique identifier for the player that attempted the run. | character | string |  |  | 2000-2005 |
| rusher_player_name | String name for the player that attempted the run. | character | string |  |  | 2000-2005 |
| rushing_yards | Numeric yards by the rusher_player_name, excluding yards gained in rush plays with laterals. This should equal official rushing statistics but could miss yards gained in rush plays with laterals. Please see the description of `lateral_rusher_player_name` for further information. | numeric | double |  |  | 2000-2005 |
| lateral_receiver_player_id | Unique identifier for the player that received the last(!) lateral on a pass play. | character | string |  |  | 2000-2005 |
| lateral_receiver_player_name | String name for the player that received the last(!) lateral on a pass play. If there were multiple laterals in the same play, this will only be the last player who received a lateral. Please see <https://github.com/mrcaseb/nfl-data/tree/master/data/lateral_yards> for a list of plays where multiple players recorded lateral receiving yards. | character | string |  |  | 2000-2005 |
| lateral_receiving_yards | Numeric yards by the `lateral_receiver_player_name` in pass plays with laterals. Please see the description of `lateral_receiver_player_name` for further information. | numeric | double |  |  | 2000-2005 |
| lateral_rusher_player_id | Unique identifier for the player that received the last(!) lateral on a run play. | character | string |  |  | 2000, 2001, 2002, 2004, 2005 |
| lateral_rusher_player_name | String name for the player that received the last(!) lateral on a run play. If there were multiple laterals in the same play, this will only be the last player who received a lateral. Please see <https://github.com/mrcaseb/nfl-data/tree/master/data/lateral_yards> for a list of plays where multiple players recorded lateral rushing yards. | character | string |  |  | 2000, 2001, 2002, 2004, 2005 |
| lateral_rushing_yards | Numeric yards by the `lateral_rusher_player_name` in run plays with laterals. Please see the description of `lateral_rusher_player_name` for further information. | numeric | double |  |  | 2000, 2001, 2002, 2004, 2005 |
| lateral_sack_player_id | Unique identifier for the player that received the lateral on a sack. | character | string |  |  | none (entirely missing 2000-2005) |
| lateral_sack_player_name | String name for the player that received the lateral on a sack. | character | string |  |  | none (entirely missing 2000-2005) |
| interception_player_id | Unique identifier for the player that intercepted the pass. | character | string |  |  | 2000-2005 |
| interception_player_name | String name for the player that intercepted the pass. | character | string |  |  | 2000-2005 |
| lateral_interception_player_id | Unique indentifier for the player that received the lateral on an interception. | character | string |  |  | 2000-2005 |
| lateral_interception_player_name | String name for the player that received the lateral on an interception. | character | string |  |  | 2000-2005 |
| punt_returner_player_id | Unique identifier for the punt returner. | character | string |  |  | 2000-2005 |
| punt_returner_player_name | String name for the punt returner. | character | string |  |  | 2000-2005 |
| lateral_punt_returner_player_id | Unique identifier for the player that received the lateral on a punt return. | character | string |  |  | 2000-2005 |
| lateral_punt_returner_player_name | String name for the player that received the lateral on a punt return. | character | string |  |  | 2000-2005 |
| kickoff_returner_player_name | String name for the kickoff returner. | character | string |  |  | 2000-2005 |
| kickoff_returner_player_id | Unique identifier for the kickoff returner. | character | string |  |  | 2000-2005 |
| lateral_kickoff_returner_player_id | Unique identifier for the player that received the lateral on a kickoff return. | character | string |  |  | 2000-2005 |
| lateral_kickoff_returner_player_name | String name for the player that received the lateral on a kickoff return. | character | string |  |  | 2000-2005 |
| punter_player_id | Unique identifier for the punter. | character | string |  |  | 2000-2005 |
| punter_player_name | String name for the punter. | character | string |  |  | 2000-2005 |
| kicker_player_name | String name for the kicker on FG or kickoff. | character | string |  |  | 2000-2005 |
| kicker_player_id | Unique identifier for the kicker on FG or kickoff. | character | string |  |  | 2000-2005 |
| own_kickoff_recovery_player_id | Unique identifier for the player that recovered their own kickoff. | character | string |  |  | 2000-2005 |
| own_kickoff_recovery_player_name | String name for the player that recovered their own kickoff. | character | string |  |  | 2000-2005 |
| blocked_player_id | Unique identifier for the player that blocked the punt or FG. | character | string |  |  | 2000-2005 |
| blocked_player_name | String name for the player that blocked the punt or FG. | character | string |  |  | 2000-2005 |
| tackle_for_loss_1_player_id | Unique identifier for one of the potential players with the tackle for loss. | character | string |  |  | 2000, 2001, 2002 |
| tackle_for_loss_1_player_name | String name for one of the potential players with the tackle for loss. | character | string |  |  | 2000, 2001, 2002 |
| tackle_for_loss_2_player_id | Unique identifier for one of the potential players with the tackle for loss. | character | string |  |  | 2001, 2002 |
| tackle_for_loss_2_player_name | String name for one of the potential players with the tackle for loss. | character | string |  |  | 2001, 2002 |
| qb_hit_1_player_id | Unique identifier for one of the potential players that hit the QB. No sack as the QB was not the ball carrier. For sacks please see `sack_player` or `half_sack_*_player`. | character | string |  |  | 2000, 2001, 2002, 2003 |
| qb_hit_1_player_name | String name for one of the potential players that hit the QB. No sack as the QB was not the ball carrier. For sacks please see `sack_player` or `half_sack_*_player`. | character | string |  |  | 2000, 2001, 2002, 2003 |
| qb_hit_2_player_id | Unique identifier for one of the potential players that hit the QB. No sack as the QB was not the ball carrier. For sacks please see `sack_player` or `half_sack_*_player`. | character | string |  |  | 2000, 2001, 2002, 2003 |
| qb_hit_2_player_name | String name for one of the potential players that hit the QB. No sack as the QB was not the ball carrier. For sacks please see `sack_player` or `half_sack_*_player`. | character | string |  |  | 2000, 2001, 2002, 2003 |
| forced_fumble_player_1_team | Team of one of the players with a forced fumble. | character | string |  |  | 2000-2005 |
| forced_fumble_player_1_player_id | Unique identifier of one of the players with a forced fumble. | character | string |  |  | 2000-2005 |
| forced_fumble_player_1_player_name | String name of one of the players with a forced fumble. | character | string |  |  | 2000-2005 |
| forced_fumble_player_2_team | Team of one of the players with a forced fumble. | character | string |  |  | 2000-2005 |
| forced_fumble_player_2_player_id | Unique identifier of one of the players with a forced fumble. | character | string |  |  | 2000-2005 |
| forced_fumble_player_2_player_name | String name of one of the players with a forced fumble. | character | string |  |  | 2000-2005 |
| solo_tackle_1_team | Team of one of the players with a solo tackle. | character | string |  |  | 2000-2005 |
| solo_tackle_2_team | Team of one of the players with a solo tackle. | character | string |  |  | 2000-2005 |
| solo_tackle_1_player_id | Unique identifier of one of the players with a solo tackle. | character | string |  |  | 2000-2005 |
| solo_tackle_2_player_id | Unique identifier of one of the players with a solo tackle. | character | string |  |  | 2000-2005 |
| solo_tackle_1_player_name | String name of one of the players with a solo tackle. | character | string |  |  | 2000-2005 |
| solo_tackle_2_player_name | String name of one of the players with a solo tackle. | character | string |  |  | 2000-2005 |
| assist_tackle_1_player_id | Unique identifier of one of the players with a tackle assist. | character | string |  |  | 2000-2005 |
| assist_tackle_1_player_name | String name of one of the players with a tackle assist. | character | string |  |  | 2000-2005 |
| assist_tackle_1_team | Team of one of the players with a tackle assist. | character | string |  |  | 2000-2005 |
| assist_tackle_2_player_id | Unique identifier of one of the players with a tackle assist. | character | string |  |  | 2000-2005 |
| assist_tackle_2_player_name | String name of one of the players with a tackle assist. | character | string |  |  | 2000-2005 |
| assist_tackle_2_team | Team of one of the players with a tackle assist. | character | string |  |  | 2000-2005 |
| assist_tackle_3_player_id | Unique identifier of one of the players with a tackle assist. | character | string |  |  | none (entirely missing 2000-2005) |
| assist_tackle_3_player_name | String name of one of the players with a tackle assist. | character | string |  |  | none (entirely missing 2000-2005) |
| assist_tackle_3_team | Team of one of the players with a tackle assist. | character | string |  |  | none (entirely missing 2000-2005) |
| assist_tackle_4_player_id | Unique identifier of one of the players with a tackle assist. | character | string |  |  | none (entirely missing 2000-2005) |
| assist_tackle_4_player_name | String name of one of the players with a tackle assist. | character | string |  |  | none (entirely missing 2000-2005) |
| assist_tackle_4_team | Team of one of the players with a tackle assist. | character | string |  |  | none (entirely missing 2000-2005) |
| tackle_with_assist | Binary indicator for if there has been a tackle with assist. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| tackle_with_assist_1_player_id | Unique identifier of one of the players with a tackle with assist. | character | string |  |  | 2000-2005 |
| tackle_with_assist_1_player_name | String name of one of the players with a tackle with assist. | character | string |  |  | 2000-2005 |
| tackle_with_assist_1_team | Team of one of the players with a tackle with assist. | character | string |  |  | 2000-2005 |
| tackle_with_assist_2_player_id | Unique identifier of one of the players with a tackle with assist. | character | string |  |  | none (entirely missing 2000-2005) |
| tackle_with_assist_2_player_name | String name of one of the players with a tackle with assist. | character | string |  |  | none (entirely missing 2000-2005) |
| tackle_with_assist_2_team | Team of one of the players with a tackle with assist. | character | string |  |  | none (entirely missing 2000-2005) |
| pass_defense_1_player_id | Unique identifier of one of the players with a pass defense. | character | string |  |  | 2000-2005 |
| pass_defense_1_player_name | String name of one of the players with a pass defense. | character | string |  |  | 2000-2005 |
| pass_defense_2_player_id | Unique identifier of one of the players with a pass defense. | character | string |  |  | 2000-2005 |
| pass_defense_2_player_name | String name of one of the players with a pass defense. | character | string |  |  | 2000-2005 |
| fumbled_1_team | Team of one of the first player with a fumble. | character | string |  |  | 2000-2005 |
| fumbled_1_player_id | Unique identifier of the first player who fumbled on the play. | character | string |  |  | 2000-2005 |
| fumbled_1_player_name | String name of one of the first player who fumbled on the play. | character | string |  |  | 2000-2005 |
| fumbled_2_player_id | Unique identifier of the second player who fumbled on the play. | character | string |  |  | 2000-2005 |
| fumbled_2_player_name | String name of one of the second player who fumbled on the play. | character | string |  |  | 2000-2005 |
| fumbled_2_team | Team of one of the second player with a fumble. | character | string |  |  | 2000-2005 |
| fumble_recovery_1_team | Team of one of the players with a fumble recovery. | character | string |  |  | 2000-2005 |
| fumble_recovery_1_yards | Yards gained by one of the players with a fumble recovery. | numeric | double |  |  | 2000-2005 |
| fumble_recovery_1_player_id | Unique identifier of one of the players with a fumble recovery. | character | string |  |  | 2000-2005 |
| fumble_recovery_1_player_name | String name of one of the players with a fumble recovery. | character | string |  |  | 2000-2005 |
| fumble_recovery_2_team | Team of one of the players with a fumble recovery. | character | string |  |  | 2000-2005 |
| fumble_recovery_2_yards | Yards gained by one of the players with a fumble recovery. | numeric | double |  |  | 2000-2005 |
| fumble_recovery_2_player_id | Unique identifier of one of the players with a fumble recovery. | character | string |  |  | 2000-2005 |
| fumble_recovery_2_player_name | String name of one of the players with a fumble recovery. | character | string |  |  | 2000-2005 |
| sack_player_id | Unique identifier of the player who recorded a solo sack. | character | string |  |  | 2000-2005 |
| sack_player_name | String name of the player who recorded a solo sack. | character | string |  |  | 2000-2005 |
| half_sack_1_player_id | Unique identifier of the first player who recorded half a sack. | character | string |  |  | 2000-2005 |
| half_sack_1_player_name | String name of the first player who recorded half a sack. | character | string |  |  | 2000-2005 |
| half_sack_2_player_id | Unique identifier of the second player who recorded half a sack. | character | string |  |  | 2000-2005 |
| half_sack_2_player_name | String name of the second player who recorded half a sack. | character | string |  |  | 2000-2005 |
| return_team | String abbreviation of the return team. Returns may occur on any of: interception, fumble, kickoff, punt, or blocked kicks. | character | string |  | ARI, ATL, BAL, BUF, CAR, CHI, CIN, CLE, DAL, DEN, DET, GB, HOU, IND, JAX, KC, LA, LAC, LV, MIA, MIN, NE, NO, NYG, NYJ, PHI, PIT, SEA, SF, TB, TEN, WAS | 2000-2005 |
| return_yards | Yards gained by the return team. Returns may occur on any of: interception, fumble, kickoff, punt, or blocked kicks. | numeric | double |  |  | 2000-2005 |
| penalty_team | String abbreviation of the team with the penalty. | character | string |  | ARI, ATL, BAL, BUF, CAR, CHI, CIN, CLE, DAL, DEN, DET, GB, HOU, IND, JAX, KC, LA, LAC, LV, MIA, MIN, NE, NO, NYG, NYJ, PHI, PIT, SEA, SF, TB, TEN, WAS | 2000-2005 |
| penalty_player_id | Unique identifier for the player with the penalty. | character | string |  |  | 2000-2005 |
| penalty_player_name | String name for the player with the penalty. | character | string |  |  | 2000-2005 |
| penalty_yards | Yards gained (or lost) by the posteam from the penalty. | numeric | double |  |  | 2000-2005 |
| replay_or_challenge | Binary indicator for whether or not a replay or challenge. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| replay_or_challenge_result | String indicating the result of the replay or challenge. | character | string |  | denied, reversed, upheld | 2000-2005 |
| penalty_type | String indicating the penalty type of the first penalty in the given play. Will be `NA` if `desc` is missing the type. | character | string |  | Chop Block, Clipping, Defensive 12 On-field, Defensive Delay of Game, Defensive Holding, Defensive Offside, Defensive Pass Interference, Delay of Game, Disqualification, Encroachment, Face Mask, Face Mask (5 Yards), Fair Catch Interference, False Start, Illegal Bat, Illegal Block Above the Waist, Illegal Contact, Illegal Crackback, Illegal Cut, Illegal Formation, Illegal Forward Pass, Illegal Kick, Illegal Motion, Illegal Procedure, Illegal Receiver Pass, Illegal Scrimmage Kick, Illegal Shift, Illegal Substitution, Illegal Touch Kick, Illegal Touch Pass, Illegal Use of Hands, Ineligible Downfield Kick, Ineligible Downfield Pass, Intentional Grounding, Interference with Opportunity to Catch, Invalid Fair Catch Signal, Kickoff Out of Bounds, Leaping, Leverage, Low Block, Neutral Zone Infraction, Offensive 12 On-field, Offensive Holding, Offensive Offside, Offensive Pass Interference, Offside on Free Kick, Personal Foul, Player Out of Bounds on Punt, Roughing the Kicker, Roughing the Passer, Running Into the Kicker, Short Free Kick, Taunting, Tripping, Unnecessary Roughness, Unsportsmanlike Conduct | 2000-2005 |
| defensive_two_point_attempt | Binary indicator whether or not the defense was able to have an attempt on a two point conversion, this results following a turnover. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| defensive_two_point_conv | Binary indicator whether or not the defense successfully scored on the two point conversion. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| defensive_extra_point_attempt | Binary indicator whether or not the defense was able to have an attempt on an extra point attempt, this results following a blocked attempt that the defense recovers the ball. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| defensive_extra_point_conv | Binary indicator whether or not the defense successfully scored on an extra point attempt. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| safety_player_name | String name for the player who scored a safety. | character | string |  |  | 2000-2005 |
| safety_player_id | Unique identifier for the player who scored a safety. | character | string |  |  | 2000-2005 |
| season | 4 digit number indicating to which season the game belongs to. | numeric | int32 | Four-digit season year; January/February games carry the prior calendar year. |  | 2000-2005 |
| cp | Numeric value indicating the probability for a complete pass based on comparable game situations. | numeric | double |  |  | none (entirely missing 2000-2005) |
| cpoe | For a single pass play this is 1 - cp when the pass was completed or 0 - cp when the pass was incomplete. Analyzed for a whole game or season an indicator for the passer how much over or under expectation his completion percentage was. | numeric | double |  |  | none (entirely missing 2000-2005) |
| series | Starts at 1, each new first down increments, numbers shared across both teams NA: kickoffs, extra point/two point conversion attempts, non-plays, no posteam | numeric | double |  |  | 2000-2005 |
| series_success | 1: scored touchdown, gained enough yards for first down. | numeric | double |  |  | 2000-2005 |
| series_result | Possible values: First down, Touchdown, Opp touchdown, Field goal, Missed field goal, Safety, Turnover, Punt, Turnover on downs, QB kneel, End of half | character | string |  | End of half, Field goal, First down, Missed field goal, Opp touchdown, Punt, QB kneel, Safety, Touchdown, Turnover, Turnover on downs | 2000-2005 |
| order_sequence | Column provided by NFL to fix out-of-order plays. Available 2011 and beyond with source "nfl". | numeric | double |  |  | 2001, 2002, 2003, 2004, 2005 |
| start_time | Kickoff time in eastern time zone. | character | string | Text kickoff time as recorded in the source feed. |  | 2001, 2002, 2003, 2004, 2005 |
| time_of_day | Time of day of play in UTC "HH:MM:SS" format. Available 2011 and beyond with source "nfl". | character | string | Text UTC time of day of the play as recorded in the source feed. |  | 2001, 2002, 2003, 2004, 2005 |
| stadium | Game site name. | character | string | Free-text stadium name. |  | 2001, 2002, 2003, 2004, 2005 |
| weather | String describing the weather including temperature, humidity and wind (direction and speed). Doesn't change during the game! | character | string | Free-text weather string (temperature, humidity, wind); constant within game. |  | 2001, 2002, 2003, 2004, 2005 |
| nfl_api_id | UUID of the game in the new NFL API. | character | string |  |  | 2001, 2002, 2003, 2004, 2005 |
| play_clock | Time on the playclock when the ball was snapped. | character | string |  |  | 2001, 2002, 2003, 2004, 2005 |
| play_deleted | Binary indicator for deleted plays. | numeric | double | Binary indicator coded 1/0. |  | 2001, 2002, 2003, 2004, 2005 |
| play_type_nfl | Play type as listed in the NFL source. Slightly different to the regular play_type variable. | character | string |  | COMMENT, END_GAME, END_QUARTER, FIELD_GOAL, FREE_KICK, FUMBLE_RECOVERED_BY_OPPONENT, GAME_START, INTERCEPTION, KICK_OFF, PASS, PAT2, PENALTY, PUNT, RUSH, SACK, TIMEOUT, UNSPECIFIED, XP_KICK | 2001, 2002, 2003, 2004, 2005 |
| special_teams_play | Binary indicator for whether play is special teams play from NFL source. Available 2011 and beyond with source "nfl". | numeric | double | Binary indicator coded 1/0. |  | 2001, 2002, 2003, 2004, 2005 |
| st_play_type | Type of special teams play from NFL source. Available 2011 and beyond with source "nfl". | character | string |  | PENALTY | 2001, 2002 |
| end_clock_time | Game time at the end of a given play. | character | string |  |  | 2001, 2002 |
| end_yard_line | String indicating the yardline at the end of the given play consisting of team half and yard line number. | character | string |  |  | 2001, 2002 |
| fixed_drive | Manually created drive number in a game. | numeric | double |  |  | 2000-2005 |
| fixed_drive_result | Manually created drive result. | character | string |  | End of half, Field goal, Missed field goal, Opp touchdown, Punt, Safety, Touchdown, Turnover, Turnover on downs | 2000-2005 |
| drive_real_start_time | Local day time when the drive started (currently not used by the NFL and therefore mostly 'NA'). | character | string |  |  | 2003, 2004, 2005 |
| drive_play_count | Numeric value of how many regular plays happened in a given drive. | numeric | double |  |  | 2000-2005 |
| drive_time_of_possession | Time of possession in a given drive. | character | string |  |  | 2000-2005 |
| drive_first_downs | Number of first downs in a given drive. | numeric | double |  |  | 2000-2005 |
| drive_inside20 | Binary indicator if the offense was able to get inside the opponents 20 yard line. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| drive_ended_with_score | Binary indicator the drive ended with a score. | numeric | double | Binary indicator coded 1/0. | 0, 1 | 2000-2005 |
| drive_quarter_start | Numeric value indicating in which quarter the given drive has started. | numeric | double |  |  | 2000-2005 |
| drive_quarter_end | Numeric value indicating in which quarter the given drive has ended. | numeric | double |  |  | 2000-2005 |
| drive_yards_penalized | Numeric value of how many yards the offense gained or lost through penalties in the given drive. | numeric | double |  |  | 2001, 2002, 2003, 2004, 2005 |
| drive_start_transition | String indicating how the offense got the ball. | character | string |  | BLOCKED_FG, BLOCKED_FG,_DOWNS, BLOCKED_FG_DOWNS, BLOCKED_PUNT, BLOCKED_PUNT,_DOWNS, BLOCKED_PUNT_DOWNS, Blocked FG, Blocked FG, Downs, Blocked Punt, Blocked Punt, Downs, DOWNS, Downs, End of Half, FUMBLE, Field Goal, Fumble, INTERCEPTION, Interception, KICKOFF, MISSED_FG, MUFFED_KICKOFF, MUFFED_PUNT, Missed FG, ONSIDE_KICK, OWN_KICKOFF, PUNT, Punt, Safety, Touchdown, UNKNOWN | 2000-2005 |
| drive_end_transition | String indicating how the offense lost the ball. | character | string |  | BLOCKED_FG, BLOCKED_FG,_DOWNS, BLOCKED_FG_DOWNS, BLOCKED_PUNT, BLOCKED_PUNT,_DOWNS, BLOCKED_PUNT_DOWNS, Blocked FG, Blocked FG, Downs, Blocked Punt, Blocked Punt, Downs, DOWNS, Downs, END_GAME, END_HALF, End of Game, End of Half, FIELD_GOAL, FUMBLE, FUMBLE,_SAFETY, FUMBLE_SAFETY, Field Goal, Fumble, INTERCEPTION, Interception, MISSED_FG, Missed FG, PUNT, Punt, SAFETY, Safety, TOUCHDOWN, Touchdown, UNKNOWN | 2000-2005 |
| drive_game_clock_start | Game time at the beginning of a given drive. | character | string |  |  | 2000-2005 |
| drive_game_clock_end | Game time at the end of a given drive. | character | string |  |  | 2000-2005 |
| drive_start_yard_line | String indicating where a given drive started consisting of team half and yard line number. | character | string |  |  | 2000-2005 |
| drive_end_yard_line | String indicating where a given drive ended consisting of team half and yard line number. | character | string |  |  | 2000-2005 |
| drive_play_id_started | Play_id of the first play in the given drive. | numeric | double |  |  | 2000-2005 |
| drive_play_id_ended | Play_id of the last play in the given drive. | numeric | double |  |  | 2000-2005 |
| away_score | Total points scored by the away team. | numeric | int32 | Final away team points. |  | 2000-2005 |
| home_score | Total points scored by the home team. | numeric | int32 | Final home team points. |  | 2000-2005 |
| location | Either 'Home' o 'Neutral' indicating if the home team played at home or at a neutral site. | character | string | Coded: Home or Neutral. | Home, Neutral | 2000-2005 |
| result | Equals home_score - away_score and means the game outcome from the perspective of the home team. | numeric | int32 | Home points minus away points at game end. |  | 2000-2005 |
| total | Equals home_score + away_score and means the total points scored in the given game. | numeric | int32 | Home points plus away points at game end. |  | 2000-2005 |
| spread_line | The closing spread line for the game. A positive number means the home team was favored by that many points, a negative number means the away team was favored by that many points. (Source: Pro-Football-Reference) | numeric | double | Closing point spread, in points, from the home team's perspective (provider definition: positive = home team favored). |  | 2000-2005 |
| total_line | The closing total line for the game. (Source: Pro-Football-Reference) | numeric | double | Closing over/under total, in points. |  | 2000-2005 |
| div_game | Binary indicator for if the given game was a division game. | numeric | int32 | Binary 1/0 indicator of a division game. |  | 2000-2005 |
| roof | One of 'dome', 'outdoors', 'closed', 'open' indicating indicating the roof status of the stadium the game was played in. (Source: Pro-Football-Reference) | character | string | Coded: dome, outdoors, closed, open (provider definition). | closed, dome, open, outdoors | 2000-2005 |
| surface | What type of ground the game was played on. (Source: Pro-Football-Reference) | character | string | Free-text/coded playing-surface type (provider definition). | astroplay, astroturf, dessograss, fieldturf, grass, sportturf | 2000-2005 |
| temp | The temperature at the stadium only for 'roof' = 'outdoors' or 'open'.(Source: Pro-Football-Reference) | numeric | int32 | Degrees Fahrenheit; populated only for roof outdoors/open per provider definition. |  | 2000-2005 |
| wind | The speed of the wind in miles/hour only for 'roof' = 'outdoors' or 'open'. (Source: Pro-Football-Reference) | numeric | int32 | Miles per hour; populated only for roof outdoors/open per provider definition. |  | 2000-2005 |
| home_coach | First and last name of the home team coach. (Source: Pro-Football-Reference) | character | string |  |  | 2000-2005 |
| away_coach | First and last name of the away team coach. (Source: Pro-Football-Reference) | character | string |  |  | 2000-2005 |
| stadium_id | ID of the stadium the game was played in. (Source: Pro-Football-Reference) | character | string | Pro-Football-Reference stadium identifier. |  | 2000-2005 |
| game_stadium | Name of the stadium the game was played in. (Source: Pro-Football-Reference) | character | string | Free-text stadium name. |  | 2000-2005 |
| aborted_play | Binary indicator if the play description indicates "Aborted". | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| success | Binary indicator wheter epa > 0 in the given play. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| passer | Name of the dropback player (scrambles included) including plays with penalties. | character | string |  |  | 2000-2005 |
| passer_jersey_number | Jersey number of the passer. | numeric | int32 |  |  | 2001, 2002, 2003, 2004, 2005 |
| rusher | Name of the rusher (no scrambles) including plays with penalties. | character | string |  |  | 2000-2005 |
| rusher_jersey_number | Jersey number of the rusher. | numeric | int32 |  |  | 2001, 2002, 2003, 2004, 2005 |
| receiver | Name of the receiver including plays with penalties. | character | string |  |  | 2000-2005 |
| receiver_jersey_number | Jersey number of the receiver. | numeric | int32 |  |  | 2001, 2002, 2003, 2004, 2005 |
| pass | Binary indicator if the play was a pass play (sacks and scrambles included). | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| rush | Binary indicator if the play was a rushing play. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| first_down | Binary indicator if the play ended in a first down. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| special | Binary indicator if "play_type" is one of "extra_point", "field_goal", "kickoff", or "punt". | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| play | Binary indicator: 1 if the play was a 'normal' play (including penalties), 0 otherwise. | numeric | double | Binary indicator coded 1/0. |  | 2000-2005 |
| passer_id | ID of the player in the 'passer' column. | character | string |  |  | 2000-2005 |
| rusher_id | ID of the player in the 'rusher' column. | character | string |  |  | 2000-2005 |
| receiver_id | ID of the player in the 'receiver' column. | character | string |  |  | 2000-2005 |
| name | Name of the 'passer' if it is not 'NA', or name of the 'rusher' otherwise. | character | string |  |  | 2000-2005 |
| jersey_number | Jersey number of the player listed in the 'name' column. | numeric | int32 |  |  | 2001, 2002, 2003, 2004, 2005 |
| id | ID of the player in the 'name' column. | character | string |  |  | 2000-2005 |
| fantasy_player_name | Name of the rusher on rush plays or receiver on pass plays (from official stats). | character | string |  |  | 2000-2005 |
| fantasy_player_id | ID of the rusher on rush plays or receiver on pass plays (from official stats). | character | string |  |  | 2000-2005 |
| fantasy | Name of the rusher on rush plays or receiver on pass plays. | character | string |  |  | 2000-2005 |
| fantasy_id | ID of the rusher on rush plays or receiver on pass plays. | character | string |  |  | 2000-2005 |
| out_of_bounds | 1 if play description contains ran ob, pushed ob, or sacked ob; 0 otherwise. | numeric | double |  |  | 2000-2005 |
| home_opening_kickoff | 1 if the home team received the opening kickoff, 0 otherwise. | numeric | double |  |  | 2000-2005 |
| qb_epa | Gives QB credit for EPA for up to the point where a receiver lost a fumble after a completed catch and makes EPA work more like passing yards on plays with fumbles. | numeric | double |  |  | 2000-2005 |
| xyac_epa | Expected value of EPA gained after the catch, starting from where the catch was made. Zero yards after the catch would be listed as zero EPA. | numeric | double |  |  | none (entirely missing 2000-2005) |
| xyac_mean_yardage | Average expected yards after the catch based on where the ball was caught. | numeric | double |  |  | none (entirely missing 2000-2005) |
| xyac_median_yardage | Median expected yards after the catch based on where the ball was caught. | numeric | double |  |  | none (entirely missing 2000-2005) |
| xyac_success | Probability play earns positive EPA (relative to where play started) based on where ball was caught. | numeric | double |  |  | none (entirely missing 2000-2005) |
| xyac_fd | Probability play earns a first down based on where the ball was caught. | numeric | double |  |  | none (entirely missing 2000-2005) |
| xpass | Probability of dropback scaled from 0 to 1. | numeric | double |  |  | none (entirely missing 2000-2005) |
| pass_oe | Dropback percent over expected on a given play scaled from 0 to 100. | numeric | double |  |  | none (entirely missing 2000-2005) |

## Games/schedules columns

| Column | Definition (provider) | Provider type | Stored type | Units / coding | Coding categories | Seasons with values (2000-2005) |
|---|---|---|---|---|---|---|
| game_id | A human-readable game ID. It consists of: the season, an underscore, the two-digit week number, an underscore, the away team, an underscore, the home team. This is the primary identifier for a given game and is also used in various nflverse dataframes. | numeric | string | Text 'SEASON_WW_AWAY_HOME'; joins to play-by-play game_id. |  | 2000-2005 |
| season | The year of the NFL season. This represents the whole season, so regular season games that happen in January as well as playoff games will occur in the year after this number. | numeric | int32 | Four-digit season year. |  | 2000-2005 |
| game_type | What type of game? One of REG, WC, DIV, CON, SB | character | string | Coded: REG, WC, DIV, CON, SB. | CON, DIV, REG, SB, WC | 2000-2005 |
| week | The week of the NFL season the game occurs in. Please note that the `game_type` will differ for weeks >= 18 because of the season expansion in 2021. Please use `game_type` to filter for regular season or postseason. | numeric | int32 | Integer week; regular season 1-17 and postseason 18-21 for these seasons. |  | 2000-2005 |
| gameday | The date on which the game occurred. | character | string | Text date YYYY-MM-DD. |  | 2000-2005 |
| weekday | The day of the week on which the game occcured. | character | string | Day-of-week name. | Friday, Monday, Saturday, Sunday, Thursday | 2000-2005 |
| gametime | The kickoff time of the game. This is represented in 24-hour time and the Eastern time zone, regardless of what time zone the game was being played in. | character | string | Text kickoff time HH:MM (US Eastern per provider documentation). |  | 2000-2005 |
| away_team | The away team. | character | string | Team abbreviation of the time (see home_team). | ARI, ATL, BAL, BUF, CAR, CHI, CIN, CLE, DAL, DEN, DET, GB, HOU, IND, JAX, KC, MIA, MIN, NE, NO, NYG, NYJ, OAK, PHI, PIT, SD, SEA, SF, STL, TB, TEN, WAS | 2000-2005 |
| away_score | The number of points the away team scored. Is NA for games which haven't yet been played. | numeric | int32 |  |  | 2000-2005 |
| home_team | The home team. Note that this contains the designated home team for games which no team is playing at home such as Super Bowls or NFL International games. | character | string | Team abbreviation of the time (e.g. STL, SD, OAK), unlike the play-by-play team columns. | ARI, ATL, BAL, BUF, CAR, CHI, CIN, CLE, DAL, DEN, DET, GB, HOU, IND, JAX, KC, MIA, MIN, NE, NO, NYG, NYJ, OAK, PHI, PIT, SD, SEA, SF, STL, TB, TEN, WAS | 2000-2005 |
| home_score | The number of points the home team scored. Is NA for games which haven't yet been played. | numeric | int32 |  |  | 2000-2005 |
| location | Either Home if the home team is playing in their home stadium, or Neutral if the game is being played at a neutral location. This still shows as Home for games between the Giants and Jets even though they share the same home stadium. | character | string |  | Home, Neutral | 2000-2005 |
| result | The number of points the home team scored minus the number of points the visiting team scored. Equals h_score - v_score. Is NA for games which haven't yet been played. Convenient for evaluating against the spread bets. | numeric | int32 | home_score minus away_score. |  | 2000-2005 |
| total | The sum of each team's score in the game. Equals h_score + v_score. Is NA for games which haven't yet been played. Convenient for evaluating over/under total bets. | numeric | int32 | home_score plus away_score. |  | 2000-2005 |
| overtime | Binary indicator of whether or not game went to overtime. | numeric | int32 | Binary 1/0 indicator that the game went to overtime. | 0, 1 | 2000-2005 |
| old_game_id | The old id for the game assigned by the NFL. | numeric | string | Ten-digit legacy NFL game identifier; joins to play-by-play old_game_id. |  | 2000-2005 |
| gsis | The id of the game issued by the NFL Game Statistics & Information System. | numeric | int32 |  |  | 2000-2005 |
| nfl_detail_id | The id of the game issued by NFL Detail. | numeric | string |  |  | none (entirely missing 2000-2005) |
| pfr | The id of the game issued by [Pro-Football-Reference](https://www.pro-football-reference.com/) | numeric | string |  |  | 2000-2005 |
| pff | The id of the game issued by [Pro Football Focus](https://www.pff.com/) | numeric | int32 |  |  | none (entirely missing 2000-2005) |
| espn | The id of the game issued by [ESPN](https://www.espn.com/) | numeric | string |  |  | 2000-2005 |
| ftn | (no provider definition) |  | int32 |  |  | none (entirely missing 2000-2005) |
| away_rest | Days of rest that the away team is coming off of. | numeric | int32 | Days of rest for the away team. |  | 2000-2005 |
| home_rest | Days of rest that the home team is coming off of. | numeric | int32 | Days of rest for the home team. |  | 2000-2005 |
| away_moneyline | Odds for away team to win the game. | numeric | int32 | American-odds moneyline. |  | none (entirely missing 2000-2005) |
| home_moneyline | Odds for home team to win the game. | numeric | int32 | American-odds moneyline. |  | none (entirely missing 2000-2005) |
| spread_line | The spread line for the game. A positive number means the home team was favored by that many points, a negative number means the away team was favored by that many points. This lines up with the result column. | numeric | double | Point spread in points; positive means the home team is favored (provider definition). |  | 2000-2005 |
| away_spread_odds | Odds for away team to cover the spread. | numeric | int32 | American odds on the spread. |  | none (entirely missing 2000-2005) |
| home_spread_odds | Odds for home team to cover the spread. | numeric | int32 | American odds on the spread. |  | none (entirely missing 2000-2005) |
| total_line | The total line for the game. | numeric | double | Over/under total in points. |  | 2000-2005 |
| under_odds | Odds that total score of game would be under the total_line. | numeric | int32 | American odds on the under. |  | none (entirely missing 2000-2005) |
| over_odds | Odds that total score of game would be over the total_ine. | numeric | int32 | American odds on the over. |  | none (entirely missing 2000-2005) |
| div_game | Binary indicator of whether or not game was played by 2 teams in the same division. | numeric | int32 | Binary 1/0 indicator of a division game. | 0, 1 | 2000-2005 |
| roof | What was the status of the stadium's roof? One of outdoors, open, closed, dome | character | string | Coded: outdoors, open, closed, dome. | closed, dome, open, outdoors | 2000-2005 |
| surface | What type of ground the game was played on | character | string |  | astroplay, astroturf, dessograss, fieldturf, grass, sportturf | 2000-2005 |
| temp | The temperature at the stadium (for outdoors and open only) | numeric | int32 | Degrees Fahrenheit (outdoors/open only). |  | 2000-2005 |
| wind | The speed of the wind in miles/hour (for outdoors and open only) | numeric | int32 | Miles per hour (outdoors/open only). |  | 2000-2005 |
| away_qb_id | GSIS Player ID for away team starting quarterback. | numeric | string |  |  | 2000-2005 |
| home_qb_id | GSIS Player ID for home team starting quarterback. | numeric | string |  |  | 2000-2005 |
| away_qb_name | Name of away team starting QB. | character | string |  |  | 2000-2005 |
| home_qb_name | Name of home team starting QB. | character | string |  |  | 2000-2005 |
| away_coach | Name of the head coach of the away team | character | string |  |  | 2000-2005 |
| home_coach | Name of the head coach of the home team | character | string |  |  | 2000-2005 |
| referee | Name of the game's referee (head official) | character | string |  |  | 2000-2005 |
| stadium_id | ID of Stadium that game took place in | character | string |  |  | 2000-2005 |
| stadium | Name of the stadium | character | string |  |  | 2000-2005 |
