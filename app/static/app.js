import {DocumentPane,ArticleReader} from './media.js';
import {acrossView,bindAcross} from './across.js';
import {escapeHTML as e, icon, badge, evidenceBar, legend, ruleSelect, helpTerm, ruleContext, LABELS} from './components.js';

const state = {studies:[], jobs:[], rule:localStorage.getItem('replication.rule') || 'study', route:'overview', study:null, media:null, compare:'figure1', zoom:1, tab:'compare', token:'', selectedJob:null};
const root=document.querySelector('#app'), modal=document.querySelector('#modal');
let poll, renderVersion=0, mediaPanes=[],articleReader;
state.displayIndex=0;state.studyLogs=null;
function clearMedia(){articleReader?.destroy();articleReader=null;mediaPanes.forEach(p=>p.destroy());mediaPanes=[];}
const countsFor=s=>s.counts[state.rule];
const prettyDate=s=>new Date(s).toLocaleString('en-GB',{day:'2-digit',month:'short',hour:'2-digit',minute:'2-digit'});
const jobStatus=j=>`<span class="job-status ${e(j.status)}"><i></i>${e(j.status.replaceAll('_',' '))}</span>`;

async function api(path, body) {
  const r=await fetch(path,body===undefined?{}:{method:'POST',headers:{'Content-Type':'application/json','X-Workbench-Token':state.token},body:JSON.stringify(body)});
  const data=await r.json();
  if (!r.ok) throw Error(data.error||`Request failed (${r.status})`);
  return data;
}
function toast(message,error=false) {
  const t=document.querySelector('#toast'); t.textContent=message;t.className=`show ${error?'error':''}`;
  clearTimeout(t.timer);t.timer=setTimeout(()=>t.className='',5000);
}
function showModal(html) {
  modal.innerHTML=`<button class="modal-close icon-button" aria-label="Close dialog">${icon('close')}</button>${html}`;
  modal.querySelector('.modal-close').onclick=()=>modal.close();
  if(!modal.open) modal.showModal();
}
modal.addEventListener('click',ev=>{if(ev.target===modal){const r=modal.getBoundingClientRect();if(ev.clientX<r.left||ev.clientX>r.right||ev.clientY<r.top||ev.clientY>r.bottom)modal.close();}});

