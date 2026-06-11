# 阶段二开发文档 · 变聪明（AI 功能 Step 1～7）

> 这份是 BrainStrom 阶段二「变聪明」的正式开发蓝图。给之后正式开发的 AI / 工程师照着做。
> 上半部讲「不变的地基与规则」，下半部「第 1～7 步」每步都能直接派代理开工，最后有「前端验收点」「风险降级」「中文命名表」「待你拍板的决策」。
> 配套阅读：`docs/HANDOFF-incremental-restructure.md`、`docs/增量结构化-SBIR模组完整记录与开发设计.md`（Step 5 的权威设计来源）、`全局开发文件夹/03-开发步骤与策略.md`（阶段总蓝图）。
>
> 建立日期：2026-06-11　｜　开发顺序：方案 A（先地基＋共用引擎，再用最简单的 AI 功能验证，再做复杂的）
> 本文档经 6 个探勘代理 + 1 个 Plan 代理交叉验证现有代码后产出。
> **v2（2026-06-11 同日改版）**：写入使用者最新共识「三层内容模型」——原始散文 AI 永不碰、一份结构化内容渲染成「优化散文＋卡片」两种皮、AI 可改可删未钉选的卡、安全网改为「版本快照＋一键还原＋上一步/下一步」。旧版「手改卡 AI 永不动」铁律已废除，见 §0.2 与 §1.2。

---

## 第 0 章 · 背景、铁律、已拍板决策

### 0.1 三条铁律（每一步都要守）

1. **金钥永不进前端**：所有 Claude 呼叫都在 Fly.io 的 AI 代理上跑，前端只送原文、收结果。
2. **UI 只走服务层**：前端不直接碰后端，一律经 `services/`。这样之后搬 SwiftUI 照 `touchpoints.js` 重接即可。
3. **模拟层与 Fly.io 层「接口签名 + SSE 事件协议」必须一模一样**：UI 零改动就能从假后端切到真后端。`touchpoints.js` 是这两层之间「唯一的契约真相」。

### 0.2 已拍板决策（硬规则，不可违反；2026-06-11 改版）

> ⚠️ 旧版第 1 条「手改永久保护（AI 永不动手改卡）」已于 2026-06-11 被使用者推翻。任何旧文档写「AI 100% 不动」的地方，一律以本节为准。

1. **三层内容模型**：
   - 第 1 层「原始散文」（手写乱稿）：**AI 永不改写**；使用者本人可以继续在这里写。
   - 第 2 层「一份结构化内容」：AI 整理出来的一串有顺序的卡，全笔记**只有这一份**。
   - 两种皮：「优化散文」与「卡片」都是同一份结构化内容画出来的（**不存两份**，同步天生免费）。
2. **AI 可以动结构化内容**：不管是优化散文皮还是卡片皮，AI 都能改、能删（推翻旧铁律）；**唯一例外是被使用者「钉选（pinned）」的卡，AI 永不碰**。
3. **安全网 = 版本快照 + 一键还原 + 上一步/下一步（Undo/Redo）**：每次 AI 动手或大改前先存快照；使用者能一键回到旧版本，也能像一般编辑器那样「上一步、下一步」整批撤销/重做。
4. **按钮触发**：第二次以后的结构化，使用者按按钮才跑，不自动跑。
5. **省钱机制**：原稿没变（指纹比对）就不叫 AI；变了只重整变动的部分。
6. **参考重写**：不直接搬 SBIR_NEW 的码，参考做法在 BrainStrom 重写，但抄它的好东西（prompt、安全阀、版本快照、提示词快取、5 层 JSON 解析）。
7. **模组卡三视图长一样**：表格 / GitHub / 进度环这类「不是文字」的模组卡，插进笔记后，在原稿、优化散文、卡片三个画面里的视觉呈现是**同一个组件、长一样**。

### 0.3 卡片版型决策（使用者补充）

- 先**不固定**卡片种类、不限排版样式、不限字数总量。
- 只教 AI：「把每一个主题，各写成一张卡」（一张卡＝标题＋内容）。
- 既有的「20 卡清单」（见 §1.5）只当**参考清单**放进 prompt，前端用「通用卡片渲染」（标题＋内容），不依赖固定 type。卡片长怎样、什么种类，留到后面做样式开发时再定。

### 0.4 六个探勘代理已确认的事实（开发前必读）

1. **现有契约**：服务层（`AuthService/SystemsService/BlocksService/StatusService`）→ 模拟后端（`api/mockClient.js`，localStorage key `brainstrom.mock.v1`）→ 触点（`touchpoints.js` **16 条**，含 `status.get()`）→ 验收页（`acceptance.html` 6 盏灯）。AI 功能照同模式加 `AIService` + 触点 + 验收灯。
2. **20 卡清单**已存在于 `mvp/brainstorm-mvp.html` 与 `docs/ios-structure.md`。
3. **资料表**：`docs/backend-design.md` **已规划**（但模拟层 `mockClient.js` **尚未实装**）blocks 的 `source`/`locked`（本版已把 `locked` 改名 `pinned`、语意改「钉选」，见 §1.3）、systems 的 `ai_restructure_count`，以及 `embeddings`/`chat_threads`/`chat_messages` 表。`sourceHash`（原文指纹）连规划都缺，要补。→ **结论：这些栏位现状全部不存在于模拟层，Step 3/4/5 动工前要先改 `mockClient.js` 真正写进去。**
4. **SBIR_NEW 可抄的 AI 引擎**：SSE 事件协议、单专案聊天三层上下文 + 提示词快取、不用 tool_use 而用「prompt 写死 JSON + 5 层解析兜底」、gateway 三入口。
5. **SBIR_NEW 校验/成本**：两层重试（gateway 层 `maxRetries=2`，实际只退避 1s→2s；spec-generator 那条 stream 路 `STREAM_MAX_RETRIES=3` 退避 2s→4s→8s）、model 白名单 `ALLOWED_CLIENT_MODELS`、`CLIENT_MAX_TOKENS_CAP=8192`、每日成本上限 shadow/canary(10%)/full、摘要失败取前 400 字、AI 端点限流 60/分。
6. **SBIR_NEW 的 RAG 没真做**：MMR、同义词展开是可抄的死码；「生向量／写向量／查向量」三步要 BrainStrom 自己写。

