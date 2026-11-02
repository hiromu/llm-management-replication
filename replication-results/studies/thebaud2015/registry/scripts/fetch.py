"""Download one URL unmodified into data/raw/<source_id>/<filename>; append an acquisition record
(url, UTC time, HTTP status, bytes, sha256, content-type) to registry/acquisition_log.jsonl.
Usage: fetch.py <study_dir> <source_id> <filename> <url>"""
import sys, os, json, hashlib, datetime, urllib.request, urllib.error
study, sid, fname, url = sys.argv[1:5]
outdir = os.path.join(study, "data", "raw", sid); os.makedirs(outdir, exist_ok=True)
path = os.path.join(outdir, fname)
rec = {"source_id": sid, "url": url, "file": os.path.relpath(path, study),
       "utc_time": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (research replication; source acquisition)",
                                            "Accept": "*/*"})
try:
    with urllib.request.urlopen(req, timeout=300) as r:
        data = r.read(); rec["http_status"] = r.status; rec["content_type"] = r.headers.get("Content-Type")
        rec["final_url"] = r.geturl()
    if fname.endswith(('.xlsx','.xls','.pdf','.zip','.csv','.xml','.json')) or True:
        pass
    with open(path, "wb") as f: f.write(data)
    rec["bytes"] = len(data); rec["sha256"] = hashlib.sha256(data).hexdigest(); rec["ok"] = True
except urllib.error.HTTPError as e:
    rec["ok"] = False; rec["http_status"] = e.code; rec["error"] = str(e)
except Exception as e:
    rec["ok"] = False; rec["error"] = repr(e)
with open(os.path.join(study, "registry", "acquisition_log.jsonl"), "a") as f: f.write(json.dumps(rec) + "\n")
print(json.dumps(rec))
