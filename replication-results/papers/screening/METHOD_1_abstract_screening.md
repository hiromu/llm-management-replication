# Abstract screening: method

2026-10-11

This file describes step 1 in full: how the paper lists were built, how each record was coded, how the codes become groups and targets, and how the coding was checked. The summary of all three steps is in `README.md`. Paths below are relative to the `1_abstract_screening/` folder.

The screen reads titles and abstracts only. No full text is read and no publisher website is visited. Its output is a prediction, which step 3 then tests against the PDFs.

## 1. Scope

Six journals, each from 1990 to the last year before it required data and code.

| Journal | Code | Window | Why the window ends there |
|---|---|---|---|
| Organization Science | ORSC | 1990–2025 | Research Transparency Policy, new submissions from 1 August 2025 |
| Strategic Management Journal | SMJ | 1990–2025 | No posting mandate |
| Academy of Management Journal | AMJ | 1990–2025 | No mandate found |
| Journal of Management | JOM | 1990–2025 | No posting mandate. Data and code go to editors on request. |
| Administrative Science Quarterly | ASQ | 1990–2024 | Data and Methods Transparency Policy, from 1 July 2024 |
| Management Science | MNSC | 1990–2019 | Data and Code Disclosure Policy, submissions from mid-2019 |

Management Science is restricted by field as well (section 4.3). The Academy of Management Review is left out because it publishes only theory.

Policy sources:

- Organization Science, Research Transparency Policy: <https://orgsci.substack.com/p/new-papers-and-a-new-policy-on-research>
- Management Science, Code and Data Disclosure Policy: <https://pubsonline.informs.org/page/mnsc/code-and-data-disclosure-policy>
- Administrative Science Quarterly, Data and Methods Transparency Policy: <https://journals.sagepub.com/pb-assets/cmscontent/ASQ/Data%20and%20Methods%20Transparency%20Policy%20040324-1712174442.pdf>
- Strategic Management Journal, author guidelines: <https://onlinelibrary.wiley.com/page/journal/10970266/homepage/guide.htm>
- Journal of Management, author guidelines: <https://journals.sagepub.com/author-instructions/JOM>

No source is on record for the Academy of Management Journal.

## 2. Paper lists

Script: `scripts/fetch_crossref.py`. Output: `paper_lists/<J>_<year>.csv` and `master/<J>_frame.csv`.

1. **Records.** All items of type `journal-article` for the journal's ISSN come from the CrossRef API, with one year of slack on each side of the window.
2. **Year.** A record's year is its print year. If CrossRef has none, the issue date is used, then the publication date, then the online date. Records outside the window are dropped.
3. **Abstracts.** CrossRef's abstract is used where the publisher deposited one. Records without one are looked up by DOI in OpenAlex, without an API key. An abstract shorter than 50 characters counts as missing.
4. **Paper IDs.** `<journal>_<year>_<first author's surname>`, with `_2`, `_3` added on a collision in order of volume, issue and page. Example: `ORSC_1991_March_2`.
5. **Non-research flag.** A script flags each record from its title and length. This flag only orders the work: the coder decides the item type again in section 4.
   - `non_research`: the title matches a pattern (editorial, erratum, reply, call for papers, index, and similar: the full list is in section 8.5), or the item has fewer than 5 pages, or fewer than 8 pages and no abstract.
   - `check`: 5 to 7 pages with an abstract.
   - `research`: everything else.
6. **Duplicates.** Some articles are registered under two DOIs. Two records are a pair if they share a normalized title and first author, or the same volume, issue and page range. The record with volume and issue is kept and the other is flagged `duplicate`. Flagged records stay in the files so that paper IDs don't shift, but they are never counted.

| Journal | Records | Duplicates | Abstract from CrossRef | From OpenAlex | Research-flagged records with no abstract |
|---|---|---|---|---|---|
| ORSC | 2,509 | 7 | 2,269 | 12 | 4 of 2,202 |
| SMJ | 3,376 | 61 | 2,554 | 505 | 20 of 2,951 |
| AMJ | 2,634 | 15 | 0 | 2,271 | 158 of 2,358 |
| JOM | 2,687 | 227 | 2,117 | 253 | 19 of 2,153 |
| ASQ | 2,007 | 0 | 550 | 311 | 194 of 750 |
| MNSC | 4,801 | 3 | 4,511 | 22 | 16 of 4,407 |

