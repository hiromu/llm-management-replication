"""Launch one isolated role as a separate CLI process from a neutral staging directory.
Adopted from setup_drafts/run_role.py with changes: scrubbed environment, read barrier on the
project and past transcripts, recorded CLI version and reported model, timeout.

usage: run_role.py <fable|astra> <label> <staging_dir> <prompt_file> [--tools T] [--sandbox MODE] [--timeout SEC] [--deny-write-study]
"""
import argparse, datetime, json, os, re, subprocess, time

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = os.path.expanduser("~")
CLAUDE = "~/.local/bin/claude"
CODEX = "~/.local/bin/codex"
ap = argparse.ArgumentParser()
ap.add_argument("family"); ap.add_argument("label"); ap.add_argument("staging"); ap.add_argument("prompt_file")
ap.add_argument("--tools", default="Read,Write,Edit,Glob,Grep")
ap.add_argument("--allowed", default=None)
ap.add_argument("--sandbox", default="workspace-write")
ap.add_argument("--timeout", type=int, default=5400)
a = ap.parse_args()
prompt = open(a.prompt_file).read()
staging = os.path.realpath(a.staging)
os.makedirs(os.path.join(STUDY, "logs/roles"), exist_ok=True)

DENY = [os.path.join(HOME, "Library/CloudStorage"), os.path.join(HOME, ".claude/projects"),
        os.path.join(HOME, ".claude-personal/projects"), os.path.join(HOME, ".codex/sessions"),
        os.path.join(HOME, ".codex/archived_sessions"),
        "/private/tmp/claude-501/-project-studies-berry2025"]
profile = "(version 1)(allow default)" + "".join(f'(deny file-read* (subpath "{p}"))(deny file-write* (subpath "{p}"))' for p in DENY)

env = {k: os.environ[k] for k in ("HOME", "USER", "LOGNAME", "PATH", "LANG", "TMPDIR", "SHELL", "TERM") if k in os.environ}
env["PWD"] = staging
if a.family == "fable":
    env["CLAUDE_CONFIG_DIR"] = os.path.join(HOME, ".claude-personal")
    cli_cmd = [CLAUDE, "-p", "--safe-mode", "--model", "claude-fable-5-1", "--effort", "high",
               "--settings", '{"fastMode":false,"autoMemoryEnabled":false}', "--no-session-persistence",
               "--tools", a.tools, "--allowed-tools", a.allowed or a.tools, "--permission-mode", "acceptEdits", "--output-format", "json"]
    version = subprocess.run([CLAUDE, "--version"], capture_output=True, text=True, env=env).stdout.strip()
else:
    cli_cmd = [CODEX, "exec", "--ephemeral", "--ignore-user-config", "--skip-git-repo-check", "-C", staging,
               "-m", "gpt-6-astra", "-c", 'model_reasoning_effort="high"', "-c", 'service_tier="default"',
               "-c", "features.fast_mode=false", "--sandbox", a.sandbox, "--json", "-"]
    version = subprocess.run([CODEX, "--version"], capture_output=True, text=True, env=env).stdout.strip()
# Codex applies its own seatbelt to tool commands, and that fails inside an outer one (tested), so
# Astra roles run under native workspace-write only: writes and tool network are denied, reads are not.
# Their read barrier is the neutral path and scrubbed environment, audited after each run from the event log.
cmd = ["/usr/bin/sandbox-exec", "-p", profile] + cli_cmd if a.family == "fable" else cli_cmd
start = time.time()
timed_out = False
try:
    proc = subprocess.run(cmd, input=prompt, cwd=staging, env=env, capture_output=True, text=True, timeout=a.timeout)
    rc, out, err = proc.returncode, proc.stdout, proc.stderr
except subprocess.TimeoutExpired as e:
    timed_out, rc = True, -1
    out = (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
    err = (e.stderr or b"").decode() if isinstance(e.stderr, bytes) else (e.stderr or "")
path_audit = sorted(set(re.findall(r"CloudStorage|Dropbox|berry|Hildreth|\\.claude/projects|\\.codex/sessions", out))) if a.family == "astra" else None
reported = None
if a.family == "fable":
    try:
        j = json.loads(out)
        reported = {"modelUsage": list(j.get("modelUsage", {}).keys()), "is_error": j.get("is_error"), "num_turns": j.get("num_turns"), "total_cost_usd": j.get("total_cost_usd")}
    except Exception:
        pass
else:
    reported = {"models_in_events": sorted(set(re.findall(r'"model"\s*:\s*"([^"]+)"', out))),
                "effort_in_events": sorted(set(re.findall(r'"(?:model_reasoning_effort|effort|reasoning_effort)"\s*:\s*"([^"]+)"', out))),
                "service_tier_in_events": sorted(set(re.findall(r'"service_tier"\s*:\s*"([^"]+)"', out)))}
rec = {"label": a.label, "family": a.family, "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
       "cli_version": version, "cmd": cli_cmd, "outer_read_barrier": DENY if a.family == "fable" else None, "env_keys": sorted(env), "staging": staging,
       "prompt_sha256": __import__("hashlib").sha256(prompt.encode()).hexdigest(), "returncode": rc, "timed_out": timed_out,
       "seconds": round(time.time() - start), "reported": reported, "event_log_path_audit_hits": path_audit}
base = os.path.join(STUDY, "logs/roles", a.label)
open(base + ".stdout", "w").write(out)
open(base + ".stderr", "w").write(err)
json.dump(rec, open(base + ".json", "w"), indent=1)
print(a.label, "rc", rc, "sec", rec["seconds"], json.dumps(reported))
