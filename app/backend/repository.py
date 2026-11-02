"""SQLite persistence; each operation owns a connection, with atomic publication."""
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sqlite3
import threading

_SCHEMA_LOCK = threading.RLock()
SCHEMA = '''
CREATE TABLE IF NOT EXISTS schema_versions(version INTEGER PRIMARY KEY);
INSERT OR IGNORE INTO schema_versions VALUES(1);
CREATE TABLE IF NOT EXISTS runs(id TEXT PRIMARY KEY, created TEXT NOT NULL, status TEXT NOT NULL, document TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS runs_status ON runs(status,created);
CREATE TABLE IF NOT EXISTS events(seq INTEGER PRIMARY KEY AUTOINCREMENT, run_id TEXT NOT NULL REFERENCES runs(id), time TEXT NOT NULL, kind TEXT NOT NULL, text TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS events_run ON events(run_id,seq);
CREATE TABLE IF NOT EXISTS studies(id TEXT PRIMARY KEY, origin TEXT NOT NULL, created TEXT NOT NULL, current_revision INTEGER);
CREATE TABLE IF NOT EXISTS results(id INTEGER PRIMARY KEY AUTOINCREMENT, study_id TEXT NOT NULL REFERENCES studies(id), run_id TEXT REFERENCES runs(id), sha256 TEXT NOT NULL, document TEXT NOT NULL, created TEXT NOT NULL, UNIQUE(study_id,sha256));
CREATE TABLE IF NOT EXISTS displays(result_id INTEGER NOT NULL REFERENCES results(id), position INTEGER NOT NULL, display_id TEXT NOT NULL, kind TEXT NOT NULL, document TEXT NOT NULL, PRIMARY KEY(result_id,position));
CREATE TABLE IF NOT EXISTS estimates(result_id INTEGER NOT NULL REFERENCES results(id), position INTEGER NOT NULL, document TEXT NOT NULL, PRIMARY KEY(result_id,position));
'''


def encode(value):
    return json.dumps(value, ensure_ascii=False, allow_nan=False, sort_keys=True)


class Repository:
    def __init__(self, runtime):
        self.root = Path(runtime)
        self.root.mkdir(parents=True, exist_ok=True)
        self.path = self.root / 'console.sqlite3'
        with _SCHEMA_LOCK, self.connection() as db:
            db.executescript(SCHEMA)

    @contextmanager
    def connection(self):
        db = sqlite3.connect(self.path, timeout=30)
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA foreign_keys=ON')
        db.execute('PRAGMA journal_mode=WAL')
        try:
            with db:
                yield db
        finally:
            db.close()

    def migrate_runs(self):
        with self.connection() as db:
            for path in sorted((self.root / 'runs').glob('*/job.json')):
                j = json.loads(path.read_text())
                db.execute('INSERT OR IGNORE INTO runs VALUES(?,?,?,?)', (j['id'], j['created'], j['status'], encode(j)))

    def save_run(self, j):
        with self.connection() as db:
            db.execute('INSERT INTO runs VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET status=excluded.status,document=excluded.document', (j['id'], j['created'], j['status'], encode(j)))

    def run(self, jid):
        with self.connection() as db:
            row = db.execute('SELECT document FROM runs WHERE id=?', (jid,)).fetchone()
        if not row:
            raise FileNotFoundError('Unknown run')
        return json.loads(row[0])

    def runs(self):
        with self.connection() as db:
            return [json.loads(r[0]) for r in db.execute('SELECT document FROM runs ORDER BY created DESC,id DESC')]

    def event(self, jid, text, kind='log'):
        timestamp = datetime.now(timezone.utc).isoformat(timespec='seconds')
        with self.connection() as db:
            db.execute('INSERT INTO events(run_id,time,kind,text) VALUES(?,?,?,?)', (jid, timestamp, kind, text))

    def events(self, jid, after=0):
        with self.connection() as db:
            return [dict(r) for r in db.execute('SELECT * FROM events WHERE run_id=? AND seq>? ORDER BY seq LIMIT 1000', (jid, after))]

    def ids(self):
        with self.connection() as db:
            return [r[0] for r in db.execute('SELECT id FROM studies ORDER BY created,id')]

    def bundle(self, sid):
        with self.connection() as db:
            row = db.execute('SELECT r.document FROM studies s JOIN results r ON r.id=s.current_revision WHERE s.id=?', (sid,)).fetchone()
        if not row:
            raise FileNotFoundError('Unknown study')
        return json.loads(row[0])

    def publish(self, bundle, run=None):
        """Commit the result, display/estimate rows, and terminal run state together."""
        sid = bundle['study']['id']
        document = encode(bundle)
        sha = hashlib.sha256(document.encode()).hexdigest()
        timestamp = datetime.now(timezone.utc).isoformat(timespec='seconds')
        with self.connection() as db:
            db.execute('BEGIN IMMEDIATE')
            if run:
                current = db.execute('SELECT status FROM runs WHERE id=?', (run['id'],)).fetchone()
                if not current or current[0] not in ('running', 'queued', 'review_required'):
                    raise ValueError('Run is no longer publishable')
            origin = bundle['provenance']['kind']
            existing = db.execute('SELECT origin FROM studies WHERE id=?', (sid,)).fetchone()
            if existing and existing[0] != origin:
                raise ValueError('Cannot replace a study from another origin')
            db.execute('INSERT OR IGNORE INTO studies(id,origin,created) VALUES(?,?,?)', (sid, origin, timestamp))
            db.execute('INSERT OR IGNORE INTO results(study_id,run_id,sha256,document,created) VALUES(?,?,?,?,?)', (sid, run['id'] if run else None, sha, document, timestamp))
            rid = db.execute('SELECT id FROM results WHERE study_id=? AND sha256=?', (sid, sha)).fetchone()[0]
            for pos, d in enumerate(bundle['displays']):
                db.execute('INSERT OR IGNORE INTO displays VALUES(?,?,?,?,?)', (rid, pos, d['id'], d['kind'], encode(d)))
            for pos, t in enumerate(bundle['terms']):
                db.execute('INSERT OR IGNORE INTO estimates VALUES(?,?,?)', (rid, pos, encode(t)))
            db.execute('UPDATE studies SET current_revision=? WHERE id=?', (rid, sid))
            if run:
                db.execute('UPDATE runs SET status=?,document=? WHERE id=?', (run['status'], encode(run), run['id']))
        return rid
