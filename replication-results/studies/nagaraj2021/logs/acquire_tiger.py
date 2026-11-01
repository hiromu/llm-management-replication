"""Download the Census TIGER/Line 2010 county file used for the article's county maps."""
import datetime
import hashlib
import json
import os
import urllib.request

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
URL = "https://www2.census.gov/geo/tiger/TIGER2010/COUNTY/2010/tl_2010_us_county10.zip"
dest = os.path.join(STUDY, "data/raw/census_tiger2010/tl_2010_us_county10.zip")
os.makedirs(os.path.dirname(dest), exist_ok=True)
with urllib.request.urlopen(URL, timeout=900) as resp:
    content, last_modified = resp.read(), resp.headers.get("Last-Modified")
with open(dest, "wb") as fh:
    fh.write(content)
rec = {"provider": "U.S. Census Bureau", "url": URL,
       "acquired_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
       "size": len(content), "sha256": hashlib.sha256(content).hexdigest(),
       "last_modified": last_modified, "stored_at": os.path.relpath(dest, STUDY)}
with open(os.path.join(STUDY, "logs/tiger_receipt.json"), "w") as fh:
    json.dump(rec, fh, indent=1)
print(rec)
