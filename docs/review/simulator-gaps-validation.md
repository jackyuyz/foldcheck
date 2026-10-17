# 模拟器可完成项验证（2026-10-17）

范围：在 main 补齐 M1 / M2 / M4 与 M6 的本地测试缺口，以及 §8 调试钩子和遗漏的触控报告热图。不使用真机、不配置或提交 App Store Connect。

## 环境与执行

- Xcode 27.1 RC，`27A9275`。本机安装已从 `Xcode-27.1RC.app` 改名为 `/Applications/Xcode.app`；每条命令设置 `DEVELOPER_DIR`，未修改系统 xcode-select。
- 全量测试与独立 Release 构建命令：独立 `FoldCheck-Gaps-QA`（iPhone 17，iOS 27.0），避免另一组本机测试反复重启同一模拟器的 App。
- Duo 增补检查：独立 `FoldCheck-Duo-Gaps-QA`，iOS 27.1；iPad 兼容模式：独立 `FoldCheck-iPad-QA`，iOS 27.0。Duo 用 Device Hub 的 Open 展开真实内屏；模拟铰链信号不替代实际窗口布局。
- 测试数据仅作为模拟器 QA；自动完成的检查明确标注示例，不是硬件结果。

| 检查 | 结果 / 证据 |
| --- | --- |
| 八个 Swift 包 | 277 项通过：FoldKit 46、FoldL10n 10、HingeAnalysis 37、HingeInput 1、Library 13、ReportKit 41、Store 6、TestsKit 123（120 Swift Testing + 3 XCTest）。`/tmp/foldcheck-gaps-packages-final.log` |
| 本地 StoreKit | 最终代码在独立 iPhone 17 / iOS 27.0 和 Duo / iOS 27.1 均六项通过：批准、拒绝、购买/退款、恢复、商品与失败；使用显式 Test Plan 和标准购买 API，无需 Apple Account |
| Duo 定向回归 | 22 项 App 单测通过；14 项 UI 中 13 通过、1 按单栏条件跳过。实际展开内屏的两栏、大字号溢出、硬件不可用路径、中英文截图、四项新增流程均通过。`/tmp/foldcheck-duo-final.xcresult` |
| iPad 实际兼容提示 | 无 `-WindowTestMode` 注入，iPad Air 11-inch (M4) / iOS 27.0 用例通过并可开始 Pixels；已查看 `Actual-iPad-compatibility-disclosure` 截图。`/tmp/foldcheck-ipad-final.xcresult` |
| 全量 App 单测 + UI | iPhone 17 / iOS 27.0：22 项 App 单测通过；38 项 UI 中 36 通过、2 按两栏条件跳过，0 失败。包含全部格子/折痕带覆盖、旋转保留、Sensors、报告和付费门槛。`/tmp/foldcheck-final-full.xcresult`，Xcode `TEST SUCCEEDED` |
| Release 模拟器构建 | 通用 iOS Simulator（arm64/x86_64）`BUILD SUCCEEDED`，App 与 Widget 扩展完整嵌入；检查主二进制不包含 DEBUG `-AutoCompleteTests` 开关。`/tmp/foldcheck-release-final.log` |
| 最后增补验证 | 将竖屏初始化移到 MainActor 启动辅助方法后，iPhone 铰链通过用例复验成功（`/tmp/foldcheck-hinge-final.xcresult`）；PDF 热图分页标签修复后，Duo 22 项 App 单测 + 全检查→PDF UI 共 23 项通过（`/tmp/foldcheck-pdf-layout-final.xcresult`） |
| 工作流和脚本 | YAML 可解析；`bash -n` 和 `git diff --check` 通过。远端 Actions 执行与本地脚本验证分开记录 |

## M6：挂起处理与可证明的范围

原用例直接 `await store.purchase()`，没有操作时限，也没有停止测试创建的交易监听。现在异步操作在独立 Task 中运行，XCTest 15 秒 deadline 失败后取消任务，不用会等待不响应取消子任务退出的 task group。CI 另设每项 180 秒、上限 300 秒和整轮 40 分钟限额；长时间逐列覆盖网格需要超过旧 60 秒时限。

测试实际验证 pending 时不解锁，批准后由 `Transaction.updates` 自动解锁并清除 pending，拒绝后仍锁定。退款、失败及恢复也验证权益。缺少本地商品会失败，不再跳过。每个测试停止 Store 的更新监听并重置 SKTestSession；Store 析构也取消监听，避免跨用例遗留任务。

