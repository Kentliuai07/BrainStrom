// main.js — 组合根 + 路由 + 画面。UI 只透过 services 碰后端。
// v3 活文件模型：一份笔记 = 一串有顺序的块；「文章 / 卡片」是同一份资料的两种画法（纯前端切换）。
import { AuthService, SystemsService, BlocksService, StatusService, AIService, splitIntoBlocks, nudgeHash, AI_BACKEND } from './services/index.js';

// ---- 组合根（建立并注入服务，无全域单例滥用）----
const services = {
  auth: new AuthService(),
  systems: new SystemsService(),
  blocks: new BlocksService(),
  status: new StatusService(),
  ai: new AIService(), // 阶段二：AI 串流（Step 1 引擎 + Step 2 聊天）
};

// ---- 图标 ----
const I = {
  plus:'<path d="M12 5v14M5 12h14"/>', back:'<path d="M15 5l-7 7 7 7"/>',
  lock:'<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/>',
  globe:'<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a15 15 0 010 18M12 3a15 15 0 000 18"/>',
  gear:'<circle cx="12" cy="12" r="3"/><path d="M19 12a7 7 0 00-.1-1l2-1.6-2-3.4-2.4 1a7 7 0 00-1.7-1L16.5 2h-4l-.3 2.4a7 7 0 00-1.7 1l-2.4-1-2 3.4L5.1 11a7 7 0 000 2l-2 1.6 2 3.4 2.4-1a7 7 0 001.7 1l.3 2.4h4l.3-2.4a7 7 0 001.7-1l2.4 1 2-3.4-2-1.6a7 7 0 00.1-1z"/>',
  search:'<circle cx="11" cy="11" r="7"/><path d="M21 21l-4-4"/>', chat:'<path d="M21 15a2 2 0 01-2 2H8l-4 4V5a2 2 0 012-2h13a2 2 0 012 2z"/>',
  type:'<path d="M4 7V5h16v2M9 19h6M12 5v14"/>', check:'<path d="M5 12l4 4L19 7"/>',
  list:'<path d="M9 6h11M9 12h11M9 18h11M5 6h.01M5 12h.01M5 18h.01"/>', sparkles:'<path d="M12 3l1.8 4.2L18 9l-4.2 1.8L12 15l-1.8-4.2L6 9l4.2-1.8z"/>',
  brain:'<path d="M9 4a3 3 0 013 3 3 3 0 013-3 3 3 0 013 3v9a3 3 0 01-6 0 3 3 0 01-6 0V7a3 3 0 013-3z"/>',
  trash:'<path d="M4 7h16M9 7V5a1 1 0 011-1h4a1 1 0 011 1v2M6 7l1 13a1 1 0 001 1h8a1 1 0 001-1l1-13"/>',
};
const svg = (k,sz=20,sw=1.8)=>`<svg width="${sz}" height="${sz}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round">${I[k]}</svg>`;

// 旋钮模组（阶段一：3 基础块可选；AI 类上锁）
const MODULES = [
  { id:'text', name:'文字', icon:'type', locked:false },
  { id:'todo', name:'待办', icon:'check', locked:false },
  { id:'heading', name:'标题', icon:'list', locked:false },
  { id:'mindmap', name:'心智图', icon:'brain', locked:true },
  { id:'ai', name:'AI 分析', icon:'sparkles', locked:true },
];

const $ = (s,r=document)=>r.querySelector(s);
const setTheme = t => { document.documentElement.setAttribute('data-theme',t); localStorage.setItem('brainstrom.theme',t); };
const VIEW_KEY = 'brainstrom.view.'; // 视图偏好（sessionStorage，按系统记）
const LONG_PARA = 2000;              // 超长段落提示阈值（F7）

class App {
  constructor(){ this.root = $('#screen'); }
  async start(){
    setTheme(localStorage.getItem('brainstrom.theme')||'obsidian');
    window.addEventListener('online',()=>this.offline(false));
    window.addEventListener('offline',()=>this.offline(true));
    await services.auth.init();
    services.auth.user ? this.home() : this.login();
  }
  frame(inner){ this.root.innerHTML =
    `<div class="island"></div>
     <div class="statusbar"><span>9:41</span><span class="dots">${svg('list',16,2)} 100%</span></div>
     <div class="offline" id="offbar">⚠ 目前离线，变更暂存本地</div>
     ${inner}<div class="homebar"></div><div class="toast" id="toast"></div>`;
    const ob=$('#offbar'); if(ob) ob.classList.toggle('show', !navigator.onLine); }
  offline(b){ const el=$('#offbar'); if(el) el.classList.toggle('show',b); }
  toast(t){ const el=$('#toast'); if(!el) return; el.textContent=t; el.classList.add('on'); clearTimeout(this._tt); this._tt=setTimeout(()=>el.classList.remove('on'),1300); }

  // ---------- 登入 ----------
  login(){
    this.frame(`<div class="login">
      <div class="logo">B</div>
      <div class="h1">BrainStrom</div>
      <div class="muted" style="max-width:240px">氛围开发笔记 · 自然语言，就是程式</div>
      <button class="apple" id="apple"> ${svg('plus',16,2)} 使用 Apple 登入</button>
      <div class="faint" style="font-size:11px;max-width:230px">收集 email 供登入、储存你的笔记（示范用 dev 登入）</div>
    </div>`);
    $('#apple').onclick = async ()=>{ $('#apple').disabled=true; $('#apple').textContent='登入中…';
      await services.auth.signInWithApple(); this.home(); };
  }