function shell(content) {
  clearMedia();
  const active=['study','studies','example'].includes(state.route)?'overview':state.route;
  if(!root.querySelector('.site-header'))root.innerHTML=`<header class="site-header"><div class="site-header-inner"><a class="brand" href="#overview">replication console</a><nav aria-label="Main navigation"><a href="#overview" aria-label="Studies">Studies</a><a href="#across">Across studies</a><a href="#runs" aria-label="Run manager">Runs<span id="active-run-count"></span></a></nav></div></header><div class="workspace"></div>`;
  root.querySelectorAll('.site-header nav a').forEach(a=>{if(a.hash==='#'+active)a.setAttribute('aria-current','page');else a.removeAttribute('aria-current');});
  root.querySelector('#active-run-count').textContent=state.jobs.filter(j=>['running','queued'].includes(j.status)).length||'';
  root.querySelector('.workspace').innerHTML=`<main id="main" tabindex="-1">${content}</main>`;
  bindCommon();
}
function title(eyebrow,heading,description,actions='') {
  const names={'Replication workspace.':'Studies','Explore the evidence.':'Studies','Run manager.':'Runs','Protocol & comparison rules.':'Protocol','See the workbench in action.':'Video'};
  return `<div class="page-heading"><div><h1>${names[heading]||heading}</h1></div><div class="heading-actions">${actions}</div></div>`;
}
function renderOverview(explorer=false) {
  const pending=state.jobs.filter(j=>j.kind==='research'&&!state.studies.some(s=>s.id===(j.result_study||j.result_id||j.study_id))&&j.status!=='stopped');
  const outcomes=state.studies.map(s=>s.paper_outcomes[state.rule]);
  const metrics=[
    [state.studies.length,'Studies','Studies with a saved paper-level assessment.'],
    [outcomes.filter(x=>x==='consistent').length,'Consistent','Paper-level consistent outcomes under the selected rule, read from saved study records.'],
    [outcomes.filter(x=>x==='partially reproduced').length,'Partial','Paper-level partially reproduced outcomes under the selected rule.'],
    [outcomes.filter(x=>!['consistent','partially reproduced'].includes(x)).length,'Indeterminate','Reviewed papers without a verified consistent or partial outcome, including unverified discrepancy candidates.']
  ];
  shell(`${title('','Studies','',`<button class="button secondary import-results" aria-label="Import results">Import results</button><button class="button primary new-study" aria-label="New replication">${icon('plus',16)} New replication</button>`)}
    <div class="overview-metrics">${metrics.map(([n,label,description])=>`<div class="metric"><strong>${n}</strong>${helpTerm(label,description)}</div>`).join('')}</div>
    <div class="section-heading"><span class="section-label">${state.studies.some(s=>s.imported)?'Studies & imports':'Studies'}</span><div class="rule-controls">${ruleContext(state.rule)}${ruleSelect(state.rule)}</div></div>
    <div class="panel collection-table"><div class="table-scroll"><table><thead><tr><th>Study</th><th>Journal</th><th>${helpTerm('Outcome','Paper-level scientific verdict. Focal claims, missing criteria and review determine it; a coefficient agreement rate does not.')}</th><th>${helpTerm('Agreement','Consistent saved assessment units divided by all exported units. Assessment units may include coefficients, claims or diagnostics. Consult each result before comparing denominators across studies.')}</th><th><span class="sr-only">Open</span></th></tr></thead><tbody>${state.studies.map(s=>{
      const c=countsFor(s);
      return `<tr class="study-card" data-study="${e(s.id)}"><td><a class="study-author" href="#study/${s.id}">${e(s.short)} <span>${s.year}</span></a></td><td class="journal-cell" title="${e(s.journal)}">${e(s.code)}</td><td>${badge(s.paper_outcomes[state.rule])}</td><td class="agreement-cell">${s.paper_outcomes[state.rule]==='not assessed'||!s.total?'<span class="unassessed-outcome">—</span>':`<span class="agreement-numbers">${c.consistent}<span> / ${s.total}</span></span>${evidenceBar(c,s.total,false,s.assessment_unit||'terms')}`}</td><td><a class="icon-button" href="#study/${s.id}" aria-label="Explore results">${icon('arrow',17)}</a></td></tr>`;
    }).join('')}${pending.map(j=>`<tr class="pending-study"><td><a href="#runs">${e(j.title)}</a></td><td>${e(j.journal)}</td><td>${e(j.status)}</td><td>Pending</td><td><a href="#runs">Logs →</a></td></tr>`).join('')}</tbody></table></div></div>
    <div class="collection-bottom">${legend()}</div>`);
}
const studyPath=()=>`${state.study.example?'example':'study'}/${state.study.id}`;
function renderAcross() {
  shell(acrossView(state.studies));
  root.querySelector('main').classList.add('across-main');
  bindAcross(root,renderAcross);
}
function renderStudy() {
  const s=state.study,isLogs=state.tab==='logs';
  shell(`<div class="study-heading"><div><h1>${e(s.short)} (${s.year})</h1></div>${s.example?'':`<a class="button secondary" href="/api/studies/${s.id}/export?rule=study" download aria-label="Export CSV">${icon('download',16)} CSV</a>`}</div>
    <nav class="study-pages" aria-label="Study pages"><a href="#${studyPath()}" ${!isLogs?'aria-current="page"':''}>Compare</a><a href="#${studyPath()}/logs" ${isLogs?'aria-current="page"':''}>Logs</a></nav>
    <section id="study-body" data-study="${e(s.id)}">${isLogs?studyLogsView():comparisonView()}</section>`);
  document.querySelector('main').classList.add('comparison-main');document.querySelector('main').classList.toggle('logs-main',isLogs);
  if(!isLogs)mountComparison();else mountLogStream();
}
function displayItems(){
  if(state.study.displays?.length)return state.study.displays;
  if(state.study.result_schema_version)return [{id:'unavailable',title:'Results',note:state.study.blockers?.join(' ')||'No reconstructed output is available.'}];
  const pairs=state.media.pairs.filter(p=>p.rebuilt);
  if(pairs.length)return pairs.map(p=>({id:p.id,title:p.label,media:p.rebuilt,pair:p}));
  return [{id:'unavailable',title:'Results',note:'No reconstructed output is available.'}];
}
const value=n=>n==null?'—':Number(n).toFixed(3);
const signed=n=>n==null?'—':`${n>=0?'+':'−'}${Math.abs(n).toFixed(3)}`;
function tableDisplay(d){
  return `<div class="table-reading-key"><span>Estimate (SE), Δ vs. original</span></div>
    <div class="reconstruction-table-scroll"><table class="reconstruction-table" data-columns="${d.columns.length}" data-compact="${d.rows.length<=6}"><thead><tr><th scope="col">${e(d.row_label||'Estimate')}</th>${d.columns.map(c=>`<th scope="col">${e(c)}</th>`).join('')}</tr></thead><tbody>${d.rows.map((r,ri)=>`<tr><th scope="row">${e(r.label)}</th>${r.cells.map((c,ci)=>`<td class="${c?c.distance_band:''}">${c?`<button class="estimate-cell" data-row="${ri}" data-col="${ci}" aria-label="${e(r.label)}, ${e(d.columns[ci])}: original ${value(c.published)}, reconstructed ${value(c.estimate)}, difference ${signed(c.delta)}, reconstructed standard error ${c.se===null?'unavailable':value(c.se)}"><strong>${c.estimate==null&&c.outcome_label?e(c.outcome_label):value(c.estimate)}</strong>${c.se===null?'':`<small>(${value(c.se)})</small>`}<span class="cell-delta">Δ ${signed(c.delta)}</span></button>`:'—'}</td>`).join('')}</tr>`).join('')}</tbody></table></div>
    <div id="cell-annotation" class="cell-annotation" aria-live="polite"></div>
`;
}
function annotateCell(d,row,col){
  const r=d.rows[row],c=r?.cells[col];if(!c)return;
  state.selectedCell={row,col};
  document.querySelectorAll('.estimate-cell').forEach(b=>b.setAttribute('aria-pressed',String(Number(b.dataset.row)===row&&Number(b.dataset.col)===col)));
  document.querySelectorAll('.reconstruction-table tbody tr').forEach((tr,i)=>{tr.classList.toggle('selected-row',i===row);[...tr.children].forEach((cell,j)=>cell.classList.toggle('selected-column',j===col+1));});
  document.querySelectorAll('.reconstruction-table thead th').forEach((th,i)=>th.classList.toggle('selected-column',i===col+1));
  document.querySelector('#cell-annotation').className=`cell-annotation ${c.distance_band}`;
  document.querySelector('#cell-annotation').innerHTML=`<div class="annotation-heading"><span>${e(r.label)} / ${e(d.columns[col])}${c.outcome_label?` · ${e(c.outcome_label)}`:''}</span></div><div class="annotation-values"><div><span>Original → replication</span><b>${value(c.published)} → ${value(c.estimate)}</b></div><div><span>Difference</span><b>Δ ${signed(c.delta)}</b></div><div><span>Distance</span><b>${c.distance_se===null?'Unavailable':c.distance_se.toFixed(2)+' published SE'}</b></div></div>`;
  const region=c.original_region;
  // Coordinates are valid only for the exact verified article, not arbitrary uploads.
  articleReader?.highlight(region&&!articleReader.source.placeholder&&articleReader.source.sha256===d.original?.sha256?{page:d.original.page,...region,label:`${r.label} / ${d.columns[col]}`} : null);
}
function comparisonView(){
  return `<div id="comparison-summary" class="comparison-summary"></div><div class="paired-results"><section class="replication-side" tabindex="0" aria-label="Replication results"><div class="comparison-column-title"><div><h2 id="display-label" aria-live="polite">LLM replication</h2><span id="display-subtitle"></span></div><div class="result-pager"><button id="previous-result" class="result-arrow" aria-label="Previous result" title="Previous result">${icon('chevronLeft',20)}</button><span id="display-count"></span><button id="next-result" class="result-arrow" aria-label="Next result" title="Next result">${icon('chevronRight',20)}</button></div></div><div id="replication-display"></div></section><section class="original-side"><div class="comparison-column-title"><div><h2>Original paper</h2><span id="source-caption"></span></div>${state.media.article?.placeholder&&!state.study.example?uploadControl('article','Upload PDF'):''}</div><div id="original-reader"></div></section></div>
`;
}
function mountComparison(){
  const d=displayItems()[0],source=d.pair?.original&&!d.pair.original.placeholder?d.pair.original:state.media.article;
  if(source?.kind==='pdf')articleReader=new ArticleReader(document.querySelector('#original-reader'),source,{onError:err=>toast(err.message,true)});
  else document.querySelector('#original-reader').innerHTML=state.study.example?'<div class="media-empty">Original PDF not attached. See setup instructions.</div>':`<div class="media-empty">${uploadControl('article','Add original PDF')}</div>`;
  bindMediaUploads();
  document.querySelector('#previous-result').onclick=()=>showComparison(state.displayIndex-1);
  document.querySelector('#next-result').onclick=()=>showComparison(state.displayIndex+1);
  document.querySelector('.replication-side').onkeydown=ev=>{if(ev.key==='ArrowLeft'||ev.key==='ArrowRight'){ev.preventDefault();showComparison(state.displayIndex+(ev.key==='ArrowLeft'?-1:1));}};
  showComparison(state.displayIndex);
}
async function showComparison(index){
  const items=displayItems();state.displayIndex=Math.max(0,Math.min(items.length-1,index));const d=items[state.displayIndex];
  document.querySelector('#display-label').textContent=`${d.title} · Replication`;
  document.querySelector('#display-subtitle').textContent=d.subtitle||'';
  document.querySelector('#source-caption').textContent=d.title;
  document.querySelector('#comparison-summary').innerHTML=d.rows?`<div class="table-agreement"><strong>${d.agreement.within_one_se} / ${d.agreement.compared}</strong> within 1 published SE</div>${d.sample?.length?`<div><strong>N = ${e(d.sample.join(' / '))}</strong> rebuilt${d.published_sample!=null?` / ${e(d.published_sample)} published`:''}</div>`:''}<div><strong>${e(LABELS[state.study.paper_outcomes.study]||state.study.paper_outcomes.study)}</strong></div>`:`<div><strong>${e(LABELS[state.study.paper_outcomes.study]||state.study.paper_outcomes.study)}</strong></div>`;
  articleReader?.highlight(null);
  document.querySelector('#display-count').textContent=`${state.displayIndex+1} / ${items.length}`;
  document.querySelector('#previous-result').disabled=state.displayIndex===0;
  document.querySelector('#next-result').disabled=state.displayIndex===items.length-1;
  mediaPanes.forEach(p=>p.destroy());mediaPanes=[];
  const host=document.querySelector('#replication-display');host.dataset.display=d.id;host.classList.toggle('has-table',!!d.rows);
  host.scrollTop=0;
  if(d.rows){host.innerHTML=tableDisplay(d);host.querySelectorAll('.estimate-cell').forEach(b=>b.onclick=()=>annotateCell(d,Number(b.dataset.row),Number(b.dataset.col)));const ri=d.rows.findIndex(r=>r.cells.some(Boolean));if(ri>=0)annotateCell(d,ri,d.rows[ri].cells.findIndex(Boolean));}
  else if(d.annotation){host.innerHTML=`<img class="replicated-figure" src="${e(d.media.url)}" alt="${e(d.title)}: ${e(d.subtitle)}"/><div class="figure-annotation"><strong>${e(d.annotation.heading)}</strong><p>${e(d.annotation.text.split(/(?<=\.) /)[0])}</p></div>`;}
  else if(d.media){host.innerHTML='<div id="result-image"></div>';const pane=new DocumentPane(host.querySelector('#result-image'),d.media,{label:'Reconstructed figure',crop:false,onError:err=>toast(err.message,true)});mediaPanes.push(pane);}
  else host.innerHTML=`<div class="media-empty">${e(d.note||'No reconstruction has been attached.')}</div>`;
  const source=d.pair?.original&&!d.pair.original.placeholder?d.pair.original:state.media.article;
  if(source?.kind==='pdf'&&articleReader?.source.id!==source.id){articleReader?.destroy();articleReader=new ArticleReader(document.querySelector('#original-reader'),source,{onError:err=>toast(err.message,true)});}
  const target=source?.placeholder?{page:1,y:0}:d.original?.sha256===source?.sha256?d.original:d.pair?.views?.original;
  if(articleReader&&target){const reader=articleReader,selected=d.id;await reader.ready;if(reader!==articleReader||displayItems()[state.displayIndex].id!==selected)return;try{await reader.goTo(target.page,target.y||0,false);if(reader===articleReader&&d.rows&&state.selectedCell)annotateCell(d,state.selectedCell.row,state.selectedCell.col);}catch(err){if(reader===articleReader)toast(err.message,true);}}
}
function studyLogsView(){
  const logs=state.studyLogs||{entries:[],jobs:[]};
  return `<div class="study-log-layout">${logs.timeline?.length?`<section class="execution-panel"><div class="execution-heading"><h2>Execution log</h2></div><pre id="study-log-stream" class="execution-stream" tabindex="0" aria-label="Execution log"></pre></section>`:''}<div class="log-documents">
    <details class="panel log-entry"><summary>Comparison details</summary>${displayItems().map(d=>d.rows?`<section><h3>${e(d.title)}</h3><p>${d.agreement.within_one_se} of ${d.agreement.compared} coefficients are within one published standard error. Reconstructed sample: ${e(d.sample?.join(' / ')||'Unavailable')}; published sample: ${e(d.published_sample??'Unavailable')}.</p><p>${e(d.note||'Descriptive coefficient distances do not determine the study outcome.')}</p></section>`:d.annotation?`<section><h3>${e(d.title)}</h3><p>${e(d.annotation.text)}</p><p>${e(d.note)}</p></section>`:'').join('')}</details>
    ${logs.jobs.map(j=>`<details class="panel log-entry"><summary>${e(j.phase)} · ${e(j.status)}</summary><pre class="console-log">${e(j.log)}</pre></details>`).join('')}
    <details class="panel log-entry" open><summary>Replication report · saved run</summary><pre class="report-text">${e(state.study.report||'No report attached.')}</pre></details>
    <details class="panel log-entry"><summary>Source records</summary><pre class="metadata-json">${e(JSON.stringify({displays:state.study.displays?.map(d=>({title:d.title,source:d.source,original:d.original})),article:state.media.article},null,2))}</pre></details>
    ${logs.entries.length?`<details class="panel log-entry source-files"><summary>Source files</summary>${logs.entries.map(l=>`<details class="log-file"><summary>${e(l.path)}</summary><pre class="report-text">${e(l.text)}</pre></details>`).join('')}</details>`:''}</div></div>`;
}

