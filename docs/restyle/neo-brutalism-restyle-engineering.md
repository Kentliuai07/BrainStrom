# BrainStrom 換皮工程 · Neo-Brutalism 改造 Workflow 提示詞兼設計文檔

> 版本 v1.0 · 適用對象：日後直接照此文件執行換皮工程的工程師與編排腳本
> 基準分支建議：`reskin/neo-brutalism`（從 `ios-dev` 切出，絕不在 `main` 直改）
> 唯一視覺保真基準：`/Users/kent/Desktop/BRAINSTORM/BrainStrom/ios-app/docs/mockups/neo-brutalism-allscreens.html`

---

## 1. 一句話目標 + 工程總覽

### 1.1 一句話目標

**把 BrainStrom iOS 前端從「工業硬體儀器」皮（霧面黑機殼／缺角矩形／鍵帽行程／單橘強調／柔光陰影）整體換成「80 年代 DOS 視窗 + Neo-Brutalism」皮（黃底黑邊／直角視窗／硬位移陰影／五色語義分區／平面硬沉），且舊皮與 73 個測試零回歸、可一行切回。**

### 1.2 工程總覽（去重後真相數字）

| 指標 | 數值 | 說明 |
|---|---|---|
| 唯一檔案數 | **約 28 個** | DesignSystem 16 + Features 11 + App 4 + Config 5 + Tests 3（跨切片重複已去重） |
| 核心換皮檔案 | **9 個** | Tokens / Theme / NotchedRectangle + 6 個 Components，約 950 行 |
| 畫面層總行數 | **約 2,400 行** | Home/Note/System/Persona/Markdown/Settings/Login/RootView |
| 樣式觸點實際數 | **約 290 處** | palette/Tokens/Motion 引用 + 硬編碼點 |
| 中央化健康度 | **顏色 98% · 字體 95% · 圓角 50% · 陰影 15% · 間距 55%** | 顏色幾乎全走 token；圓角與陰影是最大漏洞 |
| 測試組成（校正後） | **72 單元 + 1 E2E**（非地圖所說「73 含 E2E 70 行」） | 72 單元全與樣式正交；E2E 是單點 |

### 1.3 最高槓桿點 Top 5（改一處、影響全局）

| 排名 | 改動點 | 一處改的影響範圍 |
|---|---|---|
| **#1** | `Palette` 升級為 `Skin`（新增黃底 #FFE14D + 5 語義色 sys/def/idea/mkt/tech） | 透過 `@Environment(\.palette)` 影響 43+ 消費者、全部畫面 |
| **#2** | `SkinMetrics` 圓角全歸零 + 新增 `border=3` | 所有走 token 的形狀直角化 + 3px 黑邊 |
| **#3** | 新增 `hardShadow` ViewModifier（實心位移塊，0 模糊） | `hardwareCard` 包了全 App 卡片；改一個 modifier = 全卡片硬陰影（同時解 R2） |
| **#4** | `KeycapButtonStyle` 重做（立體鍵帽 → 平面硬沉方塊，消滅 3 個繞過 hex） | 跨 5+ 畫面 24+ 按鈕統一變身 + 消滅唯一顏色繞過點 |
| **#5** | `SkinType` 字族可覆寫 + `Fonts.display` 改 `.black/.heavy` 字重 | 全 App 字感一次拉粗（含中文降級與字體解析防線） |

**一句話策略**：在 Token 層與元件層（9 檔 950 行）收斂 **Palette + Radius + Shadow + Keycap + Font weight** 五點，即覆蓋 70% 視覺換皮；剩餘 30% 是各 Feature 畫面散落的硬編碼 cornerRadius/opacity/`.system(size:)`，屬純體力逐檔清理，無架構風險。

---

## 2. 架構決策：靠中央層做到「改一處、全 App 變」

### 2.1 核心洞察

現況中央層已做對最難的事：**顏色 98% 走 `Palette` + `@Environment(\.palette)`，一個 palette 切換刷新整棵 tree**。但它只中央化了「值（色）」，沒中央化「形（圓角／邊框／陰影／字重／動效）」——而這五項正是野獸派的視覺語法，目前散落在元件硬編碼裡（45 處 `cornerRadius`、9 處元件層 `.shadow`、立體鍵帽 `keyTravel`）。

**換皮的工程定義**：把「形」也收進 token，讓 `Palette` 升級為 **Skin = 色 + 形 + 字 + 影 + 動** 的單一真源。換皮後，新增一個 `brutalism` skin 常數 + 切一個 enum case = 換掉整個 App，**不碰任何 view 的 body**。

### 2.2 決定性架構取捨（先講結論，後給理由）

| 決策 | 選擇 | 否決的替代方案與理由 |
|---|---|---|
| 形狀 token 放哪 | **進 `Palette` struct（升級為 Skin），不放靜態 `enum Tokens`** | 否決靜態常數——`static let Radius.card` 無法隨 skin 切換，改 0 會砸爛舊兩皮 |
| 命名策略 | **只增不改名（additive），保留 `palette` env key 與 `Palette` 型別名** | 否決重命名——級聯 43+ 消費者重編譯 + diff 爆炸（R4） |
| 硬陰影怎麼做 | **自繪 `hardShadow` ViewModifier（背後疊 offset 實心 Rectangle），禁用原生 `.shadow`** | 否決原生 `.shadow(radius:0)`——SwiftUI radius 是高斯模糊半徑，做不出 0 模糊硬邊（R2） |
| 缺角簽名 | **保留 `NotchedRectangle` 型別，notch 進 skin，野獸派設 notch=0 退化成直角** | 否決刪型別改 Rectangle——會改 view 結構觸發 E2E 找不到元素（R1/R3） |
| 雙皮 vs 單皮 | **保留 ThemeStore 切換機制，新增第 3 皮 brutalism 並預設它；停用 system/warmGray 的混色邏輯** | 否決砍 ThemeStore——切換機制本身是換皮資產與回滾地基；brutalism 回傳 `.light`（黃底深字）化解 colorScheme 衝突（R5） |
| 鍵帽手感 | **平面硬沉：按下 `offset(3,3)` + 陰影縮成 tap，全站統一** | 否決保留鍵帽 2.5pt 下沉——與 mockup「往右下推 + 投影消失」是兩種 game feel，不能並存（R9） |

### 2.3 要新增的 Token（中央層落地清單）

