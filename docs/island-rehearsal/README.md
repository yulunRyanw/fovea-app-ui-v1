# 岛过渡排练（第二版，2026-09-11，逐帧复查后）

引擎的壳，我们的流程：形状、几何规则、一块表面的宿主方式、运动参数、拖出引擎来自设计同事的岛引擎（`Sources/Fovea/Island/`）；录音触发（按住说话、松手提交）、录音条、处理轨、送达行、「已为你保留」卡、摘要卡、完整面板、阅读态、左 Control 的含义、Esc 的含义全部按产品现状与 `RECONCILIATION-island-engine-vs-product.md` 的定案。内容来自本机真实 Codex 对话。

## 这个文件夹里有什么

| 文件 | 用途 |
|---|---|
| `rehearsal.mp4` / `rehearsal.gif` | 实速录屏，十八步一遍 |
| `rehearsal-slow5x.mp4` | 同一遍流程，所有岛动画放慢 5 倍录的，用来看过渡细节 |
| `transitions-slow5x/t02…t18.png` | 每个过渡的逐帧图（放慢 5 倍、隔一帧取一张、从触发那一刻开始），文件名写明是哪一步 |
| `stills/step-01…18.png` | 每步稳定后的截图 |
| `steps.tsv` | 步号与说明 |
| `review-crops/` | 按你截图的部位裁出来的七张：会话选择、已选会话的录音条、摘要卡、完整面板、阅读态、浮卡、保留卡 |
| `Fovea Island Rehearsal.app` | 双击打开排练台（指向 `fovea-island-ui/build/`） |
| `排练台.png` | 排练台窗口的样子 |

## 逐帧复查的结论与修正

这一轮把每个过渡都按触发时刻对齐、逐帧看过（实速一遍、放慢 5 倍一遍）。发现并修掉三处：

1. **两个形状叠在一起**：之前黑色表面和圆角是按「当前阶段的内容」各画一份的，切阶段时旧内容和新内容各带一块黑面同时存在 0.14 秒，表面根本没有变形，只是两块不同大小的黑面互相淡入淡出。现在整块表面只有一份，宽、高、耳朵、底角都随弹簧连续变形，内容在里面交叉淡入淡出。
2. **过渡不平滑**：内容淡入淡出用的是同事引擎的自定义动画修饰器，在这个宿主里旧内容不会淡出（停在原地到时间一到直接消失）、新内容要等旧内容走完才开始淡入，中间有一段空黑面。改成系统自带的透明度加缩放过渡后，两者同时进行；原设计里 4 pt 的模糊没有系统过渡可用，去掉了（0.14 秒里看不出差别）。
3. **录屏本身**：抓屏在主线程、PNG 编码拖慢帧率（8–11 fps）导致视频忽快忽慢。现在抓屏在后台线程、三个编码线程并行，实速 28 fps，视频按真实时间戳编码；`FOVEA_SLOW_MOTION=5` 可把所有岛动画放慢 5 倍录制。

另外补齐：VoiceFlow 录音条在有附件时显示附件数（与生产一致，波形相应变窄）；摘要卡在还没有任何进展时显示所提的问题，而不是一句占位文案。

按你看图后的两条意见再改：
- 身份条：官方彩色 Codex 图标（与生产 `CodexMark` 同一张图）+ 标题 + 状态 + 权限模式全文「Approve for me ∨」+ ×。模型不再在身份条重复，改在问题下方的归属行「使用 GPT-6-Astra · 最高 ∨」显示，生产从那里开模型选择。固定问题只显示说的话，不显示随问题发出的材料块。
- 阅读态：不再是 720 宽居中一栏，身份条、问题、附件、归属行、正文、进度行、动作行全部对齐同一组 40 点边距、用满页宽；正文 15 号、行距 7，问题 16 号最多 5 行。