function mountLogStream(){
  const host=document.querySelector('#study-log-stream');if(!host)return;
  for(const event of state.studyLogs.timeline){
    const line=document.createElement('span');line.className='log-line';line.title=event.source+':'+event.line;line.textContent=event.text+'\n';host.append(line);
  }
  host.scrollTop=host.scrollHeight;
}

function uploadControl(slot,label){return `<label class="button secondary media-upload">${label}<input type="file" data-media-slot="${slot}" accept="${['article','original'].includes(slot)?'application/pdf,.pdf':'application/pdf,image/png,image/jpeg,image/webp,.pdf,.png,.jpg,.jpeg,.webp'}" aria-label="${slot==='article'?'Article PDF':slot==='original'?'Original PDF':'Rebuilt figure'}"></label>`;}
function bindMediaUploads(){
  root.querySelectorAll('[data-media-slot]').forEach(input=>input.onchange=async()=>{
    const file=input.files[0];if(!file)return;
    try{
      if(file.size>30*1024*1024)throw Error('Maximum file size is 30 MB.');
      const base64=await new Promise((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result.split(',')[1]);reader.onerror=reject;reader.readAsDataURL(file);});
      state.media=await api(`/api/studies/${state.study.id}/media`,{slot:input.dataset.mediaSlot,pair_id:state.compare,name:file.name,base64});
      renderStudy();
    }catch(err){toast(err.message,true);input.value='';}
  });
}
function renderRuns() {
  shell(`${title('','Runs','',`<button class="button primary new-study" aria-label="New replication">${icon('plus',16)} New replication</button>`)}
    <div id="job-detail">${state.selectedJob?jobDetail(state.selectedJob):''}</div><div class="section-heading"><h2>History <span class="count-pill">${state.jobs.length}</span></h2><button class="icon-button" id="refresh-runs" aria-label="Refresh runs">${icon('refresh',17)}</button></div><div id="jobs-list">${jobsView()}</div>`);
  document.querySelector('#refresh-runs').onclick=refreshJobs;
  bindJobs();
}
function jobsView() {
  if(!state.jobs.length) return `<div class="panel empty-runs">${icon('terminal',32)}<p>No runs yet.</p></div>`;
  return `<div class="panel runs-table"><table><thead><tr><th>Run / scope</th><th>Type</th><th>Status</th><th>Created</th><th></th></tr></thead><tbody>${state.jobs.map(j=>`<tr class="${state.selectedJob?.id===j.id?'selected':''}"><td><button class="term-link" data-job="${j.id}">${e(j.title)}</button></td><td><span class="tag">${e(j.kind.toUpperCase())}</span></td><td>${jobStatus(j)}</td><td class="small muted">${prettyDate(j.created)}</td><td><button class="button small secondary" data-job="${j.id}" aria-label="Open log">${icon('arrow',14)}</button></td></tr>`).join('')}</tbody></table></div>`;
}
function jobDetail(j) {
  return `<div class="panel job-panel"><div class="panel-top"><div><h2>${e(j.phase)}</h2></div><div class="job-actions">${j.kind==='research'&&!['queued','running'].includes(j.status)?`<button class="button secondary" data-launch="readiness" aria-label="Check readiness">${icon('shield',15)} Check</button><button class="button primary" data-launch="research" aria-label="Start research">${icon('play',15)} Research</button>`:''}${['running','queued','prepared'].includes(j.status)?`<button class="button danger" id="stop-run" aria-label="Stop run">${icon('stop',15)} Stop</button>`:''}${j.result_study?`<a class="button secondary" href="/api/jobs/${j.id}/result" download>${icon('download',15)} Result</a>`:''}</div></div>${j.result_study?`<a class="button primary run-results" href="#study/${j.result_study}">Compare results →</a>`:''}${j.kind==='research'&&!['queued','running'].includes(j.status)?`<label class="button secondary media-upload">Add source files<input type="file" id="run-sources" multiple aria-label="Add source files"></label>`:''}${j.kind==='research'?`<details class="job-workspace"><summary>Workspace</summary><code>${e(j.workspace||'Preparing…')}</code><p>Coordinator model requested: ${e(j.model)}. Model access and scientific completion require inspection of the actual outputs.</p></details>`:''}<div class="console-heading"><span>${icon('terminal',15)} Log</span>${jobStatus(j)}</div><pre class="console-log" id="console-log" tabindex="0">${e(j.log||'Waiting for captured output…')}</pre></div>`;
}
function bindJobs() {
  const sources=root.querySelector('#run-sources');
  if(sources)sources.onchange=async()=>{try{for(const file of sources.files){if(file.size>30*1024*1024)throw Error('Source file exceeds 30 MB.');const base64=await new Promise((resolve,reject)=>{const r=new FileReader();r.onload=()=>resolve(r.result.split(',')[1]);r.onerror=reject;r.readAsDataURL(file);});await api(`/api/jobs/${state.selectedJob.id}/sources`,{name:file.name,base64});}await refreshJobs();toast('Sources saved. Select Research to retry.');}catch(err){toast(err.message,true);}};

  root.querySelectorAll('[data-job]').forEach(b=>b.onclick=async()=>{try{state.selectedJob=await api('/api/jobs/'+b.dataset.job);renderRuns();document.querySelector('#job-detail').scrollIntoView({behavior:'smooth',block:'start'});}catch(err){toast(err.message,true);}});
  const stop=root.querySelector('#stop-run');
  if(stop) stop.onclick=async()=>{try{await api(`/api/jobs/${state.selectedJob.id}/stop`,{});await refreshJobs();toast('Run stopped; artifacts retained.');}catch(err){toast(err.message,true);}};
  root.querySelectorAll('[data-launch]').forEach(b=>b.onclick=()=>confirmLaunch(b.dataset.launch));
}
async function refreshJobs() {
  const version=renderVersion,previousJobs=JSON.stringify(state.jobs),previousDetail=JSON.stringify(state.selectedJob);
  const jobs=await api('/api/jobs');
  if(version!==renderVersion)return;
  state.jobs=jobs;
  if(['overview','studies'].includes(state.route)&&previousJobs!==JSON.stringify(state.jobs)){
    const collection=await api('/api/studies');if(version!==renderVersion)return;
    state.studies=collection.studies;renderOverview(state.route==='studies');
  }
  if(state.selectedJob){
    const detail=await api('/api/jobs/'+state.selectedJob.id);if(version!==renderVersion)return;
    state.selectedJob=detail;
  }
  if(state.route==='runs') {
    const logEl=document.querySelector('#console-log'),atBottom=logEl?logEl.scrollTop+logEl.clientHeight>=logEl.scrollHeight-25:true;
    const listChanged=previousJobs!==JSON.stringify(state.jobs),detailChanged=previousDetail!==JSON.stringify(state.selectedJob);
    if(listChanged)document.querySelector('#jobs-list').innerHTML=jobsView();
    if(detailChanged){
      const opened=[...document.querySelectorAll('#job-detail details')].map(d=>d.open);
      document.querySelector('#job-detail').innerHTML=state.selectedJob?jobDetail(state.selectedJob):'';
      document.querySelectorAll('#job-detail details').forEach((d,i)=>d.open=opened[i]||false);
    }
    if(listChanged||detailChanged)bindJobs();
    if(atBottom&&document.querySelector('#console-log')) document.querySelector('#console-log').scrollTop=1e7;
  }
  const active=document.querySelector('#active-run-count');if(active)active.textContent=state.jobs.filter(j=>['running','queued'].includes(j.status)).length||'';
}
function confirmLaunch(mode) {
  const j=state.selectedJob;
  showModal(`<h2 id="modal-title">${mode==='readiness'?'Check this workspace.':'Start this paper’s coordinator.'}</h2><p>${e(j.title)}</p><div class="notice">${mode==='readiness'?'Launch the pinned coordinator to inspect settings and missing inputs. It is instructed not to begin research, download data or run analysis. This invokes your locally authenticated Claude CLI.':'Authorize research for this paper only. The locally authenticated Claude CLI may download public sources, launch the protocol’s separate roles and run analysis. Usage is billed under your CLI account. Missing inputs or model access must be reported by the coordinator.'}</div><dl class="source-details"><dt>Requested model</dt><dd>${e(j.model)}</dd><dt>Workspace</dt><dd><code>${e(j.workspace)}</code></dd></dl><div class="modal-actions"><button class="button secondary" id="cancel-launch">Cancel</button><button class="button primary" id="confirm-launch">${icon('play',16)} ${mode==='readiness'?'Launch readiness check':'Authorize & launch'}</button></div>`);
  document.querySelector('#cancel-launch').onclick=()=>modal.close();
  document.querySelector('#confirm-launch').onclick=async ev=>{ev.currentTarget.disabled=true;try{await api(`/api/jobs/${j.id}/launch`,{mode});modal.close();await refreshJobs();toast('Coordinator launched. Inspect the live log for actual progress.');}catch(err){toast(err.message,true);ev.target.disabled=false;}};
}
function importResults() {
  showModal(`<h2 id="modal-title">Import results</h2><form id="import-form"><label class="upload-field">${icon('file',28)}<strong>Results JSON</strong><input name="results" type="file" accept="application/json,.json" required aria-label="Result JSON"></label><div class="form-error" id="import-error" role="alert"></div><div class="modal-actions"><button class="button secondary" type="button" id="cancel-import">Cancel</button><button class="button primary" type="submit">Import & explore</button></div></form>`);
  document.querySelector('#cancel-import').onclick=()=>modal.close();
  const form=document.querySelector('#import-form');
  form.onsubmit=async ev=>{
    ev.preventDefault();const button=form.querySelector('[type="submit"]');button.disabled=true;
    try {
      const file=form.results.files[0];if(file.size>20*1024*1024)throw Error('Result JSON must be at most 20 MB.');
      const result=await api('/api/results/import',JSON.parse(await file.text()));
      state.studies=(await api('/api/studies')).studies;
      modal.close();location.hash='#study/'+result.id;toast('Result record imported. Scientific outcomes remain unverified.');
    }catch(err){document.querySelector('#import-error').textContent=err.message;button.disabled=false;}
  };
}

