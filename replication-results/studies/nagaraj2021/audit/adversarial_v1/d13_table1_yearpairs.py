# Pre-unsealing adversarial diagnostic: Table 1 change rows under every deposit acsyear pair (a<b). Diagnostic only:
# the article defines the change as 2014 minus 2005, which the deposit (acsyear 2005-2011) cannot supply.
import pandas as pd, numpy as np, itertools
D='data/derived/run_input_v1/'
a=pd.read_stata(D+'acs5year.dta')
cl=pd.read_csv(D+'county_lookup.csv'); U=cl[cl.STATE_NAME!='Massachusetts'][['FIPS','treat']]
m=U.merge(a,left_on='FIPS',right_on='geo_fips')
pub={'population':(7324.3,6756.5),'households':(2186.4,1899.8),'unemploymentrate':(-646.1,-543.6),'popeduc':(1995.9,1884.8),'popyoungmales':(555.3,410.5),'popmales':(555.3,410.5),'income_percapita':(3152.7,2773.7)}
w=m.pivot_table(index='FIPS',columns='acsyear',values=list(pub)); T=U.set_index('FIPS').treat
rows=[]
for v,(pt,pc) in pub.items():
    for y0,y1 in itertools.combinations(range(2005,2012),2):
        dl=w[(v,y1)]-w[(v,y0)]; t_=dl[T==1].mean(); c_=dl[T==0].mean()
        rows.append((v,y0,y1,t_,c_,max(abs(t_-pt)/abs(pt),abs(c_-pc)/abs(pc))))
R=pd.DataFrame(rows,columns=['var','y0','y1','T','C','max_rel_dev'])
print('best pair per variable (smallest max relative deviation of group means):')
print(R.sort_values('max_rel_dev').groupby('var').head(2).sort_values(['var','max_rel_dev']).round(3).to_string(index=False))
print('pairs with max_rel_dev<=0.10 for ALL six rows (popyoungmales as male 18-45):')
six=['population','households','unemploymentrate','popeduc','popyoungmales','income_percapita']
ok=R[R['var'].isin(six)].groupby(['y0','y1']).max_rel_dev.max().sort_values()
print(ok.head(5).round(3).to_string())
R.to_csv('audit/adversarial_v1/d13_table1_yearpairs.csv',index=False)
