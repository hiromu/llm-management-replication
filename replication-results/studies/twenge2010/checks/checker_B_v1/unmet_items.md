- **§7, synthetic-data testing** — `code/analysis.R:489` runs `source("code/tests.R")` for `--test`, but `code/tests.R` does not exist in `code/`. No synthetic test with known structure is implemented in the delivered code.

- **§7, CLI must write `results/<spec_id>.json` and `results/influence_<start>_<end>.csv`** — `code/analysis.R:490-492` aborts every `--spec` and `--influence` run unless `code/TESTS.md` and `code/test_results.json` (with status ok) exist. Neither file is in `code/`, so the delivered code cannot produce any required output.

- **§7, README describing how to run** — `code/README.md:12,39,79-80` instruct the user to run `code/tests.R` (via `--test`) and `code/validate_outputs.R`, and reference `TESTS.md`, `test_results.json`, `VALIDATION.md`; none of these files are present in `code/`.

- **§5 S04 with §4.4 (d_obs)** — for S04 the code returns `d_obs` as NA and status `unavailable` whenever a respondent in the FIML sample has a missing factor item (`code/analysis.R:288-302`, `422-424`). The manifest requires all of §4.4 for S04 and provides no exemption for d_obs.

- **§3, sample V4 hash** — `code/analysis.R:25` hashes the sorted V4 list written by `writeLines`, which appends a newline after the last value. The manifest specifies the SHA-256 of a "newline-separated list", i.e. without a terminal newline; the hashed byte string therefore differs from the manifest's definition (interpretation difference, documented in README).