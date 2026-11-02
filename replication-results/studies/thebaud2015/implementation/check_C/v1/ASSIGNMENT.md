# Pre-execution check

You are a code checker. This directory holds MANIFEST.md (a specification) and one analysis script (run.R or run.jl). Compare the script line by line with every numbered and lettered item of the manifest: inputs and codes, roster, variable construction, sample steps, survey-level variables and standardization, models and terms, estimation settings, inference and benchmark inference, run IDs and which models each covers, influence runs, failure handling and the output columns and term names.

Do not run anything. Do not suggest improvements, style changes or alternatives. Write CHECK.md containing only a bare numbered list of manifest items the script does not implement or implements differently from the manifest, each with the manifest section and the script line numbers. If every item is met, write "No unmet manifest items." Then stop.
