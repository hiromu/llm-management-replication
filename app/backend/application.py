#!/usr/bin/env python3
"""Local replication workbench. Standard-library HTTP server; archives are read-only."""
from __future__ import annotations

import argparse
import base64
import csv
from functools import lru_cache
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import threading
import time
import uuid
from . import media_store
from . import execution_logs
from . import repository
from . import result_contract
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlparse

APP = Path(__file__).resolve().parents[1]
PROTOCOL = APP / "protocol"
# Shipped JSON, figures, logs and the writable database are all local to app/.
BUNDLED_RESULTS = APP / "data"
ARCHIVE_ROOT = (Path(os.environ["REPLICATION_ARCHIVE_ROOT"]).expanduser().resolve()
                if os.environ.get("REPLICATION_ARCHIVE_ROOT") else
                BUNDLED_RESULTS if os.environ.get("REPLICATION_SEED_RESULTS", "1") != "0" and (BUNDLED_RESULTS / "manifest.json").is_file() else None)
STUDIES = ARCHIVE_ROOT / "studies" if ARCHIVE_ROOT else None


def require_archive():
    if STUDIES is None or not STUDIES.is_dir():
        raise ValueError("Connect a result archive with REPLICATION_ARCHIVE_ROOT to use this operation.")


@lru_cache(maxsize=1)
def verify_bundled_results():
    if ARCHIVE_ROOT != BUNDLED_RESULTS:
        return
    manifest = json.loads((BUNDLED_RESULTS / "manifest.json").read_text())
    for relative in manifest['app_files']:
        expected = manifest['files'][relative]
        path = (BUNDLED_RESULTS / relative).resolve()
        if not path.is_relative_to(BUNDLED_RESULTS) or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError(f"Bundled result checksum mismatch: {relative}")

RUNTIME = Path(os.environ.get("REPLICATION_RUNTIME", APP / "data")).resolve()
LOCK = threading.RLock()
QUEUE_ACTIVE = False
PROCESSES: dict[str, subprocess.Popen] = {}
def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def read_json(path):
    return json.loads(Path(path).read_text())


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")
    temp.replace(path)


@lru_cache(maxsize=32)
def repository_at(runtime):
    repo = repository.Repository(runtime)
    repo.migrate_runs()
    if ARCHIVE_ROOT is None:
        return repo
    require_archive()
    verify_bundled_results()
    package_manifest = ARCHIVE_ROOT / 'manifest.json'
    if package_manifest.is_file():
        packaged = read_json(package_manifest).get('results')
        if packaged:
            for sid, relative in packaged.items():
                bundle = result_contract.validate(read_json(result_contract.safe_file(ARCHIVE_ROOT, relative)))
                if bundle['study']['id'] != sid:
                    raise ValueError('Result package study identity mismatch')
                if sid not in repo.ids() or repo.bundle(sid) != bundle:
                    repo.publish(bundle)
            return repo
    return repo


def database():
    with LOCK:
        return repository_at(str(RUNTIME.resolve()))


def result_bundle(study):
    return database().bundle(study)


def study_data(study, detail=False):
    result = result_contract.study_view(result_bundle(study), detail)
    if detail:
        for d in result['displays']:
            if d['kind'] == 'figure':
                d['media'] = {'id': d['id'], 'kind': 'pdf' if d['asset'].endswith('.pdf') else 'image',
                              'url': f"/api/studies/{study}/assets/{d['id']}"}
    return result


def load_terms(study):
    return study_data(study, True)['terms']


def study_ids():
    available = database().ids()
    package = read_json(ARCHIVE_ROOT / 'manifest.json') if ARCHIVE_ROOT else {}
    ordered = [sid for sid in package.get('studies', []) if sid in available]
    return ordered + [sid for sid in available if sid not in ordered]


def result_asset(study, display_id):
    b = result_bundle(study)
    d = next((d for d in b['displays'] if d['id'] == display_id and d['kind'] == 'figure'), None)
    if not d:
        raise ValueError('Unknown result asset')
    if b['provenance']['kind'] == 'archive':
        require_archive()
    base = ARCHIVE_ROOT if b['provenance']['kind'] == 'archive' else RUNTIME / 'results' / study
    path = result_contract.safe_file(base, d['asset'])
    mime = {'.png':'image/png', '.jpg':'image/jpeg', '.jpeg':'image/jpeg', '.webp':'image/webp', '.pdf':'application/pdf'}.get(path.suffix.lower())
    if not mime:
        raise ValueError('Unsupported result asset')
    return path, mime


def environment():
    return {"archive_available": STUDIES is not None,
            "claude": shutil.which("claude"), "codex": shutil.which("codex"),
            "Rscript": shutil.which("Rscript"), "pdfs_included": False, "data_included": False,
            "coordinator_model": read_json(PROTOCOL / "config/roles.json")["coordinator"]["model"],
            "note": "CLI presence is not verification of login, model access, or statistical packages. Readiness runs verify these prerequisites; research requires a separate launch."}


