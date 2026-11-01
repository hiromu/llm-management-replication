# Replication Console

Replication Console connects paper-level replication attempts to inspectable evidence. It launches a research workflow from an uploaded article, records its execution, and presents the saved tables and figures beside the source PDF. Across studies brings documented barriers together so researchers can examine recurring gaps in sample definitions, variable construction and reporting.

The contribution is a common, auditable interface between research execution and evidence review: structured outputs, explicit scientific verdicts, source hashes and logs. Numerical agreement is descriptive; it does not determine a paper's overall verdict.

## Layout

| Location | Contents |
| --- | --- |
| `app/` | Independently runnable UI, backend, populated SQLite database, display evidence, execution prompts and result schema |
| `replication-results/` | Updated eight-study research archive, anonymous proposal and supplement, screening records, frozen protocols, and seven app-ready structured results |
| `README.md` | Start, browse and verify instructions |

## Start and browse

```bash
python3 app/server.py
```

Open http://127.0.0.1:8765. Python 3.10+ is sufficient to browse the existing results; fonts and PDF rendering libraries are included. The repository includes **seven papers and 817 assessment units** in `app/data/console.sqlite3`. The app reads and writes this database directly; no database copy or external result folder is needed. JSON, figures and displayed logs are alongside it under `app/data/`. Navigate between results with the arrow buttons, inspect completed execution records under Logs, or compare documented barriers under Across studies.

Bundled article viewers use one-page dummy PDFs. Privately uploaded original articles can be displayed, with page navigation enabled only for the recorded PDF version. No original articles or empirical input datasets are distributed here.

`app/` runs by itself with the existing seven papers, even when `replication-results/` is absent. New uploads and execution results are saved in the same database. To try an empty collection in a separate location:

```bash
REPLICATION_SEED_RESULTS=0 REPLICATION_RUNTIME=/absolute/path/to/new-runtime python3 app/server.py
```

Disabling seeding does not delete results from an existing database. Use a new runtime for an empty collection. The included database is writable, so using the app can change this tracked file; generated uploads and workspaces are ignored by Git.

## Run a new replication

Choose **New replication**, enter the citation and upload the article. The app creates an isolated workspace and queues the configured coordinator CLI. Real research requires authenticated model CLIs, access to the pinned models, source data and statistical tools; unavailable prerequisites are recorded as blockers. New outputs must satisfy the [result contract](app/protocol/RESULT_FORMAT.md) and source-hash checks before publication.

See [app setup and execution](app/README.md) for configuration and the distinction between a valid scientific output and a successful process exit.

## Verify

```bash
python3 replication-results/verify.py
```

This checks packaged evidence hashes, structured results, their referenced sources, and consistency with the app's bundled evidence and database, without model calls or empirical fitting. The [distribution guide](replication-results/DISTRIBUTION.md) explains the eight-study archive and seven-study app boundary. The [research overview](replication-results/README.md) identifies each paper's evidence and rerun requirements; the [proposal directory](replication-results/proposal/README.md) contains the updated anonymous proposal and technical supplement.

