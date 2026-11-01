"""Deterministic tests using generated data only; never reads data/."""
from dataclasses import replace
from itertools import combinations
import time
import numpy as np
import pandas as pd
from scipy.integrate import quad
from scipy.special import expit, logsumexp
from scipy.stats import norm
from statsmodels.discrete.conditional_models import ConditionalLogit
from statsmodels.discrete.discrete_model import Logit
from statsmodels.stats.sandwich_covariance import cov_cluster
from estimators import (Fit, conditional_group, polynomial_probability, fit_fixed, fit_random,
                        random_objective, jacobian, sandwich)
from samples import Samples, ORIGIN, BASE, PERF, INTER, SEASONS, refresh_interactions, cells, design, variables, id_hash
from margins import evaluation_vectors, margin_value_gradient


def fixture(seed=816, nteams=12, per_season=16):
    """Artificial analysis-ready football-shaped rows; no real data consumed."""
    rng = np.random.default_rng(seed)
    n = nteams*6*per_season
    teams = np.repeat([f"T{j:02}" for j in range(nteams)], 6*per_season)
    seasons = np.tile(np.repeat(np.arange(2000, 2006), per_season), nteams)
    df = pd.DataFrame(dict(posteam=teams, season=seasons, game_id=[f"G{i//4:05}" for i in range(n)],
                           play_id=np.arange(n), qtr=rng.integers(1, 5, n)))
    df["minutes"] = rng.uniform(2.1, 60, n)
    df["total_points"] = rng.uniform(0, 35, n)
    df["yards_first_down"] = rng.uniform(1, 20, n)
    df["yards_touchdown"] = rng.uniform(1, 99, n)
    df["same_division"] = rng.binomial(1, .3, n)
    df["same_conference"] = np.maximum(df.same_division, rng.binomial(1, .5, n))
    df["home_field"] = rng.binomial(1, .5, n)
    df["week"] = rng.integers(1, 18, n)
    df["d"] = rng.uniform(-35, 35, n)
    df["perf_below"] = np.minimum(df.d, 0)
    df["perf_below_sq"] = df.perf_below**2
    df["perf_above"] = np.maximum(df.d, 0)
    df["below_indicator"] = (df.d <= 0).astype(float)
    for s in range(2001, 2006):
        df[f"season_{s}"] = (seasons == s).astype(float)
    refresh_interactions(df)
    b = np.array([.007, -.02, -.006, .1, .08, .12, .01, -.008] + [.03]*5 +
                 [-.02, -.0002, .015, .1, .0001, .000004, -.0001])
    alpha = rng.normal(-.8, .65, nteams)
    eta = df[BASE+SEASONS+PERF+INTER].to_numpy() @ b + np.repeat(alpha, 6*per_season)
    df["y"] = rng.binomial(1, expit(eta))
    return df


