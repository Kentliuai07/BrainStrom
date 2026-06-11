# iOS 原生版 · 整合契约与算法规格（从真实代码盘点，2026-06-11）

> Swift 工程师照本文件可不读 JS 直接实作。出处：server/src/index.js、web/src/services/index.js、web/src/api/mockClient.js。
> 文中 Swift 片段为**示意**，以行为描述为准；行为有疑义回源码对照（标了行号）。

## 1. HTTP 契约

**Base URL**：`https://brainstrom-ai.fly.dev`；除 /ai/health 外都要 `Authorization: Bearer <AUTH_TOKEN>`。

### 1.1 GET /ai/health（免鉴权）
→ 200 `{ "ok":true, "version":"fly-1", "model":"claude-sonnet-4-6" }`

### 1.2 POST /ai/chat/note（SSE）
```json
{ "messages":[{"role":"user"|"ai","content":"…"}],
  "note":{ "title":"…", "blocks":[{"type":"text|heading|todo|…","content":"…","pinned":bool}] },
  "kickoff": bool }
```
- kickoff=false 时 messages 必非空；kickoff=true 允许空（教练主动开口）
- payload 总长 ≤100KB → 否则 400
- 400 `{error:'bad_request',detail}` / 401 `{error:'unauthorized'}` / 429 `{error:'rate_limited'}`（60 次/分/IP）

### 1.3 POST /ai/optimize（SSE）
```json
{ "note":{ "title":"…", "blocks":[{"id","type","content","pinned":bool,"changed":bool}] },
  "groupTopics": bool, "instruction": "string ≤2000 可选" }
```
- `changed:true` 的块才是 AI 可整理对象；false/pinned 是只读上下文
- 空 blocks 仅在带 instruction 时放行（「帮你起草」场景）
- 呼叫方差异：优化时 changed = diffBlocks 结果；applyEdit 时 changed = 全部未钉选文字/标题块

### 1.4 POST /ai/structure（SSE）
```json
{ "note":{ "title":"…", "blocks":[{"id","type","content","pinned":bool,"module":bool}] }, "mode":"full" }
```
（mode='incremental' 未实作 → 400）

### 1.5 错误 code 枚举
`unauthorized(401)` `rate_limited(429)` `bad_request(400)` `unknown_endpoint(404)`；SSE 流内：`ai_error` `upstream_error` `rate_limited` `ai_format`（AI 没回 tool）`safety_valve`（前端自产，非 server）

## 2. SSE 协议

- 传输：每事件一行 `data: {JSON}\n\n`；用 URLSession `bytes(for:)` 按行解析
- 事件枚举与形状：

| type | payload | 端点 |
|---|---|---|
| delta | `{text}` | chat |
| usage | `{input_tokens,output_tokens,cache_read_input_tokens,model}`（扁平） | 全部 |
| progress | `{current,total,message}` | chat(mock)/前端自产 |
| card_start | `{index,title,type}` | structure |
| card_done | `{index,card}` | optimize/structure（card 形状见下） |
| card_removed | `{cardId}` | optimize |
| proposal | `{items:[{action,label,args:{instruction?}}]}`，action∈edit_text/structure/find_github/find_youtube/find_info，label≤12 字 | chat |
| done | `{}` | 全部 |
| error | `{code,error}` | 全部 |

- **card_done 两种 card**：optimize → `{action:'add',type,content,position}` 或 `{action:'update',id,content}`；structure → `{type,title,content,absorbed:[blockId]}`
- 顺序：delta×N →（proposal）→ usage → done；错误时 error 后即 end
- **中断语意**：客户端 abort 后不再处理任何事件（不会有 done/error）；server 在响应被关闭时向上游 abort（省钱）

## 3. 必须移植到客户端的算法（行为必须与 web 一致）

