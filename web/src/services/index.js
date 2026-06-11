// services/index.js — 服务层（唯一能碰后端）。UI 一律走这里。
// 每个 Service 继承 EventTarget；资料变动时 dispatch → UI 订阅后重渲染。
// 对应 SwiftUI 的 @Observable ViewModel / Service。
import { Mock, splitIntoBlocks } from '../api/mockClient.js';
import { BACKEND } from '../config.js';
export { splitIntoBlocks }; // §1.2b 切块纯函式（UI 经服务层取用，不直碰 api/）
export const AI_BACKEND = BACKEND.ai; // UI 判断 mock/real 用（不直碰 config）

// ================= 阶段二 Step 3 · 纯函式（hash / diff / 安全阀 / 合并计画）=================
// 架构裁定：资料真相在浏览器 localStorage → hash gate、块级 diff（F3）、合并层＋钉选保护＋
// 安全阀（F2）、套用前快照、更新 aiHash/lastAiHash/docState 全在前端服务层；server 无状态只调 Claude。

export const CHANGE_RATIO_CAP = 0.3; // F2：单一更新块字数变化超过 ±30% → 整批拒绝
export const TOUCH_RATIO_CAP = 0.5;  // F2：一次 patch「改＋删」块数 > 未钉选块总数 × 50% → 整批拒绝

const DIFF_TYPES = ['text', 'heading'];          // 参与 diff/优化/结构化的「文字/标题类」
const TEXTUAL_BLOCK_TYPES = ['text', 'heading', 'todo'];
export const isModuleBlock = b => !TEXTUAL_BLOCK_TYPES.includes(b?.type); // 模组块＝天生钉选（F8）

// normalize（F3）：trim + 连续空白折成一格
export function normalizeText(s){ return String(s ?? '').trim().replace(/\s+/g, ' '); }
// FNV-1a 32-bit（模拟层无安全需求，F3 允许 FNV）；输入先 normalize
function fnv1a(s){
  let h = 0x811c9dc5;
  for(let i = 0; i < s.length; i++){ h ^= s.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; }
  return ('0000000' + h.toString(16)).slice(-8);
}
export function fnvHash(str){ return fnv1a(normalizeText(str)); }

// 块 → 文字内容（text/heading 用 content、todo 用 text、模组块用 payload JSON）
export function blockContent(b){
  const p = b?.payload || {};
  if(p.content !== undefined) return String(p.content || '');
  if(p.text !== undefined) return String(p.text || '');
  return JSON.stringify(p);
}

// 全文指纹（F3）：全部未软删块的 normalize(content) 按 position 以 \n\n 串接后 hash
export function fullHash(blocks){
  const joined = (blocks || []).slice().sort((a, b) => a.position - b.position)
    .map(b => normalizeText(blockContent(b))).join('\n\n');
  return fnv1a(joined);
}

// hash gate（§1.2 ⑤ 省钱铁律）：全文指纹 == lastAiHash → 不叫 AI、零成本
export function shouldSkipAi(sys, blocks){
  return !!sys?.lastAiHash && fullHash(blocks) === sys.lastAiHash;
}

// 块级 diff（F3）：只算文字/标题类、未钉选的；aiHash==null（新写）或不符（改过）= changed
export function diffBlocks(blocks){
  const changed = [], unchanged = [];
  for(const b of (blocks || []).slice().sort((a, c) => a.position - c.position)){
    const diffable = DIFF_TYPES.includes(b.type) && !b.pinned;
    if(diffable && (b.aiHash == null || fnvHash(blockContent(b)) !== b.aiHash)) changed.push(b);
    else unchanged.push(b);
  }
  return { changed, unchanged };
}

// 去空白与标点（F2 删除合法性判定用）
const stripAll = s => String(s || '').replace(/[\s\p{P}\p{S}]/gu, '');

