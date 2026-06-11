# 阶段二开发文档 · 变聪明（AI 功能 Step 1～7）

> 这份是 BrainStrom 阶段二「变聪明」的正式开发蓝图。给之后正式开发的 AI / 工程师照着做。
> 上半部讲「不变的地基与规则」，下半部「第 1～7 步」每步都能直接派代理开工，最后有「前端验收点」「风险降级」「中文命名表」「待你拍板的决策」。
> 配套阅读：`docs/HANDOFF-incremental-restructure.md`、`docs/增量结构化-SBIR模组完整记录与开发设计.md`（Step 5 的权威设计来源）、`全局开发文件夹/03-开发步骤与策略.md`（阶段总蓝图）。
>
> 建立日期：2026-06-11　｜　开发顺序：方案 A（先地基＋共用引擎，再用最简单的 AI 功能验证，再做复杂的）
> 本文档经 6 个探勘代理 + 1 个 Plan 代理交叉验证现有代码后产出。
> **v2（2026-06-11 同日改版）**：写入「三层内容模型」共识（已被 v3 取代）。
> **v3（2026-06-11 再改版，现行版）**：使用者拍板「**活文件模型**」——不再永久并存「原始手写层」，一份笔记就是一串会不断进化的块（文章/卡片两视图同一份资料）；新增「优化文字」按钮；安全网 = **无限版本历史 + 不限次数的上一步/下一步**；省钱 = 指纹比对、没变的段落不重送。v2 的「三层模型、原稿画面、sourceAnchor/sourceHash」全部作废，见 §0.2 与 §1.2。

---

## 第 0 章 · 背景、铁律、已拍板决策

### 0.1 三条铁律（每一步都要守）

1. **金钥永不进前端**：所有 Claude 呼叫都在 Fly.io 的 AI 代理上跑，前端只送原文、收结果。
2. **UI 只走服务层**：前端不直接碰后端，一律经 `services/`。这样之后搬 SwiftUI 照 `touchpoints.js` 重接即可。
3. **模拟层与 Fly.io 层「接口签名 + SSE 事件协议」必须一模一样**：UI 零改动就能从假后端切到真后端。`touchpoints.js` 是这两层之间「唯一的契约真相」。

### 0.2 已拍板决策（硬规则，不可违反；v3 活文件模型，2026-06-11）

> ⚠️ 演进轨迹：v1「手改卡 AI 永不动」→ v2「三层模型（原始散文层永久并存、AI 永不碰）」→ **v3「活文件模型」（现行版）**。旧文档任何「原始散文层永久并存 / AI 永不改写原文 / 三段视图切换」的说法全部作废，一律以本节为准。

1. **活文件模型**：一份笔记 = 一份会不断进化的「活文件」= **一串有顺序的块**（段落块＋模组块）。**文章视图**（把块串起来看成一篇文章）与**卡片视图**（把同一串块拆开一张张看）是同一份资料的两种画法，**不存两份**，同步天生免费。**没有永久并存的「原始手写层」**——最早的原稿就是版本历史里的第 1 版，想看就退回去。
2. **两个 AI 按钮**（都由使用者手动触发，不自动跑）：
   - **优化文字**：AI 优化整篇排版与文笔，做完**仍是一篇文章**（不卡片化）。每次执行都会问「要不要顺便分主题加小标题」（使用者拍板：每次都问）。
   - **卡片结构化**：必要时先补优化（已优化没变的段落跳过），然后把内容归组成一张张主题卡。
3. **AI 可改可删**任何未钉选的块/卡（含手动加的）；**钉选（pinned）的块 AI 永不改、不删、不跨越它去合并前后文**。模组卡（表格/GitHub/进度环…）的内容 AI 永不动（视同天生钉选）。
4. **安全网 = 无限版本历史 + 不限次数的上一步/下一步（Undo/Redo）**（使用者拍板：无限退）：每次「AI 操作」或「结构性操作」（改一张卡、删卡、合并、拆分、加模组）前自动存档一步；按「上一步」整批退回，文章与卡片**一起**退；打字过程不算步（用输入框原生撤销）。回旧版只做「整篇还原」，不做「捡回片段」（使用者拍板）。
5. **省钱 + 防走样**：全文指纹没变 → 不叫 AI、零成本；变了 → **只送新写/改过的段落，已优化且没变的段落一个字都不重送**——既省钱，也防「影印机效应」（AI 反复重写同一段，每次走样一点）。
6. **参考重写**：不直接搬 SBIR_NEW 的码，参考做法在 BrainStrom 重写，但抄它的好东西（prompt、安全阀、版本快照、提示词快取、5 层 JSON 解析）。
7. **模组卡两视图长一样**：模组卡在文章视图与卡片视图的视觉呈现是**同一个组件**（文章里像插图一样嵌在对应位置）。

### 0.3 卡片版型决策（使用者补充）

- 先**不固定**卡片种类、不限排版样式、不限字数总量。
- 只教 AI：「把每一个主题，各写成一张卡」（一张卡＝标题＋内容）。
- 既有的「20 卡清单」（见 §1.5）只当**参考清单**放进 prompt，前端用「通用卡片渲染」（标题＋内容），不依赖固定 type。卡片长怎样、什么种类，留到后面做样式开发时再定。

### 0.4 六个探勘代理已确认的事实（开发前必读）

1. **现有契约**：服务层（`AuthService/SystemsService/BlocksService/StatusService`）→ 模拟后端（`api/mockClient.js`，localStorage key `brainstrom.mock.v1`）→ 触点（`touchpoints.js` **16 条**，含 `status.get()`）→ 验收页（`acceptance.html` 6 盏灯）。AI 功能照同模式加 `AIService` + 触点 + 验收灯。
2. **20 卡清单**已存在于 `mvp/brainstorm-mvp.html` 与 `docs/ios-structure.md`。
3. **资料表**：`docs/backend-design.md` **已规划**（但模拟层 `mockClient.js` **尚未实装**）blocks 的 `source`/`locked`（本版已把 `locked` 改名 `pinned`、语意改「钉选」，见 §1.3）、systems 的 `ai_restructure_count`，以及 `embeddings`/`chat_threads`/`chat_messages` 表。指纹栏位（v3 的 `aiHash`/`lastAiHash`）连规划都缺，要补。→ **结论：这些栏位现状全部不存在于模拟层，Step 3/4/5 动工前要先改 `mockClient.js` 真正写进去。**
4. **SBIR_NEW 可抄的 AI 引擎**：SSE 事件协议、单专案聊天三层上下文 + 提示词快取、不用 tool_use 而用「prompt 写死 JSON + 5 层解析兜底」、gateway 三入口。
5. **SBIR_NEW 校验/成本**：两层重试（gateway 层 `maxRetries=2`，实际只退避 1s→2s；spec-generator 那条 stream 路 `STREAM_MAX_RETRIES=3` 退避 2s→4s→8s）、model 白名单 `ALLOWED_CLIENT_MODELS`、`CLIENT_MAX_TOKENS_CAP=8192`、每日成本上限 shadow/canary(10%)/full、摘要失败取前 400 字、AI 端点限流 60/分。
6. **SBIR_NEW 的 RAG 没真做**：MMR、同义词展开是可抄的死码；「生向量／写向量／查向量」三步要 BrainStrom 自己写。

---

## 第 1 章 · 资料模型（地基，最先做）

### 1.1 现状（模拟后端实况）

- `systems`：`{ id, ownerId, title, visibility, mode, version, tags[], createdAt, updatedAt, deletedAt, snippet }`
- `blocks`：`{ id, systemId, type, position, payload, createdAt, updatedAt, deletedAt }`
- 自由速记「原文」存法：一个 `type:'text'`、`payload.role==='body'`、`position:-1` 的块（`main.js` 的 `saveBody`）。**这个 body block 的 `payload.content` 就是原文。**