def job_dir(jid):
    if not re.fullmatch(r"[0-9a-f]{12}", jid):
        raise ValueError("Invalid run ID")
    return RUNTIME / "runs" / jid


def get_job(jid, logs=False):
    job_dir(jid)  # Validate before database lookup.
    j = database().run(jid)
    if logs:
        p = job_dir(jid) / "console.log"
        if p.exists():
            with p.open("rb") as f:
                f.seek(max(0, p.stat().st_size - 100_000))
                j["log"] = f.read().decode("utf-8", errors="replace")
        else:
            j["log"] = ""
    return j


def update_job(jid, **fields):
    with LOCK:
        j = get_job(jid)
        j.update(fields, updated=now())
        database().save_run(j)
        write_json(job_dir(jid) / "job.json", j)
    return j


def finish_job(jid, **fields):
    with LOCK:
        if get_job(jid)["status"] == "stopped":
            return get_job(jid)
        return update_job(jid, **fields)


def list_jobs():
    with LOCK:
        return database().runs()


def log(jid, text):
    database().event(jid, text)
    with (job_dir(jid) / "console.log").open("a") as f:
        f.write(f"[{now()}] {text}\n")


def new_job(kind, title, **fields):
    jid = uuid.uuid4().hex[:12]
    j = dict(id=jid, kind=kind, title=title, status="prepared", phase="Prepared", created=now(), updated=now(), **fields)
    database().save_run(j)
    write_json(job_dir(jid) / "job.json", j)
    log(jid, f"{title} prepared. Historical study archives are read-only.")
    return j


def process_text(line):
    """Extract real CLI messages, preserving raw JSON separately for audit."""
    try:
        event = json.loads(line)
    except (ValueError, TypeError):
        return line.rstrip(), None
    if not isinstance(event, dict):
        return line.rstrip(), None
    kind = event.get('type')
    if kind == 'assistant':
        chunks = event.get('message', {}).get('content', [])
        return '\n'.join(c.get('text', '') if c.get('type') == 'text' else
                          f"Tool: {c.get('name', 'unknown')}" if c.get('type') == 'tool_use' else '' for c in chunks).strip(), event
    if kind == 'result':
        return str(event.get('result') or event.get('errors') or event.get('subtype', '')), event
    if kind == 'system':
        return f"CLI {event.get('subtype', 'system')}: {event.get('model', '')}".strip(), event
    return '', event


def run_process(jid, command, cwd, phase):
    with LOCK:
        if get_job(jid)['status'] == 'stopped':
            return None
        proc = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, errors='replace', stdin=subprocess.DEVNULL, start_new_session=True)
        PROCESSES[jid] = proc
        update_job(jid, status='running', phase=phase, pid=proc.pid,
                   command=command[:-1] + ['[prompt in launch_prompt.txt]'] if command[0].endswith('claude') else command)
    timed_out = threading.Event()
    def timeout():
        if proc.poll() is None:
            timed_out.set()
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    timer = threading.Timer(float(os.environ.get('REPLICATION_RUN_TIMEOUT_SECONDS', '21600')), timeout)
    timer.daemon = True
    timer.start()
    model_error = False
    progress_previous = None
    try:
        with (job_dir(jid) / 'model-events.jsonl').open('a') as raw:
            for line in proc.stdout:
                raw.write(line)
                raw.flush()
                text, event = process_text(line)
                if text:
                    log(jid, text)
                if event and event.get('type') == 'system' and event.get('model'):
                    update_job(jid, actual_model=event['model'])
                if event and event.get('type') == 'result':
                    model_error |= bool(event.get('is_error'))
                    update_job(jid, cli_result={k: event[k] for k in ('subtype', 'is_error', 'total_cost_usd', 'usage', 'session_id') if k in event})
                progress_path = Path(cwd) / 'console/progress.json'
                if progress_path.exists():
                    try:
                        progress = read_json(progress_path)
                        if progress != progress_previous and progress.get('stage') in ('sources', 'read', 'reconcile', 'implement', 'execute', 'score', 'review', 'export'):
                            progress_previous = progress
                            update_job(jid, phase=progress['stage'].capitalize(), progress=progress)
                            log(jid, str(progress.get('message', progress['stage'])))
                    except (ValueError, OSError):
                        pass  # Ignore a partially written progress file, never a result file.
        rc = proc.wait()
    finally:
        timer.cancel()
        proc.stdout.close()
        with LOCK:
            PROCESSES.pop(jid, None)
    if get_job(jid)['status'] == 'stopped':
        return None
    if timed_out.is_set():
        raise RuntimeError('Run time limit reached; workspace and logs retained. Set REPLICATION_RUN_TIMEOUT_SECONDS to change the limit.')
    return rc or (1 if model_error else 0)


