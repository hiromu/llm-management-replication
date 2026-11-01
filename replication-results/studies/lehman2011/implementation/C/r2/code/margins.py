"""Analytic gradients for all frozen marginal-effect variants."""
import numpy as np
from scipy.special import expit
from scipy.stats import norm


def evaluation_vectors(fit, df, d, minutes, variant="ME0"):
    names = fit.names
    if variant == "N3":
        x = np.column_stack([df[n].to_numpy(float) if n in df else np.zeros(len(df)) for n in names])
    else:
        x = np.array([[df[n].mean() if n in df else 0. for n in names]])
    for j, name in enumerate(names):
        if name == "intercept" or name.startswith("team_") or name == "log_sigma_team":
            x[:, j] = 0
    if variant == "U9a":
        teams = sorted(df.posteam.unique())
        x = np.repeat(x, len(teams), axis=0)
        x[:, names.index("intercept")] = 1
        for i, team in enumerate(teams):
            if "team_"+team in names:
                x[i, names.index("team_"+team)] = 1
    is_m3 = "perf_below_x_min" in names
    if not (variant == "N3" and not is_m3):
        x[:, names.index("minutes")] = minutes
    below = d <= 0 and variant != "U10a"
    vals = {"perf_below": d if below else 0., "perf_below_sq": d*d if below else 0.,
            "perf_above": 0. if below else d, "below_indicator": float(below)}
    slopes = {"perf_below": float(below), "perf_below_sq": 2*d if below else 0.,
              "perf_above": float(not below)}
    v = np.zeros_like(x)
    for name, value in vals.items():
        x[:, names.index(name)] = value
    for name, slope in slopes.items():
        v[:, names.index(name)] = slope
        if is_m3:
            j = names.index(name+"_x_min")
            x[:, j] = vals[name]*minutes
            v[:, j] = slope*minutes
    return x, v


def margin_value_gradient(fit, df, d, minutes, variant="ME0", beta=None):
    b = fit.beta if beta is None else beta
    x, v = evaluation_vectors(fit, df, d, minutes, variant)
    p = expit(x @ b)
    w = p*(1-p)
    if variant == "U9b":
        xp, _ = evaluation_vectors(fit, df, d+1, minutes, "ME0")
        pp = expit(xp @ b)
        return float(p.mean()), float((pp-p).mean()), (pp[:, None]*(1-pp[:, None])*xp-w[:, None]*x).mean(axis=0)
    slope = v @ b
    grad = w[:, None]*v + (w*(1-2*p)*slope)[:, None]*x
    return float(p.mean()), float((w*slope).mean()), grad.mean(axis=0)


def delta(effect, grad, cov):
    var = float(grad @ cov @ grad)
    if var < -1e-12:
        raise FloatingPointError("Negative delta variance")
    se = np.sqrt(max(0, var))
    z = effect/se if se else (0. if effect == 0 else np.sign(effect)*np.inf)
    return float(se), float(z), float(2*norm.sf(abs(z)))


def margins(fit, df, model, variants, quarters=False):
    times = [4, 3, 2, 1] if quarters else [53, 38, 23, 8]
    if model == "M2":
        times = [float(df.minutes.mean())]
    rows = []
    for variant in variants:
        for minutes in times:
            for d in ([0] if variant == "U10a" else [-42, -28, -14, 0, 14, 28, 42]):
                prob, effect, grad = margin_value_gradient(fit, df, d, minutes, variant)
                se, z, p = delta(effect, grad, fit.cov)
                row = dict(model=model, variant=variant, minutes_eval=minutes, d=d,
                           prob=prob, effect=effect, se_native=se, z_native=z, p_native=p,
                           se_bench=None, p_bench=None,
                           time_variable="quarters_remaining" if quarters else "minutes")
                if fit.bench is not None and variant != "U9a":
                    row["se_bench"], _, row["p_bench"] = delta(effect, grad, fit.bench)
                rows.append(row)
    return rows
