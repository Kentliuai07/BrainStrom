# 增量结构化技术 · SBIR_NEW 模组完整记录 + BrainStrom 开发设计

> 这份文档分两大块：
> **上半部（第 1～4 节）= 把 SBIR_NEW 里那个「AI 只改局部、保留原貌、省成本」的模组，原封不动记录下来 + 把原理讲透。**
> **下半部（第 5～7 节）= 针对 BrainStrom 的需求，设计「怎么改造这套方法」的开发蓝图。**
>
> 给之后正式开发的 AI：上半部是「事实记录」，请当成参考来源，不要改写它的结论；下半部是「我们要做的设计」，照它开发即可。
> 配套阅读：`docs/HANDOFF-incremental-restructure.md`（需求与整合落点的原始交接文档）。
>
> 建立日期：2026-06-10　｜　记录对象 repo：`Kentliuai07/SBIR_NEW`（私有，TypeScript）
> 行号均以 2026-06-10 当下的程式码为准；之后 SBIR_NEW 改版行号可能位移，但逻辑结构可对照。

---

## 第 0 节 · 使用者已拍板的决策（开发硬规则；2026-06-11 改版）

> ⚠️ **2026-06-11 改版**：原第 1 条「手改永久保护」已被使用者推翻，新规则是「三层内容模型」（详见 `docs/阶段二开发文档-变聪明-AI功能.md` §0.2、§1.2）。本文档**上半部（SBIR_NEW 忠实记录）不受影响**；**下半部（BrainStrom 开发设计）已按新规则改写**。

1. ~~**手改永久保护**（AI 永不动手改卡）~~ → **改为「钉选保护 + 版本还原」**：只有被使用者「钉选（pinned）」的卡 AI 永不动；其余卡（含手动加的）AI 可改、可删；安全网 = 每次动手前存版本快照 + 一键还原 + 上一步/下一步（Undo/Redo）。
2. **按钮触发**：第二次以后的结构化，由使用者按按钮才跑，不自动侦测自动跑。
3. **先记录再改**：先 100% 忠实记录 SBIR_NEW 所有方法，之后才慢慢改造（本文档上半部就是这份记录）。
4. **参考重写**：不直接搬码，参考做法在 BrainStrom 重写；但把 SBIR_NEW 的好东西（prompt、安全阀、版本快照、提示词快取）抄过来。
5. **（新增）三层内容模型**：原始散文（手写乱稿）AI 永不改写；AI 整理出「一份结构化内容」（一串有顺序的卡）；「优化散文」与「卡片」是同一份资料的两种皮，不存两份。

---

# 上半部 · SBIR_NEW 模组完整记录

## 第 1 节 · 一句话总结 + 最关键的发现

**这个模组在做什么**：使用者写了一份很长的计画书（分很多章，每章是一大串 Markdown 文字）。当使用者想改其中一小段时，模组能「只把那一小段拿给 AI 改、其他段落原封不动」，然后把改好的那段缝回原位，省 AI 成本、不破坏其他内容。

**三个最关键、会影响 BrainStrom 设计的发现**：

1. **它没有「自动侦测原文差异」的能力。** 它靠使用者（其实是上游 AI）在指令里写一个段落编号标记，例如 `[4.5.1]`，才知道要改哪一段。没有 Myers / LCS / diff-match-patch 这类文字 diff 演算法。→ BrainStrom 要的「使用者乱改原文、系统自己算出哪里变」这块，**SBIR_NEW 完全没有，得自己做**。

2. **「哪些不能动」靠「根本不送给 AI」实现，没有任何资料层标记。** 它没有 `locked` 锁、没有 anchor、没有 hash、没有 version 边界。规则就是：没被点名的段落，连碰都不碰，原字串直接拼回去。→ BrainStrom 需要资料层保护标记，所以**得自己加标记栏位**（SBIR_NEW 没有；`backend-design.md` 旧规划叫 `locked`，2026-06-11 改版后改为 `pinned` 钉选，见第 0 节）。

3. **资料形态是「一大串 Markdown 字串、用标题切段」，不是「一张张有分类的卡片」。** 合并方式是「字串 substring 拼接」。→ BrainStrom 是 ~20 张有 `type` 的卡片，**字串 splice 那套不能直接套用，要改成卡片阵列版**。

---

## 第 2 节 · 模组档案与资料模型（忠实记录）

### 2.1 核心档案清单（完整路径）

