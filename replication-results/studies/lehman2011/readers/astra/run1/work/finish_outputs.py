from build_outputs import *

checks=[]
def check(what,keys,calculation,interval,result,note,p,w):
    checks.append({'check_id':f'F{len(checks)+1}','what':what,'inputs':[refs[k] for k in keys], 'calculation':calculation,'rounding_interval_used':interval,'result':result,'note':note,'source':src(p,w)})
check('Incremental LR statistic, Model 2 versus Model 1',['ll1','ll2','dlr2','lr1','lr2'],
      '2*(LL2-LL1) = 709.3746. Difference of reported overall LR statistics is 709.37; reported incremental statistic is 168.87.',
      'Each LL has interval printed ±0.00005, hence the LR difference lies in [709.3744,709.3748]. The incremental statistic interval is [168.865,168.875]; disjoint.',
      'inconsistent','Under the reported nested models and common sample, rounding cannot reconcile the values. Preserve all printed entries; no corrected value is inserted into targets.',11,'Table 5 / Models 1–2 / LL, LR χ², Δ LR χ²')
check('Incremental LR statistic, Model 3 versus Model 2',['ll2','ll3','dlr3','lr2','lr3'],
      '2*(LL3-LL2) = 526.6184. Difference of reported overall LR statistics is 526.62; reported incremental statistic is 544.05.',
      'LL-based difference in [526.6182,526.6186]; printed increment in [544.045,544.055]; disjoint.',
      'inconsistent','Same condition as the preceding check; not an automatic replication verdict.',11,'Table 5 / Models 2–3 / LL, LR χ², Δ LR χ²')
check('Common null likelihood implied by overall LR statistics',['ll1','ll2','ll3','lr1','lr2','lr3'],
      'LLnull = LLmodel - LR/2 gives -7482.0031, -7482.0008, -7482.0016.',
      'Each implied null has half-width 0.00255. Intervals [-7482.00565,-7482.00055], [-7482.00335,-7481.99825], [-7482.00415,-7481.99905] overlap.',
      'consistent','The overall LR rows are mutually compatible with a common null despite the inconsistent incremental rows.',11,'Table 5 / LL and LR χ²')
check('Degrees of freedom and stated regressors',['df1','df2','df3'],
      'Eight M1 listed non-year predictors plus five season indicators give 13; adding four performance/jump terms gives 17; adding three interactions gives 20.',
      'Degrees of freedom and counts of listed terms are exact integers, not rounded continuous estimates.',
      'consistent','Compatible with team-conditional estimation and separate season indicators, not proof of the unknown panel declaration. Explicit unconditional team dummies would have a different full parameter count.',11,'Table 5; PDF p. 9, Data Analysis Model')
check('Sample removal arithmetic and model sample equality',[],
      'In sealed_N_branch.json, original minus final sample equals the late-game removal entry; the Table 1 and Table 5 sample entries agree.',
      'Published integer counts treated as exact; no rounding allowance needed.',
      'consistent','Published sample sizes remain only in sealed_N_branch.json. No comparison to independently acquired data was made.',16,'Endnote 3; PDF p. 8, Data; PDF pp. 10–11, Tables 1 and 5')
check('Game frequency table and quarter conversion totals',['gameavg'],
      'Summing Table 2 game frequencies equals its game N; weighting frequencies by the row attempt value equals the Table 3 all-quarter conversion total. Dividing by game N rounds to the text mean. Every individual percentage falls in its printed interval; cumulative percentages are checked separately.',
      'Integer frequencies exact; two-decimal mean/percent intervals are printed ±0.005.',
      'consistent','All count and percentage operands are in sealed_N_branch.json. No raw data used.',10,'Tables 2–3 and Results / opening paragraph')
check('Quarter totals and aspiration subgroup partition',[],
      'Summing Table 3 quarter totals and conversions recovers its all-quarter totals. For each quarter, the two Table 4 subgroup Ns sum to Table 3 total fourth downs; subgroup Ns also sum correctly across quarters. All quarter percentages round from their integer ratios.',
      'Integer counts exact; percentage intervals printed ±0.005 percentage points.',
      'consistent','Operands retained only in sealed_N_branch.json.',10,'Table 3; PDF p. 11, Table 4')
check('Spline means in Table 1 versus subgroup means in Table 4',['t1_mean_1','t1_mean_2','t4_at or below_mean_All','t4_above_mean_All'],
      'For zero-filled splines, full-sample mean equals subgroup mean times subgroup sample share. Below-branch full-mean magnitude can lie in [4.732887891,4.739475070]; above branch in [2.916255807,2.919668628].',
      'Table 4 subgroup means have half-width 0.005; count weights are exact from sealed_N_branch.json. These intersect the Table 1 intervals [-4.745,-4.735] and [2.915,2.925], respectively.',
      'consistent','Signs follow the negative below-aspiration spline definition, not a positive shortfall measure.',11,'Table 4 / All; PDF p. 10, Table 1')
