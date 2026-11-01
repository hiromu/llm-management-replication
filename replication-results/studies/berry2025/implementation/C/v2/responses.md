# Responses to checker items

1. **Extra `unmet.md` files — accepted and fixed.** Removed the failure-log generation and both `unmet.md` writes from `write_outputs`. The script now writes only `results.csv`, `influence.csv`, `samples.csv`, and `session_info.txt` to `--out`, with no writes beside the script. Computational failures remain represented by `status` and `message` in the CSV files, and bootstrap discards remain in `.boot_failed` result keys.

2. **Dataset 1 unit identifiers — accepted and fixed.** Dataset 1 now links rows using the original text `part_uid` and assigns each person the one-based row number of their first occurrence in the original input file. This representative row number is assigned before filtering and used consistently in `samples.csv` and `influence.csv`. Both rows still belong to one person for attention filtering, pairing, and leave-one-person-out deletion. Each missing `part_uid` remains an isolated unit identified by its own original row number, without synthetic string identifiers or collisions with actual person identifiers. Datasets 2–4 retain their original one-based row identifiers.

## Validation

Ran successfully using only installed packages:

```text
~/.venv/bin/python output/analysis.py --data input/synthetic --out synthetic_out --seed 20261031 --boot 200
```

Validated the exact four runtime output filenames and column schemas, unique result/influence/sample identities, numeric unit identifiers, original-row mapping for Dataset 1 under both sample levels, and complete deletion coverage for every retained unit and requested influence estimand. The run produced 12,710 result rows, 7,362 influence rows, and 1,052 retained-unit rows; every result and influence row had status `ok`. Seven bootstrap-discard keys were positive; the counts are recorded in `results.csv` and remaining successful resamples supplied the intervals.

Additional regression checks passed for nonadjacent person rows, person-level attention filtering and deletion, separate missing identifiers, a real identifier matching the former synthetic-placeholder pattern, distinct text identifiers `001` and `1`, and unchanged row numbering for datasets 2–4. No substantive conclusions were drawn from the synthetic values.