| 角色 | 档案路径 | 行数 |
|---|---|---|
| 进入点（主逻辑） | `saas/backend/src/chat/handlers/refine-handler.ts` | 399 |
| 切段定位 | `saas/backend/src/utils/markdown-section-parser.ts` | 243 |
| 品检 + 自动逐段修正 | `saas/backend/src/chat/pipeline/quality-checker.ts` | 771 |
| 局部重生（重做 1～N 章） | `saas/backend/src/services/evaluation-service.ts`（`partialRegenerate`） | ~80 行段 |
| 全篇版本快照 | `saas/backend/src/chat/proposal-versioning.ts` | 94 |
| 单章版本仓储 | `saas/backend/src/repositories/ProjectRepository.ts`（886–924） | — |
| 模型 / token 设定 | `saas/backend/src/config/constants.ts` | 213 |
| 21 按钮范例库（few-shot SSOT） | `shared_domain/refine-examples.ts` | 745 |
| 意图侦测（判断是 refine） | `saas/backend/src/chat/handlers/intent-detect.ts` | — |
| 路由入口（dispatch） | `saas/backend/src/chat/streaming.ts`（176–177） | — |
| 单章版本表 migration | `saas/backend/migrations/0018_section_versions.sql` | 15 |
| 测试 1（范围侦测） | `saas/backend/src/__tests__/refine-instruction-scope.test.ts` | 163 |
| 测试 2（prompt 注入） | `saas/backend/src/__tests__/refine-handler-prompt.test.ts` | 167 |
| 设计文件 | `DOCDOC文檔總集合/09_逐章refine邏輯鏈梳理_W3/00_explorer預掃報告_主腦.md` | — |

### 2.2 资料模型（两套版本表，忠实记录）

**单章版本表**（每次 refine 存一笔，可带修改指令）—— `migrations/0018_section_versions.sql`：

```sql
CREATE TABLE IF NOT EXISTS project_section_versions (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    section_index INTEGER NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    content TEXT NOT NULL,
    title TEXT NOT NULL,
    edit_instruction TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_section_versions
ON project_section_versions(project_id, section_index, version);
```

**全篇快照表**（每次大操作打包全部章节成一个 JSON）—— `proposal_versions`（栏位：`id / project_id / version / sections_json / trigger / created_at`）。`trigger` 可为 `'generate'`、`'refine'`、`'qc-fix'`、`'manual'`。

> 重点：SBIR_NEW **没有** `source`（这卡是 AI 产还是手改）、**没有** `locked`（受保护）、**没有原文 hash** 这些栏位。它的「保护」靠演算法（不送 AI），不靠资料标记。

---

## 第 3 节 · 演算法逐段忠实记录（附原始程式码）

### 3.1 主流程进入点 `handleRefine`

签名（`refine-handler.ts:18`）：

```typescript
export async function handleRefine(ctx: StreamContext, chapterIndex: number, instruction: string)
```

- `ctx`：含 Hono context、`projectId`、`projectPhase`、`apiKey`。
- `chapterIndex`：第几章（0-based）。
- `instruction`：使用者修改指令，**可能内含 `[4.5.1]`（点名段落）或 `[全章]`（整章重写）标记**。
- 回传：SSE 串流，事件顺序 `section_start` → `delta`（一段段吐字）→ `usage` → `section_done` → `done`。

### 3.2 第一步：侦测要改哪一段（Extract-Edit-Splice 的 Extract）

`refine-handler.ts:48-70`，**这就是「只改局部」的关键判断**：

```typescript
// ─── Extract-Edit-Splice: detect target section ───
const sectionRefMatch = instruction.match(/\[(\d+(?:\.\d+)*)\]/)
const isFullChapter = instruction.includes('[全章]')
let extractMode = false
let targetSection: { startIndex: number; endIndex: number; content: string } | null = null
let cleanedInstruction = instruction

if (sectionRefMatch && !isFullChapter) {
  const targetNumber = sectionRefMatch[1]
  cleanedInstruction = instruction.replace(/\[\d+(?:\.\d+)*\]\s*/, '').trim()
  const sections = parseMarkdownSections(section.content)
  const match = sections.find((s) => extractSectionNumber(s.heading) === targetNumber)
  if (match) {
    extractMode = true
    targetSection = { startIndex: match.startIndex, endIndex: match.endIndex, content: match.content }
  } else {
    logger.warn('Section number not found, falling back to full chapter', { targetNumber })
  }
}
if (isFullChapter) {
  cleanedInstruction = instruction.replace(/\[全章\]\s*/, '').trim()
}
```

白话：
- 指令里有 `[4.5.1]` 且不是 `[全章]` → 进「精准模式（extractMode）」：把整章切段，找到编号 4.5.1 那段，记下它「从第几个字到第几个字」（startIndex / endIndex）。
- 找不到那个编号（AI 编造不存在的号）→ 自动退回「全章重写」。
- 有 `[全章]` → 整章重写。

### 3.3 第二步：只把目标段丢给 AI（省成本关键）

`refine-handler.ts:265-267`，决定送多少字给 AI：

```typescript
const userMessage = extractMode
  ? `修改指令：${cleanedInstruction}\n\n原始段落內容：\n${targetSection!.content}`
  : `修改指令：${cleanedInstruction}\n\n原始章節內容：\n${section.content}`
```

白话：精准模式只送「那一小段」给 AI，全章模式才送整章。送的字越少，AI 越便宜越快。

### 3.4 第三步：把改好的段缝回原位（Splice）

`refine-handler.ts:320-323`，**这就是「保留其他段原封不动」的实作**：