def publish_research_result(jid):
    j = get_job(jid)
    root = job_dir(jid) / 'workspace'
    path = root / 'console/result.json'
    if not path.exists():
        log(jid, 'Coordinator ended without console/result.json. No result was published.')
        return finish_job(jid, status='review_required', phase='Structured result missing', finished=now(), exit_code=0)
    if path.stat().st_size > 30 * 1024 * 1024:
        raise ValueError('Result JSON exceeds 30 MB')
    path = result_contract.safe_file(root, 'console/result.json')
    b = result_contract.validate(read_json(path))
    sid = b['study']['id']
    if sid != j['result_id'] or b['provenance']['kind'] != 'research':
        raise ValueError('Result identity must match console/context.json and provenance.kind must be research')
    sources = b['provenance'].get('sources', [])
    if not isinstance(sources, list) or not sources:
        raise ValueError('Result requires hashed source files, including a report for blocked runs')
    verified = {}
    for source in sources:
        if not isinstance(source, dict):
            raise ValueError('Every provenance source must be a path/hash record')
        file = result_contract.safe_file(root, source.get('path'))
        if file.stat().st_size > 100 * 1024 * 1024:
            raise ValueError('Referenced result evidence exceeds 100 MB; reference a smaller scored output')
        sha = result_contract.digest(file)
        if source.get('sha256') != sha:
            raise ValueError(f'Source hash mismatch: {source.get("path")}')
        verified[source['path']] = file
    for ref in [t['source'] for t in b['terms']] + [d['source']['path'] for d in b['displays']] + [v['source'] for v in b['issues'].values()]:
        if ref not in verified:
            raise ValueError(f'Unregistered result evidence: {ref}')
    destination = RUNTIME / 'results' / sid
    destination.mkdir(parents=True, exist_ok=True)
    for source in sources:
        file = verified[source['path']]
        rel = 'evidence/' + source['sha256'] + file.suffix.lower()
        saved = destination / rel
        saved.parent.mkdir(exist_ok=True)
        shutil.copyfile(file, saved)
        source['snapshot'] = rel
    for d in b['displays']:
        if d.get('original') and d['original']['sha256'] != j['article_sha256']:
            raise ValueError('Original locator must match the uploaded PDF hash')
        if d['source'].get('sha256') and d['source']['sha256'] != result_contract.digest(verified[d['source']['path']]):
            raise ValueError('Display source hash mismatch')
        if d['kind'] == 'figure':
            if d['asset'] not in verified:
                raise ValueError('Figure asset must be registered in provenance.sources')
            file = result_contract.safe_file(root, d['asset'])
            binary = file.read_bytes()
            if len(binary) > 30 * 1024 * 1024:
                raise ValueError('Figure exceeds 30 MB')
            suffix = '.png' if binary.startswith(b'\x89PNG\r\n\x1a\n') else '.jpg' if binary.startswith(b'\xff\xd8\xff') else '.pdf' if binary.startswith(b'%PDF-') else '.webp' if binary.startswith(b'RIFF') and binary[8:12] == b'WEBP' else None
            if not suffix:
                raise ValueError('Figure must be PNG, JPEG, WebP or PDF')
            sha = hashlib.sha256(binary).hexdigest()
            if d['source'].get('sha256') and d['source']['path'] == d['asset'] and d['source']['sha256'] != sha:
                raise ValueError('Figure hash mismatch')
            d['asset'] = sha + suffix
            (destination / d['asset']).write_bytes(binary)
    b['provenance'].update(run_id=jid, article_sha256=j['article_sha256'], requested_model=j['model'], actual_model=get_job(jid).get('actual_model'))
    b = result_contract.validate(b)
    with LOCK:
        if get_job(jid)['status'] == 'stopped':
            return get_job(jid)
        article = (root / 'papers/article.pdf').read_bytes()
        if hashlib.sha256(article).hexdigest() != j['article_sha256']:
            raise ValueError('Uploaded article changed during execution')
        media_store.update(RUNTIME, sid, {'slot': 'article', 'name': 'article.pdf', 'base64': base64.b64encode(article).decode()})
        status = b['execution']['status']
        j = dict(get_job(jid), status=status, phase='Results available' if status == 'completed' else 'Blocked' if status == 'blocked' else 'Results need review',
                 result_study=sid, finished=now(), updated=now(), exit_code=0)
        # Keep a portable JSON entry point beside the copied figures and evidence.
        # SQLite publication happens only after every artifact has been saved.
        write_json(destination / 'result.json', b)
        database().publish(b, j)
        write_json(job_dir(jid) / 'job.json', j)
        write_json(job_dir(jid) / 'result.json', b)
    log(jid, f'Structured result published: {len(b["terms"])} estimates, {len(b["displays"])} displays. Scientific verdict: {b["study"]["paper_outcomes"]["study"]}.')
    return j


