# Replication Console app

A standalone Python HTTP server, SQLite repository and browser interface. This directory contains the complete app, execution protocol and output contract. It can run outside the surrounding repository.

## Layout

| Path | Responsibility |
| --- | --- |
| `server.py` | Start the application |
| `backend/` | HTTP API, research execution, SQLite, result validation and uploaded media |
| `static/` | Browser UI, fonts, PDF.js and the fallback PDF |
| `protocol/` | Research instructions, prompts, output format and an editable result example |
| `data/` | Writable SQLite database, reviewed result JSON, figures and logs |

The backend has no paper-specific adapters or study IDs. It reads every saved study through the same result contract. Collection order and additional log paths are declared in `data/manifest.json`; adding a reviewed paper does not require editing Python code. JSON imports accept schema version 1. Historical conversion code and video replay tooling remain in Git history; scientific rescoring code belongs to `replication-results/`.

## Start

```bash
cd app
python3 server.py
```

Open http://127.0.0.1:8765. Python 3.10+ and the standard library suffice for serving the app, persistence and evidence viewing. Node is needed only for refreshing the vendored PDF renderer.

The checked-in `data/console.sqlite3` already contains seven papers and 817 assessment units. The app opens this file directly for reading and writing. It does not copy a template into another runtime. Ordered result JSON, figures and displayed logs are all under `data/`; no path outside `app/` is needed for normal operation.

The database is writable; using the app can modify the tracked SQLite file. Its original seven-paper contents are built from reviewed JSON, with no user uploads, private job history or credentials. New files go to ignored `data/runs/`, `data/results/` and `data/media/`. SQLite sidecars and the server lock are ignored as well. Immutable evidence files have checksums; the mutable database is intentionally excluded from those checksums.

If the database is missing, the app recreates it from local result JSON. If the whole data package is absent, it starts empty and still supports upload and research. `REPLICATION_SEED_RESULTS=0` disables JSON seeding, without deleting existing database rows. Use it with `REPLICATION_RUNTIME=/absolute/path/to/new-directory` for a separate empty collection. An explicit `REPLICATION_ARCHIVE_ROOT` is an optional maintenance override; it is not needed to use the shipped app.

## New research

1. **New replication → Upload and start** saves the PDF and SHA-256, creates a fresh workspace and queues the run. Jobs execute sequentially in separate coordinator processes.
2. The worker launches the installed Claude CLI with the model in `protocol/config/roles.json`. Authenticate the required CLIs on the host. The protocol also requires independent reader/implementation roles and statistical tools; CLI presence alone does not verify access.
3. The coordinator follows `protocol/` for source acquisition, independent reading, reconciliation, frozen implementation, scoring and review. Each workspace records installed protocol checksums. Source availability and model settings must be verified, without silent substitutions.
4. Real process output becomes timestamped logs and SQLite events. The coordinator writes the [structured output](protocol/RESULT_FORMAT.md) from saved evidence, following [console-output.md](protocol/prompts/console-output.md). These export instructions belong to the coordinator/exporter, never implementers receiving sealed inputs.
5. The worker checks identity, finite values, source paths and hashes, snapshots evidence, then publishes results and terminal run state atomically. Figure files are copied into `data/results/<result-id>/`, with `result.json` beside them and checksummed evidence under `evidence/`. Figures remain readable after the execution workspace is removed. Missing or unregistered figures prevent publication. One downstream export/repair pass is allowed; it cannot refit models or invent findings.
6. Compare displays ordered tables/figures with source PDF navigation. Logs opens at the end of completed output. Across studies reads documented issues from the same result contract.

A zero process exit without a valid export is **review required**, not a completed replication. A blocked export retains its known evidence and missing prerequisites. **Add source files** saves checksummed inputs to an inactive workspace; an explicit Research retry resumes through protocol validation. New runs cannot overwrite historical studies: each published run has a unique result ID.