```typescript
// ─── Splice: merge edited section back into full chapter ───
const finalContent = extractMode && targetSection
  ? section.content.substring(0, targetSection.startIndex) + newContent + section.content.substring(targetSection.endIndex)
  : newContent
```

白话：精准模式 = 「原文前半段（0 到 startIndex）+ AI 改好的新内容 + 原文后半段（endIndex 之后）」三段黏起来。前后段是原字串原封不动，所以其他段永远不会被 AI 弄坏。全章模式 = 直接用 AI 的整章输出。

### 3.5 第四步：存版本 + 更新 + 全篇快照

`refine-handler.ts:325-357`：

```typescript
const curMax = await ProjectRepo.getMaxSectionVersion(c.env.DB, projectId, chapterIndex)
// 若之前没版本，先把旧内容补存成 v1
if (curMax === 0) { /* insertSectionVersion v1 = oldSec.content */ }
// 新内容存成下一版
const newVer = Math.max(curMax, 1) + 1
await ProjectRepo.insertSectionVersion(c.env.DB, { projectId, sectionIndex: chapterIndex, version: newVer, content: finalContent, title: originalTitle, editInstruction: instruction })
// 更新现役章节
await ProjectRepo.updateSectionContentAndTitle(c.env.DB, projectId, chapterIndex, originalTitle, finalContent)
// 全篇快照
await saveProposalSnapshot(c.env.DB, projectId!, 'refine')
```

白话：改之前先把旧版存起来（能还原），改完存成新版，再把现役内容更新，最后打一张全篇快照。

### 3.6 切段定位器 `markdown-section-parser.ts`（忠实记录）

三个对外函式：

```typescript
export function parseMarkdownSections(markdown: string): ParsedSection[]
export function extractSectionNumber(heading: string): string | null   // "4.1 目標市場規模" → "4.1"
export function extractHeadingTitle(heading: string): string           // "4.1 目標市場規模" → "目標市場規模"
```

`ParsedSection` 结构：

```typescript
export interface ParsedSection {
  heading: string      // 标题文字（去掉 # 前缀）
  level: number        // 1=#, 2=##, 3=###, 4=####
  startIndex: number   // 这段在原字串里的起始字元位置
  endIndex: number     // 结束字元位置（不含）
  content: string      // 这段完整内容（含标题行）
}
```

切段规则（设计决策，原档注释明载）：
- 只认 ATX 标题（行首是 `#`）；**粗体伪标题 `**xxx**` 不算标题**。
- **程式码区块（```）里面的 `#` 不算标题**（用 `findFencedCodeBlockRanges` 排除）。
- 段落彼此不重叠、连续；第一个标题之前的内容当成 `heading="" level=0` 的虚拟段。
- 编号抽取靠 regex：先认「第 X 章」，再认「4.1.1 / 4.1 / 4.」这种点号前缀；都没有就回 `null`。

> 关键限制：定位准不准，完全取决于 AI 生成时有没有把标题写成正确的 `## 4.5.1 xxx` 格式。标题号错或漏，extract 就失败、退回全章。

### 3.7 品检自动逐段修正 `quality-checker.ts`（忠实记录）

这是**第二条增量路径**：AI 生成完一章后，自动叫另一个 AI 挑毛病（品检），只修有问题的段落。

**逐段修正迴圈**（`quality-checker.ts:339-392`，节录关键）：

```typescript
if (allMapped) {
  const affectedNums = new Set(sectionIssues.keys())
  // Stream sections in document order: unchanged fast, affected via AI
  for (const sec of parsedSections) {
    const num = extractSectionNumber(sec.heading)
    const issues = num ? sectionIssues.get(num) : undefined
    if (!issues) {
      // 没问题的段落 — 原文直接快速分块推给前端，不呼叫 AI
      revisedContent += sec.content
    } else {
      // 有问题的段落 — 只把这段 + 问题清单送 AI 改写
      const secPrompt = `[品檢發現的問題]\n${issueText}\n\n[待修正段落]\n${sec.content}\n\n修正規則：
1. 只修正問題清單中指出的具體錯誤
2. 保持原文結構、語氣、排版不變
3. 將錯誤的數字替換為規格書中的正確數字
4. 刪除幻覺內容，替換為「[待補充]」
5. 直接輸出修正後的段落 Markdown（包含標題行），不要開場白，不要輸出其他段落`
      // ... 呼叫 AI，结果接到 revisedContent
    }
  }
}
```

白话：每个段落如果品检没挑出问题，就直接复制原文（不花 AI 钱）；有问题才把那段 + 问题清单送 AI 改。和 refine 一样：没问题的段落不送 AI = 不会被弄坏。

**30% 字数暴冲安全阀**（`quality-checker.ts:424-430`）：

```typescript
if (!revisedContent) { qcLastFailReason = `第 ${attempt} 次修正回傳空內容`; continue }
const changeRatio = Math.abs(revisedContent.length - finalContent.length) / finalContent.length
if (changeRatio > 0.3) {
  qcLastFailReason = `第 ${attempt} 次修正字數變化 ${Math.round(changeRatio * 100)}% 超過 30% 限制`
  continue
}
```

