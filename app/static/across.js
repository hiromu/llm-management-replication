import {escapeHTML as e, badge} from './components.js';

// Documented replication issues; not an exhaustive audit.
// Outcomes are the report's study-specific classifications, never term percentages.
export const issueTypes = [
  ['sample','Sample definition'], ['missing','Missing data'],
  ['variables','Variable construction'], ['targets','Conflicting targets'],
  ['uncertainty','Reported uncertainty'], ['calculation','Calculation choices'],
];
let filter='all';

export function acrossView(availableStudies) {
  const cohort=availableStudies.filter(s=>s.issues).map(s=>({...s,name:s.short,outcome:s.paper_outcomes.study}));
  const rows=cohort.filter(s=>filter==='all'||s.issues[filter]);
  return `<div class="page-heading"><h1>Across studies</h1></div>
    <div class="across-outcomes" aria-label="Reviewed study outcomes">
      <span><strong>${cohort.length}</strong> studies</span>${[['consistent','Consistent'],['partially reproduced','Partially reproduced'],['indeterminate','Indeterminate']].map(([key,label])=>`<span><strong>${cohort.filter(s=>s.outcome===key).length}</strong> ${label}</span>`).join('')}
    </div>
    <section class="issue-index" aria-labelledby="issue-heading">
      <div class="issue-toolbar"><h2 id="issue-heading">Reported issues</h2><label>Issue <select id="issue-filter" aria-label="Issue"><option value="all">All issues</option>${issueTypes.map(([key,label])=>`<option value="${key}" ${key===filter?'selected':''}>${label} (${cohort.filter(s=>s.issues[key]).length})</option>`).join('')}</select></label></div>
      <div class="issue-matrix-scroll" tabindex="0" role="region" aria-label="Studies and documented issues"><table class="issue-matrix"><caption class="sr-only">Documented issues from saved study reports. A dash means no issue documented in the source review, not a verified absence.</caption><thead><tr><th scope="col">Study</th>${issueTypes.map(([key,label])=>`<th scope="col" class="${filter===key?'filtered-issue':''}">${e(label)}</th>`).join('')}</tr></thead><tbody>${rows.map(s=>`<tr data-review-study="${s.id}"><th scope="row"><div class="issue-study"><div class="issue-study-label"><span class="issue-study-name">${e(s.name)} <small>${s.year}</small></span>${badge(s.outcome)}</div><a class="button secondary issue-open" href="#study/${s.id}" aria-label="Open ${e(s.name)}">Open</a></div></th>${issueTypes.map(([key,label])=>`<td class="${filter===key?'filtered-issue':''}">${s.issues[key]?`<span class="issue-cell" role="img" aria-label="${e(s.name)}: ${e(label)} — documented issue">●</span>`:'<span class="issue-unrecorded" aria-label="No issue documented in this review">—</span>'}</td>`).join('')}</tr>`).join('')}</tbody></table></div>
      <div class="issue-key"><span><span class="issue-key-mark" aria-hidden="true">●</span> Documented issue</span><span>— Not documented in review</span><span id="issue-result-count">${rows.length} ${rows.length===1?'study':'studies'}</span></div>
    </section>`;
}
export function bindAcross(host,rerender) {
  host.querySelector('#issue-filter').onchange=ev=>{
    filter=ev.target.value;
    rerender();host.querySelector('#issue-filter').focus();
  };
}
