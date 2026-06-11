# BrainStrom iOS 正式前端 · 設計與工程規格書 v1

> 本文件是 iOS 正式前端（SwiftUI / `ios-app/`）的**唯一設計與工程依據**，與三份凍結契約搭配使用：
> `web/src/touchpoints.js`（API 觸點表）、`docs/阶段二开发文档-变聪明-AI功能.md`（§2.1 SSE 協議、§3 服務層簽名、§1.2/§1.2b 活文件模型、附錄 F）、`docs/ios-structure.md`。
> 衝突裁決順序：本文件（視覺與工程）→ 阶段二文档（行為與協議）→ touchpoints.js（API）。
> 範圍拍板（2026-06-11 使用者）：**iPhone 直式優先；繁體中文優先；不實作付費牆；後端接真 API（Fly.io），不做模擬引擎**。

---

## 1. 設計原則與品牌語言

1. **內容即介面**：筆記內容是主角，chrome（工具列、按鈕）退居材質層；非內容元素一律使用半透明材質與模糊，不與內容搶對比。
2. **缺角卡片是品牌簽名**：所有卡片/面板右上角 45° 切角 12pt（自訂 `NotchedRectangle` Shape），全 App 唯一卡片語言。
3. **高質感 = 材質 + 物理動效 + 觸覺**：模糊用系統 Material（`.ultraThinMaterial`/`.regularMaterial`），動效一律 spring 物理曲線，關鍵操作配 Haptics；禁止線性 ease 與突兀淡入。
4. **單手可達**：高頻操作（模組直條、AI 按鈕、聊天）集中於螢幕右緣與下半部拇指熱區。
5. **永不丟字**：任何編輯操作即時持久化（SwiftData），AI 操作前自動快照，Undo/Redo 無限。

## 2. 設計 Tokens（Asset Catalog + `DesignSystem/Tokens.swift` 單一來源）

- **主題**（兩套完整，即時切換、可跟隨系統）：
  - 黑曜石 Obsidian（深）：`bg #0B0C0E`、`surface #141619`、`card #1A1D21`、`textPrimary #F2F3F5`、`textSecondary #9BA1A8`、`accent 金 #D4A553`、`danger #E5544B`、`pin #D4A553`。
  - 親和 Approach（淺）：`bg #F7F6F3`、`surface #FFFFFF`、`card #FFFFFF`、`textPrimary #1B1D20`、`textSecondary #6E747C`、`accent 藍 #3D6BE5`、`danger #D5443C`、`pin #3D6BE5`。
  - 全部以語義色命名進 Asset Catalog；元件禁止硬編碼色值。
- **字級階梯**（全支援 Dynamic Type，基準 Large）：LargeTitle 32/SF Pro Rounded Semibold（頁標）、Title 22（卡標）、Body 17/行高 1.4（內文）、Callout 15（次要）、Caption 12（徽章/時間）。
- **間距階梯**：4 / 8 / 12 / 16 / 24 / 32；頁面左右安全邊距 20。
- **圓角**：卡 16（含缺角）、按鈕 12、輸入框 10、膠囊 999。
- **層級（elevation）**：卡片無陰影靠色差分層；浮層（直條展開、聊天面板）用 Material + 邊緣 0.5pt 描邊（白 8% / 黑 6%）。
- **動效**：標準 `spring(response: 0.35, dampingFraction: 0.85)`；浮層進出 `response 0.4`；列表進場 stagger 40ms；串流文字直接追加不加動畫；`Reduce Motion` 開啟時全部降級為 0.15s 淡入淡出。
- **觸覺**：開啟直條 `.impact(.light)`；插入模組/送出 AI `.impact(.medium)`；安全閥拒絕/錯誤 `.notification(.error)`；Undo/Redo `.selection`。
- **四態鐵律**：每個畫面與每個非同步區塊必須實作 載入中（skeleton）/ 空狀態（插畫+引導 CTA）/ 錯誤（行內訊息+重試）/ 正常 四態。

## 3. 資訊架構與導航

