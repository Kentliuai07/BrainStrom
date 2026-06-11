# iOS 整合需求報告（前端線回報 · 2026-06-11）

> 用途：給後端線設計前後端整合方案用。本報告**只盤點不改代碼**，誠實優先——缺就寫缺。
> 盤點對象：`ios-app/`（本分支 ios-native 的 ios-app，內容＝前端線 ios-dev 真實代碼，commit a5dacba「四畫面佈局對齊 web」）。
> 基準文檔：`docs/iOS原生版-功能对等清单.md`、`docs/iOS原生版-整合契约与算法规格.md`、`docs/iOS原生版-交接文档.md`。
> 一句話現狀：**四個畫面的「外觀與佈局」已做好（照 web 暫時前端排版、工業橘皮），但「接後端要的管線與算法」幾乎全缺**——目前是一台只有外殼、編輯功能能本地跑、但沒有任何真網路與省錢/安全算法的機器。

---

## 第 1 節 · 功能完成度對照（照《功能對等清單》14 區塊）

| # | 區塊 | 狀態 | 差什麼 |
|---|---|---|---|
| 1 | 登入頁 | 🟡 部分 | 佈局✅、dev 假登入✅（`Data/Auth/AuthServiceStub.swift:16`）；無「登入中…」轉圈外的真流程，真 Apple 登入未接 |
| 2 | 首頁 | ✅ 完成（佈局層） | 橫幅✅、卡片(私密/公開膠囊+日期+標題+摘要)✅、點卡進筆記✅、＋空標題建立進命名態✅、空清單✅、齒輪進設定✅（`Features/Home/HomeScreen.swift`）。摘要取第一塊文字 `Data/Persistence/NotesRepository.swift:54-67` |
| 3 | 筆記頁·命名態(F9) | 🟡 部分 | gate 條件✅(`Features/Note/NoteDocument.swift:50-54`)、placeholder✅、「先隨便取」✅(`NoteDocument.swift:69-74`)、命名態禁用 fab/✦/▦/💬✅。**缺**：返回時「空名+零塊→軟刪+toast」未做（`NoteScreen.swift` 返回鍵只 `dismiss()`，無清理） |
| 4 | 筆記頁·文章視圖 | 🟡 部分 | 標題編輯✅、點段落編輯✅(`NoteContentViews.swift` BlockRow)、todo/heading/段落/模組塊渲染✅、📌釘選✅、▲▼移動✅、刪除✅、續寫切塊✅、savechip✅。**缺**：「blur 有變才落版本步」是本地記憶體 undo（非 saveVersion 版本鏈）；**缺** >2000 字「建議拆分」提示；切塊 `splitIntoBlocks` 未處理 ``` 圍欄 |
| 5 | 頂欄 | 🟡 部分 | 返回✅、私密/公開切換✅、↶↷(本地記憶體 undo/redo)✅、文章\|卡片分段✅（未 carded 時卡片禁用✅）。**缺**：sessionStorage 視圖偏好持久化；undo/redo 是本地 stack 非版本指針 |
| 6 | ⚡ 點子助攻(Step3.6) | ❌ 未做 | 膠囊 UI 有（`NoteContentViews.swift` titleAux），但按下只 toast「需要真後端」；kickoff 串流、nudge 狀態機、重播、✕dismissed、設定總開關**全缺** |
| 7 | 💬 聊天面板 | 🟡 部分（純佈局） | 面板開/收✅、空態文案✅、輸入槽+送出鍵✅（`NoteScreen.swift` chatPanel）。**缺**：氣泡串流、user/ai 氣泡、token 小字、引用徽章、proposal 按鈕列、停止鍵邏輯、歷史——送出只 toast |
| 8 | ✦ 優化 | ❌ 未做 | dock 有 ✦ 鍵，按下 toast「需要真後端」；確認框、進行中鎖定、三種結果 toast、hash gate、安全閥**全缺** |
| 9 | ▦ 結構化 | ❌ 未做 | dock 有 ▦ 鍵，按下 toast；自動切卡片視圖、骨架卡、card_start/done 串流**全缺**（Stub 有演出但無 UI 消費） |
| 10 | 卡片視圖 | 🟡 部分 | 視圖框架✅、未結構化空態+「▦結構化」鈕✅（`NoteContentViews.swift` CardsView）。**缺**：卡片就地編輯、卡片釘選/刪除、結構化後零卡第二空態 |
| 11 | 設定頁 | 🟡 部分 | 主題切換(3款機殼)✅、email 顯示✅、登出✅、刪除帳號確認框✅、點子助攻開關✅（`Features/Settings/SettingsScreen.swift`）。**缺**：開關只 toast 無 updatePrefs；刪帳號走 signOut 非真刪資料；無 Apple 重新驗證 |
| 12 | 驗收燈(14盞) | ❌ 未做 | 無驗收頁、無 setLamp 機制；`health()` 已實作（`AIServiceLive.swift:12`）但從未被呼叫 |
| 13 | 全局行為 | 🟡 部分 | 離線橫條✅(`DesignSystem/Components/Feedback.swift` OfflineBar + `App/RootView.swift` NWPathMonitor)、toast 1.3s✅(`Feedback.swift` ToastModel)。**缺**：視圖偏好持久化、離開頁面 abort 串流（無串流可 abort） |
| 14 | mock vs real | 🟡 部分 | Stub/Live 雙實作齊（`Data/AI/`）。**缺**：CompositionRoot 預設走 Stub，且非 real 時不是「toast 擋下」而是「默默給假資料」——與 web 行為相反 |

**小計**：✅ 1（首頁佈局）／🟡 8（多為佈局到位、邏輯缺）／❌ 4（三條 AI 流＋驗收燈）。**整體完成度（以整合就緒度計）約 35%**：外觀/本地編輯到位，接後端的管線與算法基本是空的。

---

## 第 2 節 · 服務層現狀

| 協議 | 檔案 | 方法 | 實作 |
|---|---|---|---|
| `AIServicing` | `Domain/Services/AIServicing.swift:77` | health/optimize/structure/chat/search | Live＋Stub 都有，**預設 Stub**（`App/CompositionRoot.swift:30-36`：`AIConfig.fromBundle` 且 `!useStub` 才用 Live，否則 Stub；目前 AI_USE_STUB=YES） |
| `AuthServicing` | `Domain/Services/AuthServicing.swift:14` | restoreSession/signInWithApple/signOut/deleteAccount | 只有 `AuthServiceStub`（`Data/Auth/AuthServiceStub.swift`），**無 Live**；真 Apple 登入未做 |
| `NotesRepositoring` | `Domain/Services/NotesRepositoring.swift:10` | systems/createSystem/deleteSystem/setVisibility/renameSystem/documentNote/notes/note/createNote/saveNote/deleteNote/cards/saveCards/snapshot/revisions | `NotesRepository`（SwiftData，`Data/Persistence/NotesRepository.swift`）= Live，無 Stub |

**AIServicing 方法簽名（注意與契約對不上）**：
- `func health() async -> Bool`
- `func optimize(_ payload: NotePayload, options: OptimizeOptions) -> AsyncThrowingStream<AIEvent, any Error>`
- `func structure(_ payload: NotePayload) -> AsyncThrowingStream<AIEvent, any Error>`
- `func chat(messages: [ChatMessage], context: NotePayload?) -> AsyncThrowingStream<AIEvent, any Error>`
- `func search(query: String) -> AsyncThrowingStream<AIEvent, any Error>`

**與契約《§5 四條 AI 時序》的落差**：
- 契約要 `chatNote(... , {kickoff})`；現有 `chat` **無 kickoff 旗標**。
- 契約要 `optimize` 帶 `groupTopics` 且 blocks 帶 `changed` 標記；現有用 `OptimizeOptions{splitTopics,addHeadings,proofread}` 三開關，**無 changed、無 groupTopics**。
- 契約要 `applyEdit(instruction)`；**完全沒有此方法**（對話式編輯無入口）。
- 契約要 `structure(mode)`；現有 `structure` **無 mode 參數**。
- 契約**沒有** search 端點；現有多了 `search`（後端無對應，將 404）。

**AIServiceStub 目前回什麼假資料**（`Data/AI/AIServiceStub.swift`）：
- `health()` → 永遠 `true`（:13）
- `optimize` → 罐頭 8 段「微氣候研究」delta + progress + usage(512/256) + done（:15-26）
- `structure` → 3 張卡 cardStart→cardDone+progress、usage(820/410)、done（:28-52）
- `chat` → 罐頭 5 段觀測建議 delta（:54-62）
- `search` → 先 hitList 2 筆，再 3 段 delta（:64-85）
- 全部用 `Task.sleep` 模擬串流節奏，`onTermination` 會 `task.cancel()`

---

## 第 3 節 · 網路與 SSE 現狀

- **有沒有 APIClient/SSEClient**：無獨立 APIClient；SSE 邏輯內嵌在 `Data/AI/AIServiceLive.swift`，解析器在 `Data/AI/SSEParser.swift`。
- **網路實作**：`URLSession.shared.bytes(for:)` 逐 byte 讀（`AIServiceLive.swift:79`），遇 `\n`（0x0A）切行、去尾 `\r`（:92-108）——✅ 用的是契約建議的 bytes 逐行。
- **POST + Bearer + Accept**：✅（`AIServiceLive.swift:72-76`：`Authorization: Bearer <token>`、`Content-Type: application/json`、`Accept: text/event-stream`）。
- **SSE 逐行解析**：`SSEAccumulator.feed(line:)` 遇空行吐一則訊息（`SSEParser.swift:20-35`）——但**解析方式與契約不符（重大）**：
  - 我的解析器靠 **`event:` 行** 決定事件類型（`SSEEventMapper.map` switch `message.event`，`SSEParser.swift:44`）。
  - 契約《§2》說事件是 **`data: {JSON}`，type 在 JSON 裡的 `type` 欄位**，沒有 `event:` 行。
  - ⚠️ **結果**：真後端來的事件會全部掉進 `case nil`（無 event 行）→ 被當成 `delta`，其餘事件（usage/card/proposal/done）通通解析不到。**這條一定要修**。
- **AIEvent enum**（`AIServicing.swift:9-19`）涵蓋：delta/done/error/usage/cardStart/cardDone/cardRemoved/progress/hitList。
  - **缺 `proposal` 事件**（契約《§2》有，聊天提議按鈕列靠它）。
  - **形狀對不上**：契約 `card_start={index,title,type}`、`card_done={index,card}`、`progress={current,total,message}`、`usage` 多 `cache_read_input_tokens/model`；我的是 `cardStart(id,title)`、`cardDone(id)`（**丟了 card 內容**）、`progress(Double)`（**丟了 message**）、`usage(in,out)`。
- **AbortSignal / Task cancellation**：✅ 用 `AsyncThrowingStream` 的 `onTermination → task.cancel()`（`AIServiceLive.swift:117-119`），迴圈內檢查 `Task.isCancelled`（:93）；`CancellationError` 靜默結束（:111）。
- **目前有沒有任何真網路呼叫**：❌ **沒有**。Live 程式碼寫好了，但①預設走 Stub ②**沒有任何畫面/ViewModel 呼叫過 optimize/structure/chat/search**（`NoteScreen.swift` 的 ✦/▦/💬 都只 `root.toast.show("需要真後端")`）③`health()` 也沒被呼叫。

---

## 第 4 節 · 資料層現狀（對照《整合契約 §4》）

SwiftData 實體在 `Data/Persistence/PersistentModels.swift`，領域模型在 `Domain/Models/DomainModels.swift`。

**System**（契約要的欄位 → 現狀）：
| 契約欄位 | 現狀 |
|---|---|
| id | ✅ `SystemEntity.id` |
| ownerId | ❌ 缺（資料不綁使用者） |
| title | ✅ `name`（命名不同） |
| visibility | ✅ `visibilityRaw:String?`（今天加，optional） |
| version | ❌ 缺 |
| tags[] | ❌ 缺 |
| lastAiHash | ❌ 缺 |
| docState | ✅ 在 `NoteEntity.docStateRaw`（掛在 note 不在 system） |
| ai_restructure_count | ❌ 缺 |
| structuredAt | ❌ 缺 |
| nudge | ❌ 缺（整個 Nudge 物件不存在） |
| createdAt/updatedAt | ✅ |
| deletedAt | ❌ 缺（無軟刪） |

**Block**（`DomainModels.swift:89` + `PersistentModels`，blocks 以 JSON 內嵌在 `NoteEntity.blocksData`）：
| 契約欄位 | 現狀 |
|---|---|
| id/type/position | ✅ `id`/`kind`/`orderIndex` |
| payload | ✅ `text`+`isDone`+`moduleKind`+`modulePayload`（攤平，非 JSON payload 物件） |
| source(manual/ai/notes) | ❌ 缺 |
| pinned | 🟡 型別不同：今天加了 `isPinned:Bool`（`DomainModels.swift`），但另有殘留的 `BlockKind.pinned` enum case 未清；且 `NotePayload.init` 仍用 `kind == .pinned` 判斷（`AIServicing.swift:59`）→ **與 isPinned 不一致，是個 bug** |
| aiHash | ❌ 缺 |
| structureGen | ❌ 缺 |
| deletedAt | ❌ 缺 |

**User.prefs**：❌ 缺。`UserAccount` 只有 `userID`、`email:String?`（`AuthServicing.swift:8`），無 `prefs.ideaNudge`。

**Version + 指針**：🟡 有 `RevisionEntity` 但**型別不符**——只存 metadata（`kindRaw/charDelta/cardCount`），**沒有 `blocksJson`（快照內容）**，所以資料層根本還原不回去；無 `VersionPtr` 指針表。目前 undo/redo 是 `NoteDocument` 裡的**記憶體 stack**（`Features/Note/NoteDocument.swift:32-34`），App 關掉就沒了，且不是契約要的「指針法+軟刪復活」。

**軟刪語意**：❌ 缺（`deleteNote`/`saveCards` 都是 `context.delete` 硬刪）。
**splitIntoBlocks**：🟡 有（`NoteDocument.swift:166-181`），連續空行分段、`# / ##` 成標題——但**未處理 ``` 圍欄不切**（契約《§3.13》要）。

