"""Build document tables from saved estimates and screening metadata; no model fits.
Run from the project directory with ~/.venv/bin/python.
"""
from pathlib import Path
from collections import Counter, defaultdict
import csv, json, hashlib, math, shutil
ROOT=Path(__file__).resolve().parents[1]
# Artifact root: the sibling folder in the proposal workspace, or the repository root when this
# folder sits at <repo>/proposal/.
BASE=ROOT/'orgsci-proposal-supplement' if (ROOT/'orgsci-proposal-supplement').is_dir() else ROOT.parent
OUT=ROOT/'supplement_assets/generated'
OUT.mkdir(parents=True,exist_ok=True)
STUDIES=['lehman2011','holderness2012','deephouse1999','thebaud2015','twenge2010','delaney1996']
NAMES=['Lehman et al.','Holderness and Pontiff','Deephouse',"Thébaud",'Twenge et al.','Delaney and Huselid']
def read(p):
 with p.open(newline='',encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def write(p,rs,fields=None):
 fields=fields or list(rs[0]);p.parent.mkdir(parents=True,exist_ok=True)
 with p.open('w',newline='',encoding='utf-8') as f:
  w=csv.DictWriter(f,fieldnames=fields,extrasaction='ignore');w.writeheader();w.writerows(rs)
def tex(x):
 s=str(x).replace('−','-').replace('–','--').replace('—',': ').replace('≤',r'$\leq$').replace('≥',r'$\geq$')
 return ''.join({'&':r'\&','%':r'\%','_':r'\_','#':r'\#','^':r'\textasciicircum{}'}.get(c,c) for c in s)
def fmt(x):
 if x is None or str(x) in ['', 'nan','None']:return '--'
 try:
  n=float(x)
  if not math.isfinite(n):return '--'
  if n==0:return '0'
  if abs(n)<.01:return f'{n:.1e}'
  return f'{n:.4g}'
 except ValueError:return str(x)
def est(b,se='',stars=''):
 b=fmt(b)
 return tex(b)+(r' ('+tex(fmt(se))+')' if se and str(se)!='nan' else '')+((' '+tex(stars)) if stars and stars not in ['none','nan'] else '')
def status(s):
 if 'source_vintage' in s:return 'I-S'
 if s in ['consistent','fully_reproduced']:return 'C'
 if 'fragile_inference' in s:return 'FI'
 if 'candidate' in s or 'discrepant' in s:return 'U'
 if 'not_audited' in s or 'not_assessable' in s:return 'NA'
 if 'not_attemptable' in s:return 'NA'
 return 'I'
paths={'lehman2011':'runs/score_v1/target_comparisons_all_cells.csv','holderness2012':'scoring/claim_scores.csv','deephouse1999':'scoring/run_v1/term_scores.csv','thebaud2015':'reports/exports/term_comparisons.csv','twenge2010':'reports/claim_comparisons.csv','delaney1996':'reports/data/claim_cell_comparisons.csv'}
normalized=[];evidence=[]
for study,name in zip(STUDIES,NAMES):
 b=BASE/'studies'/study;raw=read(b/paths[study]);com={r['term']:r for r in read(b/'scoring/common_v1/terms.csv')}
 rs=[]
 for r in raw:
  recse='';pubse='';stars='';n='';npub='';origin='O';p='';sign='';inf='';mag='';prov=''
  if study=='lehman2011':
   if r['cell']!='U1=0|U2=0|U3=0|U4=0|U5=0|U6=0|U7=0|U8=0':continue
   key=r['key'];table='Table '+key[1];term=key.split('|',1)[1].replace('|',': ')
   pub,pubse,stars=r['pub_value'],r['pub_se'],r['pub_stars'];rec=str(math.exp(float(r['reconstructed']))) if key.startswith('T5') else r['reconstructed']
   p=r['p_native'];d=r['delta_se'];st=r['outcome'];n='21540';npub='22603';sign=r['sign'];inf=r['inference'];mag=r['magnitude']
  elif study=='holderness2012':
   key=f"{r['target_id']} {r['spec']} {r['term']}";table='Table '+r['family'][1:];term=f"{r['target_id']} {r['group']} {r['spec']} {r['term']}"
   pub=r['printed_value'];rec=r['rec_me'];p=r['rec_p'];d='';st=r['outcome'];n=r['n_rec'];npub=r['n_pub'];sign=r['sign_fail'];inf=r['inference'];mag='not audited'
  elif study=='deephouse1999':
   key=f"{r['model']} {r['term']}";table='Text' if 'without' in r['target_id'] else ('Table 2' if r['target_id'].startswith('T2') else 'Text')
   term=key;pub=r['pub_coef'];pubse=r['pub_se'];stars=r['pub_stars'];rec=r['rec_coef'];recse=r['rec_se'];p=r['rec_p2'];d=r['d_se_units'];st=r['term_outcome'];origin=r['origin'];n=r['n'];npub='960';sign=r['sign'];inf=r['inference'];mag=r['magnitude']
  elif study=='thebaud2015':
   key=f"{r['model']} {r['term']}";table=com[key]['table'];term=key;pub=r['pub_value'];pubse=r['pub_se'];stars=r['pub_stars'];rec=r['rec_value'];recse=r['rec_se'];p=r['rec_p'];d=r['distance_pub_se'];st=r['outcome'];n=r['n_rec'];npub=r['n_pub'];sign=r['sign'];inf=r['inference'];mag=r['magnitude']
  elif study=='twenge2010':
   if r['tier'].startswith('identification'):continue
   key=r['claim'];table='Table 1';term=key;pub=r['published'];rec=r['reconstructed'];p=r['native_p'];d=r['distance_se'];st=r['outcome'];sign=r['sign'];inf=r['inference'];mag=r['magnitude']
  else:
   # Delaney prints one-tailed stars; the p shown is the rebuilt one-tailed (upper-tail) p.
   if r['quantity']!='coef':continue
   key=f"{r['model_id']} {r['term']}";fam,model=r['model_id'].split('_');table='Table 3' if fam=='org' else 'Table 4';term=model+' '+r['term']
   pub,pubse,stars=r['value'],r['se'],r['stars'];rec=r['origin_est'];recse=r['origin_se'];p=r['origin_p_upper'];d=r['origin_m'];st=r['outcome'];n=r['family_n'];npub={'org':'590','mkt':'373'}[fam];sign=r['origin_sign_fail'];inf='';mag=''
  c=com[key]
  rs.append(dict(study=study,table=table,term=term,key=key,origin=origin,tier=c['tier'],claim=c['claim'],published=pub,published_se=pubse,stars=stars,reconstructed=rec,reconstructed_se=recse,p_native=p,distance=d,n_published=npub,n_reconstructed=n,sign=sign,inference=inf,magnitude=mag,provisional=prov,study_outcome=st,common=c['common'],lenient=c['lenient'],source=paths[study]))
 normalized+=rs
 # Combined columns remain on comparable scales: OR against OR in Lehman Table 5.
 def table(rows,caption,label,long=True):
  head=r'\begin{longtable}{@{}p{.245\linewidth}p{.17\linewidth}p{.17\linewidth}p{.085\linewidth}p{.060\linewidth}p{.08\linewidth}p{.07\linewidth}@{}}'+'\n'
  head+=r'\caption{'+caption+r'}\label{'+label+r'}\\'+'\n'+r'\toprule Target & Published (SE) & Rebuilt (SE) & Native $p$ & $d$ & Study & Common\\\midrule'+'\n'
  head+=r'\endfirsthead\multicolumn{7}{l}{\small '+caption+r' (continued)}\\\toprule Target & Published (SE) & Rebuilt (SE) & Native $p$ & $d$ & Study & Common\\\midrule\endhead\bottomrule\endfoot'+'\n'
  for r in rows:
   term=r['term'].replace('_',' ').replace('female:','female x ').replace('prov ','provider ').replace('P1','1976-91').replace('P2','1991-2006').replace('P3','1976-2006')
   if r['origin']!='O':term+=' ['+r['origin']+']'
   if r['tier']=='focal':term+=' *'
   head+=' & '.join([tex(term),est(r['published'],r['published_se'],r['stars']),est(r['reconstructed'],r['reconstructed_se']),tex(fmt(r['p_native'])),tex(fmt(r['distance'])),status(r['study_outcome']),status(r['common'])])+r'\\'+'\n'
  return r'{\scriptsize\setlength{\tabcolsep}{3pt}\renewcommand{\arraystretch}{1.06}'+'\n'+head+r'\end{longtable}}'+'\n'
 (OUT/(study+'_all.tex')).write_text(table(rs,tex(name)+': all numerical targets in the common-rule scope','tab:all:'+study))
 (OUT/(study+'_focal.tex')).write_text(table([r for r in rs if r['tier']=='focal'],tex(name)+': focal numerical targets','tab:focal:'+study))
 evidence.append(dict(study=study,source=paths[study],sha256=hashlib.sha256((b/paths[study]).read_bytes()).hexdigest(),rows=len(rs),unique_common_terms=len(com)))
write(OUT/'comparisons.csv',normalized)
(OUT/'comparison_provenance.json').write_text(json.dumps(evidence,indent=2)+'\n')
# Aggregate the post hoc outputs without rescoring.
summary=[]
for study,name in zip(STUDIES,NAMES):
 b=BASE/'studies'/study;rows=read(b/'scoring/common_v1/terms.csv');rec=json.loads((b/'scoring/common_v1/paper_record.json').read_text());c=Counter(r['common'] for r in rows);l=Counter(r['lenient'] for r in rows)
 summary.append(dict(study=study,name=name,consistent=c['consistent'],indeterminate=c['indeterminate'],candidate=c['candidate'],total=len(rows),common_paper=rec['paper']['common'],lenient_paper=rec['paper']['lenient'],lenient_consistent=l['consistent'],lenient_indeterminate=l['indeterminate'],lenient_candidate=l['candidate']))
write(OUT/'common_summary.csv',summary)
assert sum(r['total'] for r in summary)==733
# Screening snapshot. Do not copy PDFs, empirical data, or abstract text.
SRC=ROOT.parent/'Replication_management/top_journals_v2'
if not SRC.is_dir():
 # Outside the proposal workspace the screening ledger is not available; keep the saved snapshot.
 print(json.dumps({'comparison_rows':len(normalized),'common_terms':733,'screening':'saved snapshot in papers/screening kept'},indent=2));raise SystemExit
DEST=BASE/'papers/screening';DEST.mkdir(parents=True,exist_ok=True)
corpus=[]
for j in ['SMJ','ORSC','MNSC','AMJ','JOM','ASQ']:
 rs=read(SRC/f'1_abstract_screening/master/{j}_triage.csv')
 corpus.extend(r for r in rs if r.get('item_flag')!='duplicate' and r.get('field')!='other' and r.get('item_type')=='research')
fields=[k for k in corpus[0] if k not in ['abstract','rationale']]
write(DEST/'corpus_11051.csv',corpus,fields)
full=read(SRC/'3_pdf_screening/target_fulltext.csv');sources=read(SRC/'3_pdf_screening/target_sources.csv');by=defaultdict(list)
for r in sources:by[r['paper_id']].append(r)
write(DEST/'fulltext_776.csv',full,[k for k in full[0] if k not in ['pdf_file']])
write(DEST/'source_assessments.csv',sources,[k for k in sources[0] if k not in ['quote']])
broad=[r for r in full if r['tier_group'] in {'A','B','C'}];nopkg=[r for r in broad if r['has_replication_package']=='no'];emp=[r for r in nopkg if r['tier_group'] in {'B','C'}];arch=[r for r in emp if r['method_primary']=='archival_quant']
public={'R','T0','T1','T5'}
def available(r,tiers):return bool(by[r['paper_id']]) and all(x['tier'] in tiers for x in by[r['paper_id']])
obtain=[r for r in arch if available(r,public|{'T2c'})];pub=[r for r in arch if available(r,public)]
counts=dict(corpus=len(corpus),fulltext=len(full),candidate=len(broad),no_package_recorded=len(nopkg),empirical=len(emp),archival=len(arch),all_sources_obtainable=len(obtain),all_sources_public=len(pub))
assert list(counts.values())==[11051,776,501,468,277,265,209,154],counts
for filename,rs in [('empirical_277.csv',emp),('archival_public_154.csv',pub)]:write(DEST/filename,rs,[k for k in full[0] if k!='pdf_file'])
(DEST/'counts.json').write_text(json.dumps(counts,indent=2)+'\n')
ids=['ORSC_2011_Lehman','MNSC_2012_Holderness','SMJ_1999_Deephouse','ASQ_2015_Thebaud','JOM_2010_Twenge','AMJ_1996_DELANEY'];pubids={r['paper_id'] for r in pub};assert set(ids)<=pubids
sel=[]
for study,i in zip(STUDIES,ids):
 r=next(r for r in full if r['paper_id']==i)
 sel.append(dict(study=study,paper_id=i,doi=r['doi'],journal=r['journal'],year=r['year'],in_empirical_277=True,in_public_154=True,selection_date='not recovered',selection_mechanism='selected feasibility case; no random draw established',dated_selection_reason='not recovered',prior_results_known='not established'))
 if study=='delaney1996':sel[-1].update(selection_date='2026-10-28',dated_selection_reason='replaced weigelt2009 (AMJ_2009_Weigelt) as the AMJ case after both runs had finished; both ended indeterminate',prior_results_known='yes: both AMJ results were known when the AMJ case was chosen')
write(DEST/'six_case_membership.csv',sel)
for f in ['METHOD_1_abstract_screening.md','METHOD_3_pdf_screening.md']:
 shutil.copy2(SRC/f,DEST/f)
shutil.copy2(SRC/'3_pdf_screening/criteria.md',DEST/'fulltext_criteria.md')
manifest=[dict(file=str(p.relative_to(DEST)),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(DEST.iterdir()) if p.is_file() and p.name!='manifest.json']
(DEST/'manifest.json').write_text(json.dumps(dict(source='Replication_management/top_journals_v2',snapshot_date='2026-10-28',files=manifest),indent=2)+'\n')
print(json.dumps({'screening':counts,'comparison_rows':len(normalized),'common_terms':733,'six_memberships_verified':True},indent=2))
