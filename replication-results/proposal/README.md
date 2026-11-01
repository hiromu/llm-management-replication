# Current proposal and technical supplement

- `OS_proposal.tex` / `OS_proposal.pdf`: current anonymous main proposal.
- `OS_supplement.tex` / `OS_supplement.pdf`: current anonymous technical supplement, including Berry and Nagaraj.
- `references.bib` and `informs2014.bst`: bibliography for the main proposal.
- `proposal_references.tex`: references printed in the supplement.
- `supplement_assets/`: current figures, generated comparison tables, and their provenance records.
- `scripts/`: document build and saved-result validation/asset-generation helpers.

The main proposal's workflow figure is embedded in its LaTeX source. The obsolete separate workflow asset and earlier authored main proposal are not included. Ordinary scholarly citations retain their authors' names; they are not presented as this proposal's authors.

## Build

With TeX Live (including latexmk and BibTeX) installed, run:

```sh
bash scripts/build_documents.sh
```

The script compiles both documents in a temporary directory and copies only the PDFs back here. For Overleaf, upload the sources, bibliography files, and `supplement_assets/`, then select `OS_proposal.tex` or `OS_supplement.tex` as the main document.

The source documents were copied from the current manuscript workspace on 2026-11-01. Only anonymous presentation, repository-relative artifact paths, and the distribution note were adjusted here. The manuscript workspace itself was not edited.

## Saved-result checks

The paths in the supplement's artifact map are relative to the parent `Replication_management/` directory. To check the 26 saved common-rule outputs without fitting models:

```sh
~/.venv/bin/python scripts/check_saved_rescoring.py
```

This needs pandas and numpy in that interpreter. Asset-generation helpers use saved study outputs; regeneration is separate from compiling the documents. Numerical results and historical run hashes are preserved. See [../ANONYMIZATION.md](../ANONYMIZATION.md) for the removed conversation files and the distinction between original evidence and this distributed copy.