### 1.2 活文件内容模型（v3 2026-06-11 拍板，本章核心）★

**模型是什么**（用现有代码对应着讲）：

- 一份笔记 = **一串有顺序的 blocks**：段落块（文字类）+ 模组块（表格/GitHub/进度环…），按 `position` 排序。这串块就是**唯一的内容真相**。
- **文章视图**：把块按顺序串起来画成一篇文章——段落块 = 段落，模组块 = 嵌在对应位置的小组件（像文章里插一张图）。**整篇可编辑**：点哪段改哪段（每段背后就是一个块，点一下变成可编辑框，改完存回那个块），文末有常驻续写区（写完按空行切成新的段落块）。段落合并/拆分用明确按钮（都算一步、可 Undo）。
- **卡片视图**：把同一串块拆开一张张显示（按过「卡片结构化」之前，这页是置灰/空状态）。卡片可直接编辑、删除、钉选。
- 改哪边都是改同一串块 → 两视图永远一致、零同步代码、来回切换零漂移。**禁止为任一视图另外存一份文字**（存两份就会打架）。
- **没有永久并存的「原始手写层」**：使用者永远在最新版上继续写；最早的原稿自动成为版本历史的第 1 版（无限历史，永远找得回）。
- 旧的 body block 设计（`type:'text'`+`payload.role==='body'` 整篇存一坨）**废弃** → 迁移时按空行把 body 切成一串段落块。

**文件生命周期（`docState`，取代旧 `mode:'free'|'structured'` 的语意）**：

- `raw`（只写过、还没按过任何 AI 按钮）→ `optimized`（按过「优化文字」）→ `carded`(按过「卡片结构化」)。
- 这是**时间状态**，不是三个画面；画面永远只有「文章 / 卡片」两个（顶部两段切换，卡片段在 `carded` 之前置灰）。

**两个按钮怎么跑（共用同一条管线）**：

- **优化文字**：① 算全文指纹，和 `lastAiHash` 一样 → 提示「内容没变」、零成本结束；② 逐块比 `aiHash`，找出「新写的块（没指纹）/ 改过的块（指纹不符）」；③ 问「要不要顺便分主题加小标题」（每次都问）；④ 只把变动块＋少量前后文送 AI（**钉选块、模组块不进 AI 输入**，且 AI 不准跨越它们合并前后文；没变的块一个字不送、不准重写）；⑤ 安全阀（AI 动到没变块/钉选块、或字数暴冲超阈值 → 整批拒绝、保留原状）；⑥ 套用前自动存版本（一步）；⑦ 完成后更新每块 `aiHash`、系统 `lastAiHash`、`docState`；⑧ 顺手重算摘要＋向量（连动 Step 6）。
- **卡片结构化**：先走同一条优化管线（已优化且没变的块直接跳过，不重复扣钱），再把块归组成主题卡（如果之前答应过分主题，小标题就是现成的分卡边界）；第二次以后走增量（见 Step 5）。

**为什么「没变的段落不重送」是铁律**：① 省钱；② 防「影印机效应」——整篇重送会让 AI 把已优化的段落一遍遍重写，每代走样一点，按多了内容面目全非且无人察觉。指纹挡住它。

### 1.2b 编辑器与切块细则（开发级规格，v3.1 补）

**切块规则（body 迁移与文末续写共用同一个函式 `splitIntoBlocks(text)`）**：

- 按「**一个以上连续空行**」（regex `\n{2,}`）切块，每个自然段一个 `type:'text'` 块。
- 行首 `#` 的标题行**独立成块**（`type:'heading'`）。
- 代码围栏（```…```）内部**不切**，整段围栏归同一块。
- 切出来的块依序给 `position`；迁移旧 body 时各块设 `source:'notes'`、`pinned:false`、`aiHash:null`。

**文章视图·段落编辑器行为（点哪段改哪段）**：

1. 每个文字块渲染成一个只读段落；模组块渲染成组件（不可文字编辑）；钉选块显示 📌 标记。
2. 点一个段落 → 该段变成 textarea（自动聚焦）；其他段不动。
3. 失焦（blur）保存：内容**有变**才写回块＋落一步存档（trigger=`'cardEdit'`）；没变就只收起编辑框、不落步。
4. 文末常驻「继续写…」输入区：失焦时把输入文字用 `splitIntoBlocks` 切成新块 append（每次提交落一步，trigger=`'cardEdit'`）。
5. 段落「合并/拆分」按钮放在编辑态的工具列（v1 可后移到第二批）。
6. AI 操作（优化/结构化）进行中**锁定整个编辑器**＋显示进度，结束才解锁（防串流套用盖掉新打的字）。

**「要不要分主题」的 UI 形态（每次都问）**：

- 按「优化文字」→ 弹一个简单确认框：「要不要顺便分主题、加小标题？〔要〕〔不要〕」→ 选完把 `groupTopics: true/false` 带进 `ai.optimize(id,{groupTopics})` 才开跑。
- 答应时：AI 生成的小标题作为**独立 `type:'heading'` 块**（`source:'ai'`）插进块串；之后卡片结构化就拿这些标题块当**分卡边界**。

**优化文字的 patch 格式（tool_use 强制 schema，与卡片结构化同一套三件式）**：

```json
{
  "新增块": [ { "type": "text|heading", "payload": {...}, "插入位置": 3 } ],
  "更新块": [ { "块id": "...", "payload": {...} } ],
  "刪除块": [ "块id" ]
}
```

- 「刪除块」在优化里**只准用于合并场景**（两个乱段并成一段：一条更新＋一条删除，内容必须并进更新块里）；合法性判定见**附录 F2 安全阀统一规格**（程式判定，不信 AI 自己说）。
- 钉选块、模组块、没变的块：禁止出现在 patch 里（出现即整批拒绝）。

### 1.3 阶段二要补的栏位（先补，贯穿全程；v3 改版）

| 表 | 新增栏位 | 用途 | 引入于 |
|---|---|---|---|
| blocks | `source: 'manual'\|'ai'\|'notes'\|'voice'` | 来源标记（AI 产 vs 手动），只记出身、不代表保护 | Step 3 |
| blocks | `pinned: bool`（旧规划名 `locked`，语意改版） | **使用者钉选**；钉了 AI 永不改/删/跨越 | Step 4/5 |
| blocks | `aiHash: string`（取代 v2 的 `sourceAnchor`） | **上次 AI 处理完时这个块的指纹**——diff 与「没变不重送」的基准 | Step 3/5 |
| blocks | `structureGen: int` | 此块产自第几代 AI 操作 | Step 5 |
| systems | `lastAiHash: string`（取代 v2 的 `sourceHash` 语意） | 上次 AI 操作完成时**全文指纹**，hash gate 用 | Step 3/5 |
| systems | `docState: 'raw'\|'optimized'\|'carded'`（取代 `mode` 旧语意） | 文件生命周期状态 | Step 3 |
| systems | `ai_restructure_count: int` | AI 操作次数（已规划） | Step 3/5 |
| systems | `structuredAt: string` | 上次 AI 操作时间 | Step 3 |

新表（沿用 `backend-design.md`，真后端阶段建 migration）：

- `structure_versions`：`{ id, systemId, version, blocksJson, trigger, createdAt }` —— **全篇内容快照**（整串块存 JSON）。一键还原、上一步/下一步都吃这张表（抄 SBIR_NEW `proposal_versions` 概念）。**无限保留、不修剪**（使用者拍板无限退；纯文字很便宜）；第 1 版就是最早的原稿。

**`trigger` 完整枚举与触发时机（每种 = 落一步存档的时机，存的是「动手前」的状态）**：

