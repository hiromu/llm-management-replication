# Result bundle v1

`backend/result_contract.py:validate()` is the authoritative, standard-library validator. Every packaged result, new research export and version-1 JSON import passes through it. Structural validation does not validate the science.

The worker copies the validator, an editable example, both exporter prompts and `context.json` into the new workspace's `console/` folder. The context supplies `result_id`, `study_id`, `run_id` and the uploaded PDF's SHA-256. Research exports must match that identity exactly; they cannot replace a historical paper or another run.

```bash
python3 console/result_contract.py console/result.json
```

| Field | Required meaning |
| --- | --- |
| `schema_version` | Integer `1` |
| `study` | `id`, `citation`, `title`, `short`, `year`, `journal`, `paper_outcomes`; optional code/DOI/other descriptive metadata |
| `study.paper_outcomes` | Explicit `study`, `common`, `lenient` outcomes; uncomputed rules use `not assessed` |
| `execution.status` | `completed`, `blocked` or `review_required`; independent of scientific outcome |
| `terms` | Ordered estimate records; `[]` for unavailable analyses |
| `displays` | Ordered table/figure records for the left-hand pager; `[]` allowed for blocked or incomplete runs |
| `report` | Nonempty factual methods/results/limitations report |
| `blockers` | Array of actual blocking conditions; required and nonempty for blocked status |
| `issues` | Documented barriers keyed by sample/missing/variables/targets/uncertainty/calculation; each needs `text` and a source file |
| `provenance` | `kind` = research/archive/import, plus source paths/hashes and execution metadata |

New research `provenance.sources` is a nonempty array of `{path, sha256}`. Paths are relative to the workspace and must resolve inside it. Symlinks escaping the workspace are rejected. Every term source, display source and issue source must be in this list. Even a blocked result references a real saved report. The application retains content-addressed snapshots, leaving the original path/hash in the exported provenance. Do not register credentials or unrelated files as evidence.

Allowed paper outcomes: `consistent`, `partially reproduced`, `indeterminate`, `candidate`, `not reproduced (unverified)`, `not attemptable`, `fragile`, `fragile inference`, `not assessed`. A blocked execution cannot claim consistent/partial reproduction. Candidate labels never imply independent or human verification. Term outcomes are `consistent`, `indeterminate`, `candidate`, `fragile`, `not assessed`.

## Estimates

Each term contains `term`, `table`, `tier` (focal/lower), `scale`, `source`, `published_values`, `reconstructed_values`, and explicit `outcomes` for each rule. Optional `claim`, `origins`, `source_row`, `distances`, `sample_gap`, raw source values and transformation provenance preserve the scientific record. Arrays hold finite numbers; unknown estimates use `[]`, not zero. Both display arrays must use the same scale. Original scoring distances may differ from descriptive display distances and are retained unchanged.

## Tables

A table has `kind: table`, unique `id`, `title`, `columns` (strings), `rows`, and `source: {path, sha256?}`. Optional `row_label` defaults to Estimate. Every row has `label`, optional `term`, and exactly one `cells` entry per column. Each cell is null or an object:

```json
{
  "estimate": 0.239026648775451,
  "se": null,
  "published": 0.125,
  "published_se": 0.041,
  "source_row": 12
}
```

This is an illustrative cell shape; source_row and uncertainty must be replaced by the real source record. The server recomputes `delta`, `distance_se` and `distance_band` (close ≤1, moderate ≤2, large >2; unavailable if either value or positive published SE is missing). These are descriptive UI annotations and do not change term/paper outcomes. Missing reconstructed SE is never inferred from a published SE. Optional `sample` is a numeric array and `published_sample` a number or null. Additional per-cell sample/model fields can preserve richer designs.

`agreement` is computed from the displayed cells. For long tables the exporter may split them into sequential displays with the same original page mapping. Each archive adapter preserves the precise source estimates and separate origins; no empirical refitting occurs during conversion.

## Figures and PDF locations

A figure has `kind: figure`, unique `id`, `title`, `asset` (workspace-relative PNG/JPEG/WebP/PDF), and `source`. Optional `annotation` has a heading and text describing actual saved checks. Register the asset and underlying plotted data with hashes. The server snapshots bytes and exposes a local URL; remote URLs, HTML and executable SVG are not accepted. Distinguish original-figure reconstructions from newly created diagnostics in the report and display title.

Every display can have `original: {sha256, page, y}`. The SHA must match the submitted original PDF; `page` is a one-based PDF page, never a printed page number. `y` is a normalized vertical fraction in [0,1]. If no verified location exists, omit the mapping rather than guessing. A supplementary table must not be assigned a page in the main article. Current v1 automatic mapping targets the main uploaded PDF; separate supplement mappings are left unavailable.

Optional per-cell `original_region` contains cell/row/column boxes `{x,y,w,h}`, all normalized inside the verified page. Replacing a PDF with a different hash disables these overlays and automatic mapping. The browser still allows manual inspection.

## Lifecycle and revisions

A result is published only after the subprocess ends and all schema, identity, evidence, asset and article checks pass. A failed first export gets at most one downstream repair process; that process may only structure saved evidence. Publication updates the result revision and terminal run state in one SQLite transaction. A stopped run cannot publish. New outputs from a retry add a revision; previous documents and content-addressed evidence stay intact.

Results become viewable even when the scientific outcome is indeterminate or the execution is blocked. Missing or malformed output is not relabelled successful. Completed study logs show all captured lines immediately; active Runs accumulate real output as it arrives.
