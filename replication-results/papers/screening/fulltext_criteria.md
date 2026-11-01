# Full-text coding criteria, version 1

Sections 2 and 3 below are copied word for word from the README of the 420-paper sample (`sample_with_pdf/README.md`), where they were written and frozen on 2026-10-03 before any coding. `coding_log.json` holds the hash of section 2, and `scripts/fulltext.py` stops if it changes. A change to the criteria is version 2 and needs a re-run.

## 2. Criteria

Code in this order. Steps 2.1, 2.2, 2.3 and 2.5 can end the coding of a paper.

### 2.1 PDF check (`pdf_check`)

| Code | Meaning | What to do |
|---|---|---|
| `ok` | The PDF is the article in the bib entry and is complete | Go on |
| `extra_material` | The article plus other content: a whole issue, a manuscript version, a bundled appendix | Code the article and its own appendix. Give the page range in `pdf_note`. |
| `incomplete` | Pages are missing | Code what is there, with `confidence = low` |
| `wrong_paper` | A different article | Stop. No other codes. |

### 2.2 Research or not (`item_type`)

| Code | Meaning |
|---|---|
| `research` | A full article reporting research: empirical, simulation or formal, theory development, or review. "Perspective" essays and research notes count. So does a full-length comment that reanalyses data. |
| `non_research` | Editorials, calls for papers, working-paper lists, errata, book reviews, short comments and replies, special-issue introductions, interviews |

`non_research` ends the coding, with `triage = exclude`.

### 2.3 Field (`field`, Management Science only)

Management Science papers outside strategy, organizations and innovation are out of scope, as in the abstract screen. The coder assigns each Management Science paper one field.

| Code | Covers |
|---|---|
| `strategy` | Competitive and corporate strategy, diversification, M&A, alliances, industry evolution, firm performance |
| `organizations` | Organization theory and design, organizational economics, organizational behavior and HR, teams, networks, careers inside organizations |
| `entrepreneurship_innovation` | Entrepreneurship, venture capital, R&D, patents, technology management, science and innovation policy, open source, knowledge flows |
| `other` | Operations research, operations and supply chain, finance, accounting, marketing, information systems, decision analysis, econometric methods |

For a paper coded `other`, code `method_primary`, set `triage = exclude`, and stop. Every other journal gets `n/a`.

### 2.4 Method (`method_primary`)

Pick the one method that produces the main results.

| Code | Meaning |
|---|---|
| `archival_quant` | Statistics on records that already existed: firm, industry or patent panels, filings, databases, platform data the authors collected but didn't create, secondary surveys such as GSS |
| `survey_own` | A questionnaire the authors designed and ran |
| `experiment_lab` | Laboratory, online or vignette experiment |
| `experiment_field` | Randomized field experiment or intervention |
| `qualitative` | Ethnography, interviews, case studies, inductive or historical analysis |
| `simulation_formal` | Computational model (NK, agent-based, system dynamics) or analytical model. Results come from the model. |
| `meta_analysis` | Quantitative synthesis of earlier studies |
| `theory_review` | Conceptual work, literature review or essay with no new data analysis |
| `mixed` | Two or more methods carry the main results. List them in `method_secondary`. |
| `unclear` | The PDF is too damaged to tell |

### 2.5 Routing (`triage`)

| Code | Papers |
|---|---|
| `candidate` | `archival_quant`, `meta_analysis`, and `mixed` with an archival part |
| `simulation` | `simulation_formal` with computed or numerical results |
| `exclude` | `non_research`, `theory_review`, `qualitative`, `survey_own`, `experiment_lab`, `experiment_field`, and analytical models with no numerical results |

A survey or experiment paper becomes `candidate` if the paper says where its data are posted, or if the survey is a public secondary one.

When the routing is in doubt, choose `candidate`. `exclude` ends the coding.

### 2.6 Data sources (`sources`, candidates only)

One entry per data source used in the main-text analyses.

