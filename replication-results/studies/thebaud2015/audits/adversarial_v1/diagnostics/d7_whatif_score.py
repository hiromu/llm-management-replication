"""POST-HOC what-if scoring. Runs the frozen scorer checks/score.py unchanged on
relabelled copies of deviation rows and post-hoc refit rows. Output is diagnostic
only; it does not replace or change any frozen score."""
import os, subprocess, pandas as pd
S = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
D = os.path.join(S, 'audits/adversarial_v1/diagnostics')
dev = pd.read_csv(os.path.join(S, 'runs/exec_v1/DEV_A_combined.csv'), dtype={'deleted_country': str})
post = pd.concat([pd.read_csv(os.path.join(D, f), dtype={'deleted_country': str})
                  for f in ['d4_refits_p1.csv', 'd4_refits_p2.csv', 'd10_leave_alt_p1.csv', 'd10_leave_alt_p2.csv'] if os.path.exists(os.path.join(D, f))])
sets = {'U14': dev[dev.run_id == 'U14'], 'U09': dev[dev.run_id == 'U09']}
for rid in post.run_id.unique():
    sets[rid.replace('POSTHOC_', 'PH_')] = post[post.run_id == rid]
rows = []
for name, df in sets.items():
    df = df.copy(); df['run_id'] = 'ORIGIN'
    wd = os.path.join(D, 'whatif', name); os.makedirs(wd, exist_ok=True)
    df.to_csv(os.path.join(wd, 'rows.csv'), index=False)
    subprocess.run(['~/.venv/bin/python', os.path.join(S, 'checks/score.py'),
                    os.path.join(wd, 'rows.csv'), '', '', wd], check=True, capture_output=True)
    t = pd.read_csv(os.path.join(wd, 'term_scores.csv'))
    t = t[(t.status == 'ok') & t.term.str.contains('female')]
    t.insert(0, 'whatif_set', name)
    rows.append(t)
out = pd.concat(rows)
cols = ['whatif_set', 'model', 'term', 'pub_value', 'pub_se', 'pub_stars', 'rec_value', 'rec_se', 'rec_p', 'n_rec', 'n_pub',
        'n_status', 'distance_pub_se', 'magnitude', 'inference', 'sign', 'outcome']
out[cols].to_csv(os.path.join(D, 'd7_whatif_term_scores.csv'), index=False)
pd.set_option('display.width', 250); pd.set_option('display.max_rows', 300)
print(out[cols].round(4).to_string(index=False))
