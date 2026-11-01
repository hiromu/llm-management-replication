"""SHA-256 of every derived file and construction audit file."""
import hashlib, json, os, datetime
files = sorted([os.path.join('data/derived', f) for f in os.listdir('data/derived') if not f.startswith('.')] +
               ['registry/construction/hdr_parsed_rows.csv', 'registry/construction/leave_inputs_audit.json'])
out = {'generated_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds'),
       'files': {f: {'sha256': hashlib.sha256(open(f, 'rb').read()).hexdigest(), 'bytes': os.path.getsize(f)} for f in files}}
json.dump(out, open('registry/construction/derived_hashes.json', 'w'), indent=1)
print(json.dumps(out, indent=1))