白话：改完如果字数暴增或暴减超过 30%，就当 AI 乱搞、这次作废重试。最多试 `maxAttempts = 2` 次（`:308`）。

**两次都失败的降级**（`quality-checker.ts:446-456`）：

```typescript
if (qcLastFailReason) {
  // Restore original content to frontend so it doesn't show blank
  if (callbacks.onRevisionDelta) {
    const CHUNK = 80
    for (let i = 0; i < finalContent.length; i += CHUNK) {
      await callbacks.onRevisionDelta(chapterIndex, finalContent.slice(i, i + CHUNK))
    }
  }
}
```

白话：两次都失败，就把原文（没修的版本）推回前端，绝不让画面变空白。这是保底降级。

### 3.8 局部重生 `partialRegenerate`（忠实记录）

`evaluation-service.ts:135-189`（节录）：

```typescript
export async function partialRegenerate(env, projectId, apiKey, userId, affectedChapters: number[], onEvent): Promise<void> {
  const chunks = getChunksForPhase(pCtx.phase, 'chapters')
  const summaries = await loadChapterSummaries(env, projectId)
  for (let ci = 0; ci < affectedChapters.length; ci++) {
    const chIdx = affectedChapters[ci]
    // 1) 重新生成该章
    const result = await generateChapter(pCtx, chunk, chIdx, summaries, AI_MODELS.GENERATION, {...})
    await ProjectRepo.upsertSectionContent(env.DB, projectId, chIdx, chunk.title, result.content)
    // 2) 跑品检+自动修正
    const qcResult = await checkAndReviseChapter(pCtx, chIdx, ..., result.content, ...)
    if (qcResult.finalContent !== result.content) {
      await ProjectRepo.updateSectionContent(env.DB, projectId, chIdx, qcResult.finalContent)
    }
    // 3) 更新摘要
    const newSummary = await generateChapterSummary(pCtx, chIdx, chunk.title, qcResult.finalContent)
    await ProjectRepo.updateSectionSummary(env.DB, projectId, chIdx, newSummary)
  }
  await saveProposalSnapshot(env.DB, projectId, 'qc-fix')
}
```

白话：外面传「哪几章要重做」（如 `[2, 5]`），它就只重做那几章（生成→品检→摘要），其他章完全不碰，最后存快照。这是**章节粒度**的「局部重做」（比 refine 的段落粒度粗一级）。

---

## 第 4 节 · 模型 / 成本 / Prompt / 测试 / 扣款（忠实记录）

### 4.1 用哪个模型

`constants.ts:9-22`：**全部统一用 `claude-sonnet-4-6`**。首次生成、refine、品检全用同一个，**没有「增量用便宜模型」的分流**。

```typescript
export const AI_MODELS = {
  GENERATION: 'claude-sonnet-4-6',   // 章节生成
  QUALITY_CHECK: 'claude-sonnet-4-6',
  SPEC_SHEET: 'claude-sonnet-4-6',
  SUMMARY: 'claude-sonnet-4-6',
  FAST: 'claude-sonnet-4-6',
  PITCH: 'claude-sonnet-4-6',
} as const
```

refine 的输出上限 `TOKEN_LIMITS.REFINE = 8192`、`temperature: 0.3`（`refine-handler.ts:271-273`）。

### 4.2 省成本机制（三种，忠实记录）

1. **只送变动部分（Extract）**：精准模式只送目标段给 AI，不送整章 → 省输入 token。（最主要、最有效）
2. **提示词快取 prompt caching**：`cache_control: { type: 'ephemeral' }`。在 `refine-handler.ts:262`（few-shot block）、`chapter-generator.ts:229/234/243`、`chapter-summarizer.ts:45`、`quality-checker.ts:207` 都有挂。意思是同一 session 多次呼叫时，固定不变的 system prompt 由 Anthropic 从快取读，省最多 ~90% 输入 token 费。
3. **文件上传 SHA-256 去重**：`secondary-routes.ts:187-198`，上传同一份档案时用 hash 比对，已萃取过就直接回 `{ duplicate: true }`，不重跑 AI。**但这只限「文件上传」层。**

**没有的机制（重要）**：**没有「章节内容没变就跳过 AI」的 hash gate。** 每次按 refine 或 generate 都会打 AI。→ 这正是 BrainStrom 要补的「原文没变就别花钱」那块。

### 4.3 Prompt 全文（忠实记录 —— 这是教 AI「不要乱动」的精华）

**refine 精准模式 system prompt**（`refine-handler.ts:257`）：

> 你是 SBIR 計畫書修改顧問。根據使用者的修改指令重寫以下段落。直接輸出修改後的段落 Markdown（包含原有的標題行），不要開場白，不要輸出其他段落的內容。保留原有的客觀事實（數字、公司名等）。所有方括號 [...] 格式的佔位標籤必須原樣保留，不得自行填補或刪除。

**refine 全章模式 system prompt**（`refine-handler.ts:258`）：