Three things to know about these lists.

- AMJ deposits no abstracts with CrossRef. All of its abstracts come from OpenAlex, and some are cut short.
- More than half of ASQ's records are book reviews and front matter. Its 1990s records carry a page field of "1", which is treated as an unknown length.
- The Journal of Management's 227 duplicates are its 1993–2003 articles, registered under both an Elsevier and a SAGE DOI.

## 3. Who codes, and how

The coder is a Claude agent. Each agent gets a set of batch files of 50 records and the codebooks, and writes one line of codes per record.

- **Input per record:** paper ID, journal, year, title, page count, the non-research flag, and the abstract or "[no abstract available]". Nothing else is looked up.
- **Rules.** The codebooks in `codebooks/` are the only rules. They were written and fixed before each coding run.
- **Instructions to the agent.** Read each record and decide its codes. Don't write a script, keyword rule or other shortcut that assigns codes. Use the codebook's full code words. Don't open another coder's files.
- **Validation.** A script checks every output file: the paper IDs match the input, every code is an allowed value, and the data fields are filled only for records that qualify. A batch that fails goes back to its coder.
- **Workload.** In the two runs whose logs we kept (Organization Science and the Journal of Management), an agent coded five or six batches, about 250 to 300 records.

The Journal of Management run used Claude Opus 5.5. The model version of the earlier runs wasn't recorded.

Organization Science was coded first, in two passes: routing for every record (`scripts/triage.py`), then data sources for the records that passed (`scripts/screen.py`). The other five journals were coded in one pass per record (`scripts/combined.py`) under the same two codebooks, joined by `codebooks/combined_codebook_v1.md`. Section 6 lists the differences.

## 4. Routing

Codebook: `codebooks/triage_codebook_v1.md`. Every record is coded, including those flagged non-research.

### 4.1 Item type and method

| Field | Values |
|---|---|
| `item_type` | `research`: a full article reporting research, including theory, review and "perspective" articles and full-length comments that reanalyse data. `non_research`: editorials, errata, book reviews, calls for papers, short commentaries and replies, special-issue introductions, interviews. |
| `method_primary` | The one method that produces the main results (list below) |
| `method_secondary` | Any other methods |
| `data_named` | Data sources named in the title or abstract, copied as written. Nothing is inferred here. |
| `access_guess` | `public`, `registration`, `subscription`, `restricted`, `original`, `none`, `unclear` |
| `confidence` | `high`: the abstract states method and data. `medium`: strongly implied. `low`: a guess, including every record without an abstract. |
| `rationale` | At most 25 words: the cue that decided the call |

Methods:

| Code | Meaning |
|---|---|
| `archival_quant` | Statistics on records that already existed: firm, industry or patent panels, filings, databases, platform data the authors collected but didn't create, secondary surveys |
| `survey_own` | A questionnaire the authors designed and ran |
| `experiment_lab` | Laboratory, online or vignette experiment |
| `experiment_field` | Randomized field experiment or intervention |
| `qualitative` | Ethnography, interviews, case studies, inductive or historical analysis |
| `simulation_formal` | Computational or analytical model. Results come from the model. |
| `meta_analysis` | Quantitative synthesis of earlier studies |
| `theory_review` | Conceptual work, literature review or essay with no new data analysis |
| `mixed` | Two or more methods carry the main results |
| `unclear` | The abstract doesn't reveal the method, or there is no abstract |

### 4.2 The routing decision

| `triage` | Papers |
|---|---|
| `candidate` | `archival_quant`, `meta_analysis`, `mixed` with an archival part, secondary surveys, and every research item whose method or access is `unclear` |
| `simulation` | `simulation_formal` with computational or numerical results that could be re-run from the paper |
| `exclude` | `non_research`, `theory_review`, `qualitative`, `survey_own`, both kinds of experiment, and analytical models with no numerical results |

A survey or experiment paper becomes a `candidate` if it says its data are posted or if it uses a public secondary survey.