  // ---------- 首页 ----------
  async home(){
    this.chatAbort?.abort(); // 离开笔记页：中断进行中的 AI 串流（省钱铁律，F8）
    this.aiAbort?.abort(); this.aiAbort=null; this.aiBusy=false;
    this.frame(`<div class="view">
      <div class="scroll"><div class="pad">
        <div class="row"><div><div class="faint" style="font-size:12px">我的系统</div><div class="h1">BrainStrom</div></div>
          <div class="spacer"></div>
          <button class="iconbtn" id="settings">${svg('gear')}</button>
          <button class="iconbtn accent" id="add">${svg('plus')}</button></div>
        <div class="banner">${svg('sparkles',15,2)} 阶段二 Step 3.5/3.6：新笔记先取名，按 ⚡ 让 AI 教练点评，提议点了就落地</div>
        <div id="syslist"><div class="muted" style="padding:20px 0">载入中…</div></div>
      </div></div></div>`);
    $('#settings').onclick=()=>this.settings();
    // Step 3.6 名称先行：新建给空 title，进笔记页「命名态」（F9 gate）
    $('#add').onclick=async ()=>{ const s=await services.systems.create(''); this.note(s.id); };
    try{
      const { items } = await services.systems.list();
      const box=$('#syslist');
      if(!items.length){ box.innerHTML=`<div class="empty"><div class="big">📓</div><div>还没有系统</div>
        <button class="btn" id="first">建立第一个系统</button></div>`;
        $('#first').onclick=async()=>{ const s=await services.systems.create(''); this.note(s.id); }; return; }
      box.innerHTML = items.map(s=>`<button class="syscard" data-id="${s.id}">
        <div class="row"><span class="pill ${s.visibility==='private'?'priv':'pub'}">${svg(s.visibility==='private'?'lock':'globe',9,2)} ${s.visibility==='private'?'私密':'公开'}</span>
        <span class="spacer"></span><span class="faint" style="font-size:10px">${fmt(s.updatedAt)}</span></div>
        <div class="sys-title">${esc(s.title)||'未命名系统'}</div>
        <div class="sys-snip">${esc(s.snippet||'（空白系统，点开开始写）')}</div>
        ${s.tags?.length?`<div class="tags">${s.tags.map(t=>`<span class="tag">${esc(t)}</span>`).join('')}</div>`:''}
      </button>`).join('');
      box.querySelectorAll('.syscard').forEach(b=>b.onclick=()=>this.note(b.dataset.id));
    }catch(e){ $('#syslist').innerHTML=`<div class="empty"><div>载入失败</div><button class="btn" id="retry">重试</button></div>`;
      $('#retry').onclick=()=>this.home(); }
  }

  // ---------- 笔记（活文件：文章 / 卡片两视图 + Undo/Redo + 问 AI 聊天）----------
  async note(id){
    // 聊天历史只存前端内存，切换笔记即清空（附录 D7）；先中断上一篇残留的串流
    this.chatAbort?.abort(); this.chatAbort=null;
    this.chatMsgs=[]; this.chatBusy=false;
    this.aiAbort?.abort(); this.aiAbort=null; this.aiBusy=false;
    this.frame(`<div class="view">
      <div class="nav"><button class="link" id="back">${svg('back',20,2)} 系统</button>
        <span class="spacer"></span>
        <div class="seg" style="max-width:130px"><button id="v-article" class="on">文章</button><button id="v-cards">卡片</button></div>
        <span class="spacer"></span>
        <button class="histbtn" id="undo" aria-label="上一步" title="上一步">↶</button>
        <button class="histbtn" id="redo" aria-label="下一步" title="下一步">↷</button>
        <button class="pill priv" id="vis" style="border:none">${svg('lock',9,2)} 私密</button></div>
      <div class="scroll"><div class="pad" id="content"><div class="muted">载入中…</div></div></div>
      <div class="ailock hidden" id="ailock"><div class="aibar"><i></i></div><div class="ailock-msg" id="ailockmsg">AI 整理中…</div></div>
      <div class="dock"><button class="iconbtn accent" id="chat" title="问 AI" aria-label="问 AI">${svg('chat')}</button>
        <button class="iconbtn accent aibtn" id="ai-opt" title="优化文字" aria-label="优化文字">✦</button>
        <button class="iconbtn accent aibtn" id="ai-card" title="卡片结构化" aria-label="卡片结构化">▦</button>
        <button class="iconbtn" id="dsys">${svg('trash')}</button>
        <span class="spacer"></span><span class="savechip" id="save"></span></div>
      <button class="fab" id="fab">+</button>
      <div class="dial-scrim" id="scrim"></div><div class="dial hidden" id="dial"></div>
      <div class="chatpanel hidden" id="chatpanel">
        <div class="chathead">${svg('chat',15,2)} 问 AI · 这则笔记<span class="spacer"></span>
          <button class="sparkbtn hidden" id="chatspark" title="教练点评（内容没变就重播、零成本）" aria-label="教练点评">⚡</button>
          <button class="link" id="chatclose">收合 ▾</button></div>
        <div class="chatlist" id="chatlist"></div>
        <div class="chatfoot">
          <textarea id="chatin" rows="1" placeholder="问这则笔记…"></textarea>
          <button class="btn btn-ghost hidden" id="chatstop">停止</button>
          <button class="btn" id="chatsend">送出</button>
        </div>
      </div>
    </div>`);
    // 离开清理（F9）：空名 && 零块 → 软删 + toast「空笔记已丢弃」，清单不留空壳
    $('#back').onclick=async()=>{ const d=await this.cleanupEmptyNote(); this.home(); if(d) this.toast('空笔记已丢弃'); };
    // 问 AI 浮钮（dock 左侧聊天钮 = 触点表「笔记底部聊天浮层」的入口）
    $('#chat').onclick=()=>this.toggleChat();
    // 阶段二 Step 3：两颗 AI 钮（✦ 优化文字 / ▦ 卡片结构化）
    $('#ai-opt').onclick=()=>this.runOptimize();
    $('#ai-card').onclick=()=>this.runStructure();
    $('#chatclose').onclick=()=>this.toggleChat(false);
    // Step 3.6：面板 ⚡（指纹同→重播零成本；不同→重新 kickoff）
    $('#chatspark').onclick=()=>this.sparkReplay();
    $('#chatsend').onclick=()=>this.sendChat();
    $('#chatstop').onclick=()=>this.chatAbort?.abort();
    const ci=$('#chatin');
    ci.oninput=()=>autoraf(ci);
    ci.onkeydown=e=>{ if(e.key==='Enter'&&!e.shiftKey){ e.preventDefault(); this.sendChat(); } };
    $('#dsys').onclick=async()=>{ if(!confirm('删除这个系统？此动作无法复原。')) return;
      await services.systems.delete(this.cur.id); this.toast('已删除系统'); setTimeout(()=>this.home(),300); };
    let sys; try{ sys=await services.systems.get(id); }catch{ this.toast('打不开'); return this.home(); }
    this.cur=sys;
    // F9 命名态 gate：零块 && (空名 || 旧「未命名系统」空壳)；已有内容的笔记永不锁正文
    this.naming=this.isNamingGate(sys);
    // 视图偏好（sessionStorage）；docState 未到 carded 时强制回文章
    this.view = sessionStorage.getItem(VIEW_KEY+id) || 'article';
    if(this.view==='cards' && sys.docState!=='carded') this.view='article';
    const renderVis=()=>{ const v=$('#vis'); v.className='pill '+(sys.visibility==='private'?'priv':'pub');
      v.innerHTML=`${svg(sys.visibility==='private'?'lock':'globe',9,2)} ${sys.visibility==='private'?'私密':'公开'}`; };
    renderVis();
    $('#vis').onclick=async()=>{ const u=await services.systems.setVisibility(id, sys.visibility==='private'?'public':'private'); sys.visibility=u.visibility; this.cur=sys; renderVis(); };
    $('#v-article').onclick=()=>this.setView('article');
    $('#v-cards').onclick=()=>this.setView('cards');
    $('#undo').onclick=async()=>{ const r=await services.systems.undo(id);
      this.toast(r?'已撤销一步':'没有可撤销的步骤'); await this.reload(); };
    $('#redo').onclick=async()=>{ const r=await services.systems.redo(id);
      this.toast(r?'已重做一步':'没有可重做的步骤'); await this.reload(); };
    this.fab=$('#fab'); this.fab.onclick=()=>this.openDial();
    $('#scrim').onclick=()=>this.closeDial();
    this.syncViewSeg();
    this.renderContent();
    this.syncNamingUI();
    this.syncSpark();
  }
  // F9 gate 条件：!title.trim() && 零块；旧资料不迁移——「未命名系统」零块空壳打开时同样进命名态
  isNamingGate(s){
    const zero=!(s.blocks||[]).length;
    return zero && (!String(s.title||'').trim() || s.title==='未命名系统');
  }
  // 命名态禁用清单（F9）：fab/✦/▦/💬 全 disabled（正文区/续写区由 renderArticle 直接不渲染）
  syncNamingUI(){
    ['#fab','#ai-opt','#ai-card','#chat'].forEach(s=>{ const b=$(s); if(b) b.disabled=!!this.naming; });
  }
  // 面板 ⚡ 小钮：nudge.state!=='pending' 时显示（手动重看教练点评的常驻入口）
  syncSpark(){
    const b=$('#chatspark'); if(!b) return;
    const st=this.cur?.nudge?.state;
    b.classList.toggle('hidden', !st || st==='pending');
  }
  // F9 离开清理：空名&&零块 → 软删（回 true 让呼叫端 toast）；防御分支：空名但有块 → 回填保留
  async cleanupEmptyNote(){
    const c=this.cur; if(!c) return false;
    try{
      const input=$('#title');
      const tval=String(input?input.value:(c.title||'')).trim();
      const zero=!(c.blocks||[]).length;
      if(zero && !tval && !String(c.title||'').trim()){
        await services.systems.delete(c.id); return true;
      }
      if(!zero && !tval && !String(c.title||'').trim())
        await services.systems.update(c.id,{title:'未命名系统'}); // 理论不可达的防御分支
    }catch{}
    return false;
  }
  // 视图切换：纯前端 UI 状态，不打后端（v3 决策）
  setView(v){
    if(v==='cards' && this.cur.docState!=='carded'){ this.toast('先按 AI 结构化'); return; }
    this.view=v; sessionStorage.setItem(VIEW_KEY+this.cur.id, v);
    this.syncViewSeg(); this.renderContent();
  }
  syncViewSeg(){
    const a=$('#v-article'), c=$('#v-cards'); if(!a||!c) return;
    a.classList.toggle('on',this.view==='article');
    c.classList.toggle('on',this.view==='cards');
    const carded=this.cur.docState==='carded';
    c.disabled=!carded; c.title=carded?'':'先按 AI 结构化';
  }
  async reload(){
    try{ this.cur=await services.systems.get(this.cur.id); }catch{ return this.home(); }
    if(this.view==='cards' && this.cur.docState!=='carded') this.view='article';
    this.naming=this.isNamingGate(this.cur); // 重算 gate（已有内容的笔记永不锁正文）
    this.syncViewSeg(); this.renderContent(); this.syncNamingUI(); this.syncSpark();
  }
  renderContent(){
    if(this.view==='cards') this.renderCards(); else this.renderArticle();
    this.refreshHistoryBtns();
  }
  async refreshHistoryBtns(){
    try{ const v=await services.systems.versions(this.cur.id);
      const ub=$('#undo'), rb=$('#redo');
      if(ub) ub.disabled=!v.canUndo;
      if(rb) rb.disabled=!v.canRedo;
    }catch{}
  }
  sortedBlocks(){ return (this.cur.blocks||[]).slice().sort((a,b)=>a.position-b.position); }

