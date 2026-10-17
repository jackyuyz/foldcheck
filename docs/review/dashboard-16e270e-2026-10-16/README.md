# 首页健康仪表盘审查

本文记录修复前的审查结论。后续修复与新的验证结果见 [FIXES.md](FIXES.md)。

审查日期：2026-10-16。目标：`main` 的 `16e270e`。本轮只审查，没有修改 App、包、测试或项目配置，没有提交或推送。此目录为本轮新增的审查材料。

结论：仪表盘聚合规则和免费边界符合本次设计，Duo 真实展开状态下的左右分栏正常；建议修复以下三处问题后再做完整回归。现有测试结果不能写成“全量通过”。

## 需要修复

### P2：每次铰链状态更新都重新解码全部历史

位置：`App/Home/HomeView.swift:24–26`。

`HomeView.body` 内直接执行 `records.compactMap(\.session)`，而 `StoredSession.session` 每次访问都会 JSON 解码完整记录，包括铰链采样数据。`.observeFoldState($foldState)` 订阅持续更新的折叠状态，因此改变铰链角度时也会重复解码、聚合所有历史。代价随历史数量增长，发生在界面刷新路径上。

本机 Release 微基准，以每条 5,581 字节、包含 120 个铰链采样点的合成记录，重复执行“全部解码 + DeviceHealth”20 次，平均每次：10 条 1.72 ms，100 条 16.35 ms，500 条 83.10 ms。这是主机微基准，不是设备帧率或 Instruments 结论；足以表明这条路径不宜跟随高频铰链更新。

建议缓存已解码记录及健康汇总，只在记录变化或设备适用部件集合变化时重算；不要把每次角度、时间戳变化作为重新聚合的条件。

### P2：最大辅助字号下，环内说明与圆环重叠

位置：`App/Home/HealthDashboard.swift:21–22, 83–88`。

圆环固定为 168×168，但“满分 100”使用随动态字体放大的 `.caption`。在 Duo 内屏、最大辅助字号下，该文字横跨圆环边缘。右侧卡片正确切成了单列，因此问题集中在环内排版。

建议让圆环尺寸随字号调整，或在辅助字号下将说明移到环外，同时保留用户所选字号。[截图 04](04-inner-accessibility-text.png) 可直接复现该问题。

### P2：健康环动画未遵守“减弱动态效果”

位置：`App/Home/HealthDashboard.swift:81`。

分数变化始终使用 0.5 秒动画，没有读取 `accessibilityReduceMotion`。这不符合 `docs/foldcheck-spec.md` 的 “Reduce Motion respected”，也与现有铰链角度、音频电平等视图的处理不一致。

建议读取该环境值，在开启时取消环形填充动画。此项由代码检查确认，尚未进行辅助功能设置下的人工动画对比。

## 已确认的产品行为

- 每个部件保留最近一次真正完成的结果，之后的跳过、不适用和不可用不会覆盖它；保存的快速测试会参与汇总。
- 外屏与内屏触控分别取最近结果，再取较差者作为触控部件状态。计分按已测部件平均，整体状态取最差者。未发现本轮聚合逻辑错误。
- 仪表盘免费；点击“上次体检”仍进入付费门槛。代码中的历史、对比、PDF 和开合统计边界与规格一致。本轮未执行真实购买。
- Duo 展开时健康总览在左、部件卡片在右，没有横跨折痕；合上后为单栏。展开状态由 DeviceHub 的 Open 控件切换，截图使用实际 Duo 折叠状态，没有使用 `-FoldMock`。
- 深色模式下，橙色健康环、分数和状态徽章清楚可见。这里只做视觉检查，没有声称完成对比度或 VoiceOver 全面审计。
- 按键图标已使用 `plusminus`；旋转测试结束后恢复竖屏的修复正确。

## 文案和信息理解建议

健康环是“各部件最近已保存结果的汇总”，底下的“上次体检”是某一次完整检查，两者不同是有意的，不应改成强行一致。建议在环下补一句“根据各部件最近已保存结果汇总”，并显示“已测 4/9 项”之类的覆盖信息；把历史入口写成“最近一次完整检查”。这样也能说明为什么部分卡片尚未测试时已经有分数。

“触控 ID”符合当前中文命名，可以保留。六种语言的资源键和占位符验证通过，但这不能代替西、法、日文的母语校对。截图中折痕指标仍夹有 `(max 3)` 英文，属于后续本地化润色项。

## 本轮截图和流程

截图使用 `-ScreenshotFixtures` 隔离示例记录，未启用 `-UnlockReports`。示例分数不是真实硬件测量，不应直接作为最终 App Store 素材。每张图片均已在本轮打开检查。