| trigger | 什么时候存 |
|---|---|
| `optimize` | 按「优化文字」、确认分主题选项后、套用 patch 前 |
| `structure` | 第一次按「卡片结构化」、套用前 |
| `incremental` | 第二次以后按「卡片结构化」、套用 patch 前 |
| `cardEdit` | 改完一个块/卡失焦保存时（内容有变才存）；文末续写提交时 |
| `merge` / `split` | 按合并/拆分按钮时 |
| `delete` | 删一个块/卡时 |
| `addModule` | 加一张模组卡时 |
| `restore` | 整篇还原到某旧版前（还原本身可再 undo） |
| `migrate` | 旧 body block 迁移成段落块完成时（= 每个旧系统的「第 1 版」快照） |
- `embeddings`：`{ id, systemId, kind('note'|'summary'), chunkText, vector, model, createdAt }`
- `chat_threads`：`{ id, userId, scope('note'|'global'), systemId?, createdAt }`
- `chat_messages`：`{ id, threadId, role('user'|'ai'|'ctx'), content, createdAt }`
- `repo_bindings`：`{ id, systemId, provider, repo, tokenRef, createdAt }`
- `progress_snapshots`：`{ id, systemId, percent, stepStates(json), commitSha, createdAt }`

**Undo/Redo 怎么做**（使用者拍板：经典上一步/下一步、**不限次数**）：

- 算「一步」的操作：AI 优化（整次一步）、AI 结构化（整次一步）、改完一个块/卡（存档时）、合并、拆分、删卡、加模组、整篇还原。
- **不算「一步」**：打字过程中的每个字（用输入框原生撤销；blur/存档才落一步）。
- 每步动手前把整串块存成一张 `structure_versions` 快照，推进 Undo 堆叠；「上一步」= 还原到上一张快照、现状进 Redo 堆叠；「下一步」反向；中途做新操作清空 Redo（同一般编辑器）。
- 快照存后端（换装置、过几天都还在）；**无上限**。还原时文章视图与卡片视图必然一起回去（还原的是唯一那串块）。
- AI 操作进行中锁定编辑（防止串流套用时盖掉刚打的字）。

> 迁移注意：`addBlock` 加卡时 `source` 由呼叫方决定；旧块迁移补 `source:'notes'`、`pinned:false`、`aiHash:null`；旧 body block 按空行切成段落块。`backend-design.md` 旧规划的 `locked` 一律改名 `pinned`。模拟层只在 localStorage JSON 加这些键；真后端写 Supabase migration。

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
| `card_removed` | `{ cardId }` | 增量时 AI 删了一张卡（其内容已被使用者删掉；BrainStrom 自取的新名，SBIR_NEW 没有） |
| `proposal` | `{ items:[{action,label,args}] }` | 对话式编辑（Step 3.5）：AI 在回答末尾抛出可执行提议按钮（edit_text/structure/find_github/find_youtube/find_info），等使用者点选才动手 |
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

阶段二新增一个 `AIService extends Base`（继承 EventTarget，与现有四个 Service 同模式）。**事件规则**：串流过程中的逐字/逐卡更新走 `handlers` 回调（不广播）；AI 操作**完成落库后**才 `changed({type:'ai', op})` 派事件，让订阅的视图整体刷新。`SystemsService.undo/redo/restore` 完成后同样 `changed({type:'restore'})`。

**`handlers` 介面（所有 AI 方法共用，全部可选）**：

```js
{
  onDelta(text),          // AI 逐字吐字
  onCard(index, card),    // 一张卡/块完成（card_done）
  onCardRemoved(cardId),  // 增量删卡（card_removed）
  onProgress(cur, total, msg),
  onUsage(usage),         // token 用量
  onHit(systems),         // 全局找回命中列表（hit_list）
  onProposal(items),      // 对话式编辑提议按钮（proposal，Step 3.5）
  onDone(),
  onError(err)            // { code?, error }
}
```

所有方法签名一次列清，后面各 Step 只引用：

```js
class AIService extends Base {
  // Step 1 底层：所有 AI 方法共用的串流 transport
  async _stream(endpoint, payload, { onDelta, onCard, onDone, onError, onProgress, onHit })

  // Step 2 单专案聊天
  async chatNote(systemId, messages, handlers)

  // Step 3 优化文字（不卡片化；groupTopics = 这次要不要分主题加小标，每次询问后传入）
  async optimize(systemId, { groupTopics = false } = {}, handlers)

  // Step 3 + Step 5 卡片结构化（mode: 'full' 第一次 / 'incremental' 第二次；内部共用优化管线）
  async structure(systemId, { mode = 'incremental' } = {}, handlers)

  // Step 3.5 对话式编辑：聊天提议被点选后，按使用者意图直接改笔记（内部走 optimize 管线，有快照可 Undo）
  async applyEdit(systemId, { instruction } = {}, handlers)

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
| `ai.applyEdit(id,{instruction})` | 聊天里点选 AI 提议（Step 3.5） | `POST /ai/optimize`（带 instruction） | AIService.applyEdit() |
| `ai.optimize(id,{groupTopics})` | 笔记页·优化文字钮（先弹分主题确认框） | `POST /ai/optimize` | AIService.optimize() |
| `ai.structure(id,{mode:'full'\|'incremental'})` | 笔记页·卡片结构化钮 | `POST /ai/structure` | AIService.structure() |
| `blocks.addModule(id,type)` | 笔记左下工具按钮 | `POST …/blocks` | BlocksService.add() |
| `ai.searchGlobal(q)` | 首页全局 AI 框 | `POST /ai/search-similar` | AIService.searchGlobal() |
| `ai.chatGlobal(msgs)` | 首页全局对话 | `POST /ai/chat/global` | AIService.chatGlobal() |
| `ai.bindRepo(id,url)` | 进度卡·绑 repo | `POST /ai/repo/bind` | AIService.bindRepo() |
| `ai.analyzeProgress(id)` | 进度卡·分析 | `POST /ai/progress` | AIService.analyzeProgress() |
| `ai.findRelatedOSS(id)` | 开源参考卡 | `POST /ai/related-oss` | AIService.findRelatedOSS() |
| `systems.undo(id)` / `systems.redo(id)` | 笔记页·上一步/下一步钮 | `POST /api/systems/:id/undo`·`/redo` | SystemsService.undo()/redo() |
| `systems.versions(id)` / `systems.restore(id,v)` | 笔记页·版本列表 | `GET …/versions`·`POST …/restore` | SystemsService.versions()/restore() |
| `blocks.pin(id,bool)` | 卡片·钉选开关 | `PATCH /api/blocks/:id{pinned}` | BlocksService.update() |

> **触点改版注记**：阶段一的 `systems.setMode` 触点在 v3 **废弃**——`mode('free'|'structured')` 语意由 `docState` 取代（后端在 AI 操作时更新，前端不直接设）；顶部「文章/卡片」视图切换是**纯前端 UI 状态**，不打后端。

新增验收灯（`acceptance.html` 的 `LAMPS` + `Mock.status()`）：阶段一 6 盏 + 阶段二 8 盏 = **共 14 盏**：`ai_engine / chat_note / optimize / dialog_edit / structure / structure_incremental / global_recall / git_progress`（`dialog_edit` = Step 3.5 对话式编辑）。多个验收动作可共用一盏灯（对应见第 11 章表）。

### 前后端整合与切换设计（模拟层 ↔ Fly.io 真后端；v3.1 补缺）

> 使用者点名的缺口：现在前端是 GitHub Pages 上的静态 HTML（吃 localStorage 假后端），文档此前没写「怎么接真后端、怎么切换」。本节补齐。

**拓扑（现在 → 阶段二完成时）**：

- 现在：`GitHub Pages 静态前端(web/)` → `mockClient.js`（localStorage，全假）。
- 阶段二完成：`静态前端（GitHub Pages 照旧）` → ① AI 类触点打 `https://<app>.fly.dev`（Fly.io 常驻 AI 代理，锁全部金钥）；② CRUD 类触点仍打 mock（Supabase 是阶段三/真后端阶段才接，接上后 CRUD 触点再切）。
- **前端永远是静态页，不用搬家**；变的只有「服务层背后打谁」。

