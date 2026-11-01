"""Internal coverage validation for ICPSR 20320 (not for readers).
Reports: country-year presence for the paper's 24 countries; per variable and survey year,
whether substantive (non-missing-code) responses exist for those countries; weight presence.
No sample construction, no recoding for analysis."""
import sys, json, pyreadstat, pandas as pd, numpy as np
sav, outdir = sys.argv[1], sys.argv[2]
PAPER = {1:'United States',31:'Netherlands',32:'Belgium',33:'France',34:'Spain',39:'Italy',41:'Switzerland',
         43:'Austria',44:'United Kingdom',45:'Denmark',46:'Sweden',47:'Norway',48:'Poland',49:'Germany',
         61:'Australia',64:'New Zealand',81:'Japan',101:'Canada',351:'Portugal',353:'Ireland',354:'Iceland',
         358:'Finland',420:'Czech Republic',30:'Greece'}
SUBNAT = {4401:'UK Scotland subsample',4402:'UK Wales subsample',6401:'NZ Maori subsample'}
VARS = ['GEM_YR','COUNTRY','CTRYALP','WEIGHT','WEIGHT_L','WEIGHT_A','GEMSEX','GEMAGE','GEMAGE7C','GEMWORK','GEMWORK3',
        'GEMHHINC','GEMEDUC','BSTART','BJOBST','OWNMGE','KNOWENT','SUSKILL','FEARFAIL','NBSTATUS','NBGOODC',
        'SUACTS','SUOWN','SUWAGE','SUWAGEYR','OMOWN','OMOWNERS','OMWAGEYR','OMNEWCST','OMNEWTEC','OMNEWT_5',
        'OMNOWJOB','OMYR5JOB','OMREASON','OMWHY','OMEB_MOT','OMBB_MOT','SUREASON','SUBOANWT','OMBABYBT','OMESTBBT','TEA','TEA_MOT']
df, meta = pyreadstat.read_sav(sav, usecols=VARS, apply_value_formats=False)
codes = list(PAPER) + list(SUBNAT)
sub = df[df.COUNTRY.isin(codes)].copy()
sub['cname'] = sub.COUNTRY.map({**PAPER, **SUBNAT})
# country-year record counts (internal only)
cy = sub.groupby(['cname','GEM_YR']).size().unstack(fill_value=0).astype(int)
cy.to_csv(f'{outdir}/icpsr20320_country_year_records_INTERNAL.csv')
# missing / non-substantive codes per variable from value labels
lab = meta.variable_value_labels
MISSWORDS = ('DK','DON','REFUSED','MISS','NOT APPLICABLE','NOT CODEABLE','CANNOT','CAN NOT','DOES NOT','NO ANSWER','CODING ERROR','NO DATA','NOT ASSIGNED','OTHER,CAN NOT')
def misscodes(v):
    return sorted(k for k,l in lab.get(v,{}).items() if any(w in str(l).upper() for w in MISSWORDS))
mc = {v: misscodes(v) for v in VARS}
json.dump({v:[float(x) if not isinstance(x,str) else x for x in c] for v,c in mc.items()}, open(f'{outdir}/icpsr20320_missing_codes_from_labels.json','w'), indent=1)
pap = sub[sub.COUNTRY.isin(PAPER)]
rows=[]
for v in VARS[3:]:
    s = pap[[v,'GEM_YR']].copy()
    valid = s[v].notna() & ~s[v].isin(mc[v])
    share = valid.groupby(s.GEM_YR).mean().round(3)
    rows.append(pd.Series(share, name=v))
avail = pd.DataFrame(rows)
avail.to_csv(f'{outdir}/icpsr20320_variable_year_valid_share_INTERNAL.csv')
# per country-year: is the key variable ever substantively answered
keyv = ['GEMSEX','GEMAGE','GEMWORK','GEMEDUC','OWNMGE','BSTART','NBSTATUS','SUSKILL','FEARFAIL','KNOWENT','OMREASON','OMNOWJOB','OMYR5JOB','OMOWNERS','OMWAGEYR','OMNEWCST','OMNEWT_5','WEIGHT','WEIGHT_L','WEIGHT_A']
res={}
for v in keyv:
    valid = pap[v].notna() & ~pap[v].isin(mc[v])
    t = valid.groupby([pap.cname, pap.GEM_YR]).any().unstack()
    res[v]=t
gaps=[]
for (c,y),n in cy.stack().items():
    if c not in PAPER.values() or n==0 or not (2001<=y<=2008): continue
    missing=[v for v in keyv if not bool(res[v].loc[c].get(y,False))]
    gaps.append({'country':c,'year':int(y),'vars_without_any_valid_response':missing})
json.dump(gaps, open(f'{outdir}/icpsr20320_country_year_variable_gaps_2001_2008_INTERNAL.json','w'), indent=1)
print(cy.loc[:, [c for c in cy.columns if 2000<=c<=2009]].to_string())
print(avail.loc[:, [c for c in avail.columns if 2001<=c<=2008]].to_string())
for g in gaps:
    if g['vars_without_any_valid_response']: print(g)
