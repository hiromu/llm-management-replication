"""Check public-file integrity without loading data, fitting models, or making network requests."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parent
manifest = json.loads((root / 'export_manifest.json').read_text())
for record in manifest['files']:
    p = root / record['path']
    assert p.is_file(), record['path']
    assert hashlib.sha256(p.read_bytes()).hexdigest() == record['export_sha256'], record['path']
for line in (root / 'protocol_as_run/SHA256SUMS').read_text().splitlines():
    expected, relative = line.split(maxsplit=1)
    assert hashlib.sha256((root / 'protocol_as_run' / relative).read_bytes()).hexdigest() == expected
print(f"Verified {len(manifest['files'])} exported files and the original frozen protocol checksums.")