常量：`CHANGE_RATIO_CAP=0.3`、instruction 模式 ratio=2.0、`DIFF_TYPES=['text','heading']`、`isModuleBlock = type ∉ [text,heading,todo]`、`LONG_PARA=2000`

1. **normalizeText(s)**：trim ＋ 连续空白折成一格。
2. **fnv1a(s)→8位hex**：FNV-1a 32bit（h=0x811c9dc5；逐 UTF-16 charCode：h^=c; h=(h*0x01000193)>>>0）。**注意 web 用 charCodeAt（UTF-16 码元）不是 UTF-8 byte**——Swift 移植用 `unicodeScalars`/UTF-16 对齐，否则两端指纹不一致。`fnvHash(s)=fnv1a(normalizeText(s))`。
3. **blockContent(b)**：payload.content ?? payload.text ?? JSON 序列化整个 payload。
4. **fullHash(blocks)**：未软删块按 position 排序 → normalize(content) 以 `\n\n` 串接 → fnv1a。
5. **shouldSkipAi(sys,blocks)**：sys.lastAiHash 非空 且 fullHash==lastAiHash。
6. **nudgeHash(title,blocks)**：只取 DIFF_TYPES 块（不滤 pinned）同上串接，前面接 `normalize(title)+"\n\n"` → fnvHash。模组卡增删不影响。
7. **diffBlocks(blocks)**：DIFF_TYPES 且未钉选的块中，aiHash==null 或 fnvHash(content)!=aiHash → changed；其余 unchanged。
8. **checkOptimizePatch(blocks, patch, changedIdSet, mode)** —— 安全阀（程式判定、不信 AI），拒绝即整批不动：
   - touchSet：optimize=changedIdSet；instruction=全部未钉选 DIFF_TYPES 块 id
   - `touch_ratio`：updates+removes 数 > touchSet.size → 拒
   - updates 逐条：id 不存在→`unknown_block`；pinned/模组/不在 touchSet→`touch_forbidden`；normalize 后字数变化 > max(旧长,1)×ratioCap→`change_ratio`
   - removes 逐条：同上两检；删除合法性=被删块内容去空白标点后，**≥50% 长度的连续片段**出现在某 update.content（同样 strip 后）里，否则 `illegal_remove`（空块可删）。**instruction 模式不放宽此项**
   - adds 逐条：type ∉ text/heading→`bad_add`；content 空→`bad_add`
