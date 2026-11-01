# Pre-unsealing adversarial diagnostic: Table 2 summary stats under alternative panel samples (diagnostic only; not frozen readings).
import pandas as pd, numpy as np
D='data/derived/run_input_v1/'
q=pd.read_csv(D+'quarterly.csv',sep='\t',dtype=str)
q=q[q.geoid!='geoid']; q=q[q.quarter.notna() & (q.quarter!='')]
cols=[c for c in q.columns if c not in('geoid','quarter')]
for c in cols: q[c]=pd.to_numeric(q[c])
q['fips']=q.geoid.astype(int); q=q.drop(columns='geoid')
cl=pd.read_csv(D+'county_lookup.csv')
qs=[f'{y}q{k}' for y in range(2005,2015) for k in range(1,5)][1:]
def bal(fipsset,quarters=qs):
    pan=pd.MultiIndex.from_product([sorted(fipsset),quarters],names=['fips','quarter']).to_frame(index=False)
    return pan.merge(q,on=['fips','quarter'],how='left').fillna(0)
U=set(cl[cl.STATE_NAME!='Massachusetts'].FIPS); ALL=set(cl.FIPS); FILE=set(q.fips)
samples={'U balanced (frozen)':bal(U),'county_lookup incl MA balanced':bal(ALL),'all file counties balanced':bal(FILE|ALL),
 'U balanced, 38 file quarters':bal(U,sorted(q.quarter.unique()))}
pub={'totalcontrib':2867.80,'totaloldfocused1':2.00,'totaloldfocused5':123.52,'totalowneredit':171.42,'totalusers':7.68,'totalnewusers':4.77,'totaloldusers_active':0.10,'totaltagb':120.21,'totaltagh':366.00}
for k,p in samples.items():
    print(k,'rows',len(p),'counties',p.fips.nunique())
    for c,v in pub.items():
        s=p[c]; print('   %-22s mean %10.3f (pub %8.2f) sd %10.2f max %d'%(c,s.mean(),v,s.std(),s.max()))
