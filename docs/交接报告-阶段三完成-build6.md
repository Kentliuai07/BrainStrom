# BrainStrom · 交接报告（阶段三结构大修完成 · TestFlight build 6）

> 日期：2026-06-12 ｜ 分支：`main`（= `ios-native`，最新全量）｜ HEAD：见 `git log -1`
> 读法：先读这份 → 再读 `MEMORY.md` 指向的 `brainstrom-ios-dev-state` / `brainstrom-fly-backend` → 再读 `docs/阶段三-结构大修-开发文档.md`（v3）。

## 0. 一句话

BrainStrom = SwiftUI iOS「氛围开发笔记」App（繁中、工业橘美学、iOS 17+、Swift 6 严格并发、零第三方依赖）。后端 = Fly.io 常驻 AI 代理（Node + Anthropic SDK）。

## 1. 现在进度（已上 TestFlight build 6）

| 阶段 | 状态 |
| --- | --- |
| 一 · 能写（登入/笔记/存读） | ✅ 完成 |
| 二 · 变聪明（AI 结构化/优化/聊天/⚡/省钱闸） | ✅ 完成 |
| 三 · 结构大修（三分页/身份证/多笔记/AI教练/新建流程/主笔记锚点） | ✅ **核心全完成** |
| 四 · 上线前开发（付费/私密/真登入/媒体/社群） | ⬜ 未开始 |

**当前 App 形态**：首页（我的系统）→ ＋ 弹窗输入名称/灵感 → 专案首页（三分页：🤖AI教练 / 📝开发笔记 / 🪪系统结构）→ 单篇笔记。

## 2. 新建流程（阶段三 v3，build 6 起）

```
按 ＋ → 弹窗输入「系统名称/灵感」(home.projectNameInput) → 原子建系统+主笔记
      → 默认进 AI 教练分页，拿名称当第一句自动开场
      → 教练每则回复可：📝加入笔记(写进主笔记) / 📇记入结构(写身份证)
```
- **主笔记锚点**：`SystemEntity.primaryNoteID` 固定指向主笔记（建专案时种下）。系统结构/教练/结构化全锚定它，不再随「最近编辑」飘。身份证 = 主笔记封面。
- 旧的「笔记内取名才能写」命名闸 + ⚡名称开场 = 已删。
- 单篇笔记底部 AI 聊天面板 + 编辑能力 = 完整保留。

## 3. 关键档案地图

- **App 入口/DI**：`ios-app/BrainStrom/App/`（CompositionRoot / RootView）。
- **导航**：`Features/Home/HomeScreen.swift`（HomeRoute：settings / systemDetail(id,autoKickoff) / noteDetail(noteID)）。
- **专案三分页容器**：`Features/Note/SystemDetailScreen.swift`。
- **AI 教练**：`Features/Note/AICoachView.swift`（autoKickoff 三重闸 + coachOpen 注入名称 + 📝加入笔记）。
- **多笔记清单**：`Features/Note/NotesListView.swift`（主笔记置顶+「主」徽章）。
- **单篇笔记**：`Features/Note/NoteScreen.swift`（NoteDetailScreen）+ `NoteContentViews.swift`（ArticleView 纯写作/BlockRow/CardsView）+ `NoteChatViews.swift`（底部聊天面板）。
- **系统结构/身份证**：`Features/Note/SystemStructureView.swift`（身份证 + 结构卡片）。
- **本地文件 store**：`Features/Note/NoteDocument.swift`（活文件/版本指针 undo/redo/payload/projectContext/applyOptimize/applyStructure）。
- **AI ViewModel**：`Features/Note/NoteAIViewModels.swift`（NoteViewModel + ChatViewModel）。
- **领域模型**：`Domain/Models/DomainModels.swift`（Note/Block/SystemSpec/SpecPatch/ProjectContext…）。
- **算法**：`Domain/Algorithms/`（TextHashing fnv1a UTF-16 / SafetyValve / BlockSplitter / ApplyPipeline）。
- **持久化**：`Data/Persistence/`（SwiftData：SystemEntity/NoteEntity/Card/Revision + NotesRepository）。
- **AI 服务**：`Domain/Services/AIServicing.swift`（协议）+ `Data/AI/`（AIServiceLive 真后端 / AIServiceStub / SSEParser）。
- **后端**：`server/src/index.js`（单档 348 行，Node + @anthropic-ai/sdk，SSE）。
- **文档**：`docs/阶段三-结构大修-开发文档.md`（v3，权威）。

## 4. 怎么接手 / 验证 / 部署

```bash
git checkout main && git pull
cd ios-app
# 本地连线参数(gitignore)：从 example 复制并填真值
cp Config/Config.example.xcconfig Config/Config.xcconfig   # 填 AI_USE_STUB=NO, AI_AUTH_TOKEN(见记忆), AI_BASE_URL
```
- **build / 测试**（Mac + Xcode）：XcodeBuildMCP `build_sim` / `test_sim`（65 测试全绿，含 E2E `CoreFlowUITests`）。模拟器 iPhone 13 Pro。
- **上 TestFlight**：bump `Config/Shared.xcconfig` 的 `CURRENT_PROJECT_VERSION` → `xcodebuild archive`（Release, generic/platform=iOS, -allowProvisioningUpdates, Team `LW2X29H563`）→ `-exportArchive`（ExportOptions.plist）→ `xcrun altool --upload-app`（密码：keychain `AC_PASSWORD` / `kentliuai08@gmail.com`）。
- **云端 build→TestFlight**：见 `docs/Xcode-Cloud-设定步骤.md`（已备 `ios-app/ci_scripts/ci_post_clone.sh`）。

## 5. 剩余可开发（按优先序）

**阶段三收尾（选项，非核心）**：
1. 🔗 连结/YT 真读取（find_youtube/github/info 现为占位）——**需先升级 `server` 的 `@anthropic-ai/sdk` 0.39→最新**（要 web_fetch server tool），升级后回归测 optimize/structure/chat。
2. 教练「总结后加入笔记」（目前只做整则加入）。
3. 多笔记「合并结构化」（目前只整理主笔记）。

**阶段四 · 上线前开发（全新）**：真 Apple 登入、付费会员（Apple 订阅）、公开/私密真上架、语音/媒体、社群市集。详见 roadmap.md。

## 6. 已知限制 / 注意

- 旧专案（build 5 前建）的「主」徽章/系统名同步，要先进过一次「开发笔记」分页触发 primaryNoteID 回填才完全生效；新建专案无此问题。
- `server` 用的 SDK 0.39 偏旧（仅挡连结工具，其余正常）。
- 铁律：token/金钥永不进 git；Config.xcconfig 永远 gitignore；后端金钥只在 Fly secrets。
- 沟通：全程国中生白话文，每则回覆附白话总结。

## 7. 关键事实速查

- Team ID = **LW2X29H563**（46VX4B23QY 是个人证书、非 Team）。
- App-specific 密码在 keychain：`security find-generic-password -s AC_PASSWORD -a kentliuai08@gmail.com -w`。
- 后端：`https://brainstrom-ai.fly.dev`（health `GET /ai/health`），`cd server && fly deploy`；flyctl 在 `~/.fly/bin`。
- Bundle ID：`com.brainstrom.ios`。
