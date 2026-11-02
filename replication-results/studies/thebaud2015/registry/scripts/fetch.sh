#!/bin/zsh
# Download one URL unmodified with curl into data/raw/<source_id>/<filename> and append a JSON record
# (url, UTC time, HTTP status, bytes, sha256, content type) to registry/acquisition_log.jsonl.
# Usage: fetch.sh <study_dir> <source_id> <filename> <url>
study=$1; sid=$2; fname=$3; url=$4
mkdir -p "$study/data/raw/$sid"
out="$study/data/raw/$sid/$fname"; tmp="$out.part"
t=$(date -u +%Y-%m-%dT%H:%M:%SZ)
meta=$(curl -sS -L -m 600 -A "Mozilla/5.0 (research replication source acquisition)" -o "$tmp" -w '%{http_code}\t%{content_type}\t%{url_effective}' "$url" 2>&1)
code=$(echo "$meta" | tail -1 | cut -f1); ctype=$(echo "$meta" | tail -1 | cut -f2); eff=$(echo "$meta" | tail -1 | cut -f3)
if [[ "$code" == 2* && -s "$tmp" ]]; then
  mv "$tmp" "$out"; bytes=$(stat -f %z "$out"); sha=$(shasum -a 256 "$out" | cut -d' ' -f1); ok=true
else
  [[ -f "$tmp" ]] && mv "$tmp" "$study/registry/validation/failed_response_${sid}_${fname}.txt"
  bytes=0; sha=""; ok=false
fi
rec=$(/usr/bin/python3 -c 'import json,sys; a=sys.argv[1:]; print(json.dumps({"source_id":a[0],"url":a[1],"file":a[2],"utc_time":a[3],"http_status":a[4],"content_type":a[5],"final_url":a[6],"bytes":int(a[7]),"sha256":a[8],"ok":a[9]=="true","tool":"curl"}))' "$sid" "$url" "data/raw/$sid/$fname" "$t" "$code" "$ctype" "$eff" "$bytes" "$sha" "$ok")
echo "$rec" >> "$study/registry/acquisition_log.jsonl"
echo "$rec" | cut -c1-260
