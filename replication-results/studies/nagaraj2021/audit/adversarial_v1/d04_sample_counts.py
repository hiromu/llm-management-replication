# Pre-unsealing adversarial diagnostic: Figure 1 / Figure 2 county counts under frozen and alternative textual readings.
import pandas as pd, numpy as np
D='data/derived/run_input_v1/'
cl=pd.read_csv(D+'county_lookup.csv')
print('county_lookup rows',len(cl),'MA rows',(cl.STATE_NAME=='Massachusetts').sum(),'MA treat counts',cl[cl.STATE_NAME=='Massachusetts'].treat.value_counts().to_dict())
U=cl[cl.STATE_NAME!='Massachusetts'][['FIPS','treat']].rename(columns={'FIPS':'fips'})
print('U treat counts',U.treat.value_counts().to_dict(),'n',len(U))
print('incl MA treat counts',cl.treat.value_counts().to_dict())
# timing
t=pd.read_excel(D+'timing.xlsx')
t['yr']=t['Sch SB Delivery'].dt.year
m=U.merge(t[['FIPS','yr','SB Selected','Thread','Sch SB Delivery']].rename(columns={'FIPS':'fips'}),on='fips',how='left')
print('U counties not in timing file:',m.yr.isna().sum())
print('crosstab delivery year x treat (U):'); print(pd.crosstab(m.yr.fillna(0).astype(int),m.treat,margins=True))
print('crosstab SB Selected x treat:'); print(pd.crosstab(m['SB Selected'].fillna('NA'),m.treat,margins=True))
print('crosstab Thread x treat:'); print(pd.crosstab(m['Thread'].fillna(-1),m.treat,margins=True))
# Alternative windows (diagnostic): published timing 2218 (1228 T, 990 C) or 1820 (1096 T, 724 C)
def cnt(mask,label):
    s=m[mask]; print('%-55s T %4d C %4d all %4d'%(label,(s.treat==1).sum(),(s.treat==0).sum(),len(s)))
d=m['Sch SB Delivery']
cnt(m.yr.isin([2005,2006]),'frozen: year in 2005-2006')
cnt((d>='2005-01-01')&(d<'2007-01-01'),'same')
cnt((d>='2004-07-01')&(d<'2006-07-01'),'mid-2004..mid-2006')
cnt((d>='2004-01-01')&(d<'2007-01-01'),'2004-2006')
cnt((d>='2005-01-01')&(d<'2008-01-01'),'2005-2007')
cnt((d>='2004-01-01')&(d<'2006-01-01'),'2004-2005')
cnt((d>='2006-01-01')&(d<'2008-01-01'),'2006-2007')
cnt((d>='2005-01-01')&(d<='2006-12-31')|m.yr.isna(),'2005-2006 or missing')
# Boundary
b=pd.read_csv(D+'boundary-counties.csv'); b.columns=['src','nb']
tr=dict(zip(U.fips,U.treat))
nb={}
for s,l in zip(b.src,b.nb):
    if pd.isna(l): continue
    nb.setdefault(int(s),set()).update(int(x) for x in str(l).split(';') if x.strip()!='' and int(x)!=int(s))
def B1(trmap,univ):
    keep=[c for c in univ if any((n in trmap) and trmap[n]!=trmap[c] for n in nb.get(c,()))]
    return keep
k=B1(tr,list(U.fips)); kk=pd.Series([tr[c] for c in k])
print('B1 boundary: T',(kk==1).sum(),'C',(kk==0).sum(),'all',len(k))
# symmetric closure of adjacency
nbs={}
for s,ns in nb.items():
    for n in ns: nbs.setdefault(s,set()).add(n); nbs.setdefault(n,set()).add(s)
k2=[c for c in U.fips if any((n in tr) and tr[n]!=tr[c] for n in nbs.get(c,()))]; kk=pd.Series([tr[c] for c in k2])
print('B1 symmetric-closure: T',(kk==1).sum(),'C',(kk==0).sum(),'all',len(k2))
print('U counties absent from boundary file as source:',sum(1 for c in U.fips if c not in nb))
# Text reading: drop counties "completely surrounded by others of only one type" -> could mean surrounded by own type
# Alternative: counties whose neighbours are ALL of the opposite type are kept too (already in B1). Alternative: keep if NOT all neighbours same type as each other
k3=[c for c in U.fips if len({tr[n] for n in nb.get(c,()) if n in tr})!=1 or any(tr[n]!=tr[c] for n in nb.get(c,()) if n in tr)]
kk=pd.Series([tr[c] for c in k3]); print('Alt: drop only counties whose neighbours are all of a single type equal to own: T',(kk==1).sum(),'C',(kk==0).sum(),'all',len(k3))
k4=[c for c in U.fips if len({tr[n] for n in nb.get(c,()) if n in tr})>1]
kk=pd.Series([tr[c] for c in k4]); print('Alt literal: keep counties whose neighbours include both types: T',(kk==1).sum(),'C',(kk==0).sum(),'all',len(k4))
# B1 within timing sample, timing within boundary
tim=set(m[m.yr.isin([2005,2006])].fips)
k5=[c for c in k if c in tim]; kk=pd.Series([tr[c] for c in k5]); print('boundary AND timing: T',(kk==1).sum(),'C',(kk==0).sum(),'all',len(k5))