def prepare_study(body):
    citation = str(body.get("citation", "")).strip()
    study = str(body.get("study_id", "")).strip()
    if not citation or len(citation) > 1500 or not re.fullmatch(r"[a-z][a-z0-9_]{2,63}", study):
        raise ValueError("Supply a citation and a study ID using 3–64 lowercase letters, digits or underscores.")
    try:
        data = base64.b64decode(body.get("pdf_base64", ""), validate=True)
    except Exception:
        raise ValueError("The article upload is invalid.")
    if not data.startswith(b"%PDF-") or len(data) > 30 * 1024 * 1024:
        raise ValueError("Upload a PDF article, up to 30 MB.")
    j = new_job("research", citation, study_id=study, journal=str(body.get("journal", ""))[:300],
                model=read_json(PROTOCOL / "config/roles.json")["coordinator"]["model"],
                research_authorized=False, model_access_verified=False)
    root = job_dir(j["id"]) / "workspace"
    root.mkdir()
    for folder in ["instructions", "config", "prompts"]:
        shutil.copytree(PROTOCOL / folder, root / folder)
    shutil.copy2(PROTOCOL / "CLAUDE.md", root / "CLAUDE.md")
    protocol_files = [root / "CLAUDE.md"] + [p for d in ("instructions", "config", "prompts") for p in (root/d).rglob("*") if p.is_file()]
    write_json(root / "protocol-manifest.json", {"bundled_source": read_json(PROTOCOL / "manifest.json"),
        "installed_sha256": {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(protocol_files)}})
    # Keep the protocol verbatim; disclose machine-specific adaptations in a separate file.
    (root / "LOCAL_ENVIRONMENT.md").write_text(
        "This is a new study workspace prepared by Replication Workbench.\n"
        "Protocol files are installed from the standalone app; checksums are in protocol-manifest.json.\n"
        "Resolve available Python, R and model CLIs on this machine; record verification limits.\n"
        "No article or empirical data from an archived study have been copied.\n"
        "The local workbench provides process management, not enforced OS-level isolation.\n"
        "Do not claim role isolation or model access until actually verified.\n")
    article = root / "papers/article.pdf"
    article.parent.mkdir()
    article.write_bytes(data)
    (root / "papers/supplements").mkdir()
    write_json(root / "papers/supplements/catalog.json", {"supplements": [], "status": "unverified"})
    sha = hashlib.sha256(data).hexdigest()
    write_json(root / "papers/catalog.json", {"files": [{"study_id": study, "path": "papers/article.pdf", "sha256": sha, "bytes": len(data), "doi": str(body.get("doi", ""))[:300]}]})
    p = root / "studies" / study
    for folder in ["data/supplied", "data/raw", "data/derived", "registry", "readers", "reconciliation", "sealed", "implementation", "runs", "checks", "audits", "scoring", "reports", "logs"]:
        (p / folder).mkdir(parents=True, exist_ok=True)
    study_meta = dict(study_id=study, citation=citation, journal=j["journal"], doi=str(body.get("doi", ""))[:300],
                      paper_path_from_project_root="papers/article.pdf", paper_sha256=sha, status="prepared",
                      supplement_catalog_from_project_root="papers/supplements/catalog.json",
                      author_package_availability="unverified", external_supplement_availability="unverified",
                      reader_runs=0, model_fits=0, research_authorized=False, session_scope=f"{study} only")
    write_json(p / "STUDY.json", study_meta)
    (p / "CLAUDE.md").write_text(f"Active study: {study}. Read ../../CLAUDE.md and STUDY.json. Work on this paper only.\n")
    settings = {"model": j["model"], "effortLevel": "high", "fastMode": False, "autoMemoryEnabled": False,
                "claudeMdExcludes": [str(Path.home() / ".claude/CLAUDE.md")]}
    for path in [root / ".claude/settings.json", p / ".claude/settings.json"]:
        write_json(path, settings)
    install_console_contract(dict(j, workspace=str(root), article_sha256=sha))
    (job_dir(j["id"]) / "workspace_path.txt").write_text(str(root))
    log(j["id"], f"Fresh workspace created for {study}; article SHA-256 {sha}. Research has not started.")
    return update_job(j["id"], workspace=str(root), article_sha256=sha, phase="Ready for prerequisite check")