---

## 第 1 章 · 资料模型（地基，最先做）

### 1.1 现状（模拟后端实况）

- `systems`：`{ id, ownerId, title, visibility, mode, version, tags[], createdAt, updatedAt, deletedAt, snippet }`
- `blocks`：`{ id, systemId, type, position, payload, createdAt, updatedAt, deletedAt }`
- 自由速记「原文」存法：一个 `type:'text'`、`payload.role==='body'`、`position:-1` 的块（`main.js` 的 `saveBody`）。**这个 body block 的 `payload.content` 就是原文。**

### 1.2 三层内容模型（2026-06-11 新共识，本章核心）★

**三层是什么**（用现有代码对应着讲）：

- **第 1 层 · 原始散文** = 现状的 body block（`type:'text'` + `payload.role==='body'`）。使用者手写的乱稿。**AI 永远不改写它**；使用者随时可以继续写。它是结构化的输入来源，也是「原文变了要重整」的触发点。
- **第 2 层 · 一份结构化内容** = body 以外的全部 blocks（文字卡 + 模组卡），按 `position` 排序成「一串有顺序的卡」。全笔记**只有这一份**结构化资料。
- **两种皮（同一份资料的两种画法，不另外存东西）**：
  - **优化散文皮**：把那串卡按顺序「串起来」画成一篇顺的文章——文字卡画成段落（卡的标题当小标），模组卡（表格/GitHub/进度环…）原样嵌在文章对应位置（像文章里插一张图）。
  - **卡片皮**：把同一串卡「拆开」一张张显示。
- 因为两皮读写的都是**同一串 blocks**，改哪边都是改同一份 → 同步天生免费、永不打架、来回切换零漂移。**禁止为优化散文另外存一份文字**（存两份就会打架）。

**怎么改字（编辑规则）**：

- 优化散文皮：**点哪段改哪段**——每个段落背后就是一张卡，点一下那段变成可编辑框，改完存回那张卡（卡片皮立刻跟着变）。段落的合并/拆分用明确按钮操作（合并 = 两卡并一卡、拆分 = 一卡切两卡，都进 Undo 历史），**不开放整篇自由打字**（避免系统「猜你改了哪张卡」猜错造成漂移）。
- 卡片皮：直接编辑卡，照旧。
- 原始散文：整篇自由打字，照旧（这层是你的乱稿，AI 不碰）。

**三个画面各看到什么**（顶部切换从两段扩成三段：**原稿 ↔ 优化散文 ↔ 卡片**）：

- **原稿画面**：body 原文 + 使用者手动插入的模组卡（嵌在原位）。AI 生成的文字卡**不**显示在这（它们的内容就是原文的优化版，显示会重复）。
- **优化散文画面**：全部结构化卡串成一篇文章（文字卡=段落、模组卡=原样嵌入）。
- **卡片画面**：全部结构化卡一张张显示。
- 模组卡在三个画面的视觉呈现是**同一个渲染组件**（决策 7）。

### 1.3 阶段二要补的栏位（先补，贯穿全程）

| 表 | 新增栏位 | 用途 | 引入于 |
|---|---|---|---|
| blocks | `source: 'manual'\|'ai'\|'notes'\|'voice'` | 来源标记（AI 产 vs 手动），只记出身、不再代表保护 | Step 3 |
| blocks | `pinned: bool`（旧规划名 `locked`，语意改版） | **使用者钉选**；钉了 AI 永不改/删/移这张卡 | Step 4/5 |
| blocks | `sourceAnchor: string` | 这张卡对应「原文哪一段」的指纹 | Step 5 |
| blocks | `structureGen: int` | 此卡产自第几代结构化 | Step 5 |
| systems | `sourceHash: string` | 整份原文指纹，hash gate 用 | Step 5 |
| systems | `ai_restructure_count: int` | 结构化次数（已规划） | Step 3/5 |
| systems | `structuredAt: string` | 上次结构化时间 | Step 3 |

新表（沿用 `backend-design.md`，真后端阶段建 migration）：

- `structure_versions`：`{ id, systemId, version, blocksJson, trigger('structure'|'incremental'|'merge'|'split'|'restore'|'manual'), createdAt }` —— **全篇结构化内容快照**。一键还原、上一步/下一步（Undo/Redo）都吃这张表（抄 SBIR_NEW `proposal_versions` 概念，改存卡片阵列 JSON）。
- `embeddings`：`{ id, systemId, kind('note'|'summary'), chunkText, vector, model, createdAt }`
- `chat_threads`：`{ id, userId, scope('note'|'global'), systemId?, createdAt }`
- `chat_messages`：`{ id, threadId, role('user'|'ai'|'ctx'), content, createdAt }`
- `repo_bindings`：`{ id, systemId, provider, repo, tokenRef, createdAt }`
- `progress_snapshots`：`{ id, systemId, percent, stepStates(json), commitSha, createdAt }`

**Undo/Redo 怎么做**（使用者拍板要「经典上一步/下一步」）：

