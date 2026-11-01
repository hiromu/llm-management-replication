"""Task 1: GEM extract from ICPSR 20320 V6 (read-only .sav). No recoding."""
import pyreadstat, pandas as pd, numpy as np, json, sys
SAV = 'data/supplied/ICPSR_20320/DS0001/20320-0001-Data.sav'
OUT = 'data/derived/gem_extract.csv'
CC = 'data/derived/country_codes.csv'
# ISO3 -> GEM COUNTRY code (telephone-code based; labels verified from SAV value labels)
ISO = {'AUS':61,'AUT':43,'BEL':32,'CAN':101,'CZE':420,'DNK':45,'FIN':358,'FRA':33,'DEU':49,'GRC':30,
       'ISL':354,'IRL':353,'ITA':39,'JPN':81,'NLD':31,'NZL':64,'NOR':47,'POL':48,'PRT':351,'ESP':34,
       'SWE':46,'CHE':41,'GBR':44,'USA':1}
NAMES = {'AUS':'Australia','AUT':'Austria','BEL':'Belgium','CAN':'Canada','CZE':'Czech Republic','DNK':'Denmark',
 'FIN':'Finland','FRA':'France','DEU':'Germany','GRC':'Greece','ISL':'Iceland','IRL':'Ireland','ITA':'Italy',
 'JPN':'Japan','NLD':'Netherlands','NZL':'New Zealand','NOR':'Norway','POL':'Poland','PRT':'Portugal','ESP':'Spain',
 'SWE':'Sweden','CHE':'Switzerland','GBR':'United Kingdom','USA':'United States'}
WANT = ['GEM_YR','COUNTRY','CTRYALP','ID_9817_RDM','GEMSEX','GEMAGE','GEMEDUC','GEMWORK','GEMWORK3','BSTART',
 'SUACTS','SUOWN','SUWAGE','SUBOANWT','OWNMGE','OMOWN','OMOWNERS','OMWAGEYR','OMBABYBT','OMESTBBT','OMREASON',
 'OMWHY','OMNOWJOB','OMYR5JOB','OMNEWCST','OMNEWT_5','SUSKILL','FEARFAIL','KNOWENT','NBSTATUS','WEIGHT',
 'WEIGHT_L','WEIGHT_A','TEA']
_, meta = pyreadstat.read_sav(SAV, metadataonly=True)
missing = [v for v in WANT if v not in meta.column_names]
if missing: print('MISSING VARIABLES:', missing); sys.exit(1)
lab = meta.variable_value_labels['COUNTRY']
for iso, c in ISO.items():
    print(iso, c, lab.get(float(c)))
df, _ = pyreadstat.read_sav(SAV, usecols=WANT)
inv = {v:k for k,v in ISO.items()}
df = df[df['COUNTRY'].isin(list(ISO.values())) & df['GEM_YR'].between(2000, 2008)].copy()
df.insert(0, 'iso3', df['COUNTRY'].astype(int).map(inv))
for c in df.columns:
    if c in ('iso3','CTRYALP'): continue
    s = df[c]
    if pd.api.types.is_float_dtype(s) and s.dropna().apply(float.is_integer).all():
        df[c] = s.astype('Int64')
df = df.sort_values(['iso3','GEM_YR','ID_9817_RDM'], kind='mergesort')
df.to_csv(OUT, index=False, na_rep='')
cc = df.groupby('iso3').agg(COUNTRY=('COUNTRY','first'), CTRYALP=('CTRYALP', lambda s: '|'.join(sorted(set(s.dropna().astype(str)))))).reset_index()
cc.insert(1, 'name', cc['iso3'].map(NAMES))
cc['country_label'] = cc['COUNTRY'].map(lambda c: lab.get(float(c)))
cc.to_csv(CC, index=False)
print('rows', len(df), 'cols', df.shape[1]); print(cc.to_string())