// F2 安全阀（纯函式，程式判定、不信 AI）：优化 patch 整批检查
// changedIdSet = 本次 diff 出的变动块 id（patch 只准碰这些）
export function checkOptimizePatch(blocks, patch, changedIdSet){
  const adds = patch?.adds || [], updates = patch?.updates || [], removes = patch?.removes || [];
  const byId = new Map((blocks || []).map(b => [b.id, b]));
  // touch_ratio（F2 修正）：变动块本来就全部该被整理，分母应是「本次变动块数」而非未钉选总数的一半——
  // 否则首次优化（全部块皆 changed）会被误杀。改/删不得超过变动块数（合并场景 1 update+1 remove 仍≤changed）。
  // 「AI 乱动没变的块」由下方 touch_forbidden 100% 拦截，不靠这条。
  if((updates.length + removes.length) > changedIdSet.size)
    return { ok:false, reason:`touch_ratio：动＋删 ${updates.length + removes.length} 块，超过本次变动块数 ${changedIdSet.size}` };
  for(const u of updates){
    const b = byId.get(u.id);
    if(!b) return { ok:false, reason:`unknown_block：update 指到不存在的块 ${u.id}` };
    if(b.pinned || isModuleBlock(b) || !changedIdSet.has(b.id))
      return { ok:false, reason:'touch_forbidden：update 碰到钉选/模组/没变的块' };
    const oldLen = normalizeText(blockContent(b)).length, newLen = normalizeText(u.content).length;
    if(Math.abs(newLen - oldLen) > Math.max(oldLen, 1) * CHANGE_RATIO_CAP)
      return { ok:false, reason:`change_ratio：单块字数变化超过 ±30%（${oldLen}→${newLen} 字）` };
  }
  for(const id of removes){
    const b = byId.get(id);
    if(!b) return { ok:false, reason:`unknown_block：remove 指到不存在的块 ${id}` };
    if(b.pinned || isModuleBlock(b) || !changedIdSet.has(b.id))
      return { ok:false, reason:'touch_forbidden：remove 碰到钉选/模组/没变的块' };
    // 删除合法性（F2-b 合并场景）：被删块内容归一化后 ≥50% 字符以连续片段出现在某 update 里
    const rc = stripAll(blockContent(b));
    const need = Math.ceil(rc.length * 0.5);
    const legal = rc.length === 0 || updates.some(u => {
      const uc = stripAll(u.content);
      for(let i = 0; i + need <= rc.length; i++) if(uc.includes(rc.slice(i, i + need))) return true;
      return false;
    });
    if(!legal) return { ok:false, reason:'illegal_remove：被删块内容仍在，不是合并场景' };
  }
  for(const a of adds){
    if(!DIFF_TYPES.includes(a?.type)) return { ok:false, reason:'bad_add：新增块 type 只能是 text/heading' };
    if(!String(a?.content || '').trim()) return { ok:false, reason:'bad_add：新增块内容不可为空' };
  }
  return { ok:true };
}

// 结构化卡片安全检查（F2 精神）：空卡不收、吸收钉选/模组块整批拒绝
export function checkStructureCards(blocks, cards){
  if(!Array.isArray(cards) || !cards.length) return { ok:false, reason:'empty_cards：AI 没有回传任何卡' };
  const byId = new Map((blocks || []).map(b => [b.id, b]));
  for(const c of cards){
    if(!String(c?.title || '').trim() || !String(c?.content || '').trim())
      return { ok:false, reason:'empty_card：有卡缺标题或内容' };
    for(const id of (c.absorbed || [])){
      const b = byId.get(id);
      if(b && (b.pinned || isModuleBlock(b)))
        return { ok:false, reason:'touch_pinned：卡吸收了钉选/模组块的内容' };
    }
  }
  return { ok:true };
}

// 结构化合并计画（纯函式）：删除全部未钉选文字/标题块、按卡顺序建新块（type 'text'、payload {title,content}）；
// 钉选块与模组块按原 position 排序穿插回去（简单策略）。回传有序 entries：{isNew, ...} | {isNew:false, block}
export function computeStructuredBlocks(blocks, cards){
  const sorted = (blocks || []).slice().sort((a, b) => a.position - b.position);
  const kept = sorted.filter(b => !(DIFF_TYPES.includes(b.type) && !b.pinned));
  const gen = sorted.reduce((m, b) => Math.max(m, b.structureGen || 0), 0) + 1;
  const out = (cards || []).map(c => ({
    isNew: true, type: 'text',
    payload: { title: String(c.title || ''), content: String(c.content || '') },
    source: 'ai', pinned: false, structureGen: gen, aiHash: fnvHash(String(c.content || '')),
  }));
  for(const b of kept) out.splice(Math.min(Math.max(0, b.position | 0), out.length), 0, { isNew: false, block: b });
  return out;
}

