import {escapeHTML as e, icon, fmt} from './components.js';

let pdfModule;
async function pdfjs(){
  if(!pdfModule){pdfModule=await import('/vendor/pdfjs/pdf.min.mjs');pdfModule.GlobalWorkerOptions.workerSrc='/vendor/pdfjs/pdf.worker.min.mjs';}
  return pdfModule;
}
const full=()=>({x:0,y:0,w:1,h:1});

/** One renderer for article pages, original figures and reconstructed figures. */
export class DocumentPane {
  constructor(root,source,{label='PDF',view={},crop=true,reference=false,onView=()=>{},onError=()=>{}}={}){
    this.root=root;this.reference=reference;this.source=source;this.label=label;this.page=view.page||1;this.crop=view.crop||full();this.zoom=1;this.onView=onView;this.onError=onError;this.serial=0;this.disposed=false;
    root.innerHTML=`<div class="document-toolbar"><div class="page-controls"><button class="icon-button page-prev" aria-label="Previous ${label} page">←</button><input type="number" class="page-number" min="1" value="${this.page}" aria-label="${label} page"><span class="page-count">/ —</span><button class="icon-button page-next" aria-label="Next ${label} page">→</button></div><span class="document-name" title="${e(source.name)}">${e(source.name)}</span><div class="document-actions">${crop?`<button class="icon-button crop-toggle" aria-label="Crop ${label}" title="Crop">${icon('crop',16)}</button><button class="icon-button crop-reset" aria-label="Reset ${label} crop" title="Reset crop">${icon('refresh',15)}</button>`:''}<a class="icon-button" href="${e(source.url)}" download aria-label="Download ${label}" title="Download">${icon('download',15)}</a></div></div><div class="document-viewport" tabindex="0" aria-label="${label} document"><div class="document-content"><canvas aria-label="${label} page rendering"></canvas><div class="crop-selection" hidden></div></div><span class="document-loading" role="status">Loading…</span></div>`;
    this.viewport=root.querySelector('.document-viewport');this.content=root.querySelector('.document-content');this.canvas=root.querySelector('canvas');this.loading=root.querySelector('.document-loading');
    root.querySelector('.page-prev').onclick=()=>this.changePage(this.page-1);
    root.querySelector('.page-next').onclick=()=>this.changePage(this.page+1);
    root.querySelector('.page-number').onchange=ev=>this.changePage(Number(ev.target.value));
    const toggle=root.querySelector('.crop-toggle');if(toggle)toggle.onclick=()=>{this.cropping=!this.cropping;toggle.setAttribute('aria-pressed',!!this.cropping);this.viewport.classList.toggle('cropping',!!this.cropping);};
    const reset=root.querySelector('.crop-reset');if(reset)reset.onclick=()=>{this.crop=full();this.emit();this.paint();};
    if(reference&&source.kind==='pdf'){
      const actions=root.querySelector('.document-actions');
      const toggle=document.createElement('button');toggle.type='button';toggle.className='button small secondary';toggle.textContent='Page';toggle.setAttribute('aria-label','Show full original PDF page');
      toggle.onclick=()=>{this.fullPage=!this.fullPage;toggle.textContent=this.fullPage?'Figure':'Page';toggle.setAttribute('aria-label',this.fullPage?'Show original PDF crop':'Show full original PDF page');this.paint();};
      actions.prepend(toggle);this.pageToggle=toggle;
      const shot=document.createElement('button');shot.type='button';shot.className='button small secondary';shot.textContent='PNG';shot.setAttribute('aria-label','Save original PDF crop as PNG');
      shot.onclick=()=>this.saveScreenshot();actions.prepend(shot);
    }
    this.bindPointers();
    this.resize=new ResizeObserver(()=>this.fit());this.resize.observe(this.viewport);
    this.ready=this.load().catch(err=>{if(this.disposed)return;this.loading.textContent='Could not open this file.';this.onError(err);});
  }
  async load(){
    if(this.source.kind==='pdf'){
      const lib=await pdfjs();if(this.disposed)return;
      this.task=lib.getDocument({url:this.source.url,isEvalSupported:false,standardFontDataUrl:'/vendor/pdfjs/standard_fonts/',cMapUrl:'/vendor/pdfjs/cmaps/',cMapPacked:true,wasmUrl:'/vendor/pdfjs/wasm/'});
      this.pdf=await this.task.promise;if(this.disposed)return;
      this.pages=this.pdf.numPages;
      if(this.page<1||this.page>this.pages)throw Error(`Page ${this.page} is unavailable in this ${this.pages}-page PDF.`);
    }else{
      const image=new Image();image.src=this.source.url;await image.decode();if(this.disposed)return;
      this.image=image;this.pages=1;
    }
    this.root.querySelector('.page-count').textContent='/ '+this.pages;
    this.root.querySelector('.page-number').max=this.pages;
    await this.render();
  }
  async changePage(page){
    if(this.domain)return;
    if(!Number.isInteger(page)||page<1||page>this.pages){this.root.querySelector('.page-number').value=this.page;return;}
    if(page===this.page)return;
    this.page=page;this.crop=full();this.fullPage=false;this.updatePageToggle();this.emit();await this.render();
  }
  emit(){this.onView({page:this.page,crop:{...this.crop}});}
  async render(){
    const serial=++this.serial;
    this.raw=null;delete this.canvas.dataset.ready;this.canvas.style.visibility='hidden';
    this.loading.hidden=false;this.loading.textContent='Loading…';
    this.root.querySelector('.page-number').value=this.page;
    this.root.querySelector('.page-prev').disabled=!!this.domain||this.page<=1;
    this.root.querySelector('.page-next').disabled=!!this.domain||this.page>=this.pages;
    if(this.pdf){
      const page=await this.pdf.getPage(this.page);if(this.disposed||serial!==this.serial)return;
      const viewport=page.getViewport({scale:2});const raw=document.createElement('canvas');
      raw.width=Math.ceil(viewport.width);raw.height=Math.ceil(viewport.height);
      await page.render({canvasContext:raw.getContext('2d'),viewport,annotationMode:0,background:'white'}).promise;
      if(this.disposed||serial!==this.serial)return;this.raw=raw;
    }else this.raw=this.image;
    this.loading.hidden=true;this.paint();
  }
  setProjection(domain,shared){
    if(this.reference)return;
    this.domain=domain;this.shared=shared;this.paint();
    for(const selector of ['.crop-toggle','.crop-reset','.page-number']){const b=this.root.querySelector(selector);if(b)b.disabled=!!domain;}
    this.root.querySelector('.page-prev').disabled=!!domain||this.page<=1;
    this.root.querySelector('.page-next').disabled=!!domain||this.page>=this.pages;
  }
  paint(){
    if(!this.raw||this.disposed)return;
    const rw=this.raw.naturalWidth||this.raw.width,rh=this.raw.naturalHeight||this.raw.height,c=this.fullPage?full():this.crop;
    if(this.domain&&this.shared){
      const d=this.domain,s=this.shared,pad={left:75,top:25,right:25,bottom:60},w=1000,h=700;
      this.canvas.width=w+pad.left+pad.right;this.canvas.height=h+pad.top+pad.bottom;
      const ctx=this.canvas.getContext('2d');ctx.fillStyle='white';ctx.fillRect(0,0,this.canvas.width,this.canvas.height);
      const x=v=>pad.left+(v-s.xmin)/(s.xmax-s.xmin)*w,y=v=>pad.top+(s.ymax-v)/(s.ymax-s.ymin)*h;
      ctx.drawImage(this.raw,c.x*rw,c.y*rh,c.w*rw,c.h*rh,x(d.xmin),y(d.ymax),x(d.xmax)-x(d.xmin),y(d.ymin)-y(d.ymax));
      ctx.strokeStyle='#cccccc';ctx.strokeRect(pad.left,pad.top,w,h);ctx.fillStyle='#555555';ctx.font='18px "Noto Sans"';
      for(let i=0;i<=4;i++){let xv=s.xmin+(s.xmax-s.xmin)*i/4,yv=s.ymin+(s.ymax-s.ymin)*i/4;ctx.textAlign='center';ctx.fillText(fmt(xv),x(xv),h+pad.top+32);ctx.textAlign='right';ctx.fillText(fmt(yv),pad.left-12,y(yv)+6);}
      this.canvas.dataset.domain=JSON.stringify(s);
    }else{
      this.canvas.width=Math.max(1,Math.round(c.w*rw));this.canvas.height=Math.max(1,Math.round(c.h*rh));
      const ctx=this.canvas.getContext('2d');ctx.fillStyle='white';ctx.fillRect(0,0,this.canvas.width,this.canvas.height);
      ctx.drawImage(this.raw,c.x*rw,c.y*rh,c.w*rw,c.h*rh,0,0,this.canvas.width,this.canvas.height);
      delete this.canvas.dataset.domain;
    }
    this.canvas.dataset.ready='true';this.canvas.style.visibility='visible';this.fit();
    this.canvas.dataset.source=this.source.url;this.canvas.dataset.page=this.page;this.canvas.dataset.crop=JSON.stringify(c);this.canvas.dataset.view=this.fullPage?'page':'crop';
  }
  updatePageToggle(){if(this.pageToggle){this.pageToggle.textContent=this.fullPage?'Figure':'Page';this.pageToggle.setAttribute('aria-label',this.fullPage?'Show original PDF crop':'Show full original PDF page');}}
  saveScreenshot(){
    if(!this.raw||!this.loading.hidden)return;
    // Export the rasterized source region directly; never pass through estimates or axis projection.
    const w=this.raw.naturalWidth||this.raw.width,h=this.raw.naturalHeight||this.raw.height,c=this.crop,out=document.createElement('canvas');out.width=Math.max(1,Math.round(c.w*w));out.height=Math.max(1,Math.round(c.h*h));
    out.getContext('2d').drawImage(this.raw,c.x*w,c.y*h,c.w*w,c.h*h,0,0,out.width,out.height);
    out.toBlob(blob=>{if(!blob)return;const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=`${this.source.name.replace(/\.pdf$/i,'')}-p${this.page}-crop.png`;a.click();setTimeout(()=>URL.revokeObjectURL(url),5000);},'image/png');
  }
  setZoom(zoom){this.zoom=zoom;this.fit();}
  fit(){
    if(!this.canvas.width||!this.viewport.clientWidth)return;
    const fit=Math.min((this.viewport.clientWidth-30)/this.canvas.width,(this.viewport.clientHeight-30)/this.canvas.height);
    this.content.style.width=Math.max(1,this.canvas.width*fit*this.zoom)+'px';
    this.content.style.height=Math.max(1,this.canvas.height*fit*this.zoom)+'px';
  }
  bindPointers(){
    let start;
    const selection=this.root.querySelector('.crop-selection');
    this.content.onpointerdown=ev=>{
      if(!this.cropping||!this.raw||!this.loading.hidden)return;
      ev.preventDefault();const r=this.content.getBoundingClientRect();start={x:Math.max(0,Math.min(1,(ev.clientX-r.left)/r.width)),y:Math.max(0,Math.min(1,(ev.clientY-r.top)/r.height))};
      this.content.setPointerCapture(ev.pointerId);selection.hidden=false;selection.style.cssText=`left:${start.x*100}%;top:${start.y*100}%;width:0;height:0`;
    };
    this.content.onpointermove=ev=>{
      if(!start)return;const r=this.content.getBoundingClientRect(),x=Math.max(0,Math.min(1,(ev.clientX-r.left)/r.width)),y=Math.max(0,Math.min(1,(ev.clientY-r.top)/r.height));
      selection.style.left=Math.min(x,start.x)*100+'%';selection.style.top=Math.min(y,start.y)*100+'%';selection.style.width=Math.abs(x-start.x)*100+'%';selection.style.height=Math.abs(y-start.y)*100+'%';
    };
    this.content.onpointerup=ev=>{
      if(!start)return;const r=this.content.getBoundingClientRect(),x=Math.max(0,Math.min(1,(ev.clientX-r.left)/r.width)),y=Math.max(0,Math.min(1,(ev.clientY-r.top)/r.height));
      const w=Math.abs(x-start.x),h=Math.abs(y-start.y);
      if(w>.02&&h>.02){const c=this.fullPage?full():this.crop;this.crop={x:c.x+Math.min(x,start.x)*c.w,y:c.y+Math.min(y,start.y)*c.h,w:w*c.w,h:h*c.h};this.fullPage=false;this.updatePageToggle();this.emit();this.paint();}
      start=null;selection.hidden=true;this.cropping=false;this.viewport.classList.remove('cropping');this.root.querySelector('.crop-toggle')?.setAttribute('aria-pressed','false');
    };
  }
  destroy(){this.disposed=true;this.serial++;this.resize.disconnect();if(this.task)this.task.destroy().catch(()=>{});}
}

