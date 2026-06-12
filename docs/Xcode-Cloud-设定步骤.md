# Xcode Cloud 设定步骤（云端 build → TestFlight）

> 目的：push 到 `main` → Xcode Cloud 自动 build + 测 + 上 TestFlight，本地 Mac 挂了也能继续。
> 仓库这边已备好：`ios-app/ci_scripts/ci_post_clone.sh`（云端 clone 后自动产出 gitignore 的 Config.xcconfig）。
> ⚠️ 仅以下「GUI 点击」步骤需要人在 App Store Connect / Xcode 操作（Xcode Cloud 没有公开 CLI，无法纯脚本建立 workflow）。

## 已自动备妥（在 git 里，不用再弄）
- `ios-app/ci_scripts/ci_post_clone.sh`：从环境变数 `AI_AUTH_TOKEN` / `AI_USE_STUB` 产出 `ios-app/Config/Config.xcconfig`（URL 已内建 fly 网址）。
- 共享 scheme `BrainStrom`、Team `LW2X29H563`、Bundle `com.brainstrom.ios`、ExportOptions.plist：都在。

## GUI 步骤（在 Xcode 或 App Store Connect 点）
1. **Xcode → 打开 `ios-app/BrainStrom.xcodeproj` → Product ▸ Xcode Cloud ▸ Create Workflow**（或 App Store Connect ▸ 你的 App ▸ Xcode Cloud）。同帐号若另一专案设过，照同样流程。
2. **绑定来源**：选 GitHub repo `Kentliuai07/BrainStrom`，**分支 `main`**，授权 Xcode Cloud 存取（GitHub App 授权）。
3. **Workflow 设定**：
   - Start Condition：Branch Changes → `main`（push 即触发）。
   - Environment：macOS + 最新 Xcode；scheme = `BrainStrom`。
   - Actions：① **Build** ② **Test**（iOS Simulator，跑 BrainStromTests + BrainStromUITests）③ **Archive**（Release）。
   - Post-Action：**TestFlight（Internal Testing）** 自动散布。
4. **环境变数（关键）**：在 workflow 的 Environment ▸ Environment Variables 新增：
   - `AI_AUTH_TOKEN` = （后端 dev token，见记忆 `brainstrom-fly-backend` / 或 `web/src/config.js` 的 authToken）→ 勾 **Secret**。
   - `AI_USE_STUB` = `NO`（要真后端；省钱可设 `YES` 跑 stub）。
   - （选）`AI_BASE_URL` = `https://brainstrom-ai.fly.dev`（不设则用脚本内建值）。
5. **签章**：Xcode Cloud 用 App Store Connect 托管签章（自动），Team 选 `LW2X29H563`。首次会要你同意建立 signing assets。
6. **存档并跑一次**：Save → Start Build。绿了就会自动上 TestFlight。

## 之后的云端流程
云端 Claude Code（或任何人）改 Swift → `git push origin main` → Xcode Cloud 自动 build+测+上 TestFlight，**不需要你的 Mac**。

## 注意
- 云端 Claude Code（Linux 容器）**本身不能 build iOS**（无 macOS/Xcode），只能改码+push；真正的云端 build/部署靠 Xcode Cloud。
- `ci_post_clone.sh` 已处理 gitignore 的 Config.xcconfig；若云端 build 报「缺 AIAuthToken / 退回 Stub」→ 检查 workflow 的环境变数 `AI_AUTH_TOKEN` 有没有设。
- bump 版号：Xcode Cloud 可用「自动递增 build number」，或继续手动改 `Config/Shared.xcconfig` 的 `CURRENT_PROJECT_VERSION`。
