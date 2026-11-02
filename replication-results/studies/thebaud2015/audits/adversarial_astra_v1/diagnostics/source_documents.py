"""Inspect existing local source documents only; write extracted text in diagnostics."""
from pathlib import Path
import subprocess
import pandas as pd
import numpy as np
S=Path('../..').resolve(); O=Path('diagnostics')
for name,path in [('cepr',S/'data/raw/cepr_parental_leave/parental_2008_09.pdf'),('gem_codebook',S/'data/supplied/ICPSR_20320/DS0001/20320-0001-Codebook-ICPSR.pdf')]:
 subprocess.run(['/opt/homebrew/bin/pdftotext','-layout',str(path),str(O/(name+'.txt'))],check=True)
# Independent transcription of Table A1, used only for comparison, never as model data.
roster={'AUS':range(2002,2007),'AUT':[2005,2007],'BEL':range(2001,2009),'CAN':[2001,2002,2003,2006],'CZE':[2006],'DNK':range(2001,2009),'FIN':range(2001,2009),'FRA':range(2002,2009),'DEU':[2001,2002,2003,2004,2005,2006,2008],'GRC':range(2003,2009),'ISL':range(2002,2009),'IRL':range(2001,2009),'ITA':[2001,2002,2003,2005,2006,2007,2008],'JPN':range(2001,2009),'NLD':range(2002,2009),'NZL':[2001,2003,2004,2005],'NOR':[2002,2003,2004,2005,2006,2008],'POL':[2001,2002,2004],'PRT':[2001,2004,2007],'ESP':range(2002,2009),'SWE':range(2001,2008),'CHE':[2002,2003,2005,2007],'GBR':range(2001,2009),'USA':range(2001,2009)}
pt=[37.59,31.11,34.45,25.95,5.09,23.11,14.32,23.32,37.36,12.64,26.08,34.05,28.29,31.66,60.01,34.27,32.75,14.58,8.62,19.27,19.81,44.20,38.18,18.24]
lv=[0,16,13.9,27.5,62.8,19.4,29,19.8,36,33.5,20.6,16.7,25.1,26,16,10.5,38,39.1,15,16,39.7,2.8,9.93,0]
cy=pd.read_csv(S/'data/derived/country_year_inputs.csv').set_index(['iso3','year']); alt=pd.read_csv(O/'altleave.csv').set_index(['iso3','year'])
rows=[]
for (co,years),targetpt,targetlv in zip(roster.items(),pt,lv):
 p=cy.loc[[(co,y) for y in years],'pt_common_employees_women']; l=cy.loc[[(co,y-1) for y in years],'leave_fte_weeks']; la=alt.loc[[(co,y-1) for y in years],'leave_fte_weeks']
 rows.append(dict(iso3=co,parttime=p.mean(),parttime_A1=targetpt,leave=l.mean(),alt_leave=la.mean(),leave_A1=targetlv,original_distinct_leave=l.nunique(),alternative_distinct_leave=la.nunique()))
r=pd.DataFrame(rows);r.to_csv(O/'country_comparison.csv',index=False)
print('Part-time correlation, all 24 countries',r[['parttime','parttime_A1']].corr().iloc[0,1])
print('Leave correlation',r[['leave','leave_A1']].corr().iloc[0,1],'alternative',r[['alt_leave','leave_A1']].corr().iloc[0,1])
print(r.to_string(index=False))
