"""One further repair round for implementer A, for the single item its recheck listed.
Same staging, prompt and checker steps as run_implementers.py."""
import glob, hashlib, json, os, shutil, subprocess, tempfile

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY = "~/.venv/bin/python"
RUN = os.path.join(STUDY, "code/run_role.py")
RS = "/opt/homebrew/opt/r/bin/Rscript"
NOTES = f"R 4.6 at {RS}. Installed packages include lme4, lmerTest, car, sandwich, emmeans, afex, psych, boot. Use only installed packages; do not install anything."


def stage():
    return tempfile.mkdtemp(prefix="role_", dir=os.environ["TMPDIR"])


def common(s, syn=True):
    os.makedirs(s + "/input")
    os.makedirs(s + "/output")
    shutil.copy(os.path.join(STUDY, "manifest/implementer_manifest_v1.md"), s + "/input/manifest.md")
    if syn:
        for i in (1, 2, 3, 4):
            shutil.copy(os.path.join(STUDY, f"data/derived/implementer_bundle/dictionary_{i}.csv"), s + "/input")
        shutil.copytree(os.path.join(STUDY, "data/derived/synthetic"), s + "/input/synthetic")


def keep(s, dest):
    os.makedirs(dest, exist_ok=False)
    h = {}
    for f in glob.glob(os.path.join(s, "output", "*")):
        if os.path.isfile(f):
            shutil.copy(f, dest)
            h[os.path.basename(f)] = hashlib.sha256(open(f, "rb").read()).hexdigest()
    json.dump(h, open(dest + "_sha256.json", "w"), indent=1)


s = stage()
common(s)
shutil.copytree(os.path.join(STUDY, "implementation/A/v2"), s + "/input/code")
shutil.copy(os.path.join(STUDY, "checks/A_v2/unmet.md"), s + "/input/unmet.md")
p = open(os.path.join(STUDY, "prompts_frozen/fix_prompt.md")).read().replace("LANGUAGE_NOTES", NOTES).replace("SCRIPTNAME", "analysis.R")
open(s + "/prompt.md", "w").write(p)
r = subprocess.run([PY, RUN, "fable", "impl_A_v3", s, s + "/prompt.md", "--timeout", "3600", "--tools", "Read,Write,Edit,Glob,Grep,Bash",
                    "--allowed", f"Read,Write,Edit,Glob,Grep,Bash({RS}:*)"], capture_output=True, text=True)
print(r.stdout[-300:], r.stderr[-300:], flush=True)
keep(s, os.path.join(STUDY, "implementation/A/v3"))

c = stage()
common(c, syn=False)
shutil.copytree(os.path.join(STUDY, "implementation/A/v3"), c + "/input/code", ignore=shutil.ignore_patterns("unmet.md", "notes.md", "responses.md"))
open(c + "/prompt.md", "w").write(open(os.path.join(STUDY, "prompts_frozen/checker_prompt.md")).read())
r = subprocess.run([PY, RUN, "astra", "checker_A_v3", c, c + "/prompt.md", "--timeout", "1800"], capture_output=True, text=True)
print(r.stdout[-300:], r.stderr[-300:], flush=True)
keep(c, os.path.join(STUDY, "checks/A_v3"))
print("recheck:", open(os.path.join(STUDY, "checks/A_v3/unmet.md")).read()[:800])