```
RootView（依登入態分流）
├─ P0 登入
└─ NavigationStack
   ├─ P1 首頁（系統清單 + 全局 AI 搜索欄）
   │   └─ P2 筆記頁（文章視圖 ⇄ 卡片視圖）
   │       ├─ 模組直條（右緣浮層）
   │       ├─ AI 聊天面板（底部浮層）
   │       └─ 版本歷史（sheet）
   └─ P3 設定（sheet 或 push）
```

## 4. 畫面規格

### P0 登入頁
- 佈局：垂直三段——上 38% 品牌字標（LargeTitle + accent 句點符號）與標語「亂寫，AI 來整理。」；中段 Sign in with Apple 原生按鈕（54pt 高、全寬-40）；底部 Caption 隱私說明「收集 email 供登入、儲存你的筆記」＋隱私政策連結。
- 行為：已有有效憑證直接跳過；登入失敗行內紅字＋可重試；登入中按鈕轉 spinner。

### P1 首頁 · 我的系統
- **頂區**：問候語（Title，「早安」依時段）＋右上頭像鈕（進 P3）。
- **全局 AI 搜索欄**（Step 6 入口）：玻璃膠囊（Material+描邊），placeholder「我那個關於…的點子在哪？」；聚焦後全屏接管成搜索態：上方輸入、下方命中清單（系統卡縮неб版：標題+命中片段高亮+相似度 Caption），點擊跳轉該筆記；底部「問全局 AI」展開對話。後端未通時顯示「即將推出」殼（欄位可見、點擊出 Toast）。
- **系統清單**：缺角卡（標題 Title、私密/公開徽章、更新時間 Caption、摘要兩行 Body、標籤膠囊橫滾）；游標分頁無限滾動；下拉刷新；左滑刪除（二次確認）。
- **新建**：右下 56pt 浮動「＋」（accent 圓鈕，缺角方形變體）→ push P2 進入**命名態**（見 P2）。返回時空名＋零內容的筆記靜默丟棄，清單不留空殼。
- 空狀態：插畫＋「建立第一個系統」按鈕。

### P2 筆記頁（核心畫面）

**頂欄**（高 52，Material 背景，滾動時加 0.5pt 分隔線）：
- 左：‹ 返回；中：可編輯標題（點擊就地編輯）；右：可見性切換（鎖/地球 icon）、↶ ↷（無步可退 40% 透明禁用）、⋯ 溢出選單（版本歷史、刪除筆記）。

**命名態（名稱先行機制，Step 3.6）**：新建進入時名稱欄自動聚焦、鍵盤升起（placeholder「先給這個點子取個名字」，旁有「先隨便取」小字鈕一鍵填占位名）；名稱空白期間：正文區灰階＋提示「先給這個點子取個名字，就能開始寫」、模組直條把手與全部 AI 鈕 40% 透明禁用。名稱提交（return）→ 解鎖正文＋浮現助攻膠囊。

**點子助攻膠囊（NudgeCapsule，Step 3.6）**：標題正下方**行內** Material 膠囊（隨內容滾動，不進浮層、不與直條/聊天鈕搶位）：「⚡ 讓 AI 教練看看這個點子」＋尾部 ✕。名稱一填好即出現（零成本）；按下 → 收起並打開聊天面板走教練開場（kickoff）；✕ 劃掉 → 淡出且該筆記永不再自動出現；ChatPanel 頭部常駐 ⚡ 小鈕作手動入口（同內容重按零成本重播上次點評）。設定頁有總開關。

**視圖切換**：頂欄下方分段控制「文章 | 卡片」（膠囊滑塊動畫）；`docState ≠ carded` 時卡片段禁用，點擊出說明氣泡「先按 ▦ 卡片結構化」。