---

## 第 5 節 · 算法移植現狀（對照《整合契約 §3》13 函式）

| # | 函式 | 狀態 |
|---|---|---|
| 1 | normalizeText | ❌ 缺 |
| 2 | fnv1a / fnvHash | ❌ 缺 |
| 3 | blockContent | ❌ 缺 |
| 4 | fullHash | ❌ 缺 |
| 5 | shouldSkipAi（hash gate 省錢） | ❌ 缺 |
| 6 | nudgeHash | ❌ 缺 |
| 7 | diffBlocks | ❌ 缺 |
| 8 | checkOptimizePatch（安全閥） | ❌ 缺 |
| 9 | checkStructureCards | ❌ 缺 |
| 10 | computeStructuredBlocks | ❌ 缺 |
| 11 | applyOptimizePatch | ❌ 缺 |
| 12 | applyStructureCards | ❌ 缺 |
| 13 | splitIntoBlocks | ⚠️ 有但有差：`NoteDocument.swift:166-181`，**未處理 ``` 圍欄整段不切**（其餘空行分段、`#`→level1/`##`→level2 行為相符） |

**fnv1a 用 UTF-16 碼元還是 UTF-8 bytes？** → **目前缺，尚未實作。** 將來移植時**必須用 UTF-16 碼元（對齊 web 的 `charCodeAt`）**，不能用 UTF-8 bytes，否則兩端指紋不一致會出現「iOS 扣錢、網頁不扣」級別的分歧。建議 Swift 用 `s.utf16` 逐 `UInt16` 餵入 `h ^= c; h = h &* 0x01000193`（32-bit wrap）。