**切换开关（唯一开关点 = 服务层注入的 client）**：

- 新增 `web/src/config.js`：`export const BACKEND = { ai: 'mock' | 'real', data: 'mock' | 'real', aiBaseUrl: 'https://<app>.fly.dev' }`。
- 组合根建 Service 时按 `BACKEND` 注入 `mockClient` 或 `realClient`（`realClient` 与 `mockClient` **方法签名完全一致**——这就是触点表当唯一契约的意义）。UI 一行不改。
- **可以按「触点类别」分别切**：先把 `ai.*` 切 real（验真 AI），`systems/blocks/auth` 仍 mock；互不影响。

**SSE 串流怎么跨域接（关键技术点）**：

- 不用 `EventSource`（它只能 GET、带不了 body 和 header）；用 **`fetch` + `ReadableStream`**：`POST https://<app>.fly.dev/ai/optimize` → 逐行读 `data: {json}\n\n` → 喂给 `handlers`。`mockClient.aiStream` 模拟同一行为，所以前端解析代码两边共用。
- 断线/取消：`AbortController.signal` 传进 fetch，组件卸载或使用者按取消 → abort → Fly.io 端透传中断 Anthropic（省钱，见第 12 章风险 8）。

**CORS 与鉴权**：

- Fly.io 端 CORS 白名单只放前端正式域名（GitHub Pages 域）＋本地 dev（`localhost:*`）；`Access-Control-Allow-Headers: Authorization, Content-Type`。
- 每个请求带 `Authorization: Bearer <token>`：阶段二先用 dev token（Fly.io 校验一个共享密钥即可，防裸奔被刷）；阶段三换 Supabase Auth JWT，**前端代码不变**（仍只是带 header）。
- **金钥分布**：前端 0 把金钥；Fly.io 持 `ANTHROPIC_API_KEY`、`GITHUB_TOKEN`、（未来）`SUPABASE_SERVICE_KEY`、embedding 供应商 key，全在 Fly.io secrets。

**部署与健康检查**：

- Fly.io：1 台常驻小机（`min_machines_running=1`，避免冷启动毁串流体验），HTTPS 由 Fly 托管。
- `GET /ai/health` 回 `{ ok:true, version }`；验收页 `ai_engine` 灯的真后端模式就打这条（mock 模式打 `Mock.aiHealth()`）。
- 真后端没起来/挂了 → 前端 Service 捕获后回退提示「AI 服务暂时不可用」，CRUD 不受影响（两类触点独立）。
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
② 资料流：服务层取 `getSystem(id)` **当前活文件的全部 blocks**（段落块＋模组块，不管优化过没有；聊天永远基于「现在这一版」，要聊旧版先还原再聊）→ 组三层 system block（抄 SBIR `prompt-builder`）：㈠ 静态人设+规则（挂 `cache_control:ephemeral` 省 token）㈡ 该专案全文（每张卡序列化成文字）㈢ 任务指令 → 走 `/ai/chat/note` 串流。
③ 模拟层：`aiStream('/ai/chat/note')` 回一段「我读到你这则有 N 张卡，包含 X、Y…」的**假但反映真实卡片数**的回答（证明上下文真被读到）。
④ Fly.io 层：`POST /ai/chat/note`，三层 block + 快取，`streamAsync`。
⑤ 服务层：`AIService.chatNote(systemId, messages, handlers)`；触点 `ai.chatNote`。
⑥ 验收点（对应你要的 (a)(b)）：
   - **(a) 流式状态**：输入一句送出 → 回答逐字蹦出、右下显示 `usage` token、断线显示 `error`。`ai_engine`+`chat_note` 灯亮。
   - **(b) 单篇识别**：先手动加一张含特定关键字的卡（如「发票辨识」），问「这则在讲什么、提到哪些工具」→ AI 复述出那张卡内容 → 验收页显示「单专案问答→引用到 N 张卡」。

### 第 6 章 · Step 3：两个 AI 按钮——优化文字 ＋ 卡片结构化（第一次）

① 目标：「优化文字」把乱稿整理成一篇顺的文章（仍是文章）；「卡片结构化」把内容归组成一张张卡。两者改的都是同一串块，文章/卡片两视图同步。
② 资料流：
   - **优化文字**（`POST /ai/optimize`）：照 §1.2 八步管线——hash gate（`lastAiHash` 没变→零成本结束）→ 块级 diff（`aiHash`）→ 弹分主题确认框（UI 形态与 patch JSON schema 见 **§1.2b**；答应则 AI 顺便插入 `heading` 标题块）→ 只送变动块（钉选块/模组块不送、没变块不准重写）→ tool_use 回三件式块 patch（新增/更新/刪除，刪除仅限合并场景）→ 安全阀 → 套用前存快照（trigger=`'optimize'`，一步）→ 更新 `aiHash`/`lastAiHash`/`docState:'optimized'` → 重算摘要＋向量。
   - **卡片结构化**（`POST /ai/structure`，mode=full）：先走同一条优化管线（已优化没变的块跳过）→ prompt「每个主题归成一张卡（标题＋内容），卡的顺序要能直接串成一篇顺的文章；**资料不足的主题不要生卡**、不准编造」＋20 卡参考清单（注入方式见附录 F5；若有主题小标，小标=现成分卡边界）→ tool_use/parseAIJson 拿到**有顺序的卡阵列**（每张卡标注它吸收了哪些块 id）→ **full 模式不走 patch**：后端整批替换「未钉选的文字/标题块」为新卡阵列，钉选块与模组块**原位保留**（按相对顺序插回）→ 存快照（一步）→ 套用 → `card_done` 逐张推前端 → 记 `ai_restructure_count`、`lastAiHash`、各块 `aiHash`、`docState:'carded'`、`structuredAt`。（**只有 incremental 模式才走三件式 patch**，见 Step 5。）
③ 模拟层：`Mock.optimize` 假装把每段改顺（加标点/首字大写之类的假优化）逐块 emit；`Mock.structure(full)` 把段落按空行归组成几张 `source:'ai'` 卡逐张 emit。
④ Fly.io 层：`POST /ai/optimize` + `POST /ai/structure`（共用优化管线模组），`card_start/delta/card_done` 协议（块=卡，事件复用）。
⑤ 服务层：`AIService.optimize(id,{groupTopics},handlers)`、`AIService.structure(id,{mode:'full'},handlers)`；触点 `ai.optimize`、`ai.structure`。
⑥ 前端：顶部两段切换「**文章 ↔ 卡片**」（卡片段在 `carded` 前置灰）；文章视图整篇可编辑（点哪段改哪段＋文末续写区）；两视图从同一串 blocks 渲染（§1.2 规则）。
⑦ 验收点（对应 (c)·结构化 + 新模型动作）：
   - 按「优化文字」→ 段落逐段变顺 → `optimize` 灯亮；再按一次（没改内容）→ 提示「内容没变、没花钱」。
   - 按「卡片结构化」→ 卡片逐张浮现 → `structure` 灯亮、显示「回传 N 张卡」。
   - **两视图同步**：在文章视图点某段改一个字 → 切到卡片视图，同一张卡内容跟着变（反向也成立）。
   - **可撤销**：按「上一步」→ 这次 AI 操作整批消失（文章与卡片一起回去）；按「下一步」→ 整批回来；一路退到底能看到第 1 版原始乱稿（无限历史）。

