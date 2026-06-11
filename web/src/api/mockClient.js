// mockClient.js — 模拟后端（localStorage）。模拟文档 §4 的 API 契约。
// 之后换成真 Supabase 时，只要替换这个档案与服务层内部，UI 不动。
// v2（阶段二地基 A）：活文件模型——blocks 补 source/pinned/aiHash/structureGen、
// systems 补 lastAiHash/docState/ai_restructure_count/structuredAt、
// 旧 body block 迁移成段落块、版本快照 + Undo/Redo（附录 F1/F7）。
const KEY = 'brainstrom.mock.v1';
const DB_SOFT_LIMIT = 4*1024*1024; // localStorage 约 5MB；超 4MB 从「中段」精简版本（F7）
const sleep = (ms=180)=>new Promise(r=>setTimeout(r,ms));
const uid = ()=>'id_'+Math.random().toString(36).slice(2,10);
const now = ()=>new Date().toISOString();

// 模组类 type ＝ 非纯文字块（表格/GitHub/进度环…），恒钉选、AI 永不动其内容（F8）
const TEXTUAL_TYPES = ['text','heading','todo'];
const isModuleType = t => !TEXTUAL_TYPES.includes(t);

// §1.2b 切块规则（body 迁移与文末续写共用）：
// 按一个以上连续空行切段；行首 # 的标题行独立成 heading 块（#数量>1 算 level 2）；
// 代码围栏 ``` 内不切（整段含围栏归一个 text 块）。
export function splitIntoBlocks(text){
  const lines = String(text??'').split('\n');
  const out=[]; let buf=[]; let inFence=false;
  const flush=()=>{ const s=buf.join('\n'); buf=[];
    if(s.trim()) out.push({ type:'text', payload:{ content:s } }); };
  for(const line of lines){
    if(/^\s*```/.test(line)){ buf.push(line); inFence=!inFence; continue; } // 围栏行归同一块
    if(inFence){ buf.push(line); continue; }                                // 围栏内不切
    if(!line.trim()){ flush(); continue; }                                  // 空行＝段落边界
    if(/^#/.test(line)){                                                    // 行首 # 标题独立成块
      flush();
      const m=line.match(/^(#+)\s*(.*)$/);
      out.push({ type:'heading', payload:{ content:m[2], level: m[1].length>1?2:1 } });
      continue;
    }
    buf.push(line);
  }
  flush();
  return out;
}

function load(){ try{return JSON.parse(localStorage.getItem(KEY))||{}}catch{ return {} } }
function save(db){
  let json=JSON.stringify(db);
  if(json.length>DB_SOFT_LIMIT && db.versions){ // F7：从中段丢，永远保第 1 版与最近 50 版
    for(const sid of Object.keys(db.versions)){
      const arr=db.versions[sid]; if(!arr || arr.length<=51) continue;
      const pointed=arr[db.versionPtr?.[sid]]?.version;
      const trimmed=[arr[0], ...arr.slice(-50)];
      db.versions[sid]=trimmed;
      const ni=trimmed.findIndex(v=>v.version===pointed);
      db.versionPtr[sid]= ni>=0 ? ni : trimmed.length-1;
    }
    (db.meta ||= {}).versionsTrimmed=true;
    json=JSON.stringify(db);
  }
  localStorage.setItem(KEY, json);
}
function init(){
  const db = load();
  db.users ||= {}; db.systems ||= {}; db.blocks ||= {}; db.session ||= null;
  db.versions ||= {}; db.versionPtr ||= {}; db.meta ||= {};
  migrateV2(db);
  save(db); return db;
}

// ---- 版本快照工具（附录 F7 指针法）----
function liveBlocks(db, systemId){
  return Object.values(db.blocks).filter(b=>b.systemId===systemId && !b.deletedAt)
    .sort((a,b)=>a.position-b.position);
}
function snapshotJson(db, systemId){ return JSON.stringify(liveBlocks(db, systemId)); }
// 落一步：砍掉指针之后的版本（清 Redo）→ append 快照 → 指针=末位。
// 与末位快照内容相同时去重（不重复落步）。
function pushVersion(db, systemId, trigger){
  const arr = db.versions[systemId] ||= [];
  const ptr = db.versionPtr[systemId] ?? arr.length-1;
  arr.length = Math.max(ptr+1, 0);
  const json = snapshotJson(db, systemId);
  if(arr.length && arr[arr.length-1].blocksJson===json){
    db.versionPtr[systemId]=arr.length-1; return arr[arr.length-1];
  }
  const v = { version: arr.length ? arr[arr.length-1].version+1 : 1,
    blocksJson:json, trigger, createdAt:now() };
  arr.push(v); db.versionPtr[systemId]=arr.length-1; return v;
}
// 整批还原某快照（id 稳定：快照内的块原 id 覆写回去；现存而快照没有的块软删）
function applySnapshot(db, systemId, snap){
  const blocks = JSON.parse(snap.blocksJson);
  const keep = new Set(blocks.map(b=>b.id));
  for(const b of Object.values(db.blocks))
    if(b.systemId===systemId && !b.deletedAt && !keep.has(b.id)) b.deletedAt=now();
  for(const b of blocks) db.blocks[b.id]={ ...b, deletedAt:null };
  const s=db.systems[systemId]; if(s) s.updatedAt=now();
  return blocks;
}

// ---- migrateV2（附录 F1）：load() 时跑、幂等 ----
function migrateV2(db){
  if((db.meta.schemaVersion||0) >= 2) return;
  for(const s of Object.values(db.systems)){
    const sysBlocks = Object.values(db.blocks).filter(b=>b.systemId===s.id && !b.deletedAt);
    const body = sysBlocks.find(b=>b.type==='text' && b.payload?.role==='body');
    if(body){
      const content = body.payload.content || '';
      if(content.trim()){
        const segs = splitIntoBlocks(content);
        const others = sysBlocks.filter(b=>b!==body).sort((a,b)=>a.position-b.position);
        others.forEach((b,i)=>{ b.position = segs.length + i; }); // 原有其他块顺延
        segs.forEach((seg,i)=>{
          const nb={ id:uid(), systemId:s.id, type:seg.type, position:i, payload:seg.payload,
            source:'notes', pinned:false, aiHash:null, structureGen:0,
            createdAt:now(), updatedAt:now(), deletedAt:null };
          db.blocks[nb.id]=nb;
        });
      }
      body.deletedAt=now(); // 软删旧 body（空 body 不建空块）
    }
    // 其余既有块补默认值；text/heading payload 统一只留 content（旧 text/role 键丢弃）
    for(const b of Object.values(db.blocks)){
      if(b.systemId!==s.id || b.deletedAt) continue;
      if(b.source===undefined) b.source='notes';
      if(b.pinned===undefined) b.pinned=isModuleType(b.type); // 模组类天生钉选
      if(b.aiHash===undefined) b.aiHash=null;
      if(b.structureGen===undefined) b.structureGen=0;
      if(b.type==='text') b.payload={ content: b.payload?.content ?? b.payload?.text ?? '' };
      if(b.type==='heading') b.payload={ content: b.payload?.content ?? b.payload?.text ?? '', level: b.payload?.level ?? 1 };
    }
    if(s.lastAiHash===undefined) s.lastAiHash=null;
    if(s.docState===undefined) s.docState='raw';
    if(s.ai_restructure_count===undefined) s.ai_restructure_count=0;
    if(s.structuredAt===undefined) s.structuredAt=null;
    pushVersion(db, s.id, 'migrate'); // 每系统第 1 版快照＝最早原稿，永远找得回
  }
  db.meta.schemaVersion = 2;
}

const RawMock = {
  // ---- auth ----
  async signInWithApple(){
    await sleep(); const db=init();
    let userId = Object.keys(db.users)[0];
    if(!userId){ userId=uid(); db.users[userId]={ id:userId, email:'you@privaterelay.appleid.com', createdAt:now() }; }
    db.session=userId; save(db);
    return { ...db.users[userId] };
  },
  async me(){ const db=init(); return db.session? {...db.users[db.session]} : null; },
  async signOut(){ const db=init(); db.session=null; save(db); },
  async deleteAccount(){
    await sleep(); const db=init(); const u=db.session; if(!u) throw err(401);
    for(const s of Object.values(db.systems)) if(s.ownerId===u){ delete db.systems[s.id];
      for(const b of Object.values(db.blocks)) if(b.systemId===s.id) delete db.blocks[b.id];
      delete db.versions[s.id]; delete db.versionPtr[s.id]; }
    delete db.users[u]; db.session=null; save(db);
  },
  // ---- systems ----
  async listSystems(){
    await sleep(); const db=init(); const u=requireUser(db);
    const items=Object.values(db.systems)
      .filter(s=>!s.deletedAt && (s.ownerId===u || s.visibility==='public'))
      .sort((a,b)=>b.updatedAt.localeCompare(a.updatedAt))
      .map(s=>{ const fb=Object.values(db.blocks).filter(b=>b.systemId===s.id&&!b.deletedAt)
          .sort((a,b)=>a.position-b.position)[0];
        const snip=fb?(fb.payload.content||fb.payload.text||''):''; return {...s, snippet:snip.slice(0,60)}; });
    return { items, nextCursor:null, hasMore:false };
  },
  async createSystem(title){
    await sleep(); const db=init(); const u=requireUser(db);
    const t=(title||'未命名系统').slice(0,256);
    const s={ id:uid(), ownerId:u, title:t, visibility:'private', mode:'free', version:1, tags:[],
      lastAiHash:null, docState:'raw', ai_restructure_count:0, structuredAt:null,
      createdAt:now(), updatedAt:now(), deletedAt:null };
    db.systems[s.id]=s; save(db); return {...s};
  },
  async getSystem(id){
    await sleep(120); const db=init(); const u=requireUser(db); const s=db.systems[id];
    if(!s||s.deletedAt|| (s.ownerId!==u && s.visibility!=='public')) throw err(404);
    const blocks=Object.values(db.blocks).filter(b=>b.systemId===id && !b.deletedAt).sort((a,b)=>a.position-b.position);
    return { ...s, blocks };
  },
  async updateSystem(id, patch){
    await sleep(120); const db=init(); const u=requireUser(db); const s=db.systems[id];
    if(!s||s.deletedAt||s.ownerId!==u) throw err(404);
    if(patch.title!==undefined) s.title=patch.title.slice(0,256);
    if(patch.visibility!==undefined) s.visibility=patch.visibility;
    if(patch.mode!==undefined) s.mode=patch.mode;
    s.version++; s.updatedAt=now(); save(db); return {...s};
  },
  async deleteSystem(id){
    await sleep(); const db=init(); const u=requireUser(db); const s=db.systems[id];
    if(!s||s.ownerId!==u) throw err(404); s.deletedAt=now(); save(db);
  },
  // ---- blocks ----
  async addBlock(systemId, block){
    await sleep(100); const db=init(); const u=requireUser(db); const s=db.systems[systemId];
    if(!s||s.ownerId!==u) throw err(404);
    const positions=Object.values(db.blocks).filter(b=>b.systemId===systemId&&!b.deletedAt).map(b=>b.position);
    const pos=block.position ?? (positions.length?Math.max(...positions)+1:0);
    const mod=isModuleType(block.type);
    const b={ id:uid(), systemId, type:block.type, position:pos, payload:block.payload||{},
      source: block.source ?? 'manual',
      pinned: mod ? true : (block.pinned ?? false), // 模组类强制钉选（F8），呼叫方不可解
      aiHash: block.aiHash ?? null,
      structureGen: block.structureGen ?? 0,
      createdAt:now(), updatedAt:now(), deletedAt:null };
    db.blocks[b.id]=b; s.updatedAt=now(); save(db); return {...b};
  },
  async updateBlock(id, patch){
    await sleep(60); const db=init(); const u=requireUser(db); const b=db.blocks[id];
    if(!b||b.deletedAt) throw err(404); const s=db.systems[b.systemId]; if(!s||s.ownerId!==u) throw err(404);
    if(patch.payload!==undefined) b.payload=patch.payload;
    if(patch.position!==undefined) b.position=patch.position;
    if(patch.pinned!==undefined) b.pinned = isModuleType(b.type) ? true : !!patch.pinned; // 模组卡恒钉选
    b.updatedAt=now(); s.updatedAt=now(); save(db); return {...b};
  },
  async deleteBlock(id){
    await sleep(80); const db=init(); const u=requireUser(db); const b=db.blocks[id];
    if(!b) throw err(404); const s=db.systems[b.systemId]; if(!s||s.ownerId!==u) throw err(404);
    b.deletedAt=now(); save(db);
  },
  async reorderBlocks(systemId, ids){
    await sleep(80); const db=init(); const u=requireUser(db); const s=db.systems[systemId];
    if(!s||s.ownerId!==u) throw err(404);
    const current=Object.values(db.blocks).filter(b=>b.systemId===systemId&&!b.deletedAt).map(b=>b.id);
    if(ids.length!==current.length || !ids.every(id=>current.includes(id))) throw err(409); // 原子：集合不符则失败
    ids.forEach((id,i)=>{ db.blocks[id].position=i; }); s.updatedAt=now(); save(db);
  },
  // ---- versions / Undo / Redo（附录 F7 指针法；structure_versions 的模拟层等价物）----
  // 每个会改内容的操作「动手前」先呼叫 saveVersion 落一步（trigger 枚举见 §1.3 表）。
  async saveVersion(systemId, trigger='cardEdit'){
    await sleep(40); const db=init(); const u=requireUser(db); const s=db.systems[systemId];
    if(!s||s.deletedAt||s.ownerId!==u) throw err(404);
    const v=pushVersion(db, systemId, trigger); save(db);
    return { version:v.version, trigger:v.trigger, createdAt:v.createdAt };
  },
  // 上一步：指针-1 并整批还原；指针在末位且现状有未存档变更时，先把现状入快照（保证 redo 能回来）
  async undoVersion(systemId){
    await sleep(60); const db=init(); const u=requireUser(db); const s=db.systems[systemId];
    if(!s||s.deletedAt||s.ownerId!==u) throw err(404);
    const arr=db.versions[systemId]||[];
    if(!arr.length) return null;
    let ptr=db.versionPtr[systemId] ?? arr.length-1;
    const cur=snapshotJson(db, systemId);
    if(ptr===arr.length-1 && arr[ptr].blocksJson!==cur){
      arr.push({ version:arr[arr.length-1].version+1, blocksJson:cur, trigger:'cardEdit', createdAt:now() });
      ptr=arr.length-1;
    }
    if(ptr<=0){ db.versionPtr[systemId]=ptr; save(db); return null; } // 越界回 null
    ptr-=1; db.versionPtr[systemId]=ptr;
    const blocks=applySnapshot(db, systemId, arr[ptr]); save(db); return blocks;
  },
  // 下一步：指针+1 并整批还原；越界回 null
  async redoVersion(systemId){
    await sleep(60); const db=init(); const u=requireUser(db); const s=db.systems[systemId];
    if(!s||s.deletedAt||s.ownerId!==u) throw err(404);
    const arr=db.versions[systemId]||[];
    if(!arr.length) return null;
    let ptr=db.versionPtr[systemId] ?? arr.length-1;
    if(ptr>=arr.length-1) return null;
    ptr+=1; db.versionPtr[systemId]=ptr;
    const blocks=applySnapshot(db, systemId, arr[ptr]); save(db); return blocks;
  },
  async listVersions(systemId){
    await sleep(40); const db=init(); const u=requireUser(db); const s=db.systems[systemId];
    if(!s||s.deletedAt||s.ownerId!==u) throw err(404);
    const arr=db.versions[systemId]||[];
    const ptr=db.versionPtr[systemId] ?? arr.length-1;
    const dirty = arr.length>0 && ptr===arr.length-1 && arr[ptr].blocksJson!==snapshotJson(db, systemId);
    return {
      items: arr.map(v=>({ version:v.version, trigger:v.trigger, createdAt:v.createdAt })),
      ptr,
      canUndo: arr.length>0 && (ptr>0 || dirty),
      canRedo: arr.length>0 && ptr<arr.length-1,
      trimmed: !!db.meta.versionsTrimmed,
    };
  },
  // 一键还原到指定版本（还原前先存当前一步，还原本身可再 undo）
  async restoreVersion(systemId, version){
    await sleep(60); const db=init(); const u=requireUser(db); const s=db.systems[systemId];
    if(!s||s.deletedAt||s.ownerId!==u) throw err(404);
    const snap=(db.versions[systemId]||[]).find(v=>v.version===version);
    if(!snap) throw err(404);
    pushVersion(db, systemId, 'restore');
    const blocks=applySnapshot(db, systemId, snap); save(db); return blocks;
  },
  // ---- status (验收页) ----
  async status(){
    const db=init();
    return { db:true, auth:!!db.session, read_write:true, rls:true, delete_account:true,
      frontend_skeleton:true,
      // 阶段二 7 盏灯（各 Step 完成后点亮，现在全灭是正常）
      ai_engine:false, chat_note:false, optimize:false, structure:false,
      structure_incremental:false, global_recall:false, git_progress:false,
      systems:Object.values(db.systems).filter(s=>!s.deletedAt).length, updatedAt:now() };
  }
};
function requireUser(db){ if(!db.session) throw err(401); return db.session; }
function err(code){ const e=new Error('http '+code); e.status=code; return e; }

// 序列化所有呼叫，避免「读整包→改→写回」的并发竞态（真 DB 不需要这层）
function serialize(obj){
  let chain=Promise.resolve(); const out={};
  for(const k of Object.keys(obj)){ const fn=obj[k];
    out[k]=(...a)=>{ const r=chain.then(()=>fn.apply(obj,a)); chain=r.catch(()=>{}); return r; }; }
  return out;
}
export const Mock = serialize(RawMock);
