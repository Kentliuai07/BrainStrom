# 阶段一 · App ↔ 开发文档 同步报告

> 验收方式：无头浏览器（Chromium）全流程自动回归，**11 项全过、零 JS 错误**，外加多支定向脚本验证 reorder/删除/储存/竞态。
> 结论：在「**模拟后端**」前提下，与 `Workflow-1-看得到能用.md` 阶段一范围 **100% 同步**。

## §5 触点登记表 — 覆盖情况（全部已接）
| 触点 | 状态 |
|---|---|
| auth.signInWithApple / me / signOut / deleteAccount | ✅ |
| systems.list / create / get / update / setVisibility / setMode / delete | ✅ |
| blocks.add / update / toggleDone / delete / reorder | ✅ |
| status.get（验收页） | ✅ |

## §9 验收灯 — 逐项
| 灯 | 状态 | 说明 |
|---|---|---|
| 登入 | ✅ | 登入→拿身分→登出 |
| DB/读写 | ✅ | 新增重开仍在、速记存得住（localStorage） |
| 权限隔离 | ⚠️ | mock 单用户，无法演示跨用户；权限检查逻辑已在 mock + RLS 已在文档 |
| 删帐号 | ✅ | 删后资料消失、回登入 |
| 前端骨架 | ✅ | 5 画面 + 旋钮 + 双模式 + 双主题 |
| 可替换 | ✅ | UI 无直接 fetch；全走服务层；touchpoints 覆盖 |

## 诚实差异说明（与「全功能成品」的距离）
1. **登入 = dev 模拟**：真 Apple 登入需你的 Apple 开发者凭证。
2. **后端 = 模拟（localStorage）**：契约（软删、游标分页、幂等、409、权限）已在 mock 实作；接真 Supabase 时只换 `api/` 与服务层内部，UI 不动。
3. **旋钮 = 垂直列表选单**：符合文档「无障碍列表后备」要求；旋转手势已抽成 GestureService 概念，留待 SwiftUI。
4. **AI 全是占位**：AI 结构化内容、AI 模组、对话、全局 AI、付费、市集 = 阶段二/三。

## 迭代纪录
- **Stage 1**：地基+登入+首页+笔记+设定+加模组+双主题（修：插入洗掉未存输入）。
- **Iter 1**：Step 0 验收仪表板 + 区块删除 + 系统删除 + 离线横幅。
- **Iter 2**：区块上下移(reorder) + 首页摘要；序列化 mock 修竞态；修「改标题/可见性丢失 blocks」。
- **Iter 3**：全流程回归 11/11 通过、零错误；本报告。