### 第 6.5 章 · Step 3.5：对话式编辑（AI 在聊天里提议 → 经同意后直接动手改笔记）★使用者 2026-06-11 新增★

> 来源：使用者点子——「问 AI 觉得内容怎么样 → AI 给建议并问『要帮你改吗？』→ 答应后 AI 直接改、使用者看到笔记更新」；延伸「AI 还能问：要不要帮你找对应的 GitHub / YouTube / 相关资讯？」。
> 定位：这是把**已有的聊天（Step 2）＋优化管线（Step 3）＋安全网（Undo/快照）**接起来的体验升级，**骨架在本章落地，能力随后面 Step 逐步点亮**。

① 目标：聊天不只是问答，AI 可在对话中**提议具体修改**，使用者一句「好」就让 AI 直接套用到笔记（走优化管线、有快照可 Undo），并能提议「找 GitHub/YouTube/资讯」生成模组卡。
② 交互流程（两段式「提议 → 确认 → 套用」，绝不未经同意就改）：
   1. 使用者在聊天问「你觉得这则怎么样 / 帮我看看缺什么」。
   2. AI 回建议（纯文字），**并在结尾抛出可执行提议卡片**（结构化按钮，非纯文字）：例如〔✦ 帮我补上「风险分析」段落〕〔▦ 整理成卡片〕〔🔍 找相关 GitHub〕〔▶ 找参考 YouTube〕。提议由 AI 用 tool_use 回一个 `proposals` 阵列（每项 `{action, label, args}`），前端渲染成按钮。
   3. 使用者点某个提议 → 走对应已有管线：
      - `edit_text`（补段落/改写）→ 复用 `/ai/optimize` 的 patch 套用机制（块级 patch + 安全阀 + 套用前快照 trigger=`'optimize'`）→ 笔记当场更新、可 Undo。
      - `structure` → 走卡片结构化。
      - `find_github`（Step 7 接通前显示「即将推出」）→ 生 `github` 模组卡。
      - `find_youtube` / `find_info`（Step 8 接通前显示「即将推出」）→ 生媒体/资讯模组卡。
   4. 套用后聊天里回一条「已帮你补上 X，可按 ↶ 还原」。
③ 资料流：聊天回应的 SSE 末尾多一个事件 `proposal`（`{ items:[{action,label,args}] }`，已加入 §2.1 事件表）；前端 onProposal 渲染按钮；点击 → 调对应服务方法（edit_text → `ai.applyEdit(systemId, patch)` 内部即 optimize 管线；其余复用既有触点）。
④ Fly.io 层：`/ai/chat/note` 的 system prompt 增加「可在回答末尾用 tool 提出 proposals；绝不直接改笔记，必须等使用者点选确认」；`edit_text` 提议点选后走 `/ai/optimize` 同一端点（带 `instruction` 参数指明要补什么）。
⑤ 服务层：`AIService.chatNote` 的 handlers 加 `onProposal(items)`；新增 `AIService.applyEdit(systemId, {instruction}, handlers)`（内部即 optimize，附带使用者意图）。触点加 `ai.applyEdit`。
⑥ 前端：聊天气泡下方渲染「提议按钮列」；点击进入「确认 → 套用 → 显示更新 + 可还原」流程；未接通的能力（GitHub/YouTube/资讯）按钮显示锁/「即将推出」。
⑦ 验收点（新增 `dialog_edit` 灯）：问 AI「帮我补一段风险分析」→ AI 提议〔帮你补上风险分析〕按钮 → 点击 → 笔记多出该段、聊天提示「已补上，可还原」→ 按 ↶ 该段消失。GitHub/YouTube 提议在对应 Step 接通前显示「即将推出」。
> 能力点亮时程：`edit_text`/`structure` 在本章（Step 3.5）即可用；`find_github` 随 Step 7、`find_youtube`/`find_info` 随 Step 8 接通。

### 第 7 章 · Step 4：加模组（横排按钮，手动加卡 + 钉选开关）

① 目标：使用者能自己加卡、改卡；卡片标「来源」（manual）；想保护哪张卡就自己「钉选」。
② 资料流：选模组 → `blocks.add(systemId,{type,payload,source:'manual',pinned})`。**钉选默认值分两类**：手动加的**文字/标题块** `pinned:false`（AI 可整理它，安全靠快照+Undo）；**模组卡**（表格/GitHub/进度环等非文字 type）建立时自动 `pinned:true`（决策 3「视同天生钉选」的资料层落实）。**钉选开关只出现在文字/标题块上**（`blocks.pin` 触点）；模组卡**不显示开关**、恒为 `pinned:true`，使用者不能解钉（防止解钉后 AI 改坏模组资料，见附录 F8）。每次加模组落一步存档（trigger=`'addModule'`）。
③ 模拟层：**现状 `mockClient.js` 的 `addBlock`（约第 70–78 行）会忽略 `source`/`pinned`，必须先改它**，把这两个键写进建出的 block 物件（默认 `source:'manual'`、`pinned:false`，由呼叫方覆盖），否则照做等于没存。这步是 Step 3/5 的前置。
④ Fly.io 层：无新 AI 端点（纯 CRUD）。
⑤ 服务层：复用 `BlocksService.add`，加便捷 `addModule(systemId,type)`；触点 `blocks.addModule`、`blocks.pin`。
⑥ 前端：UI 从圆形旋钮**简化成横排按钮**（点一下弹出模组列表），加卡功能照做。**两个视图都能加模组**：插入的模组卡以同一个视觉组件出现在文章视图与卡片视图的对应位置（决策 7）；模组卡内容 AI 永不动（视同天生钉选）。
⑦ 验收点：验收页显示某笔记「手动加的 block 数 / 钉选卡数」；钉选卡是 Step 5 保护的输入。

### 第 8 章 · Step 5：增量结构化（第二次只补变动）★最复杂★

> 权威设计来源：`docs/增量结构化-SBIR模组完整记录与开发设计.md`（其下半部已按 v3 改版）。
> 关键：**SBIR_NEW 没有自动 diff、没有钉选、是字串 splice；BrainStrom 要自己写「块阵列版的差异侦测」。**
> **v3 基准搬家**：没有永久原始层了，diff 基准从「原始稿 hash」搬到「**上次 AI 输出**」——系统级 `lastAiHash` ＋ 块级 `aiHash`。语意：比的是「上次 AI 弄完的样子」vs「使用者在它上面的增改删」。

