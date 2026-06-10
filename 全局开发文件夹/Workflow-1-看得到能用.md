# Workflow-1 · 阶段一开发文档「看得到 & 能用」

> 状态：**5 轮优化迭代中（目标 100%）**。已完成第 1 轮。详见文末「§14 迭代日志」。
> 范围：Step 0 验收页、Step 1 地基+登入、Step 2 自由速记（含完整前端骨架）。
> 第一原则：**前端可替换**——现在云端做过渡 Web 前端，之后 Xcode/SwiftUI 重写；UI 不直接碰后端，全走服务层，所有 API 触点登记成搬迁清单。

---

## 1. 范围与目标
- 做完你会有：能登入、能写笔记、存得住、长得 100% 像成品的 App 骨架。
- **不含 AI**（结构化/对话/全局都在阶段二）。
- **离线同步延后阶段二**（侦察结论）：阶段一**先纯线上**，用伺服器 `updated_at` 做最后写入为准、`deleted_at` 软删除。

## 2. 系统架构（三层，前端可替换）
```
[过渡 Web 前端]  UI 层（画面）  ←只管长相
       │ 只能透过↓
   服务层 / API 客户端（所有后端呼叫集中在这）★搬迁时保留这层的契约
       │ HTTPS + Bearer JWT
[后端] 阶段一 API 端点（薄）→ Supabase（Auth + Postgres + RLS）
```
- 关键：**UI 绝不直接呼叫后端**；一律经服务层。搬去 SwiftUI 时＝重画 UI + 照同契约重做服务层，后端/API 不动。

## 3. 后端

### 3.1 资料表
```
profiles(id=auth.uid, email, created_at)            -- 对应 Supabase Auth user
systems(id, owner_id→profiles, title, visibility['private'|'public'],
        mode['free'|'structured'], version int, tags text[],
        created_at, updated_at, deleted_at)
blocks(id, system_id→systems, type, position int, payload jsonb,
        created_at, updated_at, deleted_at)
索引：systems(owner_id, visibility)、blocks(system_id, position)
```

### 3.2 RLS（资料库层强制「只能看自己」）
- 全表开 RLS、预设拒绝。
- `systems` 读：`owner_id = auth.uid()` 或 `visibility='public'`；写/改/删：`owner_id = auth.uid()`。
- `blocks`：依父 system 的拥有权限。
- 软删除用 `deleted_at`；查询一律 `WHERE deleted_at IS NULL`。

### 3.3 登入（Sign in with Apple）
- iOS 端：原生 Apple 登入 → 拿 identity token → `signInWithIdToken()` 换 Supabase JWT。
- 每个请求带 `Authorization: Bearer <jwt>`；RLS 用 `auth.uid()` 取人。
- **删除帐号**：后端用 `service_role` 呼叫 `admin.deleteUser(uid)` + 连带级联删 systems/blocks。
- ⚠️ 雷区：Apple 金钥每 6 个月要轮替；登出后旧 JWT 仍有效要前端清快取。

### 3.4 同步策略（阶段一）
- **纯线上**：写就送伺服器；伺服器盖 `updated_at`。
- 最后写入为准（单人低冲突）；离线队列＝阶段二再做。

## 4. API 契约（薄端点 = 稳定契约）
> 修订（红队）：**阶段一不自建一堆端点**——CRUD 直接用 Supabase 客户端 SDK + RLS（少写很多、够安全）。真正的「稳定契约 / 搬迁边界」是**服务层介面**（不是 HTTP）。只有两个需要后端：`POST /api/account/delete`（要 service_role）与 `GET /api/status`（公开只读）。下表是**服务层操作**，多数由 SDK 背书；SwiftUI 之后用 Supabase Swift SDK 在自己的服务层重做同一组方法。

| 方法 路径 | 输入 | 输出 | 权限 |
|---|---|---|---|
| POST `/api/account/delete` | — | 204 | 本人 |
| GET `/api/systems?limit&offset` | 分页 | system[] | 本人+公开 |
| POST `/api/systems` | title | system | 本人 |
| GET `/api/systems/:id` | — | system+blocks | 拥有/公开 |
| PATCH `/api/systems/:id` | title/visibility/mode | system | 本人 |
| DELETE `/api/systems/:id` | — | 204(软删) | 本人 |
| POST `/api/systems/:id/blocks` | type/payload/position | block | 本人 |
| PATCH `/api/blocks/:id` | payload/position | block | 本人 |
| DELETE `/api/blocks/:id` | — | 204(软删) | 本人 |
| POST `/api/blocks/reorder` | id[]顺序 | 204 | 本人 |
| GET `/api/status` | — | 各功能灯号 | 公开(只读状态) |

