// touchpoints.js — ★API 触点登记表（搬迁清单）★ 对应开发文档 §5。
// 之后搬 SwiftUI：照这张表，用 Supabase Swift SDK 在自己的服务层重做同一组方法。
export const TOUCHPOINTS = [
  { method:'auth.signInWithApple()', ui:'登入页', api:'signInWithIdToken', swift:'AuthService (ASAuthorization + Supabase Swift)' },
  { method:'auth.me()',              ui:'启动载入', api:'SDK getUser', swift:'AuthService.me()' },
  { method:'auth.signOut()',         ui:'设定页登出', api:'清本地 token', swift:'AuthService.signOut()' },
  { method:'auth.deleteAccount()',   ui:'设定页删帐号', api:'POST /api/account/delete', swift:'AuthService.deleteAccount()' },
  { method:'systems.list()',         ui:'首页清单', api:'GET /api/systems?cursor', swift:'SystemsService.list()' },
  { method:'systems.create(title)',  ui:'首页＋', api:'POST /api/systems', swift:'SystemsService.create()' },
  { method:'systems.get(id)',        ui:'打开笔记', api:'GET /api/systems/:id', swift:'SystemsService.get()' },
  { method:'systems.update(id,p)',   ui:'改标题', api:'PATCH /api/systems/:id', swift:'SystemsService.update()' },
  { method:'systems.setVisibility',  ui:'私密/公开', api:'PATCH …{visibility}', swift:'SystemsService.update()' },
  { method:'systems.setMode',        ui:'双模式切换 (v3 废弃——docState 由后端在 AI 操作时更新；视图切换纯前端)', api:'PATCH …{mode}', swift:'SystemsService.update()' },
  { method:'systems.delete(id)',     ui:'删系统', api:'DELETE /api/systems/:id', swift:'SystemsService.delete()' },
  { method:'blocks.add(sid,b)',      ui:'旋钮插块', api:'POST …/blocks', swift:'BlocksService.add()' },
  { method:'blocks.update(id,p)',    ui:'编辑块', api:'PATCH /api/blocks/:id', swift:'BlocksService.update()' },
  { method:'blocks.toggleDone(id)',  ui:'待办勾选', api:'PATCH …{payload.done}', swift:'BlocksService.update()' },
  { method:'blocks.delete(id)',      ui:'删块', api:'DELETE /api/blocks/:id', swift:'BlocksService.delete()' },
  { method:'status.get()',           ui:'验收页', api:'GET /api/status', swift:'(验收页是 Web,不搬)' },
  // ---- 阶段二 · 版本安全网与钉选（开发文档 §3 表）----
  { method:'systems.undo(id)',       ui:'笔记页·上一步钮', api:'POST /api/systems/:id/undo', swift:'SystemsService.undo()' },
  { method:'systems.redo(id)',       ui:'笔记页·下一步钮', api:'POST /api/systems/:id/redo', swift:'SystemsService.redo()' },
  { method:'systems.versions(id)',   ui:'笔记页·版本列表', api:'GET /api/systems/:id/versions', swift:'SystemsService.versions()' },
  { method:'systems.restore(id,v)',  ui:'笔记页·版本列表', api:'POST /api/systems/:id/restore', swift:'SystemsService.restore()' },
  { method:'blocks.pin(id,bool)',    ui:'卡片·钉选开关', api:'PATCH /api/blocks/:id{pinned}', swift:'BlocksService.update()' },
  // ---- 阶段二 · AI（Step 1 引擎 + Step 2 单笔记聊天；模拟层↔Fly.io 层签名与 SSE 协议一致）----
  { method:'ai.health()',            ui:'验收页', api:'GET /ai/health', swift:'AIService.health()' },
  { method:'ai.chatNote(id,msgs)',   ui:'笔记底部聊天浮层', api:'POST /ai/chat/note', swift:'AIService.chatNote()' },
];
