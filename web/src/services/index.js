// services/index.js — 服务层（唯一能碰后端）。UI 一律走这里。
// 每个 Service 继承 EventTarget；资料变动时 dispatch → UI 订阅后重渲染。
// 对应 SwiftUI 的 @Observable ViewModel / Service。
import { Mock } from '../api/mockClient.js';

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
  async setMode(id,m){ return this.update(id,{mode:m}); }
  async delete(id){ await Mock.deleteSystem(id); this.changed({type:'delete',id}); }
}

export class BlocksService extends Base {
  async add(systemId,block){ return Mock.addBlock(systemId,block); }
  async update(id,patch){ return Mock.updateBlock(id,patch); }
  async toggleDone(id,payload){ return Mock.updateBlock(id,{payload}); }
  async delete(id){ return Mock.deleteBlock(id); }
  async reorder(systemId,ids){ return Mock.reorderBlocks(systemId,ids); }
}

export class StatusService extends Base { async get(){ return Mock.status(); } }
