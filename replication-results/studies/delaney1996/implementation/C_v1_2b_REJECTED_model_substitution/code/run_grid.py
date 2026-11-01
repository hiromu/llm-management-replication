#!/usr/bin/env python
"""PAPER_K7 grid runner.

Usage:
  python code/run_grid.py --data survey.csv --metadata survey_metadata.json \
      --crosswalk industry_crosswalk.csv --grid grid_v1.json --out output_dir
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import platform
import sys
import traceback

import numpy as np
import pandas as pd
import scipy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from paperk7 import coding as C  # noqa: E402
from paperk7 import pipeline as P  # noqa: E402

COEF_COLS = ["spec_id", "family", "model_id", "term", "estimate", "se", "t", "df", "p_two", "p_upper", "p_lower",
             "se_hc3", "t_hc3", "p_two_hc3", "p_upper_hc3", "p_lower_hc3"]
STAT_COLS = ["spec_id", "family", "model_id", "status", "error", "n", "k", "n_industry_dummies", "dropped_columns",
             "r2", "adj_r2", "f", "f_df1", "f_df2", "f_p", "n_leverage_one"]
NESTED_COLS = ["spec_id", "family", "test_id", "full_model", "restricted_model", "n", "delta_r2", "f", "df1", "df2", "p"]
SAMPLE_COLS = ["spec_id", "family", "model_id", "V1"]
INFL_COLS = ["model_id", "deleted_V1", "term", "estimate", "se", "p_upper", "p_two", "status", "note"]


def now():
    return dt.datetime.now().astimezone().isoformat(timespec="seconds")


def load_raw(path):
    raw = pd.read_csv(path, low_memory=False)
    missing = [v for v in C.RAW_VARS if v not in raw.columns]
    if missing:
        raise SystemExit(f"survey file lacks required columns: {missing}")
    if not raw["V1"].is_unique:
        raise SystemExit("V1 is not unique")
    for v in C.RAW_VARS:
        raw[v] = pd.to_numeric(raw[v], errors="coerce").astype(float)
    return raw


INT_COLS = {"n", "k", "n_industry_dummies", "f_df1", "f_df2", "n_leverage_one", "df", "df1", "df2", "V1", "deleted_V1"}


def write_csv(rows, cols, path):
    df = pd.DataFrame(rows, columns=cols)
    for c in cols:
        if c in INT_COLS and c in df.columns:
            vals = pd.to_numeric(df[c], errors="coerce").astype(float)
            nonmissing = vals.dropna().values
            if np.all(np.isfinite(nonmissing)) and np.all(nonmissing == np.round(nonmissing)):
                df[c] = vals.astype("Int64")
    df.to_csv(path, index=False, na_rep="NA")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--metadata", required=True)
    ap.add_argument("--crosswalk", required=True)
    ap.add_argument("--grid", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args(argv)

    start = now()
    os.makedirs(args.out, exist_ok=True)
    raw = load_raw(args.data)
    meta = C.load_metadata(args.metadata)
    crosswalk = C.load_crosswalk(args.crosswalk)
    with open(args.grid) as fh:
        grid = json.load(fh)
    specs = {s["spec_id"]: s for s in grid["specs"]}
    order = grid.get("compute_order") or list(specs)

    coef_rows, stat_rows, nested_rows, sample_rows, infl_rows = [], [], [], [], []
    failures, specs_run, notes = [], [], []
    z_info = {}
    origin_result = None
    for spec_id in order:
        if spec_id not in specs:
            failures.append({"spec_id": spec_id, "stage": "grid", "error": "spec_id in compute_order but not in specs"})
            continue
        spec = specs[spec_id]
        print(f"[{now()}] spec {spec_id} ({spec.get('type')})", flush=True)
        try:
            res = P.run_spec(spec, raw, meta, crosswalk)
        except Exception as exc:  # noqa: BLE001
            msg = f"{type(exc).__name__}: {exc}"
            failures.append({"spec_id": spec_id, "stage": "spec", "error": msg, "traceback": traceback.format_exc()})
            for fam in ("org", "mkt"):
                for model_id, _, _ in P.model_definitions(fam):
                    stat_rows.append(P._stat_row(spec_id, fam, model_id, "failed", msg))
            specs_run.append(spec_id)
            continue
        coef_rows.extend(res.coefficients)
        stat_rows.extend(res.model_stats)
        nested_rows.extend(res.nested)
        sample_rows.extend(res.samples)
        failures.extend(res.failures)
        notes.extend(f"{spec_id}: {n}" for n in res.notes)
        if getattr(res, "z_info", None):
            z_info[spec_id] = res.z_info
        specs_run.append(spec_id)
        if spec.get("type") == "origin" or spec_id == "O":
            origin_result = res

    if origin_result is not None:
        print(f"[{now()}] influence diagnostic on origin spec {origin_result.spec_id}", flush=True)
        rows, infl_fail = P.run_influence(origin_result)
        infl_rows.extend(rows)
        failures.extend(infl_fail)
    else:
        failures.append({"spec_id": "O", "stage": "influence", "error": "no origin specification in the grid"})

    write_csv(coef_rows, COEF_COLS, os.path.join(args.out, "coefficients.csv"))
    write_csv(stat_rows, STAT_COLS, os.path.join(args.out, "model_stats.csv"))
    write_csv(nested_rows, NESTED_COLS, os.path.join(args.out, "nested_tests.csv"))
    write_csv(sample_rows, SAMPLE_COLS, os.path.join(args.out, "samples.csv"))
    write_csv(infl_rows, INFL_COLS, os.path.join(args.out, "influence.csv"))

    def _clean(obj):
        if isinstance(obj, dict):
            return {k: _clean(v) for k, v in obj.items()}
        if isinstance(obj, (list, tuple)):
            return [_clean(v) for v in obj]
        if isinstance(obj, (np.floating, float)):
            return None if not np.isfinite(obj) else float(obj)
        if isinstance(obj, np.integer):
            return int(obj)
        return obj

    n_lev = sum(1 for r in stat_rows if r.get("status") == "ok" and (r.get("n_leverage_one") or 0) > 0)
    info = {
        "specification": "PAPER_K7 implementation specification version 1 (frozen) with amendment v1.1",
        "implementation_version": "v1.2",
        "grid_version": grid.get("grid_version"),
        "software": {
            "python": sys.version,
            "platform": platform.platform(),
            "numpy": np.__version__,
            "pandas": pd.__version__,
            "scipy": scipy.__version__,
            "estimation": "own numpy OLS/WLS (paperk7.regression); statsmodels used only in tests as reference",
        },
        "inputs": {"data": os.path.abspath(args.data), "metadata": os.path.abspath(args.metadata),
                   "crosswalk": os.path.abspath(args.crosswalk), "grid": os.path.abspath(args.grid)},
        "n_rows_in_data": int(raw.shape[0]),
        "start_time": start,
        "end_time": now(),
        "specs_run": specs_run,
        "n_specs_run": len(specs_run),
        "failures": _clean(failures),
        "n_failures": len(failures),
        "notes": notes,
        "n_models_with_leverage_one_rows": n_lev,
        "hc3_convention": "amendment A1: rows with leverage >= 1 - 1e-8 contribute zero to the HC3 meat; "
                          "their count is model_stats.csv column n_leverage_one",
        "missing_value_convention": "NA in the CSV files; null in this JSON file (amendment A6)",
        "unimplemented": [],
        "z_reference_info": _clean(z_info),
        "output_files": ["coefficients.csv", "model_stats.csv", "nested_tests.csv", "samples.csv",
                         "influence.csv", "run_info.json"],
    }
    with open(os.path.join(args.out, "run_info.json"), "w") as fh:
        json.dump(info, fh, indent=1)
    print(f"[{now()}] done: {len(specs_run)} specs, {len(failures)} failures", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
