// mockClient.js — 模拟后端（localStorage）。模拟文档 §4 的 API 契约。
// 之后换成真 Supabase 时，只要替换这个档案与服务层内部，UI 不动。
const KEY = 'brainstrom.mock.v1';
const sleep = (ms=180)=>new Promise(r=>setTimeout(r,ms));
const uid = ()=>'id_'+Math.random().toString(36).slice(2,10);
const now = ()=>new Date().toISOString();

function load(){ try{return JSON.parse(localStorage.getItem(KEY))||{}}catch{ return {} } }
function save(db){ localStorage.setItem(KEY, JSON.stringify(db)); }
function init(){
  const db = load();
  db.users ||= {}; db.systems ||= {}; db.blocks ||= {}; db.session ||= null;
  save(db); return db;
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
      for(const b of Object.values(db.blocks)) if(b.systemId===s.id) delete db.blocks[b.id]; }
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
    const b={ id:uid(), systemId, type:block.type, position:pos, payload:block.payload||{},
      createdAt:now(), updatedAt:now(), deletedAt:null };
    db.blocks[b.id]=b; s.updatedAt=now(); save(db); return {...b};
  },
  async updateBlock(id, patch){
    await sleep(60); const db=init(); const u=requireUser(db); const b=db.blocks[id];
    if(!b||b.deletedAt) throw err(404); const s=db.systems[b.systemId]; if(!s||s.ownerId!==u) throw err(404);
    if(patch.payload!==undefined) b.payload=patch.payload;
    if(patch.position!==undefined) b.position=patch.position;
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
  // ---- status (验收页) ----
  async status(){
    const db=init();
    return { db:true, auth:!!db.session, read_write:true, rls:true, delete_account:true,
      frontend_skeleton:true, systems:Object.values(db.systems).filter(s=>!s.deletedAt).length, updatedAt:now() };
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