check('Risk-taking mean and Bernoulli standard deviation',['t1_mean_0','t1_sd_0'],
      'Use the Table 3 all-quarter conversion-attempt count divided by total decisions in sealed_N_branch.json. The resulting proportion rounds to the Table 1 mean, and sqrt(p*(1-p)) or its sample-SD correction rounds to the reported SD.',
      'Mean interval [0.105,0.115]; SD interval [0.3065,0.3075].',
      'consistent','This checks published aggregates only, not converted first downs or raw data.',10,'Tables 1 and 3')
check('Division/conference indicator nesting',['t1_mean_7','t1_mean_8'],
      'If both variables are affirmative inclusive indicators, same_division <= same_conference observationwise, and their means must obey the same inequality. Printed means reverse that ordering.',
      'Division mean [0.745,0.755] and conference mean [0.415,0.425] are disjoint in the wrong order under affirmative nested coding.',
      'cannot_assess','Conditional inconsistency, not a proven data error: binary codes and inclusive/exclusive definitions are unstated. Reverse coding or a mislabeled row could explain it, but neither is assumed or repaired.',10,'Table 1 / Same division and Same conference; PDF p. 9, Control Variables')

# Publication-only interval diagnostics; these never create target estimates.
byid={t['target_id']:t for t in targets}
def abs_interval(lo,hi): return (0 if lo<=0<=hi else min(abs(lo),abs(hi)),max(abs(lo),abs(hi)))
def fmt(x): return 'unbounded' if math.isinf(x) else f'{x:.8g}'
critical={'none printed':(0,1.6448536269514722),'+':(1.6448536269514722,1.959963984540054),'*':(1.959963984540054,2.5758293035489004),'**':(2.5758293035489004,math.inf)}
for key,tid in list(refs.items()):
    if not (key.startswith('or') or key.startswith('me')): continue
    t=byid[tid]
    if t['published_se'] is None: continue
    h=0.0005 if key.startswith('or') else 0.00005
    v=t['value']; s=t['published_se']; slo=max(0,s-h); shi=s+h
    if key.startswith('or'):
        lo,hi=v-h,v+h
        vals=[lo*math.log(lo),hi*math.log(hi)]
        nlo,nhi=abs_interval(min(vals),max(vals))
        method='Assuming printed SE is delta-transformed to the odds-ratio scale, |z| = OR*|ln(OR)|/SE_OR.'
    else:
        lo,hi=v-h,v+h; nlo,nhi=abs_interval(lo,hi)
        method='For a normal two-sided Wald check, |z| = |marginal effect|/SE.'
    zl=nlo/shi; zh=nhi/slo if slo>0 else math.inf
    a,b=critical[t['stars_or_inequality']]
    compatible=max(zl,a)<=min(zh,b)
    check(f"Printed uncertainty and stars: {t['model_label']}, {t['row_label']}",[key],
          method+f' Full interval bounds give |z| in [{fmt(zl)},{fmt(zh)}]. Printed symbol: {t["stars_or_inequality"]}.',
          f'Estimate interval [{v-h:.7f},{v+h:.7f}], SE interval [{slo:.7f},{shi:.7f}]; zero lower SE is a limit, not exact zero.',
          'consistent' if compatible else 'cannot_assess',
          ('At least one pair of unrounded values is compatible with the symbol under a two-sided normal reference. This does not recover an exact p or verify the unspecified method.' if compatible else 'No overlap under the assumed test; method/tail are not explicit, so no unconditional inconsistency is declared.') + (' OR-SE transformation is an assumption, not stated in the table.' if key.startswith('or') else ''),
          t['source']['pdf_page'],t['source']['where'])
check('Rounded unit odds ratio with significance',['or3_13'],
      'An odds ratio printed as 1.000 can differ from unity, and an SE printed as 0.000 can be strictly positive and small. The pair does not fix a Wald statistic or sign.',
      'OR in [0.9995,1.0005]; SE in [0,0.0005], with positive SE needed for an ordinary Wald test.',
      'consistent','Do not erase the symbol or treat the interaction as exactly zero. This also prevents recovery of a precise quadratic time interaction for prediction.',11,'Table 5 / Model 3 / Performance² × Minutes remaining')
check('Table 6 zero-rounded SEs',['me0_6','me2_5'],
      'A printed 0.0000 SE permits a sufficiently small positive SE; the corresponding effects can be statistically significant.',
      'SE in [0,0.00005]; each effect in printed value ±0.00005.',
      'consistent','No infinite test statistic is inferred from printed zero.',12,'Table 6 / All quarters at 42 and second quarter at 28')
