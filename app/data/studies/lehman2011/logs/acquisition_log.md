# Source acquisition log

Role: source acquisition (coordinator subagent). Date: 2026-10-27 (UTC). All paths are relative to the study root.
No sample selection or filtering was applied. Complete season files were acquired.

## Sources

- nflverse/nflverse-data GitHub release `pbp`: play_by_play_YYYY.parquet and .csv.gz for 2000-2005 (analysis inputs). The 2022-07-28 zip assets of the same release were also downloaded as an older-vintage cross-check only.
- nflverse/nflverse-data GitHub release `schedules`: games.parquet and games.csv (game-level metadata, including roof, surface, temp, wind and stadium).
- nflverse/nfldata repository, pinned commit 20cdb994b1342f5504065ac75859a02be1f4f905: data/games.csv, as a second distribution of the schedule data for cross-checking.
- Dictionaries: nflreadr data-raw/dictionary_pbp.csv and dictionary_schedules.csv (commit 23f915a5be30415aeaa0c5c80cd23b2c69cda122), nflfastR data/field_descriptions.rda (commit 701bbf38bc1c030ff9f1f4825a23191287d3903c), the rendered nflreadr dictionary pages, and the licence files.
- Licence: nflverse-data is CC-BY-4.0 (GitHub licence API). nflreadr and nflfastR are MIT. nfldata declares no licence; it is public and used only for cross-checks. No account, payment or access-control bypass was involved.
- No author replication package was looked for or used. No data printed in research articles was used.

## Steps and commands

1. Survey (scratchpad only): `curl` against the GitHub API for the release `pbp`, release `schedules`, release `misc`, the repository licences, the commit SHAs of nflreadr/nflfastR/nfldata, and the nflreadr/nflfastR repository trees to locate the dictionary files. `nflverse/nflfastR-data` now redirects to `nflverse/nflverse-pbp`, which holds build code and no season data files, so no older data were taken from it.
2. Download: `bash data/scripts/download.sh`. Each logical download went into its own new directory stamped 20261027T113315Z:
   - data/raw/nflverse/pbp_release_20261027T113315Z/
   - data/raw/nflverse/pbp_release_zip2022_20261027T113315Z/
   - data/raw/nflverse/schedules_release_20261027T113315Z/
   - data/raw/nfldata/games_csv_20261027T113315Z/
   - data/raw/nflverse/dictionaries_20261027T113315Z/

   Every request is logged in data/raw/download_log.tsv with the UTC time, URL, local path, HTTP code, bytes and curl exit code. The GitHub release API JSON was saved next to the files as a vintage snapshot.
3. Read-only: `find data/raw/nflverse data/raw/nfldata -type f -exec chmod a-w {} +`. The permission system refused a later `chmod a-w data/raw/download_log.tsv`, so that log file is still writable. Nothing was executed from the raw directories. Python ran with `-I` and took paths as arguments. The .rda dictionary was opened with R `load()` into an isolated environment by data/scripts/export_field_descriptions.R and exported to data/derived/dictionary_sources/nflfastR_field_descriptions.csv.
4. Loader check:
   - `python -I data/scripts/loader_check_py.py <root> registry/loader_check_parts/python.json`
   - `Rscript --vanilla data/scripts/loader_check_r.R <root> registry/loader_check_parts/r.json`
   - `python -I data/scripts/loader_check_compare.py ... registry/loader_check.json`
5. Registry: `python -I data/scripts/build_registry.py <root>` produces registry/source_registry.json.
6. Dictionary: `python -I data/scripts/build_dictionary.py <root>` produces registry/data_dictionary.md and registry/data_dictionary.json.

## Software

- macOS 26.6.2 (arm64). curl 8.7.1 (system).
- Python 3.13.4 (~/.venv/bin/python), pandas 2.2.3, numpy 2.4.2, pyarrow 26.0.0.
- R 4.6.1 (2026-06-24) (/opt/homebrew/bin/Rscript), nanoparquet 0.5.2, data.table 1.18.6.1, R.utils 2.13.0, digest 0.6.39, jsonlite 2.0.0.

