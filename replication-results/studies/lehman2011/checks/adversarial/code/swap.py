import sys, json, math, pandas as pd
root = sys.argv[1]
sys.path.insert(0, root + '/runs/scorer')
from score_v1 import compare_target
T = json.load(open(root + '/sealed/targets_reconciled_v1.json'))['targets']
d = pd.read_csv(root + '/runs/score_v1/target_comparisons_all_cells.csv')
o = d[d.cell == 'U1=0|U2=0|U3=0|U4=0|U5=0|U6=0|U7=0|U8=0'].set_index('key')
rows = []
for m in ['M1', 'M2', 'M3']:
    for lab, other in [('same_division', 'same_conference'), ('same_conference', 'same_division')]:
        k = f'T5|{m}|{lab}'; ko = f'T5|{m}|{other}'
        est, p = o.loc[k, 'reconstructed'], o.loc[k, 'p_native']
        for reading, tk in [('as_printed', k), ('swapped', ko)]:
            r = compare_target(T[tk], est, p)
            rows.append(dict(model=m, reconstructed_var=lab, reading=reading, pub_row=tk.split('|')[2],
                             pub_or=T[tk]['value'], pub_se=T[tk]['published_se'], rec_logor=round(est, 5),
                             rec_or=round(math.exp(est), 4), p_native=round(p, 4), sign=r['sign'],
                             inference=r['inference'], delta_se=round(r['delta_se'], 3),
                             magnitude=r['magnitude'], outcome=r['outcome']))
df = pd.DataFrame(rows)
pd.set_option('display.width', 250)
print(df.to_string())
df.to_csv(sys.argv[2], index=False)