- 每个「会改结构化内容的操作」= 一步：AI 结构化（整次算一步）、改一张卡、合并/拆分、删卡、手动加卡。
- 每步动手前把当下整串卡存成一张 `structure_versions` 快照，推进 **Undo 堆叠**；按「上一步」= 还原到上一张快照、把现状推进 **Redo 堆叠**；按「下一步」= 反向。中途做了新操作就清空 Redo（跟一般编辑器一样）。
- 堆叠上限先取 50 步（旧的丢掉）；卡片量小，整份快照很便宜，之后要省再改成差异存法。
- 原始散文（body）打字不进这套堆叠（输入框自带原生撤销），但「AI 结构化」这种会动到卡的操作一定进。

> 迁移注意：`addBlock` 加卡时 `source` 由呼叫方决定；旧块迁移补 `source:'notes'`、`pinned:false`。`backend-design.md` 旧规划的 `locked` 一律改名 `pinned`（语意从「系统强制 AI 永不碰」变「使用者主动钉选」）。模拟层只在 localStorage JSON 加这些键；真后端写 Supabase migration。

### 1.4 资料真相归属（决策）

- **Supabase 是资料真相**：blocks、systems、embeddings、向量全写 Supabase（Postgres + pgvector）。
- **Fly.io 只算 AI**：它读 Supabase 拿上下文、把结果写回 Supabase，金钥锁在它身上。

### 1.5 「20 卡」参考清单（只当 prompt 参考，不固定版型）

**原型现有的 20 卡**（在 `mvp/brainstorm-mvp.html` + `ios-structure.md`）：systemName 系统名称 / techStack 技术栈 / techRating 技术评估 / platformTools 平台工具 / github 开源参考 / aiSearch AI 搜寻 / video 参考影片 / reel 短影音 / voice 语音 / prompt 提示词 / devFlow 开发逻辑 / **buildSteps 建置步骤（Step 7 进度比对用）** / table 表格 / htmlPreview 版型示意 / refShots 参考截图 / devFocus 开发重点 / competitors 竞品(PRO) / estimate 预估(PRO) / aiAnalysis AI 分析(PRO) / learningPath 学习路径(PRO)。

**另有一张 `devProgress`（开发进度）是 Step 7 才由 AI 新生的卡，不在上面这 20 张现有清单里**，别混淆。

---

## 第 2 章 · AI 共用引擎（地基，Step 1 实作）

所有 AI 功能（聊天、结构化、全局、进度）都从这台引擎插上去。模拟层与 Fly.io 层都要有等价物，签名一致。

### 2.1 SSE 事件协议（全 Step 统一，抄自 SBIR_NEW）

前端用 `switch(data.type)` 接，每个事件是一行 `data: <json>\n\n`：

| 事件 | payload | 意义 |
|---|---|---|
| `delta` | `{ text }` | AI 逐字吐文字 |
| `done` | `{}` | 本次串流结束 |
| `error` | `{ code?, error }` | 出错（code 如 `ai_timeout`、`payment_required`、`rate_limited`） |
| `usage` | `{ input_tokens, output_tokens, cache_read_input_tokens, model }` | token 用量 |
| `card_start` | `{ index, type?, title }` | 开始吐一张结构化卡（BrainStrom 自取的新名；**SBIR_NEW 没有这名字**，它对应的是 SBIR 的 `section_start`，去 SBIR 找要搜 section_start） |
| `card_done` | `{ index, card }` | 一张卡完成（对应 SBIR 的 `section_done`） |
| `card_removed` | `{ cardId }` | 增量时 AI 删了一张卡（对应原稿被删的段落；BrainStrom 自取的新名，SBIR_NEW 没有） |
| `progress` | `{ current, total, message }` | 进度（如进度分析、增量合并阶段） |
| `credit_update` | `{ balance, delta }` | 扣款后推新余额（阶段三才真用，先预留） |
| `hit_list` | `{ systems:[{systemId,title,score}] }` | 全局找回命中的系统列表 |

> `credit_update`、`card_start` 这类是后端主动注入的 meta 事件，不是 AI 生出来的。

### 2.2 gateway 三入口（Fly.io 层，抄 SBIR_NEW）

- `call(apiKey, params, ctx)` — 非串流，等完整回覆。
- `stream(apiKey, params, ctx)` — 串流（内部用）。
- `streamAsync(apiKey, params, ctx)` — 串流 + 呼叫前先做余额/成本检查（`beforeAICall`）（**业务层都用这个**）。
- `ctx`（AuditContext）**必填：`db / ownerType('user'|'system') / ownerId / operation / projectId`**（缺 `db`/`ownerType` 会编译失败、计费失效）；可选 `signal`（前端断线 AbortSignal，断线即中断 Anthropic 停止烧钱）、`onCreditDeducted`、`env`（型别上选填，但 SBIR 的 `beforeAICall` 缺 `env` 会直接 throw，照抄时务必传入）。

### 2.3 两层重试（更正：别混）

- **gateway 层**：`maxRetries=2`，公式 `min(1000×2^attempt,10000)` → 实际只退避 1s→2s（第 3 次的 4s 因 maxRetries=2 不会执行），重试 HTTP 429/500/502/503/504。
- **stream 层**（仅 `spec-generator.ts` 那条路有，非全局）：`STREAM_MAX_RETRIES=3`，退避 2s→4s→8s，只重试 overloaded/529/connection error。
- 被截断（`stop_reason==='max_tokens'`）→ 续写最多 2 轮，带「请从中断处继续」。

### 2.4 JSON 强制格式（决策：tool_use 为主 + 5 层解析兜底）

- **主用** Anthropic `tool_use`（结构化输出）强制 AI 回固定 JSON schema（最新 Claude 模型稳定）。
- **兜底** 抄 SBIR_NEW 的 `parse-ai-json.ts` 5 层解析（直解 → 剥 code block → 括号状态机 → 截断回收 → fallback 默认值），万一 AI 多话也救得回。
- 此项标记为「建议默认，待你确认」（见附录 D1）。

