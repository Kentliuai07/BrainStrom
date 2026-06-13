# BUILD 12 · 竞品搜寻拆 3 轨（竞品产品 / 相关文章 / 相关开源）开发方案

> 来源：6 探勘代理 + 链式对抗审查（5 轮 / 22 代理）。计划自评 96，最终三审查 92/90/93、零致命 blocker。
> 缺口（92 而非 98）= Exa 文章召回品质 + 运营步骤，非代码风险。

## 问题根因（实测）
1. 竞品轨用「不限类别」Exa 搜 → 文章混进产品（vocus/部落格）。
2. github 轨**漏带 summaryQuery** → 前端只剩 `owner/repo`，看不懂。

## 解法
3 轨 `Promise.allSettled`：🥊`category:company`(source web) / 📄`term+' 評測'`(source article) / 🧰`category:github`+summaryQuery(source github)。前端拆 3 区，文章点击=开浏览器不持久化。

## 16 步（锚点字串为准，行号仅参考）

### 后端 server/src/index.js
1. 行430 `const competitors = [], openSource = [];` → 加 `articles`：`const competitors = [], articles = [], openSource = [];`
2. 行434-437 `const [web, repos] = await Promise.allSettled([...]` 整段换成：
   ```
   const [company, articlesRes, repos] = await Promise.allSettled([
     exaSearch(term, { type: 'auto', numResults: 8, summaryQuery: '這個產品/App 一句話在做什麼？用繁體中文，30字內' }),
     exaSearch(term + ' 評測', { type: 'auto', numResults: 8, summaryQuery: '這篇文章在講什麼？用繁體中文一句話' }),
     exaSearch(term, { category: 'github', type: 'auto', numResults: 8, summaryQuery: '這個開源專案在做什麼？用繁體中文，30字內' }),
   ]);
   ```
   解构名一律 `[company, articlesRes, repos]`（勿与收集阵列 `articles` 重名 → SyntaxError）。轨3 必须补 summaryQuery（与步骤5 耦合）。
3. 竞品 if 块 `web` → `company`（`web.status`→`company.status`、`for (const r of web.value)`→`company.value`）；source 仍写 `'web'`；上限 `>= 6` → `>= 5`。
4. 竞品 else 块后新增 articles 收集回圈：
   ```
   if (articlesRes.status === 'fulfilled' && Array.isArray(articlesRes.value)) {
     for (const r of articlesRes.value) {
       if (!r.url || seen.has(r.url)) continue;
       if (repoName(r.url)) continue;
       seen.add(r.url);
       articles.push({ source: 'article', title: String(r.title || hostOf(r.url)).slice(0, 80), url: r.url,
         subtitle: hostOf(r.url), summary: (String(r.summary || r.text || '').trim() || null), score: null });
       if (articles.length >= 5) break;
     }
   } else { partial = true; }
   ```
   （summary 已折入 `||r.text` 兜底。）
5. 开源 push 的 `summary: null` → `summary: (String(r.summary || r.text || '').trim() || null)`；上限 `>= 6` → `>= 5`。
6. 回传 `items: [...competitors, ...openSource]` → `items: [...competitors, ...articles, ...openSource]`，并加 `articles` 字段。

### 前端
7. DomainModels.swift 行84 source 注释加 `article`（零代码改动）。
8. **Domain/Services/AIServicing.swift**（实际路径，非 Data/AI）：零改动，确认 `Resp{items:[CompetitorItem]}` 契约，前端只吃 items。
9. AICoachView.swift 行195-198 竞品区 2 区 → 3 区（apps/articles/repos 三 let，各被一个 competitorGroup 消费）：🥊競品產品 / 📄相關文章 / 🧰相關開源。
10. AICoachView.swift 行19 后新增 `@Environment(\.openURL) private var openURL`。
11. competitorChip Button action（行230-231）按 source 分流：
    ```
    if c.source == "article" {
        if let u = URL(string: c.url) { openURL(u) }
    } else {
        d.addCompetitors([c]); competitorResults.removeAll { $0.url == c.url }
        root.toast.show(String(localized: "已記入競品"))
    }
    ```
12. chip emoji（行235）三态 switch（github 🐙 / article 📄 / default ""）；空态按钮文案 → `🔍 幫你找競品 / 文章 / 開源`。
13. AIServiceStub.swift findCompetitors 改 3 笔（含 article 笔 + github 补 summary）。
14. SystemStructureView.swift 行124 竞品列 emoji 三态（防御性）。

### 测试 + 部署
15. SystemSpecTests.swift 末尾加 `testArticleSourceRoundTrip` + `testArticleSourceDecodesFromRawJSON`（基准+2 全绿，不写死数字）。
16. Config/Shared.xcconfig 行13 `CURRENT_PROJECT_VERSION = 11` → `12`。

## 测试计划
- 施工前 test_sim 记基准通过数；改后 = 基准+2 全绿。
- 后端 node 起服务验无 SyntaxError；`POST /find/competitors {keywords:'健身'}` jq 验 items 含 web/article/github 三 source、顺序 [competitors,articles,openSource]、article 笔无 github 链接、无跨轨重复 url。
- 英文产品词（Notion）手测 article 区不全是农场文，劣化则回退纯 term。
- 无 EXA_API_KEY 路径：competitors/articles 空、partial=true、openSource 走 githubKeywordSearch 不崩。
- build_sim 零 warning（warnings-as-errors）；#Preview 看 3 区有料；点 article chip 开浏览器不写身份证、点 web/github chip 维持原行为。

## 部署（顺序钉死）
1. 后端先 `cd server && fly deploy -a brainstrom-ai`；curl 确认 items 含 article。
2. test_sim = 基准+2 全绿。
3. build_sim 零 warning → `xcodebuild archive`（Release, generic/platform=iOS, -allowProvisioningUpdates, Team LW2X29H563）→ `-exportArchive`（ExportOptions.plist）。
4. `xcrun altool --upload-app`（凭证：keychain AC_PASSWORD / kentliuai08@gmail.com）。

## 残留风险（皆非代码硬伤）
- Exa 文章/开源 summary 偶尔为 null → chip 退显示网址（外部不可控，已 r.text 兜底）。
- article 召回品质对英文词可能掺农场文 → testPlan 有回退预案。
- 部署顺序：后端必须先于 TestFlight，否则 📄区空白（已钉死步骤）。