**Stop** terminates the owned process group and prevents late publication. Queued/running jobs become interrupted after a server restart and need an explicit retry. The default timeout is six hours per coordinator/export process, configurable with `REPLICATION_RUN_TIMEOUT_SECONDS`. This is not a spending limit for nested roles.

The launcher is local process management, not an OS sandbox or multi-user service. Bind to localhost. The scientific protocol requires actual verification and disclosure of role isolation, model access and source limits. Credentials belong in the host CLI configuration/environment, not in the database or repository.

## Result and storage boundary

`backend/result_contract.py` defines schema version 1 for study metadata, verdicts, estimates, ordered displays, PDF locations, issues, execution state, report, blockers and evidence hashes. Unavailable values remain missing. Paper verdicts are explicit scientific outputs and are never derived from agreement percentages. Multiple origins and contradictory targets remain distinct.

```text
data/
  console.sqlite3                Included writable DB: seven papers, plus new work
  manifest.json                  Hashes of immutable display evidence
  studies/<paper-id>/result.json Reviewed result JSON
  studies/<paper-id>/...          Figures, reports and logs used by the app
  runs/<id>/workspace/            Uploaded PDF, pinned protocol, research and export
  runs/<id>/console.log           Readable captured process output
  runs/<id>/model-events.jsonl    Raw CLI stream
  results/<result-id>/result.json Portable JSON with local figure paths
  results/<result-id>/<hash>.*    Saved figures (PNG/JPEG/WebP/PDF)
  results/<result-id>/evidence/   Checksummed source snapshots
  media/<result-id>/              PDF versions and viewer state
```

SQLite uses WAL, foreign keys and transactions. Back up the full runtime, using SQLite's backup API for a live database. Keep one server per runtime. The `data/studies/` evidence remains read-only; new run outputs use the separate writable directories shown above. Keep the whole `data/` directory with the database so its figures and logs remain available.

Uploaded article PDFs are displayed from their saved bytes. If no article is attached or its saved file is missing, the viewer falls back to `static/paper-placeholder.pdf`, including for new studies. Explicit figure-specific PDF references remain paired with their figures; a placeholder reference never overrides an uploaded article. Page/cell locations are applied only when the original PDF hash matches the recorded version.

## API

Mutation requests require `X-Workbench-Token` from `GET /api/token` and the localhost origin.

| Endpoint | Purpose |
| --- | --- |
| `POST /api/jobs/submit` | Save citation, ID and base64 article; queue research |
| `GET /api/jobs`, `GET /api/jobs/<id>` | Persistent status and captured output |
| `GET /api/jobs/<id>/events?after=<seq>` | Cursor-paginated execution events |
| `POST /api/jobs/<id>/stop` | Cancel while retaining evidence |
| `POST /api/jobs/<id>/launch` | Explicit readiness/research retry |
| `POST /api/jobs/<id>/sources` | Supply data to an inactive run |
| `GET /api/studies/<id>/bundle` | Complete version-1 result |
| `GET /api/studies/<id>/assets/<display-id>` | Verified figure |
| `GET /api/studies/<id>/logs` | Execution records and reports |
| `GET /api/studies/<id>/export?rule=study` | Estimate CSV |

Uploads are limited to 30 MB per PDF/source/figure; referenced evidence is limited to 100 MB per file. Uploading does not execute or unzip a source. JSON-only result imports cannot reference arbitrary server-local figures.

## Maintenance

`package.json` defines `vendor:pdf`, which copies the installed PDF.js renderer, worker, CMaps, fonts, WebAssembly files and license into `static/vendor/pdfjs/`. `npm ci` runs it automatically through `postinstall`; `npm run vendor:pdf` refreshes those files manually. The dependency version is pinned in `package.json` and `package-lock.json`. Normal app startup does not require Node or npm.

Research results are imported automatically after the coordinator finishes: the backend validates the exported JSON and source hashes, saves figures and the article PDF, and publishes the result in SQLite. No separate data-building command is needed. If the export is missing or invalid, the backend attempts one downstream export/repair pass before publishing.

`static/FONT-LICENSES.txt` and licenses under `static/vendor/` must accompany distribution.
