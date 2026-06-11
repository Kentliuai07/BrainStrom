// services/index.js — 服务层（唯一能碰后端）。UI 一律走这里。
// 每个 Service 继承 EventTarget；资料变动时 dispatch → UI 订阅后重渲染。
// 对应 SwiftUI 的 @Observable ViewModel / Service。
import { Mock, splitIntoBlocks } from '../api/mockClient.js';
export { splitIntoBlocks }; // §1.2b 切块纯函式（UI 经服务层取用，不直碰 api/）

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
    await Mock.aiStream(endpoint, payload, ev=>{
      switch(ev.type){
        case 'delta':        h.onDelta?.(ev.text); break;
        case 'usage':        h.onUsage?.(ev); break;
        case 'progress':     h.onProgress?.(ev.current, ev.total, ev.message); break;
        case 'card_done':    h.onCard?.(ev.index, ev.card); break;
        case 'card_removed': h.onCardRemoved?.(ev.cardId); break;
        case 'hit_list':     h.onHit?.(ev.systems); break;
        case 'done':         h.onDone?.(); break;
        case 'error':        h.onError?.(ev); break;
      }
    }, signal);
  }
  async health(){ return Mock.aiHealth(); }
  // Step 2 单笔记聊天：messages=[{role:'user'|'ai',content}]，AI 知道这则的全部 blocks
  async chatNote(systemId, messages, handlers={}, signal){
    await this._stream('/ai/chat/note', { systemId, messages }, {
      ...handlers,
      onDone: ()=>{ handlers.onDone?.(); this.changed({ type:'ai', op:'chatNote' }); },
    }, signal);
  }
}