export function linkPans(panes){
  let syncing=false;
  const listeners=panes.map(p=>{const fn=()=>{
    if(syncing)return;syncing=true;
    const x=p.scrollLeft/Math.max(1,p.scrollWidth-p.clientWidth),y=p.scrollTop/Math.max(1,p.scrollHeight-p.clientHeight);
    for(const other of panes)if(other!==p){other.scrollLeft=x*(other.scrollWidth-other.clientWidth);other.scrollTop=y*(other.scrollHeight-other.clientHeight);}
    requestAnimationFrame(()=>syncing=false);
  };p.addEventListener('scroll',fn);return [p,fn];});
  return ()=>listeners.forEach(([p,f])=>p.removeEventListener('scroll',f));
}

/** A continuous, scrollable original PDF. Navigation never redraws source values. */
export class ArticleReader {
  constructor(root,source,{page=1,y=0,onError=()=>{}}={}){
    this.root=root;this.source=source;this.disposed=false;this.nodes=[];this.renders=new Map();this.onError=onError;this.navigation=0;
    root.innerHTML=`<div class="reader-toolbar"><span title="${e(source.name)}">PDF</span><label>Page <input type="number" min="1" aria-label="Original PDF page" value="${page}"></label><a href="${e(source.url)}" download aria-label="Download original PDF">${icon('download',16)}</a></div><div class="pdf-scroll" aria-label="Original article PDF" tabindex="0"></div>`;
    this.scroll=root.querySelector('.pdf-scroll');this.input=root.querySelector('input');this.input.onchange=()=>this.goTo(Number(this.input.value)).catch(err=>this.reportError(err));
    this.ready=this.load(page,y).catch(err=>{if(!this.disposed){this.scroll.textContent='Could not open the original PDF.';onError(err);}});
  }
  async load(page,y){
    const lib=await pdfjs();if(this.disposed)return;
    this.task=lib.getDocument({url:this.source.url,isEvalSupported:false,standardFontDataUrl:'/vendor/pdfjs/standard_fonts/',cMapUrl:'/vendor/pdfjs/cmaps/',cMapPacked:true,wasmUrl:'/vendor/pdfjs/wasm/'});
    this.pdf=await this.task.promise;if(this.disposed)return;this.input.max=this.pdf.numPages;
    for(let n=1;n<=this.pdf.numPages;n++){
      const p=await this.pdf.getPage(n);if(this.disposed)return;const v=p.getViewport({scale:1});
      const box=document.createElement('section');box.className='pdf-sheet';box.dataset.page=n;box.style.aspectRatio=`${v.width}/${v.height}`;box.innerHTML=`<canvas aria-label="Original PDF page ${n}"></canvas><span class="pdf-page-label">${n}</span>`;this.scroll.append(box);this.nodes.push({box,page:p,viewport:v});
    }
    this.observer=new IntersectionObserver(entries=>{for(const entry of entries)if(entry.isIntersecting)this.render(Number(entry.target.dataset.page)).catch(err=>this.reportError(err));},{root:this.scroll,rootMargin:'500px'});
    this.nodes.forEach(n=>this.observer.observe(n.box));
    this.viewportWidth=this.scroll.clientWidth;
    this.scroll.onscroll=()=>{
      // Keep a page-relative anchor; a width change must not turn into a new reading position.
      if(this.scroll.clientWidth!==this.viewportWidth)return;
      const target=this.nodes.find(n=>n.box.offsetTop+n.box.offsetHeight>this.scroll.scrollTop+30);
      if(target){this.input.value=target.box.dataset.page;this.readingPosition={page:Number(target.box.dataset.page),y:Math.max(0,(this.scroll.scrollTop-target.box.offsetTop)/target.box.offsetHeight)};}
    };
    await this.goTo(page,y,false);
    if(this.disposed)return;
    this.resize=new ResizeObserver(()=>{
      const width=this.scroll.clientWidth;if(!width||width===this.viewportWidth)return;
      this.viewportWidth=width;const anchor=this.readingPosition;
      if(anchor)this.goTo(anchor.page,anchor.y,false).catch(err=>this.reportError(err));
    });
    this.resize.observe(this.scroll);
  }
  async render(n){
    if(this.disposed||this.renders.has(n))return this.renders.get(n);
    const node=this.nodes[n-1];if(!node)return;
    const pending=(async()=>{const v=node.page.getViewport({scale:2});const canvas=node.box.querySelector('canvas');canvas.width=Math.ceil(v.width);canvas.height=Math.ceil(v.height);await node.page.render({canvasContext:canvas.getContext('2d'),viewport:v,annotationMode:0,background:'white'}).promise;if(!this.disposed)canvas.dataset.ready='true';})();
    this.renders.set(n,pending);return pending;
  }
  async goTo(page,y=0,smooth=true){
    const n=Number(page);if(this.disposed||!Number.isInteger(n)||!this.nodes[n-1])return;
    const navigation=++this.navigation;this.root.dataset.targetPage=n;this.input.value=n;
    const node=this.nodes[n-1];await this.render(n);if(this.disposed||navigation!==this.navigation)return;
    this.readingPosition={page:n,y};
    this.scroll.scrollTo({top:node.box.offsetTop+y*node.box.offsetHeight,behavior:smooth&&!matchMedia('(prefers-reduced-motion: reduce)').matches?'smooth':'instant'});
  }
  highlight(region){
    this.root.querySelectorAll('.pdf-highlight').forEach(el=>el.remove());
    if(!region||this.disposed)return;
    const node=this.nodes[region.page-1];if(!node)return;
    for(const [kind,box] of [['row',region.row],['column',region.column],['cell',region.cell]]){
      if(!box)continue;
      const el=document.createElement('div');el.className=`pdf-highlight pdf-highlight-${kind}`;
      el.style.cssText=`left:${box.x*100}%;top:${box.y*100}%;width:${box.w*100}%;height:${box.h*100}%`;
      el.setAttribute('aria-hidden','true');el.dataset.reference=region.label;node.box.append(el);
    }
  }
  reportError(err){if(!this.disposed)this.onError(err);}
  destroy(){this.disposed=true;this.observer?.disconnect();this.resize?.disconnect();this.task?.destroy().catch(()=>{});}
}
