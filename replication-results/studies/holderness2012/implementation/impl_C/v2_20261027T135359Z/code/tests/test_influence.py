"""Regression checks for CHECK.md item 1; synthetic records only."""
import csv
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import quote

import numpy as np
import pandas as pd

SPEC = importlib.util.spec_from_file_location("analysis_run", Path(__file__).resolve().parents[1] / "run.py")
run = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = run
SPEC.loader.exec_module(run)


class InfluenceRegressionTests(unittest.TestCase):
    def exercise_deletions(self, scope, inject_failure=False):
        # Include separators, traversal text, percent escapes, punctuation and
        # two codes which replacing separators with underscores would conflate.
        camps = ["/91", "\\91", "%91", "_91", "../", "a:b", "a\nb", "%2F91"]
        camps += [str(i) for i in range(101, 119)]
        base = pd.DataFrame({"camp": camps, "record_seq": np.arange(1, len(camps)+1)})
        models = run.models_for("T4")
        cache = {m.id: dict(camp=base.camp.to_numpy(), ids=base.record_seq.to_numpy()) for m in models}
        selected = sorted(camps)[:20] if scope == "first20" else sorted(camps)
        attempts = []
        failed_key = (models[0].id, "__delete_" + quote("/91", safe=""))
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            out = run.Outputs(directory)
            try:
                for model in models:
                    out.write("results", dict(spec_id="S000", model_id=model.id,
                                              term="steepness", status="ok"))
                    out.ids("S000", model.id, base.record_seq)
                original_results = (Path(directory) / "results.csv").read_bytes()

                def fit(sample, model, spec, output, *, write_results, suffix):
                    self.assertFalse(write_results)
                    attempts.append((model.id, suffix))
                    output.ids(spec, model.id + suffix, sample.record_seq)
                    if inject_failure and (model.id, suffix) == failed_key:
                        raise RuntimeError("injected deletion failure")
                    return dict(meta=dict(status="ok", error="", n=len(sample)),
                                rows={model.hierarchy[0]: dict(me=.1, me_p=.2)})

                with patch.object(run, "run_fit", side_effect=fit):
                    run.run_influence(cache, {"cap": base, "camp": base}, "S000", out, scope)
                self.assertEqual((Path(directory) / "results.csv").read_bytes(), original_results)
            finally:
                out.close()
            with (Path(directory) / "influence.csv").open() as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual(len(rows), len(models)*len(selected))
            self.assertEqual(len(attempts), len(rows))
            self.assertEqual(len(set(attempts)), len(rows))
            failures = [r for r in rows if r["status"] == "failed"]
            self.assertEqual(len(failures), int(inject_failure))
            if inject_failure:
                self.assertEqual(failures[0]["deleted_camp"], "/91")
                self.assertIn("injected deletion failure", failures[0]["error"])
                self.assertEqual(rows[-1]["status"], "ok")
            sample_dir = Path(directory) / "sample_ids"
            self.assertEqual(len(list(sample_dir.iterdir())), len(models)+len(rows))
            self.assertTrue(all(p.is_file() for p in sample_dir.iterdir()))
            for model in models:
                original_path = sample_dir / f"S000__{model.id}.txt"
                np.testing.assert_array_equal(np.loadtxt(original_path, dtype=int), base.record_seq)
                for camp in selected:
                    path = sample_dir / f"S000__{model.id}__delete_{quote(camp, safe='')}.txt"
                    np.testing.assert_array_equal(np.loadtxt(path, dtype=int),
                                                  base.loc[base.camp.ne(camp), "record_seq"])

    def test_all_camps_safe_distinct_filenames(self):
        self.exercise_deletions("all")

    def test_first20_failure_does_not_abort_or_change_original_results(self):
        self.exercise_deletions("first20", inject_failure=True)

    def test_repeated_sample_id_write_failure_is_recorded(self):
        base = pd.DataFrame({"camp": ["/91", "101"], "record_seq": [2, 1]})
        model = run.Model("T4", "camp", "simple", ("steepness",))
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            out = run.Outputs(directory)
            try:
                with patch.object(out, "ids", side_effect=OSError("injected ID write failure")) as ids:
                    fit = run.run_fit(base, model, "SYNTH_IDS_FAILURE", out)
                self.assertEqual(ids.call_count, 2)
                self.assertEqual(fit["meta"]["status"], "failed")
                self.assertFalse(fit["meta"]["converged"])
                self.assertIn("sample IDs: OSError", fit["meta"]["error"])
            finally:
                out.close()
            with (Path(directory) / "results.csv").open() as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["status"], "failed")


if __name__ == "__main__":
    unittest.main(verbosity=2)