// ===== 套用层（合并＋落库；含安全阀，被拒回 {ok:false, reason} 不动资料）=====

// 套用优化 patch：安全阀 → updates/removes/adds 落库 → 更新受影响块 aiHash、系统 lastAiHash/docState 等
export async function applyOptimizePatch(systemId, patch){
  const sys = await Mock.getSystem(systemId);
  const blocks = (sys.blocks || []).slice().sort((a, b) => a.position - b.position);
  const changedIdSet = new Set(diffBlocks(blocks).changed.map(b => b.id));
  const verdict = checkOptimizePatch(blocks, patch, changedIdSet);
  if(!verdict.ok) return verdict; // 不套用、不动资料（快照已在呼叫端先存，内容没变会被去重）
  const removes = new Set(patch.removes || []);
  for(const u of (patch.updates || [])){
    const b = blocks.find(x => x.id === u.id);
    await Mock.updateBlock(u.id, { payload: { ...b.payload, content: u.content }, aiHash: fnvHash(u.content) });
  }
  for(const id of removes) await Mock.deleteBlock(id);
  // adds：照 position 插入目前顺序（一次 reorder 收尾）
  const order = blocks.filter(b => !removes.has(b.id)).map(b => b.id);
  const adds = (patch.adds || []).slice().sort((a, b) => (a.position || 0) - (b.position || 0));
  for(const a of adds){
    const payload = a.type === 'heading' ? { content: a.content, level: 2 } : { content: a.content };
    const nb = await Mock.addBlock(systemId, { type: a.type, payload, source: 'ai', aiHash: fnvHash(a.content) });
    order.splice(Math.min(Math.max(0, a.position | 0), order.length), 0, nb.id);
  }
  await Mock.reorderBlocks(systemId, order);
  const fresh = await Mock.getSystem(systemId);
  await Mock.updateSystem(systemId, {
    lastAiHash: fullHash(fresh.blocks),
    docState: sys.docState === 'carded' ? 'carded' : 'optimized', // 已卡片化不降级（卡片页签不回灰）
    ai_restructure_count: (sys.ai_restructure_count || 0) + 1,
    structuredAt: new Date().toISOString(),
  });
  return { ok:true, applied: (patch.updates || []).length + (patch.adds || []).length, removed: removes.size };
}

// 套用结构化卡阵列：检查 → 删未钉选文字/标题块 → 建新卡块 → 钉选/模组块穿插回原相对顺序 → 更新系统栏位
export async function applyStructureCards(systemId, cards){
  const sys = await Mock.getSystem(systemId);
  const blocks = sys.blocks || [];
  const verdict = checkStructureCards(blocks, cards);
  if(!verdict.ok) return verdict;
  const plan = computeStructuredBlocks(blocks, cards);
  for(const b of blocks) if(DIFF_TYPES.includes(b.type) && !b.pinned) await Mock.deleteBlock(b.id);
  const order = [];
  for(const e of plan){
    if(e.isNew){
      const nb = await Mock.addBlock(systemId, { type: e.type, payload: e.payload,
        source: e.source, aiHash: e.aiHash, structureGen: e.structureGen });
      order.push(nb.id);
    } else order.push(e.block.id);
  }
  await Mock.reorderBlocks(systemId, order);
  const fresh = await Mock.getSystem(systemId);
  await Mock.updateSystem(systemId, {
    lastAiHash: fullHash(fresh.blocks),
    docState: 'carded',
    ai_restructure_count: (sys.ai_restructure_count || 0) + 1,
    structuredAt: new Date().toISOString(),
  });
  return { ok:true, count: cards.length };
}

