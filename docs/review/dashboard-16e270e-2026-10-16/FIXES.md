# 仪表盘审查问题修复

2026-10-16，基于 `16e270e`，按用户要求直接在 main 完成。

## 改动

- 新增 `Library.DeviceHealthCache`：仅记录 payload 改变时解码历史，仅记录或适用部件变化时重新汇总。首页不再订阅每个角度为界面状态，只观察是否有铰链；布局和测试启动仍使用原有的实时折叠状态。
- 新增缓存回归测试，覆盖连续 181 次角度变化复用缓存、记录插入/原地更新/删除、空记录，以及设备适用部件变化。
- 最大辅助字号下把“满分 100”移到环外，保留动态字体和合并的无障碍分数说明。普通字号布局保留。
- 健康环读取 `accessibilityReduceMotion`，开启减弱动态效果时取消分数变化动画。
- 六种语言增加“根据各部件最近已保存结果汇总”和已测部件数量；历史入口改为“最近一次完整体检”。计分规则、图标和付费边界保持原样。
- 新增仅 Debug 可用的 `-EmptyHistoryFixtures`，用独立的内存数据容器测试首次使用；不会清空本机历史。补上空历史和最大辅助字号 UI 测试，并验证示例数据的已测数量。

## 验证

工具链：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`，Xcode 27.1 build `27A9275`。

| 检查 | 结果 |
| --- | --- |
| XcodeGen 生成项目 | 成功 |
| Duo iOS 27.1 build-for-testing | 成功 |
| FoldKit / HingeAnalysis / TestsKit | 46 / 37 / 116 项通过 |
| ReportKit / FoldL10n / Library / Store | 41 / 10 / 9 / 6 项通过 |
| 七个包合计 | **265 项全部通过** |
| Duo 仪表盘 UI | **3/3 通过**：有数据、无数据、最大辅助字号 |
| iPhone 17 iOS 27.0 相关回归 | **11/11 通过**：4 项 App 单测、4 项首页/导航、无铰链设备、大字号操作、逐格点按 |
| 中文 Duo 实际展开状态人工截图 | 普通字号、最大辅助字号、空历史均正常 |
| Git diff whitespace 检查 | 通过 |

本轮是相关回归，没有重跑全部 App UI 测试和 StorePurchaseTests。之前不稳定的逐格点按测试本轮通过，但未据此宣称长期稳定性问题已经解决。Store 包的 6 项门槛单测不等同于 StoreKit Ask to Buy 购买流程测试。

减弱动态效果通过代码环境值分支修复；本轮没有自动切换系统辅助功能设置进行人工动画对比。

日志：`/tmp/foldcheck-dashboard-fix-*.log`。UI 结果包：`/tmp/foldcheck-dashboard-fix-duo-ui.xcresult`、`/tmp/foldcheck-dashboard-fix-regression.xcresult`。临时目录可能被系统清理。

## 修复后截图

以下均为隔离示例数据或空内存历史，未使用折叠状态 Mock；不是硬件检测结果或最终上架素材。

### 最大辅助字号：说明已移到环外

![修复后的最大辅助字号](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/dashboard-16e270e-2026-10-16/06-fixed-accessibility-text.png)

### 普通字号：显示汇总依据和已测数量

![修复后的中文仪表盘](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/dashboard-16e270e-2026-10-16/07-fixed-inner-light.png)

### 首次使用：空历史

![空历史仪表盘](/Users/yuyuanzhengjack/Developments/GitHub_Repos/foldcheck/docs/review/dashboard-16e270e-2026-10-16/08-fixed-empty-history.png)