| Field | Content |
|---|---|
| `source` | The name as the paper writes it |
| `role` | `sample` (defines the sample or the list of units), `dependent`, `key_independent`, `control`, `robustness`. A source with several roles takes the first that applies. |
| `tier` | From the table below |
| `flags` | From the list below, separated by `;` |
| `where` | URL, archive or vendor, or "printed in the paper". Note a known substitute here. |
| `page`, `quote` | PDF page (1 is the file's first page) and at most 25 words copied from the paper |

Core sources are those with role `sample`, `dependent` or `key_independent`.

The tier answers one question: can this source be obtained today?

| Tier | Meaning | Examples |
|---|---|---|
| `R` | Printed in the paper | A data table or list of dates in the article, effect sizes in a meta-analysis appendix |
| `T0` | Public, no registration | USPTO and PatentsView, Census tables, BLS, SEC EDGAR, FDIC call reports, CMS, FEC, sports records, GitHub and Wikipedia dumps |
| `T1` | Public after free registration | IPUMS, ICPSR public-use files, GSS, NLSY, PSID, WVS, GEM, World Bank Enterprise Surveys |
| `T5` | Posted by the authors | Dataverse, OSF, Zenodo, journal supplement, author website |
| `T2c` | Compustat or CRSP | Counted as obtainable (decision of 2026-09-30) |
| `T2` | Other subscription database | SDC, VentureXpert, ExecuComp, BoardEx, I/B/E/S, Factiva, Orbis, KLD, Nielsen, Web of Science |
| `T3` | Restricted, by application | Census RDC microdata, LEHD, Nordic registers, confidential tax data |
| `T4` | Not obtainable | The authors' own survey, interviews or experiment, one firm's internal records, proprietary partner data |

The order from most to least obtainable is `R`, `T0`, `T1`, `T5`, `T2c`, `T2`, `T3`, `T4`. "Obtainable" means `R`, `T0`, `T1`, `T5` or `T2c`.

| Flag | Meaning |
|---|---|
| `own_survey` | A survey by the authors |
| `single_firm` | Internal records of one or a few firms, named or not |
| `subscription_db` | A T2 database |
| `restricted_admin` | Confidential administrative or register data |
| `hand_collected` | Assembled by the authors from many documents |
| `web_vintage` | Scraped from a site whose past content can't be retrieved |
| `non_english_admin` | Administrative data from a country with limited open access |
| `old_vintage` | The version the paper used may no longer be distributed |
| `on_request` | "Available from the authors on request" |
| `source_unnamed` | The paper describes the source but doesn't name it |

The last two flags are new. The first eight are the abstract screen's.

### 2.7 Paper-level codes

Coded for `candidate` and `simulation` papers. `confidence` and `rationale` are filled for every paper, and for an excluded paper they describe the routing call.

| Field | Values | Meaning |
|---|---|---|
| `n_targets` | Integer | Main-text tables and figures that report empirical or numerical results |
| `targets_obtainable` | `all`, `some`, `none` | How many of those rest only on obtainable sources |
| `has_replication_package` | `yes`, `no` | The paper says its data or code are posted. Give the location in `package_where`. |
| `needs_supplement` | `yes`, `no` | The data description or a main result sits in an online appendix that isn't in the PDF |
| `model_specified` | `full`, `partial`, `no` | Simulation papers only: does the paper give the algorithm and every parameter value? |
| `feasibility` | `S`, `M`, `L` | S: one or two sources, standard models, fewer than about 8 targets. M: several sources to merge, or specialized models. L: heavy hand-collection, very large raw data, unusual estimators, or many targets. |
| `special_software` | Text | A named estimator or package with no standard R or Python equivalent |
| `confidence` | `high`, `medium`, `low` | High: the paper names every core source and how it was obtained. Medium: a core source is described but not named. Low: the coder had to guess, or the PDF is incomplete. |
| `rationale` | At most 30 words | The passage that decided the call |

Three fields are derived by script, never by the coder:

| Field | Rule |
|---|---|
| `max_core_tier` | The least obtainable tier among the core sources |
| `tier_group` | A: `triage = simulation`. B: `max_core_tier` is `R`, `T0`, `T1` or `T5`. C: `T2c`. D: `T2`. E: `T3` or `T4`. Empty for excluded papers. |
| `data_availability` | `no_data_needed`: group A. `public`: group B or C and every control and robustness source is obtainable. `partial`: group B or C with a control or robustness source in `T2` to `T4`. `restricted`: group D or E. |

Papers in groups A to C with `has_replication_package = no` are the package-free targets. Those with `yes` go to the validation arm.

### 2.8 Hard cases

1. Code the source the paper used, not one that could stand in for it. Web of Science stays `T2` even if OpenAlex would do. Put the substitute in `where`.
2. An unnamed source takes its tier from the description. "Proprietary", "confidential" or "provided by the firm" is `T4`. "Publicly available" with no name is `T0` with `source_unnamed` and `confidence = low`.
3. "Available from the authors on request" is `T4` with `on_request`. A package-free replication can't depend on the authors answering.
4. Data hand-collected from public documents are `T0` with `hand_collected`.
5. Printed sources in older papers: government publications (Census volumes, Statistical Abstract) are `T0` with `old_vintage`. Commercial manuals and directories (Moody's, Dun & Bradstreet, trade directories) are `T2` with `old_vintage`.
6. Compustat and CRSP are `T2c` at any vintage. Every other WRDS product is `T2`.
7. `T5` needs a named location: a repository, DOI, URL or journal supplement. The coder records it and doesn't visit it.
8. A paper with several studies: every study that produces a main-text result has core sources. The group follows the worst one, and `targets_obtainable` records how much survives.
9. Survey plus archival data: the survey is a core `T4` source if it supplies the sample, the dependent variable or a key independent variable.
10. Meta-analysis: `R` if the coded effect sizes are printed. Otherwise `T2` with `hand_collected`, since they'd have to be extracted again from the primary articles.
11. Data from an earlier study by the same authors are `T4`, unless that study's data are archived.
12. When the tier is in doubt, take the less obtainable one. This is the opposite of the routing rule in §2.5, on purpose: routing keeps papers in play, and the tier decides what gets replicated.

## 3. Output

One file per paper, `coding/<paper_id>.json`. Fields a step didn't reach stay `""`, and `sources` stays `[]`.

```json
{
  "paper_id": "SMJ_2012_Example",
  "bib_key": "example2012_ShortTitle",
  "pdf_check": "ok",
  "pdf_note": "",
  "item_type": "research",
  "field": "n/a",
  "method_primary": "archival_quant",
  "method_secondary": "",
  "triage": "candidate",
  "sources": [
    {"source": "USPTO patent grants", "role": "dependent", "tier": "T0", "flags": "",
     "where": "PatentsView", "page": 9, "quote": "..."},
    {"source": "Compustat", "role": "control", "tier": "T2c", "flags": "",
     "where": "WRDS", "page": 10, "quote": "..."}
  ],
  "n_targets": 6,
  "targets_obtainable": "all",
  "has_replication_package": "no",
  "package_where": "",
  "needs_supplement": "no",
  "model_specified": "",
  "feasibility": "M",
  "special_software": "",
  "confidence": "high",
  "rationale": "Patent counts from USPTO, firm controls from Compustat, no survey or proprietary source."
}
```

`paper_id` is the abstract-screen ID when the DOI matches. Otherwise build it the same way: journal code, year, first author's surname, with `_2` on a collision. Journal of Management is `JOM`.