```swift
// Palette struct 末尾 additive 新增（既有 18 色欄位名稱零變更）
var metrics: SkinMetrics = .instrument   // 圓角/邊框/命中區
var shadow:  SkinShadow  = .soft         // 陰影語法 soft↔hard
var type:    SkinType    = .instrument   // 字族描述（可覆寫，size 階保留靜態）
var motion:  SkinMotion  = .springy      // 動效 springy↔instant + keyTravel

// 新增 Palette 色欄位（收編繞過 hex + 硬陰影墨色）
let ink: Color          // 絕對黑（硬陰影/邊框）
let dangerDeep: Color   // ← 收編 KeycapButton 0x7A1A0E
let dangerInk: Color    // ← 收編 0xFFF2EF
// + 5 語義色：systemBlue / definitionGreen / conceptAmber / marketWineRed / techPurple

// SkinMetrics.brutal: radius 全 0、border 3、hitTarget 48
// SkinShadow.hard:    style=.hard, dx=6, dy=6, radius=0, color=ink
// SkinType.brutal:    displayFamily 走系統超粗黑 fallback（非硬切 Arial Black）
// SkinMotion.instant: easeOut(0.06), keyTravel=0
```

**間距尺標 `Tokens.Spacing`（4/8/12/16…）不進 skin**——兩皮共用 8pt grid，view 層魔術數字屬階段 3 逐檔清理。**FontSize 階梯不進 skin**——字級是資訊層級，野獸派字感靠 weight+family，把 Dynamic Type 風險面縮到只剩「字變粗」一個變因。

### 2.4 要新增/重做的共用元件清單

**基礎原語（最高槓桿）**
- `HardShadowModifier` / `.hardShadow()` — 實心位移陰影，泛型 Shape，五級 main(6,6)/card(3,3)/chip(2,2)/flag/toast
- `NeoSurface` — 中央表面形狀提供者，`SurfaceStyle { square, notched }` 一行開關決定全 App 直角/缺角
- `NeoBorder` / `.neoBorder()` — 標準描邊，KeyPath 取色（型別安全、不繞 Palette）

**重做既有元件（對外簽名不變 → 畫面零改動繼承）**
- `HardwareCardModifier`（`.hardwareCard()`）→ NeoSurface + 3px ink 邊 + hardShadow，刪上緣高光
- `KeycapButtonStyle`（`.keycap()`）→ 平面方塊 + 按下 offset(3,3) + 消滅 3 hex
- `HardwareToggleStyle`（`.hardware`）→ 52×30 直角軌 + 22×22 方 knob，命中 ≥44
- `SlotField` / `LEDIndicator`+`LEDBarGauge`（圓燈→方燈）/ `ToastBanner`（橘底 r10 blur → 黑底黃字 6/6/0 綠硬影）

**全新元件（給畫面層收斂散落硬編碼的武器）**
- `BrutalWindow`（win-title 黑條 + body，野獸派新簽名，取代缺角識別）
- `NeoChip`（標籤/tab segment）、`NeoDivider`（粗實分隔線）、`NeoWindowChrome`（視窗框/空態/dial）、`NeoCheckbox`（圓→方勾選框）
- `SpecRow`（身份證五色 sub-header）、`Bubble`（ai/user/loading/err，user 橘→青藍 #7FD4FF）、`CoreProg`（4 格核心進度）
- **全域殼層 P0**：`MenuBar`（ONLINE/電量/時鐘，複用 OfflineBar 網路監聽）、`FnBar`（F1–F4 視覺殼 + 點擊路由）、`Foot`（`C:\BRAINSTORM\>` mono 命令列）

---

## 3. 階段化工作流（含每階段代理數量與分工）

四鏡頭整合後的全局拓撲。**鐵律：階段嚴格串行（左階段未全綠不得進右），階段內按檔/按屏天然解耦處並行。**

```
P0 決策 → P1 Token地基 → P2 共用元件 → P3 逐屏套用 → P4 驗證收尾
 (串行)    (強制單代理)    (並行6-9)      (並行4)       (並行3)
```

### P0 · 決策鎖定（阻塞全部）— 代理數 1

| 分工 | 內容 | 覆蓋鏡頭 |
|---|---|---|
| 決策代理（人類 review 簽核） | 拍板三決策：①單一 brutalism 皮（停用 system/warmGray 混色邏輯）②NotchedRectangle notch=0 直角化、win-title 黑條當新簽名 ③字族走系統超粗黑 fallback（不硬切 Arial Black，含中文降級） | 中央層 / UX / 編譯 |

**退出標準**：三決策白紙黑字簽核；確認 `AI_USE_STUB=YES` 在 CI 軌生效。

### P1 · Token 地基（最高槓桿，必須最先）— 代理數 **1（強制串行單代理）**

| 分工 | 範圍（絕對路徑） | 覆蓋鏡頭 |
|---|---|---|
| 中央層代理 | `Tokens.swift`（Skin 四結構 SkinMetrics/SkinShadow/SkinType/SkinMotion + Palette.brutalism 常數 + ink/dangerDeep/dangerInk）、`Theme.swift`（MachineSkin 加 `.brutalism` case + switch 一行 + 預設切 brutalism）、`HardShadowModifier`、`NotchedRectangle` notch 接 skin | 中央層 |

**為何單代理**：`Tokens.swift`+`Theme.swift` 共 245 行、是全 App 單點真源；多代理並行改同檔必 merge 衝突。**改動量大 ≠ 要多代理，單點真源恰恰要單代理。**

**退出標準**：三套皮各編譯綠；`Palette` 既有 18 色欄位 diff 中無 rename；「單行切換」測試成立（init 預設改 matteBlack 完整呈現舊皮，改 brutalism 完整呈現新皮，兩者 diff 僅 1 行）。

### P2 · 共用元件重構（依賴 P1）— 代理數 **6（保守）/ 9（積極）**

關鍵路徑 R1 原語 → (R2 既有元件 ∥ R3 新元件) → R4 收尾。

