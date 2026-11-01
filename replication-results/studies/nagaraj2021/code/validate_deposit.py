"""Validate every deposited file against logs/osf_receipt.json and the TIGER file against logs/tiger_receipt.json.
Hashing also materializes online-only Dropbox placeholders. Sealed files are hashed, never opened as text,
and their names are written only to the log, not printed.

usage: validate_deposit.py <log_name>   (e.g. deposit_validation_pre.json)
"""
import datetime, hashlib, json, os, sys

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
receipt = json.load(open(os.path.join(STUDY, "logs/osf_receipt.json")))
tiger = json.load(open(os.path.join(STUDY, "logs/tiger_receipt.json")))


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def resolve(stored_at):
    return stored_at if os.path.isabs(stored_at) else os.path.join(STUDY, stored_at)


rows = []
for f in receipt["files"]:
    p = resolve(f["stored_at"])
    ok = os.path.exists(p)
    got = sha(p) if ok else None
    rows.append({"path": f["path"], "stored_at": f["stored_at"], "sealed": f["sealed"], "exists": ok,
                 "sha256": got, "matches_receipt": got == f["sha256"], "matches_osf": got == f.get("osf_sha256")})
p = resolve(tiger["stored_at"])
tg = sha(p) if os.path.exists(p) else None
rows.append({"path": "census_tiger2010", "stored_at": tiger["stored_at"], "sealed": False, "exists": tg is not None,
             "sha256": tg, "matches_receipt": tg == tiger["sha256"], "matches_osf": None})

out = {"checked_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "files": rows,
       "summary": {"total": len(rows), "missing": sum(not r["exists"] for r in rows),
                   "mismatch_receipt": sum(r["exists"] and not r["matches_receipt"] for r in rows),
                   "sealed": sum(r["sealed"] for r in rows),
                   "sealed_mismatch": sum(r["sealed"] and not r["matches_receipt"] for r in rows)}}
json.dump(out, open(os.path.join(STUDY, "logs", sys.argv[1]), "w"), indent=1)
print(json.dumps(out["summary"]))
for r in rows:
    if not r["sealed"]:
        print(("OK  " if r["matches_receipt"] else "BAD ") + r["stored_at"])
