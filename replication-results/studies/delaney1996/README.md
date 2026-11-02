# Delaney and Huselid (1996)

Delaney, J. T., and Huselid, M. A. (1996). The impact of human resource management practices on perceptions of organizational performance. *Academy of Management Journal*, 39(4), 949–969.

**Outcome:** Indeterminate. Both focal claims (H1, progressive HRM practices and perceived performance; H2, complementarities among practices) are indeterminate because the sample was not rebuilt: 361 and 239 organizations against 590 and 373 printed. Within the smaller samples, training is about twice its published size (0.239 against 0.125 in Table 3, model 2), and staffing selectivity is near zero for market performance (-0.013 against 0.145). The review traced most of the shortfall to three missing-data rules the article does not state. The 23 discrepancy candidates are pending human review; the adversarial review overturned 16 and left 7 uncertain.

**Common rule (post hoc):** indeterminate. Rescored with the rule shared by all six studies, written after the results were known; see [reports/common_rule_v1.md](reports/common_rule_v1.md). The outcome above is the protocol outcome under this study's frozen rules.

The findings are in [reports/replication_report.md](reports/replication_report.md) and the details in [reports/technical_supplement.md](reports/technical_supplement.md). The paper was rebuilt from the article text and original survey data only, without an author replication package.

## Data used

All survey data come from the National Organizations Survey, 1991 (ICPSR 6240, version 1), SPSS portable file DS0002: 727 establishment records, 1,016 variables. The user downloaded the bundle by hand; no agent logged in to ICPSR. ICPSR's terms of use do not allow redistribution, so no bundle, extract or synthetic copy derived from it is included.

The release has 1980 Census industry codes but no SIC codes. The source role downloaded the U.S. Census Bureau's 1980 industry list with 1972 SIC equivalents from census.gov to build the industry controls.

To rebuild, download ICPSR 6240 V1 with your own ICPSR account and check its MD5s against the ICPSR manifest. Provenance and the coverage audit: [registry/source_registry.json](registry/source_registry.json) and [registry/coverage_audit.md](registry/coverage_audit.md).

## What this copy leaves out

This is a public copy of the run record. It contains no data and no copy of the article.

- `data/` is not included. In the original run it held the supplied ICPSR bundle and the derived analysis files.
- The implementers' input files (`implementation/bundle_v1/data/`, `runs/*/inputs/`) are removed. The implementer bundle was column-permuted from the real records, so it is derived from the restricted-redistribution data. Per-specification case lists (`samples.csv`) and two record-level analysis frames used in the implementation audit (`checks/audit/C_divergence/frame_*.csv`) are also removed.
- The implementers' development outputs (`implementation/*/code/dev_out/`, about 130 MB of results on that bundle) are removed. The frozen-run results in `runs/` and `reports/data/` are kept.
- Both article copies in the reader packet are removed: the journal scan and the retypeset copy from the author's website, with their page images and extracted text. Get the article from the publisher through the DOI in [../../papers/catalog.json](../../papers/catalog.json).
- Reader B's (GPT-6 Astra) raw event log, which echoes the article text, is removed. Its parsed outputs (claims, targets, specification) are kept.

Paths in the logs, registries and reports still point to these files. Their SHA-256 hashes are kept, so a rebuilt file can be checked against the original.
