# Scoring rules addendum v1.2

Written 2026-10-27 after the ORIGIN results of A and B existed and before any influence result existed. It changes only how rows are matched, not any criterion.

1. Influence rows are identified by a non-empty deleted_country and a run_id equal to "influence" in any letter case. The manifest did not fix the run_id label for influence rows; implementation A writes "INFLUENCE". Scorer v1.1 compared against lowercase "influence" and would have silently dropped every influence row. The superseded scorer is preserved at checks/versions/score_v1_1.py.
