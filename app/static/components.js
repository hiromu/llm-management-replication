// Shared presentation components. Scientific outcomes always come from the source files.
export const escapeHTML = v => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export const fmt = v => Number.isFinite(Number(v)) && v !== '' ? Number(v).toLocaleString('en-US', {maximumSignificantDigits: 6}) : '—';
export const LABELS = {'not assessed':'Not assessed','not attemptable':'Not attemptable',consistent:'Consistent',candidate:'Candidate · unverified',indeterminate:'Indeterminate',fragile:'Fragile inference','partially reproduced':'Partially reproduced','not reproduced (unverified)':'Not reproduced · unverified'};
// Okabe–Ito categorical colors, independent of the MPG page chrome.
export const COLORS = {consistent:'#0072b2',indeterminate:'#999999',candidate:'#d55e00',fragile:'#cc79a7'};
let helpId=0;
export function helpTerm(label, explanation) {
  const id=`help-${++helpId}`;
  return `<span class="term-wrap"><button type="button" class="term" aria-expanded="false" aria-describedby="${id}">${escapeHTML(label)}</button><span class="term-tip" role="tooltip" id="${id}">${escapeHTML(explanation)}</span></span>`;
}
export function ruleContext(rule) {
  return `<details class="rule-context"><summary>About rules</summary><p>${ruleNote(rule)}</p></details>`;
}
export function icon(name, size=18) {
  const paths = {
    chevronLeft:'<path d="m14 6-6 6 6 6"/>',
    chevronRight:'<path d="m10 6 6 6-6 6"/>',
    grid:'<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
    book:'<path d="M4 4h6a3 3 0 0 1 3 3v14a4 4 0 0 0-4-2H4zM13 7a3 3 0 0 1 3-3h5v15h-5a3 3 0 0 0-3 2"/>',
    play:'<path d="m9 5 11 7-11 7z"/>',arrow:'<path d="M5 12h14m-5-5 5 5-5 5"/>',
    plus:'<path d="M12 5v14M5 12h14"/>',check:'<path d="m5 12 4 4L19 6"/>',
    layers:'<path d="m12 3 10 5-10 5L2 8zM2 12l10 5 10-5M2 16l10 5 10-5"/>',
    file:'<path d="M14 2H5v20h14V7zM14 2v6h6M8 13h8M8 17h6"/>',
    search:'<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/>',
    download:'<path d="M12 3v12m-4-4 4 4 4-4M4 17v4h16v-4"/>',
    refresh:'<path d="M20 8a8 8 0 1 0 0 8M20 3v5h-5"/>',
    terminal:'<rect x="2" y="4" width="20" height="16" rx="3"/><path d="m6 9 3 3-3 3m7 0h4"/>',
    video:'<rect x="2" y="5" width="14" height="14" rx="2"/><path d="m16 10 6-4v12l-6-4"/>',
    external:'<path d="M14 3h7v7m0-7L10 14M10 3H3v18h18v-7"/>',
    close:'<path d="m6 6 12 12M6 18 18 6"/>',
    clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    shield:'<path d="m12 2 8 4v6c0 5-8 10-8 10S4 17 4 12V6z"/><path d="m8 11 3 3 5-5"/>',
    info:'<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7h.01"/>',
    dots:'<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
    stop:'<rect x="6" y="6" width="12" height="12" rx="1"/>'
    ,crop:'<path d="M6 2v14a2 2 0 0 0 2 2h14M2 6h14a2 2 0 0 1 2 2v14"/>'
  };
  return `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] || paths.file}</svg>`;
}
export function badge(outcome) {
  const cls = outcome === 'consistent' ? 'consistent' : outcome === 'partially reproduced' ? 'partial' : outcome.includes('unverified') || outcome === 'candidate' ? 'candidate' : outcome === 'fragile' ? 'fragile' : 'indeterminate';
  return `<span class="badge ${cls}"><span class="status-dot"></span>${escapeHTML(LABELS[outcome] || outcome)}</span>`;
}
export function evidenceBar(counts, total, large=false, unit='terms') {
  return `<div class="evidence-bar ${large?'large':''}" role="img" aria-label="${Object.entries(counts).map(([k,v])=>`${v} ${k}`).join(', ')}; ${total} ${escapeHTML(unit)}">${Object.entries(counts).filter(([,v])=>v).map(([k,v])=>`<span class="segment ${k==='not assessed'?'indeterminate':k}" style="width:${v/total*100}%" title="${v} ${LABELS[k] || k}"></span>`).join('')}</div>`;
}
export function legend() {
  return `<div class="legend">${['consistent','indeterminate','candidate','fragile'].map(k=>`<span><i style="background:${COLORS[k]}"></i>${k==='candidate'?'Candidate (unverified)':LABELS[k]}</span>`).join('')}</div>`;
}
export function ruleSelect(rule) {
  return `<label class="rule-select"><span class="sr-only">Comparison rule</span><select id="rule-select" aria-label="Comparison rule"><option value="study" ${rule==='study'?'selected':''}>Study · frozen</option><option value="common" ${rule==='common'?'selected':''}>Common · post hoc</option><option value="lenient" ${rule==='lenient'?'selected':''}>Lenient · post hoc</option></select></label>`;
}
export function ruleNote(rule) {
  return rule==='study' ? 'Original labels are retained. Term counts cover exported coefficient targets; paper verdicts also consider evidence outside these terms.' : 'Post hoc comparison, written after results were known. Coefficient targets only; F tests, fit diagnostics and text-only robustness are outside this view. Candidates remain formally indeterminate.';
}
export function distancePlot(row, rule='study') {
  if (!row.distances.length) return '<span class="muted">Not audited</span>';
  const max=6, w=130, ok=rule==='lenient'?2:1.5, grey=rule==='lenient'?4:3;
  const guide=rule==='study'?'':`<rect x="5" y="7" width="${w*ok/max}" height="12" rx="1" fill="#e5f1f8"/><rect x="${5+w*ok/max}" y="7" width="${w*(grey-ok)/max}" height="12" fill="#fff2d9"/>`;
  return `<svg class="distance-plot" viewBox="0 0 150 26" role="img" aria-label="Distance ${escapeHTML(row.distance_se)} published standard errors">${guide}<line x1="5" y1="13" x2="135" y2="13" stroke="#cccccc"/>${row.distances.map((d,i)=>`<circle cx="${5+Math.min(d,max)/max*w}" cy="${row.distances.length>1?9+i*8:13}" r="3.5" fill="${rule==='study'?'#777777':d<=ok?'#0072b2':d<=grey?'#e69f00':'#d55e00'}"/>`).join('')}<text x="148" y="17" text-anchor="end" fill="#777777" font-size="9">${Math.max(...row.distances)>6?'6+':''}</text></svg>`;
}
export function comparisonPlot(row) {
  const points=[...row.published_values,...row.reconstructed_values];
  if (!points.length) return '<p>No comparable values available.</p>';
  const reference=row.scale==='odds ratio'?1:0;
  const vals=[...points,reference];
  let min=Math.min(...vals), max=Math.max(...vals), pad=(max-min)*.3 || Math.abs(max)*.15 || .1;
  min-=pad; max+=pad;
  const x=v=>55+(v-min)/(max-min)*550;
  return `<svg class="comparison-plot" viewBox="0 0 660 150" role="img" aria-label="Published and reconstructed values on the ${row.scale}"><line x1="55" x2="605" y1="68" y2="68" stroke="#d9e0e4" stroke-width="2"/>${min<0&&max>0?`<line x1="${x(0)}" x2="${x(0)}" y1="35" y2="95" stroke="#b9c4cc" stroke-dasharray="3 3"/>`:''}${row.reconstructed_values.map((v,i)=>`<line x1="${x(row.published_values[0]??v)}" x2="${x(v)}" y1="${63+i*12}" y2="${63+i*12}" stroke="#cccccc" stroke-width="4"/><path d="M ${x(v)} ${55+i*12} l 7 8 -7 8 -7 -8 Z" fill="#d55e00"/>`).join('')}${row.published_values.map(v=>`<circle cx="${x(v)}" cy="63" r="7" fill="#fff" stroke="#0072b2" stroke-width="2.5"/>`).join('')}<text x="55" y="113" fill="#687783" font-size="12">${fmt(min)}</text><text x="605" y="113" text-anchor="end" fill="#687783" font-size="12">${fmt(max)}</text><text x="330" y="140" text-anchor="middle" fill="#687783" font-size="12">${escapeHTML(row.scale)}</text></svg>`;
}
