# Pre-unsealing adversarial diagnostic: which Sch SB Delivery windows (if any) give the published timing counts?
# Exploratory search only; not a frozen reading and cannot change scores.
import pandas as pd, numpy as np
D='data/derived/run_input_v1/'
cl=pd.read_csv(D+'county_lookup.csv')
t=pd.read_excel(D+'timing.xlsx')
for label,univ in [('U (non-MA)',cl[cl.STATE_NAME!='Massachusetts']),('all county_lookup',cl)]:
    m=univ[['FIPS','treat']].merge(t[['FIPS','Sch SB Delivery']],on='FIPS',how='left')
    d=m['Sch SB Delivery']
    months=pd.date_range('2001-01-01','2008-12-01',freq='MS')
    print('==',label)
    print('monthly counts by treat (nonzero):')
    tab=pd.crosstab(d.dt.to_period('M'),m.treat); print(tab.to_string())
    best=[]
    for a in months:
        for b in months:
            if b<=a: continue
            s=m[(d>=a)&(d<b)]
            T=(s.treat==1).sum(); C=(s.treat==0).sum()
            for tgt in [(1096,724),(1228,990)]:
                err=abs(T-tgt[0])+abs(C-tgt[1])
                best.append((err,tgt,str(a.date()),str(b.date()),T,C))
    best.sort()
    for r in best[:12]: print(r)