def install_console_contract(j):
    root = Path(j['workspace'])
    console = root / 'console'
    console.mkdir(exist_ok=True)
    for source, target in [('backend/result_contract.py', 'result_contract.py'), ('protocol/result.example.json', 'result.example.json')]:
        shutil.copy2(APP / source, console / target)
    for prompt, target in [('console-output.md', 'output-instructions.md'), ('console-export.md', 'export-instructions.md')]:
        pinned = root / 'prompts' / prompt
        if pinned.is_file():
            shutil.copy2(pinned, console / target)
        elif not (console / target).is_file():
            # Legacy workspaces may predate protocol-level export prompts. Retain
            # their existing export instructions when retrying those runs.
            shutil.copy2(PROTOCOL / 'prompts' / prompt, console / target)
    result_id = j.get('result_id') or j['study_id'][:50] + '_' + j['id']
    write_json(console / 'context.json', {'study_id': j['study_id'], 'result_id': result_id, 'article_sha256': j['article_sha256'], 'run_id': j['id']})
    update_job(j['id'], result_id=result_id)


def research_worker(jid, mode):
    try:
        j = get_job(jid)
        root = job_dir(jid) / "workspace"
        study = j["study_id"]
        cli = shutil.which("claude")
        if not cli:
            raise ValueError("Claude CLI is not installed. The frozen protocol requires its pinned coordinator model.")
        prompt = f"Read CLAUDE.md, LOCAL_ENVIRONMENT.md, instructions/new_study.md and studies/{study}/STUDY.json. Active study: {study}. "
        if mode == "readiness":
            prompt += ("Perform a readiness inspection only. Do not start research, download data, invoke reader/implementer agents, "
                       "or fit empirical models. Verify the CLI/model settings and installed software where feasible. "
                       "Do not claim a setting was verified without evidence. Report missing inputs, unsupported settings and required local path adaptations. "
                       f"Write findings to studies/{study}/logs/readiness.md. Research is not authorized.")
        else:
            prompt += ("The user authorized research for this paper through the local workbench. Follow the complete shared protocol, "
                       "including eligibility checks, fresh role contexts, role input barriers, freezing, code checks, scoring and review. "
                       "Do not silently substitute any model. If an input, capability or setting is unavailable, report the blocker and stop. "
                       "Do not inspect any other workspace or historical study. "
                       "a successful CLI exit is not a verified replication outcome. Keep all artifacts inside this workspace.")
        if mode == 'research':
            prompt += " Read console/output-instructions.md and console/context.json. Execute the complete workflow and export console/result.json, including a truthful blocked bundle if execution cannot proceed. Do not finish with a plan alone."
        (job_dir(jid) / "launch_prompt.txt").write_text(prompt)
        cmd = [cli, "-p", "--safe-mode", "--model", j["model"], "--effort", "high", "--settings", str(root / ".claude/settings.json"),
               "--no-session-persistence", "--output-format", "stream-json", "--verbose", "--permission-mode", "acceptEdits", "--allowedTools", "Read,Write,Edit,Glob,Grep,Bash,WebFetch,WebSearch", "--", prompt]
        log(jid, f"Launching {mode} with requested model {j['model']}. Actual model access is not yet verified.")
        rc = run_process(jid, cmd, root, phase="Checking prerequisites" if mode == "readiness" else "Coordinator working")
        if rc is None:
            return
        if rc:
            raise RuntimeError(f"Coordinator exited with code {rc}. See the CLI log.")
        if mode == 'research':
            try:
                if not (root / 'console/result.json').exists():
                    raise ValueError('console/result.json was not produced')
                publish_research_result(jid)
            except (ValueError, KeyError, TypeError, FileNotFoundError) as error:
                log(jid, f'Result export needs repair: {error}')
                repair_prompt = ('Read console/export-instructions.md. Perform only the downstream export/repair, not new research. '
                                 'The validator reported this diagnostic: ' + json.dumps(str(error)))
                (job_dir(jid) / 'export_prompt.txt').write_text(repair_prompt)
                repaired = run_process(jid, cmd[:-1] + [repair_prompt], root, phase='Structuring results')
                if repaired is None:
                    return
                if repaired:
                    raise RuntimeError('Result exporter failed; inspect saved logs and workspace')
                publish_research_result(jid)
            return
        log(jid, "Coordinator process ended. Read its findings; this exit code does not establish readiness or a scientific verdict.")
        finish_job(jid, status="review_required", phase="Readiness findings need review" if mode == "readiness" else "Inspect coordinator outputs", exit_code=rc, finished=now())
    except Exception as e:
        if get_job(jid)["status"] != "stopped":
            log(jid, str(e))
            finish_job(jid, status="failed", phase="Run failed", error=str(e), finished=now())