### 2.5 成本与滥用防护（抄 SBIR_NEW）

- model 白名单 `ALLOWED_CLIENT_MODELS` + `CLIENT_MAX_TOKENS_CAP=8192`（注意 `CLIENT_` 前缀，去 SBIR 搜要用全名），入口用 schema 校验挡外部乱传。
- 每日成本上限三模式：`shadow`（只记录）→ `canary`（10% 用户挡）→ `full`（全挡）。
- AI 端点限流 60/分（通用 API 在 SBIR 是 120/分，BrainStrom 按需自订）；free 用户每日 AI 次数上限（默认 100，见附录 D8）。
- 每个 AI 呼叫点预留扣款挂钩（`makeCreditEmit` → `withCreditEmit({operation})`），阶段三付费才真扣。

### 2.6 模拟引擎（模拟层等价物）

`mockClient.js` 加 `async aiStream(endpoint, payload, emit)`：用 `setTimeout` 把假回答切成 token 逐个 `emit({type:'delta',text})`，最后 `emit({type:'done'})`。让前端「流式」验收逻辑提早成形。**模拟层全用假数据，只 Fly.io 层接真 Claude。**

---

## 第 3 章 · 服务层与触点扩充总览

阶段二新增一个 `AIService extends Base`（继承 EventTarget，与现有四个 Service 同模式，变动时 `changed()` 派事件）。所有方法签名一次列清，后面各 Step 只引用：

```js
class AIService extends Base {
  // Step 1 底层：所有 AI 方法共用的串流 transport
  async _stream(endpoint, payload, { onDelta, onCard, onDone, onError, onProgress, onHit })

  // Step 2 单专案聊天
  async chatNote(systemId, messages, handlers)

  // Step 3 + Step 5 结构化（mode: 'full' 第一次 / 'incremental' 第二次）
  async structure(systemId, { mode = 'incremental' } = {}, handlers)

  // Step 6 全局找回
  async searchGlobal(query, handlers)
  async chatGlobal(messages, handlers)

  // Step 7 GitHub
  async bindRepo(systemId, repoUrl)
  async analyzeProgress(systemId, handlers)
  async findRelatedOSS(systemId, handlers)

  // 健康检查
  async health()
}
```

另外 `SystemsService` 加四个「版本与还原」方法（不是 AI 呼叫，所以不放 AIService）：

```js
// 结构化内容的版本安全网（吃 structure_versions 快照）
async undo(systemId)            // 上一步：整批撤销最近一步
async redo(systemId)            // 下一步：重做刚撤销的那步
async versions(systemId)        // 列出可还原的快照
async restore(systemId, ver)    // 一键还原到指定版本（本身也算一步，可再 undo）
```

新增触点（`touchpoints.js`，模拟层↔Fly.io 层唯一契约）：

| 方法 | UI 触发点 | API | Swift |
|---|---|---|---|
| `ai.health()` | 验收页 | `GET /ai/health` | AIService.health() |
| `ai.chatNote(id,msgs)` | 笔记底部聊天浮层 | `POST /ai/chat/note` | AIService.chatNote() |
| `ai.structure(id,opts)` | 笔记页·AI结构化钮 | `POST /ai/structure` | AIService.structure() |
| `blocks.addModule(id,type)` | 笔记左下工具按钮 | `POST …/blocks` | BlocksService.add() |
| `ai.searchGlobal(q)` | 首页全局 AI 框 | `POST /ai/search-similar` | AIService.searchGlobal() |
| `ai.chatGlobal(msgs)` | 首页全局对话 | `POST /ai/chat/global` | AIService.chatGlobal() |
| `ai.bindRepo(id,url)` | 进度卡·绑 repo | `POST /ai/repo/bind` | AIService.bindRepo() |
| `ai.analyzeProgress(id)` | 进度卡·分析 | `POST /ai/progress` | AIService.analyzeProgress() |
| `ai.findRelatedOSS(id)` | 开源参考卡 | `POST /ai/related-oss` | AIService.findRelatedOSS() |
| `systems.undo(id)` / `systems.redo(id)` | 笔记页·上一步/下一步钮 | `POST /api/systems/:id/undo`·`/redo` | SystemsService.undo()/redo() |
| `systems.versions(id)` / `systems.restore(id,v)` | 笔记页·版本列表 | `GET …/versions`·`POST …/restore` | SystemsService.versions()/restore() |
| `blocks.pin(id,bool)` | 卡片·钉选开关 | `PATCH /api/blocks/:id{pinned}` | BlocksService.update() |

新增验收灯（`acceptance.html` 的 `LAMPS` + `Mock.status()`）：阶段一 6 盏 + 阶段二 6 盏 = `ai_engine / chat_note / structure / structure_incremental / global_recall / git_progress`。
> **必做**：扩 `LAMPS` 数组之外，**一定要同时在 `mockClient.js` 的 `status()` 回传对应布尔键**（现状 `status()` 只回 `db/auth/read_write/rls/delete_account/frontend_skeleton/systems/updatedAt`）。没补布尔键，新灯永远是灭的。

---

## 第 4～10 章 · Step 1～7 逐步实作

> 每步固定六段：① 目标 ② 资料流 ③ 模拟层改动 ④ Fly.io 层改动 ⑤ 服务层+触点 ⑥ 前端验收点。

### 第 4 章 · Step 1：AI 共用引擎（地基，先做不验产品）

① 目标：把第 2 章那台引擎搭起来，证明「前端 → 服务层 → 引擎 → 回串流」整条线通。
② 资料流：前端调 `ai.health()` → 引擎回 `{ ok:true }`。
③ 模拟层：加 `aiStream`（§2.6）+ `aiHealth()`。
④ Fly.io 层：起常驻实例（非 Edge，避免冷启动），实作 gateway 三入口、`/ai/health`、SSE、parse-ai-json、成本阀、AuditContext。
⑤ 服务层：加 `AIService._stream` + `health`；触点加 `ai.health`。
⑥ 验收点：验收页 `ai_engine` 灯亮（引擎在线）。