  // ---- 文章视图（§1.2b：点哪段改哪段 + 文末续写区；F9 命名态 gate）----
  renderArticle(){
    const c=$('#content');
    // 命名态：旧「未命名系统」空壳显示空名称栏（旧资料不迁移，blur 不动它）
    const showTitle=(this.naming && this.cur.title==='未命名系统') ? '' : this.cur.title;
    c.innerHTML=`<textarea class="note-title" id="title" rows="1" placeholder="${this.naming?'先给这个点子取个名字':'标题'}">${esc(showTitle)}</textarea>
      <div class="titleaux" id="titleaux"></div>
      ${this.naming
        ? `<div class="naminghint">✏️ 先给这个点子取个名字，就能开始写</div>`
        : `<div class="blocks" id="blocks"></div>
      <textarea class="note-body" id="contwrite" rows="1" placeholder="继续写…（空行分段、# 开头成标题）"></textarea>`}`;
    const title=$('#title');
    title.oninput=()=>autoraf(title);
    title.onkeydown=e=>{ if(e.key==='Enter'){ e.preventDefault(); title.blur(); } }; // Enter 提交＝blur
    title.onblur=()=>this.commitTitle(title.value);
    autoraf(title);
    this.renderTitleAux();
    if(this.naming){ title.focus(); return; } // 命名态：游标停名称栏，正文不渲染
    const bs=this.sortedBlocks();
    if(!bs.length) $('#blocks').innerHTML=`<div class="faint" id="bhint" style="padding:6px 8px">空白笔记——直接在下方「继续写…」开始，或＋加模组</div>`;
    bs.forEach(b=>this.appendBlock(b));
    // 文末常驻续写区：blur 且非空 → 整次提交先落一步，再切块逐个 append
    const cw=$('#contwrite');
    cw.oninput=()=>autoraf(cw); autoraf(cw);
    cw.onblur=async()=>{
      const v=cw.value; if(!v.trim()) return;
      await services.systems.saveVersion(this.cur.id,'cardEdit');
      const segs=splitIntoBlocks(v);
      for(const seg of segs) await services.blocks.add(this.cur.id,{ ...seg, source:'manual' });
      cw.value='';
      this.saved(); await this.reload();
    };
  }
  // 名称提交（blur / Enter）。F9 title blur 规则：非空→存；空名有块→回填「未命名系统」；
  // 空名零块→保持空、维持命名态。命名态下非空提交＝解锁＋重渲染。
  async commitTitle(raw){
    const v=String(raw||'').trim();
    const zero=!this.sortedBlocks().length;
    if(!v){
      if(!zero){ // 有块回填（现行为）
        if(this.cur.title!=='未命名系统'){
          const u=await services.systems.update(this.cur.id,{title:'未命名系统'});
          this.cur.title=u.title; this.cur.version=u.version; this.saved();
        }
        const t=$('#title'); if(t){ t.value=this.cur.title; autoraf(t); }
      }else{ // 零块保持空，维持/进入命名态
        if(String(this.cur.title||'').trim() && this.cur.title!=='未命名系统'){
          const u=await services.systems.update(this.cur.id,{title:''});
          this.cur.title=u.title; this.cur.version=u.version;
        }
        if(!this.naming){ this.naming=true; this.renderContent(); this.syncNamingUI(); }
      }
      return;
    }
    if(v!==this.cur.title){
      const u=await services.systems.update(this.cur.id,{title:v});
      this.cur.title=u.title; this.cur.version=u.version; this.saved();
    }
    if(this.naming){ this.naming=false; this.renderContent(); this.syncNamingUI(); } // 解锁＋重渲染
    else this.renderTitleAux(); // 名称从无到有：助攻胶囊可能要浮现
    this.syncSpark();
  }
  // 标题正下方的行内区：命名态放「先随便取」；命名完成放助攻胶囊（F9 规则表）
  renderTitleAux(){
    const aux=$('#titleaux'); if(!aux) return;
    if(this.naming){
      aux.innerHTML=`<button class="quickname" id="quickname">先随便取</button>`;
      $('#quickname').onclick=async()=>{ // 快速倒垃圾通道：一键占位名秒解锁
        const d=new Date(); const name=`${d.getMonth()+1}/${d.getDate()} 随手记`;
        const t=$('#title'); if(t){ t.value=name; autoraf(t); }
        await this.commitTitle(name);
      };
      return;
    }
    const nudge=this.cur.nudge||{};
    const swOn=services.auth.user?.prefs?.ideaNudge!==false; // 总开关（用户级）
    if(swOn && nudge.state==='pending' && String(this.cur.title||'').trim()){
      aux.innerHTML=`<div class="nudgecap" id="nudgecap">
        <button class="nudgego" id="nudgego">⚡ 让 AI 教练看看这个点子</button>
        <button class="nudgex" id="nudgex" aria-label="不再显示" title="不再显示">✕</button></div>`;
      $('#nudgego').onclick=()=>this.startKickoff();
      $('#nudgex').onclick=async()=>{ // ✕ → dismissed：该笔记胶囊永不再自动出现
        const cap=$('#nudgecap'); if(cap) cap.classList.add('fade');
        const u=await services.systems.update(this.cur.id,{nudge:{...(this.cur.nudge||{}),state:'dismissed'}});
        this.cur.nudge=u.nudge;
        setTimeout(()=>{ const c2=$('#nudgecap'); if(c2) c2.remove(); },250);
        this.toast('不再为这则笔记显示（设定页可关闭）');
        this.syncSpark();
      };
    } else aux.innerHTML='';
  }

