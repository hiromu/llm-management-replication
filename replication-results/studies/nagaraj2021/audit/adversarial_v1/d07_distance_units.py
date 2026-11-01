# Pre-unsealing adversarial diagnostic: distance.csv units, pair counts, raw treat differences.
import pandas as pd, numpy as np
D='data/derived/run_input_v1/'
d=pd.read_csv(D+'distance.csv',sep='\t')
print('rows',len(d),'cols',list(d.columns))
print(d.describe().T.round(3).to_string())
both=d.dropna(subset=['ggl_distance','osrm_distance'])
print('rows with both distances',len(both),'distinct fips',both.fips.nunique())
R=6371.0088
la1,lo1,la2,lo2=[np.radians(both[c]) for c in ['origin_lat','origin_lon','dest_lat','dest_lon']]
h=np.sin((la2-la1)/2)**2+np.cos(la1)*np.cos(la2)*np.sin((lo2-lo1)/2)**2
km=2*R*np.arcsin(np.sqrt(h))
both=both.assign(km=km)
print('median ratio ggl/km',(both.ggl_distance/both.km).median(),' osrm/km',(both.osrm_distance/both.km).median(),' osrm/ggl',(both.osrm_distance/both.ggl_distance).median())
print('share |osrm-ggl|==0:',(both.osrm_distance==both.ggl_distance).mean(), 'n zero',(both.osrm_distance==both.ggl_distance).sum())
print('km quantiles',np.percentile(km,[1,25,50,75,99]).round(2))
cl=pd.read_csv(D+'county_lookup.csv'); U=cl[cl.STATE_NAME!='Massachusetts'][['FIPS','treat']]
b=both.merge(U,left_on='fips',right_on='FIPS')
print('pairs in U',len(b),'counties',b.fips.nunique(),'T counties',b[b.treat==1].fips.nunique(),'C counties',b[b.treat==0].fips.nunique())
b['err']=(b.osrm_distance-b.ggl_distance).abs()
nz=b[b.err>0]
print('pairs with nonzero error',len(nz),' (published full N 81,007)')
for lab,y in [('ln|d| (W1)',np.log(nz.err)),]:
    print(lab,'mean T',y[nz.treat==1].mean(),'C',y[nz.treat==0].mean())
print('county mean of raw err (Table 1 Error-Score): T',b[b.treat==1].groupby('fips').err.mean().mean(),'C',b[b.treat==0].groupby('fips').err.mean().mean())
# Count pairs by alternative inclusion rules
print('pairs with err>=1:',(b.err>=1).sum(),' err>0 & both>0:',((b.err>0)&(b.ggl_distance>0)&(b.osrm_distance>0)).sum())
