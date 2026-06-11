# BrainStrom iOS · 設計稿包 v2「工業硬體」

> 世界觀：**App 是一台筆記儀器**（Teenage Engineering / Braun 工業語言）。
> 受眾：喜歡科技與創作的開發者——專業感＋遊戲趣味＋工業風＋克制科技感＋系統感。
> 風格基準：`v3-explore/style-e.html`（使用者拍板）。用瀏覽器打開 `index.html` 開始驗收。

## 怎麼看

1. 打開 `ios-app/design/index.html`（雙擊即可，零依賴、零網路請求）。
2. 每頁右上兩組切換：
   - **THEME**：霧面黑（預設）／暖灰機殼——同一台機器的兩種機殼，色票即 `tokens.css`。
   - **STATE**:該頁全部狀態（四態＋交互態：直條/AI 確認/進行中/聊天/版本/拖曳/串流/刪除確認…）。
3. **可以實際互動**：P2 右緣 ✦ 把手（直條）、所有撥動開關（待辦/AI 選項）、鍵帽按壓行程、P3 機殼色票。
4. 每頁右側為規格註記欄：佈局、<span style="color:#54D62C">時序</span>、<span style="color:#FFB000">觸覺</span>、<span style="color:#FF4D00">觸點</span>、無障礙。

## 檔案

| 檔案 | 內容 |
|---|---|
| `index.html` | 總覽導航＋設計原則 v2 |
| `tokens.css` | 設計 tokens v2 唯一來源（雙機殼語義色/字階/間距/圓角/動效/缺角/鍵帽行程） |
| `shared.css` / `shared.js` | 舞台＋**硬體元件庫**（鍵帽/LED/螺絲/開關/斜紋/LED 條/凹槽/銘板/直條）——舞台不進 App，元件庫對應 SwiftUI 元件 |
| `p0-login.html` | P0 登入（銘板/自檢/錯誤） |
| `p1-home.html` | P1 首頁（機架/AI 搜索/左滑刪除/四態） |
| `p2-note.html` | P2 文章視圖（★直條＋AI 確認/進行中/聊天/版本） |
| `p2b-cards.html` | P2-b 卡片視圖（板卡/拖曳/串流/空機架） |
| `p3-settings.html` | P3 設定（背板/色票/危險區） |
| `v3-explore/` | 風格探索樣張（D/E/F），E 為本包基準，留檔備查 |

## 與 SwiftUI 的對應約定

- **字體**：display=`Avenir Next Condensed`、mono=`SF Mono`、內文=SF Pro/PingFang TC——全部 iOS 系統內建，**零第三方字體**。
- **鍵帽**：`box-shadow 0 2.5px 0` 行程 → SwiftUI 自訂 ButtonStyle（offset+shadow，按壓 `.impact`）。
- **缺角**：`clip-path` → `NotchedRectangle`（卡右上 12pt、直條左上 16pt）。
- **顆粒**：SVG 噪點 → iOS 17 `.colorEffect` Metal shader 程序化生成，零圖片資產。
- **LED/掃描線/追逐條**：CSS animation → SwiftUI `TimelineView`/`phaseAnimator`。
- CSS cubic-bezier → `spring(response:0.35, dampingFraction:0.85)`；stagger 40ms。
- 註記欄 <code>觸點</code> 對應 `web/src/touchpoints.js`（凍結契約），不增不改。

## 驗收後的下一步（工作循環 §2）

設計稿確認 → 搭工程骨架（資料夾結構、DI 組合根、SwiftLint、xcconfig、String Catalog、`Tokens.swift`=tokens.css 1:1）→ 逐畫面實作，每畫面過規格書 §10 驗收清單。