**單元測試**：❌ **零**。整個 `ios-app/` 找不到任何 test target / 測試檔。契約要求 hash/diff/安全閥各至少 3 例、SSE fixture 測試——全缺。

---

## 第 6 節 · 四條 AI 流的接線點

格式：按鈕 → ViewModel 方法 → Service 方法｜Stub 行為｜進行中鎖定/錯誤顯示

| 流 | 接線現狀 |
|---|---|
| **chatNote(含 kickoff)** | 按鈕：`NoteScreen.swift` dock 💬（開面板）、聊天「送出」鍵、titleAux 的 ⚡ 膠囊。**ViewModel：無**（無 ChatViewModel）。**Service：未呼叫**——送出與 ⚡ 都只 `root.toast.show("需要真後端")`。kickoff 完全沒有。進行中鎖定/錯誤：無。 |
| **optimize** | 按鈕：dock `✦`（`NoteScreen.swift` dockKey）。→ `aiNeedsBackend()` → toast。**未接** `AIServicing.optimize`。確認框、進行中遮罩、結果 toast：無。 |
| **structure** | 按鈕：dock `▦` 與卡片空態「▦ 卡片結構化」（`NoteContentViews.swift` CardsView）。→ toast。**未接** `AIServicing.structure`。骨架卡/逐卡浮現：無。 |
| **applyEdit** | **無任何入口**——協議沒這方法，聊天也沒有 proposal 按鈕列。 |

