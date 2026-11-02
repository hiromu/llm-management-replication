#!/usr/bin/env python3
"""Draw Figures 3/4 from frozen implementation A aggregates; no model fits or scoring.

Follows the encodings in the archived make_figure_comparisons.py. Only the
reconstruction is exported: original article pixels never enter public assets.
"""
import csv
import os
import hashlib
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

if not os.environ.get('REPLICATION_ARCHIVE_ROOT'):
    raise SystemExit('Set REPLICATION_ARCHIVE_ROOT to the writable source archive before regenerating presentation assets.')
PROJECT = Path(os.environ['REPLICATION_ARCHIVE_ROOT']).expanduser().resolve()
ROOT = PROJECT / 'studies/nagaraj2021'
OUT = PROJECT / 'studies/nagaraj2021/presentation'
RUN = ROOT / 'runs/run_20261101_v1/out/A'
OUT.mkdir(parents=True, exist_ok=True)
def read(name):
    with (RUN/name).open() as f:
        return list(csv.DictReader(f))
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'axes.edgecolor':'#888888'})
rows = read('an10_means.csv')
rows = [r for r in rows if r['spec_id']=='S00054' and r['followon_def'] in ('','followon_F1')]
cumstat = next(r['statistic'] for r in rows if 'cum' in r['statistic'])
fig, axes = plt.subplots(2,2,figsize=(8.4,6.9),layout='constrained')
limits = [(0,8),(0,150000),(0,4),(0,25000)]
for i,(outcome,stat) in enumerate((('total','mean_log_y_plus_1'),('total',cumstat),('followon','mean_log_y_plus_1'),('followon',cumstat))):
    ax=axes.flat[i]
    values=[]
    for tr in ('1','0'):
        series=sorted([r for r in rows if r['outcome']==outcome and r['statistic']==stat and r['treat']==tr],key=lambda r:r['quarter'])
        xs=[int(r['quarter'][:4])+(int(r['quarter'][-1])-1)/4 for r in series]
        ys=[float(r['value']) for r in series]; values+=ys
        assert len(series)==39, (outcome,stat,tr,len(series))
        ax.plot(xs,ys,ls='-' if tr=='1' else (0,(5,3)),color='#999999' if tr=='1' else '#111111',marker='s' if tr=='1' else 'o',mfc='white' if tr=='1' else '#111111',ms=2.7,lw=1.1,label='Treatment' if tr=='1' else 'Control')
    ax.axvline(2007.5,color='#e0457b',ls=':',lw=.9)
    ax.set_xlim(2004,2014.9); ax.set_xticks(range(2004,2015,2))
    lo,hi=limits[i];ax.set_ylim(min(lo,min(values)),max(hi,max(values)))
    ax.set_title(('Total' if i<2 else 'Follow-on')+' · '+('Logged' if i%2==0 else 'Cumulative'),loc='left',fontsize=11,pad=12)
    ax.tick_params(labelsize=8.5)
    if i==1: ax.legend(frameon=False,fontsize=9)
fig.savefig(OUT/'figure3.png',dpi=180,facecolor='white');plt.close(fig)
rows = read('results.csv')
fig,axes=plt.subplots(1,2,figsize=(8.4,4),layout='constrained')
for ax,spec,title,lim in zip(axes,('S00055','S00056'),('Follow-on contributions','Contributors'),((-.4,.2),(-.3,.1))):
    series=[{'year':int(r['term'][-4:]),**{k:float(r[k]) for k in ('estimate','ci_low','ci_high')}} for r in rows if r['spec_id']==spec]
    assert len(series)==9
    series.append({'year':2007,'estimate':0.,'ci_low':0.,'ci_high':0.})
    series.sort(key=lambda r:r['year'])
    x=[r['year'] for r in series]
    for k in ('ci_low','ci_high'): ax.plot(x,[r[k] for r in series],color='#888888',ls=(0,(4,3)),lw=.8)
    for subset,marker in (([r for r in series if r['year']<=2007],'o'),([r for r in series if r['year']>=2007],'s')):
        ax.plot([r['year'] for r in subset],[r['estimate'] for r in subset],color='#2b6a8c',marker=marker,mfc='white',ms=3.5,lw=1.1)
    ax.axhline(0,color='#888888',ls=(0,(10,5)),lw=.8);ax.axvline(2007,color='#e0457b',ls=':',lw=.9)
    ax.set_xlim(2004,2014.4);ax.set_ylim(min(lim[0],min(r['ci_low'] for r in series)),max(lim[1],max(r['ci_high'] for r in series)))
    ax.set_xticks(range(2004,2015,2));ax.set_xlabel('Year');ax.set_title(title,loc='left',fontsize=11,pad=12)
    ax.tick_params(labelsize=9)
fig.savefig(OUT/'figure4.png',dpi=180,facecolor='white');plt.close(fig)
manifest={'renderer':'replication-results/tools/render-nagaraj-comparisons.py','new_fits':False,'sources':[{'path':str((RUN/p).relative_to(PROJECT)),'sha256':hashlib.sha256((RUN/p).read_bytes()).hexdigest()} for p in ('an10_means.csv','results.csv')],'assets':{p:hashlib.sha256((OUT/p).read_bytes()).hexdigest() for p in ('figure3.png','figure4.png')}}
(OUT/'figure-comparisons.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