① 目标：卡片化之后使用者又改了内容（文章里续写/改段/删段、或直接改卡），再按「卡片结构化」→ 不整篇重做，只动变动处；AI 可更新、删除未钉选的卡；内容没变就不花钱；改坏了按「上一步」整批还原。
② 资料流（九步）：
   1. **Hash gate**：算当前全文指纹比对 `systems.lastAiHash`；一样 → 直接显示旧卡、**不呼叫 AI、零成本**。
   2. **自动 diff**：不一样 → 逐块比 `aiHash`（演算法伪代码见**附录 F3**）：没指纹的块=新增、指纹不符=变动；「已删块」= 从**最近一次 AI 快照**（`structure_versions` 里最近 trigger∈{optimize,structure,incremental,migrate} 的版本）取出旧块清单，比对当前块集合，旧有今无的就是已删（顺便拿到它的旧文）。纯程式，不花 AI。
   3. **组增量上下文**：把「新增/变动块的内容＋已删块的旧文（用途：告知 AI 这些内容使用者已删、不准写回来，对应旧卡可删）＋全部卡片清单(JSON，标注哪些钉选)」交给 AI，prompt 骨架见**附录 F4**：「钉选卡绝不准动；未变块已是成品不准重写；其余卡可更新；**删除只准用在内容已被使用者删掉或并入他卡的卡**；没提到的卡一律原样保留」。
   4. **AI 只回 patch**：`{ 新增:[{type,payload,插入位置}], 更新:[{cardId,payload}], 删除:[cardId] }`（tool_use 强制 schema；新增无 id、更新/删除带 id），不用 RFC6902。
   5. **钉选保护三层**：㈠ 资料层 `pinned` 卡永不进「可改/可删」清单（只给 AI 只读上下文）；㈡ prompt 层告知不准碰；㈢ 合并层即使 AI 误回也丢弃针对钉选卡/模组卡的任何 patch。
   6. **安全阀**：统一规格见**附录 F2**（与优化按钮同一套）——动+删超过未钉选块数 50%、单块字数暴冲 ±30%、触碰钉选/模组/没变块、删除不满足合法性（程式判定）→ 整批拒绝、保留原状、回 `{code:'safety_valve'}`、提示重试。
   7. **快照 + Undo**：套用前存 `structure_versions` 快照（trigger=`'incremental'`）——**一次增量 = 一步**，「上一步」整批撤销、「下一步」整批重做，也可在版本列表一键还原任意旧版（无限历史）。
   8. 更新 `ai_restructure_count+=1`、`lastAiHash`、变动卡 `aiHash`/`structureGen`、重算摘要+向量（连动 Step 6）。
   9. 前端只重画变动卡：新增的浮现、更新的原位刷新、删除的淡出（`card_removed` 事件），其余不闪、不重排。文章/卡片两视图同时生效（同一份资料）。
③ 模拟层：最小版——hash 相同返回旧卡；不同则保留钉选卡、追加新内容卡、删掉「内容已消失」的未钉选卡。证明「钉选没被洗掉、该删的会删、Undo 能整批回来」。重点放④。
④ Fly.io 层：`/ai/structure` 加 incremental 分支，实作块级 diff + patch 合并（含删除）+ 钉选三层保护 + 安全阀 + 快照。
⑤ 服务层：同 `AIService.structure(id,{mode:'incremental'},handlers)`；还原走 `SystemsService.undo/redo/restore`。
⑥ 验收点（对应 (c)·增量）：
   - **钉选保护**：钉选某张卡 → 改文章别处 → 再按卡片结构化 → 钉选那张一字未动、其余该更新的更新。
   - **删除跟着内容走**：在文章里整段删掉某段 → 再按卡片结构化 → 对应卡被删（钉选的不删）。
   - **版本还原**：按「上一步」→ 这次增量整批撤销；按「下一步」→ 再套用。
   - **省钱**：内容没改再按 → 提示「跳过 AI、没花钱」。
   - `structure_incremental` 灯，附「钉选卡数 / 本次是否跳过 AI / 可还原版本数」。

### 第 9 章 · Step 6：全局 AI 跨笔记找回（RAG）

> SBIR_NEW 的 RAG 没真做：MMR(`mmr.ts`)、query-expansion 是可抄死码；生向量/写向量/查向量三步要自己写。

① 目标：问一句模糊描述，跨全部笔记找回、指出在哪则。
② 资料流：
   - **写向量**（v3：**任何 AI 操作完成后**都顺手做，优化也算，连 Step 3/5；另对从没按过 AI 按钮的纯手写笔记做兜底向量化，不然全局找回会漏掉它们）：系统压成摘要（失败取前 400 字）→ `embed(text)→vector` → 存 `embeddings(kind='summary')`。输入文本 = 当前活文件全文（带 hash gate 防重算）。
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

> 每个验收点 = 一个可操作动作 + 一个可观察结果（灯号/画面）。`acceptance.html` 灯阵从阶段一 6 盏扩到 **13 盏**（6＋7）。**灯 7 盏、验收点 11 个**：多个验收动作共用一盏灯（哪个动作点哪盏灯见下表「灯号」栏）。**这张表就是开发过程的「前端检查点」清单——每做完一个 Step，开发要停下来让使用者照表操作验收，确认后才进下一步。**

| 验收点 | 动作 | 可观察结果 | 灯号 |
|---|---|---|---|
| **(a) AI 流式响应** | 聊天框输入一句送出 | 回答逐字蹦出 + 显示 token 用量 + 出错显示 error | `ai_engine`+`chat_note` |
| **(b) 单篇内容识别** | 加一张含关键字的卡，问「这则在讲什么」 | AI 复述出那张卡内容 | `chat_note`（附引用卡数） |
| **(c0) 优化文字** | 按「优化文字」 | 段落逐段变顺、钉选段与模组卡一字未动；没改内容再按→提示「没变、没花钱」 | `optimize`（附是否跳过 AI） |
| **(c1) 卡片结构化** | 按「卡片结构化」 | 卡片逐张浮现 + 「回传 N 张卡」 | `structure` |
| **(c2) 增量·钉选保护** | 钉选某卡→改文章别处→再结构化 | 钉选卡一字未动；其余该更新的更新、内容被删段落对应的卡被删 | `structure_incremental`（附钉选卡数） |
| **(c3) 增量·省钱** | 内容没改→再按结构化 | 提示「跳过 AI、没花钱」 | `structure_incremental`（附是否跳过 AI） |
| **(c4) 全局找回** | 首页输入模糊描述 | 命中正确系统、可点进去 | `global_recall`（附命中数） |
| **(c5) GitHub 进度** | 先按「绑 repo」（`ai.bindRepo`），再按「分析进度」（`ai.analyzeProgress`，两个独立动作） | 环形% + buildSteps 打勾 | `git_progress`（附完成度） |
| **(c6) 两视图同步** | 文章视图点一段改一字 | 切到卡片视图，同张卡同步变（反向也成立） | `structure`（附两视图同步） |
| **(c7) 版本还原·无限退** | 连按「上一步」一路退到底 | 每步整批撤销（文章与卡片一起回去），最底能看到第 1 版原始乱稿 | `structure_incremental`（附可还原版本数） |
| **(c8) 撤销/重做** | 按「上一步」再按「下一步」 | 一次 AI 操作整批撤销、整批重做 | `structure_incremental` |

---

## 第 12 章 · 风险清单 + 降级方案

| # | 风险 | 降级 |
|---|---|---|
| 1 | 结构化 JSON 解析失败/AI 乱回 | tool_use + 5 层 parse 兜底 → 仍失败回退「不改任何卡 + 提示重试」，绝不写坏数据 |
| 2 | **增量误删/误改不该动的卡（最严重）** | 钉选三层保护（资料 `pinned` + prompt + 合并层丢弃）；每次套用前快照，「上一步」整批撤销；安全阀：触碰钉选卡、删「内容明明还在」的卡、或变动量超阈值，一律整批拒绝 |
| 3 | 内容没变还呼叫 AI 烧钱 | hash gate：全文指纹 == `lastAiHash` 直接返回、不呼叫 AI |
| 3b | **影印机效应**：连按优化让 AI 反复重写已优化段落，内容逐代走样且无人察觉 | 块级 `aiHash` 指纹：没变的块一个字不送、prompt 明令不准重写；安全阀挡「AI 动到没变块」 |
| 3c | AI 串流套用时盖掉使用者刚打的字（竞态） | AI 操作进行中锁定编辑（显示进度条） |
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
| 文章视图 | 文章 | （渲染函式 renderArticle） | 同一串块串成一篇文章，整篇可编辑，不另存资料 |
| 卡片视图 | 卡片 | （渲染函式 renderCards） | 同一串块拆开一张张显示 |
| 全文指纹（系统级） | 全文指纹 | `lastAiHash`（v3 取代 `sourceHash`） | 上次 AI 操作完成时的全文指纹，hash gate 用 |
| 块指纹（块级） | 块指纹 | `aiHash`（v3 取代 `sourceAnchor`） | 上次 AI 处理完时这个块的指纹，diff 与「没变不重送」基准 |
| 文件状态 | 文件状态 | `docState` | raw → optimized → carded（取代旧 mode 语意） |
| 优化文字 | 优化文字 | `optimize` | AI 整理排版文笔，仍是文章 |
| 结构化代数 | 结构化代数 | `structureGen` | 第几代 AI 操作 |
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