在全新模拟器中已复现购买请求超时；系统界面出现 Apple Account 登录，日志显示 Sandbox 认证请求，而本地产品加载和 SKTestSession 直接购买成功。新增 `FoldCheck.xctestplan` 将 Configuration.storekit 显式绑定 Test 动作；此前只明确绑定 Run。保留标准 Product.purchase()，另增强 unit-test host 检测，避免 App 在 SKTestSession 初始化前自行启动 Store，并同样防止 unit host 写 Widget 快照；最终代码已编译，并在独立普通 iPhone（本轮 22 项 App 单测约 2 秒）和 Duo 上通过全部六个本地购买用例。Duo 同时验证 guarded camera API 分支。先前误走 Sandbox 的诊断保留为环境故障证据，不把未验证的 SDK 内部根因写成结论；这不是正式 Sandbox 或 Family Sharing 验收。

## 人工布局检查

Duo 使用真实 provider（未传 `-FoldMock`）和隔离的 `-ScreenshotFixtures`。Device Hub 的 Open 与 Partially Open 改变实际显示布局：全开 180°、半折叠约 128°，健康环与卡片分列且避开折痕；深色模式的环、徽章和文字清晰。以下均为示例数据截图，不是实测设备健康或正式商店截图。

- [全展开内屏](screenshots/gaps-dashboard-inner-en.png)
- [半折叠深色内屏](screenshots/gaps-dashboard-partial-dark-en.png)
- [实际 iPad 窗口范围提示](screenshots/gaps-ipad-window-scope.png)
- [热图分页保留部件和屏幕标题](screenshots/gaps-touch-heatmap-page.png)

## 实现边界

- Duo 专用摄像头类型及 AVKit 方向协调器来自本机 SDK；预览/捕获使用系统旋转协调器。没有镜头的模拟器只证明安全的 Unavailable 路径，不能证明实际成像。隐藏/暂停镜头与采集配置失败分开处理。
- 照片默认仅在内存；完成测试时才保存明确选中的照片，并沿用本机 JPEG 附件和 PDF 路径。取消时无相机草稿文件清理需求。真实镜头到照片方向仍待真机。
- 听筒只接受 `builtInReceiver`；模拟器不会把 Mac 扬声器标作听筒。不可用步骤允许继续麦克风。用户是否听到、麦克风质量等不能由模拟器自动化证明。
- 窗口守卫比较同一屏幕坐标系下的 UIWindow 与 UIScreen 范围。阻挡时保留已挂载 runner；旋转不重新分格。iPad 兼容窗口先警告，显示结果附范围说明。
- 新触控结果包含原始物理网格及覆盖；旧记录仍能读取且不补造格子。PDF 热图进入规范签名数据，修改格子会破坏其验证；可见 PDF 页面和照片文件本身仍不做全字节签名。
- `-UITestMode 1 -AutoCompleteTests pass` 只有 DEBUG 生效，并使用隔离内存历史、醒目标记和每项示例说明；其通过仅覆盖完整检查/汇总/PDF 的连接。

## CI 与剩余验收

`macos-26` 跑八包，GitHub 官方的 `xcode-27` 预览镜像跑普通 iPhone 模拟器回归及 Release 构建。镜像可能只有 27.0，日志显示实际版本；这种执行不能作为 Duo 27.1 路径的验收。官方镜像说明：https://github.com/actions/runner-images/issues/14404 。脚本无需发行签名秘密，不上传构建，不调用私有姿态 CLI。本地 RC 在已通过的 iPad/Duo 用例结束后仍触发 `simctl diagnose --timeout=600`（进程采样确认为诊断等待）；CI 使用官方 `-collect-test-diagnostics never` 避免完整系统诊断阻塞，仍保留 XCTest 结果、截图附件和 coverage。全量测试结束后手动停止的也仅是它的诊断子进程，未停止 XCTest，Xcode 正常写出 `TEST SUCCEEDED`。

本地 UI 回归的运行日志仍有系统关于 AVAudioSession 同步激活/主线程调用的建议（按键及音频路径）；这些路径未在本轮发生挂起，但实际音频路由和响应性仍需真机验收。

真实铰链采样、触控尺寸、亮度/摄像头/音频/认证/按键/触感/Secure Enclave，以及 Sandbox、通知投递、人工无障碍/网络代理/首用时长、发布联系人/发行配置，仍按 spec-status.md 待验收。

## 磁盘中断记录

2026-10-17 曾因本机数据卷仅余约 167 MB 导致 Swift 编译失败。用户释放其他空间后，又明确授权删除两个指定构建目录 `/private/tmp/foldcheck-widget-derived`、`/private/tmp/foldcheck-store-diagnosis-derived`；删除时已确认无相关构建进程，未删除源码、Git 历史或模拟器数据。恢复约 38 GB 可用空间后重新构建和运行回归；旧的中断轮次不能作为通过证据。

早期中断轮次 `/tmp/foldcheck-gaps-isolated2.xcresult` 有 Test Plan 修复前的购买超时和 Sensors 崩溃，随后因磁盘耗尽停止；这些不能作为通过证据。恢复后的全量回归已包含上述用例并通过。
