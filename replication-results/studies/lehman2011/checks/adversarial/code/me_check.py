import sys, json, numpy as np, pandas as pd
from scipy.special import expit
root = sys.argv[1]
df = pd.read_parquet('origin.parquet')
c = pd.read_csv(root + '/runs/exec_v1/C/results/coefs.csv')
O = 'U1=0|U2=0|U3=0|U4=0|U5=0|U6=0|U7=0|U8=0'
def coefs(model, u7):
    x = c[c.spec_id == model + '|' + O.replace('U7=0', f'U7={u7}')].drop_duplicates('term')
    return dict(zip(x.term, x.estimate))
T = json.load(open(root + '/sealed/targets_reconciled_v1.json'))['targets']
def me(b, d, m, conv):
    names = [k for k in b if k not in ('intercept',) and not k.startswith('team_')]
    xb = 0.0
    for n in names:
        if n.startswith('perf') or n == 'below_indicator' or n == 'minutes':
            continue
        xb += b[n] * df[n].mean()
    below = d <= 0
    pb, psq, pa = (d, d * d, 0.) if below else (0., 0., d)
    xb += b['perf_below'] * pb + b['perf_below_sq'] * psq + b['perf_above'] * pa + b['below_indicator'] * float(below)
    xb += b['minutes'] * m
    slope = (b['perf_below'] + 2 * d * b['perf_below_sq']) if below else b['perf_above']
    if 'perf_below_x_min' in b:
        xb += m * (b['perf_below_x_min'] * pb + b['perf_below_sq_x_min'] * psq + b['perf_above_x_min'] * pa)
        slope += m * ((b['perf_below_x_min'] + 2 * d * b['perf_below_sq_x_min']) if below else b['perf_above_x_min'])
    if conv == 'ME0':
        a = np.array([0.])
    else:
        teams = [0.] + [v for k, v in b.items() if k.startswith('team_')]
        a = b['intercept'] + np.array(teams)
    p = expit(xb + a)
    return float((p * (1 - p) * slope).mean()), float(p.mean())
mbar = df.minutes.mean()
rows = []
for d in [-42, -28, -14, 0, 14, 28, 42]:
    pub = float(T[f'T6|all|gap{d}']['value'])
    r = dict(d=d, pub_all=pub)
    r['M2_ME0'], _ = me(coefs('M2', 0), d, mbar, 'ME0')
    r['M2_U9a'], _ = me(coefs('M2', 1), d, mbar, 'U9a')
    r['M3_at_mean_min_ME0'], _ = me(coefs('M3', 0), d, mbar, 'ME0')
    r['M3_at_mean_min_U9a'], _ = me(coefs('M3', 1), d, mbar, 'U9a')
    rows.append(r)
out = pd.DataFrame(rows)
pd.set_option('display.width', 200)
print('mean minutes', mbar)
print(out.round(5).to_string())
b2 = coefs('M2', 1); print('M2 U7=1 intercept', b2['intercept'], 'mean team', np.mean([0.] + [v for k, v in b2.items() if k.startswith('team_')]))
b3 = coefs('M3', 1); print('M3 U7=1 intercept', b3['intercept'], 'mean team', np.mean([0.] + [v for k, v in b3.items() if k.startswith('team_')]))
# check reproduction of frozen U9a for one q4 cell
print('check q4 gap0 U9a', me(coefs('M3', 1), 0, 8, 'U9a'), 'ME0', me(coefs('M3', 0), 0, 8, 'ME0'))
out.to_csv(sys.argv[2], index=False)
