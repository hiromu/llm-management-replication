"""Launch one isolated role as a separate CLI process from a neutral staging directory.
Adopted from setup_drafts/run_role.py on 2026-10-31: Opus 5.5 with fast mode and GPT-6 Astra with Ultrafast,
both High effort, as config/roles_nagaraj2021.json requests. Both families now run inside the same outer
sandbox-exec read barrier; see checks/astra_barrier_test/RESULTS.md.

usage: run_role.py <opus|astra> <label> <staging_dir> <prompt_file> [--tools T] [--timeout SEC]
"""
import argparse, datetime, hashlib, json, os, re, shutil, subprocess, time

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = os.path.expanduser("~")
CLAUDE = shutil.which("claude", path=os.path.join(HOME, ".local/bin")) or shutil.which("claude")
CODEX = shutil.which("codex", path=os.path.join(HOME, ".local/bin")) or shutil.which("codex")
ap = argparse.ArgumentParser()
ap.add_argument("family", choices=["opus", "astra"]); ap.add_argument("label"); ap.add_argument("staging"); ap.add_argument("prompt_file")
ap.add_argument("--tools", default="Read,Write,Edit,Glob,Grep")
ap.add_argument("--allowed", default=None)
ap.add_argument("--timeout", type=int, default=5400)
a = ap.parse_args()
prompt = open(a.prompt_file).read()
staging = os.path.realpath(a.staging)
os.makedirs(os.path.join(STUDY, "logs/roles"), exist_ok=True)

# The coordinator's own scratch directory is named after the study path.
SCRATCH = f"/private/tmp/claude-{os.getuid()}/" + re.sub(r"[^A-Za-z0-9]", "-", STUDY)
# The project root is listed itself so the barrier still holds if the project leaves Dropbox.
PROJECT = os.path.dirname(os.path.dirname(STUDY))
DENY = [PROJECT, os.path.join(HOME, "Library/CloudStorage"), os.path.join(HOME, ".claude/projects"),
        os.path.join(HOME, ".claude-personal/projects"), os.path.join(HOME, ".codex/sessions"),
        os.path.join(HOME, ".codex/archived_sessions"), SCRATCH]
# The user's global Codex instructions load despite --ignore-user-config.
DENY_FILES = [os.path.join(HOME, ".codex/AGENTS.md")]
profile = ("(version 1)(allow default)"
           + "".join(f'(deny file-read* (subpath "{p}"))(deny file-write* (subpath "{p}"))' for p in DENY)
           + "".join(f'(deny file-read* (literal "{p}"))' for p in DENY_FILES))

env = {k: os.environ[k] for k in ("HOME", "USER", "LOGNAME", "PATH", "LANG", "TMPDIR", "SHELL", "TERM") if k in os.environ}
env["PWD"] = staging
if a.family == "opus":
    if os.path.isdir(os.path.join(HOME, ".claude-personal")):
        env["CLAUDE_CONFIG_DIR"] = os.path.join(HOME, ".claude-personal")
    cli_cmd = [CLAUDE, "-p", "--safe-mode", "--model", "claude-opus-5-5", "--effort", "high",
               "--settings", '{"fastMode":true,"autoMemoryEnabled":false}', "--no-session-persistence",
               "--tools", a.tools, "--allowed-tools", a.allowed or a.tools, "--permission-mode", "acceptEdits", "--output-format", "json"]
    version = subprocess.run([CLAUDE, "--version"], capture_output=True, text=True, env=env).stdout.strip()
else:
    cli_cmd = [CODEX, "exec", "--ephemeral", "--ignore-user-config", "--skip-git-repo-check", "-C", staging,
               "-m", "gpt-6-astra", "-c", 'model_reasoning_effort="high"', "-c", 'service_tier="ultrafast"',
               "--sandbox", "danger-full-access", "--json", "-"]
    version = subprocess.run([CODEX, "--version"], capture_output=True, text=True, env=env).stdout.strip()
# Codex's own seatbelt cannot start inside an outer one, and on its own it blocks writes but not reads.
# Astra roles therefore run with Codex's sandbox off inside the outer profile, which is the only file barrier.
# Command network stays open for both families, so no-browsing is instruction-only.
cmd = ["/usr/bin/sandbox-exec", "-p", profile] + cli_cmd
started_utc = datetime.datetime.now(datetime.timezone.utc).isoformat()
start = time.time()
timed_out = False
try:
    proc = subprocess.run(cmd, input=prompt, cwd=staging, env=env, capture_output=True, text=True, timeout=a.timeout)
    rc, out, err = proc.returncode, proc.stdout, proc.stderr
except subprocess.TimeoutExpired as e:
    timed_out, rc = True, -1
    out = (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
    err = (e.stderr or b"").decode() if isinstance(e.stderr, bytes) else (e.stderr or "")
path_audit = sorted(set(re.findall(r"CloudStorage|Dropbox|nagaraj|Nagaraj|a47e9|Information Seeding|\.claude/projects|\.codex/sessions", out))) if a.family == "astra" else None
reported = None
if a.family == "opus":
    try:
        j = json.loads(out)
        reported = {"modelUsage": list(j.get("modelUsage", {}).keys()), "is_error": j.get("is_error"), "num_turns": j.get("num_turns"),
                    "total_cost_usd": j.get("total_cost_usd"),
                    "speed_fields": sorted(set(re.findall(r'"(?:speed|fast_mode|fastMode)"\s*:\s*("?[A-Za-z_]+"?)', out)))}
    except Exception:
        pass
    # Fast mode falls back to standard speed under its rate limit or when usage credits run out.
    fallback = sorted(set(re.findall(r"[Ff]ast mode[^\"\n]{0,80}(?:disabled|unavailable|cooldown|exhausted|fall[s]? back)[^\"\n]{0,40}", out + err)))
    reported = (reported or {}) | {"fast_mode_fallback_messages": fallback}
else:
    reported = {"models_in_events": sorted(set(re.findall(r'"model"\s*:\s*"([^"]+)"', out))),
                "effort_in_events": sorted(set(re.findall(r'"(?:model_reasoning_effort|effort|reasoning_effort)"\s*:\s*"([^"]+)"', out))),
                "service_tier_in_events": sorted(set(re.findall(r'"service_tier"\s*:\s*"([^"]+)"', out)))}
rec = {"label": a.label, "family": a.family, "started_utc": started_utc,
       "cli_version": version, "cmd": cli_cmd, "outer_read_barrier": DENY + DENY_FILES, "env_keys": sorted(env), "staging": staging,
       "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(), "returncode": rc, "timed_out": timed_out,
       "seconds": round(time.time() - start), "reported": reported, "event_log_path_audit_hits": path_audit}
base = os.path.join(STUDY, "logs/roles", a.label)
open(base + ".stdout", "w").write(out)
open(base + ".stderr", "w").write(err)
json.dump(rec, open(base + ".json", "w"), indent=1)
print(a.label, "rc", rc, "sec", rec["seconds"], json.dumps(reported))