## Installations (logged as required)

- pyarrow was not installed in the venv. The venv's Python cannot load its `ssl` module: _ssl links to /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib, which is missing. `python -m pip install pyarrow` therefore failed with an SSL error. I downloaded the wheel pyarrow-26.0.0-cp313-cp313-macosx_12_0_arm64.whl from files.pythonhosted.org with curl, checked its sha256 (a6ca849f90cf73fe361f08a5762c783ead9671e4548c1f558cc637b54c9103f2) against the PyPI JSON API and installed it with `~/.venv/bin/python -m pip install --no-index --no-deps <wheel>`. No other Python packages changed. Because Python has no SSL, all downloads used curl.
- R package nanoparquet 0.5.2 was installed from CRAN (https://cloud.r-project.org, source build) into /opt/homebrew/lib/R/4.6/site-library so that R could read the parquet files. arrow was not installed.

## Loader-check result

- For every season 2000-2005, Python reading the parquet, Python reading the csv.gz, R reading the parquet and R reading the csv.gz give the same row count, the same column count (372), the same hash of the ordered column names and the same sha256 of a canonical rendering of 19 key columns. In Python, all 372 columns of the parquet and csv.gz files are equal (floats with 1e-9 tolerance). The games files (release parquet, release csv, nfldata csv) also agree between Python and R. The nfldata copy equals the release copy in every column for seasons 2000-2005. Overall Python-R agreement: true. Details are in registry/loader_check.json.
- CSV convention, found during the check: the nflverse CSV files write missing values as an unquoted empty field and empty strings as a quoted "". The first comparisons used readers that treated both as missing, or `fread`'s default whitespace stripping, and these failed on string columns that contain empty strings (e.g. posteam, play_type, roof, surface). The final readers keep the distinction: Python uses pyarrow.csv with quoted_strings_can_be_null=False; R uses `fread(na.strings = c("NA", ""), strip.white = FALSE)`. All earlier check outputs were overwritten in registry/loader_check_parts/. Only the final files are kept.
- The 2022 zip vintage has the same 372 column names but different row counts in every season. Its key-column hashes differ from the current files. It is kept for reference only.

## Findings and gaps relevant to later roles (no analysis performed)

- Mixed vintages within the pbp release: 2000 was built 2025-07-16 with nflfastR 5.1.0.9001, 2001-2002 on 2026-08-13 with nflfastR 5.2.0.9015, and 2003-2005 on 2025-04-30 with nflfastR 5.0.0.9005. The column type of goal_to_go differs: double in 2000-2002, int32 in 2003-2005. GitHub sha256 digests are published and match for the 2000-2002 pbp assets and for the schedules assets. The 2003-2005 assets have no published digest; their local sha256 is recorded.
- Each season file contains both regular-season and postseason plays (season_type REG/POST). Regular-season weeks are 1-17 and postseason weeks are 18-21.
- Coverage gap: two regular-season 2000 games in the schedules file have no play-by-play rows: 2000_03_SD_KC (old_game_id 2000091709) and 2000_06_BUF_MIA (2000100800). They are also missing from the 2022 vintage. All other games from 2000-2005 link one-to-one between the two files on game_id and old_game_id.
- Team abbreviations: the play-by-play team columns use current franchise codes (LA, LAC, LV). game_id and the games file use the codes in use at the time (STL, SD, OAK).
- Weather and venue: the play-by-play `weather` text column, together with stadium, start_time and several other feed fields, is entirely missing for 2000. roof, surface, temp, wind (temp and wind for outdoors/open roofs only, per provider), stadium_id and game_stadium are present for 2000-2005 in the play-by-play and the games file. Betting odds columns (moneylines, spread/total odds), nfl_detail_id, pff and ftn are entirely missing in the games file for 2000-2005. spread_line and total_line are present.
- 47 play-by-play columns are entirely missing in 2000-2005, mostly air-yards, YAC, completion-probability and expected-pass model columns plus some player-id columns. 30 more are entirely missing in some of these seasons. The lists are in registry/data_dictionary.md.
- Definitional conflict: total_home_score and total_away_score are "at the start of the play" in the nflreadr dictionary and "at the end of the play" in nflfastR field_descriptions. This was not resolved at acquisition.
- Second sources: Pro-Football-Reference was not accessed because its terms restrict scraping. Raw Game Center JSON (nflverse/nflfastR-raw) exists publicly but was not downloaded.

## Problems encountered

- The venv's Python has no SSL support (see Installations).
- data/games.md in nfldata returned HTTP 404 at the pinned commit (logged as a failed attempt; no file kept).
- The permission system refused one combined heredoc-and-execute shell command; the script was then written with the file tool and run separately. It also refused `chmod a-w` on data/raw/download_log.tsv.

## Follow-up: season-specific team conference/division crosswalk (2026-10-27, about 12:16Z)

Task: build a team-season conference and division crosswalk for 2000-2005 from public records, then validate it against the games file.

Source search
- nflverse/nfldata data/standings.csv (commit 20cdb994) has season-specific conf and division for each team, but only from 2002. data/teams.csv also starts in 2002.
- The nflverse-data "teams" release (teams_colors_logos) carries current divisions only. The other nflverse-data releases (stats_team, schedules and others) have no conference or division field.
- No nflverse file covers 2000-2001. For those seasons I used English Wikipedia, the "<season> <conf> <region> standings" templates that the season articles transclude. Each template is pinned to a revision id (oldid), fetched as raw wikitext, and is under licence CC BY-SA 4.0.

Downloads
- `bash data/scripts/download_alignment.sh` saved:
  - nfldata standings.csv and teams.csv to data/raw/nfldata/standings_csv_20261027T121608Z/;
  - the six 2000-2005 season articles at pinned revisions, plus the API revision metadata, to data/raw/wikipedia/nfl_season_wikitext_20261027T121608Z/.
- `bash data/scripts/download_alignment_templates.sh` saved the 44 division standings templates (12 for 2000-2001, 32 for 2002-2005), each pinned to its current revision id through the MediaWiki API, to data/raw/wikipedia/nfl_division_standings_templates_20261027T121639Z/.
- All requests are logged in data/raw/download_log_alignment.tsv. There were no failed requests. Every raw file was made read-only. The new TSV log is still writable, like the original log.
- `python -I data/scripts/append_registry_alignment.py <root>` appended 55 file entries to registry/source_registry.json, with provider, URL, commit or revision, retrieval time, licence, bytes and sha256. It also added an "alignment_acquisition" note. I checked that the existing entries are byte-for-byte unchanged.

Construction
- `python -I data/scripts/build_alignment.py <root>` wrote registry/team_season_alignment.csv: 190 rows, 31 teams in each of 2000-2001 and 32 in each of 2002-2005.
- Source by season: 2002-2005 come from nfldata standings.csv, reading only the season, conf, division and team columns. 2000-2001 come from the Wikipedia templates, reading the division header and the team-season links.
- Wikipedia full team names are mapped to abbreviations through nfldata teams.csv, ignoring periods ("St. Louis Rams" matches "St Louis Rams").
- team_abbr_pbp comes from joining the games-file and play-by-play home/away codes on game_id within each season. The only differences are STL to LA, SD to LAC and OAK to LV, in every season.
- Structure: 6 divisions in 2000-2001 (5 or 6 teams each) and 8 divisions of 4 in 2002-2005. The team set equals the games-file team set in every season. Houston first appears in 2002.
- Cross-check: for 2002-2005, nfldata and Wikipedia agree on all 128 team-seasons.

Validation (registry/team_season_alignment_check.json)
- Rule: for 2000-2005 regular-season games, div_game == 1 requires the two teams to share a division that season, and div_game == 0 requires different divisions.
- Result: 1520 regular-season games, 1520 agreements, 0 mismatches. No game had a missing div_game, and no team was missing from the crosswalk.

Dictionary
- data/scripts/build_dictionary.py now adds a section for the crosswalk columns, with definitions and coding categories only. registry/data_dictionary.md and .json were regenerated. Apart from the new section and the creation time, their content is unchanged.
