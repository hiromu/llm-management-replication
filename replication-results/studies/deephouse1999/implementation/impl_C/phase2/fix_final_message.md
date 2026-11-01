1. R02.no_special: Kept unavailable; dictionary lacks numeric codes. Documented in README’s “Checker items.”
2. R06.rck_days: Fixed to require all four quarters, with calendar-day weights and no 2170 fallback.
3. R09.analytic: Removed the 1984 exception; reports unavailable when fixed rows become undefined. All 20 synthetic tests passed; overwrote `tests/test_output.txt`.