The rule for doubt is to keep the paper in play. Routing aims at recall. The later steps decide what is replicable.

### 4.3 The Management Science field filter

Management Science publishes operations research, finance and marketing as well, and CrossRef doesn't record the department. So the coder also assigns each of its records a field.

| `field` | Covers |
|---|---|
| `strategy` | Competitive and corporate strategy, diversification, M&A, alliances, industry evolution, firm performance |
| `organizations` | Organization theory and design, organizational economics, organizational behavior and HR, teams, networks, careers inside organizations |
| `entrepreneurship_innovation` | Entrepreneurship, venture capital, R&D, patents, technology management, science and innovation policy, open source, knowledge flows |
| `other` | Operations research, operations and supply chain, finance, accounting, marketing, information systems, decision analysis, behavioral economics not about organizations, econometric methods, public policy outside innovation |

A record coded `other` is out of scope and routed `exclude`. Of 4,798 records, 3,927 are `other`. The 871 in scope are 332 entrepreneurship and innovation, 330 organizations and 209 strategy.

## 5. The public-data screen

Codebook: `codebooks/public_data_screen_v1.md`.

### 5.1 Which records are screened

A record is screened if it is research, routed `candidate` or `simulation`, not a duplicate, and at least 8 pages long. For Management Science it must also be in scope.

### 5.2 Evidence

The coder identifies the paper's core data: what defines the sample, the dependent variable and the key independent variables. Then the coder names the likely source of each. Three kinds of evidence are allowed.

1. **The setting.** The abstract gives the industry, unit, country and period, and the codebook maps settings to the sources they usually rest on. "U.S. commercial banks, 1990–2005" points to FDIC call reports, which are public. "S&P 500 firms' financial performance" points to Compustat.
2. **Sources named in the abstract.**
3. **The reference list** (Organization Science only). A script fetched each paper's references from CrossRef and flagged citations of dataset documentation, such as the NBER patent data file or Compustat. Citing a dataset is evidence, not proof. Section 8.3 lists the patterns and what they found.

The codebook's setting-to-source list:

| Tier | Settings and their usual sources |
|---|---|
| T0, usually public | U.S. patents (USPTO, PatentsView, NBER) · grants (NIH, NSF) · government contracts · SEC filings · banks (FDIC, FFIEC) · credit unions (NCUA) · hospitals (CMS) · nonprofits (IRS 990) · universities (IPEDS) · airlines (BTS/DOT) · recalls (NHTSA, CPSC) · FDA approvals and clinical trials · OSHA · EPA TRI · NLRB, BLS, CPS · Census business statistics · court opinions · Congress and elections (FEC) · sports statistics · film (IMDb, Box Office Mojo) · open source (GitHub) · Wikipedia · award records |
| T1, free after registration | GSS, NLSY, PSID, WVS, ISSP, GEM, PSED, National Organizations Study, IPUMS, ICPSR public-use files, World Bank Enterprise Surveys, World Management Survey |
| T2c, Compustat and CRSP | Public-firm financials and stock returns |
| T2, usually paid | M&A and alliances (SDC) · venture capital (VentureXpert, PitchBook) · executive pay and boards (ExecuComp, BoardEx, ISS) · analysts (I/B/E/S) · news (Factiva, LexisNexis) · non-U.S. firm registries (Orbis) · CSR ratings (KLD) · scanner data (Nielsen) · publications from Web of Science or Scopus |
| T3, usually restricted | Census microdata (LBD, LEHD) · Nordic registers · confidential tax data · Kauffman Firm Survey |
| T4, not obtainable | One firm's internal data · the authors' own surveys · field experiments · proprietary partner data |

There is one more tier, `R`: the data can be rebuilt from the paper itself, such as an event list printed in a table. A simulation or formal model gets the tier `none`.

Compustat and CRSP have their own tier because we plan to subscribe to them (decided 2026-09-30). Every other paid database stays T2, including those sold through WRDS.

### 5.3 Codes