check('Seven-point effect examples versus local derivatives',['sevenall','sevenq2','sevenq4','sevenq4far','me0_2','me2_2','me4_2','me4_0'],
      'Seven times the absolute printed local effect, expressed in percentage points, gives 2.73, 0.63, 24.64 and 24.71, matching the text.',
      'Each derivative gives ±0.035 percentage points after multiplication by 700; each two-decimal percent has ±0.005 interval. Corresponding intervals intersect.',
      'consistent','Arithmetic matches a linear approximation. Percent likelihood changes in prose have no specified denominator; derivatives times seven do not establish relative percentages or exact finite changes. Total points also changes in a real touchdown scenario.',12,'Results / seven-point examples; PDF p. 13 continuation')
check('Exact finite-change interpretation of seven-point examples',['sevenall','sevenq2','sevenq4','sevenq4far'],
      'Exact finite differences require probabilities at both endpoints, including intercept/fixed effects and every changed regressor. These are not supplied.',
      'Rounded slope intervals do not determine endpoint probabilities; no central-value substitution is made.',
      'cannot_assess','Separate a local approximation from an exact probability difference; do not insert reconstructed probabilities into targets.',12,'Results / examples; PDF pp. 9,13')
check('H1A shape and observed support after rounding',['or2_8','or2_9']+[f'me0_{j}' for j in range(4)],
      'The Model 2 below-branch index stationary point is -ln(OR_linear)/(2*ln(OR_quadratic)). Full OR intervals allow stationary points both within and below published support. Table 6 all-quarter derivatives do not themselves show a positive far-below slope.',
      'Linear OR [0.8825,0.8835]; quadratic OR [0.9985,0.9995]. These permit approximate stationary points from -125 to -41; support endpoint is in Table 4.',
      'cannot_assess','Negative linear and quadratic terms establish concavity of the below index, not necessarily an interior turning point over observed support. Preserve stated H1A support without concluding impossibility from rounded ORs.',11,'Table 5 / Model 2; Table 4; PDF p. 12, Table 6')
check('Aspiration comparison versus model-addition test',['sensitivity','dlr2'],
      'The same printed chi-square is used for the prose below/above comparison and Model 2 improvement in Table 5. The former’s restrictions are absent and these tests are not generally identical.',
      'Both printed intervals [168.865,168.875]; equality cannot identify null restrictions.',
      'cannot_assess','Do not select a test by reproducing the value.',10,'Results / final paragraph; PDF p. 11, Table 5')
check('M1 indicator prose versus table',[],
      'Methods say the below-aspiration indicator is included in each model; Table 5 shows it only in Models 2 and 3.',
      'Not numerical; rounding does not apply.',
      'inconsistent','Origin follows explicit table; preserve prose reading as an uncertain, non-equivalent branch.',9,'Performance / indicator; PDF p. 11, Table 5')
check('Figure 3 probability versus marginal-effect labeling',[],
      'Figure title, vertical axis and discussion identify predicted probabilities; its note calls the values marginal effects.',
      'Not a numerical equality test; no values digitized.',
      'inconsistent','The manifest requests probabilities and derivatives separately.',13,'Figure 3 title, axis, note and Results')
check('Times described as quarter midpoints',[],
      'Named evaluation times 53,38,23,8 minutes are half a minute above exact midpoints of fifteen-minute quarters in a sixty-minute game.',
      'Exact midpoints lie at the half-minute boundary of rounding to integers; actual computational rounding is unspecified.',
      'cannot_assess','Use explicitly printed settings as origin, not silently substituted geometric midpoints.',12,'Table 6 and Figure 2 notes; PDF p. 9, Deadline Proximity')
check('H3 strength and significance coverage',['me4_4','me4_5','me4_6'],
      'Late above-aspiration effects are positive at every printed evaluation point, but stars weaken across columns and the final entry has no symbol.',
      'Every estimate/SE pair is assessed separately above using full intervals. No-star is not an exact p.',
      'consistent','Preserve the final prose qualification of weak support; not every late positive effect is declared significant by the table.',13,'Results / H3; PDF p. 12, Table 6')
check('Table 2 cumulative percentage for row six versus exact frequencies',[],
      'The sum of integer game frequencies through row six divided by game N, times 100, gives 99.6052631579. The printed cumulative percentage is 99.60. However, summing the already-rounded individual row percentages through that row gives exactly 99.60.',
      'Integer count operands in sealed_N_branch.json are exact. The printed cumulative interval [99.595,99.605] excludes 99.6052631579. Allowing each individual two-decimal percentage its own ±0.005 interval permits accumulated rounding of this magnitude.',
      'inconsistent','A narrow inconsistency with direct rounding of the exact count ratio, plausibly explained by summing rounded percentages. It is not evidence of contradictory integer counts and is not a replication verdict. All published counts/percentages remain in sealed_N_branch.json.',10,'Table 2 / six conversion attempts / cumulative percentage')