再按你 0911 晚的四条改：
- 身份条改两行：第一行图标 + 标题整行 + 状态 + ×；第二行模型胶囊与权限胶囊，都写全文。模型选择就在这里（放在归属行会随正文滚走）。
- 正文改用生产的渲染器（`Sources/FoveaCore/Resources/AnswerContent/`，与 fovea-mac 同一份页面）：表格、代码块、公式、深色配色与产品完全一致；页面加载前先显示纯文本，和产品一样。
- 会话选择进了排练（第 3、4 步）。按引擎的做法：录音条原地不动、保持紧凑宽度居中，会话选择作为一块高一级的圆角面板从它下面落下，里面是引擎选择器的排法（说明文字在左、动作在右、搜索框、扁平行、页脚）。「新建」按已连接的回答方逐个给胶囊（Codex、Claude Code；Cursor 接上后自动出现），会话行与选中后的胶囊都带各自回答方的图标。会话是本机真实的 Codex 与 Claude Code 会话。引擎设计语言的小结见取舍文档第七节。
- 摘要卡定为三行：状态 + 用时；一行内容；谁在回答（Codex · 模型，工具运行时加返回次数）+ 键帽。去掉「Quick Answer」字样与提示句。
- 身份条定为一行：图标 + 标题吃满剩余宽度，右边模型胶囊、权限胶囊、×；窄面板只写模型名，阅读态写全。

本轮（0911 晚第二次）只改了这三页，视频与截图按实速重录了一遍，放慢 5 倍的过渡条带仍是上一轮的。
- 按键提示改成键帽符号加动词：「L⌃ 收起」「L⌃ ×2 阅读」「esc 完整」，与录音条上的「L⌃」键帽同一种样式；这是 macOS 的标准写法（菜单与 Raycast、Spotlight 都用键帽符号；苹果对「按两下」用文字，如听写设置的「按两下 🌐」）。

上一版说明里「正式版 Fovea 同时在跑时它的录音岛会出现在同一位置」这一条，经核对当时并不成立（它只剩一个 38×24 的菜单栏窗口），叠影的真实原因就是上面第 1 条。

## 排练台（交互测试程序）

双击 `Fovea Island Rehearsal.app` 现在直接打开「Fovea 岛排练台」窗口，岛照常长在刘海下面，窗口里可以：

- **流程**：十八步列表，点任一步直接跳到那一步（前面的步骤瞬间重放）；上一步 / 下一步 / 自动播放 / 从头。
- **按键**：窗口在前面时，真实按键直接作用于岛——左 Control 单击与双击、Esc、方向键、回车、打字（会话选择里的搜索）。也有按钮：按住提问键 / 松手、按住 VoiceFlow / 松手、左 Control、左 Control ×2、Esc。
- **回合**：回答方那一侧发生的事按按钮触发——已回答 / 已送达 / 没有输入框（保留卡）/ 关掉保留卡；工具开始 / 一条进展 / 工具返回 / 工具结束 / 回答完成 / 回答失败 / +3 附件；拖出 / 靠近岛 / 就位 / 贴回 / 关闭会话。
- **数据**：案例下拉框换本机真实回合（默认是带表格与代码的长回答，另有八条长短不一的真实回答）；流式速度滑杆。
- **显示与录制**：动画放慢 1× / 2× / 5×；开始 / 停止录屏（存到 `fovea-island-ui/rendered/`）。
- **状态与事件**：当前阶段、密度、去向、高亮，以及岛收到的事件流水（去掉了指针与逐字流式的噪声）。

命令行：`FOVEA_REHEARSAL_DATA=$PWD/rehearsal-data.json swift run Fovea --demo island-rehearsal:console`。

## 运行

```bash
swift run Fovea --demo island-rehearsal            # 手动：空格下一步
swift run Fovea --demo island-rehearsal:auto       # 自动播放
FOVEA_REHEARSAL_DATA=$PWD/rehearsal-data.json swift run Fovea --demo island-rehearsal:record,ephemeral   # 实速录屏到 rendered/
FOVEA_SLOW_MOTION=5 FOVEA_REHEARSAL_DATA=$PWD/rehearsal-data.json swift run Fovea --demo island-rehearsal:record,ephemeral   # 放慢 5 倍录屏
APP_NAME="Fovea Island Rehearsal" BUNDLE_ID="app.fovea.prototype.rehearsal" REHEARSAL_DATA="$PWD/rehearsal-data.json" scripts/bundle-app.sh release   # 双击即进排练的程序
```

按键：空格下一步；左 Control 单击 摘要卡 ↔ 完整面板；左 Control 双击 进入阅读态（阅读态里单击回完整、双击回摘要）；Esc 先退回完整，再按关闭；⌘R 从头再来。

## 十八步