1. 【地基 A】资料库补栏（blocks +source/pinned/aiHash/structureGen；systems +lastAiHash/docState/structuredAt；新表 structure_versions 无限保留）+ 旧 body block 迁移成段落块。→ 无灯，是前置。
2. 【地基 B】文章视图段落编辑器（规格照 §1.2b：点哪段改哪段＋文末续写区＋空行切块）+ 顶部两段切换「文章/卡片」+ Undo/Redo 地基（无限）。**含拆旧**：移除 `main.js` 的 `m-free/m-struct` 双模式 seg、`setMode()`、`renderContent()` 的 structured 占位分支、`saveBody()` 大 textarea（约 105/125-126/131-137/152-158 行），旧 body 资料用 `splitIntoBlocks` 迁移。→ 无灯，是前置（前端工作量最大的一块，**做完是第一个前端检查点**：让使用者实际打字/改段/Undo 验手感）。
3. 【Step 1】AI 共用引擎 + `/ai/health`。→ 点 `ai_engine`。
4. 【Step 2】单专案聊天 `chatNote`。→ 点 `chat_note`，验收 (a)(b)。
5. 【Step 3】优化文字 `/ai/optimize`（hash gate＋块级 diff＋分主题询问＋安全阀）＋ 卡片结构化 full。→ 点 `optimize`+`structure`，验收 (c0)(c1)(c6)(c7)(c8)。
5.5. 【Step 3.5】对话式编辑：聊天 `proposal` 提议按钮 + `ai.applyEdit`（点选后走 optimize 套用、可 Undo）；GitHub/YouTube/资讯提议先显示「即将推出」。→ 点 `dialog_edit`。
6. 【Step 4】加模组（横排按钮）+ 来源标记 + 钉选开关。→ 验收手动卡数/钉选卡数。
7. 【Step 5】增量结构化（基准 aiHash）+ 钉选三层保护 + 删除规则 + 安全阀 + 快照/Undo。→ 点 `structure_incremental`，验收 (c2)(c3)。
8. 【Step 6】全局找回 + 写/查向量（触发扩为「任何 AI 操作完成后」＋纯手写笔记兜底向量化）。→ 点 `global_recall`，验收 (c4)。
9. 【Step 7】GitHub 进度 + 找呼应开源。→ 点 `git_progress`，验收 (c5)。

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

### 2026-06-11 已拍板（不再是待定；v3 活文件模型）

- **活文件模型**：不保留永久并存的原始手写层；一份笔记 = 一串块，文章/卡片两视图同一份资料（使用者提出、压力测试改良后拍板）。
- **两个 AI 按钮**：「优化文字」（不卡片化）＋「卡片结构化」（共用优化管线）（使用者拍板）。
- **分主题询问**：每次按优化都问一次「要不要分主题加小标」（使用者拍板）。
- **`locked` 改「钉选 `pinned`」**：保护权交给使用者自选；AI 可改可删一切未钉选的块/卡（使用者拍板）。
- **AI 可以删卡**：内容被使用者删掉的卡可删（钉选的不删）；删前有快照（使用者拍板）。
- **Undo/Redo 无限退**：经典上一步/下一步、不限次数；版本快照无限保留（第 1 版=原始乱稿，永远找得回，所以不需要另外的「原稿备份」）（使用者拍板）。
- **回旧版只做整篇还原**，不做「捡回片段」（使用者拍板）。
- **模组卡两视图同渲染**：文章/卡片两个画面视觉呈现是同一个组件；AI 永不动模组卡内容（使用者拍板）。
- **段落=块**：文章每一段底层就是一个块，「改卡=改文章」天生成立——已向使用者说明并采用（编辑器多花几天工的代价已告知）。
- **文章视图编辑方式 = 点哪段改哪段**＋文末续写区；合并/拆分用专门按钮。
- **对话式编辑（Step 3.5，使用者 2026-06-11 新增）**：AI 在聊天里给建议并提议「要帮你改吗」，经使用者点选确认后才直接套用到笔记（走 optimize 管线、有快照可 Undo）；并可提议「找 GitHub/YouTube/相关资讯」生成模组卡（GitHub 随 Step 7、YouTube/资讯随 Step 8 接通，之前显示「即将推出」）。骨架落在 Step 3.5（见第 6.5 章），新增 `dialog_edit` 灯。

### 仍待拍板（沿用上面推荐默认即可开工）

- 上面第 1（tool_use）、第 2（embedding 供应商）、第 8（成本阀阈值）三项 ⭐ 仍未经使用者亲口确认。

---

## 附录 E · 关键文件索引

- 服务层：`web/src/services/index.js`（加 `AIService`）
- 模拟后端：`web/src/api/mockClient.js`（加 `aiStream`/`optimize`/`structure`/版本与 Undo + 补栏位）
- **触点（= 暂时版前端的「API 整合交接报告」）**：`web/src/touchpoints.js`（程式版，唯一契约源）＋ `全局开发文件夹/Workflow-1-看得到能用.md` §5（文字版）。前后端整合、SwiftUI 搬迁都照这张表；阶段二 13 条新触点登记进同一张表。
- 验收页：`web/acceptance.html`（`LAMPS` 扩 13 盏 + `Mock.status()` 补布尔）
- Step 5 权威设计：`docs/增量结构化-SBIR模组完整记录与开发设计.md`、`docs/HANDOFF-incremental-restructure.md`
- AI 引擎照抄参照（SBIR_NEW）：`saas/backend/src/ai/gateway.ts`、`utils/parse-ai-json.ts`、`chat/prompt-builder.ts`、`chat/handlers/chat-handler.ts`

---

## 附录 F · 开发级实作细则（v3.2 补，达开工标准的最后一里）

> 第二轮复验（开发代理视角）挑出的全部「不问人无法动工」缺项，在此一次补齐。各 Step 正文与本附录冲突时，**以本附录为准**。

### F1 地基 A：payload 标准与迁移脚本

**payload 标准结构**（前端渲染与 AI 序列化都按此）：

- `text`：`{ content: string }`（旧资料的 `text`/`role` 键迁移时丢弃，统一只留 `content`）
- `heading`：`{ content: string, level: 1|2 }`
- `todo`：`{ text: string, done: boolean }`
- 模组卡（先定三种，其余后续补）：`table`：`{ columns: string[], rows: string[][] }`；`github`：`{ repos: [{ name, url, stars, desc }] }`；`devProgress`：`{ percent: number, steps: [{ text, done }] }`。未定义的模组 type 渲染端容错显示 JSON 摘要。

**迁移伪代码（`migrateV2()`，mockClient `load()` 时跑，幂等：查 `db.meta.schemaVersion`）**：

```
if db.meta.schemaVersion >= 2: return
for each system:
  body = 该系统 blocks 中 type=='text' 且 payload.role=='body' 的块
  if body 且 body.payload.content.trim() 非空:
    segs = splitIntoBlocks(body.payload.content)   // §1.2b 规则；代码围栏整段一块
    依序插入 position 0..n-1（原有其他块顺延），每块:
      { type, payload:{content}, source:'notes', pinned:false, aiHash:null, structureGen:0 }
    软删 body
  elif body: 软删 body（空 body 不建空块）
  其余既有块补默认值: source:'notes', pinned:(模组类 type ? true : false), aiHash:null, structureGen:0
  system 补: lastAiHash:null, docState:'raw', ai_restructure_count:0, structuredAt:null
  存「第 1 版快照」(trigger='migrate')
db.meta.schemaVersion = 2
```

