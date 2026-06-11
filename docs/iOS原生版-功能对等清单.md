# iOS 原生版 · 功能对等清单（从网页版真实代码盘点，2026-06-11）

> 用法：iOS 每做一个画面，照本清单逐条勾选；行号是 web/src 源码出处（行为有疑义时回去看代码）。
> 格式：触发动作 → 系统反应。只收「网页版现在真的能用的」。

## 1. 登入页
- [ ] 启动：已有登入态 → 直接进首页；无 → 登入屏（main.js L44-50）
- [ ] 「使用 Apple 登入」：钮禁用＋「登入中…」→ signInWithApple（dev 模拟）→ 进首页（L61-71）

## 2. 首页
- [ ] 横幅：阶段提示文案（L83）
- [ ] 笔记卡：私密/公开徽章＋更新时间(MM/DD)＋标题＋摘要(前 60 字)＋标签；按 updatedAt 倒序（L95-101, L274-275）
- [ ] 点卡 → 进笔记文章视图（L102）
- [ ] ＋ 新建 → `systems.create('')` 空标题 → 进笔记并落入命名态（L82, L88）
- [ ] 空清单：📓＋「还没有系统」＋「建立第一个系统」钮（=＋行为）（L92-94）
- [ ] 设定齿轮 → 设定页（L81, L86）

## 3. 笔记页·命名态（F9 gate）
- [ ] gate 条件 = 零块 且（空标题 或 标题==='未命名系统' 旧壳）（L184-187）
- [ ] 名称 placeholder「先给这个点子取个名字」（L250）
- [ ] 「先随便取」钮 → 填「M/D 随手记」＋自动提交解锁（L310-317）
- [ ] 名称提交（blur/Enter）：非空→存＋解锁；空名+有块→回填「未命名系统」；空名+零块→保持空维持命名态（L280-305）
- [ ] 命名态禁用：fab/✦/▦/💬 全禁；正文只显示「✏️ 先给这个点子取个名字，就能开始写」；续写区不渲染（L189-191, L252-254）
- [ ] 返回时：空名+零块 → 软删＋toast「空笔记已丢弃」；有块空名 → 回填保留（L199-212）

## 4. 笔记页·文章视图
- [ ] 标题 textarea：自适应高、Enter 提交、blur 规则同上（L250-260, L280-305）
- [ ] 点段落 → 就地变 textarea 编辑；blur **有变才落一步**（saveVersion('cardEdit')+update），无变只收起（L488, L515-531）
- [ ] text 块=段落；heading 块=标题样式（level2 较小）；todo 块=勾选框+文字（打钩落版本）；模组块=「📌 模组·type」＋payload 摘要(前140字)、恒钉选无开关（L459-463, L472-485）
- [ ] 📌 钉选：仅 text/heading 有开关，右上工具列；toggle＋toast＋重画；钉选块有边框/标记（L467-470, L492-498）
- [ ] ▲▼ 移动：交换相邻块＋saveVersion('cardEdit')＋重画（L506-513）
- [ ] 删除：saveVersion('delete')＋删块＋重画（L500-505）
- [ ] 续写区：placeholder「继续写…（空行分段、# 开头成标题）」；blur 非空 → saveVersion('cardEdit')＋splitIntoBlocks 切块逐个 add → reload（L255, L269-276）
- [ ] 切块规则：连续空行=段界；行首 # 独立成 heading（#>1 → level2）；``` 围栏内不切（mockClient L19-38）
- [ ] >2000 字段落编辑时显示「⚠ 建议拆分」（L40, L517）
- [ ] savechip「已储存」1.2s 消失（L127, L688）

## 5. 顶栏
- [ ] ←返回（触发命名态清理）（L114, L143）
- [ ] 私密/公开切换：lock/globe 图标＋色（L120, L166-169）
- [ ] ↶↷：undo/redo＋reload；不可用时禁用（L118-119, L172-175, L238-240）
- [ ] 「文章|卡片」分段：未 carded 时卡片禁用＋title 提示；切换存 sessionStorage（L116, L213-225）

## 6. ⚡ 点子助攻（Step 3.6）
- [ ] 胶囊条件：prefs.ideaNudge!==false 且 nudge.state==='pending' 且标题非空（L320-321）
- [ ] 位置：标题正下方 inline 胶囊「⚡ 让 AI 教练看看这个点子」＋✕（L322-324）
- [ ] 按下：nudge→'opened'＋胶囊收起＋开聊天面板＋kickoff 串流；完成存 nudge.opening 快照（L339-383）
- [ ] ✕：→'dismissed' 淡出＋toast「不再为这则笔记显示（设定页可关闭）」，该笔记永不再自动出现（L326-333）
- [ ] 面板头部 ⚡（state!=='pending' 时显示）：nudgeHash 同 → 注入 opening 重播（零成本，前缀「上次的教练点评（内容没变，未消耗 AI）」）；不同 → 重新 kickoff＋更新 hash/opening（L132, L384-407）
- [ ] 设定页「点子助攻」开关 OFF → 胶囊与面板 ⚡ 都不显示（L779-791）