> 你是 SBIR 計畫書修改顧問。根據使用者的修改指令重寫章節。嚴格保留未指定修改的段落的原有格式和內容，只修改指令明確提到的部分。保留原有的客觀事實（數字、公司名等）。所有方括號 [...] 格式的佔位標籤（如 [待補充]、[需驗證]…）必須原樣保留，不得自行填補或刪除。直接輸出修改後的完整章節 Markdown，不要開場白。

**品检修正 prompt 修正规则**（`quality-checker.ts:364`）：「1. 只修正問題清單中指出的具體錯誤 2. 保持原文結構、語氣、排版不變 …」

**幻觉防护五条 HALLUCINATION_GUARD**（`refine-handler.ts:230-250` 节录精神）：范例只作格式骨架、自加数字要挂 `[需驗證]`、不准编造法规字号/DOI、保留所有方括号占位标签、用使用者实际产业不要被范例题材带走。

> 给 BrainStrom 的启示：这套「保留客观事实 + 占位标签原样保留 + 只改指定部分 + 不要输出其他段落」的措辞，是要直接抄进 BrainStrom 增量 prompt 的。

### 4.4 few-shot 范例库结构（`refine-examples.ts`，忠实记录）

- 是 21 个按钮的 SSOT 阵列 `REFINE_EXAMPLES: RefineExample[]`。
- 每个范例结构：`{ featureId, title, desc, badge, instruction, hoverBefore, hoverAfter, fewShotExample }`。
- 设计原则：`instruction` 只描述格式不提产业；hover/few-shot 全用占位符（项目 A/B、指标 X/Y、N1/N2）；保留 SBIR 标准角色（PM/RD/QA）和月份。
- `getFewShotBlock()` 把这个阵列动态组成给 P2 章节用的 few-shot block（P1 投影片用另一份更短的）。

### 4.5 测试覆盖（忠实记录）

`refine-instruction-scope.test.ts`（范围侦测合约）覆盖：
- AI 下 `[4.5.1]` → 走 extract，target=4.5.1，且能对到真实标题。
- AI 下 `[全章]` → 走全章。
- AI 漏标记（旧 bug）→ 前端自动补 `[全章]`（修复后行为）。
- AI 下父节 `[4.1]`（非叶节点）→ extract 抓 4.1。
- AI 编造不存在的 `[9.9.9]` → backend 找不到、退回全章。

`refine-handler-prompt.test.ts`（prompt 注入）覆盖：P2/P1 few-shot 正确注入、五条幻觉禁令存在、`cache_control: ephemeral` 至少一个 block 存在。

**没测的情境**：删内容后 splice 结果、段落重排、30% 被拒后的降级、AI timeout 路径。

### 4.6 降级策略（忠实记录，四层）

1. refine timeout → 推 `{ type:'error', code:'ai_timeout' }`，**不覆盖 DB**（原文还在）。
2. 品检逐段修字数超 30% → 作废重试，最多 2 次。
3. 品检 2 次都失败 → 把原文推回前端（不空白）。
4. spec（规格书）生成失败 → 整条 pipeline 中止。摘要失败 → 用原文前 400 字顶上。

### 4.7 扣款整合（忠实记录 —— 更正旧资讯）

**更正**：SBIR_NEW 的 CLAUDE.md 写「refine-handler 没接扣款」是**过时**的。实际程式码：
- `refine-handler.ts` 已接：`:4` import、`:80` 建 emitter、`:276` `withCreditEmit({ operation:'refine' })`、`:385` refine 后摘要也带扣款。
- `quality-handler.ts`、`quality-checker.ts`（`chapter-qc` / `chapter-section-revision` / `chapter-full-revision`）、`qc-routes.ts` 全部已接扣款。
- 真正没接的只剩 `chat-handler.ts`（一般对话）那条。

> 对 BrainStrom 的意义：BrainStrom 现在用模拟后端、还没有真扣款系统，这块阶段二接 Fly.io 时再处理；但「每个 AI 呼叫点都要能挂扣款 emitter」这个设计习惯要学起来。

---

# 下半部 · BrainStrom 开发设计

## 第 5 节 · 这套方法 vs BrainStrom 需求的落差总表

| 面向 | SBIR_NEW 现况 | BrainStrom 需求 | 结论 |
|---|---|---|---|
| 找出要改哪里 | 靠使用者指令里的 `[4.5.1]` 编号 | 使用者乱改原文，系统自己算差异 | **要新做：差异侦测层** |
| 资料形态 | 一大串 Markdown 字串 | 一串有顺序的卡（两种皮：优化散文/卡片） | **改写：卡片阵列版合并** |
| 保护机制 | 不送 AI（无标记） | **钉选卡**永不动（要 `pinned` 标记）；未钉选的 AI 可改可删 | **要新加：`source`/`pinned` 栏位** |
| 省成本：没变就跳过 | 没有（每次都打 AI） | 原文没变就别花钱 | **要新做：原文指纹 hash gate** |
| 省成本：只送变动 | 有（extract） | 要 | **直接抄做法** |
| 提示词快取 | 有（ephemeral） | 要 | **直接抄做法** |
| 安全阀 | 有（30% 字数） | 要（防 AI 暴走、防误删） | **直接抄做法、加删除规则** |
| 版本可还原 | 有（单章 + 全篇两层） | 要，且要「上一步/下一步」Undo/Redo | **抄做法、改成卡片版 + Undo 堆叠** |
| Prompt 措辞 | 有（保留事实/占位/只改指定） | 要 | **直接抄措辞** |
| 模型分流省钱 | 没有（全 Sonnet） | 可选优化 | 可考虑增量用 Haiku |