- 统一错误格式：`{ error, code, status_code }`；401 未登入 / 403 无权 / 400 验证。
- 统一 Header：`Authorization: Bearer <jwt>`。

## 5. ★ API 触点登记表（搬迁清单）★
> 前端每个碰后端的地方 = 一条。搬去 SwiftUI 照这表重接服务层即可。

| 触点(服务层方法) | UI 在哪用 | 对应 API | 之后 SwiftUI 怎么接 |
|---|---|---|---|
| `auth.signInWithApple()` | 登入页按钮 | 原生 + signInWithIdToken | `AuthService`（ASAuthorization + Supabase Swift） |
| `auth.deleteAccount()` | 设定页 | POST /api/account/delete | `AuthService.deleteAccount()` |
| `systems.list(page)` | 首页清单 | GET /api/systems | `SystemsService.list()` async |
| `systems.create(title)` | 首页「＋」 | POST /api/systems | `SystemsService.create()` |
| `systems.get(id)` | 打开笔记 | GET /api/systems/:id | `SystemsService.get()` |
| `systems.update(id,patch)` | 改标题/私密公开/模式 | PATCH /api/systems/:id | `SystemsService.update()` |
| `systems.delete(id)` | 删系统 | DELETE /api/systems/:id | `SystemsService.delete()` |
| `blocks.add(sysId,block)` | 旋钮插基础块 | POST …/blocks | `BlocksService.add()` |
| `blocks.update(id,patch)` | 编辑块/拖动 | PATCH /api/blocks/:id | `BlocksService.update()` |
| `blocks.reorder(ids)` | 重新排序 | POST /api/blocks/reorder | `BlocksService.reorder()` |
| `status.get()` | 验收页 | GET /api/status | （验收页是 Web，不搬） |
| `auth.signOut()` | 设定页登出 | 清本地 token | `AuthService.signOut()` |
| `auth.refresh()` | 401 时自动 | SDK 换新 token | SDK 自动（URLSession 拦截器重试） |

## 6. 前端（过渡 Web）

### 6.1 技术
- **Vite + vanilla TypeScript + Web Components**（侦察结论）：一画面一个 `.ts` 元件、单一 `ApiClient`、无重框架、好丢弃。
- 之后丢掉整个 `/web`，**只保留 `ApiClient` 与商业逻辑的契约**给 SwiftUI 重用。

### 6.2 资料夹结构（UI / 服务层分离）
```
/web
  /ui          画面与元件（只管长相，禁止直接 fetch）
    LoginScreen.ts  HomeScreen.ts  NoteScreen.ts  SettingsScreen.ts
    components/ (Card, Chip, SegmentedControl, Dial, Toast, Toolbar…)
  /services    ★唯一能碰后端★（AuthService, SystemsService, BlocksService）
  /api         ApiClient.ts（单一 HTTP 客户端 + Bearer）、endpoints.ts
  /models      DTO ↔ 领域模型 的 mapper
  /design      两套主题色票、字体、tokens
  touchpoints.ts  ★触点登记表（程式化版，对照第 5 节）★
```

### 6.3 设计系统
- 两套主题（黑曜石/亲和）用 CSS 变数；字体层级；缺角卡片、按钮、标签、Toast；图标先用 Lucide（SwiftUI 时换 SF Symbols）。

### 6.4 五个画面规格（重点）
1. **登入页**：Apple 登入钮 + 标语。
2. **首页/我的系统**：系统卡清单（标题/私密公开标/时间/摘要/标签）+「＋」。
3. **笔记页**：顶部返回+系统名+私密公开切换；**双模式切换**（自由速记可用 / AI 结构化＝空状态占位）；自由速记编辑；**底部工具列 + 加模组旋钮**（能转能选，插基础块：文字/待办/标题；AI 模组占位）。
4. **设定页**：主题切换、登出、**删除帐号**。
5. **(Step 0) 验收页**：见第 8 节。

## 7. SwiftUI 搬迁映射（先写好，搬迁省力）
| Web | SwiftUI |
|---|---|
| 画面元件 | `View` struct |
| 画面状态 | `@Observable` ViewModel / `@State` |
| services/ | Service/Repository（async/await + URLSession） |
| ApiClient | URLSession + `Endpoint` enum + Codable |
| DTO/models | `Codable` struct |
| 画面跳转 | `NavigationStack` |
| 本地储存 | SwiftData |
- 好搬的：独立画面、REST 为主、单一职责元件。
- 雷区：SwiftUI 状态要不可变、UI 更新要主线程（@MainActor）。

