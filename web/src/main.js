// main.js — 组合根 + 路由 + 画面。UI 只透过 services 碰后端。
import { AuthService, SystemsService, BlocksService, StatusService } from './services/index.js';

// ---- 组合根（建立并注入服务，无全域单例滥用）----
const services = {
  auth: new AuthService(),
  systems: new SystemsService(),
  blocks: new BlocksService(),
  status: new StatusService(),
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
    this.frame(`<div class="view">
      <div class="scroll"><div class="pad">
        <div class="row"><div><div class="faint" style="font-size:12px">我的系统</div><div class="h1">BrainStrom</div></div>
          <div class="spacer"></div>
          <button class="iconbtn" id="settings">${svg('gear')}</button>
          <button class="iconbtn accent" id="add">${svg('plus')}</button></div>
        <div class="banner">${svg('sparkles',15,2)} 阶段一骨架：登入/清单/速记/旋钮可用；AI 为占位</div>
        <div id="syslist"><div class="muted" style="padding:20px 0">载入中…</div></div>
      </div></div></div>`);
    $('#settings').onclick=()=>this.settings();
    $('#add').onclick=async ()=>{ const s=await services.systems.create('未命名系统'); this.note(s.id); };
    try{
      const { items } = await services.systems.list();
      const box=$('#syslist');
      if(!items.length){ box.innerHTML=`<div class="empty"><div class="big">📓</div><div>还没有系统</div>
        <button class="btn" id="first">建立第一个系统</button></div>`;
        $('#first').onclick=async()=>{ const s=await services.systems.create('未命名系统'); this.note(s.id); }; return; }
      box.innerHTML = items.map(s=>`<button class="syscard" data-id="${s.id}">
        <div class="row"><span class="pill ${s.visibility==='private'?'priv':'pub'}">${svg(s.visibility==='private'?'lock':'globe',9,2)} ${s.visibility==='private'?'私密':'公开'}</span>
        <span class="spacer"></span><span class="faint" style="font-size:10px">${fmt(s.updatedAt)}</span></div>
        <div class="sys-title">${esc(s.title)}</div>
        <div class="sys-snip">${esc(s.snippet||'（空白系统，点开开始写）')}</div>
        ${s.tags?.length?`<div class="tags">${s.tags.map(t=>`<span class="tag">${esc(t)}</span>`).join('')}</div>`:''}
      </button>`).join('');
      box.querySelectorAll('.syscard').forEach(b=>b.onclick=()=>this.note(b.dataset.id));
    }catch(e){ $('#syslist').innerHTML=`<div class="empty"><div>载入失败</div><button class="btn" id="retry">重试</button></div>`;
      $('#retry').onclick=()=>this.home(); }
  }

  // ---------- 笔记 ----------
  async note(id){
    this.frame(`<div class="view">
      <div class="nav"><button class="link" id="back">${svg('back',20,2)} 系统</button>
        <span class="spacer"></span>
        <div class="seg"><button id="m-free" class="on">自由速记</button><button id="m-struct">AI 结构化</button></div>
        <span class="spacer"></span>
        <button class="pill priv" id="vis" style="border:none">${svg('lock',9,2)} 私密</button></div>
      <div class="scroll"><div class="pad" id="content"><div class="muted">载入中…</div></div></div>
      <div class="dock"><button class="iconbtn accent" id="chat">${svg('chat')}</button>
        <button class="iconbtn" id="dsys">${svg('trash')}</button>
        <span class="spacer"></span><span class="savechip" id="save"></span></div>
      <button class="fab" id="fab">+</button>
      <div class="dial-scrim" id="scrim"></div><div class="dial hidden" id="dial"></div>
    </div>`);
    $('#back').onclick=()=>this.home();
    $('#chat').onclick=()=>this.toast('AI 对话：阶段二');
    $('#dsys').onclick=async()=>{ if(!confirm('删除这个系统？此动作无法复原。')) return;
      await services.systems.delete(this.cur.id); this.toast('已删除系统'); setTimeout(()=>this.home(),300); };
    let sys; try{ sys=await services.systems.get(id); }catch{ this.toast('打不开'); return this.home(); }
    this.cur=sys; this.mode='free';
    const renderVis=()=>{ const v=$('#vis'); v.className='pill '+(sys.visibility==='private'?'priv':'pub');
      v.innerHTML=`${svg(sys.visibility==='private'?'lock':'globe',9,2)} ${sys.visibility==='private'?'私密':'公开'}`; };
    renderVis();
    $('#vis').onclick=async()=>{ const u=await services.systems.setVisibility(id, sys.visibility==='private'?'public':'private'); sys.visibility=u.visibility; this.cur=sys; renderVis(); };
    $('#m-free').onclick=()=>this.setMode('free');
    $('#m-struct').onclick=()=>this.setMode('structured');
    this.fab=$('#fab'); this.fab.onclick=()=>this.openDial();
    $('#scrim').onclick=()=>this.closeDial();
    this.renderContent();
  }
  setMode(m){ this.mode=m; $('#m-free').classList.toggle('on',m==='free'); $('#m-struct').classList.toggle('on',m==='structured');
    services.systems.setMode(this.cur.id,m); this.renderContent(); $('#fab').classList.toggle('hidden',m!=='free'); }
  renderContent(){
    const c=$('#content');
    if(this.mode==='structured'){ c.innerHTML=`<div class="structured-empty">还没整理<br>—— 阶段二接 AI 后，这里会变成结构化的卡片</div>`; return; }
    c.innerHTML=`<input class="note-title" id="title" value="${esc(this.cur.title)}" />
      <div class="blocks" id="blocks"></div>`;
    $('#title').onblur=async e=>{ const v=e.target.value.trim()||'未命名系统'; const u=await services.systems.update(this.cur.id,{title:v}); this.cur.title=u.title; this.cur.version=u.version; this.saved(); };
    this.renderBlocks();
  }
  renderBlocks(){
    const wrap=$('#blocks'); const bs=this.cur.blocks||[];
    wrap.innerHTML='';
    if(!bs.length){ wrap.innerHTML=`<div class="faint" id="bhint" style="padding:6px 8px">开始写…（左下角 ＋ 加模组）</div>`; return; }
    bs.forEach(b=>this.appendBlock(b));
  }
  appendBlock(b){
    const wrap=$('#blocks'); const hint=$('#bhint'); if(hint) hint.remove();
    const tmp=document.createElement('div'); tmp.innerHTML=this.blockHTML(b);
    const node=tmp.firstElementChild; wrap.appendChild(node); this.wireBlock(node,b);
  }
  wireBlock(node,b){
    if(b.type==='todo'){ node.querySelector('.tick').onclick=async()=>{ const done=!b.payload.done;
      b.payload={...b.payload,done}; node.querySelector('.tick').classList.toggle('on',done);
      await services.blocks.toggleDone(b.id,b.payload); this.saved(); }; }
    const ta=node.querySelector('textarea');
    if(ta){ ta.oninput=()=>autoraf(ta); ta.onblur=async()=>{
      if(b.type==='todo') b.payload.text=ta.value; else { b.payload.content=ta.value; b.payload.text=ta.value; }
      await services.blocks.update(b.id,{payload:b.payload}); this.saved(); }; autoraf(ta); }
    const del=node.querySelector('.bdel');
    if(del) del.onclick=async()=>{ await services.blocks.delete(b.id);
      this.cur.blocks=this.cur.blocks.filter(x=>x.id!==b.id); node.remove();
      if(!this.cur.blocks.length) this.renderBlocks(); this.toast('已删除区块'); };
    node.querySelectorAll('.bmv').forEach(btn=>btn.onclick=async()=>{
      const arr=this.cur.blocks, idx=arr.findIndex(x=>x.id===b.id);
      const ni=btn.dataset.d==='up'?idx-1:idx+1; if(ni<0||ni>=arr.length) return;
      [arr[idx],arr[ni]]=[arr[ni],arr[idx]];
      await services.blocks.reorder(this.cur.id, arr.map(x=>x.id)); this.renderBlocks(); this.saved(); });
  }
  blockHTML(b){
    const del=`<div class="btools"><button class="bmv" data-d="up" aria-label="上移">▲</button><button class="bmv" data-d="dn" aria-label="下移">▼</button><button class="bdel" aria-label="删除区块">${svg('trash',12,1.8)}</button></div>`;
    if(b.type==='todo') return `<div class="block todo" data-b="${b.id}"><span class="tick ${b.payload.done?'on':''}">${b.payload.done?svg('check',13,2.4):''}</span><textarea rows="1" placeholder="待办…">${esc(b.payload.text||'')}</textarea>${del}</div>`;
    if(b.type==='heading') return `<div class="block heading" data-b="${b.id}"><textarea rows="1" placeholder="标题">${esc(b.payload.content||b.payload.text||'')}</textarea>${del}</div>`;
    return `<div class="block" data-b="${b.id}"><textarea rows="1" placeholder="写点什么…">${esc(b.payload.content||b.payload.text||'')}</textarea>${del}</div>`;
  }
  saved(){ const s=$('#save'); if(s){ s.textContent='已储存'; setTimeout(()=>{ if(s) s.textContent=''; },1200);} }

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
    const block=await services.blocks.add(this.cur.id,{type:m.id,payload});
    this.cur.blocks=[...(this.cur.blocks||[]),block]; this.closeDial(); this.appendBlock(block); this.toast('已插入「'+m.name+'」');
  }

  // ---------- 设定 ----------
  settings(){
    const cur=document.documentElement.getAttribute('data-theme');
    this.frame(`<div class="view">
      <div class="nav"><button class="link" id="back">${svg('back',20,2)} 返回</button><span class="spacer"></span><span class="title">设定</span><span class="spacer"></span></div>
      <div class="scroll"><div class="pad">
        <div class="card list" style="padding:0">
          <div class="li"><span class="lbl">主题</span><div class="seg" style="margin:0;max-width:170px">
            <button id="t-ob" class="${cur==='obsidian'?'on':''}">黑曜石</button><button id="t-ap" class="${cur==='approach'?'on':''}">亲和</button></div></div>
          <div class="li"><span class="lbl">帐号</span><span class="val">${esc(services.auth.user?.email||'')}</span></div>
          <div class="li" id="logout"><span class="lbl" style="color:var(--primary)">登出</span></div>
        </div>
        <button class="btn btn-danger" id="del" style="width:100%;margin-top:18px">删除帐号</button>
        <div class="faint" style="font-size:11px;margin-top:8px">删除将立即永久移除你的资料、无法复原（正式版会再要求 Apple 验证）。</div>
      </div></div></div>`);
    $('#back').onclick=()=>this.home();
    $('#t-ob').onclick=()=>{ setTheme('obsidian'); this.settings(); };
    $('#t-ap').onclick=()=>{ setTheme('approach'); this.settings(); };
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