一句话：**SBIR_NEW 给我们一台「只改一块、不碰其他、改太凶就退回、能还原」的好机器；缺的「自动看出原文哪里变」我们自己补，并把它从「字串版」改造成「卡片版」——而且新规则下 AI 连删卡都可以（钉选的除外），所以「能还原」要升级成「快照 + 上一步/下一步」。**

---

## 第 6 节 · BrainStrom 增量结构化 · 演算法设计

> 命名统一用中文（见 6.6 命名对照表）。以下「卡片」= BrainStrom 的 block（阶段二的 ~20 卡模板之一）。

### 6.1 资料模型改造（沿用 `backend-design.md` 规划的栏位；`locked` 改名改语意）

每张卡片（block）要有：

- `來源`（`source`）：`ai` | `manual`（手动）| `notes` | `voice` —— 只记「这卡谁生的」，**不再代表保护**。
- `釘選`（`pinned`，旧规划名 `locked`）：true / false —— **使用者主动钉住的卡，AI 永不改、不删、不移**。语意改版：旧版是「手改卡系统强制永不碰」；新版保护权交给使用者自选，未钉选的卡（含手动卡）AI 都可动。
- `來源原文指紋`（`sourceAnchor`）：这张卡是「原文哪一段」生出来的指纹，供下次比对「这段原文有没有变 / 还在不在」。
- `結構化代數`（`structureGen`）：这张卡是第几代结构化产生的。

系统层（system）要有：

- `原文指紋`（`sourceHash`）：上次结构化时整份原文的指纹，用来一秒判断「原文到底有没有变」。
- `重新結構化次數`（`ai_restructure_count`）：每跑一次增量 +1。

版本层（新表 `structure_versions`，抄 `proposal_versions` 概念改卡片版）：

- `{ id, systemId, version, blocksJson, trigger, createdAt }` —— 每次「会动结构化内容的操作」前存一张整串卡的快照；一键还原、上一步/下一步（Undo/Redo）都吃这张表。

### 6.2 主流程（按钮触发 → 增量合并）

使用者按「AI 结构化」按钮后：

1. **算原文指纹**：把现在的原文算一个 hash，和系统记录的上次 `原文指紋` 比。
   - **一样** → 原文没变，**完全不呼叫 AI**，直接显示旧卡片。（这就是「省钱」的第一道闸，SBIR_NEW 没有，我们补上。）
   - **不一样** → 进第 2 步。

2. **差异侦测（SBIR_NEW 缺、我们新做）**：把「旧原文」和「新原文」做文字 diff，算出「哪几块原文片段是新增/变动/被删的」。BrainStrom 的自由速记可能没有干净标题，所以建议：
   - 优先用「段落/空行」切块（每个自然段当一块），各块算指纹。
   - 比对新旧各块指纹，标出「新增块」「变动块」「删除块」「没变块」。
   - 这一步**纯程式、不花 AI 钱**。

3. **组增量输入给 AI**：只把「变动相关的原文片段（含被删段的旧文）+ 现有卡片清单（标注哪些是 `pinned` 钉选）」交给 AI，并下死命令（抄 SBIR_NEW prompt 精神）：
   - 「`pinned`（钉选）的卡绝不准动——不改、不删、不移。」
   - 「只针对我给你的变动片段，决定要新增哪几张卡、更新哪几张卡；**删除只准用在『对应原文段落已经被删掉』的卡**。」
   - 「没提到的卡一律原样保留。保留客观事实、占位标签原样保留。」

4. **AI 只回 patch（要新增/更新/删除的卡）**：用 `tool_use + JSON schema` 强制 AI 回结构化结果，例如：
   ```json
   {
     "新增卡片": [ { "type": "...", "payload": {...}, "插入位置": 3 } ],
     "更新卡片": [ { "卡片id": "...", "payload": {...} } ],
     "刪除卡片": [ "卡片id" ]
   }
   ```
   **不准回「没变的卡」「钉选的卡」。**

5. **本地合并（卡片版 Splice）**：在后端用程式把 patch 套到现有卡片阵列：
   - `pinned`（钉选）的卡 → **硬跳过，连改的资格都不给**（双重保险：就算 AI 不听话回了它们，合并层也挡掉）。
   - `更新卡片` → 换对应卡的 `payload`（未钉选的都可以，含手动卡），**位置 position 尽量不动**。
   - `刪除卡片` → 只有「对应原文段落确实已被删」且未钉选的卡才真的删；否则丢弃这条 patch。
   - `新增卡片` → 插到指定位置。
   - 这就是 SBIR_NEW「前段 + 新内容 + 后段」字串拼接的**卡片阵列版**。