**文章視圖（活文件編輯器，行為細則以阶段二文档 §1.2b 為準）**：
- 段落塊：Body 17 行高 1.4；點擊任一段就地切換 `TextEditor`（聚焦、游標進入、背景升 `surface` 色、四角微光描邊），失焦自動保存（有變才落一步）；段落 hover/長按浮出行內工具：📌 釘選、▲▼ 移動、刪除。
- 標題塊：level 1 = Title Semibold、level 2 = Callout Semibold accent；同樣就地編輯。
- 待辦塊：圓框勾選（勾選動畫 + selection haptic）。
- 模組塊：嵌入式專屬組件（§5），文字不可編輯、恆釘選（不顯示釘選開關）。
- 釘選態：段落左側 2pt accent 豎線 + 右上 📌 角標。
- 文末常駐「繼續寫…」輸入區（placeholder 灰、聚焦升起），提交按空行自動切段。
- 超 2000 字段落：編輯態頂部黃色細條提示「建議拆分」。

**模組直條（★本次設計主角；取代雛形的左輪旋鈕）**：
- **常駐態**：右緣垂直把手——寬 24pt、高 96pt、貼右緣垂直置中偏下，Material 膠囊露出一半，內有 ✦ 圖標微光呼吸（4s 週期，Reduce Motion 時停止）。
- **喚出**：輕點把手或從右緣向左輕掃 →
  1. 全屏 **backdrop 模糊層**（`.ultraThinMaterial` + 黑 20% 調光，0.25s 淡入）接管背景，內容退為朦朧底紋——這就是「按下去其他地方模糊化」的高質感來源；
  2. 直條以 spring 從右緣滑入：寬 72pt、高度依內容自適（最大 70% 螢幕高）、Material 面板 + 左緣 0.5pt 描邊 + 缺角（左上）。
- **直條內容（由上而下，純圖標+8pt 下方 Caption 標籤，無卡片容器）**：
  1. **AI 主按鈕區**（固定，accent 色、52pt）：✦ 優化文字、▦ 卡片結構化——權重最高，placed 頂部（主腦拍板：與模組同住直條、以分隔線與色彩區隔，單一控制面收攏全部「對筆記動手」的操作）；
  2. 分隔線（8% 白/6% 黑）；
  3. **模組按鈕區**（44pt、竖排、超出可內滾）：表格、GitHub、進度環、待辦、標題、連結卡（Step 8，先上鎖樣式）…；AI 未解鎖的模組顯示鎖角標；
  4. 底部 ✕ 關閉。
- **行為**：輕點模組 → 在當前游標/文末插入該模組卡 → medium haptic → 直條收回、模糊退場；長按任一鈕 → 浮出說明氣泡（名稱+一句白話用途）；點模糊區或右掃 → 取消收回。
- **無障礙**：直條同時提供 VoiceOver rotor 清單；所有鈕 44pt 命中區與 `accessibilityLabel`。

**AI 交互（接真後端；時序）**：
- **✦ 優化文字**：點擊 → 置中確認框（Material 卡，缺角）「要不要順便分主題、加小標題？」〔要〕〔不要〕→ 編輯器鎖定 + 頂部細進度條 + 變動段落逐段原位刷新（舊字淡出新字淡入）→ 完成 Toast「已優化 N 段」；內容無變 → Toast「內容沒變，未消耗 AI」；安全閥拒絕 → error haptic + Toast「變動過大，已保留原內容」。
- **▦ 卡片結構化**：點擊 → 自動切到卡片視圖 → 卡片隨 `card_start/card_done` 事件逐張浮現（spring 上滑入場）；增量模式下：更新卡原位刷新、刪除卡淡出（`card_removed`）、釘選卡靜止不動；跳過 AI 時 Toast「內容沒變，未消耗 AI」。
- **💬 單筆記聊天**：右下浮鈕 → 底部面板（初始 50% 高、可拖至 90%、可收合；Material）：氣泡列表（user 右 accent / ai 左 surface）、逐字串流、氣泡下 Caption「tokens: in X / out Y」、命中時「引用到 M 張卡」徽章、串流中「停止」鈕（abort）、錯誤行內紅字。歷史本機保留於該筆記（SwiftData）。
- **版本歷史**：sheet 時間軸列表（每行：觸發徽章〔優化/結構化/手改/還原〕+ 時間 + 摘要字數變化）→ 點入唯讀預覽 → 「還原到此版」（destructive 確認；還原本身可再 Undo）。

