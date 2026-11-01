# Pre-unsealing adversarial diagnostic: Table 2 ownership rows. Summary stats of every quarterly.csv column on the balanced panel.
import pandas as pd, numpy as np, sys
D='data/derived/run_input_v1/'
q=pd.read_csv(D+'quarterly.csv',sep='\t',dtype=str)
q=q[q.geoid!='geoid']; q=q[q.quarter.notna() & (q.quarter!='')]
cols=[c for c in q.columns if c not in('geoid','quarter')]
for c in cols: q[c]=pd.to_numeric(q[c])
q['fips']=q.geoid.astype(int)
cl=pd.read_csv(D+'county_lookup.csv')
U=cl[cl.STATE_NAME!='Massachusetts'][['FIPS','treat']].rename(columns={'FIPS':'fips'})
qs=[f'{y}q{k}' for y in range(2005,2015) for k in range(1,5)][1:]
pan=pd.MultiIndex.from_product([U.fips,qs],names=['fips','quarter']).to_frame(index=False)
pan=pan.merge(q.drop(columns='geoid'),on=['fips','quarter'],how='left').fillna(0)
print('panel rows',len(pan))
out=[]
for c in cols:
    s=pan[c]; out.append((c,round(s.mean(),3),round(s.std(),2),s.median(),s.min(),s.max()))
pan['f5m1']=pan.totaloldfocused5-pan.totaloldfocused1
pan['active_minus_f1']=pan.totaloldusers_active-pan.totaloldfocused1
for c in ['f5m1','active_minus_f1']:
    s=pan[c]; out.append((c,round(s.mean(),3),round(s.std(),2),s.median(),s.min(),s.max()))
print(pd.DataFrame(out,columns=['col','mean','sd','median','min','max']).to_string())
print('published T2 Low Ownership: 2.00 87.47 0 0 20595 ; High Ownership: 123.52 6411.82 0 0 1268382; Owner 171.42 5729.41 1 0 1695215; Old Contributors 0.10 1.14 0 0 293')
# raw (unbalanced) file maxima for comparison
print('raw file maxima (all rows, all counties):'); print(q[cols].max().to_string())