### 第 5 章 · Step 2：单专案聊天（最简单 AI，验证引擎）

① 目标：在一则笔记里跟 AI 聊，AI 知道**这则的全部内容（含手动加的卡）**。
② 资料流：服务层取 `getSystem(id)` 全部 blocks → 组三层 system block（抄 SBIR `prompt-builder`）：㈠ 静态人设+规则（挂 `cache_control:ephemeral` 省 token）㈡ 该专案全文（每张卡序列化成文字）㈢ 任务指令 → 走 `/ai/chat/note` 串流。
③ 模拟层：`aiStream('/ai/chat/note')` 回一段「我读到你这则有 N 张卡，包含 X、Y…」的**假但反映真实卡片数**的回答（证明上下文真被读到）。
④ Fly.io 层：`POST /ai/chat/note`，三层 block + 快取，`streamAsync`。
⑤ 服务层：`AIService.chatNote(systemId, messages, handlers)`；触点 `ai.chatNote`。
⑥ 验收点（对应你要的 (a)(b)）：
   - **(a) 流式状态**：输入一句送出 → 回答逐字蹦出、右下显示 `usage` token、断线显示 `error`。`ai_engine`+`chat_note` 灯亮。
   - **(b) 单篇识别**：先手动加一张含特定关键字的卡（如「发票辨识」），问「这则在讲什么、提到哪些工具」→ AI 复述出那张卡内容 → 验收页显示「单专案问答→引用到 N 张卡」。

### 第 6 章 · Step 3：AI 结构化（第一次全量）→ 产出「一份结构化内容、两种皮」

① 目标：按按钮，把乱写速记整理成「一份结构化内容」，同一份能看成「优化散文」也能看成「卡片」。原稿一字不动。
② 资料流：取 body 原文 → `/ai/structure`（mode=full）→ prompt「每个主题一张卡（标题＋内容），卡的顺序要能直接串成一篇顺的文章；找不到留空、不准编造；**不准改写原文那个 body**」+ 20 卡参考清单 → tool_use/parseAIJson 拿到**有顺序的卡数组** → 先存一张 `structure_versions` 快照（推进 Undo 堆叠，让这次结构化可整批撤销）→ 每张 `blocks.add(systemId,{type,payload,source:'ai',structureGen:1})` → `card_done` 逐张推前端；同时记 `ai_restructure_count=1`、`systems.sourceHash`、`structuredAt`（为 Step 5 铺路）。
③ 模拟层：`Mock.structure(full)` 把原文按换行/标题切几段，生成几张 `source:'ai'` 卡逐张 emit。
④ Fly.io 层：`POST /ai/structure`（mode=full），`card_start/delta/card_done` 协议。
⑤ 服务层：`AIService.structure(id,{mode:'full'},handlers)`；触点 `ai.structure`。
⑥ 前端：顶部切换从两段扩成三段「**原稿 ↔ 优化散文 ↔ 卡片**」；优化散文皮与卡片皮都从同一串 blocks 渲染（§1.2 规则）；优化散文皮支持「点哪段改哪段」。
⑦ 验收点（对应 (c)·结构化 + 新模型三个新动作）：
   - 按「AI 结构化」→ 卡片逐张浮现 → `structure` 灯亮、显示「回传 N 张卡」+ 预览。
   - **两皮同步**：在优化散文皮点某段改一个字 → 切到卡片皮，同一张卡内容跟着变（反向也成立）。
   - **原稿没被动**：结构化后切回原稿画面 → 原文一字未动（body hash 不变）。
   - **可撤销**：按「上一步」→ 这次结构化整批消失；按「下一步」→ 整批回来。

### 第 7 章 · Step 4：加模组（横排按钮，手动加卡 + 钉选开关）

① 目标：使用者能自己加卡、改卡；卡片标「来源」（manual）；想保护哪张卡就自己「钉选」。
② 资料流：选模组 → `blocks.add(systemId,{type,payload,source:'manual',pinned:false})`。**手动卡默认不钉选**（新模型 AI 可动它，安全靠快照+Undo）；每张卡上有「钉选」开关，钉了 AI 永不碰（`blocks.pin` 触点）。
③ 模拟层：**现状 `mockClient.js` 的 `addBlock`（约第 70–78 行）会忽略 `source`/`pinned`，必须先改它**，把这两个键写进建出的 block 物件（默认 `source:'manual'`、`pinned:false`，由呼叫方覆盖），否则照做等于没存。这步是 Step 3/5 的前置。
④ Fly.io 层：无新 AI 端点（纯 CRUD）。
⑤ 服务层：复用 `BlocksService.add`，加便捷 `addModule(systemId,type)`；触点 `blocks.addModule`、`blocks.pin`。
⑥ 前端：UI 从圆形旋钮**简化成横排按钮**（点一下弹出模组列表），加卡功能照做。**三个画面都能加模组**：在原稿画面插入的模组卡，会以同一个视觉组件出现在原稿、优化散文、卡片三个画面的对应位置（决策 7）。
⑦ 验收点：验收页显示某笔记「手动加的 block 数 / 钉选卡数」；钉选卡是 Step 5 保护的输入。

### 第 8 章 · Step 5：增量结构化（第二次只补变动）★最复杂★

> 权威设计来源：`docs/增量结构化-SBIR模组完整记录与开发设计.md`（其下半部已按 2026-06-11 新共识改版）。
> 关键：**SBIR_NEW 没有自动 diff、没有钉选、是字串 splice；BrainStrom 要自己写「卡片阵列版的差异侦测」。**
> **规则改版**：旧版「100% 不动手改卡」已废除 → 新版「AI 可改、可删、可新增任何**未钉选**的卡（含手动卡）；**钉选卡永不碰**；安全靠快照 + Undo/Redo」。