  // ---- Step 3.6 点子助攻：kickoff 教练开场 / 指纹重播（F9）----
  // 防连点四层闸：①按下即转 opened 收胶囊 ②chatBusy 防抖 ③面板 ⚡ 受 nudge.hash gate ④server 60/分限流
  async startKickoff(){
    if(this.chatBusy) return;
    const hash=nudgeHash(this.cur.title, this.cur.blocks);
    const u=await services.systems.update(this.cur.id,
      {nudge:{ ...(this.cur.nudge||{}), state:'opened', hash, at:new Date().toISOString() }});
    this.cur.nudge=u.nudge;
    this.renderTitleAux(); this.syncSpark(); // 胶囊收起、面板 ⚡ 浮现
    this.toggleChat(true);
    await this.runKickoffChat();
  }
  // 实际跑一次 kickoff 串流：开场白逐字进 AI 气泡 → proposal 渲染按钮列 → 完成写 nudge.opening（重播快照）
  async runKickoffChat(){
    if(this.chatBusy) return;
    const bubble=this.chatBubble('ai','');
    const textEl=bubble.querySelector('.ctext');
    textEl.innerHTML='<span class="faint">教练看稿中…</span>';
    this.chatBusy=true; this.chatLock(true);
    const ac=new AbortController(); this.chatAbort=ac;
    let acc=''; let props=null;
    const meta=(cls,txt)=>{ const m=document.createElement('div'); m.className=cls; m.textContent=txt; bubble.appendChild(m); this.chatScroll(); };
    try{
      await services.ai.chatNote(this.cur.id, [], {
        onDelta:t=>{ acc+=t; textEl.textContent=acc; this.chatScroll(); },
        onUsage:u2=>meta('cmeta',`tokens: in ${u2.input_tokens} / out ${u2.output_tokens}`),
        onProposal:items=>{ props=items; },
        onError:e=>meta('cerr','出错：'+(e.error||e.code||'未知错误')),
      }, ac.signal, { kickoff:true });
    }catch(e){ meta('cerr','出错：'+(e.message||e)); }
    finally{
      if(!acc) textEl.textContent='';
      if(ac.signal.aborted && acc) meta('cmeta','（已停止）');
      if(acc) this.chatMsgs.push({role:'ai',content:acc}); // 开场白进同一份聊天历史（与手动 💬 同面板）
      if(props?.length) this.renderProposals(bubble, props);
      this.chatBusy=false; this.chatAbort=null; this.chatLock(false);
      if(!ac.signal.aborted && (acc || props?.length)){ // 完成后存开场快照（同内容重按零成本重播）
        try{
          const u=await services.systems.update(this.cur.id,
            {nudge:{ ...(this.cur.nudge||{}), state:'opened', opening:{ text:acc, proposals:props||[] } }});
          this.cur.nudge=u.nudge;
        }catch{}
      }
      this.syncSpark();
      $('#chatin')?.focus();
    }
  }
  // 面板 ⚡：指纹同 → 注入 nudge.opening（零网络、零成本）；不同 → 重新 kickoff 并更新 hash/opening
  async sparkReplay(){
    if(this.chatBusy) return;
    const nu=this.cur.nudge||{};
    const hash=nudgeHash(this.cur.title, this.cur.blocks);
    if(nu.opening && nu.hash===hash){
      const bubble=this.chatBubble('ai','');
      const pre=document.createElement('div'); pre.className='cmeta';
      pre.textContent='上次的教练点评（内容没变，未消耗 AI）';
      bubble.insertBefore(pre, bubble.firstChild);
      bubble.querySelector('.ctext').textContent=nu.opening.text||'';
      if(nu.opening.proposals?.length) this.renderProposals(bubble, nu.opening.proposals);
      if(nu.opening.text) this.chatMsgs.push({role:'ai',content:nu.opening.text});
      this.chatScroll();
      return;
    }
    try{
      const u=await services.systems.update(this.cur.id,
        {nudge:{ ...nu, state:'opened', hash, at:new Date().toISOString() }});
      this.cur.nudge=u.nudge;
    }catch{}
    this.renderTitleAux();
    await this.runKickoffChat();
  }
  // ---- Step 3.5 提议按钮列：AI 气泡下方横排小钮；点过整列禁用（防重复）----
  renderProposals(bubble, items){
    if(!bubble || !items?.length) return;
    const LOCKED=['find_github','find_youtube','find_info']; // 接通前显示「即将推出」
    const row=document.createElement('div'); row.className='proprow';
    items.slice(0,4).forEach(it=>{
      const locked=LOCKED.includes(it.action);
      const btn=document.createElement('button'); btn.className='propbtn'+(locked?' locked':'');
      btn.textContent=(locked?'🔒 ':'')+String(it.label||it.action).slice(0,12);
      btn.onclick=async()=>{
        if(locked){ this.toast('即将推出'); return; } // 锁定项不锁整列（没执行任何事）
        row.querySelectorAll('.propbtn').forEach(b=>b.disabled=true);
        if(it.action==='structure'){ this.toggleChat(false); await this.runStructure(); }
        else if(it.action==='edit_text') await this.runApplyEdit(it.args?.instruction || it.label || '');
        else this.toast('即将推出');
      };
      row.appendChild(btn);
    });
    bubble.appendChild(row); this.chatScroll();
  }
  // edit_text 提议落地：ai.applyEdit（执行中锁定编辑器同 ✦；完成可 ↶ 还原）
  async runApplyEdit(instruction){
    if(this.aiBusy) return;
    if(AI_BACKEND!=='real'){ this.toast('此功能需要真后端（config.js 切 real）'); return; }
    this.aiBusy=true; this.aiLock(true,'AI 帮你补内容中…'); this.chatLock(true);
    this.aiAbort=new AbortController();
    let err=null, skip=null;
    const r=await services.ai.applyEdit(this.cur.id,{instruction},{
      onProgress:(c,t,msg)=>{ if(msg) skip=msg; },
      onError:e=>{ err=e; },
    }, this.aiAbort.signal);
    this.aiBusy=false; this.aiAbort=null; this.aiLock(false); this.chatLock(false);
    if(err) this.aiErrToast(err);
    else if(skip && !(r?.applied||r?.removed)) this.toast(skip); // AI 没提出任何修改
    else{
      this.toast('已帮你补上，可按 ↶ 还原');
      this.chatMsgs.push({role:'ai',content:'已帮你补上，可按 ↶ 还原'});
      const p=$('#chatpanel');
      if(p && !p.classList.contains('hidden')) this.chatBubble('ai','已帮你补上，可按 ↶ 还原');
    }
    await this.reload();
  }