// real 模式：fetch + ReadableStream 逐行解析 SSE（§3 整合设计——EventSource 带不了 POST/header）
async function realStream(endpoint, body, onEvent, signal){
  const res = await fetch(BACKEND.aiBaseUrl + endpoint, {
    method:'POST',
    headers:{ 'Authorization':'Bearer '+BACKEND.authToken, 'Content-Type':'application/json' },
    body: JSON.stringify(body), signal,
  });
  if(!res.ok || !res.body){
    let detail=''; try{ detail=(await res.json()).error; }catch{}
    onEvent({ type:'error', code:'http_'+res.status, error: detail||('HTTP '+res.status) });
    return;
  }
  const reader = res.body.getReader(); const dec = new TextDecoder(); let buf='';
  while(true){
    const { done, value } = await reader.read();
    if(done) break;
    buf += dec.decode(value, { stream:true });
    let i;
    while((i = buf.indexOf('\n\n')) >= 0){
      const line = buf.slice(0, i).trim(); buf = buf.slice(i + 2);
      if(line.startsWith('data: ')){ try{ onEvent(JSON.parse(line.slice(6))); }catch{} }
    }
  }
}

// 把当前笔记序列化成 real 后端契约的 note 形状（{title, blocks:[{type,content,pinned}]}）
function serializeNote(sys){
  const text = b => b?.payload?.content ?? b?.payload?.text ?? '';
  return {
    title: sys?.title || '未命名',
    blocks: (sys?.blocks || []).map(b => ({ type:b.type, content:text(b), pinned:!!b.pinned })),
  };
}

class Base extends EventTarget {
  changed(detail){ this.dispatchEvent(new CustomEvent('change',{detail})); }
}

export class AuthService extends Base {
  user=null;
  async init(){ this.user=await Mock.me(); this.changed(); return this.user; }
  async signInWithApple(){ this.user=await Mock.signInWithApple(); this.changed(); return this.user; }
  async signOut(){ await Mock.signOut(); this.user=null; this.changed(); }
  async deleteAccount(){ await Mock.deleteAccount(); this.user=null; this.changed(); }
  async me(){ return this.user; }
}

export class SystemsService extends Base {
  async list(){ return Mock.listSystems(); }
  async create(title){ const s=await Mock.createSystem(title); this.changed({type:'create',s}); return s; }
  async get(id){ return Mock.getSystem(id); }
  async update(id,patch){ const s=await Mock.updateSystem(id,patch); this.changed({type:'update',s}); return s; }
  async setVisibility(id,v){ return this.update(id,{visibility:v}); }
  async setMode(id,m){ return this.update(id,{mode:m}); } // v3 废弃：docState 由后端在 AI 操作时更新；视图切换纯前端
  async delete(id){ await Mock.deleteSystem(id); this.changed({type:'delete',id}); }
  // ---- 版本安全网（structure_versions 快照；附录 F7）----
  // 模拟层限定：会改内容的操作「动手前」由 UI 经这里落一步；真后端在各操作端点内自动快照
  async saveVersion(id,trigger){ return Mock.saveVersion(id,trigger); }
  async undo(id){ const r=await Mock.undoVersion(id); if(r) this.changed({type:'restore'}); return r; }
  async redo(id){ const r=await Mock.redoVersion(id); if(r) this.changed({type:'restore'}); return r; }
  async versions(id){ return Mock.listVersions(id); }
  async restore(id,v){ const r=await Mock.restoreVersion(id,v); this.changed({type:'restore'}); return r; }
}

export class BlocksService extends Base {
  async add(systemId,block){ return Mock.addBlock(systemId,block); }
  async update(id,patch){ return Mock.updateBlock(id,patch); }
  async toggleDone(id,payload){ return Mock.updateBlock(id,{payload}); }
  async delete(id){ return Mock.deleteBlock(id); }
  async reorder(systemId,ids){ return Mock.reorderBlocks(systemId,ids); }
  async pin(id,pinned){ return Mock.updateBlock(id,{pinned}); } // 钉选：AI 永不改/删/跨越
}