6. **安全阀（抄 SBIR_NEW 30%，加删除规则）**：若 AI 这次「要改＋要删」的卡片数 / 内容量超过某阈值（例如动超过一半的卡，或单卡字数暴冲 >30%），或想动钉选卡、想删「原文段落还在」的卡，**作废这次合并、保留原状**，提示使用者「变动过大，已保留原内容」。

7. **存版本 + 推 Undo + 更新指纹 + 重算摘要**：
   - 套用前存一张「全篇卡片快照」进 `structure_versions`，并推进 Undo 堆叠——**一次增量 = 一步**，按「上一步」整批撤销、「下一步」整批重做，也可在版本列表一键还原任意旧版。
   - 更新系统 `原文指紋` = 新原文 hash；每张被生出/更新的卡更新 `來源原文指紋`。
   - `重新結構化次數 += 1`。
   - （阶段二）重算摘要 + 向量（给全局搜寻用）。

8. **前端只重画变动卡**：新增的浮现、更新的原位刷新、删除的淡出；其余卡不闪动、不重排。优化散文皮与卡片皮**同时生效**（同一份资料的两种皮）。

### 6.3 保护机制（2026-06-11 改版：从「手改卡全保护」改成「钉选卡保护 + 全体可还原」）

**钉选卡**的三层保险，缺一不可：

1. **资料层**：使用者在卡上按「钉选」→ `pinned=true`。
2. **Prompt 层**：明确告诉 AI「这些 id 的卡不准动」，并**根本不把它们的可改权交给 AI**（只给只读上下文）。
3. **合并层**：后端合并时，对 `pinned` 卡做白名单挡板——即使 AI 回了要改/删它们，也直接丢弃那条 patch。

**未钉选卡**（含手动加的）的安全网：

4. **快照层**：每次套用 patch 前先存 `structure_versions` 快照——AI 改坏了、删错了，按「上一步」整批回来，或在版本列表一键还原。

> SBIR_NEW 只有第 2 层（不送 AI）；BrainStrom 要四层都做。旧版「`source=manual` 一律不准动」已废除：`source` 只记出身，保护看 `pinned`。

### 6.4 省成本设计（综合抄 + 新做）

- **原文没变就不呼叫 AI**（指纹 hash gate）—— 新做，最省。
- **只送变动片段给 AI**（diff 后只送变动块）—— 抄 SBIR_NEW extract 精神。
- **提示词快取**（固定 system prompt 挂 `cache_control: ephemeral`）—— 直接抄。
- **可选优化**：增量合并这种小任务，可考虑用更便宜的模型（如 Haiku）跑，首次全量才用 Sonnet。SBIR_NEW 没做这个分流，BrainStrom 可当成第二阶段优化。

### 6.5 整合落点（对照 `HANDOFF` 第 6 节五处）

| # | 落点 | 档案 | 阶段一（模拟） | 阶段二（真 AI on Fly.io） |
|---|---|---|---|---|
| 1 | 服务层 | `web/src/services/index.js` | 新增 `結構化(systemId,{mode})`，打 `Mock.structure` | 同介面改打 `POST /ai/structure` |
| 2 | 触点登记 | `web/src/touchpoints.js` | 加一条 `systems.structure → POST /ai/structure` | 同 |
| 3 | 模拟后端 | `web/src/api/mockClient.js` | 实作 `structure()`，补 `source/pinned/sourceHash` 栏位，incremental 用简单规则模拟 | （阶段二不用，逻辑搬到 Fly.io） |
| 4 | 前端 | `web/src/main.js` `renderContent()` | 占位字串换成「呼叫服务层 → 渲染卡片、只更新变动卡」 | 介面不变，UI 不用改 |
| 5 | 真后端 | Fly.io AI 代理 `POST /ai/structure` | — | 实作 6.2 全套（差异层 + AI 合并 + JSON patch + 三层保护 + 安全阀 + 版本 + 快取） |

> 注意：使用者已决定**不做阶段一模拟预览**（第 0 节决策 3），所以阶段一的模拟实作可**最小化或跳过**，重点放在阶段二真后端的设计与开发。介面（服务层签名、触点）仍建议先定好，让 UI 不用改。

### 6.6 中文命名对照表（统一命名用）

