# 交接文档 · 「增量重新结构化」功能（移植/参考 SBIR_NEW 的局部修改模组）

> ⚠️ **2026-06-11 规则改版（先读这个；现行 = v3 活文件模型）**：本文档里所有「100% 不动原本 / 手改卡永不被覆盖 / locked 保护 / 原文 hash」的说法**已被使用者推翻**。现行规则见 `docs/阶段二开发文档-变聪明-AI功能.md` §0.2 与 §1.2「活文件模型」：没有永久并存的原始手写层（最早原稿 = 版本历史第 1 版，无限历史永远找得回）；一份笔记 = 一串块，文章/卡片两视图同一份资料；两个 AI 按钮（优化文字 / 卡片结构化）；AI 可改可删一切**未钉选**的块（含手动卡），「钉选（pinned）」的永不碰；diff 与省钱基准 = 上次 AI 输出的指纹（`aiHash`/`lastAiHash`）；安全网 = 无限版本快照 + 不限次数上一步/下一步。本文档其余背景（SBIR_NEW 研究任务、整合落点）仍可参考，该研究已完成、记录在 `docs/增量结构化-SBIR模组完整记录与开发设计.md`。

> 给接手的新视窗：这份文档是「在另一个对话里整理好的完整背景 + 需求 + 现状 + 你要做的事」。
> 那个对话只有 `brainstrom` repo 的权限，**读不到 SBIR_NEW**；所以「研究 SBIR_NEW 模组」这件事，留给你（你应同时拥有 `Kentliuai07/SBIR_NEW` 与 `Kentliuai07/BrainStrom` 两个 repo 的存取权）。
> 全程请用「国中生也听得懂的白话文」跟使用者讨论。

---

## 0. 一句话需求（先看这个）

BrainStrom 的「AI 结构化笔记」：**第一次**把散乱原文整理成结构化卡片没问题；但**第二次以后**，使用者又改了原文时，**不要整篇重做**（既花冤枉钱，又会把已经整理好、甚至使用者手动微调过的内容全洗掉）。
要的是：**比对「原文的新旧差异」与「上次结构化结果」，只把新增/变动的部分合并进去，100% 不动到原本已结构化（与使用者手改）的内容。**

这个「AI 只做局部修改、保留原貌、省成本」的能力，使用者说 **SBIR_NEW 里已经有一个做好的模组**。本任务＝**把它搬过来，或参考它的做法**，整合进 BrainStrom 的结构化流程。

---

## 1. 这个功能在整体蓝图的位置

- BrainStrom 分三阶段：阶段一「能写」(Step 0–2，已做骨架)、**阶段二「变聪明」(Step 3–7)**、阶段三「能上架」(Step 8–9)。
- 本功能属于 **阶段二 · Step 3「AI 结构化」**（产品灵魂）。
  - Step 3 流程（`全局开发文件夹/03-开发步骤与策略.md:75-87`）：3.1 在 Fly.io 架常驻 AI 代理、开 `/structure` 接口；3.2 用 `tool_use + JSON schema` 强制 Claude 照「~20 卡模板」回、找不到留空、不准编造；3.3 校验+重试；3.4 前端串流一张张卡浮现。
- 本需求＝Step 3 里**没有被详细设计过的一块**：「**第二次以后的增量结构化**」。现有文档（`backend-design.md`、`memory-architecture.md`、两份 prompt 文档）都**只描述了「第一次全量结构化」，没有写「增量/差异合并」的做法**。所以这块是「真正要新设计」的部分 —— 而 SBIR_NEW 的模组正好可以借鉴。

---

## 2. 系统架构（三层，金钥与 AI 都在后端）

来源：`全局开发文件夹/02-开发总蓝图.md`、`01-技术选型.md`。