outputs['forensics.json']={'checks':checks}

# Make the bidirectional claim links complete without adding or changing targets.
for c in claims:
    for tid in c['supporting_results']:
        if c['claim_id'] not in byid[tid]['claim_ids']: byid[tid]['claim_ids'].append(c['claim_id'])

outputs['reader_notes.md']=pathlib.Path('work/notes.md').read_text(encoding='utf-8')

def validate():
    required={'claim_map.json','targets_sealed.json','manifest.json','sealed_N_branch.json','spec_space.json','documentation_assessment.json','forensics.json','reader_notes.md'}
    assert set(outputs)==required
    for f,obj in outputs.items():
        if f.endswith('.json'): assert json.loads(json.dumps(obj,ensure_ascii=False,allow_nan=False))==obj
    assert [c['claim_id'] for c in claims]==[f'C{i+1}' for i in range(len(claims))]
    assert [t['target_id'] for t in targets]==[f'T{i+1}' for i in range(len(targets))]
    ids={t['target_id'] for t in targets}; cids={c['claim_id'] for c in claims}
    for c in claims:
        assert set(c['supporting_results'])<=ids
        assert len(c['statement'].split())<=40,(c['claim_id'],len(c['statement'].split()))
    for t in targets:
        assert set(t['claim_ids'])<=cids
        assert t['N'] is None
    for f in checks: assert set(f['inputs'])<=ids
    def walk(obj):
        if isinstance(obj,dict):
            if set(obj)=={'doc','pdf_page','where'}:
                assert obj['doc']=='D01' and isinstance(obj['pdf_page'],int) and 1<=obj['pdf_page']<=19 and obj['where']
            for v in obj.values(): walk(v)
        elif isinstance(obj,list):
            for v in obj: walk(v)
    walk(outputs)
    for key in ['sample_steps','variables','models']:
        for item in manifest[key]: assert 'source' in item
    vn={v['name'] for v in variables}
    for m in models:
        assert set(m['regressors'])<=vn
        assert set(m['fixed_effects'])<=vn
        assert m['dependent'] in vn
        assert m['regressors'][:len(controls)]==controls
    text=json.dumps(manifest,ensure_ascii=False)
    for forbidden in ['Lehman','Hahn','Ramanujam','Alge','Organization Science','2011','22,603','22603','23,965','23965','1,520','1520','1,362','1362','0.669','0.883','0.0353','0.0039','5959','168.87','544.05','32 teams','six years','89.45','10.55','76.84','0.75','0.42']:
        assert forbidden not in text,forbidden
    notes=outputs['reader_notes.md']
    assert '\\[' not in notes and '\\]' not in notes
    assert sum(freq)==1520 and sum(i*n for i,n in enumerate(freq))==2385
    assert 23965-22603==1362
    for i,n in enumerate(freq):
        assert abs(100*n/1520-pcts[i])<=.005
        assert abs(sum(pcts[:i+1])-cumulative[i])<1e-8
    for n,k,pc in [(5280,323,6.12),(6532,552,8.45),(5267,468,8.89),(5524,1042,18.86),(22603,2385,10.55)]: assert abs(100*k/n-pc)<=.005
    incompatible=[f['what'] for f in checks if f['what'].startswith('Printed uncertainty') and f['result']!='consistent']
    return {'files':len(outputs),'claims':len(claims),'targets':len(targets),'main_models':len(models),'axes':len(axes),'levels':sum(len(a['levels']) for a in axes),'forensic_checks':len(checks),'star_checks_without_overlap':incompatible}

if __name__=='__main__':
    summary=validate()
    if '--publish' in sys.argv:
        out=pathlib.Path('out'); out.mkdir(exist_ok=True)
        assert not any((out/f).exists() for f in outputs),'Refusing to overwrite first submission'
        hashes={}
        for f,obj in outputs.items():
            content=obj if isinstance(obj,str) else json.dumps(obj,ensure_ascii=False,indent=2,allow_nan=False)+'\n'
            with (out/f).open('x',encoding='utf-8') as stream: stream.write(content)
            hashes[f]=hashlib.sha256((out/f).read_bytes()).hexdigest()
        pathlib.Path('work/submission_hashes.json').write_text(json.dumps(hashes,indent=2)+'\n',encoding='utf-8')
        for f in outputs:
            if f.endswith('.json'): json.loads((out/f).read_text(encoding='utf-8'))
        summary['published_and_hashed']=True
    print(json.dumps(summary,ensure_ascii=False,indent=2))
