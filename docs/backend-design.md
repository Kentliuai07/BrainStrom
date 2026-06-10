# BrainStrom · 後端設計文檔

> ⚠️ 最新決策以 `../全局开发文件夹/` 為準：**AI 算力改放 Fly.io**（非 Supabase Edge Functions）、**語音/Whisper 延後到 v2 之後**、**加密貨幣付款取消（只用 Apple IAP）**、**市集延後 v2**。本文其餘設計仍有效。

> 來源：8 個探勘代理掃描 `mvp/brainstorm-mvp.html` 後推導。配合 `ios-structure.md`（前端）與 `memory-architecture.md`（AI 記憶）一起看。

## 0. 一句話架構

iOS App ⇄ 我們的後端 API ⇄（資料庫 + 向量庫 + Claude + 各種媒體 API + 金流）。
前端只負責畫面；**所有 AI 與資料都在後端**。

```
[iOS App] --HTTPS--> [API 層] --+--> Postgres（資料）
                                +--> pgvector（向量/語意搜尋）
                                +--> Claude API（結構化/對話/分析）
                                +--> Whisper（語音轉文字）
                                +--> YouTube / Instagram / GitHub API（媒體中繼資料）
                                +--> StoreKit / 金流（訂閱）
```

## 1. 技術選型（建議，務實優先）

| 層 | 選擇 | 為什麼 |
|---|---|---|
| 資料庫 | **Supabase（Postgres）** | 一站搞定資料庫＋登入＋儲存 |
| 向量/語意搜尋 | **pgvector**（Supabase 內建） | 全局 AI 跨筆記搜尋要用 |
| AI 模型 | **Claude API** | 結構化、對話、分析的主力 |
| 語音轉文字 | **Whisper** 類服務 | 語音模組要逐字稿 |
| 後端 API | Supabase Edge Functions 或 一個小 Node/Vapor 服務 | 放商業邏輯與金鑰（金鑰不能放 App） |
| 金流 | **Apple StoreKit**（訂閱）+ 之後加密貨幣 | iOS 訂閱必須走 Apple |
| 登入 | Supabase Auth（含 Apple 登入） | |

## 2. 資料模型（資料表）

```
users          id, email, apple_id, avatar_seed, created_at
memberships    user_id, tier(free|pro), billing_cycle, status, renews_at,
               system_cap(免費50/PRO 無限)
systems        id, owner_id, title, visibility(private|public),
               mode(free|structured), version, ai_restructure_count,
               created_at, updated_at, tags[]
blocks         id, system_id, type(systemName|techStack|...|learningPath),
               position(排序), payload(jsonb), source(manual|ai|notes|voice),
               locked(bool)        // ~20 種 type，對應前端 Block
attachments    id, system_id, block_id?, type(voice|prompt|youtube|instagram|github|image),
               payload(jsonb: url/transcript/duration/repo/stars...)
embeddings     id, system_id, chunk_text, embedding(vector), kind(note|summary)
               // 全局 AI 的索引就靠這張
chat_threads   id, user_id, scope(note|global), system_id?
chat_messages  id, thread_id, role(user|ai|ctx), content, created_at
listings       system_id, price, kind(oss|sale), likes, forks/remix_count,
               updated_at        // 探索頁
remixes        id, source_system_id, new_system_id, user_id
transactions   id, user_id, kind(subscription|purchase|remix),
               amount, method(apple|crypto), status
```

### 兩層 AI 記憶怎麼存（重點，連動 memory-architecture.md）
- **第 1 層 · 主題專屬 AI**：只讀「這一個 `system` 的所有 `blocks`/`attachments`」。內容不大時直接塞進上下文。
- **第 2 層 · 全局 AI**：把每個 `system` 壓成「重點摘要」存進 `embeddings`（kind=summary）。提問時先在 `embeddings` 做向量搜尋，撈出相關的幾個系統再回答。**免費上限 50 個系統**就是為了避免脈絡爆掉。
- 這正好回答你最早的問題：「忘了寫在哪一本」→ 用全局向量搜尋跨 `system` 找出來。

## 3. API 端點（前端會呼叫的）

**筆記 CRUD**
- `GET /systems`、`POST /systems`、`GET /systems/:id`、`PATCH /systems/:id`
- `POST /systems/:id/blocks`（插入模組／旋鈕用）、`PATCH/DELETE /blocks/:id`、`POST /blocks/reorder`