| Field | Values | Meaning |
|---|---|---|
| `setting` | At most 12 words | For example "U.S. biotech firms' patents, 1980–2000" |
| `expected_sources` | List | The likely sources of the core data |
| `expected_tier` | `none`, `R`, `T0`, `T1`, `T2c`, `T2`, `T3`, `T4` | The least obtainable tier among the core sources |
| `negative_flags` | List, below | Reasons the data may not be obtainable |
| `public_likelihood` | `high`, `medium`, `low` | Section 5.4 |
| `feasibility` | `S`, `M`, `L` | Expected replication effort |
| `confidence`, `rationale` | | How strong the evidence is, and the deciding cue in at most 30 words |

| Flag | Meaning |
|---|---|
| `own_survey` | A survey by the authors carries results |
| `single_firm` | Internal records of one or a few firms |
| `subscription_db` | A T2 database |
| `restricted_admin` | Confidential administrative or register data |
| `hand_collected` | Assembled by the authors from many documents: public but costly |
| `web_vintage` | Scraped from a site whose past content can't be retrieved |
| `non_english_admin` | Administrative data from a country with limited open access |
| `old_vintage` | An older version of the source that may no longer be distributed |

Effort: `S` is one or two sources, standard models and fewer than about 8 tables and figures. `M` is several sources to merge, or specialized models. `L` is heavy hand-collection, very large raw data, unusual estimators or many targets.

### 5.4 Likelihood

- **High.** Every core source is `T0`, `T1`, `T2c` or `R`. The source is named, cited, or follows from an unambiguous setting. No flag applies except `hand_collected`. A simulation with a fully specified numerical model is also high.
- **Medium.** The setting normally uses public sources, but a control or secondary source is probably paid, or the source is only inferred from the setting, or `hand_collected`, `web_vintage` or `old_vintage` applies.
- **Low.** A core source is probably `T2`, `T3` or `T4`, or `own_survey`, `single_firm` or `restricted_admin` applies.

When the evidence conflicts, the coder takes the lower level. A paper whose abstract gives no setting is low, unless its references cite a public dataset.

## 6. Differences between the two coding designs

| | Organization Science | The other five journals |
|---|---|---|
| Passes | Two: routing, then data screen | One per record |
| Reference-list evidence | Yes | No. On Organization Science it added little. |
| Papers of unknown length | Not screened | Screened |
| Second coder | 10% of all records for routing (251), 10% of screened papers for the data screen (100) | A pooled sample for four journals, a 10% sample for the Journal of Management |

## 7. From codes to groups and targets

A script, not the coder, turns the tier into a group.

| Group | Rule |
|---|---|
| A, no data needed | Tier `none` and a simulation or formal model |
| B, public data | Tier `T0`, `T1` or `R` |
| C, public data plus Compustat or CRSP | Tier `T2c` |
| D, other paid database | Tier `T2` |
| E, restricted or own data | Tier `T3` or `T4`, or tier `none` on a paper that isn't a model |

A paper is a **target** if it is rated high, sits in groups A to C, and has no posted-data statement. The posted-data check is a text search of the abstract and the coder's rationale for phrases such as "data are available", "replication files", Zenodo, Dataverse or OSF. Papers it catches go to a validation arm, where they would be replicated without the package first. Section 8.4 gives the search terms.

Scripts: `scripts/screen_report.py` writes one readable list per journal, `scripts/screening_summary.py` the cross-journal report, and `scripts/target_list.py` the target list.

## 8. Where keywords and patterns are used

No keyword or pattern assigns a code. Every routing and data code comes from an agent reading the record, and the agents were told not to use keyword rules. Text matching by script appears in five places around the coding.

### 8.1 A keyword scan before the project (not part of the screen)

On 2026-09-29, before the codebooks were written, a keyword scan was run on the 2,269 Organization Science abstracts then available. Its results were recorded in the project's original plan, which isn't in this folder. The figures are repeated here.

| Quantity | Share of abstracts |
|---|---|
| Name no data source | 89% |
| Name a public source (patents, Census, EDGAR and similar) | 6.0% |
| Name a proprietary database (Compustat, SDC, VentureXpert and similar) | 5.6% |
| Research abstracts with a quantitative signal | about 59% |
| Qualitative, experiment or survey signal only | about 12% |
| Simulation signal only | about 3% |
| No method signal | about 27% |

