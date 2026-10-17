# Spec 阶段核对（2026-10-16）

基线 `09c5c38`，随后增加 M8 Widget。按代码、现有测试及验证记录核对；没有把模拟器结果当作真机或上架验收。完整状态表已写回 `docs/foldcheck-spec.md` §10。

## 确实尚未实现的项

| 优先级 | 所属阶段 | 差距 | 代码证据 / 建议 |
| --- | --- | --- | --- |
| 高 | M1 | CI 尚未落地 | 仓库没有 `.github/workflows/`；本地测试通过不等于持续集成。先增加七个 Swift 包的检查，再配置满足 SDK/模拟器要求的 App runner |
| 高 | M4 / T5 | Duo 专用摄像头枚举和方向协调路径未落地 | `App/Tests/Hardware/CameraTestView.swift` 目前只发现通用 wide/ultra-wide/telephoto。不能宣称已验证覆盖所有 Duo 内外摄像头；需 SDK API 与真实设备核对 |
| 中 | M2 / §3 | 多任务全屏阻挡说明、iPad 兼容窗口提示 | `fullScreenCover` 只是 App 内呈现方式，不能代替窗口是否覆盖实际显示区域的检测和提示；当前无该防护 |
| 中 | M4 / T6 | 单独路由的听筒测试 | `AudioTestController.activate()` 明确使用 `.defaultToSpeaker`，当前只有左右声道音调和麦克风回放；应实现可路由时的听筒步骤或明确缩减规格 |
| 低 | M4 / T5 | 相机测试帧自愿附加到报告 | 当前 Capture 只保留数值，不存照片。T3 已实现外部照片导入；两者不要混淆 |
| 低 | M1 | 独立共享 HingeInput 包 | 当前 `Packages/` 无此包；手动铰链输入已直接集成 App。建议等组合应用复用需要明确后再提取，不阻挡当前检查流程 |
| 测试工具 | §8 | `-AutoCompleteTests pass` 快捷钩子 | 当前没有该参数。现有 UI 测试实际操作控件；完整检查的自动跳转钩子应标未实现，不能当作已有测试证据 |

没有发现整套 M2、M3、M5 或 M6 功能完全没做；主要模块均已有代码和测试。AC3 的全网格滑动覆盖脚本在 `UITests/DisplayTouchUITests.swift`，已实现，不应列成缺失。

其他实现差异与功能遗漏分开记录：图标按用户决定保留现有绿底勾；本地化用六种语言 JSON catalogs；TestsKit 保留纯模型、SwiftUI 测试界面放在 App；`InspectionSession` 是 Codable 值，`Library.StoredSession` 才是 SwiftData 模型。后面三项是当前代码的架构选择，并非额外待做页面，也不代表原始类型/协议草图已经逐字实现；spec 的设计/模块说明已据此澄清。

## 已实现，但仍未完成验收

- **M0 / M3 真机**：铰链采样精度、频率、量化、阈值、触控折痕带比例、内外屏亮度恢复、真实摄像头、Touch ID、邻近/音频/按键/触感、Secure Enclave。需要真实设备，不宜通过虚构测量补齐。
- **M6 购买**：`Tests/StorePurchaseTests.swift` 的 iOS 27 Ask to Buy 挂起尚未解决。之前相关本地检查不等于本轮所有购买用例通过；正式 Sandbox、购买/恢复/退款/待批准、商品和 Family Sharing 配置仍要确认。
- **M7 验收**：AC1 首次使用 ≤6 分钟的人测、AC9 实际代理网络审计、人工 VoiceOver/Reduce Motion、通知真实投递、摄像头二维码和 Files 导入、外语母语校对。
- **上架**：`AppLinks.privacy` / `support@example.com` 为占位，开发团队与发行签名、App Store Connect 商品及隐私申报、正式 Release 截图尚待配置。已写好的中英文上架文案是草稿，不是已提交或已发行证据。

## M8 决定

新增免费、只读的健康概览 Widget 有价值：它复用用户已经保存的检查，减少为查看状态而打开 App 的步骤，不引入后台硬件采集。实现范围为桌面小/中尺寸、锁屏矩形、空状态、应用内六语言和点按打开首页。刷新受 WidgetKit 调度；没有实时诊断、后台折叠统计或购买门槛变化。

实现与实际验证边界见 `docs/review/widget-validation.md`。上述既有缺口保留为明确待办，本轮没有顺带将它们标成已完成。
