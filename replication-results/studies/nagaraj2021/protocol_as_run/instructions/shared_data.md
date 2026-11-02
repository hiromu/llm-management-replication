# Shared-data rules

This file takes precedence over the other instruction files. The study's CLAUDE.md takes precedence over this file.

## Question
Can the two-reader, three-implementer workflow reconstruct a paper's results from the authors' deposited data and the written methods alone, and how does that reconstruction compare with the authors' own code?

## What differs from the public-source protocol
- A deposit with author code does not stop the study. The deposit is the reason the paper was selected.
- The empirical inputs are the deposited data files, plus any public file the study's CLAUDE.md names. No other data acquisition is needed.
- Deposited data are already author-processed. The study therefore does not test reconstruction of raw sources, and the report must say so.
- The author code, and any deposited file that holds author results or describes the code, stays sealed until the unsealing point below. STUDY.json lists what is sealed.

## Who receives what
| Role | Receives | Never receives |
| --- | --- | --- |
| Readers | Article, online appendix, deposited documentation the study's CLAUDE.md permits, data descriptions, column names | Data rows, author code, each other's work |
| Implementers | Neutral manifest, implementer data bundle, data descriptions, software notes | Article, appendices, preregistrations, targets, scoring rules, author code |
| Checkers | Manifest and code | Data results, targets, article, author code |
| Scorer | Frozen outputs, sealed targets, frozen rules | Author code, until scores are hashed |

Data descriptions contain definitions only. Check them for summary statistics before freezing the packet.

The implementer data bundle is built by code from data/raw/ into data/derived/. Use neutral file names. Remove or pseudonymize the identifying fields the study's CLAUDE.md lists, check every other file for free-text identifying fields, and record each column changed. Never print the values of removed or pseudonymized columns or send them to a model. Do not filter rows when building the bundle: sample construction belongs to the implementers.

## Unsealing point
Unseal sealed/author_package/ only after all of these exist and are hashed in logs/pre_unseal_hashes.json: reader outputs, frozen manifest and grid, implementer code and outputs, frozen scoring rules, and the scored comparison with published results. Record the hashes of the sealed files before and after unsealing and compare them with logs/osf_receipt.json.

Do not revise a frozen AI result, label or score after unsealing. Any later analysis is a labeled post-unsealing diagnostic.

## Three comparisons, reported separately
1. AI reconstruction against published results, scored by the frozen code. This is the protocol outcome.
2. Author code rerun on the deposited data against published results. Read the code before running it, because it is untrusted. Run it on a copy, outside data/raw/, with network denied. Record software and package versions and every change needed to make it run. A failure to run, or missing software, is a finding, not a reason to edit results.
3. AI code against author code: sample filters, variable construction, treatment or condition coding, estimators, fixed effects, covariance, clustering and bootstrap settings. Classify each difference by these written sources: stated in the article, stated only in an appendix, preregistration or deposit documentation, stated nowhere, or AI misreading. Report which differences change a result, using reruns with the frozen AI code changed one difference at a time. Keep these reruns labeled as post-unsealing diagnostics.

## Scope
The study's CLAUDE.md fixes the scope before any results. If time forces a reduction, record the reason and the reduced scope before empirical execution, and do not choose by results.

## Network isolation
Empirical runs execute with network denied through sandbox-exec, as follows, and the restriction is tested and recorded first:
sandbox-exec -p '(version 1)(allow default)(deny network*)' <command>
Implementer model processes need the network for their own API calls, so they may develop only against synthetic data with empirical data absent from their staging directory, unless isolation is otherwise enforced. The coordinator runs the frozen scripts on the empirical data. Disclose which restrictions were enforced and which were instruction-only.

## Licensing and privacy
Follow the license the OSF API reports in logs/osf_receipt.json. Where none is shown, do not rehost the data or the article; reports and any public artifact link to the deposit. Do not quote free-text or identifying fields in reports.

## Limits the report must state
- Author-processed data remove the sample-reconstruction problem that drives many gaps in public-source cases.
- A match does not establish that models did not recall the paper. Report memorization probe results.
- One paper does not generalize to its design class.
- The study-specific limits in the study's CLAUDE.md.
