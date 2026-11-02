# Implementer input leakage scan (v1)

Scanned: role_prompts/MANIFEST.md, implementer_assignment.md, LANGUAGE_R.txt, LANGUAGE_Julia.txt, synthetic/make_synthetic.py and the synthetic data.

- Text search for paper identity terms (author, journal, title words, DOI, year of publication, "published", "article"): no hits.
- Reviewed false positives: the roster count of 143 surveys in 24 countries equals the published survey and country counts. These are design constants that define the sample, not results. The manifest's thresholds (30 clusters, seed 20261028) are coordinator choices.
- Synthetic generating values were changed before release (intercept -2.0, female -0.5, female x childcare -0.25, female x leave 0.2) so that none resembles any published coefficient the coordinator has seen while reconciling targets.
- Sealed N values, published coefficients, SEs and stars are not present in any implementer input.