① 目标：改了原稿再按按钮，不整篇重做，只动变动处；AI 可以更新、删除既有卡（钉选的除外）；原稿没变就不花钱；改坏了按「上一步」整批还原。
② 资料流（九步）：
   1. **Hash gate**：算新原稿 `sourceHash` 比对 `systems.sourceHash`；一样 → 直接显示旧卡、**不呼叫 AI、零成本**。
   2. **自动 diff**：不一样 → 旧原稿 vs 新原稿按「段落（空行）＋标题（若有）」切块对比，分出「新增段 / 变动段 / 删除段」（纯程式，不花 AI）。
   3. **组增量上下文**：把「变动相关的原稿片段（含被删段的旧文）+ 上次结构化卡(JSON，标注哪些钉选)」交给 AI，prompt 明确「钉选卡绝不准动；其余卡可更新；**删除只准用在对应原稿段落已被删掉的卡**；没提到的卡一律原样保留」。
   4. **AI 只回 patch**：`{ 新增:[{type,payload,插入位置}], 更新:[{cardId,payload}], 删除:[cardId] }`（tool_use 强制 schema；新增无 id、更新/删除带 id），不用 RFC6902。
   5. **钉选保护三层**：㈠ 资料层 `pinned` 卡永不进「可改/可删」清单（只给 AI 只读上下文）；㈡ prompt 层告知不准碰；㈢ 合并层即使 AI 误回也丢弃针对钉选卡的任何 patch。
   6. **安全阀**：patch 异常（要改＋删的卡数超阈值、想动钉选卡、或想删「对应原稿段落还在」的卡）→ 整批拒绝、保留原状、提示重试。
   7. **快照 + Undo**：套用前存 `structure_versions` 快照（trigger=`'incremental'`）并推进 Undo 堆叠——**一次增量 = 一步**，「上一步」整批撤销、「下一步」整批重做，也可在版本列表一键还原任意旧版。
   8. 更新 `ai_restructure_count+=1`、`sourceHash`、变动卡 `structureGen`/`sourceAnchor`、重算摘要+向量（连动 Step 6）。
   9. 前端只重画变动卡：新增的浮现、更新的原位刷新、删除的淡出（`card_removed` 事件），其余不闪、不重排。两皮同时生效（同一份资料）。
③ 模拟层：最小版——hash 相同返回旧卡；不同则保留钉选卡、追加新内容卡、删掉「对应段落已消失」的未钉选卡。证明「钉选没被洗掉、该删的会删、Undo 能整批回来」。重点放④。
④ Fly.io 层：`/ai/structure` 加 incremental 分支，实作差异侦测 + patch 合并（含删除）+ 钉选三层保护 + 安全阀 + 快照。
⑤ 服务层：同 `AIService.structure(id,{mode:'incremental'},handlers)`；还原走 `SystemsService.undo/redo/restore`。
⑥ 验收点（对应 (c)·增量）：
   - **钉选保护**：钉选某张卡 → 改原稿别处 → 再按结构化 → 钉选那张一字未动、其余该更新的更新。
   - **删除跟着原稿走**：整段删掉原稿某段 → 再按结构化 → 对应卡被删（钉选的不删）。
   - **版本还原**：按「上一步」→ 这次增量整批撤销；按「下一步」→ 再套用。
   - **省钱**：原稿没改再按 → 提示「跳过 AI、没花钱」。
   - `structure_incremental` 灯，附「钉选卡数 / 本次是否跳过 AI / 可还原版本数」。

### 第 9 章 · Step 6：全局 AI 跨笔记找回（RAG）

> SBIR_NEW 的 RAG 没真做：MMR(`mmr.ts`)、query-expansion 是可抄死码；生向量/写向量/查向量三步要自己写。

① 目标：问一句模糊描述，跨全部笔记找回、指出在哪则。
② 资料流：
   - **写向量**（结构化后顺手，连 Step 3/5）：系统压成摘要（失败取前 400 字）→ `embed(text)→vector` → 存 `embeddings(kind='summary')`。
   - **查向量**：query → embed → pgvector 相似度搜（free 上限 50 系统）→ 可选 MMR 去冗 → top-k 摘要交 Claude → 回答 + 命中 systemId 列表（`hit_list` 事件）。
③ 模拟层：用关键字 includes 模拟命中（query 词出现在哪些系统摘要），回「在《X》这则」——验收命中体验不需真向量。
④ Fly.io 层：`POST /ai/search-similar` + `POST /ai/chat/global` + 写向量内部函数；`embed()` 抽象成接口，供应商可换（见附录 D2）。
⑤ 服务层：`AIService.searchGlobal/chatGlobal`；触点 `ai.searchGlobal/chatGlobal`。
⑥ 验收点（对应 (c)·全局找回）：首页输入「我那个跟发票有关的点子在哪」→ 命中《X》并能点进去。`global_recall` 灯，附「命中系统数」。

### 第 10 章 · Step 7：连 GitHub（进度判断 + 找呼应开源）

① 目标：连 repo 看 AI 判断的进度；并找跟你项目呼应的开源项目。
② 资料流：
   - **功能一·进度**：取该系统 `buildSteps` 卡 → 拉 commit/档案树/分支 → AI 逐条对比「计划 vs 实际」→ 算粗略完成度（标注「粗略」）→ 存 `progress_snapshots` → 生 `devProgress` 卡（环形%+步骤打勾）。
   - **功能二·开源**：取技术栈/描述 → 搜 GitHub → AI 挑呼应项目 → 生/更新 `github` 卡。