**共通**：目前**沒有任何「進行中鎖定編輯區」的 UI**（契約要的半透明遮罩+進度條+鎖 ✦▦💬fab↶↷），也**沒有錯誤分類顯示**（safety_valve/need_real_backend/rate_limited 都沒對應 UI）；唯一回饋是通用 toast。

---

## 第 7 節 · Config 與密鑰

- **Config.xcconfig**：✅ 存在（`ios-app/Config/Config.xcconfig`），**已 gitignore、未被追蹤**（本分支 `git ls-files` 確認無此檔）。
- **Config.example.xcconfig**：✅ 存在（占位值 `REPLACE_ME`）。
- **讀取鏈**：`Config.xcconfig` → `Shared.xcconfig` `#include?` → 注入 Info.plist 鍵（`AIBaseURL`/`AIAuthToken`/`AIUseStub`）→ `AIConfig.fromBundle()`（`Data/AI/AIConfig.swift:15-26`）讀 `Bundle.main.object(forInfoDictionaryKey:)`，且 token==`REPLACE_ME` 或空 → 回 nil → 退回 Stub。
- **AI_BASE_URL / AI_AUTH_TOKEN 怎麼進 App**：xcconfig → Info.plist → Bundle → AIConfig，App 內零金鑰字面值。
- **確認沒有 token 進 git**：✅ 本機 Config.xcconfig 含真 token 但未被追蹤；example 是占位值；程式碼無硬編 token。Anthropic 金鑰只在 Fly。
- **目前狀態**：`AI_USE_STUB=YES`，所以即使 token 已填，CompositionRoot 仍組 Stub（要接真後端時改 NO）。