This scan decided the design. An earlier sociology project had screened by dataset name, because sociology abstracts name their data ("GSS", "NLSY"). Management abstracts mostly don't, so the screen had to infer the source from the setting, and a person or agent had to read each record.

The scan's script and keyword list were not saved. The figures can't be reproduced from this folder, and nothing later depends on them.

### 8.2 A planned keyword pass that was not built

The plan for routing read "a keyword pass as in sociology, then Claude in batches". No keyword pass was written. `scripts/triage.py` and `scripts/combined.py` only cut the records into batches and check the coders' output.

### 8.3 Dataset citations in reference lists (Organization Science only)

`scripts/screen.py` fetches each screened paper's reference list from CrossRef. It joins each reference's DOI, title, journal, author and year into one lower-case string and searches it for the patterns below. A hit is passed to the coder as evidence, labelled with its class. The coder still decides the tier.

| Dataset | Class | Patterns (regular expressions) |
|---|---|---|
| NBER patent data | public | `10\.3386/w8498` · `nber patent citations? data file` · `hall,? jaffe,? (and\|&) trajtenberg.{0,40}2001` |
| Harvard patent/inventor disambiguation | public | `10\.1016/j\.respol\.2014\.01\.012` · `disambiguation and co-authorship networks of the u\.?s\.? patent inventor` · `lai,? d'?amour` |
| PatentsView | public | `patentsview` |
| Reliance on Science | public | `reliance on science` · `marx.{0,20}fuegi` |
| USPTO data | public | `uspto` · `patent and trademark office` |
| Census/BLS | public | `census bureau` · `county business patterns` · `bureau of labor statistics` · `current population survey` |
| OpenAlex/Microsoft Academic | public | `openalex` · `microsoft academic graph` |
| IPUMS | registration | `ipums` · `integrated public use microdata` |
| NLSY | registration | `national longitudinal survey` · `\bnlsy` |
| PSID | registration | `panel study of income dynamics` |
| GSS | registration | `general social survey` |
| WVS | registration | `world values survey` |
| GEM | registration | `global entrepreneurship monitor` |
| PSED | registration | `panel study of entrepreneurial dynamics` |
| Compustat/CRSP | WRDS | `compustat` · `\bcrsp\b` · `center for research in security prices` |
| SDC/Thomson | subscription | `\bsdc\b` · `securities data compan` · `thomson (financial\|reuters)` · `venturexpert` · `venture economics` |
| ExecuComp/BoardEx/ISS | subscription | `execucomp` · `boardex` · `riskmetrics` |
| KLD/MSCI | subscription | `\bkld\b` · `kinder,? lydenberg` |
| Orbis/Amadeus | subscription | `\borbis\b` · `amadeus` · `bureau van dijk` |
| VentureSource/PitchBook/Crunchbase | subscription | `venturesource` · `venture ?one` · `pitchbook` · `crunchbase` |

What it found: 946 of the 1,004 screened papers had a reference list in CrossRef (all 927 from 2000 on, and 19 of the 77 from the 1990s). Only 48 papers had a hit: NBER patent data 27, Harvard disambiguation 9, Census/BLS 6, GEM 3, SDC 2, USPTO 2, WVS 1, IPUMS 1. Authors rarely cite the documentation of the data they use, so this check added little and was dropped for the other journals. The hits are in `master/ORSC_ref_signals.json`.

### 8.4 Posted-data statements

A paper rated high in groups A to C is kept off the target list if either search below finds a match. `scripts/target_list.py` and `scripts/screening_summary.py` apply the same rule.

- In the abstract, ignoring case: `data[^.]{0,80}\b(are|is)\s+(publicly\s+|freely\s+)?available` · `supplemental material are available` · `zenodo` · `dataverse` · `osf\.io` · `openicpsr` · `replication (data|files|package|materials)` · `data (are |were )?posted`
- In the coder's rationale, ignoring case: `\bposted\b` · `replication data` · `supplemental data`