```
iPhone App(SwiftUI) ── HTTPS ──> Supabase(Auth/Postgres/pgvector，资料真相)
                                      │
                                      └──> Fly.io AI 代理(常驻，锁 Claude 金钥)
                                              └─ 所有 Claude 呼叫从这里走(串流)
```
- App 只画画面、存本地、发请求；**资料真相在 Supabase**；**所有秘密与 AI 都在 Fly.io**。
- 为何 Fly.io 独立：实测 Supabase Edge 当 LLM 云端会冷启动+串流不稳；Fly.io 常驻、延迟低、串流顺。
- **结构化的 AI 呼叫，未来一定是在 Fly.io 那台 AI 代理上跑**，不是在前端。前端只负责「送原文+上次结果」「收回结果并只更新变动卡」。

---

## 3. 目前 BrainStrom 的真实现状（很重要，别误会进度）

### 3.1 现在能动的是「过渡 Web 前端 + 模拟后端」
- 真前端代码在 `web/src/`：`main.js`(UI/画面)、`services/index.js`(服务层)、`api/mockClient.js`(**模拟后端，资料存浏览器 localStorage**)、`touchpoints.js`、`design/tokens.css`、`app.css`。
- 线上预览：GitHub Pages，从 **预设分支 `claude/kit-content-visibility-2vox39`** 部署。App 在 `web/index.html`，验收仪表板在 `web/acceptance.html`。
- **还没有真的 Supabase / Fly.io / Apple 登入**；登入、删帐号、RLS、JWT 全是 dev 占位/程式模拟。

### 3.2 「结构化」目前是空壳（这就是要接的地方）
- `web/src/main.js` 的 `renderContent()`：当 `mode==='structured'` 时，**只渲染一行占位字串**「还没整理 —— 阶段二接 AI 后，这里会变成结构化的卡片」（约 `main.js:137`）。
- **完全没有**任何「把原文送去结构化 / 比对 / 合并」的逻辑（12 个探勘代理一致确认）。
- 自由速记：标题是会自动换行的 `<textarea>`；正文存成一个 `type:'text'` 且 `payload.role==='body'` 的 block（`saveBody()`，约 `main.js:152-159`）。**这个 body block 的 `payload.content` 就是「原文」**。
- 模式切换 `setMode()`（约 `main.js:131`）会呼叫 `services.systems.setMode(id,'free'|'structured')` 存回后端。

### 3.3 服务层 / 触点（之后要在这里加方法）
- `services/index.js`：`AuthService`、`SystemsService`(list/create/get/update/setVisibility/setMode/delete)、`BlocksService`(add/update/toggleDone/delete/reorder)、`StatusService`。
- `touchpoints.js`：已登记约 15–18 条「前端碰后端」的触点（搬去 SwiftUI 时照这表重接）。
- **本功能要新增的触点（建议）**：`systems.restructure(id)` 或 `blocks.structure(id)` → 对应 `POST /ai/structure`（增量模式）。详见 §6。

---

## 4. 资料模型（含「刚好能用」的现成欄位）★关键★

### 4.1 模拟后端实况（`web/src/api/mockClient.js`）
- `systems`: `{ id, ownerId, title, visibility('private'|'public'), mode('free'|'structured'), version, tags[], createdAt, updatedAt, deletedAt }`
- `blocks`: `{ id, systemId, type, position, payload(物件), createdAt, updatedAt, deletedAt }`
- 目前 `payload`：`text`→`{content,(role)}`、`todo`→`{text,done}`、`heading`→`{content|text}`。
- **目前没有任何欄位连结「原文」与「结构化结果」**，也没有「这块是 AI 产的还是手动的」标记。

### 4.2 后端设计文档（`docs/backend-design.md`）已规划、但还没落到模拟后端的欄位 ★
这几个是做本功能的**现成地基**，新视窗务必沿用、不要另起炉灶：
- `blocks.source`：`manual | ai | notes | voice` —— **用来区分「AI 生成的卡」vs「使用者手动的卡」**。
- `blocks.locked`(bool) —— **用来标记「这块受保护、重新结构化时不准动」**。
- `systems.ai_restructure_count` —— 重新结构化的次数（版本/代数）。
- `blocks.type`：阶段二是「~20 卡模板」之一（`systemName/techStack/github/aiSearch/video/prompt/devFlow/buildSteps/table/...`，部分 PRO 锁）。
> 注意：阶段一的 `blocks` 只有 text/todo/heading 三种基础块，**不等于**阶段二的 20 卡（`Workflow-1-看得到能用.md:14`）。

