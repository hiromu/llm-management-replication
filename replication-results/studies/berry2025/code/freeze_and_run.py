"""Freeze inputs, code, manifest, grid and scoring rules, test network denial, then run the frozen scripts on empirical data."""
import datetime, hashlib, json, os, subprocess, time
STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__))); os.chdir(STUDY)
def sha(p): return hashlib.sha256(open(p, "rb").read()).hexdigest()
RS = "/opt/homebrew/opt/r/bin/Rscript"; PY = "~/.venv/bin/python"; DENY = "(version 1)(allow default)(deny network*)"
SCRIPTS = {"A": (RS, "implementation/A/v3/analysis.R"), "B": (RS, "implementation/B/v1/analysis.R"), "C": (PY, "implementation/C/v2/analysis.py")}
RUN = "runs/empirical_" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
files = ["manifest/implementer_manifest_v1.md", "manifest/frozen_grid_v1.json", "scoring/scoring_rules.json", "scoring/score.py", "scoring/compare_impl.py", "sealed/targets/targets_reconciled.json", "reconciliation/agreement.json", "reconciliation/claims_ledger.csv", "reconciliation/labels_ledger.csv", "reconciliation/transcription_ledger.csv", "packet/publication_packet.json"]
files += [s for _, s in SCRIPTS.values()] + [f"data/derived/implementer_bundle/dataset_{i}.csv" for i in (1, 2, 3, 4)]
probe = subprocess.run(["/usr/bin/sandbox-exec", "-p", DENY, "/usr/bin/curl", "-sS", "-m", "8", "-o", "/dev/null", "https://osf.io"], capture_output=True, text=True)
frz = {"frozen_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "run_dir": RUN, "sha256": {f: sha(f) for f in files}, "network_denial_test": {"returncode": probe.returncode, "stderr": probe.stderr.strip()[:200]},
       "r_version": subprocess.run([RS, "--version"], capture_output=True, text=True).stdout.strip()[:60], "python_version": subprocess.run([PY, "--version"], capture_output=True, text=True).stdout.strip(),
       "unresolved_checker_item": "Implementer A recheck v3 lists one item: path a under complete cases of the whole mediation model versus its own variables. Recheck v1 had asked the reverse. Recorded, not iterated; differences would show only with missing mediator data and would surface in implementer comparison.",
       "versions_run": {k: v[1] for k, v in SCRIPTS.items()}}
assert probe.returncode != 0
json.dump(frz, open("logs/freeze_pre_execution.json", "w"), indent=1)
os.makedirs(RUN)
for tag, (interp, script) in SCRIPTS.items():
    out = f"{RUN}/{tag}"; os.makedirs(out); t = time.time()
    r = subprocess.run(["/usr/bin/sandbox-exec", "-p", DENY, interp, script, "--data", "data/derived/implementer_bundle", "--out", out, "--seed", "20261031", "--boot", "5000"], capture_output=True, text=True)
    open(f"{out}/stdout.log", "w").write(r.stdout); open(f"{out}/stderr.log", "w").write(r.stderr)
    h = {f: sha(f"{out}/{f}") for f in os.listdir(out)}
    json.dump({"rc": r.returncode, "seconds": round(time.time() - t), "sha256": h}, open(f"{RUN}/{tag}_run.json", "w"), indent=1)
    print(tag, "rc", r.returncode, "sec", round(time.time() - t), flush=True)
print(RUN, flush=True)
