# M8 Widget 验证记录

2026-10-16，基于 `09c5c38` 直接在 main 增加 Widget，并核对 spec 中尚未完成的工作。阶段审计见 [spec-status.md](spec-status.md)，产品与数据规则见 `docs/foldcheck-spec.md` §4.1 / §10。

## 实现范围

- iOS 17+ 的原生 WidgetKit 扩展：桌面小/中尺寸和锁屏矩形。免费，点按选择首页。
- 数据与首页使用同一个 `DeviceHealth` 聚合规则。桌面小/中尺寸都显示分数、状态、已测数量和检查日期，避免单项通过被看成整机检查通过；中尺寸增加需留意数量；锁屏使用紧凑分数及状态图标，VoiceOver 仍能读取完整本地化分数和状态。
- App Group `group.com.jackyu.foldcheck` 只共享 `widget-health-v1.json` 的汇总字段。原有 SwiftData、报告、备注、照片和签名密钥没有迁移或开放给扩展。
- 只在前台发布保存、删除、适用部件或语言变化；前台恢复时重试，避免退后台时铰链上下文暂时丢失覆盖 Duo 汇总。只在快照变化后请求系统刷新。Widget 不执行检查、不采集后台铰链数据，也不宣称实时健康状态。绝对日期明确表示已保存检查。
- 缺少数据、损坏版本、尚未解锁后的不可读文件或 App Group 不可用时显示首次检查提示，不制造分数。DEBUG 截图/空历史 fixtures、FoldMock、UI 测试与单测不会覆盖真实共享快照。一旦观察到物理铰链，汇总会保留该设备能力，避免场景暂时丢失上下文导致部件消失；不生成虚构角度或测量数据。

## 工具链与自动验证

Xcode 27.1 build `27A9275`，当前安装路径 `/Applications/Xcode.app`（原 `Xcode-27.1RC.app` 已改名）。始终逐命令指定 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`，没有更改机器默认 Xcode。

| 验证 | 结果 |
| --- | --- |
| XcodeGen | 生成 App、Widget 和测试目标成功 |
| Debug build-for-testing，Duo iOS 27.1 | 成功，Widget 已嵌入 `FoldCheck.app/PlugIns` |
| Release，通用 iOS 模拟器 | 成功，验证非 DEBUG 路径及 App/Widget 嵌入；不等于发行签名或上传 |
| 七个 Swift 包 | **269/269 通过**：46 FoldKit、37 HingeAnalysis、116 TestsKit、41 ReportKit、10 FoldL10n、13 Library、6 Store |
| Widget 模型/存储新增测试 | 4 项通过：仅共享汇总字段、变化去重/删除清空、缺失/损坏/未知版本、深链接边界 |
| Widget 渲染 | 中英文 × 小/中/锁屏 × 浅/深色，共 12 张附件；检查并修正中尺寸圆环标签重叠和中文锁屏分数截断；状态文字用主文字色，图标和圆环保留状态颜色 |
| 首页回归 | Duo 的 3 项通过；普通 iPhone 的 3 项通过，修正了测试把 Face ID 机型部件数固定写成 9 的假设 |

本轮最终构建/测试结果包与日志位于 `/tmp/foldcheck-widget-*`，可能被系统清理；下方图片已保存进仓库。

主要结果：`/tmp/foldcheck-widget-final-integration.xcresult`（Duo 渲染 + 3 项首页回归）、`/tmp/foldcheck-widget-final-ui.xcresult`（普通 iPhone 的渲染 + 3 项首页回归）、`/tmp/foldcheck-widget-coverage-layout.xcresult`（最终高对比文字和小尺寸已测比例版渲染）。这些是相关回归，不是全部 App UI 或购买用例的完整重跑。

## 实际系统主屏验证

创建独立的 `FoldCheck-Widget-QA` iPhone 17 / iOS 27.0 模拟器：`C62714BA-3281-4D1D-A254-51646BED6021`。没有清空或注入原 Duo/iPhone 模拟器的真实历史。此 QA 模拟器保留，便于再次查看。

1. 安装含扩展的构建，首次打开 App，确认 App Group 创建空快照。
2. 通过系统主屏“编辑 → 添加小组件 → FoldCheck”找到扩展；空状态能正确预览并添加到桌面。
3. 通过 App 的实际单项屏幕检查和“保存到历史”流程创建一条 QA 记录。快照由空变为 100 分、通过、已测 1/6；这只是模拟器流程验证，不是硬件健康证明。
4. 在 App 设置将语言从 English 切为简体中文。共享文件和实际桌面 Widget 均变为中文，数值保持一致。
5. App 留在设置页，返回主屏点按 Widget，确认回到中文首页，显示相同的 100 分和已测 1/6。
6. 最终构建额外验证隔离：以英文 `-ScreenshotFixtures` 打开 App，实际界面显示示例的 2/6；共享文件仍保留中文的真实保存 QA 结果 1/6。退出示例模式后再恢复正常发布，没有把合成示例推到桌面。

![系统主屏空状态](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/widget-2026-10-16/system-small-empty.png)

![系统主屏保存结果并切换中文](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/widget-2026-10-16/system-small-saved-zh.png)

![从设置页通过 Widget 回到首页](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/widget-2026-10-16/widget-link-opens-home.png)

## 布局渲染附件

以下是测试中渲染的同一扩展视图，使用明确的合成数据：85 分、2/9 个部件、1 个需留意。它们不是系统主屏/锁屏截图，不是实际设备检测结果。全部图片在 `docs/review/widget-2026-10-16/`。

![中文中尺寸深色](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/widget-2026-10-16/widget-zh-Hans-medium-dark.png)

![英文小尺寸浅色](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/widget-2026-10-16/widget-en-small-light.png)

![中文锁屏紧凑排版](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/widget-2026-10-16/widget-zh-Hans-lock-screen-dark.png)

## 未覆盖与发行前事项

- 实际系统宿主已检查桌面小尺寸；中尺寸和锁屏矩形本轮检查了同一视图的渲染附件，仍需补真实系统宿主、真实锁屏隐私/重启后首次解锁、系统着色模式及人类 VoiceOver 验收。
- 删除后清空通过存储单测验证，没有从真实历史删除数据进行人工演示。
- 需要在开发者账户与 App/Widget 两份发行 profile 中配置 App Group；模拟器 ad-hoc 签名不是发行签名验收。构建没有上传或自动提交 App Store。
- 没有承诺即时刷新。`reloadTimelines` 是系统刷新请求，WidgetKit 决定实际时机；没有添加轮询或后台传感器任务。
- StoreKit Ask to Buy 挂起、M0 真机校准和其他既有 spec 待办没有在本轮顺带修复；Store 包单测不等于购买流程测试。

API 依据：[Apple Widget 扩展文档](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)、[刷新与 timeline](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)、[App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)，并以当前 SDK 编译验证公开 API。
