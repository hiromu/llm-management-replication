# Shared-data rules

This file takes precedence over the other instruction files.

## Question
Can the two-reader, three-implementer workflow reconstruct a paper's results from the authors' deposited data and the written methods alone, and how does that reconstruction compare with the authors' own code?

## What differs from the public-source protocol
- A deposit with author code does not stop the study. The deposit is the reason this paper was selected.
- The empirical inputs are the deposited CSV files. No other data acquisition is needed.
- Deposited data are already author-processed. The study therefore does not test reconstruction of raw sources, and the report must say so.
- The author script stays sealed until the unsealing point below.

## Who receives what
| Role | Receives | Never receives |
| --- | --- | --- |
| Readers | Article, Online Appendix, AppendixA, preregistrations, deviation report, dictionaries, column names | Data rows, author code, each other's work |
| Implementers | Neutral manifest, implementer data bundle, dictionaries, software notes | Article, preregistrations, appendices, deviation reports, targets, scoring rules, author code |
| Checkers | Manifest and code | Data results, targets, article, author code |
| Scorer | Frozen outputs, sealed targets, frozen rules | Author code, until scores are hashed |

Readers' dictionaries contain definitions only. Check them for summary statistics before freezing the packet.

The implementer data bundle is built by code from data/raw/osf_3h6vc/ into data/derived/. Use neutral file names. Remove the free-text columns name_person and gender_person_text from the Study 1 file. Check the other three files for free-text identifying fields and remove any you find, recording the columns removed. Never print the values of removed columns or send them to a model. Do not filter rows when building the bundle: sample construction belongs to the implementers.

## Unsealing point
Unseal sealed/author_package/ltran_analysis_script.Rmd only after all of these exist and are hashed in logs/pre_unseal_hashes.json: reader outputs, frozen manifest and grid, implementer code and outputs, frozen scoring rules, and the scored comparison with published results. Record the hash of the script before and after unsealing and compare it with logs/osf_receipt.json.

Do not revise a frozen AI result, label or score after unsealing. Any later analysis is a labeled post-unsealing diagnostic.

## Three comparisons, reported separately
1. AI reconstruction against published results, scored by the frozen code. This is the protocol outcome.
2. Author script rerun on the deposited data against published results. Read the script before running it, because it is untrusted. Run it on a copy, outside data/raw/, with network denied. Record package versions and every change needed to make it run. A failure to run is a finding, not a reason to edit results.
3. AI code against author code: sample filters, scale construction, condition coding, estimators, covariance and bootstrap settings. Classify each difference by these written sources: stated in the article, stated only in the preregistration or dictionary, stated nowhere, or AI misreading. Report which differences change a result, using reruns with the frozen AI code changed one difference at a time. Keep these reruns labeled as post-unsealing diagnostics.

## Scope
The scope is the four main-text studies, Studies 1, 2, 3 and 4. Supplemental Studies S1-S7 are out of scope. Both are fixed before any results. If time forces a reduction, record the reason and the reduced scope before empirical execution, and do not choose by results.

## Network isolation
Empirical runs execute with network denied through sandbox-exec, as follows, and the restriction is tested and recorded first:
sandbox-exec -p '(version 1)(allow default)(deny network*)' <command>
Implementer model processes need the network for their own API calls, so they may develop only against synthetic data with empirical data absent from their staging directory, unless isolation is otherwise enforced. The coordinator runs the frozen scripts on the empirical data. Disclose which restrictions were enforced and which were instruction-only.

## Licensing and privacy
The OSF API showed no license for this deposit. Do not rehost the data or the article. Reports and any public artifact link to https://osf.io/3h6vc. Do not quote free-text participant responses in reports.

## Limits the report must state
- One paper from authors who shared voluntarily, with preregistrations and dictionaries. It was received August 1, 2023, before the journal's data rules for submissions from August 1, 2025. It is likely a favorable case.
- Author-processed data remove the sample-reconstruction problem that drives many gaps in public-source cases.
- A match does not establish that models did not recall the paper. Report memorization probe results.
- The result does not generalize to experiments as a class.
