# Pre-unsealing adversarial diagnostic: Table 1 change-in-control rows. Deposit ACS coverage, units, and group means by acsyear.
import pandas as pd, numpy as np
from scipy import stats
D='data/derived/run_input_v1/'
a=pd.read_stata(D+'acs5year.dta')
r=pd.io.stata.StataReader(D+'acs5year.dta'); lab=r.variable_labels(); r.close()
print('variable labels:',lab)
print('acsyear counts:',a.acsyear.value_counts().sort_index().to_dict())
ctr=['population','households','unemploymentrate','popeduc','popmales','popyoungmales','income_percapita','popdensity']
print('non-missing by year:'); print(a.groupby('acsyear')[ctr].count().to_string())
print('unemploymentrate column quantiles (2011):',a[a.acsyear==2011].unemploymentrate.describe().round(2).to_dict())
cl=pd.read_csv(D+'county_lookup.csv'); U=cl[cl.STATE_NAME!='Massachusetts'][['FIPS','treat']]
m=U.merge(a,left_on='FIPS',right_on='geo_fips',how='left')
print('group means by acsyear:')
g=m.groupby(['acsyear','treat'])[ctr].mean().round(1); print(g.to_string())
w=m.pivot_table(index='FIPS',columns='acsyear',values=ctr)
T=U.set_index('FIPS').treat
pub={'population':(7324.3,6756.5),'households':(2186.4,1899.8),'unemploymentrate':(-646.1,-543.6),'popeduc':(1995.9,1884.8),'popyoungmales':(555.3,410.5),'popmales':(555.3,410.5),'income_percapita':(3152.7,2773.7)}
print('\nchange 2005->Y by group (treated, control) vs published 2014-2005:')
for v,(pt,pc) in pub.items():
    for y in range(2006,2012):
        dlt=(w[(v,y)]-w[(v,2005)])
        t_,c_=dlt[T==1].mean(),dlt[T==0].mean()
        print('  %-18s 2005->%d  T %9.1f C %9.1f  | x(9/%d) T %9.1f C %9.1f | pub T %8.1f C %8.1f'%(v,y,t_,c_,y-2005,t_*9/(y-2005),c_*9/(y-2005),pt,pc))
# linear-trend extrapolation to 2014 per county (diagnostic only; not a frozen reading)
print('\nper-county OLS trend 2005-2011 extrapolated to 2014 minus 2005 fitted (diagnostic):')
yrs=np.arange(2005,2012)
for v,(pt,pc) in pub.items():
    X=w[v][yrs]
    ok=X.notna().all(axis=1)
    slope=X[ok].apply(lambda r: np.polyfit(yrs,r.values,1)[0],axis=1)
    ch=slope*9
    print('  %-18s T %9.1f C %9.1f diff %8.1f | pub T %8.1f C %8.1f diff %7.1f'%(v,ch[T[ok]==1].mean(),ch[T[ok]==0].mean(),ch[T[ok]==1].mean()-ch[T[ok]==0].mean(),pt,pc,pt-pc))