### 4.3 输入上限 / 版本规则（`Workflow-1-看得到能用.md`）
- `title≤256`、`payload.content≤64KB`、`tags≤50`、单系统 `blocks≤2000`。
- `version`：内容相关变更（标题/模式/可见性/区块增改删）才 +1。

---

## 5. 期望的详细流程（要做出来的行为）

### 5.1 第一次结构化（已有设计，照 Step 3 做）
1. 使用者在某系统按「AI 结构化」。
2. 前端把该系统**原文**（目前＝body block 的 content；未来可含其他 block）送到 Fly.io `/ai/structure`。
3. AI 代理用 `tool_use + JSON schema` 强制 Claude 回「~20 卡」结构（找不到留空、不准编）。
4. 校验通过 → 把卡片存进 `blocks`（`source:'ai'`），串流回前端一张张显示。
5. 顺手：把这则压成「摘要+向量」存 `embeddings`（Step 6 全局搜寻用）。

### 5.2 第二次以后（本任务重点：增量合并，100% 不动原本）
设计目标（最终要让新视窗参考 SBIR_NEW 后定案）：
1. 使用者改了原文，再按「AI 结构化」。
2. 系统先判断「原文有没有变」（例如用原文 `hash` 比对 `systems` 上记录的上次 hash；没变就直接显示旧结果、不花钱）。
3. 若变了：把「**新原文 + 上次结构化结果(blocks) + 哪些是 locked/手改的**」一起交给增量逻辑（参考 SBIR_NEW 模组）。
4. 增量逻辑只产出「**要新增/要更新的那几张卡**」，并：
   - **绝不动** `locked:true` 或 `source:'manual'`（使用者手改）的卡。
   - 已存在的 AI 卡，只在对应原文段落真的变了时才更新；其余保持原样（连 position 都尽量不动）。
   - 真正全新的内容 → 新增卡，插到合适位置。
5. 前端只重画「有变动的那几张卡」，其他卡不闪动、不重排。
6. `systems.ai_restructure_count += 1`；更新原文 hash；重算摘要+向量。

> 这套「只回 patch、保留旧块」的精确算法，**就是要去 SBIR_NEW 里学的**（见 §7）。

---

## 6. 整合落点（程式码要加在哪）

> 阶段一可以先在**模拟后端**做一个「假的增量合并」预览，让使用者先看到行为；阶段二再把同一套介面接到真的 Fly.io `/ai/structure`。介面不变，UI 不用改。

1. **服务层**（`web/src/services/index.js`）新增（建议挂 `SystemsService` 或新开 `AiService`）：
   ```js
   // 把原文送去结构化；mode='full' 第一次全量，mode='incremental' 第二次以后增量合并
   async structure(systemId, { mode = 'incremental' } = {}) {
     return Mock.structure(systemId, { mode }); // 阶段二改打 POST /ai/structure
   }
   ```
2. **触点登记**（`web/src/touchpoints.js`）新增一条：
   `{ method:'systems.structure(id,opts)', ui:'笔记页·AI结构化钮', api:'POST /ai/structure', swift:'AiService.structure()' }`
3. **模拟后端**（`web/src/api/mockClient.js`）新增 `structure(systemId,{mode})`：
   - 取该系统 body block 当原文；算 `sourceHash`。
   - 给 blocks 补上 `source('ai'|'manual')`、`locked`、`structureGen` 等欄位（沿用 `backend-design.md` 的命名：`source`、`locked`、`ai_restructure_count`）。
   - `incremental` 时：保留所有 `locked/source==='manual'` 的块，只增/改 AI 块（阶段一可用简单规则模拟，等 SBIR_NEW 算法定案再换真逻辑）。
4. **前端**（`web/src/main.js` 的 `renderContent()` 结构化分支）：把占位字串换成「呼叫 `services...structure()` → 渲染回来的卡片清单」，并只更新变动卡。
5. **真后端（阶段二）**：在 Fly.io AI 代理实作 `POST /ai/structure`（含 incremental 模式），把 SBIR_NEW 的局部修改算法移植进去；prompt 要明确告诉 Claude「这些块不能动、只补新内容、不准重写既有卡」。