1 静息（岛不显示）· 2 按住提问键：录音条（波形、去向「自动 L⌃」、附件数、Esc）· 3 录音中按左 Control：会话选择（「自动」「Codex +」、搜索与筛选、三列本机会话卡片、键盘提示）· 4 ↓ 移动、回车：选中旧会话，胶囊换成会话名 · 5 松手：处理轨 · 6 岛长出摘要卡 · 7 回合进行（工具调用、公开进展行、正文流式）· 8 左 Control 单击：完整面板 · 9 双击：阅读态 · 10 单击：回完整 · 11 单击：收起摘要卡 · 12 VoiceFlow 按住：让位成录音条 · 13 松手：处理 → 已送达 0.55 秒 → 摘要卡回来 · 14 VoiceFlow 没有输入框：「已为你保留」卡 · 15 关掉保留卡：摘要卡回来 · 16 展开后拖出成浮卡 · 17 拖回岛 · 18 Esc 关闭。

会话选择里：↑ ↓ ← → 移动高亮（三列）、回车选中、Delete 与打字改搜索、Esc 关闭；录音中左 Control 只有这一个含义，双击不生效。

## 正文渲染器（不在仓库里）

正文用的是产品的渲染器（fovea-mac 的 `AnswerContent/`：Markdown、表格、代码块、KaTeX 公式、深色配色），它是产品代码，不放进这个公开仓库。把那个文件夹放到 `Sources/FoveaCore/Resources/AnswerContent/`（已在 .gitignore 里）就会用它渲染正文；没有它时正文以纯文本显示，其余界面与流程不受影响。需要的话向 Fovea 团队要这个文件夹。

## 数据

`rehearsal-data.json`（不入库）由 `design-prototypes/real-data/render-fixture.json` 生成：问题与回答取最长的一条真实回答（3242 字，按 5 字 / 45 毫秒流式），材料、工具、公开进展行取当前轮。没有数据文件时退回内置示例。

## 已知限制

- 排练里的处理阶段由脚本结束（`processingFinished`），生产里由真实回合结束。
- 拖出成浮卡的一瞬间，岛面收缩和浮卡出现是同时开始的，会有零点几秒两者相邻；这是引擎的撕下机制，保留原样，看视频时留意一下是否接受。
- 每次录屏在 `fovea-island-ui/rendered/` 留下约 1 GB 的逐帧 PNG（不入库）；磁盘满了录屏会悄悄丢帧、丢截图，录前清理。
- 正文页面第一次出现时（第 8 步展开）会先显示约 0.2 秒纯文本再换成渲染结果，与产品一致；之后在完整、阅读态、浮卡之间切换用的是同一个页面，不再重新加载。

## 移植到生产的状态（0911 深夜）

这套壳与流程已经整体移植到 fovea-mac 的开发分支 `feat/qa-island-engine-20260912`（工作树 `fovea-mac-island-engine-20260912`，基于 `feat/codex-conversation-continuity-20260908` 的 935fa71；尚未推送、尚未合并）。分六段提交：一个静态窗口一块变形表面与耳朵形状；回答由岛控制器承载（回合优先、结束后回来）；阅读态、展开键单双击、Esc 顺序、键帽、三行摘要卡；会话选择面板按引擎语言重排；拖出成浮卡与从接收区贴回。岛相关五个测试类 98 项通过。排练里的十八步在生产里对应同一套按键与阶段；真机走查由用户在新构建上做。

排练程序与生产的已知差异：排练的处理阶段由脚本结束，生产由真实回合结束；排练的浮卡由引擎的显示链驱动，生产的浮卡是真实的 `WidgetPanel` 窗口（同一键、同一会话），拖出时跟随指针、松手在接口 90 点内贴回，之后用窗口自身拖动靠近也能贴回。

## 引擎改动一览

`QuickAnswerPlacement.summary/.reading`、`Density.summary/.reading`、`IslandPhase.processing/.delivered/.retained`、`ProcessingOutcome`；`hotkeyUp` → 处理阶段；`transcriptFinal` 只记住文字；`toggleQuickAnswerDensity` / `doubleTapExpandKey`；VoiceFlow 从回答进入时保留回答并在 `rest()` 时回到原密度；紧凑行宽度随内容（`compactContentWidth`）；展开态圆角 12 / 22；`panelHeightFraction` 1.0；`IslandSurface` 改为单一容器承载各阶段内容（表面连续变形）；内容过渡改为系统透明度加缩放；`IslandModel.send` 对无变化的事件不再改写状态；`FOVEA_SLOW_MOTION` 放慢动画。视图：`FoveaIslandRows`（录音、处理、送达、保留卡）、`FoveaConversationPanel`（完整 / 阅读 / 浮卡）、`QuickAnswerSummaryView`。