### P2-b 卡片視圖
- 單欄卡片流（iPhone）；通用卡 = 缺角卡（卡標 Title + 內容 Body，點擊就地編輯）；模組卡用 §5 專屬組件；卡右上 📌 / ⋯（刪除）；長按拖曳排序（drop 落點高亮）。
- 空狀態（未結構化）：置中插畫 + 「還沒結構化——按 ▦ 讓 AI 把筆記變成卡片」+ 直接放一顆 ▦ 按鈕。

### P3 設定
- 分組 List：帳號（email、登出）/ 外觀（主題：黑曜石・親和・跟隨系統，即時預覽）/ **AI（「點子助攻」Toggle，Step 3.6 總開關）** / 關於（版本、隱私政策）/ 危險區（刪除帳號：紅字 → 確認彈窗「資料將立即永久刪除、無法復原」→ 重新 Apple 驗證 → 執行）。

### 付費牆
- **本期不實作**。資料模型保留 `membership` 旗標位；PRO 模組在直條中以鎖角標呈現即可。

## 5. 組件庫（`DesignSystem/Components/`）

| 組件 | 規格要點 |
|---|---|
| NotchedCard | 缺角 Shape、surface/card 雙態、可選描邊 |
| ModuleRail | §4 直條全套（把手/模糊層/面板/haptics） |
| TableBlockView | 緊湊表格：表頭 Caption Semibold、斑馬列、橫向可滾 |
| GitHubBlockView | repo 列：名稱+⭐星數+一句描述；點擊外開 |
| ProgressRingView | 環形百分比（accent 漸層描邊、中心大數字）+ buildSteps 勾選清單 +「粗略估計」Caption |
| ChatPanel | 底部可拖浮層、氣泡、串流游標（▍閃爍）、token Caption、AI 氣泡下方**提議按鈕列**（橫滾膠囊，🔒項帶「即將推出」角標）、頭部 ⚡ 助攻小鈕 |
| NudgeCapsule | 點子助攻行內膠囊：⚡ 文案＋✕，spring 入場、劃掉淡出（Step 3.6） |
| ConfirmDialog | 置中缺角 Material 卡、主次按鈕 |
| Toast | 頂部下落膠囊、2.5s 自動退場、可帶 icon |
| VersionTimeline | 時間軸 sheet、觸發徽章色票 |
| EmptyState / Skeleton / ErrorRetry | 四態統一組件 |

## 6. 三階段功能覆蓋矩陣（前端側全清單）

| Step | 功能 | 前端落點 | 本期 |
|---|---|---|---|
| 1 | 登入/刪帳號 | P0、P3 | ✅ |
| 2 | 自由速記（活文件編輯器） | P2 文章視圖全套 | ✅ |
| 3 | 優化文字＋卡片結構化 | 直條 AI 區＋串流呈現＋確認框 | ✅（接真 API） |
| 4 | 加模組 | 模組直條 | ✅ |
| 5 | 增量結構化 | 同 Step 3 按鈕；釘選/原位刷新/淡出/省錢 Toast | ✅ |
| 6 | 全局找回 | P1 搜索欄＋命中清單＋全局聊天 | ✅（後端通後啟用） |
| 7 | GitHub 進度 | ProgressRing 模組卡＋綁 repo 流程 | ✅（後端通後啟用） |
| 8 | 媒體連結卡 | 連結卡組件（先上鎖樣式） | 殼 |
| 9 | 付費/公開私密 | 可見性切換 ✅；付費牆 ❌ 不做 |
| 10 | 市集 | 不設計（v2） |

## 7. 工程規格（資料夾結構・抽象層・編譯規範）

**資料夾結構（`ios-app/BrainStrom/`，Feature-first）**：

