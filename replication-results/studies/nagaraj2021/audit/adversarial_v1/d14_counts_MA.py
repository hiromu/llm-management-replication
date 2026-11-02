# Pre-unsealing adversarial diagnostic: Figure 1/2 county counts when the 14 Massachusetts counties are in the universe.
import pandas as pd, numpy as np
D='data/derived/run_input_v1/'
cl=pd.read_csv(D+'county_lookup.csv')
b=pd.read_csv(D+'boundary-counties.csv'); b.columns=['src','nb']
nb={int(s):{int(x) for x in str(l).split(';') if x.strip()} - {int(s)} for s,l in zip(b.src,b.nb) if not pd.isna(l)}
t=pd.read_excel(D+'timing.xlsx'); t['yr']=t['Sch SB Delivery'].dt.year
for scen in ['frozen U (no MA)','MA as treated (lookup coding)','MA as control']:
    u=cl.copy()
    if scen.startswith('frozen'): u=u[u.STATE_NAME!='Massachusetts']
    if scen=='MA as control': u.loc[u.STATE_NAME=='Massachusetts','treat']=0
    tr=dict(zip(u.FIPS,u.treat))
    B=[c for c in tr if any(n in tr and tr[n]!=tr[c] for n in nb.get(c,()))]
    TS=set(t[t.yr.isin([2005,2006])].FIPS)&set(tr)
    f=lambda S:(sum(tr[c]==1 for c in S),sum(tr[c]==0 for c in S),len(S))
    print('%-32s full T/C/all %s  boundary %s  timing %s'%(scen,f(list(tr)),f(B),f(TS)))
print('published: Figure 1 1851/1256/3107; text boundary 1096/724/1820, timing 1228/990/2218; Table 1 header 1851/1242')