## 8. Step 0 验收页规格
- 一页 iOS 样式 HTML（沿用主题色票），读 `GET /api/status`。
- 灯号：DB✅ / 登入 / 读写 / 离线(本阶段灰) / 结构化(灰，阶段二)…
- 显示：系统数、最近一笔时间、各端点是否通。
- 部署成网址，你随时刷新看进度。

## 9. 验收标准（每盏灯怎样算亮）
- **登入灯**：能 Apple 登入、拿到 JWT、能登出。
- **DB/读写灯**：新增系统→重开仍在；写速记→存得住。
- **权限灯**：A 用户看不到 B 用户的私密系统（RLS 实测）。
- **删帐号灯**：删除后资料消失、无法再登入旧资料。
- **前端骨架灯**：5 画面都在；旋钮能转能插基础块；双模式能切。
- **可替换灯**：全前端无一处直接 fetch；touchpoints.ts 覆盖所有呼叫。

## 10. App Store 阶段一合规（先内建，不回头）
- **删除帐号 UI**：放设定页明显处（硬规定）。
- **隐私政策**网址 + **隐私标签**（收集：email、笔记）。
- **加密声明** ITSAppUsesNonExemptEncryption = false（只用 HTTPS）。
- **登入同意**一句话说明：「收集 email 供登入、储存你的笔记」。
- Sign in with Apple：当主登入（即使现在非强制也用它最干净）。

## 11. 派工计划（这阶段开发时）
- 工兵·后端①②③④：建表+RLS / Auth+删号 / （同步延后）/ API 端点。
- 工兵·前端⑤⑥⑦⑧：设计系统 / 5 画面 / 旋钮+双模式空壳 / 服务层+触点登记。
- 搬迁兵：维护第 5、7 节。
- 验收兵：Step 0 页 + 第 9 节灯号。
- 红队：照第 12 节攻击。

## 12. 95% 检核表
- [ ] 前端零处直接呼叫后端（全走服务层）
- [ ] 每个画面用到的后端，触点表都有一条
- [ ] 每个 API：输入/输出/权限/错误齐全
- [ ] 资料表+RLS 完整、A 看不到 B 私密
- [ ] Auth 含删除帐号
- [ ] 每个步骤有可验收灯号条件
- [ ] SwiftUI 搬迁映射完整、工作量最小
- [ ] 与蓝图 01/02/03 零矛盾
- [ ] 离线延后、AI 不在本阶段——范围正确

---

## 13. 红队修补（v1.0 增补，逐条补齐）

### 13.1 区块类型与 payload（阶段一只开 3 种基础块）
| type | payload 结构 | 说明 |
|---|---|---|
| `text` | `{ content }` | 文字段落 |
| `todo` | `{ text, done }` | 待办（可勾） |
| `heading` | `{ text, level(1\|2) }` | 小标题 |
> 需要 AI 的模组（心智图/分析…）阶段一在旋钮上**显示但不可选（上锁灰）**，阶段二才开。

### 13.2 画面状态（每个画面都要有四态）
- **载入中** / **空状态** / **错误+重试** / **正常**。
- 首页无系统：插画 +「建立第一个系统」+「＋」仍在。
- 空笔记：占位「开始写…」，旋钮可用。
- 结构化分页（阶段一）：占位「还没整理 — 阶段二接 AI」。

### 13.3 离线侦测（虽不做同步，仍要不掉资料）
- 用 `navigator.onLine` + 请求逾时；离线时顶部横幅「目前离线，稍后再试」，写入按钮暂禁、本地保留草稿。

### 13.4 旋钮互动规格（抽成 GestureService，方便搬 SwiftUI）
- 左下角触发 → 拖动旋转 → 吸附最近格 → 点中心插入。
- 只列阶段一 3 种基础块可选；AI 模组上锁。
- **手势逻辑放 `GestureService`**，不写死在 DOM；SwiftUI 用 `DragGesture`＋旋转角度重做。
- 无障碍：也提供「列表式」加模组当后备（旋钮坏了也能加）。

### 13.5 登出与 JWT
- 登出：清本地 access/refresh token → 回登入页（不需后端端点）。
- 令牌过期：碰到 401 → SDK 自动用 refresh token 换新再重试；refresh 也失效 → 强制重新登入。

### 13.6 安全与 RLS（补明确）
- `blocks` 明确策略：读 `父system.visibility='public' OR 父.owner=auth.uid()`；写 `父.owner=auth.uid()`。
- **service_role 金钥只在后端环境变数，绝不进前端**（删帐号端点用）。
- 软删不加 title 唯一键（id 用 UUID）；查询一律 `deleted_at IS NULL`。
- 幂等：`POST …/blocks` 与 `/blocks/reorder` 带 `Idempotency-Key`，重试不重复。