**`structure_versions.blocksJson`** = `JSON.stringify(当前未软删 blocks 完整阵列)`，不压缩。容量上限沿用 Workflow-1（单系统 blocks≤2000、payload.content≤64KB），见 F7 的 localStorage 限制处理。

**`mockClient.addBlock` 的字段改造归地基 A**（不是 Step 4）：接收并写入 `source/pinned/aiHash/structureGen`，默认 `'manual'/false/null/0`。

### F2 安全阀统一规格（优化与增量同一套，程式判定、不信 AI）

- 常量（默认值，最终阈值是附录 D8 待拍板项）：
  - `CHANGE_RATIO_CAP = 0.3`：任一「更新块」的字数变化超过 ±30% → 拒绝（抄 SBIR_NEW）。
  - `TOUCH_RATIO_CAP = 0.5`：一次 patch「改＋删」的块数 > 未钉选块总数 × 50% → 拒绝。
- **删除合法性**，必须满足其一，否则整批拒绝：
  - (a) 该块在本次 diff 的「已删清单」里（来源内容被使用者删掉，F3 判定）；
  - (b) 合并场景：被删块 `content` **归一化后**（去空白与标点）有 **≥50% 的字符以连续片段形式**出现在同批某个「更新块」里。
- 「内容明明还在」的定义 = 不满足 (a) 也不满足 (b)。
- 任何 patch 条目触碰钉选块 / 模组块 / 没变块 → 整批拒绝。
- 拒绝行为：不套用、不存版本、推 `{ type:'error', code:'safety_valve', error:原因 }`，前端 toast「变动过大，已保留原内容，可重试」。

### F3 块级 diff 伪代码（优化与增量共用）

```
prev = structure_versions 里最近一次 trigger∈{optimize,structure,incremental,migrate} 的快照的 blocks
cur  = 当前未软删 blocks
新增块   = cur 中 (文字/标题类) 且 aiHash == null
变动块   = cur 中 aiHash != null 且 hash(normalize(payload.content)) != aiHash
已删块   = prev 中存在、cur 中不存在的块（带旧 payload.content 当「已删旧文」）
没变块   = 其余
```

- `normalize(s)` = trim + 连续空白折成一格；`hash` 真后端用 sha256，模拟层可用 FNV/djb2（无安全需求）。
- `lastAiHash` = hash(全部未软删块的 `normalize(content)` 按 position 以 `\n\n` 串接)。
- AI 操作完成套用后：被新增/更新的块写 `aiHash = hash(normalize(新content))`，没动的块 `aiHash` 不变。

### F4 增量 prompt 骨架（钉选三层之 prompt 层示例，正式措辞抄 SBIR_NEW §4.3 精神）

```
你是笔记整理助手。输入：
(A) 使用者新增/修改的内容片段
(B) 使用者已删除的内容——这些不准写回来；对应的旧卡可以出现在「刪除」清单
(C) 当前全部卡片 JSON——pinned:true 的卡绝对禁止修改/删除/移动，也不准把内容并进它
规则：
1. 只回 patch JSON（新增/更新/刪除 三个阵列），不要任何其他文字。
2. 没提到的卡一律不动；没变的内容一个字不准重写。
3. 刪除只准用于：内容已被使用者删除、或已并入某个更新卡。
4. 保留客观事实（数字、名称）；所有 [方括号占位标签] 原样保留。
```

### F5 20 卡清单注入与聊天上下文细则

- **20 卡参考清单**：hardcode 成 Fly.io 端 prompt 模板常量（内容取自 §1.5 / `mvp/brainstorm-mvp.html`），挂 `cache_control: ephemeral`；模拟层不用。
- **「资料不足的主题不要生卡」**：tool_use schema 不允许空 content 卡；AI 对没料的主题直接不生卡（不要「留空卡」）。
- **Step 2 三层 system block 示例**：㈠ 静态人设＋规则（cache_control）㈡ `专案《{title}》共 {N} 块：\n[1·text] {content}\n[2·table] {序列化}…` ㈢ 任务指令。卡片数 N = 未软删 blocks 总数。
- **超限降级**：N>50 或总字数 >30,000 → 每块只取前 200 字；仍超 → 每块只取「标题/前 100 字」。
- **mock chatNote 行为**：回「这则笔记有 N 张卡，提到 {任一块 content 的前 8 个字}…」（证明上下文真的被读到），逐字 emit。

### F6 向量与 GitHub 细则

- `embed(text: string): Promise<number[]>`；真实作 = OpenAI `POST /v1/embeddings`（`model:'text-embedding-3-small'`，回 `data[0].embedding`，1536 维），key 只在 Fly.io。模拟层**不做假向量**——`searchGlobal` 直接关键字 `includes` 匹配各系统摘要/标题。
- **兜底向量化时机**：任何 AI 操作「响应回完之后」后台异步跑（不阻塞主流程）：找该用户「没有向量、或向量指纹 != 当前 `lastAiHash`」的系统，每轮最多补 5 个（防雪崩）。
- MMR 默认参数：top-k=8、λ=0.7（λ 越大越偏相关性）。
- **buildSteps 卡 payload**：`{ steps: [{ text, done }] }`（AI 结构化产出或手动维护）。
- **进度算法伪代码**：拉 default branch 最近 ≤200 commits（GitHub REST `GET /repos/{o}/{r}/commits`）＋档案树（`GET /git/trees/HEAD?recursive=1`）→ 每个 step：①关键字粗筛（step 文字分词 vs commit message/檔名）②AI 终判给 `0 | 0.5 | 1` 分＋一句 evidence → `percent = round(Σ分/步数×100)`，永远标注「粗略估计」。
- **`progress_snapshots.stepStates`** = `[{ "step": "...", "score": 0|0.5|1, "evidence": "..." }]`。

### F7 Undo/Redo 实作（模拟层）

- 存放：mock db 内 `db.versions = { [systemId]: [ {version, blocksJson, trigger, createdAt} ] }` + 指针 `db.versionPtr = { [systemId]: n }`。
- **经典指针法**：每落一步 → 砍掉指针之后的版本（清 Redo）→ append 新快照 → 指针=末位。「上一步」= 指针-1 并整批还原该快照；「下一步」= 指针+1。还原后**整页重渲染**（块量小，不做 diff 渲染）。
- **localStorage 物理限制（约 5MB）的诚实处理**：mock 层在 db 总量 >4MB 时从「中段」开始丢旧版本，但**永远保留每系统的第 1 版（migrate/原始稿）与最近 50 版**，验收页显示「版本已精简」警告。「无限保留」的完整承诺由真后端（Supabase）兑现——这是浏览器限制，不是设计变更。
- UI 位置：笔记页顶栏右侧 ↶ ↷ 两钮；「文章/卡片」切换钮放原 `m-free/m-struct` seg 的位置；视图偏好存 sessionStorage。
- 超长段落：textarea 自动撑高、不折叠；内容 >2000 字时编辑框上方提示「建议拆分」。

### F8 其他定案（一句话一条）

- 模组卡**没有钉选开关**：恒 `pinned:true`，使用者不能解钉（防解钉后 AI 改坏模组资料）。
- token 成本计算在 **gateway 层**（`beforeAICall` 预检、收到 usage 后记账）；应用层不重复算。
- AbortSignal：`AIService._stream(endpoint, payload, handlers, signal)` 第四参数，透传给 fetch；组件卸载或「取消」按钮触发 abort。
- Step 3 full 模式**不走 patch**（整批替换未钉选文字/标题块，钉选/模组块原位保留）；只有 incremental 走 F2/F3/F4 那套 patch。
- 视图切换不打后端（纯前端状态）；`docState` 由后端在 AI 操作完成时更新。