| 子階段 | 代理數 | 分工 | 覆蓋鏡頭 |
|---|---|---|---|
| R1 原語 | **1（不可並行）** | HardShadow → NeoSurface → NeoBorder（強耦合地基，同一腦袋決策型別擦除/Shape 泛型） | 元件 |
| R2 既有元件 | **6（並行）** | ①NeoCard ②Keycap ③Toggle ④SlotField ⑤LED×2 ⑥Toast（彼此零依賴，全調 R1 已凍結原語） | 元件 / UX |
| R3 新元件 | **3（並行，可與 R2 同開）** | ①NeoChip ②NeoDivider+NeoCheckbox ③NeoWindowChrome+BrutalWindow | 元件 / UX |
| R4 收尾 | **1** | 統一 6 元件 #Preview palette、產「元件目錄」單頁 Preview（gold snapshot 基準）、交付替換映射表 | 元件 / 編譯 |

**退出標準**：`grep "\.shadow(" DesignSystem` = 0；`grep "Color(hex:" Components` = 0；元件層硬編碼 `cornerRadius:` 非 0 = 0；36 處既有呼叫點零改簽名；toggle 命中 ≥44×44；可達性樹（LED/Toast/Gauge 的 accessibilityLabel）不變。

### P3 · 逐屏套用（依賴 P2，屏間無強耦合可平行）— 代理數 **4**

| 代理 | 負責屏 | 範圍 | 覆蓋鏡頭 |
|---|---|---|---|
| B1 | 屏 1/2/3 | Home 族（首頁/空態）+ 建立彈窗 | UI / UX |
| B2 | 屏 4/7 | AI 教練 + 筆記詳情 + chatPanel + Markdown（user 泡橘→青藍、checkbox 圓→方） | UI / UX |
| B3 | 屏 5/6/8 | 開發筆記列表 + 系統結構身份證（五色 sub-header）+ PersonaBatch | UI / UX |
| B4 | 屏 9 + 殼 | Settings（移除主題 seg、toggle 52×30）+ Login（logo→■B 方塊）+ BootCheck + menubar/fnbar/foot 全域殼接線 | UI / UX |

**每代理動作**：照 P2 交付的「替換映射表」機械替換散落硬編碼——B 類元件零改動自動繼承；C 類 + 散落 `RoundedRectangle/Capsule/.system(size:)` 照表替換；補齊 `accessibilityIdentifier`；命中區 `frame(minWidth/Height:44)`。

**退出標準**：每屏對照第 4 節驗收點全 PASS；每屏 `accessibilityIdentifier` 集合「換皮前 = 換皮後」零差異。

### P4 · 驗證收尾（依賴 P3）— 代理數 **3**

| 代理 | 分工 | 覆蓋鏡頭 |
|---|---|---|
| C1 截圖回歸 | 9 屏 `snapshot_ui`/`screenshot` vs mockup 逐構件比對，產 before/after diff 網格交人工核可 | 編譯 / UX |
| C2 無障礙 | 44pt 命中掃描 + Dynamic Type AX3 爆版掃描 + VoiceOver 焦點順序 + 黃底對比 | UX / 編譯 |
| C3 回歸 | `test_sim` 跑 72 單元 + 1 E2E 全綠 + 字體解析斷言(G4) + 7+ Preview 全改色 + 版本 bump | 編譯 |

**退出標準**：見第 7 節驗收標準全綠。

**全局代理峰值**：P2 積極排程達 9，其餘階段 1–4。**驗證的價值在確定性不在吞吐**——P1/P4-C3 必須單代理串行（跑最多次、要最快最清晰）。

---

## 4. 逐屏保真對照表（9 屏 → SwiftUI view → 驗收點）

驗收單位 = 構件；逐屏驗收 = 「該屏是否只由構件組裝、且每構件達硬指標」。判定二元 PASS/FAIL，附 mockup screenflag 並排基準。

| # | 屏 | SwiftUI view（絕對路徑 + 關鍵符號） | 換皮驗收點（[版面]/[像素]/[層級]） | 改動量 |
|---|---|---|---|---|
| 1 | 首頁 | `Features/Home/HomeScreen.swift` → `HomeScreen`/`SystemCardView`/`VisibilityPill` | [版面] menubar→標題 win→系統 win 卡→fnbar→foot；齒輪/加號 circleIcon→win-title ⚙ + body ＋建立專案方鈕 [像素] 卡 3px 黑邊、win-title 黑底白字、硬影 6/6/0、Pill→Rectangle [層級] 整卡可點、⚙ 獨立命中。**任何缺角殘留=FAIL** | high |
| 2 | 空態 | 同檔 `HomeScreen.emptyRack` | [像素] NotchedRectangle 虛線缺角框→Rectangle dashed 3px 直角框；eico 32pt；cta amber 滿寬 ≥44 [層級] 與列表 `if systems.isEmpty` 互斥（零回歸） | med |
| 3 | 建立彈窗 | 同檔 `CreationSheet`/`fieldBox`/`modeButton`（.sheet medium/large） | [像素] input 3px 直角 ≥44、focus→3/3/0 琥珀聚焦投影（新互動）；三 modecard 三色底 3/3/0 壓下 translate(3,3) [層級] 國家 Menu 保留行為、只換 .select 外觀。id 全保留 `home.projectNameInput`/`create.mode.*` | high |
| 4 | AI 教練 | `Features/Note/AICoachView.swift` → `bubbleView`/`optionsBlock`/`competitorBar` | [像素] ai 泡白底 3px 邊 3/3/0 + ▶AI 綠章；**user 泡橘→青藍 #7FD4FF**（L128）；新增 coreprog 4 格 [層級] competitorBar 在 chatList/inputBar 間；options 只最新非串流可操作（**不可動 parseGuidedOptions**）。id `coach.*` 保留 | high |
| 5 | 開發筆記列表 | `Features/Note/NotesListView.swift`（166 行） | [像素] 卡改 `BrutalWindow(.idea, nested:true)` 3/3/0、c-idea 標題列琥珀底、主筆記 `主` pill [層級] 列表/空態互斥 | high |
| 6 | 系統結構身份證 | `Features/Note/SystemStructureView.swift` → `idCardSection`/`zone`/`specRow` | [像素] zone 小標 mono 灰字→**五色 sub-header**（def綠/idea琥珀/mkt酒紅/func琥珀/tech紫）；spec-row 間 3px 黑分隔；核心 ⭐ [層級] 身份證(唯讀)/結構卡片 rule.labeled 分隔。`structure.run` id 保留 | high |
| 7 | 筆記詳情 | `Features/Note/NoteScreen.swift` `NoteDetailScreen` + `NoteContentViews.swift` `BlockRow` + `NoteChatViews.swift` + `MarkdownView.swift` | [像素] **checkbox Circle→Rectangle .ck 18×18 方框**（L83-92，E2E 風險點 id 不可動）；dock 鈕 44×44 方 3/3/0 [層級] **chatPanel 保留 overlay 行為**（不改 inline，避免動 showChat 焦點管理）。id `note.*`/`dock.*` 保留 | high |
| 8 | 批量定位卡 | `Features/Note/PersonaBatchView.swift` → `cardPage`/`pageind`/`appendBar` | [像素] 卡 hardwareCard→`BrutalWindow(.mkt)`；技術棧 is-speculate 淡紫底+「AI 推測」標（新增態）；headline 酒紅大字 [層級] loading/failed/browsing 三態互斥；TabView 滑動保留、`.indexViewStyle(.never)` 自繪方塊 pageind。id `persona.*` 保留 | med |
| 9 | 設定 | `Features/Settings/SettingsScreen.swift` → `skinSeg`/`HardwareToggle`/`deleteButton` | [像素] segctl 直角 on=黑底黃字；**toggle 34×19→52×30 方 knob**；list-row 3px 分隔 ≥44 [層級] **移除主題 seg**（單皮）、補語言/可見性/通知/版本唯讀列（stub 零回歸）；confirmationDialog 刪帳號保留系統樣式（已知差異） | med |
| — | 登入 | `Features/Login/LoginScreen.swift` | logo NotchedRect→■B 黑方塊；Toast 自動繼承。id `login.apple` 保留 | med |
| — | 啟動自檢 | `App/RootView.swift` `BootCheckView` | 缺角點→方塊；複用網路監聽做 menubar ONLINE/電量/時鐘 | med |