## 7. 💬 聊天面板
- [ ] dock 💬 开/「收合 ▾」关（L123, L145, L149）
- [ ] 气泡：user 右/ai 左、pre-wrap（L704-708）
- [ ] 送出（进行中禁用）/停止（进行中出现，abort）/输入框锁定（L137-138, L152-153, L711-715）
- [ ] 每条 AI 气泡下「tokens: in X / out Y」；命中显示「引用到 M 张卡」徽章（L362, L731-732）
- [ ] proposal 按钮列（AI 气泡下横排）：structure→关面板＋runStructure；edit_text→runApplyEdit(instruction)；find_github/find_youtube/find_info 锁定→toast「即将推出」；点过任一钮整列禁用（锁定项除外，点了只 toast）（L408-427, L411, L417-419）
- [ ] 历史只存内存（chatMsgs）、切笔记清空（L110-111）

## 8. ✦ 优化
- [ ] 确认框「要不要顺便分主题、加小标题？」三选项：要/不要/取消（L608-624）
- [ ] 进行中：半透明遮罩＋顶部进度条＋「AI 整理中…」；✦▦💬fab↶↷ 全禁（L167-174, L626-630）
- [ ] 三种结果 toast：「已优化 N 段」/「内容没变，未消耗 AI」（hash gate）/「变动过大，已保留原内容」（safety_valve）（L653, L351, L631-635）
- [ ] 完成 reload 重渲染；↶ 可整批撤销（L654）

## 9. ▦ 结构化
- [ ] 按下自动切卡片视图（L656-663）
- [ ] card_start → 骨架卡（虚线＋闪烁占位）；card_done → 填入内容去闪烁（L668-678）
- [ ] 完成 toast「回传 N 张卡」；docState→carded → 卡片页签解禁（L685, L224）

## 10. 卡片视图
- [ ] AI 卡：title 加粗卡顶＋content 卡身；点内容就地编辑（blur 有变才落步）（L556-567, L584-603）
- [ ] 模组卡：类型名＋payload 摘要（L558-561）
- [ ] 卡右上 📌（仅 text/heading）/删除（saveVersion('delete')）（L565-583）
- [ ] 未结构化空状态：说明＋一颗「▦ 卡片结构化」钮直接可按；结构化后零卡：「切回文章视图写点内容吧」（L538-549）

## 11. 设定页
- [ ] 主题切换（两款，localStorage 存）（L772-787）
- [ ] 帐号 email 显示、登出 → 回登入页（L774-775, L793）
- [ ] 删除帐号：红色危险样式＋confirm「删除将立即永久移除你的资料、无法复原」→ 回登入页（L782-795）
- [ ] AI 区块「点子助攻」开关 → auth.updatePrefs({ideaNudge})＋toast（L779-791）

## 12. 验收灯（14 盏；iOS 可做成隐藏调试页或对照网页版验收页）
| 灯 | 点亮条件 |
|---|---|
| db/read_write/rls/delete_account/frontend_skeleton | 恒亮（基础设施） |
| auth | 有登入态 |
| ai_engine | 恒亮（引擎内建/后端在线） |
| chat_note | 第一次聊天成功 |
| optimize | 第一次优化套用成功 |
| structure | 第一次结构化成功 |
| dialog_edit | 第一次 applyEdit 套用成功 |
| structure_incremental / global_recall / git_progress | 恒灭（未开发） |

## 13. 全局行为
- [ ] 离线横幅：offline 事件 →「⚠ 目前离线，变更暂存本地」；online 收起（L46-57）
- [ ] toast：1.3s 自动消失（L58）
- [ ] 视图偏好按系统 ID 存 sessionStorage；docState!=='carded' 强制回文章（L39, L164-165, L228）
- [ ] 离开笔记页 → abort 全部进行中串流（chatAbort/aiAbort）（L75-76, L110-112）

## 14. mock vs real 模式差异（iOS 对应 Stub vs Live 实作）
- health/聊天/kickoff：mock 有假实作（反映真实卡数、固定教练开场）；real 走真后端
- 优化/结构化/applyEdit：mock 模式只 toast「需要真后端」；real 走真后端
- iOS 建议：AIServicing 协议 + LiveAIService（真）+ StubAIService（开发预览用），与网页同精神