def start_research(jid, mode):
    global QUEUE_ACTIVE
    if mode not in ["readiness", "research"]:
        raise ValueError("Unknown launch mode")
    with LOCK:
        j = get_job(jid)
        if j["kind"] != "research" or j["status"] in ["running", "queued"]:
            raise ValueError("This run cannot be launched in its current state.")
        if not shutil.which("claude"):
            raise ValueError("Claude CLI was not found; the pinned coordinator cannot be launched.")
        install_console_contract(j)
        if mode == "research":
            root = job_dir(jid) / "workspace/studies" / j["study_id"] / "STUDY.json"
            m = read_json(root)
            m["research_authorized"] = True
            write_json(root, m)
        update_job(jid, status="queued", phase="Queued", research_authorized=mode == "research", mode=mode, finished=None, error=None, exit_code=None, progress=None, cli_result=None)
        (job_dir(jid) / 'workspace/console/progress.json').unlink(missing_ok=True)
        result_file = job_dir(jid) / 'workspace/console/result.json'
        if result_file.exists():
            result_file.rename(result_file.with_name(f'result.previous-{uuid.uuid4().hex[:8]}.json'))
        if not QUEUE_ACTIVE:
            QUEUE_ACTIVE = True
            threading.Thread(target=research_queue, name='replication-queue', daemon=True).start()
    return get_job(jid)


def research_queue():
    global QUEUE_ACTIVE
    while True:
        with LOCK:
            pending = [j for j in reversed(list_jobs()) if j['kind'] == 'research' and j['status'] == 'queued']
            if not pending:
                QUEUE_ACTIVE = False
                return
            j = pending[0]
            update_job(j['id'], status='running', phase='Starting coordinator')
        research_worker(j['id'], j.get('mode', 'research'))