export class StatusService extends Base { async get(){ return Mock.status(); } }

// 阶段二 · AI 服务（开发文档 §3）。串流过程走 handlers 回调（不广播）；
// 完成落库后才 changed({type:'ai', op}) 派事件。signal = AbortSignal（F8 第四参数）。
export class AIService extends Base {
  // Step 1 底层：所有 AI 方法共用的串流 transport——把引擎 emit 的 SSE 事件按 §3 介面分发
  async _stream(endpoint, payload, handlers={}, signal){
    const h=handlers;
    const dispatch = ev=>{
      switch(ev.type){
        case 'delta':        h.onDelta?.(ev.text); break;
        case 'usage':        h.onUsage?.(ev); break;
        case 'progress':     h.onProgress?.(ev.current, ev.total, ev.message); break;
        case 'card_start':   h.onCardStart?.(ev.index, ev.title, ev.type); break;
        case 'card_done':    h.onCard?.(ev.index, ev.card); break;
        case 'card_removed': h.onCardRemoved?.(ev.cardId); break;
        case 'hit_list':     h.onHit?.(ev.systems); break;
        case 'done':         h.onDone?.(); break;
        case 'error':        h.onError?.(ev); break;
      }
    };
    if(BACKEND.ai === 'real') await realStream(endpoint, payload, dispatch, signal);
    else await Mock.aiStream(endpoint, payload, dispatch, signal);
  }
  async health(){
    if(BACKEND.ai === 'real'){
      try{ const r=await fetch(BACKEND.aiBaseUrl+'/ai/health'); return await r.json(); }
      catch(e){ return { ok:false, error:String(e) }; }
    }
    return Mock.aiHealth();
  }
  // Step 2 单笔记聊天：messages=[{role:'user'|'ai',content}]，AI 知道这则的全部 blocks
  // real 模式契约：POST {messages, note:{title, blocks:[{type,content,pinned}]}}（前端只送内容收结果）
  async chatNote(systemId, messages, handlers={}, signal){
    let payload;
    if(BACKEND.ai === 'real'){
      const sys = await Mock.getSystem(systemId);
      payload = { messages, note: serializeNote(sys) };
    } else payload = { systemId, messages };
    await this._stream('/ai/chat/note', payload, {
      ...handlers,
      onDone: ()=>{ handlers.onDone?.(); this.changed({ type:'ai', op:'chatNote' }); },
    }, signal);
  }

  // ---- Step 3 ✦ 优化文字（§1.2 八步管线；合并层在前端，server 只调 Claude）----
  // 串流事件先收集成 patch，整批过安全阀后才落库；途中 handlers 只当进度回报。
  async optimize(systemId, { groupTopics = false } = {}, handlers = {}, signal){
    const h = handlers;
    try{
      const sys = await Mock.getSystem(systemId);
      const blocks = sys.blocks || [];
      // ① hash gate：全文指纹没变 → 零网络、零成本结束
      if(shouldSkipAi(sys, blocks)){
        h.onProgress?.(1, 1, '内容没变，未消耗 AI'); h.onDone?.();
        return { ok:true, skipped:true };
      }
      if(BACKEND.ai !== 'real'){
        h.onError?.({ type:'error', code:'need_real_backend', error:'此功能需要真后端（config.js 切 real）' });
        return { ok:false, reason:'need_real_backend' };
      }
      // ② 块级 diff：只送变动块标记，没变/钉选/模组块当只读上下文
      const { changed } = diffBlocks(blocks);
      if(!changed.length){
        h.onProgress?.(1, 1, '没有可优化的变动段落，未消耗 AI'); h.onDone?.();
        return { ok:true, skipped:true };
      }
      const changedIds = new Set(changed.map(b => b.id));
      const note = { title: sys.title || '未命名', blocks: blocks.slice()
        .sort((a, b) => a.position - b.position)
        .map(b => ({ id: b.id, type: b.type, content: blockContent(b),
          pinned: !!b.pinned, changed: changedIds.has(b.id) })) };
      // ③ 收集 SSE 事件组成三件式 patch
      const patch = { adds: [], updates: [], removes: [] };
      let errEv = null;
      await realStream('/ai/optimize', { note, groupTopics: !!groupTopics }, ev => {
        switch(ev.type){
          case 'card_done': { const c = ev.card || {};
            if(c.action === 'add') patch.adds.push({ type: c.type, content: c.content, position: c.position });
            else if(c.action === 'update') patch.updates.push({ id: c.id, content: c.content });
            h.onCard?.(ev.index, c); break; }
          case 'card_removed': patch.removes.push(ev.cardId); h.onCardRemoved?.(ev.cardId); break;
          case 'usage':    h.onUsage?.(ev); break;
          case 'progress': h.onProgress?.(ev.current, ev.total, ev.message); break;
          case 'error':    errEv = ev; break;
        }
      }, signal);
      if(errEv){ h.onError?.(errEv); return { ok:false, reason: errEv.code }; }
      // ④ 套用前快照（trigger='optimize'，一步）→ 安全阀＋合并落库
      await Mock.saveVersion(systemId, 'optimize');
      const r = await applyOptimizePatch(systemId, patch);
      if(!r.ok){ h.onError?.({ type:'error', code:'safety_valve', error: r.reason }); return r; }
      await Mock.setLamp('optimize'); // 验收灯（db.meta.lamps）
      this.changed({ type:'ai', op:'optimize' });
      h.onDone?.();
      return r;
    }catch(e){
      if(signal?.aborted) return { ok:false, reason:'aborted' };
      h.onError?.({ type:'error', code:'network', error: String(e?.message || e) });
      return { ok:false, reason:'network' };
    }
  }

