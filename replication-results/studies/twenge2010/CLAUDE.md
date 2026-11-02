# Twenge et al. (2010) — independent study

> **Public copy.** This folder is a finished run, published without data or the article (see [README.md](README.md)). The instructions below record how the run was set up; the shared protocol they name is at the repository root ([../../CLAUDE.md](../../CLAUDE.md), [../../instructions/](../../instructions/), [../../config/](../../config/)). Do not start a new run from this copy.

This session is exclusively for Twenge, Campbell, Hoffman and Lance (2010), study twenge2010. The project-root CLAUDE.md and instructions/ files govern this study. Resolve the project root as ../.. when this folder is opened directly. Read STUDY.json, data/supplied/supplied_sources.json and ../../config/roles.json. Do not start or continue another paper here; deliver this study's artifacts and stop. Do not start research until the user authorizes it in this session.

## Supplied original source materials

The data/supplied/ICPSR_07927/, ICPSR_09871/ and ICPSR_20022/ bundles in this folder are the Monitoring the Future 12th-grade surveys for 1976 (V4), 1991 (V1) and 2006 (V3). The user, a human, downloaded them from ICPSR and saved them; no agent downloaded them. They belong to this study only and are an explicit exception to the fresh-download requirement. They are original survey-source material, not a focal-author replication package or prior replication output. Treat them as read-only. The 1976 and 1991 data are SPSS portable (.por) files and the 2006 data are SPSS system (.sav) files, with codebooks or user guide, manifests and TermsOfUse.html. All 20 data-file MD5s match the ICPSR manifests and SPSS metadata loads for each. The source role must still validate release, questionnaire and analytical variable coverage, weights, missing-value coding, cross-year comparability and terms. Do not log in to or download from ICPSR; if an ICPSR file is missing, ask the user to download it.

Identify questionnaire forms by the provider's dataset labels, not by dataset number. In 1976, Forms 3 and 4 are DS0003 and DS0004; in 1991 and 2006 they are DS0004 and DS0005, and DS0001 is core data. Confirm this against the documentation. Keep respondents from different forms in separate samples; do not merge them or tune exclusions to a published N.

After authorization, register the supplied files in this study's new registry and acquire any other original source inputs afresh. Leave data/supplied/ unchanged; derived files go in data/derived/ and newly acquired sources in data/raw/. Never copy data/supplied/ into a reader's staging directory. Readers may receive newly prepared, summary-free source dictionaries and descriptions, never raw observations or unfiltered codebooks containing numerical summaries. Implementers receive only the neutral manifest and authorized numeric data under the shared role restrictions.

## Publication packet

The shared library supplies the article, identified and hashed in STUDY.json. No matching supplement is in the prepared catalog. Follow ../../instructions/supplements.md: check publisher materials, corrections and appendices after authorization, and freeze an identical publication packet for both readers. Published numeric values remain sealed targets; do not use printed observations, matrices or tables as empirical data. Check focal-author package availability independently.

Apart from data/supplied/, all working directories start empty. No target extraction, sample, specification grid, analysis code, report or result is supplied. Use study-relative outputs and immutable run directories. Do not inspect other studies, earlier sessions, other projects or archived replications, including the Codex project's twenge2010 folder.

## Reporting adaptation

Follow the shared reporting requirements, adapting the public-source reconstruction and influence-checks figure to this article's actual estimand. Label the effect scale and its null value. Separate descriptive reconstruction of the cross-year differences from their interpretation as generational or time-period effects. Before fitting, justify and freeze the influence-deletion unit and diagnostic scope from the study design. Retain all eligible fits and failures. Influence ranges are not confidence intervals or automatically equivalent specifications. Do not prescribe estimates, classifications, specification counts or sample decisions at setup.
