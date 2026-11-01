"""Dump ICPSR 20320 .sav metadata (variable names, labels, value labels, missing ranges). No data summaries."""
import json, sys, pyreadstat
sav, out = sys.argv[1], sys.argv[2]
_, meta = pyreadstat.read_sav(sav, metadataonly=True)
d = {"n_rows": meta.number_rows, "n_cols": meta.number_columns, "file_encoding": meta.file_encoding,
     "file_label": meta.file_label, "variables": []}
for v in meta.column_names:
    vl = meta.variable_value_labels.get(v, {})
    d["variables"].append({
        "name": v, "label": meta.column_names_to_labels.get(v),
        "spss_format": meta.original_variable_types.get(v), "readstat_type": meta.readstat_variable_types.get(v),
        "measure": meta.variable_measure.get(v),
        "value_labels": {str(k): lab for k, lab in vl.items()},
        "missing_ranges": meta.missing_ranges.get(v, []),
        "missing_user_values": [str(x) for x in meta.missing_user_values.get(v, [])] if hasattr(meta,'missing_user_values') and meta.missing_user_values else [],
    })
json.dump(d, open(out, "w"), indent=1, ensure_ascii=False, default=str)
print(meta.number_rows, meta.number_columns)
