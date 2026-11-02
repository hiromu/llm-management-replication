#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/os-documents.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT
for document in OS_proposal OS_supplement; do
    latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir="$build_dir" "$document.tex"
    cp "$build_dir/$document.pdf" "$document.pdf"
done