**AI（核心）**
- `POST /ai/structure` — 自由速記 → 20 張結構化卡（吃 system 全文，回 blocks）
- `POST /ai/chat/note` — 對單一系統提問（第 1 層 AI）
- `POST /ai/chat/global` — 對全部系統提問（第 2 層 AI，先向量搜尋）
- `POST /ai/summarize-link` — 丟連結自動摘要（YouTube/文章）
- `POST /ai/search-similar` — 「有人做過嗎」跨筆記/公開庫語意搜尋
- `POST /ai/analyze` — 可行性/風險/技術評估/學習路徑（PRO）

**媒體**
- `POST /media/youtube`（拿標題/時長/字幕）、`/media/instagram`、`/media/github`（repo stars/語言）、`POST /media/transcribe`（語音轉文字）

**帳號/會員/市集**
- `POST /auth/apple`、`GET /me`
- `POST /billing/subscribe`（驗 Apple 收據）、`POST /billing/crypto`
- `GET /explore`、`POST /systems/:id/remix`、`POST /listings/:id/buy`

## 4. 權限規則（免費 vs PRO，後端強制）

| 情境 | 模型 | 進階模組(競品/預估/分析/學習) | 私密 |
|---|---|---|---|
| 免費 · 公開筆記 | 基礎模型 | 🔒 鎖 | ❌ |
| 免費 · 想設私密 | — | — | ❌ 擋→付費牆 |
| PRO · 任意 | 進階模型 | ✅ 全開 | ✅ |

- 免費上限 50 個系統；PRO 無限。
- **重點：鎖定必須在後端做**（前端的模糊只是視覺，不能當安全）。

## 5. 開發步驟（分階段，健全版）

**Phase 0 · 地基**
- 建 Supabase 專案、開 pgvector、建上面所有資料表、設 Apple 登入。
- 後端骨架 + APIClient（前端先打通一個 `GET /me`）。

**Phase 1 · 筆記能存能讀**
- `systems` / `blocks` CRUD。前端 Home + Note（自由速記）接真資料。
- 驗收：能新增系統、寫速記、重開還在。

**Phase 2 · AI 結構化（產品核心）**
- `POST /ai/structure`：把 system 全文丟 Claude，回固定 7+ 大類、~20 種 block 的 JSON。
- 防亂掰：要求 Claude 只根據筆記內容產出、找不到就留空、不可杜撰。
- 驗收：按「AI 結構化」真的生出卡片並存進 `blocks`。

**Phase 3 · 旋鈕真插入**
- `POST /systems/:id/blocks`：選模組 → 後端建一筆 block → 前端刷新。
- 驗收：旋鈕選「提示詞」會真的多一張提示詞卡。

**Phase 4 · 第 1 層對話**
- `POST /ai/chat/note`：載入單一 system 全文當上下文，回答 + 建議追問。
- 驗收：問「chunk 多大」會根據這則筆記回答。

**Phase 5 · 第 2 層全局 AI（記憶 MVP）**
- 每次結構化後，產生該 system 的摘要 → 算 embedding 存 `embeddings`。
- `POST /ai/chat/global` 與 `POST /ai/search-similar`：先向量搜尋再回答。
- 驗收：問「我那個跟發票有關的點子在哪」能跨筆記找回正確那一則 ← 這是 `memory-architecture.md` 的核心測試。

**Phase 6 · 媒體**
- YouTube/IG/GitHub 中繼資料、語音轉文字、丟連結自動摘要。

**Phase 7 · 付費牆 + 會員**
- StoreKit 訂閱、後端驗收據、權限閘門（鎖進階模組與私密）。

**Phase 8 · 探索/市集**
- 公開、Remix、購買、按讚/分叉計數、聯絡作者。

## 6. 要先驗證的風險（MVP 重點）
1. **結構化品質**：自由速記亂七八糟，Claude 能不能穩定產出乾淨 20 卡？
2. **跨筆記找回率**：全局搜尋「忘了寫在哪」準不準？（產品命脈）
3. **防幻覺**：結構化/回答不能編造，找不到要老實說。
4. **成本**：embedding 與長上下文的 token 花費，50 系統時還撐得住嗎？
5. **記憶上限**：50 個系統 / 單系統長大後，第 1 層要不要也轉成檢索式？

> 這幾條跟 `memory-architecture.md` 的待驗證清單是同一批——後端 Phase 5 就是去撞這些邊界。
