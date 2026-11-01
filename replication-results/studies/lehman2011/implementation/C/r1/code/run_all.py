#!/usr/bin/env python
"""Run from the assignment directory:
 ~/.venv/bin/python -I code/run_all.py --stage synthetic|sample|full

Only full fits empirical models. All stages write only to results/. Frozen
grid values are embedded in samples.py; no prior results are read or reused.
"""
import os
for _key in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
    os.environ[_key] = "1"
import sys
sys.dont_write_bytecode = True
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import argparse
import datetime as dt
import platform
import traceback
import numpy as np
import pandas as pd
import scipy
import statsmodels
import pyarrow
from scipy.stats import chi2, norm
from estimators import fit_fixed, fit_random, sandwich
from samples import Samples, ORIGIN, AXES, PERF, INTER, cells, spec_id, design, refresh_interactions
from margins import margins

SPEC_COLS = ["spec_id", "step", "model"] + AXES + ["me_variant_set", "sample_hash", "status", "error",
             "n_obs", "n_groups_used", "n_groups_dropped", "loglik", "null_loglik", "null_label",
             "lr_chi2", "df", "converged", "iterations", "routine", "duplicate_of", "execution_id",
             "duplicate_of_execution_id", "auxiliary", "sigma_team"]
COEF_COLS = ["spec_id", "model", "term", "estimate", "se_native", "z_native", "p_native", "or", "or_se",
             "se_bench", "p_bench", "n_clusters_bench", "execution_id", "parameter_type"]
MARGIN_COLS = ["spec_id", "model", "variant", "minutes_eval", "d", "prob", "effect", "se_native",
               "p_native", "se_bench", "p_bench", "z_native", "execution_id", "source_execution_id", "time_variable"]
TEST_COLS = ["spec_id", "test", "statistic", "df", "p", "execution_id", "status", "error"]
INFL_COLS = ["unit_type", "unit_id", "model", "term", "estimate", "se_native", "p_native", "se_bench",
             "p_bench", "n_obs", "status", "error", "benchmark_estimate", "benchmark_n_obs", "benchmark_status",
             "benchmark_error", "n_clusters_bench", "n_groups_used", "n_groups_dropped"]

