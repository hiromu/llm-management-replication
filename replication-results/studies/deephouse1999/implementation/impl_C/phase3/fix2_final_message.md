- C1: Made the county lookup file optional except for name lookups.
- C2: Excluded RSSD9425 codes {1,2,4,9}; missing values count as 0.
- C3: Preserved origin filters for savings records; logged zero admissions.
- C4: Required four quarterly values with RCFD→RCON fallback and calendar-day weights.
- C5: Added exact 1984 lag sources; dropped and logged undefined rebuilt rows.
- C6: Back-transformed centered M2/M3; marked centered M3_SQ `not_applicable`.
- C7: Used explicit calendar-year predecessors; tested gaps.
- C8: Distinguished unavailable inputs from runtime failures; verified fixed-effect coefficient exports.
- Checker 1: Fixed the mandatory county-file dependency; documented in README.
- Checker 2: Fixed O_A savings entity filtering; documented in README.
- Checker 3: Enabled analytic-reference fits at both origins; documented in README.

All 25 synthetic tests passed; `tests/test_output.txt` overwritten. No internet or real-data model fitting used.