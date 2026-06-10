# BrainStrom · iOS 資料夾結構 + 前端拆分

> 來源：掃描 `mvp/brainstorm-mvp.html`（8 個探勘代理）。這份把那一坨單檔 HTML，拆成一個正規的 SwiftUI App 該長的樣子。

## 一、整個 App 的畫面地圖（先看懂結構）

```
App
├─ Home（首頁，有兩個分頁）
│   ├─ 我的系統  → 我自己的筆記清單（每張 = 一個待開發系統）
│   │   └─ 全局 AI 卡片（讀我全部筆記，給跨筆記建議）
│   └─ 探索公開  → 別人公開的系統（可 Remix / 購買）
│
└─ Note（單一筆記頁，有兩個模式，可切換）
    ├─ 自由速記  → 想到什麼寫什麼（像 Apple Notes）
    ├─ AI 結構化 → 一鍵把上面整理成固定格式的 ~20 張卡
    ├─ 左下角旋鈕 → 撥一撥選模組、點中心插入
    └─ 浮層：AI 對話 / 付費牆 / Toast / 錄音
```

關鍵狀態（全 App 就靠這幾個開關在動）：
- `mode` = `free` / `structured`（筆記是「速記」還是「結構化」）
- `vis` = `private` / `public`（私密 / 公開）
- `member` = 是不是 PRO 會員
- `theme` = `obsidian`（黑曜石/深色）/ `approach`（親和/淺色）

## 二、SwiftUI 資料夾結構（建議）

```
BrainStrom/
├─ App/
│   ├─ BrainStromApp.swift          // App 入口
│   └─ AppRouter.swift              // 管畫面切換（Home/Note/浮層）+ 全域狀態
│
├─ DesignSystem/                    // 設計系統（顏色/字/間距/特效）
│   ├─ Theme.swift                  // 兩套主題 obsidian / approach 的色票
│   ├─ Tokens.swift                 // 圓角、間距、陰影、毛玻璃
│   ├─ Typography.swift             // Inter / Space Grotesk / JetBrains Mono / Noto Sans TC
│   ├─ Effects/                     // 發光 glow、掃描線 scan、缺角 notch shape
│   └─ Components/                  // 共用小元件
│       ├─ BSCard.swift             // 缺角卡片（.card/.ncard/.excard 共用底）
│       ├─ IconBadge.swift          // 帶圖示的小方塊（.ch-ic/.repo-ic…）
│       ├─ Chip.swift               // 標籤膠囊（.chip/.stag）
│       ├─ SegmentedControl.swift   // 自由速記 / AI 結構化 切換
│       ├─ VisibilityPill.swift     // 私密/公開
│       ├─ Toast.swift
│       └─ ProGate.swift            // PRO 模糊鎖
│
├─ Features/
│   ├─ Home/
│   │   ├─ HomeView.swift           // 兩個分頁的殼
│   │   ├─ MySystemsView.swift      // 我的系統清單
│   │   ├─ ExploreView.swift        // 探索公開
│   │   ├─ SystemCard.swift         // .ncard
│   │   ├─ ExploreCard.swift        // .excard
│   │   └─ GlobalAIOverviewCard.swift // .aiov 全局 AI 卡
│   │
│   ├─ Note/
│   │   ├─ NoteView.swift           // 筆記殼（導覽列+切換+底部 dock）
│   │   ├─ FreeNoteView.swift       // 自由速記
│   │   ├─ StructuredNoteView.swift // AI 結構化（排 ~20 張卡）
│   │   ├─ Blocks/                  // 每一種模組 = 一個檔（見下表）
│   │   ├─ ModuleDial/              // 左下角旋鈕
│   │   │   ├─ ModuleDialView.swift
│   │   │   └─ DialController.swift // 旋轉/吸附/選中邏輯（取代 GSAP）
│   │   └─ VoiceRecorder.swift      // 長按麥克風錄音
│   │
│   ├─ Chat/
│   │   ├─ ChatView.swift           // 兩種範圍：note / global
│   │   └─ ChatViewModel.swift
│   │
│   └─ Paywall/
│       ├─ PaywallView.swift
│       └─ EntitlementStore.swift   // 會員/解鎖規則
│
├─ Models/                          // 資料結構（純 Swift struct）
│   ├─ SystemNote.swift             // 一個系統/筆記
│   ├─ Block.swift                  // enum：~20 種模組塊
│   ├─ Attachment.swift             // 語音/Prompt/YouTube/IG/GitHub/圖片
│   ├─ PublicListing.swift          // 探索頁的公開系統
│   ├─ ChatThread.swift             // 對話
│   ├─ ModuleType.swift             // 旋鈕上的模組清單
│   └─ User.swift / Membership.swift
│
└─ Services/                        // 跟後端講話的層（先用假資料，之後接真 API）
    ├─ APIClient.swift
    ├─ AuthService.swift
    ├─ NotesService.swift           // 筆記/塊的增刪改查
    ├─ AIService.swift              // 結構化/對話/摘要/搜尋/分析
    ├─ BillingService.swift         // StoreKit（Apple 訂閱）+ 加密貨幣
    ├─ MarketplaceService.swift     // 探索/Remix/購買
    └─ MediaService.swift           // YouTube/IG 中繼資料、語音轉文字
```