---

## 第 8 節 · 與規格的已知偏離（自行決定過的）

1. **「system = 一份活文件」模型**：對齊 web，把「系統」直接當成一份筆記（一個 system 一份 note），**沒有「系統內多篇筆記」中間層**。理由：web 暫時前端就是這結構，前一個任務要求佈局 100% 對齊 web。（`NotesRepository.documentNote(for:)`）
2. **佈局照 web 暫時前端，而非《交接文檔 §1》的「全新工業風設計授權」**：交接文檔本意是「視覺全新自由設計、只要行為對等」；但前一任務使用者明確要「佈局跟 web 100% 一樣、橘工業皮不變」，所以四畫面是 web 排版 + 工業橘皮。**需後端線/使用者確認這條方向是否維持**。
3. **OptimizeOptions 用三開關**（splitTopics/addHeadings/proofread）而非契約的單一 `groupTopics` 布林。理由：早期照舊設計稿「分主題/加小標/修錯字」三開關。**接後端時要改回 groupTopics**（且後端無 proofread 參數）。
4. **chat 端點路徑 `ai/chat`**（`AIServiceLive.swift:52`）而非契約的 `ai/chat/note`；且多了後端不存在的 `ai/search`。
5. **pinned 雙軌**：今天加 `Block.isPinned:Bool`，但 `BlockKind.pinned` 舊 case 與 `NotePayload.init` 的 `kind == .pinned` 判斷未清，兩者不一致。
6. **undo/redo 是記憶體 stack** 非契約的版本指針法+軟刪；RevisionEntity 不存快照內容。
7. **RootView 加了 DEBUG-only 啟動參數預覽路由**（`-previewScreen note|settings|login`），Release 不編入，僅為無 tap 自動化時的視覺驗收。
8. **可見性欄位**用 `visibilityRaw:String?`（optional）以支援既有 DB 輕量遷移。