NOTES = """# Implementation notes

Implemented all specified analysis families, including team, season and game
influence deletions. The synthetic and sample stages do not fit empirical models.
The full stage first reruns the synthetic checks, then constructs all samples,
then runs the prescribed grid and additional analyses. Empirical fitting is
intentionally deferred in this session; empirical convergence is not yet known.

- The frozen grid is embedded in `code/samples.py` so runtime inputs are only
  the files in `data/` (besides the program itself). No downloaded inputs,
  package installations, prior outputs or published results are used.
- The manifest's explicit requirement for variants on individual-deviation
  cells is followed: U9a, U9b and U10a run for steps 1 and 2. The abbreviated
  step-2 text in grid.json only mentions ME0. N3 runs only for the origin.
- Auxiliary U7=1 fits supply origin benchmark results and U9a. They are tagged
  `auxiliary` and have their own `execution_id`. U9a rows retain the target
  cell's spec_id and identify the U7=1 source execution. Its SE is native only.
- Required spec_id strings recur at step 3. An additional execution_id appears
  in every related table to make joins unambiguous; duplicate_of is the first
  occurrence's spec_id and duplicate_of_execution_id points to that execution.
  Every scheduled step-3 fit is optimized again, including duplicates.
- Samples are identified before estimator-specific removal of constant-y
  strata. Estimation N and margin means exclude such strata for U7=0/2.
  The ID hash is SHA256 of lexicographically sorted UTF-8 game_id|integer-play_id
  lines, each with a trailing LF. Gzip CSVs include a header; hashes do not.
  sample_index.csv maps all 604 scheduled fits, including repeated cells, to
  samples without claiming that any empirical fit occurred in sample stage.
- sample_flow.csv reports all eight steps for every scheduled cell, including
  repeated cells, common-case dropped counts, each model's own complete-case
  count, and division disagreements on the common sample. Empty team strings
  are missing. Missing scores propagate to all performance terms. Home status
  follows the stated equality/otherwise-zero rule. Only needed play columns
  are loaded; the unused mixed-type goal_to_go column is never stacked.
- Exact conditional likelihood uses the coefficient of the case-count power
  in the Bernoulli probability polynomial after exponential tilting. A balanced
  product tree uses direct convolution for small polynomials and zero-padded
  FFT convolution for larger ones; reverse differentiation gives the score.
  This computes the exact conditional likelihood up to floating-point error,
  with no Breslow, Efron, saddlepoint, subset or tie approximation. Central
  differences of the analytic score give observed information. Internal QR
  scaling is transformed back to the original log-odds coefficients.
- Fit convergence requires score norm in information/SE units <1e-4. A failed
  covariance or unidentified model is recorded as failed; no pseudoinverse,
  ridge penalty or alternative regressor search is used. Nonconverged fits
  retain their estimates and are labelled. Failure messages propagate.
- N1 uses normal random-intercept ML with 20-point adaptive Gauss-Hermite
  quadrature, recalculating each mode and curvature at every parameter value.
  Scores include derivatives of the adaptive nodes and scale. Observed
  information includes the log standard deviation nuisance parameter. N1's
  fixed intercept is estimated; zero-group-effect margins omit it, as in ME0.
  log_sigma_team is explicitly labelled ancillary and has no odds ratio.
- N2 uses quarters_remaining internally in the minutes slot, including every
  interaction; output coefficient names and time_variable label that change.
- nonequiv.csv is a union of the prescribed spec/coefficient/margin/test
  formats, with run_id and record_type. N4 reports the U7=1 origin estimates
  with team-cluster CR1 SEs in benchmark columns (including marginal effects).
  algebraic_checks.csv similarly includes fitted coefficients and LL/contrast
  checks. Its extra fields give original/reparameterized LLs and coefficients.
- For season deletions only, absent season levels are structural aliases.
  The same season-factor column space is expressed using the earliest retained
  season as reference and only retained levels. This normalization preserves
  every estimable performance coefficient; it is not regressor selection.
- Grid and influence fits warm-start from available earlier fits of the same
  model/estimator, with named coefficient alignment. Influence deletions use
  the origin estimates and covariance when parameterizations agree. Every
  team, season and game is visited, even after previous failures. Influence
  native estimates are U7=0; benchmark SE/p values come from the companion
  U7=1 fit. Additional benchmark_estimate/status/error fields expose this
  distinction. No game deletions are skipped.
- The undocumented spread-reference and field-goal-range analyses listed as
  unavailable in grid.json are not executed, as specified.

Manifest items not implemented: none. Full-stage empirical outputs and their
numerical fit diagnostics have not been generated in this session.
"""


def coefficient_rows(fit):
    se = np.sqrt(np.diag(fit.cov))
    rows = []
    for j, name in enumerate(fit.names):
        b, s = fit.beta[j], se[j]
        z = b/s
        ancillary = name == "log_sigma_team"
        with np.errstate(over="ignore"):
            odds = None if ancillary else float(np.exp(b))
        row = dict(term=name, estimate=b, se_native=s, z_native=z, p_native=2*norm.sf(abs(z)),
                   **{"or": odds, "or_se": None if ancillary else odds*s},
                   se_bench=None, p_bench=None, n_clusters_bench=fit.clusters,
                   parameter_type="ancillary" if ancillary else "log_odds")
        if fit.bench is not None:
            sb = np.sqrt(max(0, fit.bench[j, j]))
            row.update(se_bench=sb, p_bench=2*norm.sf(abs(b/sb)))
        rows.append(row)
    return rows