def stop_job(jid):
    with LOCK:
        j = get_job(jid)
        if j["status"] not in ["prepared", "queued", "running"]:
            raise ValueError("This run is not active.")
        update_job(jid, status="stopped", phase="Stopped by user", finished=now())
        if proc := PROCESSES.get(jid):
            try:
                os.killpg(proc.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            def enforce_stop():
                try:
                    proc.wait(timeout=4)
                except subprocess.TimeoutExpired:
                    try:
                        os.killpg(proc.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
            threading.Thread(target=enforce_stop, daemon=True).start()
    log(jid, "Stop requested. Process group terminated; artifacts retained.")
    return get_job(jid)


class Handler(BaseHTTPRequestHandler):
    server_version = "ReplicationWorkbench/1.0"

    def send(self, status, body, content="application/json; charset=utf-8", headers=None):
        if not isinstance(body, bytes):
            body = (json.dumps(body, ensure_ascii=False, allow_nan=False) if content.startswith("application/json") else str(body)).encode()
        self.send_response(status)
        self.send_header("Content-Type", content)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'self'; worker-src 'self' blob:; style-src 'self' 'unsafe-inline'; font-src 'self' data: blob:; img-src 'self' data: blob:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'")
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        try:
            self.get()
        except (ValueError, FileNotFoundError) as e:
            self.send(404, {"error": str(e)})
        except Exception as e:
            self.send(500, {"error": str(e)})

    def get(self):
        url = urlparse(self.path)
        path = unquote(url.path)
        if path == "/api/studies":
            return self.send(200, {"studies": [study_data(s) for s in study_ids()], "source": "SQLite results", "read_only": False})
        if path.startswith("/api/studies/"):
            parts = path.strip("/").split("/")
            study = parts[2]
            if study not in study_ids():
                raise ValueError("Unknown study")
            if len(parts) == 4 and parts[3] == 'bundle':
                return self.send(200, result_bundle(study))
            if len(parts) == 5 and parts[3] == 'assets':
                file, mime = result_asset(study, parts[4])
                return self.send(200, file.read_bytes(), mime)
            if len(parts) == 4 and parts[3] == "logs":
                entries = []
                if ARCHIVE_ROOT is not None and result_bundle(study)["provenance"]["kind"] == "archive":
                    manifest = read_json(ARCHIVE_ROOT / "manifest.json")
                    for relative in manifest.get("logs", {}).get(study, []):
                        file = result_contract.safe_file(ARCHIVE_ROOT, relative)
                        entries.append({"path": str(file.relative_to(STUDIES)), "text": file.read_text(errors="replace")[:24000]})
                jobs = [get_job(j["id"], True) for j in list_jobs() if (j.get("result_study") == study or j.get("study_id") == study)]
                timeline = list(execution_logs.archive_events(STUDIES, study)) if STUDIES is not None and result_bundle(study)["provenance"]["kind"] == "archive" else []
                for job in jobs:
                    timeline.extend(execution_logs.parse_lines(job.get("log", ""), f"runs/{job['id']}/console.log"))
                timeline.sort(key=lambda event: (event["time"], event["source"], event["line"]))
                return self.send(200, {"entries": entries, "jobs": jobs, "timeline": timeline})
            if len(parts) >= 4 and parts[3] == "media":
                if len(parts) == 4:
                    return self.send(200, media_store.state(RUNTIME, study))
                file, mime = media_store.resolve(RUNTIME, study, parts[4], parts[5] if len(parts) > 5 else "")
                return self.send(200, file.read_bytes(), mime)
            if len(parts) == 4 and parts[3] == "export":
                rule = parse_qs(url.query).get("rule", ["common"])[0]
                if rule not in ["study", "common", "lenient"]:
                    raise ValueError("Unknown rule")
                rows = load_terms(study)
                out = io.StringIO()
                w = csv.writer(out)
                w.writerow(["term", "table", "tier", "claim", "published", "reconstructed_original_scale", "display_scale", "reconstructed_display", "distance_se", "sample_gap", "rule", "outcome", "source_label", "source", "source_row", "comparison_source", "comparison_source_rows"])
                for r in rows:
                    w.writerow([r["term"], r["table"], r["tier"], r["claim"], r["published"], r["reconstructed"], r["scale"], " / ".join(map(str, r["reconstructed_values"])), r["distance_se"], r["n_gap"], rule, r["outcomes"][rule], r["v1_outcome"], r["source"], r["source_row"], r.get("comparison_source", r["source"]), " / ".join(map(str, r.get("comparison_source_rows", [r["source_row"]])))])
                return self.send(200, out.getvalue().encode("utf-8-sig"), "text/csv; charset=utf-8", {"Content-Disposition": f'attachment; filename="{study}_{rule}.csv"'})
            return self.send(200, study_data(study, True))
        if path == "/api/environment":
            return self.send(200, environment())
        if path == "/api/jobs":
            return self.send(200, list_jobs())
        if path.startswith("/api/jobs/"):
            parts = path.strip("/").split("/")
            if len(parts) == 4 and parts[3] == 'events':
                after = int(parse_qs(url.query).get('after', ['0'])[0])
                return self.send(200, database().events(parts[2], after))
            if len(parts) == 4 and parts[3] == "article":
                j = get_job(parts[2])
                if j["kind"] != "research":
                    raise ValueError("This run has no article")
                return self.send(200, (job_dir(j["id"]) / "workspace/papers/article.pdf").read_bytes(), "application/pdf")
            if len(parts) == 4 and parts[3] == "result":
                j = get_job(parts[2])
                return self.send(200, result_bundle(j['result_study']) if j.get('result_study') else read_json(job_dir(j["id"]) / "result.json"), headers={"Content-Disposition": f'attachment; filename="run_{j["id"]}.json"'})
            return self.send(200, get_job(parts[2], True))
        if path == "/api/protocol":
            return self.send(200, {"rules": read_json(PROTOCOL / "comparison/scoring_rules_common_v1.json"), "workflow": (PROTOCOL / "instructions/workflow.md").read_text(), "roles": read_json(PROTOCOL / "config/roles.json")})
        if path == "/api/token":
            return self.send(200, {"token": self.server.token})
        if path.startswith("/vendor/pdfjs/"):
            base = (APP / "static/vendor/pdfjs").resolve()
            file = (base / path.removeprefix("/vendor/pdfjs/")).resolve()
            if not file.is_relative_to(base) or not file.is_file() or file.suffix not in [".mjs", ".bcmap", ".pfb", ".ttf", ".wasm"]:
                raise ValueError("Unknown PDF resource")
            mime = "text/javascript" if file.suffix == ".mjs" else "application/wasm" if file.suffix == ".wasm" else "application/octet-stream"
            return self.send(200, file.read_bytes(), mime)
        if path == "/paper-placeholder.pdf":
            return self.send(200, media_store.PLACEHOLDER.read_bytes(), "application/pdf")
        name = "index.html" if path == "/" else path.lstrip("/")
        if name not in ["index.html", "app.js", "across.js", "style.css", "ui.css", "fonts.css", "components.js", "media.js", "icon.svg"]:
            raise ValueError("Not found")
        mime = "text/html" if name.endswith(".html") else "text/javascript" if name.endswith(".js") else "text/css" if name.endswith(".css") else "image/svg+xml"
        return self.send(200, (APP / "static" / name).read_bytes(), mime + "; charset=utf-8")

    def do_POST(self):
        try:
            # A local process launcher must not accept requests from unrelated browser origins.
            if self.headers.get("Host") not in [f"127.0.0.1:{self.server.server_port}", f"localhost:{self.server.server_port}"]:
                return self.send(403, {"error": "Localhost requests only"})
            origin = self.headers.get("Origin")
            if origin and origin not in [f"http://127.0.0.1:{self.server.server_port}", f"http://localhost:{self.server.server_port}"]:
                return self.send(403, {"error": "Cross-origin launch rejected"})
            if self.headers.get("X-Workbench-Token") != self.server.token:
                return self.send(403, {"error": "Reload the workbench before launching."})
            size = int(self.headers.get("Content-Length", 0))
            if size < 0 or size > 42 * 1024 * 1024:
                return self.send(413, {"error": "Upload exceeds 30 MB PDF limit"})
            body = json.loads(self.rfile.read(size) or b"{}")
            path = urlparse(self.path).path
            media_match = re.fullmatch(r"/api/studies/([a-z][a-z0-9_]{2,63})/media", path)
            if media_match:
                study = media_match[1]
                if study not in study_ids():
                    raise ValueError("Unknown study")
                with LOCK:
                    result = media_store.update(RUNTIME, study, body)
                return self.send(200, result)
            if path == "/api/results/import":
                data = result_contract.validate(body)
                with LOCK:
                    if data['study']['id'] in study_ids():
                        raise ValueError('Study ID already exists; import a new version ID')
                    if any(d['kind'] == 'figure' for d in data['displays']):
                        raise ValueError('JSON-only imports cannot carry figure files; use the run workspace exporter')
                    data['provenance']['kind'] = 'import'
                    data['study']['imported'] = True
                    database().publish(data)
                return self.send(201, study_data(data['study']['id'], True))
            if path == "/api/jobs/submit":
                j = prepare_study(body)
                try:
                    j = start_research(j["id"], "research")
                except ValueError as err:
                    log(j["id"], str(err))
                    j = update_job(j["id"], status="failed", phase="Could not start", error=str(err))
                return self.send(201, j)
            if path == "/api/jobs/prepare":
                return self.send(201, prepare_study(body))
            sources_match = re.fullmatch(r'/api/jobs/([a-f0-9]{12})/sources', path)
            if sources_match:
                with LOCK:
                    jid = sources_match[1]
                    j = get_job(jid)
                    if j['kind'] != 'research' or j['status'] in ('queued', 'running'):
                        raise ValueError('Stop this research run before adding sources')
                    name = str(body.get('name', ''))
                    if not name or Path(name).name != name or name.startswith('.') or len(name) > 150 or name in ('supplied_sources.json', 'CLAUDE.md', 'AGENTS.md'):
                        raise ValueError('Invalid source filename')
                    binary = base64.b64decode(body.get('base64', ''), validate=True)
                    if not binary or len(binary) > 30 * 1024 * 1024:
                        raise ValueError('Source files must be 1 byte to 30 MB')
                    folder = job_dir(jid) / 'workspace/studies' / j['study_id'] / 'data/supplied'
                    file = folder / name
                    if file.exists():
                        raise ValueError('Source already exists; use a new filename to preserve evidence')
                    file.write_bytes(binary)
                    catalog = folder / 'supplied_sources.json'
                    data = read_json(catalog) if catalog.exists() else {'sources': []}
                    data['sources'].append({'path': name, 'sha256': hashlib.sha256(binary).hexdigest(), 'bytes': len(binary), 'supplied_at': now(), 'validation': 'pending'})
                    write_json(catalog, data)
                    log(jid, f'User supplied source: {name}; validate its provenance and coverage before use.')
                return self.send(201, {'name': name})
            match = re.fullmatch(r"/api/jobs/([a-f0-9]{12})/(launch|stop)", path)
            if match:
                jid, action = match.groups()
                if action == "stop":
                    return self.send(200, stop_job(jid))
                return self.send(200, start_research(jid, body.get("mode", "readiness")))
            self.send(404, {"error": "Unknown action"})
        except (ValueError, FileNotFoundError) as e:
            self.send(400, {"error": str(e)})
        except Exception as e:
            self.send(500, {"error": str(e)})

    def log_message(self, fmt, *args):
        if args and str(args[0]).startswith("GET /api/jobs"):
            return
        super().log_message(fmt, *args)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    if ARCHIVE_ROOT is not None:
        try:
            require_archive()
        except ValueError as error:
            parser.error(str(error))
    RUNTIME.mkdir(parents=True, exist_ok=True)
    # One dispatcher per database; prevents a second server interrupting live jobs.
    import fcntl
    runtime_lock = (RUNTIME / 'server.lock').open('a')
    try:
        fcntl.flock(runtime_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        parser.error('Another server already owns this REPLICATION_RUNTIME')
    database()
    for j in list_jobs():
        if j["status"] in ["queued", "running"]:
            update_job(j["id"], status="interrupted", phase="Server restarted; inspect saved log")
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.token = uuid.uuid4().hex
    def terminate(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, terminate)
    print(f"Replication Workbench: http://127.0.0.1:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        for j in list_jobs():
            if j['status'] in ('queued', 'running'):
                stop_job(j['id'])
        server.server_close()


if __name__ == "__main__":
    main()
