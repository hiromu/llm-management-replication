"""Post hoc source/extraction and result audit. No fitting, downloads or writes outside this directory."""
from pathlib import Path
import json, hashlib
import numpy as np
import pandas as pd
import pyreadstat
S=Path('../..').resolve(); O=Path('diagnostics')
cols=['ID_9817_RDM','COUNTRY','GEM_YR','GEMSEX','OMREASON','OMNOWJOB','OMYR5JOB']
raw,meta=pyreadstat.read_sav(str(S/'data/supplied/ICPSR_20320/DS0001/20320-0001-Data.sav'),usecols=cols,user_missing=True)
der=pd.read_csv(S/'data/derived/gem_extract.csv',usecols=cols)
r=raw.set_index('ID_9817_RDM').reindex(der.ID_9817_RDM)
check=[]
for c in cols[1:]:
 a=r[c].to_numpy(); b=der[c].to_numpy(); eq=(a==b)|(pd.isna(a)&pd.isna(b))
 usermiss=np.zeros(len(a),dtype=bool)
 for interval in meta.missing_ranges.get(c,[]):
  usermiss |= (a>=interval['lo']) & (a<=interval['hi'])
 explained=usermiss & pd.isna(b)
 check.append(dict(column=c,n=len(b),unequal=int((~eq).sum()),raw_nonmissing_derived_missing=int((pd.notna(a)&pd.isna(b)).sum()),unexplained=int((~eq & ~explained).sum())))
pd.DataFrame(check).to_csv(O/'raw_extract_check.csv',index=False)
(O/'raw_metadata.json').write_text(json.dumps(dict(value_labels={c:meta.variable_value_labels.get(c,{}) for c in cols},missing_ranges=meta.missing_ranges),indent=2))
A=pd.read_csv(S/'runs/exec_v1/ORIGIN_A/results.csv'); B=pd.read_csv(S/'runs/exec_v1/ORIGIN_B/results.csv')
keys=['run_id','model','term']; ab=A.merge(B,on=keys,suffixes=('_A','_B'))
ab=ab[ab.model.isin(['M4','M6'])]
ab['delta_b']=ab.estimate_A-ab.estimate_B; ab['delta_se']=ab.se_A-ab.se_B
ab[keys+['n_obs_A','n_obs_B','delta_b','delta_se']].to_csv(O/'AB_check.csv',index=False)
D=pd.read_csv(S/'runs/exec_v1/DEV_A_combined.csv')
keep=((D.model=='M4')&(D.term=='female:parttime'))|((D.model=='M6')&D.term.isin(['female','female:leave','female:leave_sq']))
D.loc[keep,['run_id','model','term','n_obs','estimate','se','p','converged','loglik']].to_csv(O/'existing_deviations.csv',index=False)
# Polynomial basis map applied to existing coefficients: old z,z^2 -> z,z(L^2).
c=json.loads((O/'constants_U14.json').read_text())['variables']; mu=c['leave']['mean']; sd=c['leave']['sd']; m2=c['leave_sq']['mean']; sd2=c['leave_sq']['sd']
a=sd**2/sd2; b=2*mu*sd/sd2; cc=(mu**2-m2)/sd2
mapped=[]
for model in ['M4','M6']:
 origin=A[(A.model==model)&(A.run_id=='ORIGIN')].set_index('term')
 u14=D[(D.model==model)&(D.run_id=='U14')].set_index('term')
 g2=origin.loc['female:leave_sq','estimate']/a
 for term,value in {'female:leave_sq':g2,'female:leave':origin.loc['female:leave','estimate']-b*g2,'female':origin.loc['female','estimate']-cc*g2}.items():
  mapped.append(dict(model=model,term=term,algebraic=value,existing_U14=u14.loc[term,'estimate'],delta=value-u14.loc[term,'estimate']))
pd.DataFrame(mapped).to_csv(O/'basis_existing.csv',index=False)
print(pd.DataFrame(check).to_string(index=False));print(pd.DataFrame(mapped).to_string(index=False))
print('AB maximum coefficient difference',ab.delta_b.abs().max(),'SE difference',ab.delta_se.abs().max())
# Exact upper bound from four rounded year shares in Table A2, no empirical input.
print('M8 parent-sample upper bound',28775*(.14+.18+.14+.12+4*.005),'published M8',17498)