---

## 第 9 節 · 整合風險（我評估最可能出事的點）

1. **SSE 解析方式錯（最高風險）**：解析器讀 `event:` 行，真後端把 `type` 放 `data:` JSON 裡 → 接上去會「只收到 delta、其他事件全丟」，聊天能跑但優化/結構化/proposal 全壞。**接線第一件事就要改 `SSEEventMapper` 改讀 JSON 的 `type`。**
2. **指紋不一致（扣錢分歧）**：fnv1a 還沒寫，將來若用 UTF-8 bytes 而非 UTF-16 碼元，hash gate / diff 兩端對不上 → 「iOS 重複叫 AI 扣錢、網頁不叫」。
3. **安全閥整套缺**：checkOptimizePatch/checkStructureCards 沒移植 → AI 亂改、偷刪、改太多時前端無法擋，會直接污染使用者資料（契約強調「程式判定、不信 AI」）。
4. **版本層救不回**：RevisionEntity 不存 blocksJson、無指針、無軟刪 → 一旦套用 AI 結果，使用者按 ↶ 救不回原文（目前記憶體 undo App 重啟即失效）。
5. **事件 payload 形狀不符**：cardDone 丟了 card 內容、progress 丟了 message → 接真後端後「卡片填不進內容、引用徽章/skip 文案無資料顯示」。

---

## 第 10 節 · 需要後端線回答的問題

1. SSE 事件到底是 `event: <type>\n data: {json}` 還是 `data: {"type":...,...}`？（決定解析器怎麼改——契約寫 type 在 JSON 裡，請確認 server 實際輸出格式。）
2. `card_done` 的 `card` 物件，optimize 與 structure 兩種形狀，前端要原樣存進哪個欄位？（我這邊 Block.payload 是攤平的，要不要改成存 JSON payload？）
3. `usage` 的 `cache_read_input_tokens` 前端要不要顯示？還是只顯示 in/out？
4. 聊天端點確認是 `/ai/chat/note`（不是 `/ai/chat`）？kickoff 是 body 的 `kickoff:bool` 對嗎？
5. 後端有沒有 `/ai/search`？（清單沒列，但我目前協議有 search，要砍掉還是後端會加？）
6. optimize 的 `proofread` 後端不吃，那 iOS 的「修錯字」開關是直接拿掉，還是塞進 instruction？
7. 設計方向最終拍板：iOS 是維持「佈局照 web」還是回到《交接文檔》的「全新工業風自由設計」？（影響要不要重排版。）
8. token 限流 429 與 payload >100KB 的 400，前端要顯示什麼文案？有沒有統一文案表？

---

**白話總結**：外殼跟本地編輯做好了，但「接後端要的東西」幾乎全沒做——真網路沒接、13 個算法只做了半個切塊、SSE 解析方式還接錯（讀錯欄位）、版本救不回、安全閥沒有。最該先修的是 SSE 解析（不然接上只收得到聊天文字）和指紋算法（不然會亂扣錢）。完成度以「整合就緒」算約 35%。