---

## 7. ★你（新视窗）要对 SBIR_NEW 做的事★

> 这个对话读不到 SBIR_NEW，所以以下没做。请你先派几个探勘代理把它摸清楚，再回来设计移植。Repo：`Kentliuai07/SBIR_NEW`（私有、TypeScript，最后更新 2026-05-24）。

**第一步：定位模组**
- 找出做「AI 局部修改 / 增量更新 / 保留原貌」的档案与进入点（可能在 `modules/`、`lib/`、名字含 diff/patch/merge/incremental/structurer 之类）。先看 README 与目录结构。

**第二步：搞懂演算法（逐题回答）**
- 差异侦测：用文字 diff（Myers/LCS/diff-match-patch）？还是结构/JSON diff？还是直接叫 AI 判断语义差异？
- 「哪些不能动」怎么界定：靠 `locked` 旗标？靠 block id/anchor 对齐？靠 version 边界？id 在修改后会不会变？
- 合并的输入/输出格式：输入是不是「原文 + 上次结果 JSON + 新文」？输出是 JSON Patch(RFC 6902) 还是自订 patch 还是整包新结果？
- 「只合并新内容」的精确语义：只追加？可改既有块吗？旧块顺序保不保？
- 用哪个模型、首次/二次是否换模型省钱、有没有 cache（用 hash 当 key）、prompt 怎么教 AI「不要动既有内容」。
- 有没有测试？覆盖哪些情境（只新增/改中段/删内容/重排/动到受保护块）？失败时的降级（回退全量）？

**第三步：对齐 BrainStrom**
- SBIR_NEW 的 block 结构能不能映射到 BrainStrom 的 20 卡 + `source/locked` 欄位？
- 移植 vs 参考重写：评估工作量、依赖、授权（是否方便直接搬码）。
- 产出「移植清单」：要新增/修改哪些档案（对照 §6）。

---

## 8. 限制与原则（务必遵守）
- **100% 不动原本结构化内容**＝硬需求；尤其 `locked` 或 `source:'manual'`（使用者手改）的块。
- **省成本**：原文没变就别呼叫 AI；只送/只处理变动部分。
- **金钥不进前端**：结构化 AI 永远在 Fly.io 跑。
- **UI 可替换**：UI 不直接碰后端，一律走服务层（搬 SwiftUI 时照 `touchpoints.js`）。
- **使用者不需在前端做任何手动操作**；这是开发整合工作。

---

## 9. 建议给使用者确认的问题（开工前）
1. 「不动原本」是否包含「使用者手动改过的 AI 卡也永不被覆盖」？（建议：是，用 `locked/source` 保护。）
2. 第二次结构化是「使用者按钮触发」还是「侦测原文变就自动跑」？（产品决策文档倾向**按钮触发**。）
3. 阶段一要不要先做「模拟版增量合并预览」让你先看到行为，还是直接等阶段二接真 AI？
4. SBIR_NEW 的模组是要「直接搬码移植」还是「只参考做法、在 BrainStrom 重写」？

---

## 10. 关键文件索引（新视窗可直接打开）
- 蓝图/流程：`全局开发文件夹/02-开发总蓝图.md`、`01-技术选型.md`、`03-开发步骤与策略.md`
- 阶段一契约：`全局开发文件夹/Workflow-1-看得到能用.md`
- 后端/资料模型（含 source/locked/ai_restructure_count）：`docs/backend-design.md`
- 记忆/向量：`docs/memory-architecture.md`
- 产品决策（双模式、按钮触发、可再编辑）：`docs/product-decisions.md`
- iOS/SwiftUI 结构：`docs/ios-structure.md`
- 现有 AI 提示词：`docs/prompt-for-claude-web.md`、`docs/prompt-for-claude-web-en.md`
- 前端：`web/src/main.js`、`web/src/services/index.js`、`web/src/api/mockClient.js`、`web/src/touchpoints.js`
- SBIR_NEW（需你自己的权限）：`Kentliuai07/SBIR_NEW`
