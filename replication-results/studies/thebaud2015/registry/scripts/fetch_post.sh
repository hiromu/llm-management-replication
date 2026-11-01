#!/bin/zsh
# Like fetch.sh but issues an HTTP POST with form data (used for the public GEM consortium download button,
# which submits id=<file id> to https://www.gemconsortium.org/download@file). Saves the response unmodified
# under data/raw/<source_id>/ using the server-supplied filename when available.
# Usage: fetch_post.sh <study_dir> <source_id> <fallback_filename> <url> <form_data>
study=$1; sid=$2; fname=$3; url=$4; form=$5
mkdir -p "$study/data/raw/$sid"
tmp="$study/data/raw/$sid/.download.part"; hdr="$study/data/raw/$sid/.headers.part"
t=$(date -u +%Y-%m-%dT%H:%M:%SZ)
meta=$(curl -sS -L -m 900 -A "Mozilla/5.0 (research replication source acquisition)" -X POST --data "$form" -D "$hdr" -o "$tmp" -w '%{http_code}\t%{content_type}\t%{url_effective}' "$url" 2>&1)
code=$(echo "$meta" | tail -1 | cut -f1); ctype=$(echo "$meta" | tail -1 | cut -f2); eff=$(echo "$meta" | tail -1 | cut -f3)
cd_name=$(grep -i '^content-disposition' "$hdr" | sed -E 's/.*filename\*?=("?)([^";]+)\1.*/\2/' | tr -d '\r' | tail -1)
[[ -n "$cd_name" ]] && fname=$(basename "$cd_name")
out="$study/data/raw/$sid/$fname"
if [[ "$code" == 2* && -s "$tmp" ]]; then
  mv "$tmp" "$out"; bytes=$(stat -f %z "$out"); sha=$(shasum -a 256 "$out" | cut -d' ' -f1); ok=true
else
  [[ -f "$tmp" ]] && mv "$tmp" "$study/registry/validation/failed_response_${sid}_${fname}.txt"
  bytes=0; sha=""; ok=false
fi
mv "$hdr" "$study/registry/validation/response_headers_${sid}_${fname}.txt" 2>/dev/null
rec=$(/usr/bin/python3 -c 'import json,sys; a=sys.argv[1:]; print(json.dumps({"source_id":a[0],"url":a[1],"post_form":a[10],"file":a[2],"utc_time":a[3],"http_status":a[4],"content_type":a[5],"final_url":a[6],"bytes":int(a[7]),"sha256":a[8],"ok":a[9]=="true","tool":"curl POST"}))' "$sid" "$url" "data/raw/$sid/$fname" "$t" "$code" "$ctype" "$eff" "$bytes" "$sha" "$ok" "$form")
echo "$rec" >> "$study/registry/acquisition_log.jsonl"
echo "$rec" | cut -c1-300