  appendBlock(b){
    const wrap=$('#blocks'); const hint=$('#bhint'); if(hint) hint.remove();
    const tmp=document.createElement('div'); tmp.innerHTML=this.blockHTML(b);
    const node=tmp.firstElementChild; wrap.appendChild(node); this.wireBlock(node,b);
  }
  blockHTML(b){
    const tools=this.toolsHTML(b);
    const mark=b.pinned?'<span class="pinmark" title="已钉选，AI 永不动">📌</span>':'';
    if(b.type==='todo') return `<div class="block todo" data-b="${b.id}"><span class="tick ${b.payload.done?'on':''}">${b.payload.done?svg('check',13,2.4):''}</span><textarea rows="1" placeholder="待办…">${esc(b.payload.text||'')}</textarea>${tools}</div>`;
    if(b.type==='heading') return `<div class="block heading para ${b.pinned?'pinned':''}" data-b="${b.id}"><div class="ptext ${b.payload.level===2?'h2':''}">${mark}${esc(b.payload.content||'')||'<span class="faint">（空标题，点击编辑）</span>'}</div>${tools}</div>`;
    if(b.type==='text') return `<div class="block para ${b.pinned?'pinned':''}" data-b="${b.id}"><div class="ptext">${mark}${esc(b.payload.content||'')||'<span class="faint">（空白段落，点击编辑）</span>'}</div>${tools}</div>`;
    // 模组类块：简单组件框（type 名 + payload 摘要），不可文字编辑、恒钉选（无开关）
    return `<div class="block module" data-b="${b.id}"><div class="mhead">📌 模组 · ${esc(b.type)}</div><div class="mjson">${esc(JSON.stringify(b.payload||{}).slice(0,140))}</div>${tools}</div>`;
  }
  // 工具列：📌 钉选（仅 text/heading）＋ 上下移 ＋ 删除；edit=true 时只留钉选
  toolsHTML(b, edit=false){
    const pin=(b.type==='text'||b.type==='heading')
      ? `<button class="bpin ${b.pinned?'on':''}" aria-label="钉选" title="${b.pinned?'取消钉选':'钉选（AI 永不动）'}">📌</button>` : '';
    if(edit) return `<div class="btools">${pin}</div>`;
    return `<div class="btools">${pin}<button class="bmv" data-d="up" aria-label="上移">▲</button><button class="bmv" data-d="dn" aria-label="下移">▼</button><button class="bdel" aria-label="删除区块">${svg('trash',12,1.8)}</button></div>`;
  }
  wireBlock(node,b){
    if(b.type==='todo'){
      node.querySelector('.tick').onclick=async()=>{
        await services.systems.saveVersion(this.cur.id,'cardEdit');
        const done=!b.payload.done; b.payload={...b.payload,done};
        node.querySelector('.tick').classList.toggle('on',done);
        await services.blocks.toggleDone(b.id,b.payload); this.saved(); this.refreshHistoryBtns(); };
      const ta=node.querySelector('textarea');
      ta.oninput=()=>autoraf(ta); autoraf(ta);
      ta.onblur=async()=>{ if(ta.value===(b.payload.text||'')) return; // 没变不落步
        await services.systems.saveVersion(this.cur.id,'cardEdit');
        b.payload={...b.payload,text:ta.value};
        await services.blocks.update(b.id,{payload:b.payload}); this.saved(); this.refreshHistoryBtns(); };
    }
    // text/heading：点段落 → 变 textarea 编辑（§1.2b）
    const pt=node.querySelector('.ptext');
    if(pt && (b.type==='text'||b.type==='heading')) pt.onclick=()=>this.editBlock(node,b);
    this.wireTools(node,b);
  }
  wireTools(node,b){
    const pin=node.querySelector('.bpin');
    if(pin) pin.onpointerdown=async ev=>{ ev.preventDefault(); // 不抢焦点（编辑态按钉选不触发 blur）
      const np=!b.pinned;
      await services.blocks.pin(b.id,np); b.pinned=np;
      this.toast(np?'已钉选（AI 永不动）':'已取消钉选');
      if(!node.querySelector('textarea')) this.redrawBlock(node,b); // 读取态：整块重画（更新 📌 标记）
      else { pin.classList.toggle('on',np); pin.title=np?'取消钉选':'钉选（AI 永不动）'; } }; // 编辑态：只换按钮状态，不打断输入
    const del=node.querySelector('.bdel');
    if(del) del.onclick=async()=>{
      await services.systems.saveVersion(this.cur.id,'delete'); // 删除前落一步
      await services.blocks.delete(b.id);
      this.cur.blocks=this.cur.blocks.filter(x=>x.id!==b.id); node.remove();
      if(!this.cur.blocks.length) this.renderArticle();
      this.toast('已删除区块'); this.refreshHistoryBtns(); };
    node.querySelectorAll('.bmv').forEach(btn=>btn.onclick=async()=>{
      const arr=this.sortedBlocks(), idx=arr.findIndex(x=>x.id===b.id), step=btn.dataset.d==='up'?-1:1;
      const ni=idx+step; if(ni<0||ni>=arr.length) return;
      await services.systems.saveVersion(this.cur.id,'cardEdit'); // 移动前落一步
      [arr[idx],arr[ni]]=[arr[ni],arr[idx]];
      await services.blocks.reorder(this.cur.id, arr.map(x=>x.id));
      arr.forEach((x,i)=>{ x.position=i; }); this.cur.blocks=arr;
      this.renderArticle(); this.saved(); this.refreshHistoryBtns(); });
  }
  editBlock(node,b){
    const old=b.payload.content||'';
    const hint = old.length>LONG_PARA ? `<div class="longhint">⚠ 这段超过 ${LONG_PARA} 字，建议拆分</div>` : '';
    node.innerHTML=`${hint}<textarea rows="1" placeholder="${b.type==='heading'?'标题':'写点什么…'}">${esc(old)}</textarea>${this.toolsHTML(b,true)}`;
    const ta=node.querySelector('textarea');
    ta.oninput=()=>autoraf(ta); autoraf(ta);
    ta.focus(); ta.selectionStart=ta.selectionEnd=ta.value.length;
    ta.onblur=async()=>{
      const v=ta.value;
      if(v===old){ this.redrawBlock(node,b); return; } // 没变只收起、不落步
      await services.systems.saveVersion(this.cur.id,'cardEdit'); // 有变才落一步
      b.payload={...b.payload, content:v};
      await services.blocks.update(b.id,{payload:b.payload});
      this.redrawBlock(node,b); this.saved(); this.refreshHistoryBtns();
    };
    this.wireTools(node,b);
  }
  redrawBlock(node,b){
    const tmp=document.createElement('div'); tmp.innerHTML=this.blockHTML(b);
    const nn=tmp.firstElementChild; node.replaceWith(nn); this.wireBlock(nn,b);
  }