③ 模拟层：假 commit 数据 + 假百分比 + 假开源清单。
④ Fly.io 层：GitHub OAuth token 锁后端；`POST /ai/repo/bind`、`/ai/progress`、`/ai/related-oss`。
⑤ 服务层：`AIService.bindRepo/analyzeProgress/findRelatedOSS`；触点同名。
⑥ 验收点（对应 (c)·GitHub）：绑 repo → 按「分析进度」→ 环形百分比 + buildSteps 打勾。`git_progress` 灯，附「完成度 X%」。

---

## 第 11 章 · 前端验收决策点总表（使用者在前端验收）

> 每个验收点 = 一个可操作动作 + 一个可观察结果（灯号/画面）。`acceptance.html` 灯阵从阶段一 6 盏扩到 12 盏。

| 验收点 | 动作 | 可观察结果 | 灯号 |
|---|---|---|---|
| **(a) AI 流式响应** | 聊天框输入一句送出 | 回答逐字蹦出 + 显示 token 用量 + 出错显示 error | `ai_engine`+`chat_note` |
| **(b) 单篇内容识别** | 加一张含关键字的卡，问「这则在讲什么」 | AI 复述出那张卡内容 | `chat_note`（附引用卡数） |
| **(c1) 结构化** | 按「AI 结构化」 | 卡片逐张浮现 + 「回传 N 张卡」 | `structure` |
| **(c2) 增量·钉选保护** | 钉选某卡→改原稿别处→再结构化 | 钉选卡一字未动；其余该更新的更新、对应原稿被删段落的卡被删 | `structure_incremental`（附钉选卡数） |
| **(c3) 增量·省钱** | 原稿没改→再按结构化 | 提示「跳过 AI、没花钱」 | `structure_incremental`（附是否跳过 AI） |
| **(c4) 全局找回** | 首页输入模糊描述 | 命中正确系统、可点进去 | `global_recall`（附命中数） |
| **(c5) GitHub 进度** | 绑 repo→分析进度 | 环形% + buildSteps 打勾 | `git_progress`（附完成度） |
| **(c6) 两皮同步** | 优化散文皮点一段改一字 | 切到卡片皮，同张卡同步变（反向也成立） | `structure`（附两皮同步） |
| **(c7) 原稿没被动** | 结构化/增量后切回原稿画面 | 原文一字未动（body hash 不变） | `structure` |
| **(c8) 版本还原** | 按「上一步」「下一步」/版本列表还原 | 一次结构化整批撤销、整批重做 | `structure_incremental`（附可还原版本数） |

---

## 第 12 章 · 风险清单 + 降级方案

| # | 风险 | 降级 |
|---|---|---|
| 1 | 结构化 JSON 解析失败/AI 乱回 | tool_use + 5 层 parse 兜底 → 仍失败回退「不改任何卡 + 提示重试」，绝不写坏数据 |
| 2 | **增量误删/误改不该动的卡（最严重）** | 钉选三层保护（资料 `pinned` + prompt + 合并层丢弃）；每次套用前快照，「上一步」整批撤销；安全阀：触碰钉选卡、删「原稿段落还在」的卡、或变动量超阈值，一律整批拒绝 |
| 3 | 原文没变还呼叫 AI 烧钱 | sourceHash gate：相同直接返回旧卡 |
| 4 | AI 被无限刷烧帐单（SBIR 真实教训） | 限流 60/分 + 每日成本上限 shadow→canary→full + free 次数上限 + 金钥只在 Fly.io |
| 5 | 全局找回召回率差（产品命脉） | 模拟阶段先用关键字验收体验；真阶段 MMR 去冗 + query 扩展 + top-k 调参 + free 50 控脉络 |
| 6 | 长上下文 token 爆 | `cache_control:ephemeral` 快取静态层；摘要取前 400 字；单系统过大转检索式 |
| 7 | Fly.io 冷启动/串流不稳 | 常驻实例；`error` 事件 + 两层重试 |
| 8 | 客户端断线仍烧上游 | 透传 AbortSignal，断线即中断 Anthropic |
| 9 | embedding 供应商未定卡住 Step 6 | 接口抽象 `embed(text)→vector`，先用假向量跑通，定了只换实作 |
| 10 | 模拟层↔Fly.io 层接口漂移，UI 要改两次 | 铁律：两层签名 + SSE 协议完全一致；触点表为唯一契约源 |
| 11 | GitHub 进度判断不准误导 | 标「粗略估计」；先做打勾+粗百分比；snapshot 留痕可人工核对 |

---

## 第 13 章 · 中文命名表

| 概念 | 中文命名 | 程式识别名 | 说明 |
|---|---|---|---|
| 来源 | 来源 | `source` | manual/ai/notes/voice（只记出身，不代表保护） |
| 钉选 | 钉选 | `pinned` | 使用者钉住的卡，AI 永不改/删/移（旧名 locked，语意已改版） |
| 上一步/下一步 | 撤销/重做 | `undo` / `redo` | 整批撤销或重做一次操作（含一整次 AI 结构化） |
| 优化散文皮 | 优化散文 | （渲染函式 renderProse） | 同一串卡串成一篇文章，不另存资料 |
| 卡片皮 | 卡片 | （渲染函式 renderCards） | 同一串卡拆开一张张显示 |
| 原文指纹（系统级） | 原文指纹 | `sourceHash` | 判断原文有没有变 |
| 来源原文指纹（卡级） | 来源原文指纹 | `sourceAnchor` | 卡来自哪段原文 |
| 结构化代数 | 结构化代数 | `structureGen` | 第几代结构化 |
| 重新结构化次数 | 重新结构化次数 | `ai_restructure_count` | 增量跑了几次 |
| 增量结构化 | 增量结构化 | `structure({mode:'incremental'})` | 第二次只补变动 |
| 差异侦测 | 差异侦测 | （diff 函数） | 新旧原文比对 |
| 卡片缝合 | 卡片缝合 | `mergeCards` | 卡片阵列版合并 |
| 字数暴冲安全阀 | 安全阀 | `CHANGE_RATIO_CAP` | 防 AI 暴走 |
| 全篇卡片快照 | 全篇快照 | `structure_versions` | 整份结构化内容的版本表，Undo/Redo 与一键还原都吃它 |
| 提示词快取 | 提示词快取 | `cache_control` | 省 token |
| 流式事件 | 流式事件 | `delta/done/...` | SSE 协议 |

