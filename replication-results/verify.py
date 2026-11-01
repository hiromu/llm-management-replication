#!/usr/bin/env python3
"""Offline verification of packaged evidence and structured results; no model calls."""
import hashlib
import json
from pathlib import Path
import sqlite3


def verify(root):
    root = Path(root).resolve()
    manifest = json.loads((root / 'manifest.json').read_text())
    def source(relative):
        path = (root / relative).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            raise ValueError(f'Missing or unsafe evidence path: {relative}')
        return path
    for relative, expected in manifest['files'].items():
        if hashlib.sha256(source(relative).read_bytes()).hexdigest() != expected:
            raise ValueError(f'Evidence checksum mismatch: {relative}')
    for relative in manifest['source_distribution']['files']:
        if relative not in manifest['files']:
            raise ValueError(f'Unchecksummed upstream file: {relative}')
    archive_studies = manifest['archive_studies']
    if set(archive_studies) != {p.parent.name for p in (root / 'studies').glob('*/STUDY.json')}:
        raise ValueError('Archive study inventory mismatch')
    if set(manifest['studies']) != set(manifest['results']) or not set(manifest['studies']) <= set(archive_studies):
        raise ValueError('Console study inventory mismatch')
    cleanup = json.loads(source('anonymization_manifest.json').read_text())
    for record in cleanup['removed_files']:
        if (root / record['path']).exists():
            raise ValueError(f'Removed conversation file restored: {record["path"]}')
    for record in cleanup['edited_files']:
        if hashlib.sha256(source(record['path']).read_bytes()).hexdigest() != record['sha256_after']:
            raise ValueError(f'Upstream cleanup checksum mismatch: {record["path"]}')
    units = 0
    bundles = {}
    for sid, relative in manifest['results'].items():
        result = json.loads(source(relative).read_text())
        bundles[sid] = result
        if result['schema_version'] != 1 or result['study']['id'] != sid:
            raise ValueError(f'Result identity/schema mismatch: {sid}')
        units += len(result['terms'])
        references = result['provenance']['sources'] + [d['source'] for d in result['displays']]
        for ref in references:
            for name, checksum in [('path', 'sha256'), ('data_path', 'data_sha256')]:
                if ref.get(checksum) and hashlib.sha256(source(ref[name]).read_bytes()).hexdigest() != ref[checksum]:
                    raise ValueError(f'Result source mismatch: {sid}: {ref[name]}')
        for display in result['displays']:
            if display.get('asset'):
                source(display['asset'])
    if units != manifest['assessment_units']:
        raise ValueError('Assessment-unit count mismatch')
    app = root.parent / 'app' / 'data'
    if (app / 'manifest.json').is_file():
        app_manifest = json.loads((app / 'manifest.json').read_text())
        if app_manifest['results'] != manifest['results'] or app_manifest['assessment_units'] != units:
            raise ValueError('App result inventory mismatch')
        for relative, expected in app_manifest['files'].items():
            path = (app / relative).resolve()
            if not path.is_relative_to(app.resolve()) or not path.is_file():
                raise ValueError(f'Missing or unsafe app evidence path: {relative}')
            if hashlib.sha256(path.read_bytes()).hexdigest() != expected or path.read_bytes() != source(relative).read_bytes():
                raise ValueError(f'App evidence mismatch: {relative}')
        db = sqlite3.connect(f'{(app / "console.sqlite3").as_uri()}?mode=ro', uri=True)
        try:
            for sid, bundle in bundles.items():
                row = db.execute('SELECT r.id,r.document,r.sha256 FROM studies s JOIN results r ON r.id=s.current_revision WHERE s.id=?', (sid,)).fetchone()
                if not row or json.loads(row[1]) != bundle or hashlib.sha256(row[1].encode()).hexdigest() != row[2]:
                    raise ValueError(f'App database bundle mismatch: {sid}')
                for table, key in [('displays', 'displays'), ('estimates', 'terms')]:
                    records = [json.loads(r[0]) for r in db.execute(f'SELECT document FROM {table} WHERE result_id=? ORDER BY position', (row[0],))]
                    if records != bundle[key]:
                        raise ValueError(f'App database {table} mismatch: {sid}')
        finally:
            db.close()
        print('Verified app evidence copies and all seven archived database bundles.')
    print(f'Verified {len(archive_studies)} archived studies, {len(bundles)} console results, {units} assessment units and {len(manifest["files"])} distribution files. No empirical rerun performed.')


if __name__ == '__main__':
    verify(Path(__file__).resolve().parent)