  // ---- 卡片视图（Step 3 实装：全部块渲染成卡片流；空状态按钮直接触发 ▦）----
  renderCards(){
    const c=$('#content');
    if(this.cur.docState!=='carded'){
      c.innerHTML=`<div class="structured-empty"><div>还没结构化<br>—— 按下面的按钮，AI 会把笔记整理成一张张主题卡</div>
        <button class="btn" id="gostruct" style="margin-top:14px">▦ 卡片结构化</button></div>`;
      $('#gostruct').onclick=()=>this.runStructure();
      return;
    }
    const bs=this.sortedBlocks();
    c.innerHTML='<div class="blocks" id="cards"></div>';
    const w=$('#cards');
    if(!bs.length){ w.innerHTML='<div class="faint" style="padding:6px 8px">没有卡片——切回文章视图写点内容吧</div>'; return; }
    for(const b of bs){
      const tmp=document.createElement('div'); tmp.innerHTML=this.cardHTML(b);
      const node=tmp.firstElementChild; w.appendChild(node); this.wireCard(node,b);
    }
  }
  isModule(b){ return !['text','heading','todo'].includes(b.type); }
  cardHTML(b){
    // 模组卡：沿用文章视图同一个组件框（决策 7：两视图长一样），只多删除钮
    if(this.isModule(b)) return `<div class="block module" data-b="${b.id}">
      <div class="mhead">📌 模组 · ${esc(b.type)}</div>
      <div class="mjson">${esc(JSON.stringify(b.payload||{}).slice(0,140))}</div>
      <div class="cardtools"><button class="cdel" aria-label="删除卡" title="删除">${svg('trash',12,1.8)}</button></div></div>`;
    const title=b.payload?.title;
    const content=b.payload?.content ?? b.payload?.text ?? '';
    return `<div class="card aicard ${b.pinned?'pinned':''}" data-b="${b.id}">
      <div class="cardtools"><button class="cpin ${b.pinned?'on':''}" aria-label="钉选" title="${b.pinned?'取消钉选':'钉选（AI 永不动）'}">📌</button><button class="cdel" aria-label="删除卡" title="删除">${svg('trash',12,1.8)}</button></div>
      ${title?`<div class="cardtitle">${b.pinned?'<span class="pinmark">📌</span>':''}${esc(title)}</div>`:''}
      <div class="cardbody">${esc(content)||'<span class="faint">（空白，点击编辑）</span>'}</div></div>`;
  }
  wireCard(node,b){
    const pin=node.querySelector('.cpin');
    if(pin) pin.onpointerdown=async ev=>{ ev.preventDefault();
      const np=!b.pinned;
      await services.blocks.pin(b.id,np); b.pinned=np;
      this.toast(np?'已钉选（AI 永不动）':'已取消钉选');
      const tmp=document.createElement('div'); tmp.innerHTML=this.cardHTML(b);
      const nn=tmp.firstElementChild; node.replaceWith(nn); this.wireCard(nn,b); };
    const del=node.querySelector('.cdel');
    if(del) del.onclick=async()=>{
      await services.systems.saveVersion(this.cur.id,'delete'); // 删卡前落一步
      await services.blocks.delete(b.id);
      this.cur.blocks=this.cur.blocks.filter(x=>x.id!==b.id); node.remove();
      if(!this.cur.blocks.length) this.renderCards();
      this.toast('已删除卡'); this.refreshHistoryBtns(); };
    // 点内容就地编辑（blur 存，有变才落一步 cardEdit）
    const body=node.querySelector('.cardbody');
    if(body) body.onclick=()=>{
      const key = b.payload?.content!==undefined||b.type!=='todo' ? 'content' : 'text';
      const old = b.payload?.[key] ?? '';
      body.innerHTML=`<textarea rows="1">${esc(old)}</textarea>`;
      const ta=body.querySelector('textarea');
      ta.oninput=()=>autoraf(ta); autoraf(ta);
      ta.focus(); ta.selectionStart=ta.selectionEnd=ta.value.length;
      ta.onblur=async()=>{
        const v=ta.value;
        const redraw=()=>{ const tmp=document.createElement('div'); tmp.innerHTML=this.cardHTML(b);
          const nn=tmp.firstElementChild; node.replaceWith(nn); this.wireCard(nn,b); };
        if(v===old){ redraw(); return; }                                  // 没变只收起、不落步
        await services.systems.saveVersion(this.cur.id,'cardEdit');       // 有变才落一步
        b.payload={...b.payload,[key]:v};
        await services.blocks.update(b.id,{payload:b.payload});
        redraw(); this.saved(); this.refreshHistoryBtns();
      };
    };
  }