  // ---- Step 3 ▦ 卡片结构化（mode:'full'；incremental 留 Step 5）----
  async structure(systemId, { mode = 'full' } = {}, handlers = {}, signal){
    const h = handlers;
    try{
      const sys = await Mock.getSystem(systemId);
      const blocks = sys.blocks || [];
      // hash gate 仅在已卡片化（docState==='carded'）时生效；首次必跑
      if(sys.docState === 'carded' && shouldSkipAi(sys, blocks)){
        h.onProgress?.(1, 1, '内容没变，未消耗 AI'); h.onDone?.();
        return { ok:true, skipped:true };
      }
      if(BACKEND.ai !== 'real'){
        h.onError?.({ type:'error', code:'need_real_backend', error:'此功能需要真后端（config.js 切 real）' });
        return { ok:false, reason:'need_real_backend' };
      }
      const note = { title: sys.title || '未命名', blocks: blocks.slice()
        .sort((a, b) => a.position - b.position)
        .map(b => ({ id: b.id, type: b.type, content: blockContent(b),
          pinned: !!b.pinned, module: isModuleBlock(b) })) };
      const cards = []; let errEv = null;
      await realStream('/ai/structure', { note, mode: 'full' }, ev => {
        switch(ev.type){
          case 'card_start': h.onCardStart?.(ev.index, ev.title, ev.type); break;
          case 'card_done':  cards.push(ev.card); h.onCard?.(ev.index, ev.card); break;
          case 'usage':      h.onUsage?.(ev); break;
          case 'progress':   h.onProgress?.(ev.current, ev.total, ev.message); break;
          case 'error':      errEv = ev; break;
        }
      }, signal);
      if(errEv){ h.onError?.(errEv); return { ok:false, reason: errEv.code }; }
      // 套用前快照（trigger='structure'，一步）→ 检查＋整批替换落库
      await Mock.saveVersion(systemId, 'structure');
      const r = await applyStructureCards(systemId, cards);
      if(!r.ok){ h.onError?.({ type:'error', code:'safety_valve', error: r.reason }); return r; }
      await Mock.setLamp('structure'); // 验收灯
      this.changed({ type:'ai', op:'structure' });
      h.onDone?.();
      return r;
    }catch(e){
      if(signal?.aborted) return { ok:false, reason:'aborted' };
      h.onError?.({ type:'error', code:'network', error: String(e?.message || e) });
      return { ok:false, reason:'network' };
    }
  }
}