```
App/                BrainStromApp.swift、CompositionRoot.swift（DI 組合根）、AppRouter.swift
Features/
  Auth/             AuthView.swift + AuthViewModel.swift
  Home/             HomeView、HomeViewModel、SystemCardView
  Note/             NoteView、NoteViewModel、ArticleEditor/（段落編輯器）、CardGrid/、
                    ModuleRail/、ChatPanel/、VersionHistory/
  Settings/
  GlobalSearch/
Core/
  Models/           SystemEntity、BlockEntity、StructureVersion（@Model，欄位鏡像契約：
                    source/pinned/aiHash/structureGen/lastAiHash/docState/ai_restructure_count）
  Services/         協議：AuthServicing、SystemsServicing、BlocksServicing、AIServicing、
                    VersionServicing ＋ 各 Live 實作（簽名逐條對應 touchpoints.js）
  Networking/       APIClient（URLSession）、SSEClient（bytes(for:) 逐行解析 data: 事件）、
                    Endpoints.swift（路徑常量對應觸點表）
  Persistence/      SwiftData container、遷移、快照存取
  DesignSystem/     Tokens.swift、Theme.swift、Components/
Shared/             Extensions、Haptics.swift、Logger.swift
Resources/          Assets.xcassets（語義色雙主題）、Localizable.xcstrings（zh-Hant 基準）
Tests/              ServiceTests（含 SSE 解析 fixture）、SnapshotTests（關鍵畫面雙主題）
```

**抽象層鐵則**：View → ViewModel（`@Observable`、@MainActor）→ Service 協議 → Live/Stub 實作。View 禁止 import Networking；Service 注入一律走 CompositionRoot（環境注入），零全域單例。AI 串流以 `AsyncThrowingStream<AIEvent, Error>` 暴露（AIEvent enum 鏡像 §2.1 SSE 事件）。

**編譯與品質規範**：Swift 6 嚴格並發（complete concurrency checking）；warnings as errors；SwiftLint（附 `.swiftlint.yml`：force_unwrap 禁、檔長 ≤400、函式 ≤60 行）；SwiftFormat 統一風格；最低部署 iOS 17；分支 `ios-dev`、conventional commits；每畫面附 #Preview（雙主題）。

**後端整合**：`Config.xcconfig` 存 `AI_BASE_URL` 與 `AI_AUTH_TOKEN`（**不進 git**，附 `Config.example.xcconfig`）；後端 URL 由後端線提供後填入；未提供前 AIServicing 用 Stub 實作（回固定串流樣本，UI 全流程可跑）。金鑰永不出現在程式碼與 repo。

## 8. 性能與重量預算（重量控制）

- 安裝包 ≤ 15MB（無第三方依賴原則：UI/網路/持久化全用系統框架；引入任何 SPM 套件需書面理由）。
- 冷啟動 → 首頁可互動 p90 ≤ 400ms；筆記開啟 ≤ 200ms。
- 滾動 60fps（ProMotion 120fps）零掉幀：清單用 LazyVStack、卡片陰影禁用改色差、模糊層只在直條/浮層出現時掛載。
- 記憶體穩態 ≤ 150MB；串流期間零累積（delta 追加用 ContiguousArray 緩衝）。
- 主執行緒零磁碟 IO；SwiftData 寫入走背景 context。
- 能耗：串流時不升高定位/感測；閒置 30s 後暫停呼吸動畫。

## 9. 本地化・無障礙・隱私

- 文案全部進 String Catalog，**zh-Hant 為基準語系**；禁止硬編碼字串；日期用系統格式化。
- VoiceOver：全互動元素有 label/hint/value；直條提供線性替代導航；Dynamic Type 到 XXL 不破版；對比 ≥4.5:1（雙主題皆驗）。
- 隱私：無追蹤、無第三方 SDK；ITSAppUsesNonExemptEncryption = false。

## 10. 驗收清單（每畫面做完逐條打勾）

- [ ] 四態齊全（載入/空/錯誤/正常）
- [ ] 雙主題截圖對比皆過（色彩語義、對比度）
- [ ] Dynamic Type XXL 不破版
- [ ] VoiceOver 走查通過
- [ ] 動效在 Reduce Motion 下降級
- [ ] 性能預算抽測（Instruments：啟動、滾動、記憶體）
- [ ] 服務層簽名與 touchpoints.js 逐條對應、零 View 直連網路
- [ ] SwiftLint 零 warning