| SBIR_NEW（原） | BrainStrom 中文命名 | 程式识别名（建议） | 说明 |
|---|---|---|---|
| refine / extract mode | 增量结构化 / 精准模式 | `incrementalStructure` | 只改变动部分 |
| section number `[4.5.1]` | 卡片定位 | — | BrainStrom 改用 diff 自动定位，不靠手填编号 |
| splice（字串拼接） | 卡片缝合 | `mergeCards` | 卡片阵列版合并（含删除） |
| locked / source=manual | 钉选 / 来源 | `pinned` / `source` | 钉选=AI 永不碰（使用者自选）；来源只记出身 |
| sourceHash（系统级） | 原文指纹 | `sourceHash` | 判断原文有没有变 |
| section/source hash（卡级） | 来源原文指纹 | `sourceAnchor` | 卡来自哪段原文 |
| changeRatio 30% | 字数暴冲安全阀 | `CHANGE_RATIO_CAP` | 防 AI 暴走 |
| proposal snapshot | 全篇卡片快照 | `structure_versions` | 可整份还原；Undo/Redo（上一步/下一步）也吃它 |
| section version | 单卡版本 | `cardVersion` | 单卡可还原 |
| few-shot block | 范例教学块 | `fewShotBlock` | 教 AI 格式 |
| prompt caching | 提示词快取 | `cache_control` | 省 token |
| ai_restructure_count | 重新结构化次数 | `aiRestructureCount` | 第几代 |

---

## 第 7 节 · 给正式开发 AI 的工单（step by step）

> 顺序建议；每步独立可验收。资料层先行，再后端逻辑，最后前端接线。

1. **资料模型**：在卡片（block）加 `source` / `pinned` / `sourceAnchor` / `structureGen`；在系统（system）加 `sourceHash` / `aiRestructureCount`；新表 `structure_versions`。（`backend-design.md` 旧规划的 `locked` 改名 `pinned`、语意改钉选。）
2. **差异侦测层**（纯程式，无 AI）：写「旧原文 vs 新原文 → 新增/变动/删除块清单」的函式；含「原文指纹一样就直接 return 不动作」的 hash gate。
3. **增量 prompt + JSON schema**：照 4.3 措辞写 system prompt；用 `tool_use` 定义「新增卡片 / 更新卡片 / 刪除卡片」的 JSON schema，强制 AI 只回 patch。
4. **卡片缝合层 `mergeCards`**：实作 6.2 步骤 5 + 6.3 钉选三层保护 + 删除规则 + 6.4 安全阀。`pinned` 白名单硬挡。
5. **版本与还原**：抄 `proposal_versions` 做法改 `structure_versions`（存卡片阵列 JSON）；在它上面做 **Undo/Redo 堆叠**（上一步/下一步，一次 AI 操作 = 一步）+ 版本列表一键还原。
6. **服务层 + 触点 + 前端接线**：照 6.5 表把 `結構化(systemId,{mode})` 串起来；`undo/redo/versions/restore` 也登记触点；前端只重画变动卡，两皮（优化散文/卡片）共用同一串资料渲染。
7. **测试**（补 SBIR_NEW 没测的）：覆盖「只新增 / 改中段 / 删内容（对应卡要被删）/ 重排 / 动到钉选卡（必须被挡）/ 删『原文段落还在』的卡（必须被挡）/ 原文没变（必须不呼叫 AI）/ Undo 后 Redo / AI 超时降级」。
8. **（阶段二）部署到 Fly.io**：把 4～5 的逻辑放进 `POST /ai/structure`，金钥只在 Fly.io，前端只送原文+收 patch。

### 待使用者后续确认（不挡开发，但影响细节）

- 「变动过大安全阀」的阈值要多少（SBIR 用 30% 字数；BrainStrom 卡片版可能用「动＋删超过 X% 的卡」）。
- 单卡版本要不要做（还是全篇快照 + Undo/Redo 就够）。
- 增量是否要用便宜模型（Haiku）做省钱分流。
- Undo 堆叠上限（推荐默认 50 步）。

### 已于 2026-06-11 拍板（取代旧悬念）

- `locked` 改「钉选 `pinned`」，保护权交使用者自选 ✔
- AI 可删卡（原文段落删了对应卡可删；钉选不删）✔
- 要做经典「上一步/下一步」Undo/Redo，不只快照列表 ✔
- 模组卡（表格/GitHub/进度环）在原稿、优化散文、卡片三画面视觉呈现同一个组件 ✔

---

## 附录 · 一句话白话总览

- SBIR_NEW 那台机器：你点名「改第几段」，它只把那段拿给 AI 改，别的原封不动黏回去，改太凶（字数变超过 30%）就退回，还能还原。
- 它缺一块：不会自己看出「原文哪里变了」，得你点名。
- BrainStrom 要补这块：你乱改原文后，系统自己用「指纹比对 + 文字 diff」算出哪里变，只把变动的丢给 AI，AI 只回「要新增/要改/要删的卡」，原文没变就完全不花 AI 钱。
- 新规则（2026-06-11）：AI 什么卡都能动、连删都行——**除了你亲手「钉选」的卡**，那些三层保险绝对不碰。怕 AI 改坏？每次动手前都先存快照，按「上一步」整批回来。
- 你手写的原始散文永远不会被 AI 改写；AI 整理出来的是「一份结构化内容」，看成一篇顺的文章（优化散文）或一张张卡（卡片）都是同一份资料。
- 命名全部用中文，照第 7 节工单一步步开发即可。