---

## 第 14 章 · 开发工单清单（一步一盏灯）

每张工单循环：侦察兵摸清→设计指令→工兵实作→验收兵点灯→你过目。建议派工顺序：

1. 【地基】资料库补栏（blocks +source/pinned/sourceAnchor/structureGen；systems +sourceHash/structuredAt；新表 structure_versions）。→ 无灯，是前置。
2. 【Step 1】AI 共用引擎 + `/ai/health`。→ 点 `ai_engine`。
3. 【Step 2】单专案聊天 `chatNote`。→ 点 `chat_note`，验收 (a)(b)。
4. 【Step 3】结构化 full + 两皮渲染（原稿/优化散文/卡片三段切换、点哪段改哪段）+ Undo/Redo 地基。→ 点 `structure`，验收 (c1)(c6)(c7)(c8 的撤销结构化)。
5. 【Step 4】加模组（横排按钮）+ 来源标记 + 钉选开关。→ 验收手动卡数/钉选卡数。
6. 【Step 5】增量结构化 + 钉选三层保护 + 删除规则 + 安全阀 + 快照/Undo。→ 点 `structure_incremental`，验收 (c2)(c3)(c8)。
7. 【Step 6】全局找回 + 写/查向量。→ 点 `global_recall`，验收 (c4)。
8. 【Step 7】GitHub 进度 + 找呼应开源。→ 点 `git_progress`，验收 (c5)。

> 上架提醒：做到第 7 步（或第 6 步全局 AI）其实就是完整产品，可先上架收反馈，阶段三付费/私密之后补。

---

## 附录 D · 达「98% 可开发成功率」的待拍板决策（已给推荐默认）

> 以下我都给了「推荐默认」，标 ⭐ 的是高影响、建议你亲自确认；其余按默认即可开工。

1. ⭐ **结构化用 tool_use 还是 prompt 写死 JSON？** 推荐：tool_use 为主 + parse-ai-json 5 层兜底。（SBIR 用后者，但我们绿地新盖，tool_use 更稳。）
2. ⭐ **embedding 供应商？** 推荐：OpenAI `text-embedding-3-small`（1536 维，便宜）。接口抽象 `embed()`，之后可换。
3. **模拟层假到什么程度？** 推荐：模拟层全假（假流式+关键字模拟命中），只 Fly.io 接真 Claude。
4. **卡片 type 要不要限定 20 类？** 推荐：不限定，AI 自由命名 type（每主题一张卡），20 类只当参考；前端通用渲染（标题+内容）。
5. **增量 diff 切块粒度？** 推荐：段落（空行）+ 标题（若有）。
6. **增量 patch 格式？** 推荐：带 cardId 的 upsert 数组（新增无 id、更新带 id）。
7. **聊天历史持久化？** 推荐：MVP 先前端内存，真后端阶段再持久化到 chat_threads/messages。
8. ⭐ **成本阀阈值？** 推荐：`MAX_TOKENS_CAP=8192`；每日上限默认 $5/用户/天（先 shadow 观察）；free 用户每日 AI 次数上限 100。
9. **GitHub 进度算法？** 推荐：buildSteps 关键字 + AI 主观判断混合，标「粗略」。
10. **资料真相归属？** 推荐：Supabase 是真相，Fly.io 只算 AI、读写 Supabase。

### 2026-06-11 已拍板（不再是待定）

- **`locked` 改「钉选 `pinned`」**：保护权交给使用者自选；AI 可改可删一切未钉选的卡（使用者拍板）。
- **AI 可以删卡**：原稿某段被删，对应卡可删（钉选的不删）；删前有快照（使用者拍板）。
- **安全网要做经典 Undo/Redo**：不只版本快照列表，还要「上一步/下一步」整批撤销/重做（使用者拍板）。
- **模组卡三视图同渲染**：表格/GitHub/进度环这类卡，在原稿、优化散文、卡片三个画面视觉呈现是同一个组件（使用者拍板）。
- **优化散文皮编辑方式 = 点哪段改哪段**（段=卡，合并/拆分用专门按钮）——这条是**推荐默认**，使用者尚未明确确认，可再改。

### 仍待拍板（沿用上面推荐默认即可开工）

- 上面第 1（tool_use）、第 2（embedding 供应商）、第 8（成本阀阈值）三项 ⭐ 仍未经使用者亲口确认。

---

## 附录 E · 关键文件索引

- 服务层：`web/src/services/index.js`（加 `AIService`）
- 模拟后端：`web/src/api/mockClient.js`（加 `aiStream`/`structure`/向量模拟 + 补栏位）
- 触点：`web/src/touchpoints.js`（加 AI 触点，唯一契约源）
- 验收页：`web/acceptance.html`（`LAMPS` 扩 12 盏 + `Mock.status()` 补布尔）
- Step 5 权威设计：`docs/增量结构化-SBIR模组完整记录与开发设计.md`、`docs/HANDOFF-incremental-restructure.md`
- AI 引擎照抄参照（SBIR_NEW）：`saas/backend/src/ai/gateway.ts`、`utils/parse-ai-json.ts`、`chat/prompt-builder.ts`、`chat/handlers/chat-handler.ts`
