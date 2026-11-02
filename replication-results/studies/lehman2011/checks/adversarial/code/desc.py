import sys, pathlib, tempfile
C = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(C/'code'))
import samples as S
import numpy as np, pandas as pd
tmp = pathlib.Path(tempfile.mkdtemp()); (tmp/'samples').mkdir()
ss = S.Samples(C, tmp)
out, sha, flow, counts, dropped, dis = ss.prepare(S.ORIGIN.copy())
print('N', len(out), 'sha', sha[:12], 'div disagreements', dis)
print(out[['same_division','same_conference','home_field','week','minutes','total_points','yards_first_down','yards_touchdown','y']].describe().T[['mean','std']])
print('corr div/conf', out.same_division.corr(out.same_conference))
print('P(div=1,conf=0)', ((out.same_division==1)&(out.same_conference==0)).mean())
print(out.groupby('season')[['same_division','same_conference']].mean())
out.to_parquet(sys.argv[2])
