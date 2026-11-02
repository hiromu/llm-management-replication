# Coordinator reconciliation decisions, version 1

Inputs: readers/fable/initial_v1 and readers/astra/initial_v1 (sealed). Rules: reconciliation/rules_v1.md. Initial agreement: reconciliation/initial_agreement.json. No data were analysed before these decisions, and no clarification round was used.

## Structure

Both readers specify the same 22 reported regressions: 7 single-practice and 4 multi-practice models for each outcome, plus the HRM-block and interaction-block nested F tests. The union of claims is retained (19 Fable and 24 Astra claims; 15 matched content units, 1 Fable-only, 7 Astra-only). The unshown complementarity count, threshold and spline models and the for-profit/nonprofit subgroup analyses have no printed estimates. They are recorded as unavailable and not executed.

## Working origins set by the coordinator (readers disagreed or gave a non-executable origin)

| Decision | Working origin | Rule | Other levels |
|---|---|---|---|
| Sample scope | common complete cases within each outcome family | both readers list it; Fable origin; Astra's origin non-executable | model-specific: uncertain |
| Index item completeness | mean of available items | Fable origin executable; Astra's unresolved | all items, copy rule: uncertain |
| z-score reference | all records with a valid item | (c): computable without depending on the later sample | final sample (Fable origin), family sample, population SD: uncertain |
| Training logs | log all three items | (a): Table 1 footnote b is the more specific statement | log count only, no logs (Astra origin): uncertain |
| No-training establishments | skipped items missing | (b): no imputation | zero/lowest (Fable origin), zero count only: uncertain |
| Decision map | larger org 1, head+larger 2, head 3, head+below 4, below 5 | both readers' uncertain level, the instance named concretely by Fable and described generically by Astra | head lowest: uncertain |
| Union items | V220 + V233 | both readers list it as uncertain; it is the smallest set both describe as union influence | +V300, +V300+V166: uncertain |
| Hierarchy | ln(count), 100+ coded 100 | Fable origin executable; Astra's unresolved | 100+ missing, raw count: uncertain |
| Percent managers | 100 x managers / (full + part time); none = 0; same-occupation skips missing | executable core common to both origins; the percentage unit follows the text (rule a) | proportion: algebraic check; denominator NEWTOTAL, none missing: uncertain |
| 'Neither' product/service | excluded | (b) | in omitted group: uncertain |
| Market sample and outcome | does not require the organizational outcome | (c) | requires POP (Fable): uncertain |
| Industry | first listed SIC group; unspecified/unmapped grouped as UNCL | Fable origin executable; Astra's unresolved | exclude ambiguous/unmapped: uncertain |

Agreed origins kept as they stand:
- keep duplicate copies
- profit-making market sample
- log application counts, with special codes missing
- subsidiary = V17
- log age
- full-time plus part-time employment
- competition 1-4
- conventional OLS
- unweighted
- raw interaction products
- outcome = mean of reversed items

## Not executed

Non-equivalent levels (by agreement or by one reader, per the rules):
- three-point and binary decision recodes
- raw decision codes
- age unlogged under some labels (run as uncertain because of the label disagreement)
- outcome sum
- dropping no-training establishments
- 995/997 literal counts
- PCTUNION
- V339 employment
- separate 'neither' indicator
- Census categories or no industry controls
- ordered-response or factor-bundle estimators
- two-sided or multiplicity-adjusted inference
- HC1 as a specification (HC3 is computed for every fit as the declared benchmark adaptation)

Unavailable:
- Clustering by establishment: no validated establishment identifier; DUP/NUMOBS semantics were inferred by the source role, not documented.
- Clustering by industry: no basis for few-cluster inference and not an assignment unit.
- Complementarity count, threshold and spline models, and subgroup analyses: unshown, so there are no targets.

Algebraic checks (not alternatives):
- log base of hierarchy
- percent versus proportion of managers
- industry reference group
- log base of staffing items before z-scoring (invariant by construction; not run)
- sum versus mean of complete items
- dummy offsets
- solver choice

## Equivalent set

No substantive equivalent alternative survived reconciliation. Every level one reader called equivalent was either an algebraic re-expression (a check) or was labelled uncertain by the other reader. Under scoring.md, specification fragility is therefore not assessed; uncertain branches are reported separately.

## Transcription

191 of 192 regression-table cells agree. The differing cell, Table 3 model 3 F for delta R2, is resolved from the D1 image as `3.953*`. D1/D2 differences are kept in the sealed targets as publication diagnostics. One of them, Table 4 model 7 incentive compensation SE (D1 0.081, D2 0.061), uses D1 as governing.

## Influence diagnostic (frozen before fitting)

- Deletion unit: the establishment interview record (the observation and sampling unit). No clustering applies.
- Scope: the eight multi-practice models (org M2-M5, market M7-M10) at the origin specification.
- Every deletion is retained, including failures.
- Influence ranges are not confidence intervals and do not enter any equivalence set.

## Implementation design (frozen before implementation)

| Implementer | Family | Model | Language |
|---|---|---|---|
| A | Anthropic | claude-fable-5-1, High effort, normal speed | R (article language unspecified, so R) |
| B | OpenAI | gpt-6-astra, High effort, standard tier | R |
| C | Anthropic | claude-fable-5-1, High effort, normal speed | Python |

Pre-execution checkers: gpt-6-astra for A and C, claude-fable-5-1 for B.

No third model family is available, so the adversarial review cannot use a family independent of both implementation families. That limitation is recorded, and any fully verified discrepancy claim is withheld.