### 13.7 分页
- 预设 `limit=20, offset=0`；回 `{ items, total, hasMore }`。

### 13.8 触点表补两条
- `auth.signOut()`（清 token）、`auth.refresh()`（换新 token）也登记进 `touchpoints.ts`。

### 13.9 搬迁额外铁律（让 SwiftUI 省力）
- **禁用 Shadow DOM**、禁 keyframe 动画库；只用 CSS transition（并先标注对应 SwiftUI spring）。
- 事件回呼里**不准直接改 DOM**；一律 state → 绑定更新。
- 所有 JWT 处理现在就写清楚，附 Swift SDK 等价做法。

### 13.10 App Store 阶段一（补到可执行）
- **删除帐号流程**：设定页「删除帐号」→ 确认弹窗（写明「资料将立即永久删除、无法复原」）→ **重新用 Apple 登入验证** → 立即删除并级联清资料。
- **隐私政策**：写一页 `privacy.md` 部署成网页，URL 写进 App。
- **隐私标签答案**：email＝仅供登入(与你关联、不追踪)；笔记＝使用者内容(随帐号删除)；无 IDFA/追踪。
- **加密声明** = false（仅 HTTPS）；日后若加本地加密再改。
- **登入策略**：阶段一**强制 Apple 登入才能用**（无访客模式），登入页一句话说明用途。

> 以上补完，第 12 节检核表全部可勾 ✅ → 视为 **95% 达标**。

---

## 14. 迭代日志（5 轮优化）

### 第 1 轮 · 可建造性 + 内部一致性（→ v1.1）

**后端补强**
- **删帐号鉴权**：`/api/account/delete` 先从 JWT 取 uid，确认 = 本人才用 service_role 呼叫 `admin.deleteUser`；不符回 401。service_role 只在后端环境变数。
- **profiles 自动建立**：Supabase Auth `on_auth_user_created` 触发器，首次 Apple 登入即插入 `profiles(id, email)`。
- **updated_at 触发器**：systems/blocks `BEFORE UPDATE SET updated_at=now()`。
- **删除语义分清**：删「帐号」= 硬删 Auth user + `ON DELETE CASCADE` 连带硬删 systems/blocks；删「单一系统/区块」= 软删（`deleted_at`）。
- **`/api/status` 回应格式**：`{ db:bool, auth:bool, read_write:bool, rls:bool, delete_account:bool, frontend_skeleton:bool, updated_at }`（灰灯 = false）。仅回基础设施健康，不含 token 状态。
- **幂等**：`Idempotency-Key` 存一张小表、TTL 24h；插入前先查，命中就回上次结果。
- **reorder 语义**：单一交易内，把每个 id 的 `position` 设为阵列索引；任一 id 非本人拥有则整批失败。

**前端补强**
- **导航图**：Step0 验收页独立；App 内 `登入 → 首页 → (笔记 | 设定)`；未登入一律导回登入。
- **DI（不靠全域单例）**：一个 `composition root`（工厂）建立 Auth/Systems/Blocks Service，用建构子注入各画面。
- **反应式（无框架）**：每个 Service 继承 `EventTarget`，资料变动时 `dispatchEvent`；画面 `addEventListener` 订阅后重渲染。（对应 SwiftUI 的 `@Observable`）
- **旋钮数学**：角度 = `atan2`；360/格数 吸附最近格；放开停在最近格、点中心插入。阶段一仅 3 基础块可选，AI 模组上锁。
- **主题切换**：在根元素设 `data-theme`，CSS 变数覆盖；元件都用变数 → 自动换肤。
- **触点强制**：ESLint 规则禁止在 `/services`、`/api` 以外出现 `fetch`/supabase 呼叫（pre-commit 挡）。
- **可复用四态**：统一 class `.state-loading / .state-empty / .state-error / .state-ok`，所有画面共用。
- **Step0 取数**：载入骨架 → 失败显示错误+重试 → 成功点灯。

**一致性修正**
- §4 区块 payload 结构 → 指向 §13.1（text/todo/heading）。
- §5 触点表补 `auth.signOut()`、`auth.refresh()`（已加）。
- `version int`：定义为「编辑版本号」，每次内容大改 +1，阶段一仅显示于 trace（不做回溯）。
- `tags`：阶段一为**使用者手动**在笔记标头加/删；自动打标签属阶段二（AI）。

**第 1 轮缺陷数：后端 7 + 前端 8 + 一致性 5 = 20，已全部修补。**