def model_tests(fits):
    rows = []
    for big, small in [("M2", "M1"), ("M3", "M2")]:
        if big not in fits or small not in fits:
            continue
        f, r = fits[big], fits[small]
        if f is None or r is None:
            rows.append((big, dict(test=f"LR_{big}_vs_{small}", status="failed", error="Required fit failed")))
            continue
        if f.n != r.n or not np.array_equal(f.used, r.used):
            raise ValueError("LR comparison samples differ")
        stat, df = 2*(f.ll-r.ll), len(f.beta)-len(r.beta)
        rows.append((big, dict(test=f"LR_{big}_vs_{small}", statistic=stat, df=df,
                               p=chi2.sf(max(0, stat), df), status="ok" if f.converged and r.converged else "not_converged")))
    f = fits.get("M2")
    if f is not None:
        for name, joint in [("Wald_below_equals_above", False), ("Wald_performance_joint", True)]:
            A = np.zeros((4 if joint else 1, len(f.beta)))
            if joint:
                for j, t in enumerate(PERF):
                    A[j, f.names.index(t)] = 1
            else:
                A[0, f.names.index("perf_below")] = 1
                A[0, f.names.index("perf_above")] = -1
            v = A @ f.beta
            stat = float(v @ np.linalg.solve(A @ f.cov @ A.T, v))
            rows.append(("M2", dict(test=name, statistic=stat, df=len(A), p=chi2.sf(stat, len(A)),
                                    status="ok" if f.converged else "not_converged")))
    elif "M2" in fits:
        for name in ["Wald_below_equals_above", "Wald_performance_joint"]:
            rows.append(("M2", dict(test=name, status="failed", error="M2 fit failed")))
    return rows


def fit_dataframe(df, model, cell, previous=None, random=False, influence=False):
    X, y, groups, names = design(df, model, cell, random=random, influence=influence)
    if random:
        return fit_random(X, y, groups, names)
    start, cov = None, None
    if previous is not None:
        lookup = dict(zip(previous.names, previous.beta))
        start = np.array([lookup.get(t, 0.) for t in names])
        if names == previous.names:
            cov = previous.cov
    fit = fit_fixed(X, y, groups, names, cell["U7"] != 1, start, cov)
    if cell["U7"] == 1:
        fit.bench, fit.clusters = sandwich(X, y, fit.beta, fit.cov, df.game_id.to_numpy())
    return fit


