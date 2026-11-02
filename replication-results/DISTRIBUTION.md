# Submission package

This directory contains the updated anonymous research distribution, reorganized under `replication-results/`. Its [research overview](README.md) covers eight studies. The standalone app presents seven of them; Berry & Hildreth (2025) is included here as an archive-only case, with its original report, code, scoring and audit evidence.

## Where to start

| Location | Contents |
| --- | --- |
| [README.md](README.md) | Eight-study index and research scope |
| [proposal/](proposal/README.md) | Anonymous proposal and technical supplement, PDFs, LaTeX sources and build instructions |
| [studies/](studies/) | Original study directories, reports, analysis code, aggregate outputs and provenance |
| [papers/](papers/README.md) | Article catalog and screening records |
| [CLAUDE.md](CLAUDE.md), `instructions/`, `prompts/`, `config/` | Archived research protocol |
| [ANONYMIZATION.md](ANONYMIZATION.md) | Upstream cleanup record and its limitations |

The source directory's relative layout and file bytes are preserved. This keeps internal links, proposal build paths and frozen study inventories meaningful. Source files may still mention their historical `Replication_management/` location. Historical run inventories can refer to conversation files deliberately removed from this distribution; the upstream anonymization manifest records those omissions.

## App presentation layer

Seven study folders additionally contain a derived `result.json` following the [app result contract](../app/protocol/RESULT_FORMAT.md). Nagaraj's `presentation/` directory contains figures rendered from saved aggregate outputs; the rendering utilities are in `tools/`. These presentation artifacts supplement the research export without changing frozen outcomes.

The app retains 817 assessment units: 733 from the first six studies and 84 from Nagaraj, including descriptive/figure diagnostics and five unaudited units. This is an inventory count, not a pooled success-rate denominator. Berry's archive is outside this count.

`app/data/` holds its own copies of the selected display evidence and a populated SQLite database. App startup does not read this research directory. Its bundled Nagaraj export manifest and result provenance have been synchronized with this distribution.

## Offline verification

From the repository root:

```bash
python3 replication-results/verify.py
python3 replication-results/studies/nagaraj2021/verify_export.py
```

The package verifier checks distribution checksums, the eight-study inventory, the upstream cleanup record, structured results and their source hashes. When the adjacent app exists, it also checks its copied evidence and persisted bundles. The Nagaraj verifier checks its 338-file public export and frozen protocol checksums. Neither command fits models, downloads data or calls a model provider.

`manifest.json` distinguishes the eight `archive_studies` from the seven console `studies`. `source_distribution.files` identifies the unchanged source export; `files` checksums the distributed evidence and supporting files. Repository owner names, URLs and commit IDs are omitted from distribution metadata.

Ordinary scholarly citations and dependency credits remain, including author names in the bibliography and screening corpus. The proposal and supplement have empty PDF author fields. The upstream cleanup does not anonymize this checkout's Git history or ignored local runtime files; exclude those from a submission export.

Original articles, empirical inputs and sealed author packages remain excluded. For empirical reruns, restore permitted inputs in a separate working copy and follow each study's instructions. `requirements.txt` records the common scorer dependencies; it is not a complete environment for every study.
