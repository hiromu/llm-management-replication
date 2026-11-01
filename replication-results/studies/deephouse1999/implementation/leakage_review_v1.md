# Leakage scan review v1

Scan: implementation/build_bundle.py over every .md/.json file in implementation/bundle_v1 (identity strings and all published target numbers of 3+ digits from both readers' sealed targets, plus N, bank count, SSE, F, residual and condition values).

Hits: 1.
- docs/data_dictionary.md "Rows: 159" for county_fips_mn_wi (Minnesota 87 + Wisconsin 72 counties). Reviewed false positive: a genuine data-structure constant that happens to equal a printed count. Retained unchanged.

The named outlier is given to implementers only as RSSD9001 995151 and year 1987 (no name). The market is given as area code 5120 county lists (data-defined). No article title, author, journal, hypothesis wording or result appears in the bundle.
