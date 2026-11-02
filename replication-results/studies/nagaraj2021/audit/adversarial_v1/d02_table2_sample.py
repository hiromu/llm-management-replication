# Pre-unsealing adversarial diagnostic: where is the published High Ownership max (1,268,382) and what sample reproduces Table 2?
import pandas as pd, numpy as np
D='data/derived/run_input_v1/'
q=pd.read_csv(D+'quarterly.csv',sep='\t',dtype=str)
q=q[q.geoid!='geoid']; q=q[q.quarter.notna() & (q.quarter!='')]
cols=[c for c in q.columns if c not in('geoid','quarter')]
for c in cols: q[c]=pd.to_numeric(q[c])
q['fips']=q.geoid.astype(int)
cl=pd.read_csv(D+'county_lookup.csv')
print(q[q.totaloldfocused5>=1061012][['fips','quarter','totaloldfocused5','totaloldfocused1','totalcontrib','totalowneredit']])
r=q[q.totaloldfocused5==1268382]
print('row in county_lookup?', cl[cl.FIPS.isin(r.fips)][['FIPS','STATE_NAME','treat']].to_dict('records'))
print('quarters present in file:', sorted(q.quarter.unique()))
# rows outside U
U=set(cl[cl.STATE_NAME!='Massachusetts'].FIPS)
out=q[~q.fips.isin(U)]
print('rows outside U:',len(out),'distinct counties',out.fips.nunique())
print('MA rows:', q[q.fips.isin(set(cl[cl.STATE_NAME=='Massachusetts'].FIPS))].shape[0])
print('outside-U fips sample (state part):', sorted(set(out.fips//1000)))
# Unbalanced (present rows only) stats in U and in all rows
def st(df,label):
    print(label, 'n=',len(df))
    for c in ['totalcontrib','totaloldfocused1','totaloldfocused5','totalowneredit','totalusers','totaloldusers_active']:
        s=df[c]; print('  %-22s mean %.3f sd %.2f med %.1f max %d'%(c,s.mean(),s.std(),s.median(),s.max()))
st(q,'all file rows (incl. outside U, both 2005 quarters)')
st(q[q.fips.isin(U)],'present rows in U')