  // ---- 阶段二 Step 3 · 两颗 AI 钮的流程 ----
  // 自制置中确认框：「要不要顺便分主题、加小标题？」→ true / false / null(取消)
  askGroupTopics(){
    return new Promise(resolve=>{
      const el=document.createElement('div'); el.className='confirm-scrim';
      el.innerHTML=`<div class="confirm">
        <div class="confirm-title">要不要顺便分主题、加小标题？</div>
        <div class="confirm-btns">
          <button class="btn" data-v="yes">要</button>
          <button class="btn btn-ghost" data-v="no">不要</button>
          <button class="btn btn-ghost" data-v="cancel">取消</button>
        </div></div>`;
      this.root.appendChild(el);
      el.querySelectorAll('button').forEach(btn=>btn.onclick=()=>{
        el.remove();
        resolve(btn.dataset.v==='yes'?true:btn.dataset.v==='no'?false:null);
      });
    });
  }
  // 锁定编辑区（半透明遮罩＋顶部细进度条＋文字），AI 操作进行中防竞态（§1.2b-6）
  aiLock(on,msg){
    const el=$('#ailock'); if(el) el.classList.toggle('hidden',!on);
    const m=$('#ailockmsg'); if(m&&msg) m.textContent=msg;
    ['#ai-opt','#ai-card','#chat','#fab','#undo','#redo'].forEach(s=>{ const b=$(s); if(b) b.disabled=!!on; });
  }
  aiErrToast(e){
    if(e.code==='safety_valve') this.toast('变动过大，已保留原内容');
    else if(e.code==='need_real_backend') this.toast('此功能需要真后端（config.js 切 real）');
    else this.toast('出错：'+(e.error||e.code||'未知错误'));
  }
  // ✦ 优化文字：确认框 → 锁定 → 串流收 patch → 完成 toast → 重渲染（↶ 可整批撤销）
  async runOptimize(){
    if(this.aiBusy) return;
    if(AI_BACKEND!=='real'){ this.toast('此功能需要真后端（config.js 切 real）'); return; }
    const g=await this.askGroupTopics(); if(g===null) return;
    this.aiBusy=true; this.aiLock(true,'AI 整理中…');
    this.aiAbort=new AbortController();
    let n=0, skip=null, err=null;
    await services.ai.optimize(this.cur.id,{groupTopics:g},{
      onCard:()=>{ n++; },
      onCardRemoved:()=>{},
      onProgress:(c,t,msg)=>{ if(msg) skip=msg; },
      onError:e=>{ err=e; },
    }, this.aiAbort.signal);
    this.aiBusy=false; this.aiAbort=null; this.aiLock(false);
    if(err) this.aiErrToast(err);
    else if(skip&&!n) this.toast(skip);          // 「内容没变，未消耗 AI」
    else this.toast(`已优化 ${n} 段`);
    await this.reload();                          // 重渲染文章视图
  }
  // ▦ 卡片结构化：锁定 → 自动切卡片视图 → 卡片随 card_done 逐张浮现（先骨架后填）→ 完成解禁页签
  async runStructure(){
    if(this.aiBusy) return;
    if(AI_BACKEND!=='real'){ this.toast('此功能需要真后端（config.js 切 real）'); return; }
    this.aiBusy=true; this.aiLock(true,'AI 整理中…');
    this.view='cards'; sessionStorage.setItem(VIEW_KEY+this.cur.id,'cards');
    const a=$('#v-article'), cseg=$('#v-cards');
    if(a&&cseg){ a.classList.remove('on'); cseg.classList.add('on'); cseg.disabled=false; }
    $('#content').innerHTML='<div class="blocks" id="aicards"></div>';
    this.aiAbort=new AbortController();
    let n=0, skip=null, err=null;
    const wrap=()=>$('#aicards');
    await services.ai.structure(this.cur.id,{mode:'full'},{
      onCardStart:(i,title)=>{ const w=wrap(); if(!w) return;       // 骨架占位先浮现
        const el=document.createElement('div'); el.className='card aicard skel'; el.dataset.i=i;
        el.innerHTML=`<div class="cardtitle">${esc(title||'…')}</div><div class="cardbody shimmer">　</div>`;
        w.appendChild(el); el.scrollIntoView({block:'end'}); },
      onCard:(i,card)=>{ n++; const w=wrap(); if(!w) return;        // 再填内容
        let el=w.querySelector(`[data-i="${i}"]`);
        if(!el){ el=document.createElement('div'); el.className='card aicard'; el.dataset.i=i; w.appendChild(el); }
        el.classList.remove('skel');
        el.innerHTML=`<div class="cardtitle">${esc(card?.title||'')}</div><div class="cardbody">${esc(card?.content||'')}</div>`;
        el.scrollIntoView({block:'end'}); },
      onProgress:(c,t,msg)=>{ if(msg) skip=msg; },
      onError:e=>{ err=e; },
    }, this.aiAbort.signal);
    this.aiBusy=false; this.aiAbort=null; this.aiLock(false);
    if(err) this.aiErrToast(err);
    else if(skip&&!n) this.toast(skip);
    else this.toast(`回传 ${n} 张卡`);
    await this.reload(); // docState 成 carded → 卡片页签解除禁用（syncViewSeg）；失败则自动弹回文章
  }
  saved(){ const s=$('#save'); if(s){ s.textContent='已储存'; setTimeout(()=>{ if(s) s.textContent=''; },1200);} }

