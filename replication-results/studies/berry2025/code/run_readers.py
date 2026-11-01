"""Run sealed memorization probes, then both readers, each from a neutral staging directory."""
import hashlib, json, os, shutil, subprocess, tempfile, threading
STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY = "~/.venv/bin/python"
RUN = os.path.join(STUDY, "code/run_role.py")
PACKET = os.path.join(STUDY, "packet/frozen_v1")
def sha(p): return hashlib.sha256(open(p, "rb").read()).hexdigest()
def staging():
    return tempfile.mkdtemp(prefix="role_", dir=os.environ["TMPDIR"])
def probe(fam, tools):
    s = staging(); shutil.copy(os.path.join(STUDY, "prompts_frozen/probe_prompt.txt"), s + "/prompt.txt")
    cmd = [PY, RUN, fam, f"probe_{fam}", s, s + "/prompt.txt", "--timeout", "600"]
    cmd += ["--tools", ""] if fam == "fable" else ["--sandbox", "read-only"]
    r = subprocess.run(cmd, capture_output=True, text=True); print("probe", fam, r.returncode, flush=True)
    os.makedirs(os.path.join(STUDY, "sealed/probes"), exist_ok=True)
    for ext in ("stdout", "stderr", "json"):
        shutil.move(os.path.join(STUDY, f"logs/roles/probe_{fam}.{ext}"), os.path.join(STUDY, f"sealed/probes/probe_{fam}.{ext}"))
def reader(fam, sub):
    s = staging(); shutil.copytree(PACKET, s + "/input"); os.makedirs(s + "/output")
    shutil.copy(os.path.join(STUDY, "prompts_frozen/reader_prompt_v2.md"), s + "/prompt.md")
    r = subprocess.run([PY, RUN, fam, f"reader_{fam}", s, s + "/prompt.md", "--timeout", "10800"], capture_output=True, text=True)
    print(r.stdout.strip()[-400:], r.stderr.strip()[-400:], flush=True)
    d = os.path.join(STUDY, "readers", sub, "initial"); os.makedirs(d, exist_ok=False)
    h = {}
    for f in sorted(os.listdir(s + "/output")):
        shutil.copy(os.path.join(s, "output", f), d); h[f] = sha(os.path.join(d, f))
    json.dump(h, open(os.path.join(STUDY, "readers", sub, "initial_sha256.json"), "w"), indent=1)
    print(fam, "files", list(h), flush=True)
probe("fable", ""); probe("astra", "")
ts = [threading.Thread(target=reader, args=a) for a in (("fable", "fable"), ("astra", "astra"))]
[t.start() for t in ts]; [t.join() for t in ts]
