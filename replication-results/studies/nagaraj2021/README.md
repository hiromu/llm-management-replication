# Nagaraj (2021)

Nagaraj, A. (2021). Information Seeding and Knowledge Production in Online Communities: Evidence from OpenStreetMap. Management Science 67(8), 4908–4934. DOI: 10.1287/mnsc.2020.3764.

The overall outcome is indeterminate. Of nine paper-focal claims, one is consistent, one has fragile inference, six are indeterminate, and one is discrepant but not fully verified. No human reviewed this run. The original Stata pipeline was not rerun because Stata was unavailable. The discrepancy review used the same model family as one implementer.

This is an additional deposited-data case alongside Berry and Hildreth, separate from the six public-source studies and their post hoc common-rule comparison. Its frozen rules are study-specific. The run used author-processed aggregates, with independently downloaded Census county boundaries for mapping. It did not reconstruct the underlying OpenStreetMap dataset from raw history.

## Read the findings

- [Replication report](reports/replication_report.md)
- [Technical supplement](reports/technical_supplement.md)
- [Claim outcomes](reports/data/claim_outcomes.csv)
- [Original focal-results figure](reports/figures/figure_focal_influence.png) and [plotted values](reports/figures/figure_focal_influence.csv)
- [Frozen rules](scoring/scoring_rules_v1.json) and [final summary](runs/run_20261101_v1/scoring/final_summary.json)
- [Post-unsealing diagnostics](post_unseal/comparisons_2_and_3.md)

The routing-error estimate is about -0.108 under the article's absolute-error definition. Applying the signed transformation found in the author code gives about +0.125, close to the printed +0.126. This is a post-unsealing diagnostic of a text-code difference, not a completed author-code rerun or a human-verified correction. Frozen scores were not changed by these diagnostics.

## Files and omissions

This copy contains original analysis code, aggregate results, scoring records, structured reader assessments, provenance, and the frozen protocol. It excludes all empirical and synthetic input data, county membership and per-county deletion records, article PDFs and extracted packets, published-panel images, author-package files, raw transcripts, private conversations, and operational caches. The focal figure retains the aggregate deletion ranges calculated in the original run; this copy does not contain the individual deletion records used to generate them. Consequently, regenerating that figure with the original analysis script requires restoring or rerunning the individual deletion records first.

[export_exclusions.json](export_exclusions.json) lists omissions. Historical paths in reports and source manifests may refer to omitted files; they are not download links. Published-panel comparisons are described in prose without redistributing their images. Source comparison scripts remain available for local use after restoring the documents and data.

## Recover inputs for a separate rerun

1. Obtain the OSF deposit at https://osf.io/a47e9. [logs/osf_receipt.json](logs/osf_receipt.json) records all 60 files, download links, hashes and stored paths. Data belong under `data/raw/osf_a47e9/`; author scripts, the full Readme and results TeX belong under `sealed/author_package/`. The deposited appendix belongs at `data/raw/osf_a47e9/writing/appendix.pdf`.
2. Obtain `tl_2010_us_county10.zip` from https://www2.census.gov/geo/tiger/TIGER2010/COUNTY/2010/tl_2010_us_county10.zip and place it in `data/raw/census_tiger2010/`. Check [logs/tiger_receipt.json](logs/tiger_receipt.json).
3. Obtain the publisher-version article and save it as `packet/nagaraj2021.pdf`. Its expected hash and edition are in [STUDY.json](STUDY.json).
4. Use a separate clean working copy. Acquisition helpers in [logs/acquire_osf.py](logs/acquire_osf.py) and [logs/acquire_tiger.py](logs/acquire_tiger.py) write new receipts; do not overwrite this archived run's evidence. They require a Python environment with working HTTPS. Availability of the sources was not rechecked during export.
5. Consult [protocol_as_run/](protocol_as_run/) and [protocol_as_run/study_CLAUDE.md](protocol_as_run/study_CLAUDE.md), including the study-specific [role configuration](protocol_as_run/config/roles_nagaraj2021.json). The parent repository's six-study protocol is not a substitute for this frozen shared-data protocol. Full rerunning requires the documented software and model access and has not been performed as part of export.

The OSF receipt records CC-BY 4.0 for the deposit. This repository nevertheless links to, rather than rehosts, its data and author code. Article rights are separate. Some historical inputs, including Census correspondence, InfoUSA-derived material and 2017 routing queries, cannot be independently reacquired in the same form.

## Integrity

[export_manifest.json](export_manifest.json) records source and exported hashes separately and identifies every export edit. [logs/pre_unseal_hashes.json](logs/pre_unseal_hashes.json) and the other original run receipts retain their original hash values, including references to files omitted here. They are historical run records, not checksums of the edited public copy.

The files in `protocol_as_run/` are byte-identical to the frozen root protocol and study instructions. Its original `SHA256SUMS` checks the frozen root files; the additional `study_CLAUDE.md` is covered by the export manifest. Run `python verify_export.py` with an existing Python interpreter to verify the public copy without data or model calls. On the original machine, use `~/.venv/bin/python verify_export.py`.
