# BrainStrom · iOS（SwiftUI 原生）

这是用**原生 SwiftUI** 写的 BrainStrom 笔记页，对应已认可的设计方向：
**Apple Notes 质感的文档式笔记页 + Notion 风格的「加模组」面板**（模组为氛围开发专用）。

> 原生意味着：真 SF Pro 字体、真苹方中文、真 SF Symbols 图标、系统毛玻璃和滚动。
> ⚠️ 这些代码是在一个 Linux 云端环境里写的，**无法在那边编译/截图**。请在你的 **Mac + Xcode** 上预览。

## 怎么跑（两种，挑一种）

### 方式 A：Xcode 预览（最快，30 秒）
1. Xcode → File → New → Project → **iOS App**，Interface 选 **SwiftUI**，命名 `BrainStrom`。
2. 把本目录 `BrainStrom/` 下的 `.swift` 文件**拖进项目**（删掉 Xcode 自动生成的 `ContentView.swift`，并保留我这份 `BrainStromApp.swift` 作为入口，或只替换内容）。
3. 打开 `NoteView.swift`，右上角开 **Canvas（⌥⌘↩）** → 看 `#Preview`。
4. 点底部中间的渐变 **＋** 会弹出「加模组」面板。

### 方式 B：真机 / 模拟器
直接 Run（⌘R），首页就是这一页笔记。

## 文件结构

| 文件 | 内容 |
|---|---|
| `BrainStromApp.swift` | App 入口，根视图 = `NoteView` |
| `Theme.swift` | 配色 / 渐变 / 阴影（暖白纸面 + 品牌渐变 + Apple Notes 黄） |
| `Models.swift` | `Category`(6 分类)、`Block`(块/模组)、`Note` + 示例数据 |
| `Modules.swift` | 内嵌模组视图：心智图、GitHub、待办清单 |
| `NoteView.swift` | 笔记主页：大标题、块流、底部工具栏、影片模组 |
| `AddModuleSheet.swift` | 「加模组」底部面板（氛围开发模组 + 基础块） |

## 已实现
- 文档式笔记页：居中日期、大标题、正文高亮、加粗小标题
- Apple Notes 黄色待办圈（**可点击勾选**）
- 正文流内嵌模组：心智图（原生绘制）、GitHub 书签卡
- 底部 Apple Notes 式工具栏，中间渐变 ＋ → 弹出加模组面板
- Notion 风格加模组面板：搜索 + 氛围开发模组（心智图/影片/GitHub/代码/AI 分析）+ 基础块

## 还没做（下一步备选）
- 空白新笔记 / 文件夹（书架）列表层
- 选中模组后真正「插入到光标位置」的逻辑
- AI 分析模组的实际生成
- 接入第一层「主题专属 AI」记忆（见 `../docs/memory-architecture.md`）

## 开发约定
- 目标 iOS 17+（用到 `presentationDetents`、`.ultraThinMaterial` 等）。
- 纯 SwiftUI，无第三方依赖。
- 设计参照：`../mockups/ios/shots/note.png` 与 `note-add.png`。
