# Memorization probes (sealed from readers)

Prompt: title and author only, answer from memory, no tools (identical prompt.txt in each folder).

| Probe | Model requested | Model reported | Exact numerical results recalled | Design recalled |
| --- | --- | --- | --- | --- |
| reader_a_fable | claude-fable-5-1, high | claude-fable-5-1 (modelUsage) | None; states coefficients, SEs, N and descriptives not recalled (one guess: mean ROA about 1%) | Twin Cities banks, Call Reports, ROA, asset-allocation similarity with linear and squared terms, inverted-U finding. Several wrong or guessed details (similarity sign-reversed, log assets and year dummies as controls). |
| reader_b_astra | gpt-6-astra, high | not exposed by codex exec; CLI accepted -m gpt-6-astra | None | Twin Cities banks, 1985-1992 (tentative), ROA, strategic deviation from asset-allocation means with squared term, strategic-balance finding. |

Interpretation: both models know the paper's broad design and qualitative finding. Neither reproduces published coefficients, SEs, N or descriptive statistics. Prior knowledge of the qualitative inverted-U result is a contamination risk for readers' labelling (not for numbers); readers are instructed not to correct article values from memory.