## 三、前端拆分對照表（HTML → SwiftUI 檔）

| HTML 裡的東西 | 角色 | 對應 SwiftUI |
|---|---|---|
| `.top` 主題切換 | 深/淺色切換 | `DesignSystem/Theme.swift` + 設定頁 |
| `#pageHome` + `.tabs` | 首頁兩分頁 | `HomeView` |
| `.ncard` | 我的系統卡 | `SystemCard` |
| `.excard` | 公開系統卡 | `ExploreCard` |
| `.aiov` | 全局 AI 卡 | `GlobalAIOverviewCard` |
| `#pageNote` + `.nav` + `.seg` | 筆記殼+切換 | `NoteView` + `SegmentedControl` |
| `const FREE` | 自由速記內容 | `FreeNoteView` |
| `structHTML()` 的每個 `card()` | 結構化 ~20 張卡 | `Note/Blocks/*.swift`（見下） |
| `.dial`（GSAP 旋鈕） | 加模組 | `ModuleDial/` |
| `#chat` + `SEED` | AI 對話（note/global） | `ChatView` |
| `#pay` + `MEMBER` 鎖 | 付費牆 | `PaywallView` + `EntitlementStore` |
| `#toast` / `#rec` | 提示 / 錄音 | `Toast` / `VoiceRecorder` |
| `THEMES` 物件 | 設計令牌 | `Theme.swift` + `Tokens.swift` |

### 結構化的 ~20 種模組塊（每個一個 `Block` case + 一個 View）

| 塊 | 中文 | PRO 鎖 |
|---|---|---|
| systemName | 系統名稱 | |
| techStack | 技術棧 | |
| techRating | 技術評估（星等） | |
| platformTools | 平台工具 | |
| github | 開源參考 | |
| aiSearch | AI 搜尋「有人做過嗎」 | |
| video | 參考影片+自動摘要 | |
| reel | 參考短影音 | |
| voice | 語音筆記+逐字稿 | |
| prompt | 提示詞 | |
| devFlow | 開發邏輯流程 | |
| buildSteps | 建置步驟 | |
| table | 表格化 | |
| htmlPreview | 版型示意 | |
| refShots | 參考截圖 | |
| devFocus | 開發重點（UI/前端/後端） | |
| competitors | 競品參考 | 🔒 |
| estimate | 預估（時程/難度/成本） | 🔒 |
| aiAnalysis | AI 可行性分析 | 🔒 |
| learningPath | 學習路徑+書單 | 🔒 |

> 這 20 張卡 = 你定的 5 大結構（開發邏輯/平台工具/參考影片/GitHub/提示詞庫）+ AI 加值（評估/分析/學習路徑）的展開。

## 四、目前 HTML 是「假的」、iOS 要補成真的地方

1. **旋鈕插入是假的**：`fireDial()` 只跳一個 Toast，沒真的把模組塞進筆記。iOS 要做成：選模組 → 在 `Block` 陣列插一筆 → 列表刷新。
2. **AI 全是寫死的字**：結構化、對話、摘要、搜尋、分析，現在都是固定文字。iOS 要改成呼叫後端 `AIService`。
3. **語音只有動畫**：要接真錄音 + 轉文字。
4. **YouTube/IG/GitHub** 現在是縮圖和連結，要接各自 API 拿真資料。
5. **付費/會員** 是一個 `MEMBER=true` 假開關，要接 StoreKit + 後端權限。

## 五、前端開發順序（先讓畫面動起來，再接後端）

1. 先搭 `DesignSystem`（主題色票 + 共用元件）→ 全 App 風格統一。
2. `HomeView` + 兩種卡（假資料）。
3. `NoteView` 殼 + `SegmentedControl` + `FreeNoteView`。
4. `StructuredNoteView` + 20 個 Block（先吃假資料）。
5. `ModuleDial`（用 SwiftUI 手勢做旋轉/吸附）+ **真的能插入** Block。
6. `ChatView`、`PaywallView`（先假）。
7. 把 `Services` 從假資料換成真 API（對應後端文檔）。