function newStudy() {
  showModal(`<h2 id="modal-title">New study</h2><form id="new-study-form"><label class="field">Citation<input name="citation" required maxlength="1500" placeholder="Authors (year). Article title."></label><div class="form-grid"><label class="field">Study ID<input name="study_id" required pattern="[a-z][a-z0-9_]{2,63}" placeholder="author2026" title="3–64 lowercase letters, digits or underscores"></label><label class="field">Journal<input name="journal" placeholder="Journal name"></label></div><label class="field">DOI <span class="optional">optional</span><input name="doi" placeholder="10.…"></label><label class="upload-field" id="pdf-drop">${icon('file',28)}<strong>Article PDF</strong><span id="pdf-file-label">PDF · up to 30 MB</span><input type="file" name="article" accept="application/pdf,.pdf" required aria-label="Article PDF"></label><p>Starts replication using your configured Claude and Codex accounts. Model usage is billed to those accounts.</p><div class="form-error" id="form-error" role="alert"></div><div class="modal-actions"><button type="button" class="button secondary" id="cancel-new">Cancel</button><button class="button primary" type="submit" aria-label="Upload and start">Upload & start</button></div></form>`);
  const form=document.querySelector('#new-study-form');document.querySelector('#cancel-new').onclick=()=>modal.close();
  form.article.onchange=()=>{document.querySelector('#pdf-file-label').textContent=form.article.files[0]?.name||'PDF · up to 30 MB';};
  form.onsubmit=async ev=>{
    ev.preventDefault();const submit=form.querySelector('[type="submit"]');submit.disabled=true;submit.textContent='Uploading…';
    try {
      const file=form.article.files[0];if(file.size>30*1024*1024)throw Error('PDF exceeds the 30 MB limit.');
      const base64=await new Promise((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result.split(',')[1]);reader.onerror=reject;reader.readAsDataURL(file);});
      const j=await api('/api/jobs/submit',{citation:form.citation.value,study_id:form.study_id.value,journal:form.journal.value,doi:form.doi.value,pdf_base64:base64});
      modal.close();state.selectedJob=await api('/api/jobs/'+j.id);state.jobs=await api('/api/jobs');if(location.hash==='#runs')renderRuns();else location.hash='#runs';toast(j.status==='failed'?'Upload saved. See the log for the launch issue.':'PDF uploaded.');
    }catch(err){document.querySelector('#form-error').textContent=err.message;submit.disabled=false;submit.textContent='Upload & start';}
  };
}

