# PDF screening: method

2026-10-11

This file describes step 3 in full: what was read, who coded it, how the codes were checked, where coders had to fill gaps in the rules, and what came out. The summary of all three steps is in `README.md`. The coding rules themselves are in `criteria.md` and aren't repeated here. Paths below are relative to the `3_pdf_screening/` folder.

The step reads the full text of every paper the abstract screen rated a target. It tests that rating. It says nothing about papers the abstract screen turned away.

Update on supplement use (2026-10-27): this document describes the original article-only screening. Prepared supplements are now indexed in `4_supplements/replication_index.json` relative to `top_journals_v2/`, with use instructions in `4_supplements/README.md`. New replications must consult matching supplements. The original coding, frozen criteria and reported agreement statistics have not been revised; any supplement-aware reassessment must be versioned separately.

## 1. What goes in

The 776 target papers from step 1, each with a PDF verified in step 2. `frame.csv` lists them. The PDFs hold 17,366 pages. The median paper has 21.

Coding ran twice. Run 1 covered Organization Science and the Academy of Management Journal (303 papers). Run 2 covered the other four journals and one AMJ paper downloaded late (473 papers). Both runs used the same criteria, instructions and scripts.

## 2. Criteria

`criteria.md` is version 1. Its sections 2 and 3 are copied word for word from the 420-paper sample in `../../sample_with_pdf/`, where they were frozen on 2026-10-03 before any coding. `coding_log.json` holds the SHA-256 hash of section 2. `scripts/fulltext.py` stops if the hash no longer matches.

A coder works through a paper in this order: is the PDF the right article, is it research, which field (Management Science only), which method, which routing. For a candidate the coder then lists every data source used in the main-text analyses, and for candidates and simulations fills the paper-level codes.

The full-text criteria differ from the abstract codebooks in five ways.

- The evidence is the paper's own list of sources, each with a role, a tier, a PDF page and a quote. The abstract screen coded the paper as a whole.
- There is one more tier, `T5`, for data the authors posted, and two more flags, `on_request` and `source_unnamed`.
- No likelihood rating. The group follows from the least obtainable core source, and a script derives it.
- A doubtful tier goes to the less obtainable side (hard case 12). Doubtful routing still keeps the paper in play, as in the abstract screen.
- A new verdict, `partial`, marks papers whose core data are obtainable while a control or a `robustness` source isn't.

A paper is confirmed if its group is A, B or C.

## 3. Procedure

### 3.1 Text

`fulltext.py prepare` extracts each PDF's text with PyMuPDF and writes `text/<paper_id>.txt`, with a line `===== PDF page N of M =====` before each page. Page numbers in the coding are these PDF page numbers, not the printed ones.

A PDF counts as a scan without text when its median page, after the first page and any line repeated on half the pages are dropped, has fewer than 400 characters. Six PDFs do: five Management Science papers from 2000 and 2001 and one Journal of Management paper from 1990. Coders read those as page images.

### 3.2 Batches and the second-coder sample

Within a run, a seeded random draw takes 10% of the papers for second coding (seeds 20261011 and 2026101102). The draw comes before batching, so it doesn't depend on it. The papers are then shuffled into batches of 8.

| Run | Papers | First-coding batches | Second-coding sample | Second-coding batches |
|---|---|---|---|---|
| 1 | 303 | 38 | 30 | 4 |
| 2 | 473 | 60 | 47 | 6 |

A run's batches can't be rebuilt once prepared. The script refuses.

### 3.3 Coders

Each batch went to one Claude Opus 5.5 subagent with a fresh context: 108 coders in all, at most 20 at a time. A coder got `coder.md`, `criteria.md` and its batch file. The batch file gives the paper's ID, journal, year, title, authors, page count and file paths. It carries nothing from the abstract screen.

`coder.md` forbids opening `1_abstract_screening/`, the README, the method files, any other coder's JSON, the merged CSVs and the report. It forbids web access. A coder takes the data a paper used from the paper alone and uses its own knowledge only to judge whether a named source can be obtained today.

A second coder is another subagent under the same instructions. It writes to `coding_rel/` and can't open `coding/`.

The two runs used about 8.7 million and 13.5 million tokens.

### 3.4 Validation

Each coder runs `fulltext.py check` on its batch and fixes every error before finishing. The rules are in `scripts/rules.py`. The check fails a file when:

- a key is missing or extra, or a code isn't on its list;
- the routing contradicts the method (a `simulation` that isn't `simulation_formal`, an archival paper or meta-analysis routed to `exclude`, a `non_research` item not excluded);
- a candidate has no source, or none in a core role;
- a source lacks a name, role, tier, page or quote, carries an unknown flag, cites a page beyond the end of the PDF, or quotes more than 25 words;
- a posted package has no location, or `model_specified` is filled for a non-simulation.

It warns, without failing, on a candidate whose method is theory, qualitative or simulation, and on a `T5` source in a paper coded as having no package.

### 3.5 Merge

`fulltext.py merge` runs only when every batch passes. It derives `max_core_tier`, `tier_group` and `data_availability` by the rules in criteria §2.7, joins the abstract group from step 1, and writes `target_fulltext.csv`, `target_sources.csv`, `reliability.json`, `quotes_not_found.csv` and `reports/fulltext_targets.md`.

### 3.6 Quote check

For every source in a PDF with a text layer, the merge looks for the quote on the page the coder cited. Text is compared after lower-casing and stripping everything but letters and digits. A quote with an ellipsis or a bracketed insertion is split there, and every part has to be on the page.

## 4. Conventions where the criteria are silent

Coders reported unsettled cases in their closing notes. The table collects the ones that recurred. It comes from those notes, not from a recount of the codings, so it gives numbers only where the merged data supply them. "Moves the line" says whether the choice can put a paper on the other side of confirmed.

| Case | What coders did | Uniform? | Moves the line? |
|---|---|---|---|
| Meta-analysis that doesn't print its effect sizes | `T2` with `hand_collected` (hard case 10) for 45 papers. Twelve got a separate `T4` source for unpublished or author-supplied studies. Others with the same feature stayed `T2` with `on_request`. | No | No. D against E. |
| Meta-analysis that prints a pooled correlation matrix | Matrix entered as an `R` source, so `targets_obtainable = some` | Mostly | No |
| Printed sports annuals and record books | `T0` as sports records, or `T2` as commercial print under hard case 5 | No | Yes |
| Commercial print lists and trade books (Fortune lists, Variety, U.S. News, Moody's, BioScan) | `T2` with `old_vintage` | Yes | |
| Newspaper and magazine archives (Wall Street Journal, New York Times, Factiva) | `T2` | Yes | |
| USPTO data taken through a vendor (MicroPatent, Delphion, Derwent, LexisNexis) | `T2` under hard case 1 by most, `T0` by some. PATSTAT got `T2`, `T1` or `T5`. | No | Yes |
| Data "provided by" an organization | `T4`, unless the same file is posted today, then `T0` | Mostly | Yes |
| Data obtained by FOIA request | `T3` | Yes | |
| Old public websites and platforms | `T0` with `web_vintage`, or `T2`/`T4` when the past content looked lost | No | Yes. All three second-coder disagreements. |
| Unnamed sources | Tier from the description, with `source_unnamed`. Confidence usually `medium`, though hard case 2 says `low`. | No | Sometimes |
| An unnamed list that defines the sample | `T4` by some. Others read it as a selection rule, not a source. | No | Yes |
| Data from the authors' earlier study | `T4` under hard case 11, or the named sources behind it | No | Yes |
| Interviews and side surveys beside archival data | `T4` in the `robustness` role, which gives `partial` | Mostly | No |
| Human ratings of public material | `T4` | Yes | |
| Free-registration sources | OpenSecrets and PSED `T1`. CPS `T0` or `T1`. | No | No |
| Paper with both a model and data | `simulation`, or `mixed` and candidate | No | Yes |
| Simulation with parameters or code in an online appendix | `model_specified = partial`. Code in the appendix counts as a posted package. | Mostly | No |
| Management Science field | Decided by topic, not by the authors' department | Yes | |
| `targets_obtainable` | Some counted a table as lost when any source behind it was paid, others only when a core source was | No | No |

Two fields show the cost. Ten papers in groups B and C have `targets_obtainable = none`, and two in D and E have `all`. And 142 papers have an unnamed source, with confidence `high` for 56, `medium` for 81 and `low` for 5.

## 5. Results

### 5.1 By journal

501 of 776 papers are confirmed (65%). Thirty-three of them say their data or code are posted, which leaves 468.

| Journal | Read | Confirmed | Share | Package-free | Simulations (A) | Archival, confirmed of read | Meta-analyses read |
|---|---|---|---|---|---|---|---|
| ORSC | 194 | 143 | 74% | 133 | 77 | 63 of 102 | 4 |
| SMJ | 284 | 175 | 62% | 160 | 55 | 115 of 206 | 18 |
| AMJ | 110 | 43 | 39% | 42 | 5 | 35 of 70 | 33 |
| MNSC | 97 | 78 | 80% | 76 | 48 | 28 of 42 | 4 |
| JOM | 47 | 32 | 68% | 30 | 14 | 18 of 30 | 3 |
| ASQ | 44 | 30 | 68% | 27 | 12 | 18 of 31 | 1 |
| Total | 776 | 501 | 65% | 468 | 211 | 277 of 481 | 63 |

The spread across journals is mostly a spread in method. Archival papers are confirmed at 50% (AMJ) to 67% (Management Science). Journals rise above that with simulations and fall below it with meta-analyses.

Run 1 confirmed 185 of 303 (61%) and run 2 confirmed 316 of 473 (67%).

By decade the rate is 56% for the 1990s (54 of 97), 69% for the 2000s (119 of 173), 62% for the 2010s (199 of 319) and 69% for the 2020s (129 of 187).

### 5.2 Abstract group against full-text group

Rows are the abstract screen's group. Columns are the group from the full text.

| Abstract | A | B | C | D | E | Excluded | Total | Confirmed |
|---|---|---|---|---|---|---|---|---|
| A | 211 | 0 | 1 | 0 | 1 | 5 | 218 | 97% |
| B | 0 | 218 | 9 | 159 | 58 | 0 | 444 | 51% |
| C | 0 | 3 | 59 | 44 | 8 | 0 | 114 | 54% |

Meta-analyses pull group B down. All 63 were in B and 57 dropped out. The archival papers in B are confirmed at 59% (217 of 369) and those in C at 54% (60 of 112).

The five excluded papers are three formal models without numerical results (`ORSC_2011_Gaimon`, `ORSC_2016_Helfat`, `MNSC_2015_Mitchell`), one Management Science paper outside the field filter (`MNSC_2009_Gamba`) and one theory paper (`ORSC_1999_McKelvey`).

### 5.3 By method

| Method in the full text | Read | Confirmed | Share |
|---|---|---|---|
| `archival_quant` | 481 | 277 | 58% |
| `simulation_formal` | 215 | 211 | 98% |
| `meta_analysis` | 63 | 6 | 10% |
| `mixed` | 16 | 7 | 44% |
| `theory_review` | 1 | 0 | |

Four of the six confirmed meta-analyses print their effect sizes. One rests on a public file and one on data the authors posted.

### 5.4 Sources and tiers

The 560 candidates name 2,273 sources, a median of 3 per paper and at most 21. By tier: `T0` 1,286, `T2` 499, `T2c` 177, `T4` 114, `T1` 110, `R` 57, `T3` 15, `T5` 15. By role: sample 774, key independent 514, dependent 287, control 544, `robustness` 154.

| Worst core tier | Papers | Group |
|---|---|---|
| `R` | 7 | B |
| `T0` | 159 | B |
| `T1` | 49 | B |
| `T5` | 6 | B |
| `T2c` | 69 | C |
| `T2` | 203 | D |
| `T3` | 10 | E |
| `T4` | 57 | E |

The verdicts are `no_data_needed` 211, `public` 226, `partial` 64, `restricted` 270, and 5 excluded.

### 5.5 What blocks the 270 papers in D and E

In 168 of the 270, a single core source does it. The flags on the blocking sources, counted by paper: `hand_collected` 126, `subscription_db` 116, `old_vintage` 94, `source_unnamed` 22, `on_request` 20, `web_vintage` 12, `own_survey` 9, `restricted_admin` 6, `single_firm` 4. A paper can carry several.

Fifty-seven of the 270 are meta-analyses. The rest are archival or mixed papers that need a paid database, a commercial print source, or a sample the authors assembled and didn't print.

### 5.6 The confirmed papers

Of the 211 simulations, 94 give the full model in the paper and 117 give it in part. The share with the full model is highest in Organization Science (42 of 77), then SMJ (26 of 55) and Management Science (20 of 48). It is lowest in ASQ (2 of 12), AMJ (1 of 5) and the Journal of Management (3 of 14).

Of the 290 papers in B and C, 141 have no flag on a core source. The other 149 carry at least one: `old_vintage` on 76, `hand_collected` on 71, `web_vintage` on 13. Thirty-three have a core source described as public but not named.

Effort ratings for the 501 are S 159, M 281 and L 61. Together they report 2,993 result tables and figures.

Sixty-eight of the 501 need an online supplement that isn't in the PDF (104 of all 776).

Thirty-eight papers say data or code are posted, 28 of them from 2018 on. Thirty-three are confirmed, and 20 of those are simulations with posted code.

## 6. Reliability

### 6.1 Second coding

Seventy-seven papers were coded twice: SMJ 29, ORSC 19, AMJ 12, MNSC 8, ASQ 5, JOM 4.

| Code | Papers | Agreement | κ |
|---|---|---|---|
| Research or not | 77 | 100% | 1.00 |
| Routing | 77 | 100% | 1.00 |
| Method | 77 | 99% | 0.98 |
| Group, with excluded as a category | 77 | 96% | 0.95 |
| Confirmed or not | 77 | 96% | 0.91 |
| Verdict | 77 | 96% | 0.94 |
| Worst core tier | 52 | 92% | 0.90 |
| Package posted | 77 | 100% | 1.00 |
| Needs supplement | 77 | 97% | 0.89 |
| `targets_obtainable` | 77 | 94% | 0.89 |
| `model_specified` | 25 | 92% | 0.83 |
| `feasibility` | 77 | 82% | 0.70 |
| `confidence` | 77 | 78% | 0.53 |

The two coders gave the same count of result tables for 74 of 77 papers and the same number of sources for 40 of 52 candidates.

Run 1 had no disagreement on group in 30 papers. Run 2 had three in 47 (κ = 0.92 on group, 0.85 on confirmed or not).

| Paper | First coder | Second coder | The source in question |
|---|---|---|---|
| `MNSC_2013_Lu` | D | B | A 2004 nursing-home file (OSCAR) |
| `SMJ_2017_Hu` | D | B | A circulation website reaching back to 1972 |
| `SMJ_2023_Loh` | E | B | Wiki page histories on a platform that has since merged |

All three turn on whether an old public source can still be had, and all three go the same way: the first coder, whose code is the one used, was the stricter. Two other pairs differ without changing the group. `SMJ_2018_Arts` is archival for one coder and mixed for the other. `ASQ_2018_Ferguson` has `T4` against `T3`.

### 6.2 Quotes

2,266 quotes come from PDFs with a text layer. 2,259 stand on the page they cite and one stands elsewhere in the paper. Six in four papers don't match (`quotes_not_found.csv`). All six are on the cited page of the PDF. Five differ from the extracted text by OCR errors or a footnote marker. The sixth, in `AMJ_2014_Funk`, sits in a passage PyMuPDF dropped from page 10.

The seven sources in the six image-only scans can't be checked this way.

### 6.3 Overlap with the 420-paper sample

Fourteen targets were also coded in the sample, by other coders under the same criteria. Twelve got the same group and 13 the same side of the confirmed line. `ORSC_2017_Stuart` is E there and B here. `MNSC_1996_Damanpour` is E there and D here.

The sample tested the abstract screen's high rating on 15 papers and confirmed 11 (73%). The rate here is 65% on 776.

## 7. Limits

1. No person has checked a paper. Both coders are the same model under the same instructions, so agreement shows the coding is repeatable. It doesn't show the codes are right, and a blind spot the two share stays hidden.
2. Tiers rest on what the model knows about access today. No coder visited a source, a vendor or a posted package. The three disagreements are all of this kind.
3. The conventions in section 4 aren't uniform. Sports annuals, vendor copies of USPTO data, old websites and unnamed sample lists can each put a paper in B or in D depending on the coder. Nothing has been recoded.
4. The meta-analysis result follows from hard case 10. If effect sizes extracted again from the primary articles counted as obtainable, up to 45 more papers would be confirmed.
5. Supplements weren't read. That affects 68 confirmed papers, and it is one reason 117 simulations are specified only in part.
6. Confirmed means the data can be obtained in principle. Half the B and C papers carry a warning flag on a core source, and 61 papers are rated L.
7. `partial` papers (64) need a control or a side analysis dropped or replaced.
8. The text extraction can lose passages. The Funk case shows one. How often this happens wasn't measured. Coders were told to open the PDF page when text looked garbled, which doesn't catch a passage that is silently absent.
9. `feasibility` and `confidence` agree too weakly to count papers by. `targets_obtainable` was read two ways. Use the three for sorting only.
10. The step finds the abstract screen's false positives among the targets. Papers the abstract screen rated medium or low weren't read here. The 420-paper sample is the check on those.

## 8. Files

| File | Content |
|---|---|
| `criteria.md` | The rules, version 1 |
| `coding_log.json` | Hash and freeze date of the criteria |
| `coder.md` | The coder's instructions |
| `frame.csv` | The 776 papers, with page count, text layer and run |
| `batches/` | `r1_batch_*`, `r1_rel_*`, `r2_batch_*`, `r2_rel_*` |
| `text/` | Extracted text, one file per paper. Copyrighted, so not in the shared copies. |
| `coding/` | First coding, 776 JSON files. These are the codes used. |
| `coding_rel/` | Second coding, 77 JSON files |
| `target_fulltext.csv` | One row per paper, with the derived fields and the abstract group |
| `target_sources.csv` | One row per source: role, tier, flags, page, quote |
| `reliability.json` | Agreement on the five headline codes and the list of disagreements |
| `quotes_not_found.csv` | The six unmatched quotes |
| `reports/fulltext_targets.md` | Generated report, with the 501 confirmed papers listed by group |
| `scripts/fulltext.py` | `prepare`, `check`, `status`, `merge` |
| `scripts/rules.py` | Code lists, validation, derived fields, κ |

To rebuild the outputs from the codings, run `~/.venv/bin/python3 3_pdf_screening/scripts/fulltext.py merge` from the `top_journals_v2` folder. The agreement figures in section 6.1 beyond the first five rows aren't in `reliability.json`. They were computed from `coding/` and `coding_rel/` with `rules.derive` and `rules.kappa`.