| 步骤 | 状态 | 证据与观察 |
| --- | --- | --- |
| Duo 内屏，浅色、普通字号 | 正常 | [01](01-inner-light.png)：92 分与 1 个留意部件；左右分栏避开折痕 |
| Duo 内屏，深色、普通字号 | 正常 | [02](02-inner-dark.png)：环和徽章清楚，卡片布局正常 |
| Duo 外屏，浅色、普通字号 | 正常 | [03](03-cover-light.png)：单栏，部件卡片可向下滚动 |
| Duo 内屏，最大辅助字号 | 需修复 | [04](04-inner-accessibility-text.png)：卡片变单列正确；环内“满分 100”重叠 |
| 免费用户点击“上次体检” | 正常 | [05](05-history-paywall.png)：显示购买页；没有发起购买 |

### 内屏浅色

![Duo 内屏浅色仪表盘](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/dashboard-16e270e-2026-10-16/01-inner-light.png)

### 内屏深色

![Duo 内屏深色仪表盘](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/dashboard-16e270e-2026-10-16/02-inner-dark.png)

### 外屏

![Duo 外屏仪表盘](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/dashboard-16e270e-2026-10-16/03-cover-light.png)

### 最大辅助字号

![最大辅助字号下的环内文字重叠](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/dashboard-16e270e-2026-10-16/04-inner-accessibility-text.png)

### 历史入口的付费门槛

![免费用户打开历史详情后的购买页](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/dashboard-16e270e-2026-10-16/05-history-paywall.png)

## 测试结果与证据

工具链是 `/Applications/Xcode.app`，实际版本 Xcode 27.1、build `27A9275`，与要求的 RC 构建一致；原 `/Applications/Xcode-27.1RC.app` 路径目前不存在。命令均通过 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 指定工具链。

| 验证 | 结果 | 说明 |
| --- | --- | --- |
| TestsKit 包测试 | 116/116 通过 | 本轮独立运行；`DeviceHealthTests.swift` 实际有 4 个测试方法，变更说明中的“5 个”需更正 |
| FoldL10n 包测试 | 10/10 通过 | 包含六种语言的资源一致性验证 |
| Duo iOS 27.1 build-for-testing | 成功 | 测试构建有警告，不能据此重复“无警告”的结论；未逐项治理既有测试/SDK 警告 |
| Duo 仪表盘 UI 测试 | 1/1 通过 | 首次在启动阶段遇到 SpringBoard Busy，模拟器就绪后重跑通过 |
| iPhone 17 全量测试既有运行的最终结果 | 40 项，39 通过、1 失败 | 读取该轮最终 xcresult；该命令排除了 `StorePurchaseTests`，不是完整购买回归 |
| 上述失败的逐格点按测试单独复跑 | 1/1 通过 | 全量失败为 `PolishUITests.testTapModeCountsOnlyContactBeginnings`，拖动后实际 4 格、期望 1 格；目前记为未解决的测试不稳定，不能据此确定是仪表盘回归，也不能当作全量已绿 |

本轮独立日志、结果包与临时基准程序位于临时目录，可能被系统清理：

- `/tmp/foldcheck-dashboard-review-package.log`
- `/tmp/foldcheck-dashboard-review-l10n.log`
- `/tmp/foldcheck-dashboard-review-build.log`
- `/tmp/foldcheck-dashboard-review-ui-retry.xcresult`
- `/tmp/foldcheck-dashboard-review-tap.xcresult`
- `/tmp/foldcheck-dashboard-review-full-summary.json`
- `/tmp/foldcheck-dashboard-review-benchmark.log`
- `/tmp/foldcheck-dashboard-benchmark/`

完整既有运行的结果包：`/tmp/claude-501/-Users-yuyuanzhengjack-Developments-GitHub-Repos-foldcheck/cdc1dfed-f86c-445d-b22d-f321314717f9/scratchpad/dddash17/Logs/Test/Test-FoldCheck-2026.10.16_22-24-48--0400.xcresult`。

## 尚未覆盖

- 首次使用、无记录的 UI 自动化：模型单测已有，本轮仍未新增 UI 测试。
- 真实设备测量、VoiceOver 人工完整走查、外语母语校对。
- StoreKit Ask to Buy 卡住问题及全部购买测试。本轮没有修复或重复运行该已知挂起项。
- 全部七个 Swift 包的独立重跑：本轮只独立运行 TestsKit 和 FoldL10n，没有重新背书此前“262 项全部通过”的报告。
- 更新正式 App Store 截图。本目录只提供审查证据，没有覆盖原 M7 截图。

建议下一步先修三处界面/刷新问题，再补一次包含空状态的完整回归；购买测试恢复后单独给出明确结果。
