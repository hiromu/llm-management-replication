# Codifying the Research Routine: Reproducing Organizational Research with Partitioned AI Agents

This repository accompanies a proposal to *Organization Science*. It contains six studies reconstructed from article methods and public source data, plus two additional cases using authors' deposited data. Reader sessions examine the papers; separate implementer sessions receive analysis instructions and data with published estimates removed. A scorer compares the frozen outputs with the published results. For the deposited-data cases, author code remains sealed until the initial scoring is complete.

## Six public-source studies

The outcomes below use each study's frozen rules.

| Journal | Paper | Outcome | Folder |
| --- | --- | --- | --- |
| Organization Science | Lehman et al. (2011) | consistent | [studies/lehman2011/](studies/lehman2011/) |
| Management Science | Holderness & Pontiff (2012) | partially reproduced | [studies/holderness2012/](studies/holderness2012/) |
| Strategic Management Journal | Deephouse (1999) | indeterminate | [studies/deephouse1999/](studies/deephouse1999/) |
| Administrative Science Quarterly | Thébaud (2015) | indeterminate | [studies/thebaud2015/](studies/thebaud2015/) |
| Journal of Management | Twenge et al. (2010) | indeterminate | [studies/twenge2010/](studies/twenge2010/) |
| Academy of Management Journal | Delaney & Huselid (1996) | indeterminate | [studies/delaney1996/](studies/delaney1996/) |

Start with each study's `reports/replication_report.md`. The folders also contain analysis code, data-source records, scoring and audit records.

Each study froze its own scoring rule before fitting models. [studies/score_common.py](studies/score_common.py) compares these six studies under a common rule using saved estimates, without refitting. That rule was written after the results were known; its outcomes differ from some frozen study outcomes. See [studies/common_v1_summary.md](studies/common_v1_summary.md). The two deposited-data cases below are excluded from this comparison and its totals.

## Two deposited-data cases

| Journal | Paper | Frozen outcome | Report and scope |
| --- | --- | --- | --- |
| Organization Science | Berry & Hildreth (2025) | consistent, with a bootstrap qualification | [Study README](studies/berry2025/README.md) |
| Management Science | Nagaraj (2021) | indeterminate | [Study README](studies/nagaraj2021/README.md) |

These additional cases sit outside the 277 screened candidates. Both use author-processed data and therefore do not establish independent reconstruction of the original datasets. Frozen reconstruction outcomes are kept separate from later author-code diagnostics.

Neither case received human review, and each reviewer shared a model family with an implementer. See the linked study READMEs for detailed findings and limitations.

## Protocols and layout

- [CLAUDE.md](CLAUDE.md), `instructions/`, `prompts/` and `config/roles.json`: the public-source protocol and role configuration.
- [instructions/shared_data.md](instructions/shared_data.md): Berry's deposited-data rules. These refer to Berry's specific files and design.
- [studies/nagaraj2021/protocol_as_run/](studies/nagaraj2021/protocol_as_run/): Nagaraj's frozen protocol, including its study instructions and role configuration. Use this study-specific record when inspecting or rebuilding Nagaraj; the root protocol and Berry's rules are not substitutes.
- [papers/](papers/): the six-study article catalog and screening record; the two additional cases keep their publication inventories in their own study folders.
- [studies/](studies/): reports, code, aggregate results and provenance for each paper.
- [proposal/](proposal/): the current anonymous proposal and technical supplement. The supplement includes Berry (Section S13) and Nagaraj (Section S14). See the [build notes](proposal/README.md).

## Inputs and export boundaries

Study article PDFs, extracted article packets and empirical data are not distributed here. Source locations and expected file hashes are recorded in [papers/catalog.json](papers/catalog.json), study READMEs, registries and acquisition receipts. The deposited-data exports also omit author-package files and identifying row-level records.

See each study's README in [studies/](studies/) for data access, licensing, export omissions and hash conventions.

## Inspecting or rerunning

Reading the saved reports and aggregate results needs no data download or model calls. New empirical runs should use a separate clean working copy and the relevant study's instructions, with the required inputs restored; do not overwrite the archived run records.

For the public-source studies, Delaney (ICPSR 6240), Thébaud (ICPSR 20320) and Twenge (ICPSR 7927, 9871, 20022) need manually downloaded ICPSR files in the study's `data/supplied/` folder. Follow each study's source records for other inputs. For Berry and Nagaraj, follow their study READMEs rather than the public-source acquisition procedure.

To rescore the six-study comparison without refitting, run `cd studies && python score_common.py` in a working copy with pandas and numpy. This writes common-rule outputs; it does not score Berry or Nagaraj.
