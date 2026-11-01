# Thébaud (2015) — independent study

> **Public copy.** This folder is a finished run, published without data or the article (see [README.md](README.md)). The instructions below record how the run was set up; the shared protocol they name is at the repository root ([../../CLAUDE.md](../../CLAUDE.md), [../../instructions/](../../instructions/), [../../config/](../../config/)). Do not start a new run from this copy.

This session is exclusively for Thébaud (2015), study thebaud2015. The project-root CLAUDE.md and instructions/ files govern this study. Resolve the project root as ../.. when this folder is opened directly. Read STUDY.json, data/supplied/supplied_sources.json and ../../config/roles.json. Do not start or continue another paper here; deliver this study's artifacts and stop. Do not start research until the user authorizes it in this session.

## Supplied original source materials

The data/supplied/ICPSR_20320/ bundle in this folder was downloaded from ICPSR by the user, a human, and saved here. It belongs to this study only. No agent downloaded it. It is an explicit exception to the fresh-download requirement. It is original GEM survey-source material, not a focal-author replication package or prior replication output. Treat it as read-only. It holds DS0001/20320-0001-Data.sav, documentation, two codebooks and TermsOfUse.html. The dataset checksum matches the ICPSR manifest and SPSS metadata loads (2,796,985 records, 97 variables). The source role must still validate release, survey-year and variable coverage, weights, missing-value coding and terms. Do not assume that the harmonized file includes every variable the paper uses. Do not log in to or download from ICPSR; if an ICPSR file is missing, ask the user to download it.

After authorization, register the supplied files in this study's new registry and acquire all other original source inputs (for example country-level institutional indicators) afresh. Leave data/supplied/ unchanged; derived files go in data/derived/ and newly acquired sources in data/raw/. Never copy data/supplied/ into a reader's staging directory. Readers may receive newly prepared, summary-free source dictionaries and descriptions, never raw observations or unfiltered codebooks containing numerical summaries. Implementers receive only the neutral manifest and authorized numeric data under the shared role restrictions.

## Publication packet

The shared library supplies the article and one prepared supplement, both identified in STUDY.json. Follow ../../instructions/supplements.md: verify identity, version, hashes and completeness, check for additional material after authorization, and freeze an identical publication packet for both readers. Published numeric values remain sealed targets; do not use supplementary printed observations as empirical data. Check focal-author package availability independently.

Apart from data/supplied/, all working directories start empty. No target extraction, sample, specification grid, analysis code, report or result is supplied. Use study-relative outputs and immutable run directories. Do not inspect other studies, earlier sessions, other projects or archived replications.

## Reporting adaptation

Follow the shared reporting requirements, adapting the public-source reconstruction and influence-checks figure to this article's actual estimand. Label the coefficient or effect scale and its null value. Before fitting, justify and freeze the influence-deletion unit and diagnostic scope from the study design. Retain all eligible fits and failures. Influence ranges are not confidence intervals or automatically equivalent specifications. Do not prescribe estimates, classifications, specification counts or sample decisions at setup.