async function renderProtocol() {
  const p=await api('/api/protocol');
  shell(`${title('SCIENTIFIC INTERPRETATION','Protocol & comparison rules.','Keep the original study decisions separate from exploratory cross-study comparisons.')}
    <div class="protocol-grid"><div class="panel protocol-panel"><h2>Frozen study rules</h2><p>Each study fixes its sample decisions, analysis grid, tolerances and paper-level aggregation before fitting. These rules determine the archived protocol outcome.</p><ul><li>Two independent readers, with disagreements retained.</li><li>Three independent implementations; compare implementations first.</li><li>Published targets withheld from implementers.</li><li>Candidate discrepancies require independent-family adversarial review and human confirmation.</li></ul><div class="notice">Inspect each saved report for reviewer independence and unresolved limitations. A candidate discrepancy is not a verified finding.</div></div><div class="panel protocol-panel"><h2>Common v1 & lenient</h2><p class="small muted">Defined after results were known · 28 October 2026</p><p>These rules rescore saved coefficient estimates. They do not replace original study verdicts and do not refit empirical models.</p><table class="rule-table"><thead><tr><th>Criterion</th><th>Common v1</th><th>Lenient</th></tr></thead><tbody><tr><td>Magnitude · consistent</td><td>≤ 1.5 pub. SE</td><td>≤ 2.0 pub. SE</td></tr><tr><td>Magnitude · candidate</td><td>&gt; 3.0 pub. SE</td><td>&gt; 4.0 pub. SE</td></tr><tr><td>N gap &gt; 15%</td><td>Indeterminate</td><td>Blocks candidates</td></tr><tr><td>Inference</td><td colspan="2">Two or more significance bands weaker → candidate</td></tr></tbody></table><p class="small muted">Intermediate distances are grey zones. Sign comparisons apply to published p &lt; .10; stronger significance is not a failure under the common rule. Missing published SE can leave magnitude unaudited.</p></div></div><div class="panel protocol-panel"><h2>What the shared components preserve</h2><div class="principles"><div><h3>Correct scales</h3><p>Each saved result records its display scale. Source values, transformations and distances remain inspectable.</p></div><div><h3>Uncertainty & coverage</h3><p>Missing SEs remain missing, multiple reader origins remain separate, and excluded F tests or diagnostics are disclosed.</p></div><div><h3>Separate levels</h3><p>Coefficient agreement percentages never become paper-level success rates. Focal structure and review govern scientific verdicts.</p></div></div><details><summary>Original common-rule specification</summary><pre class="metadata-json">${e(JSON.stringify(p.rules,null,2))}</pre></details><details><summary>Full execution workflow</summary><pre class="report-text">${e(p.workflow)}</pre></details></div>`);
}
function bindCommon() {
  root.querySelectorAll('.term').forEach(b=>b.onclick=()=>b.setAttribute('aria-expanded',b.getAttribute('aria-expanded')!=='true'));
  root.querySelectorAll('.new-study').forEach(b=>b.onclick=newStudy);
  root.querySelectorAll('.import-results').forEach(b=>b.onclick=importResults);
  const sel=root.querySelector('#rule-select');if(sel)sel.onchange=ev=>{state.rule=ev.target.value;localStorage.setItem('replication.rule',state.rule);if(state.route==='study')renderStudy();else renderOverview(state.route==='studies');};
}
async function route() {
  const version=++renderVersion;
  const parts=location.hash.slice(1).split('/');state.route=parts[0]||'overview';
  try {
    if(state.route==='example'){location.replace('#study/'+encodeURIComponent(parts[1])+(parts[2]==='logs'?'/logs':''));return;}
    else if(state.route==='study') {
      const [s,media]=await Promise.all([api('/api/studies/'+encodeURIComponent(parts[1])),api('/api/studies/'+encodeURIComponent(parts[1])+'/media')]);if(version!==renderVersion)return;
      state.media=media;state.compare=media.pairs[0]?.id||'figure1';state.zoom=1;
      state.study=s;state.studyLogs=parts[2]==='logs'?await api('/api/studies/'+encodeURIComponent(parts[1])+'/logs'):null;state.displayIndex=0;state.tab=parts[2]==='logs'?'logs':'compare';renderStudy();
    } else if(state.route==='runs'){state.jobs=await api('/api/jobs');if(version!==renderVersion)return;renderRuns();}
    else if(state.route==='across'){
      const collection=await api('/api/studies');if(version!==renderVersion)return;
      state.studies=collection.studies;renderAcross();
    }
    else if(state.route==='protocol')await renderProtocol();
    else {
      // Return from a run with both saved results and current job states.
      // A stale waiting job may have a different provisional result_id.
      const [collection,jobs]=await Promise.all([api('/api/studies'),api('/api/jobs')]);
      if(version!==renderVersion)return;
      state.studies=collection.studies;state.jobs=jobs;
      state.route=state.route==='studies'?'studies':'overview';renderOverview(state.route==='studies');
    }
    window.scrollTo(0,0);document.title='replication console';
  }catch(err){shell(`<div class="panel error-page"><h1>Could not open this view.</h1><p>${e(err.message)}</p><a class="button primary" href="#overview">Back to overview</a></div>`);}
}
async function boot() {
  try {
    const [collection,jobs,token]=await Promise.all([api('/api/studies'),api('/api/jobs'),api('/api/token')]);
    state.studies=collection.studies;state.jobs=jobs;state.token=token.token;
    if(!['study','common','lenient'].includes(state.rule))state.rule='study';
    await route();
    
    poll=setInterval(()=>{if(state.route==='runs')refreshJobs().catch(err=>toast(err.message,true));},2000);
  }catch(err){root.innerHTML=`<div class="initial-loading">Unable to load the repository: ${e(err.message)}</div>`;}
}
window.addEventListener('hashchange',route);
window.addEventListener('beforeunload',()=>clearInterval(poll));
boot();