Of the 825 high papers in groups A to C, the abstract search catches 44 and the rationale search 5 more. That leaves the 776 targets. A match can be a false alarm: some statements only point to an online appendix, and step 3 checks each paper's package from the full text.

### 8.5 Non-research titles

`scripts/fetch_crossref.py` flags a record as non-research if its title starts with one of these: about the author(s), editorial, editor's note, introduction or comments, from the editor(s), note(s) from the editor, erratum, errata, correction, corrigendum, retraction, expression of concern, call for papers, proposals or submissions, in memoriam, obituary, acknowledg…, reviewer(s), editorial board, announcement, index, contents, comment(s) on, a comment, reply, a reply, response to, rejoinder, introduction to the special issue, special issue introduction, crossroads, issue information, masthead, front matter, back matter, publications received, notice, invitation or information to contributors, volume information, management insights, code of ethics, annual meeting.

It also flags a title that contains, anywhere: introduction to the special issue, a commentary, ": a reply", ": comment", ": reply", call for papers, or "special issue on … call".

The title rule flagged between 138 records (AMJ) and 280 (Management Science) per journal. The flag is only a starting point. The coder sees it and codes the item type again from the title and abstract.

### 8.6 What identifies the data, then

Two things, both the coder's reading:

- `data_named` records the sources the title or abstract names, copied as written;
- the setting-to-source list in section 5.2 maps what the paper studies to the source such a study normally uses.

## 9. Results

| Journal | Research articles | Excluded by routing | Screened | A | B | C | D | E | High in A to C | Targets |
|---|---|---|---|---|---|---|---|---|---|---|
| ORSC | 2,173 | 1,169 | 1,004 | 83 | 253 | 43 | 332 | 293 | 198 | 194 |
| SMJ | 2,898 | 876 | 2,003 | 61 | 427 | 234 | 988 | 293 | 292 | 284 |
| AMJ | 2,285 | 1,191 | 1,094 | 6 | 260 | 100 | 382 | 346 | 110 | 110 |
| JOM | 2,093 | 1,472 | 621 | 23 | 184 | 83 | 209 | 122 | 47 | 47 |
| ASQ | 752 | 343 | 409 | 15 | 121 | 30 | 145 | 98 | 45 | 44 |
| MNSC | 850 | 322 | 526 | 59 | 146 | 30 | 128 | 163 | 133 | 97 |
| **Total** | **11,051** | **5,373** | **5,657** | **247** | **1,391** | **520** | **2,184** | **1,315** | **825** | **776** |

A few routed papers aren't screened because they are shorter than 8 pages, so the excluded and screened columns don't sum to the research articles in every row.

Main method of the research articles, as coded from the abstract:

| Method | ORSC | SMJ | AMJ | JOM | ASQ | MNSC |
|---|---|---|---|---|---|---|
| Archival | 731 | 1,744 | 745 | 408 | 319 | 370 |
| Own survey | 232 | 325 | 621 | 556 | 79 | 89 |
| Qualitative | 417 | 146 | 335 | 50 | 186 | 14 |
| Theory or review | 322 | 266 | 21 | 730 | 33 | 25 |
| Mixed | 186 | 141 | 152 | 80 | 52 | 66 |
| Simulation or formal model | 108 | 120 | 6 | 25 | 16 | 196 |
| Lab experiment | 97 | 60 | 126 | 76 | 23 | 50 |
| Field experiment | 22 | 21 | 28 | 14 | 6 | 24 |
| Meta-analysis | 5 | 19 | 35 | 98 | 1 | 4 |
| Unclear | 53 | 56 | 216 | 56 | 37 | 12 |

AMJ's 216 unclear records and low count of theory papers reflect its missing and shortened abstracts.

## 10. Reliability

In every run a second coder re-coded a random sample without seeing the first coder's output. The samples were drawn by script with a fixed seed before coding began.

| Run | Sample | Routing | Method | Group |
|---|---|---|---|---|
| ORSC, routing pass | 251 records (10%) | 98%, κ = 0.97 | 91%, κ = 0.90 | |
| ORSC, data screen | 100 papers (10%) | | | 89%, κ = 0.84 |
| SMJ, AMJ, ASQ, MNSC pooled | 391 records | 97%, κ = 0.93 | 94%, κ = 0.92 | 88%, κ = 0.84 on 137 papers |
| JOM | 215 records (10%) | 98%, κ = 0.96 | 95%, κ = 0.94 | 97%, κ = 0.96 on 65 papers |

