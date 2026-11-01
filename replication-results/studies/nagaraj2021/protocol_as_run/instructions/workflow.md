# Execution workflow

## Session boundary

Execute this workflow for exactly one user-selected paper per coordinator session. All acquisition, reader, implementation, checking and reporting roles belong to that study. Keep artifacts inside its study folder; shared instructions and the PDF library may be read. Never iterate over the library as a batch, launch another paper, or carry role context into another study. On completion, deliver the study and stop. A different paper requires a separate user-started session.

## 1. Register the study and acquire sources
Follow supplements.md and shared_data.md: verify the supplied publication documents for the active paper, record gaps, and freeze the same publication packet for both readers. Empirical inputs are the deposited data files named in shared_data.md.

Record the paper identity, supplied PDF hash, planned scope, model configuration, compute budget and study ID. Make no assumption that data are obtainable. A source role validates the deposit in data/raw/ against logs/osf_receipt.json and builds a new study registry with coverage checks. Record provider, URL/query, acquisition time, license/access conditions, release/vintage, size and checksum. Keep raw files immutable. Record failed access attempts and missing sources. Do not evade access controls, buy access, contact authors, or substitute another source without a sourced frozen branch.

Build the registry before the numerical machine runs. Supply source descriptions and dictionaries listing definitions, units, types and coverage, with summary statistics removed. Implementers construct the sample from the manifest; the data role must not secretly choose the article's analysis sample. Check language loaders return equivalent data. Missing core sources lead to not attemptable for the affected scope. Missing controls require an explicit uncertain fallback or unavailable analysis, never silent omission. Do not substitute observations or summary-data matrices transcribed from the focal article for missing deposited data. Extract published results only as sealed comparison targets or publication diagnostics.

## 2. Two independent readers
Before each reader, run a separate title-and-authors-only memorization probe and seal its answers. Do not disclose the answers or previous study results to the reader. Supply identical assignment templates, input lists and the frozen article-and-supplement packet to the two different model families. Readers must consult every permitted matching supplement and cite document IDs and PDF pages. Preserve main-text/supplement contradictions in reconciliation. Freeze the common output schema before either reader starts.

Each reader produces:

- A claim map: each hypothesis or stated finding, supporting table/column/row, estimand, population, scale and tier. Tiers distinguish focal estimates, identification/inference diagnostics, robustness, descriptives and nuisance controls.
- A sealed targets file: coefficient, published SE, exact p or stars/inequality, alpha, tail/direction, N, model and source locator. Missing values remain missing. No-star entries are not exact p values.
- A target-free implementation manifest: ordered sample steps, variable definitions, source keys, estimator, fixed effects, covariance methods, software defaults, missingness and inference fields. Include an opaque paper ID; keep published N in a machine-evaluated branch outside implementer-visible targets.
- A specification space: axes/levels for genuine open decisions, a closest-described origin, sourced equivalent/non-equivalent/uncertain labels and rationales. Prioritize sample construction and variable coding, then fixed effects/clustering, then estimator. Alternatives must have an article or methodological-literature basis. Explicit control lists cannot be changed within the equivalent set. Distinct reported outcomes are not automatically interchangeable specifications.
- A wider space and documentation assessment: default/common/rare and justified/unjustified choices, structural counts and a holistic unusualness rating. These describe the documented choices and never determine a replication verdict. The wider grid is off unless explicitly included before execution.
- Inference fields: observation/sampling/assignment units, clusters, native SE method/software, first-stage strength where applicable; documentation scores for specificity, precision and exhaustiveness; item-specific unavailable-source and vintage fallbacks.
- Forensic observations based solely on the published record: consistency of coefficient/SE/test statistic/p/stars, N/df, table identities and transformations. Use whole rounding intervals before declaring an internal mismatch. Forensic findings are separate records, not automatic verdicts. Any published-table algebra is a sealed publication diagnostic, not analysis of registry data.

No reader estimates models from raw data or chooses an interpretation by numerical agreement. Preserve the first complete outputs and hashes before any coordinator feedback.

## 3. Coordinator reconciliation
Create a row-by-row ledger matching claims, tiers, axes and labels by a rule set before comparing outputs. Publish raw decisions, agreement counts and Gwet's AC1 with denominators; report undefined cases rather than forcing a value. Transcription agreement is a separate measure.

Retain agreements. Label disagreements become uncertain. Structural differences retain the union, with source locators and incompatibilities. Use written clarification requests only when necessary; preserve both original and revised versions and report initial agreement unchanged. Do not send results upstream or ask readers to agree for convenience. If treating uncertain options as equivalent would change the eventual verdict, flag label-sensitive and report both scores without choosing between them.

Freeze a finite machine-readable grid with sources, labels, compatible crossings, origin IDs, fallback rules, unavailable items and compute order. Do not invent a minimum number of specifications. Scan implementer inputs for identity and target leakage, with reviewed false positives where genuine design constants happen to equal targets. If the historical selection procedure is incomplete, distinguish fixed-equation reconstruction from selection replay and extensions.

## 4. Independent implementation
Use three implementations: A from model family 1 in the article's language (Stata if specified, otherwise R); B from family 2 in the same language; C from either family in another language. Record exact models and settings in a frozen role record. If resources make this impossible, document the degraded design before execution, never claim it is the full design.

Each fresh implementer sees only the neutral manifest and registry bundle, language and software defaults. No paper, published targets, score criteria, other implementer's work or model outputs. Browsing is disabled; supply needed software documentation before execution. Write one parameterized script covering the permitted grid. Abort with a reason is permitted.

A separate checker receives manifest and code only and returns a bare list of unmet manifest items. Implementers fix them or record unavailable items; preserve every code version. Validate meaningful synthetic cases and completeness before empirical fitting. Recheck any runtime repair before rerunning; do not expose target comparisons to the implementer.

## 5. Frozen execution
Hash inputs, code, manifest and scoring rules. Enforce file/network isolation for numerical processes where available and test the restrictions. Run origin, individual deviations, full equivalent crossings, then uncertain branches in the frozen order and budget. Keep sample construction reusable; prune only combinations excluded by the manifest. Evaluate the sealed N branch by code. Never select a sample after inspecting coefficient agreement.

For every requested specification retain status, errors, sample IDs, N, estimate, SE, native and benchmark inference, clusters, df, model fit and software routine. Preserve requested settings and distinct realized designs separately. Record environments, traces, immutable run IDs and checksums. Include unavailable analyses in the ledger. Freeze user-requested influence diagnostics before fitting and retain every eligible deletion, including failures.

## 6. Downstream comparison, audit and report
Use the deterministic scoring rules in scoring.md. First compare implementations; only then compare with targets. Auditors independently check transcription, source lineage, result completeness, calculation and scoring. An adversarial pass attempts to overturn every potential discrepant finding by checking labels, code, source vintage and the origin calculation. It needs a model family independent of the implementation families; if unavailable, record that limitation and withhold the fully verified discrepancy claim. Human confirmation was removed at the user's request; the report states that none was performed.

Publish claim records, a justified paper-level aggregation, coverage, disagreements and limitations. Corpus-level reader validation would require a random human double-coded sample of claim maps and labels. It is outside this single-paper session: record the relevant validation as pending or unavailable unless independently completed, and do not start other papers to obtain it. Keep all calibration, human review and acquisition work truthfully marked as planned, complete or unavailable.
