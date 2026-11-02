# Screening snapshot

Metadata-only snapshot taken on 28 October 2026 from the earlier `Replication_management/top_journals_v2` screening workspace. The source methods and full-text criteria are included. Article PDFs, abstract text, empirical data and source quotations are not included in the derived CSVs.

- `corpus_11051.csv`: eligible research frame after duplicate and field filtering, not every raw Crossref record.
- `fulltext_776.csv`, `source_assessments.csv`: full-text classifications and listed source tiers.
- `empirical_277.csv`: no-package-recorded B/C candidates: 265 archival, 7 mixed, 5 meta-analysis.
- `archival_public_154.csv`: archival candidates with every listed source in R/T0/T1/T5; `counts.json` also counts 209 when T2c is permitted.
- `six_case_membership.csv`: exact joins for the six cases. Delaney replaced Weigelt as the AMJ case on 28 October 2026 after both results were known; both runs ended indeterminate. Dated selection reasons and prior knowledge of results for the other five cases remain unestablished.
- `manifest.json`: file hashes for this snapshot.

From this directory, run `~/.venv/bin/python recompute_counts.py` on the original machine, or use an existing Python interpreter elsewhere. The script uses the standard library, reads only these files, and verifies counts and memberships without writing them.

The source screen's package flag is article-based, not an exhaustive repository search. Its public tier R permits printed values and T5 author-posted material; these definitions are broader than the six-study protocol's permitted empirical inputs. Screening eligibility does not guarantee complete reconstruction. Policy endpoints are historical screening choices, not certifications of current journal policies.