The group is compared only on papers both coders screened. On Organization Science the two coders agreed less on likelihood (87%, κ = 0.75) and least on effort (80%, κ = 0.57), so the effort rating should be read as rough.

The pooled sample holds 183 Management Science records. On those, the two coders gave the same field for 98% (κ = 0.94) and agreed on in scope against out of scope for 98% (κ = 0.95).

The pooled sample was drawn as 400 records across five journals. Strategy Science was dropped from the project on 2026-10-11, which leaves 391. Its 9 records remain in `coding/combined/REL/` as drawn and are ignored.

## 11. Limits

1. **The screen predicts.** It doesn't verify. In step 3 the full text confirmed 501 of the 776 targets (65%): 97% of group A, 51% of group B and 54% of group C.
2. **Meta-analyses were coded two ways.** Coders of five journals rated 60 of 64 meta-analyses high, treating the effect sizes as rebuildable from the paper. Coders of the Journal of Management rated 95 of 98 medium because the studies have to be collected by hand. The codebook allows both readings: section 5.4 lets `hand_collected` stand under high and also lists it under medium. Step 3 confirmed 6 of 63 meta-analyses, so the cautious reading is the right one, and the 60 high ratings overstate.
3. **Inferred sources are the weak point.** A setting names the usual source, not the one the paper used. Most group B papers that failed in step 3 turned out to need a paid database or a hand-built sample.
4. **The abstract doesn't show the controls.** Kwon, Park and Deng (2022, `ORSC_2022_Kwon`) is the known example. The screen rated it high in group C from "patent trades" by biopharma firms: public patent files plus Compustat. The full text agrees on that core, but every table also uses litigation and prior-tie controls from paid databases (Derwent LitAlert, Lex Machina, SDC). Step 3 gives it the verdict `partial`, and none of its tables can be rebuilt in full from obtainable data. Of the 501 papers step 3 confirmed, 64 are partial in this way.
5. **Coders sometimes used what they knew about a paper.** The paper ID shows the first author's surname, and with the title that is enough to recognize a well-known paper. Coders reported relying on such knowledge when an abstract was missing or cut short, mostly for 1990s AMJ and ASQ papers. They also named sources the abstract only describes, such as the Wisconsin Longitudinal Study for "a 1957–2004 cohort". This knowledge can be wrong, and nothing in the record checks it. These calls carry low or medium confidence.
6. **Abstracts are uneven.** 7% of AMJ's and 26% of ASQ's research-flagged records have no abstract and were coded from the title, which routes them to `candidate` with low confidence.
7. **Reference lists were used for one journal only.**
8. **The model version wasn't recorded** for the runs before the Journal of Management.

## 12. Files

| Path | Contents |
|---|---|
| `codebooks/` | The three codebooks, version 1 |
| `paper_lists/<J>_<year>.csv` | CrossRef records, one file per journal-year |
| `master/<J>_frame.csv`, `_frame_log.json` | All records of a journal, and the retrieval log |
| `master/<J>_triage.csv`, `_triage_summary.json` | Routing codes and their counts |
| `master/<J>_screen.csv`, `_screen_summary.json` | Data-screen codes for the screened papers, with reliability |
| `master/ORSC_ref_signals.json` | Dataset citations found in Organization Science reference lists |
| `master/COMBINED_reliability.json` | The pooled second-coder statistics |
| `coding/triage/ORSC/`, `coding/screen/ORSC/` | Organization Science: coders' batches and outputs, first and second pass |
| `coding/combined/<J>/` | The other journals: batches and outputs. `REL/` is the pooled second coding, and `JOM/rel_*` the Journal of Management's. |
| `reports/screening_summary.md` | The cross-journal report |
| `reports/journal_lists/<J>_tiered_list.md` | Every group A to C paper of a journal, with setting, sources and rating |
| `reports/target_papers/target_papers.csv` | The 776 targets, with DOIs |