class FullRunner:
    def __init__(self, results):
        self.results = results
        self.specs, self.coefs, self.margins, self.tests = [], [], [], []
        self.nonequiv, self.algebra, self.influence = [], [], []
        self.first, self.previous, self.origin = {}, {}, {}
        self.counter = 0

    def execute(self, df, sha, model, cell, step, variants, auxiliary=False, run_id=None,
                random=False, previous=None, quarters=False):
        self.counter += 1
        sid = spec_id(model, cell)
        eid = f"{step}:{self.counter:05d}:{run_id or 'grid'}:{sid}"
        key = (sid, run_id)
        duplicate = self.first.get(key)
        row = dict(spec_id=sid, step=step, model=model, **cell, me_variant_set=",".join(variants),
                   sample_hash=sha, duplicate_of=sid if duplicate else "",
                   duplicate_of_execution_id=duplicate or "", execution_id=eid, auxiliary=auxiliary)
        self.first.setdefault(key, eid)
        fit = None
        try:
            prev = previous if previous is not None else self.previous.get((model, cell["U7"]))
            fit = fit_dataframe(df, model, cell, previous=prev, random=random)
            row.update(status="ok" if fit.converged else "not_converged", error=fit.error,
                       n_obs=fit.n, n_groups_used=fit.groups, n_groups_dropped=fit.dropped,
                       loglik=fit.ll, null_loglik=fit.null_ll, null_label=fit.null_label,
                       lr_chi2=2*(fit.ll-fit.null_ll), df=fit.df, converged=fit.converged,
                       iterations=fit.iterations, routine=fit.routine, sigma_team=fit.sigma)
            coef = [dict(spec_id=sid, model=model, execution_id=eid, **r) for r in coefficient_rows(fit)]
            mar = [dict(spec_id=sid, execution_id=eid, source_execution_id=eid, **r)
                   for r in margins(fit, df.iloc[fit.used], model, variants, quarters)] if model != "M1" else []
            if run_id is None:
                self.coefs.extend(coef)
                self.margins.extend(mar)
                self.previous[(model, cell["U7"])] = fit
            else:
                target = self.algebra if run_id.startswith("K") else self.nonequiv
                if quarters:
                    for r in coef:
                        r["term"] = r["term"].replace("_x_min", "_x_quarters_remaining").replace("minutes", "quarters_remaining")
                if run_id == "K1":
                    for r in coef:
                        r["term"] = r["term"].replace("_x_min", "_x_elapsed").replace("minutes", "elapsed")
                target.extend(dict(run_id=run_id, record_type="coefficient", **r) for r in coef)
                target.extend(dict(run_id=run_id, record_type="margin", **r) for r in mar)
        except Exception as exc:
            row.update(status="failed", error=f"{type(exc).__name__}: {exc}", n_obs=len(df), converged=False)
            fit = None
        if run_id is None:
            self.specs.append(row)
        else:
            target = self.algebra if run_id.startswith("K") else self.nonequiv
            target.append(dict(run_id=run_id, record_type="spec", **row))
        print(f"{eid} {row['status']}", flush=True)
        return fit, eid

    def add_tests(self, fits, eids, cell, run_id=None):
        for model, row in model_tests(fits):
            out = dict(spec_id=spec_id(model, cell), execution_id=eids[model], **row)
            if run_id:
                self.nonequiv.append(dict(run_id=run_id, record_type="test", **out))
            else:
                self.tests.append(out)

    def grid_cell(self, step, cell, models, df, sha):
        fits, eids = {}, {}
        for model in models:
            variants = [] if model == "M1" else (["ME0", "U9b", "U10a"] if step < 3 else ["ME0"])
            if step == 1 and model != "M1":
                variants += ["N3"]
            fits[model], eids[model] = self.execute(df, sha, model, cell, step, variants)
            if step == 1:
                self.origin[(model, 0)] = fits[model]
                self.origin[(model, "eid0")] = eids[model]
        self.add_tests(fits, eids, cell)
        if step < 3:
            uc = cell | {"U7": 1}
            ufit, ueids = {}, {}
            for model in (["M1", "M2", "M3"] if step == 1 else [m for m in models if m != "M1"]):
                if cell["U7"] == 1:
                    ufit[model], ueids[model] = fits[model], eids[model]
                else:
                    ufit[model], ueids[model] = self.execute(df, sha, model, uc, step,
                                                          [] if model == "M1" else ["ME0"], auxiliary=True)
                if step == 1:
                    self.origin[(model, 1)] = ufit[model]
                    self.origin[(model, "eid1")] = ueids[model]
                if model != "M1" and ufit[model] is not None:
                    f = ufit[model]
                    for r in margins(f, df.iloc[f.used], model, ["U9a"]):
                        self.margins.append(dict(spec_id=spec_id(model, cell), execution_id=eids[model],
                                                 source_execution_id=ueids[model], **r))
                if model != "M1":
                    for spec in self.specs:
                        if spec["execution_id"] == eids[model]:
                            spec["me_variant_set"] += ",U9a"
            if step == 1:
                self.add_tests(ufit, ueids, uc)

    def additional(self, df, sha):
        for run_id in ["N1", "N2"]:
            data = df.copy()
            if run_id == "N2":
                data["minutes"] = 5-data.qtr
                refresh_interactions(data)
            fits, eids = {}, {}
            for model in ["M1", "M2", "M3"]:
                fits[model], eids[model] = self.execute(data, sha, model, ORIGIN, 4,
                    [] if model == "M1" else ["ME0"], run_id=run_id, random=run_id == "N1", quarters=run_id == "N2")
            self.add_tests(fits, eids, ORIGIN, run_id)
        # N4 is an inference change to exactly the origin U7=1 fits.
        import copy
        uc = ORIGIN | {"U7": 1}
        for model in ["M1", "M2", "M3"]:
            f = copy.copy(self.origin.get((model, 1)))
            sid, eid = spec_id(model, uc), self.origin.get((model, "eid1"))
            try:
                if f is None:
                    raise ValueError("Origin U7=1 fit failed")
                X, y, _, _ = design(df, model, uc)
                f.bench, f.clusters = sandwich(X, y, f.beta, f.cov, df.posteam.to_numpy())
                for row in coefficient_rows(f):
                    self.nonequiv.append(dict(run_id="N4", record_type="coefficient", spec_id=sid,
                                             model=model, execution_id=eid, **row))
                if model != "M1":
                    for row in margins(f, df, model, ["ME0", "U9b", "U10a", "N3"]):
                        self.nonequiv.append(dict(run_id="N4", record_type="margin", spec_id=sid,
                                                 execution_id=eid, **row))
                self.nonequiv.append(dict(run_id="N4", record_type="spec", spec_id=sid, model=model,
                    execution_id=eid, status="ok" if f.converged else "not_converged", error=f.error,
                    n_obs=f.n, n_groups_used=f.groups, n_groups_dropped=0, loglik=f.ll,
                    null_loglik=f.null_ll, null_label=f.null_label, lr_chi2=2*(f.ll-f.null_ll), df=f.df,
                    converged=f.converged, iterations=f.iterations, routine=f.routine+"; CR1 clustered by team"))
            except Exception as exc:
                self.nonequiv.append(dict(run_id="N4", record_type="spec", spec_id=sid, model=model,
                                         status="failed", error=str(exc)))
        for run_id, model in [("K1", "M3"), ("K2", "M2")]:
            data = df.copy()
            if run_id == "K1":
                data["minutes"] = 60-data.minutes
                refresh_interactions(data)
            else:
                data["home_field"] = 1-data.home_field
            original = self.origin.get((model, 0))
            f, eid = self.execute(data, sha, model, ORIGIN, 5, [], run_id=run_id)
            row = dict(run_id=run_id, record_type="check", spec_id=spec_id(model, ORIGIN),
                       execution_id=eid, model=model, status="failed", error="Required fit failed")
            if f is not None and original is not None:
                row.update(status="ok" if f.converged and original.converged else "not_converged", error="",
                           original_loglik=original.ll, loglik=f.ll, loglik_difference=f.ll-original.ll)
                if run_id == "K2":
                    row.update(original_coefficient=original.beta[original.names.index("home_field")],
                               complemented_coefficient=f.beta[f.names.index("home_field")])
            self.algebra.append(row)

    def influence_deletions(self, df, unit_values=None):
        """By default every observed unit; unit_values is for synthetic checks."""
        for unit, column in [("team", "posteam"), ("season", "season"), ("game", "game_id")]:
            values = sorted(df[column].unique()) if unit_values is None else unit_values.get(unit, [])
            for value in values:
                data = df.loc[df[column] != value].reset_index(drop=True)
                for model in ["M2", "M3"]:
                    fits, errors = {}, {}
                    for estimator in [0, 1]:
                        try:
                            fits[estimator] = fit_dataframe(data, model, ORIGIN | {"U7": estimator},
                                previous=self.origin.get((model, estimator)), influence=True)
                            errors[estimator] = fits[estimator].error
                        except Exception as exc:
                            fits[estimator] = None
                            errors[estimator] = f"{type(exc).__name__}: {exc}"
                    f, b = fits[0], fits[1]
                    cf = {r["term"]: r for r in coefficient_rows(f)} if f is not None else {}
                    cb = {r["term"]: r for r in coefficient_rows(b)} if b is not None else {}
                    for term in PERF + (INTER if model == "M3" else []):
                        c, bench = cf.get(term, {}), cb.get(term, {})
                        self.influence.append(dict(unit_type=unit, unit_id=value, model=model, term=term,
                            estimate=c.get("estimate"), se_native=c.get("se_native"), p_native=c.get("p_native"),
                            se_bench=bench.get("se_bench"), p_bench=bench.get("p_bench"),
                            n_obs=f.n if f else len(data), status="failed" if f is None else "ok" if f.converged else "not_converged",
                            error=errors[0], benchmark_estimate=bench.get("estimate"),
                            benchmark_n_obs=b.n if b else len(data),
                            benchmark_status="failed" if b is None else "ok" if b.converged else "not_converged",
                            benchmark_error=errors[1], n_clusters_bench=b.clusters if b else None,
                            n_groups_used=f.groups if f else None, n_groups_dropped=f.dropped if f else None))
                print(f"influence {unit}={value}", flush=True)
                # Periodic checkpoint avoids retaining hours of unflushed output.
                if len(self.influence) % 220 == 0:
                    self.save()
            self.save()

    def save(self):
        for name, rows, cols in [("specs", self.specs, SPEC_COLS), ("coefs", self.coefs, COEF_COLS),
                                  ("margins", self.margins, MARGIN_COLS), ("tests", self.tests, TEST_COLS),
                                  ("influence", self.influence, INFL_COLS)]:
            pd.DataFrame(rows, columns=cols).to_csv(self.results / (name+".csv"), index=False)
        for name, rows in [("nonequiv", self.nonequiv), ("algebraic_checks", self.algebra)]:
            columns = list(dict.fromkeys(["run_id", "record_type"]+SPEC_COLS+COEF_COLS+MARGIN_COLS+TEST_COLS+
                                         [k for row in rows for k in row]))
            pd.DataFrame(rows).reindex(columns=columns).to_csv(self.results / (name+".csv"), index=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", choices=["synthetic", "sample", "full"], default="full")
    args = parser.parse_args()
    root = Path.cwd()
    results = root / "results"
    (results / "samples").mkdir(parents=True, exist_ok=True)
    started = dt.datetime.now(dt.timezone.utc)
    (results / "implementation_notes.md").write_text(NOTES)
    try:
        if args.stage in ("synthetic", "full"):
            from synthetic import run_checks
            run_checks(results)
        if args.stage in ("sample", "full"):
            sample = Samples(root, results)
            runner = FullRunner(results) if args.stage == "full" else None
            # First construct and record every grid sample without empirical fits.
            for step, cell, models in cells():
                prepared = sample.prepare(cell)
                sample.record(step, cell, models, prepared)
            sample.save()
            origin = sample.prepare(ORIGIN)
            print("Origin sample flow: " + repr(origin[2]), flush=True)
            print(f"{len(sample.written)} distinct samples; {len(sample.index)} scheduled fits", flush=True)
            if runner:
                for step, cell, models in cells():
                    df, sha, *_ = sample.prepare(cell)
                    runner.grid_cell(step, cell, models, df, sha)
                    runner.save()
                df, sha, *_ = origin
                runner.additional(df, sha)
                runner.save()
                runner.influence_deletions(df)
                runner.save()
    finally:
        ended = dt.datetime.now(dt.timezone.utc)
        lines = [f"stage={args.stage}", f"start_utc={started.isoformat()}", f"end_utc={ended.isoformat()}",
                 f"elapsed_seconds={(ended-started).total_seconds():.3f}", f"Python={sys.version}",
                 f"executable={sys.executable}", f"OS={platform.platform()}"]
        for module in [np, pd, scipy, statsmodels, pyarrow]:
            lines.append(f"{module.__name__}={module.__version__}")
        # Append only; outputs are never used as analytical inputs.
        with (results / "environment.txt").open("a") as out:
            out.write("\n".join(lines)+"\n\n")


if __name__ == "__main__":
    main()