def run_checks(results):
    started = time.monotonic()
    records, recovery = [], []
    def check(name, error, tolerance, detail=""):
        passed = bool(np.isfinite(error) and error <= tolerance)
        records.append((name, passed, float(error), float(tolerance), detail))
        print(f"synthetic {'PASS' if passed else 'FAIL'}: {name} ({error:.4g} <= {tolerance:.4g})", flush=True)

    rng = np.random.default_rng(20261027)
    try:
        # Direct enumeration also supplies independent score and information.
        for n, m in [(8, 3), (9, 7), (12, 4), (10, 1)]:
            X = rng.normal(size=(n, 3))
            b = np.array([.65, -.45, .25])
            y = np.r_[np.ones(m), np.zeros(n-m)]
            eta = X @ b
            combos = np.array([X[list(ix)].sum(axis=0) for ix in combinations(range(n), m)])
            w = np.exp(combos @ b-logsumexp(combos @ b))
            mean = w @ combos
            direct = y @ eta-logsumexp(combos @ b)
            score = X.T @ y-mean
            info = (combos-mean).T @ (w[:, None]*(combos-mean))
            ll, s = conditional_group(eta, y)
            numerical_info = -jacobian(lambda t: X.T @ conditional_group(X @ t, y)[1], b)
            check(f"exact enumeration LL n={n},m={m}", abs(ll-direct), 1e-10)
            check(f"exact enumeration score n={n},m={m}", np.max(abs(X.T @ s-score)), 1e-9)
            check(f"exact enumeration information n={n},m={m}", np.max(abs(numerical_info-info)), 2e-7)
            sm = ConditionalLogit(y, X, groups=np.zeros(n))
            check(f"statsmodels exact LL n={n},m={m}", abs(ll-sm.loglike(b)), 1e-10)
        for n, m in [(100, 13), (1100, 90)]:
            eta = rng.normal(0, 2, n)
            y = np.r_[np.ones(m), np.zeros(n-m)]
            # Independent log-domain dynamic programming, no FFT.
            logcoef = np.full(m+1, -np.inf)
            logcoef[0] = 0
            for t in eta:
                logcoef[1:] = np.logaddexp(logcoef[1:], logcoef[:-1]+t)
            ll, s = conditional_group(eta, y)
            check(f"large-stratum exact LL versus log-DP n={n}", abs(ll-(y @ eta-logcoef[m])), 1e-8)
            check(f"conditional intercept invariance n={n}", abs(ll-conditional_group(eta+150, y)[0]), 1e-8)
            direction = rng.normal(size=n)
            h = 1e-5
            numeric = (conditional_group(eta+h*direction, y)[0]-conditional_group(eta-h*direction, y)[0])/(2*h)
            check(f"large-stratum directional score n={n}", abs(numeric-s @ direction), 1e-6)

        # All fixed-effects estimators and random effects recover the same slopes.
        ng, per = 72, 96
        groups = np.repeat(np.arange(ng), per)
        season = np.tile(np.repeat([0, 1], per//2), ng)
        X = rng.normal(size=(ng*per, 2))
        true_slopes = np.array([.65, -.45])
        sigma, intercept, season_b = .7, -.8, .25
        alpha = rng.normal(0, sigma, ng)
        y = rng.binomial(1, expit(intercept+alpha[groups]+X @ true_slopes+season_b*season))
        X0 = np.column_stack((X, season))
        names0 = ["x1", "x2", "season"]
        f0 = fit_fixed(X0, y, groups, names0)
        X1 = np.column_stack((np.ones(len(y)), X0, groups[:, None] == np.arange(1, ng)))
        names1 = ["intercept"]+names0+[f"team_{j}" for j in range(1, ng)]
        f1 = fit_fixed(X1, y, groups, names1, conditional=False)
        f2 = fit_fixed(X, y, groups*2+season, ["x1", "x2"])
        Xr = np.column_stack((np.ones(len(y)), X0))
        fr = fit_random(Xr, y, groups, ["intercept"]+names0)
        for label, fit in [("U7=0", f0), ("U7=1", f1), ("U7=2", f2), ("N1", fr)]:
            check(label+" converged", 0 if fit.converged else 1, 0, fit.error)
            truths = {"x1": .65, "x2": -.45}
            if label != "U7=2":
                truths["season"] = season_b
            if label == "N1":
                truths |= {"intercept": intercept, "log_sigma_team": np.log(sigma)}
            for term, true in truths.items():
                j = fit.names.index(term)
                se = np.sqrt(fit.cov[j, j])
                zerr = abs(fit.beta[j]-true)/se
                check(label+" recovery "+term, zerr, 4.)
                recovery.append(dict(estimator=label, term=term, truth=true, estimate=fit.beta[j], se=se, error_se=zerr))
        smfit = Logit(y, X1).fit(disp=False, maxiter=100)
        check("dummy logit versus statsmodels coefficients", np.max(abs(f1.beta-smfit.params)), 2e-5)
        check("dummy logit versus statsmodels native covariance", np.max(abs(f1.cov-smfit.cov_params())), 2e-6)
        # Exact fit handles homogeneous groups by removing them, not changing LL.
        yy = np.r_[y, np.zeros(8), np.ones(8)]
        xx = np.vstack((X0, rng.normal(size=(16, 3))))
        gg = np.r_[groups, np.repeat([ng, ng+1], 8)]
        fd = fit_fixed(xx, yy, gg, names0, start=f0.beta, start_cov=f0.cov)
        check("homogeneous conditional groups dropped", abs(fd.dropped-2)+abs(fd.n-len(y)), 0)
        check("homogeneous groups leave coefficients unchanged", np.max(abs(fd.beta-f0.beta)), 2e-5)

        # Adaptive quadrature derivative and integral checked independently.
        xs = np.column_stack((np.ones(18), rng.normal(size=(18, 2))))
        ys = rng.binomial(1, .45, 18)
        gs = np.repeat(np.arange(3), 6)
        theta = np.array([-.5, .4, -.2, np.log(.8)])
        fun = random_objective(xs, ys, gs, points=20)
        check("N1 moving-node analytic score versus numeric", np.max(abs(fun(theta)[1]-jacobian(lambda t: fun(t)[0], theta))), 2e-6)
        exact_ll = 0.
        for g in np.unique(gs):
            ix = gs == g
            eta = xs[ix] @ theta[:-1]
            sd = np.exp(theta[-1])
            def integrand(u):
                z = eta+u
                return np.exp((ys[ix]*z-np.logaddexp(0, z)).sum())*norm.pdf(u, scale=sd)
            val, _ = quad(integrand, -np.inf, np.inf, epsabs=1e-13, epsrel=1e-11)
            exact_ll += np.log(val)
        check("N1 20-point adaptive GH versus direct integration", abs(fun(theta)[0]+exact_ll), 2e-8)

        # Sandwich score, bread and cluster aggregation against numeric derivatives.
        xs = np.column_stack((np.ones(84), rng.normal(size=(84, 3))))
        ys = rng.binomial(1, expit(xs @ np.array([-.4, .6, -.25, .3])))
        gs = np.repeat(np.arange(21), 4)
        ff = fit_fixed(xs, ys, np.zeros(len(ys)), ["a", "b", "c", "d"], conditional=False)
        vc, G = sandwich(xs, ys, ff.beta, ff.cov, gs)
        def row_ll(b):
            eta = xs @ b
            return ys*eta-np.logaddexp(0, eta)
        score_num = jacobian(row_ll, ff.beta)
        bread_num = np.linalg.inv(jacobian(lambda b: xs.T @ (expit(xs @ b)-ys), ff.beta))
        cluster_scores = np.array([score_num[gs == g].sum(axis=0) for g in np.unique(gs)])
        vn = bread_num @ (cluster_scores.T @ cluster_scores) @ bread_num
        vn *= G/(G-1)*(len(ys)-1)/(len(ys)-len(ff.beta))
        check("CR1 sandwich versus numerical scores and information", np.max(abs(vc-vn)), 2e-8)
        sm = Logit(ys, xs).fit(disp=False)
        check("CR1 sandwich versus statsmodels cov_cluster", np.max(abs(vc-cov_cluster(sm, gs))), 2e-7)

        # Margins use actual fitted design coefficients; every variant and branch.
        df = fixture()
        uc = ORIGIN | {"U7": 1}
        fit_cache = {}
        for model in ["M2", "M3"]:
            xx, yy, gg, names = design(df, model, uc)
            f = fit_fixed(xx, yy, gg, names, conditional=False)
            fit_cache[model] = f
            check(f"synthetic pipeline {model} dummy convergence", 0 if f.converged else 1, 0, f.error)
            for variant in ["ME0", "U9a", "U9b", "U10a", "N3"]:
                error = 0.
                for d in ([0] if variant == "U10a" else [-14, 0, 14]):
                    for minute in ([float(df.minutes.mean())] if model == "M2" else [53, 8]):
                        _, value, gradient = margin_value_gradient(f, df, d, minute, variant)
                        # Performance-square interactions need much smaller raw
                        # coefficient increments than binary indicators.
                        x, _ = evaluation_vectors(f, df, d, minute, variant)
                        scales = np.maximum(1, np.max(abs(x), axis=0))
                        if variant == "U9b":
                            xp, _ = evaluation_vectors(f, df, d+1, minute, "ME0")
                            scales = np.maximum(scales, np.max(abs(xp), axis=0))
                        num = np.empty(len(f.beta))
                        for j in range(len(f.beta)):
                            h = 1e-5/scales[j]
                            delta = np.zeros(len(f.beta)); delta[j] = h
                            a = margin_value_gradient(f, df, d, minute, variant, f.beta+delta)[1]
                            b = margin_value_gradient(f, df, d, minute, variant, f.beta-delta)[1]
                            num[j] = (a-b)/(2*h)
                        error = max(error, float(np.max(abs(num-gradient)/np.maximum(1, abs(gradient)))))
                        # Compare delta SEs as well as gradients.
                        se = np.sqrt(gradient @ f.cov @ gradient)
                        sen = np.sqrt(num @ f.cov @ num)
                        error = max(error, abs(se-sen)/max(1e-5, se))
                check(f"{model} {variant} analytic gradient and delta SE", error, 2e-6)
            for d, variant in [(-14, "ME0"), (14, "ME0"), (0, "ME0"), (0, "U10a")]:
                minute = 23.
                _, effect, _ = margin_value_gradient(f, df, d, minute, variant)
                x, _ = evaluation_vectors(f, df, d, minute, variant)
                h = 1e-5
                if d == 0:
                    sign = -1 if variant == "ME0" else 1
                    xp, _ = evaluation_vectors(f, df, d+sign*h, minute, "ME0")
                    num = ((expit(xp @ f.beta)-expit(x @ f.beta))/(sign*h)).mean()
                else:
                    xp, _ = evaluation_vectors(f, df, d+h, minute, "ME0")
                    xm, _ = evaluation_vectors(f, df, d-h, minute, "ME0")
                    num = ((expit(xp @ f.beta)-expit(xm @ f.beta))/(2*h)).mean()
                check(f"{model} dp/dd d={d} {variant}", abs(effect-num), 2e-6)
        # K1 and K2 test the exact estimator itself on synthetic data.
        from run_all import fit_dataframe, FullRunner, model_tests
        conditional_fits = {}
        for model in ["M1", "M2", "M3"]:
            conditional_fits[model] = fit_dataframe(df, model, ORIGIN)
            check(f"synthetic pipeline {model} exact convergence", 0 if conditional_fits[model].converged else 1, 0)
        for kind, model in [("K1", "M3"), ("K2", "M2")]:
            dd = df.copy()
            if kind == "K1":
                dd["minutes"] = 60-dd.minutes
                refresh_interactions(dd)
            else:
                dd["home_field"] = 1-dd.home_field
            f = fit_dataframe(dd, model, ORIGIN)
            check(kind+" exact likelihood invariance", abs(f.ll-conditional_fits[model].ll), 2e-6)
            if kind == "K2":
                j = f.names.index("home_field")
                check("K2 home coefficient sign", abs(f.beta[j]+conditional_fits[model].beta[j]), 2e-5)
        tests = model_tests(conditional_fits)
        check("nested LR and Wald tests emitted", abs(len(tests)-4), 0)
        # Full-stage output paths exercised on a generated fixture, with one
        # grid cell, all nonequivalent/algebraic branches and selected deletions.
        smoke_dir = results / "synthetic_smoke"
        smoke_dir.mkdir(exist_ok=True)
        runner = FullRunner(smoke_dir)
        sha, _ = id_hash(df)
        runner.grid_cell(1, ORIGIN, ["M1", "M2", "M3"], df, sha)
        runner.grid_cell(3, ORIGIN, ["M1", "M2", "M3"], df, sha)
        runner.additional(df, sha)
        runner.save()
        specs = runner.specs + [r for r in runner.nonequiv+runner.algebra if r.get("record_type") == "spec"]
        bad = [r for r in specs if r["status"] != "ok"]
        check("full-stage synthetic output smoke fits", len(bad), 0,
              "; ".join(str((r.get("run_id"), r.get("model"), r.get("error"))) for r in bad))
        check("duplicate grid cells refitted and flagged", abs(sum(bool(r.get("duplicate_of")) for r in runner.specs if r["step"] == 3)-3), 0)
        # Exercise the entire execution schedule without fitting models. Failed
        # fits must still count as earlier scheduled cells for step-3 repeats.
        from contextlib import redirect_stdout
        from io import StringIO
        from unittest.mock import patch
        schedule_runner = FullRunner(smoke_dir)
        with patch("run_all.fit_dataframe", side_effect=ValueError("schedule-only fixture")), redirect_stdout(StringIO()):
            for step, cell, models in cells():
                schedule_runner.grid_cell(step, cell, models, df, sha)
        scheduled = [r for r in schedule_runner.specs if not r["auxiliary"]]
        auxiliary = [r for r in schedule_runner.specs if r["auxiliary"]]
        expected = [(step, model, cell) for step, cell, models in cells() for model in models]
        actual = [(r["step"], r["model"], {k: r[k] for k in ORIGIN}) for r in scheduled]
        check("execution schedule preserves all 604 fits in order", 0 if actual == expected else 1, 0)
        check("auxiliary fits have separate step and no duplicate flags",
              sum(r["step"] != "auxiliary" or bool(r["duplicate_of"]) or
                  bool(r["duplicate_of_execution_id"]) for r in auxiliary), 0)
        check("step 2 contains only single-axis deviations",
              sum(sum(r[k] != ORIGIN[k] for k in ORIGIN) != 1
                  for r in schedule_runner.specs if r["step"] == 2), 0)
        earlier = {r["spec_id"]: r for r in scheduled if r["step"] in (1, 2)}
        bad_duplicates = 0
        for r in schedule_runner.specs:
            source = earlier.get(r["spec_id"]) if r["step"] == 3 else None
            bad_duplicates += (r["duplicate_of"] != (source["spec_id"] if source else "") or
                               r["duplicate_of_execution_id"] != (source["execution_id"] if source else ""))
        check("duplicate flags reference only scheduled step-1/2 executions", bad_duplicates, 0)
        check("only 27 step-3 fits duplicate earlier scheduled cells",
              abs(sum(bool(r["duplicate_of"]) for r in schedule_runner.specs)-27), 0)
        # Exercise the actual influence writer, selecting generated units only.
        runner.influence_deletions(df, {"team": ["T00"], "season": [2000, 2003], "game": ["G00000"]})
        check("influence writer emits all requested rows", abs(len(runner.influence)-44), 0)
        for unit in ["team", "season", "game"]:
            for model in ["M2", "M3"]:
                rows = [r for r in runner.influence if r["unit_type"] == unit and r["model"] == model]
                for estimator, status, error in [(0, "status", "error"), (1, "benchmark_status", "benchmark_error")]:
                    bad = [r for r in rows if r[status] != "ok"]
                    check(f"{unit} deletion {model} U7={estimator} synthetic fit", len(bad), 0,
                          "; ".join(r[error] for r in bad))
        runner.save()
        # Frozen grid cardinality, inclusion priority and deterministic hashing.
        schedule = list(cells())
        check("grid 604 scheduled fits", abs(sum(len(m) for _, _, m in schedule)-604), 0)
        check("grid 192 crossed cells", abs(sum(s == 3 for s, _, _ in schedule)-192), 0)
        check("ID hash invariant to row ordering", 0 if id_hash(df.sample(frac=1, random_state=1))[0] == sha else 1, 0)
        # Filtering/variable edge cases through the same Samples.prepare path.
        raw = pd.DataFrame([dict(game_id="G", play_id=i, season=2000, season_type="REG", down=4,
                                play_type="run", punt_attempt=0, field_goal_attempt=0,
                                **{"pass": 0}, rush=1, qtr=2, game_seconds_remaining=181,
                                posteam="A", defteam="B", posteam_score=7., defteam_score=3.,
                                ydstogo=2., yardline_100=35., posteam_type="home", week=3)
                            for i in range(12)])
        raw.loc[1, ["play_type", "punt_attempt"]] = ["no_play", 1]  # punt wins over rush
        raw.loc[2, "play_type"] = "no_play"  # rush attempt
        raw.loc[3, ["play_type", "rush"]] = ["no_play", 0]  # unclassified
        raw.loc[4, "play_type"] = "qb_kneel"
        raw.loc[5, "game_seconds_remaining"] = 120
        raw.loc[6, "qtr"] = 5
        raw.loc[7, "posteam"] = ""
        raw.loc[8, "defteam_score"] = np.nan  # M1 available, common sample drops
        raw.loc[9, "play_type"] = "qb_spike"
        raw.loc[10, ["play_type", "rush", "field_goal_attempt"]] = ["no_play", 0, 1]
        raw.loc[11, "play_type"] = "punt"
        ss = Samples.__new__(Samples)
        ss.results = smoke_dir
        (smoke_dir / "samples").mkdir(exist_ok=True)
        ss.reg, ss.fourth = raw, raw
        ss.games = pd.DataFrame([dict(game_id="G", location="Neutral", div_game=1)])
        ss.align = pd.DataFrame([dict(season=2000, team_abbr_pbp=t, conference="AFC", division="AFC East") for t in ["A", "B"]])
        ss.cache, ss.written, ss.flows, ss.index = {}, set(), [], []
        s0 = ss.prepare(ORIGIN)
        check("sample origin edge-case ID selection", 0 if set(s0[0].play_id) == {0, 11} else 1, 0)
        check("model-specific versus common complete cases", abs(s0[3]["M1"]-3)+abs(s0[3]["M2"]-2)+abs(s0[4]-1), 0)
        allc = ORIGIN | {"U1": 1, "U2": 1, "U3": 1, "U4": 1, "U5": 1, "U6": 1}
        sa = ss.prepare(allc)[0].set_index("play_id")
        check("expanded decision/boundary sample IDs", 0 if set(sa.index) == {0, 1, 2, 4, 5, 9, 10, 11} else 1, 0)
        check("no_play non-attempt flag priority and classifications", abs(sa.loc[1, "y"])+abs(sa.loc[2, "y"]-1)+abs(sa.loc[10, "y"]), 0)
        check("kneel and spike are non-attempts", abs(sa.loc[4, "y"])+abs(sa.loc[9, "y"]), 0)
        check("minutes floor and terminal inclusive boundary", abs(sa.loc[0, "minutes"]-3)+abs(sa.loc[5, "minutes"]-2), 0)
        check("exclusive conference and neutral home coding", abs(sa.same_conference).sum()+abs(sa.home_field).sum(), 0)
        check("pre-play score reference and own total_points", abs(sa.loc[0, "d"]-3)+abs(sa.loc[0, "total_points"]-7), 0)
        check("team-season estimator has no season regressors", len([n for n in design(df, "M3", ORIGIN | {"U7": 2})[3] if n.startswith("season_")]), 0)
        # Deliberately broken join must abort rather than silently lose rows.
        ss.cache = {}
        ss.games = ss.games.iloc[:0]
        raised = False
        try:
            ss.prepare(ORIGIN)
        except ValueError as exc:
            raised = "Unmatched games merge" in str(exc)
        check("unmatched games join stops sample construction", 0 if raised else 1, 0)
    except Exception as exc:
        import traceback
        records.append(("Unexpected synthetic check exception", False, 1., 0., traceback.format_exc()))
        print(traceback.format_exc(), flush=True)
    finally:
        passed = sum(r[1] for r in records)
        lines = ["# Synthetic checks", "", "Generated inputs only; no empirical model was fitted.", "",
                 "Seed: 20261027 (fixture seed: 816). Recovery uses a pre-set four-standard-error tolerance.", "",
                 f"Result: {passed}/{len(records)} checks passed.",
                 f"Elapsed seconds: {time.monotonic()-started:.3f}.", "",
                 "| Check | Result | Error | Tolerance |", "|---|---|---:|---:|"]
        for name, ok, error, tol, detail in records:
            lines.append(f"| {name} | {'PASS' if ok else 'FAIL'} | {error:.8g} | {tol:.8g} |")
        lines += ["", "## Parameter recovery", "", "| Estimator | Term | Truth | Estimate | Native SE | Absolute error / SE |",
                  "|---|---|---:|---:|---:|---:|"]
        for r in recovery:
            lines.append(f"| {r['estimator']} | {r['term']} | {r['truth']:.6g} | {r['estimate']:.6g} | {r['se']:.6g} | {r['error_se']:.6g} |")
        for name, ok, _, _, detail in records:
            if detail:
                lines += ["", f"{name}: {detail}"]
        lines += ["", "The synthetic_smoke/ tables exercise full-stage output formats using generated",
                  "data; they are not empirical results. Covariance and margin checks use independent",
                  "numerical derivatives. Exact-likelihood checks include exhaustive enumeration,",
                  "statsmodels comparisons, and independent log-domain dynamic programming.", ""]
        (results / "synthetic_checks.md").write_text("\n".join(lines))
    if not all(r[1] for r in records):
        raise AssertionError("Synthetic checks failed; see results/synthetic_checks.md")
