# Memorization probes

Run before the readers, title-and-author prompt only (prompts_frozen/probe_prompt.txt), no tools, separate processes, answers sealed in sealed/probes/ (hashes in sealed/probes_sha256.txt) and opened by the coordinator only after both readers finished.

| Probe | Model and speed | Recall | Design recalled | Numbers recalled | Deposit recalled |
| --- | --- | --- | --- | --- | --- |
| probe_opus | claude-opus-5-5, fast (reported "fast") | partly | OSM county panel; TIGER import as seeding; variation in seed completeness; DiD with county and time FE; negative effect on contributions and contributors; ownership mechanism | none (declined) | none |
| probe_astra | gpt-6-astra, Ultrafast requested (tier not reported by the CLI) | partly | OSM histories; TIGER import as seeding; comparison groups and estimators not recalled | none (declined) | none |

Both models know the paper's topic and direction of the headline finding. Neither recalled sample sizes, coefficients or deposit contents. The Opus probe's description of the design is more specific than Astra's. A match between reconstruction and publication therefore cannot exclude recall of the qualitative finding, but no probe showed recall of numerical targets.
