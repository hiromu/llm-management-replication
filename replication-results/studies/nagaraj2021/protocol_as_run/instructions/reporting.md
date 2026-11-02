# Report requirements

User preference: include a reconstruction and influence-checks figure built from the deposited data. These are presentation and diagnostic requirements, not inherited empirical results or reader equivalence judgments. Build all tables and figures from this project's newly verified outputs. Do not inspect or copy archived figures, numerical values, code or verdicts.

## Main report

Report only the active paper in this session. Store reports and figure files under its studies/<study_id>/reports/ directory. Do not create cross-paper comparisons or a batch summary unless the user requests a separate task for that purpose.

Write the study's reports/replication_report.md in straightforward prose, without bold emphasis in the main text. Lead with the findings and their scope. Include:

- What was reconstructed, what was unavailable, and how the analysis inputs were independently constructed from the deposited data. State that the data were author-processed before deposit.
- The three comparisons required by shared_data.md, reported separately.
- Published-versus-reconstructed focal estimates, N, inference and relevant uncertainty. Distinguish claim-level classifications from the paper-level classification under the frozen protocol aggregation rule.
- One concrete example explaining the path from article text through reader interpretation, frozen specification, execution and scoring.
- A count of actual model settings and influence refits, with duplicates and algebraic checks distinguished. Show equivalent, uncertain and non-equivalent alternatives separately.
- Reader agreement and disagreements, coordinator decisions, exact executed model configurations, implementation agreement and verification limitations.
- The figure described below, followed by a brief explanation of what it supports and what it cannot establish.
- Supplements used, unavailable or excluded: identify document IDs, versions, cited pages, preparation/redaction status, main-text contradictions and gaps in the publication packet.
- Remaining source, coverage and measurement limitations, with links to detailed evidence.

Do not prescribe a result or classification in advance. Use the six outcome categories and reason codes in instructions/scoring.md and the frozen study scoring rules; disclose any uncalibrated or adapted rule. Do not turn an origin mismatch into specification fragility.

## Preferred figure: reconstruction and influence checks

Use a clear two-panel scientific plot with the same focal association rows in both panels. Include all eligible focal associations, with unavailable ones explicitly marked or listed alongside. Retain a fixed ordering chosen before inspecting results.

Left panel: published correlation as a cross; newly reconstructed correlation as a filled dot; the minimum-to-maximum correlation across all eligible single-observation deletion fits as a horizontal line. Use a zero reference line. Show adjusted models separately with their actual estimand, rather than mixing raw and partial correlations without labels.

Right panel: the corresponding reconstructed p value as a dot, and the complete deletion p-value range as a horizontal line on a logarithmic scale. State the tail and direction from the frozen inference rule. Draw the prespecified significance threshold. Handle numerically zero/underflow p values transparently; do not silently discard them.

The caption must say that deletion ranges are influence ranges, not confidence intervals. State sample sizes, missingness rules and deposit provenance and how measurements were independently reconstructed. Deletions are a separate influence diagnostic and do not automatically belong to the equivalent-specification set. The figure alone cannot establish a fragile verdict.

Before estimation, register which focal models receive leave-one-observation-out checks and retain every eligible deletion, including failed fits with reasons. Do not select deletions based on their effect or impose inherited model counts. If the diagnostic cannot be executed, report the missing input or reason rather than fabricate the range.

Save the figure as SVG and PNG, with a CSV of plotted values, identifiers and provenance, plus a reproducible plotting script. No PDF is required by this setup.

## Technical supplement and outputs

Write the study's reports/technical_supplement.md when needed to keep the main report concise. Include the frozen grid, sourced labels, inference and scoring rules, source provenance, rounding limitations, reader reconciliation, containment boundaries, failure/unavailability records and audit results. Export machine-readable claim comparisons, all specification results and influence results. Generate summaries from saved outputs; do not manually alter figures or tables to improve apparent agreement.

Keep this reporting brief with the coordinator/reporting role. Reader assignments remain independent and source-grounded. Presentation preferences must not decide their equivalence labels.