9. **checkStructureCards(blocks,cards)**：cards 空→`empty_cards`；卡缺 title/content→`empty_card`；absorbed 含 pinned/模组块→`touch_pinned`。
10. **computeStructuredBlocks(blocks,cards)**：保留（非 DIFF_TYPES 或 pinned）块；gen=max(structureGen)+1；新块 type='text'、payload={title,content}、source='ai'、pinned=false、aiHash=fnvHash(content)；保留块按原 position 穿插回（insert at min(position, len)）。
11. **applyOptimizePatch（套用顺序，Critical）**：①呼叫端已先存快照 ②安全阀（拒→返回 reason，资料零变动）③updates 落库＋写新 aiHash ④removes 软删 ⑤adds 依 position 插入＋整批 reorder ⑥更新 system：lastAiHash=fullHash(新 blocks)、docState=（原 carded 则保持 carded，否则 'optimized'）、ai_restructure_count+1、structuredAt=now。
12. **applyStructureCards**：①安全阀 ②计画 ③软删全部未钉选 DIFF_TYPES 块 ④按计画建新块＋穿插保留块＋reorder ⑤system：docState='carded' 其余同上。
13. **splitIntoBlocks(text)**：```` ``` ````围栏整段一块不切；连续空行=段界；行首 # 行独立成 heading（#数>1→level2，否则 1）；其余累积成 text 块。

## 4. 本机资料模型（SwiftData 镜像）

**System**：id, ownerId, title(≤256), visibility('private'|'public'), version, tags[], lastAiHash:String?, docState('raw'|'optimized'|'carded'), ai_restructure_count:Int, structuredAt:String?, nudge:Nudge, createdAt, updatedAt, deletedAt?
**Nudge**：state('pending'|'dismissed'|'opened'), hash:String?, opening:{text, proposals[]}?, at:String?（新系统默认 pending/null）
**Block**：id, systemId, type, position:Int, payload(text/heading:{content,level?}; todo:{text,done}; 模组自由 JSON), source('manual'|'ai'|'notes'), pinned:Bool（模组类强制 true）, aiHash:String?, structureGen:Int, createdAt, updatedAt, deletedAt?
**User**：id, email, prefs:{ideaNudge:Bool=true}（updatePrefs 是 merge 不是替换）
**Version**：{version:Int 自增, blocksJson:String(整批未软删块 JSON), trigger, createdAt}；trigger ∈ optimize/structure/incremental/cardEdit/merge/split/delete/addModule/restore/migrate
**VersionPtr**：systemId → 指针索引

**Undo/Redo 指针法（必须照搬的细节）**：
- saveVersion：与末位快照内容相同 → 去重不落步（指针指末位）；否则砍掉指针之后的版本（清 Redo）→ append → 指针=末位
- undo：若指针在末位且当前状态≠末位快照 → 先把现状入快照（保证 redo 回得来）→ 指针-1 → 还原该快照（块以**原 id** 覆写回去，软删的复活）；越界回 nil
- redo：指针+1 还原；越界 nil
- 还原后整页重渲染；canUndo/canRedo 驱动 ↶↷ 禁用态
- 容量：web 受 localStorage 限制做了 4MB 精简（保第 1 版+最近 50）；SwiftData 无此限制 → **无限保留**（拍板语意），不实作精简
- 软删语意：删除=写 deletedAt；查询滤 deletedAt==nil；版本还原可复活

## 5. 四条 AI 操作完整时序

**chatNote(systemId, messages, handlers, signal, {kickoff})**
序列化 note（title＋blocks{type,content,pinned}）→ POST chat/note → 事件分发（delta/usage/proposal/done/error）→ done 时点 chat_note 灯＋广播。kickoff 时 messages=[]；开场白与 proposals 由呼叫端存进 nudge.opening。

**optimize(systemId,{groupTopics})**
①hash gate：shouldSkipAi → 「内容没变，未消耗 AI」零网络结束 ②diffBlocks 无 changed → 同上 ③序列化（blocks 带 changed 标记）④**saveVersion('optimize')** ⑤POST optimize 收集 card_done/card_removed 组成 patch ⑥checkOptimizePatch(mode='optimize') 拒→error code safety_valve（快照仍在）⑦applyOptimizePatch ⑧setLamp('optimize')＋广播。docState：carded 保持，否则→optimized。

**structure(systemId,{mode:'full'})**
①hash gate **仅 docState==='carded' 时生效**（首次必跑）②序列化（blocks 带 module 标注）③saveVersion('structure') ④POST structure 收集 cards（card_start 给 UI 画骨架）⑤checkStructureCards 拒→safety_valve ⑥applyStructureCards（docState→carded）⑦setLamp('structure')＋广播。

**applyEdit(systemId,{instruction})**
①instruction 空→bad_request ②**跳过 hash gate**（使用者明示）③editable=全部未钉选 DIFF_TYPES 块；序列化时这些全标 changed:true ④saveVersion('optimize') ⑤POST optimize 带 instruction ⑥patch 空→「AI 没有提出任何修改」正常结束 ⑦checkOptimizePatch(**mode='instruction'**) ⑧applyOptimizePatch(mode='instruction')（docState 不降级）⑨setLamp('dialog_edit')＋广播。

**失败共同语意**：安全阀拒绝 = 资料零变动（快照已存，使用者可 Undo 到更早）；abort = 不套用、无事件；所有 AI 操作进行中 UI 锁定编辑。
