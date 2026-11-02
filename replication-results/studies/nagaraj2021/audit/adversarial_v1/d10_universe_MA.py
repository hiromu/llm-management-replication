# Pre-unsealing adversarial diagnostic: does the published 3,107-county universe equal the 3,093 non-MA counties plus the
# 14 Massachusetts counties counted as controls? Table 1 outcome means and Table 2 means under that hypothesis.
import pandas as pd, numpy as np
from scipy import stats
D='data/derived/run_input_v1/'
q=pd.read_csv(D+'quarterly.csv',sep='\t',dtype=str)
q=q[q.geoid!='geoid']; q=q[q.quarter.notna() & (q.quarter!='')]
cols=[c for c in q.columns if c not in('geoid','quarter')]
for c in cols: q[c]=pd.to_numeric(q[c])
q['fips']=q.geoid.astype(int); q=q.drop(columns='geoid')
cl=pd.read_csv(D+'county_lookup.csv')
qs=[f'{y}q{k}' for y in range(2005,2015) for k in range(1,5)][1:]
def bal(f):
    pan=pd.MultiIndex.from_product([sorted(f),qs],names=['fips','quarter']).to_frame(index=False)
    return pan.merge(q,on=['fips','quarter'],how='left').fillna(0)
cl['treat_MAasC']=np.where(cl.STATE_NAME=='Massachusetts',0,cl.treat)
p=bal(set(cl.FIPS)).merge(cl[['FIPS','treat','treat_MAasC','STATE_NAME']].rename(columns={'FIPS':'fips'}),on='fips')
p['followon']=p.totaltaga+p.totaltagb+p.totaltagh
pub={'totalcontrib':(2375.5,3593.3),'followon':(457.9,635.5),'totalusers':(7.482,7.966),'totalowneredit':(149.6,203.6)}
for lab,tcol,sub in [('frozen U (MA excluded)','treat',p.STATE_NAME!='Massachusetts'),('MA included as controls','treat_MAasC',slice(None)),('MA included as treated (lookup coding)','treat',slice(None))]:
    s=p[sub]; cm=s.groupby('fips').agg({**{v:'mean' for v in pub},tcol:'first'})
    print(lab,'counties T',(cm[tcol]==1).sum(),'C',(cm[tcol]==0).sum())
    for v,(pt,pc) in pub.items():
        t_=cm[cm[tcol]==1][v]; c_=cm[cm[tcol]==0][v]
        print('   %-15s T %9.3f C %9.3f  diff %9.3f  p(eq var) %.3f | pub T %s C %s'%(v,t_.mean(),c_.mean(),t_.mean()-c_.mean(),stats.ttest_ind(t_,c_).pvalue,pt,pc))