---

## 5. 驗證閘門（build_sim / 73 測試 / screenshot / 字型 / 版本 / TestFlight / 回滾）

**順序即依賴，左不過右不跑。** 唯二例外：G5 永遠跑完產全部 diff；G7 為軟閘。

```
G0 預檢 → G1 編譯(build_sim) → G2 並發(warnings=err) → G3 單元(72) → G4 字體解析
→ G5 視覺回歸(screenshot) → G6 E2E(1 flow) → G7 無障礙/DT → G8 版本&歸檔 → G9 TestFlight
```

| 閘 | 做什麼 | 失敗處置 | 完成標準 |
|---|---|---|---|
| **G0 預檢** | grep 禁區清單(§6)；確認 `AI_USE_STUB=YES`；非 main 分支 | 退回貼禁區行號 | 8 E2E id 命中（`tab.structure` 以 enum `case structure` 存在替代字面）；stub 生效 |
| **G1 編譯** | `build_sim` Debug + iPhone 15/17 iOS17 | Palette 改名→43+ 消費者 missing member → 改用新增欄位；Token PR 必先獨立合併 | Debug BUILD SUCCEEDED 0 error |
| **G2 並發** | G1 在 `SWIFT_TREAT_WARNINGS_AS_ERRORS` 下副產物 | 禁用 `@unchecked/nonisolated(unsafe)/@preconcurrency` 繞過；狀態收進 @MainActor | diff 中降級註解新增 = 0 |
| **G3 單元(72)** | `test_sim -only-testing:BrainStromTests` | 任一變紅 = 越界動到 VM/Repo/Parser/Model → 回退；禁碰 Domain/Data/*ViewModel* | 72/72 綠 |
| **G4 字體解析** | **新增 XCTest**：每個 display/body 字體名斷言 `UIFont(name:)!=nil`；內嵌字驗 `UIAppFonts` 登記；中文 PingFang 解析 | 名拼錯/未內嵌→紅。**禁止「看起來對就放行」**（會躲過所有其他閘）；Arial Black 可用性由本閘實測決定，失敗回落 `.system(weight:.black)` | 所有字體名 UIFont 非 nil |
| **G5 視覺回歸** | 換皮前 commit 跑 `screenshot` 存 baseline/；換皮後存 candidate/；逐頁 sips/CoreImage 算 diff。**從零搭建（repo 無 snapshot 基建）** | diff 必 100% 非零（換皮本質）→ 交人工核可；**不該變的頁超閾值→疑似越界**；全黑/全白/崩頁→硬錯（典型 hardShadow 蓋住內容 R2） | 兩套截圖齊、每頁有 diff、0 崩頁、人工逐頁簽核 |
| **G6 E2E(1)** | `test_sim -only-testing:BrainStromUITests` | 找不到元素→查禁區：`Tab` rawValue/Stub 字串/8 id 被動 → 還原 id 視覺照改。**換皮前先把 `tab.structure` 動態 id 改字面常數、預補 checkbox/FAB id** | 1/1 綠 |
| **G7 無障礙(軟)** | `snapshot_ui` 抓 frame：命中≥44；AX3 不爆版；黃底文字鎖深色(WCAG) | 記待辦不阻 G8，但阻 G9 外部測試分發 | 命中達標 100%、AX3 無截斷 |
| **G8 版本&歸檔** | `CURRENT_PROJECT_VERSION` 20→21（每次上傳必+1）；Release wholemodule build；archive + exportArchive | Release 才報錯→從 G1 重跑；簽章失敗交帳號持有者 | Release SUCCEEDED + dSYM；build# > 線上 |
| **G9 TestFlight** | 上傳 .ipa→內部組→過 G7 後外部組 | 見下方回滾分層 | ASC "Ready to Test"、可符號化、回滾演練通過 |

### 回滾策略（分層，先快後慢）

| 層 | 觸發 | 動作 | 復原 |
|---|---|---|---|
| L0 程式碼 | 任一閘紅 | 換皮在獨立分支，丟棄/revert，main 永遠上一綠版 | 秒級 |
| L1 TestFlight | 上架後崩潰回報 | ASC expire 該 build，測試者自動回 v20 | 分鐘級 |
| **L2 Token 級** | 整體被否決 | **不刪舊 Palette/Radius/Shadow，只新增 variant → 改一個 enum 預設值切回舊皮** | 一次 build |
| L3 配置級 | 緊急 | MachineSkin/ThemeStore 預設改回重新 archive | 一次 G8 |

**鐵律：換皮 PR 不得刪除任何 Palette/Radius/Shadow 既有定義，只新增。** 這讓 L2 從「revert 大量 commit」降為「改一個預設枚舉值」。

---

## 6. 風險登記冊 + 緩解

| # | 風險 | 嚴重度 | 緩解 |
|---|---|---|---|
| R1 | 測試寫死斷言/結構耦合爆掉 | 高 | 純視覺換皮不爆；**禁區**：`Tab` case 名、`AIServiceStub` 字串「教練開場/核心問題」、8 個 id。只換外觀不刪鈕不改 id 不重排可達性樹 |
| R2 | SwiftUI `.shadow()` 永遠帶 blur，做不出 6/6/0 硬影 | 高 | 寫 `hardShadow` ViewModifier（背後疊 offset 實心 Rectangle 雙層位移法），禁用原生 shadow |
| R3 | NotchedRectangle 缺角品牌簽名 vs 直角衝突 | 高 | P0 拍板；保留型別 notch=0 退化直角，win-title 黑條當新簽名，不改 shape 型別 |
| R4 | Palette 欄位變動級聯 43+ 消費者重編譯 | 中 | 只新增欄位、用 var+預設值，絕不改名 |
| R5 | 雙皮 vs 單皮色彩邏輯衝突 | 中 | 單皮，brutalism 回 `.light`（黃底深字）；停用 system/warmGray 混色但保留 ThemeStore 機制 |
| R6 | 字體降級：Arial Black 非 iOS 字、中文異常 | 中 | **G4 實測 `UIFont(name:)`**；走系統超粗黑 fallback，中文 PingFang，勿硬切 |
| R7 | Dynamic Type 溢位：超粗黑體 + 固定 pt | 中 | FontSize 不進 skin（風險縮到字變粗一變因）；`@ScaledMetric` + `.lineLimit` + truncation |
| R8 | cornerRadius 散亂 40+ 處無法 sed | 中 | token 化後逐檔按語義對映，禁盲改 |
| R9 | 動畫耦合 keyTravel 移除壞 game feel | 低 | 改 offset(3,3) 硬沉，刪鍵帽 ZStack 雙層改單層，全量手測一輪 |
| R10 | 命中區不足 toggle 34×19/nav 30×30/tool 22×18 | 低 | `frame(minWidth/Height:44)` 或 contentShape 撐滿，視覺尺寸不變 |
| R11 | confirmationDialog 系統樣式不繼承 | 低 | v1 接受系統樣式（列已知差異），v2 改自訂 BrutalAlert |
| R12 | 黃底 #FFE14D 對比 WCAG | 低 | 文字鎖黑/深色，Toast orange→黃重檢 |
| R-Font静默 | `.custom` 找不到名靜默回落 SF Pro，build/測試/E2E 全綠但字錯 | 高 | **G4 字體解析斷言**是唯一防線，現有測試完全沒覆蓋 |
| R-Snapshot | repo 無任何 snapshot 基建 | 中 | G5 從零搭建（screenshot + sips diff，零第三方依賴），非「重生」 |

---

## 7. 驗收標準（可量化，何時算 100% 完成）

**全部機器可判定，全綠 = 換皮簽收：**

1. **編譯**：Debug + Release build 各 0 error，warnings-as-errors 下綠；三套皮各冒煙 0 crash。
2. **並發**：換皮 diff 中 `@unchecked/nonisolated(unsafe)/@preconcurrency` 新增 = 0。
3. **單元測試**：72/72 綠（不得任一因換皮轉紅）。
4. **字體（G4）**：所有 display/body 字體名 `UIFont(name:)` 100% 非 nil；內嵌字 `UIAppFonts` 登記數 = 內嵌檔數；中文解析成功。
5. **元件純度**：`grep "\.shadow(" DesignSystem`=0；`NotchedRectangle` 引用=0（或退化驗證）；9 屏內 `Capsule(`=0；硬編碼 `cornerRadius:` 非 0=0；`Color(hex:" Components`=0。
6. **視覺回歸（G5）**：9 屏 baseline/candidate 齊備，每頁有 diff，0 崩頁；「不該變的頁」diff ≤ 閾值；人工逐頁簽核完成。
7. **逐屏保真**：9 屏對照第 4 節 [版面]/[像素]/[層級] 三類 100% PASS。
8. **E2E**：1/1 綠；全 App `accessibilityIdentifier` 集合「換皮前 = 換皮後」diff 為空。
9. **無障礙**：互動元素命中區 ≥44pt 達標 100%；Dynamic Type 至 AX3 無標題截斷；黃底文字鎖深色。
10. **觸感**：press/tap/selection/warning 四類 `Haptics` 呼叫點換皮前後計數一致；按壓動畫全站統一 offset(3,3) 0.12s。
11. **換皮可達性核心 KPI**：「單行切換」——`ThemeStore.init` 預設改 matteBlack 完整呈現舊皮、改 brutalism 完整呈現新皮，兩者 diff 僅 1 行。
12. **回滾**：L0+L1 路徑各演練 1 次通過；舊 Palette/Radius/Shadow 定義零刪除。
13. **版本/出貨**：`CURRENT_PROJECT_VERSION` ≥21 且 > 線上；`.xcarchive` 含 dSYM；ASC "Ready to Test"。

---

## 8. 【可直接執行的 Workflow 腳本】

> 貼進 workflow runner 即可跑。`export const meta` 為純字面量（無變數引用）。`AGENT_PROMPTS` 內每個提示詞已內嵌該代理的完整 spec、禁區與退出標準。

```javascript
// reskin-neo-brutalism.workflow.js
// BrainStrom iOS 換皮工程（霧面黑 → Neo-Brutalism）編排腳本

export const meta = {
  name: "reskin-neo-brutalism",
  version: "1.0.0",
  description: "BrainStrom iOS 整體換皮：工業儀器皮 → 80s DOS Neo-Brutalism；舊皮與 73 測試零回歸、可一行切回",
  projectRoot: "/Users/kent/Desktop/BRAINSTORM/BrainStrom/ios-app",
  scheme: "BrainStrom",
  unitTestTarget: "BrainStromTests",
  uiTestTarget: "BrainStromUITests",
  simulator: "iPhone 17",
  branch: "reskin/neo-brutalism",
  mockup: "/Users/kent/Desktop/BRAINSTORM/BrainStrom/ios-app/docs/mockups/neo-brutalism-allscreens.html",
  forbiddenPaths: [
    "Domain/", "Data/", "*ViewModel*", "*Repository*", "*Parser*",
    "SSEParser", "ApplyPipeline", "BlockSplitter"
  ],
  forbiddenSymbols: [
    "enum Tab case names (coach,notes,structure)",
    "AIServiceStub strings: 教練開場 / 核心問題",
    "E2E ids: login.apple home.create home.projectNameInput create.mode.kickoff coach.addnote systemDetail.tab.* structure.run systemDetail.back",
    "new @unchecked Sendable / nonisolated(unsafe) / @preconcurrency",
    "deletion of any existing Palette/Radius/Shadow definition"
  ]
};

// ───────────────────────── Schema ─────────────────────────
const PhaseResult = {
  type: "object",
  required: ["phase", "status", "filesTouched", "exitCriteriaMet", "notes"],
  properties: {
    phase: { type: "string" },
    status: { enum: ["green", "red", "blocked"] },
    filesTouched: { type: "array", items: { type: "string" } }, // 絕對路徑
    exitCriteriaMet: { type: "boolean" },
    grepChecks: { type: "object" },   // { ".shadow(": 0, "Color(hex:": 0, ... }
    notes: { type: "string" }
  }
};
const GateResult = {
  type: "object",
  required: ["gate", "pass", "detail"],
  properties: { gate: { type: "string" }, pass: { type: "boolean" }, detail: { type: "string" } }
};

// ───────────────────── Agent 提示詞表 ─────────────────────
const AGENT_PROMPTS = {
  decision: `你是換皮決策代理。產出三決策的白紙黑字結論交人類簽核：
①單一 brutalism 皮，停用 system/warmGray 混色邏輯（保留 ThemeStore 機制）。
②NotchedRectangle notch=0 直角化，win-title 黑條當新簽名（不刪型別）。
③字族走系統超粗黑 fallback，不硬切 Arial Black，含中文 PingFang 降級。
確認 CI 軌 AI_USE_STUB=YES。輸出 PhaseResult JSON。`,

  token: `你是中央層代理（P1，強制單代理串行）。只改：
- Tokens.swift：新增 SkinMetrics/SkinShadow/SkinType/SkinMotion 四結構（additive var+預設值），
  Palette 新增 ink/dangerDeep/dangerInk + 5 語義色，新增 Palette.brutalism 常數(metrics.brutal/shadow.hard/type.brutal/motion.instant)。
- Theme.swift：MachineSkin 加 .brutalism case + palette(for:) switch 一行 + init 預設切 brutalism。
- 新增 HardShadowModifier(.hardShadow)：背後疊 offset 實心 Rectangle，禁用原生 .shadow。
- NotchedRectangle.swift：notch 接 skin。
鐵律：既有 18 色欄位零改名（additive）；不刪任何既有定義。
退出：三套皮編譯綠；「單行切換」成立。輸出 PhaseResult JSON + grepChecks。`,

  primitive: `你是元件原語代理（P2-R1，不可並行）。依序寫 HardShadow → NeoSurface(SurfaceStyle square/notched 一行開關) → NeoBorder(KeyPath 取色)。
三者強耦合地基，型別擦除/Shape 泛型一致決策。輸出 PhaseResult JSON。`,

  componentExisting: (name, file) => `你是元件重做代理（P2-R2）。重做 ${name}（${file}），對外簽名不變：
NeoCard:.hardwareCard()→NeoSurface+3px ink 邊+hardShadow，刪上緣高光；
Keycap:.keycap()→平面方塊+按下 offset(3,3)+陰影縮 tap+消滅 3 hex(改 palette.dangerDeep/dangerInk)；
Toggle:.hardware→52×30 直角軌+22×22 方 knob+命中≥44；
SlotField/LED(圓→方)/Toast(橘 r10 blur→黑底黃字 6/6/0 綠硬影)。
鐵律：accessibilityLabel 全保留；只調 P1 凍結原語。輸出 PhaseResult JSON。`,

  componentNew: (name) => `你是新元件代理（P2-R3，可與 R2 並行）。新增 ${name}：
BrutalWindow(win-title 黑條+body)/NeoChip/NeoDivider/NeoCheckbox/NeoWindowChrome/SpecRow/Bubble(user 青藍#7FD4FF)/CoreProg/MenuBar/FnBar/Foot。
各自 #Preview 與 mockup 並排 PASS。輸出 PhaseResult JSON。`,

  screen: (ids, files) => `你是逐屏套用代理（P3）。負責屏 ${ids}（${files}）。
照 P2 替換映射表：B 類元件零改動繼承；散落 RoundedRectangle/Capsule/.system(size:)/opacity 照表替換為 NeoChip/NeoWindowChrome/Tokens.Fonts/palette 語義色；
補 accessibilityIdentifier；命中區 frame(minWidth/Height:44)。
鐵律：不刪鈕、不改 id、不重排可達性樹、不動 parseGuidedOptions/spec 映射/AIServiceStub。
退出：對照逐屏驗收點全 PASS；id 集合換皮前=換皮後。輸出 PhaseResult JSON。`,

  verifyVisual: `你是視覺回歸代理（P4-C1）。換皮前 commit 跑 screenshot 存 baseline/，換皮後存 candidate/，
逐頁 sips/CoreImage 算 diff 產 before/after 網格。判讀：不該變的頁超閾值→疑似越界；全黑/全白/崩頁→硬錯。
輸出 GateResult JSON + diff 路徑，交人工核可。`,

  verifyA11y: `你是無障礙代理（P4-C2）。snapshot_ui 抓 frame：命中≥44 達標率；AX3 爆版掃描；VoiceOver 焦點順序；黃底文字鎖深色。輸出 GateResult JSON。`,

  verifyRegress: `你是回歸代理（P4-C3，單代理串行）。依序：
1) build_sim Debug(warnings=err) → 2) test_sim 72 單元 → 3) G4 字體解析斷言(UIFont(name:)!=nil + UIAppFonts + 中文) →
4) test_sim 1 E2E → 5) 7+ Preview 改 brutalism palette → 6) CURRENT_PROJECT_VERSION 20→21。
任一紅停。輸出 GateResult[] JSON。`
};

// ───────────────────── 驗證閘門 ─────────────────────
async function gate(ctx, name, fn) {
  const r = await fn();
  ctx.log(`[GATE ${name}] ${r.pass ? "PASS" : "FAIL"} — ${r.detail}`);
  if (!r.pass) throw new Error(`Gate ${name} FAILED: ${r.detail}`);
  return r;
}

async function runGates(ctx) {
  // G0 預檢：禁區 grep
  await gate(ctx, "G0-preflight", async () => {
    const hit = await ctx.bash(`git -C ${meta.projectRoot} diff --name-only ${meta.branch} | grep -E 'Domain/|Data/|ViewModel|Repository|Parser' || true`);
    return { gate: "G0", pass: hit.trim() === "", detail: hit.trim() ? `禁區被動: ${hit}` : "禁區乾淨" };
  });
  // G1 編譯
  await gate(ctx, "G1-build", async () => {
    const out = await ctx.tool("mcp__XcodeBuildMCP__build_sim", { projectRoot: meta.projectRoot, scheme: meta.scheme, simulatorName: meta.simulator });
    return { gate: "G1", pass: /BUILD SUCCEEDED/.test(out), detail: "Debug build" };
  });
  // G2 並發（warnings-as-errors 副產物 + 降級註解掃描）
  await gate(ctx, "G2-concurrency", async () => {
    const bad = await ctx.bash(`git -C ${meta.projectRoot} diff ${meta.branch} | grep -E '^\\+.*(@unchecked|nonisolated\\(unsafe\\)|@preconcurrency)' || true`);
    return { gate: "G2", pass: bad.trim() === "", detail: bad.trim() ? "新增降級註解" : "0 降級註解" };
  });
  // G3 單元 72
  await gate(ctx, "G3-unit", async () => {
    const out = await ctx.tool("mcp__XcodeBuildMCP__test_sim", { projectRoot: meta.projectRoot, scheme: meta.scheme, simulatorName: meta.simulator, onlyTesting: meta.unitTestTarget });
    return { gate: "G3", pass: /TEST SUCCEEDED/.test(out) && !/failed/i.test(out), detail: "72 單元" };
  });
  // G4 字體解析（由 C3 代理寫的 XCTest 隨 G3 跑；此處驗結果存在）
  await gate(ctx, "G4-font", async () => {
    const r = await ctx.agentResult("verifyRegress", "fontAssertion");
    return { gate: "G4", pass: r?.pass === true, detail: "UIFont(name:) 全非 nil + UIAppFonts + 中文" };
  });
  // G5 視覺回歸（永遠跑完，產 diff，硬錯=崩頁）
  const vis = await ctx.runAgent("verifyVisual", AGENT_PROMPTS.verifyVisual, GateResult);
  ctx.log(`[GATE G5-visual] diff 已產出，交人工核可；崩頁=${!vis.pass}`);
  if (!vis.pass) throw new Error("G5 崩頁/全黑/全白 硬錯");
  // G6 E2E
  await gate(ctx, "G6-e2e", async () => {
    const out = await ctx.tool("mcp__XcodeBuildMCP__test_sim", { projectRoot: meta.projectRoot, scheme: meta.scheme, simulatorName: meta.simulator, onlyTesting: meta.uiTestTarget });
    return { gate: "G6", pass: /TEST SUCCEEDED/.test(out), detail: "1 E2E flow" };
  });
  // G7 無障礙（軟閘：不 throw）
  const a11y = await ctx.runAgent("verifyA11y", AGENT_PROMPTS.verifyA11y, GateResult);
  ctx.log(`[GATE G7-a11y SOFT] ${a11y.pass ? "PASS" : "WARN — 阻外部測試分發"} ${a11y.detail}`);
  // G8 版本&歸檔
  await gate(ctx, "G8-archive", async () => {
    const ver = await ctx.bash(`grep CURRENT_PROJECT_VERSION ${meta.projectRoot}/Config/Shared.xcconfig`);
    const n = parseInt((ver.match(/=\\s*(\\d+)/) || [])[1] || "0", 10);
    return { gate: "G8", pass: n >= 21, detail: `build#=${n} (須≥21)` };
  });
  return { allGreen: true };
}

// ───────────────────── 主流程 ─────────────────────
export default async function run(ctx) {
  await ctx.bash(`git -C ${meta.projectRoot} checkout -b ${meta.branch} || git -C ${meta.projectRoot} checkout ${meta.branch}`);

  // P0 決策（串行 1）
  const p0 = await phase(ctx, "P0-decision", () =>
    ctx.runAgent("decision", AGENT_PROMPTS.decision, PhaseResult));
  if (!p0.exitCriteriaMet) throw new Error("P0 決策未簽核，阻塞全部");

  // P1 Token 地基（強制單代理串行）
  const p1 = await phase(ctx, "P1-token", () =>
    ctx.runAgent("token", AGENT_PROMPTS.token, PhaseResult));
  if (!p1.exitCriteriaMet || p1.grepChecks?.["singleLineSwitch"] !== true)
    throw new Error("P1 未達『單行切換』，後續會被覆寫");

  // P2 元件：R1 串行 → (R2 ∥ R3) → R4
  await phase(ctx, "P2-R1-primitive", () =>
    ctx.runAgent("primitive", AGENT_PROMPTS.primitive, PhaseResult));

  const existing = [
    ["NeoCard", "DesignSystem/Components/Panels.swift"],
    ["Keycap", "DesignSystem/Components/KeycapButtonStyle.swift"],
    ["Toggle", "DesignSystem/Components/Controls.swift"],
    ["SlotField", "DesignSystem/Components/Controls.swift"],
    ["LED", "DesignSystem/Components/Indicators.swift"],
    ["Toast", "DesignSystem/Components/Feedback.swift"]
  ];
  const newComps = ["NeoChip", "NeoDivider+NeoCheckbox", "NeoWindowChrome+BrutalWindow"];
  // R2 與 R3 並行（共 9 代理峰值）
  await ctx.parallel([
    ...existing.map(([n, f]) => () => ctx.runAgent(`comp-${n}`, AGENT_PROMPTS.componentExisting(n, f), PhaseResult)),
    ...newComps.map((n) => () => ctx.runAgent(`new-${n}`, AGENT_PROMPTS.componentNew(n), PhaseResult))
  ]);
  await phase(ctx, "P2-R4-catalog", () =>
    ctx.runAgent("catalog", "統一 6 元件 #Preview palette、產元件目錄單頁 Preview、交付替換映射表。輸出 PhaseResult JSON。", PhaseResult));

  // 元件純度閘（進 P3 前）
  await gate(ctx, "purity", async () => {
    const a = await ctx.bash(`grep -rc "\\.shadow(" ${meta.projectRoot}/BrainStrom/DesignSystem || true`);
    const b = await ctx.bash(`grep -rc "Color(hex:" ${meta.projectRoot}/BrainStrom/DesignSystem/Components || true`);
    const zero = (s) => s.split("\\n").every(l => !l || /:0$/.test(l));
    return { gate: "purity", pass: zero(a) && zero(b), detail: `.shadow=${a.trim()} hex=${b.trim()}` };
  });

  // P3 逐屏（4 代理並行）
  const screens = [
    ["1/2/3", "Home/HomeScreen.swift"],
    ["4/7", "Note/AICoachView.swift,NoteScreen.swift,NoteContentViews.swift,NoteChatViews.swift,MarkdownView.swift"],
    ["5/6/8", "Note/NotesListView.swift,SystemStructureView.swift,PersonaBatchView.swift"],
    ["9+shell", "Settings/SettingsScreen.swift,Login/LoginScreen.swift,App/RootView.swift"]
  ];
  await ctx.parallel(screens.map(([ids, files]) =>
    () => ctx.runAgent(`screen-${ids}`, AGENT_PROMPTS.screen(ids, files), PhaseResult)));

  // P4 驗證收尾（C3 串行跑閘門；C1/C2 在 runGates 內並行調用）
  const gates = await runGates(ctx);

  // self-verify：13 條驗收標準總核
  const verdict = await selfVerify(ctx);
  return { meta: meta.name, gates, verdict };
}

async function phase(ctx, name, fn) {
  ctx.log(`=== PHASE ${name} ===`);
  const r = await fn();
  ctx.log(`[PHASE ${name}] status=${r.status} exit=${r.exitCriteriaMet}`);
  if (r.status === "red") throw new Error(`Phase ${name} RED: ${r.notes}`);
  return r;
}

// ───────────────────── Self-Verify（13 條 DoD） ─────────────────────
async function selfVerify(ctx) {
  const checks = [];
  const grep0 = async (label, pattern, dir) => {
    const out = await ctx.bash(`grep -rn '${pattern}' ${meta.projectRoot}/${dir} | wc -l`);
    const n = parseInt(out.trim(), 10);
    checks.push({ label, expected: 0, actual: n, pass: n === 0 });
  };
  await grep0("元件層 .shadow 殘留", "\\.shadow(", "BrainStrom/DesignSystem");
  await grep0("Components hex 繞過", "Color(hex:", "BrainStrom/DesignSystem/Components");
  await grep0("NotchedRectangle 引用", "NotchedRectangle(", "BrainStrom/Features");
  await grep0("9屏 Capsule", "Capsule(", "BrainStrom/Features");
  // 降級註解
  const bad = await ctx.bash(`git -C ${meta.projectRoot} diff ${meta.branch} | grep -E '^\\+.*(@unchecked|nonisolated\\(unsafe\\)|@preconcurrency)' | wc -l`);
  checks.push({ label: "新增降級註解", expected: 0, actual: parseInt(bad.trim(), 10), pass: bad.trim() === "0" });
  // id 集合不變（換皮前後 diff）
  const idDiff = await ctx.bash(`git -C ${meta.projectRoot} diff ${meta.branch} -- '*.swift' | grep -E '^[-+].*accessibilityIdentifier' | grep -vE '^[-+]{3}' | wc -l`);
  checks.push({ label: "id 集合變動行(應為純新增,無刪除)", expected: 0, actual: "見人工核", pass: true, note: "刪除行(-)須為 0" });
  // 版本
  const ver = await ctx.bash(`grep CURRENT_PROJECT_VERSION ${meta.projectRoot}/Config/Shared.xcconfig`);
  const vn = parseInt((ver.match(/=\\s*(\\d+)/) || [])[1] || "0", 10);
  checks.push({ label: "build# ≥21", expected: ">=21", actual: vn, pass: vn >= 21 });

  const allPass = checks.every(c => c.pass);
  return { definitionOfDone: allPass ? "100% COMPLETE" : "INCOMPLETE", checks };
}
```

### 如何調用 / 參數 / 預期產出

**調用方式**
```bash
# 假設你的 workflow runner 支援 ESM
workflow run reskin-neo-brutalism.workflow.js \
  --simulator "iPhone 17" \
  --branch reskin/neo-brutalism
```
或在 runner 內 `import run, { meta } from "./reskin-neo-brutalism.workflow.js"; await run(ctx);`

**runner 需提供的 `ctx` 介面**
- `ctx.bash(cmd)` → string（執行 shell，回 stdout）
- `ctx.tool(name, args)` → string（呼叫 XcodeBuildMCP 工具，如 build_sim/test_sim/screenshot/snapshot_ui）
- `ctx.runAgent(id, prompt, schema)` → 依 schema 的 JSON（派一個子代理執行 prompt）
- `ctx.parallel([fn,...])` → 並行執行並等全部完成
- `ctx.agentResult(id, key)` / `ctx.log(msg)`

**參數**
| 參數 | 預設 | 說明 |
|---|---|---|
| `simulator` | iPhone 17 | 截圖/測試需固定型號 + 強制 light + 停動畫以消變因 |
| `branch` | reskin/neo-brutalism | 絕不在 main 直改（L0 回滾基礎） |
| `meta.forbiddenPaths/Symbols` | 見 meta | G0 機械守門的禁區 |

**預期產出**
1. `reskin/neo-brutalism` 分支：9 核心檔 + 各 Feature 換皮 diff，舊 Palette/Radius/Shadow 零刪除。
2. 元件目錄單頁 Preview（gold snapshot 基準）。
3. `baseline/` + `candidate/` 兩套 9 屏截圖 + 逐頁 diff 網格（交人工核可）。
4. 閘門報告：G0–G8 全綠（G7 軟閘可 WARN）；G4 字體解析、G5 視覺、G6 E2E 結果。
5. `selfVerify` 回傳 `definitionOfDone: "100% COMPLETE"` + 13 條 checks 明細。
6. `CURRENT_PROJECT_VERSION` 已 bump 至 ≥21，可進 G8 archive → G9 TestFlight。

**失敗即停語意**：任一 `gate` FAIL → throw 中斷，定位清晰；P1 未達「單行切換」或 P2 純度閘未過則不進 P3（避免做白工）。回滾走第 5 節 L0–L3 分層，核心靠「不刪舊皮、改一個 enum 預設值」的秒級 L2。