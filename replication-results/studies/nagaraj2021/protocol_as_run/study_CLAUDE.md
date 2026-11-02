# Nagaraj (2021) — independent study

This session is exclusively for Nagaraj (2021), study nagaraj2021. The project-root CLAUDE.md and instructions/ files govern this study, and this file takes precedence over them. Resolve the project root as ../.. when this folder is opened directly. Read STUDY.json for the article, deposit and setup record, and ../../config/roles_nagaraj2021.json for the models. Deliver this study's artifacts and stop.

Do not start readers, run models or fit anything until the user authorizes research in this session. Do not read anything in sealed/author_package/ or sealed/setup_exposure_detail.txt before the unsealing point in shared_data.md. Do not inspect other studies or projects. An earlier replication of this paper, run with the author code readable, exists elsewhere on this machine: never look for it or use it. Use study-relative outputs and immutable run directories.

## Inputs
- data/raw/osf_a47e9/rawdata/: the 14 deposited data files. Hashes are in logs/osf_receipt.json.
- data/raw/osf_a47e9/writing/appendix.pdf: the online appendix, as deposited.
- data/raw/census_tiger2010/: the Census TIGER/Line 2010 county file, for county maps and any county geometry the methods need. Hash in logs/tiger_receipt.json.
- packet/nagaraj2021.pdf: the article.
- packet/deposit_data_notes.txt: the Rawdata section of the deposit Readme, extracted verbatim by logs/extract_data_notes.py. It is the only author description of the data files. The deposit has no variable dictionary.

No other data acquisition. Do not rebuild anything from OpenStreetMap history files: the deposited aggregates are the inputs.

## Sealed
sealed/author_package/ holds scripts/ (main.do, the project .ado files and bundled SSC .ado files), writing/figures_and_tables.tex and Readme.txt. The Readme maps each script to the tables and figures it makes, so it stays sealed apart from the extracted data notes. sealed/setup_exposure_detail.txt records one author-code detail the setup session learned; open it together with the author package.

## Reader packet
The article, the online appendix, packet/deposit_data_notes.txt, and the column names of each data file (variable names and labels for acs5year.dta). h12.csv has no header row: give readers its column count and each column's type, never values. Describe the TIGER file by its documented field names.

## Implementer bundle
Column 3 of h12.csv holds OpenStreetMap user names. Replace them with a stable pseudonymous code that preserves equality across rows, and never print the names or send them to a model. Check the other files for identifying free text and record what you change.

## Scope
Main-text Tables 1-7 and Figures 1-6. Online Appendices A-D are out of scope as targets; readers may use them for the methods of in-scope results. Figures 1 and 2 are county maps; Figures 3 to 6 plot estimates. Freeze before execution how figure targets are read (values printed in the figure or text, or values read from the plot with a reading interval) and how they are scored.

## Author code
The author code is Stata. Stata was not found on the setup machine. If Stata is unavailable for comparison 2, record that the author rerun could not be run. Do not translate the author code into another language as a substitute. Comparison 3 still reads the author code against the AI code.

## Limits the report must state
- The deposited data are the author's aggregates. quarterly.csv, h12.csv and tiger_census_2008q2.csv were computed from OpenStreetMap history files, and other files were pre-processed by the author (deposit_data_notes.txt marks them). The study tests reconstruction from these files, not from OpenStreetMap or Census sources.
- Some inputs cannot be rebuilt by anyone else: timing.xlsx came from the Census Bureau by personal communication, amenitycheck.csv from proprietary InfoUSA data, and distance.csv from 2017 Google Maps and OSRM queries.
- Readers, implementers, checkers and probes ran with Opus 5.5 fast mode and GPT-6 Astra Ultrafast at the user's request. These settings change speed and price, not the model. The coordinator and Reader A are the same model.

## Reporting adaptation
Follow the shared reporting requirements, adapting the preferred reconstruction and influence-checks figure to this article's estimands, such as difference-in-differences and cross-sectional coefficients. Label the effect scale and its null value. Before fitting, justify and freeze the influence-deletion unit and diagnostic scope from the study design. Retain all eligible fits and failures. Influence ranges are not confidence intervals or automatically equivalent specifications. Do not prescribe estimates, classifications, specification counts or sample decisions at setup.

## Setup drafts
setup_drafts/ holds unfrozen, untested drafts: run_role.py (role launcher with the requested speeds), build_reader_packet.py, reader_prompt_v1.md and probe_prompt.txt. Adopt or replace them and record which.
