"""Download OSF node a47e9 into data/raw and hold the author code, LaTeX results file and Readme in sealed/."""
import datetime
import hashlib
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NODE = "a47e9"
RAW = os.path.join(STUDY, f"data/raw/osf_{NODE}")
SEALED = os.path.join(STUDY, "sealed/author_package")
API = "https://api.osf.io/v2"
out = []


def get(url, timeout=60):
    # OSF answers anonymous bursts with 403 or 429; back off and retry.
    for wait in (10, 30, 60, 120, 240, None):
        try:
            with urllib.request.urlopen(url, timeout=timeout) as resp:
                return resp.status, resp.read()
        except urllib.error.HTTPError as e:
            if e.code not in (403, 429, 502, 503) or wait is None:
                raise
            print("retry", e.code, url, "after", wait, "s", flush=True)
            time.sleep(wait)


def get_json(url, **params):
    if params:
        url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
    return json.loads(get(url)[1])


def sealed(path):
    return (path.startswith("/scripts/") or path == "/writing/figures_and_tables.tex"
            or path == "/Readme.txt")


def walk(url):
    while url:
        page = get_json(url, **{"page[size]": 100})
        for item in page["data"]:
            attrs = item["attributes"]
            if attrs["kind"] == "folder":
                walk(item["relationships"]["files"]["links"]["related"]["href"])
                continue
            path = attrs["materialized_path"]
            dest = os.path.join(SEALED if sealed(path) else RAW, path.lstrip("/"))
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            osf_sha = (attrs.get("extra") or {}).get("hashes", {}).get("sha256")
            # On a rerun, keep a file already on disk whose hash matches the OSF hash.
            if osf_sha and os.path.exists(dest) and hashlib.sha256(open(dest, "rb").read()).hexdigest() == osf_sha:
                status, content = 200, open(dest, "rb").read()
            else:
                status, content = get(item["links"]["download"], timeout=600)
                time.sleep(1)
            rec = {"path": path, "status": status, "guid": item["id"],
                   "url": item["links"]["download"], "osf_size": attrs["size"],
                   "osf_modified": attrs["date_modified"], "osf_sha256": osf_sha,
                   "sealed": sealed(path)}
            if status == 200:
                with open(dest, "wb") as fh:
                    fh.write(content)
                sha = hashlib.sha256(content).hexdigest()
                rec.update(size=len(content), sha256=sha,
                           matches_osf_sha256=(sha == osf_sha) if osf_sha else None,
                           stored_at=os.path.relpath(dest, STUDY))
            out.append(rec)
            time.sleep(0.5)
        url = page["links"].get("next")


node = get_json(f"{API}/nodes/{NODE}/")["data"]
lic_link = (node["relationships"].get("license") or {}).get("links", {}).get("related", {}).get("href")
license_name = get_json(lic_link)["data"]["attributes"]["name"] if lic_link else None
walk(f"{API}/nodes/{NODE}/files/osfstorage/")
with open(os.path.join(STUDY, "logs/osf_receipt.json"), "w") as fh:
    json.dump({"provider": "OSF", "node": NODE, "title": node["attributes"]["title"],
               "acquired_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
               "license": license_name or "none shown by the OSF API; link, do not rehost",
               "files": out}, fh, indent=1)
bad = [r["path"] for r in out if r["status"] != 200 or r.get("matches_osf_sha256") is False]
print("license", license_name, "files", len(out), "sealed", sum(r["sealed"] for r in out),
      "failed_or_mismatch", bad, "bytes", sum(r.get("size", 0) for r in out))
