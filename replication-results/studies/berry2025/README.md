# Berry and Hildreth (2025)

Berry, Z., and Hildreth, J. A. D. (2025). When your friend is my friend: How loyalty prompts support for indirect ties in moral dilemmas. *Organization Science*, 36(2), 762–785.

**Outcome:** Consistent. All 22 focal claims are consistent: H1 (10 claims), H2 (9) and H3 (3). The comparability mapping is fully reproduced, with one qualification. For the nine Study 2 focal indirect effects, the printed SEs and intervals were not reproduced from the method the article names.

**Common rule:** not applied. This study uses the authors' deposited data under [../../instructions/shared_data.md](../../instructions/shared_data.md). It sits outside the 277 screened candidates and the six-study comparison in [../common_v1_summary.md](../common_v1_summary.md).

The findings are in [reports/replication_report.md](reports/replication_report.md) and the details in [reports/technical_supplement.md](reports/technical_supplement.md), [reports/audit_pre_unseal.md](reports/audit_pre_unseal.md) and [reports/adversarial_review.md](reports/adversarial_review.md). The paper was rebuilt from the written methods and the authors' OSF deposit. The authors' script stayed sealed until the scored comparison was hashed. Unsealing it showed that the article's bootstrap intervals were never bootstrapped. The script returns normal-theory standard errors, and the bootstrap the article describes gives standard errors 1.10 to 1.56 times the printed ones. None of the 16 indirect-effect intervals changes side of zero.

No human reviewed these findings. The adversarial reviewer shared a model family with one implementation family, so the review was not independent of both families and the findings are not fully verified. The consistent frozen outcome does not remove the bootstrap qualification above; later author-code diagnostics do not replace the frozen scores.

## Data used

The empirical inputs are the authors' OSF deposit, node [3h6vc](https://osf.io/3h6vc), downloaded on 31 October 2026. It holds 37 files: the Study 1–4 data, dictionaries and preregistrations, the study materials (AppendixA), the supplemental studies and the analysis script. The OSF API showed no license, so the deposit is linked here, not rehosted. File hashes: [logs/osf_receipt.json](logs/osf_receipt.json).

The article (DOI 10.1287/orsc.2023.18003) and its Online Appendix were saved by hand. Their hashes are in [STUDY.json](STUDY.json).

## What this copy leaves out

This is a public copy of the run record. It contains no data, no copy of the article and none of the authors' code.

- `data/` is not included. In the original run it held the OSF deposit (`data/raw/osf_3h6vc/`) and the files built from it by [code/](code/): the implementer bundle, with free-text columns removed, and synthetic data for development.
- The authors' script (`sealed/author_package/ltran_analysis_script.Rmd`) is removed, with its copies and edited versions in `runs/author_rerun/script/` and the two rerun logs (`asis_output.txt`, `changed_output.txt`), which echo each line of it. [runs/author_rerun/script/run_author.R](runs/author_rerun/script/run_author.R) rebuilds them from the deposited script and lists every text change. The run summaries, package versions and extracted statistics are kept.
- The reader packet (`packet/`) is removed: the article, Online Appendix, study materials, preregistrations, Study 2 deviation report, dictionaries and column lists, as files and as extracted text. [packet/publication_packet.json](packet/publication_packet.json) and [packet/reader_v1/PACKET_SHA256.json](packet/reader_v1/PACKET_SHA256.json) keep the list and hashes.
- The raw command-line transcript of Reader B (GPT-6 Astra), `logs/roles/reader_astra.stdout`, is removed because it echoes the article text. Its parsed outputs in [readers/astra/](readers/astra/) are kept.
- Saved R objects (`.rds`), per-run analysis samples (`samples.csv`) and the installed R package library (`runs/author_rerun/rlib/`) are removed.

Paths in the logs, registries and reports still point to these files. Their SHA-256 hashes are kept, so a rebuilt file can be checked against the original. Local paths were replaced with `~` and `<project>`. Where that changed a file, the hash recorded for it was updated to match this copy, in six records including [logs/pre_unseal_hashes.json](logs/pre_unseal_hashes.json).

To rerun, put the OSF files in `data/raw/osf_3h6vc/` and the article and Online Appendix at the `packet/` paths in STUDY.json, then check each against its recorded hash.
