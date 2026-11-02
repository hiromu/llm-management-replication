"""Implementers A, B, C with a checker from the other family, one repair round and a recheck. Every version is preserved."""
import glob, hashlib, json, os, shutil, subprocess, tempfile, threading
STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY = "~/.venv/bin/python"; RUN = os.path.join(STUDY, "code/run_role.py")
RS = "/opt/homebrew/opt/r/bin/Rscript"
NOTES = {"R": f"R 4.6 at {RS}. Installed packages include lme4, lmerTest, car, sandwich, emmeans, afex, psych, boot. Use only installed packages; do not install anything.",
         "Python": "Python at ~/.venv/bin/python with pandas, numpy, scipy, statsmodels. Use only installed packages; do not install anything."}
IMPL = {"A": ("fable", "R", "analysis.R", "astra"), "B": ("astra", "R", "analysis.R", "fable"), "C": ("astra", "Python", "analysis.py", "fable")}
def stage(): return tempfile.mkdtemp(prefix="role_", dir=os.environ["TMPDIR"])
def common(s, syn=True):
    os.makedirs(s + "/input"); os.makedirs(s + "/output")
    shutil.copy(os.path.join(STUDY, "manifest/implementer_manifest_v1.md"), s + "/input/manifest.md")
    if syn:
        for i in (1, 2, 3, 4): shutil.copy(os.path.join(STUDY, f"data/derived/implementer_bundle/dictionary_{i}.csv"), s + "/input")
        shutil.copytree(os.path.join(STUDY, "data/derived/synthetic"), s + "/input/synthetic")
def launch(fam, label, s, prompt, lang=None):
    open(s + "/prompt.md", "w").write(prompt)
    cmd = [PY, RUN, fam, label, s, s + "/prompt.md", "--timeout", "7200"]
    if fam == "fable":
        if lang == "R": cmd += ["--tools", "Read,Write,Edit,Glob,Grep,Bash", "--allowed", f"Read,Write,Edit,Glob,Grep,Bash({RS}:*)"]
        elif lang == "none": cmd += ["--tools", "Read,Write,Glob,Grep"]
    r = subprocess.run(cmd, capture_output=True, text=True)
    print(r.stdout.strip()[-300:], r.stderr.strip()[-300:], flush=True)
def keep(s, dest, sub="output"):
    os.makedirs(dest, exist_ok=False)
    h = {}
    for f in glob.glob(os.path.join(s, sub, "*")):
        if os.path.isfile(f):
            shutil.copy(f, dest); h[os.path.basename(f)] = hashlib.sha256(open(f, "rb").read()).hexdigest()
    json.dump(h, open(dest + "_sha256.json", "w"), indent=1)
def check(tag, ver, chk, codedir):
    s = stage(); common(s, syn=False); shutil.copytree(codedir, s + "/input/code", ignore=shutil.ignore_patterns("unmet.md", "notes.md", "responses.md"))
    launch(chk, f"checker_{tag}_{ver}", s, open(os.path.join(STUDY, "prompts_frozen/checker_prompt.md")).read(), "none")
    d = os.path.join(STUDY, f"checks/{tag}_{ver}"); keep(s, d)
    u = os.path.join(d, "unmet.md"); return open(u).read().strip() if os.path.exists(u) else "CHECKER_FAILED"
def work(tag):
    fam, lang, name, chk = IMPL[tag]
    s = stage(); common(s)
    p = open(os.path.join(STUDY, "prompts_frozen/implementer_prompt.md")).read().replace("LANGUAGE_NOTES", NOTES[lang]).replace("LANGUAGE", lang).replace("SCRIPTNAME", name)
    launch(fam, f"impl_{tag}_v1", s, p, lang)
    d1 = os.path.join(STUDY, f"implementation/{tag}/v1"); keep(s, d1)
    if not os.path.exists(os.path.join(d1, name)): print(tag, "NO SCRIPT", flush=True); return
    un = check(tag, "v1", chk, d1)
    print(tag, "checker v1 lines", len(un.splitlines()), flush=True)
    if un.strip() == "NONE": return
    s2 = stage(); common(s2); shutil.copytree(d1, s2 + "/input/code"); open(s2 + "/input/unmet.md", "w").write(un)
    p2 = open(os.path.join(STUDY, "prompts_frozen/fix_prompt.md")).read().replace("LANGUAGE_NOTES", NOTES[lang]).replace("SCRIPTNAME", name)
    launch(fam, f"impl_{tag}_v2", s2, p2, lang)
    d2 = os.path.join(STUDY, f"implementation/{tag}/v2"); keep(s2, d2)
    if os.path.exists(os.path.join(d2, name)):
        un2 = check(tag, "v2", chk, d2); print(tag, "checker v2 lines", len(un2.splitlines()), flush=True)
    else: print(tag, "repair produced no script", flush=True)
ts = [threading.Thread(target=work, args=(t,)) for t in IMPL]
[t.start() for t in ts]; [t.join() for t in ts]
print("ALL DONE", flush=True)
