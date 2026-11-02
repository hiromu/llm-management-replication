"""Download OSF node 3h6vc into data/raw and hold the author script in sealed/."""
import datetime
import hashlib
import json
import os
import shutil
import time

import requests

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(STUDY, "data/raw/osf_3h6vc")
SEALED = os.path.join(STUDY, "sealed/author_package")
AUTHOR_CODE = "/ltran_analysis_script.Rmd"
out = []


def walk(url):
    while url:
        page = requests.get(url, params={"page[size]": 100}, timeout=30).json()
        for item in page["data"]:
            attrs = item["attributes"]
            if attrs["kind"] == "folder":
                walk(item["relationships"]["files"]["links"]["related"]["href"])
                continue
            path = attrs["materialized_path"]
            dest = (os.path.join(SEALED, path.lstrip("/")) if path == AUTHOR_CODE
                    else RAW + path)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            resp = requests.get(item["links"]["download"], timeout=120)
            rec = {"path": path, "status": resp.status_code, "guid": item["id"],
                   "url": item["links"]["download"], "osf_size": attrs["size"],
                   "osf_modified": attrs["date_modified"]}
            if resp.status_code == 200:
                with open(dest, "wb") as fh:
                    fh.write(resp.content)
                rec.update(size=len(resp.content),
                           sha256=hashlib.sha256(resp.content).hexdigest(),
                           stored_at=os.path.relpath(dest, STUDY))
            out.append(rec)
            time.sleep(0.3)
        url = page["links"].get("next")


walk("https://api.osf.io/v2/nodes/3h6vc/files/osfstorage/")
with open(os.path.join(STUDY, "logs/osf_receipt.json"), "w") as fh:
    json.dump({"provider": "OSF", "node": "3h6vc",
               "acquired_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
               "license": "none shown by the OSF API; link, do not rehost",
               "files": out}, fh, indent=1)
bad = [r for r in out if r["status"] != 200]
print("files", len(out), "failed", bad, "bytes", sum(r.get("size", 0) for r in out))
print(sorted(r["stored_at"] for r in out if "stored_at" in r))
