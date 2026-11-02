"""Launch one isolated role as a separate CLI process from a neutral staging directory.

usage: run_role.py <family: fable|astra> <label> <staging_dir> <prompt_file> [tools] [--sandbox-mode MODE]
"""
import json
import os
import subprocess
import sys
import time

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
family, label, staging, prompt_file = sys.argv[1:5]
tools = sys.argv[5] if len(sys.argv) > 5 else "Read,Write,Edit,Glob,Grep"
sandbox = sys.argv[6] if len(sys.argv) > 6 else "workspace-write"
with open(prompt_file) as fh:
    prompt = fh.read()
os.makedirs(os.path.join(STUDY, "logs/roles"), exist_ok=True)
env = dict(os.environ)
if family == "fable":
    env["CLAUDE_CONFIG_DIR"] = os.path.expanduser("~/.claude-personal")
    cmd = ["~/.local/bin/claude", "-p", "--safe-mode",
           "--model", "claude-fable-5-1", "--effort", "high",
           "--settings", '{"fastMode":false,"autoMemoryEnabled":false}',
           "--no-session-persistence", "--tools", tools, "--allowed-tools", tools,
           "--permission-mode", "acceptEdits", "--output-format", "json"]
else:
    cmd = ["~/.local/bin/codex", "exec", "--ephemeral", "--ignore-user-config",
           "--skip-git-repo-check", "-C", staging, "-m", "gpt-6-astra",
           "-c", 'model_reasoning_effort="high"', "-c", 'service_tier="default"',
           "-c", "features.fast_mode=false", "--sandbox", sandbox, "--json", "-"]
start = time.time()
proc = subprocess.run(cmd, input=prompt, cwd=staging, env=env, capture_output=True, text=True)
rec = {"label": label, "family": family, "cmd": cmd[:-1] if family == "astra" else cmd,
       "staging": staging, "returncode": proc.returncode, "seconds": round(time.time() - start)}
base = os.path.join(STUDY, "logs/roles", label)
with open(base + ".stdout", "w") as fh:
    fh.write(proc.stdout)
with open(base + ".stderr", "w") as fh:
    fh.write(proc.stderr)
with open(base + ".json", "w") as fh:
    json.dump(rec, fh, indent=1)
print(label, "rc", proc.returncode, "sec", rec["seconds"])