  // ---- 单笔记聊天面板（阶段二 Step 2）----
  // 铁律：UI 只走 services.ai；历史只存内存（this.chatMsgs），切换笔记清空（D7）
  toggleChat(open){
    const p=$('#chatpanel'); if(!p) return;
    const show = open!==undefined ? open : p.classList.contains('hidden');
    p.classList.toggle('hidden', !show);
    if(show){ this.renderChat(); $('#chatin')?.focus(); }
  }
  renderChat(){
    const list=$('#chatlist'); if(!list) return;
    list.innerHTML = this.chatMsgs.length ? '' :
      `<div class="faint" style="font-size:12px;padding:6px 4px">问我这则笔记的内容，例如「这则在讲什么？」</div>`;
    for(const m of this.chatMsgs) this.chatBubble(m.role, m.content);
  }
  chatBubble(role, text){
    const list=$('#chatlist'); if(!list) return null;
    const el=document.createElement('div'); el.className='cmsg '+(role==='user'?'user':'ai');
    const t=document.createElement('div'); t.className='ctext'; t.textContent=text||'';
    el.appendChild(t); list.appendChild(el); this.chatScroll(); return el;
  }
  chatScroll(){ const l=$('#chatlist'); if(l) l.scrollTop=l.scrollHeight; }
  chatLock(b){
    const i=$('#chatin'), s=$('#chatsend'), st=$('#chatstop');
    if(i) i.disabled=b; if(s) s.disabled=b; if(st) st.classList.toggle('hidden',!b);
  }
  async sendChat(){
    const ta=$('#chatin'); if(!ta||this.chatBusy) return;
    const q=ta.value.trim(); if(!q) return;
    ta.value=''; autoraf(ta);
    this.chatMsgs.push({role:'user',content:q});
    this.chatBubble('user', q);
    const bubble=this.chatBubble('ai','');
    const textEl=bubble.querySelector('.ctext');
    textEl.innerHTML='<span class="faint">思考中…</span>';
    this.chatBusy=true; this.chatLock(true);
    const ac=new AbortController(); this.chatAbort=ac;
    let acc='';
    const meta=(cls,txt)=>{ const m=document.createElement('div'); m.className=cls; m.textContent=txt; bubble.appendChild(m); this.chatScroll(); };
    try{
      await services.ai.chatNote(this.cur.id, this.chatMsgs.slice(), {
        onDelta:t=>{ acc+=t; textEl.textContent=acc; this.chatScroll(); },                        // 逐字接进气泡
        onUsage:u=>meta('cmeta',`tokens: in ${u.input_tokens} / out ${u.output_tokens}`),         // token 用量小字
        onProgress:(c,tot,msg)=>meta('cbadge', msg||'引用到卡'),                                   // 「引用到 M 张卡」徽章
        onError:e=>meta('cerr','出错：'+(e.error||e.code||'未知错误')),                            // 红字错误
      }, ac.signal);
    }catch(e){ meta('cerr','出错：'+(e.message||e)); }
    finally{
      if(!acc) textEl.textContent='';                                  // 没吐半个字（出错/秒停）清掉「思考中…」
      if(ac.signal.aborted && acc) meta('cmeta','（已停止）');
      if(acc) this.chatMsgs.push({role:'ai',content:acc});             // 部分回答也进历史
      this.chatBusy=false; this.chatAbort=null; this.chatLock(false);  // onDone/出错/中断一律解锁
      $('#chatin')?.focus();
    }
  }

  // 加模组选单（垂直、全在屏幕内、列表式无障碍；旋钮手势之后接 GestureService）
  openDial(){
    const d=$('#dial'); $('#scrim').classList.add('open'); d.classList.remove('hidden');
    d.innerHTML=`<div class="dialmenu-head">加模组 · 氛围开发</div>`+MODULES.map((m,i)=>
      `<button class="dialmenu-item ${m.locked?'locked':''}" data-i="${i}"><span class="ic">${svg(m.icon,17,1.8)}</span><span class="nm">${m.name}</span>${m.locked?'<span class="lk">阶段二</span>':''}</button>`).join('');
    d.querySelectorAll('.dialmenu-item').forEach(b=>b.onclick=()=>{ const i=+b.dataset.i;
      if(MODULES[i].locked){ this.toast('AI 模组：阶段二'); return; } this.insertModule(i); });
  }
  closeDial(){ $('#scrim').classList.remove('open'); $('#dial').classList.add('hidden'); }
  async insertModule(i){
    const m=MODULES[i]; const payload = m.id==='todo'?{text:'',done:false}:{content:''};
    const textual=['text','todo','heading'].includes(m.id);
    await services.systems.saveVersion(this.cur.id, textual?'cardEdit':'addModule'); // 加块前落一步
    const block=await services.blocks.add(this.cur.id,{type:m.id,payload,source:'manual'});
    this.cur.blocks=[...(this.cur.blocks||[]),block]; this.closeDial();
    if(this.view==='article') this.appendBlock(block); else this.renderContent();
    this.toast('已插入「'+m.name+'」'); this.refreshHistoryBtns();
  }

  // ---------- 设定 ----------
  settings(){
    const cur=document.documentElement.getAttribute('data-theme');
    const nudgeOn=services.auth.user?.prefs?.ideaNudge!==false; // 点子助攻总开关（F9）
    this.frame(`<div class="view">
      <div class="nav"><button class="link" id="back">${svg('back',20,2)} 返回</button><span class="spacer"></span><span class="title">设定</span><span class="spacer"></span></div>
      <div class="scroll"><div class="pad">
        <div class="card list" style="padding:0">
          <div class="li"><span class="lbl">主题</span><div class="seg" style="margin:0;max-width:170px">
            <button id="t-ob" class="${cur==='obsidian'?'on':''}">黑曜石</button><button id="t-ap" class="${cur==='approach'?'on':''}">亲和</button></div></div>
          <div class="li"><span class="lbl">帐号</span><span class="val">${esc(services.auth.user?.email||'')}</span></div>
          <div class="li" id="logout"><span class="lbl" style="color:var(--primary)">登出</span></div>
        </div>
        <div class="sect">AI</div>
        <div class="card list" style="padding:0">
          <div class="li"><span class="lbl">点子助攻<div class="faint" style="font-size:11px;font-weight:400;margin-top:2px">取名后浮现「⚡ 让 AI 教练看看」胶囊</div></span>
            <button class="switch ${nudgeOn?'on':''}" id="nudgesw" role="switch" aria-checked="${nudgeOn}" aria-label="点子助攻"><i></i></button></div>
        </div>
        <button class="btn btn-danger" id="del" style="width:100%;margin-top:18px">删除帐号</button>
        <div class="faint" style="font-size:11px;margin-top:8px">删除将立即永久移除你的资料、无法复原（正式版会再要求 Apple 验证）。</div>
      </div></div></div>`);
    $('#back').onclick=()=>this.home();
    $('#t-ob').onclick=()=>{ setTheme('obsidian'); this.settings(); };
    $('#t-ap').onclick=()=>{ setTheme('approach'); this.settings(); };
    $('#nudgesw').onclick=async()=>{ // UI 只走服务层（auth.updatePrefs 触点）
      await services.auth.updatePrefs({ideaNudge:!nudgeOn});
      this.toast(!nudgeOn?'已开启点子助攻':'已关闭点子助攻');
      this.settings();
    };
    $('#logout').onclick=async()=>{ await services.auth.signOut(); this.login(); };
    $('#del').onclick=async()=>{ if(!confirm('确定删除帐号？资料将立即永久删除、无法复原。')) return;
      await services.auth.deleteAccount(); this.toast('帐号已删除'); setTimeout(()=>this.login(),600); };
  }
}

// helpers
function esc(s){ return String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])); }
function fmt(iso){ try{ return new Date(iso).toLocaleDateString('zh-CN',{month:'2-digit',day:'2-digit'}); }catch{ return ''; } }
function autoraf(ta){ ta.style.height='auto'; ta.style.height=ta.scrollHeight+'px'; }

window.__app = new App();
window.__app.start();
