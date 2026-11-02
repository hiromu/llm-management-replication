#!/usr/bin/env python3
"""Render saved aggregate estimates/ranges; no fitting, scoring, or source images."""
import csv
import os
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

if not os.environ.get('REPLICATION_ARCHIVE_ROOT'):
    raise SystemExit('Set REPLICATION_ARCHIVE_ROOT to the writable source archive before regenerating presentation assets.')
PROJECT = Path(os.environ['REPLICATION_ARCHIVE_ROOT']).expanduser().resolve()
SOURCE = PROJECT / 'studies/nagaraj2021/reports/figures/figure_focal_influence.csv'
OUTPUT = PROJECT / 'studies/nagaraj2021/presentation/focal-estimates.png'
with SOURCE.open() as f:
    rows = list(csv.DictReader(f))
labels = ['T3 (3)  Follow-on · panel', 'T3 (4)  Follow-on · controls',
          'T3 (5)  Contributors · panel', 'T3 (6)  Contributors · controls',
          'T4 (3)  Follow-on · 2008–14', 'T4 (4)  Follow-on · 2014',
          'T4 (5)  Contributors · 2008–14', 'T4 (6)  Contributors · 2014',
          'T6 (1)  Routing error']
assert [r['unit'] for r in rows] == ['T3|(3)','T3|(4)','T3|(5)','T3|(6)','T4|(3)','T4|(4)','T4|(5)','T4|(6)','T6|(1) Treat']
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'axes.spines.top':False,'axes.spines.right':False})
fig, ax = plt.subplots(figsize=(7.4,5.9), dpi=180)
fig.subplots_adjust(left=.355,right=.965,top=.86,bottom=.15)
for i, row in enumerate(rows):
    lo, hi, rec, pub = (float(row[k]) for k in ('del_est_min','del_est_max','reconstructed','published'))
    ax.hlines(i,lo,hi,color='#80a7b9',linewidth=5,zorder=2)
    ax.scatter(rec,i,color='#235d76',s=34,zorder=4)
    ax.scatter(pub,i,marker='x',color='#252b2a',s=50,linewidth=1.7,zorder=3)
ax.set_yticks(range(9),labels)
ax.set_ylim(8.65,-.65)
ax.set_xlim(-.46,.16)
ax.set_xticks([-.4,-.2,0,.1])
ax.axvline(0,color='#9b9e9c',linewidth=.9,zorder=1)
ax.grid(axis='x',color='#e4e6e3',linewidth=.7)
ax.tick_params(axis='y',length=0,pad=12)
ax.spines['left'].set_visible(False)
ax.spines['bottom'].set_color('#a9ada9')
ax.set_xlabel('Treatment coefficient (log points)',labelpad=10)
fig.legend(handles=[Line2D([0],[0],marker='x',color='#252b2a',linestyle='none',markersize=7,label='Published'),
                    Line2D([0],[0],marker='o',color='#235d76',linestyle='none',markersize=6,label='Reconstructed'),
                    Line2D([0],[0],color='#80a7b9',linewidth=4,label='County-deletion range')],
           loc='upper left',bbox_to_anchor=(.035,.99),ncol=2,frameon=False,fontsize=10,columnspacing=1.8)
fig.text(.035,.022,'Frozen run · 1 Nov 2026',color='#606761',fontsize=9)
OUTPUT.parent.mkdir(parents=True,exist_ok=True)
fig.savefig(OUTPUT,facecolor='white',metadata={'Software':'Replication Console; saved aggregate CSV only'})
print(OUTPUT)
