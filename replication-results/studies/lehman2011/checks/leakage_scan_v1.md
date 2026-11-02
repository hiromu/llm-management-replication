# Leakage scan of implementer inputs (v1)

Scanned files: manifest_neutral_v1.md, grid_v1.json, implementer_prompt_template.md, implementation/docs/*, and registry/data_dictionary.md (as regenerated with the crosswalk section). They were checked against 173 numeric values from both readers' sealed targets and N branches, plus identity terms (author surnames, journal, "deadline", "aspiration", "risk taking", "shifting", the page number).

Hits, all reviewed:
- "alge" in the manifest and grid: false positive; it is a substring of "algebraic".
- "aspiration" in grid_v1.json: removed (renamed "spread_based_reference_point") before freezing.
- "0.0001" in Python_statsmodels_Logit.txt: false positive; it is a statsmodels default tolerance in a docstring.
- Design constants that the implementers must see (evaluation points -42 to 42, minutes 53/38/23/8, the 120-second cutoff, seasons 2000-2005) are specification constants. They are not published estimates.

Result: no published estimate, SE, N, count or identity term remains in the implementer inputs.
